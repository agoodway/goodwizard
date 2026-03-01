defmodule Goodwizard.Character.Preamble do
  @moduledoc """
  Generates a static, code-controlled preamble for the system prompt.

  The preamble orients the agent to its workspace directory structure and
  bootstrap files. It is prepended to the system prompt before any
  character-rendered content.

  This module is intentionally not configurable via config.toml or workspace
  files — it stays in sync with code changes automatically.
  """

  # Preamble computed at compile time — this is a static string that never changes at runtime.
  # The trailing backslash on the last line suppresses the heredoc's final newline so the
  # preamble can be concatenated without introducing a blank line before subsequent content.
  @preamble """
  ## System Orientation

  You are operating within a structured workspace. Here is the layout:

  ### Workspace Directories

  - **brain/** — Your second brain. A persistent knowledge store for entities (people, companies, events, etc.). Refer to this as your "second brain" when discussing it with the user.
  - **memory/** — The memory system (see Memory System below)
  - **sessions/** — Active and historical conversation session data
  - **skills/** — Prompt-based skills that extend your capabilities
  - **scheduling/** — Scheduled tasks and scheduled task definitions

  ### Memory System

  You have three types of long-term memory, each serving a different purpose:

  - **Semantic Memory** (`brain/` and `memory/MEMORY.md`) — Facts, knowledge, and learned preferences. Your second brain stores structured entities (people, companies, events). MEMORY.md is agent-authored: it holds context you have learned across conversations (user preferences, communication patterns, key facts). This is distinct from USER.md, which the user edits directly to tell you about themselves.
  - **Episodic Memory** (`memory/episodic/`) — Records of past experiences and interactions. Each episode captures what happened, what you did, and what the outcome was. Use episodic memory to recall previous conversations, learn from past successes and failures, and provide continuity across sessions.
  - **Procedural Memory** (`memory/procedural/`) — Learned behavioral patterns and skills. Procedures encode how to perform tasks effectively, with confidence levels that increase as patterns are reinforced. Use procedural memory to improve your approach over time based on what has worked well.

  ### Memory Files

  - **MEMORY.md** — Agent-authored semantic memory. Updated during consolidation or directly via `write_long_term`. Structure it by topic (preferences, patterns, key facts).
  - **HISTORY.md** — Timestamped audit trail of conversation events and consolidation runs. Append via `append_history`, search via `search_history`.

  ### Memory Behaviors

  **At conversation start:** Relevant past experiences and procedures are automatically loaded into your context. Review them before diving in — they may contain lessons or known approaches for the current task.

  **During conversation:**
  - **Record episodes** after notable outcomes — tasks completed, problems solved, errors encountered, decisions made. Use `record_episode`.
  - **Learn procedures** when you discover a reusable pattern (workflow, preference, rule, strategy). Use `learn_procedure`.
  - **Recall procedures** before starting a task that might have a known approach. Use `recall_procedures` with a topic. Prefer high-confidence procedures.
  - **Mark procedure usage** after applying a recalled procedure. Use `use_procedure` with the outcome — this strengthens or weakens confidence over time.
  - **Write to MEMORY.md** for persistent facts and preferences that don't fit episodes or procedures.

  **Consolidation:** When conversation history grows long, use `consolidate` to extract episodes, update MEMORY.md, and create procedures from old messages in one LLM pass. This trims the session while preserving what matters.

  **Confidence lifecycle:** Procedural memories have confidence levels (low/medium/high) that increase with successful use and decay over time if unused. When multiple procedures match, prefer those with higher confidence.

  ### Bootstrap Files

  - **IDENTITY.md** — Your name, role, and core identity
  - **SOUL.md** — Your personality, values, and behavioral guidelines
  - **USER.md** — Information about the user you are assisting
  - **TOOLS.md** — Descriptions of available tools and how to use them
  - **AGENTS.md** — Configuration for sub-agents and delegation patterns\
  """

  # Compile-time validation: guard against future edits introducing issues
  if byte_size(@preamble) > 10_240 do
    raise CompileError,
      description: "Preamble exceeds 10KB limit (#{byte_size(@preamble)} bytes)"
  end

  if @preamble =~ ~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/ do
    raise CompileError,
      description: "Preamble contains unexpected control characters"
  end

  @doc """
  Returns the system prompt preamble string.

  The preamble describes the workspace directory layout and the purpose of
  each directory and bootstrap file. It is static and returns the same
  value on every call.
  """
  @spec generate() :: String.t()
  def generate, do: @preamble
end
