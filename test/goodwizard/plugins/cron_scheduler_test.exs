defmodule Goodwizard.Plugins.CronSchedulerTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Plugins.CronScheduler

  defp make_signal(message) do
    Jido.Signal.new!("jido.cron_tick", %{message: message}, source: "/test")
  end

  describe "handle_signal/2 with main mode" do
    test "routes to react.input signal override" do
      signal = make_signal(%{task: "check email", room_id: "room_1", mode: "main"})
      assert {:ok, {:override, {:strategy_cmd, :react_start}, new_signal}} =
               CronScheduler.handle_signal(signal, %{})

      assert new_signal.type == "react.input"
      assert new_signal.data.query == "[Cron Task] check email"
    end
  end

  describe "handle_signal/2 with isolated mode" do
    test "returns :continue for isolated mode" do
      signal = make_signal(%{task: "run report", room_id: "room_2", mode: "isolated"})
      assert {:ok, :continue} = CronScheduler.handle_signal(signal, %{})
    end

    test "defaults to isolated when mode is missing" do
      signal = make_signal(%{task: "run report", room_id: "room_2"})
      assert {:ok, :continue} = CronScheduler.handle_signal(signal, %{})
    end
  end

  describe "handle_signal/2 with string keys" do
    test "reads fields from string keys" do
      signal = make_signal(%{"task" => "check email", "room_id" => "room_1", "mode" => "main"})
      assert {:ok, {:override, {:strategy_cmd, :react_start}, new_signal}} =
               CronScheduler.handle_signal(signal, %{})

      assert new_signal.data.query == "[Cron Task] check email"
    end
  end

  describe "handle_signal/2 with nil fields" do
    test "handles nil task gracefully" do
      signal = make_signal(%{room_id: "room_1", mode: "main"})
      assert {:ok, {:override, {:strategy_cmd, :react_start}, new_signal}} =
               CronScheduler.handle_signal(signal, %{})

      assert new_signal.data.query == "[Cron Task] "
    end
  end

  describe "handle_signal/2 ignores non-cron signals" do
    test "returns :continue for unrecognized signal types" do
      {:ok, signal} = Jido.Signal.new("some.other.event", %{}, source: "/test")
      assert {:ok, :continue} = CronScheduler.handle_signal(signal, %{})
    end
  end
end
