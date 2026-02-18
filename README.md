# Goodwizard

An AI agent built in Elixir on Jido v2.

## Prerequisites

### Install Just

[Just](https://github.com/casey/just) is a command runner used for project tasks.

```bash
# macOS
brew install just

# Arch Linux
pacman -S just

# Cargo (any platform)
cargo install just

# npm
npm install -g just-install
```

See the [Just installation docs](https://github.com/casey/just#installation) for more options.

## Setup

```bash
mix deps.get
cp .env.example .env
```

Edit `.env` with your API keys:

```
ANTHROPIC_API_KEY=your-anthropic-key
TELEGRAM_BOT_TOKEN=your-telegram-bot-token
```

## Commands

| Command | Description |
|---------|-------------|
| `just setup` | Run setup |
| `just up` | Start the agent |
| `just cli` | Start the CLI channel |
| `just status` | Show agent status |
| `just test` | Run tests |
| `just check` | Run quality checks (compile, format, credo, doctor, dialyzer, test) |
| `just build` | Compile the project |
| `just clean` | Clean build artifacts |
| `just deploy` | Deploy to production |

## Scheduling

Goodwizard can run tasks on a schedule using two mechanisms: **scheduled tasks** for recurring execution and **heartbeat monitoring** for periodic agent check-ins.

### Scheduled Tasks

The agent exposes a `schedule_scheduled_task` action that registers recurring tasks with Jido's built-in scheduler. You can ask the agent to schedule tasks in natural language, and it will create the appropriate scheduled task.

**Supported cron formats:**

| Format | Example | Meaning |
|--------|---------|---------|
| Standard 5-field | `0 9 * * *` | Daily at 9:00 AM |
| Day of week | `0 9 * * MON` | Every Monday at 9:00 AM |
| Interval | `*/15 * * * *` | Every 15 minutes |
| Alias | `@daily` | Once a day (midnight) |
| Alias | `@hourly` | Once an hour |
| Alias | `@weekly` | Once a week (Sunday midnight) |
| Alias | `@monthly` | First of each month |
| Alias | `@yearly` | January 1st |

**How it works:**

1. Tell the agent what you want scheduled and when (e.g. "Remind me to check analytics every Monday at 9am")
2. The agent calls `schedule_scheduled_task` with the cron expression, task description, and target room
3. Jido's scheduler picks up the directive and fires the task on each matching tick
4. The task message is delivered to the specified Messaging room

Scheduled tasks persist for the lifetime of the running agent process. High-frequency schedules (every minute) will trigger a warning.

### Heartbeat Monitoring

The heartbeat is a GenServer that wakes the agent at a regular interval to check a `HEARTBEAT.md` file in the workspace. When the file has changed since the last check, its contents are dispatched as a message through the agent pipeline.

**Enable the heartbeat** in `config.toml`:

```toml
[heartbeat]
enabled = true
interval_minutes = 5    # how often to check (default: 5)
timeout_seconds = 120   # max time for the agent to respond (default: 120)
channel = "cli"         # which channel to bind the room to ("cli" or "telegram")
chat_id = "heartbeat"   # external room identifier (see below)
```

**Setting `chat_id` for Telegram delivery:**

To have heartbeat responses delivered to a Telegram chat, you need your Telegram chat ID:

1. Start your bot by sending it `/start` in Telegram
2. Check the application logs — the handler logs `chat_id=<your_id>` for each incoming message
3. Or message [@userinfobot](https://t.me/userinfobot) on Telegram to get your user ID (same as your DM chat ID)

Then configure the heartbeat to target that chat:

```toml
[heartbeat]
enabled = true
channel = "telegram"
chat_id = "123456789"   # your Telegram chat ID
```

For CLI, `chat_id` is just an arbitrary label (the default `"heartbeat"` is fine). Messages are persisted but not pushed anywhere since the CLI has no outbound delivery.

**Trigger a heartbeat** by writing to the file:

```bash
echo "What's the status of my projects?" > priv/workspace/HEARTBEAT.md
```

On the next tick, the agent reads the file, processes it, and saves both the prompt and response to a Messaging room. The file is only processed when its modification time changes, so the same content won't be processed twice.

**Use cases:**

Since `HEARTBEAT.md` is just a file, anything that can write to the filesystem can trigger the agent — scripts, scheduled tasks, CI pipelines, other services, or you. Some examples:

- **Reminders and check-ins** — Write a daily prompt like "What tasks are due today?" and let a system scheduled task update the file each morning.
- **External event triggers** — A deploy script writes "Production deploy completed for v1.4.2 — summarize what changed" after a release, and the agent generates a changelog.
- **Monitoring and alerting** — A shell script watches disk usage or error logs and writes "Disk usage on /data is at 92% — what should I do?" when a threshold is crossed.
- **Automated reporting** — A nightly job writes "Generate a summary of this week's brain activity" to produce periodic digests.
- **CI/CD integration** — A GitHub Action writes test results or build failures to the file, and the agent triages or summarizes them.
- **Cross-system orchestration** — Another service or agent writes instructions to `HEARTBEAT.md` to delegate work, turning the file into a simple inter-process message queue.

The pattern is always the same: write a prompt to the file, and the agent picks it up on the next heartbeat tick. Pair this with a lower `interval_minutes` value for near-real-time responsiveness, or a higher value for background batch processing.

## Agent Concurrency

Goodwizard limits how many concurrent agents can run at once to prevent resource exhaustion. This applies to both scheduled-task-spawned isolated agents and manually spawned subagents.

The default limit is **50** concurrent agents. Scheduled tasks that fire while at capacity are skipped with a warning logged and an error message saved to the target room. Subagent spawns at capacity return an error to the caller.

**Configure via `config.toml`:**

```toml
[scheduled_tasks]
max_concurrent_agents = 50  # max isolated scheduled-task agents running at once
```

The subagent spawn limit is set to the same default (50) but is not currently configurable via `config.toml`.

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
