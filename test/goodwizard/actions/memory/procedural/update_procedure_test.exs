defmodule Goodwizard.Actions.Memory.Procedural.UpdateProcedureTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.Procedural.UpdateProcedure
  alias Goodwizard.Memory.Procedural

  setup do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "update_procedure_test_#{:erlang.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    context = %{state: %{memory: %{memory_dir: tmp_dir}}}

    {:ok, procedure} =
      Procedural.create(
        tmp_dir,
        %{
          "type" => "workflow",
          "summary" => "Original summary",
          "source" => "learned",
          "confidence" => "medium",
          "tags" => ["orig"]
        },
        "## When to apply\n\nOriginal trigger\n\n## Steps\n\nOriginal steps\n\n## Notes\n\nOriginal notes"
      )

    %{memory_dir: tmp_dir, context: context, procedure: procedure}
  end

  test "updates summary only and preserves other fields and body", %{
    context: ctx,
    memory_dir: dir,
    procedure: procedure
  } do
    assert {:ok, %{procedure: updated}} =
             UpdateProcedure.run(%{id: procedure["id"], summary: "Updated summary"}, ctx)

    assert updated["summary"] == "Updated summary"
    assert updated["confidence"] == "medium"
    assert updated["tags"] == ["orig"]

    assert {:ok, {_fm, body}} = Procedural.read(dir, procedure["id"])
    assert body =~ "Original trigger"
    assert body =~ "Original steps"
    assert body =~ "Original notes"
  end

  test "updates body sections when provided", %{
    context: ctx,
    memory_dir: dir,
    procedure: procedure
  } do
    assert {:ok, %{procedure: _updated}} =
             UpdateProcedure.run(
               %{
                 id: procedure["id"],
                 when_to_apply: "After deployments",
                 steps: "1. Check logs\n2. Check metrics",
                 notes: "Prefer read-only checks first"
               },
               ctx
             )

    assert {:ok, {_fm, body}} = Procedural.read(dir, procedure["id"])
    assert body =~ "After deployments"
    assert body =~ "Check logs"
    assert body =~ "Prefer read-only checks first"
  end

  test "updates confidence", %{context: ctx, procedure: procedure} do
    assert {:ok, %{procedure: updated}} =
             UpdateProcedure.run(%{id: procedure["id"], confidence: "high"}, ctx)

    assert updated["confidence"] == "high"
  end

  test "returns error for nonexistent procedure", %{context: ctx} do
    assert {:error, message} =
             UpdateProcedure.run(
               %{id: "00000000-0000-0000-0000-000000000000", summary: "Nope"},
               ctx
             )

    assert message =~ "not found"
  end
end
