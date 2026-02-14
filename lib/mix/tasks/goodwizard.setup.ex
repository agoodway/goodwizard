defmodule Mix.Tasks.Goodwizard.Setup do
  @moduledoc """
  Creates the Goodwizard workspace directory structure and default config.

      $ mix goodwizard.setup

  Creates:
    - ~/.goodwizard/workspace/
    - ~/.goodwizard/memory/
    - ~/.goodwizard/skills/
    - ~/.goodwizard/sessions/
    - ~/.goodwizard/config.toml (if missing)
  """
  use Mix.Task

  @shortdoc "Set up Goodwizard workspace directories and default config"

  @base_dir "~/.goodwizard"
  @subdirs ~w(workspace memory skills sessions)

  @default_config """
  # Goodwizard configuration

  [agent]
  workspace = "~/.goodwizard/workspace"
  model = "anthropic:claude-sonnet-4-5"
  max_tokens = 8192
  temperature = 0.7

  [channels.cli]
  enabled = true

  [channels.telegram]
  enabled = false

  [tools]
  restrict_to_workspace = true

  [tools.exec]
  timeout = 60
  """

  @impl Mix.Task
  def run(_args) do
    base = Path.expand(@base_dir)

    for subdir <- @subdirs do
      path = Path.join(base, subdir)

      case File.mkdir_p(path) do
        :ok ->
          Mix.shell().info("Created #{path}")

        {:error, reason} ->
          Mix.shell().error("Failed to create #{path}: #{:file.format_error(reason)}")
      end
    end

    config_path = Path.join(base, "config.toml")

    if File.exists?(config_path) do
      Mix.shell().info("Config already exists: #{config_path}")
    else
      case File.write(config_path, @default_config) do
        :ok ->
          Mix.shell().info("Created #{config_path}")

        {:error, reason} ->
          Mix.shell().error(
            "Failed to create #{config_path}: #{:file.format_error(reason)}"
          )
      end
    end
  end
end
