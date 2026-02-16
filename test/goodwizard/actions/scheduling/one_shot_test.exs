defmodule Goodwizard.Actions.Scheduling.OneShotTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Scheduling.OneShot

  describe "delay mode" do
    test "schedules with correct delay" do
      params = %{delay_minutes: 20, task: "Send daily report", room_id: "cli:heartbeat"}
      assert {:ok, result} = OneShot.run(params, %{})

      assert result.scheduled == true
      assert result.task == "Send daily report"
      assert result.room_id == "cli:heartbeat"
      assert result.mode == "delay"
      assert result.job_id != nil
    end

    test "zero delay_minutes returns error" do
      params = %{delay_minutes: 0, task: "test", room_id: "room_1"}
      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "positive integer"
    end

    test "negative delay_minutes returns error" do
      params = %{delay_minutes: -5, task: "test", room_id: "room_1"}
      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "positive integer"
    end

    test "delay_minutes exceeding max returns error" do
      params = %{delay_minutes: 525_601, task: "test", room_id: "room_1"}
      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "exceeds maximum"
    end

    test "delay_minutes at max boundary succeeds" do
      params = %{delay_minutes: 525_600, task: "test", room_id: "room_1"}
      assert {:ok, _result} = OneShot.run(params, %{})
    end

    test "fires_at is approximately correct" do
      params = %{delay_minutes: 10, task: "test", room_id: "room_1"}
      assert {:ok, result} = OneShot.run(params, %{})
      expected = DateTime.add(DateTime.utc_now(), 10, :minute)
      assert_in_delta DateTime.to_unix(result.fires_at), DateTime.to_unix(expected), 5
    end
  end

  describe "at mode" do
    test "schedules with approximately correct timing" do
      future = DateTime.utc_now() |> DateTime.add(30, :minute)
      at_string = DateTime.to_iso8601(future)
      params = %{at: at_string, task: "Send weekly summary", room_id: "telegram:main"}

      assert {:ok, result} = OneShot.run(params, %{})

      assert result.scheduled == true
      assert result.task == "Send weekly summary"
      assert result.room_id == "telegram:main"
      assert result.mode == "at"
    end

    test "past datetime returns error" do
      past = DateTime.utc_now() |> DateTime.add(-60, :second)
      at_string = DateTime.to_iso8601(past)
      params = %{at: at_string, task: "test", room_id: "room_1"}

      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "in the past"
    end

    test "invalid ISO 8601 string returns error" do
      params = %{at: "not-a-date", task: "test", room_id: "room_1"}
      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "Invalid ISO 8601"
    end

    test "fires_at matches input datetime exactly" do
      future = DateTime.utc_now() |> DateTime.add(60, :minute)
      at_string = DateTime.to_iso8601(future)
      params = %{at: at_string, task: "test", room_id: "room_1"}

      assert {:ok, result} = OneShot.run(params, %{})
      assert DateTime.to_unix(result.fires_at) == DateTime.to_unix(future)
    end

    test "non-UTC timezone offset returns error" do
      params = %{at: "2026-06-15T15:00:00+05:30", task: "test", room_id: "room_1"}
      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "Only UTC"
    end
  end

  describe "mutual exclusivity" do
    test "both delay_minutes and at returns error" do
      future = DateTime.utc_now() |> DateTime.add(30, :minute) |> DateTime.to_iso8601()
      params = %{delay_minutes: 10, at: future, task: "test", room_id: "room_1"}

      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "got both"
    end

    test "neither delay_minutes nor at returns error" do
      params = %{task: "test", room_id: "room_1"}
      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "Exactly one"
    end
  end

  describe "job ID" do
    test "same params produce same job_id" do
      params = %{delay_minutes: 10, task: "check", room_id: "room_1"}
      assert {:ok, r1} = OneShot.run(params, %{})
      assert {:ok, r2} = OneShot.run(params, %{})
      assert r1.job_id == r2.job_id
    end

    test "different params produce different job_ids" do
      params1 = %{delay_minutes: 10, task: "check", room_id: "room_1"}
      params2 = %{delay_minutes: 10, task: "other", room_id: "room_1"}
      assert {:ok, r1} = OneShot.run(params1, %{})
      assert {:ok, r2} = OneShot.run(params2, %{})
      assert r1.job_id != r2.job_id
    end

    test "job_id uses oneshot_ prefix" do
      params = %{delay_minutes: 5, task: "test", room_id: "room_1"}
      assert {:ok, result} = OneShot.run(params, %{})
      assert to_string(result.job_id) =~ ~r/^oneshot_\d+$/
    end
  end
end
