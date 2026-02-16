defmodule Goodwizard.Actions.Browser.GetUrl do
  @moduledoc "Serialized wrapper around `JidoBrowser.Actions.GetUrl`."

  use Jido.Action,
    name: "browser_get_url",
    description: "Get the current page URL",
    category: "Browser",
    tags: ["browser", "url", "page"],
    vsn: "1.0.0",
    schema: [
      timeout: [type: :integer, doc: "Timeout in milliseconds"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @impl true
  def run(params, context), do: Helpers.run_serialized(JidoBrowser.Actions.GetUrl, params, context)
end
