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

  alias Goodwizard.Plugins.PromptSkills

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(%{skill_name: skill_name, resource: resource} = _params, context) do
    skills = resolve_skills(context)

    with {:ok, skill} <- find_skill(skills, skill_name),
         :ok <- check_resource_listed(skill, resource),
         {:ok, path} <- validate_resource_path(skill, resource),
         :ok <- check_resource_size(path) do
      read_resource(path, resource)
    end
  end

  defp resolve_skills(context) do
    case get_in(context, [:state, :prompt_skills, :skills]) do
      [_ | _] = skills -> skills
      _ -> PromptSkills.scan_skills(Goodwizard.Config.workspace())
    end
  end

  defp find_skill(skills, skill_name) do
    case Enum.find(skills, &(&1.name == skill_name)) do
      nil -> {:error, "skill not found: #{skill_name}"}
      skill -> {:ok, skill}
    end
  end

  defp check_resource_listed(skill, resource) do
    if resource in skill.resources, do: :ok, else: {:error, "resource not found: #{resource}"}
  end

  defp validate_resource_path(skill, resource) do
    path = Path.join(skill.dir, resource)
    resolved = path |> Path.expand() |> resolve_symlinks()
    skill_root = Path.expand(skill.dir)

    if String.starts_with?(resolved, skill_root <> "/") do
      {:ok, path}
    else
      {:error, "resource path escapes skill directory"}
    end
  end

  defp check_resource_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size > @max_resource_file_bytes ->
        {:error,
         "resource file too large: #{size} bytes exceeds #{@max_resource_file_bytes} limit"}

      {:ok, _stat} ->
        :ok

      {:error, reason} ->
        {:error, "failed to read resource: #{inspect(reason)}"}
    end
  end

  defp read_resource(path, resource) do
    case File.read(path) do
      {:ok, content} -> {:ok, %{content: content, filename: resource}}
      {:error, reason} -> {:error, "failed to read resource: #{inspect(reason)}"}
    end
  end

  defp resolve_symlinks(path) do
    case File.read_link(path) do
      {:ok, "/" <> _ = absolute_target} ->
        absolute_target |> resolve_symlinks()

      {:ok, relative_target} ->
        path
        |> Path.dirname()
        |> Path.join(relative_target)
        |> Path.expand()
        |> resolve_symlinks()

      {:error, _} ->
        path
    end
  end
end
