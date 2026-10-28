---
name: quality-score
description: 'LihFolk: score any generated model, animation, UI, system, world or VFX 0-10 on fixed rubrics (min 8.5, hard gates) and learn from a ledger. Use when generating or finishing one, or asked for a score.'
---

# LihFolk Quality Score

Bar: **8.5 / 10 minimum**. Anything below 8.5 is a draft, and you say so. The score comes from a fixed rubric and evidence, never from how the work feels.

## The loop

```
LEARN  ->  GENERATE  ->  SCORE  ->  FIX (lowest criterion only)  ->  SCORE  ...  ->  LOG
```

### 1. Learn before generating (this is what makes the first draft better)
1. Open `recipes/<type>.md` in this skill: the shipped first-pass defaults and known fixes for that asset type.
2. If the project has a ledger (`.lihfolk/ledger.jsonl` at the project root), grep it for the same `type` and read:
   - the **recipes** section of `.lihfolk/recipes.md` (lessons already distilled from this project);
   - the 3 most recent entries of that type that scored >= 8.5 (what worked);
   - the misses that were fixed repeatedly (what to get right the first time).
3. Write a 3-6 line **pre-flight plan**: which known pitfalls this draft avoids up front and which defaults it starts from. Don't skip this. It's how scores rise over time.

### 2. Score with the rubric
Use `rubrics/<type>.md`. Each rubric has:
- **Hard gates** (automated, pass/fail). Any failure caps the score at **5.0**, whatever else is true.
- **Criteria** with weights, each scored **0, 1 or 2** against written anchors, with evidence (a measured number, a render, a test result).

`score = 10 x sum(weight x points/2) / sum(weight)`, rounded to 0.1. Show the table.

**Bias control:** measured criteria use the numbers. Judged criteria (look, feel, clarity) are scored by a reviewer that isn't the maker: a Quick `council` seat given the evidence and the rubric, not your opinion or your score. The maker never grades its own work alone.

### 3. Fix efficiently
- Fix the **lowest-scoring, highest-weight** criterion first, using a matching fix from the recipes if one exists.
- One targeted change per round. No full regeneration unless a hard gate failure makes the draft unsalvageable.
- **Max 3 fix rounds.** If it's still below 8.5, stop, report the score, the blocking criterion and what's needed (usually a user decision or a missing asset), and log it.

### 4. Log every result (always, pass or fail)
Append one JSON line to `.lihfolk/ledger.jsonl` (create `.lihfolk/` if missing):
```json
{"date":"2026-10-28","type":"model","name":"Crate_Wood_A","first_score":7.8,"final_score":9.2,"rounds":2,
 "gates_failed_first":["A6"],"low_criteria_first":["V4 edge treatment"],
 "fixes":[{"criterion":"V4","fix":"bevel 0.08->0.15, 1 seg, harden normals","delta":0.9}],
 "params":{"style":"soft","bevel":0.15,"tris":44},"notes":"weighted normals fixed shading"}
```
Keep fields short; it's data, not prose.

### 5. Distill (every ~10 entries of a type, or on `/lihfolk:learn`)
Read the ledger for that type and update `.lihfolk/recipes.md`:
- **Defaults that win:** parameter values common to entries scoring >= 8.5.
- **Pre-empt list:** criteria that failed on the first try in 30% or more of entries. These go into every pre-flight plan.
- **Proven fixes:** fixes with a positive delta seen at least twice.
- **Stats:** average first score and average rounds per type, so you can see whether drafts are improving.

Keep `recipes.md` short (under ~60 lines per type) and delete lessons that newer data contradicts.

## Reporting format
`Score 9.2/10 (first draft 7.8, 2 fix rounds). Gates: pass. Lowest: V6 palette 1/2. Logged.`
Never round up to 8.5. Never call a result below 8.5 done.
