# Phase 8: Telegram Channel

## Why

Telegram is the primary mobile interface for Goodwizard, enabling interaction from anywhere. Using jido_messaging's built-in Telegram support via Telegex eliminates the need for custom Poller, Sender, and Markdown modules. The Handler macro provides polling, update processing, and message delivery out of the box.

## What

### Goodwizard.TelegramHandler

Uses `JidoMessaging.Channels.Telegram.Handler` macro to create a Telegex-based polling handler. The macro generates:

- **on_boot**: Calls `get_me` to verify bot identity, `delete_webhook` to ensure clean polling state
- **on_update**: Transforms Telegram updates → runs through jido_messaging Ingest pipeline (auto-resolves rooms/participants) → calls `handle_message/2` → delivers response via Telegex

The `handle_message/2` callback is the only custom code needed:

```elixir
defmodule Goodwizard.TelegramHandler do
  use JidoMessaging.Channels.Telegram.Handler

  def handle_message(message, context) do
    # Check allow_from list
    if allowed?(message.from.id, context.config) do
      # Get or create AgentServer for this chat
      {:ok, agent_pid} = get_or_create_agent(message.chat.id, context)
      # Dispatch to agent
      case Goodwizard.Agent.ask_sync(agent_pid, message.text, timeout: 120_000) do
        {:ok, answer} -> {:reply, answer}
        {:error, _reason} -> {:reply, "Sorry, I encountered an error. Please try again."}
      end
    else
      :noreply
    end
  end
end
```

### What's Eliminated

- **Goodwizard.Channels.Telegram.Poller** — replaced by Handler macro's built-in Telegex polling
- **Goodwizard.Channels.Telegram.Sender** — replaced by `JidoMessaging.Channels.Telegram.send_message/3` via Telegex
- **Goodwizard.Channels.Telegram.Markdown** — replaced by Telegex `parse_mode` options

### Allow-list Filtering

The `allow_from` config is checked in the `handle_message/2` callback. Empty list means allow all (open mode). Non-empty list filters by Telegram user ID.

### Message Splitting

For responses exceeding Telegram's 4096 character limit, a helper function splits at newline boundaries before the limit. Each chunk is sent as a separate message.

### Application Integration

The Telegram handler is added as a static application child when enabled:

```elixir
# In Application.start/2:
children = [
  {Goodwizard.Config, []},
  {Goodwizard.Jido, []},
  {Goodwizard.Messaging, []}
] ++ telegram_child()

defp telegram_child do
  if Goodwizard.Config.get([:channels, :telegram, :enabled]) do
    [{Goodwizard.TelegramHandler, []}]
  else
    []
  end
end
```

### Per-Channel Voice Adaptation

Telegram agents pass `character_overrides` in their `initial_state` to adapt the character's voice for the mobile context:

```elixir
# In get_or_create_agent/2:
{:ok, pid} = Goodwizard.Jido.start_agent(Goodwizard.Agent,
  id: "telegram:#{chat_id}",
  initial_state: %{
    workspace: workspace,
    channel: "telegram",
    chat_id: chat_id,
    character_overrides: %{
      voice: %{tone: :conversational, style: "brief and mobile-friendly"}
    }
  }
)
```

The `Hydrator.hydrate/2` function applies these overrides after creating the base character and before injecting runtime content, allowing the same character definition to adapt its voice per channel.

## Dependencies

- Phase 5 (CLI Channel) — uses same AgentServer + ask/await pattern
- Phase 1 (Scaffold & Config) — Telegex config and jido_messaging dependency

## Reference

- jido_messaging Telegram support: built-in via Telegex
- Telegex docs: https://hexdocs.pm/telegex/readme.html
