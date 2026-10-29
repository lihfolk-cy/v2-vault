---
name: lihfolk-tutorial
description: 'Design and build Roblox tutorials and onboarding (FTUE) that keep first-time players: first 60 seconds, guide arrows, stuck hints, skip/resume, funnels, D1 retention. Use when new players leave early or "don''t know what to do".'
---

# LihFolk Tutorial

A tutorial has one job: get a brand-new player to **enjoy the core loop once, fully, and want the next goal**, as fast as possible. Players who are taught well stay; the aim is never "explain everything". This skill turns that into decisions you can check, a drop-in module, and a rubric.

## Inputs

- `VAULT`: `<base directory>/../../LihFolk Vault V2` (absolute path from the base directory Claude Code shows when this skill loads). Search with `py "VAULT/_tools/vault.py" "<query>"`.
- Read first, in this order (TL;DR blocks are enough unless you are building that part):
  1. `VAULT/05 UI and UX/Onboarding and FTUE - Tutorials That Keep Players.md` (principles, numbers, labels)
  2. `VAULT/10 Game Design and Genres/First-Time User Experience and Onboarding.md` (timeline, five tutorial versions of one real game, server state machine)
  3. `VAULT/10 Game Design and Genres/Onboarding by Genre - The First Five Minutes.md` (the genre you are building)
  4. Building steps: `VAULT/05 UI and UX/Tutorial Step Design Patterns - Teach by Doing.md`. Measuring: `VAULT/11 Monetization Publishing and Live Ops/Measuring Onboarding - Funnels, Drop-off and A-B Tests.md`. Devices and accessibility: `VAULT/42 Accessibility and Inclusive Design/Onboarding Accessibility and Cross-Device Prompts.md`.
  5. How shipped games do it: `VAULT/32 Case Studies of Top Roblox Games/`, `VAULT/59 Viral and Trend Game Teardowns/`, `VAULT/60 High-Craft Game Teardowns/` (each has a "First 60 seconds" section).
- Module: `src/LihFolkTutorial.luau` (server + client). Example: `examples/` (5-step simulator onboarding). Checklists: `references/ftue-checklist.md`, `references/step-design-patterns.md`.
- Quality bar: `../quality-score/rubrics/tutorial.md`, minimum **8.5**.

## Workflow

1. **Name the core loop in one line** ("collect, sell, upgrade, hatch"). If you cannot, fix the design before the tutorial.
2. **Write the first-five-minutes script** as a table: second, what the player does, what they get, what is on screen. Use the genre row below as the starting shape.
3. **Cut steps.** Keep only verbs the player will not discover alone, plus the one core loop. Everything else becomes a contextual tip later.
4. **Build with the module** (step list in a shared ModuleScript, signals from your existing server systems, rewards through the reward hook). See Install.
5. **Play it fresh on a phone-sized viewport, with keyboard, and with a gamepad.** Then rejoin mid-tutorial, skip, die mid-step.
6. **Score with the tutorial rubric.** After launch, read the funnel and fix the single largest drop first.

## Principles that change outcomes

**Teach by doing**
- The first meaningful action lands within about 10 to 20 seconds of control (Rule of thumb; the vault FTUE note targets first verb by 30 s at the latest).
- One verb per step, one goal on screen, one pointer. Two pointers means the player follows neither.
- Show, then let them do it. Objective text is **8 words or fewer** (Rule of thumb), names the control for the current device, and never covers the play area.
- No slideshows. Tips appear **when the situation happens** (first time the backpack fills, first time near a trader), not in a queue at spawn.
- Hints wait. Show extra help only after the player has been stuck for several seconds (6 to 10 s is a sensible start; tune it with data). Progress resets the timer.

**Reward early and often**
- First reward inside the first minute, big and unmistakable (sound, number pop, short celebration). Every step pays something visible, even if small.
- The **whole core loop happens once** in the first session, and ideally several times in the first five minutes.
- If a step asks the player to buy something, guarantee they can afford it (top up to exactly the price).
- Then **reveal depth gradually**: HUD buttons appear as their step begins; locked features are shown with a lock and a price, not hidden.
- The end of the tutorial hands over a **next goal** (a quest, a gate with a price, a goal chain). "Tutorial complete" with nothing next is where players stall.

**Respect players**
- Skippable for returning accounts immediately and for new players after the first step, with a short confirm. A server skip grants what the steps would have paid.
- Resumable: progress is saved per step id on the server; a rejoin continues where they left; finished steps never show again; new steps added later show only to players who lack them.
- No unskippable cutscene longer than a few seconds. No purchase prompts, daily-reward pop-ups or community prompts while onboarding runs.
- Never gate social play behind the tutorial: friends can join, talk and play together from second one.
- Stop guiding once the player shows competence (they did it without the hint): drop the beam, keep the objective.

**Platform and accessibility**
- Control names come from the device the player is using now (touch, gamepad, keyboard), and update when they switch. Read bindings from the Input Action System when the game uses it.
- Prompts sit inside safe areas (`ScreenGui.ScreenInsets`), readable on a small phone, touch targets at least about 44 px.
- Colour plus shape or text for every cue (beam plus outline plus words). Respect `GuiService.ReducedMotionEnabled`: no pulsing, no moving textures. Caption any voiced line.

**Measure and iterate**
- Funnel every step on the server with `AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)`; step 1 is "Joined", the last is "Finished". Use `LogFunnelStepEvent` with a versioned funnel name ("Tutorial_v3") when you reorder steps.
- Log skips and hint displays as custom events (one event name, the step id in a custom field).
- Fix the **largest drop first**, one change at a time, cohorted by join date. A/B small things: hint delay, step order, reward size.
- Targets to start from (Rule of thumb, replace with your own data): each early step keeps **90% or more** of the players who reached it; time to first reward **under 60 s**; tutorial finished by **70% or more** of players who started it; whole tutorial **under 3 minutes**.

## Guidance tools: when to use each

| Tool | Use when | Avoid when |
|---|---|---|
| Beam from feet to target | Target is off-screen or across the map | Target is already in view (clutter) |
| `Highlight` (Occluded) | Interactable in view among many look-alikes | Many targets at once (one per step; Roblox caps active highlights) |
| `ProximityPrompt` hint | The verb is "walk up and press" | The action is a HUD button |
| HUD button pulse or hand | Target is a GUI button | World targets (point in the world instead) |
| Camera nudge | Player must notice something behind them, once | Repeatedly, or for players with Reduced Motion |
| NPC demo / ghost player | Verb is physical (jump timing, combo) | Text would do; never block input while it plays |
| Level design (show, try, test) | Obby, horror, platforming | Economy steps the space cannot show |

## Patterns by genre (first five minutes)

| Genre | Feel of the first 5 minutes | Anti-pattern |
|---|---|---|
| Simulator / tycoon | Collect, sell, upgrade, first pet or dropper inside 2 minutes; number goes up every few seconds | Long walk to the first pad; shop before the first sale |
| Trend / viral | The title verb in the first 30 s (steal, grab, escape); first risk event teaches the rule | Being robbed by a far richer player in minute one; no newcomer grace |
| Obby | Moving within seconds; first checkpoint in under 20 s; the first jumps teach by shape | Text explaining jumping; a hard jump before the first checkpoint |
| Combat | One weak, owned enemy; first kill in under a minute; one ability at a time | Full-strength enemies and five abilities at spawn |
| Horror | Quiet first rooms; the first threat has a long, readable warning and a visible counter | Unfair first death with no lesson; the lesson lives in a wall of text |
| Social / RP | No gate: own a house, car or outfit within 30 s; tips appear as you use features | Forced tutorial before you can join friends |
| Tower defense | First placement in the first wave with a pointer to a good spot; first wave cannot be lost | Explaining every tower and stat before wave 1 |

## Install (module)

```
ReplicatedStorage/LihFolk/LihFolkTutorial  ModuleScript  <- src/LihFolkTutorial.luau
ReplicatedStorage/TutorialSteps            ModuleScript  <- your step list (examples/SimulatorSteps.luau)
ServerScriptService/Tutorial               Script        <- examples/Tutorial.server.luau
StarterPlayerScripts/Tutorial              LocalScript   <- examples/Tutorial.client.luau
```

Server: `Tutorial.Server.new({ steps, remote, load, save, reward, isReturning, renamed, funnelName, onFinished })`, then `:Start()`. Gameplay systems call `tutorial:Signal(player, "Sold", 1)`; use `:Refresh(player)` after state changes with no signal, `:Complete(player, id)` for server-decided steps, `:Skip`, `:Reset` (replay from Settings).
Client: `Tutorial.Client.new({ steps, remote, ui?, glyphs?, inputActions?, reducedMotion?, beamTexture? })`, then `:Start()`. `:Report("OpenedShop")` only advances a step that lists that `clientSignal`; it never pays rewards that matter.

Step fields: `id`, `objective`, `signal`, `goal`, `clientSignal`, `requires`, `trigger` (server), `isComplete` (server), `optional`, `reward`, `target` (`instance`/`tag`/`path`/`position`, `highlight`, `beam`, `prompt`), `guide` (`always`/`whenStuck`/`none`), `hint` (per device), `hintAfter`, `reveal` (HUD keys).

Rules the module enforces: server owns progress and rewards; saves step ids, never indices; rewards pay once (also on skip); a failed load pauses the tutorial instead of resetting it; analytics are server-only, forward-only and wrapped in `pcall`; all world guidance is cleaned up on step change and respawn.

## Before you call it done

- Run `references/ftue-checklist.md` and score with `../quality-score/rubrics/tutorial.md` (8.5 bar, blind reviewers for the judged criteria).
- Run the LihFolk checker on all new Luau (0 errors).
- Describe the result in positive, constructive terms: what the player will do and feel, and the next improvement to try.
