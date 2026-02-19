defmodule Goodwizard.Actions.Memory.Procedural.RecallProceduresTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.Procedural.RecallProcedures
  alias Goodwizard.Memory.Procedural

  setup do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "recall_procedures_test_#{:erlang.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    context = %{state: %{memory: %{memory_dir: tmp_dir}}}
    %{memory_dir: tmp_dir, context: context}
  end

  defp create_procedure(memory_dir, frontmatter_overrides, body) do
    base = %{
      "type" => "workflow",
      "summary" => "Default procedure",
      "source" => "learned",
      "confidence" => "medium",
      "tags" => []
    }

    Procedural.create(memory_dir, Map.merge(base, frontmatter_overrides), body)
  end

  test "recalls procedures for a situation", %{memory_dir: dir, context: ctx} do
    {:ok, _} =
      create_procedure(
        dir,
        %{"summary" => "Debug API failures", "tags" => ["api", "debug"]},
        "Check logs, inspect response, verify auth token"
      )

    {:ok, _} =
      create_procedure(
        dir,
        %{"summary" => "Review copy changes", "tags" => ["docs"]},
        "Check tone and consistency"
      )

    assert {:ok, %{procedures: procedures, count: 1}} =
             RecallProcedures.run(%{situation: "I need to debug an API failure", limit: 1}, ctx)

    assert hd(procedures)["summary"] == "Debug API failures"
    assert is_float(hd(procedures)["score"])
  end

  test "tag filter narrows results", %{memory_dir: dir, context: ctx} do
    {:ok, _} = create_procedure(dir, %{"summary" => "A", "tags" => ["api"]}, "A")
    {:ok, _} = create_procedure(dir, %{"summary" => "B", "tags" => ["ui"]}, "B")

    assert {:ok, %{procedures: procedures, count: 1}} =
             RecallProcedures.run(%{situation: "work", tags: ["api"]}, ctx)

    assert hd(procedures)["summary"] == "A"
  end

  test "type filter narrows results", %{memory_dir: dir, context: ctx} do
    {:ok, _} = create_procedure(dir, %{"summary" => "Rule proc", "type" => "rule"}, "Rule")

    {:ok, _} =
      create_procedure(dir, %{"summary" => "Workflow proc", "type" => "workflow"}, "Workflow")

    assert {:ok, %{procedures: procedures, count: 1}} =
             RecallProcedures.run(%{situation: "any", type: "rule"}, ctx)

    assert hd(procedures)["summary"] == "Rule proc"
  end

  test "respects limit", %{memory_dir: dir, context: ctx} do
    for i <- 1..4 do
      {:ok, _} =
        create_procedure(dir, %{"summary" => "Proc #{i}", "tags" => ["common"]}, "common terms")
    end

    assert {:ok, %{procedures: procedures, count: 2}} =
             RecallProcedures.run(%{situation: "common", limit: 2}, ctx)

    assert length(procedures) == 2
  end

  test "returns empty list from empty store", %{context: ctx} do
    assert {:ok, %{procedures: [], count: 0}} =
             RecallProcedures.run(%{situation: "anything"}, ctx)
  end
end
