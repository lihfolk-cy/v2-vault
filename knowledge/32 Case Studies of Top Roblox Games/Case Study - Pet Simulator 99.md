---
tags: [case-study, top-games, simulator, pets, rng, trading, live-ops, monetization, thumbnails, sequel]
---

# Case Study - Pet Simulator 99

<!-- tldr:start -->
> [!tldr] TL;DR
> - The core verb pays out in the first ten seconds; first hatch within two minutes.
> - One long-term currency, plus per-world soft currencies if you have worlds.
> - Rebirths unlock features rather than only resetting numbers.
> - Trading opens only after a progress milestone.
> - Title skeleton fixed; one bracketed tag rotates per update.
> - Release slot fixed and announced.
>
> Read more (16 KB note): ## Snapshot · ## Click-through: thumbnail, icon and title · ## Checklist
<!-- tldr:end -->

Pet Simulator 99 (PS99) is the third major Pet Simulator game from BIG Games: pets break coins, coins buy eggs and zones, eggs hatch stronger pets, and a trading economy built around rare "Huge" pets keeps the top end alive. It is the reference for three things on Roblox: launching a sequel that carries a franchise's players and items forward, running a weekly update machine for years, and building a store around paid luck. The first two are worth studying closely. The third needs care.

Source labels used below: **Public stats** (Roblox's public APIs or a stats site, with the date checked), **Observed on the store page** (the public experience page, thumbnails and pass list, October 2026; nothing was played or logged into), **Press** (news and guide sites, with their dates), **Studio statement**.

## Snapshot

| Field | Value | Source |
|---|---|---|
| Genre | Roblox lists it as "Simulation / Incremental Simulator" | Public stats, Roblox games API, checked 27 October 2026 |
| Creator | BIG Games Pets (group, verified badge) | Public stats, Roblox games API |
| Place created | 5 February 2022 (the place existed long before launch) | Public stats, Roblox games API |
| Public launch | 1 December 2023, 11am CST | Press, VGC (21 November 2023) and a PhatMojo press release dated 1 December 2023 |
| Name origin | Launched with 99 pets | Press, VGC, 21 November 2023 |
| Pets now | Description claims "3,000+ pets to collect" | Observed on the store page, 27 October 2026 |
| Visits | 2,684,104,054 | Public stats, Roblox games API, 27 October 2026 |
| Favourites | 2,217,476 | Public stats, Roblox games API |
| Votes | 3,076,120 up, 170,730 down (about 95% positive) | Public stats, Roblox votes API, 27 October 2026 |
| Playing at check time | 79,861 | Public stats, Roblox games API, 27 October 2026 |
| Typical concurrency | 7-day average about 52,200; 14-day average about 51,500 | Public stats site, RoTrends, read October 2026 |
| Peak concurrency | 481K on RoTrends (no date); 250K labelled December 2024 on RoWatcher | Public stats sites, read October 2026 |
| Server size | 10 | Public stats, Roblox games API |

The launch-week peak is not verified: neither tracker covers December 2023 reliably, and no press source with a launch concurrency number was found. A Wikipedia list of Roblox games records that the Pet Simulator series won Most Concurrent Users at the 2023 Innovation Awards with a 1.48 million peak; that award predates PS99's launch, so it belongs to the franchise's earlier game, not to PS99. Do not quote it as a PS99 number.

Context from Press: the predecessor Pet Simulator X added NFTs, the first on the platform, and its NFT project purchases were refunded in February 2023 (Wikipedia list of Roblox games, citing coverage). Pets could move from Pet Simulator X into PS99 through a "Pet Box" that carried Huges, Titanics and eggs, kept serials, signatures and gold or rainbow status, with a transfer limit resetting every seven days and the box available for six months; BIG Games said "the only things that won't transfer over are nicknames and enchantments" (Press, VGC, 21 November 2023). McDonald's Happy Meal toys followed in November 2024, and PhatMojo makes physical toys (Press). A June 2024 article asked whether BIG Games had "given up" on PS99 (Press, cited by Wikipedia); the game is still in the top tier in October 2026, which says a lot about the weekly machine.

## Click-through: thumbnail, icon and title

Roblox does not publish click-through rate for other people's games. What follows is reasoned from what is visible, plus what Roblox says it measures (qualified play-through rate under thumbnail personalization, Roblox docs as of October 2026; see [[Thumbnails Icons and Store Page]]).

**Title.** At check time: `🎉 [PSX] Pet Simulator 99! 🐾`. The structure never changes: emoji, bracketed update tag in capitals, the franchise name, "!" and a second emoji. Only the tag and emoji rotate. RoWatcher's archived page names for the same game show the tag history: `[PSX]`, `[DIAMOND]`, `[WORLD CUP]`, `[MINE]`, `[ARCADE]`, `[TAP HEROES]`, `[PETS vs COINS]`, `[LUCKY BLOCK]` and more (Public stats site, RoWatcher URLs, read October 2026). With a Saturday update every week (Public stats site, RoWatcher description; Press, multiple guides), the title is effectively a weekly headline. The `[PSX]` tag in October 2026 suggests a crossover with the predecessor's content; what that update contains was not verified.

Why it works: a returning player scanning their Continue row sees a new word in brackets and knows there is something new. A new player sees a franchise name and a number that implies scale. The emoji pair is colour on an otherwise text-only line.

**Icon** (Observed on the store page, October 2026). No text. Three of the franchise's mascot pets (a grey cat in front, a tiger and a green dragon behind) on a bright blue gradient with sparkles. Flat, thick-outlined, high-contrast cartoon style that reads at any size. The grey cat with big eyes is the series face, the way a mascot works for a cereal box.

**Thumbnails** (Observed, first two returned by the public thumbnails API, 27 October 2026):

1. A sunny meadow with two avatars and nine pets around a pond, the grey cat peeking in from the corner, a small BIG Games logo bottom left. No headline text.
2. A single huge-eyed red panda pet with a bedroll and maple leaf, on an autumn background with blue diamonds flying past. No text.

What earns the click:

- **Faces, big eyes, centre frame.** Every image is built around a cute face looking at the viewer. On a phone-sized card that reads instantly.
- **No text on thumbnails, all news in the title.** The title carries the update tag; the art carries the mood. Text on art would fight the update cadence (re-rendering text weekly is expensive; changing a bracket is free).
- **Brand style over content.** The flat illustrated style does not show actual gameplay. That is allowed for images, but Roblox's rules for video thumbnails require authentic in-game footage (Roblox docs), and the gap between illustration and the blocky in-game look is a known risk for disappointed first sessions.
- **Seasonal recolour.** The autumn palette in October without a Halloween takeover keeps the brand gentle for its young audience.

## First five minutes

Reconstructed from guides (not played for this note):

1. **Spawn and pets.** You arrive in the first area with starter pets. You click or tap breakables (coins, chests) and your pets swarm them. Within seconds coins are flying into your counter. The core verb is shown in the first ten seconds.
2. **First egg.** Coins buy an egg in the area; the hatch animation plays and the new pet is immediately equipped. This is the first reward and it arrives within the first minute or two.
3. **First gate.** The next area is behind a coin price. The newest area you can reach drops much more currency, so the guidance is to always farm the newest one (Press, U7Buy beginner guide, 19 October 2026).
4. **Quest arrows and ranks.** Goals appear with arrows, two active rank goals at a time from Rank 1, and claiming free gifts and rank rewards is pushed early (Press, U7Buy).
5. **Diamonds.** Cheap diamond upgrades (walkspeed, magnet) are recommended immediately (Press, U7Buy).

The structure is a textbook simulator onboarding: verb, reward, gate, goal, premium currency, all inside five minutes. See [[Genre Playbook - Simulators]] and [[First-Time User Experience and Onboarding]].

## Core loop and retention

**Session loop.** Break, collect, hatch, equip best, unlock next area, repeat. Coins are per world (Spawn, Tech, Void and Fantasy each use their own coin), while diamonds work everywhere and are the long-term currency (Press, U7Buy, October 2026). Per-world coins act as a soft reset when you move worlds, without taking anything away.

**Rebirths without loss.** Guides report nine rebirths at areas 25, 50, 75, 99, 125, 150, 175, 199 and 219, each adding 75% pet strength, and that rebirthing "no longer resets progress" (Press, U7Buy, 19 October 2026). Rebirth One unlocks Teleport, Auto Hatch and the key to the Trading Plaza. This is a rebirth used as a milestone and unlock, not as a punishment; compare [[Rebirth and Prestige System End to End]].

**Ranks and stars.** Rank goals award stars that fill a reward track; higher ranks add pet, egg and enchant slots (Press, U7Buy). Ranks are the daily driver of "what do I do next" without a classic daily login calendar (the guide does not mention one; not verified).

**Huges and trading.** Huge pets are the chase item: from events and season passes, luck windows, quests, minigames, or bought in the Trading Plaza (Press, U7Buy). The Trading Plaza opens after the first rebirth, so new accounts cannot be scammed on day one. Players sell strong pets there, often for diamonds, and prices vary between servers (Press, U7Buy). The serial numbers carried over from the predecessor make some pets collectible objects with a history.

**Weekly cadence.** Updates release on Saturdays at 5:00 PM GMT, weekly, with numbered updates (Update 73 was the St. Patrick's Event 2026 on 14 March 2026, Update 74 added a Lucky Race) (Public stats site, RoWatcher game description, read October 2026). A weekly beat lets the title tag change weekly and gives content creators a weekly video topic. See [[Update Cadence and Hype Cycles]] and [[Event Calendars and Content Planning]].

**Performance.** A "Potato Mode" disables visual effects for low-end devices (Public stats site, RoWatcher description). For a game with hundreds of pets on screen, that setting is part of retention on cheap phones.

## Monetization

The full public pass list from the Roblox game pass API, 27 October 2026 (Observed on the store page):

| Pass | Price (Robux) | Kind |
|---|---|---|
| Auto Farm! | 175 | Convenience |
| Lucky! | 275 | Paid luck |
| Auto Tap! | 350 | Convenience |
| +15 Pets! | 375 | Capacity |
| VIP! | 400 | Access and perks |
| +15 Eggs! | 625 | Capacity (hatch more per open) |
| Daycare Slots! | 625 | Capacity |
| Ultra Lucky! | 800 | Paid luck |
| Magic Eggs! | 1,200 | Paid luck (gold and rainbow chance) |
| Super Shiny Hunter! | 1,600 | Paid luck |
| Double Stars! | 2,400 | Progress multiplier |
| Super Drops! | 2,400 | Drop multiplier |
| Huge Hunter! | 3,250 | Paid luck (Huge chance) |

Guide descriptions of effects (Press, ProGameGuides and others, 2025 to 2026): Lucky gives 200% better egg luck; Ultra Lucky gives +500% and stacks with Lucky; Huge Hunter increases luck hatching active Huges; VIP grants a private diamond area, a rewards chest and diamonds. Older guides list lower prices for some passes (for example Magic Eggs at 480 and Huge Hunter at 1,300), so prices have been raised over time. One guide says an MVP subscription billed monthly was added in April 2025; that was not verified from an official source.

Beyond passes: developer products (diamond packs, exclusive eggs, boosts) are not listed by the public API without logging in and are not itemised here. Real-world merchandise with redeemable codes is a revenue line too (Press, search coverage of the BIG Games merch store, unverified detail).

Read the table as a design: five of thirteen passes sell luck, three sell capacity, two sell automation, two sell multipliers. The top of the price ladder is luck on the rarest item. That is the engine of the business and also the part of the design most exposed to policy and parents. See [[Paid Random Items and Odds Disclosure in Practice]].

## What to copy

1. **The sequel bridge.** Let players carry identity and rare items into the new game, with a rate limit and a deadline (seven-day limit reset, six-month window). It rewards loyalty, fills the new economy with recognisable status items on day one and gives the old audience a reason to show up at launch. Build it with [[Saved Inventory End to End]] and [[Schema Migrations - Worked Case Studies]]; guard duplication with [[Trading Systems Without Duplication]].
2. **A fixed weekly release slot.** Same day, same hour, numbered updates. Your team, your players and your creators all plan around it. [[Event Calendars and Content Planning]], [[Patch Notes and Player Communication]].
3. **Title as a headline, art as a mood.** Keep a fixed title skeleton and rotate one bracketed tag per update. Keep text off the art so art can live for months. See [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]].
4. **Per-world currency plus one global currency.** Soft resets without loss, and a single long-term currency for the store and trading. [[Economies and Currencies]], [[Economy Inflation Sinks and Faucets Math]].
5. **Rebirth as unlock, not loss.** Attach new features (teleport, auto hatch, trading access) to rebirths so the milestone feels like a door opening. [[Rebirth and Prestige System End to End]], [[Progression and Pacing Design]].
6. **Gate trading behind progress.** Opening the Trading Plaza after the first rebirth protects brand-new accounts from scams and gives trading a place in the progression. [[Social Design and Multiplayer Play]].
7. **A low-end mode.** One toggle that kills effects. [[Mobile and Low-End Optimization]] has the details.
8. **A mascot face.** One character that appears on every icon and thumbnail for years. The franchise grey cat does more for recognition than any logo.

## What not to copy

- **Paid luck as the top of the store.** Luck passes are allowed, but paid luck on rare items is the most sensitive monetization on the platform for a young audience. If you sell luck, read [[Paid Random Items and Odds Disclosure in Practice]] and [[Roblox Policies Ratings and Compliance]] first, show odds, and consider making luck a time-limited boost rather than a permanent multiplier.
- **Real-money adjacency.** The predecessor's NFT experiment ended in refunds (Press, February 2023). Anything that lets in-game items take on cash value invites scams, account theft and policy trouble. Rare pets are traded for real money off-platform anyway; do not build features that make that easier.
- **Thirteen passes on day one.** BIG Games built that list over years with a huge audience. A new game with thirteen passes looks like a cash grab. Start with three to five, see [[Game Passes]] and [[Robux Price Points and Offer Design]].
- **Raising pass prices without a story.** Prices visibly went up over time. Players notice; if you must raise, do it alongside new value and announce it.
- **Illustrated art that oversells the game.** The thumbnails are illustrations, not in-game captures. That is legal for images but can raise bounce if the first session looks different. Test with personalization and watch session length, not just clicks; see [[A-B Testing and Experiments on Roblox]].
- **A weekly cadence you cannot sustain.** Weekly updates need a team, a content pipeline and a live config system ([[Global State and Live Config]]). Promise biweekly and deliver, rather than promise weekly and miss.

## Checklist

- [ ] The core verb pays out in the first ten seconds; first hatch within two minutes.
- [ ] One long-term currency, plus per-world soft currencies if you have worlds.
- [ ] Rebirths unlock features rather than only resetting numbers.
- [ ] Trading opens only after a progress milestone.
- [ ] Title skeleton fixed; one bracketed tag rotates per update.
- [ ] Release slot fixed and announced.
- [ ] Any paid luck shows odds and passes a policy check.
- [ ] Store starts small; price changes come with new value.
- [ ] Low-end graphics toggle.

## Connected notes
<!-- auto-links:start -->
[[Case Study - Adopt Me]] · [[Case Study - Fisch]] · [[Case Study - Doors]] · [[Case Study - Steal a Brainrot]] · [[Pet Hatching and Following End to End]] · [[Simulator and RNG Genre Teardown]] · [[Top Games Case Studies Start Here]]
<!-- auto-links:end -->
