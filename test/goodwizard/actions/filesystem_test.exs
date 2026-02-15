defmodule Goodwizard.Actions.FilesystemTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Filesystem

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "fs_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  describe "resolve_path/2" do
    test "expands tilde in path" do
      assert {:ok, resolved} = Filesystem.resolve_path("~/test.txt", Path.expand("~"))
      assert resolved == Path.expand("~/test.txt")
    end

    test "allows path within explicit allowed_dir", %{tmp_dir: tmp_dir} do
      test_path = Path.join(tmp_dir, "file.txt")
      assert {:ok, ^test_path} = Filesystem.resolve_path(test_path, tmp_dir)
    end

    test "rejects paths outside explicit allowed_dir", %{tmp_dir: tmp_dir} do
      assert {:error, msg} = Filesystem.resolve_path("/etc/passwd", tmp_dir)
      assert msg =~ "outside allowed directory"
    end

    test "allows exact match of allowed_dir", %{tmp_dir: tmp_dir} do
      assert {:ok, _} = Filesystem.resolve_path(tmp_dir, tmp_dir)
    end

    test "allows subdirectory of allowed_dir", %{tmp_dir: tmp_dir} do
      sub = Path.join(tmp_dir, "subdir/file.txt")
      assert {:ok, ^sub} = Filesystem.resolve_path(sub, tmp_dir)
    end

    test "blocks path traversal outside allowed_dir", %{tmp_dir: tmp_dir} do
      outside = Path.join(tmp_dir, "../../../etc/passwd")
      assert {:error, msg} = Filesystem.resolve_path(outside, tmp_dir)
      assert msg =~ "outside allowed directory"
    end

    test "blocks absolute path outside allowed_dir", %{tmp_dir: tmp_dir} do
      assert {:error, msg} = Filesystem.resolve_path("/etc/passwd", tmp_dir)
      assert msg =~ "outside allowed directory"
    end

    test "blocks symlink pointing outside allowed_dir", %{tmp_dir: tmp_dir} do
      link_path = Path.join(tmp_dir, "escape_link")
      File.ln_s!("/etc", link_path)

      target = Path.join(link_path, "passwd")
      assert {:error, msg} = Filesystem.resolve_path(target, tmp_dir)
      assert msg =~ "outside allowed directory"
    end

    test "allows symlink pointing within allowed_dir", %{tmp_dir: tmp_dir} do
      subdir = Path.join(tmp_dir, "real_subdir")
      File.mkdir_p!(subdir)
      File.write!(Path.join(subdir, "ok.txt"), "ok")

      link_path = Path.join(tmp_dir, "link_to_subdir")
      File.ln_s!(subdir, link_path)

      target = Path.join(link_path, "ok.txt")
      assert {:ok, _} = Filesystem.resolve_path(target, tmp_dir)
    end
  end
end
