defmodule Goodwizard.SubAgentTest do
  use ExUnit.Case, async: true

  alias Goodwizard.SubAgent

  describe "on_before_cmd/2" do
    test "injects character system prompt for react_start" do
      agent = SubAgent.new()
      params = %{query: "test query", system_prompt: ""}

      {:ok, updated_agent, {:react_start, updated_params}} =
        SubAgent.on_before_cmd(agent, {:react_start, params})

      assert is_binary(updated_params.system_prompt)
      assert updated_params.system_prompt =~ "background research and file processing agent"
      assert updated_agent.state.last_query == "test query"
    end

    test "injects task context when system_prompt is provided" do
      agent = SubAgent.new()
      params = %{query: "test query", system_prompt: "Research Elixir OTP patterns"}

      {:ok, _agent, {:react_start, updated_params}} =
        SubAgent.on_before_cmd(agent, {:react_start, params})

      assert updated_params.system_prompt =~ "Research Elixir OTP patterns"
      assert updated_params.system_prompt =~ "background research and file processing agent"
    end

    test "passes through non-react_start actions" do
      agent = SubAgent.new()
      action = {:some_other_action, %{data: "test"}}

      result = SubAgent.on_before_cmd(agent, action)
      assert {:ok, ^agent, ^action} = result
    end
  end
end
