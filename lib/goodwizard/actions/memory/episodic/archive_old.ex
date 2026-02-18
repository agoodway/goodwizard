defmodule Goodwizard.Actions.Memory.Episodic.ArchiveOld do
  @moduledoc """
  Archives old episodic memory entries into monthly summary episodes.

  When the episodic store exceeds a file count threshold, episodes older than
  the retention windows are grouped by calendar month and consolidated into
  summary episodes. Individual archived episodes are deleted after their
  monthly summary is written.
  """

  use Jido.Action,
    name: "archive_old_episodes",
    description:
      "Archive old episodic memories into monthly summaries when the store exceeds the file threshold",
    schema: [
      file_threshold: [
        type: :integer,
        default: 200,
        doc: "Number of episode files that triggers archival"
      ],
      recent_days: [
        type: :integer,
        default: 30,
        doc: "Keep all episodes from the last N days regardless of outcome"
      ],
      success_retention_days: [
        type: :integer,
        default: 90,
        doc: "Keep successful episodes from the last N days"
      ]
    ]

  require Logger

  alias Goodwizard.Actions.Memory.Episodic.Helpers
  alias Goodwizard.Memory.Entry
  alias Goodwizard.Memory.Episodic
  alias Goodwizard.Memory.Paths

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    memory_dir = Helpers.memory_dir(context)
    file_threshold = Map.get(params, :file_threshold, 200)
    recent_days = Map.get(params, :recent_days, 30)
    success_retention_days = Map.get(params, :success_retention_days, 90)

    episodic_dir = Paths.episodic_dir(memory_dir)

    case count_episode_files(episodic_dir) do
      {:ok, count} when count <= file_threshold ->
        {:ok,
         %{
           archived: 0,
           summaries_created: 0,
           retained: count,
           message: "No archival needed (#{count} files, threshold #{file_threshold})"
         }}

      {:ok, _count} ->
        run_archive(memory_dir, episodic_dir, recent_days, success_retention_days)

      {:error, reason} ->
        {:error, "Failed to count episode files: #{inspect(reason)}"}
    end
  end

  defp count_episode_files(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        {:ok, Enum.count(files, &String.ends_with?(&1, ".md"))}

      {:error, :enoent} ->
        {:ok, 0}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_archive(memory_dir, episodic_dir, recent_days, success_retention_days) do
    now = DateTime.utc_now()
    recent_cutoff = DateTime.add(now, -recent_days, :day)
    success_cutoff = DateTime.add(now, -success_retention_days, :day)

    entries = read_all_episodes(episodic_dir)

    {keep, archive} =
      Enum.split_with(entries, fn {fm, _body} ->
        keep_episode?(fm, recent_cutoff, success_cutoff)
      end)

    if archive == [] do
      {:ok,
       %{
         archived: 0,
         summaries_created: 0,
         retained: length(keep),
         message: "No episodes eligible for archival"
       }}
    else
      monthly_groups = group_by_month(archive)

      summaries_created =
        Enum.reduce(monthly_groups, 0, fn {month, episodes}, acc ->
          case create_monthly_summary(memory_dir, month, episodes) do
            {:ok, _} ->
              delete_archived_episodes(memory_dir, episodes)
              acc + 1

            {:error, reason} ->
              Logger.warning("Failed to create summary for #{month}: #{inspect(reason)}")
              acc
          end
        end)

      archived_count = length(archive)

      {:ok,
       %{
         archived: archived_count,
         summaries_created: summaries_created,
         retained: length(keep),
         message:
           "Archived #{archived_count} episodes into #{summaries_created} monthly summaries"
       }}
    end
  end

  defp read_all_episodes(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".md"))
        |> Enum.flat_map(fn file ->
          path = Path.join(dir, file)

          case File.read(path) do
            {:ok, content} ->
              case Entry.parse(content) do
                {:ok, {fm, body}} -> [{fm, body}]
                _ -> []
              end

            _ ->
              []
          end
        end)

      {:error, _} ->
        []
    end
  end

  defp keep_episode?(fm, recent_cutoff, success_cutoff) do
    if fm["type"] == "monthly_summary" do
      true
    else
      case DateTime.from_iso8601(fm["timestamp"] || "") do
        {:ok, ts, _} ->
          within_recent = DateTime.compare(ts, recent_cutoff) in [:gt, :eq]

          within_success =
            fm["outcome"] == "success" and DateTime.compare(ts, success_cutoff) in [:gt, :eq]

          within_recent or within_success

        _ ->
          true
      end
    end
  end

  defp group_by_month(entries) do
    Enum.group_by(entries, fn {fm, _body} ->
      case fm["timestamp"] do
        nil ->
          "unknown"

        ts ->
          case DateTime.from_iso8601(ts) do
            {:ok, dt, _} ->
              month = String.pad_leading("#{dt.month}", 2, "0")
              "#{dt.year}-#{month}"

            _ ->
              "unknown"
          end
      end
    end)
    |> Map.delete("unknown")
  end

  defp create_monthly_summary(memory_dir, month, episodes) do
    type_counts = count_by_field(episodes, "type")
    outcome_counts = count_by_field(episodes, "outcome")
    lessons = extract_lessons(episodes)
    notable_events = extract_notable_events(episodes)

    frontmatter = %{
      "type" => "monthly_summary",
      "summary" => "Monthly summary for #{month} (#{length(episodes)} episodes archived)",
      "outcome" => "success",
      "tags" => [month, "archive", "monthly_summary"]
    }

    body =
      build_summary_body(month, episodes, type_counts, outcome_counts, lessons, notable_events)

    Episodic.create(memory_dir, frontmatter, body)
  end

  defp count_by_field(entries, field) do
    Enum.reduce(entries, %{}, fn {fm, _body}, acc ->
      value = fm[field] || "unknown"
      Map.update(acc, value, 1, &(&1 + 1))
    end)
  end

  defp extract_lessons(episodes) do
    episodes
    |> Enum.flat_map(fn {_fm, body} ->
      case Regex.run(~r/## Lessons\s*\n+(.*?)(?=\n## |\z)/s, body) do
        [_, lessons_text] ->
          lessons_text
          |> String.trim()
          |> String.split("\n", trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        _ ->
          []
      end
    end)
    |> Enum.uniq()
    |> Enum.take(20)
  end

  defp extract_notable_events(episodes) do
    episodes
    |> Enum.map(fn {fm, _body} ->
      "- [#{fm["type"]}] #{fm["summary"]} (#{fm["outcome"]})"
    end)
    |> Enum.take(30)
  end

  defp build_summary_body(month, episodes, type_counts, outcome_counts, lessons, notable_events) do
    type_stats =
      type_counts
      |> Enum.map_join("\n", fn {type, count} -> "- #{type}: #{count}" end)

    outcome_stats =
      outcome_counts
      |> Enum.map_join("\n", fn {outcome, count} -> "- #{outcome}: #{count}" end)

    lessons_text =
      if lessons == [] do
        "No specific lessons extracted."
      else
        Enum.map_join(lessons, "\n", &("- #{&1}"))
      end

    events_text = Enum.join(notable_events, "\n")

    """
    ## Monthly Summary: #{month}

    Archived #{length(episodes)} episodes from #{month}.

    ## Episode Counts by Type

    #{type_stats}

    ## Episode Counts by Outcome

    #{outcome_stats}

    ## Key Lessons

    #{lessons_text}

    ## Notable Events

    #{events_text}
    """
    |> String.trim()
  end

  defp delete_archived_episodes(memory_dir, episodes) do
    Enum.each(episodes, fn {fm, _body} ->
      case fm["id"] do
        nil -> :ok
        id -> Episodic.delete(memory_dir, id)
      end
    end)
  end
end
