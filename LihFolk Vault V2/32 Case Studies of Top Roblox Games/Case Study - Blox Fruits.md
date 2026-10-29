---
tags: [case-study, top-games, action-rpg, grinding, rng, trading, live-ops, monetization, thumbnails, type/case-study, area/design, level/intermediate]
---
# Case Study - Blox Fruits

<!-- tldr:start -->
> [!tldr] TL;DR
> - Faction or identity choice in the first 10 seconds.
> - First quest and first level up within two minutes.
> - Stat points let players make a build choice early.
> - Each island has a level band, quests and a boss.
> - A rare power item chase sits on top of levels.
> - One shared, timed stock rotation for all servers, with a countdown.
>
> Cost: TL;DR ~120 tok · whole note ~4.9k tok. Read more: ## 1. Snapshot · ## 6. What to copy and what not to copy · ## Checklist
<!-- tldr:end -->

Blox Fruits is the long-running king of the Roblox grind RPG: an anime-inspired open sea with islands, quests, bosses and a level cap in the thousands, where the main chase is a randomly appearing "fruit" that grants a power set. It has been live since January 2019, has passed 65 billion visits, and set a platform concurrency record in December 2024 off a single rework update. Study it for three things: how a **level ladder plus a power-item chase** creates years of goals, how **timed, shared stock rotations** create daily habits and trading demand, and how a studio uses **big numbered updates and reworks** to bring millions back at once. Study the risks too: reworking items players paid for is a reliable way to anger your best customers.

Source labels used below: **Observed in the live game (October 2026)** means the public Roblox store page and public web API (games, votes, game passes, media, thumbnails) read on 27 October 2026, with no login and no play session. **Public stats site** means third party trackers. **Studio statement** means the studio's store text. **Press** means named outlets and guides. Roblox does not publish click-through rate or revenue for other creators' games; anything about clicks is reasoning from what is visible.

---

## 1. Snapshot

| Field | Value | Source |
|---|---|---|
| Title on 27 Oct 2026 | "Blox Fruits" (no tag) | Observed in the live game (October 2026) |
| Studio | Gamer Robot Inc (group, verified badge) | Observed in the live game (October 2026) |
| Created | 16 January 2019 | Observed in the live game (October 2026) |
| Original name | Launched as "Blox Piece"; renamed to Blox Fruits around December 2019 after copyright pressure | Public stats site (RoWatcher timeline article; weak source, but the rename is widely reported) |
| Inspiration | The manga and anime One Piece | Press (Wikipedia, Roblox games list) |
| Genre tags | RPG, subgenre Action RPG (legacy genre "Adventure") | Observed in the live game (October 2026) |
| Total visits | 65,122,271,540 | Observed in the live game (27 October 2026) |
| Favourites | 20,135,259 | Observed in the live game (27 October 2026) |
| Likes / dislikes | 12,797,019 / 1,068,662 (about 92.3% positive, the highest ratio of the four games in this batch) | Observed in the live game (27 October 2026) |
| Server size | 12 players | Observed in the live game (October 2026) |
| Players at the moment of reading | 127,251 (one snapshot, afternoon US time, between major updates) | Observed in the live game (27 October 2026) |
| Current level cap | 3000 | Studio statement (store description, October 2026) |
| Fruits listed in the description | 42, from Rocket to Dragon | Studio statement (store description, October 2026) |
| All-time peak | About 2.77 to 2.78 million concurrent, late December 2024, after the Dragon Rework (Update 24). Rolimons lists 2,781,531 on 31 December 2024; a RoWatcher article gives 2,768,133 | Public stats site (Rolimons as shown in search results; RoWatcher), October 2026 |
| First million | About 1 million concurrent for the first time in October 2023 | Public stats site (RoWatcher timeline; weak); Press (Sportskeeda headline "Blox Fruits hits 1 million active players") |
| Kitsune update | Over 800,000 concurrent on launch day, 15 September 2024 | Public stats site (RoWatcher timeline; weak) |
| Awards | Best Action RPG, 2024 Roblox Innovation Awards | Press (IGN, 8 September 2024, via Wikipedia) |

Things we could not verify: the exact peak (two trackers disagree by about 13,000, and one RoWatcher page claims an unrelated "3.7 million in 2023" record, which contradicts its own later figure; I ignore it). The exact rename date. Any revenue figure. We could not open the fan wiki (blocked), so update dates come from search summaries of it and from guides.

### Update history in one paragraph

From the RoWatcher timeline and guides (weak sources, but consistent with each other): Second Sea in 2019; Third Sea on 11 September 2021; fruit trading added around Update 15 in 2022; 10 billion visits by November 2022; level cap raised over time (2,450 in December 2022, 2,600 with Update 24, 2,800 grind cap and up to 3,000 via secret levels around Update 30); Race V4 in June 2023; the Kitsune update on 15 September 2024; the Dragon Rework (Update 24) on 14 December 2024 which set the record; a Control update with dungeons in December 2025; and Update 30, "Sea 1 Rework" with the Magnet fruit, on 5 September 2026. The store description now opens with "OUT NOW: 🧲 Magnet + 🏝️ Sea 1 + MORE" (Observed in the live game, October 2026). A Fourth Sea is reported as planned (unverified).

---

## 2. Click-through: icon, thumbnails and title

No CTR data is public. Reasoning from assets downloaded from the public thumbnails API on 27 October 2026.

### What is on the store page now (Observed in the live game, October 2026)

- **Icon:** a huge spiky blue mech or armoured monster (the Magnet fruit's transformation) filling the frame against an orange-red explosion, with the "BLOX FRUITS" logo bottom right. For Halloween the "O" in BLOX is a carved pumpkin. No human face, no text tag.
- **Thumbnails:** 8 images and **no video**. All are in a painted anime splash-art style, far more detailed than the in-game graphics. The four I pulled: a fighter with a red headband throwing a lightning blast at the blue mech; the same fighter shirtless in front of the mech; a green dragon breathing fire at a fighter in a ruined town; a white-haired, red-eyed beast or yeti-like character fighting a fighter with red energy. The logo is bottom right on every image with the pumpkin "O".
- **Title:** just "Blox Fruits". No emoji, no bracket tag. The update announcement lives in the first line of the description instead ("OUT NOW: ...").

### Why this probably works

1. **Power fantasy at a glance.** Each image shows one hero and one enormous threat or transformation, mid action. For an audience that watches anime, this reads like a key visual for a new season.
2. **The fruit is the star.** The icon and the first thumbnails feature the newest fruit's form (the Magnet mech after Update 30; the dragon from Update 24 is still in the gallery). Each update gets a new hero image built around the new fruit, which is the thing players want.
3. **No title churn.** With over 20 million favourites, the brand name is the asset. The studio leaves the title alone and changes only the art and the description's first line.
4. **Tiny seasonal touch.** Swapping the logo "O" for a pumpkin is a cheap way to look "current" without redrawing everything.
5. **Consistent logo placement.** Bottom right, same size, on every image.

What we would question: no gallery video. For a combat game, a short clip of a fruit ability could sell better than stills. We could not find any statement on why they skip it. See [[Thumbnails Icons and Store Page]] and [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]].

---

## 3. The first five minutes

Sources: beginner guides (Press, 2024 to 2026; Keengamer, rblxguide, Earnaldo and others; mixed quality). Not played first-hand.

1. **Pick a side.** On first join the player chooses Pirates or Marines and spawns on that side's starter island.
2. **Talk to the quest giver.** A starter NPC on the island (a Bandit quest giver for pirates, a Marine leader for marines) offers a level 0 quest: defeat a number of nearby enemies.
3. **First fights and first level ups.** Starter enemies die in a few hits. Each level gives stat points to spend across five stats: Melee, Defense, Sword, Gun and Blox Fruit. The first level ups arrive within the first couple of minutes.
4. **See the fruit dealer.** An NPC near spawn sells fruits for in-game money (Beli) or Robux. Guides advise new players not to spend Robux on permanent fruits early.
5. **Next island.** Quests point to the next zone (jungle and its first boss, the Gorilla King with a level 25 quest, per guides).

So the core loop (take quest, kill enemies, level up, spend stat points, move to a harder island) is shown in under five minutes. The long goal (find or buy a fruit, reach the next Sea at level 700) is visible from the first NPC.

What is clever: the stat point choice at level 1 makes a new player feel like they are building a character immediately, and the Pirate or Marine choice gives identity before any skill is needed. See [[First-Time User Experience and Onboarding]] and [[Quests and Objectives]].

---

## 4. Core loop and retention

### Session loop

1. Accept an island quest sized to your level.
2. Kill N enemies (or a boss), collect Beli and XP.
3. Level up, assign stats.
4. Repeat until the next island's quests are in range; move on.
5. Along the way, check fruit spawns on the map, the dealer's stock, and bosses that drop rare items.

Mastery is a second ladder: weapons and fruits gain mastery with use, unlocking more moves (the existence of a "2x Mastery" pass confirms the system; details from guides).

### Long-term goals

- **Level cap 3000** across three Seas (and a planned fourth).
- **The fruit chase.** 42 fruits from Rocket to Dragon. Fruits appear in the world on a timer, can be bought from a dealer whose stock rotates, can be awakened, and since about 2022 can be traded. Mythical fruits are status symbols.
- **Fighting styles, swords, guns, races and race upgrades** (Race V4 since June 2023).
- **Raids and dungeons** as endgame activities (dungeons added December 2025 per guides).

This is a textbook layered ladder: level gates zones, zones gate items, items gate harder content. See [[Progression and Pacing Design]] and [[Genre Playbook - Combat and RPG]].

### Daily and timed systems

- **Shared stock rotation.** Fan trackers (several, unofficial, 2025 and 2026) report that the normal fruit dealer's stock refreshes every 4 hours on a fixed UTC grid (00:00, 04:00, 08:00 and so on), the same on every server, and that a second "Mirage" dealer on a hard-to-reach island refreshes every 2 hours with rarer fruits. Discord bots exist just to post the current stock. We could not confirm this from the studio; it matches the in-game countdown according to guides.
- **World fruit spawns** on a timer and **boss respawns** give reasons to be online at certain times.
- **Events** around big updates (for example a celebration event for 50 billion visits in August 2025, and Halloween updates).

The shared global stock is the clever part: because everyone sees the same rotation, "Dragon is in stock" becomes news that spreads across Discord, TikTok and YouTube within minutes, and players join to buy. It creates a reason to check the game several times a day without a login streak. Building it needs global state (see [[Global State and Live Config]] and [[MemoryStore Service]]).

### Update cadence

Blox Fruits ships fewer, much bigger numbered updates (Update 24, Update 29, Update 30) with long teaser periods, rather than weekly patches. The Dragon Rework set the platform record. The risk is the gap: a RoWatcher tracker page in 2026 showed a 30-day change of about -40% between updates. Big updates create huge spikes and long troughs. Communication has been criticised: teasers without firm dates (Public stats site, RoWatcher). See [[Update Cadence and Hype Cycles]].

### Social hooks

Crews, trading, PvP bounty, raids with other players, and a huge content creator scene (fruit tier lists, stock alerts, trading values).

---

## 5. Monetization (public store page)

Observed in the live game (27 October 2026), from the public game passes endpoint. Only six passes, all on sale:

| Pass | Price |
|---|---|
| Fast Boats | 350 |
| 2x Boss Drops | 350 |
| 2x Money | 450 |
| 2x Mastery | 450 |
| Dark Blade | 1200 |
| Fruit Notifier | 2700 |

The main revenue is not passes. It is **fruits sold for Robux by the dealer**, as developer products. Guides (Press, 2025 and 2026) list permanent fruit prices from tens of Robux for the commonest (Rocket 50, Spin 75 per Dotesports) up to 5,000 Robux for permanent Dragon (Timesaver list, September 2026; also Eldorado). Physical (one-time, tradable) fruits from the dealer's stock can also be bought for Robux or Beli. We could not read developer product prices from a public endpoint; the official fan wiki was not reachable. Treat individual prices as guide-reported.

What the price shape shows:

1. **A very wide ladder.** From a 50 Robux fruit to a 5,000 Robux permanent mythical, plus a 2,700 Robux pass. Few Roblox games price anything at 2,700.
2. **Fruit Notifier at 2,700** sells information: it tells you when and where fruits spawn. In a game where a fruit spawn is the jackpot, information is the most valuable item, and the price says so.
3. **Multipliers on every grind.** Money, mastery and boss drops each have a 2x pass. This is classic RPG pass design: buy time, not power directly.
4. **Dark Blade at 1,200** is a strong sword sold directly, which is one of the few places Blox Fruits sells raw power.
5. **No random paid boxes in the pass list.** Paid fruits are chosen, not random, which keeps the paid side clear of paid-random-item rules. The Magnet Gacha reported in guides for Update 30 uses tokens dropped by enemies (unverified whether any Robux path exists).

### The rework problem

When the Dragon fruit was reworked in December 2024, players reported that existing Dragon fruits were converted into tokens, which upset many owners (Press: guide sites covering the update). Similar complaints followed other reworks (Public stats site: RoWatcher). Players who paid 5,000 Robux for a permanent fruit expect it to stay the fruit they bought. Some reworks kept both old and new versions, and players now expect that.

---

## 6. What to copy and what not to copy

### Copy

1. **Choose an identity in the first 10 seconds.** A two-way faction choice (Pirates or Marines) costs little and gives players a team. Teach: [[First-Time User Experience and Onboarding]].
2. **Stat points from level 1.** Let players make a build decision before they understand the game. Teach: [[Progression Levels and Unlocks]].
3. **Island ladder with quest givers.** Each zone has a quest sized to its level band and a boss. Clear, repeatable, and easy to extend with new islands. Teach: [[Quests and Objectives]], [[Boss Fight Design Patterns]], [[Zone and Biome Art Direction]].
4. **A power item chase on top of levels.** Levels are the floor; a rare, swappable power set (fruits) is the dream. Teach: [[RNG Drops and Luck Systems]], [[Rarity Ladders and Drop Pacing Math]].
5. **Global, shared, timed stock.** One rotation for all servers, on a fixed clock, with a countdown. It creates news, habit and trading demand. Teach: [[Global State and Live Config]], [[MemoryStore Service]].
6. **Sell time and information.** 2x passes and a notifier respect players who grind and let payers skip, without random boxes. Teach: [[Game Passes]], [[Developer Products and ProcessReceipt]].
7. **Each update gets a hero image built around the new item.** Teach: [[Thumbnails Icons and Store Page]].
8. **Combat that scales.** Many ability sets across 12-player servers needs disciplined hitboxes and networking. Teach: [[Combat Systems Architecture]], [[Hitboxes and Hit Detection]], [[Client Prediction and Reconciliation for Combat]].

### Do not copy

1. **Reworking paid items without a promise.** If you sell a permanent item, write down what "permanent" means. If you rework it, let owners keep the old version or choose. Teach: [[Ethical Design and Player Trust]], [[Refunds Chargebacks and Purchase Support]].
2. **IP borrowing.** The game started under a name close to an existing anime and had to rebrand. Use original names, designs and terms from day one. Teach: [[Legal Basics - IP Licenses and Assets]].
3. **Long silent gaps between giant updates.** The -40% swings between updates show the cost. Add smaller mid-cycle events, and give firm dates when you tease. Teach: [[Update Cadence and Hype Cycles]], [[Live Ops Events and Updates]].
4. **Trading without dupe protection.** A trade economy around 5,000 Robux items is a magnet for exploits and scams. Teach: [[Trading Systems Without Duplication]], [[Remote Abuse Patterns and Rate Limiting in Practice]].
5. **A level cap in the thousands at launch.** Blox Fruits grew its cap over seven years. A new game should launch with a short ladder that can be extended. Teach: [[Planning and Scoping a Roblox Game]], [[Balancing with Spreadsheets and Data]].
6. **Selling raw power in a PvP game.** A paid sword or fruit that wins fights makes PvP feel pay to win. If you sell power, keep it to PvE or balance it against earnable items. Teach: [[Pricing and Store Design]].
7. **Splash art far beyond your game.** The painted art works because the brand is established. A new game with stylised splash art and plain in-game graphics risks a disappointing first session.

### A buildable mini version

Two factions, three islands with quest givers and one boss each, a level cap of 100, five stats, eight power items with a rarity ladder, one global dealer stock that rotates every 4 hours, and two 2x passes. Add trading only after the backend is proven. Ten to twelve weeks for a small team with a combat programmer.

---

## Checklist

- [ ] Faction or identity choice in the first 10 seconds.
- [ ] First quest and first level up within two minutes.
- [ ] Stat points let players make a build choice early.
- [ ] Each island has a level band, quests and a boss.
- [ ] A rare power item chase sits on top of levels.
- [ ] One shared, timed stock rotation for all servers, with a countdown.
- [ ] Passes sell time or information; any paid power is PvE-safe.
- [ ] "Permanent" purchases have written rework rules.
- [ ] Mid-cycle events fill gaps between big updates; teasers have dates.
- [ ] Each update has a hero thumbnail built around the new item.

## Sources

- Observed in the live game (October 2026): Roblox public web API (games, votes, game passes, media and thumbnails endpoints) for the experience, read 27 October 2026, no login.
- Studio statement: store description (level cap 3000, 42 fruits, "OUT NOW: Magnet + Sea 1"), October 2026.
- Press: Wikipedia list of Roblox games (Blox Fruits entry; IGN 8 September 2024 for the award); Sportskeeda ("Blox Fruits hits 1 million active players"); Dotesports and Timesaver for fruit Robux prices; guides on Update 24 (14 December 2024) and Update 30 (5 September 2026) from Pro Game Guides, All Things How, rblxguide, Video Games Chronicle; beginner guides (Keengamer, rblxguide, Earnaldo).
- Public stats site: Rolimons (peak 2,781,531 on 31 December 2024, as shown in search results); RoWatcher timeline and game page (weak; conflicting figures flagged); fan stock trackers for the 4 hour and 2 hour rotations (unofficial).

## Connected notes
<!-- auto-links:start -->
[[Case Study - Brookhaven RP]] · [[Case Study - Dress to Impress]] · [[Case Study - Grow a Garden]] · [[Case Study - Adopt Me]] · [[Power Curve]] · Core Loops and Session Design · [[Top Games Case Studies Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Case Study - Pet Simulator 99]] · [[Case Study - Fisch]] · [[Case Study - Steal a Brainrot]] · [[Case Study - Doors]] · [[Case Study - 99 Nights in the Forest]] · [[Case Study - Jailbreak]] · [[Case Study - The Strongest Battlegrounds]] · [[Case Study - Murder Mystery 2]]
<!-- related:end -->
