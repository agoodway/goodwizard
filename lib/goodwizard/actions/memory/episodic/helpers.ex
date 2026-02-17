defmodule Goodwizard.Actions.Memory.Episodic.Helpers do
  @moduledoc """
  Shared helpers for episodic memory action modules.
  """

  @doc """
  Resolves the memory directory from action context, falling back to Config.

  Prefers `context.state.memory.memory_dir` when available (e.g. set by the
  Memory plugin), otherwise reads from `Goodwizard.Config.memory_dir/0`.
  """
  @spec memory_dir(map()) :: String.t()
  def memory_dir(context) do
    get_in(context, [:state, :memory, :memory_dir]) || Goodwizard.Config.memory_dir()
  end
end
