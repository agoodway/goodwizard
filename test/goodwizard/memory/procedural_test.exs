defmodule Goodwizard.Memory.ProceduralTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Memory.Procedural

  @valid_frontmatter %{
    "type" => "workflow",
    "summary" => "How to deploy the application",
    "source" => "learned"
  }

  @valid_body """
  ## When to apply
  When deploying the application to production.

  ## Steps
  1. Run mix test to verify all tests pass
  2. Build the Docker image
  3. Push to the container registry
  4. Deploy using kubectl apply

  ## Notes
  Always check the CI status before deploying.
  """

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "procedural_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    %{memory_dir: tmp_dir}
  end

  # --- Helpers ---

  defp create_procedure(memory_dir, overrides \\ %{}, body \\ @valid_body) do
    frontmatter = Map.merge(@valid_frontmatter, overrides)
    Procedural.create(memory_dir, frontmatter, body)
  end

  defp create_procedure_with_timestamp(memory_dir, updated_at, overrides) do
    {:ok, fm} = create_procedure(memory_dir, overrides)
    id = fm["id"]
    dir = Path.join(memory_dir, "procedural")
    path = Path.join(dir, "#{id}.md")

    {:ok, content} = File.read(path)
    updated = String.replace(content, fm["updated_at"], updated_at)
    File.write!(path, updated)

    Map.put(fm, "updated_at", updated_at)
  end

  defp create_procedure_with_last_used(memory_dir, last_used, overrides) do
    {:ok, fm} = create_procedure(memory_dir, overrides)
    id = fm["id"]
    dir = Path.join(memory_dir, "procedural")
    path = Path.join(dir, "#{id}.md")

    {:ok, content} = File.read(path)
    # Replace "last_used: ''" or "last_used:" with the desired value
    updated = String.replace(content, ~r/last_used:.*/, "last_used: '#{last_used}'")
    File.write!(path, updated)

    Map.put(fm, "last_used", last_used)
  end

  # =====================
  # Create Tests
  # =====================

  describe "create/3" do
    test "creates procedure with auto-generated id and timestamps", %{memory_dir: dir} do
      assert {:ok, fm} = create_procedure(dir)
      assert is_binary(fm["id"])
      assert String.length(fm["id"]) == 36
      assert is_binary(fm["created_at"])
      assert fm["created_at"] =~ ~r/^\d{4}-\d{2}-\d{2}T/
      assert is_binary(fm["updated_at"])
      assert fm["updated_at"] =~ ~r/^\d{4}-\d{2}-\d{2}T/
    end

    test "preserves provided frontmatter fields", %{memory_dir: dir} do
      assert {:ok, fm} = create_procedure(dir)
      assert fm["type"] == "workflow"
      assert fm["summary"] == "How to deploy the application"
      assert fm["source"] == "learned"
    end

    test "writes file to correct path", %{memory_dir: dir} do
      assert {:ok, fm} = create_procedure(dir)
      path = Path.join([dir, "procedural", "#{fm["id"]}.md"])
      assert File.exists?(path)
    end

    test "initializes usage counts to zero", %{memory_dir: dir} do
      assert {:ok, fm} = create_procedure(dir)
      assert fm["usage_count"] == 0
      assert fm["success_count"] == 0
      assert fm["failure_count"] == 0
    end

    test "initializes last_used to nil", %{memory_dir: dir} do
      assert {:ok, fm} = create_procedure(dir)
      assert fm["last_used"] == nil
    end

    test "defaults confidence to medium", %{memory_dir: dir} do
      assert {:ok, fm} = create_procedure(dir)
      assert fm["confidence"] == "medium"
    end

    test "preserves provided confidence", %{memory_dir: dir} do
      assert {:ok, fm} = create_procedure(dir, %{"confidence" => "high"})
      assert fm["confidence"] == "high"
    end

    test "defaults tags to empty list", %{memory_dir: dir} do
      assert {:ok, fm} = create_procedure(dir)
      assert fm["tags"] == []
    end

    test "preserves provided tags", %{memory_dir: dir} do
      assert {:ok, fm} = create_procedure(dir, %{"tags" => ["deploy", "docker"]})
      assert fm["tags"] == ["deploy", "docker"]
    end

    test "rejects missing type", %{memory_dir: dir} do
      fm = Map.delete(@valid_frontmatter, "type")
      assert {:error, {:missing_required, "type"}} = Procedural.create(dir, fm, "body")
    end

    test "rejects missing summary", %{memory_dir: dir} do
      fm = Map.delete(@valid_frontmatter, "summary")
      assert {:error, {:missing_required, "summary"}} = Procedural.create(dir, fm, "body")
    end

    test "rejects missing source", %{memory_dir: dir} do
      fm = Map.delete(@valid_frontmatter, "source")
      assert {:error, {:missing_required, "source"}} = Procedural.create(dir, fm, "body")
    end

    test "rejects invalid procedure type", %{memory_dir: dir} do
      assert {:error, {:invalid_type, "unknown"}} =
               create_procedure(dir, %{"type" => "unknown"})
    end

    test "rejects invalid confidence level", %{memory_dir: dir} do
      assert {:error, {:invalid_confidence, "very_high"}} =
               create_procedure(dir, %{"confidence" => "very_high"})
    end

    test "rejects invalid source type", %{memory_dir: dir} do
      assert {:error, {:invalid_source, "guessed"}} =
               create_procedure(dir, %{"source" => "guessed"})
    end

    test "accepts all valid procedure types", %{memory_dir: dir} do
      for type <- Procedural.procedure_types() do
        assert {:ok, fm} = create_procedure(dir, %{"type" => type})
        assert fm["type"] == type
      end
    end

    test "accepts all valid confidence levels", %{memory_dir: dir} do
      for conf <- Procedural.confidence_levels() do
        assert {:ok, fm} = create_procedure(dir, %{"confidence" => conf})
        assert fm["confidence"] == conf
      end
    end

    test "accepts all valid source types", %{memory_dir: dir} do
      for source <- Procedural.source_types() do
        assert {:ok, fm} = create_procedure(dir, %{"source" => source})
        assert fm["source"] == source
      end
    end

    test "written file is parseable", %{memory_dir: dir} do
      assert {:ok, fm} = create_procedure(dir)
      assert {:ok, {read_fm, read_body}} = Procedural.read(dir, fm["id"])
      assert read_fm["type"] == fm["type"]
      assert read_fm["summary"] == fm["summary"]
      assert read_body =~ "Docker"
    end
  end

  # =====================
  # Read Tests
  # =====================

  describe "read/2" do
    test "reads an existing procedure", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)

      assert {:ok, {read_fm, body}} = Procedural.read(dir, fm["id"])
      assert read_fm["id"] == fm["id"]
      assert read_fm["type"] == "workflow"
      assert body =~ "Docker"
    end

    test "returns not_found for non-existent id", %{memory_dir: dir} do
      assert {:error, :not_found} =
               Procedural.read(dir, "00000000-0000-0000-0000-000000000000")
    end

    test "returns full frontmatter and body", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir, %{"tags" => ["deploy"]})

      assert {:ok, {read_fm, body}} = Procedural.read(dir, fm["id"])
      assert read_fm["tags"] == ["deploy"]
      assert read_fm["created_at"] == fm["created_at"]
      assert is_binary(body)
    end

    test "rejects path-traversal ID", %{memory_dir: dir} do
      assert {:error, :invalid_id} = Procedural.read(dir, "../../etc/passwd")
    end
  end

  # =====================
  # Update Tests
  # =====================

  describe "update/4" do
    test "merges frontmatter updates", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)

      assert {:ok, updated} = Procedural.update(dir, fm["id"], %{"confidence" => "high"})
      assert updated["confidence"] == "high"
      assert updated["type"] == "workflow"
      assert updated["summary"] == "How to deploy the application"
    end

    test "replaces body when provided", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)
      new_body = "## Updated steps\nNew deployment process."

      assert {:ok, _updated} = Procedural.update(dir, fm["id"], %{}, new_body)
      assert {:ok, {_fm2, read_body}} = Procedural.read(dir, fm["id"])
      assert read_body =~ "Updated steps"
    end

    test "preserves body when nil is passed", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)

      assert {:ok, _updated} = Procedural.update(dir, fm["id"], %{"confidence" => "high"}, nil)
      assert {:ok, {_fm2, read_body}} = Procedural.read(dir, fm["id"])
      assert read_body =~ "Docker"
    end

    test "updates updated_at timestamp", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)
      Process.sleep(10)

      assert {:ok, updated} = Procedural.update(dir, fm["id"], %{"confidence" => "high"})
      assert updated["updated_at"] > fm["updated_at"]
    end

    test "preserves auto-managed fields", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)

      assert {:ok, updated} =
               Procedural.update(dir, fm["id"], %{
                 "id" => "fake-id",
                 "created_at" => "2020-01-01T00:00:00Z",
                 "usage_count" => 999,
                 "success_count" => 888,
                 "failure_count" => 777,
                 "last_used" => "2020-01-01T00:00:00Z"
               })

      assert updated["id"] == fm["id"]
      assert updated["created_at"] == fm["created_at"]
      assert updated["usage_count"] == 0
      assert updated["success_count"] == 0
      assert updated["failure_count"] == 0
    end

    test "returns not_found for non-existent id", %{memory_dir: dir} do
      assert {:error, :not_found} =
               Procedural.update(dir, "00000000-0000-0000-0000-000000000000", %{})
    end

    test "validates updated type", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)

      assert {:error, {:invalid_type, "bogus"}} =
               Procedural.update(dir, fm["id"], %{"type" => "bogus"})
    end

    test "validates updated confidence", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)

      assert {:error, {:invalid_confidence, "super"}} =
               Procedural.update(dir, fm["id"], %{"confidence" => "super"})
    end

    test "validates updated source", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)

      assert {:error, {:invalid_source, "guessed"}} =
               Procedural.update(dir, fm["id"], %{"source" => "guessed"})
    end
  end

  # =====================
  # Delete Tests
  # =====================

  describe "delete/2" do
    test "deletes an existing procedure", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)
      assert :ok = Procedural.delete(dir, fm["id"])
      assert {:error, :not_found} = Procedural.read(dir, fm["id"])
    end

    test "returns not_found for non-existent id", %{memory_dir: dir} do
      assert {:error, :not_found} =
               Procedural.delete(dir, "00000000-0000-0000-0000-000000000000")
    end

    test "file is removed from disk", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)
      path = Path.join([dir, "procedural", "#{fm["id"]}.md"])
      assert File.exists?(path)
      assert :ok = Procedural.delete(dir, fm["id"])
      refute File.exists?(path)
    end

    test "rejects path-traversal ID", %{memory_dir: dir} do
      assert {:error, :invalid_id} = Procedural.delete(dir, "../../etc/passwd")
    end
  end

  # =====================
  # List Tests
  # =====================

  describe "list/2" do
    test "returns empty list for empty directory", %{memory_dir: dir} do
      assert {:ok, []} = Procedural.list(dir)
    end

    test "returns empty list when directory does not exist", %{memory_dir: dir} do
      assert {:ok, []} = Procedural.list(Path.join(dir, "nonexistent"))
    end

    test "returns all procedures", %{memory_dir: dir} do
      create_procedure(dir, %{"summary" => "Procedure 1"})
      create_procedure(dir, %{"summary" => "Procedure 2"})
      create_procedure(dir, %{"summary" => "Procedure 3"})

      assert {:ok, procedures} = Procedural.list(dir)
      assert length(procedures) == 3
    end

    test "returns frontmatter only (no body)", %{memory_dir: dir} do
      create_procedure(dir)

      assert {:ok, [fm]} = Procedural.list(dir)
      assert is_map(fm)
      assert Map.has_key?(fm, "id")
      assert Map.has_key?(fm, "type")
      refute Map.has_key?(fm, "body")
    end

    test "sorts by updated_at descending", %{memory_dir: dir} do
      create_procedure_with_timestamp(dir, "2026-02-01T10:00:00Z", %{"summary" => "Oldest"})
      create_procedure_with_timestamp(dir, "2026-02-15T10:00:00Z", %{"summary" => "Middle"})
      create_procedure_with_timestamp(dir, "2026-02-17T10:00:00Z", %{"summary" => "Newest"})

      assert {:ok, procedures} = Procedural.list(dir)
      summaries = Enum.map(procedures, & &1["summary"])
      assert summaries == ["Newest", "Middle", "Oldest"]
    end

    test "applies default limit of 20", %{memory_dir: dir} do
      for i <- 1..25 do
        create_procedure(dir, %{"summary" => "Procedure #{i}"})
      end

      assert {:ok, procedures} = Procedural.list(dir)
      assert length(procedures) == 20
    end

    test "applies custom limit", %{memory_dir: dir} do
      for i <- 1..10 do
        create_procedure(dir, %{"summary" => "Procedure #{i}"})
      end

      assert {:ok, procedures} = Procedural.list(dir, limit: 5)
      assert length(procedures) == 5
    end

    test "filters by type", %{memory_dir: dir} do
      create_procedure(dir, %{"type" => "workflow", "summary" => "Deploy workflow"})
      create_procedure(dir, %{"type" => "preference", "summary" => "Code style pref"})
      create_procedure(dir, %{"type" => "workflow", "summary" => "Build workflow"})

      assert {:ok, procedures} = Procedural.list(dir, type: "workflow")
      assert length(procedures) == 2
      assert Enum.all?(procedures, &(&1["type"] == "workflow"))
    end

    test "filters by minimum confidence level", %{memory_dir: dir} do
      create_procedure(dir, %{"confidence" => "low", "summary" => "Low conf"})
      create_procedure(dir, %{"confidence" => "medium", "summary" => "Med conf"})
      create_procedure(dir, %{"confidence" => "high", "summary" => "High conf"})

      assert {:ok, procedures} = Procedural.list(dir, confidence: "medium")
      assert length(procedures) == 2
      confidences = Enum.map(procedures, & &1["confidence"])
      assert "low" not in confidences
    end

    test "filters by tags (intersection match)", %{memory_dir: dir} do
      create_procedure(dir, %{"tags" => ["deploy", "docker"], "summary" => "Both tags"})
      create_procedure(dir, %{"tags" => ["deploy"], "summary" => "One tag"})
      create_procedure(dir, %{"tags" => ["python"], "summary" => "Wrong tag"})

      assert {:ok, procedures} = Procedural.list(dir, tags: ["deploy", "docker"])
      assert length(procedures) == 1
      assert hd(procedures)["summary"] == "Both tags"
    end

    test "filters by minimum usage count", %{memory_dir: dir} do
      {:ok, fm1} = create_procedure(dir, %{"summary" => "Used a lot"})
      create_procedure(dir, %{"summary" => "Never used"})

      # Record 3 usages
      Procedural.record_usage(dir, fm1["id"], :success)
      Procedural.record_usage(dir, fm1["id"], :success)
      Procedural.record_usage(dir, fm1["id"], :success)

      assert {:ok, procedures} = Procedural.list(dir, min_usage_count: 3)
      assert length(procedures) == 1
      assert hd(procedures)["summary"] == "Used a lot"
    end

    test "combines multiple filters", %{memory_dir: dir} do
      create_procedure(dir, %{
        "type" => "workflow",
        "confidence" => "high",
        "tags" => ["deploy"],
        "summary" => "Match"
      })

      create_procedure(dir, %{
        "type" => "preference",
        "confidence" => "high",
        "tags" => ["deploy"],
        "summary" => "Wrong type"
      })

      assert {:ok, procedures} =
               Procedural.list(dir, type: "workflow", confidence: "medium", tags: ["deploy"])

      assert length(procedures) == 1
      assert hd(procedures)["summary"] == "Match"
    end
  end

  # =====================
  # Recall Tests
  # =====================

  describe "recall/3" do
    test "returns empty list for empty store", %{memory_dir: dir} do
      assert {:ok, []} = Procedural.recall(dir, "deploy the app")
    end

    test "returns procedures with scores", %{memory_dir: dir} do
      create_procedure(dir, %{
        "tags" => ["deploy"],
        "summary" => "How to deploy"
      })

      assert {:ok, [result]} = Procedural.recall(dir, "deploy the app", tags: ["deploy"])
      assert is_float(result["score"])
      assert result["score"] > 0
    end

    test "ranks by tag match", %{memory_dir: dir} do
      create_procedure(dir, %{
        "tags" => ["deploy", "docker"],
        "summary" => "Docker deploy",
        "confidence" => "medium"
      })

      create_procedure(dir, %{
        "tags" => ["testing"],
        "summary" => "Test procedure",
        "confidence" => "medium"
      })

      assert {:ok, results} =
               Procedural.recall(dir, "deploy with docker", tags: ["deploy", "docker"])

      assert length(results) == 2
      assert hd(results)["tags"] == ["deploy", "docker"]
    end

    test "high confidence scores higher than low confidence", %{memory_dir: dir} do
      create_procedure(dir, %{
        "tags" => ["deploy"],
        "summary" => "High confidence deploy",
        "confidence" => "high"
      })

      create_procedure(dir, %{
        "tags" => ["deploy"],
        "summary" => "Low confidence deploy",
        "confidence" => "low"
      })

      assert {:ok, results} = Procedural.recall(dir, "deploy", tags: ["deploy"])
      assert hd(results)["confidence"] == "high"
    end

    test "recently used scores higher", %{memory_dir: dir} do
      yesterday = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.to_iso8601()
      sixty_days_ago = DateTime.utc_now() |> DateTime.add(-60, :day) |> DateTime.to_iso8601()

      create_procedure_with_last_used(dir, yesterday, %{
        "tags" => ["deploy"],
        "summary" => "Recent deploy",
        "confidence" => "medium"
      })

      create_procedure_with_last_used(dir, sixty_days_ago, %{
        "tags" => ["deploy"],
        "summary" => "Old deploy",
        "confidence" => "medium"
      })

      assert {:ok, results} = Procedural.recall(dir, "deploy", tags: ["deploy"])
      assert hd(results)["summary"] == "Recent deploy"
    end

    test "respects limit", %{memory_dir: dir} do
      for i <- 1..10 do
        create_procedure(dir, %{"summary" => "Procedure #{i}", "tags" => ["test"]})
      end

      assert {:ok, results} = Procedural.recall(dir, "test", tags: ["test"], limit: 3)
      assert length(results) == 3
    end

    test "default limit is 5", %{memory_dir: dir} do
      for i <- 1..10 do
        create_procedure(dir, %{"summary" => "Procedure #{i}", "tags" => ["test"]})
      end

      assert {:ok, results} = Procedural.recall(dir, "test", tags: ["test"])
      assert length(results) == 5
    end

    test "filters by type", %{memory_dir: dir} do
      create_procedure(dir, %{"type" => "workflow", "summary" => "Deploy workflow"})
      create_procedure(dir, %{"type" => "preference", "summary" => "Code preference"})

      assert {:ok, results} = Procedural.recall(dir, "deploy", type: "workflow")
      assert length(results) == 1
      assert hd(results)["type"] == "workflow"
    end

    test "filters by minimum confidence", %{memory_dir: dir} do
      create_procedure(dir, %{"confidence" => "low", "summary" => "Low proc"})
      create_procedure(dir, %{"confidence" => "high", "summary" => "High proc"})

      assert {:ok, results} = Procedural.recall(dir, "proc", min_confidence: "medium")
      assert length(results) == 1
      assert hd(results)["confidence"] == "high"
    end

    test "text relevance contributes to score", %{memory_dir: dir} do
      create_procedure(dir, %{
        "summary" => "How to debug failing tests",
        "tags" => []
      })

      create_procedure(dir, %{
        "summary" => "How to deploy the app",
        "tags" => []
      })

      assert {:ok, results} = Procedural.recall(dir, "fix the failing test suite")
      # The procedure about failing tests should score higher on text relevance
      assert hd(results)["summary"] =~ "failing tests"
    end
  end

  # =====================
  # Usage Tracking Tests
  # =====================

  describe "record_usage/3" do
    test "increments usage_count on success", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)

      assert {:ok, updated} = Procedural.record_usage(dir, fm["id"], :success)
      assert updated["usage_count"] == 1
    end

    test "increments success_count on success", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)

      assert {:ok, updated} = Procedural.record_usage(dir, fm["id"], :success)
      assert updated["success_count"] == 1
      assert updated["failure_count"] == 0
    end

    test "increments failure_count on failure", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)

      assert {:ok, updated} = Procedural.record_usage(dir, fm["id"], :failure)
      assert updated["failure_count"] == 1
      assert updated["success_count"] == 0
    end

    test "increments usage_count on failure", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)

      assert {:ok, updated} = Procedural.record_usage(dir, fm["id"], :failure)
      assert updated["usage_count"] == 1
    end

    test "updates last_used timestamp", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)
      assert fm["last_used"] == nil

      assert {:ok, updated} = Procedural.record_usage(dir, fm["id"], :success)
      assert is_binary(updated["last_used"])
      assert updated["last_used"] =~ ~r/^\d{4}-\d{2}-\d{2}T/
    end

    test "accumulates multiple usages", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir)

      {:ok, _} = Procedural.record_usage(dir, fm["id"], :success)
      {:ok, _} = Procedural.record_usage(dir, fm["id"], :success)
      {:ok, updated} = Procedural.record_usage(dir, fm["id"], :failure)

      assert updated["usage_count"] == 3
      assert updated["success_count"] == 2
      assert updated["failure_count"] == 1
    end

    test "returns not_found for non-existent id", %{memory_dir: dir} do
      assert {:error, :not_found} =
               Procedural.record_usage(dir, "00000000-0000-0000-0000-000000000000", :success)
    end

    test "promotes low to medium at 3 successes", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir, %{"confidence" => "low"})

      {:ok, _} = Procedural.record_usage(dir, fm["id"], :success)
      {:ok, _} = Procedural.record_usage(dir, fm["id"], :success)
      {:ok, updated} = Procedural.record_usage(dir, fm["id"], :success)

      assert updated["confidence"] == "medium"
    end

    test "promotes medium to high at 5 successes", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir, %{"confidence" => "medium"})

      for _ <- 1..4, do: Procedural.record_usage(dir, fm["id"], :success)
      {:ok, updated} = Procedural.record_usage(dir, fm["id"], :success)

      assert updated["confidence"] == "high"
    end

    test "demotes high to medium at 2 failures", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir, %{"confidence" => "high"})

      {:ok, _} = Procedural.record_usage(dir, fm["id"], :failure)
      {:ok, updated} = Procedural.record_usage(dir, fm["id"], :failure)

      assert updated["confidence"] == "medium"
    end

    test "demotes medium to low at 3 failures", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir, %{"confidence" => "medium"})

      {:ok, _} = Procedural.record_usage(dir, fm["id"], :failure)
      {:ok, _} = Procedural.record_usage(dir, fm["id"], :failure)
      {:ok, updated} = Procedural.record_usage(dir, fm["id"], :failure)

      assert updated["confidence"] == "low"
    end

    test "does not promote below threshold", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir, %{"confidence" => "low"})

      {:ok, _} = Procedural.record_usage(dir, fm["id"], :success)
      {:ok, updated} = Procedural.record_usage(dir, fm["id"], :success)

      assert updated["confidence"] == "low"
    end

    test "does not demote below threshold", %{memory_dir: dir} do
      {:ok, fm} = create_procedure(dir, %{"confidence" => "high"})

      {:ok, updated} = Procedural.record_usage(dir, fm["id"], :failure)
      assert updated["confidence"] == "high"
    end
  end

  # =====================
  # Scoring Helper Tests
  # =====================

  describe "tag_match_score/2" do
    test "returns 0 for empty query tags" do
      assert Procedural.tag_match_score(["deploy", "docker"], []) == 0.0
    end

    test "returns 1.0 for perfect match" do
      assert Procedural.tag_match_score(["deploy", "docker"], ["deploy", "docker"]) == 1.0
    end

    test "returns fraction for partial match" do
      assert Procedural.tag_match_score(["deploy", "docker"], ["deploy", "k8s"]) == 0.5
    end

    test "returns 0 for no match" do
      assert Procedural.tag_match_score(["deploy"], ["testing"]) == 0.0
    end
  end

  describe "confidence_score/1" do
    test "high returns 1.0" do
      assert Procedural.confidence_score("high") == 1.0
    end

    test "medium returns 0.6" do
      assert Procedural.confidence_score("medium") == 0.6
    end

    test "low returns 0.3" do
      assert Procedural.confidence_score("low") == 0.3
    end
  end

  describe "recency_score/1" do
    test "nil returns 0" do
      assert Procedural.recency_score(nil) == 0.0
    end

    test "recent timestamp returns high score" do
      recent = DateTime.utc_now() |> DateTime.to_iso8601()
      score = Procedural.recency_score(recent)
      assert score > 0.9
    end

    test "old timestamp returns low score" do
      old = DateTime.utc_now() |> DateTime.add(-80, :day) |> DateTime.to_iso8601()
      score = Procedural.recency_score(old)
      assert score < 0.2
    end

    test "90+ days ago returns 0" do
      very_old = DateTime.utc_now() |> DateTime.add(-100, :day) |> DateTime.to_iso8601()
      assert Procedural.recency_score(very_old) == 0.0
    end
  end

  describe "adjust_confidence/1" do
    test "promotes low to medium at 3 successes" do
      assert Procedural.adjust_confidence(%{
               "confidence" => "low",
               "success_count" => 3,
               "failure_count" => 0
             }) == "medium"
    end

    test "promotes medium to high at 5 successes" do
      assert Procedural.adjust_confidence(%{
               "confidence" => "medium",
               "success_count" => 5,
               "failure_count" => 0
             }) == "high"
    end

    test "demotes high to medium at 2 failures" do
      assert Procedural.adjust_confidence(%{
               "confidence" => "high",
               "success_count" => 10,
               "failure_count" => 2
             }) == "medium"
    end

    test "demotes medium to low at 3 failures" do
      assert Procedural.adjust_confidence(%{
               "confidence" => "medium",
               "success_count" => 0,
               "failure_count" => 3
             }) == "low"
    end

    test "keeps low when below promotion threshold" do
      assert Procedural.adjust_confidence(%{
               "confidence" => "low",
               "success_count" => 2,
               "failure_count" => 0
             }) == "low"
    end

    test "keeps high when below demotion threshold" do
      assert Procedural.adjust_confidence(%{
               "confidence" => "high",
               "success_count" => 10,
               "failure_count" => 1
             }) == "high"
    end
  end

  # =====================
  # Module Attribute Tests
  # =====================

  describe "procedure_types/0" do
    test "returns expected types" do
      types = Procedural.procedure_types()

      assert "workflow" in types
      assert "preference" in types
      assert "rule" in types
      assert "strategy" in types
      assert "tool_usage" in types
      assert length(types) == 5
    end
  end

  describe "confidence_levels/0" do
    test "returns expected levels" do
      levels = Procedural.confidence_levels()

      assert "high" in levels
      assert "medium" in levels
      assert "low" in levels
      assert length(levels) == 3
    end
  end

  describe "source_types/0" do
    test "returns expected sources" do
      sources = Procedural.source_types()

      assert "learned" in sources
      assert "taught" in sources
      assert "inferred" in sources
      assert length(sources) == 3
    end
  end
end
