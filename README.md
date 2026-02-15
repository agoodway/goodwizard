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
