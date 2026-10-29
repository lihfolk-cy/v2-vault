---
tags: [ai, agents, ai-skill, tokens, third-party, type/guide, area/ai, level/intermediate]
---
# Third-Party Skill - Caveman Token Saver

**Source:** [github.com/JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) by Julius Brussee, Apache-2.0 licence. It is not part of this vault or plugin and nothing from it is included here. Install it from the source, and read its README for current commands, install steps and figures. This note is a short original summary written in October 2026 (**unverified**: we have not measured it ourselves).

## What it is

A third-party add-on for AI coding agents that cuts token use in two ways: the agent answers more tersely, and noisy input (logs, structured data, command output) is compressed before the model reads it. Code, paths and error text are meant to pass through unchanged.

## When it might help on a Roblox project

- **Good fits:** long agent sessions over a large codebase, and MCP-heavy work where tool output floods the context (see [[Roblox Studio MCP Server]] and [[MCP Workflows for Scripting and Debugging]]).
- **Keep it off** when you want explanations: learning Luau, writing player-facing text, design discussions, or a write-up for someone else.
- **Check any compressed instruction file by hand.** Hard rules (never touch live DataStores, Edit mode only) must survive word for word; see [[Safety Rules for AI Agents in Studio]].
- **It changes how the agent talks, not what it does.** The vault skills, such as [[Skill - Roblox Secure Remotes]], still apply.
- **Measure, do not assume.** Compare token use with and without it on your own work before keeping it on ([[Evaluating AI Tools - A Practical Rubric]], [[Token Cost Benchmarks]]).
- **Privacy:** read the project's README on telemetry and any cloud features before using it on private or unreleased game code.

## Related

- [[AI Skills Start Here]]
- [[AI Code Assistants for Luau]]
- [[Prompting and Verifying AI Output]]
- [[Agent Review Loops and Guardrails in Practice]]
- [[Third-Party Skill - Obsidian Skills]]
