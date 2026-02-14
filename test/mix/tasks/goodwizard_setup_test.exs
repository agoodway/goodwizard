defmodule Mix.Tasks.Goodwizard.SetupTest do
  use ExUnit.Case

  alias Mix.Tasks.Goodwizard.Setup

  @subdirs ~w(workspace memory skills sessions)

  defp with_tmp_dir(fun) do
    tmp = Path.join(System.tmp_dir!(), "goodwizard_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    try do
      fun.(tmp)
    after
      File.rm_rf!(tmp)
    end
  end

  describe "run/1" do
    test "creates expected workspace directories" do
      with_tmp_dir(fn tmp ->
        Setup.run(["--base-dir", tmp])

        for subdir <- @subdirs do
          assert File.dir?(Path.join(tmp, subdir)),
                 "Expected directory #{subdir} to exist"
        end
      end)
    end

    test "creates config.toml at base directory" do
      with_tmp_dir(fn tmp ->
        Setup.run(["--base-dir", tmp])

        config_path = Path.join(tmp, "config.toml")
        assert File.exists?(config_path), "Expected config.toml to exist"

        content = File.read!(config_path)
        assert content =~ "[agent]"
        assert content =~ "workspace"
      end)
    end

    test "is idempotent — running twice does not raise" do
      with_tmp_dir(fn tmp ->
        Setup.run(["--base-dir", tmp])
        Setup.run(["--base-dir", tmp])

        for subdir <- @subdirs do
          assert File.dir?(Path.join(tmp, subdir))
        end
      end)
    end

    test "raises on directory creation failure" do
      # Use a path that can't be created (file exists where dir expected)
      with_tmp_dir(fn tmp ->
        blocker = Path.join(tmp, "workspace")
        File.write!(blocker, "not a dir")

        assert_raise Mix.Error, ~r/could not create required directories/, fn ->
          Setup.run(["--base-dir", tmp])
        end

        # The blocker file should still exist (not replaced)
        assert File.regular?(blocker)
      end)
    end

    test "does not overwrite existing config.toml" do
      with_tmp_dir(fn tmp ->
        config_path = Path.join(tmp, "config.toml")
        File.write!(config_path, "# custom config")

        Setup.run(["--base-dir", tmp])

        # Original content should be preserved
        assert File.read!(config_path) == "# custom config"
      end)
    end
  end
end
