## 1. Configuration

- [ ] 1.1 Add `[approval]` section to `@defaults` in `lib/goodwizard/config.ex` with keys: `enabled` (bool, default false), `timeout` (int, default 60), `default` (string, "deny"), `actions` (list, empty)
- [ ] 1.2 Add `[approval]` section to `config.toml` (commented out with descriptions)
- [ ] 1.3 Add `[approval]` section to `@default_config` in `lib/mix/tasks/goodwizard.setup.ex`

## 2. Approval Server

- [ ] 2.1 Create `lib/goodwizard/approval/server.ex` — GenServer that tracks pending approval requests keyed by unique ref, supports `request/3` (blocking call with timeout) and `respond/2` (resolves a pending request)
- [ ] 2.2 Add `Goodwizard.Approval.Server` to the application supervision tree in `lib/goodwizard/application.ex`
- [ ] 2.3 Write tests for Approval.Server: approve flow, deny flow, timeout with default-deny, timeout with default-approve, concurrent requests, stale respond

## 3. Approval Notifier

- [ ] 3.1 Define `Goodwizard.Approval.Notifier` behaviour with `notify/2` callback (receives request struct and channel info, delivers prompt to human)
- [ ] 3.2 Implement `Goodwizard.Approval.Notifier.CLI` — prints action name, param summary, and `[y/n]` prompt to stdout, reads response from stdin, calls `Approval.Server.respond/2`
- [ ] 3.3 Implement `Goodwizard.Approval.Notifier.Telegram` — sends message with inline keyboard (Approve/Deny) to originating chat via Telegex
- [ ] 3.4 Write tests for CLI notifier (mock IO) and Telegram notifier (mock Telegex)

## 4. Telegram Callback Query Handling

- [ ] 4.1 Extend `Goodwizard.Channels.Telegram.Handler` to handle `callback_query` updates — route approval button presses to `Approval.Server.respond/2`
- [ ] 4.2 After responding, edit the original message to replace inline keyboard with confirmation/denial text
- [ ] 4.3 Handle stale callback queries (request already resolved) with an informational answer

## 5. CLI Approval Response Handling

- [ ] 5.1 Modify `Goodwizard.Channels.CLI.Server` to detect when an approval prompt is active and route `y`/`n`/`yes`/`no` input to `Approval.Server.respond/2` instead of the agent

## 6. Guarded Action Wrapper

- [ ] 6.1 Create `lib/goodwizard/approval/guarded_action.ex` — a macro that generates a wrapper module for a given action. The wrapper has the same Jido action metadata and delegates `run/2` through the approval gate
- [ ] 6.2 Add optional `summarize_params/1` callback to the macro for custom parameter summaries (default: truncate all params to 200 chars)
- [ ] 6.3 Write tests for GuardedAction: wraps action metadata correctly, blocks without approval, delegates on approval, returns error on denial

## 7. Agent Integration

- [ ] 7.1 Modify `Goodwizard.Agent` to read approval config at compile/startup and replace protected actions in the tool list with their guarded wrappers
- [ ] 7.2 Pass channel type and channel identifier (chat_id) through tool_context so guarded actions can resolve the correct notifier
- [ ] 7.3 Write integration test: agent with approval enabled, protected action triggers approval flow, approval allows execution, denial blocks execution

## 8. Parameter Summarizers

- [ ] 8.1 Add `summarize_params/1` implementation for `Shell.Exec` — shows the command string
- [ ] 8.2 Add `summarize_params/1` implementation for `Subagent.Spawn` — shows the task description
- [ ] 8.3 Add `summarize_params/1` implementation for `Messaging.Send` — shows room_id and content preview
