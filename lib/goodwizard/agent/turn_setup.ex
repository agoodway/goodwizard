defmodule Goodwizard.Agent.TurnSetup do
  @moduledoc false

  require Logger

  alias Goodwizard.Actions.Memory.Consolidate
  alias Goodwizard.Actions.Memory.LoadContext
  alias Goodwizard.Brain.ToolGenerator
  alias Goodwizard.BrowserSessionStore
  alias Goodwizard.Character.Hydrator
  alias Jido.AI.ToolAdapter

  @doc false
  @spec prepare(map(), tuple()) :: {map(), tuple()}
  def prepare(agent, {:react_start, params} = action) do
    {:react_start, %{query: query}} = action

    agent = maybe_consolidate(agent)
    agent = maybe_load_memory_context(agent, query)

    workspace = Map.get(agent.state, :workspace) || Goodwizard.Config.workspace()
    character_overrides = Map.get(agent.state, :character_overrides)
    memory_content = get_in(agent.state, [:memory, :long_term_content]) || ""
    memory_context = get_in(agent.state, [:memory, :startup_context]) || ""

    skills_state = build_skills_state(agent)

    hydrate_opts =
      [memory: memory_content, memory_context: memory_context, skills: skills_state] ++
        if(character_overrides, do: [config_overrides: character_overrides], else: [])

    system_prompt =
      try do
        {:ok, prompt} = Hydrator.hydrate(workspace, hydrate_opts)
        prompt
      rescue
        e ->
          Logger.warning("Hydration failed: #{inspect(e)}, using default system prompt")
          "You are a helpful AI assistant."
      end

    Logger.debug(fn ->
      "[Agent] Hydration complete, prompt_length=#{String.length(system_prompt)}"
    end)

    agent = %{
      agent
      | state:
          Map.put(
            agent.state,
            :query_received_at,
            DateTime.utc_now() |> DateTime.to_iso8601()
          )
    }

    {agent, browser_session} = ensure_browser_session(agent)
    agent = ensure_brain_tools(agent)

    params =
      params
      |> Map.put(:system_prompt, system_prompt)
      |> Map.update(
        :tool_context,
        %{session: browser_session},
        &Map.put(&1, :session, browser_session)
      )

    {agent, {:react_start, params}}
  end

  defp ensure_browser_session(agent) do
    case get_in(agent.state, [:browser, :session]) do
      %JidoBrowser.Session{} = session ->
        BrowserSessionStore.put(agent.id, session)
        {agent, session}

      _ ->
        stop_stale_daemon()

        case JidoBrowser.start_session(headless: true) do
          {:ok, session} ->
            agent = %{agent | state: put_in(agent.state, [:browser, :session], session)}
            BrowserSessionStore.put(agent.id, session)
            Logger.debug("[Agent] Browser session started")
            {agent, session}

          {:error, reason} ->
            Logger.warning("Failed to start browser session: #{inspect(reason)}")
            {agent, nil}
        end
    end
  end

  defp stop_stale_daemon do
    vibium_config = Application.get_env(:jido_browser, :vibium, [])
    wrapper_path = Keyword.get(vibium_config, :binary_path)

    if wrapper_path && File.exists?(wrapper_path) do
      wrapper_path
      |> extract_vibium_binary_path()
      |> maybe_stop_vibium_daemon()
    end
  rescue
    _ -> :ok
  end

  defp extract_vibium_binary_path(wrapper_path) do
    case File.read(wrapper_path) do
      {:ok, content} ->
        case Regex.run(~r/exec "(.+)" --oneshot/, content) do
          [_, real_binary] -> real_binary
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp maybe_stop_vibium_daemon(nil), do: :ok

  defp maybe_stop_vibium_daemon(real_binary) do
    System.cmd(real_binary, ["daemon", "stop"], stderr_to_stdout: true)
    :ok
  end

  defp maybe_consolidate(agent) do
    messages = get_in(agent.state, [:session, :messages]) || []
    memory_window = get_memory_window()

    if length(messages) > memory_window do
      Logger.debug(fn ->
        "[Agent] Consolidation triggered, messages=#{length(messages)} window=#{memory_window}"
      end)

      memory_dir = get_in(agent.state, [:memory, :memory_dir])
      current_memory = get_in(agent.state, [:memory, :long_term_content]) || ""

      case Consolidate.run(
             %{
               memory_dir: memory_dir,
               messages: messages,
               memory_window: memory_window,
               current_memory: current_memory
             },
             %{}
           ) do
        {:ok, %{consolidated: true, messages: trimmed, memory_content: new_memory}} ->
          state =
            agent.state
            |> put_in([:session, :messages], trimmed)
            |> put_in([:memory, :long_term_content], new_memory)

          %{agent | state: state}

        _ ->
          agent
      end
    else
      agent
    end
  end

  defp maybe_load_memory_context(agent, topic) do
    messages = get_in(agent.state, [:session, :messages]) || []
    loaded? = get_in(agent.state, [:memory, :startup_context_loaded]) == true

    cond do
      loaded? ->
        agent

      messages != [] ->
        agent

      true ->
        memory_dir = get_in(agent.state, [:memory, :memory_dir]) || Goodwizard.Config.memory_dir()

        context = %{state: %{memory: %{memory_dir: memory_dir}}}

        case LoadContext.run(%{topic: topic}, context) do
          {:ok, %{memory_context: memory_context}} ->
            state = ensure_memory_state(agent.state)

            state =
              state
              |> put_in([:memory, :startup_context], memory_context)
              |> put_in([:memory, :startup_context_loaded], true)

            %{agent | state: state}

          {:error, reason} ->
            Logger.debug("Memory context load failed on session start: #{inspect(reason)}")

            state =
              agent.state
              |> ensure_memory_state()
              |> put_in([:memory, :startup_context_loaded], true)

            %{agent | state: state}
        end
    end
  end

  defp ensure_memory_state(state) do
    case Map.get(state, :memory) do
      %{} -> state
      _ -> Map.put(state, :memory, %{})
    end
  end

  defp get_memory_window do
    Goodwizard.Config.get(["agent", "memory_window"]) || 50
  catch
    :exit, _ -> 50
  end

  defp ensure_brain_tools(agent) do
    brain_tools = ToolGenerator.generated_modules()

    if brain_tools == [] do
      agent
    else
      strategy_state = Map.get(agent.state, :__strategy__, %{})
      config = Map.get(strategy_state, :config, %{})
      current_tools = config[:tools] || []

      all_tools =
        brain_tools
        |> Kernel.++(current_tools)
        |> Enum.uniq()
        |> Enum.filter(&valid_action_module?/1)

      if length(all_tools) == length(current_tools) do
        agent
      else
        actions_by_name = Map.new(all_tools, &{&1.name(), &1})
        reqllm_tools = ToolAdapter.from_actions(all_tools)

        updated_config =
          config
          |> Map.put(:tools, all_tools)
          |> Map.put(:actions_by_name, actions_by_name)
          |> Map.put(:reqllm_tools, reqllm_tools)

        updated_strat = Map.put(strategy_state, :config, updated_config)
        %{agent | state: Map.put(agent.state, :__strategy__, updated_strat)}
      end
    end
  end

  defp valid_action_module?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :name, 0)
  end

  defp valid_action_module?(_), do: false

  defp build_skills_state(agent) do
    prompt_skills = Map.get(agent.state, :prompt_skills, %{})
    summary = Map.get(prompt_skills, :skills_summary, "")
    %{summary: summary}
  end
end
