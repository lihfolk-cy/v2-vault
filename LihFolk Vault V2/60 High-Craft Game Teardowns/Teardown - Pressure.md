---
tags: [teardown, high-craft, horror, roguelite, co-op, procedural-generation, audio, art-direction, type/case-study, area/design, level/intermediate, area/audio]
verified: 2026-10-29
---
# Teardown - Pressure

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Dark for its own sake -> keep the player's flashlight and the counter (locker, vent) readable; darkness should hide the...
> - Avoid: Warning sounds on the music bus -> put warnings on their own SoundGroup that the music slider cannot mute.
> - Avoid: Random rooms with no guaranteed hide spot -> validate every generated room for at least one reachable hide spot before the...
> - Every threat has one audio tell and one counter, readable in the dark.
> - Every generated room passes a hide-spot and route check on the server.
> - Death screen explains the cause in-world.
>
> Cost: TL;DR ~190 tok · whole note ~3.0k tok. Read more: ## Snapshot · ## The craft that sets it apart · ## Common mistakes when copying this style · ## Checklist
<!-- tldr:end -->

Pressure is a first-person co-op horror roguelite set in a flooded deep-sea research facility: you descend through about a hundred generated rooms, scavenge, hide from creatures in lockers, and try to reach the facility's core and get out.

**Trust labels used in every teardown:** **Roblox docs** (Roblox documentation or an official Roblox post), **Measured** (read by us from Roblox's public games API or a public tracker on the date shown), **Rule of thumb** (our design reading, not a published fact), **Unverified** (press, wikis or community sources we could not confirm). Nothing was played or logged into for this note.

## Snapshot

| Field | Value | Label and source |
|---|---|---|
| Creator | Urbanshade: Hadal Division (group) | Measured, Roblox games API, 2026-10-29 |
| Visits | 492,976,102 | Measured, Roblox games API, 2026-10-29 |
| Favourites | 1,653,312 | Measured, Roblox games API, 2026-10-29 |
| Rating | 86.8% (732,652 up / 111,501 down) | Measured, Roblox votes API, 2026-10-29 |
| Playing at check | 516 | Measured, Roblox games API, 2026-10-29 (between updates) |
| All-time peak CCU | 112,111 on 28 March 2026 | Measured, Rolimons, read 2026-10-29 |
| Average session | about 12.2 minutes | Measured, Rolimons, read 2026-10-29 |
| Lobby server size | 50 | Measured, Roblox games API, 2026-10-29 |
| Development start / release | 7 Feb 2023 / 7 July 2024; console 15 July 2024 | Unverified, official Pressure wiki, read 2026-10-29 (place creation date of 7 Feb 2023 is Measured) |
| Lead developer | Zeal (YourFriendZeal), plus named animators, programmers and composers | Unverified, official Pressure wiki |

The March 2026 peak lines up with the "Half A Slice Of Cake" update date on the wiki (modifiers, 200+ item skins, 250+ charms, 11 new creatures). The 516 players at check time is a quiet week, which is the normal shape for an update-driven horror game: big spikes on release day, a modest floor between.

## Core loop

1. **Lobby (Submarine Bay).** Form a party, pick an expedition, buy a loadout with soft currency.
2. **Descend.** Open doors through generated rooms, now counted down from 100 towards 1 (Unverified, wiki), so the number itself tells you how deep you are.
3. **Scavenge and survive.** Pick up Research (in-run currency) and items: flashlight, batteries, code breachers, medkits. Hide in lockers or vents when a creature's warning plays.
4. **Die and learn, or extract.** After a run you earn Kroner based on Research, doors and distance; Kroner buys revive tokens, jumpsuits and pre-run items (Unverified, wiki).

## First 60 seconds

- You spawn in a lit, populated submarine bay: the safe space is also the social space, so new players see others in jumpsuits before they see a monster.
- Joining a run is one walk into a queue pad, with host, join, invite and Quickplay options added in March 2026 (Unverified, wiki).
- The first rooms are quiet. The first threat arrives with a long audio and light warning, and the counter (a locker) is visible in almost every room. **Rule of thumb:** the game teaches "hear it, hide" before it ever punishes you for not knowing.
- A content warning screen was added in August 2024 (Unverified, wiki). It sets expectations for loud audio and flashing before the first scare.

## The craft that sets it apart

**1. Audio is the primary sensor.** In a dark, flooded corridor your eyes are unreliable, so creatures announce themselves with distinctive sound signatures that grow with distance and direction. The composer credits on the wiki (an original soundtrack released on YouTube and Spotify in July 2024) show audio was treated as a discipline, not a task. **Rule of thumb:** for every lethal entity, the warning sound must be audible over the ambient bed at the distance where hiding is still possible. Tune the hiding window first, then the sound.

**2. One counter per threat, many contexts.** Most creatures are survived by hiding in a locker or vent, or by staying out of their path (Unverified, wiki). That single verb stays readable while room generation changes the context: how far is the nearest locker, is it already taken by a teammate, is the vent on the far side of a flooded floor? Difficulty comes from layout, not from a new rule.

**3. Diegetic death teaching.** After a death, a character reveals documents about the creature that killed you (Unverified, wiki). The tutorial is written as lore, so it never feels like a tutorial and players read it because they want revenge.

**4. A strong environmental identity.** Pipes, pressure doors, bioluminescent light, wet surfaces and a cold blue-green palette make the setting readable at thumbnail size and distinct from hotel or forest horror. The art direction is the brand.

**5. Room count as a dramatic arc.** Counting down to 1 turns progress into tension: the number gets smaller as the danger gets bigger. Endless and modifier modes reuse the same rooms with new stakes.

## Progression and economy

- **Two currencies with clean jobs.** Research is earned and spent inside a run; Kroner persists and buys cosmetics, revive tokens and run starters (Unverified, wiki).
- **No stat power creep.** Your character gets cosmetics and convenience, not more health. Veterans carry knowledge, which keeps mixed parties fair.
- **Modifiers as late-game progression** (50+ added March 2026, Unverified): the same game, re-tuned, is cheaper than new floors and gives skilled players a ladder.

## Monetization and 2026 rules

Public pass list (Measured, Roblox game-passes API, 2026-10-29): Admin Pass Privileges 599, 25% Kroner Boost 599, Post-Mortem Haunting 199, Deep Sea Buddy 149, Rotten Coral Skin Pack 149, Chibi Keycharm Pack 75 Robux.

Wiki-reported extras (Unverified): a second revive in a run costs 30 Robux; a revive or ghost mode can be earned by watching an ad; group members get a shop discount.

- **Ad-funded revives** are the respectful version of pay-to-continue: the player can choose time over money. Follow [[Ads and Rewarded Video]] for eligibility and age rules.
- **Cosmetic-first passes** stay clear of the 2026 paid-random-item rules because nothing is random. If you add a random cosmetic crate, you need numeric odds before purchase: [[Paid Random Items and Odds Disclosure in Practice]] and [[Policy and Age Rules 2026]].
- **Content maturity:** horror needs an accurate maturity questionnaire; see [[Roblox Policies Ratings and Compliance]].

## Retention

- **Named, dated updates** roughly every two to four months through 2024-2026 (Friendly Fire, The Raveyard, Four Point Five, The Hunted, Worth The Wait Part One, Operation Heartburn, Half A Slice Of Cake; Unverified, wiki dates).
- **Platform events.** "The Hunted" was part of Roblox's The Hunt: Mega Edition (March 2025) and "Operation Heartburn" was part of The Takeover (September 2025) (Unverified, wiki). Event participation brings a new audience into an existing loop.
- **Seasonal expeditions** (a Halloween expedition, endless mode) give returning players a reason to log in without a full new chapter.

## Tech notes

- **Generated rooms need authored seams.** **Rule of thumb:** a room-kit generator works when every room has standard door sockets, a known locker budget, and a "creature path" volume so the server can check that the threat has a route and the player has a hide spot within reach.
- **50-player lobby, small run servers.** Teleport parties from the lobby to separate run places: [[Teleporting and Multi-Place Games]] and [[Lobby and Hub Design]].
- **Server owns the threat.** Spawning, creature position and "was the player hidden" checks belong on the server; the client only plays the sound and screen effects. See [[Server Authority and Validation]].
- **Console support at launch week** (Unverified) means gamepad hiding, flashlight and inventory had to work without a mouse: [[Gamepad and Console UX]].

## Team and cadence

A named core team (lead, two main programmers, animators, a composer) is listed on the wiki (Unverified). Development ran about 17 months from place creation to release. Updates are large and named, with smaller fixes between.

## Build it yourself

1. **Room kit generator with sockets.** Build 20 rooms with door sockets and tagged hide spots; generate a chain on the server. Start with [[Dungeon and Room Generation]] and [[Seeds Determinism and Reproducible Worlds]].
2. **Threat director.** A server module that picks a creature, plays a warning, waits a fixed hide window, then sweeps. Use [[Horror Monster Chase AI End to End]] and [[Spawn Director - Credit Budgets and Player-Count Scaling]].
3. **Audio first.** Per-creature warning sounds with distance roll-off, in their own sound group so a volume slider never mutes the warning: [[Sound Design for Games]], [[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]], [[Audio Mixer Settings with SoundGroups]].
4. **Death screen that teaches.** A table keyed by cause of death, written as in-world documents: [[Lore Delivery Without Walls of Text]].
5. **Lighting per zone.** Swap fog, colour correction and light colour per depth band: [[Lighting Mood and Time of Day]], [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]].
6. **Two-currency economy.** Run currency resets; meta currency persists. Check the receipt path with the `lihfolk:roblox-datastore-safety` skill and [[Currency Architecture - Soft Hard and Event Currencies]].

## Numbers to remember

| Number | Label | Source and date |
|---|---|---|
| 112,111 peak CCU, 28 Mar 2026 | Measured | Rolimons, read 2026-10-29 |
| ~17 months from place creation to release | Measured (creation) + Unverified (release) | Roblox API / Pressure wiki, 2026-10-29 |
| Second revive 30 Robux | Unverified | Pressure wiki, 2026-10-29 |
| Hide window should exceed reaction plus travel to nearest hide spot | Rule of thumb | This note |

## Common mistakes when copying this style

- **Dark for its own sake** -> keep the player's flashlight and the counter (locker, vent) readable; darkness should hide the threat, not the answer.
- **Warning sounds on the music bus** -> put warnings on their own SoundGroup that the music slider cannot mute.
- **Random rooms with no guaranteed hide spot** -> validate every generated room for at least one reachable hide spot before the threat can spawn.
- **Selling the second revive at the moment of panic only** -> always offer a free path (ad, token earned in play) beside the paid one.
- **Copying the setting** -> the lesson is "one environment with a clear identity", not "underwater"; pick your own.

## Checklist

- [ ] Every threat has one audio tell and one counter, readable in the dark.
- [ ] Every generated room passes a hide-spot and route check on the server.
- [ ] Death screen explains the cause in-world.
- [ ] Warning audio is on a protected sound group.
- [ ] Run currency and meta currency are separate and saved safely.
- [ ] Content warning and maturity questionnaire done before launch.
- [ ] Revives have a free path next to any paid one.

## See also

[[High-Craft Teardowns Start Here]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]] · [[Teardown - Grace]] · [[Teardown - Dandy's World]] · [[Case Study - Doors]] · [[Genre Playbook - Horror and Story]] · [[Telegraphing]] · [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]]

<!-- related:start -->
## Related
[[Teardown - Piggy]] · [[Teardown - Evade]] · [[Teardown - Apocalypse Rising 2]] · [[Teardown - BedWars]] · [[Teardown - Deepwoken]] · [[Teardown - Anime Vanguards]] · [[Teardown - Phantom Forces]] · [[Teardown - Funky Friday]]
<!-- related:end -->
