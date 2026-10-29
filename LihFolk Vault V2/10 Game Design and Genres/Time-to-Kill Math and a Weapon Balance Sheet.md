---
tags: [design, balance, ttk, dps, weapons, spreadsheets, shooters, combat, math, type/guide, area/design, level/intermediate]
---
# Time-to-Kill Math and a Weapon Balance Sheet

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Balancing by paper DPS -> Balance on STK and TTK at breakpoints
> - Avoid: Forgetting the first shot is free -> `(STK - 1) / fireRate`
> - Avoid: One range only -> Bands from close to long
> - Sheet computes STK and TTK per band for body, head and mixed.
> - Breakpoints marked; outliers highlighted against class medians.
> - Target TTK chosen for the audience and device mix.
>
> Cost: TL;DR ~140 tok · whole note ~2.1k tok. Read more: ## 1. Core formulas · ## 2. The balance sheet · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Time-to-kill (TTK) is the number that defines how a combat game feels: low TTK rewards first shot and positioning, high TTK rewards tracking, movement and teamwork. Damage per second (DPS) on paper is not the same thing, because kills come in discrete shots and real players miss. This note gives the formulas (shots to kill, TTK with fire rate, range falloff, headshots, accuracy, reload), a balance sheet layout that catches broken weapons before players do, and how to use it for melee and PvE as well as guns. The shooter design context is in [[Genre Playbook - Shooters FPS and TPS]]; general spreadsheet practice in [[Balancing with Spreadsheets and Data]].

Source labels: **Rule of thumb** (standard design maths).

---

## 1. Core formulas

```
STK (shots to kill)   = ceil(targetHP / damagePerShot)
TTK (seconds)         = (STK - 1) / fireRate          -- fireRate in shots per second, first shot at t = 0
                        + ceil(STK / magSize - 1) * reloadTime   -- only if STK exceeds a magazine
DPS (paper)           = damagePerShot * fireRate
DPS (sustained)       = damagePerShot * magSize / (magSize / fireRate + reloadTime)
```

The `- 1` matters: the first shot lands immediately. A weapon with 4 STK at 10 shots per second kills in 0.3 s, not 0.4 s. Paper DPS hides **breakpoints**: 34 damage against 100 HP is 3 shots, 33 damage is 4 shots, a 33% TTK increase for a 3% damage change. Balance around breakpoints, not DPS.

### Range falloff
Damage drops between `falloffStart` and `falloffEnd` to `minDamage`:
```
d(r) = maxDamage                                          if r <= start
     = lerp(maxDamage, minDamage, (r - start) / (end - start))   if start < r < end
     = minDamage                                          if r >= end
```
Recompute STK at several ranges (5, 15, 30, 50, 80 studs). STK jumps are where a weapon "stops working".

### Headshots and hit zones
With a headshot fraction `h` (0..1) and multiplier `m`, expected damage per hit is `d * (1 + h * (m - 1))`, but STK is discrete; compute the **best case** (all heads), **typical** (for example h = 0.25) and **body-only** STK separately. All three matter: best case is what top players experience, body-only is what new players experience ([[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]]).

### Accuracy
Real TTK includes misses. With accuracy `a` (hits per shot fired), expected shots fired to land STK hits is `STK / a`, so:
```
TTK_real ≈ (STK / a - 1) / fireRate
```
Use different `a` per weapon class and range (an SMG at 40 studs might have a = 0.3 for an average player; a rifle 0.6). Get `a` from telemetry once live.

## 2. The balance sheet

One row per weapon, inputs left, derived columns right:

| Inputs | Derived (per range band) |
|---|---|
| Damage max/min, falloff start/end | Damage at 5/15/30/50/80 |
| Fire rate (RPM or shots/s) | STK body / head / mixed at each band |
| Magazine, reload time | TTK body / head / mixed at each band |
| Head, limb multipliers | Sustained DPS |
| Spread, recoil class | TTK_real with class accuracy |
| Move speed, ADS time | "Effective TTK" = TTK + ADS time for scoped weapons |
| Unlock level, cost | Rank of the weapon per band |

Add conditional formatting: the best TTK per band in green, anything more than 20 to 30% better than the class median in red (**Rule of thumb**). A weapon that is green in every band is broken. Each class should own one or two bands.

```
Example (100 HP, illustrative numbers only)
SMG:   22 dmg, 15 shots/s  -> STK 5, TTK 0.27 s close; falloff to 14 -> STK 8, TTK 0.47 s at 50
Rifle: 30 dmg,  9 shots/s  -> STK 4, TTK 0.33 s close; holds 26 at 50 -> STK 4, TTK 0.33 s
Sniper: 95 body, 2.0 head, 0.9 shots/s -> STK 2 body (1.1 s), 1 head (0 s)
```

The SMG wins up close, the rifle at range, the sniper on headshots. Note how one falloff value moves the SMG across a breakpoint.

## 3. Choosing a target TTK

| Target body TTK | Feel | Fits |
|---|---|---|
| Under 0.3 s | Twitchy, first-shot wins | Tactical shooters; harsh on high ping and mobile |
| 0.4 to 0.8 s | Tracking matters, counterplay exists | Most arena and casual shooters on Roblox |
| 1 to 2 s+ | Abilities, movement, team focus | Hero shooters, battlegrounds, RPG PvP |

**Rule of thumb for Roblox.** Many players are on phones with touch aim and variable ping. A body TTK under about 0.3 s magnifies latency (players die before their screen shows the attacker). Mid TTKs plus generous headshot multipliers keep skill expression without punishing mobile. Test at simulated latency ([[Multi-Client and Live Testing]]).

**Health pools** are a balance lever too: raising everyone's HP by 20% raises all TTKs evenly and moves every breakpoint. Do it rarely and recheck the whole sheet.

## 4. Melee and PvE

- **Melee**: replace fire rate with swing cadence (swing time plus recovery), add combo multipliers per step, and count hit chance per swing from hitbox size. TTK against a training dummy gives the paper number; dodge and block windows give real TTK.
- **PvE**: compute time to kill each enemy archetype with each weapon tier at the zone's expected level. Fodder should die in 1 to 3 hits, elites in 5 to 15 seconds for a solo player, bosses in a few minutes of focused damage. Also compute **time to die**: how long the player survives an archetype's attacks; the ratio is the fight's tension ([[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]], [[Boss Fight Design Patterns]]).
- **Armour and resistances** change effective HP; compute TTK against each armour tier using the damage pipeline's formula ([[Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations]]).

## 5. From sheet to game

- Export the sheet as the weapon data module the game reads (one source of truth, [[Data and Config Pipeline - Spreadsheets to Game]]).
- Log live per weapon: kills, deaths, accuracy, headshot share, average engagement distance, and win rate of the holder. Compare real TTK distributions to the sheet; large gaps usually mean hit registration or spread problems, not damage values.
- Change one variable per patch per weapon where possible; changing damage and fire rate together makes it impossible to read the result.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Balancing by paper DPS | Weapons with equal DPS feel very different | Balance on STK and TTK at breakpoints |
| Forgetting the first shot is free | TTKs overestimated by one interval | `(STK - 1) / fireRate` |
| One range only | A weapon dominates at another range | Bands from close to long |
| Only best-case headshot TTK | New players feel weapons are useless | Show body, head and mixed |
| Very low TTK on a mobile-heavy game | "Died behind cover" complaints | Mid TTK, test with latency |
| Sheet and game data diverge | Balance changes do not ship | Sheet exports the data module |

## Checklist
- [ ] Sheet computes STK and TTK per band for body, head and mixed.
- [ ] Breakpoints marked; outliers highlighted against class medians.
- [ ] Target TTK chosen for the audience and device mix.
- [ ] PvE time-to-kill and time-to-die per archetype and tier.
- [ ] Sheet exports the runtime data; live telemetry compared each patch.

## See also
[[Balancing with Spreadsheets and Data]] · [[Genre Playbook - Shooters FPS and TPS]] · [[Combat Systems Architecture]] · [[Data and Config Pipeline - Spreadsheets to Game]] · [[Probability and Statistics for Designers]] · [[Genre Playbook - Combat and RPG]]

## Connected notes
<!-- auto-links:start -->
[[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]] · Kill Credit, Assists, Kill Feed and Death Recaps · [[Genre Playbook - Battlegrounds and Arena Fighters]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Genre Playbook - Tower Defense]] · [[Rarity Ladders and Drop Pacing Math]] · [[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Genre Playbook - Battle Royale]] · [[Progression and Pacing Design]] · [[Simulator and RNG Genre Teardown]] · [[Core Loops and Session Design]] · [[Genre Playbook - Sports]]
<!-- related:end -->
