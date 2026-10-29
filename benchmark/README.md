# LihFolk benchmark data

The raw data behind `RESULTS_v2.md`, so you can check the numbers and re-run the aggregation yourself.

## What was run

- **Question sets.** `questions.json` (Set A, 24 tasks, 64 points: recent platform changes, classic gotchas, practical tasks) and `questions_b.json` (Set B, a held-out set of 24 tasks, 66 points, weighted toward everyday Roblox work). Each task has a prompt, an answer-key checklist, points and primary-source URLs. `DESIGN.md` explains how the keys were checked against primary sources and lists the disputed and dropped items.
- **Arms.** Per `DESIGN.md`, every arm used the same Claude model, effort and date, with no web access. The run files don't record the exact model id.
  - `plain`: plugin off.
  - `direct`: plugin on, with vault notes read in the main context.
  - `lookup`: plugin on, with vault lookups delegated to the `lihfolk-lookup` agent (haiku).
- **Runs.** 3 runs per arm on each set, so 9 answer sets per task.
- **Answers.** `runs/v2/<arm>_r<n>_<set>.json` holds `{task id: answer}`. `runs/v2/usage.json` holds the time and tokens for each run.

## How it was graded

1. `v2_aggregate.py blind` shuffles the 9 answers to each task under the labels R1 to R9, using a fixed seed, and writes `runs/v2/blind_<set>.json`. The label-to-arm key goes to `runs/v2/_key_<set>.json`.
2. 3 independent Claude graders scored each blind file against the checklist using `grading.md` (full, partial, missing or confident-wrong per item). Per `grading.md`, graders didn't know which arm wrote which answer. Their scores are in `runs/v2/grade_<set>_g<n>.json`.
3. `v2_aggregate.py report` un-blinds the scores and takes the median of the 3 graders for each answer. It then writes `RESULTS_v2.md` with per-arm means, bootstrap 95% confidence intervals over tasks, category totals and grader agreement.

`RESULTS.md` is the earlier v1 result (one run per arm). Only its summary is included here.

`RESULTS_v2.5.md` summarises the held-out sets C-F (`questions_c.json` ... `questions_f.json`, runs in `runs/c1` ... `runs/f1`, reports `RESULTS_set<X>_scores.md`; regenerate with `py -I benchmark/v2_aggregate.py report c1 RESULTS_setC_scores.md` and so on) and the re-graded sets A and B (`runs/v2.2`, `runs/v2.3`).

`RESULTS_v2.1.md` re-checks the lookup arm after the v2.1 token-cost pass (data in `runs/v2.1/`, graded together with the original v2 lookup answers as anchors). `py -I benchmark/v2_aggregate.py report v2.1 RESULTS_v2.1_scores.md` regenerates its score table.

## Re-run the aggregation

```
py -I benchmark/v2_aggregate.py report     # rewrites benchmark/RESULTS_v2.md from the grade files
py -I benchmark/v2_aggregate.py blind      # rewrites the blind files and keys (seeded, gives the same content)
```

You need Python 3.8 or later and only the standard library. The script finds its files relative to itself, so it runs from any folder. Running `report` from this folder reproduces the published `RESULTS_v2.md` exactly. Set A: direct 60.4, lookup 58.2, plain 43.8 out of 64. Set B: direct 62.6, lookup 61.0, plain 60.5 out of 66. Running `blind` in a copy rewrites the same blind files and keys (same content; line endings follow the OS).

## Known caveats

- **Self-written questions.** The plugin's author wrote both sets. Keys were checked against Roblox docs, DevForum and newsroom posts, but the topics overlap areas the vault covers. Set A's post_training slice (8 of 24 tasks) favours any up-to-date knowledge source by design. Set B was written without reference to the vault, so it is the fairer comparison: there, the arms differ by about 2 points out of 66.
- **Claude-graded.** The graders are Claude models, the same family as the system under test, not humans. Grading was blind, with 3 graders and a median score. Graders differed by about 3% of task points on average.
- **Lookup-arm token counts exclude haiku sub-calls.** `usage.json` counts only the main agent's tokens. The `lookup` arm's tokens per run (49k) leave out the tokens spent by the haiku `lihfolk-lookup` sub-agent, so its real cost is higher than shown.
- **Usage is per run, not per set.** `usage.json` gives each run identical numbers under its A and B keys, so the time and token columns can't be split by set.
- **Small sample.** 3 runs per arm and 24 tasks per set. The confidence intervals are wide, especially on Set A.
- **Time-sensitive keys.** Several Set A keys describe 2026 phases that were announced but hadn't happened yet. Check them again before reusing the sets after early 2027.
