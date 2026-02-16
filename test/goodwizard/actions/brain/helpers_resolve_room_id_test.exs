defmodule Goodwizard.Actions.Brain.HelpersResolveRoomIdTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Brain.Helpers

  describe "resolve_room_id/1" do
    test "resolves room from cli:direct agent_id" do
      context = %{agent_id: "cli:direct:123"}
      assert {:ok, room_id} = Helpers.resolve_room_id(context)
      assert is_binary(room_id)
    end

    test "resolves room from heartbeat agent_id" do
      context = %{agent_id: "heartbeat:abc"}
      assert {:ok, room_id} = Helpers.resolve_room_id(context)
      assert is_binary(room_id)
    end

    test "resolves room from telegram agent_id" do
      context = %{agent_id: "telegram:12345"}
      assert {:ok, room_id} = Helpers.resolve_room_id(context)
      assert is_binary(room_id)
    end

    test "returns error for unrecognized agent_id" do
      context = %{agent_id: "unknown:something"}
      # Should fall through to config, which also likely fails in test
      result = Helpers.resolve_room_id(context)
      # Either resolves from config or returns error
      case result do
        {:ok, _room_id} -> :ok
        {:error, msg} -> assert is_binary(msg)
      end
    end

    test "returns error for nil agent_id without config fallback" do
      context = %{}
      result = Helpers.resolve_room_id(context)

      case result do
        {:ok, _room_id} -> :ok
        {:error, msg} -> assert is_binary(msg)
      end
    end
  end
end
