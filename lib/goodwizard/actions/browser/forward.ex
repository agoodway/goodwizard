defmodule Goodwizard.Actions.Browser.Forward do
  @moduledoc "Serialized wrapper around `JidoBrowser.Actions.Forward`."

  use Jido.Action,
    name: "browser_forward",
    description: "Navigate forward in browser history",
    category: "Browser",
    tags: ["browser", "navigation", "history"],
    vsn: "1.0.0",
    schema: [
      timeout: [type: :integer, doc: "Timeout in milliseconds"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @impl true
  def run(params, context), do: Helpers.run_serialized(JidoBrowser.Actions.Forward, params, context)
end
