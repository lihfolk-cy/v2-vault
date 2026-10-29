---
tags: [case-study, top-games, roleplay, life-sim, social, private-servers, monetization, thumbnails, type/case-study, area/design, level/intermediate, area/monetization]
---
# Case Study - Brookhaven RP

<!-- tldr:start -->
> [!tldr] TL;DR
> - A new player owns a house or vehicle within 30 seconds, with no tutorial gate.
> - One menu, phone friendly, covers houses, vehicles, avatar and settings.
> - Every building implies a role and a scene.
> - Passes sell scale, control and expression; nothing sold is power.
> - Props and vehicles are capped per player and per server.
> - Private servers have real admin tools.
>
> Cost: TL;DR ~130 tok · whole note ~5.0k tok. Read more: ## 4. Core loop and retention · ## 6. What to copy and what not to copy · ## Checklist
<!-- tldr:end -->

Brookhaven RP is the most visited experience on Roblox and the purest example of the "stage, not game" design: no levels, no combat, no currency grind, almost no failure. It hands players a small town full of free houses, cars, outfits and props and lets them make their own stories. Every system in it exists to make pretend play smoother. If you want to understand why roleplay towns dominate Roblox and what it takes to run one, this is the case to study. If you want to copy it, read the "do not copy" section first: the genre is crowded, and Brookhaven's lead comes from years of updates and network effects you cannot buy.

Source labels used below: **Observed in the live game (October 2026)** means the public Roblox store page and public web API (games, votes, game passes, media, thumbnails) read on 27 October 2026, with no login and no play session. **Public stats site** means third party trackers. **Studio statement** means the owner's press release or store text. **Press** means named outlets and guides. Roblox does not publish click-through rate or revenue for other creators' games, so everything about clicks is reasoning from what is visible.

---

## 1. Snapshot

| Field | Value | Source |
|---|---|---|
| Title on 27 Oct 2026 | "Brookhaven 🏡RP" | Observed in the live game (October 2026) |
| Owner | Group "Brookhaven by Voldex" (no verified badge shown on the group record) | Observed in the live game (October 2026) |
| Original creator | Wolfpaq (the original two-person team) | Press (multiple outlets covering the sale, February 2025) |
| Acquisition | Bought by Voldex, announced 4 February 2025, with funding from Raine Partners and Shamrock Capital per Variety's exclusive | Press (Business Wire release dated 4 February 2025, and Variety coverage, as indexed in search results) |
| Created | 21 April 2020 | Observed in the live game (October 2026) |
| Genre tags | Roleplay & Avatar Sim, subgenre Life (legacy genre "Town and City") | Observed in the live game (October 2026) |
| Total visits | 88,954,986,292 | Observed in the live game (27 October 2026) |
| Favourites | 30,707,652 | Observed in the live game (27 October 2026) |
| Likes / dislikes | 8,686,803 / 1,427,001 (about 85.9% positive) | Observed in the live game (27 October 2026) |
| Server size | 30 players | Observed in the live game (October 2026) |
| Players at the moment of reading | 334,292 (one snapshot, afternoon US time, during the Halloween event) | Observed in the live game (27 October 2026) |
| All-time peak | 1,296,208 concurrent, 19 December 2025 | Public stats site (Rolimons game page as shown in search results, October 2026; RoWatcher gives the same figure and date) |
| Earlier peak | Over 1.1 million concurrent around Christmas 2024 | Public stats site (RoWatcher news article; weak source) |
| Visits at acquisition | About 60 billion | Press (Voldex release coverage, February 2025) |

Things we could not verify: We could not open the Business Wire release directly (the fetch was blocked), so the acquisition facts come from search result summaries of that release and secondary coverage; the date (4 February 2025) and the 60 billion visits figure agree across sources. RoWatcher's own game page lists a 1.2M peak in "July 2025", which conflicts with both its own news article and Rolimons, so I use the 19 December 2025 record. Typical daily concurrency outside events is reported by trackers as roughly 300,000 to 500,000, which matches the 334,292 snapshot I read, but no source gives a reliable average. Revenue: one tracker shows a monthly estimate with low confidence; I do not repeat it.

### Ownership history and why it matters

Brookhaven was built by a tiny original team and sold to Voldex, a company that buys and operates established Roblox games. Since the sale, the update rhythm has been very regular: trackers and guides describe weekly updates, typically on Fridays (Public stats site, RoWatcher, October 2026; Press, guides for 2025 and 2026 updates such as the Movie Studio update on 28 March 2025 and the Arcade update on 10 May 2025). The all-time player record came under the new owner, in December 2025, without a single large new mechanic. For a developer, the lesson is that a mature social game can keep growing on cadence and polish alone, if the base stage is right.

---

## 2. Click-through: icon, thumbnails and title

Roblox does not publish CTR for other creators' experiences. This is reasoning from the store assets I downloaded from the public thumbnails API on 27 October 2026.

### What is on the store page now (Observed in the live game, October 2026)

- **Icon:** a white double door frame, opened, with a girl avatar in a witch hat holding a carved pumpkin standing in the doorway, a suburban house behind her, and a red ribbon banner across the bottom reading "BROOKHAVEN". The icon is a picture frame, not a scene.
- **Thumbnails:** 9 images and 1 video. Every thumbnail I pulled uses **exactly the same template**: a white room wall with open French doors on both sides, wooden floor, a window into a Brookhaven scene, the red "BROOKHAVEN" ribbon bottom left and "RP" bottom right. Only the scene inside the window changes: a Halloween house with the witch avatar; a police officer on a motorbike; a store "Grand Opening" with an avatar in a green uniform; a robber running with cash chased by police.
- **Title:** "Brookhaven 🏡RP". The house emoji is permanent. There is no seasonal tag in the title; the seasonal signal lives in the icon and first thumbnail only.

### Why this probably works

1. **A frame you can recognise at any size.** The white doors plus red ribbon make the tile identifiable even when the inner scene is tiny on a phone. This is the same principle as a magazine cover template: the frame is the brand, the content changes.
2. **Each thumbnail is a roleplay prompt.** Cop chases robber, shop opening day, police patrol, Halloween house. Each one is a story the viewer can imagine joining, which is exactly what the game sells. There are no stats, no rarity, no numbers.
3. **Plain Roblox avatars.** The characters look like the viewer's own avatar (blocky, classic proportions). For a game where you play as yourself, that is a promise: "this is you, in a town".
4. **The title does not churn.** With about 89 billion visits and over 30 million favourites, recognition is the main asset. Brookhaven does not need to shout "UPDATE"; the frequent Friday updates are signalled in the description and the icon instead.
5. **Seasonal icon.** The only thing that flips for Halloween is the inner image of the icon and the first thumbnail.

Compare with the single-face cute approach of [[Case Study - Adopt Me]] and the tag-heavy title of [[Case Study - Dress to Impress]]. General rules: [[Thumbnails Icons and Store Page]], [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]].

Unverified: Voldex's use of sponsored ads or thumbnail A/B tests for this game. Nothing public found.

---

## 3. The first five minutes

Sources: beginner guides (Press, mixed quality, 2024 to 2026) and the store description. Not played first-hand.

1. **Spawn into the town with no tutorial gate.** There is no forced tutorial and nothing to complete before you can move. You are standing in a living town with up to 29 other players.
2. **One menu does everything.** Guides describe a single menu (keyboard shortcut or a side toolbar; guides disagree on layout across versions) with tabs for Houses, Vehicles, Avatar and more.
3. **Claim a free house in seconds.** Walk to an empty plot or pick one from the menu, claim it, optionally lock it. Most houses are free; premium homes are behind passes (guides).
4. **Spawn a free car.** Pick a vehicle in the menu and it appears next to you. A wide free selection of cars, trucks, motorbikes and bikes is available (guides).
5. **Change your look for free.** The avatar tab gives free clothing, hair, faces and accessories, so a player can become "a police officer" or "a parent" without owning anything.

The core loop (pick a role, grab props, act a scene with others) is fully shown within the first minute or two because there is nothing to unlock first. The "first reward" is not a currency payout; it is ownership: a house and a car that are yours right away.

This is the opposite of most onboarding advice for progression games, and it is correct for the genre: in a stage game, any gate between the player and the props is friction with no payoff. See [[First-Time User Experience and Onboarding]] and [[Genre Playbook - Roleplay and Social Hangouts]].

---

## 4. Core loop and retention

### Session loop

There is no scored loop. A typical session, as described by guides and visible in thumbnails:

1. Join (often with friends, or join a friend in progress).
2. Claim a house, choose an outfit and role.
3. Spawn a vehicle, drive somewhere meaningful (school, hospital, police station, store, bank).
4. Improvise a scene with other players (family, cops and robbers, school day, shop owner).
5. Switch roles or houses when the scene ends.

The content is other players. The design job is to supply many scene starters (buildings with a clear purpose, uniforms, tools, props) and to remove friction (instant spawn, free items, one menu).

### Long-term goals

There are very few, by design. What keeps players coming back:

- **Friends.** A roleplay game is where friends meet on purpose; the session ends when the friends leave.
- **New places and props.** Weekly updates add buildings, vehicles, house styles and seasonal items.
- **Private servers.** The store description lists a long set of private server powers (Observed in the live game, October 2026): prop saving, server-wide music and announcements, remove or lock props, check prop owners, set players as admins, kick or temporary ban, set day of week and time, change weather and lighting, speed up time, server theme controls, no wait to change house, spawn up to three vehicles, and a higher prop limit. That turns a private server into a tool for running your own roleplay community.

### Daily and timed systems

Brookhaven largely avoids daily login streaks and timers. Its timed systems are **events**. Observed in the live game (October 2026): the description advertises a Halloween event where players "Collect Candy Corn to unlock special Halloween Tools, Props, Vehicles and a House". Guides for this event (Press, October 2026) report 60 candy corn pieces hidden around the map with rewards unlocking at milestones, an event window of 23 October to 6 November 2026, and a Candy Corn Radar that can be unlocked for 9 Robux **or by watching an ad**. That last detail is notable: a rewarded video ad as an alternative to a tiny purchase. We could not confirm the radar details from the owner; treat them as guide-reported.

The event structure is a **collectible hunt across the existing map**, which reuses the town instead of adding a new area, rewards exploration, and gives players a reason to visit corners they never use. See [[Ads and Rewarded Video]] and [[Live Ops Events and Updates]].

### Update cadence

Trackers and guides describe weekly Friday updates (Public stats site and Press, 2025 and 2026), with seasonal events layered on top (Winter Olympics in February 2026, Cherry Blossom in March 2026, Trucks and Trailers 20 March 2026, Easter from 27 March 2026, a Bank update in August 2026, Halloween from 23 October 2026, all from tracker and guide pages). A fixed weekday matters: players and content creators know when to check in. See [[Update Cadence and Hype Cycles]].

### Social hooks

- Joining friends in progress.
- Scene-friendly buildings (school, hospital, police, bank) that make group roles obvious.
- Private servers with admin powers, which let communities run regular roleplay sessions.
- Content creators: roleplay stories are a natural video format, which drives discovery outside Roblox.

See [[Social Design and Multiplayer Play]].

---

## 5. Monetization (public store page)

Observed in the live game (27 October 2026), from the public game passes endpoint. 18 passes on sale:

| Pass | Price |
|---|---|
| Vehicle Upgrade | 35 |
| On Demand Fire | 40 |
| Horse Upgrade | 85 |
| Penthouse | 180 |
| Vehicle Speed Unlocked | 199 |
| Vehicle Boost Upgrade | 199 |
| Music Unlocked | 199 |
| Vehicle Customization | 299 |
| Boat Pack | 299 |
| Theme Pack | 299 |
| Premium | 320 |
| Land Unlocked | 375 |
| Disaster Pass | 375 |
| Estates Unlocked | 599 |
| Vehicle Pack | 599 |
| House Pets | 599 |
| Prison Landmark | 699 |
| VIP | 749 |

Six more passes are off sale, including a "Faces Unlocked" pass and a "House & Motorcycle" pass, plus a few placeholder entries with names like "Unused" and "Nothing". Those placeholder records are a reminder that public pass lists are visible to everyone; clean them up.

What the list shows:

1. **Everything sold is an expansion of expression or control, not power.** Bigger houses (Estates, Penthouse, Land), more vehicles and vehicle tweaks, music, themes, pets for your house, the ability to trigger disasters or fires (scene tools), a prison landmark (a scene location).
2. **Many cheap entry points.** Five passes at 199 or less. A player can buy a single small upgrade for their favourite toy.
3. **A ladder up to 749 VIP.** No pass costs more than 749. There are no Robux random boxes visible in the pass list.
4. **Private servers as a product.** The long private server benefit list in the description is a sales page for private servers, which Roblox sells on behalf of the creator. Check current private server pricing rules in [[Subscriptions and Premium Payouts]] and [[Monetization Overview]].
5. **Free core.** Houses, cars and clothes are free; Press coverage notes no essential content is locked behind passes. That keeps the stage full, which is what paying players need too (a roleplay town with empty servers is worthless).

We could not see developer products from a public endpoint. The 9 Robux event radar reported by guides suggests small developer products are used for events.

---

## 6. What to copy and what not to copy

### Copy

1. **Zero-gate onboarding for sandbox games.** If your game is a stage, let players own something within 30 seconds: a free house, a free car, a free outfit. Teach: [[First-Time User Experience and Onboarding]].
2. **One menu, few taps.** Houses, vehicles, avatar and settings in one place with large buttons. Build it phone first. Teach: [[HUD Design]], [[Menu Archetypes - Shop Settings Codes Rewards]], [[Responsive UI for Phone Tablet Console and PC]].
3. **Buildings as scene prompts.** Every building should imply a role and a story (hospital, police, school, shop). Teach: [[Level Design for Roblox]], [[Genre Playbook - Roleplay and Social Hangouts]].
4. **Sell control and scale, not power.** Bigger homes, more vehicles, music, weather and scene tools. These are easy to price and never break fairness. Teach: [[Game Passes]], [[Pricing and Store Design]].
5. **A rich private server feature set.** Admin tools, persistence of props, time and weather control. It turns private servers into a product for communities. Teach: [[Social Design and Multiplayer Play]].
6. **A fixed update weekday.** Ship small, often, on the same day. Teach: [[Update Cadence and Hype Cycles]], [[Release Process and Rollbacks]].
7. **Event hunts on the existing map.** Hide N collectibles in the current world with milestone rewards. Cheap to build, rewards exploration, and works for every age. Use [[Global State and Live Config]] to switch the event on and off without a new publish.
8. **A recognisable template thumbnail.** Same frame, same ribbon, changing scene. Teach: [[Thumbnails Icons and Store Page]].
9. **Rewarded video as an alternative to a tiny purchase.** Offer the same small item for a low price or an ad view. Teach: [[Ads and Rewarded Video]] (check current eligibility rules and audience requirements there).

### Do not copy

1. **The genre at face value.** Roleplay towns are one of the most crowded categories on Roblox. A new town with fewer buildings and empty servers loses to Brookhaven on every metric. Find a sharper fantasy (one setting done deeply) and use [[Competitor Analysis Method]] first.
2. **Unbounded props and vehicles without budgets.** Free spawning for 30 players is a performance and abuse risk. Cap props per player, cap vehicles (Brookhaven's private server pass raises the cap to three, which implies a lower default), and stream the map. Teach: [[Instance Streaming]], [[Art Budgets - Triangles Draw Calls Memory]], [[Rate Limiting and Abuse Prevention]].
3. **Skipping safety work.** An open roleplay space with free text chat, houses with locks and private servers needs moderation tools, reporting, and age-appropriate design. Teach: [[Age Checks and Safety Features]], [[Roblox Policies Ratings and Compliance]].
4. **Leaving placeholder passes public.** Names like "Unused" on a top game's pass list look careless. Archive or rename them.
5. **Expecting long-term goals to retain players.** Brookhaven retains through friends and novelty, not progression. If your audience is not social-first, this model will feel empty. Pair it with at least a light goal (collections, jobs, house decoration) if you are small.
6. **Copying the buyout path as a plan.** The sale to Voldex is a business outcome, not a design lesson. See [[Running a Small Studio as a Business]] if that interests you.

### A buildable mini version

One district (6 to 8 purpose buildings), 10 free houses with a claim and lock system, 8 free vehicles from a single menu, a free outfit wardrobe for 6 roles, and a private server panel with time, weather and kick. Then one event: 30 hidden collectibles with 4 milestone rewards. That is the whole lesson in a 6 to 10 week scope.

---

## Checklist

- [ ] A new player owns a house or vehicle within 30 seconds, with no tutorial gate.
- [ ] One menu, phone friendly, covers houses, vehicles, avatar and settings.
- [ ] Every building implies a role and a scene.
- [ ] Passes sell scale, control and expression; nothing sold is power.
- [ ] Props and vehicles are capped per player and per server.
- [ ] Private servers have real admin tools.
- [ ] Updates ship on a fixed weekday.
- [ ] Events reuse the map with hunts and milestone rewards.
- [ ] Thumbnails share one frame template; only the inner scene changes.
- [ ] Off-sale or placeholder passes are cleaned up.

## Sources

- Observed in the live game (October 2026): Roblox public web API (games, votes, game passes, media and thumbnails endpoints) for the experience, read 27 October 2026, no login.
- Press: Voldex acquisition, Business Wire release dated 4 February 2025 and Variety coverage, as summarised in search results (direct fetch blocked).
- Public stats site: Rolimons game page (all-time peak 1,296,208 on 19 December 2025, as shown in search results); RoWatcher game page and news articles (conflicting peak dates, weak source).
- Press: beginner and event guides (Gfinity, Sportskeeda, Pixel Twelve, Mumuplayer, Of Zen and Computing, Stealthy Gaming, 2024 to 2026) for menus, houses, vehicles, update dates and the Halloween 2026 hunt. Mixed quality; flagged in text.

## Connected notes
<!-- auto-links:start -->
[[Case Study - Blox Fruits]] · [[Top Games Case Studies Start Here]] · [[Case Study - Fisch]] · [[Case Study - Doors]] · [[Genre Playbook - Racing and Driving]] · Discovery and the Algorithm
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Case Study - Pet Simulator 99]] · [[Case Study - Steal a Brainrot]] · [[Case Study - Grow a Garden]] · [[Case Study - Jailbreak]] · [[Case Study - 99 Nights in the Forest]] · [[Case Study - Dead Rails]] · [[Case Study - Forsaken]] · [[Case Study - The Strongest Battlegrounds]]
<!-- related:end -->
