defmodule Goodwizard.Actions.Memory.Episodic.ArchiveOldTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.Episodic.ArchiveOld
  alias Goodwizard.Memory.Entry
  alias Goodwizard.Memory.Episodic

  setup do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "archive_old_test_#{:erlang.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    context = %{state: %{memory: %{memory_dir: tmp_dir}}}
    %{memory_dir: tmp_dir, context: context}
  end

  defp create_episode(memory_dir, opts) do
    type = Keyword.get(opts, :type, "task_completion")
    outcome = Keyword.get(opts, :outcome, "success")
    summary = Keyword.get(opts, :summary, "Test episode")
    days_ago = Keyword.get(opts, :days_ago, 0)
    lessons = Keyword.get(opts, :lessons, nil)

    timestamp =
      DateTime.utc_now()
      |> DateTime.add(-days_ago, :day)
      |> DateTime.to_iso8601()

    frontmatter = %{
      "type" => type,
      "summary" => summary,
      "outcome" => outcome,
      "tags" => Keyword.get(opts, :tags, [])
    }

    body_parts = [
      "## Observation\n\nTest observation",
      "## Approach\n\nTest approach",
      "## Result\n\nTest result"
    ]

    body_parts = if lessons, do: body_parts ++ ["## Lessons\n\n#{lessons}"], else: body_parts
    body = Enum.join(body_parts, "\n\n")

    {:ok, episode} = Episodic.create(memory_dir, frontmatter, body)

    # Override the auto-generated timestamp by rewriting the file
    dir = Path.join(memory_dir, "episodic")
    path = Path.join(dir, "#{episode["id"]}.md")
    updated_fm = Map.put(episode, "timestamp", timestamp)
    content = Entry.serialize(updated_fm, body)
    File.write!(path, content)

    episode["id"]
  end

  defp create_episodes(memory_dir, count, opts \\ []) do
    Enum.map(1..count, fn i ->
      create_episode(memory_dir, Keyword.merge(opts, summary: "Episode #{i}"))
    end)
  end

  describe "archival skips when file count at/below threshold" do
    test "rejects unsafe memory_dir before file operations" do
      bad_context = %{state: %{memory: %{memory_dir: "../tmp/memory"}}}
      assert {:error, message} = ArchiveOld.run(%{}, bad_context)
      assert message =~ "path traversal"
    end

    test "returns without modifying files when below threshold", %{
      memory_dir: dir,
      context: ctx
    } do
      # Create 3 episodes (well below default 200 threshold)
      create_episodes(dir, 3)

      assert {:ok, result} = ArchiveOld.run(%{file_threshold: 200}, ctx)
      assert result.archived == 0
      assert result.summaries_created == 0
      assert result.retained == 3
      assert result.message =~ "No archival needed"
    end

    test "returns without modifying files when at threshold", %{
      memory_dir: dir,
      context: ctx
    } do
      create_episodes(dir, 5)

      assert {:ok, result} = ArchiveOld.run(%{file_threshold: 5}, ctx)
      assert result.archived == 0
      assert result.summaries_created == 0
    end
  end

  describe "archival keeps episodes from last 30 days" do
    test "recent episodes are retained regardless of outcome", %{
      memory_dir: dir,
      context: ctx
    } do
      # Create old episodes (archive candidates)
      create_episodes(dir, 4, days_ago: 120, outcome: "failure")
      # Create recent episodes (should be kept)
      recent_ids = create_episodes(dir, 3, days_ago: 10, outcome: "failure")

      assert {:ok, result} = ArchiveOld.run(%{file_threshold: 5}, ctx)
      assert result.archived == 4
      assert result.retained >= 3

      # Verify recent episodes still exist
      for id <- recent_ids do
        assert {:ok, _} = Episodic.read(dir, id)
      end
    end
  end

  describe "archival keeps successful episodes from last 90 days" do
    test "successful episodes within 90 days are retained", %{
      memory_dir: dir,
      context: ctx
    } do
      # Old failure episodes (archive candidates)
      create_episodes(dir, 4, days_ago: 120, outcome: "failure")
      # 60-day-old successful episodes (should be kept)
      success_ids = create_episodes(dir, 3, days_ago: 60, outcome: "success")

      assert {:ok, result} = ArchiveOld.run(%{file_threshold: 5}, ctx)
      assert result.archived == 4

      for id <- success_ids do
        assert {:ok, _} = Episodic.read(dir, id)
      end
    end
  end

  describe "archival consolidates into monthly summaries" do
    test "creates monthly summary episodes from archived episodes", %{
      memory_dir: dir,
      context: ctx
    } do
      # Create episodes from 2 different months, all old enough to archive
      create_episodes(dir, 3, days_ago: 150)
      create_episodes(dir, 2, days_ago: 180)

      assert {:ok, result} = ArchiveOld.run(%{file_threshold: 3}, ctx)
      assert result.summaries_created >= 1
      assert result.archived == 5
    end
  end

  describe "monthly summary includes aggregated counts" do
    test "summary body contains type and outcome counts", %{
      memory_dir: dir,
      context: ctx
    } do
      create_episodes(dir, 3, days_ago: 150, type: "task_completion", outcome: "success")
      create_episodes(dir, 2, days_ago: 150, type: "problem_solved", outcome: "failure")

      assert {:ok, _result} = ArchiveOld.run(%{file_threshold: 3}, ctx)

      # Find the summary episode
      {:ok, episodes} = Episodic.list(dir, type: "monthly_summary", limit: 10)
      assert episodes != []

      summary = hd(episodes)
      {:ok, {_fm, body}} = Episodic.read(dir, summary["id"])

      assert body =~ "Episode Counts by Type"
      assert body =~ "task_completion"
      assert body =~ "Episode Counts by Outcome"
    end
  end

  describe "monthly summary includes key lessons" do
    test "summary body contains extracted lessons", %{
      memory_dir: dir,
      context: ctx
    } do
      create_episode(dir, days_ago: 150, lessons: "Always validate input before processing")
      create_episode(dir, days_ago: 155, lessons: "Use caching for repeated queries")
      # Need enough to exceed threshold
      create_episodes(dir, 3, days_ago: 160)

      assert {:ok, _result} = ArchiveOld.run(%{file_threshold: 3}, ctx)

      {:ok, episodes} = Episodic.list(dir, type: "monthly_summary", limit: 10)
      assert episodes != []

      summary = hd(episodes)
      {:ok, {_fm, body}} = Episodic.read(dir, summary["id"])

      assert body =~ "Key Lessons"
    end
  end

  describe "archived episodes deleted after summary creation" do
    test "individual episodes are removed after summarization", %{
      memory_dir: dir,
      context: ctx
    } do
      old_ids = create_episodes(dir, 4, days_ago: 150)

      assert {:ok, result} = ArchiveOld.run(%{file_threshold: 2}, ctx)
      assert result.archived == 4

      # Verify old episodes are deleted
      for id <- old_ids do
        assert {:error, :not_found} = Episodic.read(dir, id)
      end
    end
  end

  describe "archival is idempotent" do
    test "running twice does not create duplicate summaries", %{
      memory_dir: dir,
      context: ctx
    } do
      create_episodes(dir, 5, days_ago: 150)

      assert {:ok, result1} = ArchiveOld.run(%{file_threshold: 3}, ctx)
      assert result1.summaries_created >= 1

      # Second run should find fewer files and not create duplicates
      assert {:ok, result2} = ArchiveOld.run(%{file_threshold: 3}, ctx)
      # Either no archival needed or no new episodes to archive
      assert result2.archived == 0 or result2.summaries_created == 0
    end
  end
end
