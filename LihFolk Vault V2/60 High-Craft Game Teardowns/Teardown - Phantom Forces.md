---
tags: [teardown, high-craft, shooter, fps, gun-feel, netcode, hit-registration, custom-character, classic, type/case-study, area/design, level/advanced]
verified: 2026-10-29
---
# Teardown - Phantom Forces

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Default tools as guns -> build a viewmodel and camera system; feel is the product.
> - Avoid: Server-only hit detection -> laggy players miss shots they clearly hit; detect on client, validate on server.
> - Avoid: Client-only hit detection -> exploiters win; always validate distance, rate and line of sight.
> - First five shots feel crisp: sound, recoil, hit marker.
> - Weapon stats live in one data sheet.
> - Hits are client-detected and server-validated.
>
> Cost: TL;DR ~160 tok · whole note ~2.1k tok. Read more: ## Snapshot · ## The craft that sets it apart · ## Common mistakes when copying this style · ## Checklist
<!-- tldr:end -->

Phantom Forces is a team-based first-person military shooter with a deep weapon and attachment unlock tree, and one of the oldest proofs that a Roblox shooter can feel like a dedicated PC FPS.

Trust labels: **Roblox docs**, **Measured**, **Rule of thumb**, **Unverified**. Not played for this note.

## Snapshot

| Field | Value | Label and source |
|---|---|---|
| Creator | StyLiS Studios (group) | Measured, Roblox games API, 2026-10-29 |
| Place created | 31 August 2015 | Measured, Roblox games API |
| Playable / free release | paid-access play from September 2015; free full release 8 December 2016 | Unverified, Roblox fandom wiki |
| Visits | 1,807,023,089 | Measured, Roblox games API, 2026-10-29 |
| Favourites | 5,992,410 | Measured, Roblox games API, 2026-10-29 |
| Rating | 90.7% | Measured, Roblox votes API, 2026-10-29 |
| Playing at check | 1,380 | Measured, Roblox games API, 2026-10-29 |
| Tracker peak | 15,592 on 16 January 2021 | Measured, Rolimons, read 2026-10-29 (tracker history does not cover the 2016-2019 era, so the true peak is Unverified) |
| Average session | about 11.9 minutes | Measured, Rolimons |
| Server size | 32 | Measured, Roblox games API |
| Game passes | none returned by the public API | Measured, 2026-10-29 |

## Core loop

Join a 32-player match, play objective or deathmatch modes on a rotating map, earn XP and credits, unlock weapons and attachments by rank and kills with each gun, customise loadouts, queue again.

## First 60 seconds

- A full-screen menu with deploy, loadout and settings, before any 3D world. It feels like a PC shooter on purpose.
- Deploy drops you into a live match with a starter class. You learn by dying to veterans; the kill camera and death screen show who and with what.
- **Rule of thumb:** a shooter's first minute is about feel, not tutorial. If the first five shots feel crisp (sound, recoil, hit marker), players forgive the difficulty.

## The craft that sets it apart

**1. Custom engine work for feel.** Press credits a custom physics and combat engine for its success (Unverified, TV Tropes summary). Viewmodel arms, aim-down-sights transitions, weapon sway, sprint and slide states, and leaning give the game a feel that Roblox's default character and tools do not. See [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]].

**2. Gun feel as a system.** Every weapon has recoil patterns, spread, damage drop-off, headshot multipliers and handling stats, and attachments trade one stat for another. The unlock tree is also a tuning tree. See [[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]] and [[Time-to-Kill Math and a Weapon Balance Sheet]].

**3. Hit registration that forgives latency.** A 2019 patch note copied by the community says hit registration was made time invariant to stop shots being rejected because of latency (Unverified, community copy of patch 4.8.0). **Rule of thumb:** the standard fair approach is client-detected hits for instant feedback, then server validation with a latency-aware rewind window and sanity checks, never trusting the client blindly. See [[Client Prediction and Reconciliation for Combat]] and [[Hitboxes and Hit Detection]].

**4. Readable military art at Roblox scale.** Detailed weapon models in first person, simpler world geometry, strong silhouettes for team identification, and maps built around lanes and cover. See [[Combat Arena and Encounter Layout]] and [[Objective Mode Maps - Capture the Flag, King of the Hill and Control Points]].

**5. Sound with distance and direction.** Gun reports, reloads and footsteps are cues players use for position. See [[Combat Sound Design and Feedback]].

## Progression and economy

- **Rank unlocks guns; kills with a gun unlock its attachments.** Two parallel ladders give a goal every match.
- **Credits** buy early access to weapons and cosmetic skins (Unverified details).
- **Skill is the real progression.** A starter weapon remains viable, which keeps new players in.

## Monetization and 2026 rules

No passes returned by the public API (Measured). Monetization is through in-game currency purchases and cosmetic cases historically (Unverified). Any random cosmetic case bought with Robux, directly or through a currency bought with Robux, must show numeric odds before purchase: [[Paid Random Items and Odds Disclosure in Practice]] and [[Policy and Age Rules 2026]]. Do not sell weapons that beat free ones; sell time-savers and cosmetics.

## Retention

- **Deep unlock tree** gives a long horizon.
- **Limited modes** headline the title (an "Infection" mode at check time, Measured).
- **Weapon remodel updates** refresh the core content (an autumn remodel update headline appears on a tracker page, Unverified).

## Tech notes

- **Custom character and camera** need careful replication: third-person bodies for others, first-person arms for yourself. [[Weapon and Combat Animation]].
- **Bullets as raycasts with travel** or instant hitscan per weapon class: [[Projectiles and Ballistics]] and [[Raycasts Shapecasts and Spatial Queries]].
- **Server validation** for shot origin distance, fire rate and line of sight: [[Detecting Combat Exploits - Reach Rate and Aim]] and [[Weekend Build - Arena Shooter with Server-Checked Hits]].
- **32 players** is a moderate shooter size on Roblox; use unreliable remotes for cosmetic shot effects and reliable remotes for damage. See [[RemoteEvents RemoteFunctions and Unreliable Remotes]].
- **Console and mobile** require aim assist and generous input: [[Aim Assist and Generous Hitboxes]].

## Team and cadence

StyLiS Studios was founded in 2014 by two developers, with a third main member joining later and a small core team listed (Unverified, community wiki). A decade of updates.

## Build it yourself

1. **Viewmodel and ADS.** [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]] and [[Procedural Weapon Motion]].
2. **Weapon stat sheet** with recoil, spread, damage curves and attachment modifiers as data: [[Time-to-Kill Math and a Weapon Balance Sheet]] and [[Data and Config Pipeline - Spreadsheets to Game]].
3. **Client hit, server check** with a rewind window: [[Client Prediction and Reconciliation for Combat]].
4. **Kill feed and death recap:** [[Kill Credit, Assists, Kill Feed and Death Recaps]].
5. **Matchmaking or server browser:** [[Server Hop Rejoin and Server Lists with Ping]].
6. **Run `lihfolk:roblox-anti-exploit-review`** on the weapon remotes before launch; see [[Skill - Roblox Anti-Exploit Review]].

## Numbers to remember

| Number | Label | Source and date |
|---|---|---|
| 32-player servers | Measured | Roblox games API, 2026-10-29 |
| 90.7% rating | Measured | Roblox votes API, 2026-10-29 |
| Free release 8 Dec 2016 | Unverified | Roblox fandom wiki |
| Validate with a latency-aware rewind window | Rule of thumb | This note |

## Common mistakes when copying this style

- **Default tools as guns** -> build a viewmodel and camera system; feel is the product.
- **Server-only hit detection** -> laggy players miss shots they clearly hit; detect on client, validate on server.
- **Client-only hit detection** -> exploiters win; always validate distance, rate and line of sight.
- **Attachments that only add stats** -> each one should trade something.
- **Paid weapons stronger than free ones** -> sell skins and early access, not power.

## Checklist

- [ ] First five shots feel crisp: sound, recoil, hit marker.
- [ ] Weapon stats live in one data sheet.
- [ ] Hits are client-detected and server-validated.
- [ ] Fire rate and shot origin are checked on the server.
- [ ] Starter weapons stay viable.
- [ ] Any random cosmetic case shows numeric odds.

## See also

[[High-Craft Teardowns Start Here]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]] · [[Teardown - Arsenal]] · [[Case Study - Rivals]] · [[Genre Playbook - Shooters FPS and TPS]] · [[Gamepad and Console UX]]

<!-- related:start -->
## Related
[[Teardown - Apocalypse Rising 2]] · [[Teardown - BedWars]] · [[Teardown - Grace]] · [[Teardown - Blade Ball]] · [[Teardown - Anime Vanguards]] · [[Teardown - Jujutsu Shenanigans]] · [[Teardown - Funky Friday]] · [[Teardown - Deepwoken]]
<!-- related:end -->
