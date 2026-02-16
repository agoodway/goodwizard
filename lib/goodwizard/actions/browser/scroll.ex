defmodule Goodwizard.Actions.Browser.Scroll do
  @moduledoc """
  Wrapper around `JidoBrowser.Actions.Scroll` with serialized execution
  and string-to-atom coercion for the `direction` parameter.
  """

  use Jido.Action,
    name: "browser_scroll",
    description: "Scroll the page by pixels, to preset positions, or to an element",
    category: "Browser",
    tags: ["browser", "scroll", "navigation"],
    vsn: "1.0.0",
    schema: [
      x: [type: :integer, doc: "Horizontal scroll pixels"],
      y: [type: :integer, doc: "Vertical scroll pixels"],
      direction: [type: :string, doc: "Preset scroll direction: up, down, top, or bottom"],
      selector: [type: :string, doc: "CSS selector to scroll element into view"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @direction_atoms %{
    "up" => :up,
    "down" => :down,
    "top" => :top,
    "bottom" => :bottom
  }

  @impl true
  def run(params, context) do
    Helpers.run_serialized(JidoBrowser.Actions.Scroll, params, context,
      coerce: [{:direction, @direction_atoms}]
    )
  end
end
