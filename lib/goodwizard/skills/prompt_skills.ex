defmodule Goodwizard.Skills.PromptSkills do
  @moduledoc """
  Plugin that scans workspace skill directories for SKILL.md files,
  parses Claude Code-compatible frontmatter, indexes resource files,
  and builds a plain-text summary for system prompt injection.

  Scans both `workspace/skills/` and `.claude/skills/` directories.
  Workspace takes precedence on name collision.
  """

  use Jido.Plugin,
    name: "prompt_skills",
    description: "Scans and indexes prompt skills from workspace",
    state_key: :prompt_skills,
    actions: [],
    schema:
      Zoi.object(%{
        skills: Zoi.list(Zoi.any()) |> Zoi.default([]),
        skills_summary: Zoi.string() |> Zoi.default("")
      })

  require Logger

  alias Goodwizard.Skills.PromptSkills.Parser

  @impl Jido.Plugin
  def mount(agent, _config) do
    workspace =
      get_in(agent, [Access.key(:state, %{}), :workspace]) || "."

    skills = scan_skills(workspace)
    summary = build_skills_summary(skills)

    {:ok, %{skills: skills, skills_summary: summary}}
  end

  @doc """
  Scan both skill directories for SKILL.md files.

  Returns a list of skill maps with keys: `:name`, `:description`, `:path`,
  `:dir`, `:content` (body), `:resources`, `:meta`.
  Workspace skills take precedence on name collision.
  """
  @spec scan_skills(String.t()) :: [map()]
  def scan_skills(workspace) do
    workspace_dir = Path.join(workspace, "skills")
    claude_dir = Path.join([workspace, ".claude", "skills"])

    # Scan claude dir first, then workspace (so workspace overwrites on collision)
    claude_skills = scan_directory(claude_dir)
    workspace_skills = scan_directory(workspace_dir)

    # Merge: workspace takes precedence by name
    merged =
      (claude_skills ++ workspace_skills)
      |> Enum.reduce(%{}, fn skill, acc -> Map.put(acc, skill.name, skill) end)
      |> Map.values()
      |> Enum.sort_by(& &1.name)

    merged
  end

  @doc """
  Build a plain-text markdown summary of all discovered skills.

  Returns an empty string if no skills are discovered.
  """
  @spec build_skills_summary([map()]) :: String.t()
  def build_skills_summary([]), do: ""

  def build_skills_summary(skills) do
    entries =
      Enum.map(skills, fn skill ->
        base = "- **#{skill.name}** - #{skill.description}"

        case skill.resources do
          [] -> base
          resources -> base <> "\n  Resources: " <> Enum.join(resources, ", ")
        end
      end)

    """
    ## Available Skills

    Skills can be activated with the activate_skill tool when relevant.

    #{Enum.join(entries, "\n")}\
    """
    |> String.trim_trailing()
  end

  # Scan a single directory for skill subdirectories containing SKILL.md.
  defp scan_directory(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        entries
        |> Enum.sort()
        |> Enum.flat_map(fn entry ->
          skill_dir = Path.join(dir, entry)
          skill_md = Path.join(skill_dir, "SKILL.md")

          if File.dir?(skill_dir) and File.regular?(skill_md) do
            case parse_skill(skill_md, skill_dir) do
              {:ok, skill} ->
                [skill]

              {:error, reason} ->
                Logger.warning("Skipping skill at #{skill_dir}: #{reason}")
                []
            end
          else
            []
          end
        end)

      {:error, _} ->
        []
    end
  end

  defp parse_skill(skill_md_path, skill_dir) do
    with {:ok, content} <- File.read(skill_md_path),
         {:ok, metadata, body} <- Parser.parse_frontmatter(content),
         {:ok, metadata} <- Parser.validate_metadata(metadata) do
      resources = list_resources(skill_dir)

      {:ok,
       %{
         name: metadata.name,
         description: metadata.description,
         path: skill_md_path,
         dir: skill_dir,
         content: body,
         resources: resources,
         meta: metadata.meta
       }}
    end
  end

  defp list_resources(skill_dir) do
    case File.ls(skill_dir) do
      {:ok, entries} ->
        entries
        |> Enum.reject(&(&1 == "SKILL.md"))
        |> Enum.filter(&File.regular?(Path.join(skill_dir, &1)))
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end
end
