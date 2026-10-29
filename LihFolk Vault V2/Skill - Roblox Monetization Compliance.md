---
tags: [ai, agents, ai-skill, monetization, compliance, live-ops, type/guide, area/monetization, level/intermediate, area/ai]
---
# Skill - Roblox Monetization Compliance

**Skill file:** [skills/roblox-monetization-compliance/SKILL.md](../skills/roblox-monetization-compliance/SKILL.md) (folder name `roblox-monetization-compliance`)

## What it does

This skill makes an agent build or audit everything that takes Robux, with two goals: every purchase produces exactly one grant that survives crashes, and every purchase surface follows Roblox's rules. Policy facts are treated as "as of October 2026", and the skill tells the user to recheck official pages before shipping.

The agent:

1. Inventories every pass, product and subscription, and every random system, marking direct, indirect (Robux-buyable currency) and modifier money paths.
2. Checks developer products: one `ProcessReceipt`, a startup assert that every product has a grant, grant and `PurchaseId` in one write, `PurchaseGranted` only after saving, one-per-player rules at prompt time, a purchase log.
3. Checks game passes: a server ownership cache, retries instead of caching false on errors, benefits reapplied on spawn.
4. Checks prices: every on-screen price from `GetProductInfoAsync`, never hard-coded (regional pricing makes hard-coded labels wrong), and a comparison of the game's product list against the Creator Dashboard.
5. Checks paid random items: all outcomes with numerical odds summing to 100%, flattened from the same tables the server rolls, never showing a non-zero chance as 0%, a worded "Odds" control on every surface, live-updating odds for luck boosts and pity, and a chi-square test in CI.
6. Checks PolicyService: called on the server, failing closed, gating paid random items (`ArePaidRandomItemsRestricted`) and paid item trading (`IsPaidItemTradingAllowed`) in the server prompt path.
7. Checks other rules: no simulated gambling, questionnaire kept current, [[Creator Rewards]] instead of the retired Premium Payouts.

## When to use it

Adding a product, pass, shop, egg, crate or luck boost; a "paid and got nothing" report; or a pre-release compliance check.

## What it cannot confirm

It cannot see the Creator Dashboard. It asks you for the product list or for you to run the comparison, and it reports mismatches rather than guessing prices. Whether unprocessed receipts are refunded automatically after some days is unverified in the docs.

## Notes behind it

[[Monetization Overview]], [[Developer Products and ProcessReceipt]], [[Game Passes]], [[Pricing and Store Design]], [[Robux Price Points and Offer Design]], [[Paid Random Items and Odds Disclosure in Practice]], [[Roblox Policies Ratings and Compliance]], [[Refunds Chargebacks and Purchase Support]], [[Subscriptions and Premium Payouts]], [[Age Checks and Safety Features]], [[Purchase Data and Receipts]], [[Ethical Design and Player Trust]].

## Related

- [[AI Skills Start Here]]
- [[Skill - Roblox DataStore Safety]]
- [[Skill - Roblox UI Builder]] for shop screens

## Connected notes
<!-- auto-links:start -->
[[Shop with Game Passes and Developer Products End to End]] · [[Skill - Roblox System Builder]] · Official Docs - Monetization · Pity Timer · Genre Playbook - RNG and Collection Games
<!-- auto-links:end -->
