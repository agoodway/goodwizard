defmodule Goodwizard.Actions.Memory.Helpers do
  @moduledoc """
  Shared helpers for memory action modules.
  """

  @doc """
  Resolves the memory directory from action context, falling back to Config.
  """
  @spec memory_dir(map()) :: String.t()
  def memory_dir(context) do
    get_in(context, [:state, :memory, :memory_dir]) || Goodwizard.Config.memory_dir()
  end

  @doc """
  Escapes text for XML-ish prompt wrappers.
  """
  @spec xml_escape(String.t()) :: String.t()
  def xml_escape(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
