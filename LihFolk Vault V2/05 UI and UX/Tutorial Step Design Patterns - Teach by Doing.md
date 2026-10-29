---
tags: [ui, ux, onboarding, tutorial, ftue, guidance, hints, beams, highlight, proximityprompt, type/guide, area/ui, area/design, level/intermediate, api/Beam, api/Highlight, api/ProximityPrompt, api/CollectionService]
verified: 2026-10-29
---
# Tutorial Step Design Patterns - Teach by Doing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: "Next" button slideshow at spawn -> Contextual steps that wait for the situation
> - Avoid: Client fires "step done" -> Server signal from the system that knows
> - Avoid: Two active steps, two beams -> One focused step; the rest wait
> - Every step is verb plus target plus server completion signal.
> - Objective 8 words or fewer; hint adds where or how.
> - Guidance tool chosen by target location; one pointer at a time.
>
> Cost: TL;DR ~150 tok · whole note ~1.9k tok. Read more: ## 2. Nine step patterns · ## 3. Choosing the guidance tool · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Onboarding and FTUE - Tutorials That Keep Players]] says what a good tutorial does. This note is about the unit it is built from: **the step**. How to write one, nine patterns that cover nearly every tutorial, how to choose between a beam, a Highlight, a prompt, a camera nudge and an NPC demo, and how to stop guiding at the right moment. The plugin skill **lihfolk-tutorial** implements every pattern here as step fields (`skills/lihfolk-tutorial/references/step-design-patterns.md` maps each one).

Trust labels: **Roblox docs** (class behaviour, as of October 2026), **Reference project** (see [[First-Time User Experience and Onboarding]]), **Rule of thumb**.

---

## 1. Anatomy of a step

| Part | Rule |
|---|---|
| Objective | Verb plus object, optionally plus why: "Sell your coins at the green pad". 8 words or fewer (**Rule of thumb**). |
| Control name | From the current device: "Press E", "Tap", "Press X". Never hard-coded ([[Onboarding Accessibility and Cross-Device Prompts]]). |
| Target | One instance or position. The player should never wonder which one. |
| Completion | A signal from the **server** system that already knows (currency changed, egg hatched, enemy died). The client never declares a step done. |
| Goal count | 1 for a new verb; 3 to 10 for a repeat that builds rhythm (**Rule of thumb**). |
| Reward | Something visible every step; the big one early. |
| Hint | The missing piece, not a repeat: if the objective says what, the hint says where or how. |

## 2. Nine step patterns

1. **Do it once.** A new verb. Pointer on, goal 1, small reward.
2. **Do it a few times.** Rhythm and the first "number goes up". Point at the nearest target only; the counter is the reward between hits.
3. **Try first, help later.** For verbs most players find alone. No guidance until the player has been stuck for several seconds; competent players never feel led.
4. **Already done.** A server check ("owns a pet") completes the step on arrival, for returning players, trades and gifts.
5. **Contextual (just in time).** Activates only when the situation happens: the backpack fills, the player nears the trader. This is how every system outside the first loop is taught (**Roblox docs**, onboarding techniques: contextual tutorials).
6. **HUD button.** Point at the button, not into the world. Reveal the button as the step starts, so the reveal itself feels like a reward.
7. **Social, never a gate.** "Bring a friend" is optional and pays nothing from a client report; the server completes it when a friend is actually in the server.
8. **Server-decided moment.** A short scripted beat (a boss roar, a door opening) the server completes when it ends. Keep it skippable and a few seconds long.
9. **Affordable purchase.** The step before a purchase tops the player up to exactly the price, so the economy can never fail a tutorial step (**Reference project**, forge top-up).

## 3. Choosing the guidance tool

| Tool | Best for | Notes |
|---|---|---|
| `Beam` from the feet to the target | Off-screen or distant targets | Two `Attachment`s; `FaceCamera = true`; start near the feet so it reads as a path. A world position can use an attachment on `workspace.Terrain`. |
| `Highlight` | An interactable in view among look-alikes | Use `DepthMode = Occluded` so it does not glow through walls. Extra highlights past the engine limit silently do not render (**Roblox docs**, October 2026: 255; older docs said 31), and each one costs on mobile, so use one per step. See [[Highlights and Selection Effects]]. |
| `ProximityPrompt` | "Walk up and press" | The prompt already shows the right key per device. Emphasise the tutorial one with a local tag and a custom style. |
| Button pulse or pointing hand | HUD targets | Place it on the exact button, in the same coordinate space as the button (the Reference project's spotlight drifted off-button on scaled phones). |
| Off-screen arrow at the screen edge | Targets behind the player | See [[Off-Screen Objective Markers and Waypoint Arrows]]. |
| Camera nudge | Once, to show something behind the player | Short, interruptible, never under Reduced Motion. |
| NPC demo or ghost player | Physical verbs (jump timing, a combo) | Never take input away while it plays. |
| The level itself | Obbies, horror, platforming | Show, try, test, combine ([[Teaching Through Level Design]]). |

## 4. When to stop helping

- **Progress resets the stuck timer.** A player who is collecting slowly is not stuck.
- **Show each hint once per step**, then leave it to the objective (**Roblox docs** recommend showing timed hints only once, only to players who need them).
- **Fade guidance after competence.** If the player did the action before the hint appeared, the next repeat of that verb needs no beam.
- **Contextual tips are one-time by default** and replayable from a tips page ([[Skippable Tutorials and Replayable Tips]]).

## 5. Ordering and changing steps

- Teaching order is list order; only the first active step is on screen.
- Step ids are saved, never indices; removed ids map to their replacement; new steps show only to players who lack them.
- Reordering changes what funnel numbers mean: start a new versioned funnel ([[Measuring Onboarding - Funnels, Drop-off and A-B Tests]]).

## Common mistakes

| Mistake | Better |
|---|---|
| "Next" button slideshow at spawn | Contextual steps that wait for the situation |
| Client fires "step done" | Server signal from the system that knows |
| Two active steps, two beams | One focused step; the rest wait |
| Highlight on every coin | Beam to the nearest coin, no outline spam |
| Hint visible immediately | Hint after several seconds stuck |
| Step depends on a random combat drop | Teach on safe ground or guarantee the drop |
| Beam lost after respawn | Rebuild guidance on `CharacterAdded` |
| Prompt text says "Press E" on a phone | Device-aware text, updated on device switch |

## Checklist

- [ ] Every step is verb plus target plus server completion signal.
- [ ] Objective 8 words or fewer; hint adds where or how.
- [ ] Guidance tool chosen by target location; one pointer at a time.
- [ ] Hints wait; progress resets the timer; each hint once.
- [ ] Guidance fades after competence; tips replayable.
- [ ] Purchases in the tutorial are guaranteed affordable.
- [ ] Guidance cleaned up on step change and rebuilt on respawn.

## See also

[[Onboarding and FTUE - Tutorials That Keep Players]] · [[First-Time User Experience and Onboarding]] · [[Onboarding by Genre - The First Five Minutes]] · [[Onboarding Accessibility and Cross-Device Prompts]] · [[Teaching Through Level Design]] · [[Off-Screen Objective Markers and Waypoint Arrows]] · [[Skippable Tutorials and Replayable Tips]] · [[Quests and Objectives]] · [[HUD Design]] · [[Reward Moments and Celebrations]] · [[World-Space UI - BillboardGui and SurfaceGui]]

<!-- related:start -->
## Related
[[Menu Archetypes - Shop Settings Codes Rewards]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[Gamepad and Console UX]] · [[Settings Menu Design for Roblox - Layout, Controls and Motion]] · [[Nametags and Overhead Bars - Cost and Visibility Rules]] · [[UI Motion Language and Timing]] · [[Input - UserInputService and ContextActionService]] · [[Touch Gestures - Pinch, Pan, Swipe and Long Press]]
<!-- related:end -->
