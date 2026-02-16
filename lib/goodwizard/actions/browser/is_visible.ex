defmodule Goodwizard.Actions.Browser.IsVisible do
  @moduledoc "Serialized wrapper around `JidoBrowser.Actions.IsVisible`."

  use Jido.Action,
    name: "browser_is_visible",
    description: "Check if an element is visible",
    category: "Browser",
    tags: ["browser", "visibility", "element"],
    vsn: "1.0.0",
    schema: [
      selector: [type: :string, required: true, doc: "CSS selector for the element"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @impl true
  def run(params, context), do: Helpers.run_serialized(JidoBrowser.Actions.IsVisible, params, context)
end
