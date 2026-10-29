---
cssclasses: [vault-hub]
tags: [index, start, ai, agents, ai-skill, type/hub, area/ai, level/beginner]
---
# AI Skills Start Here

This section packages the vault's rules as **agent skills**: ten instruction files that an AI coding agent loads when a task matches, so it builds and reviews Roblox code the way these notes say to, instead of from half-remembered tutorials. Each skill is distilled from the vault's own notes and tells the agent which notes to read, so the vault stays the source of truth and the skill stays short.

## What an agent skill is

A skill is a folder containing a file named `SKILL.md`. The file starts with a small header:

```
---
name: roblox-secure-remotes
description: What the skill does and when to use it, with trigger phrases.
---
```

followed by plain instructions: numbered steps, hard rules, checks before finishing, and a list of vault notes to read. An agent that supports skills reads only the `name` and `description` of every installed skill up front. When your request matches a description ("review my remotes", "players lost their data", "make a shop menu"), it loads the full file and follows it. Skills cost almost nothing until they are needed, which is why ten narrow skills beat one giant instruction file.

The skill files live in the plugin's `skills/<skill-name>/SKILL.md`. They are excluded from the vault's search and graph (they are instructions for agents, and every one is named `SKILL`), so each has a readable companion note in this folder, named `Skill - <Title>`, that explains it for people and links the file.

## How to install them

**Claude Code.** Copy a skill folder (the whole `<skill-name>` folder, not just the file) to one of:

- `~/.claude/skills/<skill-name>/` to make it available in every project, or
- `.claude/skills/<skill-name>/` inside a project to share it with everyone who works on that repository.

Start a new session and the skill is listed. You can also ask for one by name.

**Other agents and editors.** Most AI coding tools have a rules, instructions or skills folder. Put the `SKILL.md` content there (renamed if the tool expects a different file name), or paste the relevant skill into the tool's project instructions. The header is harmless where it is not understood; the steps are plain English.

Install only the skills you use. [[Skill - Roblox Vault Research]] is worth installing with any of the others, because they all rely on its search habits.

## How each skill uses the vault

1. Give the agent the vault path when you ask (for example "the vault is at <path>, review my remotes"), or put it in your project's agent instructions file once.
2. The skill's last section, "Read these vault notes", lists notes by their path inside the vault, such as `22 Anti-Exploit and Security/Threat Modeling a Roblox Game.md`. The agent reads those before acting.
3. The agent answers with the vault's labels intact: Roblox docs, measured in the reference project, rule of thumb, or unverified. Facts marked "as of October 2026" (prices, policies, limits) should be rechecked against official docs before shipping.
4. When a fact is disputed, the skill points the agent at [[Open Questions - Whole Vault]] instead of picking a side silently.

The skills never edit vault notes. They read the vault and act on your game.

## The skills

| Skill (folder) | Use it for | Human note |
|---|---|---|
| `lihfolk` (router; replaces `roblox-vault-research`) | Answering any Roblox question from the vault with citations, at the lowest token cost | [[Skill - Roblox Vault Research]] |
| `roblox-secure-remotes` | Writing and reviewing RemoteEvents, UnreliableRemoteEvents and RemoteFunctions | [[Skill - Roblox Secure Remotes]] |
| `roblox-anti-exploit-review` | Defensive audit: threat model, detection, fair enforcement | [[Skill - Roblox Anti-Exploit Review]] |
| `roblox-datastore-safety` | Session locking, retries, BindToClose, migrations, receipts | [[Skill - Roblox DataStore Safety]] |
| `roblox-monetization-compliance` | Products, passes, ProcessReceipt, prices, odds disclosure, PolicyService | [[Skill - Roblox Monetization Compliance]] |
| `roblox-performance-audit` | MicroProfiler, memory leaks, bandwidth, instance counts, mobile | [[Skill - Roblox Performance Audit]] |
| `roblox-debugging` | Reproduce, isolate, bisect; errors, desync, races, live servers | [[Skill - Roblox Debugging]] |
| `roblox-ui-builder` | Responsive UI, safe areas, motion, LihFolk UI, accessibility | [[Skill - Roblox UI Builder]] |
| `roblox-asset-import` | Models, rigs, kits, scale, triangle budgets, collision, PBR textures | [[Skill - Roblox Asset Import]] |
| `roblox-system-builder` | Building a full feature the way the Worked Builds do | [[Skill - Roblox System Builder]] |

## Which skill for which job

- **Starting a feature:** `roblox-system-builder`, which calls the remotes, data, monetization and UI skills as it goes.
- **Before a release:** `roblox-anti-exploit-review`, `roblox-monetization-compliance` and `roblox-performance-audit`, then the [[QA Checklists Before Release]].
- **Something is broken:** `roblox-debugging`; for lag or memory growth, `roblox-performance-audit`.
- **Bringing in art:** `roblox-asset-import`.

## Using skills safely

Skills make an agent more consistent, not infallible. Keep the habits from [[Safety Rules for AI Agents in Studio]]: work in Edit mode, snapshot before bulk changes, never let an agent touch live data stores from Studio, and review what it changed. Ask the agent to end each task with the notes it used and what it could not verify. For the wider picture, see [[AI in Roblox Development Overview]], [[AI Code Assistants for Luau]], [[Prompting and Verifying AI Output]], [[Agent Review Loops and Guardrails in Practice]] and [[Working with AI Assistants in Studio]].

The LihFolk UI design system in section 21 has its own skill, `lihfolk-ui`, with exact sizes, colours, components and motion. `roblox-ui-builder` defers to it for those values and adds the vault's layout, motion and accessibility rules on top.

## Using skills from other sources

Skills from elsewhere can sit beside these. Before installing one, read its instructions in full, check what it is allowed to run, and test it on a copy of your place or vault. Keep the vault's rules in charge: a skill that changes how an agent writes or talks does not change Edit-mode safety, server authority or DataStore discipline. Measure any token-saving claim on your own work ([[Token Cost Benchmarks]]).

## Writing your own

Copy the shape of any skill here: a `description` that names the task and the phrases people actually type, numbered steps in the imperative, hard rules, a "checks before finishing" list, and the vault notes to read. Keep the file between roughly 600 and 1,500 words; push depth into notes and point at them. Label every number with its source, exactly as the notes do.

## Connected notes
<!-- auto-links:start -->
[[LihFolk UI Design System]] · Studio Assistant and AI Tools · [[LICENSE]] · Case Study - Building a Game with AI Agents · Setting Up MCP Clients
<!-- auto-links:end -->
