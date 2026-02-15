defmodule Goodwizard.Actions.Filesystem.GrepFileTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Filesystem.GrepFile

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "grepfile_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  test "pattern found in single file returns ok with matches", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "hello.ex")
    File.write!(path, "defmodule Hello do\n  def greet, do: :hello\nend\n")

    assert {:ok, %{matches: matches, match_count: count}} =
             GrepFile.run(%{path: path, pattern: "greet"}, %{})

    assert count >= 1
    assert matches =~ "greet"
  end

  test "recursive directory search finds matches across files", %{tmp_dir: tmp_dir} do
    sub = Path.join(tmp_dir, "sub")
    File.mkdir_p!(sub)
    File.write!(Path.join(tmp_dir, "a.txt"), "hello world\n")
    File.write!(Path.join(sub, "b.txt"), "hello again\n")

    assert {:ok, %{matches: matches, match_count: count}} =
             GrepFile.run(%{path: tmp_dir, pattern: "hello"}, %{})

    assert count >= 2
    assert matches =~ "a.txt"
    assert matches =~ "b.txt"
  end

  test "no matches returns ok with zero match_count", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "empty_match.txt")
    File.write!(path, "nothing here\n")

    assert {:ok, %{matches: "No matches found.", match_count: 0}} =
             GrepFile.run(%{path: path, pattern: "zzz_no_match_zzz"}, %{})
  end

  test "path does not exist returns error", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "nonexistent.txt")

    assert {:error, "Path not found: " <> _} =
             GrepFile.run(%{path: path, pattern: "anything"}, %{})
  end

  test "case-insensitive search with case_sensitive: false", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "case.txt")
    File.write!(path, "Hello World\nhello world\nHELLO WORLD\n")

    assert {:ok, %{matches: matches, match_count: count}} =
             GrepFile.run(%{path: path, pattern: "hello", case_sensitive: false}, %{})

    assert count >= 3
    assert matches =~ "Hello"
    assert matches =~ "hello"
    assert matches =~ "HELLO"
  end

  test "context lines included when context_lines > 0", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "context.txt")
    File.write!(path, "line1\nline2\nMATCH\nline4\nline5\n")

    assert {:ok, %{matches: matches, match_count: count}} =
             GrepFile.run(%{path: path, pattern: "MATCH", context_lines: 1}, %{})

    assert matches =~ "line2"
    assert matches =~ "MATCH"
    assert matches =~ "line4"
    # match_count should only count the actual match, not context lines
    assert count == 1
  end

  test "file glob filtering limits searched files", %{tmp_dir: tmp_dir} do
    File.write!(Path.join(tmp_dir, "code.ex"), "target_pattern\n")
    File.write!(Path.join(tmp_dir, "data.txt"), "target_pattern\n")

    assert {:ok, %{matches: matches}} =
             GrepFile.run(%{path: tmp_dir, pattern: "target_pattern", file_glob: "*.ex"}, %{})

    assert matches =~ "code.ex"
    refute matches =~ "data.txt"
  end

  test "result truncation when matches exceed max_results", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "many.txt")
    content = Enum.map_join(1..50, "\n", fn i -> "match_line_#{i}" end)
    File.write!(path, content <> "\n")

    assert {:ok, %{matches: _matches, match_count: count}} =
             GrepFile.run(%{path: path, pattern: "match_line", max_results: 5}, %{})

    assert count <= 5
  end

  test "nonexistent path returns path-not-found error format" do
    path = "/nonexistent_path_for_test"

    result = GrepFile.run(%{path: path, pattern: "test"}, %{})

    assert {:error, "Path not found: " <> _} = result
  end

  test "character truncation when output exceeds max_chars", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "big.txt")
    # Each line is ~100 chars; 200 lines should exceed 10,000 chars
    content =
      Enum.map_join(1..200, "\n", fn i -> "match_#{String.pad_leading(to_string(i), 90, "x")}" end)

    File.write!(path, content <> "\n")

    assert {:ok, %{matches: matches}} =
             GrepFile.run(%{path: path, pattern: "match_", max_results: 200}, %{})

    assert matches =~ "truncated"
    assert matches =~ "more chars"
  end

  test "malformed regex returns search error", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "regex_test.txt")
    File.write!(path, "some content\n")

    assert {:error, "Search failed: " <> _} =
             GrepFile.run(%{path: path, pattern: "["}, %{})
  end

  test "non-recursive search does not match files in subdirectories", %{tmp_dir: tmp_dir} do
    sub = Path.join(tmp_dir, "nested")
    File.mkdir_p!(sub)
    File.write!(Path.join(tmp_dir, "top.txt"), "findme\n")
    File.write!(Path.join(sub, "deep.txt"), "findme\n")

    assert {:ok, %{matches: matches}} =
             GrepFile.run(%{path: tmp_dir, pattern: "findme", recursive: false}, %{})

    assert matches =~ "top.txt"
    refute matches =~ "deep.txt"
  end

  test "context_lines above max returns error", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "ctx.txt")
    File.write!(path, "content\n")

    assert {:error, "context_lines must be <= 100" <> _} =
             GrepFile.run(%{path: path, pattern: "content", context_lines: 999_999}, %{})
  end

  test "pattern starting with dash does not trigger flag injection", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "dash.txt")
    File.write!(path, "--help\n--version\nnormal line\n")

    result = GrepFile.run(%{path: path, pattern: "--help"}, %{})

    # Should find the literal text, not trigger rg/grep help output
    assert {:ok, %{matches: matches, match_count: count}} = result
    assert count >= 1
    assert matches =~ "--help"
  end

  test "fixed_string search treats metacharacters literally", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "literal.txt")
    File.write!(path, "foo.bar\nfooXbar\n")

    assert {:ok, %{matches: matches, match_count: count}} =
             GrepFile.run(%{path: path, pattern: "foo.bar", fixed_string: true}, %{})

    assert count == 1
    assert matches =~ "foo.bar"
    refute matches =~ "fooXbar"
  end

  test "invalid file_glob returns error", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "glob_test.txt")
    File.write!(path, "content\n")

    assert {:error, "Invalid file_glob: contains unsafe characters"} =
             GrepFile.run(%{path: path, pattern: "content", file_glob: "*.ex; rm -rf /"}, %{})
  end
end
