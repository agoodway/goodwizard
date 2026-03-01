defmodule Goodwizard.Config do
  @moduledoc """
  Configuration GenServer for Goodwizard.

  Loads configuration from `config.toml` (project root) with env var overrides.
  Three-layer merge: hardcoded defaults -> TOML file -> env vars (highest priority).
  """
  use GenServer

  require Logger

  @defaults %{
    "agent" => %{
      "workspace" => "priv/workspace",
      "model" => "anthropic:claude-sonnet-4-5",
      "max_tokens" => 8192,
      "temperature" => 0.7,
      "max_tool_iterations" => 20,
      "memory_window" => 50
    },
    "channels" => %{
      "cli" => %{"enabled" => true},
      "telegram" => %{"enabled" => false, "allow_from" => []}
    },
    "tools" => %{
      "exec" => %{
        "timeout" => 60,
        "deny_patterns" => [
          "\\brm\\s+(-[a-zA-Z]*r[a-zA-Z]*f|--recursive\\s+--force|-[a-zA-Z]*f[a-zA-Z]*r)\\b",
          "\\bdel\\s+\\/[fq]\\b",
          "\\brmdir\\s+\\/s\\b",
          "\\b(mkfs|format|diskpart)\\b",
          "\\bdd\\s+if=",
          "\\/dev\\/sd[a-z]",
          "\\b(shutdown|reboot|poweroff)\\b",
          ":\\(\\)\\{\\s*:\\|:\\s*&\\s*\\}\\s*;",
          "\\$\\(",
          "`",
          "\\|",
          "[<>]\\(",
          "\\b(kill|killall|pkill)\\b",
          "\\b(chmod|chown|chgrp)\\b",
          "\\b(sudo|su|doas)\\b",
          "\\b(crontab)\\b"
        ]
      },
      "restrict_to_workspace" => true
    },
    "scheduled_tasks" => %{
      "ask_timeout" => 120_000,
      "max_concurrent_agents" => 50
    },
    "heartbeat" => %{
      "enabled" => false,
      "interval_minutes" => 5
    },
    "session" => %{
      "max_cli_sessions" => 50
    },
    "browser" => %{
      "headless" => true,
      "adapter" => "vibium",
      "timeout" => 30_000,
      "search" => %{"brave_api_key" => ""}
    }
  }

  @env_overrides [
    {"BRAVE_API_KEY", ["browser", "search", "brave_api_key"]},
    {"GOODWIZARD_WORKSPACE", ["agent", "workspace"]},
    {"GOODWIZARD_MODEL", ["agent", "model"]}
  ]

  @max_toml_size 1_048_576

  # Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns the entire config map."
  @spec get() :: map()
  def get do
    safe_call(:get, @defaults)
  end

  @doc "Returns the value at the given key path, or nil if not found."
  @spec get([String.t()]) :: term()
  def get(key_path) when is_list(key_path) do
    safe_call({:get, key_path}, get_in(@defaults, key_path))
  end

  @spec get(atom()) :: term()
  def get(key) when is_atom(key) do
    get([Atom.to_string(key)])
  end

  @doc "Sets a value at the given key path. Only available in the test environment."
  @spec put([String.t()], term()) :: :ok
  if Mix.env() == :test do
    def put(key_path, value) when is_list(key_path) do
      GenServer.call(__MODULE__, {:put, key_path, value})
    end
  else
    def put(_key_path, _value) do
      raise "Config.put/2 is only available in the test environment"
    end
  end

  @doc "Returns the expanded workspace path."
  @spec workspace() :: String.t()
  def workspace do
    case get(["agent", "workspace"]) do
      nil -> Path.expand("priv/workspace")
      path -> Path.expand(path)
    end
  end

  @doc "Returns the expanded memory directory path (workspace/memory)."
  @spec memory_dir() :: String.t()
  def memory_dir, do: Path.join(workspace(), "memory")

  @doc "Returns the expanded sessions directory path (workspace/sessions)."
  @spec sessions_dir() :: String.t()
  def sessions_dir, do: Path.join(workspace(), "sessions")

  @doc "Returns the current model string."
  @spec model() :: String.t() | nil
  def model do
    get(["agent", "model"])
  end

  @doc """
  Validates configuration and emits warnings for missing or invalid values.

  Warns but does not crash — the app starts in a degraded state.
  """
  @spec validate!() :: :ok
  def validate! do
    config = get()

    validate_model(config)
    validate_telegram(config)
    validate_workspace(config)

    Logger.info("Configuration validated successfully")
    :ok
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    config_path =
      Keyword.get(opts, :config_path) ||
        Application.get_env(:goodwizard, :config_path, "config.toml")

    expanded_path = Path.expand(config_path)

    toml_config = load_toml(expanded_path)
    config = deep_merge(@defaults, toml_config)
    config = apply_env_overrides(config)
    config = validate_numeric_ranges(config)

    wire_browser_config(config)
    ensure_workspace(config)

    Logger.info(
      "Config loaded from #{expanded_path}, model=#{get_in(config, ["agent", "model"])}"
    )

    {:ok, config}
  end

  @impl true
  def handle_call(:get, _from, config) do
    {:reply, config, config}
  end

  @impl true
  def handle_call({:get, key_path}, _from, config) do
    {:reply, get_in(config, key_path), config}
  end

  @impl true
  def handle_call({:put, key_path, value}, _from, config) do
    config = put_in_path(config, key_path, value)
    {:reply, :ok, config}
  end

  # Private

  defp put_in_path(map, [key], value), do: Map.put(map, key, value)

  defp put_in_path(map, [key | rest], value) do
    child = Map.get(map, key, %{})
    Map.put(map, key, put_in_path(child, rest, value))
  end

  defp safe_call(message, fallback) do
    GenServer.call(__MODULE__, message)
  rescue
    _ -> fallback
  catch
    :exit, _ -> fallback
  end

  defp load_toml(path) do
    with {:ok, %{size: size}} <- File.stat(path),
         :ok <- check_file_size(size, path),
         {:ok, content} <- File.read(path) do
      case Toml.decode(content) do
        {:ok, parsed} ->
          parsed

        {:error, reason} ->
          Logger.error("Failed to parse config file #{path}: #{inspect(reason)}")
          %{}
      end
    else
      {:error, :enoent} ->
        Logger.warning("Config file not found: #{path} — using defaults")
        %{}

      {:error, :too_large} ->
        %{}

      {:error, reason} ->
        Logger.error("Failed to read config file #{path}: #{inspect(reason)}")
        %{}
    end
  end

  defp check_file_size(size, path) when size > @max_toml_size do
    Logger.warning(
      "Config file #{path} is #{size} bytes (max #{@max_toml_size}) — using defaults"
    )

    {:error, :too_large}
  end

  defp check_file_size(_size, _path), do: :ok

  defp apply_env_overrides(config) do
    Enum.reduce(@env_overrides, config, fn {env_var, key_path}, acc ->
      case System.get_env(env_var) do
        nil -> acc
        value -> put_nested(acc, key_path, value)
      end
    end)
  end

  defp put_nested(map, [key], value) do
    Map.put(map, key, value)
  end

  defp put_nested(map, [key | rest], value) do
    child = Map.get(map, key, %{})
    Map.put(map, key, put_nested(child, rest, value))
  end

  defp deep_merge(base, override) do
    Map.merge(base, override, fn
      _key, %{} = base_val, %{} = override_val ->
        deep_merge(base_val, override_val)

      _key, _base_val, override_val ->
        override_val
    end)
  end

  defp wire_browser_config(config) do
    brave_key = get_in(config, ["browser", "search", "brave_api_key"])

    if brave_key && brave_key != "" do
      Application.put_env(:jido_browser, :brave_search_api_key, brave_key)
    end

    adapter_name = get_in(config, ["browser", "adapter"])

    adapter_module =
      case adapter_name do
        "vibium" ->
          JidoBrowser.Adapters.Vibium

        "playwright" ->
          JidoBrowser.Adapters.Playwright

        other ->
          Logger.warning("Unknown browser adapter #{inspect(other)}, falling back to Vibium")
          JidoBrowser.Adapters.Vibium
      end

    Application.put_env(:jido_browser, :adapter, adapter_module)

    # Resolve vibium binary path — the npm package ships "vibium" not "clicker"
    # We wrap the real binary with --oneshot so each invocation launches a fresh
    # Chrome instance instead of connecting to a daemon (avoids stale-pipe errors).
    case find_vibium_binary() do
      {:ok, path} ->
        wrapper = create_oneshot_wrapper(path)
        Application.put_env(:jido_browser, :vibium, binary_path: wrapper)

      :error ->
        Logger.warning(
          "Vibium binary not found. Browser actions will fail. Install with: npm install -g vibium @vibium/darwin-arm64"
        )
    end
  end

  defp create_oneshot_wrapper(real_binary) do
    wrapper_dir = Path.join(System.tmp_dir!(), "goodwizard")
    File.mkdir_p!(wrapper_dir)
    wrapper_path = Path.join(wrapper_dir, "vibium-oneshot")

    content = "#!/bin/bash\nexec \"#{real_binary}\" --oneshot \"$@\"\n"

    File.write!(wrapper_path, content)
    File.chmod!(wrapper_path, 0o755)
    wrapper_path
  end

  defp find_vibium_binary do
    find_vibium_from_npm() || find_vibium_in_path()
  end

  defp find_vibium_from_npm do
    case System.cmd("npm", ["root", "-g"], stderr_to_stdout: true) do
      {npm_root, 0} ->
        npm_root = String.trim(npm_root)

        platform_pkg =
          case {detect_os(), detect_arch()} do
            {:darwin, :arm64} -> "@vibium/darwin-arm64"
            {:darwin, :amd64} -> "@vibium/darwin-x64"
            {:linux, :amd64} -> "@vibium/linux-x64"
            {:linux, :arm64} -> "@vibium/linux-arm64"
            _ -> "@vibium/darwin-arm64"
          end

        path = Path.join([npm_root, platform_pkg, "bin", "vibium"])
        if File.exists?(path), do: {:ok, path}, else: nil

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp find_vibium_in_path do
    case System.find_executable("vibium") do
      path when is_binary(path) -> {:ok, path}
      nil -> :error
    end
  end

  defp detect_os do
    case :os.type() do
      {:unix, :darwin} -> :darwin
      {:unix, :linux} -> :linux
      _ -> :unknown
    end
  end

  defp detect_arch do
    :erlang.system_info(:system_architecture)
    |> to_string()
    |> then(fn
      "aarch64" <> _ -> :arm64
      "arm64" <> _ -> :arm64
      _ -> :amd64
    end)
  end

  @numeric_ranges [
    {["agent", "max_tokens"], 1, 200_000},
    {["agent", "temperature"], 0.0, 2.0},
    {["agent", "max_tool_iterations"], 1, 1000},
    {["agent", "memory_window"], 1, 10_000},
    {["tools", "exec", "timeout"], 1, 3600},
    {["browser", "timeout"], 1000, 300_000}
  ]

  defp validate_numeric_ranges(config) do
    Enum.reduce(@numeric_ranges, config, fn {path, min, max}, acc ->
      value = get_in(acc, path)

      cond do
        is_nil(value) ->
          acc

        value < min or value > max ->
          default = get_in(@defaults, path)

          Logger.warning(
            "Config #{Enum.join(path, ".")} = #{inspect(value)} is outside range " <>
              "[#{min}, #{max}], using default #{inspect(default)}"
          )

          put_nested(acc, path, default)

        true ->
          acc
      end
    end)
  end

  defp ensure_workspace(config) do
    workspace = get_in(config, ["agent", "workspace"]) |> Path.expand()

    sessions_dir = Path.join(workspace, "sessions")

    for dir <- [workspace, Path.join(workspace, "memory"), sessions_dir] do
      case File.mkdir_p(dir) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("Could not create directory #{dir}: #{inspect(reason)}")
      end
    end

    case File.chmod(sessions_dir, 0o700) do
      :ok -> :ok
      {:error, reason} -> Logger.warning("Could not chmod sessions directory: #{inspect(reason)}")
    end
  end

  @known_model_prefixes ~w(anthropic: openai: google: ollama: mistral:)

  defp validate_model(config) do
    model = get_in(config, ["agent", "model"])

    if model && not Enum.any?(@known_model_prefixes, &String.starts_with?(model, &1)) do
      Logger.warning(
        "Model \"#{model}\" does not match known provider patterns " <>
          "(#{Enum.join(@known_model_prefixes, ", ")}). " <>
          "Verify the model string is correct."
      )
    end
  end

  defp validate_telegram(config) do
    telegram_enabled = get_in(config, ["channels", "telegram", "enabled"])

    if telegram_enabled do
      token = Application.get_env(:telegex, :token)

      if is_nil(token) || token == "" do
        Logger.warning(
          "Telegram channel enabled but TELEGRAM_BOT_TOKEN is not set — Telegram will not start. " <>
            "Set the TELEGRAM_BOT_TOKEN environment variable."
        )
      end
    end
  end

  defp validate_workspace(config) do
    workspace = get_in(config, ["agent", "workspace"])

    if workspace do
      expanded = Path.expand(workspace)

      unless File.dir?(expanded) do
        Logger.warning(
          "Workspace directory #{expanded} does not exist — it will be auto-created."
        )
      end
    end
  end
end
