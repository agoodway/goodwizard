defmodule Goodwizard.Actions.Skills.CreateSkill do
  @moduledoc """
  Creates a new prompt skill in the workspace skills directory.

  Writes a SKILL.md file with YAML frontmatter to `<workspace>/skills/<name>/SKILL.md`.
  Validates the skill name, generates frontmatter from structured params,
  and prevents overwriting existing skills.
  """

  use Jido.Action,
    name: "create_skill",
    description:
      "Create a new prompt skill in the workspace. " <>
        "Writes a SKILL.md file with frontmatter to the correct skills directory. " <>
        "Use this instead of write_file when creating skills.",
    schema: [
      name: [
        type: :string,
        required: true,
        doc: "Kebab-case skill name (becomes directory name)"
      ],
      description: [
        type: :string,
        required: true,
        doc: "One-line description for skill summary"
      ],
      content: [
        type: :string,
        required: true,
        doc: "The SKILL.md body (instructions)"
      ],
      metadata: [
        type: :map,
        required: false,
        doc: "Extra frontmatter fields (author, version, license, etc.)"
      ]
    ]

  @name_pattern ~r/^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/
  @max_name_length 64
  @dangerous_patterns ["..", "/", "\\", "\0"]

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    with {:ok, name} <- validate_name(params.name),
         {:ok, workspace} <- resolve_workspace(context),
         skill_dir = Path.join([workspace, "skills", name]),
         skill_path = Path.join(skill_dir, "SKILL.md"),
         :ok <- check_not_exists(skill_path, name),
         content = build_skill_content(name, params.description, params.content, params[:metadata]),
         :ok <- write_skill(skill_dir, skill_path, content) do
      {:ok, %{path: skill_path, name: name}}
    end
  end

  defp validate_name(name) do
    cond do
      Enum.any?(@dangerous_patterns, &String.contains?(name, &1)) ->
        {:error, "invalid skill name: #{name} (contains dangerous characters)"}

      String.length(name) > @max_name_length ->
        {:error, "invalid skill name: #{name} (must be at most #{@max_name_length} characters)"}

      not Regex.match?(@name_pattern, name) ->
        {:error, "invalid skill name: #{name} (must be kebab-case: lowercase alphanumeric and hyphens, no leading/trailing/consecutive hyphens)"}

      true ->
        {:ok, name}
    end
  end

  defp resolve_workspace(context) do
    case get_in(context, [:state, :workspace]) do
      nil -> {:error, "workspace not found in context"}
      workspace -> {:ok, workspace}
    end
  end

  defp check_not_exists(skill_path, name) do
    if File.exists?(skill_path) do
      {:error, "skill already exists: #{name}"}
    else
      :ok
    end
  end

  defp build_skill_content(name, description, body, metadata) do
    frontmatter =
      ["---", "name: #{name}", "description: #{description}"]
      |> maybe_add_metadata(metadata)
      |> Kernel.++(["---"])
      |> Enum.join("\n")

    frontmatter <> "\n" <> body
  end

  defp maybe_add_metadata(lines, nil), do: lines
  defp maybe_add_metadata(lines, metadata) when map_size(metadata) == 0, do: lines

  defp maybe_add_metadata(lines, metadata) do
    meta_lines =
      metadata
      |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
      |> Enum.map(fn {k, v} -> "  #{k}: #{format_yaml_value(v)}" end)

    lines ++ ["metadata:"] ++ meta_lines
  end

  defp format_yaml_value(v) when is_binary(v), do: inspect(v)
  defp format_yaml_value(v), do: to_string(v)

  defp write_skill(skill_dir, skill_path, content) do
    with :ok <- File.mkdir_p(skill_dir) do
      case File.write(skill_path, content) do
        :ok -> :ok
        {:error, reason} -> {:error, "failed to write skill: #{inspect(reason)}"}
      end
    else
      {:error, reason} -> {:error, "failed to create skill directory: #{inspect(reason)}"}
    end
  end
end
