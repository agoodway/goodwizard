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

    config_path = Path.join(base, "config.toml")

    case File.open(config_path, [:write, :exclusive]) do
      {:ok, file} ->
        IO.write(file, @default_config)
        File.close(file)
        File.chmod(config_path, 0o600)
        Mix.shell().info("Created #{config_path}")

      {:error, :eexist} ->
        Mix.shell().info("Config already exists: #{config_path}")

      {:error, reason} ->
        Mix.shell().error(
          "Failed to create #{config_path}: #{:file.format_error(reason)}"
        )
    end
  end

  defp base_dir(["--base-dir", dir | _rest]), do: Path.expand(dir)
  defp base_dir(_args), do: Path.expand(@base_dir)
end
