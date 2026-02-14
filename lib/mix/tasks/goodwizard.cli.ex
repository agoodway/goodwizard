defmodule Mix.Tasks.Goodwizard.Cli do
  @moduledoc """
  Starts the Goodwizard CLI REPL.

      $ mix goodwizard.cli

  Starts the application, launches the CLI Server, and keeps
  the process alive until the channel terminates (e.g., EOF).
  """
  use Mix.Task

  alias Goodwizard.Channels.CLI

  @shortdoc "Start Goodwizard CLI REPL"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    {:ok, pid} = CLI.Server.start_link()
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    end
  end
end
