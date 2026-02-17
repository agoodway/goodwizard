defmodule Goodwizard.Character.PreambleTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Character.Preamble

  describe "generate/0" do
    test "returns a non-empty string" do
      result = Preamble.generate()

      assert is_binary(result)
      assert byte_size(result) > 0
    end

    test "includes all workspace directory names" do
      result = Preamble.generate()

      assert result =~ "brain/"
      assert result =~ "memory/"
      assert result =~ "sessions/"
      assert result =~ "skills/"
      assert result =~ "scheduling/"
    end

    test "includes all bootstrap file names" do
      result = Preamble.generate()

      assert result =~ "IDENTITY.md"
      assert result =~ "SOUL.md"
      assert result =~ "USER.md"
      assert result =~ "TOOLS.md"
      assert result =~ "AGENTS.md"
    end

    test "returns the same value on repeated calls" do
      first = Preamble.generate()
      second = Preamble.generate()

      assert first == second
    end

    test "returns valid UTF-8" do
      assert String.valid?(Preamble.generate())
    end

    test "contains Markdown headers in correct hierarchy and order" do
      result = Preamble.generate()

      orientation_pos = :binary.match(result, "## System Orientation")
      directories_pos = :binary.match(result, "### Workspace Directories")
      memory_pos = :binary.match(result, "### Memory System")
      bootstrap_pos = :binary.match(result, "### Bootstrap Files")

      assert orientation_pos != :nomatch
      assert directories_pos != :nomatch
      assert memory_pos != :nomatch
      assert bootstrap_pos != :nomatch

      {o, _} = orientation_pos
      {d, _} = directories_pos
      {m, _} = memory_pos
      {b, _} = bootstrap_pos

      assert o < d
      assert d < m
      assert m < b
    end

    test "describes semantic, episodic, and procedural memory types" do
      result = Preamble.generate()

      assert result =~ "Semantic Memory"
      assert result =~ "Episodic Memory"
      assert result =~ "Procedural Memory"
    end

    test "includes memory storage locations" do
      result = Preamble.generate()

      assert result =~ "memory/MEMORY.md"
      assert result =~ "memory/episodic/"
      assert result =~ "memory/procedural/"
    end

    test "does not end with a newline" do
      result = Preamble.generate()

      refute String.ends_with?(result, "\n")
    end

    test "uses only Unix line endings" do
      result = Preamble.generate()

      refute result =~ "\r"
    end
  end
end
