---
tags: [gameplay, quests, objectives, dailies, tutorial, story, type/guide, area/gameplay, level/intermediate]
---
# Quests and Objectives

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Quest code inside combat code -> Signal bus
> - Avoid: Rewards computed at claim -> Freeze at deal
> - Avoid: Client time for resets -> Server UTC keys
> - Definitions in data with permanent ids; kinds driven by a signal bus.
> - Rewards frozen at deal; scale with progress.
> - UTC period keys; rerolls and a weekly track.
>
> Cost: TL;DR ~120 tok · whole note ~3.6k tok. Read more: ## 2. Driving progress: a signal bus · ## 3. Dealing dailies and weeklies · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Quests turn a sandbox into a sequence of goals. On Roblox they come in three shapes: **onboarding steps** (a scripted sequence for new players), **story beats** (one-off objectives tied to the world: talk to this NPC, defeat this boss, open this gate) and **repeatable quests** (dailies and weeklies that bring players back). All three share the same machinery: a definition, progress counters driven by game events, a completion check, a reward, and UI that says what to do next. This note covers that machinery, the data design that keeps it maintainable, and the production lessons from one game's daily/weekly system and tutorial rewrites.

Related: [[Progression Levels and Unlocks]], [[Economies and Currencies]], [[First-Time User Experience and Onboarding]], [[Retention and Return Hooks]], [[HUD Design]].

Source labels: **Docs**, **Measured** (the reference project), **Rule of thumb**.

---

## 1. The core model

```lua
--!strict
export type QuestDef = {
	id: string,            -- stable forever; saves reference it
	kind: string,          -- what counts: "Kills", "EliteKills", "Rolls", "Forges", ...
	family: string,        -- grouping for variety rules: "Combat", "Rolling", "Crafting"...
	difficulty: "Easy" | "Medium" | "Hard",
	goal: number,
	match: { [string]: any }?, -- optional filter: zone, rarity, enemy rank
	eligible: ((profile: any) -> boolean)?, -- e.g. needs zone 7 unlocked
	reward: (profile: any) -> { [string]: number }, -- computed when dealt
}

export type QuestState = {
	id: string,
	progress: number,
	goal: number,
	reward: { [string]: number }, -- frozen at deal time
	claimed: boolean,
}
```

Three design rules:
1. **Kinds are events, quests are numbers.** "Kill 20 enemies in the third zone" is kind `Kills`, goal 20, match `{zone = 3}`. New quests are data; new kinds are code (an event hook).
2. **Ids are permanent.** A save holds quest ids for days. Renaming or deleting a definition must be handled by a migration (section 6).
3. **Freeze the reward when the quest is dealt.** If rewards are computed at claim time from current progress, players delay claiming to inflate them, and rebalancing changes quests already on the board.

**Measured.** The reference project's quest rewards are fixed when dealt: cash is a share of the price of the player's *next* gate (plus a floor), materials are of the player's current zone tier. This scales rewards with progress automatically, so a late-game player's daily is still worth doing.

---

## 2. Driving progress: a signal bus

Quest code must not be sprinkled through combat, rolling and crafting code. Each system reports a fact once to a small bus; the quest service (and achievements, analytics, tutorial) listen.

```lua
--!strict
-- ServerScriptService/Signals (ModuleScript)
type Listener = (player: Player, kind: string, amount: number, info: { [string]: any }?) -> ()

local Signals = {}
local listeners: { Listener } = {}

function Signals.listen(fn: Listener): () -> ()
	table.insert(listeners, fn)
	return function()
		local i = table.find(listeners, fn)
		if i then table.remove(listeners, i) end
	end
end

function Signals.report(player: Player, kind: string, amount: number?, info: { [string]: any }?)
	for _, fn in listeners do
		task.spawn(fn, player, kind, amount or 1, info)
	end
end

return Signals
```

Combat calls `Signals.report(killer, "Kills", 1, {zone = 3, rank = "Elite"})`; the roll service reports `Rolls` and `RareRolls`; crafting reports `Forges`, `Salvage`, `Brews`. **Measured:** the reference project grew to 30 quest kinds in 8 families with hooks tagged in the roll, guard, ability, critter, potion, skill tree, event boss and enemy reward services, all reporting through one signal function. Adding a kind meant one `report` call in the owning system.

`task.spawn` isolates listeners: an error in the quest listener cannot break the kill that reported it.

### Quest service listener

```lua
--!strict
local function matches(match: { [string]: any }?, info: { [string]: any }?): boolean
	if not match then return true end
	if not info then return false end
	for k, v in match do
		if info[k] ~= v then return false end
	end
	return true
end

local function onSignal(profile: any, defsById: { [string]: any }, kind: string, amount: number, info: { [string]: any }?): boolean
	local changed = false
	for _, q in profile.Quests.Active do
		local def = defsById[q.id]
		if def and def.kind == kind and not q.claimed and q.progress < q.goal and matches(def.match, info) then
			q.progress = math.min(q.goal, q.progress + amount)
			changed = true
		end
	end
	return changed -- caller pushes the new state to the client and marks the profile dirty
end
```

---

## 3. Dealing dailies and weeklies

### Reset times
Use UTC boundaries computed from `os.time()` on the server: daily at 00:00 UTC, weekly on Monday 00:00 UTC (as in the reference project). Store the period key (`"2026-10-26"`, `"2026-W44"`) with the dealt quests; on load, a different key means "deal fresh". Never trust client time.

```lua
--!strict
local function dayKey(t: number): string
	return os.date("!%Y-%m-%d", t) :: string
end

local function weekKey(t: number): string
	-- Monday-based week: shift so Monday 00:00 UTC starts a new key.
	local days = math.floor(t / 86400)
	local mondayIndex = math.floor((days + 3) / 7) -- 1970-01-01 was a Thursday
	return "W" .. mondayIndex
end
```

### Variety rules
**Measured.** The reference project's pool held 55 daily and 33 weekly definitions over 30 kinds in 8 families. Each period deals 3 cards: one Easy, one Medium, one Hard (weeklies by difficulty), with no repeated kind or family and only quests eligible for the player's progress (a "defeat bosses" quest needs the boss zone unlocked: 7 gates in one version). Rules like these stop "kill 10 / kill 20 / kill 30" boards.

```lua
--!strict
local rng = Random.new()

local function deal(pool: { any }, profile: any, difficulties: { string }): { any }
	local usedKinds, usedFamilies = {}, {}
	local out = {}
	for _, diff in difficulties do
		local candidates = {}
		for _, def in pool do
			if def.difficulty == diff and not usedKinds[def.kind] and not usedFamilies[def.family]
				and (not def.eligible or def.eligible(profile)) then
				table.insert(candidates, def)
			end
		end
		if #candidates > 0 then
			local def = candidates[rng:NextInteger(1, #candidates)]
			usedKinds[def.kind] = true
			usedFamilies[def.family] = true
			table.insert(out, { id = def.id, progress = 0, goal = def.goal, reward = def.reward(profile), claimed = false })
		end
	end
	return out
end
```

### Rerolls and meta-progress
- **Rerolls:** one free per day and per week, then a premium-currency cost (15 and 40 gems measured). Rerolls let players skip quests they dislike without making the board feel random.
- **Quest points:** completing quests fills a weekly track with chests (measured: easy 1, hard 2, weekly 4 points; chests at 4 / 10 / 18 / 28 / 38). A track converts many small goals into one big weekly goal, which is a strong return hook ([[Retention and Return Hooks]]).
- **Claiming:** a claim remote per card plus "claim all"; server re-checks completion and the `claimed` flag before paying, sets `claimed` before granting (so a double click cannot pay twice), and saves soon after.

---

## 4. Onboarding steps

The tutorial is a quest chain with stricter rules: one step at a time, the world arranged to make it succeed, and the UI pointing exactly at what to press.

**Measured history** (one production game, useful because the design went back and forth):
- A long tutorial (roll, equip, travel, fight, dash, heal, hunt, forge, elite boss) with safety rules (enemies other than the player's assigned one ignore tutorial players and deal 35% damage; a tutorial landing kept clear of other enemy groups within 140 studs; knock-outs respawn at the landing with a shield) still produced drop-off and confusion.
- Play testing led to "exclude combat from the tutorial, just go over the absolute basics": three steps, roll, equip, go through gate I, then later one more, "defeat 3 enemies", reusing the safety plumbing.
- Further rules after testing: during the tutorial only the current step's button is shown and everything outside the spotlight is blocked; proximity prompts are off until done; the first roll is plain (no golden roll or bonus pulls), after an earlier version guaranteed a Rare.
- The pointer hand jumped between buttons when the UI rebuilt; it now moves to a new target only after that target has been the best pick for 0.3 s.

Lessons:
- **Fewer, shorter steps** beat a complete tour. Teach the loop; let quests and hints teach the rest.
- **Block what you are not teaching.** If a player can open the shop during step 1, some will, and the tutorial breaks.
- **Make each step's success automatic** (safe enemies, a guaranteed outcome, a clear target) but do not lie about the game (a guaranteed Rare first roll sets an expectation the next 50 rolls break).
- **Instrument every step** with a funnel (step started, finished, time taken, deaths, stuck events) ([[Analytics and Funnels]]).

Details: [[First-Time User Experience and Onboarding]].

---

## 5. Story beats and world objectives

Story beats are one-time objectives with presentation: a quest giver NPC, dialogue, a cutscene, a boss intro.

- **Quest giver state** shown in the world: "!" when something is available, "?" when something is ready to turn in (measured: a hooded NPC with procedural idle life and a marker). Duplicate NPCs in other hubs must not share per-NPC state by accident (a copied NPC kept its original's home attribute in the reference project).
- **Dialogue** typed out, skippable, never blocking movement for long.
- **Beats as flags in the profile:** `Story = { IntroSeen = true, BossMet_Zone5 = true }`. Check flags on load to restore world state (a door that stays open, an NPC that moved).
- **Boss intros** are beats too: a cutscene the first time, a short version afterwards ([[Cameras and Cutscenes]], [[Boss Animation and Phases]]).
- **Next-goal tracker:** one line at the top of the screen saying the single next goal ("Defeat enemies to earn $ and open the next gate") with a progress bar. The reference project found a stuck-on-screen quest bubble annoying and replaced it with a compact tracker plus a "NEXT UP" goal card.

### Guiding to objectives
- A world-space trail or ground chevrons toward the target ([[World-Space UI - BillboardGui and SurfaceGui]]).
- An off-screen arrow at the screen edge pointing toward targets behind the camera, with smoothing so it does not flip when the target crosses behind you (measured fix).
- Remove guidance as soon as the objective is visible and close.

---

## 6. Changing quests in a live game

Quests are saved state; changing definitions breaks saves unless planned.

| Change | Safe approach |
|---|---|
| New quest | Add to the pool; appears next period |
| Retire a quest | Keep the id resolvable; when a save holds it, pay it out if finished-unclaimed, else swap for a fresh quest of the same difficulty |
| Rebalance goal | Applies to newly dealt quests only (state stores its own goal) |
| Remove a mechanic | Retire every quest of that kind while the feature flag is off |
| Change rewards | Frozen rewards stay; new deals use new rules |

**Measured.** When player guard/parry was switched off, the reference project's "parry" quests became impossible; the quest service dropped those definitions while the flag was off and swapped existing ones (paying finished ones first). When quests v1 was replaced by v2, finished-unclaimed v1 quests were paid out on load.

Saved arrays must be dense ("Track.Claimed is a dense bool list"); sparse tables come back from DataStores with string keys ([[Data Schema Design and Migrations]]).

---

## 7. UI and pop-up discipline

Quest UI competes with everything else for attention. Measured rules from the reference project:
- Progress shown on the HUD tracker (bar fills, "Complete!" sparkle) rather than a modal pop-up; the right-side quest tab opens instead of a random panel.
- A single gate for automatic pop-ups: never during onboarding, a panel, a roll, a cutscene, death or combat, and never within 8 s of another pop-up.
- Toasts at 25 / 50 / 75 / 100% progress are enough; per-kill toasts are noise.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Quest code inside combat code | Every new quest touches many systems | Signal bus |
| Rewards computed at claim | Inflation, rebalance chaos | Freeze at deal |
| Client time for resets | Time-travel farming | Server UTC keys |
| Deleting definitions | Broken saves | Retire with swap and payout |
| Long tutorial | Drop-off mid-way | Few basic steps, rest via quests |
| Same-kind boards | Boring dailies | Kind and family variety rules |
| Pay before marking claimed | Double claims | Mark, then grant |

## Checklist
- [ ] Definitions in data with permanent ids; kinds driven by a signal bus.
- [ ] Rewards frozen at deal; scale with progress.
- [ ] UTC period keys; rerolls and a weekly track.
- [ ] Tutorial short, blocking, instrumented.
- [ ] Retirement path for removed quests and mechanics.
- [ ] Pop-ups gated globally.

## See also
[[Progression Levels and Unlocks]] · [[Economies and Currencies]] · [[First-Time User Experience and Onboarding]] · [[Retention and Return Hooks]] · [[Analytics and Funnels]] · [[HUD Design]] · [[Data Schema Design and Migrations]] · [[Cameras and Cutscenes]]

## Connected notes
<!-- auto-links:start -->
[[Quest Writing and Hooks]] · Quest Chain System End to End · Core Loops and Session Design · [[Combat Systems Architecture]] · Official Docs - Game Systems · Menu Archetypes - Shop Settings Codes Rewards
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[RNG Drops and Luck Systems]] · [[Spawning Teams and Rounds]] · [[Tools and Inventory Systems]] · [[Status Effects Buffs and Stacking Rules]] · [[Kill Credit, Assists, Kill Feed and Death Recaps]] · [[NPC AI and Behaviour]] · [[Downed, Revive and Bleed-Out States]] · [[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]]
<!-- related:end -->
