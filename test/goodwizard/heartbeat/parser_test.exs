defmodule Goodwizard.Heartbeat.ParserTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Heartbeat.Parser

  describe "structured?/1" do
    test "returns true for task-list lines with unchecked items" do
      content = "- [ ] Check inbox for new messages"
      assert Parser.structured?(content)
    end

    test "returns true for task-list lines with checked items" do
      content = "- [x] Already done"
      assert Parser.structured?(content)
    end

    test "returns true for multiple task-list lines" do
      content = """
      - [ ] Check inbox
      - [ ] Review calendar
      - [x] Run health check
      """

      assert Parser.structured?(content)
    end

    test "returns false for plain text" do
      content = "Check on all active projects and summarize status"
      refute Parser.structured?(content)
    end

    test "returns false for empty string" do
      refute Parser.structured?("")
    end

    test "returns false for regular markdown lists" do
      content = """
      - Check inbox
      - Review calendar
      """

      refute Parser.structured?(content)
    end

    test "returns true for mixed task-list and prose" do
      content = """
      Some preamble text here.
      - [ ] Check inbox for new messages
      More text below.
      """

      assert Parser.structured?(content)
    end
  end

  describe "parse/1" do
    test "extracts multiple checks from task-list content" do
      content = """
      - [ ] Check inbox for new messages
      - [ ] Review calendar for events in the next 2 hours
      - [ ] Run project health check on goodwizard
      """

      assert {:structured, checks} = Parser.parse(content)
      assert length(checks) == 3
      assert Enum.at(checks, 0) == %{index: 1, text: "Check inbox for new messages", checked: false}

      assert Enum.at(checks, 1) == %{
               index: 2,
               text: "Review calendar for events in the next 2 hours",
               checked: false
             }

      assert Enum.at(checks, 2) == %{index: 3, text: "Run project health check on goodwizard", checked: false}
    end

    test "extracts single check" do
      content = "- [ ] Check inbox"
      assert {:structured, [%{index: 1, text: "Check inbox", checked: false}]} = Parser.parse(content)
    end

    test "returns plain for content with no task-list lines" do
      content = "Check on all active projects and summarize status"
      assert {:plain, ^content} = Parser.parse(content)
    end

    test "parses both checked and unchecked items" do
      content = """
      - [x] Already done
      - [ ] Still pending
      """

      assert {:structured, checks} = Parser.parse(content)
      assert length(checks) == 2
      assert Enum.at(checks, 0).text == "Already done"
      assert Enum.at(checks, 1).text == "Still pending"
    end

    test "extracts only task-list lines from mixed content" do
      content = """
      Some preamble text.
      - [ ] Check inbox
      More prose here.
      - [ ] Review calendar
      Trailing text.
      """

      assert {:structured, checks} = Parser.parse(content)
      assert length(checks) == 2
      assert Enum.at(checks, 0).text == "Check inbox"
      assert Enum.at(checks, 1).text == "Review calendar"
    end

    test "returns plain for empty string" do
      assert {:plain, ""} = Parser.parse("")
    end

    test "indexes start at 1 and increment" do
      content = """
      - [ ] First
      - [ ] Second
      - [ ] Third
      """

      assert {:structured, checks} = Parser.parse(content)
      assert Enum.map(checks, & &1.index) == [1, 2, 3]
    end
  end

  describe "build_prompt/1" do
    test "generates numbered list with preamble for multiple checks" do
      checks = [
        %{index: 1, text: "Check inbox"},
        %{index: 2, text: "Review calendar"},
        %{index: 3, text: "Run health check"}
      ]

      expected =
        "Process each of the following awareness checks and report on each:\n" <>
          "1. Check inbox\n" <>
          "2. Review calendar\n" <>
          "3. Run health check"

      assert Parser.build_prompt(checks) == expected
    end

    test "generates numbered list for single check" do
      checks = [%{index: 1, text: "Check inbox"}]

      expected =
        "Process each of the following awareness checks and report on each:\n" <>
          "1. Check inbox"

      assert Parser.build_prompt(checks) == expected
    end

    test "preserves check text exactly" do
      checks = [%{index: 1, text: "Check inbox for new messages & important alerts"}]
      result = Parser.build_prompt(checks)
      assert result =~ "1. Check inbox for new messages & important alerts"
    end
  end
end
