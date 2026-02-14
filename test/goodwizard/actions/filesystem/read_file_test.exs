defmodule Goodwizard.Actions.Filesystem.ReadFileTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Filesystem.ReadFile

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "readfile_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  test "reads an existing file", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "hello.txt")
    File.write!(path, "hello world")

    assert {:ok, %{content: "hello world"}} = ReadFile.run(%{path: path}, %{})
  end

  test "returns error for missing file", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "nope.txt")

    assert {:error, "File not found: " <> _} = ReadFile.run(%{path: path}, %{})
  end

  test "returns error for directory path", %{tmp_dir: tmp_dir} do
    assert {:error, "Not a file: " <> _} = ReadFile.run(%{path: tmp_dir}, %{})
  end

  test "enforces allowed_dir constraint", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "secret.txt")
    File.write!(path, "secret")

    assert {:error, msg} =
             ReadFile.run(%{path: path, allowed_dir: "/nonexistent/allowed"}, %{})

    assert msg =~ "outside allowed directory"
  end

  test "allows path within allowed_dir", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "ok.txt")
    File.write!(path, "ok")

    assert {:ok, %{content: "ok"}} =
             ReadFile.run(%{path: path, allowed_dir: tmp_dir}, %{})
  end

  test "returns error for permission denied", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "noperm.txt")
    File.write!(path, "secret")
    File.chmod!(path, 0o000)

    assert {:error, msg} = ReadFile.run(%{path: path}, %{})
    assert msg =~ "Failed to read file"
  end

  test "returns error for file exceeding size limit", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "big.txt")
    File.write!(path, String.duplicate("x", 1000))

    assert {:error, msg} = ReadFile.run(%{path: path, max_file_size: 100}, %{})
    assert msg =~ "File too large"
    assert msg =~ "exceeds limit"
  end
end
