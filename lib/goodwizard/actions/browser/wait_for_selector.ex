defmodule Goodwizard.Actions.Browser.WaitForSelector do
  @moduledoc """
  Wrapper around `JidoBrowser.Actions.WaitForSelector` with serialized execution
  and string-to-atom coercion for the `state` parameter.
  """

  use Jido.Action,
    name: "browser_wait_for_selector",
    description: "Wait for an element to appear, disappear, or change visibility state",
    category: "Browser",
    tags: ["browser", "wait", "selector"],
    vsn: "1.0.0",
    schema: [
      selector: [type: :string, required: true, doc: "CSS selector to wait for"],
      state: [
        type: :string,
        default: "visible",
        doc: "State to wait for: attached, visible, hidden, or detached"
      ],
      timeout: [type: :integer, default: 30_000, doc: "Maximum wait time in milliseconds"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @state_atoms %{
    "attached" => :attached,
    "visible" => :visible,
    "hidden" => :hidden,
    "detached" => :detached
  }

  @impl true
  def run(params, context) do
    Helpers.run_serialized(JidoBrowser.Actions.WaitForSelector, params, context,
      coerce: [{:state, @state_atoms}]
    )
  end
end
