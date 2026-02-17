defmodule Goodwizard.Brain.SchemaMapper do
  @moduledoc """
  Converts JSON Schema property definitions to NimbleOptions keyword lists
  for `use Jido.Action, schema: [...]`.

  Used by `ToolGenerator` to build typed create/update actions from brain
  entity schemas at runtime.
  """

  @system_fields ~w(id created_at updated_at)
  @valid_property_name ~r/^[a-z][a-z0-9_]{0,63}$/

  @doc """
  Builds a Jido Action schema for a create action.

  Excludes system fields, marks schema-required fields as required,
  and appends an optional `body` field.
  """
  @spec for_create(map()) :: {:ok, keyword()} | {:error, String.t()}
  def for_create(schema_map) do
    properties = Map.get(schema_map, "properties", %{})
    required = MapSet.new(Map.get(schema_map, "required", []))

    with {:ok, fields} <- validate_and_map_properties(properties, @system_fields) do
      schema =
        fields
        |> Enum.sort_by(fn {name, _} -> name end)
        |> Enum.map(fn {atom_name, {str_name, prop}} ->
          opts = map_property(prop)

          opts =
            if MapSet.member?(required, str_name) and str_name not in @system_fields do
              Keyword.put(opts, :required, true)
            else
              opts
            end

          {atom_name, opts}
        end)
        |> Kernel.++([
          {:body, [type: :string, default: "", doc: "Optional markdown body content"]}
        ])

      {:ok, schema}
    end
  end

  @doc """
  Builds a Jido Action schema for an update action.

  Prepends a required `id` field, includes all entity fields as optional
  (excluding system fields), and appends an optional `body` field.
  """
  @spec for_update(map()) :: {:ok, keyword()} | {:error, String.t()}
  def for_update(schema_map) do
    properties = Map.get(schema_map, "properties", %{})

    with {:ok, fields} <- validate_and_map_properties(properties, @system_fields) do
      entity_fields =
        fields
        |> Enum.sort_by(fn {name, _} -> name end)
        |> Enum.map(fn {atom_name, {_str_name, prop}} ->
          {atom_name, map_property(prop)}
        end)

      schema =
        [{:id, [type: :string, required: true, doc: "The entity ID to update"]} | entity_fields]
        |> Kernel.++([
          {:body,
           [type: :string, doc: "Optional new markdown body content (nil preserves existing)"]}
        ])

      {:ok, schema}
    end
  end

  defp validate_and_map_properties(properties, system_fields) do
    result =
      properties
      |> Enum.reject(fn {name, _} -> name in system_fields end)
      |> Enum.reduce_while([], fn {name, prop}, acc ->
        if Regex.match?(@valid_property_name, name) do
          {:cont, [{String.to_atom(name), {name, prop}} | acc]}
        else
          {:halt,
           {:error,
            "Invalid property name: #{inspect(name)}. Names must match [a-z][a-z0-9_]* and be at most 64 characters."}}
        end
      end)

    case result do
      {:error, _} = err -> err
      fields -> {:ok, fields}
    end
  end

  @doc false
  @spec map_property(map()) :: keyword()
  def map_property(prop) do
    base_type = map_type(prop)
    doc = build_doc(prop)

    opts = [type: base_type]
    if doc, do: Keyword.put(opts, :doc, doc), else: opts
  end

  defp map_type(%{"type" => "string"}), do: :string
  defp map_type(%{"type" => "number"}), do: :float
  defp map_type(%{"type" => "integer"}), do: :integer
  defp map_type(%{"type" => "boolean"}), do: :boolean
  defp map_type(%{"type" => "object"}), do: :map

  defp map_type(%{"type" => "array", "items" => %{"type" => "object"}}) do
    {:list, :map}
  end

  defp map_type(%{"type" => "array", "items" => %{"type" => "string"}}) do
    {:list, :string}
  end

  defp map_type(%{"type" => "array", "items" => %{"pattern" => _}}) do
    {:list, :string}
  end

  defp map_type(%{"type" => "array"}) do
    {:list, :any}
  end

  defp map_type(_), do: :string

  defp build_doc(%{"type" => "string", "enum" => values}) when is_list(values) do
    "One of: #{Enum.join(values, ", ")}"
  end

  defp build_doc(%{"type" => "string", "format" => "email"}), do: "Email address"
  defp build_doc(%{"type" => "string", "format" => "date-time"}), do: "ISO 8601 datetime"

  defp build_doc(%{"type" => "string", "pattern" => pattern}) do
    case Regex.run(~r/^\^(\w+)\//, pattern) do
      [_, ref_type] -> "Reference to a #{singularize(ref_type)} (format: #{ref_type}/<id>)"
      _ -> nil
    end
  end

  defp build_doc(%{"type" => "array", "items" => %{"pattern" => pattern}} = prop) do
    case Regex.run(~r/^\^(\w+)\//, pattern) do
      [_, ref_type] ->
        "List of #{singularize(ref_type)} references (format: #{ref_type}/<id>)"

      _ ->
        Map.get(prop, "description")
    end
  end

  defp build_doc(%{"type" => "array", "items" => %{"type" => "object"}} = prop) do
    Map.get(prop, "description")
  end

  defp build_doc(%{"description" => desc}) when is_binary(desc), do: desc
  defp build_doc(_), do: nil

  @irregular_singular %{
    "people" => "person",
    "companies" => "company",
    "categories" => "category",
    "entries" => "entry",
    "stories" => "story",
    "activities" => "activity",
    "histories" => "history",
    "addresses" => "address"
  }

  @doc """
  Singularizes a plural entity type name.

  Uses a lookup map for irregular forms, falls back to trimming trailing "s".
  """
  @spec singularize(String.t()) :: String.t()
  def singularize(plural) do
    case Map.get(@irregular_singular, plural) do
      nil ->
        cond do
          String.ends_with?(plural, "ies") ->
            String.replace_suffix(plural, "ies", "y")

          String.ends_with?(plural, "ses") ->
            String.replace_suffix(plural, "ses", "s")

          String.ends_with?(plural, "s") ->
            String.replace_suffix(plural, "s", "")

          true ->
            plural
        end

      singular ->
        singular
    end
  end
end
