defmodule Goodwizard.Actions.Memory.ConsolidateTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.Consolidate
  alias Goodwizard.Memory.Episodic
  alias Goodwizard.Memory.Procedural

  defp tmp_memory_dir do
    dir = Path.join(System.tmp_dir!(), "test_memory_cons_#{:rand.uniform(100_000)}")
    File.mkdir_p!(dir)
    dir
  end

  defp set_llm_response(response) do
    Process.put({Consolidate, :test_llm_response}, Jason.encode!(response))
  end

  defp make_messages(count) do
    for i <- 1..count do
      %{
        role: if(rem(i, 2) == 1, do: "user", else: "assistant"),
        content: "Message #{i}",
        timestamp: "2026-01-01T00:00:#{String.pad_leading(to_string(i), 2, "0")}Z"
      }
    end
  end

  describe "no consolidation needed" do
    test "returns unchanged when messages under window" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      messages = make_messages(5)

      assert {:ok, %{consolidated: false, messages: ^messages}} =
               Consolidate.run(
                 %{memory_dir: dir, messages: messages, memory_window: 10, current_memory: ""},
                 %{}
               )
    end

    test "returns unchanged when messages equal to window" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      messages = make_messages(10)

      assert {:ok, %{consolidated: false}} =
               Consolidate.run(
                 %{memory_dir: dir, messages: messages, memory_window: 10, current_memory: ""},
                 %{}
               )
    end
  end

  describe "enhanced consolidation" do
    test "creates episodes and procedural insights and writes audit log" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      messages = make_messages(15)

      set_llm_response(%{
        "episodes" => [
          %{
            "type" => "problem_solved",
            "summary" => "Fixed flaky test setup",
            "outcome" => "success",
            "observation" => "Tests failed intermittently",
            "approach" => "Switched to isolated tmp dirs",
            "result" => "Stable test runs",
            "lessons" => "Avoid shared temp state",
            "tags" => ["test", "stability"]
          }
        ],
        "memory_profile_update" => "User values deterministic testing and isolated fixtures.",
        "procedural_insights" => [
          %{
            "type" => "rule",
            "summary" => "Use isolated tmp directories in tests",
            "when_to_apply" => "When writing filesystem-based tests",
            "steps" => "1. Create unique tmp dir\n2. Clean up on exit",
            "tags" => ["test", "filesystem"],
            "notes" => "Prevents cross-test interference"
          }
        ]
      })

      assert {:ok, result} =
               Consolidate.run(
                 %{
                   memory_dir: dir,
                   messages: messages,
                   memory_window: 10,
                   current_memory: "existing memory"
                 },
                 %{}
               )

      assert result.consolidated
      assert result.episodes_created == 1
      assert result.procedures_created == 1
      assert result.procedures_updated == 0
      assert result.episodes_failed == 0
      assert result.procedures_failed == 0
      assert length(result.messages) == 10
      assert result.memory_content =~ "deterministic testing"

      assert {:ok, episodes} = Episodic.list(dir, limit: 10)
      assert length(episodes) == 1

      {:ok, {_fm, episode_body}} = Episodic.read(dir, hd(episodes)["id"])
      assert episode_body =~ "Extracted during consolidation"

      assert {:ok, procedures} = Procedural.list(dir, limit: 10)
      assert length(procedures) == 1
      assert hd(procedures)["source"] == "learned"
      assert hd(procedures)["confidence"] == "medium"

      history = File.read!(Path.join(dir, "HISTORY.md"))
      assert history =~ "Consolidation"
      assert history =~ "Extracted 1 episodes"
      assert history =~ "Use isolated tmp directories in tests"
    end

    test "updates an existing procedure when updates_existing is provided" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      {:ok, existing} =
        Procedural.create(
          dir,
          %{
            "type" => "workflow",
            "summary" => "Original procedure",
            "source" => "learned",
            "confidence" => "medium",
            "tags" => ["orig"]
          },
          "## When to apply\n\nOriginal\n\n## Steps\n\nDo original"
        )

      set_llm_response(%{
        "episodes" => [],
        "memory_profile_update" => "No semantic changes.",
        "procedural_insights" => [
          %{
            "type" => "workflow",
            "summary" => "Updated procedure",
            "when_to_apply" => "When debugging",
            "steps" => "1. Check logs",
            "updates_existing" => existing["id"],
            "tags" => ["debug"]
          }
        ]
      })

      assert {:ok, result} =
               Consolidate.run(
                 %{
                   memory_dir: dir,
                   messages: make_messages(15),
                   memory_window: 10,
                   current_memory: ""
                 },
                 %{}
               )

      assert result.procedures_created == 0
      assert result.procedures_updated == 1

      assert {:ok, {updated, body}} = Procedural.read(dir, existing["id"])
      assert updated["summary"] == "Updated procedure"
      assert body =~ "When debugging"
    end

    test "defaults missing arrays to empty and still updates MEMORY.md" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      set_llm_response(%{
        "memory_profile_update" =>
          "Semantic profile updated with no episodic/procedural extraction."
      })

      assert {:ok, result} =
               Consolidate.run(
                 %{
                   memory_dir: dir,
                   messages: make_messages(15),
                   memory_window: 10,
                   current_memory: ""
                 },
                 %{}
               )

      assert result.consolidated
      assert result.episodes_created == 0
      assert result.procedures_created == 0
      assert result.procedures_updated == 0

      assert File.read!(Path.join(dir, "MEMORY.md")) =~ "no episodic/procedural extraction"
    end

    test "existing procedures are included in the LLM prompt" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      {:ok, existing} =
        Procedural.create(
          dir,
          %{
            "type" => "strategy",
            "summary" => "Use grep before editing",
            "source" => "learned",
            "confidence" => "medium",
            "tags" => ["search", "workflow"]
          },
          "## When to apply\n\nBefore edits\n\n## Steps\n\nSearch first"
        )

      set_llm_response(%{
        "episodes" => [],
        "memory_profile_update" => "noop",
        "procedural_insights" => []
      })

      assert {:ok, _result} =
               Consolidate.run(
                 %{
                   memory_dir: dir,
                   messages: make_messages(15),
                   memory_window: 10,
                   current_memory: ""
                 },
                 %{}
               )

      prompt = Process.get({Consolidate, :last_prompt})
      assert is_binary(prompt)
      assert prompt =~ existing["id"]
      assert prompt =~ "Use grep before editing"
      assert prompt =~ "updates_existing"
    end

    test "episode write failure does not block other writes" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      set_llm_response(%{
        "episodes" => [
          %{
            "type" => "invalid_type",
            "summary" => "Bad episode",
            "outcome" => "success",
            "observation" => "o",
            "approach" => "a",
            "result" => "r"
          },
          %{
            "type" => "task_completion",
            "summary" => "Good episode",
            "outcome" => "success",
            "observation" => "o",
            "approach" => "a",
            "result" => "r"
          }
        ],
        "memory_profile_update" => "memory still updates",
        "procedural_insights" => []
      })

      assert {:ok, result} =
               Consolidate.run(
                 %{
                   memory_dir: dir,
                   messages: make_messages(15),
                   memory_window: 10,
                   current_memory: ""
                 },
                 %{}
               )

      assert result.consolidated
      assert result.episodes_created == 1
      assert result.episodes_failed == 1
      assert File.read!(Path.join(dir, "MEMORY.md")) =~ "memory still updates"
    end
  end
end
