defmodule Goodwizard.Actions.Scheduling.CronTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.Cron

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "cron_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    ensure_config_started()
    ensure_cron_registry_started()

    cron_dir = Path.join(@test_workspace, "scheduling/cron")
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(cron_dir)

    original_workspace = Goodwizard.Config.workspace()
    Goodwizard.Config.put(["agent", "workspace"], @test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)

      if Process.whereis(Goodwizard.Config) do
        Goodwizard.Config.put(["agent", "workspace"], original_workspace)
      end
    end)

    :ok
  end

  defp ensure_config_started do
    if Process.whereis(Goodwizard.Config) do
      :ok
    else
      start_supervised!(Goodwizard.Config)
      :ok
    end
  end

  defp ensure_cron_registry_started do
    if Process.whereis(Goodwizard.Scheduling.CronRegistry) do
      :ok
    else
      start_supervised!(Goodwizard.Scheduling.CronRegistry)
      :ok
    end
  end

  describe "run/2" do
    test "valid cron schedule returns success with channel target" do
      params = %{
        schedule: "0 9 * * *",
        task: "check email",
        channel: "telegram",
        external_id: "123"
      }

      assert {:ok, result} = Cron.run(params, %{})
      assert result.scheduled == true
      assert result.schedule == "0 9 * * *"
      assert result.task == "check email"
      assert result.channel == "telegram"
      assert result.external_id == "123"
      assert result.job_id != nil
    end

    test "auto-resolves channel from telegram agent context" do
      params = %{schedule: "0 9 * * *", task: "check email"}
      context = %{agent_id: "telegram:7041440974"}
      assert {:ok, result} = Cron.run(params, context)
      assert result.channel == "telegram"
      assert result.external_id == "7041440974"
    end

    test "auto-resolves channel from cli agent context" do
      params = %{schedule: "0 9 * * *", task: "check email"}
      context = %{agent_id: "cli:direct:main"}
      assert {:ok, result} = Cron.run(params, context)
      assert result.channel == "cli"
      assert result.external_id == "direct"
    end

    test "falls back to scheduling config when agent context unknown" do
      original_channel = Goodwizard.Config.get(["scheduling", "channel"])
      original_chat_id = Goodwizard.Config.get(["scheduling", "chat_id"])
      Goodwizard.Config.put(["scheduling", "channel"], "telegram")
      Goodwizard.Config.put(["scheduling", "chat_id"], "999")

      on_exit(fn ->
        if Process.whereis(Goodwizard.Config) do
          if original_channel,
            do: Goodwizard.Config.put(["scheduling", "channel"], original_channel)

          if original_chat_id,
            do: Goodwizard.Config.put(["scheduling", "chat_id"], original_chat_id)
        end
      end)

      params = %{schedule: "0 9 * * *", task: "check email"}
      context = %{agent_id: "unknown:agent"}
      assert {:ok, result} = Cron.run(params, context)
      assert result.channel == "telegram"
      assert result.external_id == "999"
    end

    test "rejects channel without external_id" do
      params = %{schedule: "0 9 * * *", task: "check email", channel: "cli"}
      assert {:error, msg} = Cron.run(params, %{})
      assert msg =~ "external_id is required"
    end

    test "rejects external_id without channel" do
      params = %{schedule: "0 9 * * *", task: "check email", external_id: "direct"}
      assert {:error, msg} = Cron.run(params, %{})
      assert msg =~ "channel is required"
    end

    test "every-5-minutes cron expression works" do
      params = %{
        schedule: "*/5 * * * *",
        task: "poll status",
        channel: "cli",
        external_id: "direct"
      }

      assert {:ok, result} = Cron.run(params, %{})
      assert result.scheduled == true
    end

    test "cron alias @daily works" do
      params = %{schedule: "@daily", task: "daily report", channel: "cli", external_id: "direct"}
      assert {:ok, _result} = Cron.run(params, %{})
    end

    test "cron alias @hourly works" do
      params = %{
        schedule: "@hourly",
        task: "check metrics",
        channel: "cli",
        external_id: "direct"
      }

      assert {:ok, _result} = Cron.run(params, %{})
    end

    test "invalid cron expression returns error" do
      params = %{schedule: "not-a-cron", task: "test", channel: "cli", external_id: "direct"}
      assert {:error, msg} = Cron.run(params, %{})
      assert msg =~ "Invalid cron expression: not-a-cron"
    end

    test "empty cron expression returns error" do
      params = %{schedule: "", task: "test", channel: "cli", external_id: "direct"}
      assert {:error, msg} = Cron.run(params, %{})
      assert msg =~ "Invalid cron expression"
    end

    test "same params produce same job_id" do
      params = %{schedule: "0 9 * * *", task: "check", channel: "cli", external_id: "direct"}
      assert {:ok, r1} = Cron.run(params, %{})
      assert {:ok, r2} = Cron.run(params, %{})
      assert r1.job_id == r2.job_id
    end

    test "different params produce different job_ids" do
      params1 = %{schedule: "0 9 * * *", task: "check", channel: "cli", external_id: "direct"}
      params2 = %{schedule: "0 10 * * *", task: "check", channel: "cli", external_id: "direct"}
      assert {:ok, r1} = Cron.run(params1, %{})
      assert {:ok, r2} = Cron.run(params2, %{})
      assert r1.job_id != r2.job_id
    end
  end

  describe "mode parameter" do
    test "mode:main produces correct result" do
      params = %{
        schedule: "0 9 * * *",
        task: "check",
        channel: "cli",
        external_id: "direct",
        mode: "main"
      }

      assert {:ok, result} = Cron.run(params, %{})
      assert result.mode == "main"
    end

    test "mode:isolated includes mode in result" do
      params = %{
        schedule: "0 9 * * *",
        task: "check",
        channel: "cli",
        external_id: "direct",
        mode: "isolated"
      }

      assert {:ok, result} = Cron.run(params, %{})
      assert result.mode == "isolated"
    end

    test "rejects invalid mode value" do
      params = %{
        schedule: "0 9 * * *",
        task: "check",
        channel: "cli",
        external_id: "direct",
        mode: "turbo"
      }

      assert {:error, msg} = Cron.run(params, %{})
      assert msg =~ "Invalid mode"
      assert msg =~ "turbo"
    end

    test "without mode defaults to isolated" do
      params = %{schedule: "0 9 * * *", task: "check", channel: "cli", external_id: "direct"}
      assert {:ok, result} = Cron.run(params, %{})
      assert result.mode == "isolated"
    end
  end

  describe "mode affects job_id" do
    test "same task in different modes gets distinct job IDs" do
      base = %{schedule: "0 9 * * *", task: "check", channel: "cli", external_id: "direct"}
      assert {:ok, r_main} = Cron.run(Map.put(base, :mode, "main"), %{})
      assert {:ok, r_isolated} = Cron.run(Map.put(base, :mode, "isolated"), %{})
      assert r_main.job_id != r_isolated.job_id
    end
  end

  describe "model validation" do
    test "accepts valid anthropic model" do
      params = %{
        schedule: "0 9 * * *",
        task: "check",
        channel: "cli",
        external_id: "direct",
        mode: "isolated",
        model: "anthropic:claude-haiku-4-5"
      }

      assert {:ok, _result} = Cron.run(params, %{})
    end

    test "rejects model with unknown provider prefix" do
      params = %{
        schedule: "0 9 * * *",
        task: "check",
        channel: "cli",
        external_id: "direct",
        mode: "isolated",
        model: "unknown-provider:some-model"
      }

      assert {:error, msg} = Cron.run(params, %{})
      assert msg =~ "Invalid model"
      assert msg =~ "unknown-provider"
    end

    test "accepts nil model (no model override)" do
      params = %{
        schedule: "0 9 * * *",
        task: "check",
        channel: "cli",
        external_id: "direct",
        mode: "isolated"
      }

      assert {:ok, _result} = Cron.run(params, %{})
    end
  end
end
