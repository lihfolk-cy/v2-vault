# LihFolk Vault V2 benchmark: design and answer-key verification

This is a fair, blind benchmark of one question: **does the LihFolk Vault V2 plugin make an AI better at Roblox development than the same model without it?**

- `questions.json` holds the 24 tasks: prompt, answer_key checklist, points, sources and optional grader_notes.
- `grading.md` has the blind grading rules.
- This file covers the design, how the keys were verified, how to run the benchmark, and the disputed or dropped items.

## Composition

| Category | Tasks | Points | What it tests |
|---|---|---|---|
| post_training (P1-P8) | 8 | 23 | 2025-2026 platform, API and policy changes: Async renames, Server Authority, Input Action System player scripts, TextChatService lockdown, per-experience DataStore budgets, paid random item odds, Roblox Kids/Select (with the 16+ evaluation step), Creator Rewards and DevEx |
| classic_gotcha (G1-G8) | 8 | 20 | ProcessReceipt idempotency, UpdateAsync vs SetAsync, NaN through remote checks (client trust), Motor6D Transform vs C0, animation priority and weights, FBX 100x scale from Blender, glTF exporter dropping modifiers, UI aspect ratio and safe areas |
| practical (T1-T8) | 8 | 21 | Secure shop remote, session-locked save outline, mobile-safe ScreenGui, two debug-from-symptom remote/PlayerAdded cases, AwardBadgeAsync, an IAS sprint action, and a mesh streaming / RenderFidelity debug case |
| **Total** | **24** | **64** | |

Each task has 2-4 points and a checklist of 2-4 items. Every task can be answered in about 200 words or a short Luau snippet.

## How the keys were verified (fairness)

1. Topics were chosen from the brief. The plugin's `_data/roblox_facts_2026.json` was used **only as a pointer** to find candidate primary URLs.
2. Every key item was written from a primary source fetched on **2026-10-28**:
   - create.roblox.com docs, read through their `.md` renderings and Roblox's official `Roblox/creator-docs` GitHub source where the HTML reference pages render without descriptions
   - official DevForum announcements
   - the Roblox newsroom
   - for G7 only, Blender's own manual and Python API reference, which are the primary source for Blender exporter behaviour
3. Vault wording was not used. After the keys were written, a few vault notes were spot-checked (BindToClose, autosave, ProcessReceipt idempotency, ScreenInsets, Motor6D timing, FBX scale, animation priority). They agree with the keys except where listed below.
4. Trick questions were avoided. Every prompt states the context needed (for example "not a player character" in G4) and asks for facts the sources state directly.

## Running it

1. Use the **same model, effort, tools and date** for every arm:
   - **A**: plugin enabled
   - **B**: plugin disabled
   - optional **C**: plugin disabled but with web search, as a "could it just look it up" control

   Either give web access to every arm or to none; the default is none.
2. Each prompt goes into a fresh, empty working folder with no project files. Add one line to every prompt: *"Answer in under ~200 words or a short Luau snippet."*
3. Run each arm at least 3 times; responses vary from run to run.
4. Anonymise, shuffle the labels per task, and grade blind as described in `grading.md`.
5. Report the total out of 64, the per-category totals, and the count of confident-wrong (-1) items. Report the classic_gotcha score separately as well. It is the least vault-specific slice, so it is the fairest test of whether the plugin helps beyond "knowing recent news".

The original harness (a small PowerShell script, not included) toggled the plugin through `--settings` (`enabledPlugins.lihfolk@lihfolk`) and ran each prompt with `claude -p` in an empty folder.

## Known biases

- **The post_training topics favour the plugin by design.** They cover changes made after a typical model's training data. A plain model will miss them; that gap is part of what the benchmark measures. Read the post_training score next to the gotcha and practical scores.
- **Topic selection overlaps vault coverage.** The topic list came from the brief, and the brief tracks areas the vault covers. A task where neither arm improves still counts.
- **Time sensitivity.** Several keys (P3, P4, T8) describe announced-but-future phases. Re-verify the keys before reusing this benchmark after early 2027.

## Disputed items (vault and/or primary sources disagree; kept out of keys or given partial credit)

1. **DataStore base budget, 250 vs 300 (P5).**
   - The error-codes-and-limits page and the July 2026 unification announcement both say a base of 300.
   - The vault's facts file says an Extended Services pricing table listed 250 and advises designing for the lower figure.
   - A search summary also suggested the Open Cloud throttling guide still describes flat, non-CCU-scaled limits. This was not confirmed by fetching the page.
   - Handling: the key uses 300, and a base of 250 earns partial credit.
2. **TextChatService opt-out deadline (P4).** The announcement says both "before March 2027" and "until May 2027". It is excluded from the key and not penalised either way.
3. **US 18+ DevEx avatar requirement (P8).** The post says "Avatar Settings must be set to R15 Only" but its later update allows custom avatar rigs. Both are accepted.
4. **Mesh streaming Phase 2 (T8).** The ~July 2026 default-on switch could not be confirmed, so both "you enabled it" and "it may be default now" are accepted.
5. **Standard DevEx rate $0.0038 (P8).** The vault labels this "reported" (third-party source). The US 18+ DevEx DevForum post states "$0.38 per 100 Earned Robux", so it is kept as confirmed. This is a provenance mismatch, not a fact dispute.
6. **Motor6D on player characters (G4).** The Motor6D reference says R15 characters with AvatarJointUpgrade (the default for new experiences) use AnimationConstraints instead of Motor6Ds. The vault claims C0 becomes a read-only alias on those characters, which was not confirmed here. G4 is therefore scoped to a non-avatar turret rig.
7. **FBX scale method (G6).** Roblox's current Blender page recommends Apply Scalings = FBX Unit Scale, while older Roblox pages say Transform Scale 0.01. Either method earns credit.
8. **ProcessReceipt vs BindReceiptHandler (G1).** BindReceiptHandler is a newer documented alternative that falls back to ProcessReceipt. Answers using either earn credit.

## Dropped candidates (no primary source confirmed the key)

- *"Animation fails to load in a group game"* (animation asset ownership). The primary docs don't state the ownership rule; only community threads do.
- *"LocalScript in Workspace doesn't run"*. The docs list valid LocalScript containers but never state the Workspace case explicitly.
- *Social-hangout age floor raised from 13 to 16 in May 2026* and *paid random item rules covering bundles*. Both are vault "reported" items from third-party sources only.
- *"One write per key every 6 seconds"*. This rule is no longer on the limits page, which now gives per-key throughput of 4 MB/min for writes and 25 MB/min for reads.

## Set B (held-out)

`questions_b.json` is a held-out set of 24 tasks (B1-B24), written without reference to the LihFolk vault or set A, with the same schema (id, category, prompt, answer_key, points, sources). Mix: 6 debugging, 6 code-writing, 4 architecture, 4 performance/networking, 4 recent-platform; 66 points total. Weighted toward everyday Roblox work. Answer keys were checked in Oct 2026 against create.roblox.com docs, the Creator Roadmap DevForum post and Roblox newsroom posts (URLs in each task's sources). Candidate tasks whose facts could not be confirmed from primary sources (e.g. exact per-server DataStore budget formulas, task library timing semantics, Instance:Destroy connection behavior, MicroProfiler specifics) were dropped or written without those claims. Grade each checklist item as met/not met; score proportionally to points.
