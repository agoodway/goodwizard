defmodule Goodwizard.Scenario.Runner do
  @moduledoc """
  Executes scenario definitions against a live Goodwizard agent.
  """

  alias Goodwizard.Agent, as: GoodwizardAgent
  alias Goodwizard.Scenario.LogHandler

  @default_timeout 120_000
  @react_events [
    [:jido, :ai, :strategy, :react, :start],
    [:jido, :ai, :strategy, :react, :complete],
    [:jido, :ai, :strategy, :react, :failed],
    [:jido, :ai, :request, :start],
    [:jido, :ai, :request, :complete],
    [:jido, :ai, :request, :failed],
    [:jido, :ai, :tool, :execute, :start],
    [:jido, :ai, :tool, :execute, :stop],
    [:jido, :ai, :tool, :execute, :exception]
  ]

  defmodule ToolCall do
    @moduledoc false
    @enforce_keys [:tool_name, :status, :duration_ms]
    defstruct [:tool_name, :status, :duration_ms, :timestamp, :metadata]

    @type t :: %__MODULE__{
            tool_name: String.t(),
            status: :ok | :error,
            duration_ms: non_neg_integer(),
            timestamp: String.t() | nil,
            metadata: map() | nil
          }
  end

  defmodule QueryResult do
    @moduledoc false
    @enforce_keys [:index, :type, :duration_ms, :status]
    defstruct [
      :index,
      :type,
      :query,
      :response,
      :duration_ms,
      :status,
      :error,
      :tool_calls,
      :log_entries
    ]

    @type t :: %__MODULE__{
            index: non_neg_integer(),
            type: :query | :setup,
            query: String.t() | nil,
            response: String.t() | nil,
            duration_ms: non_neg_integer(),
            status: :ok | :error,
            error: String.t() | nil,
            tool_calls: [ToolCall.t()] | nil,
            log_entries: [map()] | nil
          }
  end

  defmodule AssertionResult do
    @moduledoc false
    @enforce_keys [:type, :passed, :message]
    defstruct [:type, :passed, :message]

    @type t :: %__MODULE__{
            type: atom() | String.t(),
            passed: boolean(),
            message: String.t()
          }
  end

  defmodule Result do
    @moduledoc false
    @enforce_keys [:name, :status, :duration_ms]
    defstruct [
      :name,
      :status,
      :duration_ms,
      :workspace,
      :steps,
      :tool_calls,
      :log_entries,
      :assertions,
      :error
    ]

    @type t :: %__MODULE__{
            name: String.t(),
            status: :pass | :fail | :error,
            duration_ms: non_neg_integer(),
            workspace: String.t() | nil,
            steps: [QueryResult.t()] | nil,
            tool_calls: [ToolCall.t()] | nil,
            log_entries: [map()] | nil,
            assertions: [AssertionResult.t()] | nil,
            error: term()
          }
  end

  @assertion_types %{
    "response_contains" => :response_contains,
    "response_not_contains" => :response_not_contains,
    "no_errors" => :no_errors,
    "no_warnings" => :no_warnings,
    "tool_called" => :tool_called,
    "tool_not_called" => :tool_not_called,
    "max_duration_ms" => :max_duration_ms,
    "max_tool_calls" => :max_tool_calls
  }

  @type execute_option ::
          {:timeout, pos_integer()}
          | {:workspace, String.t()}
          | {:progress, (non_neg_integer(), map() -> any())}

  @doc """
  Executes a scenario map with default options.
  """
  @spec execute(map()) :: {:ok, Result.t()} | {:error, term()}
  def execute(scenario), do: execute(scenario, [])

  @doc """
  Executes a scenario map against a live Goodwizard agent.
  """
  @spec execute(map(), [execute_option()]) :: {:ok, Result.t()} | {:error, term()}
  def execute(scenario, opts) when is_map(scenario) and is_list(opts) do
    workspace = Keyword.get(opts, :workspace, Goodwizard.Config.workspace())
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    progress = Keyword.get(opts, :progress, fn _index, _step -> :ok end)
    scenario_name = Map.get(scenario, :name, "inline")
    start_ms = System.monotonic_time(:millisecond)

    try do
      with {:ok, telemetry} <- start_telemetry_collector(),
           {:ok, logs} <- start_log_capture(),
           {:ok, session_key, steps} <- prepare_steps_with_replay(scenario, workspace),
           {:ok, agent_pid} <- start_agent(workspace, session_key),
           {step_results, maybe_error} <-
             execute_steps(agent_pid, steps, timeout, workspace, progress) do
        tool_calls = collect_tool_calls(telemetry)
        log_entries = collect_log_entries(logs)
        duration_ms = System.monotonic_time(:millisecond) - start_ms

        assertion_results =
          evaluate_assertions(
            Map.get(scenario, :assertions, []),
            %{
              steps: step_results,
              tool_calls: tool_calls,
              log_entries: log_entries,
              duration_ms: duration_ms
            }
          )

        status = resolve_status(maybe_error, assertion_results)

        {:ok,
         %Result{
           name: scenario_name,
           status: status,
           duration_ms: duration_ms,
           workspace: workspace,
           steps: step_results,
           tool_calls: tool_calls,
           log_entries: log_entries,
           assertions: assertion_results,
           error: maybe_error
         }}
      end
    after
      stop_agent_if_present()
      stop_telemetry_collector_if_present()
      stop_log_capture_if_present()
    end
  end

  @doc """
  Starts a telemetry collector for tool call events during scenario execution.
  """
  @spec start_telemetry_collector() ::
          {:ok, %{collector: pid(), handler_id: String.t()}} | {:error, term()}
  def start_telemetry_collector do
    with {:ok, collector} <- Agent.start_link(fn -> [] end),
         handler_id <- "scenario-tool-calls-#{System.unique_integer([:positive, :monotonic])}",
         :ok <-
           :telemetry.attach_many(
             handler_id,
             @react_events,
             &__MODULE__.handle_tool_event/4,
             %{collector: collector}
           ) do
      Process.put(:scenario_telemetry, %{collector: collector, handler_id: handler_id})
      {:ok, %{collector: collector, handler_id: handler_id}}
    end
  end

  @doc """
  Stops a running telemetry collector.
  """
  @spec stop_telemetry_collector(%{collector: pid(), handler_id: String.t()}) :: :ok
  def stop_telemetry_collector(%{collector: collector, handler_id: handler_id}) do
    :telemetry.detach(handler_id)

    if Process.alive?(collector) do
      Agent.stop(collector, :normal)
    end

    :ok
  end

  @doc """
  Returns tool calls captured so far.
  """
  @spec collect_tool_calls(map()) :: [ToolCall.t()]
  def collect_tool_calls(%{collector: collector}) do
    collector
    |> Agent.get(& &1)
    |> Enum.reverse()
  end

  @doc """
  Telemetry callback that captures completed tool events.
  """
  @spec handle_tool_event([atom()], map(), map(), %{collector: pid()}) :: :ok
  def handle_tool_event(event, measurements, metadata, %{collector: collector}) do
    with true <- tool_complete_event?(event),
         tool_name when is_binary(tool_name) <- normalize_tool_name(metadata),
         true <- Process.alive?(collector) do
      tool_call = %ToolCall{
        tool_name: tool_name,
        status: normalize_status(event, metadata),
        duration_ms: normalize_duration_ms(measurements),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        metadata: metadata
      }

      Agent.update(collector, fn entries -> [tool_call | entries] end)
    else
      _ -> :ok
    end
  end

  @doc """
  Starts scoped log capture for the scenario run.
  """
  @spec start_log_capture() :: {:ok, %{collector: pid(), handler_id: atom()}} | {:error, term()}
  def start_log_capture do
    with {:ok, collector} <- Agent.start_link(fn -> [] end),
         handler_id <- :"scenario-log-#{System.unique_integer([:positive, :monotonic])}",
         :ok <-
           :logger.add_handler(handler_id, LogHandler, %{
             level: :all,
             filter_default: :log,
             filters: [],
             config: %{collector: collector}
           }) do
      Process.put(:scenario_log_capture, %{collector: collector, handler_id: handler_id})
      {:ok, %{collector: collector, handler_id: handler_id}}
    end
  end

  @doc """
  Stops scoped log capture.
  """
  @spec stop_log_capture(%{collector: pid(), handler_id: atom()}) :: :ok
  def stop_log_capture(%{collector: collector, handler_id: handler_id}) do
    case :logger.remove_handler(handler_id) do
      :ok -> :ok
      {:error, _} -> :ok
    end

    if Process.alive?(collector) do
      Agent.stop(collector, :normal)
    end

    :ok
  end

  @doc """
  Returns log entries captured so far.
  """
  @spec collect_log_entries(map()) :: [map()]
  def collect_log_entries(%{collector: collector}) do
    collector
    |> Agent.get(& &1)
    |> Enum.reverse()
  end

  @doc """
  Evaluates scenario assertions against execution context.
  """
  @spec evaluate_assertions([map()], map()) :: [AssertionResult.t()]
  def evaluate_assertions(assertions, context) when is_list(assertions) and is_map(context) do
    Enum.map(assertions, &evaluate_assertion(&1, context))
  end

  if Mix.env() == :test do
    @doc """
    Test helper for exercising setup step application.
    """
    @spec apply_setup_step(String.t(), map()) :: :ok | {:error, term()}
    def apply_setup_step(workspace, step), do: apply_setup(workspace, step)
  end

  defp execute_steps(agent_pid, steps, timeout, workspace, progress) do
    Enum.reduce_while(Enum.with_index(steps), {[], nil}, fn {step, index}, {acc, _error} ->
      progress.(index, step)

      case execute_step(agent_pid, step, index, timeout, workspace) do
        {:ok, result} ->
          {:cont, {acc ++ [result], nil}}

        {:error, result, reason} ->
          {:halt, {acc ++ [result], reason}}
      end
    end)
  end

  defp execute_step(agent_pid, %{type: :query, query: query}, index, timeout, _workspace) do
    start_ms = System.monotonic_time(:millisecond)

    case GoodwizardAgent.ask_sync(agent_pid, query, timeout: timeout) do
      {:ok, response} ->
        duration_ms = System.monotonic_time(:millisecond) - start_ms

        {:ok,
         %QueryResult{
           index: index,
           type: :query,
           query: query,
           response: response,
           duration_ms: duration_ms,
           status: :ok,
           tool_calls: [],
           log_entries: []
         }}

      {:error, reason} ->
        duration_ms = System.monotonic_time(:millisecond) - start_ms

        result = %QueryResult{
          index: index,
          type: :query,
          query: query,
          response: nil,
          duration_ms: duration_ms,
          status: :error,
          error: inspect(reason),
          tool_calls: [],
          log_entries: []
        }

        {:error, result, reason}
    end
  end

  defp execute_step(_agent_pid, %{type: :setup} = step, index, _timeout, workspace) do
    start_ms = System.monotonic_time(:millisecond)

    case apply_setup(workspace, step) do
      :ok ->
        duration_ms = System.monotonic_time(:millisecond) - start_ms

        {:ok,
         %QueryResult{
           index: index,
           type: :setup,
           query: "#{step.action}:#{step.path}",
           response: "ok",
           duration_ms: duration_ms,
           status: :ok,
           tool_calls: [],
           log_entries: []
         }}

      {:error, reason} ->
        duration_ms = System.monotonic_time(:millisecond) - start_ms

        result = %QueryResult{
          index: index,
          type: :setup,
          query: "#{step.action}:#{step.path}",
          response: nil,
          duration_ms: duration_ms,
          status: :error,
          error: inspect(reason),
          tool_calls: [],
          log_entries: []
        }

        {:error, result, reason}
    end
  end

  defp apply_setup(workspace, %{action: :write_file, path: path, content: content}) do
    with {:ok, resolved} <- resolve_workspace_path(workspace, path),
         :ok <- File.mkdir_p(Path.dirname(resolved)),
         :ok <- File.write(resolved, content) do
      :ok
    end
  end

  defp apply_setup(workspace, %{action: :delete_file, path: path}) do
    with {:ok, resolved} <- resolve_workspace_path(workspace, path) do
      case File.rm(resolved) do
        :ok -> :ok
        {:error, :enoent} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp apply_setup(_workspace, _step), do: {:error, :invalid_setup_step}

  defp resolve_workspace_path(workspace, relative_path) do
    expanded_workspace = Path.expand(workspace)
    resolved = Path.expand(relative_path, expanded_workspace)

    if String.starts_with?(resolved, expanded_workspace <> "/") or resolved == expanded_workspace do
      {:ok, resolved}
    else
      {:error, :path_outside_workspace}
    end
  end

  defp evaluate_assertion(%{type: type} = assertion, context),
    do: evaluate_assertion_by_type(normalize_assertion_type(type), assertion, context)

  defp evaluate_assertion(_assertion, _context), do: fail(:unknown, "invalid assertion")

  defp evaluate_assertion_by_type(:response_contains, assertion, context) do
    text = assertion_value(assertion)
    response = response_for_step(context, assertion)

    if contains_case_insensitive?(response, text) do
      pass(:response_contains, "response contains #{inspect(text)}")
    else
      fail(:response_contains, "response missing #{inspect(text)}")
    end
  end

  defp evaluate_assertion_by_type(:response_not_contains, assertion, context) do
    text = assertion_value(assertion)
    response = response_for_step(context, assertion)

    if contains_case_insensitive?(response, text) do
      fail(:response_not_contains, "response unexpectedly contains #{inspect(text)}")
    else
      pass(:response_not_contains, "response does not contain #{inspect(text)}")
    end
  end

  defp evaluate_assertion_by_type(:no_errors, _assertion, context) do
    errors = Enum.count(context.log_entries, fn entry -> Map.get(entry, :level) == :error end)

    if errors == 0,
      do: pass(:no_errors, "no error logs found"),
      else: fail(:no_errors, "found #{errors} error log(s)")
  end

  defp evaluate_assertion_by_type(:no_warnings, _assertion, context) do
    warnings =
      Enum.count(context.log_entries, fn entry -> Map.get(entry, :level) in [:warning, :warn] end)

    if warnings == 0,
      do: pass(:no_warnings, "no warning logs found"),
      else: fail(:no_warnings, "found #{warnings} warning log(s)")
  end

  defp evaluate_assertion_by_type(:tool_called, assertion, context) do
    tool_name = assertion_value(assertion)

    if tool_called?(context.tool_calls, tool_name) do
      pass(:tool_called, "tool #{inspect(tool_name)} was called")
    else
      fail(:tool_called, "tool #{inspect(tool_name)} was not called")
    end
  end

  defp evaluate_assertion_by_type(:tool_not_called, assertion, context) do
    tool_name = assertion_value(assertion)

    if tool_called?(context.tool_calls, tool_name) do
      fail(:tool_not_called, "tool #{inspect(tool_name)} was called")
    else
      pass(:tool_not_called, "tool #{inspect(tool_name)} was not called")
    end
  end

  defp evaluate_assertion_by_type(:max_duration_ms, assertion, context) do
    max_duration = assertion_value(assertion)

    if is_integer(max_duration) and context.duration_ms <= max_duration do
      pass(:max_duration_ms, "duration #{context.duration_ms}ms <= #{max_duration}ms")
    else
      fail(
        :max_duration_ms,
        "duration #{context.duration_ms}ms exceeded #{inspect(max_duration)}"
      )
    end
  end

  defp evaluate_assertion_by_type(:max_tool_calls, assertion, context) do
    max_calls = assertion_value(assertion)
    count = length(context.tool_calls)

    if is_integer(max_calls) and count <= max_calls do
      pass(:max_tool_calls, "tool calls #{count} <= #{max_calls}")
    else
      fail(:max_tool_calls, "tool calls #{count} exceeded #{inspect(max_calls)}")
    end
  end

  defp evaluate_assertion_by_type(other, _assertion, _context),
    do: fail(other, "unsupported assertion type")

  defp response_for_step(context, assertion) do
    index = Map.get(assertion, :step_index, 0)

    if is_integer(index) and index >= 0 do
      context.steps
      |> Enum.at(index)
      |> case do
        %QueryResult{response: response} when is_binary(response) -> response
        _ -> ""
      end
    else
      ""
    end
  end

  defp assertion_value(assertion), do: Map.get(assertion, :value)

  defp contains_case_insensitive?(value, text) when is_binary(value) and is_binary(text) do
    String.contains?(String.downcase(value), String.downcase(text))
  end

  defp contains_case_insensitive?(_value, _text), do: false

  defp tool_called?(tool_calls, name) when is_binary(name) do
    downcased = String.downcase(name)

    Enum.any?(tool_calls, fn call ->
      call.tool_name
      |> to_string()
      |> String.downcase()
      |> Kernel.==(downcased)
    end)
  end

  defp tool_called?(_tool_calls, _name), do: false

  defp pass(type, message), do: %AssertionResult{type: type, passed: true, message: message}
  defp fail(type, message), do: %AssertionResult{type: type, passed: false, message: message}

  defp resolve_status(nil, assertion_results) do
    if Enum.all?(assertion_results, & &1.passed), do: :pass, else: :fail
  end

  defp resolve_status(_error, _assertion_results), do: :error

  defp normalize_assertion_type(type) when is_atom(type), do: type

  defp normalize_assertion_type(type) when is_binary(type),
    do: Map.get(@assertion_types, type, type)

  defp normalize_assertion_type(type), do: type

  defp normalize_tool_name(metadata) do
    cond do
      is_binary(metadata[:tool_name]) ->
        metadata[:tool_name]

      is_atom(metadata[:tool_name]) ->
        Atom.to_string(metadata[:tool_name])

      is_binary(metadata[:tool]) ->
        metadata[:tool]

      is_atom(metadata[:tool]) ->
        Atom.to_string(metadata[:tool])

      is_binary(metadata[:action]) ->
        metadata[:action]

      is_atom(metadata[:action]) ->
        Atom.to_string(metadata[:action])

      true ->
        nil
    end
  end

  defp tool_complete_event?(event) do
    List.last(event) in [:complete, :failed, :stop, :exception]
  end

  defp normalize_status(event, metadata) do
    case List.last(event) do
      status when status in [:failed, :exception] ->
        :error

      _ ->
        case metadata[:result] do
          {:error, _} -> :error
          _ -> :ok
        end
    end
  end

  defp normalize_duration_ms(measurements) do
    cond do
      is_integer(measurements[:duration_ms]) ->
        measurements[:duration_ms]

      is_integer(measurements[:duration]) ->
        System.convert_time_unit(measurements[:duration], :native, :millisecond)

      true ->
        0
    end
  end

  defp start_agent(workspace, session_key) do
    agent_id = "scenario:#{System.unique_integer([:positive, :monotonic])}"

    opts = [
      id: agent_id,
      initial_state: %{
        workspace: workspace,
        channel: "scenario",
        chat_id: "runner",
        session_key: session_key
      }
    ]

    case Goodwizard.Jido.start_agent(GoodwizardAgent, opts) do
      {:ok, pid} ->
        Process.put(:scenario_agent_pid, pid)
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp stop_agent_if_present do
    case Process.get(:scenario_agent_pid) do
      pid when is_pid(pid) ->
        Goodwizard.Jido.stop_agent(pid)
        Process.delete(:scenario_agent_pid)

      _ ->
        :ok
    end
  end

  defp stop_telemetry_collector_if_present do
    case Process.get(:scenario_telemetry) do
      %{collector: _collector, handler_id: _handler_id} = telemetry ->
        stop_telemetry_collector(telemetry)
        Process.delete(:scenario_telemetry)

      _ ->
        :ok
    end
  end

  defp stop_log_capture_if_present do
    case Process.get(:scenario_log_capture) do
      %{collector: _collector, handler_id: _handler_id} = capture ->
        stop_log_capture(capture)
        Process.delete(:scenario_log_capture)

      _ ->
        :ok
    end
  end

  defp prepare_steps_with_replay(scenario, workspace) do
    steps = Map.get(scenario, :steps, [])
    session_key = "scenario-run-#{System.unique_integer([:positive, :monotonic])}"

    apply_replay(Map.get(scenario, :replay), steps, workspace, session_key)
  end

  defp apply_replay(nil, steps, _workspace, session_key), do: {:ok, session_key, steps}

  defp apply_replay(%{session_file: session_file} = replay, steps, workspace, session_key) do
    with {:ok, replay_query, replay_messages} <- load_replay_messages(session_file, replay),
         :ok <- seed_replay_session(workspace, session_key, replay_messages) do
      replay_step = %{type: :query, query: replay_query}
      merged_steps = if steps == [], do: [replay_step], else: steps
      {:ok, session_key, merged_steps}
    end
  end

  defp apply_replay(_replay, _steps, _workspace, _session_key), do: {:error, :invalid_replay}

  defp load_replay_messages(path, replay) do
    with {:ok, content} <- File.read(path),
         [metadata_line | message_lines] <- String.split(content, "\n", trim: true),
         {:ok, metadata_json} <- Jason.decode(metadata_line) do
      message_lines
      |> decode_replay_messages()
      |> maybe_take_messages(Map.get(replay, :up_to_message))
      |> build_replay_payload(metadata_json)
    else
      _ -> {:error, :invalid_replay_file}
    end
  end

  defp decode_replay_messages(lines) do
    Enum.reduce(lines, [], fn line, acc ->
      case Jason.decode(line) do
        {:ok, msg} -> acc ++ [msg]
        {:error, _} -> acc
      end
    end)
  end

  defp build_replay_payload(messages, metadata_json) do
    case find_last_user_index(messages) do
      nil ->
        {:error, :replay_missing_user_message}

      final_user_index ->
        final_user = Enum.at(messages, final_user_index)
        replay_messages = Enum.take(messages, final_user_index)
        metadata = %{created_at: Map.get(metadata_json, "created_at", ""), metadata: %{}}

        {:ok, Map.get(final_user, "content", ""),
         %{metadata: metadata, messages: replay_messages}}
    end
  end

  defp maybe_take_messages(messages, nil), do: messages

  defp maybe_take_messages(messages, limit) when is_integer(limit),
    do: Enum.take(messages, limit + 1)

  defp find_last_user_index(messages) do
    messages
    |> Enum.with_index()
    |> Enum.reduce(nil, fn {msg, index}, acc ->
      if Map.get(msg, "role") == "user", do: index, else: acc
    end)
  end

  defp seed_replay_session(workspace, session_key, %{metadata: metadata, messages: messages}) do
    sessions_dir = Path.join(workspace, "sessions")
    path = Path.join(sessions_dir, "#{session_key}.jsonl")

    metadata_line =
      Jason.encode!(%{
        key: session_key,
        created_at: Map.get(metadata, :created_at, DateTime.utc_now() |> DateTime.to_iso8601()),
        version: 1,
        metadata: Map.get(metadata, :metadata, %{})
      })

    message_lines =
      Enum.map(messages, fn msg ->
        Jason.encode!(%{
          role: Map.get(msg, "role"),
          content: Map.get(msg, "content"),
          timestamp: Map.get(msg, "timestamp")
        })
      end)

    with :ok <- File.mkdir_p(sessions_dir),
         :ok <- File.write(path, Enum.join([metadata_line | message_lines], "\n") <> "\n") do
      :ok
    end
  end
end
