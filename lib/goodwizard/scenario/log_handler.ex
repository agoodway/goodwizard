defmodule Goodwizard.Scenario.LogHandler do
  @moduledoc """
  Lightweight Erlang `:logger` handler used by the scenario runner.

  Captures log events into an Agent-backed buffer scoped to one scenario run.
  """

  @doc false
  def adding_handler(config), do: {:ok, config}

  @doc false
  def removing_handler(_config), do: :ok

  @doc false
  def changing_config(_set_or_update, config), do: {:ok, config}

  @doc false
  def log(event, config) when is_map(event) and is_map(config) do
    with collector when is_pid(collector) <- get_in(config, [:config, :collector]),
         true <- Process.alive?(collector),
         entry when is_map(entry) <- normalize_event(event) do
      Agent.update(collector, fn entries -> [entry | entries] end)
    else
      _ -> :ok
    end

    :ok
  end

  def log(_event, _config), do: :ok

  defp normalize_event(event) do
    meta = Map.get(event, :meta, %{})
    mfa = Map.get(meta, :mfa)

    %{
      level: Map.get(event, :level, :info),
      message: format_message(Map.get(event, :msg)),
      timestamp: format_timestamp(Map.get(meta, :time)),
      module: format_module(mfa)
    }
  end

  defp format_message({:string, message}), do: to_binary(message)

  defp format_message({:report, report}) when is_map(report) do
    report
    |> Enum.map_join(" ", fn {key, value} -> "#{key}=#{inspect(value)}" end)
    |> String.trim()
  end

  defp format_message({:report, report}), do: inspect(report)
  defp format_message(message), do: to_binary(message)

  defp to_binary(value) when is_binary(value), do: value

  defp to_binary(value) when is_list(value), do: IO.iodata_to_binary(value)

  defp to_binary(value), do: inspect(value)

  defp format_module({module, _function, _arity}) when is_atom(module), do: inspect(module)
  defp format_module(_), do: nil

  defp format_timestamp({date, time}) when is_tuple(date) and is_tuple(time) do
    with {:ok, date_struct} <- Date.new(elem(date, 0), elem(date, 1), elem(date, 2)),
         {:ok, time_struct} <- Time.new(elem(time, 0), elem(time, 1), elem(time, 2)),
         {:ok, naive} <- NaiveDateTime.new(date_struct, time_struct) do
      DateTime.from_naive!(naive, "Etc/UTC") |> DateTime.to_iso8601()
    else
      _ -> DateTime.utc_now() |> DateTime.to_iso8601()
    end
  end

  defp format_timestamp(timestamp) when is_integer(timestamp) do
    timestamp
    |> DateTime.from_unix!(:microsecond)
    |> DateTime.to_iso8601()
  rescue
    _ -> DateTime.utc_now() |> DateTime.to_iso8601()
  end

  defp format_timestamp(_), do: DateTime.utc_now() |> DateTime.to_iso8601()
end
