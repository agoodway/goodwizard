defmodule Goodwizard.Actions.Filesystem.EditFileTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Filesystem.EditFile

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "editfile_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  test "successful single-occurrence replace", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "code.ex")
    File.write!(path, "defmodule Foo do\n  def hello, do: :world\nend")

    assert {:ok, %{message: msg}} =
             EditFile.run(
               %{
                 path: path,
                 old_text: "def hello, do: :world",
                 new_text: "def hello, do: :earth"
               },
               %{}
             )

    assert msg =~ "Successfully edited"
    assert File.read!(path) =~ "def hello, do: :earth"
  end

  test "old_text not found in file", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "code.ex")
    File.write!(path, "defmodule Foo do\nend")

    assert {:error, "old_text not found in file. Make sure it matches exactly."} =
             EditFile.run(%{path: path, old_text: "nonexistent", new_text: "x"}, %{})
  end

  test "ambiguous match returns error with count", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "code.ex")
    File.write!(path, "foo\nbar\nfoo\nbar\nfoo")

    assert {:error, msg} =
             EditFile.run(%{path: path, old_text: "foo", new_text: "baz"}, %{})

    assert msg =~ "old_text appears 3 times"
  end

  test "file does not exist", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "missing.ex")

    assert {:error, "File not found: " <> _} =
             EditFile.run(%{path: path, old_text: "x", new_text: "y"}, %{})
  end

  test "enforces allowed_dir constraint", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "code.ex")
    File.write!(path, "content")

    assert {:error, msg} =
             EditFile.run(
               %{path: path, old_text: "content", new_text: "x", allowed_dir: "/nonexistent"},
               %{}
             )

    assert msg =~ "outside allowed directory"
  end

  test "returns error for read permission denied", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "noperm.ex")
    File.write!(path, "content")
    File.chmod!(path, 0o000)

    assert {:error, msg} = EditFile.run(%{path: path, old_text: "content", new_text: "x"}, %{})
    assert msg =~ "Failed to read file"
  end

  test "returns error for write permission denied", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "readonly.ex")
    File.write!(path, "content")
    File.chmod!(path, 0o444)

    assert {:error, msg} = EditFile.run(%{path: path, old_text: "content", new_text: "x"}, %{})
    assert msg =~ "Failed to write file"
  end
end
