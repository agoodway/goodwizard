defmodule Goodwizard.AgentTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Agent, as: GoodwizardAgent
  alias Goodwizard.Plugins.Session
  alias Jido.Agent.Strategy.State, as: StratState
  alias Jido.AI.Strategies.ReAct
  alias Jido.Instruction

  describe "module compilation" do
    test "defines ask/2, ask/3, ask_sync/2, ask_sync/3, await/1, await/2" do
      assert function_exported?(GoodwizardAgent, :ask, 2)
      assert function_exported?(GoodwizardAgent, :ask, 3)
      assert function_exported?(GoodwizardAgent, :ask_sync, 2)
      assert function_exported?(GoodwizardAgent, :ask_sync, 3)
      assert function_exported?(GoodwizardAgent, :await, 1)
      assert function_exported?(GoodwizardAgent, :await, 2)
    end

    test "has correct name and description" do
      agent = GoodwizardAgent.new()
      assert agent.name == "goodwizard"
      assert agent.description == "Personal AI assistant"
    end

    test "registers all five tools" do
      agent = GoodwizardAgent.new()
      tools = ReAct.list_tools(agent)

      assert Goodwizard.Actions.Filesystem.ReadFile in tools
      assert Goodwizard.Actions.Filesystem.WriteFile in tools
      assert Goodwizard.Actions.Filesystem.EditFile in tools
      assert Goodwizard.Actions.Filesystem.ListDir in tools
      assert Goodwizard.Actions.Shell.Exec in tools
    end

    test "registers all brain action tools" do
      agent = GoodwizardAgent.new()
      tools = ReAct.list_tools(agent)

      # Static brain tools (typed create/update tools are registered dynamically)
      assert Goodwizard.Actions.Brain.ReadEntity in tools
      assert Goodwizard.Actions.Brain.DeleteEntity in tools
      assert Goodwizard.Actions.Brain.ListEntities in tools
      assert Goodwizard.Actions.Brain.GetSchema in tools
      assert Goodwizard.Actions.Brain.SaveSchema in tools
      assert Goodwizard.Actions.Brain.ListEntityTypes in tools
    end

    test "uses correct model" do
      agent = GoodwizardAgent.new()
      assert agent.state.model == "anthropic:claude-sonnet-4-5"
    end
  end

  describe "start via Jido instance" do
    test "starts agent with workspace, channel, and chat_id in state" do
      {:ok, pid} =
        Goodwizard.Jido.start_agent(GoodwizardAgent,
          id: "test:#{System.unique_integer([:positive])}",
          initial_state: %{workspace: "/tmp", channel: "cli", chat_id: "direct"}
        )

      assert is_pid(pid)
      assert Process.alive?(pid)

      {:ok, server_state} = Jido.AgentServer.state(pid)
      agent = server_state.agent

      assert agent.state.workspace == "/tmp"
      assert agent.state.channel == "cli"
      assert agent.state.chat_id == "direct"

      # Verify session plugin was mounted
      assert is_map(agent.state.session)
      assert agent.state.session.messages == []
      assert is_binary(agent.state.session.created_at)

      GenServer.stop(pid)
    end
  end

  describe "on_before_cmd/2 dynamic system prompt" do
    test "builds system prompt from workspace with bootstrap files" do
      workspace = Path.join(System.tmp_dir!(), "gw_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(workspace)
      on_exit(fn -> File.rm_rf!(workspace) end)
      File.write!(Path.join(workspace, "AGENTS.md"), "# Agent Config\nYou are a test agent.")

      agent = GoodwizardAgent.new(state: %{workspace: workspace})

      # Simulate a react_start action
      action = {:react_start, %{query: "Hello", request_id: "req_1"}}
      {:ok, updated_agent, {:react_start, params}} = GoodwizardAgent.on_before_cmd(agent, action)

      # The system prompt should be set
      assert is_binary(params.system_prompt)
      assert params.system_prompt =~ "Agent Config"
      assert params.system_prompt =~ "test agent"

      # Request tracking should also work (from super)
      assert updated_agent.state.last_request_id == "req_1"
    end

    test "system prompt reflects updated bootstrap files" do
      workspace = Path.join(System.tmp_dir!(), "gw_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(workspace)
      on_exit(fn -> File.rm_rf!(workspace) end)
      File.write!(Path.join(workspace, "AGENTS.md"), "Version 1")

      agent = GoodwizardAgent.new(state: %{workspace: workspace})

      action1 = {:react_start, %{query: "First", request_id: "req_1"}}
      {:ok, _, {:react_start, params1}} = GoodwizardAgent.on_before_cmd(agent, action1)
      assert params1.system_prompt =~ "Version 1"

      # Modify the file between queries
      File.write!(Path.join(workspace, "AGENTS.md"), "Version 2")

      action2 = {:react_start, %{query: "Second", request_id: "req_2"}}
      {:ok, _, {:react_start, params2}} = GoodwizardAgent.on_before_cmd(agent, action2)
      assert params2.system_prompt =~ "Version 2"
    end

    test "applies character_overrides from state" do
      workspace = Path.join(System.tmp_dir!(), "gw_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(workspace)
      on_exit(fn -> File.rm_rf!(workspace) end)

      agent =
        GoodwizardAgent.new(
          state: %{
            workspace: workspace,
            character_overrides: %{"name" => "TestBot"}
          }
        )

      action = {:react_start, %{query: "Hello", request_id: "req_1"}}
      {:ok, _, {:react_start, params}} = GoodwizardAgent.on_before_cmd(agent, action)

      assert params.system_prompt =~ "TestBot"
    end

    test "passes through non-react_start actions to super" do
      agent = GoodwizardAgent.new()
      {:ok, returned_agent, :some_action} = GoodwizardAgent.on_before_cmd(agent, :some_action)
      assert returned_agent == agent
    end
  end

  describe "on_after_cmd/3 session update" do
    test "appends query and response to session after completed cycle" do
      workspace = Path.join(System.tmp_dir!(), "gw_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(workspace)
      on_exit(fn -> File.rm_rf!(workspace) end)

      agent = GoodwizardAgent.new(state: %{workspace: workspace})

      # Start a request first (sets up request tracking)
      start_action = {:react_start, %{query: "What is Elixir?", request_id: "req_1"}}
      {:ok, agent, _action} = GoodwizardAgent.on_before_cmd(agent, start_action)

      # Simulate the strategy completing with a result
      # Set strategy state to completed with result
      strat_state = StratState.get(agent, %{})

      strat_state =
        strat_state
        |> Map.put(:status, :completed)
        |> Map.put(:result, "Elixir is a functional programming language.")

      agent = StratState.put(agent, strat_state)

      # Call on_after_cmd
      action = {:react_start, %{query: "What is Elixir?", request_id: "req_1"}}
      {:ok, updated_agent, _directives} = GoodwizardAgent.on_after_cmd(agent, action, [])

      # Check session was updated
      messages = Session.get_history(updated_agent.state)
      assert length(messages) == 2
      assert Enum.at(messages, 0).role == "user"
      assert Enum.at(messages, 0).content == "What is Elixir?"
      assert Enum.at(messages, 1).role == "assistant"
      assert Enum.at(messages, 1).content == "Elixir is a functional programming language."

      # User and assistant timestamps should both be valid ISO8601
      assert is_binary(Enum.at(messages, 0).timestamp)
      assert is_binary(Enum.at(messages, 1).timestamp)
      assert {:ok, _, _} = DateTime.from_iso8601(Enum.at(messages, 0).timestamp)
      assert {:ok, _, _} = DateTime.from_iso8601(Enum.at(messages, 1).timestamp)
    end

    test "does not update session when cycle is not done" do
      workspace = Path.join(System.tmp_dir!(), "gw_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(workspace)
      on_exit(fn -> File.rm_rf!(workspace) end)

      agent = GoodwizardAgent.new(state: %{workspace: workspace})

      start_action = {:react_start, %{query: "Hello", request_id: "req_1"}}
      {:ok, agent, _action} = GoodwizardAgent.on_before_cmd(agent, start_action)

      # Strategy state is still :reasoning (not completed)
      action = {:react_start, %{query: "Hello", request_id: "req_1"}}
      {:ok, updated_agent, _directives} = GoodwizardAgent.on_after_cmd(agent, action, [])

      messages = Session.get_history(updated_agent.state)
      assert messages == []
    end

    test "on_after_cmd/3 delegates to super and skips session recording for non-completing actions" do
      agent = GoodwizardAgent.new()
      {:ok, returned_agent, []} = GoodwizardAgent.on_after_cmd(agent, :some_action, [])
      assert returned_agent == agent
    end

    test "falls back to empty string for nil result" do
      workspace = Path.join(System.tmp_dir!(), "gw_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(workspace)
      on_exit(fn -> File.rm_rf!(workspace) end)

      agent = GoodwizardAgent.new(state: %{workspace: workspace})

      # Set up request tracking with a valid query first
      start_action = {:react_start, %{query: "test", request_id: "req_1"}}
      {:ok, agent, _action} = GoodwizardAgent.on_before_cmd(agent, start_action)

      strat_state = StratState.get(agent, %{})

      strat_state =
        strat_state
        |> Map.put(:status, :completed)
        |> Map.put(:result, nil)

      agent = StratState.put(agent, strat_state)

      # Call on_after_cmd — query comes from agent.state[:last_query], answer from [:last_answer]
      action = {:react_start, %{request_id: "req_1"}}
      {:ok, updated_agent, _directives} = GoodwizardAgent.on_after_cmd(agent, action, [])

      messages = Session.get_history(updated_agent.state)
      assert length(messages) == 2
      # Query comes from state[:last_query] set by on_before_cmd
      assert Enum.at(messages, 0).content == "test"
      # nil result defaults to ""
      assert Enum.at(messages, 1).content == ""
    end

    test "stores empty query string as-is" do
      workspace = Path.join(System.tmp_dir!(), "gw_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(workspace)
      on_exit(fn -> File.rm_rf!(workspace) end)

      agent = GoodwizardAgent.new(state: %{workspace: workspace})

      start_action = {:react_start, %{query: "", request_id: "req_1"}}
      {:ok, agent, _action} = GoodwizardAgent.on_before_cmd(agent, start_action)

      strat_state = StratState.get(agent, %{})

      strat_state =
        strat_state
        |> Map.put(:status, :completed)
        |> Map.put(:result, "Response to empty query")

      agent = StratState.put(agent, strat_state)

      action = {:react_start, %{query: "", request_id: "req_1"}}
      {:ok, updated_agent, _directives} = GoodwizardAgent.on_after_cmd(agent, action, [])

      messages = Session.get_history(updated_agent.state)
      assert length(messages) == 2
      assert Enum.at(messages, 0).content == ""
      assert Enum.at(messages, 1).content == "Response to empty query"
    end
  end

  describe "on_before_cmd/2 rescue path" do
    test "nil workspace still produces valid system prompt with preamble" do
      # Hydration gracefully handles nil workspace (bootstrap files silently skip),
      # so a valid prompt with the preamble is still produced
      agent = GoodwizardAgent.new(state: %{workspace: nil})
      agent = %{agent | state: Map.put(agent.state, :workspace, nil)}

      action = {:react_start, %{query: "Hello", request_id: "req_rescue"}}

      {:ok, _updated_agent, {:react_start, params}} =
        GoodwizardAgent.on_before_cmd(agent, action)

      assert params.system_prompt =~ "System Orientation"
      assert params.system_prompt =~ "Goodwizard"
    end

    test "outer rescue catches non-hydration errors and injects safe default prompt" do
      import ExUnit.CaptureLog

      # Create an agent with corrupted state that will fail in maybe_consolidate
      agent = GoodwizardAgent.new(state: %{workspace: System.tmp_dir!()})
      # Put session.messages as a non-list to trigger length/1 failure in maybe_consolidate
      agent = %{agent | state: put_in(agent.state, [:session, :messages], :not_a_list)}

      action = {:react_start, %{query: "Hello", request_id: "req_outer_rescue"}}

      log =
        capture_log(fn ->
          {:ok, _updated_agent, {:react_start, params}} =
            GoodwizardAgent.on_before_cmd(agent, action)

          # Outer rescue should inject safe default prompt
          assert params.system_prompt == "You are a helpful AI assistant."
        end)

      assert log =~ "on_before_cmd error"
    end

    test "ignores stale generated brain modules without triggering rescue" do
      import ExUnit.CaptureLog

      # Simulate stale generated tool cache containing an unloaded module.
      stale_module = Module.concat(Goodwizard.Actions.Brain.Generated, "UpdateCompany")
      cache_key = "brain_tools:generated_modules"
      original = Goodwizard.Cache.get(cache_key) || []

      on_exit(fn -> Goodwizard.Cache.put(cache_key, original) end)
      Goodwizard.Cache.put(cache_key, [stale_module])

      workspace = Path.join(System.tmp_dir!(), "gw_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(workspace)
      on_exit(fn -> File.rm_rf!(workspace) end)

      agent = GoodwizardAgent.new(state: %{workspace: workspace})
      action = {:react_start, %{query: "Hello", request_id: "req_stale_module"}}

      log =
        capture_log(fn ->
          {:ok, _updated_agent, {:react_start, params}} =
            GoodwizardAgent.on_before_cmd(agent, action)

          assert is_binary(params.system_prompt)
        end)

      refute log =~ "on_before_cmd error"
    end
  end

  describe "on_after_cmd/3 rescue path" do
    test "recovers from exception and returns ok with original directives" do
      import ExUnit.CaptureLog

      # Create agent with state that will cause session operations to fail
      agent = GoodwizardAgent.new(state: %{workspace: System.tmp_dir!()})

      # Set up request tracking
      start_action = {:react_start, %{query: "test", request_id: "req_rescue_after"}}
      {:ok, agent, _action} = GoodwizardAgent.on_before_cmd(agent, start_action)

      # Make strategy state show completed to trigger session update path
      strat_state = StratState.get(agent, %{})
      strat_state = strat_state |> Map.put(:status, :completed) |> Map.put(:result, "answer")
      agent = StratState.put(agent, strat_state)

      # Corrupt the state to cause session operations to fail
      agent = %{agent | state: Map.put(agent.state, :session, :not_a_map)}

      action = {:react_start, %{query: "test", request_id: "req_rescue_after"}}

      log =
        capture_log(fn ->
          {:ok, _updated_agent, directives} =
            GoodwizardAgent.on_after_cmd(agent, action, [:test_directive])

          assert directives == [:test_directive]
        end)

      assert log =~ "on_after_cmd error"
    end
  end

  describe "ask_sync with mocked LLM (no tools)" do
    test "processes query through ReAct strategy and returns text response" do
      agent = GoodwizardAgent.new(state: %{workspace: System.tmp_dir!()})

      # Start a query via strategy
      instruction = %Instruction{
        action: ReAct.start_action(),
        params: %{query: "Hello"}
      }

      ctx = %{
        system_prompt: "You are a helpful assistant",
        max_iterations: 20,
        telemetry_metadata: %{}
      }

      {agent, [%Jido.AI.Directive.LLMStream{id: call_id}]} =
        ReAct.cmd(agent, [instruction], ctx)

      # Simulate LLM returning a text-only response (no tools)
      llm_result = %Instruction{
        action: ReAct.llm_result_action(),
        params: %{
          call_id: call_id,
          result: {:ok, %{type: :final_answer, text: "Hello! How can I help you today?"}}
        }
      }

      {final_agent, _directives} = ReAct.cmd(agent, [llm_result], ctx)

      state = StratState.get(final_agent, %{})
      assert state[:status] == :completed
      assert state[:result] == "Hello! How can I help you today?"
    end
  end

  describe "ask_sync with tool call" do
    test "processes query with tool call through ReAct strategy" do
      agent = GoodwizardAgent.new(state: %{workspace: System.tmp_dir!()})

      instruction = %Instruction{
        action: ReAct.start_action(),
        params: %{query: "Read the file at /tmp/test.txt"}
      }

      ctx = %{
        system_prompt: "You are a helpful assistant",
        max_iterations: 20,
        telemetry_metadata: %{}
      }

      {agent, [%Jido.AI.Directive.LLMStream{id: call_id}]} =
        ReAct.cmd(agent, [instruction], ctx)

      # Simulate LLM responding with a read_file tool call
      llm_result = %Instruction{
        action: ReAct.llm_result_action(),
        params: %{
          call_id: call_id,
          result:
            {:ok,
             %{
               type: :tool_calls,
               tool_calls: [
                 %{
                   id: "tool_1",
                   name: "read_file",
                   arguments: %{path: "/tmp/test.txt"}
                 }
               ]
             }}
        }
      }

      {agent, directives} = ReAct.cmd(agent, [llm_result], ctx)

      # Should emit tool execution directive
      assert Enum.any?(directives, &match?(%Jido.AI.Directive.ToolExec{}, &1))

      state = StratState.get(agent, %{})
      assert state[:status] == :awaiting_tool

      # Simulate tool returning result
      tool_result = %Instruction{
        action: ReAct.tool_result_action(),
        params: %{
          call_id: "tool_1",
          tool_name: "read_file",
          result: {:ok, %{content: "File contents here"}}
        }
      }

      {agent, [%Jido.AI.Directive.LLMStream{id: call_id_2}]} =
        ReAct.cmd(agent, [tool_result], ctx)

      # LLM processes tool result and gives final answer
      final_result = %Instruction{
        action: ReAct.llm_result_action(),
        params: %{
          call_id: call_id_2,
          result:
            {:ok,
             %{
               type: :final_answer,
               text: "The file contains: File contents here"
             }}
        }
      }

      {final_agent, _directives} = ReAct.cmd(agent, [final_result], ctx)

      state = StratState.get(final_agent, %{})
      assert state[:status] == :completed
      assert state[:result] == "The file contains: File contents here"
    end
  end
end
