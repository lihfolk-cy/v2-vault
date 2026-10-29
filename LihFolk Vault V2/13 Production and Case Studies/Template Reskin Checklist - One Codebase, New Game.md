---
tags: [production, reskin, template, reuse, asset-ids, products, economy, qa, compliance, fast-ship, type/checklist, area/production]
---
# Template Reskin Checklist - One Codebase, New Game

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Copying the place into the old universe "temporarily".
> - Avoid: Template product IDs left in config. Purchases fail or route to the wrong game.
> - Avoid: Animations owned by a different group. Characters T-pose; no error in the output for players.
>
> Cost: TL;DR ~100 tok · whole note ~1.8k tok. Read more: ## 2. Money (second) · ## 3. Asset IDs and content · ## Common mistakes
<!-- tldr:end -->

Reskinning a proven codebase into a new game is how many small studios ship several titles a year. It is also how they ship someone else's product IDs, a broken economy tuned for a different theme, a DataStore that collides with the old game, and thumbnails that get flagged as misleading. This checklist is ordered by blast radius: identity and money first, art last.

Source labels: **Roblox docs**, **Rule of thumb**, **Unverified**.

## Before you start: is a reskin the right call?

A reskin works when the **loop** is what made the original succeed and the **theme** is replaceable. It fails when the new theme implies different verbs (a "pet" template reskinned as "cars" invites driving the player expects). Write one sentence each: what players do, and what fantasy the new theme promises. If those disagree, it is a new game, not a reskin.

Also check originality and IP: a reskin of your own template is fine; reskinning someone else's uncopylocked game, or copying another live game's art and names, risks takedowns. See [[Creator Store and Toolbox Safety]].

## 1. Identity and isolation (do first)

- [ ] **New universe**, not a new place in the old universe. DataStores, badges, products and analytics are per universe ([[Places Universes and Experience Settings]]).
- [ ] **DataStore names changed anyway**, and a version suffix added (`PlayerData_v1`). If anyone ever imports the place into the old universe by accident, distinct names prevent overwriting real player data.
- [ ] **No hard-coded universe, place or group IDs** left from the template. Grep for long numbers: `rg -n "\b\d{8,}\b" src/`.
- [ ] Teleport destinations and reserved-server place IDs point at the new universe.
- [ ] Open Cloud API keys, webhooks and external services re-issued for the new universe, with old keys not reused ([[Open Cloud APIs]]).
- [ ] Group ownership decided (which group owns the new game, who has edit access); see [[Groups Roles and Permissions for Studios]].

## 2. Money (second)

- [ ] **Every game pass and developer product recreated** in the new universe. Product and pass IDs are per universe; IDs copied from the template will prompt purchases that either fail or credit the old game.
- [ ] A single product config module maps logical names to IDs; the template's IDs are removed, not commented out.
- [ ] `ProcessReceipt` handler maps every new product; an unknown product returns `NotProcessedYet` and logs, rather than granting nothing silently ([[Developer Products and ProcessReceipt]]).
- [ ] Prices reviewed for the new audience and economy, not copied ([[Robux Price Points and Offer Design]]).
- [ ] Subscriptions, if any, recreated and their benefit descriptions rewritten ([[Subscriptions and Recurring Revenue]]).
- [ ] Paid random items: odds tables re-derived from the new roll tables and disclosed; `PolicyService` gating still wired ([[Paid Random Items and Odds Disclosure in Practice]]).
- [ ] Studio test purchases run for **every** product in the new universe.

## 3. Asset IDs and content

- [ ] Every `rbxassetid://` in code, config and instances inventoried. A quick command-bar sweep in Studio lists `Image`, `Texture`, `SoundId`, `MeshId`, `AnimationId` properties and their values.
- [ ] Animations re-uploaded or owned by the new game's owner. **Animations only play in games owned by the same user or group that owns the animation** (Roblox docs, animation permissions); a reskin moved to a different group will have silent T-poses ([[Animation Asset Permissions and Groups]]).
- [ ] Audio permissions checked for the same reason; private audio uploaded by another account will not play.
- [ ] Badges recreated; badge award code points at new IDs ([[Badges and Achievement Design]]).
- [ ] Old theme's text strings, item names and lore replaced, including localisation tables ([[Localization]]).
- [ ] Old theme assets deleted from the place, not just hidden. Unused assets cost place size and load time ([[Case Study - Instance Cleanup and Place Size]]).

## 4. Economy re-tune

A new theme changes perceived value. Coins that felt fine as "seeds" may feel stingy as "diamonds".

- [ ] Progression curve re-simulated, not assumed ([[Simulating an Economy Before Launch]]).
- [ ] First-session pacing re-timed with a stranger playtest: first reward, first upgrade, first unlock.
- [ ] Rarity ladder and drop pacing match the new collection size ([[Rarity Ladders and Drop Pacing Math]]).
- [ ] Codes from the template removed; new codes created ([[Codes Redemption System End to End]]).

## 5. Compliance and store

- [ ] Content maturity questionnaire completed for the **new** content. A cute template reskinned as horror changes the answers (Roblox docs, content maturity page).
- [ ] If the new game has AI features, the questionnaire's AI interaction answers updated ([[Roblox Policies on AI-Generated Content]]).
- [ ] Icon, thumbnails, video thumbnails and description show the new game only. Template screenshots are misleading content.
- [ ] Title and description written fresh; avoid near-duplicate descriptions across your games ([[Thumbnails Icons and Store Page]]).

## 6. What must be re-tested (even if the code did not change)

Code that "did not change" still runs against new data and new IDs.

- [ ] New player join, save, leave, rejoin; server shutdown save.
- [ ] Every purchase, including failed and cancelled prompts.
- [ ] Every teleport.
- [ ] Every animation and sound plays (permissions).
- [ ] Remote validation still matches new item IDs and limits.
- [ ] Performance with the new art on a low-end phone (new meshes and textures change memory).
- [ ] Analytics events arrive in the new universe's dashboard with new item names.

## Common mistakes

- **Copying the place into the old universe "temporarily".** One wrong publish overwrites a live game; use a new universe from minute one.
- **Template product IDs left in config.** Purchases fail or route to the wrong game.
- **Animations owned by a different group.** Characters T-pose; no error in the output for players.
- **Same economy numbers across themes.** Perceived value changes; re-time the first session.
- **Template thumbnails or descriptions.** Misleading store content and confused players.
- **Old DataStore names.** Risk of colliding with or reading the template's test data.

## See also

- [[Packages and Shared Assets Across Places]]
- [[Packages and Asset Reuse]]
- [[LihFolk Systems Library]]
- [[Release Process and Rollbacks]]
- [[QA Checklists Before Release]]

## Connected notes

[[Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev]] · [[Animation Asset Permissions and Groups]] · Developer Products and ProcessReceipt · Places Universes and Experience Settings

<!-- related:start -->
## Related
[[Scoping and Roles for Small Teams]] · [[Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts]] · [[Live Incident Response and Post-Mortems]] · [[Planning and Scoping a Roblox Game]] · [[Documentation and Knowledge Bases]] · [[Lessons Learned Index]] · [[Asset Pipelines]] · [[Safe Changes in a Shared Place]]
<!-- related:end -->
