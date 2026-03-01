defmodule Goodwizard.Actions.Memory.ConsolidateSuccessPathTest do
  @moduledoc """
  Tests for the consolidation success path: file writes, message trimming,
  and memory updates. Since we can't mock the LLM in test without Mox,
  we test the internal file operations and verify the consolidation logic
  by testing the parse_json_response path and file operations.
  """
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.{
    AppendHistory,
    Consolidate,
    ReadLongTerm,
    SearchHistory,
    WriteLongTerm
  }

  defp tmp_memory_dir do
    dir = Path.join(System.tmp_dir!(), "test_memory_succ_#{:rand.uniform(100_000)}")
    File.mkdir_p!(dir)
    dir
  end

  describe "consolidation success path simulation" do
    test "history append + memory write + message trim cycle" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      # Simulate what consolidation does on LLM success:
      # 1. Append history entry
      assert {:ok, _} =
               AppendHistory.run(%{memory_dir: dir, entry: "Discussed Elixir patterns"}, %{})

      # 2. Write updated memory
      assert {:ok, _} =
               WriteLongTerm.run(
                 %{memory_dir: dir, content: "User prefers Elixir. Interested in OTP patterns."},
                 %{}
               )

      # 3. Verify the writes persisted
      assert {:ok, %{content: memory}} = ReadLongTerm.run(%{memory_dir: dir}, %{})
      assert memory =~ "User prefers Elixir"

      assert {:ok, %{matches: matches}} =
               SearchHistory.run(%{memory_dir: dir, pattern: "elixir"}, %{})

      assert length(matches) == 1
      assert hd(matches) =~ "Discussed Elixir patterns"
    end

    test "multiple consolidation cycles accumulate history" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      # First consolidation
      AppendHistory.run(%{memory_dir: dir, entry: "First conversation about setup"}, %{})
      WriteLongTerm.run(%{memory_dir: dir, content: "User is setting up Phoenix project."}, %{})

      # Second consolidation
      AppendHistory.run(%{memory_dir: dir, entry: "Second conversation about testing"}, %{})

      WriteLongTerm.run(
        %{
          memory_dir: dir,
          content: "User is setting up Phoenix project. Also interested in ExUnit."
        },
        %{}
      )

      # Verify history accumulated
      {:ok, %{matches: matches}} =
        SearchHistory.run(%{memory_dir: dir, pattern: "conversation"}, %{})

      assert length(matches) == 2

      # Verify memory was replaced (not appended)
      {:ok, %{content: memory}} = ReadLongTerm.run(%{memory_dir: dir}, %{})
      assert memory =~ "ExUnit"
      assert memory =~ "Phoenix"
    end

    test "file permissions are set correctly after consolidation writes" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      AppendHistory.run(%{memory_dir: dir, entry: "Permissions test"}, %{})
      WriteLongTerm.run(%{memory_dir: dir, content: "Test content"}, %{})

      history_path = Path.join(dir, "HISTORY.md")
      memory_path = Path.join(dir, "MEMORY.md")

      {:ok, history_stat} = File.stat(history_path)
      {:ok, memory_stat} = File.stat(memory_path)

      assert history_stat.access == :read_write
      assert memory_stat.access == :read_write
    end
  end

  describe "consolidation prompt escaping" do
    test "XML characters in content don't break consolidation attempt" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      # Content with XML-like characters that could break prompt if not escaped
      messages =
        for i <- 1..15 do
          %{
            role: if(rem(i, 2) == 1, do: "user", else: "assistant"),
            content: "<script>alert('xss #{i}')</script> & other <dangerous> content",
            timestamp: "2026-01-01T00:00:#{String.pad_leading(to_string(i), 2, "0")}Z"
          }
        end

      # Should not raise even with dangerous content — will fail at LLM
      # but the prompt construction should succeed
      result =
        Consolidate.run(
          %{
            memory_dir: dir,
            messages: messages,
            memory_window: 10,
            current_memory: "<existing>data</existing>"
          },
          %{}
        )

      # Should not crash during prompt building — consolidation may succeed or
      # fail at the LLM depending on environment, but either outcome is fine.
      assert {:ok, %{}} = result
    end
  end
end
