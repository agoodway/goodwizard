defmodule Goodwizard.Actions.Memory.Procedural.LearnProcedureTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.Procedural.LearnProcedure
  alias Goodwizard.Memory.Procedural

  @valid_params %{
    type: "workflow",
    summary: "Use ripgrep before editing",
    source: "learned",
    when_to_apply: "Before changing code in unfamiliar areas",
    steps: "1. Search symbols\n2. Read target file\n3. Make minimal edits"
  }

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "learn_procedure_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    context = %{state: %{memory: %{memory_dir: tmp_dir}}}
    %{memory_dir: tmp_dir, context: context}
  end

  test "creates procedure with required params", %{context: ctx} do
    assert {:ok, %{procedure: procedure, message: message}} =
             LearnProcedure.run(@valid_params, ctx)

    assert procedure["type"] == "workflow"
    assert procedure["source"] == "learned"
    assert procedure["confidence"] == "medium"
    assert procedure["usage_count"] == 0
    assert is_binary(procedure["id"])
    assert is_binary(procedure["created_at"])
    assert is_binary(procedure["updated_at"])
    assert message == "Procedure learned: Use ripgrep before editing"
  end

  test "writes body with when_to_apply, steps, and notes", %{memory_dir: dir, context: ctx} do
    params = Map.put(@valid_params, :notes, "Prefer fast scans in large repos")

    assert {:ok, %{procedure: procedure}} = LearnProcedure.run(params, ctx)
    assert {:ok, {_fm, body}} = Procedural.read(dir, procedure["id"])

    assert body =~ "## When to apply"
    assert body =~ "## Steps"
    assert body =~ "## Notes"
    assert body =~ "Prefer fast scans in large repos"
  end

  test "truncates summary at 200 characters", %{context: ctx} do
    params = Map.put(@valid_params, :summary, String.duplicate("a", 220))

    assert {:ok, %{procedure: procedure}} = LearnProcedure.run(params, ctx)
    assert String.length(procedure["summary"]) == 200
  end

  test "defaults confidence to medium", %{context: ctx} do
    assert {:ok, %{procedure: procedure}} = LearnProcedure.run(@valid_params, ctx)
    assert procedure["confidence"] == "medium"
  end
end
