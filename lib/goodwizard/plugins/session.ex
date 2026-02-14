defmodule Goodwizard.Plugins.Session do
  @moduledoc """
  Plugin that manages conversation session state for the agent.

  Stores messages with role, content, and timestamp. Provides helpers
  to add messages, retrieve history with optional limits, and clear.
  """

  @max_messages 200
  @valid_roles ~w(user assistant system tool)

  use Jido.Plugin,
    name: "session",
    description: "Manages conversation session state",
    state_key: :session,
    actions: [],
    schema:
      Zoi.object(%{
        messages:
          Zoi.list(
            Zoi.object(%{
              role: Zoi.string(),
              content: Zoi.string(),
              timestamp: Zoi.string()
            })
          )
          |> Zoi.default([]),
        created_at: Zoi.string() |> Zoi.optional(),
        metadata: Zoi.map() |> Zoi.default(%{})
      })

  @impl Jido.Plugin
  def mount(_agent, _config) do
    {:ok, %{created_at: DateTime.utc_now() |> DateTime.to_iso8601()}}
  end

  @doc """
  Append a message to the session's messages list.

  Returns updated agent state with the new message appended.
  """
  @spec add_message(map(), String.t(), String.t(), String.t()) :: map()
  def add_message(state, role, content, timestamp) when role in @valid_roles do
    message = %{role: role, content: content, timestamp: timestamp}
    session = Map.get(state, :session, %{messages: []})
    messages = Map.get(session, :messages, [])

    messages =
      messages ++ [message]
      |> Enum.take(-@max_messages)

    updated_session = Map.put(session, :messages, messages)
    Map.put(state, :session, updated_session)
  end

  @doc """
  Return the session's messages list, optionally limited to the most recent N.

  ## Options

    * `:limit` - Return only the N most recent messages
  """
  @spec get_history(map(), keyword()) :: [map()]
  def get_history(state, opts \\ []) do
    messages =
      state
      |> Map.get(:session, %{messages: []})
      |> Map.get(:messages, [])

    case Keyword.get(opts, :limit) do
      nil -> messages
      n when is_integer(n) and n > 0 -> Enum.take(messages, -n)
      _invalid -> messages
    end
  end

  @doc """
  Clear the session's messages list while preserving created_at and metadata.
  """
  @spec clear(map()) :: map()
  def clear(state) do
    session = Map.get(state, :session, %{})
    updated_session = Map.put(session, :messages, [])
    Map.put(state, :session, updated_session)
  end
end
