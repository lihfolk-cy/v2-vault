---
tags: [teardown, high-craft, rpg, souls-like, permadeath, parry, builds, paid-access, combat, type/case-study, area/design, level/advanced]
verified: 2026-10-29
---
# Teardown - Deepwoken

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Permadeath with unreadable deaths -> every death needs a visible cause.
> - Avoid: Wipes triggered from the client or by a crash -> wipe only after a server-confirmed death, saved atomically.
> - Avoid: No combat-log rule -> players escape death by leaving; add a combat tag.
> - Every attack has a readable wind-up and a punishable recovery.
> - Parry, dodge and block windows validated on the server.
> - Death cause shown clearly.
>
> Cost: TL;DR ~150 tok · whole note ~2.0k tok. Read more: ## Snapshot · ## The craft that sets it apart · ## Common mistakes when copying this style · ## Checklist
<!-- tldr:end -->

Deepwoken is a paid-access hardcore action RPG with souls-like real-time combat, deep character builds and permanent death: your character can be lost for good, and what survives is your knowledge and a few carried-over unlocks.

Trust labels: **Roblox docs**, **Measured**, **Rule of thumb**, **Unverified**. Not played for this note.

## Snapshot

| Field | Value | Label and source |
|---|---|---|
| Creator | Monad Studios East (group) | Measured, Roblox games API, 2026-10-29 |
| Place created | 12 October 2019 | Measured, Roblox games API |
| Price | 400 Robux paid access | Measured, Roblox games API, 2026-10-29 |
| Visits | 1,649,429,613 | Measured, Roblox games API, 2026-10-29 |
| Favourites | 1,044,511 | Measured, Roblox games API, 2026-10-29 |
| Rating | 86.3% | Measured, Roblox votes API, 2026-10-29 |
| Playing at check | 1,072 | Measured, Roblox games API, 2026-10-29 |
| All-time peak CCU | 62,422 on 23 December 2022 | Measured, Rolimons, read 2026-10-29 |
| 30-day peak | 5,330 | Measured, Rolimons |
| Server size | 30 | Measured, Roblox games API |
| Peak trigger | "Verse 2" update with the second layer of the world, released 23 December 2022 | Unverified, Deepwoken fandom wiki |

62K concurrent players paying 400 Robux each to enter is a remarkable figure for a hardcore game.

## Core loop

1. Create a character: race, origin, starting stats.
2. Explore a dangerous open world, fight monsters and players, train attributes and learn talents, mantras (abilities) and weapon skills.
3. Gain power through investment choices that define a build.
4. Die. A death can cost lives or end the character permanently, depending on state and mechanics (Unverified details, community wiki).
5. Start again, wiser, with some account-level unlocks carried forward.

## First 60 seconds

- A character creator with meaningful choices, then a hostile start. The game does not hold your hand.
- The first fight teaches the combat grammar: attack, block, parry, dodge, and a posture or guard meter.
- **Rule of thumb:** a hard game earns trust when its first death is readable. If the player can tell why they died (bad parry timing, out of stamina), they come back.

## The craft that sets it apart

**1. Combat with commitment.** Attacks have wind-ups you can read and recoveries you can punish; parries reward precise timing; feints and dodges create mind games. Every input is a commitment, which is what "souls-like" means in practice. See [[Combat Animation Craft]] and [[Telegraphing]].

**2. Permanent stakes.** Permadeath makes every fight matter and every build precious. It also makes skilled play visible and admired, a status system with no shop attached.

**3. Build depth.** Many attributes, talents and abilities combine into builds that players plan in spreadsheets and community tools. Depth outside the game (planners, wikis, guides) keeps players engaged when they are not playing.

**4. World as threat.** Layers of world with escalating danger, hidden areas and lore discovered by exploring. See [[Lore Delivery Without Walls of Text]].

**5. Paid access as a filter.** A 400 Robux entry (Measured) filters for committed players, reduces throwaway alts and griefers, and funds development. It also caps the audience; it is a deliberate trade.

## Progression and economy

- **Character progression** is deep and resets on permadeath.
- **Account progression** carries limited unlocks across lives (Unverified details).
- **Loot and gear** found in the world; trading between players.

## Monetization and 2026 rules

- **Paid access** at 400 Robux (Measured). Paid access experiences have their own requirements (age and identity, refunds, store presentation); check current rules before choosing it.
- **Passes** (Measured, 2026-10-29): Emote Pack 1 and Emote Pack 2 at 150 each. That is all. The store respects the game's tone: no paid power in a permadeath game.
- **Trading:** honour `IsPaidItemTradingAllowed` and protect trades: [[Trading Systems Without Duplication]].
- See [[Monetization Overview]] and [[Policy and Age Rules 2026]].

## Retention

- **Major "Verse" updates** that open new layers of the world; the December 2022 Verse 2 coincides with the tracker peak.
- **Community tools and theorycrafting.**
- **Hardcore status:** surviving long with a known build is a social achievement.

## Tech notes

- **Multi-place world.** Layers and areas as separate places with teleports that carry character state: [[Teleporting and Multi-Place Games]].
- **Permadeath data safety.** A character wipe must only happen on a confirmed server-side death, saved atomically, and logged. A lost character from a data bug is a catastrophe in a permadeath game. See [[Data Loss Prevention and Recovery]], [[DataStore Fundamentals]] and the `lihfolk:roblox-datastore-safety` skill.
- **Combat logging protection.** Players leaving mid-fight to avoid death need a rule (for example, a combat tag that keeps the character in the world briefly). See [[Exploits and Anti-Cheat]].
- **Parry and stun timing on the server** with timestamps: [[Server-Authoritative Freeze and Stun Timestamps]].
- **30-player servers** in a large world: streaming and NPC budgets per area: [[Instance Streaming]] and [[Spawn Director - Credit Budgets and Player-Count Scaling]].

## Team and cadence

Monad Studios East, a subdivision of Monad Studios, formerly known by other group names (Unverified, community wiki). Large, infrequent world updates with balance patches between.

## Build it yourself

1. **Commitment combat:** [[Melee Combat System End to End]], [[Combat Combo Systems]] and [[Stamina]]; add a parry window, a posture meter and punishable recoveries.
2. **Telegraphs** on every enemy attack: [[Telegraphing]] and [[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]].
3. **Boss phases:** [[Boss Animation and Phases]].
4. **Permadeath save design:** versioned character records, server-only wipe, backups: [[Data Loss Prevention and Recovery]].
5. **Combat tag on leave:** a server timer started on damage.
6. **Build planner data** exported as a public table so the community can build tools: [[Data and Config Pipeline - Spreadsheets to Game]].

## Numbers to remember

| Number | Label | Source and date |
|---|---|---|
| 400 Robux entry price | Measured | Roblox games API, 2026-10-29 |
| 62,422 peak CCU, 23 Dec 2022 | Measured | Rolimons, read 2026-10-29 |
| 2 game passes, both emote packs | Measured | Roblox game-passes API, 2026-10-29 |
| Permadeath wipes only on confirmed server-side death | Rule of thumb | This note |

## Common mistakes when copying this style

- **Permadeath with unreadable deaths** -> every death needs a visible cause.
- **Wipes triggered from the client or by a crash** -> wipe only after a server-confirmed death, saved atomically.
- **No combat-log rule** -> players escape death by leaving; add a combat tag.
- **Selling power in a hardcore game** -> keep the store cosmetic.
- **Paid access with a confusing first hour** -> paying players expect polish in the opening.

## Checklist

- [ ] Every attack has a readable wind-up and a punishable recovery.
- [ ] Parry, dodge and block windows validated on the server.
- [ ] Death cause shown clearly.
- [ ] Character wipes are server-confirmed, atomic and logged.
- [ ] Combat tag prevents escape by leaving.
- [ ] Store contains no power.

## See also

[[High-Craft Teardowns Start Here]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]] · [[Teardown - Jujutsu Shenanigans]] · [[Case Study - Blox Fruits]] · [[Genre Playbook - Combat and RPG]] · [[Hit Reactions Stagger and Hit-Stop]]

<!-- related:start -->
## Related
[[Teardown - Apocalypse Rising 2]] · [[Teardown - Blade Ball]] · [[Teardown - Grace]] · [[Teardown - Phantom Forces]] · [[Teardown - Anime Vanguards]] · [[Teardown - BedWars]] · [[Teardown - Pressure]] · [[Teardown - Arsenal]]
<!-- related:end -->
