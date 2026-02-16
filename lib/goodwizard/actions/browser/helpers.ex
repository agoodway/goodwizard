defmodule Goodwizard.Actions.Browser.Helpers do
  @moduledoc """
  Shared helpers for browser action wrappers.

  Provides serialized execution and string-to-atom parameter coercion
  used by all `Goodwizard.Actions.Browser.*` wrapper modules.
  """

  alias Goodwizard.Browser.Serializer

  @doc """
  Run an upstream browser action serialized through the Serializer GenServer.

  Applies optional parameter coercions before delegating to the upstream module.

  ## Options

    * `:coerce` — list of `{param_key, lookup_map}` tuples for string-to-atom coercion

  """
  @spec run_serialized(module(), map(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run_serialized(upstream_module, params, context, opts \\ []) do
    params = apply_coercions(params, Keyword.get(opts, :coerce, []))

    Serializer.execute(fn ->
      upstream_module.run(params, context)
    end)
  end

  @doc """
  Coerce a single parameter from string to atom using a lookup map.

  Returns params unchanged if the value is already an atom or not in the map.
  """
  @spec coerce_atom_param(map(), atom(), %{String.t() => atom()}) :: map()
  def coerce_atom_param(params, key, lookup_map) do
    case Map.get(params, key) do
      value when is_binary(value) ->
        case Map.get(lookup_map, String.downcase(value)) do
          nil -> params
          atom -> Map.put(params, key, atom)
        end

      _ ->
        params
    end
  end

  defp apply_coercions(params, coercions) do
    Enum.reduce(coercions, params, fn {key, lookup_map}, acc ->
      coerce_atom_param(acc, key, lookup_map)
    end)
  end
end
