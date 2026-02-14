## REWRITTEN — Messaging.Send uses room_id API

The `Messaging.Send` action now uses `room_id + content` schema instead of `channel + chat_id + content`. Messages are persisted via `Goodwizard.Messaging.save_message/1` and delivered externally via `JidoMessaging.Deliver` for rooms with channel bindings.

## ADDED Requirements

### Requirement: Messaging.Send action saves and delivers messages to rooms
The `Goodwizard.Actions.Messaging.Send` action SHALL use `use Jido.Action` with a schema accepting `room_id` (required, string) and `content` (required, string). The `run/2` callback SHALL save the message via `Goodwizard.Messaging.save_message/1` and trigger external delivery via `JidoMessaging.Deliver` for rooms with channel bindings.

#### Scenario: Send a message to a room
- **WHEN** `Messaging.Send` is called with `room_id: "room_abc123"` and `content: "Hello from the agent"`
- **THEN** it SHALL save the message via `Goodwizard.Messaging.save_message(%{room_id: "room_abc123", sender_id: "assistant", content: "Hello from the agent"})` and return `{:ok, %{message: "Message sent to room room_abc123"}}`

#### Scenario: Send a message to a Telegram-bound room
- **WHEN** `Messaging.Send` is called with a room_id that has a Telegram external binding
- **THEN** the message SHALL be saved to the room AND delivered externally via `JidoMessaging.Deliver` to the bound Telegram chat

#### Scenario: Send a message to a CLI-bound room
- **WHEN** `Messaging.Send` is called with a room_id that has a CLI external binding
- **THEN** the message SHALL be saved to the room (CLI delivery is handled by the CLI Server's own read loop)

#### Scenario: Missing required fields
- **WHEN** `Messaging.Send` is called without `room_id` or `content`
- **THEN** it SHALL return a schema validation error for the missing field

#### Scenario: Empty content
- **WHEN** `Messaging.Send` is called with `content: ""`
- **THEN** it SHALL return `{:error, "Message content cannot be empty"}`

### Requirement: Tool registration adds browser plugin, subagent, and messaging actions to main agent
The main `Goodwizard.Agent` SHALL include `JidoBrowser.Plugin` in its plugins configuration and `Subagent.Spawn` and `Messaging.Send` in its tool list, in addition to the existing filesystem and shell tools.

#### Scenario: Main agent has browser plugin
- **WHEN** the main `Goodwizard.Agent` is instantiated
- **THEN** its plugins SHALL include `JidoBrowser.Plugin` which auto-registers 31 browser actions (no individual `Goodwizard.Actions.Web.*` modules needed)

#### Scenario: Main agent has subagent tools
- **WHEN** the main `Goodwizard.Agent` is instantiated
- **THEN** its tool list SHALL include `Goodwizard.Actions.Subagent.Spawn`

#### Scenario: Main agent has messaging tools
- **WHEN** the main `Goodwizard.Agent` is instantiated
- **THEN** its tool list SHALL include `Goodwizard.Actions.Messaging.Send` with `room_id + content` schema
