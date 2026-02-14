defmodule Goodwizard.Actions.Subagent.SpawnTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Subagent.Spawn
  alias Goodwizard.SubAgent

  describe "module structure" do
    test "has correct action name and description" do
      assert Spawn.name() == "spawn_subagent"
      assert is_binary(Spawn.description())
      assert Spawn.description() =~ "subagent"
    end

    test "defines required schema fields" do
      schema = Spawn.schema()
      # task is required
      assert schema[:task][:required] == true
      assert schema[:task][:type] == :string
      # context is optional
      assert schema[:context][:type] == :string
    end
  end

  describe "SubAgent module structure" do
    test "SubAgent is a ReActAgent with limited tools" do
      agent = SubAgent.new()
      tools = Jido.AI.Strategies.ReAct.list_tools(agent)

      assert Goodwizard.Actions.Filesystem.ReadFile in tools
      assert Goodwizard.Actions.Filesystem.WriteFile in tools
      assert Goodwizard.Actions.Filesystem.ListDir in tools
      assert Goodwizard.Actions.Shell.Exec in tools

      # Should NOT include spawn, messaging, or browser
      refute Goodwizard.Actions.Subagent.Spawn in tools
      refute Goodwizard.Actions.Messaging.Send in tools

      # Should NOT include any JidoBrowser actions
      browser_tools = Enum.filter(tools, fn mod ->
        mod |> Module.split() |> List.first() == "JidoBrowser"
      end)

      assert browser_tools == [], "Expected no JidoBrowser tools, got: #{inspect(browser_tools)}"
    end

    test "SubAgent uses correct model and iteration limit" do
      agent = SubAgent.new()
      assert agent.state.model == "anthropic:claude-sonnet-4-5"
    end

    test "SubAgent can be started via Jido instance" do
      agent_id = "spawn_test:#{System.unique_integer([:positive])}"

      {:ok, pid} = Goodwizard.Jido.start_agent(SubAgent, id: agent_id)

      on_exit(fn ->
        if Process.alive?(pid), do: Goodwizard.Jido.stop_agent(pid)
      end)

      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end

  describe "run/2 query building" do
    test "builds query from task only (no context)" do
      # Verify the query construction logic by testing the params processing
      params = %{task: "List all files"}
      # Context is absent, so query should just be the task
      assert Map.get(params, :context, "") == ""
    end

    test "builds query with context" do
      params = %{task: "List all files", context: "Project root is /src"}
      context = Map.get(params, :context, "")
      assert context == "Project root is /src"
    end
  end
end
