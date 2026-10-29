---
tags: [game-design, ftue, onboarding, tutorial, funnel, retention]
---
# First-Time User Experience and Onboarding

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Text walls ("Welcome to the world of...") -> One line, one target, one pointer
> - Avoid: Teaching every system up front -> Teach the core loop; teach the rest just in time
> - Avoid: Combat in the first 20 seconds with full-strength enemies -> Weakened, owned tutorial enemies, or no combat until the loop is clear
> - Control within about 10 s of join; no unskippable cutscene.
> - First verb by 30 s, first big reward by 40 s.
> - Core loop closed three or more times in 5 minutes.
>
> Cost: TL;DR ~160 tok · whole note ~5.5k tok. Read more: ## 6. Case study: five versions of one tutorial · ## 7. Implementation: a server-side onboarding state machine · ## 9. Common mistakes · ## 10. Checklist
<!-- tldr:end -->

The **first-time user experience (FTUE)** is everything a new player sees from the moment the game starts loading to the moment they understand the core loop and want more. On Roblox it is the single highest-leverage piece of design: discovery measures it directly, and a player who bounces in minute one never sees your best content. This note covers the first 60 seconds, the first 5 minutes, tutorial gating and HUD reveals, the techniques Roblox recommends, and a long case study of one production game's tutorial going through five versions.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production RNG combat game, anonymised), **Rule of thumb**.

---

## 1. Why the first minutes matter so much on Roblox

- Discovery ranks games partly on **first play bounce rate**, measured as the share of sessions under 60 seconds and between 61 and 180 seconds (Docs, "Discovery"). Every new player who leaves in the first three minutes is a negative signal.
- Day 1 retention is the first number the docs' retention guidance addresses, and it recommends getting users "into the fun within about 5 minutes", a brief tutorial or tooltips, "a rewarding moment after the first loop", and a preview of future progress (Docs, "Retention").
- The onboarding page says players often decide their interest "within minutes" and frames onboarding around three goals: **teach the essentials, get to the fun quickly, leave players wanting more** (Docs, "Onboarding").
- Users hop between games, often with friends, and "long tutorials risk losing them" (Docs, "Design for Roblox").

Treat the FTUE as a **funnel**: each step loses some players. Your job is to make each step short, obvious and rewarding, and to measure where people fall out.

---

## 2. The first 60 seconds

A timeline to design against (targets are rules of thumb):

| Time | Event | Target | Notes |
|---|---|---|---|
| 0 s | Join pressed | | |
| 0 to 10 s | Loading | As short as you can make it | Defer non-essential assets; see [[Case Study - Fast Join and Deferred Loading]] |
| about 10 s | Control | Player can move | No forced cutscene; a skippable one at most |
| 10 to 20 s | First prompt | One instruction, one target | A pointer, a trail, or a glowing button |
| 15 to 30 s | First verb | Player does the core action | Roll, swing, jump, place |
| 20 to 40 s | First reward | Big, loud payoff | Full-screen reveal, sound, number pop |
| 40 to 60 s | Second loop | Player repeats with a small twist | Proves the loop is a loop |

What the reference project did at the loading step: a loading screen capped at 12 s, skippable after 5 s, and new players let in at 8 s. It also **disabled its 27-second intro cutscene**: a first-person wake-up scene that was polished but sat entirely inside the bounce window.

### Spawn placement
Spawn new players **facing the first target**. The reference project moved its spawn point so the player lands on the hub plaza looking at the roll altar, and later shrank the first zone (walk from the portal to the first gate went from about 460 studs to about 227) because players "should be able to get to zone 1 quicker". Walking with nothing to do is dead time in the bounce window.

---

## 3. The first 5 minutes

By minute five a player should have:

1. **Completed the core loop several times** (three to five is a good rule of thumb).
2. **Seen the number go up**: a currency counter, a level, a power stat.
3. **Made one meaningful choice** (which weapon to equip, which upgrade to buy).
4. **Spent something** and seen the spend change the verb.
5. **Seen the long loop**: a locked gate with a price, the rebirth button, the rarity ladder, a leaderboard.
6. **Finished onboarding with a "moment of joy"**, which the docs recommend: a reward, animation or celebratory effect (Docs, "Onboarding").
7. **Been handed the next goal**, so the end of the tutorial is not the end of direction.

### Starter items and currency
The docs advise giving enough free starter items and currency that players can enjoy them, and testing the amount with A/B experiments (Docs, "Onboarding"). Two production patterns:
- **Tutorial top-ups.** If a tutorial step asks the player to buy something, guarantee they can afford it. The reference project's forge step tops the player up to exactly one forge (12 of the starter material plus $320) and opens the forge already focused on the held weapon.
- **Finale bundle.** The reference project paid $2,000 plus a 10-roll luck charm at "TUTORIAL COMPLETE", so the first free session starts with momentum.

### Low early thresholds
Keep early XP, gate and upgrade thresholds low so the first level-ups arrive fast (Docs, "Onboarding"). See [[Progression and Pacing Design]] for curves that start gentle and steepen.

---

## 4. Techniques Roblox recommends

The docs page "Onboarding techniques" names three:

| Technique | What it is | Example |
|---|---|---|
| Visual elements | Temporary in-world or UI cues: bouncing arrows on buttons, particles on items, glowing trails to destinations, in-world signs | A trail beam from the player to the next gate |
| Contextual (just-in-time) tutorials | Triggered by natural play, such as entering a zone or picking up an item | A trading tip that appears the first time a player opens the market |
| Timed hints | Shown only to players who have not progressed after a set time | Highlight the plant button at 11 s if most players press it within 10 s |

Its recommendations: **visuals over text** (players skip text), **feedback for every action**, **teach in context**, set hint timing by playtest, **show timed hints only once** and only to players who need them, and tune timings with A/B tests (the docs give the example of comparing a 5-second and a 10-second hint delay).

### Production details that make these work
From the reference project's tutorial reference document (its "bar for every tutorial change"):
- A full-screen first reward.
- A **"NEXT UP!" top bar** with one goal and a progress bar.
- Big, short-lived coach text.
- Animated ground chevrons or a trail to the target.
- A bobbing hand on the **exact** button.
- "+N" gain pops on every action.
- Full-screen payoffs with plain-language "what you got" text.
- Locked features shown with a lock, not hidden.
- Steps that take seconds, not minutes.

And the pointer rules that came from playtests:
- **One goal on screen.** If two systems both draw a pointer, the player follows neither.
- The hand must not jump between candidate buttons. The reference project's fix was a tie-break order: the step's own target first, then the element the hand is already on, then top-most and left-most.
- Spotlight cut-outs must be computed in the same coordinate space as the button (an `AbsolutePosition` mismatch put the hole off the button on scaled phone layouts).

---

## 5. Tutorial gating and the HUD reveal

**Gating** decides what a new player can touch before they have been taught it.

| Model | How it works | Good for | Risk |
|---|---|---|---|
| Hard gate | Everything except the current step is disabled | Very simple games, small number of verbs | Feels like a cage; experienced players hate it |
| Soft gate | Everything works, but pointers and rewards only follow the script | Most games | New players wander off-script |
| HUD reveal | HUD elements are hidden until their step, then animate in | Games with many menus | Must handle players who skip or rejoin mid-way |
| Contextual unlock | A feature appears when the player first needs it | Large games | Players never discover optional features |

### The HUD unlock reveal
A dense simulator HUD (a dozen menu buttons, three currencies, quest dock, boost pills) is overwhelming to a new player on a phone. A reveal shows **only what the current step needs**, then animates each element in as it is taught, so the HUD itself becomes a progress display.

The reference project's version, in its seven-step tutorial:
- During steps 1 to 5, the left menu grid, the currency stack, the ability bar, the quest dock tabs and the boost pill were hidden.
- At the forge step, **only the Forge button** appeared, with the hand on it.
- The quest tracker stayed hidden until the quests step.
- Everything else appeared at "TUTORIAL COMPLETE".

Implementation notes:
- Drive visibility from **one** onboarding state (an attribute or a replicated JSON value), not from each UI script's own guess. Every HUD script reads the same "step" value.
- Animate the reveal (scale from 0.8 with a back-out ease, a short sound). The reveal is itself a reward. See [[UI and GUI Animation]].
- Pop-ups that are not part of the tutorial (daily reward, favourite prompt, community prompt, event banners) must be **suppressed while onboarding runs**. The reference project's rule: no automatic pop-up during onboarding, over another panel, in combat, or within 8 s of another.

---

## 6. Case study: five versions of one tutorial

The reference project rewrote its onboarding repeatedly over about two weeks. The versions are worth reading in order, because each fixed the previous one's specific failure.

### Version A: long and cinematic
A 27 s first-person intro cutscene, then tips. **Problem**: the cutscene sat inside the bounce window. **Fix**: intro disabled behind a flag.

### Version B: eleven steps, combat included ("first 5 minutes should be super fun")
Steps: roll, equip, portal, fight, dash, heal, hunt, roll five times, buy a skill, kill an elite, forge.
- First roll **guaranteed Rare** with a big "FIRST BLADE: RARE!" reveal.
- Tutorial-safe combat: fight-step enemies at 0.5x health and 0.3x damage, about 26 studs ahead of the player; a tutorial elite at 4x health and 0.4x damage of the zone average (normal elites were 12x and 1.5x); tutorial enemies only targeted their own player.
- Bigger rewards (3,850 cash across steps, 2,000 at the finale, a 10-roll luck charm, 45 gems).
- Funnel logged with `AnalyticsService` onboarding steps.

**What the live 7-day funnel showed**: drops of 31% at the fight step and 34% at the forge step, and 82% at the elite ("boss") step. Several steps also had bugs: the elite step depended on a system that had been switched off, so it could never complete.

### Version C: three steps, no combat
After a full playtest ("its screwed up entirely"), the tutorial was cut to the **absolute basics on the hub**: roll, equip, buy one upgrade, then bold "TUTORIAL COMPLETE!" text and a trail to the first gate. Full run about 16 to 18 seconds. Combat was left for the player to discover. The forge step was cut because forge materials only dropped in combat.

### Version D: seven steps that teach the economy
The designer then specified an exact sequence: roll (forced to a plain Common), equip it yourself in the backpack, roll again (forced to the weakest Common), **salvage** that weaker weapon, **forge** the first one with the salvaged material, open quests, claim a quest.
- A daily quest "Upgrade any weapon 1 time" is **placed first in the new player's daily list**, so the forge step completes a quest and the claim step pays immediately. That is a neat trick: the tutorial teaches the quest system by finishing a real quest.
- A persistent top banner "Step n/7" sits under the top bar.
- A **roll gate**: profiles that have never rolled a Rare roll only Commons for their first 60 to 240 seconds, and luck consumables are not spent during that window, because players were "progressing way too fast".

### Version E: a goal chain after the tutorial, plus one combat step
Players still reported feeling "thrown in the game without knowing what to do" after the tutorial. Two changes:
- A **Next Goal chain** of 35 goals read from the save: walk into the first zone, defeat 5 enemies, then for each gate: earn the rebirth requirement and rebirth (when that gate needs rebirths), earn the gate price, open it; defeat the realm boss; enter the second realm; and so on to the final boss. Each goal pays once (gate goal: 5% of the gate's cost plus 5+g gems; rebirth n: 10+2n gems; first kills: $300 + 5 gems; first walk-in: $150; bosses: 50 or 100 gems), shows a progress bar, draws a trail to its target, and holds the finished bar for 2.5 s before the next goal slides in.
- One short combat step was added back to the tutorial: "defeat 3 enemies".

### Lessons
1. **Every combat step is a funnel risk.** Combat has failure states; the hub steps do not. Teach the economy on safe ground first, then one tiny fight.
2. **Teach the verbs players will not discover alone.** Rolling is obvious; salvage-then-forge is not. Version D's value was teaching the hidden loop.
3. **The tutorial should finish a real goal**, not a fake one: the pre-seeded quest.
4. **The end of the tutorial needs a successor.** Without a goal chain, "TUTORIAL COMPLETE" is where players stall.
5. **A guaranteed great first pull vs a modest one** is a genuine trade-off. Rare-first feels generous but shows the top of the early ladder too soon; Common-first leaves room to climb. The project changed its mind; measure it in your own game.
6. **Rename and migrate steps** when the tutorial changes. Players saved mid-tutorial under the old version must map to a valid new step. The reference project kept a "renamed" table (old combat steps map to the nearest new step) so nobody got stuck.

---

## 7. Implementation: a server-side onboarding state machine

Keep onboarding state on the server, in the player's profile, and replicate one value to the client. The client only draws pointers.

```lua
--!strict
-- ServerScriptService/Onboarding (ModuleScript)
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")

export type Step = {
	id: string,
	text: string,     -- may contain device tokens like {ATTACK}
	goal: number,     -- how many signals complete it
	signal: string,   -- which gameplay signal counts
	reward: number?,  -- cash paid on completion
}

export type State = {
	step: number,     -- index into STEPS; #STEPS + 1 means done
	progress: number,
	done: boolean,
}

local STEPS: { Step } = {
	{ id = "roll",    text = "{ROLL} to get your first blade!",  goal = 1, signal = "Rolled",   reward = 100 },
	{ id = "equip",   text = "Open your BACKPACK and equip it!", goal = 1, signal = "Equipped" },
	{ id = "upgrade", text = "Press FORGE to power up!",         goal = 1, signal = "Forged",   reward = 250 },
	{ id = "hunt",    text = "{ATTACK} to defeat 3 enemies!",    goal = 3, signal = "Kill" },
}

-- Old step ids that were removed map to the nearest current step.
local RENAMED: { [string]: string } = { dash = "hunt", heal = "hunt", portal = "hunt" }

local Onboarding = {}

local function publish(player: Player, state: State)
	local s = STEPS[state.step]
	player:SetAttribute("OnboardingJson", HttpService:JSONEncode({
		done = state.done,
		index = state.step,
		total = #STEPS,
		id = s and s.id or "done",
		text = s and s.text or "",
		progress = state.progress,
		goal = s and s.goal or 0,
	}))
end

-- Call once after the profile loads. `saved` is the table stored in the profile.
function Onboarding.load(player: Player, saved: { stepId: string?, progress: number?, done: boolean? }?): State
	local state: State = { step = 1, progress = 0, done = false }
	if saved then
		if saved.done then
			state.done = true
			state.step = #STEPS + 1
		elseif saved.stepId then
			local id = RENAMED[saved.stepId] or saved.stepId
			for i, s in STEPS do
				if s.id == id then
					state.step = i
					state.progress = saved.progress or 0
					break
				end
			end
		end
	end
	publish(player, state)
	return state
end

-- Gameplay systems call this ("Rolled", "Kill", ...). Unknown or off-step signals are ignored.
function Onboarding.signal(player: Player, state: State, signal: string, pay: (Player, number) -> ())
	if state.done then return end
	local s = STEPS[state.step]
	if not s or s.signal ~= signal then return end

	state.progress += 1
	if state.progress >= s.goal then
		-- Log each step once. Steps are numbered from 1 in order.
		AnalyticsService:LogOnboardingFunnelStepEvent(player, state.step, s.id)
		if s.reward then pay(player, s.reward) end
		state.step += 1
		state.progress = 0
		state.done = state.step > #STEPS
	end
	publish(player, state)
end

function Onboarding.serialize(state: State): { stepId: string?, progress: number, done: boolean }
	local s = STEPS[state.step]
	return { stepId = s and s.id or nil, progress = state.progress, done = state.done }
end

return Onboarding
```

Design points in that code:
- **Step ids, not indices, are saved.** Inserting a step does not shift everyone's progress.
- **Signals, not polling.** The roll service calls `signal(player, state, "Rolled", pay)`. Nothing scans the world every frame.
- **One replicated value** (`OnboardingJson`) drives the pointer, the banner and the HUD reveal on the client.
- **Funnel step numbers are stable.** If you reorder steps, start a new named funnel (the reference project used versioned names like `Tutorial_v4`, `Tutorial_v5`) with `LogFunnelStepEvent` so old and new data do not mix.

### Device-aware text
Tutorial text must name the right control. A token like `{ATTACK}` should become "Click", "Tap" or the gamepad button. The reference project shipped wrong keybind text for a while (it said Z and X when the keys were 1 and 2), which is the kind of bug only a fresh player notices. Resolve tokens on the client:

```lua
--!strict
-- Client: replace device tokens in onboarding text.
local UserInputService = game:GetService("UserInputService")

local TOKENS = {
	Keyboard = { ATTACK = "Click", ROLL = "Press ROLL" },
	Touch    = { ATTACK = "Tap",   ROLL = "Tap ROLL" },
	Gamepad  = { ATTACK = "Press R2", ROLL = "Press X" },
}

local function deviceKind(): "Keyboard" | "Touch" | "Gamepad"
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then return "Touch" end
	if last.Name:match("^Gamepad") then return "Gamepad" end
	return "Keyboard"
end

local function render(text: string): string
	local map = TOKENS[deviceKind()]
	return (text:gsub("{(%u+)}", function(key: string)
		return map[key] or key
	end))
end

-- Re-render when the player switches device mid-step.
UserInputService.LastInputTypeChanged:Connect(function()
	-- call your banner's refresh here, which uses render()
end)
```

Match the gamepad labels to your real bindings; see [[Gamepad and Console UX]] and [[Input - UserInputService and ContextActionService]].

---

## 8. Returning players, skips and edge cases

| Case | What goes wrong | Handle it by |
|---|---|---|
| Player leaves mid-tutorial | Rejoins on a step whose world state is gone (no enemy, closed panel) | Every step must be re-enterable from a fresh join |
| Experienced player on an alt | Forced through steps they know | A clear Skip button (with a confirm) that grants the finale rewards |
| Two tutorial players in one server | They steal each other's targets | Per-player tutorial targets (the reference project tagged tutorial enemies with their owner) |
| Tutorial changes after launch | Old saves point to removed steps | A renamed-steps table and a one-time migration flag |
| Player completes a step's action early | Signal arrives before the step | Either accept "already done" checks on entering a step, or keep steps strictly ordered and cheap |
| Death during the tutorial | Long respawn breaks the flow | Short respawn and a tip; the reference project showed "Back on your feet in N" plus a dodge tip |
| Monetisation prompts during onboarding | Feels predatory, breaks focus | No purchase prompts until the tutorial is done; see [[Ethical Design and Player Trust]] |

---

## 9. Common mistakes

| Mistake | Better |
|---|---|
| Text walls ("Welcome to the world of...") | One line, one target, one pointer |
| Teaching every system up front | Teach the core loop; teach the rest just in time |
| Combat in the first 20 seconds with full-strength enemies | Weakened, owned tutorial enemies, or no combat until the loop is clear |
| A finale that is just text | A real reward and the next goal |
| Pop-ups stacking on the first join | One gate rule for all automatic pop-ups |
| Tutorial that cannot be skipped | Skip with confirmation for experienced players |
| Measuring nothing | Onboarding funnel events on every step, compared by version |
| Shipping tutorial changes untested | Play the whole tutorial on a phone-sized viewport after every change |

---

## 10. Checklist

- [ ] Control within about 10 s of join; no unskippable cutscene.
- [ ] First verb by 30 s, first big reward by 40 s.
- [ ] Core loop closed three or more times in 5 minutes.
- [ ] One goal on screen at a time; pointer targets exact.
- [ ] HUD reveal driven by one onboarding state.
- [ ] Tutorial-safe combat (or none) in the first minutes.
- [ ] Purchases the tutorial asks for are guaranteed affordable.
- [ ] Moment of joy at the end, then a next-goal chain.
- [ ] Device-correct control text on PC, phone and gamepad.
- [ ] Funnel events per step, versioned when steps change.
- [ ] Mid-tutorial rejoin, skip, and death all tested.

## See also
- [[Core Loops and Session Design]], [[Retention and Return Hooks]], [[Progression and Pacing Design]]
- [[HUD Design]], [[Menu Archetypes - Shop Settings Codes Rewards]], [[UI and GUI Animation]], [[Responsive UI for Phone Tablet Console and PC]]
- [[Quests and Objectives]], [[Analytics and Funnels]], [[Discovery and the Algorithm]]
- [[Case Study - Fast Join and Deferred Loading]], [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Onboarding Funnel]] · [[Teaching Through Level Design]] · [[Simulator and RNG Genre Teardown]] · [[Core Loop]] · [[Quest Writing and Hooks]] · [[Progression Levels and Unlocks]]
<!-- auto-links:end -->
