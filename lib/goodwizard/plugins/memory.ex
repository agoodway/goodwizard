defmodule Goodwizard.Plugins.Memory do
  @moduledoc """
  Plugin that manages long-term memory state for the agent.

  Loads MEMORY.md from the workspace on mount and tracks the memory
  directory path. Memory actions read/write through this plugin's state.
  """

  use Jido.Plugin,
    name: "memory",
    description: "Manages long-term memory state",
    state_key: :memory,
    actions: [],
    schema:
      Zoi.object(%{
        memory_dir: Zoi.string(),
        long_term_content: Zoi.string() |> Zoi.default("")
      })

  require Logger

  @impl Jido.Plugin
  def mount(_agent, config) do
    memory_dir = Map.get(config, :memory_dir)

    resolved_dir = resolve_memory_dir(memory_dir)
    content = load_memory_md(resolved_dir)
    Logger.debug("Memory plugin mounted, dir=#{resolved_dir}, content_size=#{byte_size(content)}")
    {:ok, %{memory_dir: resolved_dir, long_term_content: content}}
  end

  defp resolve_memory_dir(nil), do: Goodwizard.Config.memory_dir()
  defp resolve_memory_dir(""), do: Goodwizard.Config.memory_dir()
  defp resolve_memory_dir(dir) when is_binary(dir), do: Path.expand(dir)

  defp load_memory_md(memory_dir) do
    path = Path.join(memory_dir, "MEMORY.md")

    case File.read(path) do
      {:ok, content} -> content
      {:error, _} -> ""
    end
  end
end
