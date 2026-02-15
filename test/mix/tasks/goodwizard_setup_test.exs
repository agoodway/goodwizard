defmodule Mix.Tasks.Goodwizard.SetupTest do
  use ExUnit.Case

  alias Mix.Tasks.Goodwizard.Setup

  @subdirs ~w(memory sessions skills)
  @entity_types ~w(people places events notes tasks companies tasklists)

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

    test "creates config.toml at project root" do
      config_path = "config.toml"
      had_config = File.exists?(config_path)

      if had_config do
        # config.toml already exists — setup should not overwrite it
        with_tmp_dir(fn tmp ->
          Setup.run(["--base-dir", tmp])
          assert File.exists?(config_path)
        end)
      else
        try do
          with_tmp_dir(fn tmp ->
            Setup.run(["--base-dir", tmp])

            assert File.exists?(config_path), "Expected config.toml to exist"

            content = File.read!(config_path)
            assert content =~ "[agent]"
            assert content =~ "workspace"
          end)
        after
          unless had_config, do: File.rm(config_path)
        end
      end
    end

    test "creates brain directory structure and seeds schemas" do
      with_tmp_dir(fn tmp ->
        Setup.run(["--base-dir", tmp])

        brain_dir = Path.join(tmp, "brain")
        assert File.dir?(brain_dir), "Expected brain/ directory to exist"

        schemas_dir = Path.join(brain_dir, "schemas")
        assert File.dir?(schemas_dir), "Expected brain/schemas/ directory to exist"

        for type <- @entity_types do
          schema_path = Path.join(schemas_dir, "#{type}.json")
          assert File.exists?(schema_path), "Expected schema #{type}.json to exist"

          type_dir = Path.join(brain_dir, type)
          assert File.dir?(type_dir), "Expected brain/#{type}/ directory to exist"
        end
      end)
    end

    test "is idempotent — running twice does not raise" do
      with_tmp_dir(fn tmp ->
        Setup.run(["--base-dir", tmp])
        Setup.run(["--base-dir", tmp])

        for subdir <- @subdirs do
          assert File.dir?(Path.join(tmp, subdir))
        end

        # Brain should still be intact
        for type <- @entity_types do
          assert File.exists?(Path.join([tmp, "brain", "schemas", "#{type}.json"]))
        end
      end)
    end

    test "raises on directory creation failure" do
      # Use a path that can't be created (file exists where dir expected)
      with_tmp_dir(fn tmp ->
        blocker = Path.join(tmp, "memory")
        File.write!(blocker, "not a dir")

        assert_raise Mix.Error, ~r/could not create required directories/, fn ->
          Setup.run(["--base-dir", tmp])
        end

        # The blocker file should still exist (not replaced)
        assert File.regular?(blocker)
      end)
    end

    test "raises when Brain.ensure_initialized fails" do
      with_tmp_dir(fn tmp ->
        # Create the brain dir as a regular file to make mkdir_p inside ensure_initialized fail
        brain_dir = Path.join(tmp, "brain")
        File.write!(brain_dir, "not a directory")

        assert_raise Mix.Error, ~r/could not initialize brain/, fn ->
          Setup.run(["--base-dir", tmp])
        end
      end)
    end

    test "does not overwrite existing config.toml" do
      config_path = "config.toml"
      had_config = File.exists?(config_path)
      original_content = if had_config, do: File.read!(config_path)

      with_tmp_dir(fn tmp ->
        unless had_config do
          File.write!(config_path, "# custom config")
        end

        Setup.run(["--base-dir", tmp])

        if had_config do
          assert File.read!(config_path) == original_content
        else
          assert File.read!(config_path) == "# custom config"
        end
      end)

      unless had_config do
        File.rm(config_path)
      end
    end
  end
end
