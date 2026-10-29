---
tags: [teardown, high-craft, shooter, arcade, gun-game, short-rounds, cosmetics, classic, type/case-study, area/design, level/beginner]
verified: 2026-10-29
---
# Teardown - Arsenal

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Letting avatars change hitbox size -> morph to a fixed rig or use fixed hit volumes.
> - Avoid: A rotation that gets weaker at the end -> the final weapon should be hard to use but satisfying.
> - Avoid: No spawn protection in small maps -> new arrivals quit if they die instantly.
> - Weapon ladder defined as data and advanced on validated kills.
> - Fixed hitboxes for all players.
> - Spawn protection and smart spawns.
>
> Cost: TL;DR ~150 tok · whole note ~1.8k tok. Read more: ## Snapshot · ## The craft that sets it apart · ## Common mistakes when copying this style · ## Checklist
<!-- tldr:end -->

Arsenal is an arcade free-for-all shooter built on the "gun game" rule: every kill swaps your weapon for the next one in a rotation, and the first player to get a kill with the final weapon wins the round.

Trust labels: **Roblox docs**, **Measured**, **Rule of thumb**, **Unverified**. Not played for this note.

## Snapshot

| Field | Value | Label and source |
|---|---|---|
| Creator | ROLVe (group) | Measured, Roblox games API, 2026-10-29 |
| Place created | 18 August 2015 | Measured, Roblox games API |
| Visits | 6,323,341,496 | Measured, Roblox games API, 2026-10-29 |
| Favourites | 11,526,393 | Measured, Roblox games API, 2026-10-29 |
| Rating | 88.5% | Measured, Roblox votes API, 2026-10-29 |
| Playing at check | 1,495 | Measured, Roblox games API, 2026-10-29 |
| Tracker peak | 152,613 on 26 October 2020 | Measured, Rolimons, read 2026-10-29 |
| Average session | about 8.2 minutes | Measured, Rolimons |
| Server size | 16 | Measured, Roblox games API |
| Avatar | morphs to R6 | Measured, Roblox games API (universeAvatarType) |
| Group perk | in-game chat tag and 25% more BattleBucks and XP for group members | Measured, game description, 2026-10-29 |

## Core loop

Spawn, kill, get the next gun, repeat until the final weapon; round ends, a new map loads. Earn BattleBucks and XP, spend on skins, characters, melees, kill effects and announcers.

## First 60 seconds

- You join a running round and are in combat within seconds. No loadout screen is needed because the game chooses your weapon.
- **Rule of thumb:** removing the loadout decision is the onboarding. New players cannot pick wrong, and every kill shows them a new toy.
- Rounds are short (an 8-minute average session, Measured), so a bad round ends fast.

## The craft that sets it apart

**1. The rotation as a comeback and variety engine.** Everyone climbs the same ladder, so the leader is always using a weapon you have already tried. Joke weapons (spell books and bazookas, per the description) sit next to standard guns, which keeps the tone playful.

**2. R6 morph for consistent hitboxes.** Forcing one body type means every player presents the same target shape regardless of avatar (Measured: the place morphs to R6). **Rule of thumb:** competitive shooters should normalise hitboxes; cosmetics change the look, not the size.

**3. Arcade feel over realism.** Fast movement, quick time-to-kill and loud, bright feedback (hit sounds, kill effects, announcers) make every kill a small celebration. See [[Reward Moments and Celebrations]] and [[Combat Sound Design and Feedback]].

**4. Cosmetics that are visible in play.** Kill effects, announcer voices and taunts are seen and heard by others at the moment of victory, which makes them desirable without affecting balance.

**5. Small, readable maps.** Sixteen players in compact maps means short time between fights; spawns must be protected so new arrivals are not killed instantly. See [[Quick Respawn and Spawn Protection]].

## Progression and economy

- **BattleBucks** buy cosmetics; XP levels up an account.
- **Codes are cosmetic only** (announcer voices, skins, taunts) and never grant currency or weapons (Unverified, code guides). That keeps codes a marketing tool without affecting the economy.
- **No weapon unlocks needed** because the rotation hands out every gun.

## Monetization and 2026 rules

Public passes (Measured, 2026-10-29): Nexus Bundle 725, Bugs & Beasts Bundle 495, VIP 395, Day of the Dead Bundle 395, Primus the Knight Bundle 245; many older bundles off sale, including a "Competitive" pass and a "Premium Battle Pass" (now off sale).

- **Bundles of cosmetics** at fixed prices; no paid randomness in the pass list.
- **Group join reward** (25% more currency and XP) grows the community notification audience; see [[Roblox Communities as Your On-Platform Hub]].
- If you add a battle pass, follow [[Battle Pass and Season Design]] and keep paid tracks cosmetic.

## Retention

- **Collaborations and events** (a Medal collaboration ended 15 November 2025, Unverified event tracker).
- **Cosmetic collections** and seasonal bundles.
- **Instant fun:** no commitment needed, which suits short sessions.

## Tech notes

- **16-player servers** and small maps keep bandwidth and physics cheap.
- **Weapon rotation on the server.** The server owns which weapon each player holds and advances it only on a validated kill. See [[Kill Credit, Assists, Kill Feed and Death Recaps]].
- **Many weapon types** (hitscan, projectile, melee) share one damage pipeline: [[Combat Systems Architecture]] and [[Projectiles and Ballistics]].
- **Hit validation** as in any shooter: [[Detecting Combat Exploits - Reach Rate and Aim]].

## Team and cadence

ROLVe, a studio group with several games (Unverified details). Long-running cosmetic and event updates.

## Build it yourself

1. **Weapon ladder as data.** An ordered list of weapon ids; a kill advances the killer. [[Data and Config Pipeline - Spreadsheets to Game]].
2. **One damage pipeline** for all weapon types: [[Combat Systems Architecture]].
3. **Spawn protection** and smart spawn selection away from enemies: [[Quick Respawn and Spawn Protection]] and [[Spawning Teams and Rounds]].
4. **Kill effects and announcers** as cosmetics: [[VFX Design Playbook]] and the `lihfolk:lihfolk-vfx` skill.
5. **Hitbox normalisation** via a fixed rig: [[Hitboxes and Hit Detection]].
6. **Group reward** with a server-side group check.

## Numbers to remember

| Number | Label | Source and date |
|---|---|---|
| 6.3 billion visits | Measured | Roblox games API, 2026-10-29 |
| 152,613 tracker peak, 26 Oct 2020 | Measured | Rolimons, read 2026-10-29 |
| 25% currency and XP group perk | Measured | Game description, 2026-10-29 |
| Normalise hitboxes in competitive games | Rule of thumb | This note |

## Common mistakes when copying this style

- **Letting avatars change hitbox size** -> morph to a fixed rig or use fixed hit volumes.
- **A rotation that gets weaker at the end** -> the final weapon should be hard to use but satisfying.
- **No spawn protection in small maps** -> new arrivals quit if they die instantly.
- **Codes that give currency** -> keep codes cosmetic or tiny.
- **Cosmetics nobody else sees** -> prioritise effects visible at the moment of the kill.

## Checklist

- [ ] Weapon ladder defined as data and advanced on validated kills.
- [ ] Fixed hitboxes for all players.
- [ ] Spawn protection and smart spawns.
- [ ] Kill effects and announcers as cosmetics.
- [ ] Group perk checked on the server.
- [ ] Rounds end in under 10 minutes.

## See also

[[High-Craft Teardowns Start Here]] · [[What Craft Looks Like on Roblox - Lessons from Top Studios]] · [[Teardown - Phantom Forces]] · [[Case Study - Rivals]] · [[Genre Playbook - Shooters FPS and TPS]] · [[Arena Rounds with Teams and Spectating End to End]]

<!-- related:start -->
## Related
[[Teardown - BedWars]] · [[Teardown - Evade]] · [[Teardown - Piggy]] · [[Teardown - Blade Ball]] · [[Teardown - Jujutsu Shenanigans]] · [[Teardown - Apocalypse Rising 2]] · [[Teardown - Anime Vanguards]] · [[Teardown - Funky Friday]]
<!-- related:end -->
