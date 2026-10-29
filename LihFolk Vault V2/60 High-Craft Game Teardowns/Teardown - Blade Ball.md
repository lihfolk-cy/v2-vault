---
tags: [teardown, high-craft, pvp, skill, parry, timing, abilities, short-rounds, type/case-study, area/design, level/intermediate]
verified: 2026-10-29
---
# Teardown - Blade Ball

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Server-time-only parry checks -> high-ping players never parry; accept timestamped input within a capped rewind.
> - Avoid: No miss cooldown -> spam clicking beats timing; add a short lockout after a whiff.
> - Avoid: Paid abilities with a slow free earn rate -> raise earn rates or rotate free abilities.
> - Ball path owned by the server; clients interpolate.
> - Parry uses timestamps with a capped rewind.
> - Miss cooldown and autoclick checks in place.
>
> Cost: TL;DR ~160 tok · whole note ~2.1k tok. Read more: ## The craft that sets it apart · ## Tech notes · ## Common mistakes when copying this style · ## Checklist
<!-- tldr:end -->

Blade Ball is a last-player-standing timing duel: a homing ball targets one player at a time and speeds up with every deflection, and you survive by parrying it at the right moment with a single button.

Trust labels: **Roblox docs**, **Measured**, **Rule of thumb**, **Unverified**. Not played for this note.

## Snapshot

| Field | Value | Label and source |
|---|---|---|
| Creator | Wiggity. (group); developers named in press as Y1ddy and Chunchbunch | Measured (group), Unverified (names, Naavik, 24 Oct 2023) |
| Place created | 17 June 2023 | Measured, Roblox games API |
| Visits | 6,513,633,426 | Measured, Roblox games API, 2026-10-29 |
| Favourites | 13,066,189 | Measured, Roblox games API, 2026-10-29 |
| Rating | 93.5% | Measured, Roblox votes API, 2026-10-29 |
| Playing at check | 10,980 | Measured, Roblox games API, 2026-10-29 |
| All-time peak CCU | 511,924 on 19 November 2023 | Measured, Rolimons, read 2026-10-29 |
| 30-day peak | 27,483 | Measured, Rolimons, read 2026-10-29 |
| Average session | about 13.1 minutes | Measured, Rolimons |
| Server size | 16 | Measured, Roblox games API |
| Growth story | about 15K CCU on 6 Sep 2023 to over 100K on 9 Sep, driven largely by TikTok; $1,500 in early ad funding | Unverified, Naavik, 24 Oct 2023 |

## Core loop

Spawn into a round, the ball picks a target, the target parries, the ball retargets faster. Last player alive wins. Knockouts earn coins; coins buy abilities and cosmetic swords and effects. Rounds are short.

## First 60 seconds

- You often join mid-round and spectate briefly (Naavik noted this friction, Unverified). Spectating teaches the whole game: watch the ball, see the parry, see the timing get harder.
- Your first round is one button. **Rule of thumb:** one input with a rising tempo is the purest onboarding there is; the difficulty curve is the ball's speed.

## The craft that sets it apart

**1. One input, honest timing.** A parry window that the player can read from the ball's distance and speed. Every loss feels like your own mistake, which is why the rating is high (93.5%, Measured).

**2. Rising tempo as drama.** Speed increases each deflection, so every duel builds to a climax in seconds. Two finalists trading parries at high speed is a natural highlight clip.

**3. Readability under speed.** The targeted player is highlighted; the ball has a bright trail; the parry has a big flash and sound. At high speed, the player reacts to the highlight and audio as much as the ball. See [[VFX Readability and Value - Lessons from Blind Reviews]] and [[Feedback Timing - Sound Visual and Haptic Sync]].

**4. Visual spectacle that sells cosmetics.** Swords, explosions and parry effects are seen by everyone in the arena. Naavik credits electronic music and visual effects for TikTok virality (Unverified).

**5. Abilities as variety.** Dashes, freezes and other abilities add counterplay layers on the simple loop (Unverified details).

## Progression and economy

- **Coins per knockout** (seven per knockout in October 2023) with the first ability around 300 coins, so most players need over 80 games for it (Unverified, Naavik, 24 Oct 2023).
- **Abilities** are bought or rolled on a wheel; **swords and effects** are cosmetic.
- **Rule of thumb:** a slow earn rate plus purchasable abilities in PvP creates spending pressure. If you copy the loop, raise the free earn rate or rotate abilities so free players compete.

## Monetization and 2026 rules

Public passes (Measured, 2026-10-29): VIP 240, Double Coins 240, Instant Spin 120, Trading Sign 112.

- **Cases and spins:** Naavik reported that about 90% of revenue came from purchases and premium case rolls (Unverified, October 2023). Under Roblox's 2026 rules, any random reward paid for with Robux, directly or through a purchasable currency, must show numeric odds before purchase, and restricted regions need alternatives. Read [[Paid Random Items and Odds Disclosure in Practice]], [[Regional Compliance - Paid Random Items and Country Rules]] and [[Policy and Age Rules 2026]].
- **Trading:** honour `IsPaidItemTradingAllowed` from `PolicyService:GetPolicyInfoForPlayerAsync` and build trades without duplication: [[Trading Systems Without Duplication]] and [[Player-Driven Trading Economies]].

## Retention

- **Weekly updates** with new items, abilities and maps (Unverified, Naavik 2023).
- **Large owned community** (over 500K Discord members in October 2023, Unverified).
- **Short sessions** that fit a few spare minutes.
- **Seasonal events** keep the 2026 30-day peak above 27K (Measured).

## Tech notes

- **The parry is a latency problem.** At high ball speed, a 100 ms ping is a large fraction of the window. Practical approach (Rule of thumb): the server owns the ball path; the client sends a parry with a timestamp; the server accepts it if the ball was within the parry radius at the client's time, within a capped rewind. See [[Client Prediction and Reconciliation for Combat]] and [[Server-Authoritative Freeze and Stun Timestamps]].
- **Server region matters.** Naavik noted inconsistent server placement causing variable ping (Unverified). Show ping and let players pick servers: [[Server Hop Rejoin and Server Lists with Ping]] and [[Feedback - Autosave Indicator Ping Display and Error Toasts]].
- **Autoclick and macro parry** is the main exploit vector: rate-limit parries and use a cooldown after a missed parry. [[Autoclicker and Macro Detection for Combat Remotes]].
- **Ball movement replication.** Simulate the ball on the server and replicate position at a steady rate; clients interpolate. [[Network Bandwidth Budgets and Measuring Them]].

## Team and cadence

Two young developers at launch, building on an established game category and open-source assets (Unverified, Naavik). Weekly updates in the launch period.

## Build it yourself

1. **Homing projectile** with retargeting and per-deflection speed growth: [[Projectiles and Ballistics]].
2. **Parry window** with timestamped input and a short miss cooldown: [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]].
3. **Target highlight and parry VFX:** use the `lihfolk:lihfolk-vfx` skill and [[VFX Design Playbook]]; check [[Hit-Stop and Screen Shake Tuning by Numbers]] for the parry flash.
4. **Round loop with spectating:** [[Arena Rounds with Teams and Spectating End to End]].
5. **Ability kit:** [[Ability Kits Architecture]].
6. **Odds UI** for any spin: [[Drop Tables Rarity and Pity Systems]] plus the disclosure note above.

## Numbers to remember

| Number | Label | Source and date |
|---|---|---|
| 511,924 peak CCU, 19 Nov 2023 | Measured | Rolimons, read 2026-10-29 |
| 13,066,189 favourites | Measured | Roblox games API, 2026-10-29 |
| 7 coins per KO; ~300 coins for first ability | Unverified | Naavik, 24 Oct 2023 |
| Rewind cap for parry validation: keep it short and fixed | Rule of thumb | This note |

## Common mistakes when copying this style

- **Server-time-only parry checks** -> high-ping players never parry; accept timestamped input within a capped rewind.
- **No miss cooldown** -> spam clicking beats timing; add a short lockout after a whiff.
- **Paid abilities with a slow free earn rate** -> raise earn rates or rotate free abilities.
- **Spins without odds** -> show numeric odds before every paid roll.
- **Joining mid-round with nothing to do** -> make spectating informative and short.

## Checklist

- [ ] Ball path owned by the server; clients interpolate.
- [ ] Parry uses timestamps with a capped rewind.
- [ ] Miss cooldown and autoclick checks in place.
- [ ] Target highlight readable at top speed.
- [ ] Paid random rolls show numeric odds; restricted players get alternatives.
- [ ] Ping shown; server choice offered.

## See also

[[High-Craft Teardowns Start Here]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]] · [[Teardown - BedWars]] · [[Teardown - Funky Friday]] · [[Genre Playbook - Battlegrounds and Arena Fighters]] · [[Short-Form Video Marketing]]

<!-- related:start -->
## Related
[[Teardown - Anime Vanguards]] · [[Teardown - Jujutsu Shenanigans]] · [[Teardown - Apocalypse Rising 2]] · [[Teardown - Deepwoken]] · [[Teardown - Phantom Forces]] · [[Teardown - Arsenal]] · [[Teardown - Grace]] · [[Teardown - Piggy]]
<!-- related:end -->
