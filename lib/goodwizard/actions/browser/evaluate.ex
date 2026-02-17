defmodule Goodwizard.Actions.Browser.Evaluate do
  @moduledoc "Serialized wrapper around `JidoBrowser.Actions.Evaluate`."

  use Jido.Action,
    name: "browser_evaluate",
    description: "Execute JavaScript in the browser and return the result",
    category: "Browser",
    tags: ["browser", "javascript", "evaluate"],
    vsn: "1.0.0",
    schema: [
      script: [type: :string, required: true, doc: "JavaScript code to execute"],
      timeout: [type: :integer, doc: "Timeout in milliseconds"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @impl true
  def run(params, context),
    do: Helpers.run_serialized(JidoBrowser.Actions.Evaluate, params, context)
end
