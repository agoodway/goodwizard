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
      timeout: [type: :integer, default: 60, doc: "Timeout in seconds"],
      deny_patterns: [type: {:list, :string}, doc: "Regex patterns to block"],
      allow_patterns: [type: {:list, :string}, doc: "Regex patterns to allow"],
      restrict_to_workspace: [type: :boolean, default: false, doc: "Block path traversal"]
    ]

  @max_output 10_000

  @default_deny_patterns [
    ~r/\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|--recursive\s+--force|-[a-zA-Z]*f[a-zA-Z]*r)\b/,
    ~r/\bdel\s+\/[fq]\b/i,
    ~r/\brmdir\s+\/s\b/i,
    ~r/\b(mkfs|format|diskpart)\b/i,
    ~r/\bdd\s+if=/,
    ~r/\/dev\/sd[a-z]/,
    ~r/\b(shutdown|reboot|poweroff)\b/,
    ~r/:\(\)\{\s*:\|:\s*&\s*\}\s*;/,
    # Shell metacharacter injection
    ~r/\$\(/,
    ~r/`/,
    ~r/\|/,
    ~r/[<>]\(/,
    # Network commands
    ~r/\b(curl|wget|nc|ncat|netcat)\b/,
    # Process and permission commands
    ~r/\b(kill|killall|pkill)\b/,
    ~r/\b(chmod|chown|chgrp)\b/,
    ~r/\b(sudo|su|doas)\b/,
    ~r/\b(crontab)\b/
  ]

  @impl true
  def run(params, _context) do
    command = params.command
    working_dir = Map.get(params, :working_dir)
    timeout = Map.get(params, :timeout, 60)
    restrict = Map.get(params, :restrict_to_workspace, false)

    with {:ok, deny_patterns} <-
           compile_patterns(Map.get(params, :deny_patterns), @default_deny_patterns),
         {:ok, allow_patterns} <- compile_patterns(Map.get(params, :allow_patterns), nil),
         :ok <- check_deny_patterns(command, deny_patterns),
         :ok <- check_allow_patterns(command, allow_patterns),
         :ok <- check_workspace_restriction(command, working_dir, restrict) do
      execute(command, working_dir, timeout)
    end
  end

  defp check_deny_patterns(command, patterns) do
    if Enum.any?(patterns, &Regex.match?(&1, command)) do
      {:error, "Command blocked by safety guard (dangerous pattern detected)"}
    else
      :ok
    end
  end

  defp check_allow_patterns(_command, nil), do: :ok

  defp check_allow_patterns(command, patterns) do
    if Enum.any?(patterns, &Regex.match?(&1, command)) do
      :ok
    else
      {:error, "Command blocked by safety guard (not in allowlist)"}
    end
  end

  defp check_workspace_restriction(_command, _working_dir, false), do: :ok

  defp check_workspace_restriction(command, working_dir, true) do
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

  defp compile_patterns(nil, default), do: {:ok, default}

  defp compile_patterns(patterns, _default) do
    results = Enum.map(patterns, &Regex.compile/1)

    case Enum.find(results, &match?({:error, _}, &1)) do
      {:error, {msg, _}} -> {:error, "Invalid regex pattern: #{msg}"}
      nil -> {:ok, Enum.map(results, fn {:ok, regex} -> regex end)}
    end
  end

  defp has_outside_absolute_path?(command, working_dir) when is_binary(working_dir) do
    expanded_dir = Path.expand(working_dir)

    Regex.scan(~r/(?:^|\s)(\/\S+)/, command)
    |> Enum.any?(fn [_full, path] ->
      not String.starts_with?(path, expanded_dir)
    end)
  end

  defp has_outside_absolute_path?(_command, _working_dir), do: false

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
