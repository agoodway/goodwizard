defmodule Goodwizard.Config do
  @moduledoc """
  Configuration GenServer for Goodwizard.

  Loads configuration from `~/.goodwizard/config.toml` with env var overrides.
  Three-layer merge: hardcoded defaults -> TOML file -> env vars (highest priority).
  """
  use GenServer

  require Logger

  @defaults %{
    "agent" => %{
      "workspace" => "~/.goodwizard/workspace",
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
      "exec" => %{"timeout" => 60},
      "restrict_to_workspace" => false
    },
    "browser" => %{
      "headless" => true,
      "adapter" => "vibium",
      "timeout" => 30000,
      "search" => %{"brave_api_key" => ""}
    }
  }

  @env_overrides [
    {"BRAVE_API_KEY", ["browser", "search", "brave_api_key"]},
    {"GOODWIZARD_WORKSPACE", ["agent", "workspace"]},
    {"GOODWIZARD_MODEL", ["agent", "model"]}
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns the entire config map."
  def get do
    GenServer.call(__MODULE__, :get)
  end

  @doc "Returns the value at the given key path, or nil if not found."
  def get(key_path) when is_list(key_path) do
    GenServer.call(__MODULE__, {:get, key_path})
  end

  def get(key) when is_atom(key) do
    get([Atom.to_string(key)])
  end

  @doc "Returns the expanded workspace path."
  def workspace do
    get(["agent", "workspace"]) |> Path.expand()
  end

  @doc "Returns the current model string."
  def model do
    get(["agent", "model"])
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    config_path =
      Keyword.get(opts, :config_path) ||
        Application.get_env(:goodwizard, :config_path, "~/.goodwizard/config.toml")

    expanded_path = Path.expand(config_path)

    toml_config = load_toml(expanded_path)
    config = deep_merge(@defaults, toml_config)
    config = apply_env_overrides(config)

    wire_browser_config(config)
    ensure_workspace(config)

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

  # Private

  defp load_toml(path) do
    case File.read(path) do
      {:ok, content} ->
        case Toml.decode(content) do
          {:ok, parsed} ->
            parsed

          {:error, reason} ->
            Logger.error("Failed to parse config file #{path}: #{inspect(reason)}")
            %{}
        end

      {:error, :enoent} ->
        Logger.warning("Config file not found: #{path} — using defaults")
        %{}

      {:error, reason} ->
        Logger.error("Failed to read config file #{path}: #{inspect(reason)}")
        %{}
    end
  end

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
        "vibium" -> JidoBrowser.Adapters.Vibium
        other -> other
      end

    Application.put_env(:jido_browser, :adapter, adapter_module)
  end

  defp ensure_workspace(config) do
    workspace = get_in(config, ["agent", "workspace"]) |> Path.expand()
    File.mkdir_p!(workspace)
  end
end
