defmodule Goodwizard.Actions.Shell.Exec do
  @moduledoc """
  Executes a shell command with safety guards, timeout, and output truncation.
  """

  use Jido.Action,
    name: "exec",
    description: "Execute a shell command",
    schema: [
      command: [type: :string, required: true, doc: "Shell command to execute"],
      working_dir: [type: :string, doc: "Working directory for the command"],
      timeout: [type: :integer, default: 60, doc: "Timeout in seconds"]
    ]

  @max_output 10_000
  @default_deny_pattern_sources [
    ~S/\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|--recursive\s+--force|-[a-zA-Z]*f[a-zA-Z]*r)\b/,
    ~S/\b(shutdown|reboot|poweroff)\b/,
    ~S/\b(mkfs|diskpart)\b/,
    ~S/\$\(/,
    ~S/`/,
    ~S/\|/,
    ~S/[<>]\(/,
    ~S/\bcurl\b/,
    ~S/\b(sudo|su|doas)\b/,
    ~S/\b(chmod|chown|chgrp)\b/,
    ~S/\b(kill|killall|pkill)\b/
  ]

  @impl true
  def run(params, _context) do
    command = params.command
    working_dir = Map.get(params, :working_dir)
    timeout = Map.get(params, :timeout, 60)
    deny_patterns = build_deny_patterns(params)
    allow_patterns = build_allow_patterns(params)

    with {:ok, deny_patterns} <- deny_patterns,
         {:ok, allow_patterns} <- allow_patterns,
         :ok <- check_allow_patterns(command, allow_patterns),
         :ok <- check_deny_patterns(command, deny_patterns),
         :ok <- check_workspace_restriction(command, working_dir) do
      execute(command, working_dir, timeout)
    end
  end

  defp check_allow_patterns(_command, []), do: :ok

  defp check_allow_patterns(command, patterns) do
    if Enum.any?(patterns, &Regex.match?(&1, command)) do
      :ok
    else
      {:error, "Command '#{String.slice(command, 0, 80)}' not in allowlist"}
    end
  end

  defp check_deny_patterns(command, patterns) do
    case Enum.find(patterns, &Regex.match?(&1, command)) do
      nil ->
        :ok

      matched ->
        {:error,
         "Command '#{String.slice(command, 0, 80)}' blocked by safety guard " <>
           "(dangerous pattern detected: #{Regex.source(matched)})"}
    end
  end

  defp check_workspace_restriction(command, working_dir) do
    if restrict_to_workspace?() do
      check_workspace_paths(command, working_dir)
    else
      :ok
    end
  end

  defp check_workspace_paths(command, working_dir) do
    cond do
      String.contains?(command, "../") ->
        {:error, "Command blocked by safety guard (path traversal detected)"}

      Regex.match?(~r/\$\w|\$\{/, command) ->
        {:error, "Command blocked by safety guard (variable expansion detected)"}

      Regex.match?(~r/\b(cd|pushd|popd)\b/, command) ->
        {:error, "Command blocked by safety guard (directory change detected)"}

      has_outside_absolute_path?(command, working_dir) ->
        {:error, "Command blocked by safety guard (path outside working dir)"}

      true ->
        :ok
    end
  end

  defp build_allow_patterns(params) do
    patterns =
      case Map.get(params, :allow_patterns) do
        list when is_list(list) -> list
        _ -> []
      end

    compile_patterns(patterns, "allow")
  end

  defp build_deny_patterns(params) do
    custom_patterns =
      case Map.get(params, :deny_patterns) do
        list when is_list(list) -> list
        _ -> []
      end

    patterns = @default_deny_pattern_sources ++ deny_patterns_from_config() ++ custom_patterns
    compile_patterns(patterns, "deny")
  end

  defp compile_patterns(pattern_sources, kind) do
    Enum.reduce_while(pattern_sources, {:ok, []}, fn source, {:ok, acc} ->
      source = to_string(source)

      case Regex.compile(source) do
        {:ok, regex} ->
          {:cont, {:ok, [regex | acc]}}

        {:error, reason} ->
          {:halt, {:error, "Invalid regex pattern in #{kind}_patterns: #{inspect(reason)}"}}
      end
    end)
    |> case do
      {:ok, patterns} -> {:ok, Enum.reverse(patterns)}
      {:error, _} = error -> error
    end
  end

  defp deny_patterns_from_config do
    Goodwizard.Config.get(["tools", "exec", "deny_patterns"]) || []
  catch
    :exit, _ -> []
  end

  defp has_outside_absolute_path?(command, working_dir) when is_binary(working_dir) do
    expanded_dir = Path.expand(working_dir)

    Regex.scan(~r/(?:^|\s)(\/\S+)/, command)
    |> Enum.any?(fn [_full, path] ->
      not String.starts_with?(path, expanded_dir)
    end)
  end

  defp has_outside_absolute_path?(_command, _working_dir), do: false

  defp restrict_to_workspace? do
    Goodwizard.Config.get(["tools", "restrict_to_workspace"]) != false
  catch
    :exit, _ -> true
  end

  defp execute(command, working_dir, timeout) do
    opts = [stderr_to_stdout: true]
    opts = if working_dir, do: [{:cd, Path.expand(working_dir)} | opts], else: opts

    task =
      Task.async(fn ->
        System.cmd("sh", ["-c", command], opts)
      end)

    case Task.yield(task, :timer.seconds(timeout)) || Task.shutdown(task, :brutal_kill) do
      {:ok, {output, exit_code}} ->
        {:ok, %{output: format_output(output, exit_code)}}

      nil ->
        {:error, "Command timed out after #{timeout} seconds"}
    end
  end

  defp format_output("", 0), do: "(no output)"

  defp format_output(output, 0) do
    truncate(output)
  end

  defp format_output("", exit_code) do
    "(no output)\nExit code: #{exit_code}"
  end

  defp format_output(output, exit_code) do
    truncate(output) <> "\nExit code: #{exit_code}"
  end

  defp truncate(output) when byte_size(output) <= @max_output, do: output

  defp truncate(output) do
    truncated = String.slice(output, 0, @max_output)
    remaining = String.length(output) - String.length(truncated)
    truncated <> "\n... (truncated, #{remaining} more chars)"
  end
end
