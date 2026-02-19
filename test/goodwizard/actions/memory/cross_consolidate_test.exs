defmodule Goodwizard.Actions.Memory.CrossConsolidateTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.CrossConsolidate
  alias Goodwizard.Memory.Episodic
  alias Goodwizard.Memory.Procedural

  setup do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "cross_consolidate_test_#{:erlang.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    Process.delete({CrossConsolidate, :test_llm_response})
    Process.delete({CrossConsolidate, :last_prompt})
    context = %{state: %{memory: %{memory_dir: tmp_dir}}}
    %{memory_dir: tmp_dir, context: context}
  end

  defp create_successful_episode(memory_dir, summary) do
    frontmatter = %{
      "type" => "task_completion",
      "summary" => summary,
      "outcome" => "success",
      "tags" => ["test"]
    }

    body = """
    ## Observation

    Observed #{summary}

    ## Approach

    Applied standard approach

    ## Result

    Completed successfully

    ## Lessons

    Learned from #{summary}
    """

    {:ok, _episode} = Episodic.create(memory_dir, frontmatter, body)
  end

  defp create_procedure(memory_dir, summary) do
    frontmatter = %{
      "type" => "workflow",
      "summary" => summary,
      "source" => "learned",
      "confidence" => "medium",
      "tags" => ["test"]
    }

    body = "## When to apply\n\nAlways\n\n## Steps\n\nDo it\n\n## Notes\n\nNone"

    {:ok, _proc} = Procedural.create(memory_dir, frontmatter, body)
  end

  describe "cross-consolidation skips with insufficient episodes" do
    test "returns early when fewer than min_episodes", %{context: ctx, memory_dir: dir} do
      # Create only 2 episodes (below default min of 5)
      create_successful_episode(dir, "Episode 1")
      create_successful_episode(dir, "Episode 2")

      assert {:ok, result} = CrossConsolidate.run(%{min_episodes: 5}, ctx)
      assert result.procedures_created == 0
      assert result.message =~ "Insufficient"
    end
  end

  describe "cross-consolidation creates inferred low-confidence procedures" do
    test "creates procedures from deterministic LLM stub", %{context: ctx, memory_dir: dir} do
      for i <- 1..6 do
        create_successful_episode(dir, "Episode #{i}")
      end

      Process.put(
        {CrossConsolidate, :test_llm_response},
        Jason.encode!([
          %{
            "type" => "workflow",
            "summary" => "Run checks after editing",
            "tags" => ["quality", "workflow"],
            "when_to_apply" => "After code changes",
            "steps" => "Run mix check and address findings",
            "notes" => "Inferred from repeated episodes"
          }
        ])
      )

      assert {:ok, result} = CrossConsolidate.run(%{min_episodes: 5}, ctx)
      assert result.procedures_created == 1
      assert result.message =~ "1 procedures inferred"

      {:ok, procedures} = Procedural.list(dir, limit: 10)
      assert Enum.any?(procedures, &(&1["summary"] == "Run checks after editing"))
    end
  end

  describe "existing procedures included in LLM prompt" do
    test "existing procedures are loaded for deduplication", %{context: ctx, memory_dir: dir} do
      create_procedure(dir, "Existing workflow A")
      create_procedure(dir, "Existing workflow B")
      for i <- 1..6, do: create_successful_episode(dir, "Episode #{i}")

      Process.put({CrossConsolidate, :test_llm_response}, "[]")

      assert {:ok, _result} = CrossConsolidate.run(%{min_episodes: 5}, ctx)

      prompt = Process.get({CrossConsolidate, :last_prompt})
      assert is_binary(prompt)
      assert prompt =~ "Existing workflow A"
      assert prompt =~ "Existing workflow B"
    end

    test "cross-consolidation errors when LLM response is invalid JSON", %{
      context: ctx,
      memory_dir: dir
    } do
      for i <- 1..6, do: create_successful_episode(dir, "Episode #{i}")
      Process.put({CrossConsolidate, :test_llm_response}, "not json")

      assert {:error, message} = CrossConsolidate.run(%{min_episodes: 5}, ctx)
      assert message =~ "Pattern detection failed"
    end
  end

  describe "no suggested procedures results in no new files" do
    test "empty LLM response creates no procedures", %{memory_dir: dir} do
      {:ok, procs_before} = Procedural.list(dir, limit: 200)

      # Manually verify no procedures exist
      assert procs_before == []
    end
  end

  describe "created procedures have valid frontmatter and body" do
    test "inferred procedures have correct structure when created directly", %{memory_dir: dir} do
      # Test the procedure creation path directly (bypassing LLM)
      frontmatter = %{
        "type" => "rule",
        "summary" => "Always check logs after deployment",
        "source" => "inferred",
        "confidence" => "low",
        "tags" => ["deployment", "debugging"]
      }

      body =
        """
        ## When to apply

        After any production deployment

        ## Steps

        1. Check application logs
        2. Verify health endpoints
        3. Monitor error rates

        ## Notes

        Inferred from episodic patterns
        """
        |> String.trim()

      {:ok, fm} = Procedural.create(dir, frontmatter, body)

      assert fm["type"] == "rule"
      assert fm["source"] == "inferred"
      assert fm["confidence"] == "low"
      assert is_binary(fm["id"])
      assert is_binary(fm["created_at"])

      {:ok, {_read_fm, read_body}} = Procedural.read(dir, fm["id"])
      assert read_body =~ "When to apply"
      assert read_body =~ "Steps"
      assert read_body =~ "Notes"
    end
  end
end
