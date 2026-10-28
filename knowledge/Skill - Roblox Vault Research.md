---
tags: [ai, agents, ai-skill, research, workflow]
---
# Skill - Roblox Vault Research

**Skill file:** [skills/roblox-vault-research/SKILL.md](../skills/roblox-vault-research/SKILL.md) (folder name `roblox-vault-research`)

## What it does

This skill teaches an AI coding agent to answer Roblox questions from this vault instead of from memory. It is the base skill: the other nine all lean on the same habits.

The agent is told to:

1. Start at [[00 Start Here]] and pick the matching section or reading path.
2. Read the section hub before individual notes: [[Anti-Exploit Start Here]], [[Debugging Start Here]], [[Animation Start Here]], [[Luau Cookbook Start Here]], [[LihFolk UI Design System]] and the others.
3. Search by note title first (titles are unique and descriptive), then grep for exact API names such as `ProcessReceipt` or `UpdateAsync`, then by front matter tags.
4. Read headings, then the relevant sections, with the "Common mistakes" and "Checklist" sections as the fastest route to the rules.
5. Rank sources the way the vault labels them: Roblox docs for platform facts, measured numbers from the reference project for practice, rules of thumb as advice, and unverified claims repeated as unverified.
6. Check [[Open Questions - Whole Vault]] before quoting any limit or rule, and give both sides when it is disputed.
7. End with a list of the notes it used, by path.

## When to use it

- Any "how do I" or "what is the limit" question about Roblox development, when the vault is available.
- Before another skill starts work, to load the right notes.
- When you want an answer you can check: the citation list tells you exactly which notes to read yourself.

Trigger phrases in its description include "check the vault", "what does the vault say" and "find the note on".

## What it will not do

It does not edit notes, it does not upgrade a rule of thumb into a fact, and it says plainly when the vault does not cover something. It also skips the asset folders (`20 CC0 Library`, `30 Models and Environment Kits`) and the skill files themselves when searching prose.

## Why it matters

AI agents are confident even when wrong. The habit of citing notes and flagging disputed facts is what makes their answers safe to act on. See [[Prompting and Verifying AI Output]] and [[Safety Rules for AI Agents in Studio]] for the wider rules, and [[Documentation and Knowledge Bases]] for why a vault like this pays off for a team.

## Related

- [[AI Skills Start Here]]
- [[Glossary]]
- [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[Third-Party Skill - Obsidian Skills]] · [[Skill - Roblox DataStore Safety]] · [[Skill - Roblox Performance Audit]] · [[Skill - Roblox Debugging]] · [[CHANGELOG]] · [[Resource Library Start Here]]
<!-- auto-links:end -->
