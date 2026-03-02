# Goodwizard

A personal AI agent built in Elixir on [Jido](https://github.com/agentjido/jido).

## Getting Started

### Prerequisites

- Elixir ~> 1.17
- [Just](https://github.com/casey/just) command runner
- An [Anthropic API key](https://console.anthropic.com/)

### Install & Setup

```bash
mix deps.get
mix goodwizard.setup
```

`mix goodwizard.setup` creates the workspace directory, `config.toml`, and bootstrap files (`IDENTITY.md`, `SOUL.md`, `USER.md`, etc.).

### Configure

Copy and edit `.env` with your API keys:

```bash
cp .env.example .env
```

```
ANTHROPIC_API_KEY=your-anthropic-key
TELEGRAM_BOT_TOKEN=your-telegram-bot-token   # optional, for Telegram channel
```

Edit `config.toml` to set your preferred model, enabled channels, and other options.

### Run

```bash
# Interactive CLI REPL
mix goodwizard.cli

# Full OTP application (Telegram, heartbeat, scheduling)
mix goodwizard.start
```

### Commands

| Command | Description |
|---------|-------------|
| `just setup` | Run setup |
| `just up` | Start the agent |
| `just cli` | Start the CLI REPL |
| `just status` | Show agent status |
| `just test` | Run tests |
| `just check` | Run quality checks (compile, format, credo, doctor, dialyzer, test) |
| `just build` | Compile the project |
| `just clean` | Clean build artifacts |

## How the Agent Works

### Character & Identity

The agent's personality and knowledge are shaped by editable files in the workspace:

- **`IDENTITY.md`** — who the agent is (name, role, tone)
- **`SOUL.md`** — values, principles, and behavioral guidelines
- **`USER.md`** — what the agent knows about you
- **`TOOLS.md`** — guidance for how the agent uses its tools
- **`AGENTS.md`** — conventions for sub-agent behavior

At startup, the Preamble module assembles these files plus runtime state (available tools, knowledge base schemas, skills) into a full system prompt via the Hydrator.

### Knowledge Base

A file-backed structured entity store with JSON Schema validation. Entities are stored as markdown with YAML frontmatter in `knowledge_base/<type>/<id>.md`.

**Built-in types:** people, places, events, notes, tasks, companies, tasklists, webpages

At startup, type-specific actions are auto-generated from the schemas — `create_person`, `update_company`, `search_notes`, etc. — so the agent can manage entities through natural conversation. Entities can cross-reference each other via `"type/uuid"` strings in their fields.

### Memory System

Three complementary memory types:

- **Semantic** (`MEMORY.md`) — persistent free-form context the agent maintains about you. Updated as the agent learns your preferences, habits, and ongoing projects.
- **Episodic** (`memory/episodic/`) — immutable records of past experiences: task completions, errors, decisions, and outcomes. Provides a factual history the agent can reference.
- **Procedural** (`memory/procedural/`) — learned workflows and patterns with confidence tracking, usage-based promotion/demotion, and time-based decay. The agent builds these by recognizing repeated patterns.

When a conversation grows long, a consolidation pass extracts new episodes and procedures from the session and updates `MEMORY.md`.

### Skills

Prompt-based capability extensions stored in `skills/<name>/SKILL.md`.

Skills use two-tier loading: a summary of each skill is included in every system prompt so the agent knows what's available, but the full skill body is only loaded on demand via `activate_skill`. This keeps the base prompt compact while allowing rich, detailed instructions when a skill is actually used.

**Bundled:** `weather` (wttr.in + Open-Meteo forecasts)

### Scheduled Tasks

**Recurring tasks** use cron expressions (standard 5-field, day names, or aliases like `@daily`, `@hourly`). Each tick spawns an isolated sub-agent so scheduled work can't interfere with your active conversation.

| Format | Example | Meaning |
|--------|---------|---------|
| Standard 5-field | `0 9 * * *` | Daily at 9:00 AM |
| Day of week | `0 9 * * MON` | Every Monday at 9:00 AM |
| Interval | `*/15 * * * *` | Every 15 minutes |
| Alias | `@daily` | Once a day (midnight) |
| Alias | `@hourly` | Once an hour |

**One-time tasks** fire after a delay or at an absolute time, then are cleaned up.

Both types persist to disk and reload on restart.

### Heartbeat

A GenServer that polls `HEARTBEAT.md` on a configurable interval. When the file's modification time changes, its contents are dispatched through the agent pipeline.

Since `HEARTBEAT.md` is just a file, anything that can write to the filesystem can trigger the agent — scripts, CI pipelines, cron jobs, monitoring tools, or other services. Example:

```bash
echo "What tasks are due today?" > priv/workspace/HEARTBEAT.md
```

On the next tick, the agent reads the file, processes the prompt, and saves the response. The same content won't be processed twice.

**Use cases:** reminders, deploy hooks, monitoring alerts, automated reporting, cross-system orchestration.

### Tools

The agent has access to these tool categories:

| Category | Description |
|----------|-------------|
| **Filesystem** | Read, write, edit, list, grep — restricted to the workspace by default |
| **Shell** | Command execution with safety guards (regex deny-list blocks dangerous commands) |
| **Browser** | Full automation: navigate, click, type, screenshot, extract content |
| **Knowledge Base** | Auto-generated CRUD actions for each entity type |
| **Memory** | Store and recall semantic, episodic, and procedural memories |
| **Messaging** | Send messages to rooms |
| **Sub-agent** | Spawn isolated child agents for delegated work |
| **Scheduling** | Create recurring or one-time scheduled tasks |

### Sessions

Conversation history is persisted as JSONL in `sessions/`.

- **CLI:** A new session is created per invocation.
- **Telegram:** One persistent session per chat, survives restarts.

### Channels

**CLI** — Interactive REPL via `mix goodwizard.cli`. Best for local development and quick interactions.

**Telegram** — Long-polling bot with user allowlist, automatic splitting of long messages, and per-channel personality overrides via `character_overrides` in config. See [Telegram Bot Setup](#telegram-bot-setup) below.

## Configuration Reference

| Section | Key | Default | Description |
|---------|-----|---------|-------------|
| `[agent]` | `model` | `anthropic:claude-sonnet-4-5` | LLM model identifier |
| | `max_tokens` | `8192` | Max tokens per response |
| | `temperature` | `0.7` | Sampling temperature |
| | `workspace` | `priv/workspace` | Workspace directory path |
| | `max_tool_iterations` | `20` | Max ReAct loop iterations per turn |
| | `memory_window` | `50` | Recent messages loaded into context |
| `[channels.cli]` | `enabled` | `true` | Enable CLI channel |
| `[channels.telegram]` | `enabled` | `false` | Enable Telegram channel |
| | `allow_from` | `[]` | User ID allowlist (empty = allow all) |
| | `character_overrides` | — | Override tone/style for Telegram |
| `[tools]` | `restrict_to_workspace` | `true` | Restrict filesystem/shell to workspace |
| `[tools.exec]` | `timeout` | `60` | Shell command timeout in seconds |
| | `deny_patterns` | *(see config.toml)* | Regex patterns that block shell commands |
| `[heartbeat]` | `enabled` | `false` | Enable heartbeat polling |
| | `interval_minutes` | `5` | How often to check the file |
| | `timeout_seconds` | `120` | Max agent response time |
| | `channel` | `cli` | Delivery channel (`cli` or `telegram`) |
| | `chat_id` | `heartbeat` | Room identifier for delivery |
| `[scheduling]` | `channel` | `cli` | Default channel for scheduled tasks |
| | `chat_id` | — | Default chat ID for scheduled tasks |
| `[scheduled_tasks]` | `max_concurrent_agents` | `50` | Max isolated agents running at once |
| | `ask_timeout` | `120000` | Timeout (ms) per scheduled agent call |
| | `max_jobs` | `50` | Max total persisted scheduled tasks |
| `[browser]` | `headless` | `true` | Run browser without GUI |
| | `adapter` | `vibium` | Browser adapter (`vibium` or `playwright`) |
| | `timeout` | `30000` | Browser action timeout in ms |
| `[browser.search]` | `brave_api_key` | — | Brave Search API key |
| `[session]` | `max_cli_sessions` | `50` | Max retained CLI session files |

**Env var overrides:** `GOODWIZARD_WORKSPACE`, `GOODWIZARD_MODEL`, `BRAVE_API_KEY`, `TELEGRAM_BOT_TOKEN`, `ANTHROPIC_API_KEY`

## Telegram Bot Setup

### 1. Create the bot

1. Open Telegram and message [@BotFather](https://t.me/BotFather)
2. Send `/newbot`
3. Choose a display name (e.g. "Good Wizard")
4. Choose a username ending in `bot` (e.g. `goodwizard_bot`)
5. Copy the API token BotFather gives you

### 2. Add the token to your environment

Add the token to your `.env` file:

```
TELEGRAM_BOT_TOKEN=7123456789:AAFmtwQR...your-token
```

### 3. Enable the Telegram channel

Edit `config.toml`:

```toml
[channels.telegram]
enabled = true
allow_from = []  # empty = allow all users
```

To restrict access to specific Telegram users, add their user IDs:

```toml
[channels.telegram]
enabled = true
allow_from = [123456789]
```

You can find your Telegram user ID by messaging [@userinfobot](https://t.me/userinfobot).

### 4. Customize the bot profile (optional)

Message [@BotFather](https://t.me/BotFather) and use `/mybots` to:

- **Edit Botpic** — set a profile picture
- `/setdescription` — text users see before starting a chat
- `/setabouttext` — bio in the bot's profile
- `/setname` — change the display name
- `/setcommands` — set the command menu

## Agent Concurrency

Goodwizard limits concurrent agents to prevent resource exhaustion. This applies to scheduled-task agents and manually spawned sub-agents.

The default limit is **50** concurrent agents (configurable via `scheduled_tasks.max_concurrent_agents`). Scheduled tasks that fire while at capacity are skipped with a warning logged. Sub-agent spawns at capacity return an error to the caller.
