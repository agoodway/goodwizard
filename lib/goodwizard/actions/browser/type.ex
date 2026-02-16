defmodule Goodwizard.Actions.Browser.Type do
  @moduledoc "Serialized wrapper around `JidoBrowser.Actions.Type`."

  use Jido.Action,
    name: "browser_type",
    description: "Type text into an element in the browser",
    category: "Browser",
    tags: ["browser", "type", "input"],
    vsn: "1.0.0",
    schema: [
      selector: [type: :string, required: true, doc: "CSS selector for the input element"],
      text: [type: :string, required: true, doc: "Text to type into the element"],
      clear: [type: :boolean, default: false, doc: "Clear the field before typing"],
      timeout: [type: :integer, doc: "Timeout in milliseconds"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @impl true
  def run(params, context), do: Helpers.run_serialized(JidoBrowser.Actions.Type, params, context)
end
