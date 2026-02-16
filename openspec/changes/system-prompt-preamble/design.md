## Context

The system prompt is built by `Character.Hydrator.hydrate/2`, which:
1. Creates a base `Jido.Character` struct
2. Applies config overrides (tone, style)
3. Injects bootstrap files from workspace (`IDENTITY.md`, `SOUL.md`, etc.) as knowledge
4. Injects brain awareness instructions
5. Injects memory and skills
6. Renders via `Jido.Character.to_system_prompt/1` → returns a markdown string

There is no code-controlled orientation section. The agent has no built-in awareness of workspace directory structure, conventions, or system capabilities unless manually written into workspace files.

## Goals / Non-Goals

**Goals:**
- Add a `Preamble` module that generates a static orientation string describing the system
- Inject it at the start of the system prompt, before all character-rendered content
- Include workspace directory layout and purpose of each directory
- Keep it code-controlled so it stays in sync with structural changes

**Non-Goals:**
- Not a replacement for `IDENTITY.md` or `SOUL.md` — those define personality and identity
- Not configurable via `config.toml` — this is developer-controlled context, not user-tunable
- Not a place for dynamic/runtime content — keep it static and fast

## Decisions

### 1. New module: `Goodwizard.Character.Preamble`

Single public function `generate/0` that returns a string. No arguments needed — it describes the system's own structure which is fixed at compile time (or at most reads from Config for the workspace path).

**Why a separate module:** Keeps the Hydrator focused on orchestration. The preamble content will grow over time as the system gains features, and isolating it makes it easy to find and edit.

### 2. Prepend to the rendered prompt string, not injected into Character struct

The `Jido.Character` struct has structured fields (knowledge, instructions) that get rendered by `Jido.Character.Context.Renderer`. Injecting the preamble as "knowledge" would place it after identity/personality sections and label it with a category header.

Instead, `Hydrator.hydrate/2` will:
1. Render the character to a string as before
2. Prepend the preamble string with `\n\n` separator

This keeps the preamble at the very top of the system prompt where orientation context belongs.

### 3. Content scope

The preamble will describe:
- Workspace directory layout (brain, memory, sessions, skills, scheduling)
- Purpose of each directory in one line
- Bootstrap file purposes (IDENTITY.md, SOUL.md, USER.md, TOOLS.md, AGENTS.md)

It will NOT include:
- Agent personality or tone (that's `SOUL.md` / `IDENTITY.md`)
- Tool descriptions (that's `TOOLS.md`)
- Dynamic state (brain entities, active skills)

## Risks / Trade-offs

- **[Prompt length]** → The preamble adds tokens to every request. Mitigation: keep it concise (target < 200 tokens). Review periodically.
- **[Staleness]** → If workspace structure changes but preamble isn't updated, agent gets wrong info. Mitigation: CLAUDE.md already documents the config change checklist; add preamble to that list.
