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
         :ok <- validate_confidence(frontmatter) do
      {:ok, id} = Id.generate()
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

      dir = Paths.procedural_dir(memory_dir)

      with :ok <- File.mkdir_p(dir) do
        content = Entry.serialize(enriched, body)
        path = Path.join(dir, "#{id}.md")

        case File.write(path, content) do
          :ok -> {:ok, enriched}
          {:error, reason} -> {:error, {:fs_error, reason}}
        end
      else
        {:error, reason} -> {:error, {:fs_error, reason}}
      end
    end
  end

  @doc """
  Reads a procedural memory entry by ID.

  Returns `{:ok, {frontmatter_map, body_string}}` or `{:error, :not_found}`.
  """
  @spec read(String.t(), String.t()) :: {:ok, {map(), String.t()}} | {:error, :not_found}
  def read(memory_dir, id) do
    with {:ok, _} <- Paths.validate_memory_dir(memory_dir),
         {:ok, path} <- Paths.procedure_path(memory_dir, id) do
      case File.read(path) do
        {:ok, content} ->
          Entry.parse(content)

        {:error, :enoent} ->
          {:error, :not_found}
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
    with {:ok, _} <- Paths.validate_memory_dir(memory_dir),
         {:ok, path} <- Paths.procedure_path(memory_dir, id),
         {:ok, {existing_fm, existing_body}} <- read_file(path) do
      # Strip auto-managed fields from caller updates
      safe_updates = Map.drop(frontmatter_updates, @auto_managed_fields)

      merged = Map.merge(existing_fm, safe_updates)
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
      merged = Map.put(merged, "updated_at", timestamp)

      with :ok <- validate_type(merged),
           :ok <- validate_source(merged),
           :ok <- validate_confidence(merged) do
        final_body = if body != nil, do: body, else: existing_body
        content = Entry.serialize(merged, final_body)

        case File.write(path, content) do
          :ok -> {:ok, merged}
          {:error, reason} -> {:error, {:fs_error, reason}}
        end
      end
    end
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
      limit = Keyword.get(opts, :limit, @default_list_limit)
      dir = Paths.procedural_dir(memory_dir)

      entries =
        dir
        |> list_procedure_files()
        |> read_frontmatters()
        |> filter_by_type(Keyword.get(opts, :type))
        |> filter_by_confidence(Keyword.get(opts, :confidence))
        |> filter_by_tags(Keyword.get(opts, :tags))
        |> filter_by_min_usage(Keyword.get(opts, :min_usage_count))
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
      limit = Keyword.get(opts, :limit, @default_recall_limit)
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

  @doc false
  def compute_score(frontmatter, situation, query_tags, body) do
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
    with {:ok, _} <- Paths.validate_memory_dir(memory_dir),
         {:ok, path} <- Paths.procedure_path(memory_dir, id),
         {:ok, {fm, body}} <- read_file(path) do
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

      updated =
        fm
        |> Map.update("usage_count", 1, &((&1 || 0) + 1))
        |> increment_outcome(outcome)
        |> Map.put("last_used", timestamp)
        |> Map.put("updated_at", timestamp)

      updated = Map.put(updated, "confidence", adjust_confidence(updated))

      content = Entry.serialize(updated, body)

      case File.write(path, content) do
        :ok -> {:ok, updated}
        {:error, reason} -> {:error, {:fs_error, reason}}
      end
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

    case confidence do
      "low" ->
        if successes >= @promote_low_to_medium, do: "medium", else: "low"

      "medium" ->
        cond do
          successes >= @promote_medium_to_high -> "high"
          failures >= @demote_medium_to_low -> "low"
          true -> "medium"
        end

      "high" ->
        if failures >= @demote_high_to_medium, do: "medium", else: "high"

      other ->
        other
    end
  end

  # --- Scoring helpers ---

  @doc false
  def tag_match_score(_procedure_tags, []), do: 0.0

  def tag_match_score(procedure_tags, query_tags) do
    matches = Enum.count(query_tags, &(&1 in procedure_tags))
    matches / length(query_tags)
  end

  @doc false
  def text_relevance_score(situation, frontmatter, body \\ "") do
    words =
      situation
      |> String.downcase()
      |> String.split(~r/\s+/, trim: true)
      |> Enum.uniq()

    if words == [] do
      0.0
    else
      searchable =
        [frontmatter["summary"] || "", body]
        |> Enum.join(" ")
        |> String.downcase()

      matches = Enum.count(words, &String.contains?(searchable, &1))
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
        days_ago = DateTime.diff(DateTime.utc_now(), dt, :day)

        if days_ago <= 0 do
          1.0
        else
          max(0.0, 1.0 - days_ago / @recency_decay_days)
        end

      _ ->
        0.0
    end
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
    end
  end

  defp increment_outcome(fm, :success) do
    Map.update(fm, "success_count", 1, &((&1 || 0) + 1))
  end

  defp increment_outcome(fm, :failure) do
    Map.update(fm, "failure_count", 1, &((&1 || 0) + 1))
  end

  defp list_procedure_files(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".md"))
        |> Enum.sort(:desc)
        |> Enum.take(@max_file_scan)
        |> Enum.map(&Path.join(dir, &1))

      {:error, :enoent} ->
        []
    end
  end

  defp read_frontmatters(paths) do
    Enum.flat_map(paths, fn path ->
      case File.read(path) do
        {:ok, content} ->
          case Entry.parse(content) do
            {:ok, {frontmatter, _body}} ->
              [frontmatter]

            _ ->
              Logger.warning("Skipping corrupted procedure file: #{path}")
              []
          end

        _ ->
          []
      end
    end)
  end

  defp read_entries(paths) do
    Enum.flat_map(paths, fn path ->
      case File.read(path) do
        {:ok, content} ->
          case Entry.parse(content) do
            {:ok, {frontmatter, body}} ->
              [{frontmatter, body}]

            _ ->
              Logger.warning("Skipping corrupted procedure file: #{path}")
              []
          end

        _ ->
          []
      end
    end)
  end

  # --- List filters (operate on frontmatter maps) ---

  defp filter_by_type(entries, nil), do: entries

  defp filter_by_type(entries, type) do
    Enum.filter(entries, &(&1["type"] == type))
  end

  defp filter_by_confidence(entries, nil), do: entries

  defp filter_by_confidence(entries, min_confidence) do
    min_level = confidence_level_value(min_confidence)
    Enum.filter(entries, &(confidence_level_value(&1["confidence"]) >= min_level))
  end

  defp filter_by_tags(entries, nil), do: entries
  defp filter_by_tags(entries, []), do: entries

  defp filter_by_tags(entries, tags) do
    Enum.filter(entries, fn fm ->
      entry_tags = fm["tags"] || []
      Enum.all?(tags, &(&1 in entry_tags))
    end)
  end

  defp filter_by_min_usage(entries, nil), do: entries

  defp filter_by_min_usage(entries, min_count) do
    Enum.filter(entries, &((&1["usage_count"] || 0) >= min_count))
  end

  # --- Recall filters (operate on {frontmatter, body} tuples) ---

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

  defp confidence_level_value("high"), do: 3
  defp confidence_level_value("medium"), do: 2
  defp confidence_level_value("low"), do: 1
  defp confidence_level_value(_), do: 0

  defp sort_by_updated_at_desc(entries) do
    Enum.sort_by(entries, & &1["updated_at"], :desc)
  end
end
