---
description: Distill the project's quality ledger (.lihfolk/ledger.jsonl) into recipes so first drafts score higher
argument-hint: [type: model|animation|system|ui|world|vfx|all]
---

Use the `quality-score` skill, step 5 (Distill), for type: ${ARGUMENTS:-all}.

Read `.lihfolk/ledger.jsonl`, and for each type with entries:
- compute the average first score, the average fix rounds and the share of entries reaching 9 first try;
- list the defaults common to 9+ results, the criteria that fail on the first try in 30% or more of entries, and the fixes with a positive delta seen at least twice.

Update `.lihfolk/recipes.md` (keep each type under ~60 lines, remove contradicted lessons) and report the trend: is the first-draft score improving?