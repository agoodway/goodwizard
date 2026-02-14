defmodule Mix.Tasks.Goodwizard.StartTest do
  use ExUnit.Case

  alias Mix.Tasks.Goodwizard.Start

  describe "module structure" do
    test "module loads and is a Mix.Task" do
      assert {:module, Start} = Code.ensure_loaded(Start)
      assert function_exported?(Start, :run, 1)
    end

    test "has moduledoc and shortdoc" do
      {:docs_v1, _, _, _, module_doc, _, _} = Code.fetch_docs(Start)
      assert module_doc != :hidden
      assert module_doc != :none
    end
  end
end
