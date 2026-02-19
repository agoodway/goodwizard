defmodule Goodwizard.Actions.Memory.Episodic.ListEpisodesTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.Episodic.ListEpisodes
  alias Goodwizard.Memory.Episodic

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "list_episodes_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    context = %{state: %{memory: %{memory_dir: tmp_dir}}}
    %{memory_dir: tmp_dir, context: context}
  end

  defp create_episode(memory_dir, overrides \\ %{}) do
    base = %{
      "type" => "task_completion",
      "summary" => "Default summary",
      "outcome" => "success"
    }

    Episodic.create(memory_dir, Map.merge(base, overrides), "## Observation\n\nTest")
  end

  describe "listing episodes" do
    test "returns episodes sorted by timestamp descending", %{memory_dir: dir, context: ctx} do
      {:ok, _} = create_episode(dir, %{"summary" => "First"})
      Process.sleep(10)
      {:ok, _} = create_episode(dir, %{"summary" => "Second"})
      Process.sleep(10)
      {:ok, _} = create_episode(dir, %{"summary" => "Third"})

      assert {:ok, %{episodes: episodes, count: 3}} = ListEpisodes.run(%{}, ctx)

      summaries = Enum.map(episodes, & &1["summary"])
      assert hd(summaries) == "Third"
      assert List.last(summaries) == "First"
    end

    test "respects limit parameter", %{memory_dir: dir, context: ctx} do
      for i <- 1..5 do
        create_episode(dir, %{"summary" => "Episode #{i}"})
      end

      assert {:ok, %{episodes: episodes, count: 2}} = ListEpisodes.run(%{limit: 2}, ctx)

      assert length(episodes) == 2
    end

    test "defaults limit to 20", %{memory_dir: dir, context: ctx} do
      for i <- 1..25 do
        create_episode(dir, %{"summary" => "Episode #{i}"})
      end

      assert {:ok, %{episodes: episodes, count: 20}} = ListEpisodes.run(%{}, ctx)

      assert length(episodes) == 20
    end
  end

  describe "filtering" do
    test "filters by type", %{memory_dir: dir, context: ctx} do
      create_episode(dir, %{"summary" => "Task", "type" => "task_completion"})
      create_episode(dir, %{"summary" => "Problem", "type" => "problem_solved"})
      create_episode(dir, %{"summary" => "Decision", "type" => "decision_made"})

      assert {:ok, %{episodes: [episode], count: 1}} =
               ListEpisodes.run(%{type: "problem_solved"}, ctx)

      assert episode["summary"] == "Problem"
    end

    test "filters by outcome", %{memory_dir: dir, context: ctx} do
      create_episode(dir, %{"summary" => "Win", "outcome" => "success"})
      create_episode(dir, %{"summary" => "Lose", "outcome" => "failure"})

      assert {:ok, %{episodes: [episode], count: 1}} =
               ListEpisodes.run(%{outcome: "failure"}, ctx)

      assert episode["summary"] == "Lose"
    end

    test "combines type and outcome filters", %{memory_dir: dir, context: ctx} do
      create_episode(dir, %{"summary" => "A", "type" => "task_completion", "outcome" => "success"})

      create_episode(dir, %{"summary" => "B", "type" => "task_completion", "outcome" => "failure"})

      create_episode(dir, %{"summary" => "C", "type" => "problem_solved", "outcome" => "success"})

      assert {:ok, %{episodes: [episode], count: 1}} =
               ListEpisodes.run(%{type: "task_completion", outcome: "failure"}, ctx)

      assert episode["summary"] == "B"
    end
  end

  describe "empty store" do
    test "returns empty list from empty store", %{context: ctx} do
      assert {:ok, %{episodes: [], count: 0}} = ListEpisodes.run(%{}, ctx)
    end
  end
end
