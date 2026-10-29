---
tags: [teardown, high-craft, rhythm, music, pvp, timing, audio-sync, cosmetics, type/case-study, area/design, area/audio, level/intermediate]
verified: 2026-10-29
---
# Teardown - Funky Friday

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Notes timed by frame deltas -> they drift; always read the song position.
> - Avoid: No offset setting -> Bluetooth and phone players miss everything; add calibration.
> - Avoid: Server judging every note -> latency ruins timing; judge on the client, validate results.
> - Note scheduler reads the song's playback position.
> - Audio preloaded before the countdown.
> - Offset calibration available in settings.
>
> Cost: TL;DR ~140 tok · whole note ~2.0k tok. Read more: ## Snapshot · ## The craft that sets it apart · ## Common mistakes when copying this style · ## Checklist
<!-- tldr:end -->

Funky Friday is a rhythm battle game: two players step onto a stage, pick a song, and hit falling arrow notes in time with the music; the higher score (or fewer misses, or better accuracy, depending on the chosen rule) wins.

Trust labels: **Roblox docs**, **Measured**, **Rule of thumb**, **Unverified**. Not played for this note.

## Snapshot

| Field | Value | Label and source |
|---|---|---|
| Creator | Lyte Interactive (group) | Measured, Roblox games API, 2026-10-29 |
| Place created | 26 February 2021 | Measured, Roblox games API |
| Visits | 2,025,908,683 | Measured, Roblox games API, 2026-10-29 |
| Favourites | 4,127,244 | Measured, Roblox games API, 2026-10-29 |
| Rating | 90.2% | Measured, Roblox votes API, 2026-10-29 |
| Playing at check | 1,126 | Measured, Roblox games API, 2026-10-29 |
| All-time peak CCU | 125,314 on 24 July 2021 | Measured, Rolimons, read 2026-10-29 |
| Average session | about 15.3 minutes | Measured, Rolimons |
| Server size | 20 | Measured, Roblox games API |
| Genre labels | Action, Music & Rhythm | Measured, Roblox games API |
| Inspiration | the indie rhythm game Friday Night Funkin', with songs from it and from community mods | Unverified, Roblox fandom wiki |
| Win rules | highest score, least misses or highest accuracy; solo play gives no score or wins | Unverified, Roblox fandom wiki |

## Core loop

Walk onto a free stage, wait for an opponent (or play solo), pick a song and difficulty, play, see the result, earn points, spend them on animations and emotes.

## First 60 seconds

- Stages are physical spaces in a hub: you join a match by walking onto one. The social space is the matchmaking.
- The first song on easy difficulty teaches the four lanes and timing grades at once.
- **Rule of thumb:** a rhythm game is learned in its first song if timing feedback (Perfect, Good, Miss) appears instantly at the note and a sound confirms each hit.

## The craft that sets it apart

**1. Audio-visual sync is the whole game.** Notes must arrive at the hit line exactly when the music says so, on every device. That means the chart is scheduled against the song's playback position, not against frame time. A drift of a few tens of milliseconds is felt by players (Rule of thumb).

**2. Latency calibration.** Audio output latency differs between phones, PCs and Bluetooth headsets. Rhythm games offer an offset setting so each player can shift the judgement window to match their device. **Rule of thumb:** ship an offset setting and a simple "tap to the beat" calibration screen.

**3. Fair judgement windows.** Timing grades should be generous enough for mobile touch and strict enough to separate skill. Show accuracy per song so players can see their improvement.

**4. Head-to-head without netcode pain.** Each player's notes are judged locally against the same chart and song; only scores and combo events need to be sent. Rhythm PvP is one of the friendliest genres for latency because neither player's input affects the other's notes.

**5. Expression through animation.** Character animations dance to the song and react to hits and misses; animation customisation is sold (Measured pass list). The stage is a show for the hub.

## Progression and economy

- **Points per song** buy animations and emotes, all cosmetic (Unverified, wiki).
- **Skill ladder** through difficulty levels and harder songs.
- **Win streaks** in PvP (solo play does not count, Unverified).

## Monetization and 2026 rules

Public passes (Measured, 2026-10-29): Animation Customization 399, 2x Points 349.

- **Cosmetic and time-saver only.** The skill contest stays pure.
- **Music rights.** Songs from other games and mods need permission; Roblox's audio rules for 2026 also limit what can be uploaded and shared. Read [[Music Licensing and Audio Upload Rules for 2026]] and [[Legal Basics - IP Licenses and Assets]]. Mod removals and returns are reported by press (Unverified), which shows song libraries depend on creator permissions.

## Retention

- **New songs** are the content cadence.
- **Social stages** in a hub give an audience.
- **Mastery** of hard charts.

## Tech notes

- **Schedule notes from the song clock.** Read `Sound.TimePosition` each frame (and smooth it), and place notes by their beat time minus current song time. Do not accumulate frame deltas. See [[Sound Fundamentals]] and [[Frame Order and RunService Timing]].
- **Preload audio** before the countdown with `ContentProvider:PreloadAsync` so the first beat is not late on slow connections.
- **Judge locally, report results.** The client judges each note; the server receives score summaries and sanity-checks them (maximum possible score for that chart, plausible accuracy). See [[Server Authority and Validation]] and [[Rate Limiting and Abuse Prevention]].
- **Chart data as compact tables** (time, lane, length) loaded per song: [[Data and Config Pipeline - Spreadsheets to Game]].
- **UI performance.** Hundreds of notes per song: pool note frames instead of creating and destroying them. See [[UI and GUI Animation]] and [[Juice on a Budget - Mobile and Low-End]].

## Team and cadence

Lyte Interactive (team details Unverified). Song additions and cosmetic updates.

## Build it yourself

1. **Song clock and note scheduler** driven by `Sound.TimePosition`.
2. **Judgement windows** (for example Perfect, Good, Miss) defined as data and tuned on phones first.
3. **Offset calibration** in settings: [[Settings Menu Essentials and Persistence]].
4. **Stage matchmaking** in a hub: [[Lobby and Hub Design]].
5. **Score validation** on the server against the chart's maximum.
6. **Hit feedback** with sound and a small pop: [[Feedback Timing - Sound Visual and Haptic Sync]] and [[Squash Stretch and Anticipation in UI and Characters]].
7. **Licensed or original music only:** [[Music Licensing and Audio Upload Rules for 2026]] and [[AI Audio - Voice Music and SFX]] for original tracks.

## Numbers to remember

| Number | Label | Source and date |
|---|---|---|
| 125,314 peak CCU, 24 Jul 2021 | Measured | Rolimons, read 2026-10-29 |
| 4,127,244 favourites | Measured | Roblox games API, 2026-10-29 |
| 2 passes: 399 and 349 Robux | Measured | Roblox game-passes API, 2026-10-29 |
| Schedule from song time, never accumulated frame time | Rule of thumb | This note |

## Common mistakes when copying this style

- **Notes timed by frame deltas** -> they drift; always read the song position.
- **No offset setting** -> Bluetooth and phone players miss everything; add calibration.
- **Server judging every note** -> latency ruins timing; judge on the client, validate results.
- **Using songs without permission** -> use original or licensed music.
- **Creating a GUI object per note** -> pool frames.

## Checklist

- [ ] Note scheduler reads the song's playback position.
- [ ] Audio preloaded before the countdown.
- [ ] Offset calibration available in settings.
- [ ] Judgement windows tested on phones.
- [ ] Scores validated against chart maximums on the server.
- [ ] Every song is original or licensed.

## See also

[[High-Craft Teardowns Start Here]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]] · [[Teardown - Blade Ball]] · [[Music and Adaptive Audio]] · [[Genre Playbook - Party and Minigame Collections]] · [[Captions and Audio Accessibility]]

<!-- related:start -->
## Related
[[Teardown - Grace]] · [[Teardown - Jujutsu Shenanigans]] · [[Teardown - Phantom Forces]] · [[Teardown - Evade]] · [[Teardown - BedWars]] · [[Teardown - Anime Vanguards]] · [[Teardown - Apocalypse Rising 2]] · [[Teardown - Driving Empire]]
<!-- related:end -->
