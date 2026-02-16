defmodule Goodwizard.Plugins.PromptSkills do
  @moduledoc """
  Plugin that scans the workspace `skills/` directory for SKILL.md files,
  parses frontmatter, indexes resource files, and builds a plain-text
  summary for system prompt injection.

  Resource indexing is non-recursive: only files directly inside a skill's
  directory are indexed (subdirectories are ignored).
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

  @typedoc "A discovered skill with parsed metadata and indexed resources."
  @type skill :: %{
          name: String.t(),
          description: String.t(),
          path: String.t(),
          dir: String.t(),
          content: String.t(),
          resources: [String.t()],
          meta: map()
        }

  # 256 KB max for SKILL.md files
  @max_skill_file_bytes 256 * 1024

  alias Goodwizard.Plugins.PromptSkills.Parser

  @impl Jido.Plugin
  def mount(agent, config) do
    workspace =
      Map.get(config, :workspace) ||
        get_in(agent, [Access.key(:state, %{}), :workspace]) ||
        Goodwizard.Config.workspace()

    skills = scan_skills(workspace)
    summary = build_skills_summary(skills)

    {:ok, %{skills: skills, skills_summary: summary}}
  end

  @doc """
  Scan the workspace `skills/` directory for SKILL.md files.

  Returns a list of skill maps with keys: `:name`, `:description`, `:path`,
  `:dir`, `:content` (body), `:resources`, `:meta`.
  """
  @spec scan_skills(String.t()) :: [skill()]
  def scan_skills(workspace) do
    workspace_dir = Path.join(workspace, "skills")

    skills =
      scan_directory(workspace_dir)
      |> Enum.sort_by(& &1.name)

    Logger.debug(fn -> "[PromptSkills] Scan complete, skills=#{length(skills)}" end)
    skills
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

    IMPORTANT: Before using browser tools or shell commands for a task, check if a skill below already handles it. Skills are faster, more reliable, and use fewer iterations than browser scraping. Activate a matching skill first with the activate_skill tool, then follow its instructions.

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
        |> Enum.flat_map(&try_parse_skill_entry(dir, &1))

      {:error, _} ->
        []
    end
  end

  defp try_parse_skill_entry(dir, entry) do
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
  end

  defp parse_skill(skill_md_path, skill_dir) do
    with {:ok, stat} <- File.stat(skill_md_path),
         :ok <- check_file_size(stat.size, skill_md_path),
         {:ok, content} <- File.read(skill_md_path),
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

  defp check_file_size(size, path) when size > @max_skill_file_bytes do
    Logger.warning("Skipping #{path}: file size #{size} exceeds limit #{@max_skill_file_bytes}")
    {:error, "file too large"}
  end

  defp check_file_size(_size, _path), do: :ok

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
