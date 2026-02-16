## Why

The Spawn action currently creates a generic `SubAgent` with a hardcoded character and tool list regardless of the task. After `subagent-workspace-discovery` makes role configs available, the Spawn action needs to use them — resolving a named role to its character, tools, model, and constraints at spawn time.

This is the change that makes "spawn a researcher" different from "spawn a coder" without any new Elixir modules.

## What Changes

- Update `Goodwizard.Actions.Subagent.Spawn` to accept an optional `agent_name` parameter that resolves to a discovered subagent config.
- Make `Goodwizard.SubAgent` accept runtime options for character content, model, max_iterations, and tool list instead of using hardcoded values.
- Replace `Goodwizard.SubAgent.Character` hardcoded defaults with config-driven character construction — frontmatter fields map to character traits, body becomes instructions.
- Add a tool category resolver that maps category names (`filesystem`, `shell`, `brain`, `memory`, `messaging`, `scheduling`, `browser`) to their corresponding action modules.

## Capabilities

### New Capabilities

- `subagent-configurable-spawn`: Spawn a named subagent role with workspace-defined character, tools, model, and constraints.

### Modified Capabilities

- `subagent-spawn`: The existing `spawn_subagent` action gains an optional `agent_name` parameter. When omitted, it falls back to the current generic SubAgent behavior (backwards compatible).

## Impact

- **New files**: `lib/goodwizard/actions/subagent/tool_resolver.ex`
- **Modified files**: `lib/goodwizard/actions/subagent/spawn.ex` (add `agent_name` param, config resolution), `lib/goodwizard/sub_agent.ex` (accept runtime opts for model, max_iterations, tools), `lib/goodwizard/sub_agent/character.ex` (construct from config instead of hardcoded defaults)
- **Dependencies**: None new

## Prerequisites

- `subagent-workspace-discovery`
