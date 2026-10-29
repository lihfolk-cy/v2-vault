---
tags: [ui, ux, onboarding, ftue, tutorial, retention, first-session, d1-retention, guidance, type/guide, area/ui, area/design, level/intermediate, api/AnalyticsService, api/GuiService, api/UserInputService]
verified: 2026-10-29
---
# Onboarding and FTUE - Tutorials That Keep Players

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: "Welcome to..." text wall at spawn -> One short objective and a pointer
> - Avoid: Teaching every system before the first reward -> Teach the core loop; the rest arrives as contextual tips
> - Avoid: A tutorial step that can be failed by the economy -> Top the player up to exactly the price
> - First meaningful action within about 10 to 20 s of control; first reward inside 60 s.
> - One verb, one goal, one pointer per step; objective text 8 words or fewer.
> - The whole core loop completed at least once in the first session.
>
> Cost: TL;DR ~170 tok · whole note ~2.3k tok. Read more: ## 2. The principles, ranked · ## 3. Numbers to design against · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A tutorial is not there to explain the game. Its job is to get a new player to **enjoy the core loop once, completely, and want the next goal**, and to do it before they think about leaving. This note is the compact rulebook: the principles that most change first-session and Day 1 retention, the numbers to aim for with their trust labels, and how the rest of the vault fills in each part. The long-form timeline, a five-version case study and a server state machine are in [[First-Time User Experience and Onboarding]]. Building the steps is in [[Tutorial Step Design Patterns - Teach by Doing]]; genre shapes in [[Onboarding by Genre - The First Five Minutes]]; measuring in [[Measuring Onboarding - Funnels, Drop-off and A-B Tests]]; devices and accessibility in [[Onboarding Accessibility and Cross-Device Prompts]].

To build one, use the plugin skill **lihfolk-tutorial** (`skills/lihfolk-tutorial/`): a data-driven step module, a 5-step simulator example, a checklist and a scoring rubric.

Trust labels: **Roblox docs** (Creator Hub onboarding, retention and analytics pages, as of October 2026), **Reference project** (one production game, measured, see the FTUE note), **Rule of thumb** (starting points to tune with your own funnel), **Unverified**.

---

## 1. Why it matters so much on Roblox

- Discovery reads early bounce: sessions under about 60 seconds and between about 1 and 3 minutes count against you (**Roblox docs**, Discovery; see [[Discovery and the Algorithm]]).
- Day 1 retention is a measure of the first session. The docs' retention guidance asks for "fun within about 5 minutes", a short tutorial or tooltips, and a rewarding moment after the first loop (**Roblox docs**, Retention).
- Players arrive with low commitment, often with friends, and another game is one tap away. Every second without something to do is time they can spend leaving.

## 2. The principles, ranked

Ranked by how much they usually move retention (**Rule of thumb**, from the reference project, the case studies and teardowns in sections 32, 59 and 60).

1. **Teach by doing.** The player acts within seconds, and every step is an action, not a page to read. Show the target, let them do it, celebrate it.
2. **One verb, one goal, one pointer.** Two pointers on screen and the player follows neither (**Reference project**, playtests).
3. **Reward early, then every step.** A big, clear first reward inside the first minute; something visible on every step after it.
4. **Complete the whole core loop once in the first session**, and ideally several times in the first five minutes. A player who never sells never learns why collecting matters.
5. **Reveal depth gradually.** HUD buttons appear as their step starts; locked features show a lock and a price; optional systems arrive as contextual tips when they first matter.
6. **Hand over a next goal.** The end of the tutorial is where players stall if nothing follows (**Reference project**: "thrown in the game without knowing what to do" until a goal chain was added).
7. **Respect players.** Skip (immediately for returning accounts), resume after a rejoin, never repeat finished steps, no long unskippable cutscene, no purchase or daily-reward pop-ups during onboarding.
8. **Never gate social play.** Friends can join and play together from the first second. Social features are taught by using them.
9. **Help only when stuck, then step back.** Hints wait several seconds without progress; guidance fades once the player shows competence.
10. **Measure each step and fix the biggest drop first.**

## 3. Numbers to design against

| Moment | Target | Label |
|---|---|---|
| Join to control | about 10 s or less | Rule of thumb; Reference project capped loading at 12 s |
| Control to first meaningful action | 10 to 20 s | Rule of thumb |
| First reward | under 60 s (Reference project aimed for 40 s) | Rule of thumb |
| Objective text | 8 words or fewer | Rule of thumb |
| Stuck hint delay | 6 to 10 s without progress, tuned by A/B test | Rule of thumb; the docs suggest testing hint delays such as 5 s against 10 s |
| Core loop completions in 5 minutes | 3 or more | Rule of thumb |
| Whole tutorial | under about 3 minutes | Rule of thumb |
| Step-to-step retention early in the funnel | 90% or more per step | Rule of thumb; measure your own |
| Tutorial completion of starters | 70% or more | Rule of thumb; measure your own |
| Unskippable cutscene | none, or a few seconds | Rule of thumb; the Reference project removed a 27 s intro |

Treat every number as a hypothesis. Your own funnel replaces it as soon as you have a few hundred new players per variant ([[Measuring Onboarding - Funnels, Drop-off and A-B Tests]]).

## 4. What good looks like in shipped games

- **Grow a Garden**: buy, plant, harvest, sell, upgrade within two or three minutes, with no tutorial screen. The store description's short bullet list does the teaching ([[Case Study - Grow a Garden]]).
- **Brookhaven RP**: no gate at all. A house or a car within about 30 seconds, because a stage game has nothing to teach before play ([[Case Study - Brookhaven RP]]).
- **Doors** and **Pressure**: the first death is the lesson. One sentence about what killed you and how to survive it ([[Case Study - Doors]], [[Teardown - Pressure]]).
- **Pet Simulator 99**: verb, reward, gate, goal and premium currency all inside five minutes ([[Case Study - Pet Simulator 99]]).
- **Steal An Egg** and **Escape Tsunami for Brainrots**: the first risk event teaches the rule without text ([[Teardown - Steal An Egg]], [[Teardown - Escape Tsunami for Brainrots]]).

## 5. Where each part lives in the vault

| Part | Note |
|---|---|
| Loading and the first goal | [[Loading Screen Skip and First-Session Goals]] |
| Skip, per-step saves, replayable tips | [[Skippable Tutorials and Replayable Tips]] |
| Teaching with the space itself | [[Teaching Through Level Design]] |
| Pointers to off-screen targets | [[Off-Screen Objective Markers and Waypoint Arrows]] |
| The reward moment | [[Reward Moments and Celebrations]] |
| Words on screen | [[Writing Dialogue for Roblox Players]], [[Lore Delivery Without Walls of Text]] |
| Return after day one | [[Retention and Return Hooks]] |

## Common mistakes

| Mistake | Better |
|---|---|
| "Welcome to..." text wall at spawn | One short objective and a pointer |
| Teaching every system before the first reward | Teach the core loop; the rest arrives as contextual tips |
| A tutorial step that can be failed by the economy | Top the player up to exactly the price |
| A combat step with full-strength enemies | Weak, owned tutorial enemies, or teach the economy first |
| Hints shown immediately to everyone | Hints after several seconds stuck, once per step |
| Guidance that never stops | Fade the beam once the action has been done unaided |
| Skip that only hides the UI | Server skip that grants what the steps would have paid |
| Pop-ups stacking on first join | One gate: no automatic pop-ups until onboarding ends |
| Tutorial blocks joining friends | Social play always open; any social step optional |
| No measurement | Funnel per step, versioned when steps change |

## Checklist

- [ ] First meaningful action within about 10 to 20 s of control; first reward inside 60 s.
- [ ] One verb, one goal, one pointer per step; objective text 8 words or fewer.
- [ ] The whole core loop completed at least once in the first session.
- [ ] HUD and features revealed as taught; a next goal after the end.
- [ ] Skippable, resumable, saved per step id on the server; rewards paid once.
- [ ] No long cutscene, no purchase or reward pop-ups during onboarding, social play never gated.
- [ ] Hints only when stuck; guidance fades with competence.
- [ ] Device-correct prompts, safe areas, colour plus shape cues, Reduced Motion honoured.
- [ ] Funnel per step; biggest drop fixed first, one change at a time.

## See also

[[First-Time User Experience and Onboarding]] · [[Tutorial Step Design Patterns - Teach by Doing]] · [[Onboarding by Genre - The First Five Minutes]] · [[Measuring Onboarding - Funnels, Drop-off and A-B Tests]] · [[Onboarding Accessibility and Cross-Device Prompts]] · [[Onboarding Funnel]] · [[Skippable Tutorials and Replayable Tips]] · [[Loading Screen Skip and First-Session Goals]] · [[Core Loops and Session Design]] · [[Retention and Return Hooks]] · [[Analytics and Funnels]] · [[HUD Design]] · [[Ethical Design and Player Trust]] · [[Top Games Case Studies Start Here]]

<!-- related:start -->
## Related
[[Menu Archetypes - Shop Settings Codes Rewards]] · [[Settings Menu Design for Roblox - Layout, Controls and Motion]] · [[Accessibility]] · [[Notification and Toast Systems]] · [[UI Motion Language and Timing]] · [[Responsive UI for Phone Tablet Console and PC]]
<!-- related:end -->
