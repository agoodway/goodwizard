defmodule Goodwizard.Actions.Brain.Helpers do
  @moduledoc """
  Shared helpers for brain action modules.
  """

  require Logger

  @doc """
  Resolves the workspace path from action context, falling back to Config.

  Prefers `context.state.workspace` when available (e.g. set by the agent),
  otherwise reads the configured workspace via `Goodwizard.Config.workspace/0`.
  """
  @spec workspace(map()) :: String.t()
  def workspace(context) do
    get_in(context, [:state, :workspace]) || Goodwizard.Config.workspace()
  end

  # Channel instance IDs must match what each channel uses when creating rooms.
  # The Telegram handler macro defaults instance_id to to_string(__MODULE__).
  @telegram_instance_id to_string(Goodwizard.Channels.Telegram.Handler)
  @cli_instance_id "goodwizard"

  @known_channels ~w(cli telegram)

  @doc """
  Resolves the Messaging room ID for the current agent.

  Resolution order:
  1. `context.agent_id` — parse channel + external ID from the agent ID string
  2. `[scheduling]` config — read channel/chat_id from config (like heartbeat)

  Returns `{:ok, room_id}` or `{:error, reason}`.

  ## Config

  In `config.toml`:

      [scheduling]
      channel = "telegram"
      chat_id = "7041440974"

  """
  @spec resolve_room_id(map()) :: {:ok, String.t()} | {:error, String.t()}
  def resolve_room_id(context) do
    case resolve_room_from_agent_id(Map.get(context, :agent_id)) do
      {:ok, _} = ok -> ok
      {:error, _} -> resolve_room_from_config()
    end
  end

  defp resolve_room_from_agent_id("telegram:" <> chat_id),
    do: resolve_room(:telegram, @telegram_instance_id, chat_id)

  defp resolve_room_from_agent_id("cli:direct:" <> _),
    do: resolve_room(:cli, @cli_instance_id, "direct")

  defp resolve_room_from_agent_id("heartbeat:" <> _),
    do: resolve_room(:cli, @cli_instance_id, "heartbeat")

  defp resolve_room_from_agent_id(other),
    do: {:error, "Cannot resolve room_id from agent_id: #{inspect(other)}"}

  defp resolve_room_from_config do
    channel = Goodwizard.Config.get(["scheduling", "channel"])
    chat_id = Goodwizard.Config.get(["scheduling", "chat_id"])

    case {channel, chat_id} do
      {ch, id} when is_binary(ch) and is_binary(id) ->
        case resolve_channel_binding(ch, id) do
          {:ok, _} = ok -> ok
          {:error, _} = err -> err
        end

      _ ->
        {:error,
         "Cannot resolve room_id: agent_id not recognized and no [scheduling] config found. " <>
           "Set channel and chat_id under [scheduling] in config.toml."}
    end
  end

  defp resolve_channel_binding(channel_str, external_id) do
    if channel_str in @known_channels do
      {instance_id, channel_atom} =
        case channel_str do
          "telegram" -> {@telegram_instance_id, :telegram}
          "cli" -> {@cli_instance_id, :cli}
        end

      resolve_room(channel_atom, instance_id, external_id)
    else
      {:error, "Unknown scheduling channel #{inspect(channel_str)}"}
    end
  end

  defp resolve_room(channel, instance_id, external_id) do
    case Goodwizard.Messaging.get_or_create_room_by_external_binding(
           channel,
           instance_id,
           external_id,
           %{type: :direct, name: "Scheduled Task"}
         ) do
      {:ok, room} -> {:ok, room.id}
      {:error, reason} -> {:error, "Failed to resolve room: #{inspect(reason)}"}
    end
  end

  @doc """
  Strips internal-only fields (e.g. metadata) from entity data before returning to callers.
  """
  @spec sanitize_entity_data(map()) :: map()
  def sanitize_entity_data(data) when is_map(data), do: Map.drop(data, ["metadata"])

  @doc """
  Formats error reasons into safe, user-friendly messages.

  Returns specific messages for known error atoms and a generic
  fallback for unexpected errors to avoid leaking internal details.
  """
  @spec format_error(term()) :: String.t()
  def format_error(reason) when is_binary(reason), do: reason
  def format_error(:not_found), do: "Entity not found"
  def format_error(:path_traversal), do: "Invalid path"
  def format_error(:body_too_large), do: "Body exceeds maximum size"
  def format_error(:update_locked), do: "Entity is locked by another operation"
  def format_error(:enoent), do: "File not found"
  def format_error(:eacces), do: "Permission denied"
  def format_error({:duplicate_id, _id}), do: "Duplicate entity ID"
  def format_error({:parse_error, _file, _reason}), do: "Failed to parse entity file"
  def format_error({:schema_resolution_error, _msg}), do: "Schema resolution failed"

  def format_error({:validation, errors}) when is_list(errors),
    do: format_validation_errors(errors)

  def format_error(errors) when is_list(errors), do: format_validation_errors(errors)

  def format_error(reason) do
    Logger.warning("[Brain] Unhandled error reason: #{inspect(reason)}")
    "Unexpected error: #{inspect(reason)}"
  end

  defp format_validation_errors(errors) do
    details =
      errors
      |> Enum.map(fn
        {message, path} when is_binary(message) -> "#{path}: #{message}"
        other -> inspect(other)
      end)
      |> Enum.join("; ")

    "Validation failed: #{details}"
  end
end
