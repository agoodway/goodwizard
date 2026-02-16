defmodule Goodwizard.Actions.Browser.Snapshot do
  @moduledoc """
  Serialized browser snapshot with robust output parsing.

  The Vibium clicker binary mixes progress log lines into stdout alongside
  the actual JS evaluation result, and serializes complex BiDi objects using
  Go's native format instead of JSON. This wrapper works around both issues
  by:

  1. Wrapping the snapshot JS in `JSON.stringify()` so the BiDi result is a
     plain string (not a complex object the clicker mis-serializes).
  2. Adding unique markers around the JSON so we can reliably extract it
     from the noisy clicker output.
  """

  use Jido.Action,
    name: "browser_snapshot",
    description: "Get comprehensive LLM-friendly snapshot of the current page state",
    category: "Browser",
    tags: ["browser", "snapshot", "page", "content"],
    vsn: "1.0.0",
    schema: [
      include_links: [type: :boolean, default: true, doc: "Include extracted links"],
      include_forms: [type: :boolean, default: true, doc: "Include form field info"],
      include_headings: [type: :boolean, default: true, doc: "Include heading structure"],
      max_content_length: [type: :integer, default: 50_000, doc: "Truncate content at this length"],
      selector: [type: :string, default: "body", doc: "CSS selector to scope extraction"]
    ]

  require Logger

  alias Goodwizard.Browser.Serializer

  # Markers that delimit the JSON in clicker output. Chosen to be
  # unlikely to appear in page content, log lines, or JS source.
  @marker_start "<<GW_SNAP>>"
  @marker_end "<</GW_SNAP>>"

  @impl true
  def run(params, context) do
    Serializer.execute(fn ->
      case run_snapshot(params, context) do
        {:ok, _} = success ->
          success

        {:error, reason} ->
          Logger.warning("Full snapshot failed (#{inspect(reason)}), trying simple fallback")
          run_simple_fallback(params, context)
      end
    end)
  end

  # -- Primary path: full snapshot JS wrapped in JSON.stringify + markers ------

  defp run_snapshot(params, context) do
    js = build_snapshot_js(params)

    case JidoBrowser.Actions.Evaluate.run(%{script: js}, context) do
      {:ok, %{result: result}} ->
        case extract_marked_json(result) do
          {:ok, decoded} when is_map(decoded) ->
            {:ok, Map.put(decoded, "status", "success")}

          _ ->
            {:error, :snapshot_json_extraction_failed}
        end

      {:error, _} = error ->
        error
    end
  end

  defp build_snapshot_js(params) do
    selector = params |> Map.get(:selector, "body") |> Jason.encode!()
    include_links = Map.get(params, :include_links, true)
    include_forms = Map.get(params, :include_forms, true)
    include_headings = Map.get(params, :include_headings, true)
    max_len = Map.get(params, :max_content_length, 50_000)

    """
    (function() {
      var r = (function(selector, includeLinks, includeForms, includeHeadings, maxLen) {
        var root = document.querySelector(selector) || document.body;
        var result = {
          url: window.location.href,
          title: document.title,
          meta: {
            viewport_height: window.innerHeight,
            scroll_height: document.body.scrollHeight,
            scroll_position: window.scrollY
          }
        };
        result.content = root.innerText.substring(0, maxLen);
        if (includeLinks) {
          result.links = Array.from(root.querySelectorAll('a[href]')).slice(0, 100).map(function(a, i) {
            return {id: 'link_' + i, text: a.innerText.trim().substring(0, 100), href: a.href};
          });
        }
        if (includeForms) {
          result.forms = Array.from(root.querySelectorAll('form')).map(function(form) {
            return {
              id: form.id || null, action: form.action, method: form.method || 'GET',
              fields: Array.from(form.querySelectorAll('input, select, textarea')).map(function(f) {
                return {
                  name: f.name, type: f.type || 'text',
                  label: document.querySelector('label[for=\"' + f.id + '\"]') ? document.querySelector('label[for=\"' + f.id + '\"]').innerText : null,
                  required: f.required, value: f.type === 'password' ? '' : f.value
                };
              })
            };
          });
        }
        if (includeHeadings) {
          result.headings = Array.from(root.querySelectorAll('h1,h2,h3,h4,h5,h6')).slice(0, 50).map(function(h) {
            return {level: parseInt(h.tagName.substring(1)), text: h.innerText.trim().substring(0, 200)};
          });
        }
        return result;
      })(#{selector}, #{include_links}, #{include_forms}, #{include_headings}, #{max_len});
      return '#{@marker_start}' + JSON.stringify(r) + '#{@marker_end}';
    })()
    """
  end

  # -- Simple fallback: just url/title/content ---------------------------------

  defp run_simple_fallback(params, context) do
    selector = params |> Map.get(:selector, "body") |> Jason.encode!()
    max_len = Map.get(params, :max_content_length, 50_000)

    js = """
    (function() {
      var sel = document.querySelector(#{selector}) || document.body;
      var r = {url: window.location.href, title: document.title, content: sel.innerText.substring(0, #{max_len})};
      return '#{@marker_start}' + JSON.stringify(r) + '#{@marker_end}';
    })()
    """

    case JidoBrowser.Actions.Evaluate.run(%{script: js}, context) do
      {:ok, %{result: result}} ->
        case extract_marked_json(result) do
          {:ok, decoded} when is_map(decoded) ->
            {:ok, %{
              url: decoded["url"] || "",
              title: decoded["title"] || "",
              content: decoded["content"] || "",
              links: [],
              forms: [],
              headings: [],
              fallback: true
            }}

          _ ->
            {:error, :fallback_json_extraction_failed}
        end

      {:error, _} = error ->
        error
    end
  rescue
    e ->
      Logger.warning("Snapshot simple fallback failed: #{Exception.message(e)}")
      {:error, :fallback_exception}
  end

  # -- JSON extraction from noisy clicker output -------------------------------

  @doc false
  def extract_marked_json(result) when is_map(result) do
    # If the adapter already decoded it (unlikely with Vibium, but possible
    # with other adapters), just use it directly.
    {:ok, result}
  end

  def extract_marked_json(result) when is_binary(result) do
    # Strategy 1: Direct JSON decode (works if output is clean)
    case Jason.decode(result) do
      {:ok, decoded} when is_map(decoded) ->
        {:ok, decoded}

      _ ->
        # Strategy 2: Extract JSON between our markers
        extract_between_markers(result)
    end
  end

  def extract_marked_json(_), do: {:error, :unexpected_result_type}

  defp extract_between_markers(output) do
    case Regex.run(~r/#{Regex.escape(@marker_start)}(.*?)#{Regex.escape(@marker_end)}/s, output) do
      [_full, json_str] ->
        Jason.decode(json_str)

      nil ->
        {:error, :markers_not_found}
    end
  end
end
