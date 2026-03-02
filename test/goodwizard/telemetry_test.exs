defmodule Goodwizard.TelemetryTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Goodwizard.Telemetry

  setup do
    Telemetry.detach()
    Telemetry.attach()
    on_exit(fn -> Telemetry.detach() end)
    :ok
  end

  describe "tool events" do
    test "start logs at debug with tool name and call_id" do
      log =
        capture_log([level: :debug], fn ->
          :telemetry.execute(
            [:jido, :ai, :tool, :execute, :start],
            %{},
            %{tool_name: "read_file", call_id: "abc123", iteration: 1}
          )
        end)

      assert log =~ "tool=read_file"
      assert log =~ "event=start"
      assert log =~ "call_id=abc123"
      assert log =~ "iteration=1"
    end

    test "stop with {:ok, _} logs at info with status=ok and duration" do
      log =
        capture_log([level: :info], fn ->
          :telemetry.execute(
            [:jido, :ai, :tool, :execute, :stop],
            %{duration: System.convert_time_unit(42, :millisecond, :native)},
            %{
              tool_name: "write_file",
              result: {:ok, %{message: "done"}},
              call_id: "def456",
              thread_id: "t1"
            }
          )
        end)

      assert log =~ "tool=write_file"
      assert log =~ "event=stop"
      assert log =~ "status=ok"
      assert log =~ "duration_ms=42"
    end

    test "stop with {:error, _} logs at error with status=error and reason" do
      log =
        capture_log([level: :error], fn ->
          :telemetry.execute(
            [:jido, :ai, :tool, :execute, :stop],
            %{duration: System.convert_time_unit(10, :millisecond, :native)},
            %{
              tool_name: "create_entity",
              result: {:error, "not found"},
              call_id: "err789",
              thread_id: "t2"
            }
          )
        end)

      assert log =~ "tool=create_entity"
      assert log =~ "status=error"
      assert log =~ "reason=\"not found\""
    end

    test "exception logs at error with reason" do
      log =
        capture_log([level: :error], fn ->
          :telemetry.execute(
            [:jido, :ai, :tool, :execute, :exception],
            %{duration: System.convert_time_unit(5, :millisecond, :native)},
            %{
              tool_name: "exec",
              reason: %RuntimeError{message: "boom"},
              call_id: "exc1",
              thread_id: "t3"
            }
          )
        end)

      assert log =~ "tool=exec"
      assert log =~ "event=exception"
      assert log =~ "boom"
    end

    test "exception logs stacktrace when available" do
      stacktrace = [{MyModule, :my_fun, 2, [file: ~c"lib/my_module.ex", line: 42]}]

      log =
        capture_log([level: :error], fn ->
          :telemetry.execute(
            [:jido, :ai, :tool, :execute, :exception],
            %{duration: System.convert_time_unit(5, :millisecond, :native)},
            %{
              tool_name: "exec",
              reason: %RuntimeError{message: "crash"},
              stacktrace: stacktrace,
              call_id: "exc2",
              thread_id: "t3"
            }
          )
        end)

      assert log =~ "tool=exec"
      assert log =~ "event=exception"
      assert log =~ "crash"
      assert log =~ "my_module.ex:42"
    end

    test "stop with structured error map includes reason" do
      log =
        capture_log([level: :error], fn ->
          :telemetry.execute(
            [:jido, :ai, :tool, :execute, :stop],
            %{duration: System.convert_time_unit(3, :millisecond, :native)},
            %{
              tool_name: "schedule_scheduled_task",
              result: {:error, %{message: "invalid cron expression", field: :schedule}},
              call_id: "cron1",
              thread_id: "t4"
            }
          )
        end)

      assert log =~ "tool=schedule_scheduled_task"
      assert log =~ "status=error"
      assert log =~ "invalid cron expression"
    end
  end

  describe "react events" do
    test "start logs at debug with query_length" do
      log =
        capture_log([level: :debug], fn ->
          :telemetry.execute(
            [:jido, :ai, :react, :start],
            %{},
            %{call_id: "r1", query_length: 42, thread_id: "t1"}
          )
        end)

      assert log =~ "react=start"
      assert log =~ "query_length=42"
    end

    test "iteration logs at debug with iteration number" do
      log =
        capture_log([level: :debug], fn ->
          :telemetry.execute(
            [:jido, :ai, :react, :iteration],
            %{},
            %{iteration: 3, call_id: "r2", thread_id: "t1"}
          )
        end)

      assert log =~ "react=iteration"
      assert log =~ "iteration=3"
    end

    test "complete with :final_answer logs at info with usage and duration" do
      log =
        capture_log([level: :info], fn ->
          :telemetry.execute(
            [:jido, :ai, :react, :complete],
            %{duration: 1500},
            %{
              termination_reason: :final_answer,
              iteration: 4,
              usage: %{input_tokens: 100, output_tokens: 50},
              call_id: "r3",
              thread_id: "t1"
            }
          )
        end)

      assert log =~ "react=complete"
      assert log =~ "termination=final_answer"
      assert log =~ "duration_ms=1500"
      assert log =~ "input_tokens=100"
      assert log =~ "output_tokens=50"
    end

    test "complete with :error logs at error" do
      log =
        capture_log([level: :error], fn ->
          :telemetry.execute(
            [:jido, :ai, :react, :complete],
            %{duration: 200},
            %{
              termination_reason: :error,
              iteration: 1,
              usage: %{},
              call_id: "r4",
              thread_id: "t1"
            }
          )
        end)

      assert log =~ "react=complete"
      assert log =~ "termination=error"
    end

    test "complete with :max_iterations logs at warning" do
      log =
        capture_log([level: :warning], fn ->
          :telemetry.execute(
            [:jido, :ai, :react, :complete],
            %{duration: 5000},
            %{
              termination_reason: :max_iterations,
              iteration: 10,
              usage: %{input_tokens: 500, output_tokens: 200},
              call_id: "r5",
              thread_id: "t1"
            }
          )
        end)

      assert log =~ "react=complete"
      assert log =~ "termination=max_iterations"
    end
  end

  describe "agent command events" do
    test "start logs at debug with agent id and action" do
      log =
        capture_log([level: :debug], fn ->
          :telemetry.execute(
            [:jido, :agent, :cmd, :start],
            %{},
            %{agent_id: "agent-1", action: "run"}
          )
        end)

      assert log =~ "agent_cmd=start"
      assert log =~ "agent_id=agent-1"
      assert log =~ "action=run"
    end

    test "stop logs at debug with directive count and duration" do
      log =
        capture_log([level: :debug], fn ->
          :telemetry.execute(
            [:jido, :agent, :cmd, :stop],
            %{duration: System.convert_time_unit(17, :millisecond, :native)},
            %{agent_id: "agent-2", action: "think", directive_count: 3}
          )
        end)

      assert log =~ "agent_cmd=stop"
      assert log =~ "agent_id=agent-2"
      assert log =~ "action=think"
      assert log =~ "directives=3"
      assert log =~ "duration_ms=17"
    end

    test "exception logs at error with error and duration" do
      log =
        capture_log([level: :error], fn ->
          :telemetry.execute(
            [:jido, :agent, :cmd, :exception],
            %{duration: System.convert_time_unit(9, :millisecond, :native)},
            %{agent_id: "agent-3", action: "run", error: :badarg}
          )
        end)

      assert log =~ "agent_cmd=exception"
      assert log =~ "agent_id=agent-3"
      assert log =~ "action=run"
      assert log =~ "error=:badarg"
      assert log =~ "duration_ms=9"
    end
  end

  describe "attach/detach" do
    test "detach stops logging, re-attach resumes" do
      Telemetry.detach()

      log =
        capture_log([level: :debug], fn ->
          :telemetry.execute(
            [:jido, :ai, :tool, :execute, :start],
            %{},
            %{tool_name: "read_file", call_id: "d1", iteration: 1}
          )
        end)

      assert log == ""

      Telemetry.attach()

      log =
        capture_log([level: :debug], fn ->
          :telemetry.execute(
            [:jido, :ai, :tool, :execute, :start],
            %{},
            %{tool_name: "read_file", call_id: "d2", iteration: 1}
          )
        end)

      assert log =~ "tool=read_file"
    end
  end

  describe "nil metadata handling" do
    test "nil fields are excluded from output" do
      log =
        capture_log([level: :debug], fn ->
          :telemetry.execute(
            [:jido, :ai, :react, :start],
            %{},
            %{call_id: "n1", query_length: nil, thread_id: nil}
          )
        end)

      assert log =~ "react=start"
      assert log =~ "call_id=n1"
      refute log =~ "query_length="
      refute log =~ "thread_id="
    end
  end
end
