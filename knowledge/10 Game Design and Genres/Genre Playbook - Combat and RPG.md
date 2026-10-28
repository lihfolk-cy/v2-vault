---
tags: [game-design, genre, combat, rpg, enemies, bosses, ttk, abilities]
---
# Genre Playbook - Combat and RPG

Combat games on Roblox range from simulator-style "click the enemy" fighting to anime ability RPGs, dungeon crawlers, open-world quest games and arena PvP. They have the highest production cost of the common genres (animation, VFX, AI, hit detection, networking) and the deepest long loops (builds, gear, mastery). This playbook covers the combat design numbers that matter (time to kill, damage budgets, telegraphs), enemy and boss design, RPG progression (levels, gear, abilities, builds), mobile combat, PvP, and the funnel risks that come with failure states. Most numbers come from one live action game, labelled as such.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one live action game, anonymised), **Rule of thumb**.

---

## 1. Why combat works, and why it is risky

| Strength | Risk |
|---|---|
| Strong verb: hitting things feels good | Feel needs animation, VFX, sound and network work |
| Natural power fantasy and progression | Failure states (death, boss walls) cause funnel cliffs |
| Builds and gear give deep long loops | Balance across many items is hard |
| Bosses are memorable shared moments | Bosses that block progress lose most players |
| Abilities and ultimates make great clips | Cinematic abilities can be expensive and buggy |

The docs' own example of a core loop is an action RPG: explore (minute to minute), fight (most repeated), upgrade (progression engine) (Docs, "Core loops").

---

## 2. Time to kill (TTK) is the master number

Every combat number derives from how long fights should last.

```
TTK (seconds) = enemy health / player DPS
hits to kill   = enemy health / damage per hit
```

Targets (rules of thumb, with the reference project's values where given):

| Enemy type | Target | Reference project |
|---|---|---|
| Regular, at the zone's expected power | 2 to 5 hits | A starter weapon kills a zone-1 regular in about **3 hits** |
| Elite | 10 to 20 s | Elites at about 2.5x to 12x regular health depending on version |
| Mini-boss | 20 to 40 s | About **25x** regular health; "short (~20 to 30 s), telegraphed, always beatable at the recommended power" |
| Region / world boss | 1 to 3 min | About **150x** regular health |

Then scale across zones:
- The reference project's revamp plan: enemy health **+~55% per zone**, coins per kill **x~1.6 per zone**, and "players outscale through rolls". A zone should take about 8 to 12 minutes.
- Because health grows 1.55x per zone, TTK stays flat only if player DPS also grows about 1.55x per zone. That growth must come from somewhere visible: better weapons, forging, upgrades. If DPS sources lag, TTK creeps up and fights feel spongy.

Put TTK in your balance sheet per zone and per enemy type; see [[Balancing with Spreadsheets and Data]].

### Damage budget by rarity
When weapons have ability kits, decide a damage multiplier per rarity so higher tiers feel stronger without breaking TTK. The reference project's kit multipliers (move / ultimate): Legendary 2.0 / 4.2, Mythic 2.2 to 2.4 / 4.8 to 4.9, Celestial 2.4 to 2.6 / 5.2 to 5.4, Divine 2.6 / 6.0, Eternal 2.8 / 8.2. Kit size also scaled with rarity (Legendary 2 moves, Mythic 2 to 3, Celestial 3, Divine 4, Eternal 5, plus a shared signature move), and only Epic or higher weapons got an ultimate. Notice how small the move multipliers' spread is (2.0 to 2.8) compared with the ultimate's (4.2 to 8.2): rarity shows mostly in the **big moment**, not in every hit, which keeps regular combat balanced.

---

## 3. Readable enemies

Fights are fair when players can **see** what is coming.

| Rule | Reference project value |
|---|---|
| Every attack has a telegraph | 0.4 to 0.8 s: glow + pose + ground marker |
| Each role has a unique silhouette | melee, ranged, tank, swarm, summoner |
| Hits react | Hit flash and stagger |
| Enemy animations never play slowed below 1x | Exception: the stagger hit at 0.5x, which reads as weight |

### Roles
| Role | Behaviour | Teaches |
|---|---|---|
| Melee | Closes in, combos | Spacing, dodging |
| Ranged | Keeps distance, telegraphed shots | Closing gaps, cover |
| Tank | Slow, armour phase, shield bash | Patience, ability timing |
| Swarm | Packs of 4 to 6, weak | Area attacks |
| Summoner | Spawns adds; priority target | Target selection |

Two roles per zone plus one mini-boss was the reference project's plan (2 regular types + 1 mini-boss per zone, one boss per world). A new enemy every zone keeps the treadmill feeling away; the later stage plan asked for "1 to 2 enemies that are new every time".

### Aggression tempo
Enemies that wait politely between attacks make combat boring; enemies that attack instantly feel unfair. The reference project tuned enemies to attack faster **only while they have a target**: first attack after 0.4 to 0.7 s, cooldowns x0.6, think time x0.4, with gentler multipliers in the starter zone (0.5), on bosses (0.5) and elites (0.75). Separating "idle tempo" from "engaged tempo" is a cheap way to make fights feel alive.

### Variants and elites
- **Variants** (the second half of each region): +15% size, +30% health, +15% damage, a tint and one extra trait (shield, enrage, speed).
- **Elites**: about 1 in 8 spawns in later zones, x2.5 health, an aura and an extra drop roll.
Both reuse existing models and animations: cheap content.

See [[NPC AI and Behaviour]], [[Enemy and NPC Animation]] and [[Enemy Animation State Protocol]].

---

## 4. Bosses without funnel cliffs

Bosses are the best moments in combat games and the most dangerous for retention. The reference project's onboarding funnel lost **82% of players at the boss step**; separately, the designer observed that "players quit at the boss fights".

What the project changed, and what generalises:

| Change | Why |
|---|---|
| Mini-boss arenas made **open**: no locked doors or seals; walk away and the fight resets after 20 s empty | Failure costs nothing; players retry when ready |
| Boss fights short (20 to 30 s for mini-bosses) and telegraphed | Short attempts are cheap to retry |
| A **Recommended Power** number on every boss gate | Players can see why they lost and what to do |
| "A boss wall should take one forge level or one better weapon to pass" | The fix is always one step away |
| Rebirth offered when stuck | The long loop is always an option |
| Bosses refightable for drops, scaling up per region | Bosses become content, not just walls |
| Boss intros as short cutscenes using the ability cinematic system | Spectacle without long waits |

Boss structure from the revamp plan: mini-bosses with 2 phases and 3 to 4 attacks; world bosses with 3 phases and 6 attacks and an intro. See [[Boss Animation and Phases]] and [[Cameras and Cutscenes]].

---

## 5. Feel: the part players judge first

Combat feel is covered in depth elsewhere; the design-level rules:
- **Input to visible response in under 100 ms.** Play the swing locally at once; the server validates the hit. See [[Combat Systems Architecture]] and [[Hitboxes and Hit Detection]].
- **Hit-stop, flash, shake and sound on every connect.** See [[Hit Reactions Stagger and Hit-Stop]] and [[Game Feel and Juice]].
- **Anticipation that matches the telegraph.** Players learn timing from animation; see [[Combat Animation Craft]] and [[Weapon Swing Design]].
- **Damage numbers** that are readable on phones and scale with crits.
- **Combos** that reward rhythm; see [[Combat Combo Systems]].
- **Ultimates** as cinematic payoffs; the reference project made all ultimates cinematic **for the caster only**, with onlookers seeing a milder version, so one player's big moment does not interrupt everyone else. See [[Cinematic Ultimates]].

---

## 6. RPG progression

| System | Design notes |
|---|---|
| Levels and XP | Polynomial XP curve (for example `XP(n) = a n^1.5 to n^2`); low early thresholds so first levels arrive fast (Docs, "Onboarding") |
| Stats | Few, readable stats (Power, Health, Speed); avoid ten tiny stats on phones |
| Gear | Rarity tiers; rarer is better; stats fitted to rarity (see [[Balancing with Spreadsheets and Data]]) |
| Upgrades | Forge levels, stars, enchantments: sinks that raise power |
| Sets | Set bonuses for wearing matching pieces; the reference project's armour: crafted sets only, 3 slots, set bonuses |
| Abilities | Unlocked by level, gear or rarity; 2 to 6 slots on the hotbar |
| Skill tree | Choices that define builds; priced in minutes of income |
| Crafting and salvage | Turn unwanted drops into materials; the reference project's salvage-then-forge loop |

### Builds
Depth comes from **choices with trade-offs**: glass cannon versus tank, area versus single target. Keep each choice readable: "+30% damage, -20% health" beats a paragraph. Let players respec cheaply; young players experiment.

### Drops
- Per-player loot (no stealing), visible rarity beams, a pickup sound per tier.
- Bosses drop guaranteed materials plus a chance at something rare; first clear pays a bonus. The reference revamp plan: mini-bosses drop fragment chances toward zone-themed weapons plus a guaranteed material bundle; gems at a 1 to 2% chance from mini-bosses, 25 gems on a world boss's first clear then 3%.
See [[RNG Drops and Luck Systems]].

---

## 7. Mobile combat

| Problem | Design answer |
|---|---|
| No precise aim | Aim assist or soft lock-on to the nearest enemy in front; the reference project's ability controller had aim assist |
| Few fingers | Attack, dodge and 2 to 4 abilities is about the limit for thumbs |
| Small screen | Big telegraphs on the ground, not only on enemy bodies |
| Performance | Enemy count caps (the reference project's plan capped live enemies at 8 per zone and about 60 per server), effect LOD |
| Interruptions | Short fights, respawn near the action |

Teach controls with device-correct labels; the reference project shipped wrong keybind text in its tutorial for a while. See [[First-Time User Experience and Onboarding]] and [[Gamepad and Console UX]].

---

## 8. Death and failure

- **Respawn fast.** The reference project respawns realm deaths at the realm's return portal and keeps progress (highest stage cleared). Its PvP arena knocks out for 3 s, then respawns in an alcove with a 2 s shield.
- **Explain the death.** A short card ("FALLEN", who or what, a tip) turns a loss into a lesson. Tutorial deaths showed "Back on your feet in N" plus a dodge tip.
- **Never take away progress for dying** in a game for young players, except in a mode that announces it (roguelike runs, hardcore).
- **Protect new players.** Tutorial enemies at reduced health and damage that only target their own player; no other enemies pulling aggro on someone mid-tutorial.

---

## 9. PvP

Opt-in PvP keeps competitive players without scaring the rest.
- **Separate space** (an arena) or a mode, never forced in the open world.
- **Normalised damage** (percent of health per hit) compresses gear gaps; the reference project's arena did this.
- **Anti-farm** caps (2 paid kills per victim per minute in the reference project).
- **Spawn protection** and multiple spawn points.
- **Matchmaking** by power for ranked modes; casual arenas can be open.
See [[Social Design and Multiplayer Play]] and [[Spawning Teams and Rounds]].

---

## 10. A server-side damage formula

Keep damage maths in one module that both the hit validator and the UI preview use.

```lua
--!strict
-- ReplicatedStorage/DamageMath (ModuleScript). Pure functions; the server applies the result.
local DamageMath = {}

export type Attack = {
	base: number,         -- weapon power
	moveMult: number,     -- e.g. 1.0 basic swing, 2.0 to 2.8 kit move, 4.2+ ultimate
	critChance: number,   -- 0..1
	critMult: number,     -- e.g. 1.5
}

export type Target = {
	armor: number,        -- flat reduction factor input
	isPlayer: boolean,
	maxHealth: number,
}

-- Armour as diminishing reduction: 100 armour halves damage, 300 quarters it.
local function armorFactor(armor: number): number
	return 100 / (100 + math.max(armor, 0))
end

function DamageMath.roll(rng: Random, a: Attack, t: Target, pvpPercent: number?): (number, boolean)
	local crit = rng:NextNumber() < a.critChance
	if t.isPlayer and pvpPercent then
		-- Normalised PvP: a fixed share of the target's max health per hit, crits still matter.
		local dmg = t.maxHealth * pvpPercent * (if crit then a.critMult else 1)
		return dmg, crit
	end
	local dmg = a.base * a.moveMult * armorFactor(t.armor)
	if crit then dmg *= a.critMult end
	return dmg, crit
end

-- Hits to kill, for balance sheets and tooltips.
function DamageMath.hitsToKill(health: number, a: Attack, armor: number): number
	return math.ceil(health / (a.base * a.moveMult * armorFactor(armor)))
end

return DamageMath
```

The diminishing armour curve (`100 / (100 + armor)`) never reaches zero damage and makes each point of armour worth a bit less than the last, which keeps tanks from becoming invulnerable. Validate every hit on the server (range, cooldown, line of sight) before calling this; see [[Server Authority and Validation]].

---

## 11. Production cost: scope it honestly

Combat RPGs are expensive per unit of content. The reference project's experience:
- Dozens of weapons each with an animated ability kit (it grew to over 100 kits) meant a dedicated pipeline for arms, VFX, sounds and testing. See [[Ability Kits Architecture]] and [[Pipeline - New Animated Weapon]].
- Enemy rosters were rebuilt several times; each enemy needs a model, rig, 8 or more clips and AI tuning. See [[Case Study - Enemy Roster Rebuild]].
- Studio-only animation paths broke live; see [[Case Study - Abilities That Only Worked in Studio]].

Plan content in **reusable units**: shared base rigs per body type (biped, quadruped, flyer), variants and elites from existing enemies, shared moves across weapons (the project gave every weapon one shared signature move in slot 1). See [[Planning and Scoping a Roblox Game]].

---

## 12. Common mistakes

| Mistake | Better |
|---|---|
| Tuning damage without a TTK target | TTK per enemy type per zone in the sheet |
| Health growth with no matching DPS source | A visible DPS source per zone (gear, forge, upgrades) |
| Attacks without telegraphs | 0.4 to 0.8 s telegraph, ground markers |
| Locked boss arenas as hard gates | Open, resettable fights with a power number |
| Rarity shown only as bigger numbers | Rarity in moves, ultimates and presentation |
| Forced PvP | Opt-in arena, normalised damage |
| Ten abilities on a phone | Attack, dodge, 2 to 4 abilities |
| Losing progress on death | Respawn fast, keep progress |

## 13. Checklist

- [ ] TTK targets per enemy type; health and DPS growth matched per zone.
- [ ] Every attack telegraphed; roles distinct in silhouette.
- [ ] Bosses short, open, retryable, with a recommended power number.
- [ ] Rarity budget defined for moves and ultimates.
- [ ] Mobile: aim assist, few buttons, big ground telegraphs.
- [ ] Death: fast respawn, explanation, no progress loss.
- [ ] PvP opt-in with normalised damage and anti-farm.
- [ ] Damage maths in one shared module; hits validated on the server.

## See also
- [[Combat Systems Architecture]], [[Hitboxes and Hit Detection]], [[NPC AI and Behaviour]], [[Pathfinding]]
- [[Weapon and Combat Animation]], [[Combat Animation Craft]], [[Boss Animation and Phases]], [[Hit Reactions Stagger and Hit-Stop]]
- [[VFX Design Playbook]], [[Game Feel and Juice]], [[Sound Design for Games]]
- [[Progression and Pacing Design]], [[Genre Playbook - RNG and Collection Games]], [[Post-Mortem - Building a Melee Action Game]]

## Connected notes
<!-- auto-links:start -->
[[Boss Fight Design Patterns]] · [[Progression Levels and Unlocks]] · [[Combat Arena and Encounter Layout]] · [[Rarity Ladders and Drop Pacing Math]] · [[Tower Defense Waves and Placement End to End]] · [[Anticipation]]
<!-- auto-links:end -->
