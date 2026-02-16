defmodule Goodwizard.Character.Preamble do
  @moduledoc """
  Generates a static, code-controlled preamble for the system prompt.

  The preamble orients the agent to its workspace directory structure and
  bootstrap files. It is prepended to the system prompt before any
  character-rendered content.

  This module is intentionally not configurable via config.toml or workspace
  files — it stays in sync with code changes automatically.
  """

  @doc """
  Returns the system prompt preamble string.

  The preamble describes the workspace directory layout and the purpose of
  each directory and bootstrap file. It is static and returns the same
  value on every call.
  """
  @spec generate() :: String.t()
  def generate do
    """
    ## System Orientation

    You are operating within a structured workspace. Here is the layout:

    ### Workspace Directories

    - **brain/** — Persistent knowledge store for entities (people, companies, events, etc.)
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
  end
end
