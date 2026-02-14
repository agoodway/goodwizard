defmodule Goodwizard.Actions.Memory.HistoryTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.AppendHistory
  alias Goodwizard.Actions.Memory.SearchHistory

  defp tmp_memory_dir do
    dir = Path.join(System.tmp_dir!(), "test_memory_hist_#{:rand.uniform(100_000)}")
    File.mkdir_p!(dir)
    dir
  end

  describe "AppendHistory" do
    test "appends timestamped entry to HISTORY.md" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      assert {:ok, %{message: "Appended entry to HISTORY.md"}} =
               AppendHistory.run(%{memory_dir: dir, entry: "User asked about Elixir"}, %{})

      content = File.read!(Path.join(dir, "HISTORY.md"))
      assert content =~ "User asked about Elixir"
      assert content =~ ~r/^\[.+\] User asked about Elixir\n$/
    end

    test "preserves order of multiple appends" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      AppendHistory.run(%{memory_dir: dir, entry: "First entry"}, %{})
      AppendHistory.run(%{memory_dir: dir, entry: "Second entry"}, %{})
      AppendHistory.run(%{memory_dir: dir, entry: "Third entry"}, %{})

      lines =
        Path.join(dir, "HISTORY.md")
        |> File.read!()
        |> String.split("\n", trim: true)

      assert length(lines) == 3
      assert Enum.at(lines, 0) =~ "First entry"
      assert Enum.at(lines, 1) =~ "Second entry"
      assert Enum.at(lines, 2) =~ "Third entry"
    end

    test "creates file if missing" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      refute File.exists?(Path.join(dir, "HISTORY.md"))

      AppendHistory.run(%{memory_dir: dir, entry: "First!"}, %{})

      assert File.exists?(Path.join(dir, "HISTORY.md"))
    end
  end

  describe "SearchHistory" do
    test "finds matching lines (case-insensitive)" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(Path.join(dir, "HISTORY.md"), """
      [2026-01-01T00:00:00Z] User asked about Elixir patterns
      [2026-01-01T01:00:00Z] Discussed Python testing
      [2026-01-01T02:00:00Z] User asked about ELIXIR macros
      """)

      assert {:ok, %{matches: matches}} =
               SearchHistory.run(%{memory_dir: dir, pattern: "elixir"}, %{})

      assert length(matches) == 2
      assert Enum.at(matches, 0) =~ "Elixir patterns"
      assert Enum.at(matches, 1) =~ "ELIXIR macros"
    end

    test "returns empty list when no matches" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(Path.join(dir, "HISTORY.md"), "[2026-01-01T00:00:00Z] Some entry\n")

      assert {:ok, %{matches: []}} =
               SearchHistory.run(%{memory_dir: dir, pattern: "nonexistent"}, %{})
    end

    test "returns empty list when HISTORY.md missing" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      assert {:ok, %{matches: []}} =
               SearchHistory.run(%{memory_dir: dir, pattern: "anything"}, %{})
    end
  end

  describe "append then search round-trip" do
    test "appended entries are searchable" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      AppendHistory.run(%{memory_dir: dir, entry: "Configured Phoenix LiveView"}, %{})
      AppendHistory.run(%{memory_dir: dir, entry: "Set up Tailwind CSS"}, %{})
      AppendHistory.run(%{memory_dir: dir, entry: "Phoenix deployment to Fly.io"}, %{})

      assert {:ok, %{matches: matches}} =
               SearchHistory.run(%{memory_dir: dir, pattern: "phoenix"}, %{})

      assert length(matches) == 2
    end
  end
end
