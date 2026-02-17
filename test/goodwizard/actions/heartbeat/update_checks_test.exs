defmodule Goodwizard.Actions.Heartbeat.UpdateChecksTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Heartbeat.UpdateChecks

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "update_checks_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(@test_workspace)

    original_workspace = Goodwizard.Config.workspace()
    Goodwizard.Config.put(["agent", "workspace"], @test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)
      Goodwizard.Config.put(["agent", "workspace"], original_workspace)
    end)

    context = %{state: %{workspace: @test_workspace}}
    %{context: context, heartbeat_path: Path.join(@test_workspace, "HEARTBEAT.md")}
  end

  describe "add operation" do
    test "creates file and adds check when file missing", %{context: context} do
      assert {:ok, %{added: "Check inbox", total_checks: 1}} =
               UpdateChecks.run(%{operation: "add", text: "Check inbox"}, context)

      content = File.read!(Path.join(@test_workspace, "HEARTBEAT.md"))
      assert content == "- [ ] Check inbox\n"
    end

    test "appends check to existing file", %{context: context, heartbeat_path: path} do
      File.write!(path, "- [ ] Check inbox")

      assert {:ok, %{added: "Review calendar", total_checks: 2}} =
               UpdateChecks.run(%{operation: "add", text: "Review calendar"}, context)

      content = File.read!(path)
      assert content =~ "- [ ] Check inbox"
      assert content =~ "- [ ] Review calendar"
    end

    test "rejects duplicate check", %{context: context, heartbeat_path: path} do
      File.write!(path, "- [ ] Check inbox")

      assert {:error, "Check already exists: Check inbox"} =
               UpdateChecks.run(%{operation: "add", text: "Check inbox"}, context)
    end

    test "duplicate check is case-insensitive", %{context: context, heartbeat_path: path} do
      File.write!(path, "- [ ] Check inbox")

      assert {:error, "Check already exists: check inbox"} =
               UpdateChecks.run(%{operation: "add", text: "check inbox"}, context)
    end

    test "adds check to file with plain text content", %{context: context, heartbeat_path: path} do
      File.write!(path, "Some plain text content")

      assert {:ok, %{added: "Check inbox", total_checks: 1}} =
               UpdateChecks.run(%{operation: "add", text: "Check inbox"}, context)

      content = File.read!(path)
      assert content =~ "Some plain text content"
      assert content =~ "- [ ] Check inbox"
    end
  end

  describe "remove operation" do
    test "removes existing check", %{context: context, heartbeat_path: path} do
      File.write!(path, "- [ ] Check inbox\n- [ ] Review calendar")

      assert {:ok, %{removed: "Check inbox", total_checks: 1}} =
               UpdateChecks.run(%{operation: "remove", text: "Check inbox"}, context)

      content = File.read!(path)
      refute content =~ "Check inbox"
      assert content =~ "Review calendar"
    end

    test "errors on nonexistent check", %{context: context, heartbeat_path: path} do
      File.write!(path, "- [ ] Check inbox")

      assert {:error, "Check not found: Does not exist"} =
               UpdateChecks.run(%{operation: "remove", text: "Does not exist"}, context)
    end

    test "errors on missing file", %{context: context} do
      assert {:error, "Check not found: Check inbox"} =
               UpdateChecks.run(%{operation: "remove", text: "Check inbox"}, context)
    end

    test "errors on plain text file", %{context: context, heartbeat_path: path} do
      File.write!(path, "Some plain text content")

      assert {:error, "Check not found: Check inbox"} =
               UpdateChecks.run(%{operation: "remove", text: "Check inbox"}, context)
    end
  end

  describe "list operation" do
    test "lists checks from structured file", %{context: context, heartbeat_path: path} do
      File.write!(path, "- [ ] Check inbox\n- [ ] Review calendar\n- [x] Run health check")

      assert {:ok, %{checks: checks, total_checks: 3}} =
               UpdateChecks.run(%{operation: "list"}, context)

      assert checks == ["Check inbox", "Review calendar", "Run health check"]
    end

    test "returns empty list for missing file", %{context: context} do
      assert {:ok, %{checks: [], total_checks: 0}} =
               UpdateChecks.run(%{operation: "list"}, context)
    end

    test "returns empty list for plain text file", %{context: context, heartbeat_path: path} do
      File.write!(path, "Some plain text content")

      assert {:ok, %{checks: [], total_checks: 0}} =
               UpdateChecks.run(%{operation: "list"}, context)
    end

    test "returns empty list for empty file", %{context: context, heartbeat_path: path} do
      File.write!(path, "")

      assert {:ok, %{checks: [], total_checks: 0}} =
               UpdateChecks.run(%{operation: "list"}, context)
    end
  end

  describe "validation" do
    test "rejects invalid operation", %{context: context} do
      assert {:error, msg} = UpdateChecks.run(%{operation: "invalid"}, context)
      assert msg =~ "Invalid operation"
    end

    test "requires text for add operation", %{context: context} do
      assert {:error, msg} = UpdateChecks.run(%{operation: "add"}, context)
      assert msg =~ "text is required"
    end

    test "requires text for remove operation", %{context: context} do
      assert {:error, msg} = UpdateChecks.run(%{operation: "remove"}, context)
      assert msg =~ "text is required"
    end

    test "does not require text for list operation", %{context: context} do
      assert {:ok, _} = UpdateChecks.run(%{operation: "list"}, context)
    end

    test "rejects text with newlines", %{context: context} do
      assert {:error, msg} = UpdateChecks.run(%{operation: "add", text: "line1\nline2"}, context)
      assert msg =~ "newlines or null bytes"
    end

    test "rejects text with carriage returns", %{context: context} do
      assert {:error, msg} = UpdateChecks.run(%{operation: "add", text: "line1\rline2"}, context)
      assert msg =~ "newlines or null bytes"
    end

    test "rejects text with null bytes", %{context: context} do
      assert {:error, msg} = UpdateChecks.run(%{operation: "add", text: "line1\0line2"}, context)
      assert msg =~ "newlines or null bytes"
    end

    test "rejects text exceeding 500 bytes", %{context: context} do
      long_text = String.duplicate("a", 501)
      assert {:error, msg} = UpdateChecks.run(%{operation: "add", text: long_text}, context)
      assert msg =~ "exceeds maximum length"
    end

    test "trims whitespace from text before operations", %{context: context, heartbeat_path: path} do
      assert {:ok, _} = UpdateChecks.run(%{operation: "add", text: "  Check inbox  "}, context)
      content = File.read!(path)
      assert content =~ "- [ ] Check inbox"
      refute content =~ "  Check inbox  "
    end
  end
end
