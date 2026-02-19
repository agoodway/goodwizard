defmodule Goodwizard.Actions.Memory.Procedural.UseProcedureTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.Procedural.UseProcedure
  alias Goodwizard.Memory.Procedural

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "use_procedure_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    context = %{state: %{memory: %{memory_dir: tmp_dir}}}
    %{memory_dir: tmp_dir, context: context}
  end

  defp create_procedure(memory_dir, confidence) do
    Procedural.create(
      memory_dir,
      %{
        "type" => "workflow",
        "summary" => "Use procedure #{confidence}",
        "source" => "learned",
        "confidence" => confidence,
        "tags" => []
      },
      "## When to apply\n\nAny time\n\n## Steps\n\nDo thing"
    )
  end

  test "success increments usage_count and success_count", %{context: ctx, memory_dir: dir} do
    {:ok, procedure} = create_procedure(dir, "medium")

    assert {:ok, %{procedure: updated}} =
             UseProcedure.run(%{id: procedure["id"], outcome: "success"}, ctx)

    assert updated["usage_count"] == 1
    assert updated["success_count"] == 1
    assert is_binary(updated["last_used"])
  end

  test "failure increments usage_count and failure_count", %{context: ctx, memory_dir: dir} do
    {:ok, procedure} = create_procedure(dir, "medium")

    assert {:ok, %{procedure: updated}} =
             UseProcedure.run(%{id: procedure["id"], outcome: "failure"}, ctx)

    assert updated["usage_count"] == 1
    assert updated["failure_count"] == 1
    assert is_binary(updated["last_used"])
  end

  test "promotes confidence from low to medium after repeated successes", %{
    context: ctx,
    memory_dir: dir
  } do
    {:ok, procedure} = create_procedure(dir, "low")

    assert {:ok, _} = UseProcedure.run(%{id: procedure["id"], outcome: "success"}, ctx)
    assert {:ok, _} = UseProcedure.run(%{id: procedure["id"], outcome: "success"}, ctx)

    assert {:ok, %{procedure: updated}} =
             UseProcedure.run(%{id: procedure["id"], outcome: "success"}, ctx)

    assert updated["confidence"] == "medium"
  end

  test "demotes confidence from high to medium after repeated failures", %{
    context: ctx,
    memory_dir: dir
  } do
    {:ok, procedure} = create_procedure(dir, "high")

    assert {:ok, _} = UseProcedure.run(%{id: procedure["id"], outcome: "failure"}, ctx)

    assert {:ok, %{procedure: updated}} =
             UseProcedure.run(%{id: procedure["id"], outcome: "failure"}, ctx)

    assert updated["confidence"] == "medium"
  end

  test "returns not found for unknown id", %{context: ctx} do
    assert {:error, message} =
             UseProcedure.run(
               %{id: "00000000-0000-0000-0000-000000000000", outcome: "success"},
               ctx
             )

    assert message =~ "not found"
  end
end
