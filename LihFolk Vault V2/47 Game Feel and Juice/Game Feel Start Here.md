---
cssclasses: [vault-hub]
tags: [game-feel, juice, hub, start-here]
---
# Game Feel Start Here

Game feel is the sense that a game answers you: the jump that happens when you meant it to, the hit that lands with weight, the reward that pays off. This section goes past the overview in [[Game Feel and Juice]] into the numbers, timing and engineering behind it. Each note assumes you know the basics and adds trade-offs, failure modes, worked Luau (strict mode throughout) and a checklist.

Source labels used across the section: **Roblox docs (as of October 2026)**, **measured in the reference project** (one live action game), and **rule of thumb**.

## Read these first

The section builds on four older notes. Read them before the deep dives, because the new notes link back to them instead of repeating them:

- [[Game Feel and Juice]]: the feedback stack, UI juice code, combat and audio juice, when juice becomes noise.
- [[Hit Reactions Stagger and Hit-Stop]]: the reaction ladder and the catch-up hit-stop that stays in sync with clock-timed effects.
- [[Camera Shake and Camera FX]]: envelopes that end at exactly zero, trauma shake, reduced motion, impact frames.
- [[Combat Sound Design and Feedback]]: the outcome matrix, who plays which sound over the network, telegraphs and voice stealing.

## The deep dives

| Note | Read it when |
|---|---|
| [[Hit-Stop and Screen Shake Tuning by Numbers]] | You have hit-stop and shake working and need to choose the values: frame math at 30 to 240 fps, one strength value driving every layer, flurry budgets, FOV-correct shake, the 30 fps aliasing trap |
| [[Squash Stretch and Anticipation in UI and Characters]] | You want elastic UI and props on an engine where `UIScale` is uniform and CFrames carry no scale, or you want anticipation that hides server latency instead of adding input delay |
| [[Feedback Timing - Sound Visual and Haptic Sync]] | Good assets still feel floaty: sound lead-ins, unloaded sounds, frame placement, haptic spin-up, and a one-clock scheduler for all channels |
| [[Reward Moments and Celebrations]] | You are building reveals, level-ups or drops: a tier ladder with time budgets, honest suspense, manual and auto modes, a safe-moment queue, count-ups and social banners |
| [[Input Responsiveness Buffering and Coyote Time]] | Players say the controls eat inputs: the first-frame rule, buffer semantics, cancel windows, coyote time on the default Humanoid, touch and gamepad details, server cooldown grace |
| [[Juice on a Budget - Mobile and Low-End]] | Effects cost frames on phones: cost buckets, a frame-time governor with spawn budgets, bounded pools, substitutes, and the rule that information never degrades |

## Suggested order

1. **Input first.** Responsiveness is the foundation; no effect fixes a jump that does not happen. Start with [[Input Responsiveness Buffering and Coyote Time]].
2. **Then timing.** [[Feedback Timing - Sound Visual and Haptic Sync]] makes every later effect land on the right frame.
3. **Then impact.** [[Hit-Stop and Screen Shake Tuning by Numbers]] and [[Squash Stretch and Anticipation in UI and Characters]].
4. **Then payoff.** [[Reward Moments and Celebrations]].
5. **Last, budget.** [[Juice on a Budget - Mobile and Low-End]] before you ship to phones, and again after every big effects pass.

## Related notes elsewhere in the vault

- Motion and UI: [[UI Motion Language and Timing]], [[UI and GUI Animation]], [[Springs Damping and Smoothing]], [[Notification and Toast Systems]].
- Animation craft: [[Principles of Animation for Games]], [[VFX Timing with Animation]], [[Combat Combo Systems]].
- Movement: [[Custom Character Controllers]], [[Camera Systems]].
- Comfort and access: [[Motion Sensitivity and Camera Comfort]], [[Captions and Audio Accessibility]], [[Accessibility]].
- Performance: [[Mobile and Low-End Optimization]], [[VFX Performance Budgets and Culling]].
- Design and trust: [[Ethical Design and Player Trust]], [[Paid Random Items and Odds Disclosure in Practice]].

## Principles that run through every note

- **Respond on the first frame, decide on the server.**
- **One value drives many layers**, so hit-stop, shake, sound and particles stay proportional.
- **Never early, err late**: sound before its visual is noticed far sooner than sound after it.
- **Information never degrades**; comfort settings and low-end tiers remove only decoration.

## Connected notes
<!-- auto-links:start -->
[[Hit-Stop]] · [[Anticipation]] · [[Input Buffering]] · [[Snippets - Camera Shake and FX]] · [[Frame Budget]] · [[Tween vs Spring]]
<!-- auto-links:end -->
