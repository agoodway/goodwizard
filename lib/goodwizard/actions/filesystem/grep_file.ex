defmodule Goodwizard.Actions.Filesystem.GrepFile do
  @moduledoc """
  Searches file contents by pattern using ripgrep (rg) or grep.
  """

  @max_chars 10_000

  use Jido.Action,
    name: "grep_file",
    description: "Search file contents by pattern using ripgrep or grep",
    schema: [
      path: [type: :string, required: true, doc: "Path to file or directory to search"],
      pattern: [type: :string, required: true, doc: "Search pattern (regex)"],
      case_sensitive: [type: :boolean, default: true, doc: "Case-sensitive search"],
      recursive: [type: :boolean, default: true, doc: "Search directories recursively"],
      context_lines: [
        type: :integer,
        default: 0,
        doc: "Lines of context before and after matches"
      ],
      file_glob: [type: :string, doc: "Glob pattern to filter files (e.g. \"*.ex\")"],
      max_results: [type: :integer, default: 100, doc: "Maximum number of matching lines"]
    ]

  alias Goodwizard.Actions.Filesystem

  @impl true
  def run(params, _context) do
    with {:ok, resolved} <- Filesystem.resolve_path(params.path),
         :ok <- check_path_exists(resolved),
         {:ok, backend} <- detect_backend() do
      args = build_args(backend, params, resolved)

      case System.cmd(backend, args, stderr_to_stdout: true) do
        {output, 0} ->
          format_results(output, params)

        {_output, 1} ->
          # Exit code 1 means no matches for both rg and grep
          {:ok, %{matches: "No matches found.", match_count: 0}}

        {error_output, _code} ->
          {:error, "Search failed: #{String.trim(error_output)}"}
      end
    end
  end

  defp check_path_exists(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, "Path not found: #{path}"}
    end
  end

  defp detect_backend do
    cond do
      System.find_executable("rg") -> {:ok, System.find_executable("rg")}
      System.find_executable("grep") -> {:ok, System.find_executable("grep")}
      true -> {:error, "No search tool available: install ripgrep (rg) or ensure grep is on PATH"}
    end
  end

  defp build_args(backend, params, resolved) do
    if String.ends_with?(backend, "rg") do
      build_rg_args(params, resolved)
    else
      build_grep_args(params, resolved)
    end
  end

  defp build_rg_args(params, resolved) do
    args = ["--no-heading", "--line-number", "--with-filename"]

    args = if Map.get(params, :case_sensitive, true), do: args, else: args ++ ["-i"]
    args = if Map.get(params, :recursive, true), do: args, else: args ++ ["--no-recursive"]

    context_lines = Map.get(params, :context_lines, 0)
    args = if context_lines > 0, do: args ++ ["-C", to_string(context_lines)], else: args

    args =
      case Map.get(params, :file_glob) do
        nil -> args
        glob -> args ++ ["--glob", glob]
      end

    max_results = Map.get(params, :max_results, 100)
    args = args ++ ["-m", to_string(max_results)]

    args ++ [params.pattern, resolved]
  end

  defp build_grep_args(params, resolved) do
    args = ["-n", "-H"]

    args = if Map.get(params, :case_sensitive, true), do: args, else: args ++ ["-i"]
    args = if Map.get(params, :recursive, true), do: args ++ ["-r"], else: args

    context_lines = Map.get(params, :context_lines, 0)
    args = if context_lines > 0, do: args ++ ["-C", to_string(context_lines)], else: args

    args =
      case Map.get(params, :file_glob) do
        nil -> args
        glob -> args ++ ["--include", glob]
      end

    max_results = Map.get(params, :max_results, 100)
    args = args ++ ["-m", to_string(max_results)]

    args ++ [params.pattern, resolved]
  end

  defp format_results(output, params) do
    output = String.trim(output)
    lines = String.split(output, "\n", trim: true)
    max_results = Map.get(params, :max_results, 100)
    total_count = length(lines)

    {lines, truncation_note} =
      if total_count > max_results do
        {Enum.take(lines, max_results),
         "\n(truncated, showing #{max_results} of #{total_count} matches)"}
      else
        {lines, ""}
      end

    matches = Enum.join(lines, "\n") <> truncation_note

    matches = truncate_chars(matches)

    {:ok, %{matches: matches, match_count: min(total_count, max_results)}}
  end

  defp truncate_chars(text) when byte_size(text) <= @max_chars, do: text

  defp truncate_chars(text) do
    truncated = String.slice(text, 0, @max_chars)
    remaining = String.length(text) - @max_chars
    truncated <> "\n... (truncated, #{remaining} more chars)"
  end
end
