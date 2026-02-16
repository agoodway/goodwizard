defmodule Goodwizard.Actions.Browser.Hover do
  @moduledoc "Serialized wrapper around `JidoBrowser.Actions.Hover`."

  use Jido.Action,
    name: "browser_hover",
    description: "Hover over an element in the browser",
    category: "Browser",
    tags: ["browser", "hover", "interaction"],
    vsn: "1.0.0",
    schema: [
      selector: [type: :string, required: true, doc: "CSS selector for the element to hover"],
      timeout: [type: :integer, doc: "Timeout in milliseconds"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @impl true
  def run(params, context), do: Helpers.run_serialized(JidoBrowser.Actions.Hover, params, context)
end
