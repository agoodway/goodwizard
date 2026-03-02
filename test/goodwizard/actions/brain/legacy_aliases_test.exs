defmodule Goodwizard.Actions.Brain.LegacyAliasesTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Goodwizard.Actions.Brain.CreateEntity
  alias Goodwizard.Actions.Brain.Legacy.CreateEntity, as: LegacyCreateEntity
  alias Goodwizard.Actions.Brain.Legacy.ListEntities, as: LegacyListEntities

  setup do
    workspace = Path.join(System.tmp_dir!(), "brain_legacy_aliases_#{:rand.uniform(100_000)}")
    on_exit(fn -> File.rm_rf!(workspace) end)
    %{context: %{state: %{workspace: workspace}}}
  end

  test "legacy create alias routes to canonical behavior with deprecation warning", %{
    context: context
  } do
    params = %{entity_type: "people", data: %{"name" => "Alice"}, body: ""}

    log =
      capture_log(fn ->
        assert {:ok, result} = LegacyCreateEntity.run(params, context)
        assert is_binary(result.id)
        assert result.data["name"] == "Alice"
      end)

    assert log =~ "DEPRECATION"
    assert log =~ "create_brain_entity"
    assert log =~ "create_entity"
  end

  test "legacy aliases are rejected after configured cutoff", %{context: context} do
    cutoff_context = put_in(context, [:state, :legacy_brain_aliases_until], "2000-01-01")

    params = %{entity_type: "people", data: %{"name" => "Bob"}, body: ""}

    assert {:error, message} = LegacyCreateEntity.run(params, cutoff_context)
    assert message =~ "no longer supported"
    assert message =~ "create_entity"
    assert message =~ "knowledge base / kb"
  end

  test "legacy list alias resolves to canonical list behavior", %{context: context} do
    assert {:ok, _} =
             CreateEntity.run(
               %{entity_type: "people", data: %{"name" => "Charlie"}, body: ""},
               context
             )

    assert {:ok, %{entities: entities}} =
             LegacyListEntities.run(%{entity_type: "people"}, context)

    assert Enum.any?(entities, &(&1.data["name"] == "Charlie"))
  end
end
