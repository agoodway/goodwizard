defmodule Goodwizard.Actions.Memory.Episodic.SearchEpisodesTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.Episodic.SearchEpisodes
  alias Goodwizard.Memory.Episodic

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "search_episodes_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    context = %{state: %{memory: %{memory_dir: tmp_dir}}}
    %{memory_dir: tmp_dir, context: context}
  end

  defp create_episode(memory_dir, overrides \\ %{}, body \\ "## Observation\n\nTest episode") do
    base = %{
      "type" => "task_completion",
      "summary" => "Default summary",
      "outcome" => "success"
    }

    Episodic.create(memory_dir, Map.merge(base, overrides), body)
  end

  describe "search by text query" do
    test "finds episodes matching query in body", %{memory_dir: dir, context: ctx} do
      create_episode(dir, %{"summary" => "Login fix"}, "## Observation\n\nFixed the login bug")
      create_episode(dir, %{"summary" => "Deploy fix"}, "## Observation\n\nFixed deployment")

      assert {:ok, %{episodes: episodes, count: 1}} =
               SearchEpisodes.run(%{query: "login bug"}, ctx)

      assert hd(episodes)["summary"] == "Login fix"
    end

    test "search is case-insensitive", %{memory_dir: dir, context: ctx} do
      create_episode(
        dir,
        %{"summary" => "ELIXIR upgrade"},
        "## Observation\n\nUpgraded ELIXIR version"
      )

      assert {:ok, %{episodes: [_], count: 1}} =
               SearchEpisodes.run(%{query: "elixir"}, ctx)
    end

    test "returns empty list when no matches", %{memory_dir: dir, context: ctx} do
      create_episode(dir, %{"summary" => "Something else"})

      assert {:ok, %{episodes: [], count: 0}} =
               SearchEpisodes.run(%{query: "nonexistent topic"}, ctx)
    end
  end

  describe "search with filters" do
    test "filters by tags", %{memory_dir: dir, context: ctx} do
      create_episode(dir, %{"summary" => "Auth fix", "tags" => ["auth"]})
      create_episode(dir, %{"summary" => "UI fix", "tags" => ["ui"]})
      create_episode(dir, %{"summary" => "Auth refactor", "tags" => ["auth", "refactor"]})

      assert {:ok, %{episodes: episodes, count: 2}} =
               SearchEpisodes.run(%{tags: ["auth"]}, ctx)

      summaries = Enum.map(episodes, & &1["summary"])
      assert "Auth fix" in summaries
      assert "Auth refactor" in summaries
    end

    test "filters by type", %{memory_dir: dir, context: ctx} do
      create_episode(dir, %{"summary" => "Task done", "type" => "task_completion"})
      create_episode(dir, %{"summary" => "Problem solved", "type" => "problem_solved"})

      assert {:ok, %{episodes: [episode], count: 1}} =
               SearchEpisodes.run(%{type: "problem_solved"}, ctx)

      assert episode["summary"] == "Problem solved"
    end

    test "filters by outcome", %{memory_dir: dir, context: ctx} do
      create_episode(dir, %{"summary" => "Success", "outcome" => "success"})
      create_episode(dir, %{"summary" => "Failure", "outcome" => "failure"})

      assert {:ok, %{episodes: [episode], count: 1}} =
               SearchEpisodes.run(%{outcome: "failure"}, ctx)

      assert episode["summary"] == "Failure"
    end

    test "combines text query with filters", %{memory_dir: dir, context: ctx} do
      create_episode(
        dir,
        %{"summary" => "Auth success", "tags" => ["auth"], "outcome" => "success"},
        "## Observation\n\nFixed auth bug"
      )

      create_episode(
        dir,
        %{"summary" => "Auth failure", "tags" => ["auth"], "outcome" => "failure"},
        "## Observation\n\nAuth bug persisted"
      )

      assert {:ok, %{episodes: [episode], count: 1}} =
               SearchEpisodes.run(%{query: "auth bug", outcome: "success"}, ctx)

      assert episode["summary"] == "Auth success"
    end
  end

  describe "search limit" do
    test "respects limit parameter", %{memory_dir: dir, context: ctx} do
      for i <- 1..5 do
        create_episode(dir, %{"summary" => "Episode #{i}"})
      end

      assert {:ok, %{episodes: episodes, count: 3}} =
               SearchEpisodes.run(%{limit: 3}, ctx)

      assert length(episodes) == 3
    end
  end

  describe "empty store" do
    test "returns empty list from empty store", %{context: ctx} do
      assert {:ok, %{episodes: [], count: 0}} =
               SearchEpisodes.run(%{query: "anything"}, ctx)
    end
  end
end
