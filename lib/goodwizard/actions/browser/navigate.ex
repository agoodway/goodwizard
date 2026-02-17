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
  alias JidoBrowser.Actions.Navigate, as: JidoNavigate

  @impl true
  def run(params, context) do
    Serializer.execute(fn ->
      case JidoNavigate.run(params, context) do
        {:ok, %{session: %JidoBrowser.Session{} = session} = result} ->
          maybe_store_session(context[:agent_id], session)
          {:ok, result}

        other ->
          other
      end
    end)
  end

  defp maybe_store_session(nil, _session), do: :ok
  defp maybe_store_session(agent_id, session), do: BrowserSessionStore.put(agent_id, session)
end
