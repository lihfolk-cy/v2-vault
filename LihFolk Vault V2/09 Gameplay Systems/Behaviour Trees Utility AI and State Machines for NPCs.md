---
tags: [gameplay, ai, npc, state-machine, behaviour-tree, utility-ai, architecture, enemies, bosses, type/guide, area/gameplay, level/intermediate]
---
# Behaviour Trees Utility AI and State Machines for NPCs

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Interrupts duplicated in every state -> Global transitions in a parent
> - Avoid: No `exit` / `halt` clean-up -> Release everything acquired, on every exit path
> - Avoid: `task.wait` inside a state or leaf -> Timestamps and per-tick checks
> - Each NPC type mapped to the cheapest technique that expresses its design.
> - Global interrupts (death, stagger, leash, zone change) handled once, above states.
> - Every state or action releases what it acquired on exit, halt, death and despawn.
>
> Cost: TL;DR ~160 tok · whole note ~6.0k tok. Read more: ## 2. State machines that do not rot · ## 3. Behaviour trees, honestly · ## 8. Common mistakes · ## Checklist
<!-- tldr:end -->

[[NPC AI and Behaviour]] covers the whole enemy stack (perception, decision, action, presentation) and recommends "state machine first". This note goes one level down into the **decision layer**: how finite state machines, hierarchical state machines, [[behaviour trees]] and utility scoring actually differ, what each costs to author and debug, how each one fails, and how to combine them on a Roblox server that runs hundreds of brains at 10 Hz. The goal is not to pick the most impressive technique. It is to pick the cheapest one that still lets a designer say "make the archer back off when cornered" and get it done in one config change.

Related: [[NPC AI and Behaviour]], [[Pathfinding Edge Cases and Fallbacks]], [[Boss Fight Design Patterns]], [[Combat Systems Architecture]], [[Status Effects Buffs and Stacking Rules]], [[Entity Component Systems]], [[Enemy Animation State Protocol]].

Source labels: **Docs** (Roblox docs as of October 2026), **Measured** (the reference project, a production combat game with roughly 90 enemy kinds), **Rule of thumb**.

---

## 1. The four techniques in one table

| Technique | Mental model | Good at | Bad at | Authoring cost |
|---|---|---|---|---|
| Finite state machine (FSM) | "I am in exactly one mode" | Clear modes with few transitions: idle, chase, attack, return | Many modes that all need the same interrupts; transitions grow as N squared | Lowest |
| Hierarchical FSM (HFSM) | "Modes inside modes" | Shared interrupts (stagger, death, leash) handled once at the parent | Deep nesting, unclear which level owns a timer | Low |
| Behaviour tree (BT) | "Try these in priority order, step by step" | Scripted multi-step behaviour (approach, wind up, strike, retreat), bosses, reusable sub-behaviours | Continuous trade-offs, "how much do I want this?" | Medium |
| Utility AI | "Score every option, do the best" | Many competing options with fuzzy trade-offs (which attack, which target, flee or fight) | Strict sequences; debugging "why did it pick that" without tooling | Medium to high |

Two more appear in talks and are rarely worth it on Roblox:
- **GOAP** (goal-oriented action planning, a search over actions to reach a goal state). Powerful for simulation games with tools and crafting NPCs. For combat enemies that live 20 seconds it is planning cost with nothing to plan. Rule of thumb: skip unless your NPCs genuinely chain resource actions (fetch key, open door, take item).
- **Scripted sequences** (a list of timed steps). Not AI at all, and exactly right for intros, tutorial NPCs and the first phase of a boss. Do not dress a cutscene up as a behaviour tree.

The reference project used one data-driven FSM brain for all regular enemies with weighted attack selection inside the Attack state, and phase blocks in data for bosses. That combination (FSM for mode, a light utility pick for the attack) is the most common good answer, and the rest of this note explains when it stops being enough.

---

## 2. State machines that do not rot

### The three rules
1. **States own their own timers and clean-up.** Every state has `enter`, `update`, `exit`. Anything a state acquires (an attack token, a speed modifier, a telegraph marker) is released in `exit`, and `exit` always runs, including on death and on despawn.
2. **Transitions are data, not scattered `if` statements.** A table of `{from, to, condition}` is readable in one screen and can be logged. Transitions buried in `update` functions are how "the enemy sometimes freezes after being stunned" bugs survive for months.
3. **Global interrupts live above the states.** Death, stagger, leash and "my target left the zone" apply to every state. Writing them into each state is the N squared growth that makes people abandon FSMs. Put them in a parent (that is all an HFSM is).

### A compact HFSM in Luau

```lua
--!strict
-- A two-level state machine: global interrupts first, then the current state's own transitions.
export type Ctx = { [string]: any } -- the NPC's blackboard (target, distances, timers)

export type State = {
	name: string,
	enter: ((Ctx, number) -> ())?,
	update: ((Ctx, number, number) -> ())?, -- (ctx, now, dt)
	exit: ((Ctx, number) -> ())?,
}

export type Transition = { from: string | "*", to: string, when: (Ctx, number) -> boolean }

export type Machine = {
	states: { [string]: State },
	transitions: { Transition },
	current: State,
	enteredAt: number,
	trace: { string }, -- small ring buffer for debugging
}

local TRACE_LEN = 16

local function switch(m: Machine, ctx: Ctx, nextName: string, now: number)
	local nextState = m.states[nextName]
	assert(nextState, "unknown state " .. nextName)
	if m.current.exit then
		m.current.exit(ctx, now)
	end
	table.insert(m.trace, string.format("%.2f %s>%s", now, m.current.name, nextName))
	if #m.trace > TRACE_LEN then
		table.remove(m.trace, 1)
	end
	m.current = nextState
	m.enteredAt = now
	if nextState.enter then
		nextState.enter(ctx, now)
	end
end

local function tick(m: Machine, ctx: Ctx, now: number, dt: number)
	-- Transitions are checked in table order: put "*" (global) ones first so they win.
	for _, t in m.transitions do
		if (t.from == "*" and t.to ~= m.current.name) or t.from == m.current.name then
			if t.when(ctx, now) then
				switch(m, ctx, t.to, now)
				break -- at most one transition per tick: avoids ping-pong within a frame
			end
		end
	end
	if m.current.update then
		m.current.update(ctx, now, dt)
	end
end

return { tick = tick, switch = switch }
```

Notes on the design:
- **One transition per tick.** Allowing chains in one tick ("Chase to Attack to Recover") hides bugs and can loop forever when two conditions are mutually true.
- **`enteredAt` makes timers trivial**: "leave Recover after 0.8 s" is `now - m.enteredAt > 0.8`. Never `task.wait` inside a state. A brain that yields cannot be interrupted by a stagger, and a yielded thread outlives the NPC if it is destroyed mid-wait.
- **The trace buffer** is the cheapest debugging tool you will ever write. Publish `m.current.name` as an attribute in Studio builds and print the trace when a tester reports "it stood still".

### Failure modes of FSMs and how to spot them

| Symptom | Likely cause |
|---|---|
| NPC stuck in one state forever | A state with no exit transition for some condition (target died while in Attack, target teleported) |
| Rapid flicker between two states | Conditions with no hysteresis: Chase if distance > 15, Attack if distance <= 15, and the player stands at 15 |
| Pack goes passive after a few fights | A resource acquired in `enter` and released in the normal path only; stagger or death skipped the release |
| "Every enemy needs its own version of Chase" | The state is doing decision work; move the choice into data (attack lists, ranges) |

**Hysteresis** is the fix for flicker: enter Attack below 15 studs, leave it above 18. Rule of thumb: a 10 to 20% gap on every distance threshold, and a minimum time in state (0.2 to 0.5 s) for anything visible to players.

---

## 3. Behaviour trees, honestly

A behaviour tree is ticked from the root. Each node returns **Success**, **Failure** or **Running**.

| Node | Behaviour |
|---|---|
| Sequence | Run children in order; fail on the first failure; succeed when all succeed |
| Selector (fallback) | Try children in order; succeed on the first success; fail if all fail |
| Decorator | Wraps one child: invert, repeat, cooldown, time limit, "only if" condition |
| Leaf (action / condition) | Does the work or checks a fact |

### The part tutorials skip: Running and aborts
A leaf like "Wind up attack for 0.6 s" returns Running across several ticks. Two questions decide whether your tree works:

1. **Does the tree re-evaluate higher-priority branches while a lower branch is Running?** If not (a "memory" selector that resumes where it left off), a fleeing archer keeps winding up its shot while a sword is in its face. If yes (a "reactive" selector that restarts from the top every tick), every higher-priority condition is checked each tick and can **abort** the running branch.
2. **What happens to the aborted branch?** It must be told. Every action node needs a `halt` that releases what it holds: the attack token, the telegraph, the slow it applied to itself. A tree without halts leaks exactly like an FSM without `exit`.

Rule of thumb: use reactive selectors at the top (safety and interrupts) and memory sequences inside a committed action (once the boss has started a three-hit combo, finish it unless staggered).

### A minimal tree with halts

```lua
--!strict
export type Status = "Success" | "Failure" | "Running"
export type Node = {
	tick: (Node, any, number) -> Status, -- (self, ctx, now)
	halt: ((Node, any, number) -> ())?,
	running: boolean?,
}

local BT = {}

local function haltNode(n: Node, ctx: any, now: number)
	if n.running and n.halt then
		n.halt(n, ctx, now)
	end
	n.running = false
end

-- Reactive selector: re-checks every child from the top each tick, halting a lower
-- child that was running when a higher one now succeeds or runs.
function BT.selector(children: { Node }): Node
	local self: Node
	self = {
		tick = function(_, ctx, now)
			for i, child in children do
				local s = child.tick(child, ctx, now)
				child.running = s == "Running"
				if s ~= "Failure" then
					for j = i + 1, #children do
						haltNode(children[j], ctx, now)
					end
					return s
				end
			end
			return "Failure"
		end,
		halt = function(_, ctx, now)
			for _, c in children do
				haltNode(c, ctx, now)
			end
		end,
	}
	return self
end

-- Memory sequence: resumes at the child that was running.
function BT.sequence(children: { Node }): Node
	local index = 1
	local self: Node
	self = {
		tick = function(_, ctx, now)
			while index <= #children do
				local child = children[index]
				local s = child.tick(child, ctx, now)
				child.running = s == "Running"
				if s == "Running" then
					return "Running"
				elseif s == "Failure" then
					index = 1
					return "Failure"
				end
				index += 1
			end
			index = 1
			return "Success"
		end,
		halt = function(_, ctx, now)
			for _, c in children do
				haltNode(c, ctx, now)
			end
			index = 1
		end,
	}
	return self
end

function BT.condition(f: (any, number) -> boolean): Node
	return { tick = function(_, ctx, now) return if f(ctx, now) then "Success" else "Failure" end }
end

-- Timed action: runs for `duration`, calling start once and stop on finish or halt.
function BT.timed(duration: number, start: (any, number) -> (), stop: (any, number) -> ()): Node
	local endsAt = 0
	local active = false
	local self: Node
	self = {
		tick = function(_, ctx, now)
			if not active then
				active = true
				endsAt = now + duration
				start(ctx, now)
			end
			if now < endsAt then
				return "Running"
			end
			active = false
			stop(ctx, now)
			return "Success"
		end,
		halt = function(_, ctx, now)
			if active then
				active = false
				stop(ctx, now)
			end
		end,
	}
	return self
end

return BT
```

Important caveat: the closures above hold per-instance state (`index`, `endsAt`), so **build one tree per NPC**, not one shared tree. For hundreds of NPCs that is many small tables; it is fine at Roblox scales (a few hundred brains), but if you want a shared tree, move per-NPC state into the context table keyed by node id. That is how engine BT implementations do it, and it is the version to write if you ever serialise or hot-reload trees.

### When a tree is the right call
- **Bosses** with scripted beats: "if phase 2 and arena hazard ready, run Flood sequence; else if player far, Lunge; else melee combo". A tree reads like the design document.
- **Reusable sub-behaviours** shared across very different NPCs: "take cover", "call for help", "investigate noise". You plug the same subtree into a guard and a shopkeeper.
- **Designers who read diagrams**. A tree can be drawn; a utility system is a spreadsheet.

### When it is the wrong call
- Regular enemies with idle, chase, attack, return: a tree is an FSM with more ceremony.
- Choosing between eight attacks by distance, cooldown and health: the selector's fixed priority order makes the first valid attack win every time. You will end up adding random decorators to fake a weighted choice. Use a utility pick inside one leaf instead.

---

## 4. Utility AI: scoring, curves and the traps

Utility AI scores each option and picks the best (or picks randomly among the best few). Each option has **considerations**, each mapped through a **response curve** to 0..1, and the option's score is their product.

```
score(option) = weight * product over considerations of curve(input)
```

### Response curves
| Curve | Shape | Use |
|---|---|---|
| Linear | `x` | Proportional desire |
| Inverse | `1 - x` | Prefer when low (my health low means flee) |
| Step | `x >= t and 1 or 0` | Hard gate (in range or not) |
| Quadratic | `x^2` | Ignore until it gets serious |
| Logistic | `1 / (1 + e^(-k(x - m)))` | A soft threshold around `m` |

Normalise inputs first: distance divided by the attack's max range, health as a fraction, time since last use divided by a cooldown.

### Trap 1: multiplying many considerations punishes options with more of them
Five considerations at 0.9 each multiply to 0.59; one consideration at 0.7 beats it, even though the first option is "very good on every count". Published game AI literature describes a **compensation factor** that nudges each consideration's value back toward 1 depending on how many considerations the option has (rule of thumb here; check the formula against your source before relying on it). The simpler fix most teams use first: keep each option to **two or three** considerations, and turn hard requirements (in range, off cooldown, has line of sight) into **gates** that return 0 or pass through untouched, so they never drag a valid option's score down.

### Trap 2: oscillation
Two options with nearly equal scores swap every tick and the NPC dithers. Fixes:
- **Momentum bonus**: the current option gets x1.1 to x1.25 while active.
- **Commitment**: once started, an option is locked until it finishes or a hard interrupt fires.
- **Pick from the top band**: choose randomly among options within 10% of the best, weighted by score. This adds variety and removes ties.

### Trap 3: you cannot debug what you cannot see
A utility brain that "picked Retreat for no reason" is unfixable without the numbers. Log the scored table (option, each consideration, final) when a debug attribute is set on the NPC, and keep the last few decisions in a ring buffer as with the FSM trace.

### A small utility picker

```lua
--!strict
export type Consideration = (ctx: any) -> number -- returns 0..1
export type Option = { id: string, weight: number, considerations: { Consideration }, gate: ((any) -> boolean)? }

local rng = Random.new()
local BAND = 0.9      -- choose among options scoring at least 90% of the best
local MOMENTUM = 1.15 -- bonus for the option already running

local function score(o: Option, ctx: any): number
	if o.gate and not o.gate(ctx) then
		return 0
	end
	local s = o.weight
	for _, c in o.considerations do
		s *= math.clamp(c(ctx), 0, 1)
		if s <= 0 then
			return 0
		end
	end
	return s
end

local function pick(options: { Option }, ctx: any, currentId: string?): Option?
	local scored = {}
	local best = 0
	for _, o in options do
		local s = score(o, ctx)
		if o.id == currentId then
			s *= MOMENTUM
		end
		if s > 0 then
			table.insert(scored, { o = o, s = s })
			best = math.max(best, s)
		end
	end
	if best <= 0 then
		return nil
	end
	local total = 0
	local band = {}
	for _, e in scored do
		if e.s >= best * BAND then
			table.insert(band, e)
			total += e.s
		end
	end
	local r = rng:NextNumber() * total
	for _, e in band do
		r -= e.s
		if r <= 0 then
			return e.o
		end
	end
	return band[#band].o
end

return { pick = pick, score = score }
```

---

## 5. Hybrids: what production brains look like

Almost every shipped Roblox enemy that feels good is a hybrid. The layering that works:

| Layer | Technique | Example |
|---|---|---|
| Mode | HFSM | Idle, Alert, Combat, ReturnHome, Dead; global Stagger and Leash interrupts |
| Combat choice | Utility or weighted pick | Which attack: filtered by range and cooldown, scored by distance fit and variety |
| Committed action | Sequence (BT style or a timed script) | Wind-up, telegraph, hit frames, recover |
| Group rules | Shared service | Attack tokens, ring slots, separation ([[NPC AI and Behaviour]] section 5) |

**Measured:** the reference project's regular enemies were exactly this: a data-driven state brain at 10 Hz, attacks filtered by range and cooldown and picked by weight, never the same attack twice in a row for bosses, two attack tokens per target, and boss phases expressed as data (`at` health fraction, speed and damage multipliers). Its pop-up event boss added three phases at 66% and 33%, each opened by a knock-back roar, and unlocked new attacks per phase, which is a phase-gated option list rather than a new architecture.

### Worked example: one archer, three architectures
Design: an archer keeps 25 to 40 studs from the player, shoots when it has line of sight, backs off when the player closes in, and melee-kicks if cornered.

- **FSM:** states Reposition, Shoot, Retreat, Kick. Transitions on distance bands with hysteresis, plus "no line of sight" to Reposition. Six transitions, readable. **Best fit.**
- **BT:** Selector(Sequence(cornered?, Kick), Sequence(tooClose?, Retreat), Sequence(hasLOS?, inBand?, Shoot), Reposition). Also fine; the reactive selector gives correct interrupts for free. Slightly more machinery than needed.
- **Utility:** four options with distance and LOS considerations. Works, but "cornered" is a hard rule pretending to be a curve, and tuning four curves to reproduce two distance thresholds is wasted effort.

Now add "the archer prefers fire arrows against shielded players, poison against high-health players, and splits fire between two targets in groups". The FSM now needs a choice inside Shoot. That choice is a **utility pick inside one state**, not a rewrite.

---

## 6. Roblox-specific constraints

- **Tick rate.** Run brains at 5 to 10 Hz and let movers or `Humanoid:MoveTo` produce smooth motion between ticks (**Measured**: 10 Hz brains, staggered phase, only within 200 studs of a player). A brain that runs every Heartbeat for 300 NPCs is the first thing the [[MicroProfiler Guide]] will show you.
- **No yielding in brains.** `task.wait`, `ComputeAsync` and any `Async` call inside a brain tick stall it. Request paths through a queue and read the result on a later tick ([[Pathfinding Edge Cases and Fallbacks]]).
- **Use one clock.** `os.clock()` for server-only timers; `workspace:GetServerTimeNow()` for anything a client must line up with (telegraph start times sent to clients) (Docs).
- **Replicate the decision, not the brain.** Write the visible state as an attribute or send a compact message ("attack Slam at t aimed at P"); clients animate it ([[Enemy Animation State Protocol]]). Never replicate scores or trees.
- **Parallel Luau.** Scoring is read-heavy and could run in Actors, but Actors cannot write to instances outside their own context without synchronising, and brains act on shared state (tokens, targets). Rule of thumb: only parallelise the expensive read-only part (spatial queries, line of sight batches) once profiling proves the brain is the bottleneck ([[Parallel Luau and Actors]]).
- **Data over code.** Definitions in ModuleScripts (or generated from a spreadsheet: [[Data and Config Pipeline - Spreadsheets to Game]]) so a balance change is not a code review.

---

## 7. Debugging any of them

| Tool | How |
|---|---|
| State attribute | `npc:SetAttribute("AIState", name)` in Studio builds; filter in the Properties panel |
| Overhead label | A BillboardGui on each NPC showing state, target and last decision, toggled by a dev command |
| Trace ring buffer | Last 16 transitions or decisions with timestamps; dump on demand |
| Freeze and step | A dev flag that stops brain ticks, plus a command to tick one NPC once |
| Score dump | For utility: the full table of options and considerations for the last decision |

Rule of thumb: build the overhead label before the second enemy type. It pays for itself the first time a tester says "they just stand there".

---

## 8. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Interrupts duplicated in every state | One state forgets stagger; enemy attacks through stun | Global transitions in a parent |
| No `exit` / `halt` clean-up | Leaked tokens, permanent slows, stuck telegraphs | Release everything acquired, on every exit path |
| `task.wait` inside a state or leaf | Cannot be interrupted; threads outlive dead NPCs | Timestamps and per-tick checks |
| No hysteresis | Flicker between two states | Enter and exit thresholds 10 to 20% apart, minimum time in state |
| Behaviour tree for a three-state enemy | Hard to read, no gain | FSM |
| Fixed-priority selector choosing attacks | First valid attack always wins | Utility or weighted pick inside one leaf |
| Utility with five or more considerations per option | Options with more considerations never win | Two or three per option; hard rules as gates |
| Shared BT instance with per-node state | NPCs interfere with each other's sequences | One tree per NPC or state in the context |
| Scores invisible | "Why did it do that?" unanswerable | Score dumps and decision traces |

---

## 9. When not to build any of this

- Ambient NPCs that walk a loop and play an emote: a patrol list and a timer.
- Tutorial guides: a scripted sequence with explicit steps, so the tutorial is deterministic and testable ([[First-Time User Experience and Onboarding]]).
- Crowds in a hub: animation and a few waypoints; no brain at all is the most performant brain.

---

## Checklist
- [ ] Each NPC type mapped to the cheapest technique that expresses its design.
- [ ] Global interrupts (death, stagger, leash, zone change) handled once, above states.
- [ ] Every state or action releases what it acquired on exit, halt, death and despawn.
- [ ] Distance and health thresholds have hysteresis; visible states have a minimum duration.
- [ ] No yields inside brain ticks; async work goes through queues.
- [ ] Attack choice is a weighted or utility pick, with momentum or commitment to prevent dithering.
- [ ] Brains run at 5 to 10 Hz, staggered and distance-gated.
- [ ] State attribute, overhead label and decision trace available in Studio builds.

## See also
[[NPC AI and Behaviour]] · [[Pathfinding]] · [[Pathfinding Edge Cases and Fallbacks]] · [[Boss Fight Design Patterns]] · [[Status Effects Buffs and Stacking Rules]] · [[Combat Systems Architecture]] · [[Entity Component Systems]] · [[Enemy Animation State Protocol]] · [[Boss Animation and Phases]] · [[Frame Order and RunService Timing]] · [[Script Performance]]

## Connected notes
<!-- auto-links:start -->
[[Horror Monster Chase AI End to End]] · Enemy and NPC Animation · Links - NPCs and AI · Anticipation · Dialogue System End to End · Hit Reactions Stagger and Hit-Stop
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Visual AI Debugging - State Labels, Path Lines and Perception Gizmos]] · [[Squad AI - Attack Tokens, Flanking and Attacker Limits]] · [[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[Wildlife and Ambient Creature AI - Passive, Neutral and Hostile]] · [[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]] · [[Spawning Teams and Rounds]] · [[Spawn Director - Credit Budgets and Player-Count Scaling]] · [[AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses]]
<!-- related:end -->
