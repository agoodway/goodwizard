defmodule Goodwizard.Actions.Filesystem.ListDirTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Filesystem.ListDir

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "listdir_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  test "lists files and directories with prefixes", %{tmp_dir: tmp_dir} do
    File.write!(Path.join(tmp_dir, "alpha.txt"), "")
    File.mkdir_p!(Path.join(tmp_dir, "beta"))
    File.write!(Path.join(tmp_dir, "gamma.ex"), "")

    assert {:ok, %{entries: listing}} = ListDir.run(%{path: tmp_dir}, %{})
    assert listing =~ "[FILE] alpha.txt"
    assert listing =~ "[DIR] beta"
    assert listing =~ "[FILE] gamma.ex"

    # Verify sorted order
    lines = String.split(listing, "\n")
    assert Enum.at(lines, 0) =~ "alpha.txt"
    assert Enum.at(lines, 1) =~ "beta"
    assert Enum.at(lines, 2) =~ "gamma.ex"
  end

  test "empty directory", %{tmp_dir: tmp_dir} do
    empty = Path.join(tmp_dir, "empty")
    File.mkdir_p!(empty)

    assert {:ok, %{entries: msg}} = ListDir.run(%{path: empty}, %{})
    assert msg =~ "is empty"
  end

  test "not a directory", %{tmp_dir: tmp_dir} do
    file = Path.join(tmp_dir, "file.txt")
    File.write!(file, "")

    assert {:error, "Not a directory: " <> _} = ListDir.run(%{path: file}, %{})
  end

  test "directory not found", %{tmp_dir: tmp_dir} do
    missing = Path.join(tmp_dir, "nope")

    assert {:error, "Directory not found: " <> _} = ListDir.run(%{path: missing}, %{})
  end

  test "enforces allowed_dir constraint", %{tmp_dir: tmp_dir} do
    assert {:error, msg} =
             ListDir.run(%{path: tmp_dir, allowed_dir: "/nonexistent"}, %{})

    assert msg =~ "outside allowed directory"
  end

  test "returns error for permission denied", %{tmp_dir: tmp_dir} do
    noperm = Path.join(tmp_dir, "noperm")
    File.mkdir_p!(noperm)
    File.chmod!(noperm, 0o000)

    assert {:error, msg} = ListDir.run(%{path: noperm}, %{})
    assert msg =~ "Failed to list directory"
  end
end
