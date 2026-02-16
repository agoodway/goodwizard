defmodule Goodwizard.Actions.Browser.Navigate do
  @moduledoc """
  Wrapper around `JidoBrowser.Actions.Navigate` that serializes execution
  and stores the updated browser session in `BrowserSessionStore` after
  a successful navigation.

  This ensures the session's `current_url` is available to subsequent browser
  actions via the ETS side-channel, working around the ReAct strategy's
  immutable `run_tool_context`.
  """

  use Jido.Action,
    name: "browser_navigate",
    description: "Navigate the browser to a URL",
    category: "Browser",
    tags: ["browser", "navigation", "web"],
    vsn: "1.0.0",
    schema: [
      url: [type: :string, required: true, doc: "The URL to navigate to"],
      timeout: [type: :integer, doc: "Timeout in milliseconds"]
    ]

  alias Goodwizard.Browser.Serializer
  alias Goodwizard.BrowserSessionStore

  @impl true
  def run(params, context) do
    Serializer.execute(fn ->
      case JidoBrowser.Actions.Navigate.run(params, context) do
        {:ok, %{session: %JidoBrowser.Session{} = session} = result} ->
          if agent_id = context[:agent_id] do
            BrowserSessionStore.put(agent_id, session)
          end

          {:ok, result}

        other ->
          other
      end
    end)
  end
end
