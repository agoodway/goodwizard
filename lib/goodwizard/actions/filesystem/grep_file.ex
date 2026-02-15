defmodule Goodwizard.Actions.Filesystem.GrepFile do
  @moduledoc """
  Searches file contents by pattern using ripgrep (rg) or grep.
  """

  @max_chars 10_000
  @max_context_lines 100
  @timeout_ms 30_000
  @safe_glob_pattern ~r/\A[\w.*?\[\]{},\/\-]+\z/

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
        doc: "Lines of context before and after matches (max #{@max_context_lines})"
      ],
      file_glob: [type: :string, doc: "Glob pattern to filter files (e.g. \"*.ex\")"],
      max_results: [type: :integer, default: 100, doc: "Maximum number of matching lines"],
      fixed_string: [
        type: :boolean,
        default: false,
        doc: "Treat pattern as literal string, not regex"
      ]
    ]

  alias Goodwizard.Actions.Filesystem

  @impl true
  def run(params, _context) do
    with {:ok, resolved} <- Filesystem.resolve_path(params.path),
         :ok <- check_path_exists(resolved),
         :ok <- validate_context_lines(params),
         :ok <- validate_file_glob(params),
         {:ok, backend} <- detect_backend() do
      args = build_args(backend, params, resolved)

      case exec_with_timeout(backend, args) do
        {:ok, {output, 0}} ->
          format_results(output, params)

        {:ok, {_output, 1}} ->
          {:ok, %{matches: "No matches found.", match_count: 0}}

        {:ok, {error_output, _code}} ->
          {:error, "Search failed: #{String.trim(error_output)}"}

        {:error, :timeout} ->
          {:error, "Search timed out after #{div(@timeout_ms, 1000)}s"}
      end
    end
  end

  defp exec_with_timeout(backend, args) do
    task = Task.async(fn -> System.cmd(backend, args, stderr_to_stdout: true) end)

    case Task.yield(task, @timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> {:ok, result}
      nil -> {:error, :timeout}
    end
  end

  defp check_path_exists(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, "Path not found: #{path}"}
    end
  end

  defp validate_context_lines(params) do
    context_lines = Map.get(params, :context_lines, 0)

    if context_lines > @max_context_lines do
      {:error, "context_lines must be <= #{@max_context_lines}, got: #{context_lines}"}
    else
      :ok
    end
  end

  defp validate_file_glob(params) do
    case Map.get(params, :file_glob) do
      nil ->
        :ok

      glob when is_binary(glob) ->
        if Regex.match?(@safe_glob_pattern, glob) do
          :ok
        else
          {:error, "Invalid file_glob: contains unsafe characters"}
        end
    end
  end

  defp detect_backend do
    case System.find_executable("rg") do
      nil ->
        case System.find_executable("grep") do
          nil ->
            {:error, "No search tool available: install ripgrep (rg) or ensure grep is on PATH"}

          path ->
            {:ok, path}
        end

      path ->
        {:ok, path}
    end
  end

  defp build_args(backend, params, resolved) do
    if Path.basename(backend) == "rg" do
      build_rg_args(params, resolved)
    else
      build_grep_args(params, resolved)
    end
  end

  defp build_rg_args(params, resolved) do
    args = ["--no-config", "--color=never", "--no-heading", "--line-number", "--with-filename"]

    args = if Map.get(params, :case_sensitive, true), do: args, else: args ++ ["-i"]
    args = if Map.get(params, :recursive, true), do: args, else: args ++ ["--max-depth", "1"]
    args = if Map.get(params, :fixed_string, false), do: args ++ ["-F"], else: args

    context_lines = Map.get(params, :context_lines, 0)
    args = if context_lines > 0, do: args ++ ["-C", to_string(context_lines)], else: args

    args =
      case Map.get(params, :file_glob) do
        nil -> args
        glob -> args ++ ["--glob", glob]
      end

    args ++ ["--", params.pattern, resolved]
  end

  defp build_grep_args(params, resolved) do
    args = ["-n", "-H", "--color=never"]

    args = if Map.get(params, :case_sensitive, true), do: args, else: args ++ ["-i"]
    args = if Map.get(params, :recursive, true), do: args ++ ["-r"], else: args
    args = if Map.get(params, :fixed_string, false), do: args ++ ["-F"], else: args

    context_lines = Map.get(params, :context_lines, 0)
    args = if context_lines > 0, do: args ++ ["-C", to_string(context_lines)], else: args

    args =
      case Map.get(params, :file_glob) do
        nil -> args
        glob -> args ++ ["--include", glob]
      end

    args ++ ["--", params.pattern, resolved]
  end

  defp format_results(output, params) do
    output = String.trim(output)
    all_lines = String.split(output, "\n", trim: true)
    max_results = Map.get(params, :max_results, 100)

    # Filter out context separators ("--") to get actual match/context lines
    content_lines = Enum.reject(all_lines, &(&1 == "--"))

    # Count only actual matching lines (not context lines or separators).
    # Context lines use "file-linenum-text", match lines use "file:linenum:text".
    context_lines = Map.get(params, :context_lines, 0)

    match_count =
      if context_lines > 0 do
        Enum.count(content_lines, fn line ->
          # Match lines have ":" as the separator after the file:linenum prefix
          # Context lines use "-" separator. Both rg and grep follow this convention.
          Regex.match?(~r/^.+:\d+:/, line)
        end)
      else
        length(content_lines)
      end

    {display_lines, truncation_note} =
      if length(content_lines) > max_results do
        {Enum.take(content_lines, max_results),
         "\n(truncated, showing #{max_results} of #{length(content_lines)} lines)"}
      else
        {content_lines, ""}
      end

    matches = Enum.join(display_lines, "\n") <> truncation_note
    matches = truncate_chars(matches)

    {:ok, %{matches: matches, match_count: min(match_count, max_results)}}
  end

  defp truncate_chars(text) when byte_size(text) <= @max_chars, do: text

  defp truncate_chars(text) do
    truncated = String.slice(text, 0, @max_chars)
    remaining = String.length(text) - String.length(truncated)
    truncated <> "\n... (truncated, #{remaining} more chars)"
  end
end
