defmodule Goodwizard.Scenario.LogHandlerTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Scenario.LogHandler

  test "buffers :string, :report, and binary messages with levels" do
    {:ok, collector} = Agent.start_link(fn -> [] end)

    on_exit(fn ->
      _ = catch_exit(Agent.stop(collector, :normal))
      :ok
    end)

    :ok =
      LogHandler.log(
        %{
          level: :info,
          msg: {:string, "hello"},
          meta: %{time: {{2026, 1, 1}, {12, 0, 0}}, mfa: {__MODULE__, :test, 0}}
        },
        %{collector: collector}
      )

    :ok =
      LogHandler.log(
        %{
          level: :warning,
          msg: {:report, %{event: "warn", value: 2}},
          meta: %{time: {{2026, 1, 1}, {12, 0, 1}}, mfa: {__MODULE__, :test, 0}}
        },
        %{collector: collector}
      )

    :ok =
      LogHandler.log(
        %{
          level: :error,
          msg: "boom",
          meta: %{time: {{2026, 1, 1}, {12, 0, 2}}, mfa: {__MODULE__, :test, 0}}
        },
        %{collector: collector}
      )

    entries =
      collector
      |> Agent.get(& &1)
      |> Enum.reverse()

    assert length(entries) == 3
    assert Enum.at(entries, 0).level == :info
    assert Enum.at(entries, 0).message == "hello"
    assert Enum.at(entries, 1).level == :warning
    assert Enum.at(entries, 1).message =~ "event"
    assert Enum.at(entries, 2).level == :error
    assert Enum.at(entries, 2).message == "boom"
    assert Enum.at(entries, 2).module == inspect(__MODULE__)
  end
end
