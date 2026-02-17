defmodule Goodwizard.Actions.Browser.SelectOption do
  @moduledoc "Serialized wrapper around `JidoBrowser.Actions.SelectOption`."

  use Jido.Action,
    name: "browser_select_option",
    description: "Select an option from a dropdown element",
    category: "Browser",
    tags: ["browser", "select", "form", "dropdown"],
    vsn: "1.0.0",
    schema: [
      selector: [type: :string, required: true, doc: "CSS selector for the select element"],
      value: [type: :string, doc: "Option value to select"],
      label: [type: :string, doc: "Option label/text to select"],
      index: [type: :integer, doc: "Option index to select (0-based)"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @impl true
  def run(params, context),
    do: Helpers.run_serialized(JidoBrowser.Actions.SelectOption, params, context)
end
