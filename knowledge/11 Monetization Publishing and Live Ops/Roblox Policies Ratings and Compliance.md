---
tags: [policy, compliance, maturity, paid-random-items, policyservice, odds, luau]
---
# Roblox Policies Ratings and Compliance

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Thinking gem-priced eggs are exempt because gems can be earned.
> - Avoid: Odds in an (i) icon with no word.
> - Avoid: Display odds from a different table than the roll.
> - Questionnaire complete, accurate, resubmitted after content changes
> - Policy service on the server, fail-closed, attributes for UI
> - Every paid random item: all outcomes, numerical odds, 100% sum, labelled details button
>
> Cost: TL;DR ~140 tok · whole note ~4.0k tok. Read more: ## 1. The Maturity & Compliance Questionnaire (Docs) · ## 2. Paid random items (Docs, Oct 2026) · ## 7. Common mistakes · ## 8. Checklist
<!-- tldr:end -->

Compliance on Roblox has three layers: the **Maturity & Compliance Questionnaire** (which sets your content label and who can see your game), **monetization policies** (paid random items and odds disclosure, paid item trading, subscription, ad and notification rules), and the general **Terms of Use and Community Standards**. Breaking them costs reach, ads eligibility, payouts, or the game. This note explains each layer, the `PolicyService` checks you must implement, and how to build odds disclosure that meets the rules, with code. Verified against the Creator Hub "Content maturity and compliance", "Paid random items" and `PolicyService` pages **as of October 2026**. This is a developer guide, not legal advice; regulations differ by country and change.

---

## 1. The Maturity & Compliance Questionnaire (Docs)

You answer questions about what content your game contains and how often. Roblox produces a **maturity label**, **content descriptors** and a **regional compliance result**.

- You must answer the **full** questionnaire to reach Roblox Kids and Select, to serve regions with specific content policies, or to offer age-restricted content.
- If you only target age-checked **16+** users in most regions, you need only the **first question** (the age-restricted content question). Answering "No" gives **Content May Vary** and releases to age-checked 16+ (Docs, publishing).
- A game with **no maturity information** has its playability automatically restricted for all players (Docs).
- Roblox Moderation may review answers. Discrepancies lead to a message, feedback on the questionnaire page and possible label replacement or removal and moderation consequences; repeated inaccuracies can affect the game or account. Appeals go through report-appeals or Support (Docs).
- Retake any time; **if an update changes any answer you must resubmit** (Docs). A Restricted label cannot be changed back, only its descriptors updated.
- **Resubmitting temporarily removes rewarded video ads eligibility while it is reviewed** (Docs, ads). Resubmit when needed, not casually.

### Labels and audiences (Docs, Oct 2026)

| Label | Default audiences |
|---|---|
| **Minimal** | Roblox Kids (5 to 8), Roblox Select (9 to 15), and up (with extra publishing requirements for Kids/Select) |
| **Mild** | Same as Minimal |
| **Moderate** | Roblox Select (9 to 15) and Roblox (16+) |
| **Content May Vary** | Age-checked 16+ only |
| **Restricted** | Age-verified **18+** only |

There is no 17+ tier any more; older guides that mention "17+ experiences" describe the previous system. When a game becomes Restricted, servers restart to remove everyone not age-verified 18+, and Studio collaborators not verified 18+ are removed from active sessions (Docs). Restricted games are unplayable for accounts created in or located in certain countries, examples given include Korea, Saudi Arabia and Türkiye (Docs).

### Content items with their own rules (Docs)

| Item | Requirement |
|---|---|
| Paid random items | Must be disclosed; check `ArePaidRandomItemsRestricted` and hide, replace or block when true |
| Paid item trading | Must be disclosed; check `IsPaidItemTradingAllowed`; block trading when false |
| Gambling | **Playable gambling, including simulated gambling, is not allowed.** Depictions of unplayable gambling are allowed and labelled |
| Social hangout | Without private spaces 16+; with private spaces age-verified 18+ |
| Free-form user creation | 16+ |
| Sensitive issues as primary theme | 16+; not recommended or discoverable unless players are age-verified; parents can allow |
| Romantic themes, alcohol, strong language | Age-verified 18+ |
| Strong violence, heavy realistic blood | Age-verified 18+ |
| AI interaction | Must be disclosed (limited versus extended) |
| Media sharing and viewing | Asked about; no separate age rule stated |

Labels also decide which age groups see the game on Home and Charts (Docs). A sword-combat game with stylised violence typically sits in Mild or Moderate; check the violence wording carefully, because "heavy realistic blood" moves a game to 18+.

**Simulated gambling** is the trap for RNG games. Slot machines, roulette, coin-flip betting of currency, "double or nothing" mechanics are risky even with free currency. Rolling for items with disclosed odds is a different thing (a random item system); betting a stake for a chance to multiply it is gambling-shaped. When in doubt, remove the stake.

---

## 2. Paid random items (Docs, Oct 2026)

### What counts
A **paid random item** is any random outcome bought **directly or indirectly with Robux**, including through paid in-game currency. Docs examples: paying Robux to spin a wheel; buying gems or spin tickets that are spent on a wheel; keys, re-roll tokens, spin tickets.

Types covered:
- **Capsules:** wheels, eggs, chests, crates.
- **Enhancements:** potions, upgrade spells with random success.
- **Combinations:** synthesising (fusing eggs, crafting into a random result).
- **Probability modifiers:** luck boosts, pity systems, enhanced drop rates, rate-up scrolls.

**Exempt:** random rewards earned through actions that involve neither Robux nor paid currency.

The "indirect" clause catches most simulators: if gems can be bought with Robux and eggs cost gems, eggs are paid random items, even for a player who only ever earned gems by playing. The reference project's free rolls are not paid random items, but its "Jackpot Roll" product (next roll Legendary or better), luck passes, server luck boosts, lucky charms and a craft feature that turns five blades into a random next-rarity blade all touch the policy whenever paid currency or Robux is involved.

### Disclosure rules
- Show **all possible outcomes** and their **actual numerical odds** **before purchase**.
- Odds as **percentages summing to exactly 100%**. Long decimals may be rounded to four or more decimal places past the first non-zero digit, with a disclaimer that displayed probabilities are rounded and may not total 100%.
- Long lists: a clickable pop-up opened by a button labelled with a word ("Info", "Details"). **A standalone (i) icon without a word is not sufficient.**
- Many items with the same odds: you may say "Odds for each item listed below: X%".
- **Limited outcomes:** if an outcome can only be obtained once per user, update the remaining odds for that user.
- **Probability modifiers** sold for Robux (or paid currency) must explain their effect numerically before purchase, and **while active, displayed odds must update to the user's true odds**.

### When `ArePaidRandomItemsRestricted` is true
The user may not interact with paid random item generators. You must do one of (Docs):
- offer an unpaid, earnable path to the item;
- offer outcomes in a predetermined, disclosed, non-random order;
- sell specific outcomes directly, priced at expected value;
- remove or hide the paid random item;
- block the purchase with an error message;
- keep the user out of areas with paid random items.

### Paid item trading
When `IsPaidItemTradingAllowed` is false, do not let the user trade paid random outcomes or other paid items (Docs). Note the `PolicyService` reference page itself (Oct 2026) documents only `ArePaidRandomItemsRestricted` and `IsEligibleToPurchaseCommerceProduct` among the returned keys; `IsPaidItemTradingAllowed` is documented on the paid random items and maturity pages. Treat a missing key as "not allowed".

---

## 3. PolicyService in practice

`PolicyService:GetPolicyInfoForPlayerAsync(player)` yields and returns a dictionary. The reference samples call it from the client; enforcement must happen on the server, so call it on the server and replicate the result as attributes for UI.

```lua
--!strict
-- ServerScriptService/Services/Policy (ModuleScript)
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")

export type Policy = {
	RandomItemsRestricted: boolean,
	PaidTradingAllowed: boolean,
}

local cache: { [Player]: Policy } = {}

-- Fail closed: if we cannot read the policy, treat the player as restricted.
local RESTRICTED: Policy = { RandomItemsRestricted = true, PaidTradingAllowed = false }

local function load(player: Player): Policy
	for attempt = 1, 3 do
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if ok and typeof(info) == "table" then
			local p: Policy = {
				RandomItemsRestricted = info.ArePaidRandomItemsRestricted ~= false,
				PaidTradingAllowed = info.IsPaidItemTradingAllowed == true,
			}
			return p
		end
		task.wait(attempt)
	end
	return RESTRICTED
end

Players.PlayerAdded:Connect(function(player)
	local p = load(player)
	cache[player] = p
	player:SetAttribute("PolicyRandomRestricted", p.RandomItemsRestricted)
	player:SetAttribute("PolicyPaidTrading", p.PaidTradingAllowed)
end)
Players.PlayerRemoving:Connect(function(player)
	cache[player] = nil
end)

local Policy = {}

function Policy.Get(player: Player): Policy
	return cache[player] or RESTRICTED
end

return Policy
```

Use it at every gate: the shop remote refuses to prompt a paid random product for restricted players (and the UI shows the compliant alternative), the egg or crate opener refuses paid-currency opens, and the trade service refuses paid items when trading is not allowed. Remember the indirect rule: a gem-priced egg is a paid random item if gems are sold.

Fail-closed has a cost: during an outage everyone loses access to paid random items. That is the safe direction.

---

## 4. Building odds disclosure

The display must come from the **same numbers the server rolls with**. Never maintain a separate "display odds" table.

```lua
--!strict
-- ReplicatedStorage/Odds (ModuleScript): weights -> percentages that the UI shows.
export type Entry = { id: string, weight: number }
export type Shown = { id: string, percent: number, text: string }

local Odds = {}

-- Show the first non-zero digit plus four more decimals (Docs: round to four or more
-- decimal places past the first non-zero digit). 0.00123 -> "0.0012300%".
local function format(p: number): string
	if p >= 1 then
		return string.format("%.4f%%", p)
	end
	local digits = 5
	local x = p
	while x > 0 and x < 1 do
		x *= 10
		digits += 1
	end
	return string.format(`%.{digits - 1}f%%`, p)
end

-- luckFn lets the caller apply the player's ACTIVE modifiers, so the display shows true odds.
function Odds.Compute(entries: { Entry }, luckFn: ((Entry) -> number)?): ({ Shown }, boolean)
	local total = 0
	local adjusted = table.create(#entries)
	for i, e in entries do
		local w = if luckFn then luckFn(e) else e.weight
		adjusted[i] = w
		total += w
	end
	local shown: { Shown } = {}
	for i, e in entries do
		local p = adjusted[i] / total * 100
		table.insert(shown, { id = e.id, percent = p, text = format(p) })
	end
	-- Exact sum is 100 by construction; the displayed (rounded) texts may not be.
	local needsDisclaimer = true
	return shown, needsDisclaimer
end

Odds.Disclaimer = "Displayed probabilities are rounded and may not total 100%."

return Odds
```

The server's roll uses the same `entries` and the same `luckFn` (or an equivalent cumulative-weight pick). Details of weighted picking and luck curves are in [[RNG Drops and Luck Systems]].

UI rules distilled:
- Odds visible on the purchase card or behind a button labelled "Odds" or "Details".
- Group by rarity tier if lists are long, with per-item odds in the details view.
- When a luck boost or pity is active, the shown odds change accordingly.
- A boost product card says exactly what it does: "x2 luck for 15 minutes, this server" and, ideally, an example ("Mythic: 0.0010% -> 0.0020%").

**Reference project.** Its index cards, fragment list and backpack odds tooltip showed the **true per-roll chance at the player's current luck**, including lucky and golden dice, and marked tiers not reachable in the current realm ("unlocks in realm II") because its roll caps limit the maximum rarity per world. That last point is a disclosure detail people miss: if a cap makes an outcome impossible where the player is, its odds there are 0%, and the display must say so.

---

## 5. Other monetization rules in one place

| Area | Rule (Docs, Oct 2026) | Note |
|---|---|---|
| Subscriptions | Clear names with price and duration; same benefits on all platforms; honour the full term; no extra tasks to unlock paid benefits; no directing to off-platform purchases | [[Subscriptions and Premium Payouts]] |
| Rewarded ads | No Robux, random items or inflationary currency as rewards; disclose it is an ad; no forced ads as progress gates; no obscuring the screen | [[Ads and Rewarded Video]] |
| Notifications | Personalised, actionable, no dark patterns, gameplay must not require them | [[Live Ops Events and Updates]] |
| Premium/Plus prompts | Honest benefits; no promise of Robux you do not control; not a paywall; cosmetics fine, no tactical advantage (Premium guidance) | |
| Promoted passes | Cannot grant paid random items; follow Community Standards | [[Game Passes]] |
| Thumbnails/video | No misrepresentation, no enhanced graphics, no promotions or claims | [[Thumbnails Icons and Store Page]] |
| Chat | All player-to-player text through `TextChatService` | [[Age Checks and Safety Features]] |
| External links | No external social links in-game (2026) | [[Community Building]] |

Truthful descriptions are a recurring theme. The reference project had to fix a pass description that understated the real multiplier and a server-wide boost whose copy did not say "this server". Inaccurate claims in either direction are a trust and policy problem.

---

## 6. Audit routine (rule of thumb)

Before each release:
1. List every product, pass and subscription. For each: random or not? paid directly or indirectly? modifier? tradeable?
2. For each random one: odds visible before purchase, sum to 100%, disclaimer if rounded, labelled button, true odds with modifiers.
3. Restricted players: compliant path exists and is tested (force the restricted policy in a test build).
4. Trading: paid items blocked where not allowed; price-level gate.
5. Questionnaire answers still true after this update? If not, resubmit (and expect ads eligibility to pause during review).
6. Descriptions match code numbers.

---

## 7. Common mistakes
- Thinking gem-priced eggs are exempt because gems can be earned.
- Odds in an (i) icon with no word.
- Display odds from a different table than the roll.
- Luck boosts with no numbers.
- Assuming `PolicyService` succeeded; not failing closed.
- Coin-flip or double-or-nothing mechanics ("it's only free currency").
- Answering the questionnaire once and never again.

## 8. Checklist
- [ ] Questionnaire complete, accurate, resubmitted after content changes
- [ ] Policy service on the server, fail-closed, attributes for UI
- [ ] Every paid random item: all outcomes, numerical odds, 100% sum, labelled details button
- [ ] Modifiers explained numerically; active odds update live
- [ ] Restricted players get a compliant alternative
- [ ] Paid item trading gated
- [ ] No simulated gambling
- [ ] Descriptions generated from code values

## See also
[[Age Checks and Safety Features]] · [[RNG Drops and Luck Systems]] · [[Genre Playbook - RNG and Collection Games]] · [[Pricing and Store Design]] · [[Developer Products and ProcessReceipt]] · [[Publishing an Experience]] · [[Ethical Design and Player Trust]] · [[Monetization Overview]]

## Connected notes
<!-- auto-links:start -->
[[Paid Random Items and Odds Disclosure in Practice]] · [[Skill - Roblox Monetization Compliance]] · [[Pity Timer]] · [[Expected Value]] · [[Pet Hatching and Following End to End]] · [[Genre Playbook - Simulators]]
<!-- auto-links:end -->
