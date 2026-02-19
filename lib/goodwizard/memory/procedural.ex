defmodule Goodwizard.Memory.Procedural do
  @moduledoc """
  File-based CRUD, recall scoring, and usage tracking for procedural memory entries.

  Procedures are learned behavioral patterns (workflows, preferences, rules,
  strategies, tool usage) stored as individual markdown files in
  `memory/procedural/` with YAML frontmatter metadata.

  Unlike episodic memory, procedures are mutable — they can be updated as the
  agent refines its understanding, and their confidence levels shift
  automatically based on usage outcomes.

  Uses `Memory.Entry` for parsing/serialization, `Memory.Paths` for path
  construction, and `Brain.Id` for UUID7 generation.
  """

  require Logger

  alias Goodwizard.Brain.Id
  alias Goodwizard.Memory.Entry
  alias Goodwizard.Memory.Paths

  @procedure_types ~w(workflow preference rule strategy tool_usage)
  @confidence_levels ~w(high medium low)
  @source_types ~w(learned taught inferred)

  @auto_managed_fields ~w(id created_at usage_count success_count failure_count last_used)

  @max_file_scan 1_000
  @max_list_limit 200
  @default_list_limit 20
  @default_recall_limit 5

  # Recall scoring weights
  @tag_weight 0.4
  @text_weight 0.3
  @confidence_weight 0.2
  @recency_weight 0.1

  # Recency decay window in days
  @recency_decay_days 90

  # Confidence promotion/demotion thresholds
  @promote_low_to_medium 3
  @promote_medium_to_high 5
  @demote_high_to_medium 2
  @demote_medium_to_low 3

  @doc "Returns the list of valid procedure types."
  @spec procedure_types() :: [String.t()]
  def procedure_types, do: @procedure_types

  @doc "Returns the list of valid confidence levels."
  @spec confidence_levels() :: [String.t()]
  def confidence_levels, do: @confidence_levels

  @doc "Returns the list of valid source types."
  @spec source_types() :: [String.t()]
  def source_types, do: @source_types

  @doc """
  Creates a procedural memory entry.

  Auto-generates a UUID7 `id`, `created_at`, and `updated_at` timestamps.
  Sets `usage_count`, `success_count`, `failure_count` to 0 and `last_used`
  to nil. Validates required fields (`type`, `summary`, `source`) and their
  allowed values. Defaults `confidence` to `"medium"` if not provided.

  Writes the procedure to `memory/procedural/<id>.md`.

  Returns `{:ok, frontmatter_map}` or `{:error, reason}`.
  """
  @spec create(String.t(), map(), String.t()) :: {:ok, map()} | {:error, term()}
  def create(memory_dir, frontmatter, body) when is_map(frontmatter) and is_binary(body) do
    with {:ok, _} <- Paths.validate_memory_dir(memory_dir),
         :ok <- validate_required(frontmatter),
         :ok <- validate_type(frontmatter),
         :ok <- validate_source(frontmatter),
         :ok <- validate_confidence(frontmatter),
         {:ok, id} <- Id.generate(),
         dir = Paths.procedural_dir(memory_dir),
         :ok <- File.mkdir_p(dir) do
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

      enriched =
        frontmatter
        |> Map.put("id", id)
        |> Map.put("created_at", timestamp)
        |> Map.put("updated_at", timestamp)
        |> Map.put_new("confidence", "medium")
        |> Map.put_new("tags", [])
        |> Map.put("usage_count", 0)
        |> Map.put("success_count", 0)
        |> Map.put("failure_count", 0)
        |> Map.put("last_used", nil)

      content = Entry.serialize(enriched, body)
      path = Path.join(dir, "#{id}.md")

      case File.write(path, content) do
        :ok -> {:ok, enriched}
        {:error, reason} -> {:error, {:fs_error, reason}}
      end
    end
  end

  @doc """
  Reads a procedural memory entry by ID.

  Returns `{:ok, {frontmatter_map, body_string}}` or `{:error, :not_found}`.
  """
  @spec read(String.t(), String.t()) :: {:ok, {map(), String.t()}} | {:error, term()}
  def read(memory_dir, id) do
    with {:ok, _} <- Paths.validate_memory_dir(memory_dir),
         {:ok, path} <- Paths.procedure_path(memory_dir, id) do
      case File.read(path) do
        {:ok, content} ->
          Entry.parse(content)

        {:error, :enoent} ->
          {:error, :not_found}

        {:error, reason} ->
          {:error, {:fs_error, reason}}
      end
    end
  end

  @doc """
  Updates a procedure's frontmatter and optionally its body.

  Frontmatter updates are merged into the existing frontmatter. Auto-managed
  fields (`id`, `created_at`, `usage_count`, `success_count`, `failure_count`,
  `last_used`) cannot be overwritten by the caller. The `updated_at` field is
  auto-set to the current timestamp.

  Pass `nil` for body to keep the existing body unchanged.

  Returns `{:ok, merged_frontmatter}` or `{:error, reason}`.
  """
  @spec update(String.t(), String.t(), map(), String.t() | nil) ::
          {:ok, map()} | {:error, term()}
  def update(memory_dir, id, frontmatter_updates, body \\ nil) do
    with_file_lock(id, fn ->
      with {:ok, _} <- Paths.validate_memory_dir(memory_dir),
           {:ok, path} <- Paths.procedure_path(memory_dir, id),
           {:ok, {existing_fm, existing_body}} <- read_file(path) do
        persist_update(path, existing_fm, existing_body, frontmatter_updates, body)
      end
    end)
  end

  @doc """
  Deletes a procedural memory entry by ID.

  Returns `:ok` or `{:error, :not_found}`.
  """
  @spec delete(String.t(), String.t()) :: :ok | {:error, :not_found}
  def delete(memory_dir, id) do
    with {:ok, _} <- Paths.validate_memory_dir(memory_dir),
         {:ok, path} <- Paths.procedure_path(memory_dir, id) do
      case File.rm(path) do
        :ok -> :ok
        {:error, :enoent} -> {:error, :not_found}
      end
    end
  end

  @doc """
  Lists procedural memory entries with optional filters.

  Returns frontmatter maps only (no body content), sorted by `updated_at`
  descending (most recently modified first).

  ## Options

  - `:limit` — max results (default #{@default_list_limit})
  - `:type` — filter by procedure type
  - `:confidence` — minimum confidence level (low < medium < high)
  - `:tags` — filter by tags (intersection match — procedure must have all listed tags)
  - `:min_usage_count` — minimum usage count
  """
  @spec list(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list(memory_dir, opts \\ []) do
    with {:ok, _} <- Paths.validate_memory_dir(memory_dir) do
      limit = opts |> Keyword.get(:limit, @default_list_limit) |> min(@max_list_limit)
      dir = Paths.procedural_dir(memory_dir)

      entries =
        dir
        |> list_procedure_files()
        |> read_entries()
        |> filter_entries_by_type(Keyword.get(opts, :type))
        |> filter_entries_by_confidence(Keyword.get(opts, :confidence))
        |> filter_entries_by_tags(Keyword.get(opts, :tags))
        |> filter_entries_by_min_usage(Keyword.get(opts, :min_usage_count))
        |> Enum.map(fn {fm, _body} -> fm end)
        |> sort_by_updated_at_desc()
        |> Enum.take(limit)

      {:ok, entries}
    end
  end

  @doc """
  Finds procedures relevant to a given situation description.

  Computes a weighted relevance score for each procedure:
  `tag_match * 0.4 + text_relevance * 0.3 + confidence_score * 0.2 + recency_score * 0.1`

  Results are sorted by score descending. Each returned frontmatter map
  includes a `"score"` key with the computed value.

  ## Options

  - `:limit` — max results (default #{@default_recall_limit})
  - `:type` — filter by procedure type
  - `:tags` — query tags for tag matching score
  - `:min_confidence` — minimum confidence level filter
  """
  @spec recall(String.t(), String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def recall(memory_dir, situation, opts \\ []) do
    with {:ok, _} <- Paths.validate_memory_dir(memory_dir) do
      limit = opts |> Keyword.get(:limit, @default_recall_limit) |> min(@max_list_limit)
      query_tags = Keyword.get(opts, :tags, [])
      dir = Paths.procedural_dir(memory_dir)

      results =
        dir
        |> list_procedure_files()
        |> read_entries()
        |> filter_entries_by_type(Keyword.get(opts, :type))
        |> filter_entries_by_confidence(Keyword.get(opts, :min_confidence))
        |> Enum.map(fn {fm, body} ->
          score = compute_score(fm, situation, query_tags, body)
          Map.put(fm, "score", score)
        end)
        |> Enum.sort_by(& &1["score"], :desc)
        |> Enum.take(limit)

      {:ok, results}
    end
  end

  @doc """
  Computes the weighted relevance score for a procedure.

  Score = tag_match * 0.4 + text_relevance * 0.3 + confidence * 0.2 + recency * 0.1
  """
  @spec compute_score(map(), String.t(), [String.t()]) :: float()
  def compute_score(frontmatter, situation, query_tags) do
    compute_score(frontmatter, situation, query_tags, "")
  end

  defp compute_score(frontmatter, situation, query_tags, body) do
    tag_score = tag_match_score(frontmatter["tags"] || [], query_tags)
    text_score = text_relevance_score(situation, frontmatter, body)
    conf_score = confidence_score(frontmatter["confidence"])
    rec_score = recency_score(frontmatter["last_used"])

    tag_score * @tag_weight +
      text_score * @text_weight +
      conf_score * @confidence_weight +
      rec_score * @recency_weight
  end

  @doc """
  Records usage of a procedure and automatically adjusts confidence.

  Increments `usage_count` and the corresponding outcome counter
  (`success_count` or `failure_count`), updates `last_used` to the current
  timestamp, and evaluates confidence adjustment rules.

  Returns `{:ok, updated_frontmatter}` or `{:error, reason}`.
  """
  @spec record_usage(String.t(), String.t(), :success | :failure) ::
          {:ok, map()} | {:error, term()}
  def record_usage(memory_dir, id, outcome) when outcome in [:success, :failure] do
    with_file_lock(id, fn ->
      with {:ok, _} <- Paths.validate_memory_dir(memory_dir),
           {:ok, path} <- Paths.procedure_path(memory_dir, id),
           {:ok, {fm, body}} <- read_file(path) do
        persist_usage(path, fm, body, outcome)
      end
    end)
  end

  @doc """
  Decays confidence of procedures not used within the given time windows.

  Scans all procedures and:
  - Demotes high -> medium and medium -> low for procedures with `last_used`
    older than `decay_days` (or nil)
  - Deletes procedures at low confidence with `last_used` older than
    `archive_days` (or nil with `created_at` older than `archive_days`)

  Uses `updated_at` as an idempotency guard: procedures updated today
  (e.g., by a previous decay run) are skipped.

  ## Options

  - `:decay_days` — days without use before demotion (default 60)
  - `:archive_days` — days without use at low confidence before deletion (default 120)

  Returns `{:ok, %{demoted: count, deleted: count, unchanged: count}}`.
  """
  @spec decay_unused(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def decay_unused(memory_dir, opts \\ []) do
    decay_days = Keyword.get(opts, :decay_days, 60)
    archive_days = Keyword.get(opts, :archive_days, 120)

    with {:ok, _} <- Paths.validate_memory_dir(memory_dir) do
      now = DateTime.utc_now()
      decay_cutoff = DateTime.add(now, -decay_days, :day)
      archive_cutoff = DateTime.add(now, -archive_days, :day)
      today = DateTime.to_date(now)

      dir = Paths.procedural_dir(memory_dir)

      entries =
        dir
        |> list_procedure_files()
        |> read_entries()

      {demoted, deleted, unchanged} =
        Enum.reduce(entries, {0, 0, 0}, fn {fm, _body}, {dem, del, unch} ->
          {d_dem, d_del, d_unch} =
            process_decay_entry(memory_dir, fm, today, decay_cutoff, archive_cutoff)

          {dem + d_dem, del + d_del, unch + d_unch}
        end)

      {:ok, %{demoted: demoted, deleted: deleted, unchanged: unchanged}}
    end
  end

  defp updated_today?(fm, today) do
    case fm["updated_at"] do
      nil ->
        false

      ts ->
        case DateTime.from_iso8601(ts) do
          {:ok, dt, _} -> DateTime.to_date(dt) == today
          _ -> false
        end
    end
  end

  defp classify_for_decay(fm, decay_cutoff, archive_cutoff) do
    confidence = fm["confidence"] || "medium"
    last_used = parse_iso_datetime(fm["last_used"])
    created_at = parse_iso_datetime(fm["created_at"])
    activity_time = last_used || created_at

    cond do
      should_delete?(confidence, activity_time, archive_cutoff) -> :delete
      should_demote?(confidence, activity_time, decay_cutoff) -> :demote
      true -> :keep
    end
  end

  defp demote_confidence("high"), do: "medium"
  defp demote_confidence("medium"), do: "low"
  defp demote_confidence(other), do: other

  defp parse_iso_datetime(nil), do: nil

  defp parse_iso_datetime(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  @doc """
  Evaluates confidence promotion/demotion rules based on cumulative counts.

  - Promote: low -> medium at #{@promote_low_to_medium} successes; medium -> high at #{@promote_medium_to_high} successes
  - Demote: high -> medium at #{@demote_high_to_medium} failures; medium -> low at #{@demote_medium_to_low} failures

  Returns the adjusted confidence level string.
  """
  @spec adjust_confidence(map()) :: String.t()
  def adjust_confidence(frontmatter) do
    confidence = frontmatter["confidence"] || "medium"
    successes = frontmatter["success_count"] || 0
    failures = frontmatter["failure_count"] || 0

    promote_confidence(confidence, successes, failures)
  end

  # --- Scoring helpers ---

  @doc false
  def tag_match_score(_procedure_tags, []), do: 0.0

  def tag_match_score(procedure_tags, query_tags) do
    matches = Enum.count(query_tags, &(&1 in procedure_tags))
    matches / length(query_tags)
  end

  # Minimum word length for text relevance matching (filters common short words)
  @min_relevance_word_length 3

  @doc false
  def text_relevance_score(situation, frontmatter, body \\ "") do
    words =
      situation
      |> String.downcase()
      |> String.split(~r/\s+/, trim: true)
      |> Enum.filter(&(String.length(&1) >= @min_relevance_word_length))
      |> Enum.uniq()

    if words == [] do
      0.0
    else
      searchable =
        [frontmatter["summary"] || "", body]
        |> Enum.join(" ")
        |> String.downcase()

      searchable_words =
        searchable
        |> String.split(~r/[\s\p{P}]+/u, trim: true)
        |> MapSet.new()

      matches = Enum.count(words, &MapSet.member?(searchable_words, &1))
      matches / length(words)
    end
  end

  @doc false
  def confidence_score("high"), do: 1.0
  def confidence_score("medium"), do: 0.6
  def confidence_score("low"), do: 0.3
  def confidence_score(_), do: 0.0

  @doc false
  def recency_score(nil), do: 0.0

  def recency_score(last_used) when is_binary(last_used) do
    case DateTime.from_iso8601(last_used) do
      {:ok, dt, _offset} ->
        seconds_ago = DateTime.diff(DateTime.utc_now(), dt, :second)

        if seconds_ago <= 0 do
          1.0
        else
          decay_seconds = @recency_decay_days * 86_400
          max(0.0, 1.0 - seconds_ago / decay_seconds)
        end

      _ ->
        0.0
    end
  end

  # Serializes read-then-write operations per procedure ID using :global.trans/2
  defp with_file_lock(id, fun) do
    :global.trans({__MODULE__, id}, fn -> fun.() end)
  end

  # --- Validation helpers ---

  defp validate_required(frontmatter) do
    Enum.reduce_while(~w(type summary source), :ok, fn field, :ok ->
      if Map.has_key?(frontmatter, field) do
        {:cont, :ok}
      else
        {:halt, {:error, {:missing_required, field}}}
      end
    end)
  end

  defp validate_type(%{"type" => type}) when type in @procedure_types, do: :ok
  defp validate_type(%{"type" => type}), do: {:error, {:invalid_type, type}}
  defp validate_type(_), do: :ok

  defp validate_confidence(%{"confidence" => confidence}) when confidence in @confidence_levels,
    do: :ok

  defp validate_confidence(%{"confidence" => confidence}),
    do: {:error, {:invalid_confidence, confidence}}

  defp validate_confidence(_), do: :ok

  defp validate_source(%{"source" => source}) when source in @source_types, do: :ok
  defp validate_source(%{"source" => source}), do: {:error, {:invalid_source, source}}
  defp validate_source(_), do: :ok

  # --- Private helpers ---

  defp read_file(path) do
    case File.read(path) do
      {:ok, content} -> Entry.parse(content)
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, {:fs_error, reason}}
    end
  end

  defp increment_outcome(fm, :success) do
    Map.update(fm, "success_count", 1, &((&1 || 0) + 1))
  end

  defp increment_outcome(fm, :failure) do
    Map.update(fm, "failure_count", 1, &((&1 || 0) + 1))
  end

  # Scans up to @max_file_scan procedure files, sorted by filename (UUID7 creation
  # order) descending. If the directory contains more files than @max_file_scan,
  # older procedures are silently excluded from list/recall results. This is a
  # pragmatic ceiling to bound memory/IO for very large stores.
  defp list_procedure_files(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        md_files =
          files
          |> Enum.filter(&String.ends_with?(&1, ".md"))
          |> Enum.sort(:desc)

        if length(md_files) > @max_file_scan do
          Logger.warning(
            "Procedural store has #{length(md_files)} files, scanning only the newest #{@max_file_scan}"
          )
        end

        md_files
        |> Enum.take(@max_file_scan)
        |> Enum.map(&Path.join(dir, &1))

      {:error, :enoent} ->
        []

      {:error, reason} ->
        Logger.warning("Unable to list procedural directory #{dir}: #{inspect(reason)}")
        []
    end
  end

  defp read_entries(paths) do
    Enum.flat_map(paths, fn path ->
      case File.read(path) do
        {:ok, content} ->
          parse_entry(path, content)

        _ ->
          []
      end
    end)
  end

  defp persist_update(path, existing_fm, existing_body, frontmatter_updates, body) do
    safe_updates = Map.drop(frontmatter_updates, @auto_managed_fields)

    merged =
      existing_fm
      |> Map.merge(safe_updates)
      |> Map.put("updated_at", DateTime.utc_now() |> DateTime.to_iso8601())

    with :ok <- validate_type(merged),
         :ok <- validate_source(merged),
         :ok <- validate_confidence(merged) do
      final_body = if body != nil, do: body, else: existing_body
      write_serialized(path, merged, final_body)
    end
  end

  defp persist_usage(path, fm, body, outcome) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    updated =
      fm
      |> Map.update("usage_count", 1, &((&1 || 0) + 1))
      |> increment_outcome(outcome)
      |> Map.put("last_used", timestamp)
      |> Map.put("updated_at", timestamp)
      |> apply_confidence_transition(fm)

    write_serialized(path, updated, body)
  end

  defp apply_confidence_transition(updated, previous_fm) do
    old_confidence = previous_fm["confidence"] || "medium"
    new_confidence = adjust_confidence(updated)
    direction = confidence_level_value(new_confidence) - confidence_level_value(old_confidence)

    updated
    |> Map.put("confidence", new_confidence)
    |> maybe_reset_opposing_counter(direction)
  end

  defp maybe_reset_opposing_counter(frontmatter, direction) when direction > 0,
    do: Map.put(frontmatter, "failure_count", 0)

  defp maybe_reset_opposing_counter(frontmatter, direction) when direction < 0,
    do: Map.put(frontmatter, "success_count", 0)

  defp maybe_reset_opposing_counter(frontmatter, _direction), do: frontmatter

  defp write_serialized(path, frontmatter, body) do
    content = Entry.serialize(frontmatter, body)

    case File.write(path, content) do
      :ok -> {:ok, frontmatter}
      {:error, reason} -> {:error, {:fs_error, reason}}
    end
  end

  defp process_decay_entry(memory_dir, fm, today, decay_cutoff, archive_cutoff) do
    if updated_today?(fm, today) do
      {0, 0, 0}
    else
      apply_decay_action(memory_dir, fm, classify_for_decay(fm, decay_cutoff, archive_cutoff))
    end
  end

  defp apply_decay_action(memory_dir, fm, :delete) do
    case delete(memory_dir, fm["id"]) do
      :ok -> {0, 1, 0}
      _ -> {0, 0, 0}
    end
  end

  defp apply_decay_action(memory_dir, fm, :demote) do
    new_confidence = demote_confidence(fm["confidence"])

    case update(memory_dir, fm["id"], %{"confidence" => new_confidence}) do
      {:ok, _} -> {1, 0, 0}
      _ -> {0, 0, 0}
    end
  end

  defp apply_decay_action(_memory_dir, _fm, :keep), do: {0, 0, 1}

  defp should_delete?("low", nil, _archive_cutoff), do: true

  defp should_delete?("low", activity_time, archive_cutoff) do
    DateTime.compare(activity_time, archive_cutoff) == :lt
  end

  defp should_delete?(_confidence, _activity_time, _archive_cutoff), do: false

  defp should_demote?(confidence, nil, _decay_cutoff), do: confidence in ["high", "medium"]

  defp should_demote?(confidence, activity_time, decay_cutoff) do
    confidence in ["high", "medium"] and DateTime.compare(activity_time, decay_cutoff) == :lt
  end

  defp promote_confidence("low", successes, _failures) do
    if successes >= @promote_low_to_medium, do: "medium", else: "low"
  end

  defp promote_confidence("medium", successes, failures) do
    cond do
      successes >= @promote_medium_to_high -> "high"
      failures >= @demote_medium_to_low -> "low"
      true -> "medium"
    end
  end

  defp promote_confidence("high", _successes, failures) do
    if failures >= @demote_high_to_medium, do: "medium", else: "high"
  end

  defp promote_confidence(other, _successes, _failures), do: other

  defp parse_entry(path, content) do
    case Entry.parse(content) do
      {:ok, {frontmatter, body}} ->
        [{frontmatter, body}]

      _ ->
        Logger.warning("Skipping corrupted procedure file: #{path}")
        []
    end
  end

  # --- Entry filters (operate on {frontmatter, body} tuples) ---

  defp filter_entries_by_type(entries, nil), do: entries

  defp filter_entries_by_type(entries, type) do
    Enum.filter(entries, fn {fm, _body} -> fm["type"] == type end)
  end

  defp filter_entries_by_confidence(entries, nil), do: entries

  defp filter_entries_by_confidence(entries, min_confidence) do
    min_level = confidence_level_value(min_confidence)

    Enum.filter(entries, fn {fm, _body} ->
      confidence_level_value(fm["confidence"]) >= min_level
    end)
  end

  defp filter_entries_by_tags(entries, nil), do: entries
  defp filter_entries_by_tags(entries, []), do: entries

  defp filter_entries_by_tags(entries, tags) do
    Enum.filter(entries, fn {fm, _body} ->
      entry_tags = fm["tags"] || []
      Enum.all?(tags, &(&1 in entry_tags))
    end)
  end

  defp filter_entries_by_min_usage(entries, nil), do: entries

  defp filter_entries_by_min_usage(entries, min_count) when is_integer(min_count) do
    Enum.filter(entries, fn {fm, _body} -> (fm["usage_count"] || 0) >= min_count end)
  end

  defp filter_entries_by_min_usage(entries, _non_integer), do: entries

  defp confidence_level_value("high"), do: 3
  defp confidence_level_value("medium"), do: 2
  defp confidence_level_value("low"), do: 1
  defp confidence_level_value(_), do: 0

  defp sort_by_updated_at_desc(entries) do
    Enum.sort_by(entries, & &1["updated_at"], :desc)
  end
end
