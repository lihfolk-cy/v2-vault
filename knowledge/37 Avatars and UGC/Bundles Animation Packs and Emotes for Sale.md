---
tags: [ugc, bundles, emotes, animation-packs, marketplace, animation, avatars]
---
# Bundles Animation Packs and Emotes for Sale

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Travelling emote -> Keep root near start
> - Avoid: Root pops between frames -> Spread snaps over frames
> - Avoid: Uploading a KeyframeSequence -> Convert first
> - Product type chosen with eligibility checked (packs need pilot access to sell).
> - Emote: under 10 s, root near origin, no frame pops, CurveAnimation, standard R15.
> - Emote tested on several bodies and with bulky layered clothing.
>
> Read more (15 KB note): ## 3. Emotes · ## 5. Games and emotes: three integration levels · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Single accessories are only part of the avatar Marketplace. Bodies, dynamic heads, shoes and animation packs are sold as **bundles**, and emotes are sold as single animation assets that players equip into an eight-slot wheel. These products sit where modelling, animation and game code meet: an emote has to pass a validator that measures root motion, an animation pack has to work inside every game's Animate script, and a game that sells either has to cooperate with the default emote menu or replace it. This note covers what each product is, the creation rules that matter, who can sell what (as of October 2026), and how games integrate them.

The craft of emotes (timing, readability, synchronised social moments) is in [[Emotes and Social Animation]]; fees and advances are in [[UGC Avatar Items and Accessories]]; pricing strategy in [[UGC Pricing Limiteds and Marketplace Rules]]. Facts marked "docs" are **Roblox docs (as of October 2026)**.

## 1. Product map

| Product | What it is | Who can sell (as of October 2026) | Key spec |
|---|---|---|---|
| Rigid or layered accessory | One asset | Eligible UGC creators | [[UGC Avatar Items and Accessories]] |
| Body bundle | 15 body part meshes, often with head, hair, eyebrows, eyelashes | Eligible UGC creators (bodies have their own advance) | Per-part triangle budgets, cages |
| Dynamic head | FACS-rigged head, usually inside a body bundle | Eligible UGC creators | Head up to 4,000 triangles |
| Shoes | Left and right shoe accessories grouped | Eligible UGC creators | Layered rules for each shoe |
| Emote | One animation asset | Eligible UGC creators (emote advance 1,500 non-limited, 10,000 limited, per the older note) | Under 10 s, CurveAnimation, standard R15 |
| Animation pack | Idle, walk, run, jump, fall, climb, swim (and mood) as a bundle | **Closed pilot**: community reports say selling needs pilot access; creating and testing is open | Works with the Animate script |

The animation-pack row is the one most creators get wrong: you can make and test a pack today, but **selling one requires pilot access** that, per a 2026 DevForum thread, is not expanding. That is a community answer, not an official statement, and was **not confirmed** against an announcement for this note.

## 2. Body bundles

A body is the most demanding avatar product: it is the target every accessory and garment must fit.

Spec points from the character body docs (as of October 2026; the cached versions differed slightly, so check the live page):

| Item | Value (docs) |
|---|---|
| Mesh objects | 15 (the R15 parts) |
| Head (dynamic) | Up to 4,000 triangles |
| Torso (UpperTorso plus LowerTorso) | Up to 1,750 |
| Each arm and leg | Up to 1,248 |
| Whole body (auto-setup page) | 10,742 triangles total |
| Geometry | Watertight (outer cages exempt), no n-gons, transforms frozen with pivots at 0, 0, 0 |
| Body scale | Slender via Rig Type "Rthro Narrow", Classic via "Default" in the 3D Importer |
| Cages | Bodies must include an outer cage to be compatible with layered accessories (layered spec page) |
| Face accessories | Eyebrows and eyelashes cannot be sold alone; they ship bundled with a body (or makeup) |

Nuances:

- **The auto-setup tool adds geometry.** It segments the body and caps limb ends, which can push a body near the limit over it (docs). Leave a margin of a few hundred triangles if you use it.
- **The outer cage is your compatibility promise.** A body with a sloppy outer cage makes every shirt in the catalog look broken on it. Buyers blame the shirt; the shirt creator's reviews suffer. Treat the body cage as carefully as the garment cages in [[Layered Clothing Creation Workflow]].
- **Proportions drive accessory fit.** Rigid accessories are placed by attachments and scaled by body scale type. A body with an unusually large head pushes hats into odd positions. Test your body with popular hats and hair.
- **Heads mean FACS.** A dynamic head needs face controls and expressions; budget animation time, not just modelling ([[Facial Animation and Dynamic Heads]]).

## 3. Emotes

### The validator's rules

Emote specifications (docs):

| Rule | Meaning in practice |
|---|---|
| Less than 10 seconds | Hard limit; a looping dance is one short cycle, not a full routine |
| Joint root must not move too far from the start | Travelling emotes (cartwheels across the room) fail; keep the root near origin |
| Movement speed capped, measured frame to frame | Big root jumps between keys fail even when the total distance is small |
| Standard R15 rig | Advanced R15 rigs for emotes are in closed beta |
| Sourced from a `CurveAnimation` | Convert keyframe sequences first ([[CurveAnimation and Curve Channels]]) |
| Only an `Animation` object is uploaded, with its `AnimationId` set | No meshes or textures |

The numeric thresholds for root distance and speed are **not published** (docs). Creators report a "more than 1 stud between frames" style error that persisted even after slowing the motion (community report, not confirmed). Practical rules of thumb:

- Keep the root inside a small radius of its start; express travel with the legs and upper body.
- Avoid single-frame snaps of the root. If a move needs a pop, spread it over two or three frames with an ease.
- Bake at a steady frame rate and check the root curve for spikes before upload. A spike usually comes from a gimbal flip or a mis-keyed frame.
- Jumps: let the body rise but keep the root's vertical travel modest; the validator sees the root, not the feet.

### Designing for the wheel

Players equip up to **8 emotes** into the menu (docs). Emotes appear in the order they were set, starting at the top and going clockwise, and the names you give them are shown as written (docs). Design implications:

- **The name is the button.** Short, clear names in a consistent style. A name like "Dance_v3_final" ships to players verbatim.
- **Read at distance.** Most emotes are seen from a third-person camera across a lobby. Big shapes, clear silhouettes, strong poses held for a beat ([[Emotes and Social Animation]]).
- **Loop or not.** A looping emote needs a seamless cycle and a sensible stop when the player moves. A one-shot needs a clean return to idle.
- **Layered clothing stretches.** Arms-overhead emotes expose every garment's weakest area. Test emotes with bulky jackets and long skirts.
- **Body variety.** An emote that looks great on a slender body may clip hands into a wide torso. Test on several body scales.

## 4. Animation packs

An animation pack replaces a character's locomotion set. In a `HumanoidDescription` the slots are `IdleAnimation`, `WalkAnimation`, `RunAnimation`, `JumpAnimation`, `FallAnimation`, `ClimbAnimation`, `SwimAnimation` and `MoodAnimation` (docs). The engine writes these into the default `Animate` script's values, which is why packs only work in games that use that script ([[The Default Animate Script]]).

What makes a pack good (rule of thumb):

| Clip | Watch for |
|---|---|
| Idle | Must be calm enough to watch for minutes; avoid big repeating gestures |
| Walk and run | Stride length must match speed; packs are played on characters of every scale, and the Animate script scales playback speed to movement speed, so feet slide if the authored stride does not match ([[Scale and Animation]]) |
| Jump and fall | Short; fall must loop |
| Climb | Hands must reach a ladder at body-relative positions |
| Swim | Horizontal body; test in water |
| Mood (dynamic heads) | Facial idle; subtle |

Testing without pilot access: upload the clips as ordinary animations and swap the ids into the `Animate` script's value objects in a test place (community advice). That shows exactly what buyers would see in a standard game.

## 5. Games and emotes: three integration levels

| Level | What you do | Who pays | Notes |
|---|---|---|---|
| Leave defaults | Players use their own emotes from the wheel and `/e` commands | Nobody | Free social feature |
| Curate | Add game-chosen Marketplace emotes to each character's description and equip them | You pay nothing; players get extra emotes in your game | Use `SetEmotes` and `SetEquippedEmotes` |
| Replace | Disable the default menu and run your own emote system with your own animations | You build and maintain it | Required for game-made emotes, custom rigs, or gameplay-safe emoting |

Controls (docs):

- `StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)` disables the menu. **It does not stop chat-command emotes.**
- `StarterPlayer.UserEmotesEnabled = false` stops user-owned emotes from loading; it can only be changed in Studio, not by scripts.
- `GuiService:SetEmotesMenuOpen(bool)` and `GuiService:GetEmotesMenuOpen()` open, close and query the menu.
- `Humanoid:PlayEmote(name)` plays an emote that is in the character's description and returns true if it played.

### Curating Marketplace emotes

The docs sample sets emotes from a LocalScript in `StarterCharacterScripts`. For emotes that everyone should see consistently, and for gating them on ownership, do it on the server:

```lua
--!strict
-- Server: give every character a curated emote set, plus owned premium emotes.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

-- Emote asset ids (placeholders). Names are what players see on the wheel.
local FREE_EMOTES: { [string]: number } = {
	Wave = 0000000000,
	Cheer = 0000000000,
}
local PREMIUM_EMOTES: { [string]: number } = {
	Victory = 0000000000, -- shown only if the player owns it
}
local WHEEL_ORDER = { "Wave", "Cheer", "Victory" }

local function ownsAsset(player: Player, assetId: number): boolean
	local ok, owns = pcall(function()
		return MarketplaceService:PlayerOwnsAssetAsync(player, assetId)
	end)
	return ok and owns == true
end

local function setupEmotes(player: Player, humanoid: Humanoid)
	local desc = humanoid:GetAppliedDescription()
	local emotes = desc:GetEmotes() -- keep the player's own emotes

	for name, id in FREE_EMOTES do
		emotes[name] = { id }
	end
	for name, id in PREMIUM_EMOTES do
		if ownsAsset(player, id) then
			emotes[name] = { id }
		end
	end
	desc:SetEmotes(emotes)

	local equipped = {}
	for _, name in WHEEL_ORDER do
		if emotes[name] and #equipped < 8 then
			table.insert(equipped, { Slot = #equipped + 1, Name = name })
		end
	end
	desc:SetEquippedEmotes(equipped)

	if humanoid.Parent then
		local ok, err = pcall(function()
			humanoid:ApplyDescriptionAsync(desc)
		end)
		if not ok then
			warn("Emote setup failed:", err)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAppearanceLoaded:Connect(function(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			setupEmotes(player, humanoid)
		end
	end)
end)
```

Notes on this code:

- `SetEmotes` takes a dictionary of name to an **array** of asset ids (several emotes may share a name, docs). `SetEquippedEmotes` takes an array of `{ Slot, Name }` entries; the docs examples use slots 1 to 3, and the menu holds up to 8.
- Replacing the player's equipped list removes their own choices from the wheel in your game. Some players hate that. A gentler option: equip curated emotes only into empty slots.
- Description emotes must be emote **assets**. Raw animation ids made by your game are not Marketplace emotes; for those, replace the menu with your own system.

### Gameplay-safe emoting

Emotes are full-body animations that can hide attack tells, move the head and arms out of expected places, and break combat readability. Competitive games commonly:

- Block emotes while in combat, carrying a weapon, or moving fast (a custom system can check state; the default menu cannot, so disable it).
- Cancel the emote on any movement or damage.
- Keep emotes cosmetic: never let an emote shrink the hitbox or change the character's collision ([[Avatar Body Types and Scale in Gameplay]]).

## 6. Selling emotes and packs inside your game

- **Marketplace emotes in your shop:** `PromptPurchase` the emote asset; your experience earns the in-experience commission (older note). After purchase, re-run the emote setup so it appears on the wheel immediately.
- **Game-only emotes:** sell them as developer products or passes, store ownership in your data, and play them through your own system. They cannot be worn outside your game, which players should be told plainly ([[Developer Products and ProcessReceipt]]).
- **Do not double-sell.** Charging Robux for a game-only "dance" that is visibly the same as a cheap Marketplace emote makes players feel cheated.
- **Animation packs:** you cannot sell packs without pilot access, but your game can offer **game-only locomotion styles** (a "sneaky walk" pass) by swapping the Animate script's ids at runtime for players who own them.

## 7. When not to bother

- **Fixed-character games.** If everyone is a knight or a creature, Marketplace emotes and packs look wrong on your rig or do not play at all; disable them and ship a small curated set.
- **Custom controllers** that do not use the Animate script ignore animation packs; that is often fine, but then say so rather than letting purchased packs silently do nothing.
- **Emotes as a first UGC product** for a new creator: the validator thresholds are unpublished and iteration costs upload fees. A rigid accessory is a cheaper first product.

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Travelling emote | Root displacement validation failure | Keep root near start |
| Root pops between frames | Speed validation failure | Spread snaps over frames |
| Uploading a KeyframeSequence | Not a CurveAnimation | Convert first |
| Unclear wheel names | Players cannot find emotes | Short, consistent names |
| Disabling the menu and assuming emotes are off | `/e` still works | Also handle chat commands or `UserEmotesEnabled` |
| Overwriting the player's equipped emotes | Complaints | Fill empty slots |
| Selling a pack-like "walk style" via Marketplace without access | Cannot publish | Game-only style, or pilot access |
| Body with a careless outer cage | Every shirt looks broken on it | Treat body cages like garment cages |
| Ignoring auto-setup extra triangles | Body fails budget | Keep a margin |

## Checklist

- [ ] Product type chosen with eligibility checked (packs need pilot access to sell).
- [ ] Emote: under 10 s, root near origin, no frame pops, CurveAnimation, standard R15.
- [ ] Emote tested on several bodies and with bulky layered clothing.
- [ ] Wheel names short and final.
- [ ] Body: per-part budgets, margin for auto-setup, clean outer cage, tested with popular items.
- [ ] Game: integration level decided (defaults, curate, replace); chat emotes handled.
- [ ] Curated emotes respect the player's own slots; premium emotes gated on ownership.
- [ ] Game-only emotes and styles labelled as game-only.

## See also

[[Avatars and UGC Start Here]] · [[Emotes and Social Animation]] · [[UGC Avatar Items and Accessories]] · [[UGC Pricing Limiteds and Marketplace Rules]] · [[HumanoidDescription and Outfit Systems]] · [[The Default Animate Script]] · [[CurveAnimation and Curve Channels]] · [[Facial Animation and Dynamic Heads]] · [[Scale and Animation]] · [[Layered Clothing Creation Workflow]] · [[Developer Products and ProcessReceipt]] · [[Animation Asset Permissions and Groups]]

## Connected notes
<!-- auto-links:start -->
[[Links - Avatars and UGC]] · [[Layered Clothing Cages and Animation]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Commerce and Physical Goods]] · [[Custom Characters and StarterCharacter]] · [[3D Importer Settings Reference]]
<!-- auto-links:end -->
