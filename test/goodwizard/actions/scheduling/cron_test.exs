defmodule Goodwizard.Actions.Scheduling.CronTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Scheduling.Cron

  describe "run/2" do
    test "valid cron schedule returns directive" do
      params = %{schedule: "0 9 * * *", task: "check email", room_id: "room_abc123"}
      assert {:ok, result, [directive]} = Cron.run(params, %{})
      assert result.scheduled == true
      assert result.schedule == "0 9 * * *"
      assert result.task == "check email"
      assert result.room_id == "room_abc123"
      assert result.job_id != nil
      assert %Jido.Agent.Directive.Cron{} = directive
      assert directive.cron == "0 9 * * *"
    end

    test "every-5-minutes cron expression works" do
      params = %{schedule: "*/5 * * * *", task: "poll status", room_id: "room_1"}
      assert {:ok, result, [directive]} = Cron.run(params, %{})
      assert result.scheduled == true
      assert directive.cron == "*/5 * * * *"
    end

    test "cron alias @daily works" do
      params = %{schedule: "@daily", task: "daily report", room_id: "room_1"}
      assert {:ok, _result, [directive]} = Cron.run(params, %{})
      assert directive.cron == "@daily"
    end

    test "cron alias @hourly works" do
      params = %{schedule: "@hourly", task: "check metrics", room_id: "room_1"}
      assert {:ok, _result, [_directive]} = Cron.run(params, %{})
    end

    test "invalid cron expression returns error" do
      params = %{schedule: "not-a-cron", task: "test", room_id: "room_1"}
      assert {:error, msg} = Cron.run(params, %{})
      assert msg =~ "Invalid cron expression: not-a-cron"
    end

    test "empty cron expression returns error" do
      params = %{schedule: "", task: "test", room_id: "room_1"}
      assert {:error, msg} = Cron.run(params, %{})
      assert msg =~ "Invalid cron expression"
    end

    test "directive message contains task and room_id" do
      params = %{schedule: "0 0 * * *", task: "midnight cleanup", room_id: "room_xyz"}
      assert {:ok, _result, [directive]} = Cron.run(params, %{})
      assert directive.message.task == "midnight cleanup"
      assert directive.message.room_id == "room_xyz"
      assert directive.message.type == "cron.task"
    end

    test "same params produce same job_id" do
      params = %{schedule: "0 9 * * *", task: "check", room_id: "room_1"}
      assert {:ok, r1, _} = Cron.run(params, %{})
      assert {:ok, r2, _} = Cron.run(params, %{})
      assert r1.job_id == r2.job_id
    end

    test "different params produce different job_ids" do
      params1 = %{schedule: "0 9 * * *", task: "check", room_id: "room_1"}
      params2 = %{schedule: "0 10 * * *", task: "check", room_id: "room_1"}
      assert {:ok, r1, _} = Cron.run(params1, %{})
      assert {:ok, r2, _} = Cron.run(params2, %{})
      assert r1.job_id != r2.job_id
    end
  end

  describe "mode parameter" do
    test "mode:main produces correct payload" do
      params = %{schedule: "0 9 * * *", task: "check", room_id: "room_1", mode: "main"}
      assert {:ok, result, [directive]} = Cron.run(params, %{})
      assert result.mode == "main"
      assert directive.message.mode == "main"
      refute Map.has_key?(directive.message, :model)
    end

    test "mode:isolated includes mode in payload" do
      params = %{schedule: "0 9 * * *", task: "check", room_id: "room_1", mode: "isolated"}
      assert {:ok, result, [directive]} = Cron.run(params, %{})
      assert result.mode == "isolated"
      assert directive.message.mode == "isolated"
    end

    test "isolated+model includes model in payload" do
      params = %{
        schedule: "0 9 * * *",
        task: "check",
        room_id: "room_1",
        mode: "isolated",
        model: "anthropic:claude-haiku-4-5"
      }

      assert {:ok, _result, [directive]} = Cron.run(params, %{})
      assert directive.message.model == "anthropic:claude-haiku-4-5"
      assert directive.message.mode == "isolated"
    end

    test "main+model excludes model from payload" do
      params = %{
        schedule: "0 9 * * *",
        task: "check",
        room_id: "room_1",
        mode: "main",
        model: "anthropic:claude-haiku-4-5"
      }

      assert {:ok, _result, [directive]} = Cron.run(params, %{})
      assert directive.message.mode == "main"
      refute Map.has_key?(directive.message, :model)
    end

    test "rejects invalid mode value" do
      params = %{schedule: "0 9 * * *", task: "check", room_id: "room_1", mode: "turbo"}
      assert {:error, msg} = Cron.run(params, %{})
      assert msg =~ "Invalid mode"
      assert msg =~ "turbo"
    end

    test "without mode defaults to isolated" do
      params = %{schedule: "0 9 * * *", task: "check", room_id: "room_1"}
      assert {:ok, result, [directive]} = Cron.run(params, %{})
      assert result.mode == "isolated"
      assert directive.message.mode == "isolated"
    end
  end

  describe "mode affects job_id" do
    test "same task in different modes gets distinct job IDs" do
      base = %{schedule: "0 9 * * *", task: "check", room_id: "room_1"}
      assert {:ok, r_main, _} = Cron.run(Map.put(base, :mode, "main"), %{})
      assert {:ok, r_isolated, _} = Cron.run(Map.put(base, :mode, "isolated"), %{})
      assert r_main.job_id != r_isolated.job_id
    end
  end

  describe "model validation" do
    test "accepts valid anthropic model" do
      params = %{
        schedule: "0 9 * * *",
        task: "check",
        room_id: "room_1",
        mode: "isolated",
        model: "anthropic:claude-haiku-4-5"
      }

      assert {:ok, _result, _directives} = Cron.run(params, %{})
    end

    test "rejects model with unknown provider prefix" do
      params = %{
        schedule: "0 9 * * *",
        task: "check",
        room_id: "room_1",
        mode: "isolated",
        model: "unknown-provider:some-model"
      }

      assert {:error, msg} = Cron.run(params, %{})
      assert msg =~ "Invalid model"
      assert msg =~ "unknown-provider"
    end

    test "accepts nil model (no model override)" do
      params = %{schedule: "0 9 * * *", task: "check", room_id: "room_1", mode: "isolated"}
      assert {:ok, _result, _directives} = Cron.run(params, %{})
    end
  end
end
