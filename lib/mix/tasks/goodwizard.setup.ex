defmodule Mix.Tasks.Goodwizard.Setup do
  @moduledoc """
  Creates the Goodwizard workspace directory structure and default config.

      $ mix goodwizard.setup

  Creates:
    - priv/workspace/memory/
    - priv/workspace/sessions/
    - priv/workspace/skills/
    - priv/workspace/brain/schemas/ (with default schemas)
    - priv/workspace/brain/<type>/ for each entity type
    - priv/workspace/IDENTITY.md (agent identity, if missing)
    - priv/workspace/SOUL.md (personality and values, if missing)
    - priv/workspace/USER.md (user profile, if missing)
    - priv/workspace/TOOLS.md (tool usage guidance, if missing)
    - priv/workspace/AGENTS.md (sub-agent configuration, if missing)
    - priv/workspace/HEARTBEAT.md (periodic awareness checks, if missing)
    - config.toml (project root, if missing)
  """
  use Mix.Task

  alias Goodwizard.Brain

  @shortdoc "Set up Goodwizard workspace directories and default config"

  @base_dir "priv/workspace"
  @subdirs ~w(memory sessions skills)

  @default_config """
  # Goodwizard configuration

  [agent]
  workspace = "priv/workspace"
  model = "anthropic:claude-sonnet-4-5"
  max_tokens = 8192
  temperature = 0.7

  [channels.cli]
  enabled = true

  [channels.telegram]
  enabled = false

  [scheduling]
  # Default delivery channel for cron/oneshot tasks.
  # Set these so scheduled tasks know where to send results.
  # channel = "telegram"
  # chat_id = "your_chat_id"

  [tools]
  restrict_to_workspace = true

  [tools.exec]
  timeout = 60
  """

  @impl Mix.Task
  def run(args) do
    base = base_dir(args)

    # Ensure base directory exists with restricted permissions
    File.mkdir_p(base)
    File.chmod(base, 0o700)

    errors =
      for subdir <- @subdirs, reduce: [] do
        acc ->
          path = Path.join(base, subdir)

          case File.mkdir_p(path) do
            :ok ->
              File.chmod(path, 0o700)
              Mix.shell().info("Created #{path}")
              acc

            {:error, reason} ->
              msg = "Failed to create #{path}: #{:file.format_error(reason)}"
              Mix.shell().error(msg)
              [msg | acc]
          end
      end

    if errors != [] do
      Mix.raise("Setup failed: could not create required directories")
    end

    setup_brain(base)
    setup_bootstrap_files(base)
    setup_config()
  end

  defp setup_brain(base) do
    Mix.shell().info("Initializing brain...")
    init_brain(base)
    create_entity_type_dirs(base)
  end

  defp init_brain(base) do
    case Brain.ensure_initialized(base) do
      {:ok, []} ->
        Mix.shell().info("Brain already initialized")

      {:ok, seeded} ->
        Mix.shell().info("Seeded schemas: #{Enum.join(seeded, ", ")}")

      {:error, reason} ->
        Mix.shell().error("Failed to initialize brain: #{inspect(reason)}")
        Mix.raise("Setup failed: could not initialize brain")
    end
  end

  defp create_entity_type_dirs(base) do
    dir_errors =
      for type <- Brain.Seeds.entity_types(), reduce: [] do
        acc -> create_entity_type_dir(base, type, acc)
      end

    if dir_errors != [] do
      Mix.raise("Setup failed: could not create entity type directories")
    end
  end

  defp create_entity_type_dir(base, type, acc) do
    with {:ok, dir} <- Brain.Paths.entity_type_dir(base, type),
         :ok <- File.mkdir_p(dir) do
      Mix.shell().info("Created #{dir}")
      acc
    else
      {:error, reason} ->
        msg = "Failed to create entity type dir for #{type}: #{inspect(reason)}"
        Mix.shell().error(msg)
        [msg | acc]
    end
  end

  @default_identity_md """
  # Identity

  You are **Goodwizard**, a personal AI assistant.

  Your role is to help the user manage their work, stay organized, and make
  informed decisions. You operate through conversation (CLI or Telegram) and
  have access to a persistent workspace with memory, a knowledge brain, and
  scheduled tasks.
  """

  @default_soul_md """
  # Soul

  ## Personality

  - Analytical — you reason through problems before acting
  - Patient — you never rush the user or skip steps
  - Thorough — you read before editing, verify before committing

  ## Values

  - **Accuracy** over speed — get it right
  - **Helpfulness** — proactively surface relevant information
  - **Safety** — never bypass guards, never delete without confirmation

  ## Communication Style

  - Concise and technical by default
  - Adapt tone to the channel (brief on Telegram, detailed on CLI)
  - Explain your reasoning before taking actions
  - When uncertain, ask for clarification rather than guessing
  """

  @default_user_md """
  # User Profile

  <!-- Edit this file to tell your agent about yourself. -->
  <!-- The agent reads this on every turn to personalize responses. -->

  ## About

  - Name:
  - Role:
  - Timezone:

  ## Preferences

  - Communication style:
  - Favorite tools:
  - Things to always remember:
  """

  @default_agents_md """
  # Sub-Agents

  <!-- Configure sub-agent behavior here. -->
  <!-- Sub-agents are spawned for isolated tasks like cron jobs or delegated work. -->

  ## Defaults

  - Model: inherit from main agent
  - Timeout: 120 seconds
  - Max concurrent: 5
  """

  @default_heartbeat_md """
  - [ ] Check if there are any upcoming events or deadlines today
  """

  @default_tools_md """
  # Tools Guide

  ## Scheduling & Monitoring

  You have two scheduling systems. Choose based on the task's needs:

  ### When to use heartbeat

  - **Multiple periodic checks**: Instead of 5 separate cron jobs checking inbox, calendar, weather, notifications, and project status, a single heartbeat can batch all of these.
  - **Context-aware decisions**: You have full main-session context, so you can make smart decisions about what's urgent vs. what can wait.
  - **Conversational continuity**: Heartbeat runs share the same session, so you remember recent conversations and can follow up naturally.
  - **Low-overhead monitoring**: One heartbeat replaces many small polling tasks.

  ### Heartbeat advantages

  - **Batches multiple checks**: One agent turn can review inbox, calendar, and notifications together.
  - **Reduces API calls**: A single heartbeat is cheaper than 5 isolated cron jobs.
  - **Context-aware**: You know what the user has been working on and can prioritize accordingly.
  - **Smart suppression**: If nothing needs attention, reply `HEARTBEAT_OK` and no message is delivered.
  - **Natural timing**: Drifts slightly based on queue load, which is fine for most monitoring.

  ### When to use cron

  - **Exact timing required**: "Send this at 9:00 AM every Monday" (not "sometime around 9").
  - **Standalone tasks**: Tasks that don't need conversational context.
  - **Different model/thinking**: Heavy analysis that warrants a more powerful model.
  - **One-shot reminders**: "Remind me in 20 minutes" with `--at`.
  - **Noisy/frequent tasks**: Tasks that would clutter main session history.
  - **External triggers**: Tasks that should run independently of whether you are otherwise active.

  ### Cron advantages

  - **Exact timing**: 5-field cron expressions with timezone support.
  - **Session isolation**: Runs in isolated mode without polluting main history.
  - **Model overrides**: Use a cheaper or more powerful model per job.
  - **Delivery control**: Isolated jobs default to `announce` (summary); choose `none` as needed.
  - **Immediate delivery**: Announce mode posts directly without waiting for heartbeat.
  - **No agent context needed**: Runs even if main session is idle or compacted.
  - **One-shot support**: `schedule_oneshot_task` for precise future timestamps or delays.
  """

  @bootstrap_files [
    {"IDENTITY.md", @default_identity_md},
    {"SOUL.md", @default_soul_md},
    {"USER.md", @default_user_md},
    {"TOOLS.md", @default_tools_md},
    {"AGENTS.md", @default_agents_md},
    {"HEARTBEAT.md", @default_heartbeat_md}
  ]

  defp setup_bootstrap_files(base) do
    Enum.each(@bootstrap_files, fn {filename, content} ->
      seed_file(base, filename, content)
    end)
  end

  defp seed_file(base, filename, content) do
    path = Path.join(base, filename)

    case File.open(path, [:write, :exclusive, :utf8]) do
      {:ok, file} ->
        IO.write(file, content)
        File.close(file)
        Mix.shell().info("Created #{path}")

      {:error, :eexist} ->
        Mix.shell().info("Already exists: #{path}")

      {:error, reason} ->
        Mix.shell().error("Failed to create #{path}: #{:file.format_error(reason)}")
    end
  end

  defp setup_config do
    config_path = "config.toml"

    case File.open(config_path, [:write, :exclusive, :utf8]) do
      {:ok, file} ->
        IO.write(file, @default_config)
        File.close(file)
        File.chmod(config_path, 0o600)
        Mix.shell().info("Created #{config_path}")

      {:error, :eexist} ->
        Mix.shell().info("Config already exists: #{config_path}")

      {:error, reason} ->
        Mix.shell().error("Failed to create #{config_path}: #{:file.format_error(reason)}")
    end
  end

  defp base_dir(["--base-dir", dir | _rest]), do: Path.expand(dir)
  defp base_dir(_args), do: Path.expand(@base_dir)
end
