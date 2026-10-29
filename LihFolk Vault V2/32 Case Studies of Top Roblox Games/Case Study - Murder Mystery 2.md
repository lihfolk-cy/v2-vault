---
tags: [case-study, top-games, murder-mystery, social-deduction, rounds, cosmetics, trading, knives, game-passes, type/case-study, area/design, area/monetization]
---
# Case Study - Murder Mystery 2

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Role data replicated through teams, attributes or visible tools.
> - Avoid: No grace period at round start.
> - Avoid: Cosmetics that change hitboxes or reach.
> - Three-line rules; rounds of a few minutes; 8 to 12 players.
> - Private role delivery; grace period; full role reveal at round end.
> - Hero mechanic for the weakest role.
>
> Cost: TL;DR ~130 tok · whole note ~1.6k tok. Read more: ## Snapshot · ## The economy · ## Common mistakes in MM2 clones · ## Checklist
<!-- tldr:end -->

Murder Mystery 2 (MM2) is the defining social-deduction round game on Roblox: each round one player is the Murderer, one the Sheriff, the rest Innocents. It has been on the platform since 2014 and remains one of its most visited games. It is a study in a tiny, repeatable round loop carrying a huge cosmetic and trading economy built on knives and guns.

Source labels: **Public stats** (Roblox public APIs, fetched 29 October 2026), **Observed** (store description and pass list), **Reported**, **Rule of thumb**, **Unverified**.

## Snapshot

| Field | Value | Source |
|---|---|---|
| Creator | Nikilis (user account) | Public stats |
| Place created | 18 January 2014 | Public stats |
| Genre on Roblox | Horror / Survival / 1 vs All | Public stats |
| Visits | 31,911,093,959 | Public stats, 29 Oct 2026 |
| Favourites | 24,697,335 | Public stats |
| Votes | 10,870,770 up, 1,100,142 down (about 91 % positive) | Public stats |
| Playing at check | 371,368 | Public stats, one moment, during Halloween season |
| Server size | 12 | Public stats |

The playing figure was taken in late October, when Halloween content is typically live; treat it as a seasonal high, not a baseline. Wikipedia describes MM2's role structure and coin-bought powers, emotes and mystery boxes, and notes critical praise for its level design (Reported, read October 2026).

## The loop

The description states the whole game in three lines (Observed): Innocents run, hide and expose the Murderer; the Sheriff is the only one with a weapon who can take the Murderer down; the Murderer must eliminate everyone without being shot. Then: "Collect and trade hundreds of knives!"

- **Rounds of a few minutes** with an intermission. Twelve-player servers keep rounds tense and readable.
- **Roles randomised each round**, so every player gets to be the Murderer eventually; that anticipation keeps players in the server.
- **Hero moment**: if the Sheriff dies, the gun drops and any Innocent can pick it up.
- **Works without chat.** The game is played through movement and observation, which suits a young, phone-heavy audience ([[Genre Playbook - Social Deduction and Murder Mystery]]).

## The economy

- **Cosmetic weapons are the business.** Knife and gun skins with rarity tiers, many sold in bundles or obtained from boxes, and traded between players.
- The public pass list is dominated by seasonal and themed weapon bundles. At check time only "BUNDLE: Mortal" had a price listed (3,399 Robux); dozens of other bundles and "GODLY" or "EVO" items were listed without prices, meaning off sale (Observed). Retired items gain trading value, which is the engine of the collector market.
- **Trading** creates a secondary economy with its own value lists maintained by the community (Reported, community sites; not verified here). That economy brings long-term engagement and also scams, account theft and real-money trading risk.

Paid random boxes and trading of paid items are policy-gated by region and age; any MM2-like game must disclose odds and honour `ArePaidRandomItemsRestricted` and `IsPaidItemTradingAllowed` ([[Regional Compliance - Paid Random Items and Country Rules]], [[Player-Driven Trading Economies]]).

## Store page notes

The description asks players to "Like, follow, and subscribe for exclusive update news, free knife codes" and points to the creator's profile for links (Observed). Under 2026 rules, rewarding likes or off-platform follows and putting external handles in game text are restricted ([[Community Building]], [[Policy and Age Rules 2026]]). Old games often carry text written before the rules changed; new games should not copy it.

## What to copy

- **A loop you can explain in three lines.**
- **Role rotation** as the reason to stay for one more round.
- **A hero mechanic** (dropped gun) that gives the weakest role a chance.
- **Cosmetic weapons as identity**, visible in every round.
- **Seasonal bundles** retired on schedule, giving collections history.

## What not to copy

- **Trading without safeguards.** Trade confirmations, value warnings, cooldowns and logs are necessary to limit scams ([[Trading Systems Without Duplication]]).
- **Engagement-bait text** ("like and follow for codes") under 2026 policy.
- **Unlimited limited-time pressure.** Constant "last chance" bundles push young players.
- **Roles that leak to clients.** Exploit scripts for this genre target role information; keep roles server-side and send them privately.

## Common mistakes in MM2 clones

- Role data replicated through teams, attributes or visible tools.
- No grace period at round start.
- Cosmetics that change hitboxes or reach.
- Trading added before duplication-proof inventory.

## Checklist

- [ ] Three-line rules; rounds of a few minutes; 8 to 12 players.
- [ ] Private role delivery; grace period; full role reveal at round end.
- [ ] Hero mechanic for the weakest role.
- [ ] Cosmetic weapons with rarity; odds disclosed; policy-gated boxes and trading.
- [ ] Trade safety: confirmations, cooldowns, logs.
- [ ] Description and in-game text compliant with 2026 link and reward rules.

## See also

- [[Genre Playbook - Social Deduction and Murder Mystery]]
- [[Player-Driven Trading Economies]]
- [[Trading Systems Without Duplication]]
- [[Round-Based Minigame Loop End to End]]
- [[Top Games Case Studies Start Here]]

## Connected notes

[[Case Study - Adopt Me]] · [[UGC Pricing Limiteds and Marketplace Rules]] · Paid Random Items and Odds Disclosure in Practice · Social Design and Multiplayer Play

Sources: https://games.roblox.com/v1/games?universeIds=66654135 ; https://games.roblox.com/v1/games/votes?universeIds=66654135 ; https://apis.roblox.com/game-passes/v1/universes/66654135/game-passes ; https://en.wikipedia.org/wiki/List_of_Roblox_games (read 29 October 2026).

<!-- related:start -->
## Related
[[Case Study - Forsaken]] · [[Case Study - Rivals]] · [[Case Study - Tower Defense Simulator]] · [[Case Study - The Strongest Battlegrounds]] · [[Case Study - Jailbreak]] · [[Case Study - Dead Rails]] · [[Case Study - Blox Fruits]] · [[Case Study - Pet Simulator 99]]
<!-- related:end -->
