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
      Goodwizard.Actions.Shell.Exec
    ],
    model: "anthropic:claude-sonnet-4-5",
    max_iterations: 20,
    plugins: [Goodwizard.Plugins.Session]

  require Logger

  alias Goodwizard.Character.Hydrator
  alias Goodwizard.Plugins.Session

  @impl true
  def on_before_cmd(agent, {:react_start, %{query: _query}} = action) do
    # First let the parent macro handle request tracking
    {:ok, agent, action} = super(agent, action)

    # Build dynamic system prompt from workspace state
    workspace = Map.get(agent.state, :workspace, ".")
    character_overrides = Map.get(agent.state, :character_overrides)

    hydrate_opts =
      if character_overrides,
        do: [config_overrides: character_overrides],
        else: []

    system_prompt =
      try do
        {:ok, prompt} = Hydrator.hydrate(workspace, hydrate_opts)
        prompt
      rescue
        e ->
          Logger.warning("Hydration failed: #{inspect(e)}, using default system prompt")
          "You are a helpful AI assistant."
      end

    # NOTE: Session history is recorded in on_after_cmd but not yet injected
    # into the LLM context here. Multi-turn conversational memory injection
    # is deferred to Phase 6 (Memory & Context Management). This phase only
    # scaffolds the session storage infrastructure.

    # Capture user message timestamp for session recording in on_after_cmd
    agent = %{agent | state: Map.put(agent.state, :query_received_at, DateTime.utc_now() |> DateTime.to_iso8601())}

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
        user_timestamp = Map.get(agent.state, :query_received_at, DateTime.utc_now() |> DateTime.to_iso8601())
        assistant_timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

        state =
          agent.state
          |> Session.add_message("user", query, user_timestamp)
          |> Session.add_message("assistant", answer, assistant_timestamp)

        %{agent | state: state}
      else
        agent
      end

    {:ok, agent, directives}
  end

  @impl true
  def on_after_cmd(agent, action, directives), do: super(agent, action, directives)
end
