---
tags: [policy, compliance, policyservice, paid-random-items, regions, trading, country-rules, monetization, type/guide, area/policy, area/monetization, area/platform]
---
# Regional Compliance - Paid Random Items and Country Rules

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Failing open when `GetPolicyInfoForPlayerAsync` errors.
> - Avoid: Client-only gating. UI hidden, remote still accepts the purchase.
> - Avoid: Inferring country from locale.
> - All money paths audited; every random outcome reachable with Robux identified.
> - One server `PolicyGate`; missing keys and failures resolve to restrictive.
> - Every prompt, receipt and trade handler re-checks on the server.
>
> Cost: TL;DR ~140 tok · whole note ~2.3k tok. Read more: ## What `PolicyService` gives you · ## One policy gate, fail closed · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Some players cannot legally or contractually be offered certain things, and the rules depend on where they are and who they are. Roblox does not hand you a country code and a rulebook; it hands you `PolicyService`, which answers per player "is this allowed?". This note is the implementation side: one server-side policy gate that every money-touching feature consults, how to fail closed, how to design the alternative experience for restricted players, and how to test it. The odds-disclosure mechanics are in [[Paid Random Items and Odds Disclosure in Practice]] and the 2026 rule dates in [[Policy and Age Rules 2026]]; neither is repeated here.

Source labels: **Roblox docs** (create.roblox.com engine reference and policy pages, read October 2026), **Reported**, **Rule of thumb**, **Unverified**.

## What `PolicyService` gives you

- `PolicyService:GetPolicyInfoForPlayerAsync(player)` yields and returns a dictionary of policy flags for that player (Roblox docs). The current reference page shows `ArePaidRandomItemsRestricted` and `IsEligibleToPurchaseCommerceProduct` in samples and wraps the call in `pcall`.
- Other flags in use across V2 notes and older documentation include `IsPaidItemTradingAllowed` and `IsEligibleToPurchaseSubscription`. The current reference (October 2026) also lists `AreAdsAllowed`, `IsContentSharingAllowed`, `IsPhotoToAvatarAllowed`, `IsEndlessContentLoadAllowed` and `IsEndlessContentAutoplayAllowed`. `AllowedExternalLinkReferences` is a legacy field that **always returns an empty array** (since early 2026): social links are no longer shown in-game at all ([[API Renames and Deprecations 2025-2026]]). Read flags defensively (treat a missing key as "not allowed").
- The service also exposes `IsLuobuServer` and related members tied to the former China-specific programme; do not build new logic on them (Unverified status; legacy).

Key design facts:

- **Flags are per player, not per server.** Two players in the same server can see different shops.
- **You do not get the country.** Do not try to infer it from locale (`LocalizationService`) for compliance; locale is a language preference, not a jurisdiction.
- **The call can fail.** Network or service errors happen; your code must decide what failure means.

## Which features each flag gates

| Flag | Gate | Typical features |
|---|---|---|
| `ArePaidRandomItemsRestricted` | Do not offer paid random items to this player | Robux crates, eggs, gacha spins, paid rerolls, luck boosts bought with Robux that affect random outcomes, and indirect paths (Robux -> currency -> random item) |
| `IsPaidItemTradingAllowed` | Whether items bought with Robux may be traded | Trading UI, gifting, trade-locked flags on paid items |
| `IsEligibleToPurchaseSubscription` | Show subscription offers | Subscription shop entries |
| `IsEligibleToPurchaseCommerceProduct` | Physical goods (Commerce) | Commerce product prompts ([[Commerce and Physical Goods]]) |

The paid random items rule covers indirect money paths too. If premium currency bought with Robux can buy a random item, that random item is a paid random item. Audit the money paths before writing gates ([[Paid Random Items and Odds Disclosure in Practice]]).

## One policy gate, fail closed

```lua
--!strict
-- ServerScriptService/PolicyGate: the only code that calls PolicyService.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")

local PolicyGate = {}

export type Policy = {
	randomItemsRestricted: boolean,
	tradingAllowed: boolean,
	subscriptionsAllowed: boolean,
	resolved: boolean,
}

local RESTRICTIVE: Policy = { randomItemsRestricted = true, tradingAllowed = false, subscriptionsAllowed = false, resolved = false }
local cache: {[Player]: Policy} = {}

local function fetch(player: Player): Policy
	for attempt = 1, 3 do
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if ok and typeof(info) == "table" then
			return {
				randomItemsRestricted = info.ArePaidRandomItemsRestricted ~= false, -- missing => restricted
				tradingAllowed = info.IsPaidItemTradingAllowed == true,
				subscriptionsAllowed = info.IsEligibleToPurchaseSubscription == true,
				resolved = true,
			}
		end
		task.wait(attempt * 2)
	end
	return RESTRICTIVE
end

function PolicyGate.get(player: Player): Policy
	return cache[player] or RESTRICTIVE
end

Players.PlayerAdded:Connect(function(player)
	local policy = fetch(player)
	if player.Parent then
		cache[player] = policy
		player:SetAttribute("RandomItemsRestricted", policy.randomItemsRestricted) -- for UI only
		player:SetAttribute("TradingAllowed", policy.tradingAllowed)
	end
end)
Players.PlayerRemoving:Connect(function(player) cache[player] = nil end)

return PolicyGate
```

Rules encoded:

- **Fail closed.** Unknown means restricted. A failed lookup must never unlock a crate.
- **Server decides.** Attributes exist only so the client can hide UI; every purchase and trade handler calls `PolicyGate.get` again on the server. The client attribute is not trusted.
- **Retry once resolved.** If a lookup failed, retry later in the session (for example when the player opens the shop) and update the cache.
- **Check before prompting, not only after.** Never call `PromptProductPurchase` for a restricted product; also reject it in `ProcessReceipt` if a purchase somehow arrives (grant an equivalent non-random item or log for refund review, depending on your design; never silently grant the random item).

## Designing the restricted experience

Restricted players should have a complete game, not a greyed-out shop. Options (rule of thumb):

- **Direct purchase** of the same items at a fixed price instead of a random roll.
- **Earnable random items** with soft currency only, if your design and the rules allow non-paid randomness. Make sure no Robux path leads into that soft currency.
- **Fixed bundles** with known contents.
- **Hide, do not tease.** Do not show restricted players an animated crate they cannot open.

Keep the odds tables and alternatives in the same config, so a change to one is reviewed against the other.

## Country rules beyond Roblox flags (Reported)

Some countries regulate or have regulators who have ruled on paid loot boxes (Belgium and the Netherlands are the most cited examples in press since 2018; details and court outcomes have changed over time). Roblox's per-player flags are the mechanism Roblox provides; rely on them rather than building your own geolocation, which you cannot do reliably on Roblox anyway. If you operate a business in a specific jurisdiction, take local legal advice.

## Testing

- Unit-test `fetch` with a stubbed `PolicyService` returning: restricted, unrestricted, missing keys, and errors. All but "unrestricted" must produce restrictive results.
- In Studio, test the restricted path by forcing the stub; Studio's Player emulator offers policy-related emulation options in some versions (Unverified; check your Studio build). Do not ship the stub.
- Abuse test: fire your purchase remote for a restricted product directly from a test client; the server must refuse ([[Testing Your Own Remotes - Fuzzing and Abuse Tests]]).

## Common mistakes

- **Failing open** when `GetPolicyInfoForPlayerAsync` errors.
- **Client-only gating.** UI hidden, remote still accepts the purchase.
- **Inferring country from locale.**
- **Missing indirect money paths** (Robux -> gems -> crate).
- **Calling `PolicyService` from many scripts** with different fallbacks.
- **Restricted players shown teaser crates** they can never open.

## Checklist

- [ ] All money paths audited; every random outcome reachable with Robux identified.
- [ ] One server `PolicyGate`; missing keys and failures resolve to restrictive.
- [ ] Every prompt, receipt and trade handler re-checks on the server.
- [ ] Restricted players get direct-purchase or fixed alternatives.
- [ ] Stubbed tests for each policy outcome; remote abuse test for restricted products.
- [ ] Re-review after any Roblox policy update.

## See also

- [[Paid Random Items and Odds Disclosure in Practice]]
- [[Policy and Age Rules 2026]]
- [[Roblox Policies Ratings and Compliance]]
- [[Trading Systems Without Duplication]]
- [[Developer Products and ProcessReceipt]]
- [[PolicyService]]

## Connected notes

[[Subscriptions and Recurring Revenue]] · [[Commerce and Physical Goods]] · [[Genre Playbook - RNG and Collection Games]] · [[Platform Features Start Here]]

Source: https://create.roblox.com/docs/reference/engine/classes/PolicyService (read 28 October 2026).

<!-- related:start -->
## Related
[[AI Pitfalls - Data and Monetization]] · [[LihFolk Systems Library]] · [[Roblox Changes 2025-2026]] · [[Discovery and Monetization Changes 2025-2026]] · [[Friend Invites Referrals and Experience Invites]] · [[Console and VR Release Checklists]]
<!-- related:end -->
