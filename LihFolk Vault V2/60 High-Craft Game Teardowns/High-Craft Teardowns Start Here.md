---
cssclasses: [vault-hub]
tags: [teardown, high-craft, start-here, hub, game-design, case-study, type/hub, area/design, level/beginner]
verified: 2026-10-29
---
# High-Craft Teardowns Start Here

This section takes apart high-production Roblox games across genres and asks one question of each: **what craft makes it feel premium, and how would you build that yourself?** Section 32 ([[Top Games Case Studies Start Here]]) covers the most played games from a store-page and business angle. Section 59 covers viral and trend games. This section stays on the craft end: combat feel, netcode, horror pacing, audio, art direction, building tools, rhythm sync and live-ops discipline.

## How to read these notes

- **Every note has the same parts:** Snapshot, Core loop, First 60 seconds, The craft that sets it apart, Progression and economy, Monetization and 2026 rules, Retention, Tech notes, Team and cadence, Build it yourself, Numbers to remember, Common mistakes when copying this style, Checklist, See also.
- **Trust labels on every fact:**
  - **Roblox docs**: Roblox documentation or an official Roblox post (for example a DevForum Creator Spotlight).
  - **Measured**: read by us on 29 October 2026 from Roblox's public games, votes and game-passes APIs, or from the Rolimons tracker.
  - **Rule of thumb**: our design reading or engineering advice, not a published fact.
  - **Unverified**: press, wikis, community guides or developer posts we could not confirm independently.
- **Snapshot week caveat.** 29 October 2026 fell during Roblox's Halloween platform event, so "playing now" counts are event-week numbers. Tracker peaks only cover the period a tracker has been recording, so older games' true peaks may be higher than shown.
- **Nothing was played or logged into.** Mechanics come from public pages, official posts and community guides, labelled as such.
- **Original wording only.** No descriptions, images or assets were copied. Copy mechanisms, never names, characters or art.

## The games

| Genre | Teardown | Key stat (label, source, date) | The one craft lesson |
|---|---|---|---|
| Horror roguelite | [[Teardown - Pressure]] | 112,111 peak CCU on 28 Mar 2026 (Measured, Rolimons, read 2026-10-29) | Make audio the primary sensor: every threat is heard before it is seen |
| Speed horror | [[Teardown - Grace]] | 93.0% rating (Measured, Roblox votes API, 2026-10-29) | Give each entity a different verb so overlaps create choices |
| Co-op cartoon horror | [[Teardown - Dandy's World]] | 875K peak CCU, first Easter event (Roblox docs, Creator Spotlight, 5 May 2025) | One base character design, one trait each, and a twisted twin per hero |
| Asymmetric horror (classic) | [[Teardown - Piggy]] | 533,409 peak CCU on 24 May 2020 (Measured, Rolimons) | Chapters on a schedule turn map releases into appointments |
| Movement survival | [[Teardown - Evade]] | 165,296 30-day peak vs 197,261 all-time (Measured, Rolimons, read 2026-10-29) | Simple enemies plus deep, stackable movement tech |
| Open-world survival | [[Teardown - Apocalypse Rising 2]] | 43,831 peak CCU on 18 Sep 2026 (Measured, Rolimons) | Loss on death gives every found item meaning |
| Tactical FPS (classic) | [[Teardown - Phantom Forces]] | 32-player servers, 90.7% rating (Measured, Roblox API, 2026-10-29) | Client-detected hits, server-validated with a latency-aware window |
| Arcade shooter (classic) | [[Teardown - Arsenal]] | 6.3 billion visits (Measured, Roblox API, 2026-10-29) | Remove the loadout decision; normalise hitboxes |
| PvP sandbox | [[Teardown - BedWars]] | 334,747 peak CCU on 27 Aug 2022 (Measured, Rolimons) | Building is combat: predict blocks on the client, own them on the server |
| Skill PvP | [[Teardown - Blade Ball]] | 511,924 peak CCU on 19 Nov 2023 (Measured, Rolimons) | One input with rising tempo; timestamped parries with a capped rewind |
| Anime battlegrounds | [[Teardown - Jujutsu Shenanigans]] | 697,083 peak CCU about 24 Oct 2026 (Measured, Rolimons, read 2026-10-29) | Hidden timing rewards and readable, fast-clearing VFX |
| Souls-like RPG | [[Teardown - Deepwoken]] | 400 Robux paid access; 62,422 peak CCU on 23 Dec 2022 (Measured) | Commitment combat plus permanent stakes, protected by bulletproof saves |
| Social sim and building | [[Teardown - Welcome to Bloxburg]] | 592,451 peak CCU on 28 Jun 2025 (Measured, Rolimons) | The build tool is the product: snapping, previews, costs and undo |
| Rhythm | [[Teardown - Funky Friday]] | 125,314 peak CCU on 24 Jul 2021 (Measured, Rolimons) | Schedule notes from the song clock and ship an offset calibration |
| Tower defense / strategy | [[Teardown - Anime Vanguards]] | 96.7% rating; 48.2-minute average session (Measured, 2026-10-29) | Information-rich UI and honest odds on every summon |
| Racing and vehicles | [[Teardown - Driving Empire]] | 31,810,888 favourites (Measured, Roblox API, 2026-10-29) | Driver-owned physics, server checks, and streaming ahead of the car |

The cross-cutting synthesis is [[What Craft Looks Like on Roblox - Lessons from Top Studios]].

## Reading paths

- **Making a horror game:** Pressure, Grace, Dandy's World, Piggy, then [[Case Study - Doors]] and [[Case Study - Forsaken]]. Pair with [[Genre Playbook - Horror and Story]] and [[Horror Monster Chase AI End to End]].
- **Making a combat or PvP game:** Jujutsu Shenanigans, Deepwoken, BedWars, Blade Ball. Pair with [[Melee Combat System End to End]], [[Client Prediction and Reconciliation for Combat]] and [[Game Feel Start Here]].
- **Making a shooter:** Phantom Forces, Arsenal, then [[Case Study - Rivals]]. Pair with [[Genre Playbook - Shooters FPS and TPS]] and [[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]].
- **Making a social or building game:** Welcome to Bloxburg, then [[Case Study - Brookhaven RP]]. Pair with [[Grid Placement and Player Building Systems]].
- **Making a niche genre (rhythm, racing, tower defense):** Funky Friday, Driving Empire, Anime Vanguards. Pair with [[Music and Adaptive Audio]], [[Physics and Vehicles Start Here]] and [[Genre Playbook - Tower Defense]].
- **Monetization under 2026 rules:** the Monetization sections of Blade Ball, Anime Vanguards and BedWars, then [[Paid Random Items and Odds Disclosure in Practice]] and [[Policy and Age Rules 2026]].

## Doing your own teardown

Use [[Competitor Analysis Method]]. Read the store page and public APIs on a stated date, separate what you measured from what you inferred, and label every number. Watch a game across an update: the change in its numbers tells you what its players valued.

## See also

[[Top Games Case Studies Start Here]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]] · [[Genre Systems Start Here]] · [[Game Feel Start Here]] · [[Level Design Start Here]] · [[Live Ops Deep Dive Start Here]]
