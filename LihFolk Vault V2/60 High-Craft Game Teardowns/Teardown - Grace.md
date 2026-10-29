---
tags: [teardown, high-craft, horror, speedrun, movement, pacing, solo-dev, type/case-study, area/design, level/intermediate]
verified: 2026-10-29
---
# Teardown - Grace

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Every entity uses the same counter -> give each a different verb so overlaps create choices.
> - Avoid: Colour-only warnings -> add a shape, a sound and a screen position per threat.
> - Avoid: One-frame checks for "don't look" -> use a cone and a short time window, or lag kills players unfairly.
> - Each threat has one tell and one verb, and the verbs differ.
> - At least one pair of threats interacts in a learnable way.
> - Verb checks run on the server with latency tolerance.
>
> Cost: TL;DR ~160 tok · whole note ~2.1k tok. Read more: ## Snapshot · ## The craft that sets it apart · ## Common mistakes when copying this style · ## Checklist
<!-- tldr:end -->

Grace is a fast first-person horror run against a clock: you sprint, slide and crouch through rooms while a cast of entities each demand one specific reaction, and standing still is rarely safe.

Trust labels: **Roblox docs**, **Measured** (our read of a public API or tracker on the date shown), **Rule of thumb** (our design reading), **Unverified** (press, wiki or community). Not played for this note.

## Snapshot

| Field | Value | Label and source |
|---|---|---|
| Creator | The Fartering Few (group) | Measured, Roblox games API, 2026-10-29 |
| Place created | 3 September 2024 | Measured, Roblox games API |
| Last update | 9 July 2026 | Measured, Roblox games API, 2026-10-29 |
| Visits | 461,390,376 | Measured, Roblox games API, 2026-10-29 |
| Favourites | 1,064,600 | Measured, Roblox games API, 2026-10-29 |
| Rating | 93.0% (504,155 up / 37,778 down) | Measured, Roblox votes API, 2026-10-29 |
| All-time peak CCU | 46,672 on 1 April 2026 | Measured, Rolimons, read 2026-10-29 |
| Average session | about 8.1 minutes | Measured, Rolimons, read 2026-10-29 |
| Server size | 50 | Measured, Roblox games API |
| Game passes | none returned by the public API | Measured, Roblox game-passes API, 2026-10-29 |
| Team | mostly one developer | Unverified, Roblox fandom wiki, read 2026-10-29 |

The 93% rating is the headline: very high for a hard horror game, and earned with almost no monetization surface.

## Core loop

Enter a room, read the threat, react correctly, keep moving, beat the timer. If the timer runs out, a final punishing entity arrives (Unverified, guides). Runs are short (an 8-minute average session, Measured), so a death costs little and "one more go" is natural.

## First 60 seconds

- You are moving almost immediately. There is no long walk to a first scare; the first entity (signalled by coloured flames at the screen edges, per guides, Unverified) forces you to run forward until you find a hiding spot, which may be a few rooms away.
- **Rule of thumb:** the opening teaches the game's real rule, "speed is safety", in the first encounter. Hiding exists, but you have to earn it by moving.

## The craft that sets it apart

**1. One verb per entity, and the verbs differ.** Community guides list a roster where each threat asks for a different input (Unverified, ProGameGuides and Sportskeeda guides): get under cover or a doorframe; stop and crouch; look away; stare at it; walk away and wait; step out of its path; crouch or slide. Each rule is a single sentence a player can shout to a friend. Because the verbs differ (look, don't look, move, freeze, duck), two entities overlapping creates a real decision without any new mechanic.

**2. Entities that change each other.** Guides report that one freeze-type entity slows the main chaser dramatically while it is active (Unverified). Interactions like this give depth from a small cast: the designer adds a relationship, not an enemy.

**3. Movement that feels expensive to master.** Sliding and crouch-sliding are survival tools, not decoration. A skilled run looks visibly different from a new player's, which makes the game watchable and gives it a speedrun community (a Speedrun.com board exists, Unverified).

**4. Pacing by clock, not by script.** A visible timer moves the tension from "what is behind the door" to "can I afford to wait here". **Rule of thumb:** a timer turns hiding into a cost, so hide spots can be generous without making the game easy.

**5. Clean visual language.** Each threat has its own colour, shape and screen-edge cue. Readability is the craft; the horror comes from speed and overlap, not from obscurity.

## Progression and economy

Light. There is no game pass store in the public API (Measured). Progression is mastery, modes and modifiers (modifier-only entities are mentioned in guides, Unverified). This keeps the rating high and the barrier to entry at zero.

## Monetization and 2026 rules

With no passes listed, Grace is a reminder that a high-rating free game can be a calling card for a developer: reputation, group growth and future projects. If you add monetization to a game like this, keep it cosmetic (slide trails, death effects) and never sell the counter to an entity. Read [[Monetization Overview]] and [[Game Passes]]; check age and chat rules in [[Policy and Age Rules 2026]].

## Retention

- **Skill retention.** Players return to beat their time or survive a harder modifier.
- **Clips.** Fast deaths with a clear cause make short videos; see [[Short-Form Video Marketing]].
- **Cadence.** Updates are irregular (last update 9 July 2026, Measured). Small-team games survive gaps when the base loop is replayable.

## Tech notes

- **Input checks per entity.** Each rule is a server-checkable state: crouching, moving, camera facing, under cover. The client reports camera look direction often, but the server should sample it and allow a short grace window for latency. See [[Server Authority and Validation]] and [[False Positives Lag and Fair Enforcement]].
- **Look-at rules need a forgiving cone.** For "don't look" and "stare" entities, use a dot-product cone with tolerance, and judge it over a short window rather than one frame. See [[Math Vectors and CFrames]] and [[Look-At Aim and Head Tracking]].
- **Slide physics.** A slide is a timed velocity boost plus a lowered hitbox; tune it so a slide under a low obstacle always clears. See [[Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run]].

## Team and cadence

Mostly a solo developer (Unverified). The game shows what one person can reach by choosing a scope where every asset carries gameplay weight.

## Build it yourself

1. **Entity rule table.** One row per entity: tell (colour, sound, screen cue), required verb, check function, punishment. Use [[Telegraphing]] and [[Horror Monster Chase AI End to End]].
2. **Verb checks on the server.** Crouch, stand still, facing, under cover. Sample over 0.2-0.4 s windows (Rule of thumb) to forgive jitter. See [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]].
3. **Run timer and closer.** A visible countdown that spawns a final threat on expiry. Use [[Round-Based Minigame Loop End to End]] for the timer state machine.
4. **Slide and crouch movement.** Build from [[Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run]] and [[Input Responsiveness Buffering and Coyote Time]].
5. **Screen-edge cues** that are colour and shape coded (not colour only): [[Colour-Blind Safe Design]].

## Numbers to remember

| Number | Label | Source and date |
|---|---|---|
| 93.0% rating | Measured | Roblox votes API, 2026-10-29 |
| 46,672 peak CCU, 1 Apr 2026 | Measured | Rolimons, read 2026-10-29 |
| 8.1-minute average session | Measured | Rolimons, read 2026-10-29 |
| Judge look and stillness over 0.2-0.4 s, not one frame | Rule of thumb | This note |

## Common mistakes when copying this style

- **Every entity uses the same counter** -> give each a different verb so overlaps create choices.
- **Colour-only warnings** -> add a shape, a sound and a screen position per threat.
- **One-frame checks for "don't look"** -> use a cone and a short time window, or lag kills players unfairly.
- **Timer without generous hide spots** -> the timer is the pressure; hide spots can be plentiful.
- **Copying entity names or designs** -> copy the rule table structure, invent your own cast.

## Checklist

- [ ] Each threat has one tell and one verb, and the verbs differ.
- [ ] At least one pair of threats interacts in a learnable way.
- [ ] Verb checks run on the server with latency tolerance.
- [ ] A visible clock sets the pace.
- [ ] Warnings use colour plus shape plus sound.
- [ ] A new player understands the first threat within one minute.

## See also

[[High-Craft Teardowns Start Here]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]] · [[Teardown - Pressure]] · [[Teardown - Evade]] · [[Case Study - Doors]] · [[Genre Playbook - Horror and Story]] · [[Motion Sensitivity and Camera Comfort]]

<!-- related:start -->
## Related
[[Teardown - Piggy]] · [[Teardown - Dandy's World]] · [[Teardown - Phantom Forces]] · [[Teardown - Anime Vanguards]] · [[Teardown - Funky Friday]] · [[Teardown - Apocalypse Rising 2]] · [[Teardown - Deepwoken]] · [[Teardown - Blade Ball]]
<!-- related:end -->
