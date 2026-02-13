# Goodwizard Build Plan

Nanobot rebuilt in Elixir on Jido v2 (2.0.0-rc.4) + jido_ai (0.5.2). Each phase is scoped to complete in a single Opus 4.6 context window.

**Jido v2 docs**: https://hexdocs.pm/jido/2.0.0-rc.4/readme.html
**jido_ai docs**: https://hexdocs.pm/jido_ai/readme.html

---

## Architecture Decision: jido_ai over req_llm

jido_ai (from the same agentjido team) replaces req_llm as the LLM integration layer. This collapses what was originally 11 phases into 10 by eliminating custom code that jido_ai provides out of the box:

| jido_ai Component | Replaces | Impact |
|-------------------|----------|--------|
| `Jido.AI.Strategies.ReAct` | Custom ToolLoop strategy | Eliminates Phase 5 entirely |
| `Jido.AI.Tools.Registry` + `Executor` + `ToolAdapter` | Custom ToolBuilder | Eliminates most of Phase 3 |
| `Jido.AI.ReActAgent` macro | Manual agent + skill composition | Simplifies Phase 4 |
| Orchestration actions (`SpawnChildAgent`, `DelegateTask`) | Custom subagent spawning | Simplifies Phase 10 |
| Multiple strategies (CoT, ToT, GoT, TRM, Adaptive) | Nothing (bonus) | Free capabilities |

req_llm is still used under the hood — jido_ai pulls it in transitively.

---

## Dependency Graph

```
Phase 1: Scaffold + Config           (standalone)
Phase 2: Actions                     (standalone)
Phase 3: ReAct Integration           (needs Phase 2)
Phase 4: Agent Definition            (needs Phase 3)
Phase 5: CLI Channel                 (needs Phase 4)
Phase 6: Memory + Persistence        (needs Phase 4, 5)
Phase 7: Prompt Skills               (needs Phase 6)
Phase 8: Telegram Channel            (needs Phase 5)
Phase 9: Web + Subagents             (needs Phase 4)
Phase 10: Cron + Polish              (needs Phase 8, 9)
```

Phases 1-2 can run in parallel. Phases 8-9 can run in parallel after Phase 5.

---

## Line Count Estimates

| Phase | Est. Lines | Modules |
|-------|-----------|---------|
| 1. Scaffold + Config | ~200 | 3 |
| 2. Actions | ~350 | 5 |
| 3. ReAct Integration | ~150 | 1 |
| 4. Agent Definition | ~200 | 2 |
| 5. CLI Channel | ~250 | 4 |
| 6. Memory + Persistence | ~400 | 6 |
| 7. Prompt Skills | ~200 | 1 |
| 8. Telegram Channel | ~350 | 3 |
| 9. Web + Subagents | ~300 | 5 |
| 10. Cron + Polish | ~200 | 4 |
| **Total** | **~2,600** | **34** |

~400 fewer lines than the original plan thanks to jido_ai eliminating custom ToolBuilder and ToolLoop code.

---

## OpenSpec Changes

Each phase has a proposal and tasks file in `openspec/changes/`:

```
openspec/changes/
  phase-01-scaffold-config/    proposal.md  tasks.md
  phase-02-actions/            proposal.md  tasks.md
  phase-03-react-integration/  proposal.md  tasks.md
  phase-04-agent-definition/   proposal.md  tasks.md
  phase-05-cli-channel/        proposal.md  tasks.md
  phase-06-memory-persistence/ proposal.md  tasks.md
  phase-07-prompt-skills/      proposal.md  tasks.md
  phase-08-telegram-channel/   proposal.md  tasks.md
  phase-09-web-subagents/      proposal.md  tasks.md
  phase-10-cron-polish/        proposal.md  tasks.md
```

---

## Reference: Nanobot Source Files

| Python File | Lines | Target Phase |
|---|---|---|
| `config/schema.py` | 289 | Phase 1 (Config) |
| `agent/tools/base.py` | 103 | Phase 2 (Action pattern) |
| `agent/tools/filesystem.py` | 212 | Phase 2 (FS Actions) |
| `agent/tools/shell.py` | 144 | Phase 2 (Shell Action) |
| `agent/tools/registry.py` | 74 | Phase 3 (jido_ai replaces) |
| `agent/context.py` | 239 | Phase 3 (ContextBuilder) |
| `agent/loop.py` | 455 | Phase 3 (jido_ai ReAct replaces) |
| `session/manager.py` | 203 | Phase 6 (Session) |
| `agent/memory.py` | 31 | Phase 6 (Memory) |
| `agent/skills.py` | 229 | Phase 7 (PromptSkills) |
| `channels/telegram.py` | 408 | Phase 8 (Telegram) |
| `agent/tools/web.py` | ~150 | Phase 9 (Web) |
| `agent/subagent.py` | ~100 | Phase 9 (SubAgent) |
