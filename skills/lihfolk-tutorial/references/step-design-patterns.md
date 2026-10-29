# Step design patterns

How to turn a design into `LihFolkTutorial` steps. Each pattern: when to use it, the step fields, and what to watch. The vault note `05 UI and UX/Tutorial Step Design Patterns - Teach by Doing.md` covers the reasoning in more depth.

## Writing a step
- **Objective = verb + object (+ why).** "Sell your coins at the green pad". 8 words or fewer. Tokens like `{INTERACT}` become "Press E", "Tap" or "Press X".
- **Hint = the missing piece, not a repeat.** If the objective says what, the hint says where or how: "Follow the gold path".
- **One signal per step**, sent by the server system that already knows it happened (currency change, hatch, kill). Never a client "I finished".
- **Goal counts stay small**: 1 for a new verb, 3 to 10 for a repeat that builds rhythm.

## Pattern 1: Do it once (new verb)
`signal`, `goal = 1`, `target`, `guide = "always"`. The default. Pay a small reward on completion.

## Pattern 2: Do it a few times (rhythm)
`goal = 3..10`, `highlight = false` when there are many targets (beam to the nearest only). The progress counter in the banner is the reward between hits.

## Pattern 3: Try first, help later
`guide = "whenStuck"`, `hintAfter = 6..10`. For verbs most players find alone (walking to a big glowing door). Guidance appears only for those who need it, so competent players never feel led.

## Pattern 4: Already done
`isComplete = function(player) ... end` on the server. For steps a returning player, a trade or a gift may have satisfied (owns a pet, has a tool). The step completes itself on activation or `:Refresh(player)`.

## Pattern 5: Contextual (just in time)
`trigger = function(player) ... end` on the server, plus `requires`. The step activates only when the situation happens (backpack full, first time near the trader). Call `:Refresh(player)` when that state changes. Use for every tip that is not part of the first loop.

## Pattern 6: HUD button step
`guide = "none"` plus `reveal = { "UpgradeButton" }`. The client pulses or points at the button; the world beam stays off. If the button opens a menu that only the client knows about, use `clientSignal = "OpenedShop"` and keep any reward server-side elsewhere.

## Pattern 7: Social, never a gate
`optional = true`, `clientSignal = "InviteOpened"`, no reward from the client. The server completes it for real when a friend is in the server (`:Complete(player, "friends")`).

## Pattern 8: Server-decided moment
No `signal`; the server calls `:Complete(player, id)` when a scripted moment ends (a short cutscene, a boss intro). Keep the moment skippable.

## Pattern 9: Affordable purchase
The step before a purchase has `reward = "TopUp"`; the reward hook tops currency up to exactly the price. The player never fails a step because of the economy.

## Ordering the graph
- List steps in teaching order; the first active step is the one on screen.
- `requires` must point to earlier steps (the module asserts this).
- Parallel steps (two `requires` on the same parent) are allowed; only the first is shown, so keep parallel branches rare.

## Changing steps after launch
- Never reuse an id for a different step. Add new ids; map removed ones with `renamed = { old = "new" }`.
- New steps show only to players who lack them. Finished players see only new steps that pass their `trigger`.
- Reordering changes funnel meaning: set `funnelName = "Tutorial_v2"` and compare cohorts.

## Anti-patterns
| Pattern | Better |
|---|---|
| A "Next" button slideshow at spawn | Contextual steps with triggers |
| Client fires "StepDone" | Server signal from the system that knows |
| Two steps active with two beams | One focused step; others wait |
| Hint visible from second zero | `hintAfter` and `guide = "whenStuck"` |
| Step that needs a drop from combat | Teach on safe ground or guarantee the drop |
| "Tutorial complete" as the last screen | `onFinished` hands over the next goal |
