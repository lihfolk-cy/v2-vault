---
tags: [monetization, ads, rewarded-video, adservice, ads-manager, luau, type/guide, area/monetization, level/intermediate, api/ProcessReceipt, area/scripting, api/RemoteEvent]
---
# Ads and Rewarded Video

<!-- tldr:start -->
> [!tldr] TL;DR
> - Button never shows: Not eligible (questionnaire pending, traffic below 2,000/month)... -> Check the Eligibility page; Serving toggle
> - Ad plays, no reward: Receipt handler does not know the reward product -> Add it to the grant table
> - Reward granted twice: Granted after `ShowRewardedVideoAdAsync` *and* in `ProcessReceipt` -> Grant only in the receipt
> - Eligibility met: creator ID + 2SV, game public, approved questionnaire, 2,000+ monthly visitors
> - Reward product is deterministic, not Robux, not random, not inflationary
> - Availability checked right before offering; one check per play
>
> Cost: TL;DR ~190 tok · whole note ~3.7k tok. Read more: ## 2. The flow · ## 3. Rules for rewards and placements (Docs) · ## 7. Failure modes · ## 8. Checklist
<!-- tldr:end -->

Ads touch a Roblox game in two directions:
- **Earning from ads** shown in your game: rewarded video (the player opts in to watch a short ad for a reward) and immersive ads (ad units placed in your world).
- **Spending on ads** to bring players to your game: Ads Manager campaigns (sponsored placements and search ads).

This note covers both, with the rewarded video integration in working Luau. Facts verified against the Creator Hub "Rewarded video ads" guide and the `AdService` reference **as of October 2026**. Ad programs are among the most frequently changed features on the platform; re-check eligibility before building.

---

## 1. Rewarded video: what it is

Full-screen, **click-to-play** video ads of **6 to 30 seconds**. The player chooses to watch and receives an in-game item after finishing (Docs). You earn per impression: **earnings = EPM (earnings per 1,000 impressions) x impressions** (Docs). The docs give no fixed EPM or revenue share; it depends on demand. Do not plan revenue on an assumed EPM until your own dashboard shows one.

### Eligibility (Docs, Oct 2026)

**The publishing creator** must be:
- 13 or older,
- in good standing,
- with 2-Step Verification on and a verified ID.

**The game** must:
- be public and unrestricted, with **no free-form user creation**;
- have a **Maturity & Compliance Questionnaire that Roblox has reviewed and approved** (a pending review can be re-requested; response within 24 hours);
- average **at least 2,000 unique visitors per month**;
- comply with the Terms of Use, Community Standards and publisher integrity requirements.

**Resubmitting the questionnaire temporarily removes ads eligibility during review** (Docs). Only resubmit when an update changes your answers, and do it at a quiet time.

Docs do not list region or device rules for viewers, which is why the API makes you ask "is an ad available right now?" for each player.

---

## 2. The flow

1. **Dashboard:** Creations, game, Monetization, Ads, Settings; under Rewarded Video, Serving, enable Serving and select a reward: an existing **developer product** or a new one (Docs).
2. **Client:** call `AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)` as close as possible to when the ad will show (for example when the shop opens). If the result is `Enum.AdAvailabilityResult.IsAvailable`, show the ad button (Docs). One availability result covers **one** ad play (Docs).
3. **Client to server:** button press fires a RemoteEvent.
4. **Server:** `AdService:CreateAdRewardFromDevProductId(productId)` creates an `AdReward`; `AdService:ShowRewardedVideoAdAsync(player, reward, placementId?)` plays it and returns an `Enum.ShowAdResult` (Docs).
5. **Grant:** the reward arrives through **`MarketplaceService.ProcessReceipt`** for that developer product after the full ad is watched (Docs). The player pays no Robux.

The important consequence: **you do not grant the reward after `ShowRewardedVideoAdAsync` returns.** The receipt is the grant. Your existing idempotent receipt handler ([[Developer Products and ProcessReceipt]]) handles ad rewards automatically.

`ShowVideoAd`, `VideoAdClosed` and `UnregisterAdOpportunity` are deprecated (Docs). The guide's text uses two spellings for the show method; the reference name is `ShowRewardedVideoAdAsync`.

### Client

```lua
--!strict
-- LocalScript: show the "Watch ad" button only when an ad can actually play.
local AdService = game:GetService("AdService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RequestAd = ReplicatedStorage.Remotes.RequestRewardedAd :: RemoteEvent
local button = script.Parent :: TextButton

local function refreshAvailability()
	button.Visible = false
	local ok, result = pcall(function()
		return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)
	if ok and result and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable then
		button.Visible = true
	end
end

button.Activated:Connect(function()
	button.Visible = false -- one result = one play; re-check before showing again
	RequestAd:FireServer("ShopGems")
end)

-- Call when the shop opens, not at join (availability goes stale).
return refreshAvailability
```

The shape of the returned object (`GetAdAvailabilityNowResult`) is from the reference sample; check the current reference if the field name has changed.

### Server

```lua
--!strict
local AdService = game:GetService("AdService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RequestAd = ReplicatedStorage.Remotes.RequestRewardedAd :: RemoteEvent

-- Placement name -> reward product id and placement id (both from the dashboard).
local PLACEMENTS: { [string]: { ProductId: number, PlacementId: number? } } = {
	ShopGems = { ProductId = 0000000000, PlacementId = nil },
}

local busy: { [Player]: boolean } = {}
local lastAd: { [Player]: number } = {}
local MIN_GAP = 60 -- seconds between ads per player; your pacing, not a platform rule

RequestAd.OnServerEvent:Connect(function(player: Player, placement: unknown)
	if typeof(placement) ~= "string" then
		return
	end
	local spec = PLACEMENTS[placement]
	if not spec or spec.ProductId == 0 or busy[player] then
		return
	end
	if os.clock() - (lastAd[player] or -math.huge) < MIN_GAP then
		return
	end
	if not SafeZone.IsSafe(player) then -- not in combat, not in a round (your module)
		return
	end
	busy[player] = true
	lastAd[player] = os.clock()
	player:SetAttribute("WatchingAd", true) -- pause damage, AFK kick, round timers
	local ok, result = pcall(function()
		local reward = AdService:CreateAdRewardFromDevProductId(spec.ProductId)
		return AdService:ShowRewardedVideoAdAsync(player, reward, spec.PlacementId)
	end)
	player:SetAttribute("WatchingAd", false)
	busy[player] = nil
	if not ok then
		warn("[Ads] show failed", result)
	end
	-- No grant here: ProcessReceipt delivers the reward product after a completed view.
end)

Players.PlayerRemoving:Connect(function(p)
	busy[p] = nil
	lastAd[p] = nil
end)
```

The `WatchingAd` attribute is the hook for the docs' advice to **pause damage during ads or show them only in safe zones**: enemy AI skips targets with it, the round system extends their timer, the AFK kicker ignores them.

---

## 3. Rules for rewards and placements (Docs)

**Rewards must:**
- be developer products that would normally be sold for Robux in your shop;
- **not** be Robux, **not** randomized items, **not** currency that inflates the economy;
- be issued immediately after the ad finishes and match what was promised.
- Docs recommend rewards worth about **3 to 10 Robux**.

The "no randomized items" rule matters for RNG games: "watch an ad for a free roll" is a random reward. Offer a deterministic reward instead (a fixed amount of currency within the inflation rule, a timed boost, a revive).

**Placements:**
- High-traffic areas: lobbies, menus. Natural breaks: level complete, out of lives.
- Clearly disclose that the player is watching an ad, what they must do and what they get; a clear call to action of 1 to 2 clicks.

**Prohibited:**
- forcing an ad as a progress gate;
- taking over the screen or obscuring avatar motion;
- fraudulent rewards ("free Robux"), inaccurate descriptions, rewards that do not match the promise.

Violations can mean suspension, removal, revoked payouts or loss of ads eligibility (Docs).

**Exclude likely purchasers.** A dashboard option hides ads from players who are likely to buy. Docs advise against it when the reward is not purchasable. Rule of thumb: if the ad reward is a cheap version of a product, turning this on protects sales; test both with an experiment.

### Pacing (rule of thumb)
Docs set **no frequency cap** but track Frequency (ads per user per day) and warn not to trivialise progression. Patterns that work:
- One ad offer per natural break, not a permanent button.
- A daily cap per player (for example 5 to 10) enforced on the server.
- Reward tied to the moment: "Revive now", "Double this chest", "+15 minutes 2x cash".
- Never stack ad offers with purchase prompts in the same moment.

### Analytics (Docs)
Monetization, Ads, Analytics, filtered to Rewarded Video: Earnings, EPM, the funnel (Requested, Filled, Ad Opportunities, Impressions, Rewarded), Fill Rate, Daily Unique Viewers (DUV), AEPDUV, eDAU, DUV/eDAU, Opt-In Rate, Frequency. DUV-based metrics lag one day. The Eligibility page has a calculator for weekly earnings estimates. Pass a `placementId` so each placement reports separately; Docs suggest running an experiment on a percentage of users before rolling a placement out.

Log your own funnel too (offer shown, button pressed, reward received) with `LogFunnelStepEvent` so you can see where players drop. See [[Analytics and Funnels]].

---

## 4. Immersive ads

Ad units (image billboards, video, portals in some formats) placed in the 3D world, served by Roblox from advertisers (Docs, monetization overview). They pay on impressions. Relevant API members on `AdService` (Oct 2026): `RegisterAdOpportunityAsync(instance, placementId?)` and `RegisterDisclosureButton(button, placementId)`. Practical notes (rule of thumb):
- Place them where players look anyway (spawn plaza, queue areas) but not where they block gameplay.
- They count against draw calls and texture memory like any other surface ([[Rendering Performance]]).
- The same questionnaire and eligibility checks apply.

The immersive ads guide has its own format specs and rules; read it before placing units. This vault does not reproduce them.

---

## 5. Buying ads: Ads Manager

You can also pay to promote your game: sponsored placements on Home and search ads, run from Ads Manager in the Creator Hub. Things that matter for planning:
- **Recommendations only count organic players.** Engagement, retention and spending from players acquired through ads, search or friends are not used in the ranking stage of Recommended for You; ads can still speed up a game's *consideration* for recommendations (Docs, discovery page). So ads buy players and data; they do not directly buy ranking. See [[Discovery and the Algorithm]].
- **Ads buy you a test audience.** A small campaign right after launch tells you whether your thumbnail and first five minutes work before organic traffic arrives.
- **Kids and Select eligibility.** A beta Engagement objective targets players who count toward the highly engaged player threshold for all-ages eligibility; campaigns do not pause automatically at the threshold (Announcement, mid 2026). See [[Publishing an Experience]].
- Sponsored ads are measured in ad credits and Robux; ad credits are excluded from Plus discounts (Docs).

Rule of thumb: never buy ads for a game whose D1 retention you have not measured. You will pay to fill a leaky bucket.

---

## 6. Choosing reward value: a worked example

Docs recommend rewards worth about 3 to 10 Robux. Suppose your cheapest currency product is a small pack (call its contents C coins) sold at a price P Robux. A rewarded ad worth about 5 Robux would then be roughly `C x 5 / P` coins. Check it against three limits (rule of thumb):
1. **Inflation:** compare the daily maximum from ads (reward x your daily cap) with what a free player earns per day by playing. If ads add more than about 10 to 20% of daily free income, they start to replace play and the docs' "currency that inflates the economy" warning applies.
2. **Cannibalisation:** if a player can get a small pack's worth from a few ads, the small pack stops selling. Either use the "exclude likely purchasers" option or make the ad reward different in kind (a 15-minute 2x boost rather than coins).
3. **Delight:** the reward must feel worth 30 seconds. Timed boosts and "double this reward" moments feel larger than their Robux value because they multiply something the player just earned.

In RNG games the tempting reward is a free roll, which is not allowed (random). A deterministic alternative that feels similar: "watch to double the cash from your next 10 rolls" or "+15 minutes of 2x roll speed". The roll stays free and random; the ad reward is a fixed boost.

Log each placement's offer rate, opt-in rate and post-ad session length. A placement that lifts session length is helping retention, not just earning.

---

## 7. Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Button never shows | Not eligible (questionnaire pending, traffic below 2,000/month), Serving off, or availability not `IsAvailable` | Check the Eligibility page; Serving toggle |
| Ad plays, no reward | Receipt handler does not know the reward product | Add it to the grant table |
| Reward granted twice | Granted after `ShowRewardedVideoAdAsync` *and* in `ProcessReceipt` | Grant only in the receipt |
| Player dies while watching | No safe-zone rule | `WatchingAd` attribute; safe zones |
| Eligibility lost for a day | Questionnaire resubmitted | Resubmit only when answers change |
| Ads hurt sales | Ad reward too close to a cheap product | Turn on "exclude likely purchasers" or change reward |

## 8. Checklist
- [ ] Eligibility met: creator ID + 2SV, game public, approved questionnaire, 2,000+ monthly visitors
- [ ] Reward product is deterministic, not Robux, not random, not inflationary
- [ ] Availability checked right before offering; one check per play
- [ ] Server-side pacing and daily cap
- [ ] Damage paused / safe zone while watching
- [ ] Reward delivered only by `ProcessReceipt`
- [ ] Placement ids set; funnel logged
- [ ] Copy says it is an ad, what to do, what you get

## See also
[[Monetization Overview]] · [[Developer Products and ProcessReceipt]] · [[Roblox Policies Ratings and Compliance]] · [[Discovery and the Algorithm]] · [[Analytics and Funnels]] · [[Economies and Currencies]]

## Connected notes
<!-- auto-links:start -->
[[Sponsored Ads and Campaign Math]] · Official Docs - Monetization · Launch Strategy - The First Two Weeks · Marketing and Growth Start Here · Click-Through Rate · Shop with Game Passes and Developer Products End to End
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Robux Price Points and Offer Design]] · [[Unit Economics - ARPDAU, Payer Conversion, LTV and Ad Payback]] · [[Pricing and Store Design]] · [[Subscriptions and Premium Payouts]] · [[Game Passes]] · [[Live Ops Events and Updates]] · [[Community Building]] · [[Paid Random Items and Odds Disclosure in Practice]]
<!-- related:end -->
