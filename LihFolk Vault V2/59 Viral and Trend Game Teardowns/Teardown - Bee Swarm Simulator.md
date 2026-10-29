---
tags: [teardown, viral-trend, evergreen, simulator, collection, quests, seasonal-events, solo-dev, type/case-study, area/design, level/intermediate, area/liveops]
verified: 2026-10-29
---

# Teardown - Bee Swarm Simulator

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Simulating every bee on the server -> server tracks outputs, clients animate bees
> - Avoid: Depth shown all at once -> staged unlocks, quest arrows
> - Avoid: Odds only on community wikis -> in-game odds panel
> - Does the first gather-convert-spend loop finish inside a minute?
> - Are bee or pet visuals client-side with server-owned outputs?
> - Are random eggs and paid luck disclosed in game with odds summing to 100%?
>
> Cost: TL;DR ~150 tok · whole note ~2.4k tok. Read more: ## Snapshot · ## Monetization and 2026 compliance · ## Common mistakes · ## Checklist
<!-- tldr:end -->

> **In one line:** collect pollen from flower fields with a growing swarm of bees, turn it into honey, and spend honey on more bees, better tools and new areas up the mountain, guided by quest-giving bears.

Bee Swarm Simulator is the enduring classic of the collect-and-convert simulator. It launched in 2018, is built and run by one developer, and still sat in the top 40 of "Top Playing Now" in the snapshot for this note. It is the counter-example to the spike-and-fade trend game: slow updates, very deep systems, and a once-a-year seasonal event that brings the audience back.

Labels: **Measured**, **Roblox docs**, **Rule of thumb**, **Unverified** ([[Viral and Trend Teardowns Start Here]]).

## Snapshot

| Fact | Value | Label | Source and date |
|---|---|---|---|
| Created | 2018-03-21 | Measured | Roblox game API, 2026-10-29 |
| Owner | Onett (a user account, not a group) | Measured | Roblox game API, 2026-10-29 |
| Last update stamp | 2026-08-22 | Measured | Roblox game API, 2026-10-29 |
| Genre on Roblox | Adventure-tagged; Simulation / Incremental Simulator | Measured | Roblox game API, 2026-10-29 |
| Server size | 6 players | Measured | Roblox game API, 2026-10-29 |
| Playing now | 30,338 (08:06 UTC Thursday), #32 on Top Playing Now | Measured | Roblox game and explore APIs, 2026-10-29 |
| Visits | 4,632,703,364 | Measured | Roblox game API, 2026-10-29 |
| Favourites | 6,563,556 | Measured | Roblox game API, 2026-10-29 |
| Votes | 3,044,891 up / 139,988 down, about 95.6% positive | Measured (computed) | Roblox votes API, 2026-10-29 |
| All-time peak CCU | about 265,000 during a winter "Beesmas" event | Unverified | RoWatcher article, 2026 (a draft wiki page gives about 200,000) |
| Seasonal surges | 147,000 to 170,000 during Beesmas peaks | Unverified | RoWatcher articles, 2026 |
| Recent seasonal timing | the winter 2025 event ran into March 2026 | Unverified | RoWatcher article, 2026 |
| Average session | 25-31 minutes for longer-lived sims including this one | Unverified | Adellion snapshot 2026-10-02, via the research module |
| Public game passes | four listed (x2 ticket chance, a special bee, x2 pollen gathering, x2 convert speed); the API returned no price for any of them on the snapshot date | Measured | Roblox game-pass API, 2026-10-29 |

## Core loop

```text
 field ──► bees + tool collect pollen ──► backpack full
   ▲                                       │
   │                                       ▼
 new fields (bee-count gates)        hive converts pollen → honey
   ▲                                       │
   │                                       ▼
 more / better bees, tools, gear ◄──── spend honey, tickets, treats
   │
   └── bear quests (guided goals) ── mobs and bosses ── hidden treasures
```

## First 60 seconds

1. Claim a hive slot; your first bee hatches.
2. Walk into the nearest field and swing your tool. Pollen numbers pop from the flowers and your bees fly to help.
3. The backpack fills fast. Walk home, convert to honey.
4. A friendly bear gives the first quest, which points you at the next purchase.

The loop is fully visible in the first minute: gather, carry, convert, spend.

## Progression and economy

- **Bees** are the collection: many types with traits, rarities and gifted variants (store description: each type has its own traits and personality).
- **Fields** are gated by the number of bees, so the collection doubles as the map key.
- **Tools, bags and gear** raise collection and capacity.
- **Quests** from several bears give structured goals for years of content.
- **Secondary currencies** (tickets, treats, event items) and crafting-like conversions provide sinks.
- **Rarity tables:** egg and jelly odds are community-documented; no official table was checked for this note.

## Monetization and 2026 compliance

The visible store is small: four multiplier-style passes, with no price returned by the public API on the snapshot date (they may be temporarily off sale). The game has historically sold premium currency and items as developer products, which are not visible from outside.

- A **"x2 ticket chance"** style pass affects a random drop. Under the 2026-05-26 clarification that is a probability modifier: explain its effect numerically before purchase and update displayed odds while active (Roblox docs).
- **Random eggs or jellies bought with premium currency that is bought with Robux** count as paid random items indirectly; disclose all outcomes with odds summing to 100% and gate with `PolicyService` ([[Paid Random Items and Odds Disclosure in Practice]]).
- **Doubling passes** for gathering and converting are clean, self-only sales.

## Retention hooks

- **The annual winter event** is the heartbeat: trackers describe it as the source of every big peak (Unverified figures).
- **Long quest lines** give returning players a clear next step even after months away.
- **Hive building** is slow, visible, permanent progress.
- **Hidden treasures and secrets** reward exploration and community knowledge-sharing.

## Multiplayer and social design

Six-player servers share fields, so you see other swarms working beside you. Co-operation is light (shared boss fights, field boosts), and status is shown through hive size and rare bees. The community lives largely outside the game, in the developer's group and fan wikis.

## Art, UI, title and thumbnail

- **Title:** the plainest form, "[Thing] Simulator", from the 2018 naming era. No tags, no update numbers.
- **Art:** soft, toy-like bees with distinct colours per type; fields as colour-coded flower beds. The style has aged gently because it is simple and consistent.
- **Description:** a calm paragraph rather than emoji bullets, written as an invitation.

## Technical notes

- **Hundreds of bees in view.** Each player's swarm is a crowd; bees must be cheap (simple meshes, client-side flight, server tracks counts and outputs, not positions).
- **Pollen numbers** are pure juice; batch number pop-ups to avoid UI spam ([[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]]).
- **Six-player servers** keep fields from crowding and keep bee counts affordable.

## Why it went viral, and why it lasted

1. **A cute, specific fantasy.** "Raise a bee swarm" is clearer and warmer than a generic "collect coins" simulator.
2. **Depth at the top.** Years of quests, bees and gear mean the endgame never runs out quickly.
3. **One developer, one voice.** A consistent tone and a small, careful update cadence built trust (RoWatcher profile articles, 2026).
4. **The seasonal event as a ritual.** Players return every winter like a holiday.

## Build it yourself

| System | Notes | Vault notes |
|---|---|---|
| Gather into a capacity bag, convert at home | Server-owned bag and conversion rate | [[Tycoon Plots and Droppers End to End]] |
| Collection gates the map | Field gates by bee count | [[Server Authority and Validation]] |
| Bee hatching and traits | Weighted, data-driven | [[Pet Hatching and Following End to End]], [[Drop Tables Rarity and Pity Systems]] |
| Quest-giver NPCs | Quest chains with rewards | [[Quest Chain System End to End]], [[Quest Writing and Hooks]] |
| Seasonal event | Event currency, calendar | [[Event Calendars and Content Planning]], [[Currency Architecture - Soft Hard and Event Currencies]] |
| Data | Very large inventories | [[Session Locking and Profile Libraries]], [[LihFolk Systems Library]] |

## Raise the quality bar

- **Onboard the depth gently.** A new player in 2026 meets years of systems; staged unlocks and a "what next" hint keep it friendly ([[Skippable Tutorials and Replayable Tips]]).
- **Odds in game, not only on wikis.** A built-in odds panel for every egg and jelly is now expected and builds trust.
- **Seasonal events with a bridge.** Small monthly beats between big yearly events keep the community warm.

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Simulating every bee on the server | server heartbeat drops | server tracks outputs, clients animate bees |
| Depth shown all at once | new players bounce | staged unlocks, quest arrows |
| Odds only on community wikis | trust and policy risk | in-game odds panel |
| Paid ticket-chance boost without numbers | moderation notice | state the multiplier, show boosted odds |

## Checklist

- [ ] Does the first gather-convert-spend loop finish inside a minute?
- [ ] Are bee or pet visuals client-side with server-owned outputs?
- [ ] Are random eggs and paid luck disclosed in game with odds summing to 100%?
- [ ] Is there a yearly anchor event plus smaller beats between?
- [ ] Do quests always show the next step?

## See also

- [[Viral Game Anatomy - Hooks, Loops and Timing]]
- [[Case Study - Pet Simulator 99]], [[Case Study - Adopt Me]]
- [[Genre Playbook - Simulators]], [[Simulator and RNG Genre Teardown]]

## Sources

- Roblox public game, votes, game-pass and explore APIs, read 2026-10-29 08:06 UTC.
- RoWatcher, "Onett's Seven-Year Marathon" and "Bee Swarm Simulator: How One Developer Built a Roblox Empire That Won't Quit", 2026.
- Adellion 2026-10-02 snapshot, via the LihFolk trend-game research module.

<!-- related:start -->
## Related
[[Teardown - Ride A Pet]] · [[Teardown - Tap Simulator REBORN]] · [[Teardown - Escape Tsunami for Brainrots]] · [[Teardown - Steal An Egg]] · [[Teardown - Plants vs Brainrots]] · [[Teardown - Sol's RNG]] · [[Teardown - Fish It]] · [[Teardown - Build A Boat For Treasure]]
<!-- related:end -->
