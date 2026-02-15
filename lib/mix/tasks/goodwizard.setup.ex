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
    - config.toml (project root, if missing)
  """
  use Mix.Task

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
    setup_config()
  end

  defp setup_brain(base) do
    Mix.shell().info("Initializing brain...")

    case Goodwizard.Brain.ensure_initialized(base) do
      {:ok, []} ->
        Mix.shell().info("Brain already initialized")

      {:ok, seeded} ->
        Mix.shell().info("Seeded schemas: #{Enum.join(seeded, ", ")}")

      {:error, reason} ->
        Mix.shell().error("Failed to initialize brain: #{inspect(reason)}")
        Mix.raise("Setup failed: could not initialize brain")
    end

    # Create entity type directories so they're ready for use
    for type <- Goodwizard.Brain.Seeds.entity_types() do
      case Goodwizard.Brain.Paths.entity_type_dir(base, type) do
        {:ok, dir} ->
          case File.mkdir_p(dir) do
            :ok -> Mix.shell().info("Created #{dir}")
            {:error, reason} -> Mix.shell().error("Failed to create #{dir}: #{inspect(reason)}")
          end

        {:error, reason} ->
          Mix.shell().error("Invalid entity type #{type}: #{reason}")
      end
    end
  end

  defp setup_config do
    config_path = "config.toml"

    case File.open(config_path, [:write, :exclusive]) do
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
