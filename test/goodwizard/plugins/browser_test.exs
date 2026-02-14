defmodule Goodwizard.Plugins.BrowserTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Agent, as: GoodwizardAgent

  describe "JidoBrowser.Plugin mounts on agent" do
    test "browser state is initialized after agent creation" do
      {:ok, pid} =
        Goodwizard.Jido.start_agent(GoodwizardAgent,
          id: "browser_test:#{System.unique_integer([:positive])}",
          initial_state: %{workspace: System.tmp_dir!(), channel: "cli", chat_id: "direct"}
        )

      {:ok, server_state} = Jido.AgentServer.state(pid)
      agent = server_state.agent

      # Browser plugin state should be initialized
      assert is_map(agent.state.browser)
      assert agent.state.browser.headless == true
      assert agent.state.browser.session == nil

      GenServer.stop(pid)
    end

    test "browser actions are registered via plugin" do
      plugin_actions = GoodwizardAgent.actions()

      # Spot-check key browser actions from the plugin
      assert JidoBrowser.Actions.Navigate in plugin_actions
      assert JidoBrowser.Actions.Click in plugin_actions
      assert JidoBrowser.Actions.Type in plugin_actions
      assert JidoBrowser.Actions.Screenshot in plugin_actions
      assert JidoBrowser.Actions.ExtractContent in plugin_actions
      assert JidoBrowser.Actions.StartSession in plugin_actions
      assert JidoBrowser.Actions.EndSession in plugin_actions
    end

    test "browser plugin is listed in plugin instances" do
      instances = GoodwizardAgent.plugin_instances()
      browser_instance = Enum.find(instances, fn inst -> inst.module == JidoBrowser.Plugin end)
      assert browser_instance != nil
    end
  end
end
