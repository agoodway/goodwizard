defmodule Mix.Tasks.Goodwizard.Status do
  @moduledoc """
  Shows Goodwizard system configuration and runtime state.

      $ mix goodwizard.status

  Displays:
  - Configuration source and key settings
  - Active Messaging rooms and message counts
  - Channel instance status
  - Memory stats (long-term memory size, session count)
  """
  use Mix.Task

  alias Goodwizard.Config
  alias Goodwizard.Messaging

  @shortdoc "Show Goodwizard config and system state"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    print_config()
    print_rooms()
    print_instances()
    print_memory_stats()
  end

  defp print_config do
    Mix.shell().info("=== Configuration ===")
    Mix.shell().info("  Model:     #{Config.model()}")
    Mix.shell().info("  Workspace: #{Config.workspace()}")

    cli_enabled = Config.get(["channels", "cli", "enabled"])
    telegram_enabled = Config.get(["channels", "telegram", "enabled"])
    heartbeat_enabled = Config.get(["heartbeat", "enabled"])

    Mix.shell().info("  Channels:  CLI=#{cli_enabled}, Telegram=#{telegram_enabled}")
    Mix.shell().info("  Heartbeat: #{if heartbeat_enabled, do: "enabled", else: "disabled"}")
    Mix.shell().info("")
  end

  defp print_rooms do
    Mix.shell().info("=== Messaging Rooms ===")

    case Messaging.list_rooms() do
      {:ok, []} ->
        Mix.shell().info("  No active rooms")

      {:ok, rooms} ->
        for room <- rooms do
          message_count =
            case Messaging.list_messages(room.id) do
              {:ok, messages} -> length(messages)
              _ -> 0
            end

          Mix.shell().info("  #{room.id} (#{room.name || "unnamed"}) — #{message_count} messages")
        end

      {:error, reason} ->
        Mix.shell().info("  Error listing rooms: #{inspect(reason)}")
    end

    Mix.shell().info("")
  end

  defp print_instances do
    Mix.shell().info("=== Channel Instances ===")

    case Messaging.list_instances() do
      [] ->
        Mix.shell().info("  No running instances")

      instances when is_list(instances) ->
        for instance <- instances do
          Mix.shell().info(
            "  #{instance.id} (#{instance.channel_type}) — #{instance.name || "unnamed"}"
          )
        end

      _ ->
        Mix.shell().info("  No running instances")
    end

    Mix.shell().info("")
  end

  defp print_memory_stats do
    Mix.shell().info("=== Memory Stats ===")

    workspace = Config.workspace()
    base_dir = workspace |> Path.dirname()
    memory_dir = Path.join(base_dir, "memory")
    sessions_dir = Path.join(base_dir, "sessions")

    # Long-term memory
    lt_path = Path.join(memory_dir, "long_term.md")

    lt_size =
      case File.stat(lt_path) do
        {:ok, %{size: size}} -> "#{size} bytes"
        _ -> "not found"
      end

    Mix.shell().info("  Long-term memory: #{lt_path} (#{lt_size})")

    # Session files
    session_count =
      case File.ls(sessions_dir) do
        {:ok, files} -> files |> Enum.filter(&String.ends_with?(&1, ".jsonl")) |> length()
        _ -> 0
      end

    Mix.shell().info("  Sessions: #{session_count} session files in #{sessions_dir}")
    Mix.shell().info("  Workspace: #{workspace}")
    Mix.shell().info("")
  end
end
