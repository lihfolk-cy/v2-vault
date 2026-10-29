---
tags: [avatars, ugc, avatar-editor, avatareditorservice, humanoiddescription, catalog, ui, security, type/guide, area/avatars, level/intermediate, api/AvatarEditorService]
---
# AvatarEditorService and In-Game Avatar Editors

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Sending a `HumanoidDescription` through a remote -> Send ids; build on server
> - Avoid: No asset-type check -> `GetProductInfoAsync` allow-list
> - Avoid: Overlapping applies -> Latest-wins queue
> - Browse, try-on, save and buy are separate flows with separate UI states.
> - Every `Async` getter is in `pcall`; every prompt waits on its `*Completed` event.
> - Inventory permission requested only when needed; declined handled gracefully.
>
> Cost: TL;DR ~150 tok · whole note ~5.7k tok. Read more: ## 3. Catalog browsing on the client · ## 4. Try-on: the server decides · ## Common mistakes · ## Checklist
<!-- tldr:end -->

An in-game avatar editor is one of the most requested features in hangout, roleplay and fashion games, and one of the easiest to build badly. The obvious version (a grid of catalog items, click to wear, a "Save" button) hides four separate systems: catalog browsing, server-side try-on, platform saving, and commerce. Each has its own permission model, failure modes and trust boundary. This note goes past the basics in [[UGC Avatar Items and Accessories]] and [[HumanoidDescription and Outfit Systems]] and covers how `AvatarEditorService` actually behaves, how to split work between client and server, and the edge cases that turn a pretty editor into a support queue.

API names and capabilities below are **Roblox docs (as of October 2026)**. Several methods were renamed with an `Async` suffix during 2026; the old names still appear in tutorials and are marked deprecated in the reference.

## 1. Four jobs, four trust levels

| Job | Who does it | API | Trust |
|---|---|---|---|
| Browse the catalog and the player's inventory | Client | `SearchCatalogAsync`, `GetInventoryAsync`, `GetItemDetailsAsync`, `GetBatchItemDetailsAsync`, `GetOutfitsAsync` | Read-only, cosmetic; client data is fine for display |
| Show the change on the character for everyone | Server | `Humanoid:ApplyDescriptionAsync` | Must validate: the client chooses ids, the server decides |
| Save to the player's real avatar or outfits | Client, via a Roblox prompt | `PromptSaveAvatar`, `PromptCreateOutfit`, `PromptUpdateOutfit` | Roblox owns the decision; the player confirms in a system prompt |
| Sell items | Client prompt, server-observed | `MarketplaceService:PromptPurchase`, `PlayerOwnsAssetAsync` | Roblox owns the transaction; your game earns a commission |

The mistake most editors make is treating these as one flow. A try-on is not a save, a save is not a purchase, and a purchase does not change what the character is wearing in your game until you apply it. Keep them as separate code paths with separate UI states.

## 2. What AvatarEditorService is and is not

`AvatarEditorService` (AES) is a client-facing bridge to the player's Roblox account: their inventory, outfits, favourites, and the catalog. It has **no properties**, only methods and `*Completed` events (docs). It is not what changes the character in your game; that is `Humanoid:ApplyDescriptionAsync`, which works without AES at all.

Two families of methods matter:

- **Getters ending in `Async`** yield and hit web services. Wrap every call in `pcall`. They fail under load, on bad ids, and when the player has not granted access.
- **`Prompt*` methods** do not yield. They show a system dialog and report the outcome through a matching event (`PromptSaveAvatarCompleted`, `PromptCreateOutfitCompleted`, `PromptAllowInventoryReadAccessCompleted` and so on) carrying an `Enum.AvatarPromptResult`. Your UI must wait on the event, not on the call.

Capabilities listed in the reference (as of October 2026): inventory and outfit reads need `Players` and `AssetRead`; prompts that change the account need `Players` and `PlatformAvatarEditing`; catalog search needs `AssetRead`. These matter if you run editor code inside sandboxed scripts with restricted capabilities.

### The inventory permission

Reading the player's inventory or owned head shapes requires `PromptAllowInventoryReadAccess()` first, and checking that the completed event returns `Enum.AvatarPromptResult.Success`. The docs say the request is needed once per session. Design consequences:

- **Do not prompt on join.** A permission dialog before the player has seen anything reads like a scam and gets declined. Prompt when they open the "My Items" tab.
- **Declined is a normal state.** Show the catalog and try-on anyway; only the "My Items" tab needs the permission. Offer a retry button, not a retry loop.
- **Do not cache "granted" in a DataStore.** It is per session. Ask again next session when they open the tab.

## 3. Catalog browsing on the client

```lua
--!strict
-- Client: page through catalog search results for one asset type.
local AvatarEditorService = game:GetService("AvatarEditorService")

type CatalogItem = { Id: number, Name: string, [string]: any }

local function searchCatalog(keyword: string, assetType: Enum.AvatarAssetType): CatalogPages?
	local params = CatalogSearchParams.new()
	params.SearchKeyword = keyword
	params.AssetTypes = { assetType }
	params.SortType = Enum.CatalogSortType.Relevance
	params.IncludeOffSale = false -- off-sale items cannot be bought or saved by most players

	local ok, result = pcall(function()
		return AvatarEditorService:SearchCatalogAsync(params)
	end)
	if not ok then
		warn("Catalog search failed:", result)
		return nil
	end
	return result :: CatalogPages
end

local function readPage(pages: CatalogPages): { CatalogItem }
	return pages:GetCurrentPage() :: { CatalogItem }
end

local function nextPage(pages: CatalogPages): boolean
	if pages.IsFinished then
		return false
	end
	local ok = pcall(function()
		pages:AdvanceToNextPageAsync()
	end)
	return ok
end
```

`CatalogSearchParams` fields (docs): `AssetTypes`, `BundleTypes`, `CategoryFilter`, `MaxPrice`, `MinPrice` (default 0), `SearchKeyword`, `SortType` (default Relevance), `IncludeOffSale` (default false), `CreatorId`, `CreatorName`.

Nuances that matter in production:

- **Filter by creator for curated shops.** A "brand store" or "our group's items" tab should set `CreatorId` (or `CreatorName`) rather than searching keywords and filtering client-side; results are paged and you would otherwise throw most pages away.
- **Results include bundles if you ask for them.** A bundle is not an asset id. Try-on code that expects asset ids will break on a bundle id. Either keep bundles in a separate tab or expand them with `GetItemDetailsAsync(id, Enum.AvatarItemType.Bundle)` and read the contained items (field names are not fully documented on the reference page; log the dictionary once and code against what you see).
- **Thumbnails.** Use `rbxthumb://type=Asset&id=<id>&w=150&h=150` in an `ImageLabel` rather than downloading anything. Only certain sizes are valid per type (150 and 420 are the common asset sizes, rule of thumb); an invalid size silently shows nothing.
- **Lists get long.** A catalog tab is an infinite list: virtualise it (render only visible rows) and append pages on scroll. See [[Virtualized Lists and Large Inventories]]. A naive grid of 1,000 `ImageButton`s is a classic mobile frame-time killer.
- **Debounce typing.** Search on submit or after 400 to 600 ms of no typing (rule of thumb). Searching on every keystroke issues a web request per character and will hit throttles. AES rate limits are **not documented** as of October 2026; assume they exist and back off on failure.
- **Timed options (rentals).** Search results and item details can carry a `TimedOptions` array with durations and prices for items that support timed ownership, and inventory entries can carry an `ExpirationTime` (docs examples). Do not hardcode the durations: the docs warn the options may change. Show "Rent for X days" only when the field is present.

## 4. Try-on: the server decides

Try-on means "everyone in the server sees me wearing this item, even though I do not own it". That is allowed: players may wear unowned catalog items inside your experience. It is also the part attackers abuse, because the client sends arbitrary numbers.

### Why the client cannot send a HumanoidDescription

A `HumanoidDescription` created on the client exists only on the client. Passing it through a `RemoteEvent` delivers `nil` to the server, because instances that do not exist on the receiving side arrive as nil. Even if it did arrive, you would be trusting a client-built object. Send a **compact request** (asset id plus intent) and build the description on the server.

### What to validate

| Check | Why | How |
|---|---|---|
| Type and range of the id | Remotes accept any value | `typeof(id) == "number"`, integer, positive, below 2^53 |
| Asset type | Someone sends a decal, a model, a place id | `MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Asset)` and compare `AssetTypeId` against an allow-list; cache results |
| Count | 200 accessories on one character lags every client | Cap total try-on items (8 to 12 is plenty, rule of thumb) |
| Rate | Spamming applies is a server load attack | Latest-wins queue per player plus a minimum interval |
| Moderation state | Moderated or deleted assets fail to load | `pcall` the apply; on failure drop the item and tell the client |
| Game rules | Your game may ban some types (huge back items in an obby) | Allow-list per game mode |

`ApplyDescriptionAsync` and its siblings also take an optional `Enum.AssetTypeVerification` argument (docs, default `Default`). It controls how strictly the engine checks that each id is the right kind of asset for its slot. Leave it at the default for player-driven try-on; do your own allow-list check on top, because a type check does not stop someone wearing twelve hats.

### Latest-wins application

`ApplyDescriptionAsync` yields while it loads meshes and textures. If the player clicks five items in two seconds, five overlapping applies race, and the final look depends on which finished last. Collapse requests: keep only the newest pending state per player, and apply one at a time.

```lua
--!strict
-- Server: validated, rate-limited, latest-wins try-on.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TryOnRemote = ReplicatedStorage:WaitForChild("TryOn") :: RemoteEvent

local MAX_TRY_ON = 10
local MIN_INTERVAL = 0.5 -- seconds between applies per player (rule of thumb)

-- Rigid accessory types allowed for try-on in this game.
local RIGID: { [number]: Enum.AccessoryType } = {
	[Enum.AssetType.Hat.Value] = Enum.AccessoryType.Hat,
	[Enum.AssetType.HairAccessory.Value] = Enum.AccessoryType.Hair,
	[Enum.AssetType.FaceAccessory.Value] = Enum.AccessoryType.Face,
	[Enum.AssetType.NeckAccessory.Value] = Enum.AccessoryType.Neck,
	[Enum.AssetType.ShoulderAccessory.Value] = Enum.AccessoryType.Shoulder,
	[Enum.AssetType.FrontAccessory.Value] = Enum.AccessoryType.Front,
	[Enum.AssetType.WaistAccessory.Value] = Enum.AccessoryType.Waist,
	-- Back accessories left out on purpose: large wings block the camera in this game.
}

-- Layered clothing types allowed.
local LAYERED: { [number]: Enum.AccessoryType } = {
	[Enum.AssetType.TShirtAccessory.Value] = Enum.AccessoryType.TShirt,
	[Enum.AssetType.ShirtAccessory.Value] = Enum.AccessoryType.Shirt,
	[Enum.AssetType.SweaterAccessory.Value] = Enum.AccessoryType.Sweater,
	[Enum.AssetType.JacketAccessory.Value] = Enum.AccessoryType.Jacket,
	[Enum.AssetType.PantsAccessory.Value] = Enum.AccessoryType.Pants,
	[Enum.AssetType.ShortsAccessory.Value] = Enum.AccessoryType.Shorts,
	[Enum.AssetType.DressSkirtAccessory.Value] = Enum.AccessoryType.DressSkirt,
}

-- Layer order for layered clothing: inner garments first.
local LAYER_ORDER: { [Enum.AccessoryType]: number } = {
	[Enum.AccessoryType.TShirt] = 1,
	[Enum.AccessoryType.Shirt] = 2,
	[Enum.AccessoryType.Pants] = 2,
	[Enum.AccessoryType.Shorts] = 3,
	[Enum.AccessoryType.DressSkirt] = 4,
	[Enum.AccessoryType.Sweater] = 5,
	[Enum.AccessoryType.Jacket] = 6,
}

type Kind = { accessoryType: Enum.AccessoryType, layered: boolean }

local typeCache: { [number]: Kind | false } = {}

local function classify(assetId: number): Kind?
	local cached = typeCache[assetId]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(assetId, Enum.InfoType.Asset)
	end)
	if not ok or typeof(info) ~= "table" then
		return nil -- do not cache transient failures
	end
	local typeId = info.AssetTypeId
	local kind: Kind | false = false
	if RIGID[typeId] then
		kind = { accessoryType = RIGID[typeId], layered = false }
	elseif LAYERED[typeId] then
		kind = { accessoryType = LAYERED[typeId], layered = true }
	end
	typeCache[assetId] = kind
	return if kind then kind else nil
end

-- Per-player state
local baseDescription: { [Player]: HumanoidDescription } = {}
local pending: { [Player]: { number } } = {}
local busy: { [Player]: boolean } = {}
local lastApply: { [Player]: number } = {}

local function buildDescription(player: Player, ids: { number }): HumanoidDescription?
	local base = baseDescription[player]
	if not base then
		return nil
	end
	local desc = base:Clone()
	local list = desc:GetAccessories(true) -- rigid and layered
	for _, id in ids do
		local kind = classify(id)
		if kind then
			if kind.layered then
				table.insert(list, {
					AssetId = id,
					AccessoryType = kind.accessoryType,
					IsLayered = true,
					Order = LAYER_ORDER[kind.accessoryType] or 5,
				})
			else
				table.insert(list, {
					AssetId = id,
					AccessoryType = kind.accessoryType,
					IsLayered = false,
				})
			end
		end
	end
	desc:SetAccessories(list, true)
	return desc
end

local function pump(player: Player)
	if busy[player] then
		return
	end
	busy[player] = true
	while pending[player] do
		local remaining = MIN_INTERVAL - (os.clock() - (lastApply[player] or 0))
		if remaining > 0 then
			task.wait(remaining)
		end
		local ids = pending[player]
		pending[player] = nil
		if not ids or player.Parent == nil then
			break
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local desc = buildDescription(player, ids)
		if humanoid and desc then
			local ok, err = pcall(function()
				humanoid:ApplyDescriptionAsync(desc)
			end)
			if not ok then
				warn("Try-on apply failed for", player.UserId, err)
			end
		end
		lastApply[player] = os.clock()
	end
	busy[player] = nil
end

TryOnRemote.OnServerEvent:Connect(function(player: Player, ids: unknown)
	if typeof(ids) ~= "table" then
		return
	end
	local clean: { number } = {}
	for _, v in ids :: { any } do
		if #clean >= MAX_TRY_ON then
			break
		end
		if typeof(v) == "number" and v > 0 and v < 2 ^ 53 and v % 1 == 0 then
			table.insert(clean, v)
		end
	end
	pending[player] = clean -- latest wins: older pending requests are dropped
	task.spawn(pump, player)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAppearanceLoaded:Connect(function(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and not baseDescription[player] then
			-- Capture the player's own look once, before any try-on.
			baseDescription[player] = humanoid:GetAppliedDescription()
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	baseDescription[player] = nil
	pending[player] = nil
	busy[player] = nil
	lastApply[player] = nil
end)
```

Design notes on this code:

- **Base plus delta, not cumulative.** Each apply rebuilds from the saved base, so "take off" is just sending a shorter list. Cumulative edits drift: one failed apply leaves the character in an unknown state.
- **Capture the base once.** `CharacterAppearanceLoaded` fires on every respawn; capturing on every spawn after a try-on would make the try-on the new "real" look. Reset the base explicitly when the player presses "Reset to my avatar".
- **Respawn re-applies.** After death, the character loads the platform avatar again. If try-on should persist across deaths, re-run the queue from `CharacterAdded` with the last list.
- **`GetProductInfoAsync` is cached** because it is a web call with its own limits. Cache negative results (wrong type) but not failures.

## 5. Saving to the platform

`PromptSaveAvatar(description, rigType)` asks the player to make a description their real Roblox avatar; `PromptCreateOutfit` saves it as a new outfit without replacing the current avatar (docs). Both are client calls, both show a Roblox dialog, both return through events.

The rule that surprises players: **items they do not own are not saved** ("users don't receive catalog items they don't own", docs). A player who builds a full look from try-on items, presses Save, and sees only their old shirt on the website will report your game as broken. Handle it before the prompt:

1. On the client, compute which items in the current look are unowned. Ownership checks for display can use `MarketplaceService:PlayerOwnsAssetAsync` from the server or the inventory reads you already have.
2. If any are unowned, show a "Buy missing items" step: list them with prices, one `PromptPurchase` per item, or a "Favourite these" option via `PromptSetFavorite`.
3. Only then call the save prompt, with a clear line: "Items you don't own won't be saved."

Purchases made inside your experience earn the experience owner a commission (40 percent on in-experience Marketplace purchases, as documented in [[UGC Avatar Items and Accessories]]); purchases the player makes later on the website earn you nothing. That is the business reason to put "Buy" next to "Try".

### Failure cases to handle

| Event result | Meaning | UI |
|---|---|---|
| `Success` | Saved | Toast, no further action |
| `PermissionDenied` | Player declined | Silent; return to editor |
| `Failed` | Service error | "Couldn't save, try again" with retry |
| Create-outfit `failureType` | `OutfitLimitReached`, `InvalidName`, `Other` (docs sample) | Specific text; for the limit, suggest updating an existing outfit with `PromptUpdateOutfit` |

The number of outfits a player may have is **not documented** on the AES page (as of October 2026); do not print a number.

## 6. Commerce and policy edges

- **Purchase prompts from try-on.** Call `MarketplaceService:PromptPurchase(player, assetId)` on the client or server. Listen for `PromptPurchaseFinished` but re-check ownership server-side before granting anything game-side; the finished event is not a receipt.
- **Do not imply ownership.** Labels like "Get" on a try-on item are misleading. Use "Try on" and "Buy".
- **Paid random cosmetics** (crates that award avatar items) are paid random items: odds disclosure rules apply. See [[Paid Random Items and Odds Disclosure in Practice]].
- **Rentals** (timed options) are real purchases with an expiry; show the expiry and never present a rental as permanent.
- **Off-sale and Limited items** in try-on: they can be worn in-game but usually cannot be bought; mark them "Not for sale" instead of offering a prompt that will fail.

## 7. Performance and scale

Applying a description loads meshes, textures and cages, and on layered clothing it re-runs the cage fit for every layer on the body. In a 30-player hangout:

- **Cost lands on every client**, not just the wearer, because everyone renders the result. Ten players spinning through outfits at once is visible as hitching on low-end phones (rule of thumb from hangout games; measure with the MicroProfiler).
- **Throttle per player** (the 0.5 s floor above) and **globally** if needed: a server-wide budget of a few applies per second keeps spikes bounded.
- **Preview locally first.** For browsing, render the item on a local clone of the character in a `ViewportFrame`, and only send the try-on to the server when the player taps "Wear". The local preview can use a client-side `HumanoidDescription` on a client-only model (it never replicates, so nobody else pays). This one change cuts server applies by an order of magnitude.

## 8. When not to build an editor

- **Competitive games where silhouette matters.** A shooter with try-on means players hunt the smallest, darkest look. Use Avatar Settings limits instead ([[Avatar Body Types and Scale in Gameplay]]).
- **Games with fixed characters.** If everyone plays a class or a creature, an editor fights your art direction. A small set of in-game skins is cheaper.
- **Tiny teams without moderation capacity.** An editor shows arbitrary catalog content next to your branding. Curate with `CreatorId` or a hand-picked list.

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Sending a `HumanoidDescription` through a remote | Server receives nil | Send ids; build on server |
| No asset-type check | Players wear decals or models; errors in output | `GetProductInfoAsync` allow-list |
| Overlapping applies | Wrong final outfit, flicker | Latest-wins queue |
| Cumulative edits | Items "stick" after removal | Rebuild from base each time |
| Inventory prompt on join | Declined permission, empty "My Items" | Prompt on tab open |
| Saving unowned items without warning | "Your game deleted my outfit" reports | Pre-save ownership step |
| Searching every keystroke | Throttled search, empty results | Debounce |
| Hardcoded rental durations | Wrong text after Roblox changes options | Read `TimedOptions` |
| Full grid of all results | Mobile lag | Virtualised list, paging |

## Checklist

- [ ] Browse, try-on, save and buy are separate flows with separate UI states.
- [ ] Every `Async` getter is in `pcall`; every prompt waits on its `*Completed` event.
- [ ] Inventory permission requested only when needed; declined handled gracefully.
- [ ] Server validates id type, asset type, count and rate; latest-wins queue.
- [ ] Try-on rebuilds from a captured base description; reset button restores it.
- [ ] Local `ViewportFrame` preview before server apply.
- [ ] Unowned items flagged before save; buy and favourite offered.
- [ ] Rentals, off-sale and Limited items labelled honestly.
- [ ] Tested on a low-end phone with a full server swapping outfits.

## See also

[[Avatars and UGC Start Here]] · [[HumanoidDescription and Outfit Systems]] · [[UGC Avatar Items and Accessories]] · [[UGC Pricing Limiteds and Marketplace Rules]] · [[Avatar Body Types and Scale in Gameplay]] · [[Server Authority and Validation]] · [[Remote Abuse Patterns and Rate Limiting in Practice]] · [[Virtualized Lists and Large Inventories]] · [[Genre Playbook - Roleplay and Social Hangouts]] · [[Ethical Design and Player Trust]] · [[Monetization Overview]]

## Connected notes
<!-- auto-links:start -->
[[Avatar Context Menus Profiles and Social Surfaces]] · Commerce and Physical Goods · [[Bundles Animation Packs and Emotes for Sale]] · Platform Features Start Here · Cookbook - Players and Characters · Official Docs - Asset Creation
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Commerce and Physical Goods]] · [[Character Select and Class Systems with Different Rigs]] · [[Layered Clothing Creation Workflow]] · [[MarketplaceService - Engine Reference Card]] · [[Emotes and Social Animation]] · [[Game Passes]]
<!-- related:end -->
