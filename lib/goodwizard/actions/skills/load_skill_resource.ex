defmodule Goodwizard.Actions.Skills.LoadSkillResource do
  @moduledoc """
  Reads a resource file from a skill's directory (Tier 3 content).

  Validates the requested filename against the skill's pre-indexed resource
  list to prevent path traversal attacks.
  """

  use Jido.Action,
    name: "load_skill_resource",
    description:
      "Load a bundled resource file from a skill's directory. Use when a skill's instructions reference additional files.",
    schema: [
      skill_name: [type: :string, required: true, doc: "The skill name"],
      resource: [type: :string, required: true, doc: "The resource filename to load"]
    ]

  # 1 MB max for resource files
  @max_resource_file_bytes 1_024 * 1_024

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(%{skill_name: skill_name, resource: resource} = _params, context) do
    skills = get_in(context, [:state, :prompt_skills, :skills]) || []

    case Enum.find(skills, &(&1.name == skill_name)) do
      nil ->
        {:error, "skill not found: #{skill_name}"}

      skill ->
        if resource in skill.resources do
          path = Path.join(skill.dir, resource)
          resolved = path |> Path.expand() |> resolve_symlinks()
          skill_root = Path.expand(skill.dir)

          if String.starts_with?(resolved, skill_root <> "/") do
            case File.stat(path) do
              {:ok, %{size: size}} when size > @max_resource_file_bytes ->
                {:error, "resource file too large: #{size} bytes exceeds #{@max_resource_file_bytes} limit"}

              {:ok, _stat} ->
                case File.read(path) do
                  {:ok, content} -> {:ok, %{content: content, filename: resource}}
                  {:error, reason} -> {:error, "failed to read resource: #{inspect(reason)}"}
                end

              {:error, reason} ->
                {:error, "failed to read resource: #{inspect(reason)}"}
            end
          else
            {:error, "resource path escapes skill directory"}
          end
        else
          {:error, "resource not found: #{resource}"}
        end
    end
  end

  defp resolve_symlinks(path) do
    case File.read_link(path) do
      {:ok, "/" <> _ = absolute_target} ->
        absolute_target |> resolve_symlinks()

      {:ok, relative_target} ->
        path |> Path.dirname() |> Path.join(relative_target) |> Path.expand() |> resolve_symlinks()

      {:error, _} ->
        path
    end
  end
end
