defmodule Goodwizard.Plugins.ScheduledTaskSchedulerTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Plugins.ScheduledTaskScheduler

  setup do
    ensure_config_started()
    ensure_messaging_started()
    ensure_jido_registry_started()
    ensure_jido_task_supervisor_started()
    :ok
  end

  defp make_signal(message) do
    Jido.Signal.new!("jido.scheduled_task_tick", %{message: message}, source: "/test")
  end

  defp ensure_config_started do
    if Process.whereis(Goodwizard.Config) do
      :ok
    else
      start_supervised!(Goodwizard.Config)
      :ok
    end
  end

  defp ensure_messaging_started do
    if Process.whereis(Goodwizard.Messaging.Runtime) do
      :ok
    else
      start_supervised!(Goodwizard.Messaging)
      :ok
    end
  end

  defp ensure_jido_registry_started do
    if Process.whereis(Goodwizard.Jido.Registry) do
      :ok
    else
      start_supervised!({Registry, keys: :unique, name: Goodwizard.Jido.Registry})
      :ok
    end
  end

  defp ensure_jido_task_supervisor_started do
    name = Goodwizard.Jido.task_supervisor_name()

    if Process.whereis(name) do
      :ok
    else
      start_supervised!({Task.Supervisor, name: name})
      :ok
    end
  end

  describe "handle_signal/2 with main mode" do
    test "routes to react.input signal override" do
      signal =
        make_signal(%{task: "check email", channel: "cli", external_id: "direct", mode: "main"})

      assert {:ok, {:override, {:strategy_cmd, :react_start}, new_signal}} =
               ScheduledTaskScheduler.handle_signal(signal, %{})

      assert new_signal.type == "react.input"
      assert new_signal.data.query == "[Scheduled Task] check email"
    end
  end

  describe "handle_signal/2 with isolated mode" do
    test "returns Noop override for isolated mode" do
      signal =
        make_signal(%{
          task: "run report",
          channel: "cli",
          external_id: "direct",
          mode: "isolated"
        })

      assert {:ok, {:override, Jido.Actions.Control.Noop}} =
               ScheduledTaskScheduler.handle_signal(signal, %{})
    end

    test "defaults to isolated when mode is missing" do
      signal = make_signal(%{task: "run report", channel: "cli", external_id: "direct"})

      assert {:ok, {:override, Jido.Actions.Control.Noop}} =
               ScheduledTaskScheduler.handle_signal(signal, %{})
    end
  end

  describe "handle_signal/2 with string keys" do
    test "reads fields from string keys" do
      signal =
        make_signal(%{
          "task" => "check email",
          "channel" => "cli",
          "external_id" => "direct",
          "mode" => "main"
        })

      assert {:ok, {:override, {:strategy_cmd, :react_start}, new_signal}} =
               ScheduledTaskScheduler.handle_signal(signal, %{})

      assert new_signal.data.query == "[Scheduled Task] check email"
    end
  end

  describe "handle_signal/2 with missing channel" do
    test "returns Noop when channel/external_id are missing" do
      signal = make_signal(%{task: "orphan task", mode: "main"})

      assert {:ok, {:override, Jido.Actions.Control.Noop}} =
               ScheduledTaskScheduler.handle_signal(signal, %{})
    end

    test "returns Noop when channel is unsupported" do
      signal =
        make_signal(%{task: "orphan task", channel: "email", external_id: "x", mode: "main"})

      assert {:ok, {:override, Jido.Actions.Control.Noop}} =
               ScheduledTaskScheduler.handle_signal(signal, %{})
    end
  end

  describe "handle_signal/2 ignores non-cron signals" do
    test "returns :continue for unrecognized signal types" do
      {:ok, signal} = Jido.Signal.new("some.other.event", %{}, source: "/test")
      assert {:ok, :continue} = ScheduledTaskScheduler.handle_signal(signal, %{})
    end
  end
end
