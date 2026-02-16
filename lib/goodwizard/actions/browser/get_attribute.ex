defmodule Goodwizard.Actions.Browser.GetAttribute do
  @moduledoc "Serialized wrapper around `JidoBrowser.Actions.GetAttribute`."

  use Jido.Action,
    name: "browser_get_attribute",
    description: "Get an attribute value from an element",
    category: "Browser",
    tags: ["browser", "attribute", "element"],
    vsn: "1.0.0",
    schema: [
      selector: [type: :string, required: true, doc: "CSS selector for the element"],
      attribute: [type: :string, required: true, doc: "Attribute name to get"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @impl true
  def run(params, context), do: Helpers.run_serialized(JidoBrowser.Actions.GetAttribute, params, context)
end
