---
tags: [worked-build, library, drop-in, luau, strict, datastore, remotes, monetization, odds, policyservice, testing]
---
# LihFolk Systems Library

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Installing next to an existing data module -> migrate to one writer before shipping
> - Avoid: Leaving an old `ProcessReceipt` assignment -> grep `ProcessReceipt`; keep `Receipts.Start` only
> - Avoid: Using a per-system example and Main together -> one bootstrap only
> - One data writer, one `ProcessReceipt`, one server Script, one remote creator.
> - Config asserted at startup without errors (Output is clean on Play).
> - Paid currencies, paid modifiers and restricted alternatives set.
>
> Cost: TL;DR ~170 tok · whole note ~2.4k tok. Read more: ## 2. What is in it · ## 3. Install and wiring order · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The LihFolk Systems Library is a set of drop-in, strict Luau modules (data, remotes, currency, shop, receipts, inventory, eggs, codes, daily rewards, rebirth, quests, leaderboards) that agents install and configure instead of writing these systems from scratch. The Worked Builds in this folder teach each system end to end; the library is the same knowledge packaged as reusable modules with one shared data layer, one remote layer and one receipt router, so a game built from several systems still has exactly one of each.

Skill file: [skills/lihfolk-systems/SKILL.md](../../skills/lihfolk-systems/SKILL.md). Command: `/lihfolk:new-system <system>`.

**Trust label:** all library code is **reviewed, not run** in Studio. It passed a structural checker (blocks, brackets, string interpolation, deprecated APIs), parsed with zero syntax errors in Roblox LSP, and built into a place with Rojo 7.7. Its 18 spec modules have not been executed. API facts are Roblox docs (as of October 2026); policy facts must be rechecked before shipping.

---

## 1. Why a library and not more worked builds

Experienced developers and strong models write plausible systems quickly. The bugs that survive review are rarely syntax; they are invariants:

| Invariant | Typical generated bug | Library answer |
|---|---|---|
| One server owns a profile | `GetAsync` then `SetAsync`, no lease | lease + token fence inside `UpdateAsync` (rule of thumb from [[Session Locking and Profile Libraries]]) |
| A failed load never saves | `pcall` error treated as a new player | `ready` / `locked` / `failed` / `corrupt` / `newer` are distinct; only `ready` can save |
| A receipt grants once | grant, then save, then forget the `PurchaseId` | grant + `PurchaseId` + log in one document and one write; `PurchaseGranted` after the save |
| Displayed odds equal rolled odds | separate display table, tier odds shown | one `computeFinals` feeds the roll and the odds panel |
| Restricted players stay out | `PolicyService` checked in UI only, or fail open | server prompt path, fail closed, two separate gates |
| Remotes are hostile | `tonumber(x)` and hope | rate limit, arg count, type and range before the handler |

Writing these once, testing the pure parts, and reusing them is cheaper than re-deriving them per game.

## 2. What is in it

| Module | Side | Job |
|---|---|---|
| Signal, Janitor | shared | events and cleanup, dependency-free |
| RateLimit | shared | token bucket per player, cleared on leave |
| Net | shared | creates every remote; validators `T.integer`, `T.string`, `T.key`, `T.guid`, `T.array`...; violation scoring |
| Odds | shared | flatten tiers, pick with a safe tail, format percentages, pity maths, chi-square |
| Feedback | client | result codes to kind messages |
| PlayerData | server | session-locked profiles with slices, migrations, autosave, BindToClose, idempotent purchases |
| Policy | server | PolicyService cache: `CanBuyPaidRandom`, `CanTradePaid`, fail closed |
| Currency | server | whole-number balances below 2^53, earn multipliers, paid flag per currency |
| Inventory | server | stacks and GUID uniques with `Paid` provenance, equip, trade gate |
| Rewards | server | one reward format (currency, item, bundle) with `CanGrant` then `Grant` |
| Receipts | server | the only `ProcessReceipt`; data or custom grants; prompt checks |
| Shop | server | soft-currency buys, product prompts with policy and limits, pass ownership cache |
| EggHatch | server | weighted eggs, hard pity, luck sources and timed boosts, once-items, live odds, boost preview |
| Codes | server | normalised codes, expiry, one use per player, miss lockout |
| DailyRewards | server | UTC-day streak with grace, server countdown |
| Rebirth | server | closed-form geometric bulk cost, earn multiplier |
| Quests | server | data-defined quests, server-reported progress, claims |
| Leaderboard | server | ordered stores on a budget, monotonic writes, weekly stores, log encoding |

## 3. Install and wiring order

```
ReplicatedStorage/LihFolk/          Signal Janitor RateLimit Net Odds Feedback
ReplicatedStorage/LihFolkConfig     display-safe config
ServerScriptService/LihFolk/        PlayerData Policy Currency Inventory Rewards Receipts Shop
                                    EggHatch Codes DailyRewards Rebirth Quests Leaderboard
ServerScriptService/Main            the only server Script
ServerScriptService/LihFolkTests/   Runner + *.spec
ServerStorage/LihFolkSecrets        codes
```

`Main` runs: `PlayerData.Configure` -> `Policy.Init` -> each service's `Init(config)` (registers its profile slice and its remotes) -> cross-module hooks -> `Receipts.Start` (asserts every product has a grant, then assigns `ProcessReceipt`) -> `PlayerData.Start` (loads players last, so every slice exists). The skill's `default.project.json` maps this tree for Rojo.

**Profile slices.** Services do not edit a central template. Each calls `PlayerData.RegisterSlice(name, makeDefault)` before `Start`; the template is the union of slices, reconciled into old profiles on load. `makeDefault` must return a new table each call (asserted). Renames and type changes still go through numbered migrations ([[Data Schema Design and Migrations]]).

## 4. Configuration rules that carry policy weight

- **Paid currencies.** Set `paid = true` on any currency Robux can buy, directly or through a bundle. Anything random priced in it becomes a paid random item ([[Paid Random Items and Odds Disclosure in Practice]], Roblox docs as of October 2026).
- **Product and pass ids** stay `0` until the user supplies real ones; id 0 is never prompted. Prices are never configured: the client shows `GetProductInfoAsync` (regional pricing).
- **Paid modifiers.** Luck passes and boost products are flagged (`paidModifier`, `paidRandom`, luck source `paid = true`). Restricted players neither buy them nor receive their effect, and their displayed odds use the same reduced luck.
- **Restricted alternative.** Each paid egg has a `restrictedNote`; the example config gives the paid egg's rare pet as a free quest reward (a free earnable path, one of the documented alternatives).

## 5. Testing

Specs are TestEZ-style (`describe`, `it`, `expect(...).to.equal`), exercise only pure logic, and run with the bundled runner from the command bar: `require(game.ServerScriptService.LihFolkTests.Runner)()`. They cover validators, rate limiting, odds flattening and formatting, a chi-square roll test, pity, migrations and reconcile, unsavable values, bounded receipts, the purchase idempotency core (grant once, duplicate, failed save then redelivery), currency maths, inventory checks, day maths, rebirth bulk maths against brute force, quest progress, week indices and policy interpretation. The Play tests from [[Saved Inventory End to End]] still apply: persistence, `TestProfileKey`, `SimulateLoadFailure`, lock contention, two clients, `ForceRestrictedPolicy`, remote fuzzing ([[Testing Your Own Remotes - Fuzzing and Abuse Tests]]).

## 6. What it deliberately leaves out

Combat ([[Melee Combat System End to End]]), player trading (use `Inventory.CanTrade` on both sides plus a ledger, [[Trading Systems Without Duplication]]), live codes and global code limits ([[Codes Redemption System End to End]]), UI art ([[Worked Builds Start Here]] notes build UI in code; use the LihFolk UI skills for production UI).

---

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Installing next to an existing data module | two modules call `UpdateAsync` on player keys | migrate to one writer before shipping |
| Leaving an old `ProcessReceipt` assignment | some products never grant | grep `ProcessReceipt`; keep `Receipts.Start` only |
| Using a per-system example and Main together | "remote declared twice" at startup | one bootstrap only |
| Leaderboard `source` calling `PlayerData.Get` | final write on leave never happens | read the profile argument |
| Currency sold for Robux left `paid = false` | eggs priced in it skip the policy gate | mark it paid |
| Prompting products with `id = 0` | prompt silently does nothing | fill ids from the Creator Dashboard |
| Calling the code "tested" | no Runner output in Studio | keep "reviewed, not run" until the specs pass |

## Checklist

- [ ] One data writer, one `ProcessReceipt`, one server Script, one remote creator.
- [ ] Config asserted at startup without errors (Output is clean on Play).
- [ ] Paid currencies, paid modifiers and restricted alternatives set.
- [ ] Real product and pass ids, no hard-coded Robux prices.
- [ ] Labelled "Odds" control on every purchase surface for eggs and boosts.
- [ ] Runner reports 0 failures in Studio; Play tests done.
- [ ] Scored with the system rubric, 8.5 or higher, logged.

## See also
[[LihFolk Systems - Data and Purchase Guarantees]] · [[Worked Builds Start Here]] · [[Saved Inventory End to End]] · [[Shop with Game Passes and Developer Products End to End]] · [[Pet Hatching and Following End to End]] · [[Session Locking and Profile Libraries]] · [[Developer Products and ProcessReceipt]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Roblox Policies Ratings and Compliance]] · [[Rate Limiting and Abuse Prevention]] · [[Automated Testing with TestEZ and Jest-Lua]]
