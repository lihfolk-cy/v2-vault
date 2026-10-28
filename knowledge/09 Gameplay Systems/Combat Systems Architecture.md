---
tags: [gameplay, combat, architecture, damage, knockback, guard, parry, server-authority]
---
# Combat Systems Architecture

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Damage computed on the client -> Server computes from server stats
> - Avoid: Several damage paths -> One core, one `hurt`
> - Avoid: Multipliers applied in random order -> Fixed, tested order
> - Intents in, results out; every remote validated and rate-limited.
> - One damage core and one player-damage entry point.
> - Reactions have immunity windows after hard control.
>
> Read more (15 KB note): ## 3. The damage pipeline · ## 4. Reactions: stagger, knockback, guard break · ## 8. Common mistakes · ## Checklist
<!-- tldr:end -->

A combat system is not a damage function. It is a pipeline that starts with a button press on one client, produces instant feedback there, is validated and resolved on the server, changes state on several bodies, and ends with reactions, rewards, quests and analytics on many clients. When the pipeline is not explicit, every new feature (a shield, a crit, a dodge, a tutorial safety rule) is bolted onto whichever script was nearest, and the game ends up with three damage paths that disagree. This note describes a structure that held up in one live action game, with its real numbers, and the failure modes it ran into.

Detail notes: [[Hitboxes and Hit Detection]], [[NPC AI and Behaviour]], [[Custom Character Controllers]]. Animation side: [[Weapon and Combat Animation]], [[Combat Combo Systems]], [[Hit Reactions Stagger and Hit-Stop]], [[Ability Kits Architecture]].

Source labels: **Docs**, **Measured** (the reference project), **Rule of thumb**.

---

## 1. The pipeline

```
Client input ─► Client feedback (anim, trail, sound, provisional hit FX)
     │
     └─► Remote: "Swing segment 2" / "Dash dir" / "Cast ability 3 at P"
              │
Server: rate/permission checks ─► schedule hit at data time ─► query targets
              │
         Damage pipeline (dealt mods ─► taken mods ─► apply) ─► reactions
              │                                          (stagger, knockback, KO)
              └─► Kill? ─► reward payload ─► quests, drops, analytics
              │
Server ─► Clients: confirmed hits, numbers, deaths (reliable); VFX hints (unreliable)
```

Each box is one module with one owner. The rules that made this work:

1. **One damage core.** Swing damage, ability damage, hazards, PvP and boss hits all call the same functions for "dealt" and "taken" modifiers. **Measured:** the reference project grew a legacy combat service, a newer enemy service and an event boss fight; it pulled the shared maths into a `CombatCore` module and a `CombatReward` payload so kills paid identically whichever system ran the fight.
2. **One player-damage entry point.** Every blow on a player goes through one `hurt` function that checks dash i-frames, then guard/parry, then multipliers, then applies. New rules (boss dodge windows, tutorial damage reduction, freeze immunity) were one-line changes there.
3. **Data, not code, for numbers.** Reach, hit times, cooldowns, crit, stagger thresholds and knockback live in a config module that designers can edit live ([[Global State and Live Config]]).
4. **Server decides consequences; the owner applies physics.** The server decides knockback on a player; the player's client applies it ([[Physics Assemblies and Constraints]] section 4).

### Do not let one script own everything
**Measured, as a warning.** The reference project's original combat service grew to about 199,700 characters, at the 200,000-character script source limit. From then on every change had to delete as much as it added, comments were moved into a separate notes module, and new features had to live elsewhere. Split by responsibility before a script passes about 50 KB: brain, attacks, spawner, rewards, world queries, fighters (bodies), each a ModuleScript ([[Module Scripts and Requiring]]).

---

## 2. Remotes and messages

| Message | Direction | Type | Contents |
|---|---|---|---|
| Swing | C to S | RemoteEvent | segment index, client time (optional), facing |
| Dash | C to S | RemoteEvent | direction |
| Guard | C to S | RemoteEvent | boolean held |
| Ability | C to S | RemoteEvent | slot, aim point |
| Hit confirmed / damage numbers | S to C | RemoteEvent | target, amount, crit, kind |
| Blood, sparks, enemy FX hints | S to C | UnreliableRemoteEvent | position, kind |

Principles:
- Clients send **intents** (I swung, I want to dash here), never results (I dealt 500).
- Validate every argument: type, range, NaN, permission, plausibility ([[Server Authority and Validation]]).
- Cosmetic broadcasts are unreliable and distance-filtered. **Measured:** the reference project filtered per-hit broadcasts (blood FX, hit sounds, projectile positions) to players within 320 studs during a performance pass after "immense lag" reports ([[Network Performance]]).
- Rate-limit with a bank, not a hard refusal ([[Hitboxes and Hit Detection]] section 3).

---

## 3. The damage pipeline

### Dealt side (attacker)
Order matters when multipliers clamp. A typical order from the reference project:

| Step | Example values (measured) |
|---|---|
| Base damage | From the weapon's Power stat (by rarity tier) |
| Move multiplier | Swing segment, or ability move/ult multipliers (e.g. Legendary 2.0 / 4.2, Eternal 2.8 / 8.2) |
| Upgrades | Forge level (+15/30/50%), fusion stars (+10% per star), skill tree "ability power" (+70% over a branch) |
| Archetype trait | "Executioner" +25% vs targets under 30% health; "Momentum" +5% per hit on the same enemy up to +20% within 2.5 s |
| Element counter | Attacker element strong against target element |
| Temporary buffs | Potions, a damage-buff ability capped at 1.5x for 12 s |
| Crit | Base 5%, multiplier 2x, crit chance capped at 60% |
| Safety clamp | A maximum multiplier on ability hits |

### Taken side (victim)

| Step | Example values (measured) |
|---|---|
| Invulnerability | Dash i-frames; 0.40 s vs boss-class attacks |
| Guard / parry | Parry window 0.26 s after raising guard: no damage and the enemy is stunned 2.2 s; held block takes 25% damage; guard re-arms after 0.55 s |
| Defensive trait | "Bulwark" takes 15% less from enemy hits |
| Context | Tutorial: 35% damage from enemies not assigned to that player |
| Apply | Fight health, KO at 0 (4 s), or real death |

```lua
--!strict
-- Minimal two-sided damage core. Each modifier is a pure function; order is explicit.
export type HitContext = {
	attacker: any,
	target: any,
	base: number,
	kind: "swing" | "ability" | "hazard" | "pvp",
	isCrit: boolean,
	tags: { [string]: boolean },
}

export type Modifier = (ctx: HitContext, amount: number) -> number

local Core = {}
Core.dealt = {} :: { Modifier }
Core.taken = {} :: { Modifier }

local MAX_MULT = 50

function Core.resolve(ctx: HitContext): number
	local amount = ctx.base
	for _, m in Core.dealt do
		amount = m(ctx, amount)
	end
	amount = math.min(amount, ctx.base * MAX_MULT)
	for _, m in Core.taken do
		amount = m(ctx, amount)
		if amount <= 0 then
			return 0 -- i-frames or parry ended it; later modifiers do not resurrect it
		end
	end
	return math.max(0, amount)
end

return Core
```

Register modifiers at startup in a fixed order and write a test per modifier. Keep the numbers in config, not inside the functions.

### The ability damage floor
**Measured.** Abilities with long cooldowns sometimes dealt less per cast than spamming basic swings for the same time, so players ignored them. The reference project added a server-side floor: each move learns its per-cast damage to its main target, and if that is below what basic swings would deal in `max(0.45 * cooldown, 1.2 * animation length)` it is scaled up (never down, at most 6x). PvP, the event boss and the stance strike are excluded. The lesson is general: **compare every ability against the basic attack over the same time window**, and fix the outliers in data or with a floor ([[Balancing with Spreadsheets and Data]]).

---

## 4. Reactions: stagger, knockback, guard break

| Reaction | Reference values (measured) | Notes |
|---|---|---|
| Stagger | At 75%, 50%, 25% health; 1.6 s, bosses 0.9 s; hit clip at 0.5x speed | Health thresholds read as progress; poise systems read as skill |
| Knockback | Config value 2.6 (relative strength) | Server decides; owner applies |
| Parry stun | 2.2 s on the enemy | Big reward for a 0.26 s window |
| Freeze | 1.2 s, then 2 s immunity | Always add immunity after hard control |
| KO | 4 s (PvE body), 3 s in PvP plus 2 s shield | Shields after respawn stop spawn-camping |

### Knockback done right

```lua
--!strict
-- Server: decide knockback, then apply on the owner.
local KnockbackRemote = game:GetService("ReplicatedStorage"):WaitForChild("Knockback") :: RemoteEvent

local function knockback(target: Model, from: Vector3, strength: number)
	local root = target.PrimaryPart
	if not root then return end
	local dir = (root.Position - from) * Vector3.new(1, 0, 1)
	dir = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.xAxis
	local velocity = dir * strength * 20 + Vector3.new(0, strength * 8, 0)

	local player = game:GetService("Players"):GetPlayerFromCharacter(target)
	if player then
		KnockbackRemote:FireClient(player, velocity) -- the owner applies it
	else
		root:ApplyImpulse(velocity * root.AssemblyMass) -- server-owned NPC
	end
end
```

```lua
--!strict
-- Client: apply knockback to the local character.
local Players = game:GetService("Players")
local KnockbackRemote = game:GetService("ReplicatedStorage"):WaitForChild("Knockback") :: RemoteEvent

KnockbackRemote.OnClientEvent:Connect(function(velocity: Vector3)
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = hum and hum.RootPart
	if not (hum and root) then return end
	hum:ChangeState(Enum.HumanoidStateType.Freefall) -- stop Running from pinning us down
	root.AssemblyLinearVelocity = velocity
end)
```

For mover-driven NPCs, knockback is a goal: push the move goal back along the hit direction and let the mover glide there. **Measured:** the reference project's enemy navigation pushes every goal, including knockback, out of tree trunks and arena holes, so knockback never parks an enemy inside a tree.

### When to remove a mechanic
**Measured.** The reference project shipped guard and parry, then switched the player guard off by config (`PlayerGuard = false`). Its quest system had "parry N attacks" quests; with the mechanic gone those quests became impossible. The fix retired those quest definitions while the flag is off and swapped any already in saves for a fresh quest of the same difficulty (paying out finished-but-unclaimed ones first). **Every mechanic has dependents** (quests, tutorials, achievements, UI hints, analytics); a feature flag must reach them all ([[Quests and Objectives]]).

---

## 5. Engagement rules

Who fights whom is as much design as damage:
- **Enemies only engage armed players.** The reference project's enemies ignore players without a weapon equipped, so hub visitors and AFK players are never chased.
- **Zone ownership.** An enemy drops its target as soon as the target leaves the enemy's zone (plus a leash range, 200 studs). This stops trains of enemies following players across the map.
- **Engage guard.** On aggro an enemy performs a quick "pounce" attack, and a short engage guard prevents it being killed before it reacts, so even strong players see it fight back.
- **Tutorial shield.** During onboarding steps, only the enemy assigned to that new player may target them (unless they attacked another in the last 5 s), and others deal 35% damage.
- **Open boss arenas.** Mini-bosses fight in the open; walking away makes them walk home and reset after 20 s, and nobody outside can damage them. The final boss keeps a sealed arena.

See [[NPC AI and Behaviour]] for aggro and targeting.

---

## 6. Kills and rewards

The kill is where combat hands over to progression. One payload, built on the server, consumed by many listeners:

```lua
--!strict
export type KillPayload = {
	killer: Player,
	assisters: { Player },
	enemyId: string,
	zone: number,
	rank: "Basic" | "Elite" | "Boss",
	isRare: boolean,
	position: Vector3,
}
```

Listeners: currency, XP, pet XP, quest progress, potion ingredient drops, materials, fragments, bestiary, analytics. **Measured:** the reference project's `CombatReward` used the same payload for its legacy and new combat services; when a new service forgot to fire the blood/kill effects event, kills were silent until it was wired to the same path. Make the payload the *only* way kills are announced.

Rules of thumb:
- **Kill credit** goes to the player with the most damage or the last hit, with assists for anyone over a threshold (10 to 20% of max health). Pay assists something, or groups fight over last hits.
- **Anti-farm in PvP.** **Measured:** at most 2 paid kills per victim per minute in the reference project's arena.
- **Rare spawns** pay more: zone top level +3, 1.35x size, a "RARE" tag and 3x drops, replaced by a fresh roll on death (measured). See [[RNG Drops and Luck Systems]].

---

## 7. PvP specifics

PvP breaks assumptions PvE can make:
- **Normalise.** A player with a weapon 1,000x stronger one-shots everyone. The reference project's arena deals damage as a percentage of the victim's fight health, so skill matters more than inventory.
- **Both sides are client-owned.** Hit validation uses rewind or tolerance for both ([[Hitboxes and Hit Detection]]).
- **Spawn protection** after respawn (2 s shield measured) and respawn points away from the killer (an alcove is kept unless someone is within 24 studs).
- **Teams and friendly fire** checks belong in the damage core, not in each weapon ([[Spawning Teams and Rounds]]).

---

## 8. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Damage computed on the client | One-shot exploits | Server computes from server stats |
| Several damage paths | Shields work on swings, not on abilities | One core, one `hurt` |
| Multipliers applied in random order | Inconsistent crit and clamp results | Fixed, tested order |
| Server applies knockback to players | Late or missing | Owner applies |
| Removing a mechanic by deleting code | Impossible quests, broken tutorials | Feature flag reaching all dependents |
| Abilities weaker than swinging | Abilities ignored | Compare per time window; floor |
| Huge single script | Can no longer edit it | Split by responsibility early |

## Checklist
- [ ] Intents in, results out; every remote validated and rate-limited.
- [ ] One damage core and one player-damage entry point.
- [ ] Reactions have immunity windows after hard control.
- [ ] Kill payload is the single announcement of kills.
- [ ] PvP normalised, with spawn protection and anti-farm.
- [ ] Each mechanic's dependents listed so a flag can turn it off cleanly.

## See also
[[Hitboxes and Hit Detection]] · [[NPC AI and Behaviour]] · [[Progression Levels and Unlocks]] · [[Economies and Currencies]] · [[Genre Playbook - Combat and RPG]] · [[Weapon and Combat Animation]] · [[Ability Kits Architecture]] · [[Exploits and Anti-Cheat]] · [[Post-Mortem - Building a Melee Action Game]]

## Connected notes
<!-- auto-links:start -->
[[Genre Playbook - Battlegrounds and Arena Fighters]] · [[Status Effects Buffs and Stacking Rules]] · [[Melee Combat System End to End]] · [[Boss Fight Design Patterns]] · [[Case Study - Enemy Roster Rebuild]] · [[Detecting Combat Exploits - Reach Rate and Aim]]
<!-- auto-links:end -->
