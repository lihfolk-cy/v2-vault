---
tags: [teardown, viral-trend, social, hangout, donation, creator-content, robux, type/case-study, area/design, level/intermediate, area/monetization]
verified: 2026-10-29
---

# Teardown - PLS DONATE

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Unfiltered sign text -> filter every sign for every viewer
> - Avoid: Counting the same donation twice -> idempotent records keyed by the platform's event id
> - Avoid: Wheels or chance features tied to Robux -> no wagering; disclose any paid randomness
> - Is every sign filtered before display?
> - Is booth ownership server-side with cleanup on leave?
> - Are donation records idempotent?
>
> Cost: TL;DR ~140 tok · whole note ~2.3k tok. Read more: ## Snapshot · ## Monetization and 2026 compliance · ## Common mistakes · ## Checklist
<!-- tldr:end -->

> **In one line:** claim a booth, write a sign, and other players can send you Robux; you can send Robux to others too.

PLS DONATE turned **generosity into a game**. There is almost no "game" in the usual sense: the booth is the content, other players are the audience, and big donations filmed by video creators were the marketing. It peaked as a phenomenon in 2022-2023 and remains a large, well-favourited social space.

Labels: **Measured**, **Roblox docs**, **Rule of thumb**, **Unverified** ([[Viral and Trend Teardowns Start Here]]).

## Snapshot

| Fact | Value | Label | Source and date |
|---|---|---|---|
| Created | 2022-02-05 | Measured | Roblox game API, 2026-10-29 |
| Owner group | Quataun | Measured | Roblox game API, 2026-10-29 |
| Creator credit | launched largely solo by a developer named Hazem | Unverified | RoWatcher profile article, 2026 |
| Last update stamp | 2026-08-16 | Measured | Roblox game API, 2026-10-29 |
| Genre on Roblox | Social | Measured | Roblox game API, 2026-10-29 |
| Server size | 28 players | Measured | Roblox game API, 2026-10-29 |
| Playing now | 2,343 (08:06 UTC Thursday) | Measured | Roblox game API, 2026-10-29 |
| Visits | 5,257,837,796 | Measured | Roblox game API, 2026-10-29 |
| Favourites | 4,451,123 | Measured | Roblox game API, 2026-10-29 |
| Votes | 3,702,620 up / 280,245 down, about 93.0% positive | Measured (computed) | Roblox votes API, 2026-10-29 |
| Peak era | "regularly in the top 10" with "hundreds of thousands" online at its height (no dates given); trackers' recent windows show far lower peaks | Unverified | RoWatcher article, 2026; RoWatcher and profitable.app pages |
| Viral moment | late 2022 into 2023, driven by creators filming large donations to strangers | Unverified | RoWatcher article, 2026 |
| How donating works now (store page) | the description says a Roblox Plus subscription is needed to donate, transfers are capped at 500 Robux a day and 1,000 a month, and 2-Step Verification raises the cap tenfold; under-18 donations may need parental approval | Measured (as stated on the store page; platform rules not independently checked) | Roblox game API description, 2026-10-29 |
| Earlier mechanism | donating by buying another player's game pass (Roblox takes 30%) | Unverified | RoWatcher article, 2026 |
| Public game passes | Donation Sign 99; Boombox Control 49; Disguise Mask 299; Cloaking Device 399; Golf Cart 499; Booth Painter 699; Gigantic Donation Sign 100,000 (Robux); a Spinning Wheel pass is listed but off sale | Measured | Roblox game-pass API, 2026-10-29 |

## Core loop

```text
 claim booth ──► customise sign and look ──► stand, chat, perform
       ▲                                         │
       │                                         ▼
 spend on booth style ◄── receive Robux ◄── another player donates
                                                  │
                     give back: donate to others ◄┘
```

## First 60 seconds

1. You spawn into a plaza of booths with signs. Each sign is a tiny stand-up act.
2. You claim an empty booth and type your own sign.
3. You walk around reading other signs; the social mood is clear immediately.

There is no fail state and nothing to learn. The game is a stage.

## Progression and economy

- **Raised and donated totals** are the stats, often shown on leaderboards and booth displays.
- **Booth customisation** (colours, sizes, effects) is the progression.
- **No rarity, no grind.** Status comes from generosity and creativity.

## Monetization and 2026 compliance

- **Passes are presentation and mobility:** signs, a booth painter, a boombox, a cart, disguises. The 100,000 Robux sign is a pure prestige anchor.
- **The money flowing between players is not the developer's product.** It runs on whatever platform mechanism Roblox currently allows; the store page describes a subscription requirement and daily and monthly caps (Measured as stated, 2026-10-29). Always build donation features on official platform tools and current rules, never on off-platform transfers ([[Roblox Policies Ratings and Compliance]]).
- **Random features:** a spinning wheel pass exists but was off sale at the snapshot. Any paid wheel or spin would be a paid random item needing full odds disclosure and `PolicyService` gating, and anything resembling wagering is prohibited as gambling (Roblox docs, Community Standards; [[Paid Random Items and Odds Disclosure in Practice]]).
- **Age and safety:** a donation game handles real value between strangers. Parental approval flows, clear limits and scam warnings are part of the product ([[Age Checks and Safety Features]]).

## Retention hooks

- **Hope and surprise:** any moment, a stranger might donate.
- **Creator visits:** video creators drop in to give away Robux, which brings their audiences.
- **Self-expression:** the sign is a personal joke you can keep improving.
- **Seasonal events and booth options** added over time (Unverified, RoWatcher).

## Multiplayer and social design

Twenty-eight players in a plaza is a crowd big enough to feel lively and small enough to read every sign. The core interaction is positive: giving. That is unusual and powerful. The risks are social (begging pressure, scams), which a builder must design against.

## Art, UI, title and thumbnail

- **Title:** a playful imperative in capitals with a money emoji. The title *is* the sign every player holds.
- **Art:** clean plaza, uniform booths, so signs and avatars stand out.
- **Thumbnails** historically show big Robux numbers and happy reactions.

## Technical notes

- **Booth claiming** must be server-authoritative with one booth per player and cleanup on leave.
- **Text on signs** must pass Roblox text filtering for every viewer (TextService filtering) before display.
- **Donation events** come from the platform; record them idempotently for leaderboards so a retried event does not double-count ([[Developer Products and ProcessReceipt]] covers idempotent purchase handling).
- **Leaderboards** for raised and donated totals ([[Global Leaderboards End to End]]).

## Why it went viral

1. **Real value, visible.** Seeing a stranger receive Robux on camera is compelling.
2. **Creator economy fit.** Video creators could make generosity content cheaply and repeatedly.
3. **Zero barrier.** No skill, no grind, works on any device.
4. **Timing.** 2022 was an early, open period for creator giveaway videos on short-form platforms.

## Build it yourself

| System | Notes | Vault notes |
|---|---|---|
| Booth claim and release | Server-owned, one per player | [[Server Authority and Validation]] |
| Filtered player signs | Filter per recipient before display | [[Roblox Policies Ratings and Compliance]] |
| Totals and leaderboards | Idempotent counters | [[Global Leaderboards End to End]], [[OrderedDataStores and Leaderboards]] |
| Cosmetic passes | Fixed price | [[Game Passes]] |
| Safety tools | Report, block, scam warnings | [[Block and Mute Respecting Platform Rules]] |

## Raise the quality bar

- **Safety first:** clear on-screen reminders that donations are gifts, never trades; warnings about off-platform "deals"; easy block and report.
- **Positive design:** thank-you emotes, gratitude effects and "donor" cosmetics reward giving, not asking.
- **Creative booths:** booth themes, stickers and small mini-games give non-donating players something to do.
- **Parent clarity:** a simple explanation panel of limits and approvals helps families feel safe.

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Unfiltered sign text | moderation action | filter every sign for every viewer |
| Counting the same donation twice | leaderboard totals jump | idempotent records keyed by the platform's event id |
| Wheels or chance features tied to Robux | gambling and policy risk | no wagering; disclose any paid randomness |
| No anti-scam messaging | complaints from parents | warnings, reporting, clear rules |

## Checklist

- [ ] Is every sign filtered before display?
- [ ] Is booth ownership server-side with cleanup on leave?
- [ ] Are donation records idempotent?
- [ ] Is there no chance-based feature tied to Robux without full disclosure, and nothing that resembles wagering?
- [ ] Are safety messages and limits explained in game?

## See also

- [[Viral Game Anatomy - Hooks, Loops and Timing]]
- [[Case Study - Brookhaven RP]] (another stage-not-game social space)
- [[Genre Playbook - Roleplay and Social Hangouts]]

## Sources

- Roblox public game, votes and game-pass APIs, read 2026-10-29 08:06 UTC (including the store description's donation notes).
- RoWatcher, "Who Made PLS Donate? Meet the Developer Behind Roblox's Viral Tipping Game", 2026.
- RoWatcher and profitable.app game pages, seen via search 2026-10-29.

<!-- related:start -->
## Related
[[Teardown - Fling Things and People]] · [[Teardown - Ride A Pet]] · [[Teardown - Build A Boat For Treasure]] · [[Teardown - Sol's RNG]] · [[Teardown - Natural Disaster Survival]] · [[Teardown - Bee Swarm Simulator]] · [[Teardown - Tower of Hell]] · [[Teardown - Escape Tsunami for Brainrots]]
<!-- related:end -->
