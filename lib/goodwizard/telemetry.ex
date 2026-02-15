defmodule Goodwizard.Telemetry do
  @moduledoc """
  Attaches handlers to Jido's built-in telemetry events for centralized logging.

  Jido's executor and ReAct machine emit `:telemetry` events for every tool call
  and lifecycle transition. This module converts those events into structured log lines.
  """

  require Logger

  @tool_events [
    [:jido, :ai, :tool, :execute, :start],
    [:jido, :ai, :tool, :execute, :stop],
    [:jido, :ai, :tool, :execute, :exception]
  ]

  @react_events [
    [:jido, :ai, :react, :start],
    [:jido, :ai, :react, :iteration],
    [:jido, :ai, :react, :complete]
  ]

  @tool_handler_id "goodwizard-tool-handler"
  @react_handler_id "goodwizard-react-handler"

  @doc "Attach telemetry handlers for Jido tool and ReAct events."
  @spec attach() :: :ok
  def attach do
    :telemetry.attach_many(
      @tool_handler_id,
      @tool_events,
      &__MODULE__.handle_tool_event/4,
      %{}
    )

    :telemetry.attach_many(
      @react_handler_id,
      @react_events,
      &__MODULE__.handle_react_event/4,
      %{}
    )

    :ok
  end

  @doc "Detach all Goodwizard telemetry handlers."
  @spec detach() :: :ok
  def detach do
    :telemetry.detach(@tool_handler_id)
    :telemetry.detach(@react_handler_id)
    :ok
  end

  @doc false
  def handle_tool_event([:jido, :ai, :tool, :execute, :start], _measurements, metadata, _config) do
    Logger.debug(fn ->
      kv(
        tool: metadata[:tool_name],
        event: :start,
        call_id: metadata[:call_id],
        iteration: metadata[:iteration]
      )
    end)
  end

  def handle_tool_event([:jido, :ai, :tool, :execute, :stop], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements[:duration] || 0, :native, :millisecond)
    status = if match?({:ok, _}, metadata[:result]), do: :ok, else: :error

    log_fn = fn ->
      kv(
        tool: metadata[:tool_name],
        event: :stop,
        status: status,
        duration_ms: duration_ms,
        call_id: metadata[:call_id]
      )
    end

    if status == :ok, do: Logger.info(log_fn), else: Logger.error(log_fn)
  end

  def handle_tool_event(
        [:jido, :ai, :tool, :execute, :exception],
        measurements,
        metadata,
        _config
      ) do
    duration_ms = System.convert_time_unit(measurements[:duration] || 0, :native, :millisecond)

    Logger.error(fn ->
      kv(
        tool: metadata[:tool_name],
        event: :exception,
        reason: inspect(metadata[:reason]),
        duration_ms: duration_ms,
        call_id: metadata[:call_id]
      )
    end)
  end

  @doc false
  def handle_react_event([:jido, :ai, :react, :start], _measurements, metadata, _config) do
    Logger.debug(fn ->
      kv(
        react: :start,
        query_length: metadata[:query_length],
        call_id: metadata[:call_id],
        thread_id: metadata[:thread_id]
      )
    end)
  end

  def handle_react_event([:jido, :ai, :react, :iteration], _measurements, metadata, _config) do
    Logger.debug(fn ->
      kv(
        react: :iteration,
        iteration: metadata[:iteration],
        call_id: metadata[:call_id],
        thread_id: metadata[:thread_id]
      )
    end)
  end

  def handle_react_event([:jido, :ai, :react, :complete], measurements, metadata, _config) do
    duration_ms = measurements[:duration]
    usage = metadata[:usage] || %{}

    log_fn = fn ->
      kv(
        react: :complete,
        termination: metadata[:termination_reason],
        duration_ms: duration_ms,
        iterations: metadata[:iteration],
        input_tokens: usage[:input_tokens],
        output_tokens: usage[:output_tokens],
        call_id: metadata[:call_id],
        thread_id: metadata[:thread_id]
      )
    end

    case metadata[:termination_reason] do
      :final_answer -> Logger.info(log_fn)
      :max_iterations -> Logger.warning(log_fn)
      :error -> Logger.error(log_fn)
      _ -> Logger.info(log_fn)
    end
  end

  defp kv(pairs) do
    pairs
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.map_join(" ", fn {k, v} -> "#{k}=#{v}" end)
  end
end
