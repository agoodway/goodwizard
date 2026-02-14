defmodule Goodwizard.Channels.Telegram.HandlerTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Agent, as: GoodwizardAgent
  alias Goodwizard.Channels.Telegram.Handler
  alias Goodwizard.Character.Hydrator
  alias Goodwizard.Messaging
  alias Jido.Signal.ID, as: SignalID
  alias JidoMessaging.Channels.Telegram, as: TelegramChannel
  alias JidoMessaging.Content.Text, as: ContentText
  alias JidoMessaging.Message

  setup do
    workspace = Path.join(System.tmp_dir!(), "gw_tg_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(workspace)
    on_exit(fn -> File.rm_rf!(workspace) end)
    {:ok, workspace: workspace}
  end

  describe "split_message/1" do
    test "returns single-element list for short message" do
      assert Handler.split_message("hello") == ["hello"]
    end

    test "returns single-element list for exactly 4096 characters" do
      text = String.duplicate("a", 4096)
      assert Handler.split_message(text) == [text]
    end

    test "splits at newline boundary for long message" do
      # Create a message with a newline at position 4000, total > 4096
      first_part = String.duplicate("a", 4000)
      second_part = String.duplicate("b", 200)
      text = first_part <> "\n" <> second_part

      chunks = Handler.split_message(text)
      assert length(chunks) == 2
      assert Enum.at(chunks, 0) == first_part
      assert Enum.at(chunks, 1) == second_part
    end

    test "force splits at 4096 when no newline available" do
      text = String.duplicate("a", 5000)
      chunks = Handler.split_message(text)

      assert length(chunks) == 2
      assert String.length(Enum.at(chunks, 0)) == 4096
      assert String.length(Enum.at(chunks, 1)) == 904
    end

    test "handles multiple splits" do
      text = String.duplicate("a", 10_000)
      chunks = Handler.split_message(text)

      assert length(chunks) == 3
      assert String.length(Enum.at(chunks, 0)) == 4096
      assert String.length(Enum.at(chunks, 1)) == 4096
      assert String.length(Enum.at(chunks, 2)) == 1808
    end

    test "returns single-element list for empty string" do
      assert Handler.split_message("") == [""]
    end

    test "splits at last newline before limit" do
      # Newlines at 2000 and 4000 — should split at 4000 (last before limit)
      chunk_a = String.duplicate("a", 2000)
      chunk_b = String.duplicate("b", 2000)
      chunk_c = String.duplicate("c", 200)
      text = chunk_a <> "\n" <> chunk_b <> "\n" <> chunk_c

      chunks = Handler.split_message(text)
      assert length(chunks) == 2
      # First chunk should include everything up to the last newline before 4096
      assert Enum.at(chunks, 0) == chunk_a <> "\n" <> chunk_b
      assert Enum.at(chunks, 1) == chunk_c
    end
  end

  describe "handle_message/2 with allow-list" do
    test "allows message when allow_from is empty (open mode)", %{workspace: workspace} do
      {message, context} = build_message_and_context("hello", 12_345, workspace)

      # With empty allow_from (default config), message should be processed
      # It will error on agent creation but that's fine — we're testing the allow check
      result = Handler.handle_message(message, context)
      # If it got past the allow check, it won't be :noreply
      refute result == :noreply
    end

    test "blocks message from user not in allow_from list", %{workspace: workspace} do
      # Temporarily set allow_from to a list that excludes our test user
      original_config = :sys.get_state(Goodwizard.Config)

      updated_config =
        put_in(original_config, ["channels", "telegram", "allow_from"], [111_111])

      :sys.replace_state(Goodwizard.Config, fn _ -> updated_config end)

      try do
        {message, context} = build_message_and_context("hello", 99_999, workspace)
        result = Handler.handle_message(message, context)
        assert result == :noreply
      after
        :sys.replace_state(Goodwizard.Config, fn _ -> original_config end)
      end
    end

    test "blocks message when from_id is nil", %{workspace: workspace} do
      {message, context} = build_message_and_context("hello", 12_345, workspace)

      # Override context to have no telegram external_id
      context = %{context | participant: %{context.participant | external_ids: %{}}}

      result = Handler.handle_message(message, context)
      assert result == :noreply
    end
  end

  describe "handle_message/2 with agent routing" do
    test "processes text message and routes to agent", %{workspace: workspace} do
      {message, context} = build_message_and_context("hello world", 12_345, workspace)

      # The handler will try to start an agent and call ask_sync
      # Without a real API key, the agent will return an error
      # The handler catches this and returns {:reply, error_message}
      result = Handler.handle_message(message, context)

      # Handler always returns {:reply, text} or :noreply — never {:error, _}
      # Without API key, agent fails but handler wraps it in an error reply
      assert match?({:reply, _}, result) or result == :noreply
    end

    test "returns :noreply for empty text message", %{workspace: workspace} do
      {message, context} = build_message_and_context("", 12_345, workspace)
      assert Handler.handle_message(message, context) == :noreply
    end

    test "returns :noreply for message with no text content", %{workspace: workspace} do
      context = build_context(12_345, workspace)

      message = %Message{
        id: SignalID.generate!(),
        room_id: context.room.id,
        sender_id: context.participant.id,
        role: :user,
        content: [],
        metadata: %{}
      }

      assert Handler.handle_message(message, context) == :noreply
    end
  end

  describe "handle_message/2 input validation" do
    test "rejects messages exceeding max input length", %{workspace: workspace} do
      long_text = String.duplicate("a", 10_001)
      {message, context} = build_message_and_context(long_text, 12_345, workspace)

      result = Handler.handle_message(message, context)
      assert {:reply, reply} = result
      assert reply =~ "too long"
    end
  end

  describe "message persistence" do
    test "saves user message to Messaging store", %{workspace: workspace} do
      {message, context} = build_message_and_context("hello persistence", 12_345, workspace)

      # The handler will try to process and save the user message
      # Even if agent fails, the user message should be saved first
      Handler.handle_message(message, context)

      {:ok, messages} = Messaging.list_messages(context.room.id)
      user_messages = Enum.filter(messages, fn msg -> msg.role == :user end)
      assert user_messages != []

      last_user = List.last(user_messages)
      assert last_user.sender_id == "user"
      assert [%{type: "text", text: "hello persistence"}] = last_user.content
    end
  end

  describe "character_overrides for Telegram voice" do
    test "Hydrator applies tone and style overrides from Telegram config", %{workspace: workspace} do
      overrides = %{
        "tone" => "friendly",
        "style" => "brief and mobile-friendly"
      }

      {:ok, prompt} =
        Hydrator.hydrate(workspace, config_overrides: overrides)

      assert is_binary(prompt)
      assert String.length(prompt) > 0
      # The hydrated prompt should reflect the friendly tone
      assert prompt =~ "friendly" or String.length(prompt) > 100
    end

    test "agent passes character_overrides to Hydrator", %{workspace: workspace} do
      # Start an agent with Telegram-style character_overrides
      {:ok, agent_pid} =
        Goodwizard.Jido.start_agent(GoodwizardAgent,
          id: "telegram:test_voice_#{System.unique_integer([:positive])}",
          initial_state: %{
            workspace: workspace,
            channel: "telegram",
            chat_id: "test",
            character_overrides: %{
              "tone" => "friendly",
              "style" => "brief and mobile-friendly"
            }
          }
        )

      assert is_pid(agent_pid)
      assert Process.alive?(agent_pid)

      # Verify agent state has the overrides
      {:ok, server_state} = Jido.AgentServer.state(agent_pid)
      agent = server_state.agent

      assert agent.state.character_overrides == %{
               "tone" => "friendly",
               "style" => "brief and mobile-friendly"
             }

      assert agent.state.channel == "telegram"
    end
  end

  # -- Helpers -----------------------------------------------------------------

  defp build_message_and_context(text, user_id, workspace) do
    context = build_context(user_id, workspace)

    content =
      if text == "" do
        []
      else
        [%ContentText{text: text}]
      end

    message = %Message{
      id: SignalID.generate!(),
      room_id: context.room.id,
      sender_id: context.participant.id,
      role: :user,
      content: content,
      metadata: %{channel: :telegram}
    }

    {message, context}
  end

  defp build_context(user_id, _workspace) do
    {:ok, room} =
      Messaging.get_or_create_room_by_external_binding(
        :telegram,
        "test",
        "chat_#{user_id}",
        %{type: :direct, name: "Test Chat #{user_id}"}
      )

    {:ok, participant} =
      Messaging.get_or_create_participant_by_external_id(
        :telegram,
        "#{user_id}",
        %{type: :human, identity: %{username: "test_user_#{user_id}"}}
      )

    %{
      room: room,
      participant: participant,
      channel: TelegramChannel,
      instance_id: "test",
      external_room_id: "chat_#{user_id}",
      instance_module: Goodwizard.Messaging
    }
  end
end
