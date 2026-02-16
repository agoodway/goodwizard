defmodule Goodwizard.Actions.Browser.Focus do
  @moduledoc "Serialized wrapper around `JidoBrowser.Actions.Focus`."

  use Jido.Action,
    name: "browser_focus",
    description: "Focus on an element in the browser",
    category: "Browser",
    tags: ["browser", "focus", "interaction"],
    vsn: "1.0.0",
    schema: [
      selector: [type: :string, required: true, doc: "CSS selector for the element to focus"],
      timeout: [type: :integer, doc: "Timeout in milliseconds"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @impl true
  def run(params, context), do: Helpers.run_serialized(JidoBrowser.Actions.Focus, params, context)
end
