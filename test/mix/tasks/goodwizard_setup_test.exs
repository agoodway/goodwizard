defmodule Mix.Tasks.Goodwizard.SetupTest do
  use ExUnit.Case

  alias Mix.Tasks.Goodwizard.Setup

  @base_dir Path.expand("~/.goodwizard")

  describe "run/1" do
    test "creates expected workspace directories" do
      Setup.run([])

      for subdir <- ~w(workspace memory skills sessions) do
        assert File.dir?(Path.join(@base_dir, subdir)),
               "Expected directory #{subdir} to exist"
      end
    end

    test "creates config.toml at base directory" do
      Setup.run([])

      config_path = Path.join(@base_dir, "config.toml")
      assert File.exists?(config_path), "Expected config.toml to exist"

      content = File.read!(config_path)
      assert content =~ "[agent]"
      assert content =~ "workspace"
    end

    test "is idempotent — running twice does not raise" do
      Setup.run([])
      Setup.run([])

      # Verify directories still exist after second run
      for subdir <- ~w(workspace memory skills sessions) do
        assert File.dir?(Path.join(@base_dir, subdir))
      end
    end
  end
end
