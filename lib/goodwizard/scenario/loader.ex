defmodule Goodwizard.Scenario.Loader do
  @moduledoc """
  Loads and normalizes TOML scenarios from `priv/scenarios`.
  """

  @setup_actions %{"write_file" => :write_file, "delete_file" => :delete_file}

  @doc """
  Loads a named scenario (`<name>.toml`) from the scenarios directory.
  """
  @spec load(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def load(name, opts \\ []) when is_binary(name) do
    with :ok <- validate_name(name),
         {:ok, content} <- File.read(scenario_path(name, opts)),
         {:ok, decoded} <- Toml.decode(content) do
      normalize_scenario(name, decoded)
    else
      {:error, :enoent} ->
        {:error, {:not_found, list_names(opts)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists available scenario files with names and optional descriptions.
  """
  @spec list(keyword()) :: {:ok, [map()]} | {:error, term()}
  def list(opts \\ []) do
    scenarios_dir = scenarios_dir(opts)

    with {:ok, entries} <- File.ls(scenarios_dir) do
      scenarios =
        entries
        |> Enum.filter(&String.ends_with?(&1, ".toml"))
        |> Enum.sort()
        |> Enum.map(&scenario_name_and_description(&1, scenarios_dir))

      {:ok, scenarios}
    end
  end

  @doc """
  Returns only scenario names for the configured scenarios directory.
  """
  @spec list_names(keyword()) :: [String.t()]
  def list_names(opts \\ []) do
    case list(opts) do
      {:ok, scenarios} -> Enum.map(scenarios, & &1.name)
      _ -> []
    end
  end

  @doc """
  Resolves the scenarios directory.
  """
  @spec scenarios_dir(keyword()) :: String.t()
  def scenarios_dir(opts \\ []) do
    Keyword.get(opts, :scenarios_dir, Application.app_dir(:goodwizard, "priv/scenarios"))
  end

  defp scenario_path(name, opts), do: Path.join(scenarios_dir(opts), "#{name}.toml")

  defp scenario_name_and_description(filename, dir) do
    name = filename |> Path.rootname()
    path = Path.join(dir, filename)

    description =
      with {:ok, content} <- File.read(path),
           {:ok, decoded} <- Toml.decode(content) do
        Map.get(decoded, "description")
      else
        _ -> nil
      end

    %{name: name, description: description}
  end

  defp normalize_scenario(name, decoded) when is_map(decoded) do
    with {:ok, steps} <- normalize_steps(Map.get(decoded, "steps", [])),
         {:ok, assertions} <- normalize_assertions(Map.get(decoded, "assertions", [])),
         {:ok, replay} <- normalize_replay(Map.get(decoded, "replay")) do
      {:ok,
       %{
         name: name,
         description: Map.get(decoded, "description", ""),
         steps: steps,
         assertions: assertions,
         replay: replay
       }}
    end
  end

  defp normalize_steps(steps) when is_list(steps) do
    Enum.reduce_while(steps, {:ok, []}, fn step, {:ok, acc} ->
      case normalize_step(step) do
        {:ok, normalized} -> {:cont, {:ok, acc ++ [normalized]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_steps(_), do: {:error, :invalid_steps}

  defp normalize_step(step) when is_map(step) do
    case Map.get(step, "type", "query") do
      "query" -> normalize_query_step(step)
      "setup" -> normalize_setup_step(step)
      _ -> {:error, :invalid_step_type}
    end
  end

  defp normalize_step(_), do: {:error, :invalid_step}

  defp normalize_query_step(step) do
    query = Map.get(step, "query")

    if is_binary(query) and query != "" do
      {:ok, %{type: :query, query: query}}
    else
      {:error, :invalid_query_step}
    end
  end

  defp normalize_setup_step(step) do
    action = Map.get(step, "action")
    path = Map.get(step, "path")
    content = Map.get(step, "content", "")

    cond do
      action not in ["write_file", "delete_file"] ->
        {:error, :invalid_setup_action}

      not is_binary(path) or path == "" ->
        {:error, :invalid_setup_path}

      action == "write_file" and not is_binary(content) ->
        {:error, :invalid_setup_content}

      true ->
        {:ok,
         %{
           type: :setup,
           action: Map.fetch!(@setup_actions, action),
           path: path,
           content: content
         }}
    end
  end

  defp normalize_assertions(assertions) when is_list(assertions) do
    Enum.reduce_while(assertions, {:ok, []}, fn assertion, {:ok, acc} ->
      case normalize_assertion(assertion) do
        {:ok, normalized} -> {:cont, {:ok, acc ++ [normalized]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_assertions(_), do: {:error, :invalid_assertions}

  defp normalize_assertion(assertion) when is_map(assertion) do
    type = Map.get(assertion, "type")

    if is_binary(type) and type != "" do
      {:ok,
       %{
         type: type,
         step_index: Map.get(assertion, "step_index"),
         value: Map.get(assertion, "value")
       }}
    else
      {:error, :invalid_assertion}
    end
  end

  defp normalize_assertion(_), do: {:error, :invalid_assertion}

  defp normalize_replay(nil), do: {:ok, nil}

  defp normalize_replay(replay) when is_map(replay) do
    session_file = Map.get(replay, "session_file")
    up_to_message = Map.get(replay, "up_to_message")

    cond do
      not is_binary(session_file) or session_file == "" ->
        {:error, :invalid_replay_session_file}

      not is_nil(up_to_message) and (not is_integer(up_to_message) or up_to_message < 0) ->
        {:error, :invalid_replay_up_to_message}

      true ->
        {:ok, %{session_file: session_file, up_to_message: up_to_message}}
    end
  end

  defp normalize_replay(_), do: {:error, :invalid_replay}

  defp validate_name(name) do
    cond do
      name == "" ->
        {:error, :invalid_name}

      String.contains?(name, "..") ->
        {:error, :invalid_name}

      String.contains?(name, "/") ->
        {:error, :invalid_name}

      String.contains?(name, "\\") ->
        {:error, :invalid_name}

      true ->
        :ok
    end
  end
end
