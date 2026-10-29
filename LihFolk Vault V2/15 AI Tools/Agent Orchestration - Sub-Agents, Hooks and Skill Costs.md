---
tags: [ai, agents, sub-agents, hooks, skills, claude-code, git, tokens, lihfolk, type/guide, area/ai, level/advanced]
verified: 2026-10-28
---
# Agent Orchestration - Sub-Agents, Hooks and Skill Costs

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Spawning a sub-agent for a lookup that one search call would answer.
> - Avoid: Fanning out makers and reviewers from one unbudgeted pool, then shipping unreviewed items.
> - Avoid: Hooks that block on style warnings.
> - Lookup sub-agents get one question, a place to look, and an answer shape
> - Concurrency budget written down; review slots reserved
> - Skipped reviews logged as skipped
>
> Cost: TL;DR ~140 tok · whole note ~1.6k tok. Read more: ## 2. Concurrency limits stall review pipelines · ## 3. Hooks should block only on errors · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Practical rules for running many AI agents on one Roblox project: when to spawn sub-agents, how to keep concurrency from stalling a pipeline, what hooks should and should not block, why skill descriptions cost tokens in every session, and how to merge work from parallel copies. Learned while building LihFolk V2 with Claude Code; **Measured** marks numbers from that build.

## 1. The lookup sub-agent pattern

Reading documentation in the main conversation fills its context with file dumps. A **lookup sub-agent** does the reading and returns only the conclusion.

- Give it one narrow question, the place to look (vault search command, index file, section names) and the shape of the answer you want ("the rule, the API name, one code line, the note path").
- It returns about a paragraph. The main agent keeps working with a clean context.
- Use it for questions where the answer lives somewhere you know but haven't read. For a lookup you could do in one search call, search inline instead; a sub-agent's start-up cost is larger than one search.
- Don't hand it your hypothesis to confirm. Ask the question neutrally or it tends to agree with you.

## 2. Concurrency limits stall review pipelines

The environment caps concurrent sub-agents (20 in this setup). A pipeline that spawns a maker per asset and a reviewer per maker will hit the cap without any error message: new spawns wait or fail, and late stages starve.

**Measured:** in the VFX batch four drafts (overhead cleave, dash trail, hit spark, charge-up) were never blind-reviewed, and a thrust effect missed its final review, because makers held every slot when the reviews were due.

Budget slots like any other resource:

- Count the agents per stage: makers, 3 reviewers per panel item, lookups.
- Reserve review slots first. Makers get the remainder.
- Run in waves (for example 5 makers, then 15 reviewers) instead of fanning out everything at once.
- Write a ledger line for every item that was skipped, so "not reviewed" is never mistaken for "passed".

## 3. Hooks should block only on errors

Hooks run deterministic checks before or after tool calls (for example a Luau checker after every file write).

- **Block (non-zero exit) only on errors** that are definitely wrong: syntax errors, a forbidden API, a secret in code, a missing `pcall` around a DataStore call.
- **Report warnings without blocking.** Style issues and heuristics that are sometimes right should print and let the agent continue. A hook that blocks on warnings trains the agent to route around the hook, or stalls it on false positives.
- Keep hooks fast. They run on every matching tool call.
- Make the message say what to change. "Blocked" alone sends the agent guessing.

See [[Automated Luau Checks - LihFolk Hook and Audit]] and [[Agent Review Loops and Guardrails in Practice]].

## 4. Skill descriptions are an always-on cost

Claude Code loads every installed skill's `description` into context at the start of every session, whether the skill is used or not. The body loads only when the skill runs.

- **Measured:** trimming 16 skill descriptions to 15 shorter ones cut the fixed load from about 1,750 to about 740 tokens per session (-58 %), partly by merging a duplicate lookup skill into the router.
- Write descriptions as triggers ("Use when ..."), not marketing. One or two sentences.
- Merge skills that fire on the same requests. Two overlapping skills cost twice and confuse selection.
- Put detail in the skill body and its reference files, which are only read on demand.

## 5. Merging parallel working copies

Running several agents on separate copies of the repo (or worktrees) avoids edit collisions, but the merge needs care:

- Give each agent a disjoint set of paths (a section, a tool folder). Most conflicts disappear.
- Tell agents to create **new** files and check names first when several write into one folder.
- Regenerate derived files (index, router, TL;DRs) **once after merging**, not in every copy. Generated files conflict on every line.
- Merge one copy at a time and run the checks (links, API names, snippet compilation) between merges.
- Never resolve a conflict by taking one side of a generated file. Take either side, then regenerate.

## 6. Shared-folder etiquette for agents

- State in the brief who else is writing and where.
- Ban commits and generator runs for workers; the coordinator does them once.
- Ask workers for a short report (files written, open issues), not a summary of what they read.

## Common mistakes

- Spawning a sub-agent for a lookup that one search call would answer.
- Fanning out makers and reviewers from one unbudgeted pool, then shipping unreviewed items.
- Hooks that block on style warnings.
- Long, overlapping skill descriptions that cost tokens in every session.
- Running the index generator in every parallel copy and fighting the conflicts.
- Asking a sub-agent to "confirm" a theory instead of asking the question.

## Checklist

- [ ] Lookup sub-agents get one question, a place to look, and an answer shape
- [ ] Concurrency budget written down; review slots reserved
- [ ] Skipped reviews logged as skipped
- [ ] Hooks block only on errors; warnings print
- [ ] Skill descriptions are short triggers; duplicates merged
- [ ] Parallel writers have disjoint paths; generated files rebuilt once after merge

## See also

- [[AI Agents and Autonomous Workflows]]
- [[Token Cost Benchmarks]]
- [[Running Many AI Agents on One Roblox Place]]
- [[Windows Tooling Pitfalls for Agent Pipelines]]

## Connected notes

[[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]] · [[Case Study - Building LihFolk V2 with AI Agents]] · Git and Source Control for Roblox

<!-- related:start -->
## Related
[[Obsidian Vaults for AI Agents - Structure, Graph and Theming]] · [[AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well]] · [[Benchmark - Does a Knowledge Vault Make AI Better at Roblox]] · [[Local vs Cloud AI - Keeping Unreleased Game Code Private]] · [[AI Code Assistants for Luau]] · [[Roblox Studio Assistant]] · [[Prompting and Verifying AI Output]] · [[Evaluating AI Tools - A Practical Rubric]] · [[Roblox Built-In AI Tools Timeline 2023-2026]]
<!-- related:end -->
