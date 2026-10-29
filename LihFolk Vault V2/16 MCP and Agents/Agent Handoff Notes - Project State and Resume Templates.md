---
tags: [agents, ai, workflow, handoff, documentation, claude-code, type/template, area/ai, level/intermediate]
---
# Agent Handoff Notes - Project State and Resume Templates

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No state file; every session starts with a full re-read.
> - Avoid: "Works" with no evidence.
> - Avoid: Decisions without dates or reasons, so they get reopened.
> - CLAUDE.md or AGENTS.md has the start and end session protocol.
> - PROJECT_STATE.md exists, under ~150 lines, with Identity, Works, In progress, Broken, Decisions, Open questions, Do not touch.
> - Every session ends with a handoff file with a concrete next step.
>
> Cost: TL;DR ~150 tok · whole note ~2.1k tok. Read more: ## 2. PROJECT_STATE.md template · ## 3. Handoff note template · ## Common mistakes · ## Checklist
<!-- tldr:end -->

AI agents forget everything between sessions, and long sessions get compacted. A new agent that starts on a Roblox project with no handoff will re-read the codebase (expensive), re-make decisions you already rejected (frustrating) and, worst, act on stale assumptions about the place: which Studio window, which branch, what is half-finished, what must not be touched. A short, maintained **PROJECT_STATE.md** plus a handoff note at the end of each session fixes this. It is the cheapest reliability tool in an agent workflow.

This note gives the templates and the rules that keep them honest. Labels: **Rule of thumb** unless stated. Claude Code facts cite [code.claude.com/docs](https://code.claude.com/docs/en/memory).

---

## 1. Three layers of memory

| Layer | What goes there | Changes |
|---|---|---|
| `CLAUDE.md` / `AGENTS.md` | Stable rules: build commands, conventions, safety rules, where things live | Rarely |
| `PROJECT_STATE.md` | Current truth: what works, what is in progress, open decisions, known breakages | Every session |
| `handoffs/YYYY-MM-DD-<topic>.md` | What one session did, left undone and learned | Written once, then read-only |

Claude Code loads `CLAUDE.md` (and can read `AGENTS.md`) from the working directory and every parent at session start; subdirectory files load when the agent touches files there; the docs recommend keeping each under about 200 lines, and `@path` imports load together with the importing file, so they organise but do not save context (Claude Code docs). So **do not import PROJECT_STATE.md into CLAUDE.md** if it grows; instead put one rule in CLAUDE.md: "Read PROJECT_STATE.md before starting work."

LihFolk's own [AGENTS.md](../../AGENTS.md) is an example of the stable layer: one search command first, TL;DR before sections, quality bar.

---

## 2. PROJECT_STATE.md template

```markdown
# Project state (updated 2026-10-28 by <agent or person>)

## Identity
- Game: <name>, universe <id>, live place <id>, TEST place <id>
- Repo branch in use: <branch>; Rojo project: default.project.json
- Studio: open place by PLACE ID, never by window title

## Works (verified, with how)
- Shop purchase flow: UI suite shop_buy_flow passed 2026-10-27
- Data save/load: migration fixtures v3-v9 green in CI

## In progress
- Trading v2 (branch trade-v2): escrow done, UI not wired. Next: confirm screen.

## Broken or risky right now
- CombatService.lua is ~199k chars (200k Source limit): extend via new modules only
- Do not run start_stop_play: <person> playtests 14:00-16:00 UTC

## Decisions (do not relitigate without new evidence)
- 2026-10-20: ProfileStore for data, not raw DataStore (session locking)
- 2026-10-22: no paid random items; eggs use soft currency only

## Open questions (need a human)
- Price of the starter pack: 99 or 149 Robux?

## Do not touch
- ServerStorage/LegacyMap (kept for rollback until 2026-11-15)
```

Rules:

- **Each "Works" line says how it was verified** (test name, date). An unverified "works" is a guess handed to the next agent as a fact.
- **Decisions carry a date and a one-line reason.** Agents (and people) reopen settled questions when the reason is missing.
- **"Do not touch" and "Broken" go near the top.** They prevent the most expensive mistakes.
- **Keep it short.** Rule of thumb: under 150 lines. Move history to handoff files.

---

## 3. Handoff note template

Written at the end of each session (or before a planned context compaction):

```markdown
# Handoff 2026-10-28 trading-confirm-screen

## Goal of the session
Wire the trade confirm screen to the escrow service.

## Done
- TradeConfirm UI built (StarterGui/Trade/Confirm), buttons named Confirm_Accept/Confirm_Cancel
- Server: TradeService.confirm validates both sides, commits via escrow

## Not done / next step (start here)
1. Cancel path does not release escrow on player leave. Repro: dupe script 2.1 "leave mid-trade".
2. Then run Dupe Hunting script sections 2.1 and 2.4.

## State left behind
- Studio: TEST place open, Edit mode, nothing running
- Uncommitted: src/server/TradeService.luau (compiles; tests not run)
- Named Version History save: "before trade confirm" 2026-10-28 13:10

## Learned
- multi_edit fails if the script changed since read; re-read first.

## Evidence
- Quality score: system rubric 8.1/10 (one blind reviewer), lowest: error handling
```

The **"Not done / next step"** section is the most valuable: the next agent starts there instead of rediscovering it.

---

## 4. Resume protocol for the next agent

Put this in CLAUDE.md or AGENTS.md:

```markdown
## Starting a session
1. Read PROJECT_STATE.md, then the newest file in handoffs/.
2. Verify the "State left behind": git status, Studio state (list_roblox_studios, get_studio_state).
3. If reality differs from the note, stop and report the difference before changing anything.
4. Work from "Not done / next step". Do not reopen "Decisions" without new evidence.
## Ending a session
1. Write a handoff file. 2. Update PROJECT_STATE.md (Works / In progress / Broken).
3. Leave Studio in Edit with nothing running; make a named save if the place changed.
```

Step 3 is the safety net: a handoff is a claim about the world, and the world may have changed (a human edited the place, a teammate merged a branch).

---

## 5. Automating the reminders

- A Claude Code **SessionStart** hook can print the first lines of PROJECT_STATE.md and the newest handoff's "Next step" into context, so the agent sees them even if it forgets the rule. A **Stop** or **SessionEnd** hook can remind it to write the handoff. Check the current hook event names in the Claude Code hooks docs before wiring them.
- Claude Code also keeps local transcripts for resuming a session (stored under `~/.claude/projects/` for 30 days by default, adjustable with `cleanupPeriodDays`, per the [data usage docs](https://code.claude.com/docs/en/data-usage)). Resuming a transcript is not a substitute for a handoff: transcripts are long and full of dead ends.
- The LihFolk quality ledger (`.lihfolk/ledger.jsonl`, written by the `quality-score` skill) is another persistent record: link the latest score in the handoff's Evidence section rather than copying it.

---

## 6. Multi-agent projects

When several agents share a place ([[Multiple Agents in One Studio]]), add an **Ownership** section to PROJECT_STATE.md: which agent or person owns which folder or system right now. Two agents editing the same ModuleScript produce lost edits that neither notices.

---

## Common mistakes

- No state file; every session starts with a full re-read.
- "Works" with no evidence.
- Decisions without dates or reasons, so they get reopened.
- Handoffs that describe what was done but not what to do next.
- Importing a growing state file into CLAUDE.md, bloating every session.
- Trusting the handoff without checking Studio and git state.

## Checklist

- [ ] CLAUDE.md or AGENTS.md has the start and end session protocol.
- [ ] PROJECT_STATE.md exists, under ~150 lines, with Identity, Works, In progress, Broken, Decisions, Open questions, Do not touch.
- [ ] Every session ends with a handoff file with a concrete next step.
- [ ] Next agent verifies state before acting.
- [ ] Ownership section when more than one agent works at once.

## See also

- [[AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well]], [[Agent Review Loops and Guardrails in Practice]]
- [[Safety Rules for AI Agents in Studio]], [[Multiple Agents in One Studio]]
- [[Case Study - Building a Game with AI Agents]], [[AI Agents and Autonomous Workflows]]

## Connected notes

[[Roblox Studio MCP Server]] · [[Version History and Backups]] · Prompting and Verifying AI Output · Team Create and Collaboration

<!-- related:start -->
## Related
[[Running Many AI Agents on One Roblox Place]] · [[Built-In Studio MCP vs Community MCP Servers - Migration Guide]] · [[What Is MCP]] · [[MCP Workflows for Building Worlds]] · [[MCP Workflows for Scripting and Debugging]] · [[Writing Your Own MCP Server]] · [[Setting Up MCP Clients]] · [[Blender MCP]] · [[Studio Plugins and Local HTTP Bridges]]
<!-- related:end -->
