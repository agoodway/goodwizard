defmodule Goodwizard.Actions.Brain.RefreshToolsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Goodwizard.Actions.Brain.RefreshTools

  @test_schema %{
    "$schema" => "http://json-schema.org/draft-07/schema#",
    "title" => "Person",
    "type" => "object",
    "required" => ["id", "name"],
    "properties" => %{
      "id" => %{"type" => "string"},
      "name" => %{"type" => "string"},
      "created_at" => %{"type" => "string"},
      "updated_at" => %{"type" => "string"}
    }
  }

  setup do
    workspace = Path.join(System.tmp_dir!(), "refresh_tools_test_#{:rand.uniform(100_000)}")
    schemas_dir = Path.join([workspace, "knowledge_base", "schemas"])
    File.mkdir_p!(schemas_dir)
    on_exit(fn -> File.rm_rf!(workspace) end)

    context = %{state: %{workspace: workspace}}
    %{workspace: workspace, schemas_dir: schemas_dir, context: context}
  end

  describe "run/2" do
    test "regenerates knowledge base tools and logs legacy deprecation warning", %{
      schemas_dir: schemas_dir,
      context: context
    } do
      File.write!(Path.join(schemas_dir, "people.json"), Jason.encode!(@test_schema))

      log =
        capture_log(fn ->
          assert {:ok, result} = RefreshTools.run(%{}, context)
          assert result.message =~ "2 knowledge base tools"
          assert length(result.tools) == 2
          assert "create_person" in result.tools
          assert "update_person" in result.tools
        end)

      assert log =~ "DEPRECATION"
      assert log =~ "refresh_brain_tools"
    end

    test "returns zero tools when no schemas exist", %{context: context} do
      assert {:ok, result} = RefreshTools.run(%{}, context)
      assert result.message =~ "0 knowledge base tools"
      assert result.tools == []
    end

    test "returns actionable error after legacy cutoff", %{context: context} do
      cutoff_context = put_in(context, [:state, :legacy_brain_aliases_until], "2000-01-01")

      assert {:error, message} = RefreshTools.run(%{}, cutoff_context)
      assert message =~ "no longer supported"
      assert message =~ "refresh_knowledge_base_tools"
    end

    test "works without workspace in context state" do
      # Falls back to Goodwizard.Config.workspace()
      empty_context = %{state: %{}}
      result = RefreshTools.run(%{}, empty_context)
      assert {:ok, _} = result
    end
  end
end
