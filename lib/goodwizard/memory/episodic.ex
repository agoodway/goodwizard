defmodule Goodwizard.Memory.Episodic do
  @moduledoc """
  File-based CRUD and search for episodic memory entries.

  Episodes are structured records of past experiences stored as individual
  markdown files in `memory/episodic/` with YAML frontmatter metadata.
  Episodes are immutable after creation — no update operation is provided.

  Uses `Memory.Entry` for parsing/serialization and `Memory.Paths` for
  path construction.
  """

  require Logger

  alias Goodwizard.Brain.Id
  alias Goodwizard.Memory.Entry
  alias Goodwizard.Memory.Paths

  @episode_types ~w(task_completion problem_solved error_encountered decision_made interaction)
  @outcome_types ~w(success failure partial abandoned)

  @max_summary_length 200
  @max_file_scan 1_000
  @max_list_elements 20
  @max_element_length 100
  @default_list_limit 20
  @default_search_limit 10

  @doc "Returns the list of valid episode types."
  @spec episode_types() :: [String.t()]
  def episode_types, do: @episode_types

  @doc "Returns the list of valid outcome types."
  @spec outcome_types() :: [String.t()]
  def outcome_types, do: @outcome_types

  @doc """
  Creates an episodic memory entry.

  Auto-generates a UUID7 `id` and ISO 8601 `timestamp`. Validates required
  fields (`type`, `summary`, `outcome`) and their allowed values. Truncates
  summaries exceeding #{@max_summary_length} characters. Defaults `tags` and
  `entities_involved` to empty lists if not provided.

  Writes the episode to `memory/episodic/<id>.md`.

  Returns `{:ok, frontmatter_map}` or `{:error, reason}`.
  """
  @spec create(String.t(), map(), String.t()) :: {:ok, map()} | {:error, term()}
  def create(memory_dir, frontmatter, body) when is_map(frontmatter) and is_binary(body) do
    with {:ok, _} <- Paths.validate_memory_dir(memory_dir),
         :ok <- validate_required(frontmatter),
         :ok <- validate_type(frontmatter),
         :ok <- validate_outcome(frontmatter),
         :ok <- validate_list_field(frontmatter, "tags"),
         :ok <- validate_list_field(frontmatter, "entities_involved") do
      {:ok, id} = Id.generate()
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

      enriched =
        frontmatter
        |> Map.put("id", id)
        |> Map.put("timestamp", timestamp)
        |> Map.put_new("tags", [])
        |> Map.put_new("entities_involved", [])
        |> truncate_summary()

      dir = Paths.episodic_dir(memory_dir)

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
  Reads an episodic memory entry by ID.

  Returns `{:ok, {frontmatter_map, body_string}}` or `{:error, :not_found}`.
  """
  @spec read(String.t(), String.t()) :: {:ok, {map(), String.t()}} | {:error, :not_found}
  def read(memory_dir, id) do
    with {:ok, _} <- Paths.validate_memory_dir(memory_dir),
         {:ok, path} <- Paths.episode_path(memory_dir, id) do
      case File.read(path) do
        {:ok, content} ->
          Entry.parse(content)

        {:error, :enoent} ->
          {:error, :not_found}
      end
    end
  end

  @doc """
  Deletes an episodic memory entry by ID.

  Returns `:ok` or `{:error, :not_found}`.
  """
  @spec delete(String.t(), String.t()) :: :ok | {:error, :not_found}
  def delete(memory_dir, id) do
    with {:ok, _} <- Paths.validate_memory_dir(memory_dir),
         {:ok, path} <- Paths.episode_path(memory_dir, id) do
      case File.rm(path) do
        :ok -> :ok
        {:error, :enoent} -> {:error, :not_found}
      end
    end
  end

  @doc """
  Lists episodic memory entries with optional filters.

  Returns frontmatter maps only (no body content), sorted by timestamp
  descending (most recent first).

  ## Options

  - `:limit` — max results (default #{@default_list_limit})
  - `:type` — filter by episode type
  - `:outcome` — filter by outcome
  - `:tags` — filter by tags (intersection match — episode must have all listed tags)
  - `:after` — ISO 8601 datetime, include episodes at or after this time
  - `:before` — ISO 8601 datetime, include episodes before this time
  """
  @spec list(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list(memory_dir, opts \\ []) do
    with {:ok, _} <- Paths.validate_memory_dir(memory_dir) do
      limit = Keyword.get(opts, :limit, @default_list_limit)
      dir = Paths.episodic_dir(memory_dir)

      entries =
        dir
        |> list_episode_files()
        |> read_entries()
        |> apply_entry_filters(opts)
        |> Enum.map(fn {fm, _body} -> fm end)
        |> filter_by_date_range(Keyword.get(opts, :after), Keyword.get(opts, :before))
        |> sort_by_timestamp_desc()
        |> Enum.take(limit)

      {:ok, entries}
    end
  end

  @doc """
  Searches episodic memory entries by text query.

  Applies metadata filters first, then searches frontmatter fields and body
  content for case-insensitive substring match. When query is empty, behaves
  like `list/2`.

  ## Options

  - `:limit` — max results (default #{@default_search_limit})
  - `:type` — filter by episode type
  - `:outcome` — filter by outcome
  - `:tags` — filter by tags (intersection match)
  """
  @spec search(String.t(), String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def search(memory_dir, query, opts \\ []) do
    with {:ok, _} <- Paths.validate_memory_dir(memory_dir) do
      limit = Keyword.get(opts, :limit, @default_search_limit)

      if query == "" do
        list(memory_dir, Keyword.put(opts, :limit, limit))
      else
        dir = Paths.episodic_dir(memory_dir)
        downcased_query = String.downcase(query)

        results =
          dir
          |> list_episode_files()
          |> read_entries()
          |> apply_entry_filters(opts)
          |> Enum.filter(fn {frontmatter, body} ->
            text_matches?(frontmatter, body, downcased_query)
          end)
          |> Enum.map(fn {frontmatter, _body} -> frontmatter end)
          |> sort_by_timestamp_desc()
          |> Enum.take(limit)

        {:ok, results}
      end
    end
  end

  # --- Validation helpers ---

  defp validate_required(frontmatter) do
    Enum.reduce_while(~w(type summary outcome), :ok, fn field, :ok ->
      if Map.has_key?(frontmatter, field) do
        {:cont, :ok}
      else
        {:halt, {:error, {:missing_required, field}}}
      end
    end)
  end

  defp validate_type(%{"type" => type}) when type in @episode_types, do: :ok
  defp validate_type(%{"type" => type}), do: {:error, {:invalid_type, type}}

  defp validate_outcome(%{"outcome" => outcome}) when outcome in @outcome_types, do: :ok
  defp validate_outcome(%{"outcome" => outcome}), do: {:error, {:invalid_outcome, outcome}}

  defp validate_list_field(frontmatter, field) do
    case Map.get(frontmatter, field) do
      nil ->
        :ok

      list when is_list(list) ->
        cond do
          length(list) > @max_list_elements ->
            {:error, {:list_too_long, field}}

          not Enum.all?(list, &is_binary/1) ->
            {:error, {:invalid_list_element, field}}

          Enum.any?(list, &(String.length(&1) > @max_element_length)) ->
            {:error, {:element_too_long, field}}

          true ->
            :ok
        end

      _ ->
        {:error, {:invalid_list_field, field}}
    end
  end

  # --- Private helpers ---

  defp truncate_summary(%{"summary" => summary} = frontmatter)
       when is_binary(summary) and byte_size(summary) > 0 do
    if String.length(summary) > @max_summary_length do
      Map.put(frontmatter, "summary", String.slice(summary, 0, @max_summary_length))
    else
      frontmatter
    end
  end

  defp truncate_summary(frontmatter), do: frontmatter

  defp list_episode_files(dir) do
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

  defp read_entries(paths) do
    Enum.flat_map(paths, fn path ->
      case File.read(path) do
        {:ok, content} ->
          case Entry.parse(content) do
            {:ok, {frontmatter, body}} ->
              [{frontmatter, body}]

            _ ->
              Logger.warning("Skipping corrupted episode file: #{path}")
              []
          end

        _ ->
          []
      end
    end)
  end

  defp apply_entry_filters(entries, opts) do
    entries
    |> filter_entries_by(:type, Keyword.get(opts, :type))
    |> filter_entries_by(:outcome, Keyword.get(opts, :outcome))
    |> filter_entries_by_tags(Keyword.get(opts, :tags))
  end

  defp filter_entries_by(entries, _field, nil), do: entries

  defp filter_entries_by(entries, field, value) do
    key = Atom.to_string(field)
    Enum.filter(entries, fn {fm, _} -> fm[key] == value end)
  end

  defp filter_entries_by_tags(entries, nil), do: entries
  defp filter_entries_by_tags(entries, []), do: entries

  defp filter_entries_by_tags(entries, tags) do
    Enum.filter(entries, fn {fm, _} ->
      entry_tags = fm["tags"] || []
      Enum.all?(tags, &(&1 in entry_tags))
    end)
  end

  defp filter_by_date_range(entries, nil, nil), do: entries

  defp filter_by_date_range(entries, after_dt, before_dt) do
    parsed_after = parse_datetime(after_dt)
    parsed_before = parse_datetime(before_dt)

    Enum.filter(entries, fn entry ->
      case DateTime.from_iso8601(entry["timestamp"]) do
        {:ok, ts, _offset} ->
          after_ok = parsed_after == nil or DateTime.compare(ts, parsed_after) in [:gt, :eq]
          before_ok = parsed_before == nil or DateTime.compare(ts, parsed_before) == :lt
          after_ok and before_ok

        _ ->
          false
      end
    end)
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(dt_string) do
    case DateTime.from_iso8601(dt_string) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp sort_by_timestamp_desc(entries) do
    Enum.sort_by(entries, & &1["timestamp"], :desc)
  end

  defp text_matches?(frontmatter, body, downcased_query) do
    searchable =
      [
        frontmatter["summary"],
        frontmatter["type"],
        frontmatter["outcome"],
        body
        | frontmatter["tags"] || []
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> String.downcase()

    String.contains?(searchable, downcased_query)
  end
end
