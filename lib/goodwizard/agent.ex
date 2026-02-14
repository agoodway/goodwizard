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
      Goodwizard.Actions.Shell.Exec,
      Goodwizard.Actions.Memory.ReadLongTerm,
      Goodwizard.Actions.Memory.WriteLongTerm,
      Goodwizard.Actions.Memory.AppendHistory,
      Goodwizard.Actions.Memory.SearchHistory,
      Goodwizard.Actions.Memory.Consolidate,
      Goodwizard.Actions.Skills.ActivateSkill,
      Goodwizard.Actions.Skills.LoadSkillResource
    ],
    model: "anthropic:claude-sonnet-4-5",
    max_iterations: 20,
    plugins: [
      Goodwizard.Plugins.Session,
      Goodwizard.Plugins.Memory,
      Goodwizard.Plugins.PromptSkills
    ]

  require Logger

  alias Goodwizard.Actions.Memory.Consolidate
  alias Goodwizard.Character.Hydrator
  alias Goodwizard.Plugins.Session

  @impl true
  def on_before_cmd(agent, {:react_start, %{query: _query}} = action) do
    # First let the parent macro handle request tracking
    {:ok, agent, action} = super(agent, action)

    # Check if consolidation is needed before building the prompt
    agent = maybe_consolidate(agent)

    # Build dynamic system prompt from workspace state
    workspace = Map.get(agent.state, :workspace, ".")
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

    # Capture user message timestamp for session recording in on_after_cmd
    agent = %{
      agent
      | state:
          Map.put(agent.state, :query_received_at, DateTime.utc_now() |> DateTime.to_iso8601())
    }

    # Inject system prompt into the strategy options
    {:react_start, params} = action
    action = {:react_start, Map.put(params, :system_prompt, system_prompt)}

    {:ok, agent, action}
  end

  @impl true
  def on_before_cmd(agent, action), do: super(agent, action)

  @impl true
  def on_after_cmd(agent, {:react_start, %{request_id: _} = params} = action, directives) do
    # Let parent macro handle request completion tracking
    {:ok, agent, directives} = super(agent, action, directives)

    # Update session with the conversation turn
    snap = strategy_snapshot(agent)

    agent =
      if snap.done? do
        query = Map.get(params, :query) || ""
        answer = snap.result || ""

        user_timestamp =
          Map.get(agent.state, :query_received_at, DateTime.utc_now() |> DateTime.to_iso8601())

        assistant_timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

        state =
          agent.state
          |> Session.add_message("user", query, user_timestamp)
          |> Session.add_message("assistant", answer, assistant_timestamp)

        agent = %{agent | state: state}

        # Persist session to JSONL
        persist_session(agent)

        agent
      else
        agent
      end

    {:ok, agent, directives}
  end

  @impl true
  def on_after_cmd(agent, action, directives), do: super(agent, action, directives)

  defp maybe_consolidate(agent) do
    messages = get_in(agent.state, [:session, :messages]) || []
    memory_window = get_memory_window()

    if length(messages) > memory_window do
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
    sessions_dir = Path.expand("~/.goodwizard/sessions")
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
    try do
      Goodwizard.Config.get(["agent", "memory_window"]) || 50
    catch
      :exit, _ -> 50
    end
  end

  defp build_skills_state(agent) do
    prompt_skills = Map.get(agent.state, :prompt_skills, %{})
    summary = Map.get(prompt_skills, :skills_summary, "")
    %{summary: summary}
  end
end
