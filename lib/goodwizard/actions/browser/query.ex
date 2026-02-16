defmodule Goodwizard.Actions.Browser.Query do
  @moduledoc "Serialized wrapper around `JidoBrowser.Actions.Query`."

  use Jido.Action,
    name: "browser_query",
    description: "Query for elements matching a CSS selector",
    category: "Browser",
    tags: ["browser", "query", "selector"],
    vsn: "1.0.0",
    schema: [
      selector: [type: :string, required: true, doc: "CSS selector to query"],
      limit: [type: :integer, default: 10, doc: "Maximum number of elements to return"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @impl true
  def run(params, context), do: Helpers.run_serialized(JidoBrowser.Actions.Query, params, context)
end
