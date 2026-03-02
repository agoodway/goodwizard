defmodule Goodwizard.Brain.PathsTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain.Paths

  @workspace "/tmp/test_workspace"

  describe "knowledge_base_dir/1" do
    test "returns knowledge base directory under workspace" do
      assert Paths.knowledge_base_dir(@workspace) == "/tmp/test_workspace/knowledge_base"
    end
  end

  describe "legacy_brain_dir/1" do
    test "returns legacy brain directory under workspace" do
      assert Paths.legacy_brain_dir(@workspace) == "/tmp/test_workspace/brain"
    end
  end

  describe "brain_dir/1" do
    test "returns canonical knowledge base directory under workspace" do
      assert Paths.brain_dir(@workspace) == "/tmp/test_workspace/knowledge_base"
    end
  end

  describe "schemas_dir/1" do
    test "returns schemas directory under knowledge base" do
      assert Paths.schemas_dir(@workspace) == "/tmp/test_workspace/knowledge_base/schemas"
    end
  end

  describe "entity_type_dir/2" do
    test "returns entity type directory" do
      assert {:ok, "/tmp/test_workspace/knowledge_base/people"} =
               Paths.entity_type_dir(@workspace, "people")
    end

    test "rejects path traversal with .." do
      assert {:error, "entity type contains path traversal"} =
               Paths.entity_type_dir(@workspace, "..")
    end

    test "rejects absolute paths" do
      assert {:error, "entity type must be relative"} =
               Paths.entity_type_dir(@workspace, "/etc/passwd")
    end

    test "rejects null bytes" do
      assert {:error, "entity type contains null bytes"} =
               Paths.entity_type_dir(@workspace, "people\0evil")
    end

    test "rejects forward slashes in segment" do
      assert {:error, "entity type contains path separator"} =
               Paths.entity_type_dir(@workspace, "people/evil")
    end

    test "rejects backslashes in segment" do
      assert {:error, "entity type contains path separator"} =
               Paths.entity_type_dir(@workspace, "people\\evil")
    end
  end

  describe "entity_path/3" do
    test "returns entity file path with .md extension" do
      assert {:ok,
              "/tmp/test_workspace/knowledge_base/people/0193a5e7-8b4c-7f2a-9d1e-3b5c6d7e8f9a.md"} =
               Paths.entity_path(@workspace, "people", "0193a5e7-8b4c-7f2a-9d1e-3b5c6d7e8f9a")
    end

    test "rejects traversal in type" do
      assert {:error, "entity type contains path traversal"} =
               Paths.entity_path(@workspace, "..", "0193a5e7-8b4c-7f2a-9d1e-3b5c6d7e8f9a")
    end

    test "rejects traversal in id" do
      assert {:error, "entity id contains path traversal"} =
               Paths.entity_path(@workspace, "people", "..")
    end
  end

  describe "schema_path/2" do
    test "returns schema file path with .json extension" do
      assert {:ok, "/tmp/test_workspace/knowledge_base/schemas/people.json"} =
               Paths.schema_path(@workspace, "people")
    end

    test "rejects traversal in schema type" do
      assert {:error, "schema type contains path traversal"} =
               Paths.schema_path(@workspace, "../evil")
    end
  end

  describe "validate_segment/2" do
    test "accepts valid segment" do
      assert :ok = Paths.validate_segment("people", "test")
    end

    test "accepts underscored segments" do
      assert :ok = Paths.validate_segment("my_type", "test")
    end

    test "rejects .." do
      assert {:error, _} = Paths.validate_segment("..", "test")
    end

    test "rejects embedded .." do
      assert {:error, _} = Paths.validate_segment("foo..bar", "test")
    end

    test "rejects null bytes" do
      assert {:error, _} = Paths.validate_segment("foo\0bar", "test")
    end

    test "rejects leading slash" do
      assert {:error, _} = Paths.validate_segment("/foo", "test")
    end

    test "rejects embedded slash" do
      assert {:error, _} = Paths.validate_segment("foo/bar", "test")
    end

    test "rejects backslash" do
      assert {:error, _} = Paths.validate_segment("foo\\bar", "test")
    end

    test "rejects empty string" do
      assert {:error, "test must not be empty"} = Paths.validate_segment("", "test")
    end

    test "rejects strings exceeding 255 bytes" do
      long = String.duplicate("a", 256)
      assert {:error, "test exceeds maximum length of 255"} = Paths.validate_segment(long, "test")
    end

    test "accepts string at exactly 255 bytes" do
      exact = String.duplicate("a", 255)
      assert :ok = Paths.validate_segment(exact, "test")
    end
  end
end
