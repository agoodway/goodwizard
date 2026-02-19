defmodule Goodwizard.Actions.Memory.LoadContextTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.LoadContext
  alias Goodwizard.Memory.Episodic
  alias Goodwizard.Memory.Procedural

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "load_context_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    context = %{state: %{memory: %{memory_dir: tmp_dir}}}
    %{memory_dir: tmp_dir, context: context}
  end

  defp create_episode(memory_dir, summary, body, overrides \\ %{}) do
    frontmatter =
      Map.merge(
        %{
          "type" => "task_completion",
          "summary" => summary,
          "outcome" => "success",
          "tags" => []
        },
        overrides
      )

    Episodic.create(memory_dir, frontmatter, body)
  end

  defp create_procedure(memory_dir, summary, body, overrides \\ %{}) do
    frontmatter =
      Map.merge(
        %{
          "type" => "workflow",
          "summary" => summary,
          "source" => "learned",
          "confidence" => "medium",
          "tags" => []
        },
        overrides
      )

    Procedural.create(memory_dir, frontmatter, body)
  end

  test "returns recent episodes when no topic is provided", %{memory_dir: dir, context: ctx} do
    {:ok, _} = create_episode(dir, "First", "## Lessons\n\nLesson one")
    {:ok, _} = create_episode(dir, "Second", "## Lessons\n\nLesson two")

    assert {:ok, %{memory_context: context, episodes_loaded: 2}} =
             LoadContext.run(%{topic: ""}, ctx)

    assert context =~ "Relevant Past Experiences"
    assert context =~ "Second"
    assert context =~ "First"
  end

  test "topic-relevant episodes are included", %{memory_dir: dir, context: ctx} do
    {:ok, _} = create_episode(dir, "API auth failure", "## Lessons\n\nCheck auth headers")
    {:ok, _} = create_episode(dir, "UI polish", "## Lessons\n\nKeep spacing consistent")

    assert {:ok, %{memory_context: context, episodes_loaded: count}} =
             LoadContext.run(%{topic: "auth failure", max_episodes: 5}, ctx)

    assert count >= 1
    assert context =~ "API auth failure"
  end

  test "episode results are deduplicated by id", %{memory_dir: dir, context: ctx} do
    {:ok, _} =
      create_episode(dir, "Auth flow", "## Lessons\n\nUse token refresh", %{"tags" => ["auth"]})

    assert {:ok, %{episodes_loaded: count}} =
             LoadContext.run(%{topic: "auth", max_episodes: 5}, ctx)

    assert count == 1
  end

  test "episode count is capped by max_episodes", %{memory_dir: dir, context: ctx} do
    for i <- 1..8 do
      {:ok, _} = create_episode(dir, "Episode #{i}", "## Lessons\n\nL#{i}")
    end

    assert {:ok, %{episodes_loaded: 3}} =
             LoadContext.run(%{topic: "episode", max_episodes: 3}, ctx)
  end

  test "procedures use recall when topic is provided", %{memory_dir: dir, context: ctx} do
    {:ok, _} =
      create_procedure(
        dir,
        "Debug auth errors",
        "## When to apply\n\nWhen auth fails\n\n## Steps\n\nCheck token"
      )

    {:ok, _} =
      create_procedure(
        dir,
        "Review CSS",
        "## When to apply\n\nWhen styling issues appear\n\n## Steps\n\nInspect elements"
      )

    assert {:ok, %{memory_context: context, procedures_loaded: count}} =
             LoadContext.run(%{topic: "auth", max_procedures: 2}, ctx)

    assert count >= 1
    assert context =~ "Relevant Procedures"
    assert context =~ "Debug auth errors"
  end

  test "procedures fall back to list when topic is empty", %{memory_dir: dir, context: ctx} do
    {:ok, _} =
      create_procedure(
        dir,
        "High usage",
        "## When to apply\n\nAlways\n\n## Steps\n\nA",
        %{"confidence" => "high", "usage_count" => 10}
      )

    {:ok, _} =
      create_procedure(
        dir,
        "Low usage",
        "## When to apply\n\nSometimes\n\n## Steps\n\nB",
        %{"confidence" => "low", "usage_count" => 1}
      )

    assert {:ok, %{procedures_loaded: 2}} = LoadContext.run(%{topic: ""}, ctx)
  end

  test "procedure count is capped by max_procedures", %{memory_dir: dir, context: ctx} do
    for i <- 1..5 do
      {:ok, _} =
        create_procedure(
          dir,
          "Procedure #{i}",
          "## When to apply\n\nCondition #{i}\n\n## Steps\n\nDo #{i}"
        )
    end

    assert {:ok, %{procedures_loaded: 2}} = LoadContext.run(%{topic: "", max_procedures: 2}, ctx)
  end

  test "empty episodic store omits episode section", %{memory_dir: dir, context: ctx} do
    {:ok, _} =
      create_procedure(
        dir,
        "Only procedure",
        "## When to apply\n\nWhen needed\n\n## Steps\n\nDo it"
      )

    assert {:ok, %{memory_context: context, episodes_loaded: 0, procedures_loaded: 1}} =
             LoadContext.run(%{topic: ""}, ctx)

    refute context =~ "Relevant Past Experiences"
    assert context =~ "Relevant Procedures"
  end

  test "empty procedural store omits procedures section", %{memory_dir: dir, context: ctx} do
    {:ok, _} = create_episode(dir, "Only episode", "## Lessons\n\nLesson")

    assert {:ok, %{memory_context: context, episodes_loaded: 1, procedures_loaded: 0}} =
             LoadContext.run(%{topic: ""}, ctx)

    assert context =~ "Relevant Past Experiences"
    refute context =~ "Relevant Procedures"
  end

  test "both stores empty returns empty context string", %{context: ctx} do
    assert {:ok, %{memory_context: "", episodes_loaded: 0, procedures_loaded: 0}} =
             LoadContext.run(%{topic: ""}, ctx)
  end

  test "episode markdown includes timestamp type outcome summary and key lesson", %{
    memory_dir: dir,
    context: ctx
  } do
    {:ok, episode} =
      create_episode(
        dir,
        "Ship release",
        "## Observation\n\nRelease build\n\n## Lessons\n\nRun smoke tests first"
      )

    assert {:ok, %{memory_context: context}} = LoadContext.run(%{topic: "release"}, ctx)

    assert context =~ episode["timestamp"]
    assert context =~ "task_completion"
    assert context =~ "success"
    assert context =~ "Ship release"
    assert context =~ "Run smoke tests first"
  end

  test "procedure markdown includes summary confidence and when-to-apply", %{
    memory_dir: dir,
    context: ctx
  } do
    {:ok, _} =
      create_procedure(
        dir,
        "Use focused test runs",
        "## When to apply\n\nWhen debugging failures\n\n## Steps\n\nRun single file",
        %{"confidence" => "high"}
      )

    assert {:ok, %{memory_context: context}} = LoadContext.run(%{topic: ""}, ctx)

    assert context =~ "Use focused test runs"
    assert context =~ "Confidence: high"
    assert context =~ "When to apply: When debugging failures"
  end
end
