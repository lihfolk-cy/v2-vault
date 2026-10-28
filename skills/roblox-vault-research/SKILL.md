---
name: roblox-vault-research
description: 'LihFolk: Consult LihFolk Vault V2 (the LihFolk Roblox knowledge base) automatically, without being asked, whenever you work on anything Roblox (Luau scripts, Studio, remotes, DataStores, UI, physics, animation, VFX, monetization, publishing, performance, anti-exploit, Blender assets for Roblox, game design). Before writing, reviewing or debugging Roblox code or answering a Roblox question, grep the vault index for the APIs and topics involved and apply what the matching notes say. Also use when the user says "check the vault" or "look it up in my notes".'
---
# LihFolk Vault Research

LihFolk Vault V2 is a folder of Markdown notes about every part of making Roblox games. Each note labels its facts as "Roblox docs" (checked October 2026), "measured in the reference project" (one production game), "rule of thumb", or "unverified". Your job is to find the right notes fast, answer from them, and say exactly where the answer came from.

## Inputs

- `VAULT`: LihFolk Vault V2, the knowledge base at `../../knowledge/` relative to this file (plugin root `knowledge/`). Start with `VAULT/INDEX.md` to find notes fast.
- The question or task.

## When to use it (no prompt needed)

Do not wait to be asked. Any Roblox task is a trigger: a new feature, a bug, a review, a design question, an asset import. Do a quick vault check first (under a minute), then work. Skip it only for trivial edits that touch no Roblox behaviour (renaming a variable, fixing a typo).

## Procedure

0. **Skim the index first.** Grep `VAULT/INDEX.md` for the API names, services and topic words in the task (for example `ProcessReceipt`, `UpdateAsync`, `remote`, `hitbox`, `ScreenGui`). Each line is `title | path | tags | first sentence`. Open the two or three best matches only. If nothing matches, fall back to the steps below.

1. **Open the map first.** Read `00 Start Here.md`. It lists the sections and reading paths (new developer, programmer, artist, designer, AI tools, shipping, case studies). Pick the section or path that matches the question before you search.

2. **Use the section hubs.** Several sections have a hub note that lists every note in reading order and gives a symptom or task finder. Read the hub before reading individual notes:
   - `08 Animation/Animation Start Here.md`
   - `22 Anti-Exploit and Security/Anti-Exploit Start Here.md`
   - `23 Debugging Deep Dives/Debugging Start Here.md` (has a symptom quick finder table)
   - `26 Community and Moderation/Community and Moderation Start Here.md`
   - `27 Marketing and Growth/Marketing and Growth Start Here.md`
   - `28 Business and Careers/Business and Careers Start Here.md`
   - `29 Luau Cookbook/Luau Cookbook Start Here.md`
   - For the house cartoon/simulator menu style, use the `lihfolk-ui` skill instead of a hub note.
   - `AI Skills Start Here.md`
   For sections without a hub, list the folder; note titles are descriptive.

3. **Search by title, then by content, then by tag.**
   - Titles are unique across the vault and say what the note covers. List file names in the relevant folder and match words from the question.
   - Grep content for the exact API name (`ProcessReceipt`, `UpdateAsync`, `UnreliableRemoteEvent`, `ScreenInsets`). API names are more reliable search terms than prose.
   - Grep front matter tags: every note starts with `tags: [...]`. Common tags include `luau`, `performance`, `ui`, `security`, `networking`, `datastore`, `remotes`, `monetization`, `debugging`, `testing`.
   - Skip the plugin's `skills/` folder when grepping prose: it holds agent instructions, not explanations.

4. **Read the right parts.** Notes run 2,000 to 5,000 words. Read the headings first (`## ` lines), then the sections that answer the question. Almost every note ends with "Common mistakes" and "Checklist" sections: these are the fastest way to get the rules. Follow `[[links]]` in "See also" only when the first note does not answer the question.

5. **Rank sources.** When notes disagree or the question is about platform facts (limits, prices, policies, API members):
   1. Facts labelled "Roblox docs" win for how the engine and platform work.
   2. "Measured in the reference project" wins for what happened in practice; give both when they disagree.
   3. "Rule of thumb" is advice, not a fact. Say so when you pass it on.
   4. "Unverified" claims must be repeated as unverified, never upgraded to fact.
   Anything marked "as of October 2026" can be stale. Say so for prices, payouts, policies and beta features.

6. **Check Open Questions.** Before giving a number or a platform rule, grep `Open Questions - Whole Vault.md` (and `08 Animation/07 Gotchas/Open Questions.md` for animation) for the topic. If it appears there, tell the user the claim is disputed and give both sides. Examples already listed: DataStore experience limits (300 vs 250 base), the old "one write per key every 6 seconds" rule versus per-key throughput, NaN checks with `math.isfinite` versus `x ~= x`, text floor 9 versus 12 px, texture size 1024 versus 4096.

7. **Use the Glossary** (`Glossary.md`) when a term is unclear, instead of inventing a definition.

8. **Answer, then cite.** Give the answer in plain words with the concrete numbers from the notes. Then list every note you used by its vault path. If code is involved, adapt the note's code rather than writing from memory, and keep its comments about why.

## Hard rules

- Never present your own memory as what the vault says. If the vault does not cover something, say "the vault does not cover this" and label anything you add as your own general knowledge.
- Never invent API members, limits, prices or policies. If neither the vault nor official docs confirm it, say it is unverified.
- Do not edit vault notes unless the user asks you to. Research is read-only.
- Quote at most a few lines; summarise the rest.
- Do not read the asset folders as if they were notes.

## Report format

End every research answer with:

```
Notes used:
- <vault path 1>
- <vault path 2>
Open questions touched: <none, or the topic and both claims>
Labels: <which facts were Roblox docs / measured / rule of thumb / unverified>
```

## Checks before finishing

- [ ] Started from `00 Start Here.md` or a section hub.
- [ ] Every number in the answer appears in a note you read, with its label.
- [ ] Open Questions checked for the topic.
- [ ] Time-sensitive facts flagged as "as of October 2026".
- [ ] Notes used are listed by path.

## Read these vault notes

- `00 Start Here.md`
- `Glossary.md`
- `Open Questions - Whole Vault.md`
- `13 Production and Case Studies/Documentation and Knowledge Bases.md`
- `13 Production and Case Studies/Lessons Learned Index.md`
- `15 AI Tools/Prompting and Verifying AI Output.md`
- `16 MCP and Agents/Safety Rules for AI Agents in Studio.md`
