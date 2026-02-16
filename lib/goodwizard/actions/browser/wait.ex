defmodule Goodwizard.Actions.Browser.Wait do
  @moduledoc "Serialized wrapper around `JidoBrowser.Actions.Wait`."

  use Jido.Action,
    name: "browser_wait",
    description: "Wait for a specified number of milliseconds",
    category: "Browser",
    tags: ["browser", "wait", "delay"],
    vsn: "1.0.0",
    schema: [
      ms: [type: :integer, required: true, doc: "Milliseconds to wait"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @impl true
  def run(params, context), do: Helpers.run_serialized(JidoBrowser.Actions.Wait, params, context)
end
