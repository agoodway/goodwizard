defmodule Goodwizard.Scenario.RunnerTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Scenario.Runner

  describe "telemetry collector" do
    test "captures completed tool events" do
      {:ok, collector} = Runner.start_telemetry_collector()
      on_exit(fn -> Runner.stop_telemetry_collector(collector) end)

      :telemetry.execute(
        [:jido, :ai, :tool, :execute, :stop],
        %{duration: System.convert_time_unit(25, :millisecond, :native)},
        %{tool_name: "read_file", result: {:ok, "ok"}}
      )

      tool_calls = Runner.collect_tool_calls(collector)
      assert length(tool_calls) == 1
      assert Enum.at(tool_calls, 0).tool_name == "read_file"
      assert Enum.at(tool_calls, 0).status == :ok
      assert Enum.at(tool_calls, 0).duration_ms >= 25
    end
  end

  describe "setup steps" do
    test "write_file and delete_file mutate workspace safely" do
      workspace =
        Path.join(
          System.tmp_dir!(),
          "scenario_runner_#{System.unique_integer([:positive, :monotonic])}"
        )

      File.mkdir_p!(workspace)
      on_exit(fn -> File.rm_rf!(workspace) end)

      write_step = %{type: :setup, action: :write_file, path: "tmp/note.txt", content: "hello"}
      assert :ok = Runner.apply_setup_step(workspace, write_step)

      file_path = Path.join(workspace, "tmp/note.txt")
      assert File.exists?(file_path)
      assert File.read!(file_path) == "hello"

      delete_step = %{type: :setup, action: :delete_file, path: "tmp/note.txt"}
      assert :ok = Runner.apply_setup_step(workspace, delete_step)
      refute File.exists?(file_path)
    end

    test "rejects setup path traversal outside workspace" do
      workspace =
        Path.join(
          System.tmp_dir!(),
          "scenario_runner_#{System.unique_integer([:positive, :monotonic])}"
        )

      File.mkdir_p!(workspace)
      on_exit(fn -> File.rm_rf!(workspace) end)

      traversal = %{type: :setup, action: :write_file, path: "../outside.txt", content: "nope"}
      assert {:error, :path_outside_workspace} = Runner.apply_setup_step(workspace, traversal)
    end
  end

  describe "assertion evaluator" do
    test "evaluates response, log, budget, and tool assertions" do
      context = %{
        steps: [
          %Runner.QueryResult{
            index: 0,
            type: :query,
            query: "hello",
            response: "Goodwizard says hello",
            duration_ms: 10,
            status: :ok,
            tool_calls: [],
            log_entries: []
          }
        ],
        tool_calls: [
          %Runner.ToolCall{
            tool_name: "read_file",
            status: :ok,
            duration_ms: 10,
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
            metadata: %{}
          }
        ],
        log_entries: [%{level: :info, message: "ok"}],
        duration_ms: 42
      }

      assertions = [
        %{type: :response_contains, step_index: 0, value: "goodwizard"},
        %{type: :no_errors},
        %{type: :tool_called, value: "read_file"},
        %{type: :tool_not_called, value: "exec"},
        %{type: :max_duration_ms, value: 100},
        %{type: :max_tool_calls, value: 2}
      ]

      results = Runner.evaluate_assertions(assertions, context)
      assert Enum.all?(results, & &1.passed)
    end
  end
end
