---
tags: [case-study, top-games, simulator, idle, farming, live-ops, retention, monetization, marketing, type/case-study, area/design, level/intermediate]
---

# Case Study - Grow a Garden

<!-- tldr:start -->
> [!tldr] TL;DR
> - Can a new player complete buy, plant, collect, upgrade within two minutes with no tutorial screen?
> - Does leaving the game earn the player something they will see on return?
> - Is there a shared, visible timer that creates moments players gather for?
> - Is randomness layered on top of a dependable base loop, with multipliers shown in game?
> - Are status items visible to other players?
> - Is anything you sell allowed to harm another player?
>
> Cost: TL;DR ~150 tok · whole note ~5.1k tok. Read more: ## 2. Click-through: title, icon and thumbnails · ## 6. What to copy and what not to copy · ## Checklist
<!-- tldr:end -->

Grow a Garden is the game that showed the whole industry how big a Roblox experience can get. It is a farming idle game: plant seeds on your plot, wait, harvest, sell, buy better seeds. In its first summer it broke the concurrent player record for any video game, then lost almost all of that audience within about a year. Both halves of that story are worth studying. This note is about the lessons you can build, not about copying the game.

How to read the labels in this note:
- **Public stats site**: third-party trackers (RoMonitor Stats, RoWatcher, Profitable.app) or Roblox's public game API.
- **Studio statement**: something the developers or their company said.
- **Press**: news coverage, with outlet and date.
- **Observed in the live game (October 2026)**: what the public store page, title, icon and thumbnails show. Nothing in this note comes from playing or logging in.

Roblox does not publish click-through rate (CTR), session length or revenue for other people's games. Anything here about why a thumbnail "works" is reasoning from what is visible, not measured data.

## 1. Snapshot

| Field | Value | Source |
|---|---|---|
| Genre | Idle farming simulator. Roblox lists it as Simulation, sub-genre Tycoon | Public stats site (Roblox game API, checked October 27, 2026) |
| Released | Experience created March 25, 2025 (UTC); press gives the launch as March 26, 2025 | Roblox game API; Wikipedia citing press |
| Owner on Roblox | Group "The Garden Game" | Roblox game API, October 27, 2026 |
| Studios involved | Created by a teenage developer; Splitting Point Studios (Jandel's company) bought in around April 2025; Do Big Studios later took a minority share | Press (PC Gamer, Business Insider, via Wikipedia) |
| Peak concurrent users | 21.3 million on June 21, 2025; at least 22.3 million on August 23, 2025 (the "admin war" with Steal a Brainrot) | Press (PocketGamer.biz, IGN), citing RoMonitor Stats |
| Earlier milestones | About 5 million (May 17 to 18, 2025), 11.7 million (May 31), 16.4 million (June 14, the first time it beat Fortnite's 14.3 million record) | Press (PCGamesN, PocketGamer.biz) citing RoMonitor Stats |
| Peak daily users | About 60 million | Studio statement (Jandel, GamesBeat interview, September 7, 2025) |
| Visits | 35,993,618,761 | Roblox game API, checked October 27, 2026 |
| Favourites | 11,458,473 | Roblox game API, October 27, 2026 |
| Likes | 9,440,910 up, 1,055,641 down (about 90% positive) | Roblox game API, October 27, 2026 |
| Playing now | 13,651 at 3:42 pm US Eastern on Tuesday, October 27, 2026 | Roblox game API, single snapshot |
| Server size | Listed as 4 players per server | Roblox game API, October 27, 2026 (press in 2025 described larger servers; I could not confirm when this changed) |
| Fastest to 1 billion visits | 33 days | Press (PocketGamer.biz, June 2, 2025) |

Two numbers in that table tell the main story. The peak was 22.3 million concurrent players. On a Tuesday afternoon in October 2026 the game had about 13,600. A tracker reported daily concurrent figures of roughly 31,000 to 48,000 in late July 2026 (Profitable.app, July 2026). That is still a large Roblox game by normal standards, and its visit count (36 billion) is among the highest on the platform, but it is a fall of more than 99% from the record.

Things I could not verify:
- A widely repeated claim that the game earned $12 million in May 2025. I found no primary source. The studio has declined to share revenue (Press, IGN via Wikipedia).
- Who runs day-to-day development in late 2026. Guide sites say the original leads stepped back in early 2026 and that a sequel exists, but I found no studio statement. A "Grow a Garden 2" experience exists on Roblox under a different group with about 1,000 players on October 27, 2026 (Roblox search API); I could not confirm it is an official sequel.
- Bot accusations. An analyst (TD Cowen) alleged in 2025 that bot activity inflated the game's discovery ranking, then withdrew the manipulation claim. Roblox said its own analysis showed real players (Press, PC Gamer, IGN, Game File via Wikipedia). Treat the peak numbers as real but note the dispute.

## 2. Click-through: title, icon and thumbnails

### What is visible today (Observed, October 2026)

- **Title:** `[🎃] Grow a Garden 🌶️`. Two emoji, one in a bracket tag at the front and one at the end. The bracket tag is seasonal (pumpkin for Halloween). The trailing chilli marks the current content theme.
- **Icon:** a farmer avatar in front of a giant blocky plant, with the words "GROW OFFLINE" in heavy white outlined text at the top. The whole icon sits inside a red, spiky frame branded "The Hollow", the name of Roblox's 2026 Halloween platform event. I could not confirm whether the game is an official participant in The Hollow (the event's published roster of nine games does not list it, per games.gg, October 22, 2026), so the frame may be a seasonal style choice or a partnership I could not trace.
- **Thumbnails:** 10 images in the carousel (the maximum this API returned). The first shows a huge exploding yellow fruit with a rainbow-coloured "$95,643,734,647" across the top, in the same red frame. The second shows a giant glowing jack-o'-lantern crop with "GROW OFFLINE" in large text.
- **Description:** short, with emoji section headers, four "How To Plant" bullets, and the line that your garden "literally grows while you are offline".

### Why these choices plausibly earn clicks

Roblox does not publish CTR for this game, so this is reasoning, not data.

1. **One promise in three words.** "GROW OFFLINE" is the pitch. It answers the question a child scrolling the home page actually has: "will I lose progress if I leave?" It also tells a returning player that they have something waiting. A thumbnail that states the core fantasy beats one that shows a scene the viewer has to interpret.
2. **A giant number.** The rainbow "$95,643,734,647" is a pure aspiration hook. Big numbers are the visual language of simulators: they promise that growth is huge and fast. The rainbow colouring borrows the rarity colour players already associate with the best items.
3. **One oversized object.** The fruit and the pumpkin fill most of the frame. The avatar is small and in the corner, which makes the crop look enormous. Scale contrast reads at the tiny size the home page uses.
4. **Seasonal swap without losing identity.** The farmer, the plot fence and the blocky crop style stay the same; only the crop and the frame change for Halloween. Players who already know the game recognise it instantly, and lapsed players get a "something new happened" signal.
5. **Bracket tags.** The `[🎃]` prefix pattern is now so standard that a search for "grow a garden" on October 27, 2026 returned dozens of games with `[🎃]` prefixes, many of them garden clones (Roblox search API). That tells you two things: the tag is expected by players, and it is no longer a differentiator on its own. It is table stakes.

### How it changed over time (Press and public trackers)

The game's titles tracked updates throughout 2025: named updates such as "Blood Moon" (May 18, 2025), "Bizzy Bees" (May 31), "Working Bees" (June 14), "Summer" (June 21) and the "Corruption" update with an NFL player cameo (July 26) each came with new seeds and events (Press, PCGamesN, Game Rant, PC Gamer, IGN, Eurogamer via Wikipedia). The pattern was a weekly update with its theme reflected in the store page. I could not recover a dated archive of every title and thumbnail change, so the exact wording of past tags is not recorded here.

See [[Thumbnails Icons and Store Page]], [[Discovery and the Algorithm]] and the cross-game comparison note in this section.

## 3. First five minutes

From the game's own description and press coverage (Wikipedia gameplay section, October 2026; guides dated July 2026):

1. You spawn next to your own empty plot of brown soil. Each player in a server gets one plot, visible to everyone else.
2. You have a small amount of the soft currency (Sheckles) and the first thing you can afford is a carrot seed.
3. The seed shop is a few steps away. Its stock is shared by everyone in the server and refreshes on a short timer (a guide reported every 5 minutes in July 2026; I could not confirm the current value).
4. You equip the seed, click a brown plot tile, and a sprout appears immediately. Fast crops are ready within the first minute or two.
5. You harvest, walk to the sell stand, and see a number go up. Then you buy a better seed.

The whole core loop (buy, plant, wait, harvest, sell, upgrade) is shown inside the first two or three minutes, with no tutorial screen. The description's four bullet points are the tutorial. That is the lesson: the first reward arrives before the player has a chance to get bored, and every step uses a verb the player already knows from real life.

Notice what is missing: no combat, no class selection, no lobby, no loading into a separate match. The first click after spawning can be a purchase. Compare with [[First-Time User Experience and Onboarding]] and [[Lobby and Hub Design]].

## 4. Core loop and retention

### The session loop

- **Short loop (seconds to minutes):** check the shop, buy seeds, plant, harvest ripe crops, sell.
- **Medium loop (minutes to hours):** wait for rarer seeds to appear in the restock, plant multi-harvest crops that keep producing fruit, hatch pets that boost growth or apply mutations.
- **Long loop (days to weeks):** collect rare mutated crops, build a garden of high-value perennials, complete weekly event goals for limited items.

### Systems that bring players back

1. **Offline growth.** Crops keep growing while you are away (Studio statement: Jandel called the persistent world novel for Roblox, GamesBeat, September 2025). This turns "log off" from a loss into an investment. Every return session starts with a reward.
2. **Restock timer.** A shared, frequent shop restock creates a reason to stay "just five more minutes" for a rare seed. Because the stock is the same for everyone in the server, a rare restock becomes a social event: players run to the shop together.
3. **Weather and mutations.** Weather events (rain, thunderstorms, meteor showers and many more) apply mutations to crops that multiply their sell value. Guides list Gold at 20x and Rainbow at 50x, with rare weather such as thunderstorms appearing roughly once per 40 restocks (guide sites, mid-2025 to July 2026; I could not verify current values). Weather is a variable-ratio reward on top of a deterministic loop: you know your carrots will grow, but you do not know whether lightning will make one worth 100 times more.
4. **Admin events.** Developers trigger special weather or giveaways live, usually before an update. These are announced on social media and become appointment viewing. The August 23, 2025 mock "admin war" with Steal a Brainrot pushed both games to records (Press, IGN and PocketGamer.biz).
5. **Weekly updates and limited items.** New seeds, pets and events arrived weekly in 2025. Exclusive items had to be claimed while online during the event (Press, Morning Brew and NYT via Wikipedia).
6. **Social visibility.** Every plot is visible to everyone. A huge mutated crop is a status symbol you can walk up to. The description literally says "Flex fruits and finds on friends".

### Why it declined (reasoned from public data and press)

- **Event fatigue.** By August 2025 players were complaining that weekly events felt repetitive; the studio acknowledged this and announced a change of direction (Press, PC Gamer via NME, August 2025).
- **Monetization backlash.** Press reported paid stealing of crops (a January 2026 report gave 37 Robux per steal) and a pass whose price rose sharply; guide sites described players feeling the game "stopped respecting their time" (Press and blogs, January 2026; not verified against the store).
- **Genre cannibalisation.** The game's success produced hundreds of clones and successors. On October 27, 2026 another "Steal a" game had about 800,000 players at the same moment the original garden game had about 13,600 (Roblox search API snapshot). Audiences on Roblox follow the genre and the trend more than any single game (analysis by RoWatcher, early 2026).

The lesson: a loop built on waiting is cheap to produce and extremely sticky, but it has very little depth to fall back on when novelty fades. Weekly content can hold it up for months, not years.

See [[Retention and Return Hooks]], [[Core Loops and Session Design]], [[Live Ops Events and Updates]] and [[Update Cadence and Hype Cycles]].

## 5. Monetization

### What the public store page shows (Observed, October 27, 2026)

- **Game passes:** one, "Premium Seed Pack", not for sale. The game does not sell permanent passes today.
- **Developer products:** not listed publicly by Roblox's API for other games, so the full list cannot be read from outside.

### What press reported (2025 to early 2026)

- Robux can skip waiting, unlock perks and pay to steal other players' crops (Press, PC Gamer and Bloomberg via Wikipedia).
- Pets come from eggs, which work like loot boxes (Press, NYT via Wikipedia).
- A paid steal reportedly costs 37 Robux per action and announces itself to the whole server (blog report, January 2026; unverified).
- Players traded rare items for real money on eBay and Discord, which breaks Roblox's terms (Press, Bloomberg via Wikipedia).
- On July 19, 2025 the game was number one on Roblox's "Top Earners" chart (Roblox Charts, archived, via Wikipedia).

### The shape of the model

Almost all spending is consumable: speed, luck and convenience sold per use. This fits a game where most players are young (Jandel said about 35% are under 13, NYT via Wikipedia) and arrive in huge waves from video. Consumables monetise a spike well because they do not require a long-term commitment. They also cause the strongest backlash when they touch competitive or social systems, such as stealing from another player's garden.

See [[Developer Products and ProcessReceipt]], [[Paid Random Items and Odds Disclosure in Practice]], [[Robux Price Points and Offer Design]] and [[Ethical Design and Player Trust]].

## 6. What to copy and what not to copy

### Copy

1. **Show the whole loop in the first two minutes.** Buy, place, wait briefly, collect, upgrade. Make the first wait under a minute and the first upgrade affordable from the first harvest. Build it with [[First-Time User Experience and Onboarding]] and [[Progression and Pacing Design]].
2. **[[Offline Earnings|Offline progress]] as the return hook.** Save a server timestamp per plot, compute growth on load with `os.time()` differences, and cap it (for example at 8 or 24 hours) so absence is rewarded but not infinitely. Always compute on the server; the client only displays. [[Retention and Return Hooks]], [[Server Authority and Validation]].
3. **Shared restock timers.** A server-wide shop with a visible countdown turns a shop into an event. Generate the stock on the server from a seeded random roll per restock, broadcast it, and show the timer on the HUD. [[HUD Design]], [[RNG Drops and Luck Systems]].
4. **Weather as a multiplier layer.** Keep the base loop deterministic and add random, server-wide modifiers that multiply value. Publish multipliers in game so players can plan. [[Rarity Ladders and Drop Pacing Math]], [[Drop Tables Rarity and Pity Systems]].
5. **Live admin moments.** Plan scheduled global events and announce them in advance. Use [[Cross-Server Messaging]] so every server starts at once, and [[Event Calendars and Content Planning]] to space them.
6. **Visible status.** Let other players see what you grew. Give rare results a glow, a sound and a server-wide message. [[Social Design and Multiplayer Play]].
7. **One-promise thumbnails.** Two or three words of benefit text, one giant object, a small avatar for scale, a rainbow or gold number for aspiration. Swap the seasonal layer, keep the identity layer. [[Thumbnails Icons and Store Page]].

### Do not copy

1. **Paid interference with other players.** Selling the ability to take from someone else's plot is the fastest way to turn delight into resentment, and it is the feature press singled out. If players can affect each other, make it earnable in play and give the victim counterplay. [[Ethical Design and Player Trust]].
2. **Weekly content as the only depth.** A waiting loop needs long-term goals that do not depend on a new seed every week: collections, gardens to design, cooperative goals. Otherwise the team is on a treadmill and players notice repetition within a couple of months. [[Event Calendars and Content Planning]].
3. **Real-money trading pressure.** Tradeable rare items with no in-game market invite off-platform sales and scams. If you add trading, build it safely and give it a sink. [[Trading Systems Without Duplication]], [[Player-Driven Trading Economies]], [[Economy Inflation Sinks and Faucets Math]].
4. **Assuming a spike is a plateau.** Plan infrastructure, moderation and support for 100 times your normal load, but plan the business for the decay that follows. [[Launch Strategy - The First Two Weeks]].
5. **Relying on a seasonal tag to stand out.** When every competitor uses the same `[🎃]` prefix, the tag only says "I am up to date". The thumbnail still has to do the work.

### A small build sketch: offline growth

```lua
--!strict
-- Server-only. Grow time is computed from saved timestamps, never trusted from the client.
local MAX_OFFLINE_SECONDS = 8 * 60 * 60 -- rule of thumb cap: 8 hours

export type Plant = { seedId: string, plantedAt: number, growSeconds: number }

local function progressFor(plant: Plant, now: number): number
	local elapsed = math.clamp(now - plant.plantedAt, 0, MAX_OFFLINE_SECONDS)
	return math.clamp(elapsed / plant.growSeconds, 0, 1) -- 0 to 1, 1 = ripe
end

return { progressFor = progressFor }
```

Store `plantedAt` with `os.time()` when the server accepts the plant request. On join, compute progress for every plant and send the result to the client for display. The cap means a player who leaves for a week does not return to an economy-breaking haul; tune it with [[Simulating an Economy Before Launch]].

## Checklist

- [ ] Can a new player complete buy, plant, collect, upgrade within two minutes with no tutorial screen?
- [ ] Does leaving the game earn the player something they will see on return?
- [ ] Is there a shared, visible timer that creates moments players gather for?
- [ ] Is randomness layered on top of a dependable base loop, with multipliers shown in game?
- [ ] Are status items visible to other players?
- [ ] Is anything you sell allowed to harm another player? If yes, redesign it.
- [ ] Do you have long-term goals that survive a month with no new content?
- [ ] Does your thumbnail state one benefit in two or three words, with one oversized subject?
- [ ] Have you planned for the decline after a spike, not just the spike?

## Sources

- Roblox public game, votes, favourites, game pass, thumbnail and search APIs, all queried October 27, 2026.
- Wikipedia, "Grow a Garden", read October 27, 2026 (citing PC Gamer, PCGamesN, PocketGamer.biz, IGN, Business Insider, NYT, Bloomberg, Game File, Reuters, Roblox Charts).
- GamesBeat, interview with Janzen "Jandel" Madsen, September 7, 2025.
- games.gg, "Roblox The Hollow Halloween event 2026", October 22, 2026.
- RoWatcher, "Is the Brainrot Trend Dying?", early 2026.
- Profitable.app tracker page, July 2026.
- Guide sites on restocks, weather and mutations (ginx.tv, Pocket Tactics, playnews.gg, 2025 to July 2026): treated as unverified.

## Connected notes
<!-- auto-links:start -->
[[Case Study - Steal a Brainrot]] · [[Case Study - 99 Nights in the Forest]] · [[Top Games Case Studies Start Here]] · [[Case Study - Dress to Impress]] · [[Core Loop]] · Click-Through Rate
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Case Study - Adopt Me]] · [[Case Study - Blox Fruits]] · [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]] · [[Case Study - Pet Simulator 99]] · [[Case Study - Doors]] · [[Case Study - Brookhaven RP]] · [[Case Study - Fisch]] · [[Case Study - Dead Rails]]
<!-- related:end -->
