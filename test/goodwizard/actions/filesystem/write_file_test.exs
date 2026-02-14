defmodule Goodwizard.Actions.Filesystem.WriteFileTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Filesystem.WriteFile

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "writefile_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  test "creates a new file", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "new.txt")

    assert {:ok, %{message: msg}} = WriteFile.run(%{path: path, content: "hello"}, %{})
    assert msg =~ "Successfully wrote 5 bytes"
    assert File.read!(path) == "hello"
  end

  test "creates parent directories", %{tmp_dir: tmp_dir} do
    path = Path.join([tmp_dir, "a", "b", "c", "deep.txt"])

    assert {:ok, %{message: _}} = WriteFile.run(%{path: path, content: "deep"}, %{})
    assert File.read!(path) == "deep"
  end

  test "overwrites an existing file", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "existing.txt")
    File.write!(path, "old content")

    assert {:ok, %{message: msg}} = WriteFile.run(%{path: path, content: "new content"}, %{})
    assert msg =~ "Successfully wrote 11 bytes"
    assert File.read!(path) == "new content"
  end

  test "enforces allowed_dir constraint", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "bad.txt")

    assert {:error, msg} =
             WriteFile.run(%{path: path, content: "x", allowed_dir: "/nonexistent"}, %{})

    assert msg =~ "outside allowed directory"
  end

  test "returns error for write to read-only directory", %{tmp_dir: tmp_dir} do
    readonly_dir = Path.join(tmp_dir, "readonly")
    File.mkdir_p!(readonly_dir)
    File.chmod!(readonly_dir, 0o555)
    path = Path.join(readonly_dir, "file.txt")

    assert {:error, msg} = WriteFile.run(%{path: path, content: "x"}, %{})
    assert msg =~ "Failed to write file"
  end

  test "returns error when parent directory cannot be created", %{tmp_dir: tmp_dir} do
    # Create a file where a directory needs to be
    blocker = Path.join(tmp_dir, "blocker")
    File.write!(blocker, "I'm a file, not a dir")

    path = Path.join([blocker, "subdir", "file.txt"])

    assert {:error, msg} = WriteFile.run(%{path: path, content: "x"}, %{})
    assert msg =~ "Failed to create directory"
  end
end
