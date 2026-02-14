## REMOVED — Superseded by Goodwizard.Messaging

The `Goodwizard.ChannelSupervisor` module has been **removed**. Its responsibilities are now handled by `Goodwizard.Messaging` (backed by `jido_messaging ~> 0.1`), which was introduced in Phase 1.

### What Goodwizard.Messaging replaces

- **DynamicSupervisor for channels** → jido_messaging provides room supervision, channel instance management, and a signal bus
- **`start_channel/2` helper** → Channels are either static application children (Telegram handler) or started directly (CLI Server via mix task)
- **Supervision tree entry** → `Goodwizard.Messaging` is already in the application supervision tree from Phase 1 (Config → Jido → Messaging)

### Migration notes

- All references to `ChannelSupervisor` in downstream phases should use `Goodwizard.Messaging` or direct process start instead
- The CLI Server is started directly by the mix task, not via a supervisor helper
- The Telegram handler is a static application child when enabled (see Phase 8)
