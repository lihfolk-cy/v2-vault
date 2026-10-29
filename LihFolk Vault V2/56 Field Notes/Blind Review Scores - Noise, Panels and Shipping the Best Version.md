---
tags: [field-notes, review, scoring, rubric, panel, median, reviewer-noise, ai-agents, versioning, backups, animation, vfx, lihfolk, type/guide, area/ai, level/intermediate]
verified: 2026-10-29
---
# Blind Review Scores - Noise, Panels and Shipping the Best Version

<!-- tldr:start -->
> [!tldr] TL;DR
> - Clip "passed" in iteration, failed at review: Single-reviewer scores run about 1 point high -> Decide with a 3-reviewer panel median per criterion
> - A better earlier version is lost: Rebuilt in place without a backup -> Back up every scored version before rebuilding
> - Shipped a regression: Shipped the latest build, not the best score -> Ship the best panel-scored version
> - Every scored version backed up with its evidence
> - Ship decision made on a 3-reviewer panel median per criterion, bar 8.5
> - Shipped version is the best panel score; the ledger says which and why
>
> Cost: TL;DR ~190 tok · whole note ~1.1k tok. Read more: ## What went wrong · ## The rule · ## Common mistakes · ## Checklist
<!-- tldr:end -->

When AI reviewers score assets (animation clips, VFX, models) against a rubric, the score is a noisy measurement, not a fact. Over two days of LihFolk V2 animation and VFX work the noise was large enough to change ship decisions, and two habits saved the work: always keep every scored version, and ship the best **panel** score rather than the latest attempt. The general scoring method is in [[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]]; this note is the production trap. **Measured** marks numbers from the LihFolk ledgers.

## What went wrong

- **Single reviewers run high and noisy.** A single blind reviewer scored about 1 point above the 3-reviewer panel on average (SwordLight1 8.7 single -> 7.7 panel; Idle 9.0 and 9.0 singles -> 8.3 panels; Jump singles 7.0 / 7.3 / 9.3 for the same clip). An iteration loop driven by single scores "improved" clips that the panel then failed.
- **Panels disagree too.** Two independent 3-reviewer panels on the same or nearly the same clip differed by about 1 point (TwistBackflip 6.3 then 5.7; Jump panels 8.3 and 7.3 a version apart).
- **The newest version is not always the best.** Jump v5 (bent elbows in the air) scored 7.3 against v4's 8.3; SwordDashSlash's redesign scored 5.7 against the earlier 7.7. Without backups the better version would have been lost.

## The rule

1. **Iterate with single reviewers if you must, but decide with a panel**: 3 blind reviewers, median **per criterion**, bar 8.5. One-shot requests from the owner are fine, but anything given a score still goes through the panel.
2. **Back up every scored version** (sheet, preview, clip or module, JSON) before rebuilding, keyed by version, so any earlier result can be restored and compared.
3. **Ship the best panel-scored version**, not the last one built. Record in the ledger which version shipped and why.
4. **The catalogue shows the latest panel score of the shipped version.** Do not quote a single-reviewer score, or a panel score of a version that was not shipped.
5. Treat a difference under about 1 point between panels as noise. Only a change that moves several criteria, or repeats across panels, is a real improvement.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Clip "passed" in iteration, failed at review | Single-reviewer scores run about 1 point high | Decide with a 3-reviewer panel median per criterion |
| A better earlier version is lost | Rebuilt in place without a backup | Back up every scored version before rebuilding |
| Shipped a regression | Shipped the latest build, not the best score | Ship the best panel-scored version |
| Catalogue scores do not match the game | Quoted a single score or an unshipped version | Latest panel score of the shipped version |
| Chasing tenths | Treating panel-to-panel noise as signal | Ignore differences under about 1 point unless they repeat |

## Checklist

- [ ] Every scored version backed up with its evidence
- [ ] Ship decision made on a 3-reviewer panel median per criterion, bar 8.5
- [ ] Shipped version is the best panel score; the ledger says which and why
- [ ] Catalogue uses the latest panel score of the shipped version
- [ ] Panel differences under about 1 point treated as noise

## See also

- [[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]]
- [[Locomotion Clip Lessons - Jump, Sprint, Idle]]
- [[Arm Twist and Grip Roll - Lessons from Baked Sword Clips]]
- [[VFX Readability and Value - Lessons from Blind Reviews]]
- [[Running Many AI Agents on One Roblox Place]]
- [[House Construction Method - Modular Kit Workflow]] (the same session's building and modelling lessons)

<!-- related:start -->
## Related
[[Case Study - Building LihFolk V2 with AI Agents]] · [[Locomotion Readability - Lessons from Blind Panels]] · [[VFX Previews in Blender for Roblox - Colour and Framing]] · [[Spin and Whole-Body Rotation Moves]] · [[Procedural Materials and Skies - Lessons]] · [[Benchmark - Does a Knowledge Vault Make AI Better at Roblox]]
<!-- related:end -->
