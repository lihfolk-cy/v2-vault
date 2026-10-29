---
name: lihfolk
description: 'LihFolk Roblox knowledge router (1,300+ notes; "check the vault"). Use before non-trivial Roblox work: Luau, Studio, remotes, data, UI, building, VFX, animation, design, money, performance, security, publishing.'
---

# LihFolk Roblox Knowledge Router

LihFolk Vault V2 (1,300+ notes written for AI agents) lives in the plugin root's `LihFolk Vault V2/` folder.

**Resolve the vault path first.** Claude Code shows this skill's base directory (`.../skills/lihfolk`). The plugin root is two folders above it, so `VAULT` = `<base directory>/../../LihFolk Vault V2`, written out as an absolute path (for example `C:/Users/me/.claude/plugins/.../LihFolk Vault V2`). Use this absolute `VAULT` in every command and Read; the user's project folder does not contain the vault. If the base directory is not shown, use `${CLAUDE_PLUGIN_ROOT}/LihFolk Vault V2`.

**Python launcher:** commands say `python`. If it is not found (or prints "Python was not found"), use `python3`, and on Windows `py`.

## Default: delegate the lookup

For a Roblox question that needs the vault, spawn the `lihfolk-lookup` agent with a prompt whose first line is `VAULT=<absolute vault path>`, then the question (batch related questions in one call). It searches on a small model and returns only facts, gotchas and note titles, keeping the main context clean. Look things up yourself (below) only to quote a long code pattern verbatim or when the agent says "not in vault".
- **Always look up** limits, quotas, defaults, prices, policy, dates and anything changed or renamed in 2025-2026: training data lags there, and that is where answers go wrong. Batch them, at most 6 questions per lookup call, and run several calls in parallel when there are more (bigger batches squeeze each answer and drop facts).
- When the lookup's dated facts or API names differ from what you remember, use the lookup's; put its exact numbers, names and dates into the answer.
- Skip lookups for plain Luau logic, math and long-stable APIs you know cold. One lookup per topic per session; reuse the answer.
- `quality-score` and `council-method` are for work the user asked to have scored or reviewed, not ordinary coding.

## Looking it up yourself

Scale to the task: trivial = none; normal (feature, bug, review) = one search; big or unfamiliar (new system, security, money, data, publishing) = up to 3-4 notes, one section each.

1. `python "<VAULT>/_tools/vault.py" "<task or bug in plain words>"` (quote the path). It prints the 3 best notes' TL;DR bullets and section lists, plus matching `SYMPTOMS.md` lines (symptom | cause | fix | note).
2. One section, not the file: `python "<VAULT>/_tools/vault.py" --read "<title>" "<heading words>"` (`--sections "<title>"` lists headings).
3. Without Python: grep `<VAULT>/INDEX_SLIM.md` (`title | path | tags`) for API names and `<VAULT>/SYMPTOMS.md` for the symptom.
4. Apply and cite note titles. Trust labels: `Roblox docs` and `Measured` beat `Rule of thumb`; check `Unverified` before relying on it. If nothing matches, say so and use the official Roblox docs. Never invent APIs or asset ids.

**Accuracy over savings:** a TL;DR is a pointer. For player data, purchases and receipts, paid random items and policy, remotes and security, or anything shipping to live players, read the note's `Common mistakes` and `Checklist` sections and the section holding the exact numbers or API rules you use. Never cite a number seen only in a TL;DR.

For building a map or level use `lihfolk-worldbuilding`; for tutorials and onboarding use `lihfolk-tutorial`; for Figma designs use `lihfolk-figma`. Folder map by topic, the asset pack path, the specialist skill list and reference images: `<base directory>/references/vault-map.md`.
