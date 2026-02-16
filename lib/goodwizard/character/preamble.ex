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
  - **memory/** — Long-term conversation memory and learned preferences
  - **sessions/** — Active and historical conversation session data
  - **skills/** — Prompt-based skills that extend your capabilities
  - **scheduling/** — Scheduled tasks and cron job definitions

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
