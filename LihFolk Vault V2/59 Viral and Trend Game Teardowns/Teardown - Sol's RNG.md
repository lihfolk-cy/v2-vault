---
tags: [teardown, viral-trend, rng, luck, collection, auras, biomes, battle-pass, live-ops, odds, type/case-study, area/design, level/intermediate]
verified: 2026-10-29
---

# Teardown - Sol's RNG

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Client rolls -> server rolls only
> - Avoid: Paid speed-ups treated as outside the rules -> disclose odds before any paid access to rolls
> - Avoid: Display odds from a different table -> one table feeds both
> - Is the first roll available within five seconds?
> - Does every aura show its "1 in N" from the same table the server rolls from?
> - Do modifiers update displayed odds live?
>
> Cost: TL;DR ~140 tok · whole note ~2.9k tok. Read more: ## Snapshot · ## Technical notes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

> **In one line:** press Roll, get an aura with a "1 in N" rarity, keep the rarest; potions, gear and world "biomes" shift your luck, and the hunt for a one-in-hundreds-of-millions result can last months.

Sol's RNG is the long-running leader of the "RNG" (roll for rarity) wave that started in early 2024. Its core verb is the shortest possible: one button. Everything else (biomes, crafting, potions, seasons) exists to make that button feel different over time. It is the reference game for *odds as content*, and for why **free** randomness is treated differently from **paid** randomness under the 2026 rules.

Labels: **Measured**, **Roblox docs**, **Rule of thumb**, **Unverified** ([[Viral and Trend Teardowns Start Here]]).

## Snapshot

| Fact | Value | Label | Source and date |
|---|---|---|---|
| Created | 2023-12-03 | Measured | Roblox game API, 2026-10-29 |
| Owner group | Sol's Studio | Measured | Roblox game API, 2026-10-29 |
| Genre on Roblox | Simulation / Incremental Simulator | Measured | Roblox game API, 2026-10-29 |
| Server size | 20 players | Measured | Roblox game API, 2026-10-29 |
| Playing now | 32,339 (08:06 UTC Thursday), #27 on Top Playing Now | Measured | Roblox game and explore APIs, 2026-10-29 |
| Visits | 2,256,802,376 | Measured | Roblox game API, 2026-10-29 |
| Favourites | 1,031,056 | Measured | Roblox game API, 2026-10-29 |
| Votes | 1,430,411 up / 134,349 down, about 91.4% positive | Measured (computed) | Roblox votes API, 2026-10-29 |
| Peak CCU recorded by one tracker | 156k on 2026-04-25 (the tracker's own history; earlier 2024 peaks may be missing) | Measured (tracker) | RoWatcher, seen 2026-10-29 |
| Recent averages | 7-day about 31k, 30-day about 36k | Measured (tracker) | RoWatcher, seen 2026-10-29 |
| Content scale | 400+ auras (store page) | Measured | Roblox game API description, 2026-10-29 |
| Update naming | Series renamed from "Era" to "Eon" with Eon 1 on 2024-11-10 | Unverified | Sportskeeda patch notes, 2024 |
| Example odds | one aura 1 in 180,000,000, improving to 1 in 30,000,000 in a specific biome | Unverified | ProGameGuides, 2025 |
| Rarest regular biome (Dec 2025) | 1 in 7,777 chance per second to start, 5x "breakthrough" multiplier, nine biomes total | Unverified | Guide summary of the 2025-12-06 update |
| Public game passes (on sale) | VIP 249; VIP+ 350; Quick roll 100; RNG Premium Pass Season VIII 499; Starter Pack 49; Merchant Teleporter 40; Invisible Gear 80 (Robux). Eight earlier season passes and three "Innovator" packs off sale | Measured | Roblox game-pass API, 2026-10-29 |

## Core loop

```text
 Roll ──► aura (1 in N) ──► keep / equip / store
   ▲                           │
   │                           ▼
 luck modifiers:        craft gear from auras ──► gear raises luck or roll speed
 potions, gear,                │
 biome of the moment ◄─────────┘
   │
   └── world events: biomes rotate on server time, some auras only roll (or roll better) in a biome
```

## First 60 seconds

1. The Roll button is the first thing you see. Press it.
2. An aura animation plays, with its "1 in N" displayed big. Even a common one feels like a moment.
3. Auto-roll or quick roll appear soon; the numbers start flowing.
4. Within the first minutes a biome change washes over the server, teaching that the world affects luck.

## Progression and economy

- **Collection:** 400+ auras with explicit "1 in N" rarities. The denominator is the trophy.
- **Luck stack:** potions, crafted gear and biome conditions. Some auras have amplify conditions that change their odds in a specific biome (guides; Unverified values).
- **Crafting** converts auras (including duplicates) into gear, giving every roll a use.
- **Merchants** visit with stock; a teleporter pass gets you there faster.
- **Seasons** (premium pass per season since at least Season I) add a reward track.

## Monetization and 2026 compliance

Sol's RNG is a useful compliance case because its core randomness is **earned**, not bought: rolling is free. The 2026 paid-random-item policy applies to random items bought directly or indirectly with Robux, and to paid probability modifiers (Roblox docs, 2026-05-26).

- **Free rolls** are earned randomness; showing odds is still good design, and the game shows them on every aura.
- **Quick roll** speeds up rolling for 100 Robux. It does not change the odds per roll, but it buys more random outcomes per minute. A conservative reading is to treat any paid feature that increases access to random outcomes as in scope and disclose the full odds before purchase (Rule of thumb; the policy text is about items and probability modifiers).
- **Paid potions or luck boosts,** if sold for Robux, are probability modifiers: state the effect numerically before purchase and update displayed odds live while active.
- **Season premium passes** with fixed rewards are fine; if a pass grants random rewards, disclose them.
- Gate every paid random path with `PolicyService` fail-closed and offer a compliant alternative to restricted players ([[Regional Compliance - Paid Random Items and Country Rules]]).
- See [[Paid Random Items and Odds Disclosure in Practice]] and [[Skill - Roblox Monetization Compliance]].

## Retention hooks

- **Biome rotation on server time** is a built-in event calendar: "Hell biome is up, roll now".
- **Long-tail chase:** with odds in the hundreds of millions, the top of the collection is a months-long goal.
- **Seasons and numbered Eons** give returning players a fresh pass and new auras.
- **Free private servers** (store page) let players roll in peace and invite friends; private-server joins count as intentional co-play in RFY (Roblox docs).

## Multiplayer and social design

Twenty-player servers turn one player's rare roll into a server-wide event: big announcements and visual effects make luck social. Equipped auras are visible status. There is no direct player-versus-player interaction at the core.

## Art, UI, title and thumbnail

- **Title:** "[creator name]'s RNG" plus the current event in brackets. The possessive gives the genre a brand.
- **Aura art is the product.** Each aura is a stack of particles, beams and colour that reads at a glance; rarity must be legible from the effect alone.
- **Description:** a confident headline claim, then emoji verbs: roll, craft, drink potions, compete.

## Technical notes

- **Rolls on the server,** always, with the luck stack computed from server-known modifiers. The same table renders the odds UI.
- **Aura VFX budget:** 20 players each wearing a large aura is a heavy particle load. Offer "hide others' auras" and LOD for distant players ([[Juice on a Budget - Mobile and Low-End]], [[Graphics and Performance Toggles for Low-End Devices]]).
- **Biomes from server time** so every server agrees without messaging (the same technique as a shared restock clock).
- **Huge denominators:** use integer odds tables and format numbers carefully ([[Big Numbers Precision and Formatting]]).

```lua
--!strict
-- One table feeds both the roll and the odds panel. Weights are integers.
type Entry = { id: string, weight: number }

local function roll(entries: { Entry }, rng: Random): string
	local total = 0
	for _, e in entries do
		total += e.weight
	end
	local pick = rng:NextInteger(1, total)
	for _, e in entries do
		pick -= e.weight
		if pick <= 0 then
			return e.id
		end
	end
	return entries[#entries].id
end

local function oneIn(entries: { Entry }, id: string): number
	local total, w = 0, 0
	for _, e in entries do
		total += e.weight
		if e.id == id then
			w = e.weight
		end
	end
	return if w > 0 then total / w else math.huge
end

return { roll = roll, oneIn = oneIn }
```

## Why it went viral

1. **The minimum viable verb.** One button and a number. Nothing to learn, endless to chase.
2. **Odds as a story.** "I got a 1 in 180 million" is a sentence that spreads on video.
3. **Timing.** Created in December 2023, it rode the early-2024 RNG wave and outlasted most of it by turning the button into a world (biomes, crafting, seasons).
4. **Steady named updates** (Eras, then Eons) and seasonal passes.

## Build it yourself

| System | Notes | Vault notes |
|---|---|---|
| Weighted roll with "1 in N" UI | One table, integer weights | [[RNG Drops and Luck Systems]], [[Drop Tables Rarity and Pity Systems]] |
| Luck modifiers with live odds | Recompute and redisplay when a modifier changes | [[Paid Random Items and Odds Disclosure in Practice]] |
| Biomes on server time | Deterministic schedule | [[Live Ops Events and Updates]] |
| Crafting from duplicates | Recipe table, server-validated | [[Economy Inflation Sinks and Faucets Math]] |
| Season pass | Free and premium tracks | [[Battle Pass and Season Design]] |
| Rare-roll announcements | Server and cross-server | [[Cross-Server Messaging]] |
| Data | Large inventories need compact storage | [[DataStore Fundamentals]], [[LihFolk Systems Library]] |

## Raise the quality bar

- **Make every roll useful.** Crafting, dust or quest credit for commons keeps the button rewarding between rare hits.
- **Odds panel with context:** base odds, every active modifier, and the final odds per aura, in plain numbers.
- **Readable auras:** rarity tiers should differ in silhouette and motion, not only colour, for colour-blind players ([[Colourblind Palettes Text Size and Tooltips]]).
- **Respect time:** offline progress or capped auto-roll keeps the chase healthy without encouraging all-day AFK.

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Client rolls | impossible auras in inventories | server rolls only |
| Paid speed-ups treated as outside the rules | policy review risk | disclose odds before any paid access to rolls |
| Display odds from a different table | "1 in N" text wrong after an update | one table feeds both |
| Unlimited aura VFX for all players | phones overheat in full servers | hide-others toggle, LOD |
| Floating-point odds with huge denominators | rounding errors in UI | integer weights, careful formatting |

## Checklist

- [ ] Is the first roll available within five seconds?
- [ ] Does every aura show its "1 in N" from the same table the server rolls from?
- [ ] Do modifiers update displayed odds live?
- [ ] Is every paid path to random outcomes disclosed and `PolicyService`-gated?
- [ ] Can players hide other players' auras?
- [ ] Does each update add a new reason to roll (biome, recipe, season)?

## See also

- [[Viral Game Anatomy - Hooks, Loops and Timing]]
- [[Teardown - Fish It]] ("1 in X" fish), [[Teardown - Tap Simulator REBORN]]
- [[Genre Playbook - RNG and Collection Games]], [[Simulator and RNG Genre Teardown]]

## Sources

- Roblox public game, votes, game-pass and explore APIs, read 2026-10-29 08:06 UTC.
- RoWatcher game page and "Sol's RNG and the luck-based game craze", seen 2026-10-29.
- Sportskeeda Eon 1 patch notes (2024-11); ProGameGuides aura list; guide summaries of the December 2025 biome update (Unverified values).

<!-- related:start -->
## Related
[[Teardown - Plants vs Brainrots]] · [[Teardown - Ride A Pet]] · [[Teardown - Escape Tsunami for Brainrots]] · [[Teardown - Bee Swarm Simulator]] · [[Teardown - Steal An Egg]] · [[Teardown - +1 Speed Keyboard Escape]] · [[Teardown - Tower of Hell]] · [[Teardown - Build A Boat For Treasure]]
<!-- related:end -->
