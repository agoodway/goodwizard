defmodule Goodwizard.Actions.Browser.SnapshotTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Browser.Snapshot

  describe "extract_marked_json/1" do
    test "returns map result directly" do
      result = %{"url" => "https://example.com", "title" => "Test"}
      assert {:ok, ^result} = Snapshot.extract_marked_json(result)
    end

    test "decodes clean JSON string" do
      json = ~s({"url":"https://example.com","title":"Test"})
      assert {:ok, %{"url" => "https://example.com", "title" => "Test"}} =
               Snapshot.extract_marked_json(json)
    end

    test "extracts JSON from noisy clicker output with markers" do
      output = """
      Launching browser...
      Connecting to BiDi...
      Navigating to https://example.com...
      Evaluating: (function() { ... })()
      Result: <<GW_SNAP>>{"url":"https://example.com","title":"Test","content":"Hello"}<</GW_SNAP>>
      """

      assert {:ok, decoded} = Snapshot.extract_marked_json(output)
      assert decoded["url"] == "https://example.com"
      assert decoded["title"] == "Test"
      assert decoded["content"] == "Hello"
    end

    test "extracts JSON from output with BiDi string wrapper around markers" do
      # The clicker might wrap the string result in BiDi format
      output =
        "Launching browser...\nResult: map[type:string value:<<GW_SNAP>>{\"url\":\"https://example.com\"}<</GW_SNAP>>]"

      assert {:ok, %{"url" => "https://example.com"}} = Snapshot.extract_marked_json(output)
    end

    test "handles markers embedded in multiline output" do
      output =
        "Launching browser...\nConnecting to BiDi...\n<<GW_SNAP>>{\"url\":\"https://example.com\",\"title\":\"Test\",\"content\":\"Line1\\nLine2\"}<</GW_SNAP>>\n"

      assert {:ok, decoded} = Snapshot.extract_marked_json(output)
      assert decoded["url"] == "https://example.com"
      assert decoded["content"] == "Line1\nLine2"
    end

    test "returns error when markers are missing" do
      output = "Launching browser...\nResult: [[url map[type:string value:https://example.com]]]"
      assert {:error, :markers_not_found} = Snapshot.extract_marked_json(output)
    end

    test "returns error for non-binary, non-map input" do
      assert {:error, :unexpected_result_type} = Snapshot.extract_marked_json(42)
    end

    test "returns error when JSON between markers is invalid" do
      output = "<<GW_SNAP>>not valid json<</GW_SNAP>>"
      assert {:error, _} = Snapshot.extract_marked_json(output)
    end

    test "handles large content with special characters" do
      content = String.duplicate("Hello <world> & \"quotes\" ", 100)
      json = Jason.encode!(%{"url" => "https://example.com", "content" => content})
      output = "Launching browser...\n<<GW_SNAP>>#{json}<</GW_SNAP>>"

      assert {:ok, decoded} = Snapshot.extract_marked_json(output)
      assert decoded["content"] == content
    end
  end
end
