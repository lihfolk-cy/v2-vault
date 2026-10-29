---
tags: [case-study, top-games, fishing, collection, rng, minigame, live-ops, thumbnails, monetization, progression, type/case-study, area/design]
---

# Case Study - Fisch

<!-- tldr:start -->
> [!tldr] TL;DR
> - First catch (first reward) in under a minute.
> - Minigame adds skill to a luck-based reward.
> - Each zone has a finite collection goal.
> - Some rewards depend on time, weather or season.
> - How-to-play lines in the store description.
> - Passes sell convenience ("anywhere") before power.
>
> Cost: TL;DR ~110 tok · whole note ~3.7k tok. Read more: ## Snapshot · ## Click-through: thumbnail, icon and title · ## Checklist
<!-- tldr:end -->

Fisch is a fishing game: cast, wait, play a short reel minigame, catch one of hundreds of species with random size and mutation, sell or keep it, buy a better rod, travel to a new island. It took a genre most people think of as filler and made it one of the most played games on Roblox in its first year. It is also a cautionary tale: a big expansion in 2025 split the player base, and the developers ended up polling players and removing it. Both halves are worth learning from.

Source labels used below: **Public stats** (Roblox's public APIs or a stats site, with the date checked), **Observed on the store page** (the public experience page, thumbnails and pass list, October 2026; nothing was played or logged into), **Press** (news and guide sites, with dates), **Community wiki** (fan wikis, lower confidence; flagged where used).

## Snapshot

| Field | Value | Source |
|---|---|---|
| Genre | Roblox lists it as "Simulation"; a fishing, collection and exploration game | Public stats, Roblox games API, checked 27 October 2026 |
| Creator | Fisching (group); original developer credited as WoozyNate | Public stats, Roblox games API; Public stats site, RoWatcher |
| Place created | 13 March 2024 | Public stats, Roblox games API |
| Public release | 5 October 2024 (trailer and date announced 29 September 2024) | Press, Destructoid (10 April 2025); Community wiki |
| Ownership | Acquired by DoBig Studios on 2 November 2024, moved into the Fisching group 4 November 2024; the wiki says DoBig left the group and returned ownership to the original developer on 21 August 2025 | Community wiki (Roblox fandom), via search, October 2026; not confirmed by a studio statement |
| Visits | 5,071,834,187 | Public stats, Roblox games API, 27 October 2026 |
| Favourites | 3,705,899 | Public stats, Roblox games API |
| Votes | 3,074,953 up, 311,210 down (about 91% positive) | Public stats, Roblox votes API, 27 October 2026 |
| Playing at check time | 57,943 | Public stats, Roblox games API, 27 October 2026 |
| Typical concurrency | 7-day average about 74,700, 14-day average about 79,800 | Public stats site, RoTrends, read October 2026 |
| Peak concurrency | 1.3M on RoTrends (no date); the community wiki says Fisch was the 14th game to reach 1 million concurrent players, on 4 October 2025; RoWatcher's sidebar shows lower peaks for its own tracking window | Public stats sites and Community wiki, October 2026 |
| Server size | 20; avatars forced to R6 | Public stats, Roblox games API |

How to read this: the 1 million milestone comes from a single community source and the 1.3M peak from one tracker with no date. Both are plausible together (a 1.3M peak after crossing 1M), but neither is an official Roblox figure. Treat "over a million at peak in 2025" as likely, not verified. Visits went from "just under three billion" in April 2025 (Press, Destructoid) to just over five billion in October 2026 (Public stats), so the game kept adding roughly two billion visits in eighteen months after its crisis.

Timeline of the crisis (Press, Destructoid, 10 April 2025): the Second Sea update released 29 March 2025. Reaching it required level 200, it used a new currency so players effectively started over, First Sea rods were weakened, and the level cap rose from 1,000 to 2,500. Players left "by the thousands" (no figures published). On 7 April 2025 the developers ran an in-game poll open to almost 50,000 players, then a second poll, and were reported to be "seriously considering" removing the Second Sea. The community wiki says the Second Sea was removed on 31 August 2025 with the Continental Drift update (Community wiki, not confirmed by a studio statement).

A competitor matters to the story: Fish It!, a different fishing game, launched 21 October 2024; one tracker reports an all-time peak around 2.7 million (Public stats site, RoWatcher, read October 2026; unverified). Fisch proved the genre and was quickly out-scaled by a follower. Being first is not a moat.

## Click-through: thumbnail, icon and title

Roblox does not publish click-through rate for other people's games, so this section reasons from what is visible and from the metric Roblox uses for your own game (qualified play-through rate under thumbnail personalization; Roblox docs, as of October 2026).

**Title.** At check time: `Fisch 👻 [HORSEMAN]`. Skeleton: the one-word brand, one emoji, one bracketed tag in capitals naming the current update. RoWatcher's archived page names for the same game show the rotation over two years: `[FISCHFRIGHT]`, `[SKYCREST]`, `[RACING]`, `[JOURNAL]`, `[ASTRAL]`, `[CHAPEL]`, `[SOON]`, `[NOW]`, `[ROAMING FISH]`, `[MARIANA]`, `[BUDLING]`, `[BIRTHDAY]`, `[DRYLANDS]`, `[SEI WHALE]`, `[SAVE NATE]`, `[EASTER]` and more (Public stats site, RoWatcher URLs, read October 2026). Note `[SOON]` and `[NOW]`: a teaser tag before an update, then a launch tag the day it lands. That is a two-step hype cycle done entirely in the title.

The name itself is a lesson: "Fisch" is one syllable, misspelled just enough to be searchable and ownable, and still obviously about fishing.

**Icon** (Observed on the store page, October 2026). A classic yellow-faced avatar with a terrified open mouth, holding a glowing red rod, beside a giant dark serpent with purple glow, pumpkins and candles around, a second avatar in a top hat behind. No text. The emotion is the hook: a small person versus a huge fish.

**Thumbnails** (Observed, first two returned by the public thumbnails API, 27 October 2026):

1. Halloween: a giant dark purple sea serpent rising from glowing green water in a candle-lit cave, a witch-hatted avatar reeling in a skeletal fish. No text.
2. Birthday: a cheerful avatar in a party hat on a dock, a huge red sea dragon wearing a party hat, balloons, confetti, a gift box with "FISCH" printed on it.

What earns the click:

- **Scale contrast.** Every image puts a small blocky avatar next to an enormous creature. "You can catch that?" is the question the thumbnail asks.
- **In-engine look.** The art is Roblox-rendered with heavy post-processing and lighting, not illustration, so the first session matches the promise. Compare [[Case Study - Pet Simulator 99]], which uses flat illustration.
- **Stale cards in rotation.** The birthday thumbnail was still active in late October. With personalization, an old card that still wins its segment keeps serving; that is fine, but a card advertising a finished event can cost trust. Retire event art when the event ends.
- **No text, tag in the title.** Same split as PS99: the title carries the news, the art carries the fantasy.

## First five minutes

From the official store description and guides (not played for this note):

1. **Instructions on the store page.** The description itself teaches the verb: hold to cast, wait for a bite, you can "shake" to attract fish faster, then hold or click to keep a white bar on a moving blue line until the progress bar fills (Observed on the store page, October 2026). Putting the controls on the store page means players arrive already knowing what to do.
2. **Free rod at the start island.** The starting rod is free at the first island, Moosewood, and has zero in its stats (Press, rblxguide rod page). The next rods cost in-game cash: one guide lists 300, 750 and 2,000 for the next three, another gives a different price for one of them (Press, rblxguide; prices vary by version).
3. **First catch in under a minute.** Cast, bite, reel minigame, fish. The first reward is the fish itself with its random size and possible mutation, and the bestiary entry.
4. **Sell and upgrade.** Sell the catch at the merchant and save for the next rod. Guides recommend upgrading the rod before bait because rod stats are permanent (Press, rblxguide guide).
5. **First collection goal.** The first island's bestiary has a set of species to complete (one guide says 16); some fish depend on weather, time of day or season (Press, dungeonpath beginner guide). A finite checklist on the first island gives the first session an end goal.

## Core loop and retention

**Session loop.** Cast, minigame, catch, appraise or sell, buy rod or bait, move to a new spot. The minigame is the skill layer: a better player catches harder fish with the same rod. The variation system is the luck layer: the description claims 400,000+ possible variations per species (Observed on the store page), so even common fish can roll something rare.

**Long-term goals.** Rods (stat upgrades and collectible flex), islands (each with its own bestiary and conditions), levels, enchantments and appraisal (the pass list implies "Enchant" and "Appraise" as systems), and rare event creatures.

**Timed systems.** Weather, time of day and seasons change which fish appear (Press, dungeonpath). That is a retention system disguised as a world: "the fish I need only bites at night in the rain" brings a player back at a different time.

**Update cadence.** Weekly, usually Saturday, per several guides (Press, Ginx and Deltia's Gaming, 2025; not confirmed from an official schedule for October 2026). Named updates: the 1 November 2025 update added a Fabulous Rod and Nico's Yarncaster (Press, Gfinity, December 2025), an Atlantis update ran through late July into August 2026 (Press, allthings.how). A Halloween Spotlight ran 23 October to 3 November 2025 (Community wiki).

**Community steering.** After the Second Sea backlash, in-game polls with tens of thousands of voters decided its fate. Polling is a real retention tool, but here it was a repair, not a plan.

## Monetization

Full public pass list from the Roblox game pass API, 27 October 2026 (Observed on the store page):

| Pass | Price (Robux) | Kind |
|---|---|---|
| Emote Pack | 99 | Cosmetic |
| Bobber Pack | 99 | Cosmetic |
| Supporter | 169 | Supporter perk |
| Enchant Anywhere | 239 | Convenience |
| Double XP | 239 | Progress multiplier |
| Spawn Boat Anywhere | 299 | Convenience |
| Appraisers Luck | 299 | Paid luck (appraisal) |
| Sell Anywhere | 399 | Convenience |
| Appraise Anywhere | 499 | Convenience |
| Aquarium Boat, Radio | Not for sale | Retired or unreleased |

Developer products (rods, bait, crates, boosts) are not listed by the public API without logging in and were not verified. RoTrends listed 9 passes; the API returned 11 including two not for sale.

Read the table as a design: most passes sell "anywhere", meaning they remove a walk back to an NPC. That is the friendliest form of convenience monetization: the free player loses a minute, the paying player saves it, nobody gets stronger. One pass sells luck on appraisal, and Double XP sells speed. Compare the PS99 store, where luck is the top of the ladder.

## What to copy

1. **A skill minigame on top of a luck roll.** The reel bar makes every catch an action, and the random variation makes every catch a lottery. Skill keeps it from feeling like a slot machine; luck keeps it from feeling like work. See [[RNG Drops and Luck Systems]] and [[Rarity Ladders and Drop Pacing Math]].
2. **Controls in the store description.** Four short lines of "how to play" on the store page. Free onboarding for every visitor who reads.
3. **Finite bestiary per zone.** A checklist per island gives every zone an end and makes "complete the set" the first goal. [[Quests and Objectives]], [[Zone and Biome Art Direction]].
4. **World state as retention.** Fish tied to weather, time and season are a return hook that needs no calendar UI. [[Lighting Mood and Time of Day]] and [[Retention and Return Hooks]].
5. **"Anywhere" passes.** Sell convenience as removing a walk, never as removing a fight. [[Game Passes]], [[Shop with Game Passes and Developer Products End to End]].
6. **Teaser then launch tags.** `[SOON]` days before, `[NOW]` on the day. It costs nothing. [[Update Cadence and Hype Cycles]].
7. **A brand name you can own.** Short, playful, searchable. See [[Naming Items Zones and Abilities]] for the naming method.
8. **Scale contrast in thumbnails.** Small avatar, huge creature, in-engine render. [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]].

## What not to copy

- **An expansion that resets players.** The Second Sea combined a high entry level, a new currency, weakened old gear and a higher level cap. Each alone is survivable; together they told every player their progress was worth less. If you add a new tier, let old progress count, keep old gear relevant in old zones, and test the change on a slice of servers first ([[Feature Flags and Staged Rollouts]], [[Economy Resets and Seasonal Wipes]]).
- **Polling as damage control.** Poll before you ship, on concepts, not after you ship, on whether to delete the update. [[Patch Notes and Player Communication]].
- **Ownership churn in public.** Selling a game to a studio and then reversing it within a year (as the community wiki reports) shows up in group names, credits and player trust. If you sell, plan the handover. See [[Running a Small Studio as a Business]] and [[Commissions Pricing and Contracts]].
- **Assuming first means safe.** A follower in the same genre reportedly out-peaked Fisch within its first year. Your moat is update speed and community, not the idea. [[Competitor Analysis Method]].
- **Leaving finished-event art in rotation.** A birthday card still serving in late October is a small trust leak. Retire event thumbnails when the event ends.
- **Over-variation.** "400,000+ variations" is a marketing number; too many near-identical variants make the bestiary feel like noise. Make each rarity tier visually distinct.

## Checklist

- [ ] First catch (first reward) in under a minute.
- [ ] Minigame adds skill to a luck-based reward.
- [ ] Each zone has a finite collection goal.
- [ ] Some rewards depend on time, weather or season.
- [ ] How-to-play lines in the store description.
- [ ] Passes sell convenience ("anywhere") before power.
- [ ] Big expansions keep old progress valuable and roll out to a slice first.
- [ ] Event art retired when the event ends.
- [ ] Title skeleton fixed; teaser and launch tags planned.

## Connected notes
<!-- auto-links:start -->
[[Case Study - Doors]] · [[Case Study - Blox Fruits]] · [[Case Study - Brookhaven RP]] · [[Top Games Case Studies Start Here]] · [[Core Loop]] · Marketing and Growth Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Teardown - Fish It]] · [[Case Study - Adopt Me]] · [[Case Study - Steal a Brainrot]] · [[Case Study - 99 Nights in the Forest]] · [[Case Study - Grow a Garden]] · [[Case Study - Dress to Impress]] · [[Case Study - Jailbreak]] · [[Case Study - Dead Rails]] · [[Case Study - The Strongest Battlegrounds]]
<!-- related:end -->
