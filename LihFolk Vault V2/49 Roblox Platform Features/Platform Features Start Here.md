---
cssclasses: [vault-hub]
tags: [platform-features, hub, badges, invites, notifications, subscriptions, commerce, social, type/hub, area/platform, level/beginner]
---
# Platform Features Start Here

This section is about the features **Roblox itself** provides around your game: badges on player profiles, invite and referral flows, notifications that reach players outside the game, recurring subscriptions, real-world commerce, and the built-in social menus. You configure them and live with their rules (rate limits, age gates, daily throttles, eligibility thresholds), which decide most of the design, so every platform fact in these notes is labelled **Roblox docs (as of October 2026)** and was checked against create.roblox.com. These features change often; re-check numbers before you plan around them.

It builds on older notes. Read them first if the topic is new; the notes here go deeper and do not repeat them:

- [[Social Design and Multiplayer Play]]: why friends, co-play and visible status matter, and the basic invite call.
- [[Monetization Overview]]: the money map, and where subscriptions and commissions fit among passes and products.
- [[Subscriptions and Premium Payouts]]: subscription payouts and rules, Roblox Plus and [[Creator Rewards]].
- [[Community Building]] and [[Retention and Return Hooks]]: the strategy behind invites, share links and notifications.
- [[Official Docs - Publishing and Live Ops]]: the official badge docs. There is no older badge note in the vault; [[Badges and Achievement Design]] is the first.

## The six notes

| Note | Problem it solves | Key ideas |
|---|---|---|
| [[Badges and Achievement Design]] | Achievements that mean something and badges that never go missing | 5 free badges per day, award rules and rate limits, ledger as source of truth with a badge mirror, pending retries, rarity as a health signal |
| [[Friend Invites Referrals and Experience Invites]] | Bringing new and lapsed players in through existing ones | Four mechanisms compared, `ReferredByPlayerId`, launch data as a hint, rewards on qualification, cross-server mailbox, alt-account abuse |
| [[Experience Notifications and Return Prompts]] | Reaching players after they leave | One notification per user per day, the 30-day opt-in prompt, engagement-driven reach, a MemoryStore due-time queue, update announcements, event RSVPs |
| [[Subscriptions and Recurring Revenue]] | Subscriptions that earn trust and renew | Subscription state machine, grace period, per-cycle grants, churn and lifetime value arithmetic, honest cancellation, webhooks |
| [[Commerce and Physical Goods]] | Selling real-world merchandise, or the digital alternative | Shopify-linked commerce products, US-only buyers 13+, digital benefit thresholds, revocation by webhook, 40% game-owner commission on in-game avatar item sales |
| [[Avatar Context Menus Profiles and Social Surfaces]] | Safe, useful ways for players to act on each other | Avatar Context Menu options and theme, inspect menu modes, [[SetCore]] friend and block prompts, respecting blocks server-side, profile card data |

## 2025-2026 changes, limits and release checks

Added after the six notes above. Start at the hub, [[Roblox Changes 2025-2026]], which lists the ten changes most likely to break generated code.

| Note | Problem it solves |
|---|---|
| [[Roblox Changes 2025-2026]] | One entry point to everything that changed between January 2025 and October 2026 |
| [[API Renames and Deprecations 2025-2026]] | A lookup table of renamed, deprecated and replaced API names, including the `Async` renames |
| [[Engine and API Changes 2025-2026]] | Engine and Studio changes that matter when writing or reviewing code: mesh streaming, 4K textures, fonts, the new type solver, UI Styling, the Character Controller Library |
| [[Server Authority and Input Migration 2026]] | Server Authority, Next Generation Replication, the physics replication rewrite and the Input Action System |
| [[Data and Cloud Changes 2025-2026]] | DataStore and Open Cloud budget changes, retired web endpoints, rate limits and Open Cloud Luau Execution |
| [[Discovery and Monetization Changes 2025-2026]] | Retention in recommendations, Creator Rewards, Roblox Plus, regional pricing defaults and DevEx rates |
| [[Policy and Age Rules 2026]] | Age checks for chat, Roblox Kids and Select, maturity labels, paid random items and chat changes |
| [[Regional Compliance - Paid Random Items and Country Rules]] | One fail-closed `PolicyService` gate and designing the restricted experience |
| [[Engine Limits, Quotas and Defaults - Cheat Sheet]] | The numbers people most often get wrong, from DataStores to terrain, in one place |
| [[Console and VR Release Checklists]] | What to check before enabling Xbox, PlayStation or VR, and after release |
| [[Photo Mode and In-Game Screenshots with CaptureService]] | Screenshots and shares players make inside your game, with a safe photo-mode camera |

## Suggested reading paths

- **New game preparing for launch:** Badges first (create them over several days before launch), then Invites, then Notifications. Pair with [[Launch Strategy - The First Two Weeks]] and [[First-Time User Experience and Onboarding]].
- **Live game that wants recurring revenue:** Subscriptions, then Notifications (a subscription with a reason to return renews better). Pair with [[Battle Pass and Season Design]], [[Economy Inflation Sinks and Faucets Math]] and [[Pricing and Store Design]].
- **Hangout, roleplay or trading game:** Social Surfaces, then Invites, then Commerce (the in-game avatar item route). Pair with [[Genre Playbook - Roleplay and Social Hangouts]], [[Trading Systems Without Duplication]] and [[AvatarEditorService and In-Game Avatar Editors]].
- **Large game with a brand:** Commerce, then Subscriptions. Pair with [[Working with Content Creators]] and [[Roblox Policies Ratings and Compliance]].

## Rules that apply to every note here

- **Prompt-finished events are not success signals.** Grant on a receipt, a status change, a paid cycle or a qualified arrival.
- **The server decides.** Launch data, block lists and "I earned this" messages are hints until validated ([[Server Authority and Validation]]).
- **Mind age and region gates.** Personalised notifications reach only users 13+; commerce only eligible US users. Players outside each gate still need a complete game.
- **Never gate progress** behind inviting, enabling notifications or subscribing ([[Ethical Design and Player Trust]]).

## Related sections
[[Multiplayer Services Start Here]] · [[Avatars and UGC Start Here]] · [[Live Ops Deep Dive Start Here]] · [[Community and Moderation Start Here]] · [[Marketing and Growth Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Official Docs - Monetization]] · Official Docs - Publishing and Live Ops · Refunds Chargebacks and Purchase Support · Live Ops Events and Updates · Discovery and the Algorithm
<!-- auto-links:end -->
