---
tags: [avatars, humanoiddescription, outfits, characters, data, npc, luau]
---
# HumanoidDescription and Outfit Systems

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Starting from `Instance.new("HumanoidDescription")` -> Start from `GetAppliedDescription()`
> - Avoid: Mixing manual accessory edits with diff applies -> One owner, or `ApplyDescriptionResetAsync`
> - Avoid: `SetAccessories(layered, true)` -> Read all, modify, write back
> - One system owns appearance; others are additive or go through it.
> - Edits start from `GetAppliedDescription()`.
> - Reset variant used after other systems touched the character.
>
> Read more (19 KB note): ## 1. The mental model: target state plus a cache · ## 5. Storing outfits as data · ## Common mistakes · ## Checklist
<!-- tldr:end -->

`HumanoidDescription` is the declarative recipe for how a Humanoid character looks: body part ids, colours, scales, accessories, classic clothing, animations and emotes. You build a description, apply it, and the engine works out what to add, remove and resize. Almost every avatar feature in a game (uniforms, saved outfits, NPC crowds, morphs, disguises, loading screens with the player's avatar) is a description operation underneath. This note covers the mechanics the API reference does not spell out: the cached "applied" description, diff versus reset, merging a game uniform over a player's own look, storing outfits as data, and building many NPCs cheaply.

For the in-game editor UI and catalog side, see [[AvatarEditorService and In-Game Avatar Editors]]. For how the character itself works (states, health, spawning), see [[Characters and Humanoids]].

## 1. The mental model: target state plus a cache

A Humanoid remembers the last description applied to it. `Humanoid:GetAppliedDescription()` returns a **copy** of that cached description (docs). When you call `ApplyDescriptionAsync(newDesc)`, the engine compares `newDesc` with the cache and changes only what differs.

That diff is fast, and it is also the source of the most confusing bug in avatar code:

> If something else changed the character since the last apply (a script added an accessory with `Humanoid:AddAccessory`, deleted the Shirt instance, or swapped a body part by hand), the cache no longer matches reality, and `ApplyDescriptionAsync` may apply the description incorrectly (docs).

`ApplyDescriptionResetAsync` exists for exactly this case: it always makes the character match the description fully, ignoring the cache. It costs more because it rebuilds everything.

| Method (as of October 2026) | Behaviour | Use when |
|---|---|---|
| `Humanoid:ApplyDescriptionAsync(desc, verification?)` | Diff against cached applied description | Your code is the only thing that changes appearance |
| `Humanoid:ApplyDescriptionResetAsync(desc, verification?)` | Full reapply | Other systems touched the character, or you are unsure |
| `Humanoid:GetAppliedDescription()` | Copy of the cache | Start every edit from this, not from a blank description |
| `Players:GetHumanoidDescriptionFromUserIdAsync(userId)` | A user's current avatar | Mirrors, statues, "play as your friend" |
| `Players:GetHumanoidDescriptionFromOutfitIdAsync(outfitId)` | A saved outfit | Loading platform outfits |
| `Players:CreateHumanoidModelFromDescriptionAsync(desc, rigType, verification?)` | A full new character Model | NPCs, previews, statues |
| `Player:LoadCharacterWithHumanoidDescriptionAsync(desc, verification?)` | Spawn with a look | Uniform games that should never show the player's own avatar |

The non-`Async` names (`ApplyDescription`, `GetHumanoidDescriptionFromUserId`, `CreateHumanoidModelFromDescription` and so on) are deprecated in the current reference; you will still meet them in older code. The behaviour is the same.

**Where to call it.** Apply to player characters from the server, so the change replicates. The current reference page does not state a server-only restriction, and older guidance described `ApplyDescription` as server-only; treat that as **unconfirmed** for October 2026 and keep player-character applies on the server regardless (rule of thumb: it is the only place the result is authoritative). Client-side use is fine for client-only models such as a `ViewportFrame` preview.

**The golden rule:** pick one owner for appearance. If your armour system adds parts by hand and your outfit system applies descriptions, they will fight. Either make armour go through descriptions, or make armour purely additive and never touch slots the description owns (see [[Accessories and Armor That Follow Animation]]), and use the reset variant when the outfit system takes over again.

## 2. What is inside a description

| Group | Properties (docs) | Notes |
|---|---|---|
| Body parts | `Head`, `Torso`, `LeftArm`, `RightArm`, `LeftLeg`, `RightLeg`, `Face` | Asset ids; 0 means default |
| Colours | `HeadColor`, `TorsoColor`, `LeftArmColor`, `RightArmColor`, `LeftLegColor`, `RightLegColor` | `Color3` |
| Classic clothing | `Shirt`, `Pants`, `GraphicTShirt` | Asset ids |
| Rigid accessories | `HatAccessory`, `HairAccessory`, `FaceAccessory`, `NeckAccessory`, `ShouldersAccessory`, `FrontAccessory`, `BackAccessory`, `WaistAccessory` | Comma-separated id strings |
| Layered accessories | `AccessoryBlob` (JSON, not scriptable), read and written through `GetAccessories` / `SetAccessories` | Entries have `AssetId`, `AccessoryType`, `Order`, optional `Puffiness`, `IsLayered` |
| Scales | `HeightScale`, `WidthScale`, `DepthScale`, `HeadScale`, `BodyTypeScale`, `ProportionScale` | R15 only; `BodyTypeScale` and `ProportionScale` clamp to 0 to 1, and proportion does nothing when body type is 0 (docs) |
| Animations | `IdleAnimation`, `WalkAnimation`, `RunAnimation`, `JumpAnimation`, `FallAnimation`, `ClimbAnimation`, `SwimAnimation`, `MoodAnimation` | Animation-pack asset ids, not raw Animation ids |
| Emotes | `AddEmote`, `SetEmotes`, `GetEmotes`, `SetEquippedEmotes`, `GetEquippedEmotes`, `RemoveEmote` | Feeds the default emote menu ([[Bundles Animation Packs and Emotes for Sale]]) |
| Flags | `UseAvatarSettings`, `StaticFacialAnimation` | See below |

Two newer flags (docs, as of October 2026):

- **`UseAvatarSettings`**: when true, applying the description (or creating a model from it) also applies the universe's Avatar Settings. Useful for NPCs that should obey the same scale and accessory limits as players.
- **`StaticFacialAnimation`**: controls whether facial animation plays on a dynamic head for this description. It differs from setting `MoodAnimation` to 0 (which gives the neutral rest pose). Turning facial animation off is a cheap win for crowds of 50 NPCs nobody looks at closely.

### The two accessory APIs

The string properties are fine for rigid accessories but cannot express layering. `SetAccessories(list, includeRigidAccessories)` is the complete API:

- `includeRigidAccessories = true`: the list replaces **all** accessories, rigid and layered.
- `false`: only layered clothing (the `AccessoryBlob`) is replaced; rigid strings are untouched.
- An entry without `Order` is treated as rigid (docs).
- Higher `Order` renders on top. Equal orders fall back to serialization order (WrapLayer docs), which is effectively random to you: always give distinct orders to garments that overlap.
- `Puffiness` is deprecated on `WrapLayer` (docs, valid range was -1 to 1). Do not build features on it.

A frequent bug: calling `SetAccessories(layeredOnly, true)` to "add a jacket" and wiping every hat and hair. Read with `GetAccessories(true)`, modify, write back with `true`.

## 3. Spawning with a look versus applying after spawn

| Approach | Flash of the player's own avatar? | Cost | Notes |
|---|---|---|---|
| Spawn normally, then `ApplyDescriptionAsync` | Yes, for a moment | Two loads | Simple; fine for optional outfits |
| `CharacterAutoLoads = false` plus `LoadCharacterWithHumanoidDescriptionAsync` | No | One load | You own all spawning ([[Spawning Teams and Rounds]]) |
| Avatar Settings overrides (Custom Clothing, Custom Parts) | No | Engine-side | Global; no per-player logic ([[Avatar Body Types and Scale in Gameplay]]) |
| `StarterCharacter` | No | Fixed rig | Ignores the player's avatar entirely ([[Custom Characters and StarterCharacter]]) |

The flash matters more than it sounds: in a horror game where the hunter must look like a monster, a 300 ms glimpse of a player's normal avatar ruins the reveal. Use the spawn-with path or Avatar Settings for gameplay-critical looks, and the apply path for cosmetics.

## 4. Uniforms over the player's own avatar

Most team games want "your body, your face, your hair, our team shirt". That is a merge, and the merge rules are a design decision you should write down:

| Slot | Keep from player | Override from uniform |
|---|---|---|
| Body parts, head, face, colours | Yes (identity) | Optionally skin tone never; body colours only on blocky parts if the art needs it |
| Scales | Yes, unless gameplay needs equal size | Clamp to game limits |
| Hair, hat | Hair yes, hat usually no | Team hat or helmet replaces hats |
| Layered tops and bottoms | No | Uniform garments |
| Classic Shirt and Pants | No | Uniform classic clothing as fallback for R6 |
| Back and waist accessories | Often no (silhouette, team readability) | Remove |
| Animations | Yes, unless competitive fairness needs standard | Optional |

```lua
--!strict
-- Server: build a team uniform that keeps the player's identity.
type Uniform = {
	shirt: number,      -- classic shirt id (R6 fallback)
	pants: number,      -- classic pants id
	layered: { { AssetId: number, AccessoryType: Enum.AccessoryType, Order: number } },
	hat: number?,       -- optional team hat
}

local KEEP_RIGID: { [Enum.AccessoryType]: boolean } = {
	[Enum.AccessoryType.Hair] = true,
	[Enum.AccessoryType.Face] = true, -- glasses, facial hair
}

local function applyUniform(humanoid: Humanoid, uniform: Uniform)
	local desc = humanoid:GetAppliedDescription()

	-- Keep only identity accessories from the player's look.
	local kept = {}
	for _, entry in desc:GetAccessories(true) do
		if not entry.IsLayered and KEEP_RIGID[entry.AccessoryType] then
			table.insert(kept, entry)
		end
	end
	for _, garment in uniform.layered do
		table.insert(kept, {
			AssetId = garment.AssetId,
			AccessoryType = garment.AccessoryType,
			Order = garment.Order,
			IsLayered = true,
		})
	end
	if uniform.hat then
		table.insert(kept, { AssetId = uniform.hat, AccessoryType = Enum.AccessoryType.Hat, IsLayered = false })
	end
	desc:SetAccessories(kept, true)

	desc.Shirt = uniform.shirt
	desc.Pants = uniform.pants
	desc.GraphicTShirt = 0

	-- Other systems may have edited the character; use the reset variant.
	local ok, err = pcall(function()
		humanoid:ApplyDescriptionResetAsync(desc)
	end)
	if not ok then
		warn("Uniform apply failed:", err)
	end
end
```

Edge cases worth testing: hair that is layered (some hair is a layered accessory; the code above drops it, so decide whether `IsLayered` hair should be kept); players with no shirt-compatible body (R6 uses classic clothing only); a player whose hair is enormous and covers the team hat.

## 5. Storing outfits as data

Never store instances or the `AccessoryBlob` string verbatim. Store a small, versioned table you control, and rebuild the description on load. That keeps saves small, lets you migrate formats, and lets you strip banned or deleted items.

```lua
--!strict
-- Outfit codec: HumanoidDescription <-> plain table for DataStores.
local OUTFIT_VERSION = 2

export type SavedAccessory = { id: number, t: string, o: number? } -- t = AccessoryType name
export type SavedOutfit = {
	v: number,
	parts: { [string]: number },
	colors: { [string]: string },   -- hex strings
	scales: { [string]: number },
	acc: { SavedAccessory },
	shirt: number, pants: number, tshirt: number,
}

local PART_PROPS = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Face" }
local COLOR_PROPS = { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" }
local SCALE_PROPS = { "HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale" }

local function encode(desc: HumanoidDescription): SavedOutfit
	local out: SavedOutfit = {
		v = OUTFIT_VERSION, parts = {}, colors = {}, scales = {}, acc = {},
		shirt = desc.Shirt, pants = desc.Pants, tshirt = desc.GraphicTShirt,
	}
	for _, p in PART_PROPS do
		out.parts[p] = (desc :: any)[p]
	end
	for _, p in COLOR_PROPS do
		out.colors[p] = ((desc :: any)[p] :: Color3):ToHex()
	end
	for _, p in SCALE_PROPS do
		-- Round to 3 decimals: smaller saves, no float noise in diffs.
		out.scales[p] = math.round((desc :: any)[p] * 1000) / 1000
	end
	for _, e in desc:GetAccessories(true) do
		table.insert(out.acc, { id = e.AssetId, t = e.AccessoryType.Name, o = if e.IsLayered then e.Order else nil })
	end
	return out
end

local function decode(saved: SavedOutfit, isAllowed: (number) -> boolean): HumanoidDescription
	local desc = Instance.new("HumanoidDescription")
	for p, id in saved.parts do
		(desc :: any)[p] = id
	end
	for p, hex in saved.colors do
		(desc :: any)[p] = Color3.fromHex(hex)
	end
	for p, s in saved.scales do
		(desc :: any)[p] = s
	end
	local list = {}
	for _, a in saved.acc do
		local ok, accType = pcall(function()
			return (Enum.AccessoryType :: any)[a.t] :: Enum.AccessoryType
		end)
		if ok and isAllowed(a.id) then
			table.insert(list, {
				AssetId = a.id,
				AccessoryType = accType,
				IsLayered = a.o ~= nil,
				Order = a.o,
			})
		end
	end
	desc:SetAccessories(list, true)
	desc.Shirt, desc.Pants, desc.GraphicTShirt = saved.shirt, saved.pants, saved.tshirt
	return desc
end
```

Notes:

- **Store enum names, not values.** `AccessoryType.Name` survives enum reordering; the `.Value` integer is an implementation detail.
- **Allow-list on load.** Items can be deleted, moderated, or banned by your own rules after saving. `isAllowed` is the hook.
- **Ownership.** If outfits only allow owned items, re-check ownership on load, not just on save; items can be traded, resold or refunded.
- **Size.** A full outfit encodes to well under 1 KB in JSON (rule of thumb), so 20 saved outfits per player is cheap. Keep outfits inside the player's profile with session locking ([[Session Locking and Profile Libraries]]) and version them ([[Data Schema Design and Migrations]]).
- **Platform outfits are separate.** `AvatarEditorService:GetOutfitsAsync` lists the player's Roblox outfits (needs their permission flow); `Players:GetHumanoidDescriptionFromOutfitIdAsync` loads one. Do not copy them into your DataStore unless the player asks; they change on the website.

## 6. NPC crowds from descriptions

`CreateHumanoidModelFromDescriptionAsync` builds a whole character Model, which is a web-backed, yielding operation. Calling it 60 times at server start is slow and spiky.

The cheap pattern:

1. Build a small set of **template** models once (say 8 looks), cached in `ServerStorage`.
2. `Clone()` a template for each NPC. Cloning is local and fast.
3. Vary cheaply after cloning: body colours, a hat from a small pre-built set, scale via `Model:ScaleTo` for size variety (see [[Scale and Animation]] for what scaling does to clips).
4. For dense crowds, set `StaticFacialAnimation` on the template description, and consider stripping layered clothing for distant NPCs: layered cage fitting has a per-character cost that a crowd multiplies.

For "statues of top players" or "your friend's avatar", use `GetHumanoidDescriptionFromUserIdAsync` with a cache keyed by user id and a refresh interval; avatars change but not every minute.

**Anchoring and ownership.** A model built from a description is a full physics character. Statues should be anchored and have their Humanoid's state machine disabled or removed; idle NPCs should have their network owner set deliberately ([[Characters and Humanoids]]).

## 7. Timing hazards

- **The character can die mid-apply.** `ApplyDescriptionAsync` yields. After it returns, check `humanoid.Parent` and `humanoid.Health > 0` before doing follow-up work like welding armour.
- **`CharacterAdded` fires before appearance loads.** Use `Player.CharacterAppearanceLoaded` to know when the platform avatar has finished; applying before that can be overwritten by the engine's own appearance load. `Player.CanLoadCharacterAppearance` (default from `StarterPlayer.LoadPlayerAppearance`) turns the platform load off entirely, and changing it only takes effect on the next `LoadCharacterAsync` (docs).
- **Animations from descriptions need the Animate script.** Animation-pack ids in a description are written into the `Animate` script's values; a custom controller that does not read them ignores packs ([[The Default Animate Script]]).
- **Scale changes resize accessories** only when `Humanoid.AutomaticScalingEnabled` is true (docs). If you turned it off for a custom rig, scale changes from descriptions leave hats floating.

## 8. When not to use descriptions

- **Non-Humanoid rigs.** Creatures with `AnimationController` and custom skeletons do not use descriptions; compose them yourself ([[Creature Rig Conventions]]).
- **Gameplay gear.** Swords, tools and armour that exist only in your game are not avatar assets; weld them directly.
- **Per-frame changes.** Colour pulses, glowing hands, damage flashes: modify the parts or use a `Highlight`. A description apply per frame is absurd and visibly stutters.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Starting from `Instance.new("HumanoidDescription")` | Player loses face, colours, body | Start from `GetAppliedDescription()` |
| Mixing manual accessory edits with diff applies | Items reappear or refuse to remove | One owner, or `ApplyDescriptionResetAsync` |
| `SetAccessories(layered, true)` | All hats and hair vanish | Read all, modify, write back |
| Same `Order` for overlapping garments | Random layering between sessions | Distinct orders |
| Saving the blob or instances | Huge, unmigratable saves | Versioned plain table |
| Building 60 NPCs from scratch | Long, spiky server start | Templates plus `Clone` |
| Applying on `CharacterAdded` | Engine appearance load overwrites you | `CharacterAppearanceLoaded` or spawn-with |
| Ignoring deprecated-to-Async renames in docs | Confusion between tutorials | Prefer `Async` names in new code |

## Checklist

- [ ] One system owns appearance; others are additive or go through it.
- [ ] Edits start from `GetAppliedDescription()`.
- [ ] Reset variant used after other systems touched the character.
- [ ] Merge rules for uniforms written down per slot.
- [ ] Outfits saved as versioned tables with enum names and allow-list on load.
- [ ] NPCs cloned from a small template set; facial animation off for crowds.
- [ ] Applies happen after `CharacterAppearanceLoaded` or via spawn-with.
- [ ] Every apply wrapped in `pcall`, with alive checks afterwards.

## See also

[[Avatars and UGC Start Here]] · [[AvatarEditorService and In-Game Avatar Editors]] · [[Avatar Body Types and Scale in Gameplay]] · [[Bundles Animation Packs and Emotes for Sale]] · [[Characters and Humanoids]] · [[Custom Characters and StarterCharacter]] · [[Cookbook - Players and Characters]] · [[Accessories and Armor That Follow Animation]] · [[The Default Animate Script]] · [[Data Schema Design and Migrations]] · [[Session Locking and Profile Libraries]] · [[UGC Avatar Items and Accessories]]

## Connected notes
<!-- auto-links:start -->
[[Layered Clothing Cages and Animation]] · [[Links - Avatars and UGC]] · [[Links - Custom characters and avatars]] · [[Layered Clothing Creation Workflow]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Emotes and Social Animation]]
<!-- auto-links:end -->
