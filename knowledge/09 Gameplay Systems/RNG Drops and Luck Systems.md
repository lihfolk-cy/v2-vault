---
tags: [gameplay, rng, luck, drops, loot, pity, rolling]
---
# RNG Drops and Luck Systems

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Rolling on the client -> Server rolls only
> - Avoid: Displayed odds from a different table -> One data source
> - Avoid: Unbounded multiplicative luck -> Additive or capped stacking
> - Server-side rolls with dedicated `Random` objects.
> - One documented luck definition, capped stacking, total shown to the player.
> - Pity or deterministic progress for every rare chase.
>
> Cost: TL;DR ~140 tok · whole note ~3.4k tok. Read more: ## 3. Luck multipliers · ## 4. Bad luck protection: pity and guarantees · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Random rewards drive whole genres on Roblox: rolling games where you pull items with "1 in 5,000,000" odds, loot drops from enemies, egg hatching, crates. The code for a weighted pick is ten lines. Everything around it is where games succeed or fail: how luck multipliers actually change odds, how to stop bad streaks with pity and guarantees, how to keep the maths on the server, how to show odds honestly, and how to keep a luck economy from inflating until everything is common. This note covers the mechanics with numbers from one production rolling game.

Design and ethics: [[Genre Playbook - RNG and Collection Games]], [[Ethical Design and Player Trust]]. Policy: [[Roblox Policies Ratings and Compliance]].

Source labels: **Docs**, **Measured** (the reference project), **Rule of thumb**.

---

## 1. Random numbers on Roblox

- `Random.new(seed?)` creates an independent generator: `NextNumber()` in [0, 1), `NextNumber(min, max)`, `NextInteger(min, max)` inclusive, `NextUnitVector()`, `Shuffle(array)`, and `Clone()` (Docs).
- `math.random` uses a shared generator per Luau VM. Fine for cosmetics; for gameplay use your own `Random` objects so one system's calls do not change another's sequence (useful for reproducible tests).
- **Rolls happen on the server only.** A client that rolls can roll until it likes the result. The client asks; the server rolls, records, and tells the client what to animate.
- **Seeded randomness** is useful for deterministic content (a daily dungeon layout the same for everyone: seed with the day number) and for tests, never for rewards a player could predict.

---

## 2. Weighted picks

### Weights versus "1 in N"
Rolling games describe items as "1 in N" odds. Two ways to turn a catalogue into a roll:

| Method | How | Property |
|---|---|---|
| Weight table | Weight = 1/N; pick proportionally | Displayed odds are approximate (they are normalised by the total weight) |
| Rarest-first cutoff | Walk items from rarest to commonest; each succeeds with chance `1/N`; first success wins; fallback is the commonest | Displayed "1 in N" is close to exact for rare items; easy to apply luck |

```lua
--!strict
export type Entry = { id: string, oneIn: number }

local rng = Random.new()

-- Weighted: probability of each = (1/oneIn) / sum(1/oneIn).
local function pickWeighted(entries: { Entry }): Entry
	local total = 0
	for _, e in entries do
		total += 1 / e.oneIn
	end
	local r = rng:NextNumber() * total
	for _, e in entries do
		r -= 1 / e.oneIn
		if r <= 0 then
			return e
		end
	end
	return entries[#entries]
end

-- Rarest-first with luck: each item rolls with chance min(1, luck / oneIn).
-- `sorted` must be ordered rarest first; the last entry is the guaranteed fallback.
local function pickRarestFirst(sorted: { Entry }, luck: number): Entry
	for i = 1, #sorted - 1 do
		local e = sorted[i]
		if rng:NextNumber() < math.min(1, luck / e.oneIn) then
			return e
		end
	end
	return sorted[#sorted]
end
```

In rarest-first, the real chance of a mid-tier item is slightly lower than `1/N` because rarer items are checked first; for rare items the difference is negligible. Document which method you use, because displayed odds must match.

### Tiered rolls
Large catalogues roll in two stages: pick a rarity tier, then an item within it. Tier odds become a design lever (raise "Epic+" odds by 1.5x, as the reference project's difficulty pass did) without touching every item.

---

## 3. Luck multipliers

"2x luck" is ambiguous. Common definitions:

| Definition | Effect |
|---|---|
| Divide every N by luck (rarest-first) | A 1-in-1,000 item becomes 1-in-500; common items barely change (they were near 1 already) |
| Multiply weights of rare tiers only | Shifts mass from commons to rares; must renormalise |
| Roll twice, keep the better | "Advantage"; strong at low odds, roughly doubles the chance of rare items |

Pick one definition, write it in the item index ("your luck: 2.0x, this item: 1 in 2,500"), and apply it everywhere (rolls, drops, crafting).

### Stacking luck sources
**Measured** luck sources in the reference project:

| Source | Value |
|---|---|
| Golden roll | 20% chance per press, 2x luck for that roll |
| Lucky Rolls game pass | Bonus luck (pass) |
| VIP pass | 1.1x |
| Friend boost | Luck per friend in the server |
| Potions | 1.5x / 2x / 3x; only the strongest of a kind counts down, weaker ones pause |
| Server luck product | Applies to everyone in that server for a time |
| Permanent bundle | 2x |
| Lucky critter charm | 3x to 10x for 1 to 5 rolls (cut from 20x to 100x) |

Lessons:
- **Multiply or add?** Multiplying many sources explodes (1.1 x 2 x 3 x 2 x 10 = 132x). Additive bonuses (`1 + sum`) or a cap keep the top end sane. The reference project had to cut its critter charm from 20 to 100x down to 3 to 10x.
- **Show the total** the next roll will use, including temporary charms ("INCL. CHARM xN"), and the cap that applies here. The reference project publishes a standing `TotalLuck` attribute once per second for the HUD.
- **Queue rather than stack** same-kind consumables (only the strongest potion runs), so players do not waste them.
- **Make "this server" explicit** for server-wide boosts in the product text, the chip and the feed; players assume a purchase applies everywhere.

### Rarity caps by progress
**Measured.** The reference project capped rolls by world: the first world could roll up to Legendary, later worlds up to Mythic, Celestial and Eternal; purchases were never capped. When the later worlds were not ready, players were stuck below the cap with nothing to chase, and the caps were turned off by a flag ("players want to be able to get better weapons"). With caps off the top tiers became about 1 in 3.8M at base luck. Caps are a pacing tool; they need content behind them.

---

## 4. Bad luck protection: pity and guarantees

Pure randomness produces long droughts. With a 1-in-100 drop, about 37% of players have not seen it after 100 tries, and about 13% have not after 200. Those players quit. Protection systems:

| System | How | Feel |
|---|---|---|
| Hard pity | Guarantee the item after K failures | Transparent, a clear goal |
| Soft pity | Chance rises after a threshold | Smooth, less visible |
| Fragments / tokens | Each roll or kill gives a fragment; N fragments buy the item | Deterministic progress alongside luck |
| Duplicate conversion | Duplicates become upgrade material (fusion, salvage) | No roll is wasted |
| First-time guarantee | Tutorial or first purchase gives a fixed good result | Good start, but sets expectations |

```lua
--!strict
-- Soft pity on a per-player counter (saved in the profile).
local BASE = 1 / 200
local SOFT_START = 150
local HARD = 250

local function rareChance(failures: number): number
	if failures >= HARD - 1 then
		return 1
	end
	if failures < SOFT_START then
		return BASE
	end
	-- linear ramp from BASE at SOFT_START to 1 at HARD
	local t = (failures - SOFT_START) / (HARD - SOFT_START)
	return BASE + (1 - BASE) * t
end

local function rollWithPity(profile: { RarePity: number }, rng: Random): boolean
	local hit = rng:NextNumber() < rareChance(profile.RarePity)
	profile.RarePity = if hit then 0 else profile.RarePity + 1
	return hit
end
```

Rules:
- **Save pity counters** in the profile; a counter that resets on rejoin is not pity.
- **Show them** when they are a feature ("guaranteed in 34 rolls"). Hidden soft pity is acceptable; hidden hard pity wastes its motivational value.
- **Disclose how pity changes odds** if odds are displayed.

**Measured** guarantees in the reference project:
- Ultimate pulls on abilities include a guaranteed nearest-target pull within 240 studs, so the move never "whiffs".
- Mini-boss drops: fragment chances toward zone-themed weapons plus a guaranteed material bundle.
- Bosses: one material always, a rarer one at 25% (35% for a later boss).
- Tutorial first roll: an early version guaranteed a Rare; after playtesting it became a plain roll with no golden or bonus pulls. A guaranteed great first result teaches the wrong odds.
- Fusion and crafting give deterministic ways to turn bad luck (duplicates) into progress ([[Progression Levels and Unlocks]] section 6).

---

## 5. Enemy drop tables

```lua
--!strict
export type Drop = { item: string, chance: number, min: number, max: number }
export type DropTable = { always: { Drop }?, rolls: { Drop } }

local function rollDrops(t: DropTable, rng: Random, dropMult: number): { [string]: number }
	local out: { [string]: number } = {}
	local function add(d: Drop)
		local n = rng:NextInteger(d.min, d.max)
		out[d.item] = (out[d.item] or 0) + n
	end
	if t.always then
		for _, d in t.always do add(d) end
	end
	for _, d in t.rolls do
		if rng:NextNumber() < math.min(1, d.chance * dropMult) then
			add(d)
		end
	end
	return out
end
```

**Measured** modifiers: rare spawns 3x drops; elites 2.5x drop multiplier; the "Hoarder" weapon archetype +20% cash and +25% materials; zone tables give materials of the zone's tier (tiers 1 to 6 in the first realm).

Rule of thumb: separate **always** drops (currency, the zone's common material) from **chance** drops. Players need a floor reward every kill and an occasional spike.

### Who gets the drop
- Per-player drops (each participant rolls separately) avoid loot fights and suit Roblox's mixed-stranger servers.
- Visible pickups (coins flying out) are presentation; credit the reward on the server at the kill and let the pickup be cosmetic, or require proximity and validate it. The reference project drops coins and material pickups visually while the server credits the payload.

---

## 6. Presentation: the reveal

The roll animation is part of the mechanic. **Measured** elements from the reference project's reveal: a full-screen roll mode for manual rolls (world dimmed, HUD hidden) and a small reel over the head for auto-rolls; banners for the rarest tiers; a burst for Rare and above; near-miss frames capped by world; the golden roll landing on a golden tile and spinning on; a skippable reveal in the tutorial.

Rules of thumb:
- Auto-roll must be quieter than manual roll, or a session of auto-rolls becomes noise.
- Big pulls should be shared: a server-wide feed line or announcement for the rarest tiers is social proof ([[Social Design and Multiplayer Play]]).
- Near-miss presentation (the reel stopping just past a rare item) increases excitement and is ethically sensitive; avoid making it misleading, and never use it on paid rolls ([[Ethical Design and Player Trust]]).
- The server decides the result before the animation starts; the animation must never decide.

---

## 7. Odds disclosure and paid randomness

Roblox's rules on paid random items (items bought with Robux, directly or through currency, whose contents are random) require odds disclosure before purchase and have regional restrictions; the details change, so check the current policy pages as of October 2026 before shipping any paid random item ([[Roblox Policies Ratings and Compliance]]). Regardless of policy:
- Show odds for every rollable item, including how luck changes them.
- Keep displayed odds generated from the same data the server rolls from (one source of truth).
- Log every roll result server-side so you can audit "my odds feel wrong" reports.

---

## 8. Testing RNG

- Simulate a million rolls offline (the roll function must be pure: catalogue + luck + Random in, result out) and compare observed frequencies to displayed odds.
- Test streaks: distribution of rolls-to-first-rare with and without pity.
- Test luck stacking: every combination of sources, check the cap.
- Test with a fixed seed in unit tests so failures reproduce ([[Testing Strategies and Frameworks]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Rolling on the client | Exploited rewards | Server rolls only |
| Displayed odds from a different table | Odds complaints, policy risk | One data source |
| Unbounded multiplicative luck | Everything becomes common | Additive or capped stacking |
| Pity not saved | Pity resets on rejoin | Save counters |
| Caps without content | Players stuck, frustration | Caps only with content behind them |
| Guaranteed great first roll | Wrong expectations | Plain first roll, early guaranteed progress elsewhere |
| Duplicates useless | Rolls feel wasted | Fusion, salvage, crafting |

## Checklist
- [ ] Server-side rolls with dedicated `Random` objects.
- [ ] One documented luck definition, capped stacking, total shown to the player.
- [ ] Pity or deterministic progress for every rare chase.
- [ ] Drop tables with floor rewards and multipliers in data.
- [ ] Odds displayed from the roll data; paid randomness checked against current policy.
- [ ] Million-roll simulation in tests.

## See also
[[Progression Levels and Unlocks]] · [[Economies and Currencies]] · [[Genre Playbook - RNG and Collection Games]] · [[Ethical Design and Player Trust]] · [[Roblox Policies Ratings and Compliance]] · [[Developer Products and ProcessReceipt]] · [[Tools and Inventory Systems]]

## Connected notes
<!-- auto-links:start -->
[[Rarity Ladders and Drop Pacing Math]] · [[Pity Timer]] · [[Drop Tables Rarity and Pity Systems]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Balancing with Spreadsheets and Data]] · [[Probability and Statistics for Designers]]
<!-- auto-links:end -->
