defmodule Goodwizard.ConfigBrowserTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Config

  setup do
    saved_env =
      for var <- ["BRAVE_API_KEY", "GOODWIZARD_WORKSPACE", "GOODWIZARD_MODEL"] do
        {var, System.get_env(var)}
      end

    for {var, _val} <- saved_env, do: System.delete_env(var)

    Application.stop(:goodwizard)
    Process.sleep(50)

    tmp_dir =
      Path.join(System.tmp_dir!(), "gw_browser_cfg_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    on_exit(fn ->
      if Process.whereis(Config) do
        try do
          GenServer.stop(Config, :normal, 5000)
        catch
          :exit, _ -> :ok
        end
      end

      for {var, val} <- saved_env do
        if val, do: System.put_env(var, val), else: System.delete_env(var)
      end

      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  describe "browser config wiring" do
    test "wires Brave API key to jido_browser app config", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [browser.search]
      brave_api_key = "test-brave-key-123"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Application.get_env(:jido_browser, :brave_search_api_key) == "test-brave-key-123"
    end

    test "does not set brave key when empty", %{tmp_dir: tmp_dir} do
      Application.delete_env(:jido_browser, :brave_search_api_key)

      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [browser.search]
      brave_api_key = ""
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Application.get_env(:jido_browser, :brave_search_api_key) == nil
    end

    test "BRAVE_API_KEY env var overrides TOML value", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [browser.search]
      brave_api_key = "toml-key"
      """)

      System.put_env("BRAVE_API_KEY", "env-key")

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Application.get_env(:jido_browser, :brave_search_api_key) == "env-key"
    end

    test "sets adapter to Vibium by default", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")
      File.write!(config_path, "")

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Application.get_env(:jido_browser, :adapter) == JidoBrowser.Adapters.Vibium
    end

    test "sets adapter to Playwright when configured", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "config.toml")

      File.write!(config_path, """
      [browser]
      adapter = "playwright"
      """)

      {:ok, _pid} = Config.start_link(config_path: config_path)

      assert Application.get_env(:jido_browser, :adapter) == JidoBrowser.Adapters.Playwright
    end
  end
end
