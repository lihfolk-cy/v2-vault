---
cssclasses: [vault-hub]
tags: [teardown, viral-trend, start-here, hub, case-study, game-design, marketing, type/hub, area/design, level/beginner, area/marketing]
verified: 2026-10-29
---

# Viral and Trend Teardowns Start Here

This section tears down the fast-to-build end of Roblox: steal-a-X, grow-a-X, brainrot fusions, "+1 per second" games, clickers, RNG rollers, meme obbies, physics toys, round-based party games and social hangouts. It covers the biggest hits of 2024-2026 plus the classics they grew from. Each note explains what works, which systems to build, and how to raise the quality bar so a fast game lasts longer.

It complements [[Top Games Case Studies Start Here]], which already covers Grow a Garden, Steal a Brainrot, Fisch, Pet Simulator 99, Adopt Me, Dead Rails, 99 Nights in the Forest and others. Those games are not repeated here; the teardowns link to them.

## How to read these notes

- **One snapshot for all "now" numbers.** Visits, favourites, votes, server size, creation and update dates, playing-now counts and public game-pass prices were read from Roblox's public game, votes, game-pass and explore (charts) APIs at **08:06 UTC on Thursday 2026-10-29**. That hour is off-peak for the Americas, so playing-now counts are a low point of the day, not an average.
- **Peaks come from named trackers** (RoStats, Rolimons, RoWatcher, Rotrends, RoMonitor) seen via search on 2026-10-29, or from press, each with its date. Trackers sample Roblox's public API and only record from the day they start following a game, so a tracker's "all-time" can miss earlier spikes.
- **Trust labels on every number:**
  - **Measured**: read from the Roblox API snapshot above, or a named tracker's sampled figure (marked "tracker"), or computed from those (marked "computed").
  - **Roblox docs**: Creator Hub, DevForum staff posts, Community Standards, newsroom.
  - **Rule of thumb**: design guidance, not data.
  - **Unverified**: single low-authority source, self-reported, or conflicting figures.
- **Nothing was played or logged into.** Gameplay descriptions come from store pages and from guides, which are treated as Unverified for exact values.
- **Roblox does not publish other creators' revenue, retention or click-through rates.** None are invented here.
- **Original wording only.** Store descriptions are paraphrased; no images or assets are reproduced.

## The teardowns

| Teardown | Type | The hook in one line |
|---|---|---|
| [[Teardown - Steal An Egg]] | Steal-a-X, pets | Train speed, outrun an egg's guardian, hatch a pet that earns, and guard your pen |
| [[Teardown - Plants vs Brainrots]] | Brainrot fusion, lane defence | The enemies your plants defeat become your income |
| [[Teardown - Escape Tsunami for Brainrots]] | Brainrot fusion, hazard run | Grab and run before the wave; the world is the thief, not other players |
| [[Teardown - +1 Speed Keyboard Escape]] | +1 per step, speed obby | Every step makes you faster, and faster makes the keyboard course harder |
| [[Teardown - Fish It]] | Simplified fishing collector | A friendlier fishing loop with "1 in X" rarities and close-together islands |
| [[Teardown - Ride A Pet]] | Pet collection, exploration | Your best pet is your vehicle, so every hatch opens more of the map |
| [[Teardown - Tap Simulator REBORN]] | Clicker, incremental | A brand relaunch of the purest loop: tap, hatch, rebirth |
| [[Teardown - Sol's RNG]] | RNG roller | One Roll button, 400+ auras and biomes that bend the odds |
| [[Teardown - Ink Game]] | Event-driven round game | A 100-player elimination show with a group vote on the ending |
| [[Teardown - Bee Swarm Simulator]] | Classic collect-and-convert sim | A solo developer's deep, gentle simulator with a yearly event ritual |
| [[Teardown - Build A Boat For Treasure]] | Classic building sandbox | Creativity with a destination: build, launch, see how far you get |
| [[Teardown - Natural Disaster Survival]] | Classic round survival | A random disaster each round, and a crowd to survive it with |
| [[Teardown - Fling Things and People]] | Physics toy | Grab anything, including other players, and throw it |
| [[Teardown - Tower of Hell]] | Meme obby classic | No checkpoints and a fresh random tower every round |
| [[Teardown - PLS DONATE]] | Social hangout | A booth, a sign, and the hope a stranger will be generous |
| [[Viral Game Anatomy - Hooks, Loops and Timing]] | Synthesis of all of the above | Fast-to-fun verbs, one twist, return hooks, event cadence, clone waves, titles |

## Every teardown follows the same shape

Snapshot (numbers with labels) → Core loop diagram → First 60 seconds → Progression and economy → Monetization and 2026 compliance → Retention hooks → Multiplayer and social design → Art, UI, title and thumbnail → Technical notes → Why it went viral → Build it yourself → Raise the quality bar → Common mistakes → Checklist → See also → Sources.

## Suggested reading paths

- **Making a steal-a-X or brainrot-style game:** [[Case Study - Steal a Brainrot]], then [[Teardown - Steal An Egg]], [[Teardown - Escape Tsunami for Brainrots]] and [[Teardown - Plants vs Brainrots]]. Pair with the trend-game skill (`/lihfolk:trend-game`) and [[Discovery and Monetization Changes 2025-2026]].
- **Making a +1, clicker or incremental game:** [[Teardown - +1 Speed Keyboard Escape]], [[Teardown - Tap Simulator REBORN]], [[Teardown - Sol's RNG]]. Pair with [[Rebirth and Prestige System End to End]] and [[Big Numbers Precision and Formatting]].
- **Making a collection or luck game:** [[Teardown - Fish It]], [[Teardown - Sol's RNG]], [[Teardown - Ride A Pet]], [[Teardown - Bee Swarm Simulator]]. Pair with [[Paid Random Items and Odds Disclosure in Practice]] and [[Drop Tables Rarity and Pity Systems]].
- **Making a round-based or party game:** [[Teardown - Ink Game]], [[Teardown - Natural Disaster Survival]], [[Teardown - Tower of Hell]]. Pair with [[Round-Based Minigame Loop End to End]].
- **Making a physics or sandbox game:** [[Teardown - Fling Things and People]], [[Teardown - Build A Boat For Treasure]]. Pair with [[Physics and Vehicles Start Here]].
- **Making a social hangout:** [[Teardown - PLS DONATE]], then [[Case Study - Brookhaven RP]] and [[Genre Playbook - Roleplay and Social Hangouts]].

## The rules every teardown checks against (as of October 2026)

- Paid random items, including luck boosts and bundles with randomness, need numerical odds summing to 100% before purchase, live-updating odds under boosts, value in every outcome, and `PolicyService` gating that fails closed (Roblox docs, 2026-05-26). See [[Paid Random Items and Odds Disclosure in Practice]] and [[Regional Compliance - Paid Random Items and Country Rules]].
- Recommended For You uses 28-day windows, first-play bounce rate and play-through rate, and credits at most 60 minutes of playtime per user per game per day (Roblox docs, 2026-06-15).
- Home rewards games strong in both retention and monetization (Roblox docs, 2026-08).
- New games reach under-16 players only after an evaluation period (Roblox docs, 2026-06).

## Before you write your own teardown

Use [[Competitor Analysis Method]]. Record the date and hour of every number, separate what you observed from what you inferred, and re-check the store page a week later; titles, passes and descriptions change with each update.

## See also

- [[Top Games Case Studies Start Here]]
- [[Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks]]
- [[Genre Systems Start Here]], [[Worked Builds Start Here]], [[Live Ops Deep Dive Start Here]], [[Economy Design Start Here]], [[Marketing and Growth Start Here]]
- [[LihFolk Systems Library]]
