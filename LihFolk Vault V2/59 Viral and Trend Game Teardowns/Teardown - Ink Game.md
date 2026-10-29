---
tags: [teardown, viral-trend, event-driven, party, elimination, rounds, minigames, social, type/case-study, area/design, level/intermediate, area/liveops]
verified: 2026-10-29
---

# Teardown - Ink Game

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Client decides who is eliminated -> server checks with tolerance
> - Avoid: Heavy maps in 100-player servers -> simple arenas, streaming
> - Avoid: Copying a show's logos or characters -> original visual identity
> - Can a new player understand the first challenge from one sentence on screen?
> - Are eliminations decided on the server with latency tolerance?
> - Does the server hold frame rate with 100 players on mobile?
>
> Cost: TL;DR ~150 tok · whole note ~2.6k tok. Read more: ## Snapshot · ## Monetization and 2026 compliance · ## Common mistakes · ## Checklist
<!-- tldr:end -->

> **In one line:** a 100-player elimination show of deadly playground challenges, where every knockout grows the prize pot, and the survivors choose how the show ends.

Ink Game is the most successful Roblox experience built on the "survival game show" format popularised by a streaming drama series. It is event-driven by design: interest rose and fell with the show's release calendar and with the game's own themed events. It is also the clearest example in this section of a **round-based party game** reaching viral scale.

Labels: **Measured**, **Roblox docs**, **Rule of thumb**, **Unverified** ([[Viral and Trend Teardowns Start Here]]).

## Snapshot

| Fact | Value | Label | Source and date |
|---|---|---|---|
| Created | 2024-12-31 | Measured | Roblox game API, 2026-10-29 |
| Owner group | "games i think" (store page says made by developers from another studio team) | Measured | Roblox game API, 2026-10-29 |
| Genre on Roblox | Party & Casual | Measured | Roblox game API, 2026-10-29 |
| Server size | 100 players | Measured | Roblox game API, 2026-10-29 |
| Playing now | 9,435 (08:06 UTC Thursday) | Measured | Roblox game API, 2026-10-29 |
| Visits | 3,369,526,005 | Measured | Roblox game API, 2026-10-29 |
| Favourites | 22,533,148, the highest favourite count of any game in this section | Measured | Roblox game API, 2026-10-29 |
| Votes | 1,257,414 up / 329,912 down, about 79.2% positive | Measured (computed) | Roblox votes API, 2026-10-29 |
| All-time peak CCU | 810,470 on 2025-08-31 | Measured (tracker) | Rolimons; EverybodyWiki list of Roblox games by peak, seen 2026-10-29 |
| Events | "Sky" themed event 2025-08-09 to 08-16; playable guards update September 2025 | Unverified | Insider Gaming; Deltia's Gaming; AllThingsHow, 2025 |
| Endings | three (rebel, final fight, a sky-themed variant) per the store page | Measured | Roblox game API description, 2026-10-29 |
| Public game passes | Permanent Guard 799; VIP 649; Glass Manufacturer Vision 649; Private Server+ 499; 2x Vote Count 249; Custom Player Tag 199; Emote Pages 199 (Robux) | Measured | Roblox game-pass API, 2026-10-29 |

The favourites-to-visits ratio (about 1 favourite per 150 visits) is far higher than for the simulators here (about 1 per 1,100 for Steal An Egg), which fits a game people bookmark to return to on event days (Measured, computed from the API snapshot).

## Core loop

```text
 lobby (100) ──► challenge 1 ──► eliminations add to the prize pot
                     │
                     ▼
               challenge 2..n  (survivors get fewer, the pot gets bigger)
                     │
                     ▼
        survivors vote: final fight / rebel / special ending
                     │
                     ▼
     winner(s) paid in game currency ──► cosmetics, emotes, power-ups ──► next lobby
```

## First 60 seconds

1. You load into a big lobby with up to 99 others. The scale itself is the first impression.
2. The first challenge starts quickly and is readable from one rule (move only when allowed, stay on the safe path, and so on).
3. Elimination is immediate and theatrical; you either survive or spectate.
4. The pot counter grows with every knockout, so you understand the stakes without a tutorial.

Recognition does the onboarding: the format is famous, so players already know the rules of most challenges.

## Progression and economy

- **Per-round reward:** a share of the prize pot for winners.
- **Unlocks:** abilities such as a dash "if unlocked" (store page keybind note), emotes, tags.
- **Role variety:** a guards update let players play the other side of the show (Unverified date, September 2025).
- **No rarity ladder** at the core. The long-term goal is mastery, wins and cosmetics.

## Monetization and 2026 compliance

The passes are a clean mix of **status** (VIP, tag, emotes), **role access** (permanent guard), **voice in group decisions** (2x vote count), **private play** (Private Server+) and one **information advantage** (a pass named for seeing the glass in a glass-bridge style challenge).

- No paid random items are visible, so odds rules do not apply to the visible store.
- The **vote multiplier** and **information pass** sell influence over shared outcomes. They are allowed, but a builder chasing high approval might prefer cosmetic-only versions or keep such passes out of competitive rounds ([[Ethical Design and Player Trust]]).
- **Private servers** are a good fit for a party game: friends play together, and reserved or private server joins count as intentional co-play in RFY (Roblox docs, 2026-06-15). See [[Private Servers]].
- **Theme IP:** the format borrows a famous show's challenges. Game mechanics are generally not protected, but names, character designs and logos are; keep visual identity original (Rule of thumb; not legal advice; see the research module, section 8.4).
- **Maturity:** elimination games with "deadly" framing must answer the Maturity questionnaire honestly; violence level decides Kids and Select reach (Roblox docs; [[Roblox Policies Ratings and Compliance]]).

## Retention hooks

- **Event weeks** tied to themed variants.
- **Multiple endings** that the lobby votes on create "this time let us try the rebel ending" sessions.
- **Role swaps** (guards) double the content without new maps.
- **Frequent updates:** update stamp two days before the snapshot (Roblox game API, 2026-10-27).

## Multiplayer and social design

The 100-player lobby is the product. Shared tension, mass eliminations and a group vote at the end create stories that no small server can. The guard role adds asymmetric play. The store warns firmly about cheating, which matters in a game where one exploiter can ruin a 100-player round.

## Art, UI, title and thumbnail

- **Title:** two plain words that evoke the show without naming it, plus a crossed-swords tag in the snapshot.
- **Description:** a "NEW" headline for the latest feature, then the pitch, then the endings list, then device support and keybinds.
- **Visual language:** saturated playground colours against a stark arena, the contrast the format is known for.

## Technical notes

- **100-player servers are expensive.** Keep challenge maps simple, avoid per-player physics props, use unreliable remotes for cosmetic state and cap effects ([[RemoteEvents RemoteFunctions and Unreliable Remotes]], [[Physics Performance]]).
- **Eliminations on the server.** Detection of "moved during red light" or "fell from the bridge" must be server-decided with generous tolerance for latency.
- **Spectating** keeps eliminated players in the session; build a good spectator camera ([[Arena Rounds with Teams and Spectating End to End]]).

## Why it went viral

1. **Borrowed recognition.** The format was globally famous, so the pitch needed no explanation.
2. **Event timing.** The all-time peak came at the end of August 2025, during a stretch of themed events and a summer of renewed interest in the show (Unverified link; trackers give the peak date only).
3. **Scale as spectacle.** 100 players at once looks big in a thumbnail and in a video.
4. **Group decisions.** Voting on the ending gives every survivor agency.

## Build it yourself

| System | Notes | Vault notes |
|---|---|---|
| Round state machine for 100 players | Lobby, intermission, challenge, results | [[Round-Based Minigame Loop End to End]] |
| Challenge rotation | Weighted or voted | [[Map Voting and Rotation for Round Games]] |
| Server-decided eliminations | Latency-tolerant checks | [[Server Authority and Validation]] |
| Prize pot and payout | Server-owned currency | [[Currency Architecture - Soft Hard and Event Currencies]] |
| Spectator mode | Camera cycling, UI | [[Arena Rounds with Teams and Spectating End to End]] |
| Roles (guards) | Team assignment, role-only tools | [[Spawning Teams and Rounds]] |
| Private servers | Settings for owners | [[Reserved and Private Servers in Practice]] |

## Raise the quality bar

- **Original challenges.** The best long-term versions invent their own playground games, which also builds a distinct brand.
- **Fair-play passes.** Prefer cosmetic VIP and emotes over in-round information or vote weight to protect competitive trust.
- **Strong spectating.** Eliminated players who enjoy watching stay to the next round.
- **Accessibility:** colour-safe signals for "move / stop" challenges ([[Colourblind Palettes Text Size and Tooltips]]).

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Client decides who is eliminated | exploiters survive every challenge | server checks with tolerance |
| Heavy maps in 100-player servers | long loads, phone crashes | simple arenas, streaming |
| Copying a show's logos or characters | takedown risk | original visual identity |
| Paid advantages inside rounds | low approval | cosmetic-first passes |
| No spectator experience | players leave after elimination | spectator camera and next-round countdown |

## Checklist

- [ ] Can a new player understand the first challenge from one sentence on screen?
- [ ] Are eliminations decided on the server with latency tolerance?
- [ ] Does the server hold frame rate with 100 players on mobile?
- [ ] Is the visual identity original, with no borrowed logos or characters?
- [ ] Are paid items cosmetic or clearly fair in competitive rounds?
- [ ] Is the Maturity questionnaire answered for the most intense challenge?

## See also

- [[Viral Game Anatomy - Hooks, Loops and Timing]]
- [[Teardown - Natural Disaster Survival]] (the round-based classic)
- [[Genre Playbook - Party and Minigame Collections]]
- [[Case Study - Dress to Impress]] (another round game with a group vote)

## Sources

- Roblox public game, votes and game-pass APIs, read 2026-10-29 08:06 UTC.
- Rolimons game page for place 99567941238278 and EverybodyWiki peak list, seen via search 2026-10-29.
- Insider Gaming, Deltia's Gaming and AllThingsHow guides on events and endings, 2025 (Unverified details).

<!-- related:start -->
## Related
[[Teardown - Tower of Hell]] · [[Teardown - Plants vs Brainrots]] · [[Teardown - Fling Things and People]] · [[Teardown - Ride A Pet]] · [[Teardown - +1 Speed Keyboard Escape]] · [[Teardown - Escape Tsunami for Brainrots]] · [[Teardown - Fish It]] · [[Teardown - Build A Boat For Treasure]]
<!-- related:end -->
