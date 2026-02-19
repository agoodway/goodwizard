defmodule Goodwizard.Actions.Memory.Procedural.ListProceduresTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.Procedural.ListProcedures
  alias Goodwizard.Memory.Procedural

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "list_procedures_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    context = %{state: %{memory: %{memory_dir: tmp_dir}}}
    %{memory_dir: tmp_dir, context: context}
  end

  defp create_procedure(memory_dir, overrides) do
    base = %{
      "type" => "workflow",
      "summary" => "Default procedure",
      "source" => "learned",
      "confidence" => "medium"
    }

    Procedural.create(
      memory_dir,
      Map.merge(base, overrides),
      "## When to apply\n\nAny\n\n## Steps\n\nDo"
    )
  end

  test "lists procedures", %{memory_dir: dir, context: ctx} do
    {:ok, _} = create_procedure(dir, %{"summary" => "Proc A"})
    {:ok, _} = create_procedure(dir, %{"summary" => "Proc B"})

    assert {:ok, %{procedures: procedures, count: 2}} = ListProcedures.run(%{}, ctx)
    assert length(procedures) == 2
  end

  test "filters by type", %{memory_dir: dir, context: ctx} do
    {:ok, _} = create_procedure(dir, %{"summary" => "Workflow", "type" => "workflow"})
    {:ok, _} = create_procedure(dir, %{"summary" => "Rule", "type" => "rule"})

    assert {:ok, %{procedures: procedures, count: 1}} =
             ListProcedures.run(%{type: "rule"}, ctx)

    assert hd(procedures)["summary"] == "Rule"
  end

  test "filters by minimum confidence", %{memory_dir: dir, context: ctx} do
    {:ok, _} = create_procedure(dir, %{"summary" => "Low", "confidence" => "low"})
    {:ok, _} = create_procedure(dir, %{"summary" => "High", "confidence" => "high"})

    assert {:ok, %{procedures: procedures, count: 1}} =
             ListProcedures.run(%{confidence: "high"}, ctx)

    assert hd(procedures)["summary"] == "High"
  end

  test "respects limit", %{memory_dir: dir, context: ctx} do
    for i <- 1..5 do
      {:ok, _} = create_procedure(dir, %{"summary" => "Proc #{i}"})
    end

    assert {:ok, %{procedures: procedures, count: 2}} =
             ListProcedures.run(%{limit: 2}, ctx)

    assert length(procedures) == 2
  end

  test "returns empty list from empty directory", %{context: ctx} do
    assert {:ok, %{procedures: [], count: 0}} = ListProcedures.run(%{}, ctx)
  end
end
