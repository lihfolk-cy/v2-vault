---
name: roblox-monetization-compliance
description: 'Game passes, dev products, ProcessReceipt, prices, eggs and luck boosts under 2026 odds rules. Use when adding or auditing purchases, or "paid and got nothing".'
---
# LihFolk Monetization Compliance

Two goals: every Robux spent produces exactly one grant that survives crashes, and every purchase surface follows Roblox's rules on prices, paid random items and restricted players. Policies change; treat every policy fact here as "as of October 2026" and tell the user to recheck the official pages before shipping.

## Inputs

- `VAULT`: LihFolk Vault V2, the knowledge base in the plugin root's `LihFolk Vault V2/` folder: `<base directory>/../../LihFolk Vault V2`, where the base directory is the one Claude Code shows when this skill loads. Resolve it to an absolute path before any Read, Grep or command (the vault is in the plugin, not the user's project). Start with `VAULT/INDEX.md` to find notes fast.
- The receipt handler, pass ownership code, shop UI, any random-outcome systems, and the product and pass list from the Creator Dashboard if the user can provide it.

## Procedure

1. **Inventory the money paths.** List every pass, product and subscription with its id, key, grant and the UI surfaces that prompt it. Then list every random system and mark how money reaches it: directly (Robux egg), indirectly (currency that can be bought with Robux) or via a modifier (paid luck boost, pity, drop-rate boosts). Indirect paths count: a currency-priced egg is a paid random item if that currency can be bought with Robux.

2. **Developer products and `ProcessReceipt`.**
   - Exactly one `ProcessReceipt` assignment in the codebase. Grep it. A second assignment silently replaces the first, and that system's products never grant.
   - Dispatch by product key. Assert at startup that every configured product has a grant function.
   - Wait for the player's profile. If the player is gone or the profile cannot be saved, return `NotProcessedYet`.
   - Write the grant and the `PurchaseId` marker in the same saved document, in one write, then return `PurchaseGranted` only after that save succeeded.
   - Grant functions are pure and never yield inside `UpdateAsync`.
   - Never grant from `PromptProductPurchaseFinished` or a client remote.
   - Enforce one-per-player rules at prompt time, not at receipt time (refusing a paid receipt leaves it stuck).
   - Retired products keep their grant code forever.
   - Keep a purchase log: purchase id, product key, real Robux spent, grant contents, time. Support, refunds and data resets depend on it.
   - Docs publish no retry schedule and no automatic refund deadline for unprocessed receipts; community claims of refunds after a few days are unverified. Design as if an unprocessed receipt waits for the player's next visit.

3. **Game passes.**
   - One server ownership cache, filled on join with `UserOwnsGamePassAsync` and updated on purchase. Do not call it per hit or per frame.
   - If the ownership check fails, retry; never cache "false" from an error.
   - Reapply character benefits on every spawn.
   - Pass ids are per experience. Cross-game pass and product sales ended May 30, 2026 (vault, as of October 2026).
   - Never sell a consumable as a pass.

4. **Prices.**
   - Every price shown on screen comes from `MarketplaceService:GetProductInfoAsync` at runtime, never a hard-coded number. Regional pricing means hard-coded labels show the wrong amount while Roblox charges the correct one. Roblox's Dynamic Price Check tool flags mismatches.
   - Ask the user to compare the configured product list against the Creator Dashboard: ids, names and prices. Report every product the game prompts that is missing from the dashboard and every dashboard product with no grant.
   - "X% off" labels and bonus amounts are computed from real values, never typed by hand. Every timer is real.

5. **Paid random items.** For every random system reached by money:
   - Show all possible outcomes and their actual numerical odds before purchase, as percentages summing to 100%.
   - Flatten tier odds into final-outcome odds from the same tables the server rolls. One source of truth: the display and the roll call the same function.
   - Rounding: allowed to four or more places below the first non-zero digit, with a disclaimer. Never display a non-zero chance as 0%.
   - Put the odds behind a control labelled with a word ("Odds", "Details"), not a bare (i) icon, on every purchase surface: shop cards, pop-ups, in-world egg prompts, paid-currency confirmations.
   - Once-per-user outcomes: show that user's updated remaining odds; zero out empty tiers.
   - Modifiers (luck, pity, boosts) explain their effect numerically before purchase, show before and after, respect caps in the preview, disable at the cap, and update displayed odds live while active.
   - Recommend a chi-square test in CI that rolls each table and modifier state and compares with the displayed odds.
   - Rewards earned without Robux or paid currency are exempt.

6. **PolicyService.**
   - Call `PolicyService:GetPolicyInfoForPlayerAsync` on the server, in `pcall`, with retries. Fail closed: if it errors, treat the player as restricted.
   - If `ArePaidRandomItemsRestricted` is true, give a compliant alternative or keep the player away from the paid random item. Enforce in the server prompt path, not only in UI.
   - Gate trading of paid items on `IsPaidItemTradingAllowed`.
   - Replicate results as attributes for UI.

7. **Other rules to check.** No simulated gambling (coin flips, double-or-nothing), even for free currency. The Maturity and Compliance Questionnaire is complete and resubmitted after content changes. Subscription benefits are the same on every platform. Premium Payouts were replaced by Creator Rewards in July 2025; do not plan revenue around them. Revenue projections use the creator share and regional factors from the vault notes, not list prices.

8. **Report.** Group findings as: reliability (lost or double grants), price display, odds disclosure, restricted players, other policy. Each finding names the file, the surface and the fix.

## Hard rules

- Grants only in `ProcessReceipt` (products) or the server ownership cache (passes).
- No hard-coded prices.
- No paid random item without full numerical odds on every surface, drawn from the roll tables.
- PolicyService failures fail closed.
- Never ask players for account details in support flows; date, time and product name are enough.

## Checks before finishing

- [ ] One `ProcessReceipt`; startup assert covers every product.
- [ ] Grant and `PurchaseId` saved together; `PurchaseGranted` after save.
- [ ] Pass ownership cached server-side; errors retried.
- [ ] All prices from `GetProductInfoAsync`; dashboard comparison requested or done.
- [ ] Every paid random system disclosed, flattened, labelled, live-updating.
- [ ] Restricted players gated on the server with an alternative.
- [ ] Policy facts flagged as "as of October 2026".

## Read these vault notes

- `11 Monetization Publishing and Live Ops/Monetization Overview.md`
- `11 Monetization Publishing and Live Ops/Developer Products and ProcessReceipt.md`
- `11 Monetization Publishing and Live Ops/Game Passes.md`
- `11 Monetization Publishing and Live Ops/Pricing and Store Design.md`
- `11 Monetization Publishing and Live Ops/Robux Price Points and Offer Design.md`
- `11 Monetization Publishing and Live Ops/Paid Random Items and Odds Disclosure in Practice.md`
- `11 Monetization Publishing and Live Ops/Roblox Policies Ratings and Compliance.md`
- `11 Monetization Publishing and Live Ops/Refunds Chargebacks and Purchase Support.md`
- `11 Monetization Publishing and Live Ops/Subscriptions and Premium Payouts.md`
- `11 Monetization Publishing and Live Ops/Age Checks and Safety Features.md`
- `04 Data and Persistence/Purchase Data and Receipts.md`
- `22 Anti-Exploit and Security/Economy Exploits - Dupes Races and Purchase Abuse.md`
- `10 Game Design and Genres/Ethical Design and Player Trust.md`
