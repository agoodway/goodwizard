defmodule Mix.Tasks.Goodwizard.Scenario do
  @moduledoc """
  Run Goodwizard scenarios for debugging.

      mix goodwizard.scenario list
      mix goodwizard.scenario run smoke_test
      mix goodwizard.scenario run "Hello, who are you?"
  """

  use Mix.Task

  alias Goodwizard.Scenario.Loader
  alias Goodwizard.Scenario.Runner

  @shortdoc "Run or list Goodwizard debug scenarios"
  @bootstrap_files ~w(AGENTS.md HEARTBEAT.md IDENTITY.md SOUL.md TOOLS.md USER.md worldcities.csv)

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, argv, _invalid} =
      OptionParser.parse(args,
        strict: [workspace: :string, timeout: :integer, no_cleanup: :boolean]
      )

    case argv do
      ["list"] ->
        list_scenarios()

      ["run" | rest] ->
        run_scenario(rest, opts)

      _ ->
        print_usage()
    end
  end

  defp run_scenario([], _opts) do
    Mix.raise("Missing scenario name or inline query.")
  end

  defp run_scenario(args, opts) do
    scenario_arg = Enum.join(args, " ")

    with {:ok, workspace, cleanup?} <- resolve_workspace(opts),
         {:ok, scenario} <- resolve_scenario(scenario_arg),
         {:ok, result} <- execute_scenario(scenario, workspace, opts) do
      print_result(result)
      maybe_print_workspace(workspace, cleanup?, opts)
      maybe_cleanup(workspace, cleanup?, opts)
    else
      {:error, {:not_found, available}} ->
        Mix.shell().error("Scenario not found. Available: #{Enum.join(available, ", ")}")
        maybe_cleanup_from_error(opts)

      {:error, reason} ->
        Mix.shell().error("Scenario run failed: #{inspect(reason)}")
        maybe_cleanup_from_error(opts)
    end
  end

  defp execute_scenario(scenario, workspace, opts) do
    timeout = Keyword.get(opts, :timeout, 120_000)
    steps = Map.get(scenario, :steps, [])

    # Override Config.workspace() so plugins and actions use the scenario workspace.
    # The GenServer handle_call({:put, ...}) is always available; only the public
    # Config.put/2 API is gated to :test env.
    original_workspace = Goodwizard.Config.workspace()
    GenServer.call(Goodwizard.Config, {:put, ["agent", "workspace"], workspace})

    try do
      Runner.execute(scenario,
        workspace: workspace,
        timeout: timeout,
        progress: fn index, step ->
          step_type = Map.get(step, :type, :unknown)
          Mix.shell().info("step #{index + 1}/#{length(steps)}: #{step_type}")
        end
      )
    after
      GenServer.call(Goodwizard.Config, {:put, ["agent", "workspace"], original_workspace})
    end
  end

  defp list_scenarios do
    case Loader.list() do
      {:ok, scenarios} ->
        Mix.shell().info("Available scenarios:")
        Enum.each(scenarios, &print_scenario_line/1)

      {:error, reason} ->
        Mix.shell().error("Failed to list scenarios: #{inspect(reason)}")
    end
  end

  defp print_scenario_line(scenario) do
    description =
      case scenario.description do
        value when is_binary(value) and value != "" -> value
        _ -> "(no description)"
      end

    Mix.shell().info("  - #{scenario.name}: #{description}")
  end

  defp resolve_scenario(scenario_arg) do
    if String.contains?(scenario_arg, " ") do
      {:ok, inline_scenario(scenario_arg)}
    else
      case Loader.load(scenario_arg) do
        {:ok, scenario} -> {:ok, scenario}
        {:error, {:not_found, _available}} -> {:ok, inline_scenario(scenario_arg)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp inline_scenario(query) do
    %{
      name: "inline",
      description: "Inline scenario query",
      steps: [%{type: :query, query: query}],
      assertions: []
    }
  end

  defp resolve_workspace(opts) do
    case Keyword.get(opts, :workspace) do
      nil ->
        create_temp_workspace()

      provided ->
        {:ok, Path.expand(provided), false}
    end
  end

  defp create_temp_workspace do
    temp_workspace =
      Path.join(
        System.tmp_dir!(),
        "goodwizard-scenario-#{System.unique_integer([:positive, :monotonic])}"
      )

    with :ok <- File.mkdir_p(temp_workspace),
         :ok <- create_workspace_dirs(temp_workspace),
         :ok <- copy_workspace_artifacts(Goodwizard.Config.workspace(), temp_workspace) do
      {:ok, temp_workspace, true}
    end
  end

  defp create_workspace_dirs(workspace) do
    dirs = [
      Path.join(workspace, "memory"),
      Path.join(workspace, "memory/episodic"),
      Path.join(workspace, "memory/procedural"),
      Path.join(workspace, "sessions"),
      Path.join(workspace, "skills"),
      Path.join(workspace, "brain"),
      Path.join(workspace, "brain/schemas")
    ]

    Enum.reduce_while(dirs, :ok, fn dir, :ok ->
      case File.mkdir_p(dir) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp copy_workspace_artifacts(source_workspace, temp_workspace) do
    schema_source = Path.join(source_workspace, "brain/schemas")
    schema_dest = Path.join(temp_workspace, "brain/schemas")

    with :ok <- copy_bootstrap_files(source_workspace, temp_workspace),
         :ok <- copy_directory_files(schema_source, schema_dest),
         :ok <- copy_memory_markdown(source_workspace, temp_workspace),
         :ok <- copy_skills(source_workspace, temp_workspace) do
      :ok
    end
  end

  defp copy_bootstrap_files(source_workspace, temp_workspace) do
    Enum.reduce_while(@bootstrap_files, :ok, fn filename, :ok ->
      src = Path.join(source_workspace, filename)
      dst = Path.join(temp_workspace, filename)

      case copy_if_exists(src, dst) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp copy_memory_markdown(source_workspace, temp_workspace) do
    src = Path.join(source_workspace, "memory/MEMORY.md")
    dst = Path.join(temp_workspace, "memory/MEMORY.md")
    copy_if_exists(src, dst)
  end

  defp copy_skills(source_workspace, temp_workspace) do
    source = Path.join(source_workspace, "skills")
    dest = Path.join(temp_workspace, "skills")

    if File.dir?(source) do
      case File.cp_r(source, dest) do
        {:ok, _} -> :ok
        {:error, reason, _file} -> {:error, reason}
      end
    else
      :ok
    end
  end

  defp copy_directory_files(source_dir, destination_dir) do
    case File.mkdir_p(destination_dir) do
      :ok ->
        copy_directory_entries(source_dir, destination_dir)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp copy_directory_entries(source_dir, destination_dir) do
    case File.ls(source_dir) do
      {:ok, files} ->
        Enum.reduce_while(files, :ok, &copy_directory_entry(&1, &2, source_dir, destination_dir))

      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp copy_directory_entry(file, :ok, source_dir, destination_dir) do
    src = Path.join(source_dir, file)
    dst = Path.join(destination_dir, file)

    case copy_regular_file(src, dst) do
      :ok -> {:cont, :ok}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp copy_regular_file(src, dst) do
    if File.regular?(src), do: File.cp(src, dst), else: :ok
  end

  defp copy_if_exists(src, dst) do
    if File.exists?(src) do
      File.cp(src, dst)
    else
      :ok
    end
  end

  defp maybe_print_workspace(workspace, cleanup?, opts) do
    if cleanup? and Keyword.get(opts, :no_cleanup, false) do
      Mix.shell().info("Workspace retained: #{workspace}")
    end
  end

  defp maybe_cleanup(workspace, cleanup?, opts) do
    if cleanup? and not Keyword.get(opts, :no_cleanup, false) do
      File.rm_rf(workspace)
    end
  end

  defp maybe_cleanup_from_error(opts) do
    if Keyword.has_key?(opts, :workspace) do
      :ok
    else
      :ok
    end
  end

  defp print_result(result) do
    Mix.shell().info("=== Scenario Result ===")
    Mix.shell().info("name: #{result.name}")
    Mix.shell().info("status: #{String.upcase(to_string(result.status))}")
    Mix.shell().info("duration_ms: #{result.duration_ms}")
    Mix.shell().info("workspace: #{result.workspace}")
    Mix.shell().info("")

    Mix.shell().info("=== Steps ===")

    Enum.each(result.steps, fn step ->
      Mix.shell().info("[step #{step.index}] type=#{step.type} status=#{step.status}")

      if is_binary(step.query) do
        Mix.shell().info("query: #{step.query}")
      end

      if is_binary(step.response) do
        Mix.shell().info("response: #{step.response}")
      end

      if is_binary(step.error) do
        Mix.shell().info("error: #{step.error}")
      end

      Mix.shell().info("duration_ms: #{step.duration_ms}")
      Mix.shell().info("")
    end)

    Mix.shell().info("=== Tool Calls ===")
    Mix.shell().info("count: #{length(result.tool_calls)}")

    Enum.each(result.tool_calls, fn call ->
      Mix.shell().info(
        "- tool=#{call.tool_name} status=#{call.status} duration_ms=#{call.duration_ms}"
      )
    end)

    Mix.shell().info("")
    Mix.shell().info("=== Log Entries ===")
    Mix.shell().info("count: #{length(result.log_entries)}")

    Enum.each(result.log_entries, fn entry ->
      Mix.shell().info("- [#{entry.level}] #{entry.message}")
    end)

    Mix.shell().info("")
    Mix.shell().info("=== Assertions ===")

    Enum.each(result.assertions, fn assertion ->
      verdict = if assertion.passed, do: "PASS", else: "FAIL"
      Mix.shell().info("- [#{verdict}] #{assertion.type}: #{assertion.message}")
    end)
  end

  defp print_usage do
    Mix.shell().info("""
    Usage:
      mix goodwizard.scenario list
      mix goodwizard.scenario run <scenario_name_or_query> [--workspace PATH] [--timeout MS] [--no-cleanup]
    """)
  end
end
