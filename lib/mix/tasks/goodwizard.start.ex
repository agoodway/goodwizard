defmodule Mix.Tasks.Goodwizard.Start do
  @moduledoc """
  Starts the full Goodwizard application with all enabled channels.

      $ mix goodwizard.start

  Starts the application (Config, Jido, Messaging, and any enabled channels
  like CLI and Telegram), then blocks until the process is terminated via
  SIGTERM or Ctrl+C.

  Channel auto-detection is config-driven via `config.toml` — no flags needed.
  """
  use Mix.Task

  @shortdoc "Start Goodwizard with all enabled channels"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Mix.shell().info("Goodwizard started. Press Ctrl+C to stop.")

    # Block until terminated
    Process.sleep(:infinity)
  end
end
