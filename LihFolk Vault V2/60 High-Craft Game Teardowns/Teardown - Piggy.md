---
tags: [teardown, high-craft, horror, asymmetric, chapters, story, build-mode, ugc-maps, classic, type/case-study, area/design, level/beginner]
verified: 2026-10-29
---
# Teardown - Piggy

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Big servers for an asymmetric horror game -> keep groups small so one hunter can matter.
> - Avoid: Story only in the description -> put a short cutscene at each chapter start and end.
> - Avoid: No bot hunter -> quiet servers never start a round; add one.
> - Each map is an item-lock graph defined as data.
> - One-slot (or tiny) inventory creates co-op routing.
> - Bot fills the hunter role when needed.
>
> Cost: TL;DR ~140 tok · whole note ~2.1k tok. Read more: ## Snapshot · ## The craft that sets it apart · ## Common mistakes when copying this style · ## Checklist
<!-- tldr:end -->

Piggy is a small-server asymmetric horror game: one player (or a bot) is the hunter, the others solve a map's item puzzle to escape, and the whole thing is wrapped in a chaptered story that turned a 2020 hit into a long-running franchise.

Trust labels: **Roblox docs**, **Measured**, **Rule of thumb**, **Unverified**. Not played for this note.

## Snapshot

| Field | Value | Label and source |
|---|---|---|
| Creator | Piggy Dev Team (group); created by MiniToon | Measured (group), Unverified (creator, press and wikis) |
| Place created | 23 January 2020 | Measured, Roblox games API |
| Visits | 14,439,145,026 | Measured, Roblox games API, 2026-10-29 |
| Favourites | 12,287,208 | Measured, Roblox games API, 2026-10-29 |
| Rating | 90.3% | Measured, Roblox votes API, 2026-10-29 |
| Playing at check | 4,495 | Measured, Roblox games API, 2026-10-29 |
| All-time peak CCU | 533,409 on 24 May 2020 | Measured, Rolimons, read 2026-10-29 |
| 30-day peak | 83,295 | Measured, Rolimons, read 2026-10-29 (Halloween event) |
| Server size | 6 | Measured, Roblox games API |
| Story structure | Book 1 (12 chapters, finished May 2020), Book 2 from September 2020 | Unverified, Piggy wiki and speedrun.com |
| Player-made maps | Build Mode, credited to a collaborator | Unverified, community sources |

The May 2020 peak sits on the Book 1 finale date reported by wikis, which shows the chapter model working: each chapter release was an event.

## Core loop

1. Vote on a map and mode (player hunter, bot hunter, or variants).
2. Survivors search for keys and tools, carry one item at a time, and use them on locks in the right order to open the escape route.
3. The hunter patrols, and a hit removes a survivor or turns them, depending on mode.
4. Escape or die, earn tokens, repeat on the next map.

## First 60 seconds

- Six-player servers mean you always see every other player; the social read is instant.
- The first map teaches "one item at a time" by the inventory itself: picking up a second item swaps it for the first (Unverified, community guides). **Rule of thumb:** the constraint creates the teamwork, because survivors must split carrying duties.
- The hunter's jump scare and chase music are short and loud, then the run continues. Death is quick and round length is short (average session about 11.2 minutes, Measured, Rolimons).

## The craft that sets it apart

**1. One-slot inventory as the puzzle engine.** Every map is a set of item-lock pairs with a fixed solve order and randomised item spawns. One slot forces routing decisions ("you carry the wrench, I get the key") and keeps the UI tiny for mobile players.

**2. Asymmetric roles with a bot fallback.** A player hunter is the fun mode; a bot hunter guarantees a match in a quiet server. **Rule of thumb:** asymmetric games need a bot that can fill the rarest role, or queues stall.

**3. Story in chapter drops.** Each map was a chapter with a short cutscene and a cliffhanger, released on a steady schedule in 2020. Chapters turned map releases into appointments and gave YouTubers a reason to make a new video every week.

**4. A tiny, readable character language.** Blocky, high-contrast characters with one coloured feature each (infected eyes, a coloured outfit) read at icon size and at distance in a dark map.

**5. Build Mode.** Players can build and share their own maps (Unverified credit). The community produces content faster than any team, and the best map makers become future collaborators.

## Progression and economy

- **Tokens** earned per round buy skins, traps and cosmetics.
- **Skins as story trophies.** Many skins are characters from chapters, so cosmetics double as a collection of the story's cast.
- Progression does not make survivors stronger, which keeps rounds fair.

## Monetization and 2026 rules

Public passes (Measured, 2026-10-29): x2 Piggy Tokens 300, x2 Piggy Chance 150 (higher chance to be the hunter), Build Map Slots 100 each.

- **"Chance to be the hunter"** is a role-selection boost. It is not a paid random item in the item sense, but it is still a probability sold for Robux: state the effect plainly ("double your weight in the hunter draw"), and keep a free path to the role. See [[Paid Random Items]] and [[Paid Random Items and Odds Disclosure in Practice]] for when disclosure rules apply.
- **Build slots** monetise creators, not winners.
- **Merchandise and books** exist off-platform (Unverified). Off-platform promotion to children has its own rules: [[Marketing to Kids and Teens - Age Rules and Paid-Promo Disclosure]].

## Retention

- **Chapters, then books.** Two books of chapters plus bonus chapters (Unverified) built years of appointment content.
- **Seasonal events.** The October 2026 title carried a Halloween carnival event, and the 30-day peak of 83,295 (Measured) shows events still pull returning players six years on.
- **Player maps** keep the map pool fresh between official drops.

## Tech notes

- **Six-player servers** make bandwidth and NPC cost trivial; the budget goes to map detail and lighting.
- **Item pickups on the server.** Pickups, drops and lock use are server-validated so items cannot be duplicated or teleported. See [[Server Authority and Validation]] and [[Economy Exploits - Dupes Races and Purchase Abuse]].
- **Bot hunter.** Pathfinding with patrol points, a sight cone and a short memory of last-seen position: [[Pathfinding]], [[Pathfinding Edge Cases and Fallbacks]] and [[Horror Monster Chase AI End to End]].
- **Player-built maps** need validation (part limits, no scripts, reachable exits) and moderation of text and decals: [[Grid Placement and Player Building Systems]] and [[Roblox Policies Ratings and Compliance]].

## Team and cadence

Started by a solo creator, then grew into a team with collaborators (Unverified). Weekly chapters in 2020, then slower books, events and spin-offs.

## Build it yourself

1. **Item-lock map graph.** Define items, locks and a solve order as data; randomise spawn points per round. [[Genre Playbook - Puzzle and Escape Rooms]].
2. **One-slot inventory.** Pickup swaps with drop; server owns item state. [[Saved Inventory End to End]] covers persistence if you need it later.
3. **Role draw with weights.** Server picks the hunter by weighted draw; a pass may raise weight, disclosed in plain words. [[Probability and Statistics for Designers]].
4. **Bot hunter.** [[Horror Monster Chase AI End to End]].
5. **Chapter cutscenes.** Short, skippable, story-flagged: [[Cameras and Cutscenes]] and [[Story State Flags and Chapter Saves]].
6. **Map voting.** [[Map Voting and Rotation for Round Games]].

## Numbers to remember

| Number | Label | Source and date |
|---|---|---|
| 14.4 billion visits | Measured | Roblox games API, 2026-10-29 |
| 533,409 peak CCU, 24 May 2020 | Measured | Rolimons, read 2026-10-29 |
| 6-player servers | Measured | Roblox games API |
| Asymmetric games need a bot for the rarest role | Rule of thumb | This note |

## Common mistakes when copying this style

- **Big servers for an asymmetric horror game** -> keep groups small so one hunter can matter.
- **Story only in the description** -> put a short cutscene at each chapter start and end.
- **No bot hunter** -> quiet servers never start a round; add one.
- **Player maps without validation** -> enforce part caps, exits and text filtering.
- **Copying the characters or the parody start** -> build an original cast; the chapter structure is the lesson.

## Checklist

- [ ] Each map is an item-lock graph defined as data.
- [ ] One-slot (or tiny) inventory creates co-op routing.
- [ ] Bot fills the hunter role when needed.
- [ ] Role-weight passes disclose their effect in plain words.
- [ ] Chapters ship on a predictable schedule.
- [ ] Player-built content is validated and moderated.

## See also

[[High-Craft Teardowns Start Here]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]] · [[Teardown - Dandy's World]] · [[Case Study - Forsaken]] · [[Case Study - Murder Mystery 2]] · [[Genre Playbook - Social Deduction and Murder Mystery]] · [[Update Cadence and Hype Cycles]]

<!-- related:start -->
## Related
[[Teardown - Anime Vanguards]] · [[Teardown - Grace]] · [[Teardown - Pressure]] · [[Teardown - Apocalypse Rising 2]] · [[Teardown - Evade]] · [[Teardown - Arsenal]] · [[Teardown - Phantom Forces]] · [[Teardown - BedWars]]
<!-- related:end -->
