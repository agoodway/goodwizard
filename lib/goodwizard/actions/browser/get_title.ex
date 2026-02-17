defmodule Goodwizard.Actions.Browser.GetTitle do
  @moduledoc "Serialized wrapper around `JidoBrowser.Actions.GetTitle`."

  use Jido.Action,
    name: "browser_get_title",
    description: "Get the current page title",
    category: "Browser",
    tags: ["browser", "title", "page"],
    vsn: "1.0.0",
    schema: [
      timeout: [type: :integer, doc: "Timeout in milliseconds"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @impl true
  def run(params, context),
    do: Helpers.run_serialized(JidoBrowser.Actions.GetTitle, params, context)
end
