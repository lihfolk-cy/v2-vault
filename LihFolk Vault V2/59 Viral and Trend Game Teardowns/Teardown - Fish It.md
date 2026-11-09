---
tags: [teardown, viral-trend, fishing, collection, rng, simulator, incremental, battle-pass, live-ops, type/case-study, area/design, level/intermediate]
verified: 2026-10-29
---

# Teardown - Fish It

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Luck pass sold without numeric effect -> state the multiplier and show boosted odds
> - Avoid: Client decides the catch -> roll on the server
> - Avoid: AFK fishing with no limit -> diminishing AFK rate, idle checks
> - First catch inside 30 seconds with no reading?
> - Are all catch, mutation and luck rolls server-side?
> - Does each luck product state its effect numerically and update displayed odds while active?
>
> Cost: TL;DR ~150 tok · whole note ~2.8k tok. Read more: ## Snapshot · ## Monetization and 2026 compliance · ## Common mistakes · ## Checklist
<!-- tldr:end -->

> **In one line:** a fast, forgiving fishing collector: click to cast, click quickly to reel, sell the catch, buy better rods and boats, and chase fish listed as "1 in X" rarities across a cluster of nearby islands.

Fish It is the simplified fishing hit. It openly names its inspirations in the store description (Fisch and an older fishing simulator), then removed most of the friction that made fishing games hard for younger players. It grew from a few thousand players to a top-6 all-time peak in about four months. Compare with [[Case Study - Fisch]], which this note does not repeat.

Labels: **Measured**, **Roblox docs**, **Rule of thumb**, **Unverified** ([[Viral and Trend Teardowns Start Here]]).

## Snapshot

| Fact | Value | Label | Source and date |
|---|---|---|---|
| Created | 2024-10-21 | Measured | Roblox game API, 2026-10-29 |
| Owner group | Fish Atelier | Measured | Roblox game API, 2026-10-29 |
| Genre on Roblox | Simulation / Incremental Simulator | Measured | Roblox game API, 2026-10-29 |
| Server size | 20 players | Measured | Roblox game API, 2026-10-29 |
| Playing now | 58,603 (08:06 UTC Thursday), #13 on Top Playing Now | Measured | Roblox game and explore APIs, 2026-10-29 |
| Visits | 4,805,147,256 | Measured | Roblox game API, 2026-10-29 |
| Favourites | 1,295,038 | Measured | Roblox game API, 2026-10-29 |
| Votes | 1,348,047 up / 279,409 down, about 82.8% positive | Measured (computed) | Roblox votes API, 2026-10-29 |
| All-time peak CCU | 2,716,766 on 2025-12-07 | Measured (tracker) | Rolimons; GGAID gives 2,719,050; RoMonitor 2.72M; seen 2026-10-29 |
| Average CCU by month, 2025 | about 50k (Aug), 186k (Sep), 389k (Oct), 839k (Nov), over 1M (early Dec) | Measured (tracker, as reported) | Max Power Gaming, 2025-12 |
| All-time rank | sixth by peak at the time, one of 16 games ever above 1M | Measured (tracker, as reported) | Max Power Gaming citing Rolimons, 2025-12 |
| Average session | about 30 minutes, linked to AFK auto-fish | Unverified | Max Power Gaming, 2025-12 |
| Rarest fish odds | 1 in 4,000,000 for the top fish at the time | Unverified | Max Power Gaming, 2025-12 |
| Bot questions | some observers questioned organic numbers; weekend spikes suggest real players | Unverified | Max Power Gaming; GameBoost, 2025-12 |
| Public game passes (on sale) | VIP 445; Advanced Luck 545; Extra Luck 245; Small Luck 50; More Mutations 295; Hyper Pack 999; Sell Anywhere 315; Double XP 195; Mini Hoverboat 225; three themed packs at 399 (Robux). Several limited boats and seasonal packs off sale | Measured | Roblox game-pass API, 2026-10-29 |

## Core loop

```text
 cast (click to charge) ──► reel (click fast) ──► catch: species × variant × mutation
      ▲                                                  │
      │                                                  ▼
  better rod / bait / boat ◄── coins ◄── sell (or keep for index / quests)
      │
      └──► new island unlocked ──► new fish pool ──► "1 in X" chase
                     │
          events, battle pass, crews, group fishing events
```

## First 60 seconds

1. You spawn on a dock with a rod already equipped (auto-equip is part of the simplification, per Max Power Gaming).
2. The store description's whole tutorial is two steps: click to charge, then click quickly. The first catch arrives in seconds.
3. A quest arrow points to the seller and the next objective; points of interest are labelled.
4. First coins buy the first rod upgrade. Upgrades, bigger fish and a new area all come within minutes (Max Power Gaming).

## Progression and economy

- **Currency:** coins from selling fish.
- **Gear ladder:** rods, bait, boats. Boats unlock new zones; islands sit close together so travel is short.
- **Rarity display:** "1 in X" odds on fish instead of weight-based tiers. Showing the denominator *is* the chase; a 1-in-millions fish is a story.
- **Variants:** the store page claims over a million fish variations from species, mutations and other modifiers (store description, 2026-10-29; marketing claim, Unverified).
- **AFK auto-fish:** unlocks during play and can be toggled. It raises session time and lowers the skill floor (Unverified effect size).
- **Battle pass and gacha:** the October 2026 description mentions a limited battle pass, a gacha and a skin crate with animated rods.

## Monetization and 2026 compliance

Fish It sells **luck** in three sizes (50, 245, 545 Robux) and a **mutation** pass. Under the 2026-05-26 clarification these are **probability modifiers**: a paid luck pass counts as a paid random item feature (Roblox docs).

- Before purchase, explain each luck pass's effect numerically, and show the fish odds that change.
- While the pass is active, displayed odds must update to the boosted values.
- Gacha and skin crates bought with Robux need full outcome lists with odds summing to 100%, value in every outcome, and `PolicyService` gating that fails closed.
- See [[Paid Random Items and Odds Disclosure in Practice]] and [[Regional Compliance - Paid Random Items and Country Rules]].
- **Convenience passes** (Sell Anywhere, Double XP, hoverboat) are clean fixed-price sales.

The "1 in X" display already used for fish is a strong base for compliance: it is a habit of showing odds, which a builder can extend into the purchase screen.

## Retention hooks

- **Collection index** with rare denominators.
- **Seasonal expansions** with new secret fish (Halloween 2026: new fish, secrets, limited battle pass, per the store description).
- **Crews and group fishing events** (2026 update) add a reason to play with others.
- **AFK mode** lets a player keep a session going; note that RFY credits only the first 60 minutes per user per day (Roblox docs), so AFK time beyond that does not help discovery. See [[AFK Detection Idle Kicks and AFK Reward Rules]].

## Multiplayer and social design

Twenty players share islands. Fishing is parallel play: you see others' catches and rods, and server-wide announcements of rare catches make one player's luck everyone's moment. Crews add a light group identity. No player can harm another.

## Art, UI, title and thumbnail

- **Title:** a two-word imperative with an exclamation mark. Plain, verb-first, readable at icon size.
- **Seasonal tag** in brackets and an "UPD" tag signal freshness.
- **Description:** update headlines in capitals first, then the two-line how-to. It reads like a patch billboard, which suits returning players.
- **Crediting inspirations** in the description is unusual and honest; it also sets expectations.

## Technical notes

- **20-player servers on water:** keep boats simple (few parts, client-side bobbing) and fish models tiny or 2D in UI; see [[Boats Buoyancy and Water]] and [[Juice on a Budget - Mobile and Low-End]].
- **Rolls on the server.** The catch roll, mutation roll and luck multiplier all live on the server; the client only plays the reel minigame and sends a result that the server sanity-checks (time to reel, click rate).
- **AFK fishing needs limits** so it does not become an exploit for unlimited currency ([[Autoclicker and Macro Detection for Combat Remotes]] covers rate patterns).

## Why it went viral

1. **Simplification of a proven genre.** Fishing was already popular through Fisch; Fish It lowered the fail rate, added arrows and auto-equip, and put islands close together (Max Power Gaming).
2. **Timing.** Its climb from August 2025 coincided with what Max Power Gaming describes as Fisch's weaker period, leaving room for a friendlier fishing game.
3. **Odds as spectacle.** "1 in 4,000,000" is a headline in itself.
4. **Steady update rhythm** through autumn 2025, with month-on-month average CCU roughly doubling.

## Build it yourself

| System | Notes | Vault notes |
|---|---|---|
| Cast and reel minigame | Client feel, server validation of timing | [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]] |
| Weighted catch table with "1 in X" display | One table feeds roll and UI | [[RNG Drops and Luck Systems]], [[Drop Tables Rarity and Pity Systems]] |
| Luck modifiers with live odds | Recompute displayed odds when a boost starts or ends | [[Paid Random Items and Odds Disclosure in Practice]] |
| Index and quests | Collection log; quest arrows | [[Quest Chain System End to End]] |
| Boats and zones | Simple boats, zone gates | [[Boats Buoyancy and Water]] |
| Battle pass | Free and premium tracks | [[Battle Pass and Season Design]] |
| Rare-catch announcements | Server-wide and cross-server | [[Cross-Server Messaging]] |
| Data | Session lock, inventory caps | [[LihFolk Systems Library]] |

## Raise the quality bar

- **Keep a little skill in the reel.** A forgiving minigame with an optional "perfect reel" bonus satisfies both young and older players.
- **Make the index a journey.** Silhouettes, habitat hints and per-island completion rewards turn rarity into exploration.
- **Odds UI as a first-class screen.** Show base odds, active boosts and the boosted result side by side.
- **Cap AFK rewards sensibly** and reward active play more, so sessions stay meaningful.

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Luck pass sold without numeric effect | moderation notice | state the multiplier and show boosted odds |
| Client decides the catch | impossible fish appear in inventories | roll on the server |
| AFK fishing with no limit | currency inflation, bot farms | diminishing AFK rate, idle checks |
| Separate display odds and roll odds | "1 in X" text does not match drops | one table |
| Heavy boats and many fish models | low-end phone frame drops | simple boats, fish shown in UI |

## Checklist

- [ ] First catch inside 30 seconds with no reading?
- [ ] Are all catch, mutation and luck rolls server-side?
- [ ] Does each luck product state its effect numerically and update displayed odds while active?
- [ ] Are gacha and crates disclosed with odds summing to 100% and gated by `PolicyService`?
- [ ] Are AFK rewards bounded?
- [ ] Is there a rare-catch announcement that makes luck social?

## See also

- [[Viral Game Anatomy - Hooks, Loops and Timing]]
- [[Case Study - Fisch]] (the deeper fishing game it simplified)
- [[Teardown - Sol's RNG]] (odds-as-spectacle)
- [[Genre Playbook - RNG and Collection Games]], [[Simulator and RNG Genre Teardown]]

## Sources

- Roblox public game, votes, game-pass and explore APIs, read 2026-10-29 08:06 UTC.
- Rolimons game page for place 121864768012064; GGAID; RoMonitor; seen via search 2026-10-29.
- Max Power Gaming, "Fish It: How a Simplified Copycat Became One of Roblox's Biggest Hits", 2025-12.
- games.gg, "Fish It unexpected rise to the top of Roblox", 2025.
- GameBoost, "Fish It! vs Fisch", 2025-12.

<!-- related:start -->
## Related
[[Teardown - Tap Simulator REBORN]] · [[Teardown - Plants vs Brainrots]] · [[Teardown - Ride A Pet]] · [[Teardown - Bee Swarm Simulator]] · [[Teardown - +1 Speed Keyboard Escape]] · [[Teardown - Steal An Egg]] · [[Teardown - Escape Tsunami for Brainrots]] · [[Teardown - Build A Boat For Treasure]]
<!-- related:end -->
