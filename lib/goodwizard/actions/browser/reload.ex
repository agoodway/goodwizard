defmodule Goodwizard.Actions.Browser.Reload do
  @moduledoc "Serialized wrapper around `JidoBrowser.Actions.Reload`."

  use Jido.Action,
    name: "browser_reload",
    description: "Reload the current page",
    category: "Browser",
    tags: ["browser", "navigation", "reload"],
    vsn: "1.0.0",
    schema: [
      timeout: [type: :integer, doc: "Timeout in milliseconds"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @impl true
  def run(params, context), do: Helpers.run_serialized(JidoBrowser.Actions.Reload, params, context)
end
