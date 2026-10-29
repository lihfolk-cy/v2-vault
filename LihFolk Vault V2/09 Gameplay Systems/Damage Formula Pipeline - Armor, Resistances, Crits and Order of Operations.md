---
tags: [gameplay, combat, damage, armor, resistances, crits, balance, math, type/guide, area/gameplay, level/advanced, server-authority]
---
# Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: All bonuses multiplicative -> One additive bucket, few "more" factors
> - Avoid: Linear percent armour without cap -> Hyperbolic curve
> - Avoid: Flat reduction without floor -> Floor at a fraction of the hit
> - Order of operations written down and implemented in one pure function.
> - Additive bucket and multiplicative factors labelled distinctly in UI.
> - Hyperbolic armour with documented K; resistances capped, negatives allowed.
>
> Cost: TL;DR ~150 tok · whole note ~2.4k tok. Read more: ## 1. The canonical order · ## 3. Damage types and resistances · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Combat Systems Architecture]] establishes one damage core with ordered "dealt" and "taken" modifiers. This note fills in the maths inside that core: which armour curve to pick and why, how damage types and resistance tables interact, where crits belong in the order, additive versus multiplicative stacking, rounding, overkill and damage over time. The goal is a formula designers can reason about on a spreadsheet and players can feel, with no hidden blow-ups at high levels.

Source labels: **Rule of thumb** (standard game-design maths), **Roblox docs** where engine behaviour matters.

---

## 1. The canonical order

```
base (weapon/ability, per hit)
  x move multiplier (combo step, charge level)
  x (1 + sum of additive "damage +%" bonuses)          -- one bucket
  x product of multiplicative "more" bonuses           -- each its own factor
  x crit multiplier (if crit)
  x damage-type effectiveness (element vs element)
  -> mitigation: armour curve, then resistance %, then flat reduction
  x context (PvP scale, difficulty, tutorial shield)
  -> shields/absorb, then health
  -> round once, clamp, record overkill
```

Why this order (**Rule of thumb**):
- **Additive bonuses in one bucket** keep growth linear: five "+20%" items give +100%, not +149%. Make anything that should feel exceptional a separate **multiplicative** factor, and keep the count of those small. Label them differently in UI ("+20% damage" vs "20% more damage") or players cannot predict stacking.
- **Crits before mitigation**, so armour reduces crit hits proportionally and crit stays a constant relative bonus. Crits after flat reduction make crits disproportionately strong against armour.
- **Percent armour before flat reduction**, so flat reduction does not dominate small hits twice.
- **Context last**, so PvP scaling or tutorial shields are a single, predictable knob.

## 2. Armour curves

| Curve | Formula | Feel | Problem |
|---|---|---|---|
| Flat subtraction | `dmg - armor` (floor) | Strong vs many small hits | Big armour makes fast weapons useless; needs a floor |
| Linear percent | `dmg * (1 - armor%)` with cap | Easy to read | Near cap, each point is huge (90% to 95% halves damage taken) |
| Hyperbolic (diminishing) | `dmg * K / (K + armor)` | Each point of armour adds the same effective health | Players must understand "effective HP" |
| Level-relative | `K = a + b * attackerLevel` in the hyperbolic | Armour stays relevant against same-level foes | Need to tune `a, b` per curve |

**Rule of thumb.** Use **hyperbolic** for anything that scales with progression. With `mitigation = armor / (K + armor)`, effective health is `HP * (1 + armor / K)`, linear in armour: 100 armour with K = 100 means "double effective health". That property makes balance spreadsheets simple ([[Balancing with Spreadsheets and Data]]).

If you use flat reduction anywhere (common for "block reduces 5 damage"), add a **floor**: `max(dmg - flat, dmg * 0.1)` or a minimum of 1, so nothing becomes immune by accident.

## 3. Damage types and resistances

- A small fixed set of types (Physical, Fire, Ice, Shock, True). More than five or six becomes noise.
- **Effectiveness table** (attacker type vs target type) for rock-paper-scissors elements: 1.5x strong, 0.75x weak, 1x neutral. Keep multipliers modest; 2x/0.5x makes element choice mandatory, not interesting.
- **Resistance %** per type on the target, after armour (armour usually applies only to Physical). Cap resistances (for example 75%) and allow negative resistance from debuffs (amplifies damage). **True** damage ignores armour and resistance; use sparingly (execute effects, fall damage, hazards).

```lua
--!strict
export type DamageType = "Physical" | "Fire" | "Ice" | "Shock" | "True"

export type Hit = {
	base: number, moveMult: number,
	addPct: number,            -- sum of additive bonuses, e.g. 0.6 for +60%
	more: { number },          -- multiplicative factors
	crit: boolean, critMult: number,
	dtype: DamageType, effectiveness: number,
}
export type Defence = { armor: number, armorK: number, resist: { [DamageType]: number }, flat: number, contextMult: number }

local RESIST_CAP = 0.75

local function resolve(hit: Hit, def: Defence): number
	local d = hit.base * hit.moveMult * (1 + hit.addPct)
	for _, m in hit.more do d *= m end
	if hit.crit then d *= hit.critMult end
	d *= hit.effectiveness

	if hit.dtype ~= "True" then
		if hit.dtype == "Physical" then
			d *= def.armorK / (def.armorK + math.max(def.armor, 0))
		end
		local r = math.min(def.resist[hit.dtype] or 0, RESIST_CAP) -- may be negative
		d *= 1 - r
		d = math.max(d - def.flat, d * 0.1)
	end
	d *= def.contextMult
	return math.max(0, d) -- unrounded; round once at application
end

return resolve
```

## 4. Crits

- **Chance cap** (50 to 60%) so builds cannot reach guaranteed crits unless crit is the build's identity; then reduce crit multiplier as chance rises.
- **Pseudo-random distribution** (increasing chance after each non-crit) reduces streaks if crits matter a lot ([[Probability and Statistics for Designers]]).
- **Roll on the server**. Never accept a client "it was a crit" flag. If the client predicts damage numbers, it shows a neutral number until the server confirms ([[Client Prediction and Reconciliation for Combat]]).
- **Headshots / weak points** are a separate multiplier from crits (deterministic, skill-based); decide whether they stack. Usually they do, but cap the product ([[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]]).

## 5. Rounding, overkill and display

- Keep all maths in floats; **round once** at the moment you subtract from health, and use the same rounded number for display. Rounding at each step drifts and makes displayed numbers disagree with health bars.
- Decide rounding direction: `math.floor` favours defenders, `math.round` is neutral. With small numbers (10 to 50 damage) the choice changes breakpoints; with large numbers it does not matter.
- **Overkill** (`damage - remainingHealth` when it kills) is worth recording for analytics and for effects (big overkill triggers gib or ragdoll), but kill credit and rewards use damage up to remaining health only ([[Kill Credit, Assists, Kill Feed and Death Recaps]]).
- `Humanoid:TakeDamage` respects `ForceField`; setting `Humanoid.Health` directly does not (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/Humanoid#TakeDamage). Pick one path for the whole game, usually your own health value, and mirror it to the Humanoid.

## 6. Damage over time and snapshots

- **Snapshot** DoTs at application: compute the per-tick value with the attacker's stats at cast time. Dynamic recalculation every tick makes buffs applied later retroactively affect old DoTs and costs more.
- Each DoT tick still runs the **taken side** (resistance, shields), because the target's defences can change.
- Ticks at fixed server intervals (0.5 or 1 s) from a single scheduler, not a `task.wait` loop per effect ([[Status Effects Buffs and Stacking Rules]]).

## 7. Testing the formula

Write unit tests that pin known cases: neutral hit, max armour, capped resistance, negative resistance, crit against armour, True damage, flat floor. Put the formula in a pure module with no Instance access so tests run in a test runner ([[Testing Strategies and Frameworks]]). Plot effective damage against armour and level in a spreadsheet and look for cliffs.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| All bonuses multiplicative | Exponential late-game damage | One additive bucket, few "more" factors |
| Linear percent armour without cap | Immortal tanks near 100% | Hyperbolic curve |
| Flat reduction without floor | Fast weapons deal 0 | Floor at a fraction of the hit |
| Crit after mitigation | Crits shred armour | Crit before mitigation |
| Rounding every step | Numbers disagree with bars | Round once at application |
| Client-reported crits | Exploited crit rates | Server rolls |

## Checklist
- [ ] Order of operations written down and implemented in one pure function.
- [ ] Additive bucket and multiplicative factors labelled distinctly in UI.
- [ ] Hyperbolic armour with documented K; resistances capped, negatives allowed.
- [ ] Crits server-rolled, capped, before mitigation.
- [ ] Single rounding step; overkill recorded.
- [ ] Unit tests for edge cases; spreadsheet plots for cliffs.

## See also
[[Combat Systems Architecture]] · [[Status Effects Buffs and Stacking Rules]] · [[Balancing with Spreadsheets and Data]] · [[Time-to-Kill Math and a Weapon Balance Sheet]] · [[Genre Playbook - Combat and RPG]] · [[Probability and Statistics for Designers]]

## Connected notes
<!-- auto-links:start -->
[[Explosions - Radius Damage, Falloff and Cover Checks]] · [[Hitboxes and Hit Detection]] · [[Melee Combat System End to End]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]] · [[RNG Drops and Luck Systems]] · [[Downed, Revive and Bleed-Out States]] · [[Spawn Director - Credit Budgets and Player-Count Scaling]] · [[AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses]] · [[Characters and Humanoids]] · [[Spawning Teams and Rounds]] · [[Grabs, Carries and Throws - Moving Players Safely]]
<!-- related:end -->
