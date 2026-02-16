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
  end
end
