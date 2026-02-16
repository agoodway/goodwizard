defmodule Goodwizard.Agent do
  @moduledoc """
  ReAct-powered AI agent for Goodwizard.

  Uses Jido's ReActAgent macro with workspace-aware system prompts
  and session tracking. The system prompt is rebuilt fresh each turn
  via `Goodwizard.Character.Hydrator` to pick up bootstrap file changes.
  """

  use Jido.AI.ReActAgent,
    name: "goodwizard",
    description: "Personal AI assistant",
    tools: [
      Goodwizard.Actions.Filesystem.ReadFile,
      Goodwizard.Actions.Filesystem.WriteFile,
      Goodwizard.Actions.Filesystem.EditFile,
      Goodwizard.Actions.Filesystem.ListDir,
      Goodwizard.Actions.Filesystem.GrepFile,
      Goodwizard.Actions.Shell.Exec,
      Goodwizard.Actions.Memory.ReadLongTerm,
      Goodwizard.Actions.Memory.WriteLongTerm,
      Goodwizard.Actions.Memory.AppendHistory,
      Goodwizard.Actions.Memory.SearchHistory,
      Goodwizard.Actions.Memory.Consolidate,
      Goodwizard.Actions.Skills.ActivateSkill,
      Goodwizard.Actions.Skills.LoadSkillResource,
      Goodwizard.Actions.Skills.CreateSkill,
      Goodwizard.Actions.Subagent.Spawn,
      Goodwizard.Actions.Messaging.Send,
      Goodwizard.Actions.Scheduling.Cron,
      Goodwizard.Actions.Scheduling.CancelCron,
      Goodwizard.Actions.Scheduling.ListCronJobs,
      Goodwizard.Actions.Scheduling.OneShot,
      # Brain (typed create/update tools are registered dynamically, generics are fallbacks)
      Goodwizard.Actions.Brain.ReadEntity,
      Goodwizard.Actions.Brain.CreateEntity,
      Goodwizard.Actions.Brain.UpdateEntity,
      Goodwizard.Actions.Brain.DeleteEntity,
      Goodwizard.Actions.Brain.ListEntities,
      Goodwizard.Actions.Brain.GetSchema,
      Goodwizard.Actions.Brain.SaveSchema,
      Goodwizard.Actions.Brain.ListEntityTypes,
      Goodwizard.Actions.Brain.RefreshTools
    ],
    model: "anthropic:claude-sonnet-4-5",
    max_iterations: 20,
    plugins: [
      Goodwizard.Plugins.Session,
      Goodwizard.Plugins.Memory,
      Goodwizard.Plugins.PromptSkills,
      Goodwizard.Plugins.CronScheduler,
      {JidoBrowser.Plugin, [headless: true]}
    ]

  require Logger

  alias Goodwizard.Actions.Memory.Consolidate
  alias Goodwizard.Brain.ToolGenerator
  alias Goodwizard.Character.Hydrator
  alias Goodwizard.Plugins.Session
  alias Jido.Agent.Strategy.State, as: StratState
  alias Jido.AI.Strategy.StateOpsHelpers
  alias Jido.AI.ToolAdapter

  @impl true
  def on_before_cmd(agent, {:react_start, %{query: _query}} = action) do
    # First let the parent macro handle request tracking
    {:ok, agent, action} = super(agent, action)

    # Register any generated brain tools into the strategy state
    agent = maybe_register_brain_tools(agent)

    Logger.debug(fn ->
      {:react_start, %{query: q}} = action
      "[Agent] Query received, length=#{String.length(q)}"
    end)

    try do
      # Check if consolidation is needed before building the prompt
      agent = maybe_consolidate(agent)

      # Build dynamic system prompt from workspace state
      workspace = Map.get(agent.state, :workspace) || Goodwizard.Config.workspace()
      character_overrides = Map.get(agent.state, :character_overrides)
      memory_content = get_in(agent.state, [:memory, :long_term_content]) || ""

      skills_state = build_skills_state(agent)

      hydrate_opts =
        [memory: memory_content, skills: skills_state] ++
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

      # Capture user message timestamp for session recording in on_after_cmd
      agent = %{
        agent
        | state:
            Map.put(
              agent.state,
              :query_received_at,
              DateTime.utc_now() |> DateTime.to_iso8601()
            )
      }

      # Inject system prompt into the strategy options
      {:react_start, params} = action
      action = {:react_start, Map.put(params, :system_prompt, system_prompt)}

      {:ok, agent, action}
    rescue
      e ->
        Logger.error(
          "on_before_cmd error: #{Exception.message(e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
        )

        # Inject a safe default system prompt so the agent doesn't proceed with stale action
        {:react_start, params} = action

        safe_action =
          {:react_start, Map.put(params, :system_prompt, "You are a helpful AI assistant.")}

        {:ok, agent, safe_action}
    end
  end

  @impl true
  def on_before_cmd(agent, action), do: super(agent, action)

  @impl true
  def on_after_cmd(agent, action, directives) do
    was_completed = agent.state[:completed] == true

    {:ok, agent, directives} = super(agent, action, directives)

    try do
      if not was_completed and agent.state[:completed] == true do
        query = agent.state[:last_query] || ""
        answer = agent.state[:last_answer] || ""

        user_timestamp =
          Map.get(
            agent.state,
            :query_received_at,
            DateTime.utc_now() |> DateTime.to_iso8601()
          )

        assistant_timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

        state =
          agent.state
          |> Session.add_message("user", query, user_timestamp)
          |> Session.add_message("assistant", answer, assistant_timestamp)

        agent = %{agent | state: state}
        persist_session(agent)

        Logger.debug(fn ->
          "[Agent] Session recorded, query_length=#{String.length(query)} answer_length=#{String.length(answer)}"
        end)

        {:ok, agent, directives}
      else
        {:ok, agent, directives}
      end
    rescue
      e ->
        Logger.error(
          "on_after_cmd error: #{Exception.message(e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
        )

        {:ok, agent, directives}
    end
  end

  defp maybe_register_brain_tools(agent) do
    desired_modules = ToolGenerator.generated_modules()

    state = StratState.get(agent, %{})
    config = state[:config] || %{}
    current_tools = config[:tools] || []

    # Separate current tools into generated (in Generated namespace) and static
    {generated_current, static_tools} =
      Enum.split_with(current_tools, fn mod ->
        mod |> Module.split() |> Enum.take(5) == ~w(Goodwizard Actions Brain Generated)
      end)

    # If desired matches current generated set, nothing to do
    if MapSet.new(desired_modules) == MapSet.new(generated_current) do
      agent
    else
      # Rebuild: static tools + desired generated modules
      new_tools = (static_tools ++ desired_modules) |> Enum.uniq()
      new_by_name = Map.new(new_tools, fn mod -> {mod.name(), mod} end)
      new_reqllm = ToolAdapter.from_actions(new_tools)

      new_state =
        StateOpsHelpers.apply_to_state(
          state,
          StateOpsHelpers.update_tools_config(new_tools, new_by_name, new_reqllm)
        )

      StratState.put(agent, new_state)
    end
  rescue
    e ->
      Logger.warning(
        "Brain tool registration failed: #{Exception.message(e)}, continuing without dynamic tools"
      )

      agent
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

  defp persist_session(agent) do
    sessions_dir = Goodwizard.Config.sessions_dir()
    session_key = Map.get(agent.state, :session_key, "default")
    state = agent.state

    Task.start(fn ->
      case Session.save_session(sessions_dir, session_key, state) do
        :ok -> :ok
        {:error, reason} -> Logger.warning("Failed to persist session: #{inspect(reason)}")
      end
    end)
  end

  defp get_memory_window do
    Goodwizard.Config.get(["agent", "memory_window"]) || 50
  catch
    :exit, _ -> 50
  end

  defp build_skills_state(agent) do
    prompt_skills = Map.get(agent.state, :prompt_skills, %{})
    summary = Map.get(prompt_skills, :skills_summary, "")
    %{summary: summary}
  end
end
