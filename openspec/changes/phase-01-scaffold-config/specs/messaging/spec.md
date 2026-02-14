## ADDED Requirements

### Requirement: Messaging module uses JidoMessaging with ETS adapter
`Goodwizard.Messaging` SHALL use `use JidoMessaging, adapter: JidoMessaging.Adapters.ETS` to provide messaging infrastructure including rooms, participants, messages, signal bus, deduplication, and channel supervision.

#### Scenario: Messaging module starts successfully
- **WHEN** `Goodwizard.Messaging` is started as part of the application supervision tree
- **THEN** it SHALL be a running process providing room supervision, signal bus, and deduper services

#### Scenario: Messaging module provides room management
- **WHEN** `Goodwizard.Messaging` is running
- **THEN** it SHALL support creating, listing, and managing rooms via the JidoMessaging API

### Requirement: Messaging supports room creation
`Goodwizard.Messaging` SHALL support creating rooms for tracking conversations across channels.

#### Scenario: Create a room
- **WHEN** `Goodwizard.Messaging.create_room(%{name: "test-room"})` is called
- **THEN** it SHALL return `{:ok, %JidoMessaging.Room{}}` with the room created and supervised

#### Scenario: Get or create room by external binding
- **WHEN** `Goodwizard.Messaging.get_or_create_room_by_external_binding(:cli, "goodwizard", "direct")` is called
- **THEN** it SHALL return `{:ok, room}` — creating the room if it doesn't exist, or returning the existing room if it does

#### Scenario: Get or create room is idempotent
- **WHEN** `get_or_create_room_by_external_binding(:telegram, "bot", "12345")` is called twice
- **THEN** both calls SHALL return the same room

### Requirement: Messaging supports message persistence
`Goodwizard.Messaging` SHALL support saving messages to rooms for conversation tracking.

#### Scenario: Save a message to a room
- **WHEN** `Goodwizard.Messaging.save_message(%{room_id: room_id, sender_id: "user", content: "Hello"})` is called
- **THEN** it SHALL return `{:ok, %JidoMessaging.Message{}}` with the message persisted in the room

#### Scenario: Retrieve messages from a room
- **WHEN** messages have been saved to a room and the room's message history is queried
- **THEN** the messages SHALL be returned in chronological order
