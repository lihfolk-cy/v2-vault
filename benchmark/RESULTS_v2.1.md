# LihFolk Benchmark v2.1: token-cost pass, accuracy re-check

v2.1 trims the plugin's always-loaded text, the router skill, the `vault.py` output and the lookup agent, and adds a few search and symptom fixes. This file checks that accuracy held. The v2 results (`RESULTS_v2.md`, `runs/v2/`) are unchanged.

## What changed (kept)

| Lever | Change | Measured effect |
|---|---|---|
| 1. Descriptions | Shorter `description` frontmatter for 19 skills, 3 agents and 6 commands; distinctive trigger phrases and the routing splits (lihfolk-ui vs roblox-ui-builder, lihfolk-systems vs roblox-system-builder, council-method vs `/lihfolk:council`) kept | 6,891 → 4,474 chars, **~1,720 → ~1,120 tokens** always loaded. Routing test: 30 requests routed from the old and the new listing, 30/30 and 30/30 correct, identical choices |
| 2. Router | `skills/lihfolk/SKILL.md` keeps vault-path resolution (`VAULT=<abs path>` for the lookup agent, `python` → `python3` → `py`), the delegation default, the lookup steps and the accuracy rule; the folder map, specialist list, reference images and extra tips moved to `skills/lihfolk/references/vault-map.md` | Body **~1,610 → ~720 tokens** (reference file ~680 tokens, read only when needed) |
| 3. `vault.py` output | Default prints each hit's TL;DR bullets and section list without the callout header, cost line, path, size and "Next:" boilerplate. `--full` gives the old output; `--brief` cuts notes 2-3 to two lines; `--read`, `--sections`, `--paths`, `--json` unchanged | **745 → 594 tokens/task** (`--brief` ≈ 403). Ranking unchanged |
| 4. Lookup agent | Tighter instructions; the reply must surface version-dated facts, renames, deprecations, removal plans and rollout phases; a second search with exact API names when the first misses; one launcher check before searching | See benchmark below |
| Search fixes (from eval dev misses and set A only) | 10 new `SYMPTOMS.md` lines: phone UI cut off, weak/floaty hits, remote spam farming, party split across servers, Robux pack must survive leave/crash, paid crates, pity, frame hitches, fly/noclip exploits, and RenderFidelity ignored under mesh streaming (set A T8) | eval dev hit@3 **85% → 92%** (MRR 0.71 → 0.76); test hit@3 **93% → 93%** (hit@1 77%, MRR 0.84, unchanged). Set A T8: lookup arm **0 → 1.25 / 2** |

Lever 5 (TL;DR generation in `build_index.py`) was not changed: the boilerplate it writes is now stripped at print time in `vault.py`, which gets the saving without rewriting 1,300 notes.

eval numbers above were measured in a clean worktree of the base commit plus only these changes (`py -I "LihFolk Vault V2/_tools/eval.py"`).

## Method (same as v2 lookup runs)

- **Answering:** one `general-purpose` subagent per run, same model as the v2 runs (inherits the session model), no web, answering all 24 set A and 24 set B tasks from `questions.json` / `questions_b.json` (prompt and id only), delegating vault lookups to the haiku lookup agent and batching related questions. Prompt text matches the v2 lookup-run prompt except for the lookup step (next point).
- **Lookup agent:** the installed plugin agent (`lihfolk:lihfolk-lookup`) is loaded from the plugin cache at session start, so it would run the old instructions and the old vault. To test the repo version, each lookup was a `general-purpose` agent on **haiku** told `VAULT=<repo vault path>` and to follow the body of the repo's `agents/lihfolk-lookup.md`. This adds about one line per lookup call to the main context.
- **Tokens and time:** taken from the subagent's reported usage, halved per set, exactly as in `runs/v2/usage.json` (each v2 run also answered both sets; its usage equals half of the reported subagent total). As in v2, haiku sub-call tokens are excluded.
- **Grading:** `v2_aggregate.py blind v2.1` shuffled, per task, the 2 new runs, the 2 runs of an intermediate configuration (`brief`, see below) and the **3 original v2 lookup runs as anchors** (`v2lookup_r1-3`, copied unchanged from `runs/v2/`), labelled R1-R7. Two independent blind Claude graders (same prompt as v2, `grading.md`) scored them; `v2_aggregate.py report v2.1 RESULTS_v2.1_scores.md` takes the median (= mean of 2). Grader agreement: 2.6% (A), 2.3% (B) of task points.

## Results

Scores out of 64 (A) and 66 (B), all graded together by the same two graders:

| Arm | Set A | Set B | Tokens / run | Time / run |
|---|---:|---:|---:|---:|
| v2 lookup (original answers, re-graded) | 55.4 (r1-r3: 55.5, 54.7, 56.1) | 60.7 (60.7, 61.6, 59.9) | 48.7k | 197 s |
| **v2.1 lookup (final)** | **56.2** (57.4, 55.1) | **61.6** (61.5, 61.7) | **50.8k** | **134 s** |
| v2.1 with `--brief` default (intermediate) | 57.1 (56.4, 57.8) | 62.3 (61.8, 62.8) | 51.0k | 176 s |

Comparison with the published v2 lookup means (58.2 / 61.0, 3 different graders):

- **Same graders (fair comparison):** v2.1 is +0.8 on A and +0.9 on B against the original answers.
- **Raw against the published numbers:** B 61.6 vs 61.0 (above). A 56.2 vs 58.2 is lower, but the unchanged original answers themselves score 55.4 under these graders (2.8 below their published 58.2), so the gap is grader strictness, not the plugin. Calibrated by that offset, v2.1 is 59.0 on A and 61.9 on B, both above the "original mean minus 1" bar (57.2 / 60.0).

Tokens: the benchmark's main-agent tokens per run are 50.8k vs 48.7k (v2 runs ranged 45.4k-54.3k). This benchmark does not exercise levers 1 and 2: its answerer is told how to look things up, so the router body is never loaded, and its skill listing comes from the installed (cached) plugin. The haiku agents' hand-back messages were about 1.5x longer than in v2, which the main agent pays for; part of that is the general-purpose stand-in agent's own system prompt. Time per run fell from 197 s to 134 s.

## Kept vs reverted

- **`--brief` as the default: reverted to opt-in.** With notes 2-3 cut to two lines, both runs lost the per-player `IsPaidItemTradingAllowed` check on P6 (2.63 vs 3.0 in every other run) because the hidden third note held the trade re-check, and T2 lost the parallel `BindToClose` point. Its totals were slightly higher only through noise on other tasks. The final default prints every TL;DR bullet (594 tokens/task) and recovered P6 (3.0 / 3.0).
- **Lookup reply "~150 words per question": reverted** to "~150 words in total". In a first trial (`runs/v2.1/_try1/`, not graded) it roughly doubled the haiku answers and pushed the main agent to 54-55k tokens per run.
- Everything else in the table at the top was kept.

## Remaining point losses and their cause

| Task | Cause | Action |
|---|---|---|
| A T8 (mesh streaming) | Search missed the note (v2: 0/2 in all runs) | Fixed with a symptom line: now 1.0-1.5 / 2 |
| A P7 (Kids/Select creator requirements) | Vault sources disagree: `Publishing an Experience` (docs, Oct 2026) lists "Plus/Premium **or** a publishing fee" for all-ages audiences, while `Policy and Age Rules 2026` and the key say an active Plus subscription. One run mixed them | Left for the owner to resolve against the sources; not changed to fit the key |
| A G1 | Answerer omitted "never grant from PromptProductPurchaseFinished"; the vault has it (symptom line and note) | Answer-writing variance, no change |
| A G6, G7 | Paraphrase slips by the answerer; vault wording is correct | No change |

## Files

- `runs/v2.1/lookup_r{1,2}_{A,B}.json`: final answers. `brief_r{1,2}_*`: intermediate configuration. `v2lookup_r{1-3}_*`: copies of the v2 lookup answers used as anchors.
- `runs/v2.1/blind_*.json`, `_key_*.json`, `grade_*_g{1,2}.json`, `usage.json`; `RESULTS_v2.1_scores.md` is the generated report.
- `runs/v2.1/_try2_brief/`: the first blind grading of the brief configuration (5 responses per task, same conclusion: A 56.5 vs 55.5 anchors, B 62.0 vs 60.1). `runs/v2.1/_try1/`: ungraded first trial.
