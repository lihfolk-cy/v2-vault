---
tags: [delta, platform-features, changelog, deprecations, policy, monetization, discovery, engine, ai-context, type/guide, area/platform, level/intermediate]
verified: 2026-10-28
---
# Roblox Changes 2025-2026

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Treating "deprecated" as "removed". Most 2026 deprecations (Async renames, `Enum.Font`) still run.
> - Avoid: Treating a beta as shipped. As of 2026-10-28, Script Sync, StyleQuery and Styling Transitions were still Studio betas, and...
> - Avoid: Trusting a planned date. Several rollouts slipped or were reverted (the first physics replication rollout was rolled back in...
> - New code uses the `Async` names from the rename list.
> - Game has completed the maturity questionnaire (unrated games are unplayable).
> - Any paid random item shows numerical odds for every outcome before purchase.
>
> Cost: TL;DR ~190 tok · whole note ~1.9k tok. Read more: ## The ten changes most likely to break generated code · ## Child notes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

This hub lists what changed on Roblox between January 2025 and late October 2026 that a capable developer or a strong AI model trained before mid-2025 is likely to miss. It is a delta, not a tutorial: each child note says what changed, when, what code or behaviour must change, and gives a short migration snippet. The numbers are also in machine-readable form in `_data/roblox_facts_2026.json`.

## Trust labels used in this set

| Label | Meaning |
|---|---|
| **Roblox docs** | Creator Hub documentation, or an official Roblox staff announcement on the DevForum or newsroom. The note gives the URL and the post date |
| **Reported** | Third-party press, community threads or creator reports. Plausible, not confirmed by Roblox |
| **Measured** | Observed in the LihFolk reference project |
| **Unverified** | Could not be confirmed at the time of writing. Check before relying on it |

All dates are post dates or stated effective dates. "As of 2026-10-28" means the state on the day this set was checked.

## The ten changes most likely to break generated code

1. **Yielding methods renamed with `Async`** (January 14, 2026). `GetProductInfo`, `LoadCharacter`, `AwardBadge`, `IsInGroup`, `ReserveServer` and 41 others have `Async` names. Old names still work but are flagged deprecated. See [[Engine and API Changes 2025-2026]].
2. **Server Authority is fully released** (July 9, 2026). Opt in with `Workspace.AuthorityMode = Server`. That setting forces StreamingEnabled, deferred signals, fixed simulation, Next Generation Replication and the Input Action System player scripts. Simulation code moves into `RunService:BindToSimulation`. See [[Server Authority and Input Migration 2026]].
3. **The Input Action System is fully released** (June 11, 2026), and the default player scripts are being converted. `PlayerScriptsUseInputActionSystem` defaults to on in early 2027 (planned) and the property is removed in mid 2027 (planned). Code that reaches into `PlayerModule:GetControls()` will break.
4. **Property updates are not ordered against RemoteEvents** under Next Generation Replication. Code that fires a remote "after" setting a property and assumes the client sees the property first is wrong.
5. **TextChatService lockdown** (announced October 21, 2026). `TextChatMessage.Text` will return an empty string to scripts, `OnIncomingMessage` and `Player.Chatted` are unsupported for custom moderation, and custom chat UI must move to `TextChannelWindow`. Automatic opt-in February 2027, mandatory May 2027. See [[Policy and Age Rules 2026]].
6. **DataStore limits are per experience and shared with Open Cloud** (live July 29, 2026). Storage is 500 MB + 1 MB per lifetime player. See [[Data and Cloud Changes 2025-2026]].
7. **Paid random items need numerical odds for every outcome, before purchase**, including luck boosts and indirect purchases (Community Standards update May 26, 2026).
8. **Age-checked chat and age-tiered accounts.** Chat requires an age check worldwide (January 2026). Roblox Kids (5-8) and Roblox Select (9-15) see only games that pass a selection process. Games with no maturity questionnaire are unplayable for everyone.
9. **Mesh streaming and cloud LoDs** replace `MeshPart.RenderFidelity`, which is ignored when `Workspace.MeshStreamingAndImprovedLoDs` is on and is planned for removal. **4096 x 4096 textures render in live games** (January 30, 2026).
10. **Money changed.** Roblox Plus replaced Premium for new subscribers (April 30, 2026). [[Creator Rewards]] replaced Premium Payouts (July 24, 2025). The standard DevEx rate is $0.0038 per Robux (September 5, 2025), and a US 18+ rate of $0.0054 applies from June 8, 2026. Regional pricing is on by default for passes (March 30, 2026). See [[Discovery and Monetization Changes 2025-2026]].

## Child notes

| Note | Covers |
|---|---|
| [[Engine and API Changes 2025-2026]] | Async renames, mesh streaming, 4K textures, fonts, new type solver, UI styling, Character Controller Library, SLIM, frustum streaming, custom terrain materials, Script Sync status, smaller deprecations |
| [[Server Authority and Input Migration 2026]] | Server Authority, Next Generation Replication, physics replication rewrite, Input Action System, player-script conversion, with migration code |
| [[Policy and Age Rules 2026]] | Age checks, Kids and Select, maturity labels and feature age limits, paid random items, TextChatService lockdown, Terms of Use |
| [[Discovery and Monetization Changes 2025-2026]] | Recommended For You on 28-day retention, thumbnail eligibility, DevEx rates, Creator Rewards, Roblox Plus, regional pricing, Creator Store USD sales |
| [[Data and Cloud Changes 2025-2026]] | DataStore per-experience limits and storage, Open Cloud unification, deprecated web endpoints, rate-limit tuning, Luau Execution |

## How to use this set

- Before writing Roblox code from memory, check the deprecated-to-replacement map in `_data/roblox_facts_2026.json` (`deprecated_api_map`).
- Before quoting a limit (DataStore budgets, texture size, attribute counts), take the number from the JSON, not from training data.
- For the mistakes models make even with current APIs, see [[What AI Models Get Wrong in Roblox]].

## Common mistakes

- Treating "deprecated" as "removed". Most 2026 deprecations (Async renames, `Enum.Font`) still run. Write the new name in new code; do not mass-rewrite working code under time pressure.
- Treating a beta as shipped. As of 2026-10-28, Script Sync, StyleQuery and Styling Transitions were still Studio betas, and Next Generation Replication on its own was not generally released.
- Trusting a planned date. Several rollouts slipped or were reverted (the first physics replication rollout was rolled back in May 2026; the mesh streaming default was planned for about July 2026 and its status was unconfirmed in October).
- Quoting old money rules: Premium Payouts, the $0.0035 DevEx rate, the "10% Premium Robux bonus".

## Checklist

- [ ] New code uses the `Async` names from the rename list.
- [ ] Game has completed the maturity questionnaire (unrated games are unplayable).
- [ ] Any paid random item shows numerical odds for every outcome before purchase.
- [ ] All user-to-user text goes through TextChatService; non-chat text inputs are rate-limited to 1 per minute.
- [ ] No script relies on `MeshPart.RenderFidelity` or reads `TextChatMessage.Text` for moderation.
- [ ] Custom input code tested with `PlayerScriptsUseInputActionSystem = Enabled` before early 2027.
- [ ] Game has a custom thumbnail (required for Home recommendations since October 19, 2026).

## See also

- [[What AI Models Get Wrong in Roblox]]
- [[Platform Features Start Here]]
- [[Roblox Policies Ratings and Compliance]]
- [[Discovery and the Algorithm]]
- [[DataStore Fundamentals]]
- [[Server Authority and Validation]]

<!-- related:start -->
## Related
[[AI Pitfalls - Stale APIs and Luau]] · [[AI Pitfalls - Data and Monetization]] · [[Regional Compliance - Paid Random Items and Country Rules]] · [[Console and VR Release Checklists]] · [[Commerce and Physical Goods]] · [[Subscriptions and Recurring Revenue]] · [[Badges and Achievement Design]] · [[Experience Notifications and Return Prompts]] · [[Avatar Context Menus Profiles and Social Surfaces]] · [[Friend Invites Referrals and Experience Invites]]
<!-- related:end -->
