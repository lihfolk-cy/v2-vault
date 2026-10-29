---
tags: [gameplay, economy, currency, sinks, faucets, inflation, analytics, type/guide, area/gameplay, level/intermediate, api/AnalyticsService, area/economy]
---
# Economies and Currencies

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Fixed rewards in an exponential game -> Scale to next price
> - Avoid: Prices tuned item by item -> One income model
> - Avoid: Too many currencies -> Merge or remove
> - Each currency has listed faucets and sinks per stage.
> - Prices and rewards derived from an income model.
> - All transactions server-side, validated, non-yielding, logged.
>
> Cost: TL;DR ~130 tok · whole note ~3.6k tok. Read more: ## 2. Faucets and sinks · ## 3. Transactions on the server · ## 8. Common mistakes · ## Checklist
<!-- tldr:end -->

An in-game economy is a set of currencies, the **faucets** that create them, the **sinks** that destroy them, and the prices that connect the two to progression. A good one keeps every player near a meaningful purchase, survives a million-fold growth in income, resists duplication exploits, and can be rebalanced without wiping saves. This note covers currency design, faucet/sink accounting, exponential economies, server-side transactions, analytics and the rebalancing lessons of one production game whose cash went from thousands to hundreds of millions per gate.

Monetisation (Robux, passes, products) is covered in [[Monetization Overview]], [[Developer Products and ProcessReceipt]] and [[Game Passes]]. Pricing of unlocks: [[Progression Levels and Unlocks]].

Source labels: **Docs** (AnalyticsService reference, checked October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. Kinds of currency

| Kind | Example | Earned by | Spent on | Notes |
|---|---|---|---|---|
| Soft currency | Cash, coins | Kills, idle income, quests | Gates, upgrades, forge | Inflates; the main progression clock |
| Premium currency | Gems | Small free drips, Robux | Rerolls, convenience, cosmetics | Keep scarce; tie to Robux value carefully |
| Materials | Ores, crystals by tier | Drops, salvage | Crafting, forge | Tiered by zone; gate deeper content |
| Event currency | Tokens | Event activities | Event shop | Expires or converts after the event |
| Meta points | Quest points | Quests | A reward track | Never purchasable |
| Prestige count | Rebirths | Rebirthing | Requirements, multipliers | A currency you cannot spend, only reach |

**Measured** in the reference project: cash (soft), gems (premium, also earned: +5 for the tutorial dash step, daily rewards, +25 per day with VIP), nine forge materials by tier, quest points on a weekly track, rebirths, and weapon fragments.

Rules of thumb:
- **Fewer is better.** Each currency needs UI, sources, sinks, save fields, analytics and balance. Add one only if it creates a decision existing ones cannot.
- **Materials gate breadth, cash gates depth.** Tiered materials make deeper zones necessary for higher upgrades without exponential cash numbers doing all the work.
- **Premium currency must have free sources** so free players see its value, but small enough that buying still matters.

---

## 2. Faucets and sinks

Write the economy down as flows per minute of play at each stage.

| Faucets (create) | Sinks (destroy) |
|---|---|
| Enemy kills (cash, materials) | Zone gates |
| Passive income from equipped items | Skill tree nodes |
| Quest rewards (scaled to next gate price) | Forge levels |
| Daily rewards, chests, codes | Rerolls, crafting fees |
| Selling items | Rebirth (resets cash) |
| Robux purchases (cash packs) | Cosmetics |

An economy **inflates** when faucets outgrow sinks: prices feel trivial, rewards stop mattering, the only goal left is the next big number. Sinks that scale with income (rebirth resets, percentage costs, upgrades priced in minutes of income) keep currency meaningful.

### Exponential economies
Simulators and RNG games grow income exponentially with progress. The reference project's gate prices ran from $2.5K at the first gate to hundreds of millions in the tenth, with income from roughly 2K per minute in zone 1 to 40M at the final boss (see [[Progression Levels and Unlocks]] section 3). In such economies:
- Price in **minutes of income at the stage where the item unlocks**.
- Rewards scale too: a daily quest that pays a fixed 1,000 cash is worthless at zone 9. The reference project's quests pay a share of the *next gate's* price.
- Old content's rewards become irrelevant by design; make sure players are pulled forward, not stuck farming early zones.
- Display with suffixes and stable decimals (a count-up animation that switches units mid-way looks broken; the reference project's count-up shows every in-between value in the final value's unit).

---

### Sinks that feel good
Players resent sinks that only take ("repair costs", "tax") and enjoy sinks that turn currency into visible power or identity. Rank sinks by how they feel:

| Sink | Feel | Notes |
|---|---|---|
| Unlocking a new zone | Excellent | The core goal; price as the "big" purchase of each stage |
| Permanent upgrades (skill nodes, forge levels) | Good | Visible numbers going up |
| Rebirth | Good if celebrated | Destroys the most currency of any sink; must feel like a reward |
| Consumables (potions, boosts) | Neutral | Repeatable; good for late-game surplus |
| Rerolls and convenience | Neutral | Small premium sinks |
| Maintenance (repairs, upkeep) | Poor | Avoid in casual Roblox audiences |

A late-game player with nothing to buy will either quit or become a farmer whose only goal is leaderboards. Always have a repeatable sink with escalating returns available at the top (consumables, prestige, cosmetic tiers).

### Premium currency exchange rates
If premium currency can be bought with Robux and also earned, fix an internal value ("1 gem = about N Robux") and keep every gem price and gem reward consistent with it. Common mistakes are free gem sources so generous that the store is pointless, or gem prices for convenience so high that free players never see the store. The reference project's gem uses (quest rerolls at 15 and 40 gems, daily VIP bonus of 25) are small, repeatable decisions, which is the healthy range for a soft premium currency. Never sell premium currency packs whose value differs from how the same gems are priced elsewhere without making that obvious; players compare. Store pricing details: [[Pricing and Store Design]].

### Converting between currencies
One-way conversions (sell items for cash, salvage items into materials) are safe. Two-way exchanges (cash to materials and back) create arbitrage loops: if any route returns more than it costs, players and bots find it within days. If you must allow both ways, put a spread on every exchange (sell for 50 to 70% of buy price) and log volumes.

## 3. Transactions on the server

Every currency change is a server transaction on the player's profile. The rules (see also [[Server Authority and Validation]]):

```lua
--!strict
-- ServerScriptService/Wallet (ModuleScript)
local AnalyticsService = game:GetService("AnalyticsService")

export type Profile = { Cash: number, Gems: number, [string]: any }

local Wallet = {}

local function valid(n: number): boolean
	return n == n and n >= 0 and n < math.huge
end

-- Spend: check and deduct in one non-yielding step. Returns false if unaffordable.
function Wallet.spend(player: Player, profile: Profile, currency: "Cash" | "Gems", amount: number, sku: string): boolean
	if not valid(amount) then return false end
	local balance = profile[currency] :: number
	if balance < amount then return false end
	profile[currency] = balance - amount
	pcall(AnalyticsService.LogEconomyEvent, AnalyticsService, player,
		Enum.AnalyticsEconomyFlowType.Sink, currency, amount, profile[currency],
		Enum.AnalyticsEconomyTransactionType.Shop.Name, sku)
	return true
end

function Wallet.grant(player: Player, profile: Profile, currency: "Cash" | "Gems", amount: number, source: string)
	if not valid(amount) then return end
	profile[currency] = (profile[currency] :: number) + amount
	pcall(AnalyticsService.LogEconomyEvent, AnalyticsService, player,
		Enum.AnalyticsEconomyFlowType.Source, currency, amount, profile[currency],
		Enum.AnalyticsEconomyTransactionType.Gameplay.Name, source)
end

return Wallet
```

Notes:
- `LogEconomyEvent(player, flowType, currencyType, amount, endingBalance, transactionType, itemSku, customFields?)`; amount positive, ending balance zero or more; transaction type passed as the enum item's `Name` (Docs). The docs list per-experience limits: 5 currency types, 20 transaction types, 100 item SKUs. `AnalyticsEconomyTransactionType` members are `IAP`, `Shop`, `Gameplay`, `ContextualPurchase`, `TimedReward` and `Onboarding` (Docs); use `TimedReward` for daily rewards and `Onboarding` for tutorial grants so dashboards separate them.
- Wrap analytics in `pcall`: telemetry must never block a purchase.
- **Never yield between check and deduct.** A yield lets a second request spend the same balance.
- **Validate numbers.** NaN passes `typeof(x) == "number"` and fails every comparison; `x ~= x` catches it.
- **Mirror to the client** for display (an attribute or the owner-only state channel); the client copy is never read back.
- **Multipliers in one place.** Cash multipliers (VIP x2 in the reference project, potions, a weapon trait +20%, rebirth multiplier) are applied by one function so they stack predictably and appear in one tooltip.

### Robux purchases that grant currency
Grant currency for developer products only inside `ProcessReceipt`, record the receipt id before returning `PurchaseGranted`, and make the grant idempotent ([[Developer Products and ProcessReceipt]], [[Purchase Data and Receipts]]). The reference project kept its purchase receipts store intact across every player-data reset.

---

## 4. Duplication and abuse

Economies die from duplication bugs more than from design. Classic causes:

| Cause | Prevention |
|---|---|
| Yield between check and mutation | Plan, then apply without yielding |
| Repeated remote calls | Idempotency tokens; claimed flags set before granting |
| Trading race conditions | Lock both inventories during trade; re-validate at commit |
| Save/load races across servers | Session locking ([[Session Locking and Profile Libraries]]) |
| Rejoin to retry a roll | Commit results before showing them |
| Client-reported values | Server computes all amounts |

**Measured** patterns from the reference project: hub activities (spin wheel, fishing, chests) used range checks, cooldowns, a 0.5 s throttle and "claim marked before paying"; fusion used token receipts and plan-then-apply. Anti-farm rules cap PvP kill payouts at 2 per victim per minute.

---

## 5. Measuring the economy

Track per player and in aggregate:
- **Income per minute by stage** (zone, rebirth count): the basis of all pricing.
- **Time to afford each gate**: median and 90th percentile. If the 90th is 5x the median, a group is stuck.
- **Currency held vs spent**: rising unspent balances mean nothing is worth buying (inflation or missing sinks).
- **Sink usage**: which sinks players actually use; an unused sink is not a sink.
- **Premium currency sources**: free vs purchased share.

Use `LogEconomyEvent` for flows and funnels for progression steps ([[Analytics and Funnels]]). Spreadsheets model, analytics verify ([[Balancing with Spreadsheets and Data]]).

---

## 6. Rebalancing a live economy

**Measured.** The reference project ran a "difficulty pass": enemy health x1.8, damage x1.35, cash x0.55, XP x0.6; weapon income x0.6; higher gate and skill prices. Because old saves held currency earned under the old rates, the team bumped the DataStore names to new versions (an account reset), leaving the old stores untouched so the change could be rolled back, and kept purchase receipts and settings. Later passes re-priced the upgrade board and the forge against the new gate ladder (an Epic +1 forge fell from 150K to about 12 to 15K).

Lessons:
- **Rebalances that change income by large factors invalidate saved balances.** Options: scale existing balances by the same factor in a migration, grant compensation, or reset. Resetting is the most honest but costs trust; only do it early and announce it.
- **Never touch purchase records** in a reset; refund or re-grant paid items.
- **Keep the old store** until you are sure (rename back = rollback) ([[Data Loss Prevention and Recovery]]).
- **Re-derive all prices from one model** after any income change; a forgotten system (the forge here) ends up wildly mispriced.
- **Freeze rewards at deal time** so a rebalance mid-day does not change quests already on the board ([[Quests and Objectives]]).

---

## 7. UI for currencies

- Always visible: the soft currency and premium currency, with income rate where income is passive.
- Count-up animations on gain (about 0.4 s cubic-out in the reference project), not instant jumps.
- "+N" pops at the source (a kill, a chest) tie income to action ([[Game Feel and Juice]]).
- Show what is affordable: glow or badge on affordable gates and upgrades; "$X more" on progress bars.
- Lock icons for features gated by progress rather than hiding them.

See [[HUD Design]].

---

## 8. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Fixed rewards in an exponential game | Late quests worthless | Scale to next price |
| Prices tuned item by item | Inconsistent, outdated after changes | One income model |
| Too many currencies | Confusing UI, thin sinks | Merge or remove |
| Yield in purchase code | Duplication | Check and apply atomically |
| No economy analytics | Balance by guesswork | `LogEconomyEvent`, funnels |
| Reset touching receipts | Paid items lost | Keep receipts, re-grant |

## Checklist
- [ ] Each currency has listed faucets and sinks per stage.
- [ ] Prices and rewards derived from an income model.
- [ ] All transactions server-side, validated, non-yielding, logged.
- [ ] Multipliers applied in one function.
- [ ] Rebalance plan includes save migration or reset with rollback.

## See also
[[Progression Levels and Unlocks]] · [[RNG Drops and Luck Systems]] · [[Monetization Overview]] · [[Developer Products and ProcessReceipt]] · [[Pricing and Store Design]] · [[Balancing with Spreadsheets and Data]] · [[Analytics and Funnels]] · [[Genre Playbook - Simulators]]

## Connected notes
<!-- auto-links:start -->
[[Economy Inflation Sinks and Faucets Math]] · Currency Architecture - Soft Hard and Event Currencies · Faucets and Sinks · Progression and Pacing Design · Economy Telemetry and Balancing Live · Simulating an Economy Before Launch
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Currency Architecture - Soft Hard and Event Currencies]] · [[Faucets and Sinks]] · [[Progression and Pacing Design]] · [[Economy Telemetry and Balancing Live]] · [[Robux Price Points and Offer Design]] · [[Tools and Inventory Systems]]
<!-- related:end -->
