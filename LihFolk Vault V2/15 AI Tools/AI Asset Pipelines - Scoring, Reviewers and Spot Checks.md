---
tags: [ai, agents, review, rubric, quality, pipeline, assets, lihfolk, type/guide, area/ai, area/pipelines, level/advanced]
verified: 2026-10-28
---
# AI Asset Pipelines - Scoring, Reviewers and Spot Checks

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Letting a reviewer see the maker's intent, then wondering why scores rise every round.
> - Avoid: Averaging three totals instead of taking the median per criterion.
> - Avoid: Using a judged criterion for something measurable (tiling, symmetry, tri count).
> - Every measurable property is a gate with a numeric threshold
> - Reviewer sees evidence and rubric only, plus calibration anchors
> - Grades re-added by script from evidence lines
>
> Cost: TL;DR ~150 tok · whole note ~1.6k tok. Read more: ## 1. Two layers: gates, then judgement · ## 3. Variance: median of three · ## Common mistakes · ## Checklist
<!-- tldr:end -->

How to make AI-generated assets (models, materials, skies, VFX, animation clips) reach a known quality bar without a human looking at every one. The method was built and tuned on the LihFolk V2 asset pack. Figures marked **Measured** come from its ledgers.

## 1. Two layers: gates, then judgement

**Gates** are measured checks with a pass/fail threshold. A failed gate caps the score at 5.0 no matter how good the asset looks, and the failed item is dropped rather than shipped.

| Asset | Example gates |
|---|---|
| Model | tris under class ceiling, watertight, no n-gons, transforms applied, symmetry error <= 1 % (A15), features centred and seated (A16), no self-intersections (A17), clean planar caps (A18) |
| Material | five separate 1024 maps, wrap-diff <= 1.25, half-tile re-bake difference <= 0.004, normal map OpenGL, no baked light (luminance vs normal correlation < 0.25) |
| Sky | six faces, worst cube-seam ratio <= 1.6, pole pinch ratio <= 2.5, one sun |
| Animation | foot slide < 0.02 studs, IK reachable, no body overlap > 0.05, arm roll <= 25 deg/frame, zero roll reversals in the swing |
| VFX | cleans itself up, bursts use `:Emit()`, stated particle budget, no invented asset ids |

**Judgement** is a weighted 0/1/2 rubric scored by a reviewer agent: `score = 10 x sum(w x points/2) / sum(w)`, pass bar 8.5.

Rule of thumb: anything a script can measure becomes a gate. Reviewers are expensive and noisy, so spend them only on what needs eyes.

## 2. Making the reviewer blind

- Give the reviewer only evidence: renders, contact sheet, gate report, QA JSON and the rubric.
- Never pass the maker's reasoning, earlier scores or "what I fixed". Reviewers anchor on it.
- Shuffle and anonymise when comparing variants.
- State the camera and light setup in the rubric. Workbench light comes from one side, and two reviewers called a symmetric badge "leaning" until the rubric said to judge symmetry from the outline and the A15 number.
- Ask for evidence lines per criterion **and** a grades array, then recompute the total yourself. 2 of 30 model reviews (**Measured**) typed a grades array that did not match their own evidence lines, and 3 of ~90 kit reviews typed weight-1 grades as "1" meaning 1/1.

## 3. Variance: median of three

A single blind reviewer swings about one point and sometimes two (**Measured**: Walk 6.0 / 7.0 / 8.0; Sprint 7.7 / 6.0 / 8.3; potion bottle about 0.4). Single reviewers also over-scored sword clips by about 0.7 against the panel. Therefore:

- **Pass/fail = per-criterion median of 3 independent reviewers**, then the weighted formula. Do not average totals.
- Record any criterion where reviewers spread by 2+ points; it usually means the rubric wording is ambiguous.
- Add **calibration anchors**: one known-good and one known-weak example with their agreed scores, shown with the rubric. Anchors target the drift between "laxer" and "stricter" reviewers seen in early animation rounds, where a Walk clip scored 8.0 in one round and 5.7 from a stricter reviewer later (**Measured**).

## 4. Kits: prove the generator, then gate

Reviewing every variant of a 26-generator kit with three reviewers is not affordable. The pattern that worked:

1. **Prove** each generator: a 3-reviewer panel on representative variants until the median passes 8.5.
2. **Freeze** the generator and its parameter ranges.
3. **Produce on gates only.** Variants that fail a gate, or exceed their class tri target, are filtered out automatically.
4. **Spot check 1 in 20** with a single blind reviewer. A spot score under the bar re-opens the generator for a panel.

## 5. Ledger and recipes

Write one JSON line per attempt: name, round, gates failed, low criteria, the fix, the score delta, reviewer spread. Then distil:

- Fixes with a positive delta on several assets become **first-pass defaults**.
- Fixes with zero or negative delta are recorded as **don't**. Examples: softening horn ridges cost -0.7; flaring a horn collar cost -0.6; claw prongs on a gem setting cost -0.6 (**Measured**).
- Two rounds at zero delta on the same criterion means change the method, not the parameters.

## 6. Budgeting review slots

Each review is a full agent run. The platform allows a limited number of concurrent sub-agents (20 in this setup). When a batch launched makers and reviewers from the same pool, four VFX drafts never got their final review (**Measured**). Reserve review slots first, run makers in the remainder, and queue rather than fan out without limit. See [[Agent Orchestration - Sub-Agents, Hooks and Skill Costs]].

## Common mistakes

- Letting a reviewer see the maker's intent, then wondering why scores rise every round.
- Averaging three totals instead of taking the median per criterion.
- Using a judged criterion for something measurable (tiling, symmetry, tri count).
- Trusting the reviewer's arithmetic.
- Panelling every variant of a frozen generator instead of gating plus spot checks.
- Changing the rubric mid-batch and comparing old and new scores directly (the VFX rubric gained X6 and its weights changed from 11 to 13).

## Checklist

- [ ] Every measurable property is a gate with a numeric threshold
- [ ] Reviewer sees evidence and rubric only, plus calibration anchors
- [ ] Grades re-added by script from evidence lines
- [ ] Median of 3 decides; spreads of 2+ logged
- [ ] Generators proven by panel, then gate-only with 1-in-20 spot checks
- [ ] Review slots reserved before launching makers
- [ ] Ledger line per attempt, including regressions

## See also

- [[Case Study - Building LihFolk V2 with AI Agents]]
- [[Evaluating AI Tools - A Practical Rubric]]
- [[Prompting and Verifying AI Output]]
- [[Procedural Model Kits - Lessons]]

## Connected notes

[[Agent Review Loops and Guardrails in Practice]] · Asset Pipelines · Animation Review Checklist

<!-- related:start -->
## Related
[[Blind Review Scores - Noise, Panels and Shipping the Best Version]] · [[Mesh Gates for Generated Models - Symmetry, Seating and Caps]] · [[Procedural Materials and Skies - Lessons]] · [[Benchmark - Does a Knowledge Vault Make AI Better at Roblox]] · [[Locomotion Readability - Lessons from Blind Panels]] · [[Obsidian Vaults for AI Agents - Structure, Graph and Theming]]
<!-- related:end -->
