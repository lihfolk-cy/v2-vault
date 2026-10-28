---
tags: [gameplay, combat, status-effects, buffs, debuffs, crowd-control, stacking, server-authority]
---
# Status Effects Buffs and Stacking Rules

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Effects write `WalkSpeed` or `Health` directly -> Modifiers plus one owner that recomputes
> - Avoid: Countdown timers in loops -> Absolute expiry in server time
> - Avoid: `task.delay` per effect to remove it -> One update loop; compare against current expiry
> - Every timed modifier uses one effect model with a named stacking policy.
> - Stat formula order written down: flat, percent sum, independent multipliers, clamps.
> - Movement speed and other contested properties have exactly one owner.
>
> Read more (22 KB note): ## 6. Time, ticks and edge cases · ## 8. A compact effect service · ## 9. Common mistakes · ## Checklist
<!-- tldr:end -->

Burn, poison, slow, freeze, stun, a damage potion, a rally zone, a shield that blocks four hits: status effects are small, and they are where combat code goes to rot. Each one starts as three lines ("set WalkSpeed to 10 for 3 seconds") and then two of them overlap, one expires and restores the wrong speed, a boss gets frozen for its whole phase, a potion keeps ticking while the player is offline, and a debuff survives respawn. This note gives one model for every timed modifier: how effects stack, how their numbers combine, how crowd control is limited, how time is kept, and how it replicates.

Related: [[Combat Systems Architecture]], [[Ability Kits Architecture]], [[Hitboxes and Hit Detection]], [[Characters and Humanoids]], [[Server Authority and Validation]], [[Instances Attributes and Tags]], [[HUD Design]].

Source labels: **Docs** (Roblox docs as of October 2026), **Measured** (the reference project: a combat game with support abilities, armour set bonuses and potions), **Rule of thumb**.

---

## 1. One model for everything

Treat every timed modifier as an **effect instance** applied to a **target** by a **source**, described by an **effect definition**. Potions, auras, debuffs and crowd control are all the same shape; only the definition differs.

```lua
--!strict
export type Stacking =
	"Refresh"      -- one instance; re-applying resets duration
	| "Extend"     -- one instance; re-applying adds duration up to a cap
	| "Intensity"  -- one instance with a stack count; each application adds a stack
	| "Independent" -- separate instances, each with its own timer
	| "Strongest"  -- only the strongest instance applies; weaker ones wait
	| "PerSource"  -- one instance per source (each attacker's poison counts)

export type EffectDef = {
	id: string,
	stacking: Stacking,
	duration: number,
	maxStacks: number?,
	maxDuration: number?,   -- for Extend
	tickInterval: number?,  -- for damage or heal over time
	stat: string?,          -- which stat it modifies, e.g. "MoveSpeed", "DamageDealt"
	op: ("Add" | "Mul")?,   -- how it modifies the stat
	value: number?,         -- per stack
	cc: ("Slow" | "Root" | "Stun" | "Freeze")?,
	bossScale: number?,     -- multiplier on duration (or value) against bosses
	dispellable: boolean?,
	clearOnDeath: boolean?, -- default true
}

export type Effect = {
	def: EffectDef,
	sourceId: string,       -- player UserId, enemy id, "potion", "zone:RallySigil:41"
	appliedAt: number,
	expiresAt: number,      -- absolute server time
	stacks: number,
	value: number,          -- snapshotted magnitude per stack
	nextTick: number?,
}
```

Two properties of this model matter more than any detail:
- **Absolute expiry times**, not countdowns. `expiresAt = now + duration` is correct after a hitch, survives a pause in your update loop, and can be replicated once instead of every frame.
- **Effects never write the final stat directly.** They contribute modifiers; a single function computes the stat from base plus all active modifiers. This is what prevents the "expired slow restores the wrong speed" bug (section 4).

---

## 2. Stacking policies and when to use each

| Policy | Re-application does | Good for | Watch out for |
|---|---|---|---|
| Refresh | Resets the timer | Slows, marks, "in combat" flags | Permanent uptime if the source re-applies faster than the duration |
| Extend | Adds time up to `maxDuration` | Burn from many small hits | Without a cap, infinite duration |
| Intensity | Adds a stack (value x stacks), refreshes timer | Bleed, armour shred, "every hit +2%" | Stack decay rules: all at once or one at a time |
| Independent | New timer per application | Poison darts where each dart is its own DoT | Instance count explodes with fast attacks; cap it |
| Strongest | Only the best applies; others pause or tick down | Potions, auras of the same kind from several allies | Deciding whether weaker ones pause or keep counting |
| PerSource | One per attacker | Multiplayer DoTs, each player's own debuff | Kill credit and per-source caps |

**Measured** examples from the reference project:
- Potions of the same kind (luck x1.5, x2, x3) used a **Strongest** policy where only the strongest active one counted down and weaker ones **paused**, so drinking a big potion never wasted a small one. Potion effects ticked only while the player was online and were saved in the profile.
- A "supercharge" damage buff was capped at **1.5x for 12 s**: a cap on both magnitude and duration in the definition, not in the caller.
- Armour set mechanics included an **Intensity**-style stacking buff ("each ability cast +12% damage for 5 s, up to x2 stacks") and a threshold buff ("below 40% health: +25% damage, -15% damage taken") which is a **conditional modifier**, not a timed effect. Model conditionals as modifiers recomputed when the condition changes, not as effects with a duration.

### The pause-or-count decision for Strongest
| Variant | Feel | Use for |
|---|---|---|
| Weaker ones pause | Nothing is wasted; players stockpile | Consumables players paid for or crafted |
| Weaker ones count down in the background | Simple; stacking two is pointless | Auras and zone buffs |

### Intensity decay
When an Intensity effect expires, either all stacks drop (simple, harsh) or one stack drops and the timer restarts (smooth, keeps players engaged with "keep the stacks up"). Pick per effect and show it in the tooltip.

---

## 3. Combining numbers: the order of operations

The modifiers from all active effects (plus gear, passives, set bonuses) must combine in one documented order. A common, defensible pipeline (rule of thumb):

```
final = (base + sum of flat adds) * (1 + sum of percent adds) * product of independent multipliers
then clamp to [min, max]
```

- **Flat adds** first (+5 damage from a buff).
- **Percent adds** summed together (+20% Rally, +15% Warcry, +30% Bloodrage = +65%, not 1.2 x 1.15 x 1.3 = 1.79). Summing keeps many small buffs from exploding.
- **Independent multipliers** for things that should feel separate (a critical hit, a boss vulnerability window, a difficulty multiplier).
- **Clamps last.** Movement speed never below 30% of base (rule of thumb) so slows never become roots by accident; damage taken never below 10% so stacking defensive buffs cannot make a player immortal.

### Worked example: four effects at once
A player stands in an ally's Rally zone (+20% damage), has cast Bloodrage (+30% damage, +10% damage taken), an ally used Warcry (+15% damage for allies, enemies deal -20%), and the target is inside a Hex field (+20% damage taken by the target, halved against bosses). These are the reference project's measured support ability numbers.

Attacker side, percent adds summed: 1 + 0.20 + 0.30 + 0.15 = **1.65**.
Target side, Hex as a separate "damage taken" multiplier: x1.20 (x1.10 on a boss).
Against a regular enemy: base 100 becomes 100 x 1.65 x 1.20 = **198**.
If all four were multiplied independently: 100 x 1.2 x 1.3 x 1.15 x 1.2 = **215**.

The difference looks small at four effects and becomes large at ten. More importantly, the team has to *know* which formula is live. Write it at the top of the stat module and in the tooltip system.

### Dealt versus taken
Keep "damage dealt" modifiers on the attacker and "damage taken" modifiers on the victim, applied in two clearly separate steps of the damage pipeline ([[Combat Systems Architecture]] section 3). Effects like Thorn Mantle (reflect 0.6x of a hit back, throttled to once per 0.3 s per attacker: **Measured**) belong in the taken step and must not trigger on reflected damage, or two reflect effects ping-pong forever. Tag damage with its kind (`Direct`, `DoT`, `Reflect`) and let effects filter on it.

---

## 4. Movement speed: one owner

`Humanoid.WalkSpeed` is the most fought-over property in Roblox combat code. Sprint, slow, haste, carrying, a stun and a cutscene all want to set it. If two systems write it, the last writer wins and expiry restores stale values.

The fix is ownership:
- Every system writes a **modifier** (an attribute or an entry in a table): `SpeedMul_Slow = 0.6`, `SpeedMul_Haste = 1.4`, `SpeedRoot = true`.
- One controller computes `WalkSpeed` from base and modifiers whenever any modifier changes, and nobody else touches it.

**Measured:** the reference project's support abilities wrote a `SupportSpeed` attribute and a dash cooldown multiplier on the character, and the sprint controller (the single owner) read them. Enemy slows were stored as a speed multiplier on the enemy and restored by the same system that applied them.

Who runs the controller matters: player characters are usually moved by the client, so the client must compute `WalkSpeed` from server-set attributes, and the server should validate movement speed against the same formula rather than trusting the client ([[Exploits and Anti-Cheat]]). For server-owned NPCs the server computes it directly.

```lua
--!strict
-- Single owner of WalkSpeed for one Humanoid. Other systems only set attributes:
-- SpeedMul_<name> (number) and SpeedRoot_<name> (true) on the character model.
local BASE = 16
local MIN_MUL = 0.3

local function bind(character: Model, humanoid: Humanoid): RBXScriptConnection
	local function recompute()
		local mul = 1
		local rooted = false
		for name, value in character:GetAttributes() do
			if string.sub(name, 1, 9) == "SpeedMul_" and typeof(value) == "number" then
				mul *= value
			elseif string.sub(name, 1, 10) == "SpeedRoot_" and value == true then
				rooted = true
			end
		end
		humanoid.WalkSpeed = if rooted then 0 else BASE * math.max(mul, MIN_MUL)
	end
	recompute()
	return character.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Speed" then
			recompute()
		end
	end)
end

return { bind = bind }
```

Speed multipliers are multiplied here on purpose (two slows compound) and clamped; choose additive if your design prefers it, but choose once.

---

## 5. Crowd control: the effects that remove agency

Slow, root, stun and freeze take control away. They need extra rules, because stacked CC is the fastest way to make a fight unplayable for the victim, player or boss.

### Diminishing returns
After a CC ends, the same category applied again within a window has reduced duration. A typical ladder (rule of thumb): full, half, quarter, then immune for a few seconds. Track per target, per category.

```lua
--!strict
-- Diminishing returns per CC category: 1, 0.5, 0.25, then immune. Window resets after RESET seconds.
local RESET = 15
local LADDER = { 1, 0.5, 0.25, 0 }

type DR = { level: number, lastAt: number }
local state: { [any]: { [string]: DR } } = {}

local function scaleDuration(target: any, category: string, duration: number, now: number): number
	local perTarget = state[target]
	if not perTarget then
		perTarget = {}
		state[target] = perTarget
	end
	local dr = perTarget[category]
	if not dr or now - dr.lastAt > RESET then
		dr = { level = 1, lastAt = now }
		perTarget[category] = dr
	else
		dr.level = math.min(dr.level + 1, #LADDER)
		dr.lastAt = now
	end
	return duration * LADDER[dr.level]
end

local function clear(target: any)
	state[target] = nil -- on death, despawn or leave
end

return { scaleDuration = scaleDuration, clear = clear }
```

### Bosses
Bosses need CC rules of their own or a group of players freezes them for the whole fight. Options:
- **Scaled CC**: **Measured**, the reference project's freeze lasted 2 s on regular enemies and 0.5 s on bosses; its Hex debuff applied half its value to bosses. A `bossScale` field in the definition keeps this in data.
- **CC as damage to a bar**: CC fills a "stagger" or "poise" bar instead of applying directly; when the bar fills, the boss is stunned once, then the bar is locked for a while. This turns CC into a team goal rather than a lock.
- **Immune windows**: phase transitions and big attacks ignore CC. **Measured:** the reference project made boss phase-shift clips untouchable and kept bosses out of ultimate pulls entirely.

### Players as victims
Players hate losing control more than they hate losing health. Rule of thumb for PvE: no player stun longer than about 1 s from a single regular enemy, always a visible tell before it, and a short CC immunity afterwards. In PvP, diminishing returns are not optional.

---

## 6. Time, ticks and edge cases

### Ticking DoTs and HoTs
- Store `nextTick` per effect; a single update loop (5 to 10 Hz is plenty) processes all due ticks. Do not spawn a thread or `task.delay` per tick per effect; at 40 burning enemies that is hundreds of scheduled threads, and cancelling them correctly on death is error-prone.
- **Catch up correctly after a hitch**: process every tick whose time has passed (`while now >= nextTick`), with a cap, so a lag spike does not silently drop damage, and a long one does not deliver ten ticks in one frame (cap at 2 or 3 per update, rule of thumb).
- **The last partial tick.** A 5-second burn ticking every 1 s gives 5 ticks only if the first tick happens at 1 s and the last at exactly 5 s. Decide whether ticks are at `[1..5]` or `[0..4]`, and whether a refresh preserves the tick phase (it should, or rapid refreshes delay every tick forever).
- **Snapshot or dynamic?** Is a burn's damage fixed when applied (snapshot) or recomputed every tick from the attacker's current stats (dynamic)? Snapshot is simpler and cannot be gamed by swapping gear mid-burn; dynamic requires the attacker to still exist. **Rule of thumb: snapshot.** The `value` field in the model above holds the snapshot.

### Kill credit
A target that dies to a poison tick after the attacker left: who gets the reward? Record `sourceId` on the effect and credit that source if it is still in the server; otherwise credit the last direct damager. Make sure DoT kills fire the same kill pipeline as direct kills ([[Combat Systems Architecture]] section 6), or quests counting kills will miss them.

### Lifecycle events
| Event | Default handling |
|---|---|
| Death | Clear everything with `clearOnDeath` (the default); keep persistent consumables like potions |
| Respawn | New character, new Humanoid: re-bind the speed owner; re-apply persistent effects |
| Zone change or teleport within the place | Clear zone auras; keep personal buffs |
| Teleport to another place | Persist only what is saved in the profile ([[Teleporting and Multi-Place Games]]) |
| Leaving the server | Save persistent effects as **remaining duration** (not absolute time) if they should pause offline; save absolute expiry if they should run in real time |
| Source dies | Zone effects end with their zone; DoTs usually continue |

The offline decision is a design choice with consequences. Remaining-duration saving means a potion bought for "30 minutes" gives 30 minutes of play. Absolute expiry means players log in to find their purchase used up. For anything bought with Robux, pausing offline is the trustworthy choice ([[Ethical Design and Player Trust]]).

### Which clock
Use one server clock for expiry: `workspace:GetServerTimeNow()` is synchronised to clients (Docs), so a client can draw a countdown from a replicated `expiresAt` with no further messages. `os.time()` has one-second resolution and should be used only for wall-clock things like daily resets.

---

## 7. Replication and UI

The client needs to show icons, timers and stack counts, and to play looping VFX. It does not need ticks.

| Approach | Cost | Fits |
|---|---|---|
| One attribute per effect (`Effect_Burn = expiresAt`) | Simple; one replication per change | A handful of effect kinds |
| One packed attribute (JSON or buffer of all effects) | One replication per change for all effects | Many kinds, frequent changes |
| RemoteEvent on apply and remove | Most control; client keeps a mirror | Effects on other players and NPCs filtered by distance |

**Measured:** the reference project stored timed debuffs on enemy models as attributes holding an expiry in server time and a multiplier (for example a weaken effect's until-time and multiplier), which let any system and the client read them without messages.

UI rules (rule of thumb):
- Buffs and debuffs in separate rows, debuffs with a red edge.
- Sort by remaining time, show stacks as a number in the corner, show a radial sweep for duration.
- On enemies, show only debuffs the local player applied plus CC, or bars become unreadable in groups.
- Always show the CC the player is under in the centre of the screen with its remaining time. "Why can't I move?" is the most common status complaint.

See [[HUD Design]] and [[UI Design Systems]].

---

## 8. A compact effect service

```lua
--!strict
-- Server-side effect container for one target. Pair with a stat function that reads modifiers().
local Workspace = game:GetService("Workspace")

local Effects = {}
Effects.__index = Effects

export type Container = typeof(setmetatable({} :: { list: { any }, onTick: (any) -> () }, Effects))

function Effects.new(onTick: (any) -> ()): Container
	return setmetatable({ list = {}, onTick = onTick }, Effects)
end

local function find(self: Container, id: string, sourceId: string?): any
	for _, e in self.list do
		if e.def.id == id and (sourceId == nil or e.sourceId == sourceId) then
			return e
		end
	end
	return nil
end

function Effects.apply(self: Container, def: any, sourceId: string, value: number, durationScale: number?)
	local now = Workspace:GetServerTimeNow()
	local duration = def.duration * (durationScale or 1)
	if duration <= 0 then
		return -- fully diminished or immune
	end
	local mode = def.stacking
	local existing = if mode == "PerSource" then find(self, def.id, sourceId)
		elseif mode == "Independent" then nil
		else find(self, def.id, nil)
	if existing and mode ~= "Strongest" then
		if mode == "Extend" then
			local cap = now + (def.maxDuration or duration)
			existing.expiresAt = math.min(existing.expiresAt + duration, cap)
		else
			existing.expiresAt = now + duration -- Refresh, Intensity, PerSource
		end
		if mode == "Intensity" then
			existing.stacks = math.min(existing.stacks + 1, def.maxStacks or 1)
		end
		existing.value = math.max(existing.value, value)
		return
	end
	table.insert(self.list, {
		def = def, sourceId = sourceId, appliedAt = now, expiresAt = now + duration,
		stacks = 1, value = value,
		nextTick = if def.tickInterval then now + def.tickInterval else nil,
	})
end

-- Call at 5 to 10 Hz. Strongest-policy pausing is left out for brevity.
function Effects.update(self: Container)
	local now = Workspace:GetServerTimeNow()
	for i = #self.list, 1, -1 do
		local e = self.list[i]
		local ticks = 0
		while e.nextTick and now >= e.nextTick and e.nextTick <= e.expiresAt and ticks < 3 do
			self.onTick(e)
			e.nextTick += e.def.tickInterval
			ticks += 1
		end
		if now >= e.expiresAt then
			table.remove(self.list, i)
		end
	end
end

-- Sum of percent adds per stat; Strongest keeps only the best value per id.
function Effects.modifiers(self: Container): { [string]: number }
	local best: { [string]: any } = {}
	local out: { [string]: number } = {}
	for _, e in self.list do
		local d = e.def
		if d.stat then
			if d.stacking == "Strongest" then
				local b = best[d.id]
				if not b or e.value > b.value then
					best[d.id] = e
				end
			else
				out[d.stat] = (out[d.stat] or 0) + e.value * e.stacks
			end
		end
	end
	for _, e in best do
		out[e.def.stat] = (out[e.def.stat] or 0) + e.value * e.stacks
	end
	return out
end

function Effects.clear(self: Container, predicate: ((any) -> boolean)?)
	for i = #self.list, 1, -1 do
		if not predicate or predicate(self.list[i]) then
			table.remove(self.list, i)
		end
	end
end

return Effects
```

What this leaves to you: the pausing variant of Strongest (store remaining time on paused instances and only advance the active one), replication (write a packed attribute after `apply`, `update` removals and `clear`), and persistence for consumables.

---

## 9. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Effects write `WalkSpeed` or `Health` directly | Wrong values restored on expiry; stuck slows | Modifiers plus one owner that recomputes |
| Countdown timers in loops | Effects last longer after lag; drift between client and server | Absolute expiry in server time |
| `task.delay` per effect to remove it | Removes the refreshed effect early; leaks on death | One update loop; compare against current expiry |
| Multiplying every percent buff | Late-game damage explodes | Sum percent adds; reserve multipliers for distinct mechanics |
| No CC rules for bosses | Groups lock bosses for whole phases | Boss scaling, poise bars, immune windows |
| No diminishing returns in PvP | Chain-stun deaths | Per-category DR ladder |
| Refresh resets tick phase | Rapid re-application delays every tick | Keep `nextTick` on refresh |
| Reflect damage triggers reflect | Infinite ping-pong | Tag damage kind; filter |
| Paid buffs expire offline | Support tickets, refunds | Save remaining duration for consumables |
| DoT kills skip the kill pipeline | Quests and rewards miss kills | One kill path with source credit |

## Checklist
- [ ] Every timed modifier uses one effect model with a named stacking policy.
- [ ] Stat formula order written down: flat, percent sum, independent multipliers, clamps.
- [ ] Movement speed and other contested properties have exactly one owner.
- [ ] Crowd control has diminishing returns, boss scaling and clear on-screen feedback.
- [ ] Expiry stored as absolute server time; ticks processed in one loop with catch-up caps.
- [ ] Death, respawn, zone change, teleport and leave each have defined effect handling.
- [ ] Offline behaviour of consumables decided and fair to paying players.
- [ ] Damage tagged by kind; reflect and DoT cannot recurse.
- [ ] Client shows CC prominently and reads timers from replicated expiry.

## See also
[[Combat Systems Architecture]] · [[Ability Kits Architecture]] · [[Boss Fight Design Patterns]] · [[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Characters and Humanoids]] · [[Hit Reactions Stagger and Hit-Stop]] · [[Exploits and Anti-Cheat]] · [[HUD Design]] · [[Balancing with Spreadsheets and Data]] · [[Economies and Currencies]]

## Connected notes
<!-- auto-links:start -->
[[Cookbook - Players and Characters]] · [[Genre Playbook - Combat and RPG]] · [[Custom Character Controllers]] · [[Case Study - Enemy Roster Rebuild]] · [[Melee Combat System End to End]] · [[Hit-Stop]]
<!-- auto-links:end -->
