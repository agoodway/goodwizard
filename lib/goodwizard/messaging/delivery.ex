defmodule Goodwizard.Messaging.Delivery do
  @moduledoc """
  Delivers messages to external channels bound to a Messaging room.

  Looks up room bindings and delivers via `JidoMessaging.Deliver.send_to_room/4`.
  Used by both the Send action and CronRunner.

  Supports two binding sources:
  - Formal `RoomBinding` structs (from `list_room_bindings`)
  - Room `external_bindings` map (set by `get_or_create_room_by_external_binding`)

  Falls back to `external_bindings` when no formal bindings exist, which is the
  common case for Telegram rooms created via the ingest pipeline.
  """

  require Logger

  alias Goodwizard.Messaging

  @default_channel_modules %{
    telegram: JidoMessaging.Channels.Telegram
  }

  @doc """
  Deliver content to all outbound-enabled bindings for a room.

  Returns a list of `{:ok, channel}` or `{:error, channel, reason}` tuples.
  """
  @spec deliver_to_bindings(String.t(), String.t()) :: [
          {:ok, atom()} | {:error, atom(), term()}
        ]
  def deliver_to_bindings(room_id, content) do
    case resolve_bindings(room_id) do
      [] ->
        Logger.debug("No outbound bindings for room #{room_id}")
        []

      bindings ->
        Enum.map(bindings, fn {channel, external_room_id} ->
          deliver_to_channel(channel, external_room_id, room_id, content)
        end)
    end
  end

  # Try formal RoomBinding structs first, fall back to room's external_bindings map.
  defp resolve_bindings(room_id) do
    case Messaging.list_room_bindings(room_id) do
      {:ok, bindings} when bindings != [] ->
        bindings
        |> Enum.filter(&outbound_enabled?/1)
        |> Enum.map(fn b -> {b.channel, b.external_room_id} end)

      _ ->
        bindings_from_room(room_id)
    end
  end

  # Extract binding targets from the room's external_bindings map.
  # Format: %{telegram: %{"instance_id" => "external_room_id"}}
  defp bindings_from_room(room_id) do
    case Messaging.get_room(room_id) do
      {:ok, room} -> flatten_external_bindings(room.external_bindings)
      {:error, _} -> []
    end
  end

  defp flatten_external_bindings(external_bindings) do
    Enum.flat_map(external_bindings, fn {channel, instances} ->
      Enum.map(instances, fn {_instance_id, external_room_id} ->
        {channel, to_string(external_room_id)}
      end)
    end)
  end

  defp outbound_enabled?(%{direction: direction, enabled: enabled}) do
    enabled and direction in [:both, :outbound]
  end

  defp deliver_to_channel(channel, external_room_id, room_id, content) do
    case Map.get(channel_modules(), channel) do
      nil ->
        Logger.debug("No channel module for #{channel}, skipping delivery")
        {:error, channel, :no_channel_module}

      channel_module ->
        channel_context = %{
          channel: channel_module,
          external_room_id: external_room_id
        }

        case JidoMessaging.Deliver.send_to_room(
               Messaging,
               room_id,
               content,
               channel_context
             ) do
          {:ok, _message} ->
            {:ok, channel}

          {:error, reason} ->
            Logger.warning(
              "Failed to deliver to #{channel}:#{external_room_id}: #{inspect(reason)}"
            )

            {:error, channel, reason}
        end
    end
  end

  defp channel_modules do
    Application.get_env(:goodwizard, :channel_modules, @default_channel_modules)
  end
end
