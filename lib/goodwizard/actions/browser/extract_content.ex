defmodule Goodwizard.Actions.Browser.ExtractContent do
  @moduledoc """
  Wrapper around `JidoBrowser.Actions.ExtractContent` with serialized execution
  and string-to-atom coercion for the `format` parameter.

  The upstream schema expects `{:in, [:markdown, :html]}` but the LLM sends
  string values like `"markdown"` or `"html"`. The executor's `normalize_params`
  doesn't coerce `{:in, [atoms]}` values from strings, causing validation failure.
  """

  use Jido.Action,
    name: "browser_extract_content",
    description: "Extract content from the current page as markdown or HTML",
    category: "Browser",
    tags: ["browser", "content", "extract", "markdown", "web"],
    vsn: "1.0.0",
    schema: [
      selector: [type: :string, default: "body", doc: "CSS selector to scope extraction"],
      format: [type: :string, default: "markdown", doc: "Output format: markdown or html"]
    ]

  alias Goodwizard.Actions.Browser.Helpers

  @format_atoms %{"markdown" => :markdown, "html" => :html}

  @impl true
  def run(params, context) do
    Helpers.run_serialized(JidoBrowser.Actions.ExtractContent, params, context,
      coerce: [{:format, @format_atoms}]
    )
  end
end
