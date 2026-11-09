---
tags: [avatars, ugc, avatar-creation, creation-token, editablemesh, editableimage, wrapdeformer, monetization, marketplace, luau, type/guide, area/avatars, level/advanced, api/AvatarCreationService, api/HumanoidDescription, area/monetization]
---
# In-Experience Avatar Creation - Tokens, Editing and Prompting

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Token owner lost ID verification or Premium/Plus -> Keep the owning account or group qualified
> - Avoid: Token from another experience, or wrong item type -> One token per type and price point, created on this experience
> - Avoid: Existing asset ids left in the description -> Only `BodyPartDescription` children pointing at edited folders
> - Token created on this experience, item type correct, price checked on the Create Token screen.
> - Owner or group stays ID-verified with Premium or Plus.
> - Enable Mesh / Image APIs turned on for the published experience.
>
> Cost: TL;DR ~180 tok · whole note ~3.2k tok. Read more: ## 4. The editing flow · ## 5. Building the description and prompting · ## Common mistakes · ## Checklist
<!-- tldr:end -->

An avatar editor ([[AvatarEditorService and In-Game Avatar Editors]]) lets players wear items that already exist. **In-experience creation** goes further: players reshape and repaint a body (or make an accessory or a makeup look) inside your game, then buy it as a **new item that lands in their Roblox inventory**. The player becomes the item's creator, your experience is the publisher and earns Marketplace commission, and every created item links back to your game. This note covers the money model, the setup, the editing flow, the prompt, moderation and attribution.

Source labels: **Roblox docs** (the `AvatarCreationService` reference, the in-experience creation guide and the avatar creation token page, checked as of November 2026), **Rule of thumb**, **Unverified**. References:
- https://create.roblox.com/docs/reference/engine/classes/AvatarCreationService
- https://create.roblox.com/docs/avatar/in-experience-creation
- https://create.roblox.com/docs/production/monetization/avatar-creation-token

---

## 1. The money model

- You buy an **avatar creation token** per item type and price point in the Creator Dashboard (Creations ⟩ your experience ⟩ Monetization ⟩ Avatar Creation Tokens ⟩ Create Token). Each token costs a **Creation Advance** (based on current publishing advance prices for that item type, and described as fully recoupable) plus a **Creation Fee**; the dashboard shows the combined total before you buy. **Roblox docs.**
- The token sets what players pay: an **Amount Above Price Floor** plus an optional **Do not price below** minimum, both editable later. Want two price points for bodies? Buy two tokens. The **Item Type cannot be changed** after creation. **Roblox docs.**
- The player pays the price; the experience owner earns **Marketplace commissions** (as publisher; the token page says as both creator and game owner). Rates are on the Marketplace fees page, summarised in [[UGC Avatar Items and Accessories]] and [[UGC Pricing Limiteds and Marketplace Rules]]. **Roblox docs.**
- Items created in-experience are **not listed on the Marketplace and cannot be resold or traded**. **Roblox docs.**
- Exact advance and fee amounts change; **Unverified** figures quoted in older announcements are not repeated here. Read the live total on the Create Token screen.

## 2. Requirements and switches

| Requirement | Detail | Source |
|---|---|---|
| Token owner meets Marketplace creator requirements | ID-verified with a Roblox Premium or Plus subscription; must **stay** qualified or the token stops being valid | **Roblox docs** |
| Token belongs to this universe | A token from another experience fails | **Roblox docs** |
| Enable Mesh / Image APIs | Needed by the editing APIs and several `AvatarCreationService` methods ([[EditableMesh - Runtime Mesh Editing, Budgets and Publishing]]) | **Roblox docs** |
| A base body | A `Model` that meets the 15-part body specification and the Marketplace avatar body guidelines, including the minimum [[FACS]] controls; set up with the Importer and Avatar Setup (or Avatar Auto Setup for a single mesh) | **Roblox docs** |

## 3. Token types and which prompt to call

| Creating | Token item type | Method |
|---|---|---|
| A full body (bundle + outfit) | Body | `PromptCreateAvatarAsync(tokenId, player, humanoidDescription)` |
| One accessory or clothing asset | That asset type | `PromptCreateAvatarAssetAsync(tokenId, player, assetInstance, assetType)` |
| A makeup look of 2 to 6 layers | One token per layer, type matching the layer | `PromptCreateMakeupAsync(player, entries, thumbnailHeadColor?)` (server only) |

All three yield and take their price from the token; `GetBatchTokenDetailsAsync(tokenIds)` returns each token's name, creator, on-sale state, price and off-sale reasons, which is what your shop UI should display. **Roblox docs.**

## 4. The editing flow

From the official guide (**Roblox docs**):
1. **Set up each body `MeshPart`.** If it has a `WrapTarget`, add a `WrapDeformer` driven by a cage `EditableMesh`; otherwise put an `EditableMesh` on it directly. Create one `EditableImage` per texture, and reuse it when parts share a texture id.
2. **Repaint** with `EditableImage` drawing (`DrawRectangle` for recolours, `DrawImage` for stickers, transformed or projected draws for placement). See [[EditableImage for Pixel Buffers and Procedural 2D]].
3. **Reshape** by moving cage vertices (`FindVerticesWithinSphere` then `SetPosition`) and applying them with `WrapDeformer:SetCageMeshContent()`.
4. **Hair** gets an `EditableImage` and an `EditableMesh` but no `WrapDeformer`.
5. **Preview honestly.** After cage or mesh edits, `PrepareAvatarForPreviewAsync(model)` regenerates surface data and fixes attachment points so the preview matches the published result.
6. **Validate in Studio.** `GetValidationRules()` returns the live UGC limits (triangles, texture size, body bounds, attachment positions). `ValidateUGCBodyPartAsync`, `ValidateUGCAccessoryAsync` and `ValidateUGCFullBodyAsync` return pass or fail with reasons, but are **Studio only**, so use them in your test harness and clamp edits in-game to what passes.

**Rule of thumb:** design the editor so players cannot leave the valid range: clamp sliders and sculpt brushes to the bounds from `GetValidationRules()` instead of letting a purchase fail at the last step.

## 5. Building the description and prompting

The `HumanoidDescription` needs six `BodyPartDescription` children (Head, Torso, LeftArm, RightArm, LeftLeg, RightLeg), each pointing at a `Folder` of that part's `MeshPart`s. Do **not** include existing asset ids. Scales are optional but must match the base body's import scales. Hair can go in as an `AccessoryDescription`. **Roblox docs.**

```lua
--!strict
local AvatarCreationService = game:GetService("AvatarCreationService")

local BODY_TOKEN_ID = "REPLACE_ME" -- Creator Dashboard > Monetization > Avatar Creation Tokens > Copy Token ID

local function buildDescription(folders: { [Enum.BodyPart]: Folder }, base: HumanoidDescription): HumanoidDescription
	local desc = Instance.new("HumanoidDescription")
	-- Scales must match the base body's import scales
	desc.BodyTypeScale = base.BodyTypeScale
	desc.HeadScale = base.HeadScale
	desc.HeightScale = base.HeightScale
	desc.WidthScale = base.WidthScale
	desc.ProportionScale = base.ProportionScale
	for bodyPart, folder in folders do
		local partDesc = Instance.new("BodyPartDescription")
		partDesc.BodyPart = bodyPart
		partDesc.Instance = folder
		partDesc.Parent = desc
	end
	return desc
end

local function promptCreateBody(player: Player, desc: HumanoidDescription): boolean
	local ok, result, bundleIdOrError, outfitId = pcall(function()
		return AvatarCreationService:PromptCreateAvatarAsync(BODY_TOKEN_ID, player, desc)
	end)
	if not ok then
		warn("Avatar creation prompt errored:", result)
		return false
	end
	if result == Enum.PromptCreateAvatarResult.Success then
		print("Created bundle", bundleIdOrError, "outfit", outfitId)
		return true
	end
	-- Cancelled, validation failed, token off sale and so on: tell the player, never retry in a loop
	print("Not created:", result, bundleIdOrError)
	return false
end
```

**Unverified:** which side must call `PromptCreateAvatarAsync`. The reference gives it a `Player` argument and lists no client or server restriction, while the editing runs on the client (client memory budget, `EditableMesh`). Follow the official Avatar Creator demo the guide links, and test the call from the side you choose in a published place before building UI around it.

## 6. After the purchase: moderation

Created items start **not reviewed**. On the client, `AvatarCreationService.AvatarAssetModerationCompleted` (single assets) and `AvatarOutfitModerationCompleted` (outfits; replaces the deprecated `AvatarModerationCompleted`) fire when the status changes; they only cover items created in the current experience. An outfit cannot be used until its status allows it. **Roblox docs.**

**Rule of thumb:** show a "Submitted, in review" state with the item's thumbnail, and do not promise the player can wear it immediately. A rejected item is the platform's decision; point players to Roblox support rather than offering refunds you cannot make ([[Refunds Chargebacks and Purchase Support]]).

## 7. Attribution: free growth

Every created item links back to your experience. Players who arrive from it join with `Player:GetJoinData()` whose `GameJoinContext` has `JoinSource` set to `Enum.JoinSource.CreatedItemAttribution`. **Roblox docs.** Log that as its own acquisition source ([[Analytics and Funnels]]) and drop those newcomers straight into the creator, because they came to make what they saw.

## 8. Photo-to-avatar generation (early)

`AvatarCreationService` also has generation methods: `PromptSelectAvatarGenerationImageAsync` (asks for a selfie, server only), `RequestAvatarGenerationSessionAsync`, `GenerateAvatar2DPreviewAsync`, `GenerateAvatarAsync`, `LoadGeneratedAvatarAsync` and `AutoSetupAvatarAsync`. **Roblox docs** for the members. Their availability was announced as an early alpha and beta in 2025; **Unverified** whether they are generally available to every experience as of November 2026. Selfie capture involves sensitive input: follow [[Player Privacy and Data Deletion]] and [[Policy and Age Rules 2026]], and never store the image yourself.

## 9. Design notes

- **Sell the making, not just the item** (**Rule of thumb**). Free sculpting and dressing up with a single clear "Make it mine" purchase at the end converts better than paywalled tools, and keeps the experience fun for non-buyers ([[Ethical Design and Player Trust]]).
- Show the full price, including that it is a Robux purchase of a new item, before the prompt. Players should never meet a surprise price in the platform dialog ([[Pricing and Store Design]]).
- Budget memory: an editor holding a full body's editable meshes and images is one of the heaviest things a phone can run. Release editable assets when the player leaves the editor.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Token owner lost ID verification or Premium/Plus | Creation APIs stop working for the whole experience | Keep the owning account or group qualified |
| Token from another experience, or wrong item type | Prompt fails immediately | One token per type and price point, created on this experience |
| Existing asset ids left in the description | Creation rejected | Only `BodyPartDescription` children pointing at edited folders |
| Scales that differ from the base body's import scales | Proportions wrong or creation fails | Copy the base body's scales |
| Skipping `PrepareAvatarForPreviewAsync` after cage edits | Preview and created item look different | Call it after every cage or mesh edit before showing the preview |
| Letting edits leave the UGC bounds | Purchase fails at the final step | Clamp tools to `GetValidationRules()`; validate in Studio tests |
| Promising instant wear | Support complaints while items are in review | Show the review state; listen for the moderation events |
| Mesh / Image APIs disabled | Editor works in Studio, fails live | Enable the setting in Creator Dashboard |

## Checklist
- [ ] Token created on this experience, item type correct, price checked on the Create Token screen.
- [ ] Owner or group stays ID-verified with Premium or Plus.
- [ ] Enable Mesh / Image APIs turned on for the published experience.
- [ ] Base body meets the 15-part spec and FACS minimum.
- [ ] Edits clamped to `GetValidationRules()`; Studio test harness runs the `ValidateUGC*` checks.
- [ ] Preview prepared with `PrepareAvatarForPreviewAsync`.
- [ ] Prompt wrapped in `pcall`; every non-success result shown to the player, never auto-retried.
- [ ] Review state shown until the moderation event allows use.
- [ ] `CreatedItemAttribution` joins tracked and routed to the creator.

## See also
[[Avatars and UGC Start Here]] · [[AvatarEditorService and In-Game Avatar Editors]] · [[HumanoidDescription and Outfit Systems]] · [[Layered Clothing Creation Workflow]] · [[UGC Avatar Items and Accessories]] · [[UGC Pricing Limiteds and Marketplace Rules]] · [[EditableMesh - Runtime Mesh Editing, Budgets and Publishing]] · [[Monetization Overview]]

<!-- related:start -->
## Related
[[Bundles Animation Packs and Emotes for Sale]] · [[Commerce and Physical Goods]] · [[Subscriptions and Premium Payouts]] · [[3D Importer Settings Reference]] · [[Game Passes]] · [[Avatar Body Types and Scale in Gameplay]]
<!-- related:end -->
