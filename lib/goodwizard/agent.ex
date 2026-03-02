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
      Goodwizard.Actions.Memory.LoadContext,
      # Episodic memory
      Goodwizard.Actions.Memory.Episodic.RecordEpisode,
      Goodwizard.Actions.Memory.Episodic.SearchEpisodes,
      Goodwizard.Actions.Memory.Episodic.ReadEpisode,
      Goodwizard.Actions.Memory.Episodic.ListEpisodes,
      # Procedural memory
      Goodwizard.Actions.Memory.Procedural.LearnProcedure,
      Goodwizard.Actions.Memory.Procedural.RecallProcedures,
      Goodwizard.Actions.Memory.Procedural.UpdateProcedure,
      Goodwizard.Actions.Memory.Procedural.UseProcedure,
      Goodwizard.Actions.Memory.Procedural.ListProcedures,
      Goodwizard.Actions.Skills.ActivateSkill,
      Goodwizard.Actions.Skills.LoadSkillResource,
      Goodwizard.Actions.Skills.CreateSkill,
      Goodwizard.Actions.Subagent.Spawn,
      Goodwizard.Actions.Messaging.Send,
      Goodwizard.Actions.Scheduling.ScheduledTask,
      Goodwizard.Actions.Scheduling.CancelScheduledTask,
      Goodwizard.Actions.Scheduling.ListScheduledTasks,
      Goodwizard.Actions.Scheduling.OneTime,
      Goodwizard.Actions.Scheduling.CancelOneTime,
      Goodwizard.Actions.Scheduling.ListOneTimeJobs,
      # Heartbeat
      Goodwizard.Actions.Heartbeat.UpdateChecks,
      # Browser (serialized wrappers around JidoBrowser.Actions.*)
      Goodwizard.Actions.Browser.Navigate,
      Goodwizard.Actions.Browser.Back,
      Goodwizard.Actions.Browser.Forward,
      Goodwizard.Actions.Browser.Reload,
      Goodwizard.Actions.Browser.GetUrl,
      Goodwizard.Actions.Browser.GetTitle,
      Goodwizard.Actions.Browser.Click,
      Goodwizard.Actions.Browser.Type,
      Goodwizard.Actions.Browser.Hover,
      Goodwizard.Actions.Browser.Focus,
      Goodwizard.Actions.Browser.Scroll,
      Goodwizard.Actions.Browser.SelectOption,
      Goodwizard.Actions.Browser.Wait,
      Goodwizard.Actions.Browser.WaitForSelector,
      Goodwizard.Actions.Browser.WaitForNavigation,
      Goodwizard.Actions.Browser.Query,
      Goodwizard.Actions.Browser.GetText,
      Goodwizard.Actions.Browser.GetAttribute,
      Goodwizard.Actions.Browser.IsVisible,
      Goodwizard.Actions.Browser.Snapshot,
      Goodwizard.Actions.Browser.Screenshot,
      Goodwizard.Actions.Browser.ExtractContent,
      Goodwizard.Actions.Browser.Evaluate,
      # Brain
      Goodwizard.Actions.Brain.CreateEntity,
      Goodwizard.Actions.Brain.ReadEntity,
      Goodwizard.Actions.Brain.UpdateEntity,
      Goodwizard.Actions.Brain.DeleteEntity,
      Goodwizard.Actions.Brain.ListEntities,
      Goodwizard.Actions.Brain.GetSchema,
      Goodwizard.Actions.Brain.SaveSchema,
      Goodwizard.Actions.Brain.ListEntityTypes,
      Goodwizard.Actions.KnowledgeBase.RefreshTools,
      # Legacy brain aliases (migration window only)
      Goodwizard.Actions.Brain.Legacy.CreateEntity,
      Goodwizard.Actions.Brain.Legacy.ReadEntity,
      Goodwizard.Actions.Brain.Legacy.UpdateEntity,
      Goodwizard.Actions.Brain.Legacy.DeleteEntity,
      Goodwizard.Actions.Brain.Legacy.ListEntities,
      Goodwizard.Actions.Brain.Legacy.GetSchema,
      Goodwizard.Actions.Brain.Legacy.SaveSchema,
      Goodwizard.Actions.Brain.Legacy.ListEntityTypes,
      Goodwizard.Actions.Brain.RefreshTools
    ],
    model: "anthropic:claude-sonnet-4-5",
    max_iterations: 20,
    plugins: [
      Goodwizard.Plugins.Session,
      Goodwizard.Plugins.Memory,
      Goodwizard.Plugins.PromptSkills,
      Goodwizard.Plugins.ScheduledTaskScheduler,
      {JidoBrowser.Plugin, [headless: true]}
    ]

  require Logger

  alias Goodwizard.Agent.TurnSetup
  alias Goodwizard.BrowserSessionStore
  alias Goodwizard.Plugins.Session

  @impl true
  def on_before_cmd(agent, {:ai_react_start, %{query: _query}} = action) do
    # First let the parent macro handle request tracking
    {:ok, agent, action} = super(agent, action)

    Logger.debug(fn ->
      {:ai_react_start, %{query: q}} = action
      "[Agent] Query received, length=#{String.length(q)}"
    end)

    try do
      {agent, action} = TurnSetup.prepare(agent, action)
      {:ok, agent, action}
    rescue
      e ->
        Logger.error(
          "on_before_cmd error: #{Exception.message(e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
        )

        # Inject a safe default system prompt so the agent doesn't proceed with stale action
        {:ai_react_start, params} = action

        safe_action =
          {:ai_react_start, Map.put(params, :system_prompt, "You are a helpful AI assistant.")}

        {:ok, agent, safe_action}
    end
  end

  @impl true
  def on_before_cmd(agent, {:ai_react_llm_result, _params} = action) do
    {:ok, agent, action} = super(agent, action)
    agent = refresh_browser_session(agent)
    {:ok, agent, action}
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

  # Reads the latest browser session from the ETS store and injects it into
  # the strategy's run_tool_context so that lift_directives builds ToolExec
  # directives with an up-to-date session (including current_url after Navigate).
  defp refresh_browser_session(agent) do
    case BrowserSessionStore.get(agent.id) do
      nil ->
        agent

      session ->
        strategy_state = Map.get(agent.state, :__strategy__, %{})
        run_ctx = Map.get(strategy_state, :run_tool_context, %{})
        updated_ctx = Map.put(run_ctx, :session, session)
        updated_strat = Map.put(strategy_state, :run_tool_context, updated_ctx)
        %{agent | state: Map.put(agent.state, :__strategy__, updated_strat)}
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
end
