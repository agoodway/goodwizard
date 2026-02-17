defmodule Goodwizard.Memory.EpisodicTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Memory.Episodic

  @valid_frontmatter %{
    "type" => "problem_solved",
    "summary" => "Fixed deployment pipeline",
    "outcome" => "success"
  }

  @valid_body """
  ## Observation
  The deployment pipeline was failing on the CI step.

  ## Approach
  Investigated the Docker build context and found a missing dependency.

  ## Result
  Added the missing dependency to mix.exs and the pipeline recovered.

  ## Lessons
  Always check dependency lists after version upgrades.
  """

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "episodic_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    %{memory_dir: tmp_dir}
  end

  # --- Helper ---

  defp create_episode(memory_dir, overrides \\ %{}, body \\ @valid_body) do
    frontmatter = Map.merge(@valid_frontmatter, overrides)
    Episodic.create(memory_dir, frontmatter, body)
  end

  defp create_episode_with_timestamp(memory_dir, timestamp, overrides) do
    # Create the episode, then rewrite the file with a fixed timestamp
    {:ok, fm} = create_episode(memory_dir, overrides)
    id = fm["id"]
    dir = Path.join(memory_dir, "episodic")
    path = Path.join(dir, "#{id}.md")

    {:ok, content} = File.read(path)
    updated = String.replace(content, fm["timestamp"], timestamp)
    File.write!(path, updated)

    Map.put(fm, "timestamp", timestamp)
  end

  # =====================
  # Episode Creation Tests
  # =====================

  describe "create/3" do
    test "creates episode with auto-generated id and timestamp", %{memory_dir: dir} do
      assert {:ok, fm} = create_episode(dir)
      assert is_binary(fm["id"])
      assert String.length(fm["id"]) == 36
      assert is_binary(fm["timestamp"])
      assert fm["timestamp"] =~ ~r/^\d{4}-\d{2}-\d{2}T/
    end

    test "preserves provided frontmatter fields", %{memory_dir: dir} do
      assert {:ok, fm} = create_episode(dir)
      assert fm["type"] == "problem_solved"
      assert fm["summary"] == "Fixed deployment pipeline"
      assert fm["outcome"] == "success"
    end

    test "writes file to correct path", %{memory_dir: dir} do
      assert {:ok, fm} = create_episode(dir)
      path = Path.join([dir, "episodic", "#{fm["id"]}.md"])
      assert File.exists?(path)
    end

    test "defaults tags to empty list", %{memory_dir: dir} do
      assert {:ok, fm} = create_episode(dir)
      assert fm["tags"] == []
    end

    test "defaults entities_involved to empty list", %{memory_dir: dir} do
      assert {:ok, fm} = create_episode(dir)
      assert fm["entities_involved"] == []
    end

    test "preserves provided tags", %{memory_dir: dir} do
      assert {:ok, fm} = create_episode(dir, %{"tags" => ["elixir", "deploy"]})
      assert fm["tags"] == ["elixir", "deploy"]
    end

    test "preserves provided entities_involved", %{memory_dir: dir} do
      assert {:ok, fm} =
               create_episode(dir, %{"entities_involved" => ["user:abc", "service:deploy"]})

      assert fm["entities_involved"] == ["user:abc", "service:deploy"]
    end

    test "truncates summary exceeding 200 characters", %{memory_dir: dir} do
      long_summary = String.duplicate("a", 250)
      assert {:ok, fm} = create_episode(dir, %{"summary" => long_summary})
      assert String.length(fm["summary"]) == 200
    end

    test "accepts summary at exactly 200 characters", %{memory_dir: dir} do
      summary = String.duplicate("a", 200)
      assert {:ok, fm} = create_episode(dir, %{"summary" => summary})
      assert fm["summary"] == summary
    end

    test "rejects missing type", %{memory_dir: dir} do
      fm = Map.delete(@valid_frontmatter, "type")
      assert {:error, {:missing_required, "type"}} = Episodic.create(dir, fm, "body")
    end

    test "rejects missing summary", %{memory_dir: dir} do
      fm = Map.delete(@valid_frontmatter, "summary")
      assert {:error, {:missing_required, "summary"}} = Episodic.create(dir, fm, "body")
    end

    test "rejects missing outcome", %{memory_dir: dir} do
      fm = Map.delete(@valid_frontmatter, "outcome")
      assert {:error, {:missing_required, "outcome"}} = Episodic.create(dir, fm, "body")
    end

    test "rejects invalid episode type", %{memory_dir: dir} do
      assert {:error, {:invalid_type, "unknown_type"}} =
               create_episode(dir, %{"type" => "unknown_type"})
    end

    test "rejects invalid outcome", %{memory_dir: dir} do
      assert {:error, {:invalid_outcome, "maybe"}} =
               create_episode(dir, %{"outcome" => "maybe"})
    end

    test "accepts all valid episode types", %{memory_dir: dir} do
      for type <- Episodic.episode_types() do
        assert {:ok, fm} = create_episode(dir, %{"type" => type})
        assert fm["type"] == type
      end
    end

    test "accepts all valid outcome types", %{memory_dir: dir} do
      for outcome <- Episodic.outcome_types() do
        assert {:ok, fm} = create_episode(dir, %{"outcome" => outcome})
        assert fm["outcome"] == outcome
      end
    end

    test "written file is parseable", %{memory_dir: dir} do
      assert {:ok, fm} = create_episode(dir)
      assert {:ok, {read_fm, read_body}} = Episodic.read(dir, fm["id"])
      assert read_fm["type"] == fm["type"]
      assert read_fm["summary"] == fm["summary"]
      assert read_body =~ "deployment pipeline"
    end
  end

  # =====================
  # Episode Read Tests
  # =====================

  describe "read/2" do
    test "reads an existing episode", %{memory_dir: dir} do
      {:ok, fm} = create_episode(dir)

      assert {:ok, {read_fm, body}} = Episodic.read(dir, fm["id"])
      assert read_fm["id"] == fm["id"]
      assert read_fm["type"] == "problem_solved"
      assert body =~ "deployment pipeline"
    end

    test "returns not_found for non-existent id", %{memory_dir: dir} do
      assert {:error, :not_found} = Episodic.read(dir, "nonexistent-id")
    end

    test "returns full frontmatter and body", %{memory_dir: dir} do
      {:ok, fm} = create_episode(dir, %{"tags" => ["elixir"]})

      assert {:ok, {read_fm, body}} = Episodic.read(dir, fm["id"])
      assert read_fm["tags"] == ["elixir"]
      assert read_fm["timestamp"] == fm["timestamp"]
      assert is_binary(body)
    end
  end

  # =====================
  # Episode Delete Tests
  # =====================

  describe "delete/2" do
    test "deletes an existing episode", %{memory_dir: dir} do
      {:ok, fm} = create_episode(dir)
      assert :ok = Episodic.delete(dir, fm["id"])
      assert {:error, :not_found} = Episodic.read(dir, fm["id"])
    end

    test "returns not_found for non-existent id", %{memory_dir: dir} do
      assert {:error, :not_found} = Episodic.delete(dir, "nonexistent-id")
    end

    test "file is removed from disk", %{memory_dir: dir} do
      {:ok, fm} = create_episode(dir)
      path = Path.join([dir, "episodic", "#{fm["id"]}.md"])
      assert File.exists?(path)
      assert :ok = Episodic.delete(dir, fm["id"])
      refute File.exists?(path)
    end
  end

  # =====================
  # Episode Listing Tests
  # =====================

  describe "list/2" do
    test "returns empty list for empty directory", %{memory_dir: dir} do
      assert {:ok, []} = Episodic.list(dir)
    end

    test "returns empty list when directory does not exist", %{memory_dir: dir} do
      assert {:ok, []} = Episodic.list(Path.join(dir, "nonexistent"))
    end

    test "returns all episodes", %{memory_dir: dir} do
      create_episode(dir, %{"summary" => "Episode 1"})
      create_episode(dir, %{"summary" => "Episode 2"})
      create_episode(dir, %{"summary" => "Episode 3"})

      assert {:ok, episodes} = Episodic.list(dir)
      assert length(episodes) == 3
    end

    test "returns frontmatter only (no body)", %{memory_dir: dir} do
      create_episode(dir)

      assert {:ok, [fm]} = Episodic.list(dir)
      assert is_map(fm)
      assert Map.has_key?(fm, "id")
      assert Map.has_key?(fm, "type")
      # Frontmatter maps don't have a "body" key — body is separate in the tuple
      refute Map.has_key?(fm, "body")
    end

    test "sorts by timestamp descending", %{memory_dir: dir} do
      create_episode_with_timestamp(dir, "2026-02-01T10:00:00Z", %{"summary" => "Oldest"})
      create_episode_with_timestamp(dir, "2026-02-15T10:00:00Z", %{"summary" => "Middle"})
      create_episode_with_timestamp(dir, "2026-02-17T10:00:00Z", %{"summary" => "Newest"})

      assert {:ok, episodes} = Episodic.list(dir)
      summaries = Enum.map(episodes, & &1["summary"])
      assert summaries == ["Newest", "Middle", "Oldest"]
    end

    test "applies default limit of 20", %{memory_dir: dir} do
      for i <- 1..25 do
        create_episode(dir, %{"summary" => "Episode #{i}"})
      end

      assert {:ok, episodes} = Episodic.list(dir)
      assert length(episodes) == 20
    end

    test "applies custom limit", %{memory_dir: dir} do
      for i <- 1..10 do
        create_episode(dir, %{"summary" => "Episode #{i}"})
      end

      assert {:ok, episodes} = Episodic.list(dir, limit: 5)
      assert length(episodes) == 5
    end

    test "filters by type", %{memory_dir: dir} do
      create_episode(dir, %{"type" => "problem_solved", "summary" => "Solved it"})
      create_episode(dir, %{"type" => "error_encountered", "summary" => "Error"})
      create_episode(dir, %{"type" => "problem_solved", "summary" => "Another fix"})

      assert {:ok, episodes} = Episodic.list(dir, type: "problem_solved")
      assert length(episodes) == 2
      assert Enum.all?(episodes, &(&1["type"] == "problem_solved"))
    end

    test "filters by outcome", %{memory_dir: dir} do
      create_episode(dir, %{"outcome" => "success", "summary" => "Win"})
      create_episode(dir, %{"outcome" => "failure", "summary" => "Loss"})
      create_episode(dir, %{"outcome" => "success", "summary" => "Another win"})

      assert {:ok, episodes} = Episodic.list(dir, outcome: "success")
      assert length(episodes) == 2
      assert Enum.all?(episodes, &(&1["outcome"] == "success"))
    end

    test "filters by tags (intersection match)", %{memory_dir: dir} do
      create_episode(dir, %{"tags" => ["elixir", "debug"], "summary" => "Both tags"})
      create_episode(dir, %{"tags" => ["elixir"], "summary" => "One tag"})
      create_episode(dir, %{"tags" => ["python"], "summary" => "Wrong tag"})

      assert {:ok, episodes} = Episodic.list(dir, tags: ["elixir", "debug"])
      assert length(episodes) == 1
      assert hd(episodes)["summary"] == "Both tags"
    end

    test "filters by date range (after inclusive, before exclusive)", %{memory_dir: dir} do
      create_episode_with_timestamp(dir, "2026-02-01T10:00:00Z", %{"summary" => "Too early"})
      create_episode_with_timestamp(dir, "2026-02-10T10:00:00Z", %{"summary" => "In range"})
      create_episode_with_timestamp(dir, "2026-02-15T10:00:00Z", %{"summary" => "At before"})

      assert {:ok, episodes} =
               Episodic.list(dir,
                 after: "2026-02-05T00:00:00Z",
                 before: "2026-02-15T10:00:00Z"
               )

      assert length(episodes) == 1
      assert hd(episodes)["summary"] == "In range"
    end

    test "after filter is inclusive", %{memory_dir: dir} do
      create_episode_with_timestamp(dir, "2026-02-10T10:00:00Z", %{"summary" => "Exact match"})

      assert {:ok, episodes} = Episodic.list(dir, after: "2026-02-10T10:00:00Z")
      assert length(episodes) == 1
    end

    test "combines multiple filters", %{memory_dir: dir} do
      create_episode(dir, %{
        "type" => "problem_solved",
        "outcome" => "success",
        "tags" => ["elixir"],
        "summary" => "Match"
      })

      create_episode(dir, %{
        "type" => "error_encountered",
        "outcome" => "success",
        "tags" => ["elixir"],
        "summary" => "Wrong type"
      })

      assert {:ok, episodes} =
               Episodic.list(dir, type: "problem_solved", outcome: "success", tags: ["elixir"])

      assert length(episodes) == 1
      assert hd(episodes)["summary"] == "Match"
    end
  end

  # =====================
  # Episode Search Tests
  # =====================

  describe "search/3" do
    test "finds text match in summary", %{memory_dir: dir} do
      create_episode(dir, %{"summary" => "Fixed deployment pipeline"}, "no match here")
      create_episode(dir, %{"summary" => "Updated documentation"}, "nothing relevant")

      assert {:ok, results} = Episodic.search(dir, "deploy")
      assert length(results) == 1
      assert hd(results)["summary"] =~ "deploy"
    end

    test "finds text match in body", %{memory_dir: dir} do
      create_episode(dir, %{"summary" => "Some episode"}, "restarted the Docker container")
      create_episode(dir, %{"summary" => "Other episode"}, "nothing special")

      assert {:ok, results} = Episodic.search(dir, "docker")
      assert length(results) == 1
      assert hd(results)["summary"] == "Some episode"
    end

    test "search is case-insensitive", %{memory_dir: dir} do
      create_episode(dir, %{"summary" => "Elixir debugging session"})

      assert {:ok, results} = Episodic.search(dir, "ELIXIR")
      assert length(results) == 1

      assert {:ok, results} = Episodic.search(dir, "elixir")
      assert length(results) == 1
    end

    test "combines text search with metadata filters", %{memory_dir: dir} do
      create_episode(dir, %{
        "type" => "error_encountered",
        "summary" => "App crashed on deploy"
      })

      create_episode(dir, %{
        "type" => "problem_solved",
        "summary" => "Deploy issue fixed"
      })

      assert {:ok, results} = Episodic.search(dir, "deploy", type: "error_encountered")
      assert length(results) == 1
      assert hd(results)["type"] == "error_encountered"
    end

    test "empty query acts as list", %{memory_dir: dir} do
      create_episode(dir, %{"summary" => "Episode 1"})
      create_episode(dir, %{"summary" => "Episode 2"})

      assert {:ok, results} = Episodic.search(dir, "")
      assert length(results) == 2
    end

    test "empty query with filters", %{memory_dir: dir} do
      create_episode(dir, %{"type" => "problem_solved", "summary" => "One"})
      create_episode(dir, %{"type" => "error_encountered", "summary" => "Two"})

      assert {:ok, results} = Episodic.search(dir, "", type: "problem_solved")
      assert length(results) == 1
      assert hd(results)["summary"] == "One"
    end

    test "respects limit", %{memory_dir: dir} do
      for i <- 1..10 do
        create_episode(dir, %{"summary" => "Episode #{i} test"})
      end

      assert {:ok, results} = Episodic.search(dir, "test", limit: 3)
      assert length(results) == 3
    end

    test "default search limit is 10", %{memory_dir: dir} do
      for i <- 1..15 do
        create_episode(dir, %{"summary" => "Episode #{i} searchable"})
      end

      assert {:ok, results} = Episodic.search(dir, "searchable")
      assert length(results) == 10
    end

    test "returns results sorted by timestamp descending", %{memory_dir: dir} do
      create_episode_with_timestamp(dir, "2026-02-01T10:00:00Z", %{
        "summary" => "Oldest searchable"
      })

      create_episode_with_timestamp(dir, "2026-02-15T10:00:00Z", %{
        "summary" => "Newest searchable"
      })

      assert {:ok, results} = Episodic.search(dir, "searchable")
      assert length(results) == 2
      assert List.first(results)["summary"] == "Newest searchable"
      assert List.last(results)["summary"] == "Oldest searchable"
    end

    test "returns empty list when no matches", %{memory_dir: dir} do
      create_episode(dir, %{"summary" => "Nothing related"})

      assert {:ok, []} = Episodic.search(dir, "nonexistent_term_xyz")
    end

    test "searches across tags", %{memory_dir: dir} do
      create_episode(dir, %{"tags" => ["phoenix", "liveview"], "summary" => "Tagged episode"})
      create_episode(dir, %{"tags" => ["python"], "summary" => "Other episode"})

      assert {:ok, results} = Episodic.search(dir, "liveview")
      assert length(results) == 1
      assert hd(results)["summary"] == "Tagged episode"
    end
  end

  # =====================
  # Module Attribute Tests
  # =====================

  describe "episode_types/0" do
    test "returns expected types" do
      types = Episodic.episode_types()

      assert "task_completion" in types
      assert "problem_solved" in types
      assert "error_encountered" in types
      assert "decision_made" in types
      assert "interaction" in types
      assert length(types) == 5
    end
  end

  describe "outcome_types/0" do
    test "returns expected outcomes" do
      outcomes = Episodic.outcome_types()

      assert "success" in outcomes
      assert "failure" in outcomes
      assert "partial" in outcomes
      assert "abandoned" in outcomes
      assert length(outcomes) == 4
    end
  end
end
