---
tags: [case-study, mcp, agents, production, workflow, type/case-study, area/ai, level/intermediate, area/monetization]
---
# Case Study - Building a Game with AI Agents

<!-- tldr:start -->
> [!tldr] TL;DR
> - The rules in Safety Rules for AI Agents in Studio were not designed up front.
> - Write the rules down, with numbers. "Under 1.5 s" works; "be careful" does not.
> - Keep a map of the place in the instructions.
> - Studio is for I/O and truth; compute elsewhere.
>
> Cost: TL;DR ~110 tok · whole note ~3.4k tok. Read more: ## 4. A real agent pipeline: adding a weapon · ## 6. What went wrong
<!-- tldr:end -->

This is the story of the reference project used throughout this vault: a live action game on Roblox built with heavy use of AI coding agents (Claude Code sessions) connected to Roblox Studio and Blender through MCP. It covers what the game contained, how the work was organised, a real end-to-end agent pipeline (adding a new weapon), the numbers, what went wrong, and the lessons that generalise. Names, ids and people are left out; the numbers are real.

For the mechanics behind each part see [[Roblox Studio MCP Server]], [[Blender MCP]], [[Studio Plugins and Local HTTP Bridges]], [[Safety Rules for AI Agents in Studio]] and [[Multiple Agents in One Studio]]. For the game-design side of the same project see [[Post-Mortem - Building a Melee Action Game]].

---

## 1. The game

A melee action game with collectible weapons of rising rarity, zones of enemies and bosses. By the period this study covers it had:

- A lobby with crafting stations, several areas of zones, and a few side modes.
- Well over a hundred weapons, each with a rigged model, an icon, lore, a voice, and (for higher rarities) a full attack kit of animated moves and an ultimate.
- Thousands of animation clips: several hundred player kit move clips and well over a thousand enemy clips across dozens of enemy kits.
- Quests, an upgrade board, crafting, daily rewards, game passes, leaderboards, a phone-specific UI.

Almost all of it was written, built, placed or tuned by agents, with one human owner directing, importing assets, approving looks, publishing, and play-testing.

---

## 2. The setup

| Part | Role |
|---|---|
| Roblox Studio + Studio MCP server | The live place: read and edit scripts, run Luau in Edit, read the Output, capture the viewport, upload images |
| Claude Code sessions | The agents. A lead session plus several long-running independent sessions; the lead spawned specialist agents for passes |
| Blender (interactive) | Modelling and the upload add-on; driven through Blender MCP and by scripts |
| Blender (headless, `blender -b`) | Batch rendering (icons), mesh rebuilds, exports |
| Python on disk | Offline tools: animation solvers, QA scoring, generators for zone and enemy definitions, icon post-processing, note generators |
| Local HTTP servers on 127.0.0.1 | Serving tool sources and data into Studio, receiving dumps out, serving images for upload, serving archived clips |
| A project instructions file | Working rules, a map of the place, owned areas, gotchas; read at every session start |

The governing idea, stated in the project's tooling notes: **Studio is an I/O device and a ground-truth oracle; the heavy work lives outside it.** Studio did three kinds of things (dump data, play or measure the real engine, write results); everything else ran offline and could be re-run without touching Studio ([[Studio Tooling Architecture]]).

---

## 3. The working rules (and the incidents behind them)

The rules in [[Safety Rules for AI Agents in Studio]] were not designed up front. Each came from an incident:

| Rule | Incident |
|---|---|
| Edit only; never start or stop Play | A Play-mode verification cycled Play and blocked every other session's Edit work |
| Calls under about 1.5 s, one at a time | Studio froze for about 25 minutes with around 18 offline processes plus in-Studio simulations; the budget went 5 s, then 3.5 s, then 1.5 s |
| Never undo | An undo went about 40 waypoints back and reverted other sessions' changes |
| No backup folders in the place | The place reached about 1.07 million instances; Studio ran at about 15 fps |
| Clone-require modules | Edited modules tested as unchanged because `require` returned a cached copy |
| Save gate with a use-before-definition scan | Scripts that compiled crashed at runtime on a call above its definition |
| Reserved names | A clip named `Origin` shadowed a kit's `Origin` RemoteEvent; that weapon dealt no damage |
| Re-read shared modules; one insert | Sessions overwrote each other's config changes |
| Verify numerically when captures fail | Captures came back black whenever Studio was not in front |
| "Not play-tested" in every report | A backlog of untested changes built up; the notes said so explicitly |

The owner's own preferences became rules too: be direct, no long reports, no screenshots unless asked; one art style for everything; player-facing text plain and short.

---

## 4. A real agent pipeline: adding a weapon

The best example of agents working well was the "new weapon" pipeline, packaged as a **skill**: a written procedure the agent loads automatically when the owner says something like "added X weapon, do all that is needed". The owner's part was to drop two files (a setup script describing the model's parts and effects, and a GLB) and import the GLB into Studio. The agent did the rest.

Stages and measured time on the first weapon built with it:

| # | Stage | Where | Time |
|---|---|---|---|
| 0 | GLB import (human) | Studio, File > Import 3D | 1 min |
| 1 | Parse the setup; generate rig, effects, item, lore, voice and sheath data | Offline Python | 0.1 s |
| 2 | Build the rig and effects in Studio (probe, rig, fx, icon parts) | Studio, short staged calls | about 1 min |
| 3 | Render the icon; upload it | Headless Blender, then `upload_image` from localhost | about 3 min |
| 4 | Config item and lore, voice, sheath rows | Studio | about 1 min |
| 5 | Design the attack kit (the creative part) | Agent, from a worked template | 30 to 45 min |
| 6 | Build kit sources and move icons | Offline Python | 2 s |
| 7 | Bake and install the kit (check, bake per move, rig, install) | Studio, staged | about 5 min |
| 8 | Register the weapon | Studio | about 1 min |
| 9 | Dev test and arm quality (IK bake, QA score at least 80, no criticals) | Offline solver plus short Studio plays | 15 to 25 min |
| 10 | Verify, captures, cleanup | Studio | about 2 min |
| 11 | Notes | Instructions file, change log | about 5 min |

Total about 1 to 1.5 hours per weapon, most of it kit design and the arm bake. The first run (which also built the pipeline) took about 50 minutes of wall clock, 12 of them waiting for another session's play-test.

Design choices that made it work:
- **Stages, not one script.** Each stage is one short Studio call or one offline command, so a failure stops at a known point and can be re-run.
- **Staged writes with a safety copy.** Every edit kept one copy in the agent's WIP folder; the lead deleted it after verification.
- **Shared config protocol.** The central config was shared with another session: re-read, one insert, compile, scan, clone-require.
- **Budgets enforced by tools.** The kit installer reported the kit folder's instance count and flagged anything over 2,500; every script stayed under 200,000 characters.
- **A rarity-sized template.** Kit size and damage multipliers came from a table by rarity, so the agent's creative work stayed inside agreed numbers.
- **A checklist file** the agent ticked through, so nothing was skipped.

What stayed manual (by design or by tool limits): the GLB import (the MCP cannot import local files), **publishing animation ids** (uploads under the owner's account), and the play-test. See [[Pipeline - New Animated Weapon]] for the animation side in depth.

---

## 5. Big passes agents did well

| Pass | Scale | How |
|---|---|---|
| Weapon visual rebuild | Every weapon (well over a hundred) re-modelled in a consistent style, icons re-rendered | Blender batches, meshes uploaded with ids per batch, an install tool swapping models with recorded originals |
| Animation baking | Several hundred player clips and well over a thousand enemy clips turned into compact stubs; originals archived to disk | Bake tool with verify and restore; archive server ([[Baked Clip Stubs and Archiving]]) |
| Instance cleanup | Replicated content about 392k to 107k instances; server storage about 1.96M to 712k, then 420k after archiving | Inventories, dry runs, proof of no references ([[Case Study - Cutting a Million Instances]]) |
| Arm quality | Hundreds of attack clips re-solved with IK and scored | Offline solver, short Studio verification plays ([[Case Study - Fixing Hundreds of Attack Clips]]) |
| UI audits | Every panel given a phone layout; a font standard enforced across scripts and static GUI | Scanners that list violations, then fixers with `Pre*` attributes |
| A second area | A full set of zones built from hand-modelled Blender art, definitions generated from source files | Offline build folder, generator scripts, installers with Status/Install/Verify |

The common shape: **inventory, dry run, apply in chunks, verify, record how to revert.**

---

## 6. What went wrong

Honest failures, because they teach more than successes:

- **Abilities that only worked in Studio.** Kit clips were played through temporary Studio-only animation ids. Everything looked right in Studio; on live servers dozens of weapon kits had motionless weapon parts and dead specials. Agents verified in the one environment where the bug was invisible. The fix was a Lua keyframe player and a grep rule before every release. See [[Case Study - Abilities That Only Worked in Studio]].
- **Untested backlog.** Because agents could not play-test, changes piled up ahead of the human's testing. The notes eventually carried "nothing since this date is play-tested".
- **Proposals left as proposals.** Some balance findings (the basic combo hitting about 2.3 to 2.9 times as often as intended, with a damage correction proposed) correctly waited for the owner's decision. Agents should propose, not silently rebalance.
- **Unverified money settings.** Developer product ids sat at 0 for some kiosks for weeks, flagged as unverified. Agents cannot see the Creator Dashboard; anything there needs a human check. See [[Developer Products and ProcessReceipt]].
- **Generative tools.** Studio's material generation failed almost every job in this project, and AI-generated meshes clashed with the art style; the owner banned generated meshes and foreign assets entirely.
- **Context cost.** Screenshots and huge tree dumps burned context and gave little. The owner explicitly asked agents to skip anything costing tokens without real benefit.
- **Instruction drift.** The instructions file grew to hundreds of lines; a history file was split off, to be read only on demand.

---

## 7. The human's role

The owner did not write code, but the project depended on them:

| Human task | Why agents could not |
|---|---|
| Direction and taste (which floor style, how much decoration) | Requires judgement and ownership |
| Approving pilots before agents scaled a pattern | Screenshots are not reliable art review |
| Importing GLBs | Not exposed to the tools |
| Publishing animation and asset ids | Account ownership and permissions |
| Play-testing | Agents in a shared Studio do not start Play |
| Final decisions (balance, monetisation) | Agents propose; owners decide |
| Creator Dashboard settings | Not reachable by the tools |

A good split: **agents do volume and verification; the human does judgement and anything tied to the account.**

---

## 8. Lessons that generalise

1. **Write the rules down, with numbers.** "Under 1.5 s" works; "be careful" does not.
2. **Keep a map of the place in the instructions.** Agents that know where things are make fewer exploratory calls and fewer edits in the wrong place.
3. **Studio is for I/O and truth; compute elsewhere.**
4. **Every tool gets modes: status, test, install, rollback, verify.** And every write records how to undo it.
5. **Fingerprint before write-back** when anything else might have changed the target.
6. **Package repeated work as a skill or pipeline** with stages, a checklist and timings.
7. **Verify in the environment that matters.** Studio-only success is not success.
8. **Report honestly.** "Not play-tested" is a feature.
9. **Budget everything:** call time, instances per folder, script size, requests per minute, CPU per agent, context per session.
10. **Agents propose, owners decide.**

## See also

- [[Post-Mortem - Building a Melee Action Game]], [[Lessons Learned Index]], [[Working with AI Assistants in Studio]]
- [[Safety Rules for AI Agents in Studio]], [[Multiple Agents in One Studio]], [[Roblox Studio MCP Server]], [[Blender MCP]]
- [[Pipeline - New Animated Weapon]], [[Studio Tooling Architecture]], [[Case Study - Cutting a Million Instances]]
- [[AI Agents and Autonomous Workflows]], [[Pipeline Design Principles]]
- [[Case Study - Building LihFolk V2 with AI Agents]] (the same approach applied to building this vault and its asset pack)

## Connected notes
<!-- auto-links:start -->
[[Asset Pipelines]] · Batch Processing Tools in Studio · [[Agent Review Loops and Guardrails in Practice]] · [[MCP Workflows for Building Worlds]] · Prompting and Verifying AI Output · AI in Roblox Development Overview
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[MCP Workflows for Scripting and Debugging]] · [[Batch Processing Tools in Studio]] · [[Writing Your Own MCP Server]] · [[Case Study - Instance Cleanup and Place Size]] · [[Built-In Studio MCP vs Community MCP Servers - Migration Guide]] · [[Agent Handoff Notes - Project State and Resume Templates]] · [[AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well]] · [[Setting Up MCP Clients]] · [[What Is MCP]]
<!-- related:end -->
