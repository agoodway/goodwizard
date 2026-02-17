defmodule Goodwizard.Actions.Browser.Screenshot do
  @moduledoc """
  Wrapper around `JidoBrowser.Actions.Screenshot` with serialized execution
  and string-to-atom coercion for the `format` parameter.
  """

  use Jido.Action,
    name: "browser_screenshot",
    description: "Take a screenshot of the current page",
    category: "Browser",
    tags: ["browser", "screenshot", "capture"],
    vsn: "1.0.0",
    schema: [
      full_page: [type: :boolean, default: false, doc: "Capture the full scrollable page"],
      format: [
        type: :string,
        default: "png",
        doc: "Image format (only PNG is currently supported)"
      ],
      save_path: [type: :string, doc: "Optional file path to save the screenshot"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @format_atoms %{"png" => :png}

  @impl true
  def run(params, context) do
    Helpers.run_serialized(JidoBrowser.Actions.Screenshot, params, context,
      coerce: [{:format, @format_atoms}]
    )
  end
end
