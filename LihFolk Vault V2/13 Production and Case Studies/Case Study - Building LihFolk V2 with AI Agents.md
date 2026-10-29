---
tags: [case-study, ai, agents, lihfolk, pipeline, quality, review, type/case-study, area/production, area/ai, level/advanced]
---
# Case Study - Building LihFolk V2 with AI Agents

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Letting the maker agent grade its own work, or showing the reviewer the maker's intent text.
> - Avoid: Treating one reviewer's score as the truth.
> - Avoid: Hand-fixing one variant of a generated family; the fix vanishes on the next run.
> - Rubric, gates and anchors written before production
> - Every attempt logged with fix and delta, including negative ones
> - Pass/fail = median of 3 blind reviewers; spreads of 2+ points recorded
>
> Cost: TL;DR ~150 tok · whole note ~1.8k tok. Read more: ## 1. What was built · ## 3. Headline lessons · ## Common mistakes · ## Checklist
<!-- tldr:end -->

verified: 2026-10-28

LihFolk V2 is a Roblox toolkit built almost entirely by AI agents: a knowledge vault of several hundred notes, a Claude Code plugin with skills and hooks, and an asset pack of procedural models, PBR materials, skyboxes, VFX and R15 animation clips. This note is the post-mortem. It records what the build taught about running agents on creative and technical work at scale, and points to the detailed lesson notes. Numbers marked **Measured** were measured in this project; everything else is a judgement from doing the work.

## 1. What was built

| Part | Size | How it was judged |
|---|---|---|
| Knowledge vault | 50+ sections, generated index, router and TL;DRs | Retrieval eval (90 tasks) and a 24-task benchmark |
| Model kits | 26 generator types, about 90 blind reviews (**Measured**) | Gates A1-A18 + 9-criterion rubric |
| Materials | 99 ledger entries across ~20 families (**Measured**) | Gates G1-G6 + 7-criterion rubric |
| Skies | 46 ledger entries across ~12 families (**Measured**) | Gates S1-S5 + 6-criterion rubric |
| Animations | 54 ledger entries, 11 clips iterated through v1-v6 (**Measured**) | QA JSON gates + 7-criterion rubric |
| VFX | 10 entries; slashes, thrusts, impacts, charges | Gates + 6-criterion rubric |

Every attempt was written to a `.lihfolk/ledger.jsonl` with the score, failed gates, low criteria, the fix tried and the score change. That ledger is the raw material for the recipes and for this vault's lesson notes.

## 2. The loop that worked

1. **Generator, not hand edits.** Each asset family is a script with parameters, so a fix applies to every variant.
2. **Hard gates first.** Measured checks (watertight, symmetry, tiling proof, foot slide, arm twist) cap the score at 5.0 when they fail. Agents cannot argue past a number.
3. **Blind review second.** A reviewer agent sees only the renders, the gate report and the rubric. It never sees the maker's intent or reasoning.
4. **Median of three decides.** One reviewer swings 1-2 points (**Measured**: Walk 6.0 / 7.0 / 8.0 on the same clip). Pass/fail uses the per-criterion median of three.
5. **Ledger every round.** Record the fix and its delta, including regressions. Several "obvious" fixes scored negative.
6. **Distil into recipes.** Recurring misses move into the first-pass defaults so the next draft starts higher.

Details: [[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]].

## 3. Headline lessons

- **A vault beats the base model mainly on recent facts.** In the benchmark the vault arm scored 61.8 / 64 against 45.4 / 64, and almost all of the gap came from 2025-2026 platform changes (**Measured**). See [[Benchmark - Does a Knowledge Vault Make AI Better at Roblox]].
- **Maker-assisted scores flatter.** Blind reviewers scored animation clips about 2 points below the maker's own review, and single reviewers over-scored sword clips by about 0.7 against the panel (**Measured**).
- **Prove the generator, then trust the gates.** Once a generator passes a 3-reviewer panel, production runs on gates alone with a 1-in-20 blind spot check.
- **Previews lie in specific ways.** Blender showed Roblox colours washed out until sRGB values were converted to linear; Workbench's default AgX view made vertex colours look grey. Fix the preview before arguing with the reviewer. See [[VFX Previews in Blender for Roblox - Colour and Framing]].
- **Some plateaus are topological.** A 22-shell fox stuck at 7.7 however the shells were tuned; a fused SDF shell removed the seams but decimation facets held it at 7.0. The next step is a designed quad cage. See [[Procedural Creatures - Fused Shells, Quad Cages and Faceting]].
- **The arm twist bug needed a per-frame plan.** Per-key solves let Blender's per-joint interpolation re-twist the forearm between keys. See [[Arm Twist and Grip Roll - Lessons from Baked Sword Clips]].
- **Infrastructure fails quietly.** The sub-agent concurrency limit left four VFX drafts without a final review; PowerShell 5.1 corrupted UTF-8; a folder rename broke every path. See [[Agent Orchestration - Sub-Agents, Hooks and Skill Costs]] and [[Windows Tooling Pitfalls for Agent Pipelines]].

## 4. What it cost

- Each blind review is a full agent run with images. Panels of three triple that. Budget review slots before starting a batch, not after.
- With the vault the benchmark answers took about 1.9x the time and 1.7x the tokens of plain answers (**Measured**). That price is worth paying for recent platform knowledge. It is not worth paying for evergreen basics.
- Every skill description is loaded into every session. Trimming them saved about 1,000 tokens per session (**Measured**, see [[Token Cost Benchmarks]]).

## 5. What we would do differently

- Write the rubric, the gates and the calibration anchors **before** the first asset, not after the second round of reviews.
- Lock a reference sheet (front + side) for any creature before modelling. Fox reviewers asked for a different proportion every round.
- Reserve sub-agent slots for final reviews at the start of a batch.
- Keep before/after copies of every render and module (`_compare/_vN/`) from round one.
- Stop iterating a criterion after two rounds with zero delta and change the method instead.

## Common mistakes

- Letting the maker agent grade its own work, or showing the reviewer the maker's intent text.
- Treating one reviewer's score as the truth. A swing of 1-2 points is normal.
- Hand-fixing one variant of a generated family; the fix vanishes on the next run.
- Logging only successes. The regressions in the ledger were the most useful entries.
- Iterating on surface parameters when the plateau comes from topology, rig limits or preview bugs.

## Checklist

- [ ] Rubric, gates and anchors written before production
- [ ] Every attempt logged with fix and delta, including negative ones
- [ ] Pass/fail = median of 3 blind reviewers; spreads of 2+ points recorded
- [ ] Preview pipeline verified against Studio colours and framing
- [ ] Sub-agent slots budgeted for the final reviews
- [ ] Recurring misses moved into first-pass recipes

## See also

- [[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]]
- [[Procedural Model Kits - Lessons]]
- [[Procedural Materials and Skies - Lessons]]
- [[Obsidian Vaults for AI Agents - Structure, Graph and Theming]]
- [[Case Study - Building a Game with AI Agents]]

## Connected notes

[[Lessons Learned Index]] · [[Asset Pipelines]] · [[AI Agents and Autonomous Workflows]] · Agent Review Loops and Guardrails in Practice

<!-- related:start -->
## Related
[[Team Roles and Workflows]] · [[Documentation and Knowledge Bases]] · [[Post-Mortem - Building a Melee Action Game]] · [[Case Study - Enemy Roster Rebuild]] · [[Working with AI Assistants in Studio]] · [[Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev]] · [[Planning and Scoping a Roblox Game]] · [[Scoping and Roles for Small Teams]]
<!-- related:end -->
