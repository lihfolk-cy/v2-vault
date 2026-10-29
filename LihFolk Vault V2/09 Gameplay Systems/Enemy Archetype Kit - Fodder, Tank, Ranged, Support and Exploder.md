---
tags: [gameplay, ai, enemies, archetypes, encounter-design, roster, balance, type/guide, area/gameplay, level/intermediate, data-driven, area/data]
---
# Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Variety only in stats and meshes -> Five archetypes asking different questions
> - Avoid: Tanks with health and nothing else -> Shield, stagger or weak point
> - Avoid: Unidentifiable supports -> Silhouette, link beam, aura
>
> Cost: TL;DR ~100 tok · whole note ~2.3k tok. Read more: ## 2. Data definition · ## 3. Archetype by archetype · ## 5. Readability checklist per enemy · ## Common mistakes
<!-- tldr:end -->

A roster of twenty enemies that differ only in mesh and health is one enemy twenty times. A roster built from five **archetypes**, each asking the player a different question, gives real variety with fewer assets, and makes encounters composable: the [[Spawn Director - Credit Budgets and Player-Count Scaling]] buys a mix, the [[Squad AI - Attack Tokens, Flanking and Attacker Limits]] coordinates it, and the player has to prioritise. This note defines the five archetypes as data, lists the behaviours and tells each needs, and gives composition rules. Stat numbers are starting ratios (**Rule of thumb**) to be tuned with [[Time-to-Kill Math and a Weapon Balance Sheet]].

Source labels: **Rule of thumb** throughout; Roblox-specific implementation notes reference V2 notes.

---

## 1. The question each archetype asks

| Archetype | Player question | Role in a fight |
|---|---|---|
| **Fodder** | "Can you handle many at once?" | Fills space, feeds power fantasy, creates pressure by count |
| **Tank** | "Can you handle one durable threat while others act?" | Anchors a position, absorbs focus, blocks paths |
| **Ranged** | "Can you deal with threats you are not facing?" | Forces movement and target switching; punishes standing still |
| **Support** | "Can you identify and kill the priority target?" | Buffs, heals or shields others; multiplies everything around it |
| **Exploder** | "Can you manage space and timing?" | Rushes and detonates; punishes clumping and backing into corners |

A fight that asks only one question is a grind. Two or three questions at once is the sweet spot for most action games.

## 2. Data definition

```lua
--!strict
export type Archetype = "Fodder" | "Tank" | "Ranged" | "Support" | "Exploder"

export type EnemyDef = {
	id: string,
	archetype: Archetype,
	cost: number,            -- director credits
	health: number,          -- multiple of the zone's fodder health
	damage: number,          -- multiple of the zone's fodder hit
	moveSpeed: number,       -- studs/s
	preferredRange: NumberRange,
	tokenCost: number,
	tells: { string },       -- telegraph ids (anim + sound + VFX)
	behaviours: { string },  -- flags: "Kite", "ShieldFront", "HealAllies", "Detonate"
}

local Roster: { [string]: EnemyDef } = {
	Grunt = { id = "Grunt", archetype = "Fodder", cost = 1, health = 1, damage = 1,
		moveSpeed = 16, preferredRange = NumberRange.new(0, 5), tokenCost = 1,
		tells = { "SwingWindup" }, behaviours = {} },
	Bulwark = { id = "Bulwark", archetype = "Tank", cost = 8, health = 10, damage = 2.5,
		moveSpeed = 10, preferredRange = NumberRange.new(0, 7), tokenCost = 2,
		tells = { "SlamWindup" }, behaviours = { "ShieldFront" } },
	Slinger = { id = "Slinger", archetype = "Ranged", cost = 3, health = 0.8, damage = 1.2,
		moveSpeed = 14, preferredRange = NumberRange.new(30, 60), tokenCost = 0.5,
		tells = { "AimGlint" }, behaviours = { "Kite", "UseCover" } },
	Chanter = { id = "Chanter", archetype = "Support", cost = 6, health = 2, damage = 0.5,
		moveSpeed = 12, preferredRange = NumberRange.new(25, 45), tokenCost = 0,
		tells = { "ChantAura" }, behaviours = { "BuffAllies", "StayBehindTank" } },
	Burster = { id = "Burster", archetype = "Exploder", cost = 2, health = 0.6, damage = 4,
		moveSpeed = 20, preferredRange = NumberRange.new(0, 6), tokenCost = 2,
		tells = { "FuseHiss", "Glow" }, behaviours = { "Detonate" } },
}

return Roster
```

Health and damage are multiples of the zone's baseline, so a new zone only defines its baseline and every archetype scales consistently ([[Data and Config Pipeline - Spreadsheets to Game]]).

## 3. Archetype by archetype

### Fodder
- Low health (dies in 1 to 3 basic hits), low individual damage, numerous. Fast to spawn and cheap to simulate: lightweight brains, direct movement, low-detail animation at distance ([[Enemy and NPC Animation]]).
- Short, readable tells. Fodder that hits hard is not fodder.
- Death should feel great (hit-stop, knockback, a burst): they exist to make the player feel strong ([[Hit-Stop and Screen Shake Tuning by Numbers]]).

### Tank
- High health (8 to 15x fodder), slow, high damage per hit with long windups. Takes 2 tokens.
- Needs a **mechanic**, not just health: a frontal shield (damage reduction from the front), a stagger threshold, a weak point. Health alone makes tanks sponges.
- Breaks formations by blocking corridors; place them with level design in mind ([[Combat Arena and Encounter Layout]]).

### Ranged
- Fragile, keeps distance (kites when approached), uses cover ([[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]]).
- Projectiles must be dodgeable: visible travel time, a glint or charge tell, and capped per target (2 shooters at a time).
- Aim with deliberate error so misses near the player create tension without unfair chip damage ([[AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses]]).

### Support
- Low threat alone, high threat in groups: heals, shields, haste or damage auras for allies within a radius. Stays behind a tank.
- **Must be identifiable at a glance**: unique silhouette, a visible beam or aura linking it to buffed allies. If players cannot tell who is healing, the fight feels unwinnable.
- Cap buffs: no stacking from multiple supports on one ally unless intended ([[Status Effects Buffs and Stacking Rules]]).

### Exploder
- Fast, fragile, high burst damage in an area on death or on contact. Takes a big token or is exempt but capped (1 to 2 alive near a target).
- Long, loud, unmistakable fuse (sound plus glow plus slowdown) and a fixed fuse time once triggered; the player's counterplay is to kill it early or move.
- Killing it early should detonate it where it is, hurting its allies: that creates emergent combos and rewards awareness. Damage falloff and cover rules in [[Explosions - Radius Damage, Falloff and Cover Checks]].

## 4. Composition rules

| Rule | Why |
|---|---|
| Lead with fodder, then add one new question at a time | Teaching through encounters, not text |
| At most one support per group early on | Supports multiply difficulty fast |
| Tank plus ranged is the classic pairing | Player must close on ranged while the tank blocks |
| Exploders with fodder, not with tanks | Fodder clumps make exploder chains fun; tanks plus exploders feel punishing |
| Reserve 15 to 25% of the director budget for archetypes that counter the players' current strategy | Players camping in a corner meet an exploder |

Variants extend archetypes without new code: element, armour type, a single extra behaviour flag. An "elite" is an archetype with a modifier (more health, an aura, an extra attack), not a new archetype ([[NPC AI and Behaviour]] section 8).

## 5. Readability checklist per enemy

Silhouette distinct at 60 studs; colour accent tied to archetype (consistent across zones); one signature sound; telegraphs at least 0.4 to 0.6 s for melee hits and longer for heavy attacks ([[Enemy Animation State Protocol]], [[Anticipation]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Variety only in stats and meshes | Every fight feels the same | Five archetypes asking different questions |
| Tanks with health and nothing else | Sponge fights | Shield, stagger or weak point |
| Unidentifiable supports | "Unkillable" groups | Silhouette, link beam, aura |
| Exploders without a long tell | Unfair deaths | Fuse sound, glow and slowdown |
| Absolute stats per zone | Zones drift out of balance | Multiples of a zone baseline |
| Too many questions at once early | New players overwhelmed | One new archetype per encounter |

## Checklist
- [ ] Every enemy tagged with an archetype and defined as data.
- [ ] Each archetype has a counterplay and a readable tell.
- [ ] Stats are multiples of a zone baseline.
- [ ] Composition rules encoded in director roster weights per phase.
- [ ] Supports and exploders capped per target or group.

## See also
[[NPC AI and Behaviour]] · [[Spawn Director - Credit Budgets and Player-Count Scaling]] · [[Case Study - Enemy Roster Rebuild]] · [[Genre Playbook - Combat and RPG]] · [[Boss Fight Design Patterns]] · [[Balancing with Spreadsheets and Data]]

## Connected notes
<!-- auto-links:start -->
[[Squad AI - Attack Tokens, Flanking and Attacker Limits]] · [[Combat Arena and Encounter Layout]] · Tower Defense Waves and Placement End to End · [[Wildlife and Ambient Creature AI - Passive, Neutral and Hostile]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Combat Systems Architecture]] · [[Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations]] · [[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Downed, Revive and Bleed-Out States]] · [[Kill Credit, Assists, Kill Feed and Death Recaps]] · [[Pathfinding Edge Cases and Fallbacks]] · [[Spawning Teams and Rounds]] · [[Hitboxes and Hit Detection]]
<!-- related:end -->
