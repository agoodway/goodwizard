defmodule Goodwizard.ConfigTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Config

  @moduletag :config

  setup do
    # Save and clear env vars that could interfere with tests
    saved_env =
      for var <- ["BRAVE_API_KEY", "GOODWIZARD_WORKSPACE", "GOODWIZARD_MODEL"] do
        {var, System.get_env(var)}
      end

    for {var, _val} <- saved_env, do: System.delete_env(var)

    # Stop the application so its supervisor doesn't restart Config
    Application.stop(:goodwizard)
    # Wait for everything to wind down
    Process.sleep(50)

    tmp_dir = Path.join(System.tmp_dir!(), "goodwizard_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)

    on_exit(fn ->
      if Process.whereis(Config) do
        try do
          GenServer.stop(Config, :normal, 5000)
        catch
          :exit, _ -> :ok
        end
      end

      # Restore env vars
      for {var, val} <- saved_env do
        if val, do: System.put_env(var, val), else: System.delete_env(var)
      end

      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  describe "Config loads from a temp TOML file" do
    test "loads all values from a valid TOML file", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [agent]
      workspace = "/tmp/custom-workspace"
      model = "openai:gpt-4o"
      max_tokens = 4096
      temperature = 0.5

      [channels.cli]
      enabled = false

      [browser]
      headless = false
      timeout = 60000
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      config = Config.get()
      assert get_in(config, ["agent", "workspace"]) == "/tmp/custom-workspace"
      assert get_in(config, ["agent", "model"]) == "openai:gpt-4o"
      assert get_in(config, ["agent", "max_tokens"]) == 4096
      assert get_in(config, ["agent", "temperature"]) == 0.5
      assert get_in(config, ["channels", "cli", "enabled"]) == false
      assert get_in(config, ["browser", "headless"]) == false
      assert get_in(config, ["browser", "timeout"]) == 60000
    end

    test "partial config merges with defaults", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [agent]
      model = "openai:gpt-4o"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      config = Config.get()
      # Overridden value
      assert get_in(config, ["agent", "model"]) == "openai:gpt-4o"
      # Default values preserved
      assert get_in(config, ["agent", "max_tokens"]) == 8192
      assert get_in(config, ["agent", "workspace"]) == "~/.goodwizard/workspace"
      assert get_in(config, ["channels", "cli", "enabled"]) == true
      assert get_in(config, ["browser", "headless"]) == true
    end
  end

  describe "env vars override TOML values" do
    test "GOODWIZARD_MODEL overrides TOML model", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [agent]
      model = "anthropic:claude-sonnet-4-5"
      """)

      System.put_env("GOODWIZARD_MODEL", "openai:gpt-4o")

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Config.get(["agent", "model"]) == "openai:gpt-4o"
    end

    test "GOODWIZARD_WORKSPACE overrides default when no TOML", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")

      System.put_env("GOODWIZARD_WORKSPACE", "/tmp/work")

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Config.get(["agent", "workspace"]) == "/tmp/work"
    end

    test "BRAVE_API_KEY overrides browser config", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")

      System.put_env("BRAVE_API_KEY", "my-brave-key")

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Config.get(["browser", "search", "brave_api_key"]) == "my-brave-key"
    end

    test "unset env var does not override TOML or default", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [agent]
      model = "anthropic:claude-sonnet-4-5"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Config.get(["agent", "model"]) == "anthropic:claude-sonnet-4-5"
    end
  end

  describe "missing TOML file uses defaults" do
    test "returns all default values when no config file exists", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")

      {:ok, _pid} = Config.start_link(config_path: config_path)

      config = Config.get()
      assert get_in(config, ["agent", "workspace"]) == "~/.goodwizard/workspace"
      assert get_in(config, ["agent", "model"]) == "anthropic:claude-sonnet-4-5"
      assert get_in(config, ["agent", "max_tokens"]) == 8192
      assert get_in(config, ["agent", "temperature"]) == 0.7
      assert get_in(config, ["agent", "max_tool_iterations"]) == 20
      assert get_in(config, ["agent", "memory_window"]) == 50
      assert get_in(config, ["channels", "cli", "enabled"]) == true
      assert get_in(config, ["channels", "telegram", "enabled"]) == false
      assert get_in(config, ["channels", "telegram", "allow_from"]) == []
      assert get_in(config, ["tools", "exec", "timeout"]) == 60
      assert get_in(config, ["tools", "restrict_to_workspace"]) == false
      assert get_in(config, ["browser", "headless"]) == true
      assert get_in(config, ["browser", "adapter"]) == "vibium"
      assert get_in(config, ["browser", "timeout"]) == 30000
      assert get_in(config, ["browser", "search", "brave_api_key"]) == ""
    end
  end

  describe "workspace/0 expands ~ to full path" do
    test "expands tilde in default workspace path", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")

      {:ok, _pid} = Config.start_link(config_path: config_path)

      workspace = Config.workspace()
      home = System.user_home!()

      assert workspace == Path.join(home, ".goodwizard/workspace")
      refute String.contains?(workspace, "~")
    end

    test "expands tilde in custom workspace path", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [agent]
      workspace = "~/my-workspace"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      workspace = Config.workspace()
      home = System.user_home!()

      assert workspace == Path.join(home, "my-workspace")
    end
  end

  describe "Config.get(:character) returns map or nil" do
    test "returns parsed map when character section is present", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [character]
      name = "Goodwizard"
      tone = "helpful"
      style = "concise technical"
      traits = ["analytical", "patient", "thorough"]
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      character = Config.get(:character)
      assert is_map(character)
      assert character["name"] == "Goodwizard"
      assert character["tone"] == "helpful"
      assert character["style"] == "concise technical"
      assert character["traits"] == ["analytical", "patient", "thorough"]
    end

    test "returns nil when character section is absent", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [agent]
      model = "anthropic:claude-sonnet-4-5"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Config.get(:character) == nil
    end
  end

  describe "model/0" do
    test "returns the configured model string", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Config.model() == "anthropic:claude-sonnet-4-5"
    end
  end

  describe "get/1 with key path" do
    test "returns value at nested key path", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Config.get(["agent", "model"]) == "anthropic:claude-sonnet-4-5"
      assert Config.get(["browser", "search", "brave_api_key"]) == ""
    end

    test "returns nil for missing key path", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Config.get(["nonexistent", "key"]) == nil
    end
  end
end
