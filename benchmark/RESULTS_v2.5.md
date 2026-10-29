# LihFolk Benchmark v2.5: held-out sets C-F

Sets A and B (`RESULTS_v2.md`, `RESULTS_v2.1.md`) were used to find and fix vault gaps during 2.5.0, so they no longer count as unseen. Sets C, D, E and F were written for this release by agents that could not open the vault, the other sets or any results; every answer-key fact was checked against create.roblox.com, official Roblox staff announcements or luau.org on 2026-10-29 (URLs in each task's `sources`).

## Protocol

- **Arms:** `cur` = this release (router `skills/lihfolk/SKILL.md` + lookup agent `agents/lihfolk-lookup.md` + vault), `v240` = the v2.4.0 tag (its own router, lookup agent and vault), `plain` = same model, no plugin. The answering agent read only task ids and prompts, followed its arm's router for when to look things up, and ran lookups as haiku agents following that arm's lookup instructions. No web.
- **Grading:** answers per task shuffled and labelled blind (`v2_aggregate.py blind <run>`), identifying words stripped, then graded by independent Claude graders with `grading.md` and each task's `grader_notes`; `v2_aggregate.py report <run> <file>` takes the median.
- Each set ran after the fixes guided by the previous sets, so C measures the vault before the C fixes, D before the D fixes, and so on.

## Results (accuracy = mean score / points)

| Set | Tasks / points | Runs per arm, graders | cur | v240 | plain | Report |
|---|---|---|---:|---:|---:|---|
| C | 24 / 66 | 2, 3 | **91.3%** | 90.5% | 88.3% | `RESULTS_setC_scores.md`, `runs/c1/` |
| D | 24 / 66 | 2, 3 | **93.7%** | 93.7% | 87.4% | `RESULTS_setD_scores.md`, `runs/d1/` |
| E | 24 / 66 | 2, 3 | **91.9%** | 91.7% | 84.3% | `RESULTS_setE_scores.md`, `runs/e1/` |
| F (quick) | 12 / 34 | 2 cur + 1 plain, 2 | **92.3%** | - | 79.2% | `RESULTS_setF_scores.md`, `runs/f1/` |

- The plugin beats the same model without it on every held-out set: +3.0, +6.3, +7.6 and +13.1 points. The gap is largest on recent-platform questions (set D 14.8/15 vs 11.6/15; set E 13.0/17 vs 10.1/17).
- Against v2.4.0 the release is level on unseen questions (C +0.8, D 0.0, E +0.2) at about 4% fewer main-agent tokens on set E (87k vs 91k per run). Most 2.5.0 fixes target the gaps those sets exposed; set F, run after them, is the first measure of the strengthened vault, and its one large miss came from a wrong vault line (equal `LayoutOrder` ties) that has since been corrected.
- Set F is small: one 3-point task moves the score by about 9 points per run, so read it as a direction, not a precise number.

## Sets A and B after the fixes (tuned, for reference)

`RESULTS_v2.2_scores.md` and `RESULTS_v2.3_scores.md`: graded blind next to the original v2 and v2.1 answers as anchors. Set A 87.6% (v2) -> 96.5%, set B 91.8% (v2) -> 97.1%. Two set A/B key items were corrected against the sources first (P7 Kids/Select creator requirements; B24 adjacent age-group chat), with the reasons in their `grader_notes`.

## Caveats

- The question writers and graders are Claude models, the same family as the system under test.
- Main-agent token counts exclude the haiku lookup agents' own tokens.
- Recent-platform keys describe the state on 2026-10-29; recheck before reusing the sets.
