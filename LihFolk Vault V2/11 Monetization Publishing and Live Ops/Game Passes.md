---
tags: [monetization, game-passes, marketplaceservice, luau, type/guide, area/monetization, level/intermediate, api/GetProductInfoAsync, area/scripting, api/Player]
---
# Game Passes

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Granting on a client remote.
> - Avoid: Calling `UserOwnsGamePassAsync` every frame or every hit.
> - Avoid: Using `MarketplaceService.PromptGamePassPurchaseFinished` on the client to change server state.
> - Every pass has a custom icon (default icons convert worse; Docs recommend custom)
> - One server ownership cache, updated on join and on purchase
> - Unknown ownership retried, not stored as false
>
> Cost: TL;DR ~140 tok · whole note ~4.1k tok. Read more: ## 3. Server code · ## 5. Designing a pass lineup · ## 7. Common mistakes · ## 8. Checklist
<!-- tldr:end -->

A pass is a one-time Robux purchase that grants a permanent privilege: a multiplier, an area, a tool, a tag. This note covers how passes work, how to check ownership correctly (including the cases where the obvious check returns the wrong answer), how to grant in-session, and how to design a pass lineup. Facts verified against the Creator Hub "Passes" guide and the `MarketplaceService` reference **as of October 2026**.

Roblox's docs now say "passes" in most places; the engine API still says `GamePass` (`PromptGamePassPurchase`, `UserOwnsGamePassAsync`, `Enum.InfoType.GamePass`). They are the same thing.

---

## 1. What a pass is, mechanically

- Created per experience on the Creator Dashboard: Creations, select the game, Monetization, Passes, Create pass (Docs). You give it an icon, a name, a description and a shop category; the category organises items in the in-game Shop surface (Docs).
- **Icon:** at most 512x512, `.jpg`, `.png` or `.bmp`, with important content inside the circle because the corners can be cropped (Docs).
- **Ownership is stored by Roblox.** Unlike developer products, you do not need to save "owns pass" yourself. You ask `UserOwnsGamePassAsync`.
- **No `ProcessReceipt`.** Passes do not go through the receipt callback (Docs). That makes them simpler, and also means you have no receipt to make a grant idempotent against. Pass benefits must be derived from ownership, not "granted once".
- **Purchasable outside the game.** If you mark a pass Listed in Monetization, Shop, it can appear on the Roblox home page, in search and on the post-purchase page (Docs). A player may therefore join already owning a pass, which is why the join check is mandatory.
- **Per-user history is not kept for you.** Docs: Roblox does not store per-user purchase history for passes; use sales data downloads for aggregates or your own data stores for per-user tracking.
- **Regional pricing is on by default** for all new and existing passes, and can be switched off per pass (Docs, regional pricing page). So the price a player sees may be lower than your default. See [[Pricing and Store Design]].
- **Promotion.** A pass can be put in the "bonus pool" so Roblox gives it free to users buying Robux; promoted passes on sale must be priced above 49 and below 801 Robux and cannot grant paid random items (Docs). Docs recommend a unique pass for promotion.
- **Cross-game pass sales** are disabled from May 30, 2026 (Docs).

---

## 2. The ownership model

The right mental model: **ownership is a fact Roblox holds; your server caches it for the session and derives benefits from it.**

Three sources of truth can disagree:

| Source | When it is right | When it is wrong |
|---|---|---|
| `UserOwnsGamePassAsync(userId, passId)` | On join, for passes bought before joining | Can fail (network) and, by long-standing community experience, may return a cached `false` for a short time right after an in-game purchase (rule of thumb; the reference page does not document caching) |
| `PromptGamePassPurchaseFinished(player, passId, wasPurchased)` | Right after an in-game purchase on this server | Never fires for purchases made on the website or another server |
| Your cache (a table or attribute) | Fast reads for gameplay code | Stale if you never update it after a purchase |

So the pattern is: check on join, set the cache; on `PromptGamePassPurchaseFinished` with `wasPurchased == true`, set the cache; gameplay reads the cache only.

**Reference project.** Its pass service had two "stale false" bugs: a pass bought in-session was not applied until rejoin because one feature re-queried `UserOwnsGamePassAsync` instead of reading the cache updated by the purchase event. Fixing both meant one ownership table for the whole server. Another fix: the Studio "test profile" path ignored owned passes so testers could see the free experience, a useful testing switch.

### Is `PromptGamePassPurchaseFinished` trustworthy?

It fires on the server with a `wasPurchased` flag (Docs). The Passes guide uses it as the grant point. Unlike developer products there is no receipt to verify. The event is raised by the engine, not by a client remote, so a client should not be able to fake it for another purchase (**Unverified**: the reference page does not state a security guarantee). Treat it by tier: grant **session-only** perks (a speed boost, a UI badge) straight from the event; make **persisted or high-value** benefits (saved items, currency, anything written to the profile) depend on `MarketplaceService:UserOwnsGamePassAsync` returning `true`, re-polled a few times with backoff because it can briefly lag a fresh purchase (rule of thumb). Never accept a client remote saying "I bought the pass".

---

## 3. Server code

A typed pass service that every gameplay system queries. It retries the join check, updates on purchase, mirrors ownership into a player attribute for UI, and exposes a changed signal.

```lua
--!strict
-- ServerScriptService/Services/PassService (ModuleScript)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PassService = {}

-- Keys are your own stable names; ids come from the Creator Dashboard.
-- 0 means "not created yet": the pass is hidden or shown as "coming soon".
PassService.Passes = {
	DoubleRoll = 0000000000,
	VIP = 0000000000,
	FastRoll = 0000000000,
} :: { [string]: number }

local owned: { [Player]: { [string]: boolean } } = {}
local changed = Instance.new("BindableEvent")
PassService.Changed = changed.Event -- (player, key, isOwned)

local function setOwned(player: Player, key: string, value: boolean)
	local t = owned[player]
	if not t or t[key] == value then
		return
	end
	t[key] = value
	player:SetAttribute("Pass_" .. key, value) -- replicated, read by UI
	changed:Fire(player, key, value)
end

local function ownsWithRetry(userId: number, passId: number): boolean?
	for attempt = 1, 3 do
		local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, userId, passId)
		if ok then
			return result
		end
		task.wait(attempt) -- 1 s, 2 s backoff
	end
	return nil -- unknown: do not treat as false forever
end

local function loadPasses(player: Player)
	owned[player] = {}
	-- Spawn checks concurrently; the reference sample notes the engine
	-- batches concurrent calls into fewer HTTP requests (Docs).
	for key, passId in PassService.Passes do
		if passId ~= 0 then
			task.spawn(function()
				local result = ownsWithRetry(player.UserId, passId)
				if result == nil then
					warn(`[PassService] ownership unknown for {key}, will recheck`)
					task.delay(30, function()
						if player.Parent and owned[player] and not owned[player][key] then
							local again = ownsWithRetry(player.UserId, passId)
							if again then
								setOwned(player, key, true)
							end
						end
					end)
				elseif player.Parent and owned[player] then
					setOwned(player, key, result)
				end
			end)
		end
	end
end

function PassService.Owns(player: Player, key: string): boolean
	local t = owned[player]
	return t ~= nil and t[key] == true
end

function PassService.Prompt(player: Player, key: string)
	local passId = PassService.Passes[key]
	if not passId or passId == 0 or PassService.Owns(player, key) then
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, passId)
end

local keyById: { [number]: string } = {}
for key, id in PassService.Passes do
	if id ~= 0 then
		keyById[id] = key
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, wasPurchased: boolean)
	local key = keyById[passId]
	if key and wasPurchased then
		setOwned(player, key, true)
	end
end)

Players.PlayerAdded:Connect(loadPasses)
for _, p in Players:GetPlayers() do
	task.spawn(loadPasses, p)
end
Players.PlayerRemoving:Connect(function(player)
	owned[player] = nil
end)

return PassService
```

Notes on the code:
- `owned[player]` is cleared on leave so the table does not leak players ([[Memory Budgets and Leaks]]).
- An unknown result (all retries failed) is not stored as `false`. Storing a false permanently is the classic "I bought VIP and it doesn't work" ticket.
- The client prompts through a remote that calls `PassService.Prompt`, or calls `PromptGamePassPurchase` itself with `Players.LocalPlayer` (allowed from the client). Either way the grant is server-side.
- Gameplay code reads `PassService.Owns(player, "DoubleRoll")` at the moment of use. Multipliers then apply the instant ownership flips, with no rejoin.

### Applying effects that live on the character

Some pass benefits are physical: a speed coil, a tool, a trail. Those must be re-applied every time the character spawns, and once at purchase time. Hook `CharacterAdded` and the `Changed` signal; do not only do it on join (the character respawns and the tool vanishes). For Tools, put a copy in `player.StarterGear` as well as the Backpack. See [[Tools and Inventory Systems]].

---

## 4. Client display

Docs show `GetProductInfo(passId, Enum.InfoType.GamePass)` and checking `IsForSale` before showing the name, price and description. `GetProductInfo` is now marked deprecated on the reference page in favour of `GetProductInfoAsync` (Docs, Oct 2026). The price-optimization and regional-pricing docs both require that prices be read dynamically, on the client, so the player sees their own price.

```lua
--!strict
-- LocalScript: fill a pass card with the live price for THIS player.
local MarketplaceService = game:GetService("MarketplaceService")

local function fillCard(card: Frame, passId: number)
	local priceLabel = card:FindFirstChild("Price") :: TextLabel
	local buy = card:FindFirstChild("Buy") :: TextButton
	if passId == 0 then
		priceLabel.Text = "Coming soon"
		buy.Active = false
		buy.AutoButtonColor = false
		return
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(passId, Enum.InfoType.GamePass)
	end)
	if not ok or not info.IsForSale then
		priceLabel.Text = "Unavailable"
		buy.Active = false
		return
	end
	priceLabel.Text = `R$ {info.PriceInRobux}`
end
```

Keep the "owned" state from the `Pass_<Key>` attribute: show OWNED and disable the button once the attribute is true. Do not call `UserOwnsGamePassAsync` from each card on the client.

---

## 5. Designing a pass lineup

Passes work best as **permanent multipliers of the core loop**. The reference project's lineup is typical for a simulator:

| Pass | Price (R$) | Effect | Design note |
|---|---|---|---|
| Lucky Rolls | 75 | +1 permanent luck | Cheap first purchase; a "door opener" |
| Super Potions | 199 | Potions last 2x | Multiplies a free system |
| Fast Roll | 299 | Rolls twice as fast | Time saver |
| VIP | 399 | Cash, XP and luck multipliers, more daily gems, more backpack space, chat tag, nametag effect | Bundle of status plus power |
| Double Roll | 599 | Two results per roll | The core loop doubled: the premium anchor |

Patterns worth copying:
- **One cheap pass under 100 Robux.** The first purchase is the hardest; a low-friction one converts players who then buy more.
- **A status pass.** Visible signals (chat tag, nametag effect) give the buyer social value and advertise the pass to everyone else.
- **The core-loop pass priced highest.** It is worth the most to the most engaged players.
- **Multipliers stack multiplicatively with care.** Five passes each giving 1.5x stack to 7.6x. Balance the free curve assuming payers own everything, or cap. See [[Balancing with Spreadsheets and Data]].

Patterns to avoid:
- **Passes that make free play unbearable.** Doubling the free grind to sell a 2x pass reads as a paywall. Players can tell.
- **Pay-to-win in PvP.** A damage pass in a PvP game shrinks the free population that paying players need to beat.
- **Passes that later stop working.** If a feature a pass boosts is removed, convert the benefit (for example to an equivalent multiplier elsewhere) and say so. Roblox's subscription guidelines explicitly say to honour benefits for the full term; the same principle applies to permanent passes.
- **A pass that changes random odds without numbers.** A luck pass is a paid probability modifier: you must explain numerically what it does before purchase, and show the player's true modified odds while active (Docs, paid random items). The reference project's luck readout showed the true per-roll chance at the player's current luck for exactly this reason.

### Onboarding and passes

Turn pass effects off where they would break the tutorial. The reference project disabled the Double Roll pass, golden rolls and luck doubling during the scripted first roll, so every new player gets the same teachable result. Owners still get the benefit from the second roll on.

---

## 6. Edge cases and failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| "I bought it but nothing happened" | Benefit only applied on join; or the cache stored a failed check as false | Update on `PromptGamePassPurchaseFinished`; retry unknown checks |
| Works in Studio, not live | Pass id from a different experience; or Studio test account owns it | Ids are per experience; test with a fresh account |
| Tool disappears on respawn | Granted only to Backpack | Also clone into `StarterGear`, reapply on `CharacterAdded` |
| Price label wrong for some players | Hard-coded price | Read `PriceInRobux` from `GetProductInfoAsync` |
| Pass owners join with no benefits during an outage | All `UserOwnsGamePassAsync` calls failed | Retry with backoff; re-check later; never persist `false` |
| Gift or trade arbitrage with regional prices | Items bought cheap in one region traded to another | Use `GetUsersPriceLevelsAsync` rules for gifts/trades (Docs) |

**Gifting passes.** You cannot buy a pass for another user through the API. "Gift a pass" systems are developer products that grant the pass-equivalent benefit into the recipient's save data. That benefit is then *your* data, not Roblox ownership, so your pass checks must accept both sources. The reference project kept a separate gift-intents store for this. With regional pricing, Docs recommend allowing a gift only when the sender's price level is greater than or equal to the recipient's. See [[Pricing and Store Design]].

---

## 7. Common mistakes

- Granting on a client remote.
- Calling `UserOwnsGamePassAsync` every frame or every hit. Cache it.
- Using `MarketplaceService.PromptGamePassPurchaseFinished` on the client to change server state.
- Not reapplying character-based benefits on respawn.
- Using one pass id in two experiences (ids are per experience).
- Selling a consumable as a pass.

## 8. Checklist

- [ ] Every pass has a custom icon (default icons convert worse; Docs recommend custom)
- [ ] One server ownership cache, updated on join and on purchase
- [ ] Unknown ownership retried, not stored as false
- [ ] Character benefits reapplied on spawn
- [ ] Prices read dynamically on the client
- [ ] Luck/odds passes disclose numerical effects
- [ ] Tutorial unaffected by pass effects where it matters
- [ ] Listed in Monetization, Shop if you want off-game sales

## See also
[[Monetization Overview]] · [[Developer Products and ProcessReceipt]] · [[Pricing and Store Design]] · [[Server Authority and Validation]] · [[Menu Archetypes - Shop Settings Codes Rewards]] · [[Economies and Currencies]] · [[RNG Drops and Luck Systems]]

## Connected notes
<!-- auto-links:start -->
[[Official Docs - Monetization]] · Shop with Game Passes and Developer Products End to End · Purchase Data and Receipts · Skill - Roblox Monetization Compliance · Genre Playbook - Simulators · UGC Pricing Limiteds and Marketplace Rules
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Shop with Game Passes and Developer Products End to End]] · [[Robux Price Points and Offer Design]] · [[Purchase Data and Receipts]] · [[Subscriptions and Premium Payouts]] · [[Refunds Chargebacks and Purchase Support]] · [[Roblox Policies Ratings and Compliance]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Economy Inflation Sinks and Faucets Math]] · [[Ads and Rewarded Video]] · [[Community Building]]
<!-- related:end -->
