defmodule Goodwizard.Plugins.Session do
  @moduledoc """
  Plugin that manages conversation session state for the agent.

  Stores messages with role, content, and timestamp. Provides helpers
  to add messages, retrieve history with optional limits, and clear.
  """

  @max_messages 200
  @valid_roles ~w(user assistant system tool)

  use Jido.Plugin,
    name: "session",
    description: "Manages conversation session state",
    state_key: :session,
    actions: [],
    schema:
      Zoi.object(%{
        messages:
          Zoi.list(
            Zoi.object(%{
              role: Zoi.string(),
              content: Zoi.string(),
              timestamp: Zoi.string()
            })
          )
          |> Zoi.default([]),
        created_at: Zoi.string() |> Zoi.optional(),
        metadata: Zoi.map() |> Zoi.default(%{})
      })

  require Logger

  @impl Jido.Plugin
  def mount(agent, _config) do
    session_key = get_in_state(agent, :session_key)
    workspace = get_in_state(agent, :workspace)

    case load_existing_session(workspace, session_key) do
      {:ok, loaded} ->
        {:ok, loaded}

      :skip ->
        {:ok, %{created_at: DateTime.utc_now() |> DateTime.to_iso8601()}}
    end
  end

  defp get_in_state(%{state: state}, key) when is_map(state), do: Map.get(state, key)
  defp get_in_state(_, _), do: nil

  defp load_existing_session(nil, _session_key), do: :skip
  defp load_existing_session(_workspace, nil), do: :skip

  defp load_existing_session(workspace, session_key) do
    sessions_dir = Path.join(Path.expand(workspace), "sessions")

    case load_session(sessions_dir, session_key) do
      {:ok, %{messages: messages, created_at: created_at, metadata: metadata}} ->
        Logger.info("Loaded existing session: #{session_key} (#{length(messages)} messages)")
        {:ok, %{messages: messages, created_at: created_at, metadata: metadata}}

      {:error, _} ->
        :skip
    end
  end

  @doc """
  Append a message to the session's messages list.

  Returns updated agent state with the new message appended.
  """
  @spec add_message(map(), String.t(), String.t(), String.t()) :: map()
  def add_message(state, role, content, timestamp) when role in @valid_roles do
    Logger.debug(fn ->
      "[Session] add_message role=#{role} content_length=#{String.length(content)}"
    end)

    message = %{role: role, content: content, timestamp: timestamp}
    session = Map.get(state, :session, %{messages: []})
    messages = Map.get(session, :messages, [])

    messages =
      (messages ++ [message])
      |> Enum.take(-@max_messages)

    updated_session = Map.put(session, :messages, messages)
    Map.put(state, :session, updated_session)
  end

  @doc """
  Return the session's messages list, optionally limited to the most recent N.

  ## Options

    * `:limit` - Return only the N most recent messages
  """
  @spec get_history(map(), keyword()) :: [map()]
  def get_history(state, opts \\ []) do
    messages =
      state
      |> Map.get(:session, %{messages: []})
      |> Map.get(:messages, [])

    case Keyword.get(opts, :limit) do
      nil -> messages
      n when is_integer(n) and n > 0 -> Enum.take(messages, -n)
      _invalid -> messages
    end
  end

  @doc """
  Clear the session's messages list while preserving created_at and metadata.
  """
  @spec clear(map()) :: map()
  def clear(state) do
    session = Map.get(state, :session, %{})
    updated_session = Map.put(session, :messages, [])
    Map.put(state, :session, updated_session)
  end

  @doc """
  Clean up old CLI session files beyond the configured retention limit.

  Lists all `cli-direct-*.jsonl` files in the sessions directory, sorts by
  modification time (newest first), and deletes files beyond the limit.
  Non-CLI session files are never touched. Deletion errors are logged as
  warnings and do not prevent the function from continuing.
  """
  @spec cleanup_old_sessions() :: :ok
  def cleanup_old_sessions do
    sessions_dir = Goodwizard.Config.sessions_dir()
    max = Goodwizard.Config.get(["session", "max_cli_sessions"]) || 50

    cli_pattern = Path.join(sessions_dir, "cli-direct-*.jsonl")

    files =
      Path.wildcard(cli_pattern)
      |> Enum.map(fn path ->
        case File.stat(path) do
          {:ok, %{mtime: mtime}} -> {path, mtime}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(fn {_path, mtime} -> mtime end, :desc)

    excess = Enum.drop(files, max)

    Enum.each(excess, fn {path, _mtime} ->
      case File.rm(path) do
        :ok ->
          Logger.debug("Cleaned up old session: #{Path.basename(path)}")

        {:error, reason} ->
          Logger.warning("Failed to delete session file #{path}: #{inspect(reason)}")
      end
    end)

    :ok
  end

  @doc """
  Save session state to a JSONL file.

  First line is metadata (key, created_at, version), subsequent lines are messages.
  Session key is sanitized to alphanumeric plus dash/underscore for the filename.
  Creates the sessions directory if it doesn't exist.
  Sets file permissions to 0600 (owner read/write only).
  """
  @spec save_session(String.t(), String.t(), map()) :: :ok | {:error, term()}
  def save_session(sessions_dir, session_key, session_state) do
    with {:ok, filename} <- safe_filename(sessions_dir, session_key),
         :ok <- File.mkdir_p(sessions_dir) do
      path = Path.join(sessions_dir, filename)

      session = Map.get(session_state, :session, %{})
      messages = Map.get(session, :messages, [])
      created_at = Map.get(session, :created_at, "")
      metadata = Map.get(session, :metadata, %{})

      metadata_line =
        Jason.encode!(%{
          key: session_key,
          created_at: created_at,
          version: 1,
          metadata: metadata
        })

      message_lines =
        Enum.map(messages, fn msg ->
          Jason.encode!(%{
            role: Map.get(msg, :role),
            content: Map.get(msg, :content),
            timestamp: Map.get(msg, :timestamp)
          })
        end)

      content = Enum.join([metadata_line | message_lines], "\n") <> "\n"

      case File.write(path, content) do
        :ok ->
          File.chmod(path, 0o600)
          Logger.debug("Session saved: #{session_key} (#{length(messages)} messages)")
          :ok

        error ->
          Logger.error("Failed to write session file #{path}: #{inspect(error)}")
          error
      end
    end
  end

  @doc """
  Load session state from a JSONL file.

  Returns `{:ok, session_state}` with messages, created_at, and metadata,
  or `{:error, :not_found}` if the file doesn't exist or is unreadable.
  Handles corrupted/malformed JSON gracefully.
  """
  @spec load_session(String.t(), String.t()) ::
          {:ok, %{messages: [map()], created_at: String.t(), metadata: map()}}
          | {:error, :not_found | :corrupted}
  def load_session(sessions_dir, session_key) do
    with {:ok, filename} <- safe_filename(sessions_dir, session_key) do
      path = Path.join(sessions_dir, filename)

      case File.read(path) do
        {:ok, content} ->
          parse_session_file(content)

        {:error, _reason} ->
          {:error, :not_found}
      end
    end
  end

  defp parse_session_file(content) do
    lines = String.split(content, "\n", trim: true)

    case lines do
      [metadata_line | message_lines] ->
        with {:ok, metadata_json} <- Jason.decode(metadata_line) do
          messages = decode_message_lines(message_lines)

          {:ok,
           %{
             messages: messages,
             created_at: Map.get(metadata_json, "created_at", ""),
             metadata: Map.get(metadata_json, "metadata", %{})
           }}
        else
          {:error, _} -> {:error, :corrupted}
        end

      [] ->
        {:error, :not_found}
    end
  end

  defp decode_message_lines(lines) do
    lines
    |> Enum.reduce([], fn line, acc ->
      case Jason.decode(line) do
        {:ok, decoded} ->
          [
            %{
              role: Map.get(decoded, "role"),
              content: Map.get(decoded, "content"),
              timestamp: Map.get(decoded, "timestamp")
            }
            | acc
          ]

        {:error, _} ->
          Logger.warning("Skipping corrupted message line in session file")
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp sanitize_key(key) do
    key
    |> String.replace(~r/[^a-zA-Z0-9_\-]/, "_")
    |> String.trim_leading(".")
  end

  defp safe_filename(sessions_dir, session_key) do
    sanitized = sanitize_key(session_key)

    if sanitized == "" do
      {:error, "Invalid session key"}
    else
      filename = sanitized <> ".jsonl"
      full_path = Path.expand(Path.join(sessions_dir, filename))
      expanded_dir = Path.expand(sessions_dir)

      if String.starts_with?(full_path, expanded_dir <> "/") do
        {:ok, filename}
      else
        {:error, "Session key resolves outside sessions directory"}
      end
    end
  end
end
