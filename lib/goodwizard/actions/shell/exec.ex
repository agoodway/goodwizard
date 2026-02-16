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

  @impl true
  def run(params, _context) do
    command = params.command
    working_dir = Map.get(params, :working_dir)
    timeout = Map.get(params, :timeout, 60)

    with :ok <- check_deny_patterns(command, deny_patterns_from_config()),
         :ok <- check_workspace_restriction(command, working_dir) do
      execute(command, working_dir, timeout)
    end
  end

  defp check_deny_patterns(command, patterns) do
    case Enum.find(patterns, &Regex.match?(&1, command)) do
      nil ->
        :ok

      matched ->
        {:error,
         "Command '#{String.slice(command, 0, 80)}' blocked by safety guard " <>
           "(matched deny pattern: #{Regex.source(matched)})"}
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

  defp deny_patterns_from_config do
    Goodwizard.Config.get(["tools", "exec", "deny_patterns"])
    |> Enum.map(&Regex.compile!/1)
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
