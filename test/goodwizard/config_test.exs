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

    tmp_dir =
      Path.join(System.tmp_dir!(), "goodwizard_test_#{:erlang.unique_integer([:positive])}")

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
      assert get_in(config, ["browser", "timeout"]) == 60_000
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
      assert get_in(config, ["agent", "workspace"]) == "priv/workspace"
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
      assert get_in(config, ["agent", "workspace"]) == "priv/workspace"
      assert get_in(config, ["agent", "model"]) == "anthropic:claude-sonnet-4-5"
      assert get_in(config, ["agent", "max_tokens"]) == 8192
      assert get_in(config, ["agent", "temperature"]) == 0.7
      assert get_in(config, ["agent", "max_tool_iterations"]) == 20
      assert get_in(config, ["agent", "memory_window"]) == 50
      assert get_in(config, ["channels", "cli", "enabled"]) == true
      assert get_in(config, ["channels", "telegram", "enabled"]) == false
      assert get_in(config, ["channels", "telegram", "allow_from"]) == []
      assert get_in(config, ["tools", "exec", "timeout"]) == 60
      assert get_in(config, ["tools", "restrict_to_workspace"]) == true
      assert get_in(config, ["browser", "headless"]) == true
      assert get_in(config, ["browser", "adapter"]) == "vibium"
      assert get_in(config, ["browser", "timeout"]) == 30_000
      assert get_in(config, ["browser", "search", "brave_api_key"]) == ""
      assert get_in(config, ["session", "max_cli_sessions"]) == 50
    end
  end

  describe "workspace/0 expands ~ to full path" do
    test "expands relative default workspace path", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")

      {:ok, _pid} = Config.start_link(config_path: config_path)

      workspace = Config.workspace()

      assert workspace == Path.expand("priv/workspace")
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

  describe "memory_dir/0 and sessions_dir/0" do
    test "returns paths under workspace by default", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")

      {:ok, _pid} = Config.start_link(config_path: config_path)

      workspace = Config.workspace()
      assert Config.memory_dir() == Path.join(workspace, "memory")
      assert Config.sessions_dir() == Path.join(workspace, "sessions")
    end

    test "follows custom workspace setting", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [agent]
      workspace = "#{tmp_dir}/custom"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Config.memory_dir() == Path.join(tmp_dir, "custom/memory")
      assert Config.sessions_dir() == Path.join(tmp_dir, "custom/sessions")
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

  describe "wire_browser_config/1 sets :jido_browser app env" do
    test "sets brave_search_api_key when configured", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [browser.search]
      brave_api_key = "test-brave-key"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Application.get_env(:jido_browser, :brave_search_api_key) == "test-brave-key"
    end

    test "does not set brave_search_api_key when empty string", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")

      Application.delete_env(:jido_browser, :brave_search_api_key)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Application.get_env(:jido_browser, :brave_search_api_key) == nil
    end

    test "sets adapter to Vibium module for 'vibium' string", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [browser]
      adapter = "vibium"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Application.get_env(:jido_browser, :adapter) == JidoBrowser.Adapters.Vibium
    end

    test "sets adapter to Playwright module for 'playwright' string", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [browser]
      adapter = "playwright"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Application.get_env(:jido_browser, :adapter) == JidoBrowser.Adapters.Playwright
    end

    test "falls back to Vibium for unknown adapter", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [browser]
      adapter = "unknown_adapter"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Application.get_env(:jido_browser, :adapter) == JidoBrowser.Adapters.Vibium
    end
  end

  describe "invalid TOML handling" do
    test "falls back to defaults and logs error for malformed TOML", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [agent
      this is not valid toml!!!
      """)

      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          {:ok, _pid} = Config.start_link(config_path: config_path)
        end)

      assert log =~ "Failed to parse config file"

      config = Config.get()
      assert get_in(config, ["agent", "model"]) == "anthropic:claude-sonnet-4-5"
      assert get_in(config, ["agent", "max_tokens"]) == 8192
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

  describe "workspace directory creation" do
    test "creates workspace directory and subdirs on startup", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")
      workspace_path = Path.join(tmp_dir, "new_workspace")

      refute File.exists?(workspace_path)

      File.write!(config_path, """
      [agent]
      workspace = "#{workspace_path}"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert File.dir?(workspace_path)
      assert File.dir?(Path.join(workspace_path, "memory"))
      assert File.dir?(Path.join(workspace_path, "sessions"))
    end
  end

  describe "validate_numeric_ranges" do
    test "clamps out-of-range values to defaults", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [agent]
      max_tokens = 999999
      temperature = 5.0
      memory_window = -1
      """)

      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          {:ok, _pid} = Config.start_link(config_path: config_path)
        end)

      assert log =~ "outside range"

      # Should fall back to defaults
      assert Config.get(["agent", "max_tokens"]) == 8192
      assert Config.get(["agent", "temperature"]) == 0.7
      assert Config.get(["agent", "memory_window"]) == 50
    end
  end

  describe "oversized config file" do
    test "rejects config file exceeding size limit", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      # Write a file larger than @max_toml_size (1MB)
      File.write!(config_path, String.duplicate("# comment\n", 200_000))

      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          {:ok, _pid} = Config.start_link(config_path: config_path)
        end)

      assert log =~ "bytes (max"

      # Should fall back to defaults
      config = Config.get()
      assert get_in(config, ["agent", "model"]) == "anthropic:claude-sonnet-4-5"
    end
  end

  describe "validate!/0" do
    test "returns :ok and logs success for valid defaults", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")
      {:ok, _pid} = Config.start_link(config_path: config_path)

      import ExUnit.CaptureLog

      log = capture_log(fn -> assert Config.validate!() == :ok end)
      assert log =~ "Configuration validated successfully"
    end

    test "warns about unknown model prefix", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [agent]
      model = "unknown-provider:some-model"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      import ExUnit.CaptureLog

      log = capture_log(fn -> Config.validate!() end)
      assert log =~ "does not match known provider patterns"
    end

    test "warns when telegram enabled but no token set", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [channels.telegram]
      enabled = true
      """)

      # Ensure no telegram token is set
      Application.delete_env(:telegex, :token)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      import ExUnit.CaptureLog

      log = capture_log(fn -> Config.validate!() end)
      assert log =~ "TELEGRAM_BOT_TOKEN is not set"
    end

    test "warns when workspace directory does not exist", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      missing_workspace =
        Path.join(tmp_dir, "nonexistent_workspace_#{System.unique_integer([:positive])}")

      File.write!(config_path, """
      [agent]
      workspace = "#{missing_workspace}"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      # workspace is auto-created by init, so remove it to test validate_workspace
      File.rm_rf!(missing_workspace)

      import ExUnit.CaptureLog

      log = capture_log(fn -> Config.validate!() end)
      assert log =~ "does not exist"
    end

    test "does not warn for valid known model prefix", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [agent]
      model = "anthropic:claude-sonnet-4-5"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      import ExUnit.CaptureLog

      log = capture_log(fn -> Config.validate!() end)
      refute log =~ "does not match known provider patterns"
    end
  end

  describe "put/2" do
    test "sets a top-level key", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")
      {:ok, _pid} = Config.start_link(config_path: config_path)

      Config.put(["agent", "model"], "openai:gpt-4o")
      assert Config.get(["agent", "model"]) == "openai:gpt-4o"
    end

    test "creates intermediate maps for nested paths", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")
      {:ok, _pid} = Config.start_link(config_path: config_path)

      Config.put(["cron", "max_jobs"], 100)
      assert Config.get(["cron", "max_jobs"]) == 100
    end

    test "overwrites existing nested value", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")
      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Config.get(["agent", "max_tokens"]) == 8192
      Config.put(["agent", "max_tokens"], 4096)
      assert Config.get(["agent", "max_tokens"]) == 4096
    end

    test "deeply nested path creates all intermediate maps", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")
      {:ok, _pid} = Config.start_link(config_path: config_path)

      Config.put(["a", "b", "c"], "deep_value")
      assert Config.get(["a", "b", "c"]) == "deep_value"
    end
  end
end
