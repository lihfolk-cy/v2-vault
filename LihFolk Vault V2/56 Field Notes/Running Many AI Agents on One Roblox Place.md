---
tags: [field-notes, ai, agents, mcp, coordination, studio, workflow, backups, type/guide, area/ai, level/intermediate, area/studio]
---
# Running Many AI Agents on One Roblox Place

<!-- tldr:start -->
> [!tldr] TL;DR
> - A fix disappears after another agent's change: Two writers on one module -> Single owner per area
> - Batch items done twice or skipped: No claims -> Claim files with expiry and status
> - Edits silently revert recent work: Edit based on a stale read -> Fresh read and changed-since-read check
> - Ownership map on disk; one writer per module or folder.
> - Claim files with `claimed_by`, `claimed_at`, status and expiry for batch work.
> - Every edit preceded by a fresh read and guarded by a changed-since-read check.
>
> Cost: TL;DR ~170 tok · whole note ~1.7k tok. Read more: ## 2. Claim files for batch jobs · ## 3. Re-read before every edit · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Multiple Agents in One Studio]] covers what agents share in one Studio window and the rules that keep them from colliding. This note adds the operational lessons that only showed up after weeks of many agents editing one large place: ownership that is written down, claim files for batch jobs, why "re-read before edit" is not optional, where backups belong, who holds Play mode, the autosave restart trap, and tagging every edit so it can be found again. Safety rules are in [[Safety Rules for AI Agents in Studio]]; the wider story in [[Case Study - Building a Game with AI Agents]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. Single ownership per area

One agent owns each area: a folder, a set of modules, a GUI, a map zone. Others may read it; only the owner writes. **Never two writers on one module**, even for "a one-line fix": two agents that each read, change and write the same script will silently erase each other's change, because each writes the whole source it read.

Write ownership down in a file every agent reads at start (`OWNERS.md` or a JSON map of path prefix to agent). If an agent needs a change in someone else's area, it leaves a request for the owner instead of editing.

## 2. Claim files for batch jobs

Batch jobs (re-export 120 animations, restyle 40 panels, rename ids across modules) are often split across several agents. Without coordination two agents take the same item, or an item is skipped because each thought the other had it. A claim file per item fixes it:

```json
{
  "item": "Panels/ShopPanel",
  "claimed_by": "agent-ui-2",
  "claimed_at": "2026-10-12T14:03:11Z",
  "status": "in_progress"
}
```

Rules that worked (**Measured**):

- Claim before starting; check that nobody else claimed it first (write the claim, re-read it, confirm it is still yours).
- Claims expire. If `claimed_at` is older than the job's sensible maximum (for example 30 minutes) and the status is still `in_progress`, another agent may take it over.
- Mark `done` with a short result line, so the lead can audit progress without reading Studio.

Keep claim files **on disk**, not as attributes inside the place, so they survive Studio restarts and are readable without Studio.

## 3. Re-read before every edit

An agent's picture of a script is whatever it read last, possibly minutes ago. Other agents, the human, or the agent's own earlier call may have changed it since. **Every edit starts with a fresh read**, and the write checks that the source still matches what was read (with `ScriptEditorService:UpdateSourceAsync`, compare inside the callback and abort on mismatch; see [[Studio Automation Without Freezing Studio]]).

**Rule of thumb:** with many agents, lost work comes far more often from edits based on a stale read than from two agents writing at the same instant.

## 4. Back up to disk, not into the place

Copies of scripts or folders kept "just in case" inside the place (a `Backup_Old` folder in `ServerStorage`) cause problems: they bloat the place, get found by searches and edited by mistake, and old copies of scripts can run if they are moved or cloned. Back up to the file system instead: dump sources and serialised instance trees to a dated folder before each risky change. That also gives you diffs. [[Version History and Backups]] covers the place-level history; disk backups cover the minute-to-minute work.

## 5. One agent holds Play mode

While a Play session runs, Studio's Edit model cannot be changed by tools in the usual way, and one agent stopping Play ends everyone's test. Treat Play as a lock:

- Only one agent (or the human) holds it, announced in a shared status file.
- Others queue Edit work and wait; they do not stop Play.
- The holder releases promptly and records what it tested.

## 6. Restarts can reopen an older autosave

**Measured.** After Studio crashed or was restarted, it sometimes reopened an older autosave or recovery copy rather than the latest state, so recent edits were missing. To everyone else this looks like a fix that "regressed".

Hence:

## 7. Tag every edit with a searchable marker

Every edit an agent makes carries a short marker comment, such as `-- [agent-ui-2 2026-10-12 close-button]` at the changed lines, plus a line in the agent's on-disk log. After any restart, search the place for the markers listed in the logs. Missing markers mean missing edits; re-apply them from the disk backup or the log. Markers also answer "who changed this?" months later. **Rule of thumb:** keep the marker format fixed and grep-able, and strip markers only in a deliberate clean-up pass, never casually.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| A fix disappears after another agent's change | Two writers on one module | Single owner per area |
| Batch items done twice or skipped | No claims | Claim files with expiry and status |
| Edits silently revert recent work | Edit based on a stale read | Fresh read and changed-since-read check |
| Old backup scripts run or get edited | Backups stored inside the place | Back up to disk |
| Tests killed mid-run | Agents stopping each other's Play | Play is a lock held by one |
| Fixes "regress" after a restart | Older autosave reopened | Search for edit markers and re-apply |

## Checklist

- [ ] Ownership map on disk; one writer per module or folder.
- [ ] Claim files with `claimed_by`, `claimed_at`, status and expiry for batch work.
- [ ] Every edit preceded by a fresh read and guarded by a changed-since-read check.
- [ ] Backups written to disk, none inside the place.
- [ ] Play mode treated as a single-holder lock.
- [ ] Every edit tagged with a marker; markers re-verified after any restart.

## Connected notes
<!-- auto-links:start -->
[[Multiple Agents in One Studio]] · Safety Rules for AI Agents in Studio · Case Study - Building a Game with AI Agents · Agent Review Loops and Guardrails in Practice · Version History and Backups · [[Field Notes Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[AI Agents and Autonomous Workflows]] · [[Agent Handoff Notes - Project State and Resume Templates]] · [[Roblox Studio MCP Server]] · [[Resetting One Player's Data Safely]] · [[Moving Data Out of a Play Session]] · [[Blind Review Scores - Noise, Panels and Shipping the Best Version]]
<!-- related:end -->
