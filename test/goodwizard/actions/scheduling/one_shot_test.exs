defmodule Goodwizard.Actions.Scheduling.OneShotTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.OneShot
  alias Goodwizard.Scheduling.OneShotRegistry

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "oneshot_action_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    ensure_config_started()

    oneshot_dir = Path.join(@test_workspace, "scheduling/oneshot")
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(oneshot_dir)

    original_workspace = Goodwizard.Config.workspace()
    Goodwizard.Config.put(["agent", "workspace"], @test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)

      if Process.whereis(Goodwizard.Config) do
        Goodwizard.Config.put(["agent", "workspace"], original_workspace)
      end
    end)

    %{oneshot_dir: oneshot_dir}
  end

  defp ensure_config_started do
    if Process.whereis(Goodwizard.Config) do
      :ok
    else
      start_supervised!(Goodwizard.Config)
      :ok
    end
  end

  describe "delay mode" do
    test "schedules with correct delay" do
      params = %{
        delay_minutes: 20,
        task: "Send daily report",
        channel: "cli",
        external_id: "direct"
      }

      assert {:ok, result} = OneShot.run(params, %{})

      assert result.scheduled == true
      assert result.task == "Send daily report"
      assert result.channel == "cli"
      assert result.external_id == "direct"
      assert result.mode == "delay"
      assert result.job_id != nil
    end

    test "zero delay_minutes returns error" do
      params = %{delay_minutes: 0, task: "test", channel: "cli", external_id: "direct"}
      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "positive integer"
    end

    test "negative delay_minutes returns error" do
      params = %{delay_minutes: -5, task: "test", channel: "cli", external_id: "direct"}
      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "positive integer"
    end

    test "delay_minutes exceeding max returns error" do
      params = %{delay_minutes: 525_601, task: "test", channel: "cli", external_id: "direct"}
      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "exceeds maximum"
    end

    test "delay_minutes at max boundary succeeds" do
      params = %{delay_minutes: 525_600, task: "test", channel: "cli", external_id: "direct"}
      assert {:ok, _result} = OneShot.run(params, %{})
    end

    test "fires_at is approximately correct" do
      params = %{delay_minutes: 10, task: "test", channel: "cli", external_id: "direct"}
      assert {:ok, result} = OneShot.run(params, %{})
      expected = DateTime.add(DateTime.utc_now(), 10, :minute)
      assert_in_delta DateTime.to_unix(result.fires_at), DateTime.to_unix(expected), 5
    end
  end

  describe "at mode" do
    test "schedules with approximately correct timing" do
      future = DateTime.utc_now() |> DateTime.add(30, :minute)
      at_string = DateTime.to_iso8601(future)

      params = %{
        at: at_string,
        task: "Send weekly summary",
        channel: "telegram",
        external_id: "123"
      }

      assert {:ok, result} = OneShot.run(params, %{})

      assert result.scheduled == true
      assert result.task == "Send weekly summary"
      assert result.channel == "telegram"
      assert result.external_id == "123"
      assert result.mode == "at"
    end

    test "past datetime returns error" do
      past = DateTime.utc_now() |> DateTime.add(-60, :second)
      at_string = DateTime.to_iso8601(past)
      params = %{at: at_string, task: "test", channel: "cli", external_id: "direct"}

      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "in the past"
    end

    test "invalid ISO 8601 string returns error" do
      params = %{at: "not-a-date", task: "test", channel: "cli", external_id: "direct"}
      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "Invalid ISO 8601"
    end

    test "fires_at matches input datetime exactly" do
      future = DateTime.utc_now() |> DateTime.add(60, :minute)
      at_string = DateTime.to_iso8601(future)
      params = %{at: at_string, task: "test", channel: "cli", external_id: "direct"}

      assert {:ok, result} = OneShot.run(params, %{})
      assert DateTime.to_unix(result.fires_at) == DateTime.to_unix(future)
    end

    test "non-UTC timezone offset returns error" do
      params = %{
        at: "2026-06-15T15:00:00+05:30",
        task: "test",
        channel: "cli",
        external_id: "direct"
      }

      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "Only UTC"
    end
  end

  describe "mutual exclusivity" do
    test "both delay_minutes and at returns error" do
      future = DateTime.utc_now() |> DateTime.add(30, :minute) |> DateTime.to_iso8601()

      params = %{
        delay_minutes: 10,
        at: future,
        task: "test",
        channel: "cli",
        external_id: "direct"
      }

      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "got both"
    end

    test "neither delay_minutes nor at returns error" do
      params = %{task: "test", channel: "cli", external_id: "direct"}
      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "Exactly one"
    end

    test "rejects channel without external_id" do
      params = %{delay_minutes: 10, task: "test", channel: "cli"}
      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "external_id is required"
    end

    test "rejects external_id without channel" do
      params = %{delay_minutes: 10, task: "test", external_id: "direct"}
      assert {:error, msg} = OneShot.run(params, %{})
      assert msg =~ "channel is required"
    end
  end

  describe "job ID" do
    test "uses oneshot_ prefix with 16 hex chars" do
      params = %{delay_minutes: 5, task: "test", channel: "cli", external_id: "direct"}
      assert {:ok, result} = OneShot.run(params, %{})
      assert to_string(result.job_id) =~ ~r/^oneshot_[0-9a-f]{16}$/
    end

    test "same fires_at/task/channel/external_id produce same job_id" do
      fires_at = ~U[2026-06-15 09:00:00Z]
      id1 = OneShot.generate_job_id(fires_at, "check", "cli", "direct")
      id2 = OneShot.generate_job_id(fires_at, "check", "cli", "direct")
      assert id1 == id2
    end

    test "different inputs produce different job_ids" do
      fires_at = ~U[2026-06-15 09:00:00Z]
      id1 = OneShot.generate_job_id(fires_at, "check", "cli", "direct")
      id2 = OneShot.generate_job_id(fires_at, "other", "cli", "direct")
      assert id1 != id2
    end
  end

  describe "persistence" do
    test "saves job to OneShotStore after scheduling", %{oneshot_dir: oneshot_dir} do
      params = %{delay_minutes: 30, task: "persist test", channel: "cli", external_id: "direct"}
      assert {:ok, result} = OneShot.run(params, %{})

      path = Path.join(oneshot_dir, "#{result.job_id}.json")
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      {:ok, data} = Jason.decode(content)
      assert data["task"] == "persist test"
      assert data["channel"] == "cli"
      assert data["external_id"] == "direct"
      assert data["fires_at"] != nil
    end

    test "registers timer in OneShotRegistry after scheduling" do
      params = %{delay_minutes: 30, task: "registry test", channel: "cli", external_id: "direct"}
      assert {:ok, result} = OneShot.run(params, %{})

      assert {:ok, _tref} = OneShotRegistry.lookup(result.job_id)

      # Cleanup
      OneShotRegistry.cancel(result.job_id)
    end

    test "deliver/3 cleans up persisted file and registry entry", %{oneshot_dir: oneshot_dir} do
      params = %{delay_minutes: 30, task: "cleanup test", channel: "cli", external_id: "direct"}
      assert {:ok, result} = OneShot.run(params, %{})

      job_id = result.job_id
      path = Path.join(oneshot_dir, "#{job_id}.json")
      assert File.exists?(path)
      assert {:ok, _} = OneShotRegistry.lookup(job_id)

      # Simulate delivery (agent won't be found but cleanup should still happen)
      signal = %{type: "test"}
      OneShot.deliver("nonexistent_agent", signal, job_id)

      refute File.exists?(path)
      assert :error = OneShotRegistry.lookup(job_id)
    end
  end
end
