---
tags: [level-design, interiors, instancing, housing, roleplay, pooling, streaming, type/guide, area/level-design, level/advanced, api/RequestStreamAroundAsync, api/PivotTo, api/ModelStreamingMode]
---
# Instanced Interiors - Pooled House and Room Copies for Many Players

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Slots too close together -> Spacing above streaming radius plus interior size
> - Avoid: Slots below `FallenPartsDestroyHeight` -> Slots above the map
> - Avoid: Slots very far from origin -> Keep within a few thousand studs
> - Instancing model chosen (slots, client-only, separate place) with a reason.
> - Slot spacing and origin distance checked; slots visually isolated.
> - Shell pool with lazy close; per-owner furniture loaded and cleared.
>
> Cost: TL;DR ~150 tok · whole note ~2.6k tok. Read more: ## 2. Slot layout · ## 3. Pooling · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roleplay and housing games promise every player their own house, shop or apartment, but the map only has one front door per lot, and twenty players walking into twenty real houses would need twenty lots. The usual answer is **instanced interiors**: the exterior is shared, and stepping through the door moves you to a private copy of the interior placed somewhere far away, out of sight. This note covers slot layout, pooling, the door transition, streaming, per-instance lighting, cleanup, and when to use a separate place instead. Saving what players put inside is covered by [[Grid Placement and Player Building Systems]] and [[Saved Inventory End to End]].

Source labels: **Roblox docs** (create.roblox.com, as of October 2026), **Rule of thumb**. Code is strict Luau, **reviewed, not run**.

---

## 1. Choose the instancing model

| Model | How | Best for | Costs |
|---|---|---|---|
| **Far-away slots in the same server** | Interiors cloned into a grid of slots under the map | Houses, shops, small dungeons; visits between players | Memory per active interior; all on one server |
| **Client-only interiors** | Client clones the interior locally; server knows only "player is inside house X" | Purely cosmetic rooms nobody else enters | Server cannot validate anything inside; no visitors |
| **Separate place / reserved server** | Teleport into a reserved server running the interior place | Large interiors, raids, private realms | Teleport time; party handling; cross-server data ([[Teleporting and Multi-Place Games]]) |

Rule of thumb: same-server slots for anything players visit together or interact with; separate places for anything large, long or competitive. Client-only interiors are tempting but break as soon as you add a second player, an item pickup or a sale.

## 2. Slot layout

Allocate a grid of slots in a region nobody can reach or see, usually high above the playable map. Below the map works only if you check `Workspace.FallenPartsDestroyHeight` (default -500, Roblox docs): unanchored parts and characters below it are destroyed, so a slot at Y = -2000 kills everyone who enters it.

- **Spacing** larger than the biggest interior plus your streaming radius, so a player in slot 3 does not stream in slot 4 or see it through a window. Rule of thumb: spacing of at least `StreamingTargetRadius` plus interior size.
- **Distance from origin**: keep slots within a few thousand studs. Floating-point precision degrades far from the origin; physics and animation jitter becomes visible at very large coordinates (rule of thumb: stay well under 10,000 studs on any axis for anything players stand in).
- **Isolation**: enclose each slot (skybox walls or a void with fog) so windows show a fake exterior, not the slot next door. Use a window "backdrop" image or a static exterior model.
- **Out-of-bounds**: each slot gets its own bounds for the recovery sweep ([[Kill Planes, Map Boundaries and Out-of-Bounds Recovery]]); a player who falls out of an interior must recover to the interior's door, not to a world position.

## 3. Pooling

Cloning a detailed interior and destroying it every time someone enters and leaves causes hitches and replication spikes. Keep a pool per interior type:

```lua
--!strict
-- ServerScriptService/InteriorPool
local ServerStorage = game:GetService("ServerStorage")

export type Slot = { index: number, origin: CFrame, model: Model?, kind: string?, owner: number?, occupants: number }

local SLOT_SPACING = 1500
local SLOT_BASE = CFrame.new(-6000, 2000, -6000) -- above the map, NOT below FallenPartsDestroyHeight
local MAX_SLOTS = 40

local InteriorPool = {}
local slots: { Slot } = {}
local spare: { [string]: { Model } } = {} -- unused clones by kind

for i = 1, MAX_SLOTS do
	local row, col = (i - 1) // 8, (i - 1) % 8
	slots[i] = { index = i, origin = SLOT_BASE * CFrame.new(col * SLOT_SPACING, 0, row * SLOT_SPACING), occupants = 0 }
end

local function takeModel(kind: string): Model
	local list = spare[kind]
	if list and #list > 0 then
		return table.remove(list) :: Model
	end
	return (ServerStorage.Interiors :: Folder):FindFirstChild(kind):Clone() :: Model
end

function InteriorPool.open(kind: string, ownerUserId: number): Slot?
	for _, slot in slots do
		if slot.owner == ownerUserId and slot.kind == kind then
			return slot -- already open (owner re-entering, or a visitor)
		end
	end
	for _, slot in slots do
		if slot.owner == nil then
			local model = takeModel(kind)
			model:PivotTo(slot.origin)
			model.Parent = workspace.Interiors
			slot.model, slot.kind, slot.owner = model, kind, ownerUserId
			return slot
		end
	end
	return nil -- full: show "house busy, try again" rather than overlapping
end

function InteriorPool.close(slot: Slot)
	local model = slot.model
	if model and slot.kind then
		model.Parent = nil -- keep for reuse; reset per-owner furniture separately
		spare[slot.kind] = spare[slot.kind] or {}
		table.insert(spare[slot.kind], model)
	end
	slot.model, slot.kind, slot.owner, slot.occupants = nil, nil, nil, 0
end

return InteriorPool
```

- **Furniture is per owner, shell is shared.** Pool the empty shell; load the owner's saved furniture into it on open and clear it on close. Never pool furnished models across owners.
- **Close lazily.** When the last occupant leaves, start a timer (30 to 60 s, rule of thumb) before closing, so a player who pops out to the street and back does not reload everything.
- **Close on owner leave.** On `PlayerRemoving`, eject visitors to the exterior door, then close.
- **Cap the pool** by memory, not by player count; measure one furnished interior's memory in the Developer Console and divide your budget ([[Memory Budgets and Leaks]]).

## 4. The door transition

1. Player triggers the door (`ProximityPrompt` on the exterior, validated on the server: right player or allowed visitor, within range).
2. Server opens or finds the slot.
3. Client shows a short fade (0.3 to 0.6 s) so the jump is not jarring.
4. Server calls `player:RequestStreamAroundAsync(entryPoint, timeOut)` (Roblox docs) so the interior's floor exists on the client before the move ([[Instance Streaming]]).
5. Server `PivotTo`s the character to the entry point, zeroes velocity, sets a `CurrentInterior` attribute on the player.
6. Client fades in and applies interior lighting (section 5).

Exiting is the same in reverse, landing the player outside the door facing away from it. Always teleport on the server; a client-side teleport desyncs other players' view of the character.

## 5. Lighting, audio and visibility per interior

`Lighting` is global per client, so interior mood is a **client** concern keyed off the `CurrentInterior` attribute: on change, push an interior lighting layer (ambient, `ColorCorrectionEffect`, `Atmosphere` density, reverb) and pop it on exit, using the same priority stack as zones ([[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]).

Other interiors and the exterior are still in Workspace. Streaming handles distance; for extra safety, the client can hide the exterior entirely while inside (see [[Client Zone Culling for Interiors and Cities]]). Set interior shells' `ModelStreamingMode` to `Atomic` (Roblox docs: the model streams in and out as a whole) so a player never sees half a room.

## 6. Security and correctness

- Items picked up, purchases and furniture edits inside an interior are validated against **the slot the server put the player in**, not the position the client claims.
- Visitors: permission list on the server (friends, party, public); kick visitors on permission change.
- Physics: interior props should be anchored; an unanchored chair flung by an exploiter can leave the slot and land in another.
- Proximity voice and spatial sounds are distance-based; confirm their range is well below slot spacing so neighbours cannot hear each other.

---

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Slots too close together | Players see or hear the neighbouring house | Spacing above streaming radius plus interior size |
| Slots below `FallenPartsDestroyHeight` | Players die or vanish on entry | Slots above the map |
| Slots very far from origin | Jittery characters and animation inside | Keep within a few thousand studs |
| Clone and destroy on every entry | Hitch at every door | Pool shells, load furniture separately |
| Pooling furnished models | Player B sees player A's furniture | Clear per-owner content on close |
| Teleport before streaming | Players fall out of the interior | `RequestStreamAroundAsync` first |
| Client-side teleport | Others see the player standing outside | Server `PivotTo` |
| OOB recovers to world position | Player appears in the void below the map | Per-slot bounds and door recovery |

## Checklist

- [ ] Instancing model chosen (slots, client-only, separate place) with a reason.
- [ ] Slot spacing and origin distance checked; slots visually isolated.
- [ ] Shell pool with lazy close; per-owner furniture loaded and cleared.
- [ ] Door flow: server validation, stream, server pivot, attribute, client fade.
- [ ] Interior lighting as a client layer keyed off an attribute.
- [ ] Owner leave ejects visitors; pool capped by measured memory.
- [ ] Tested with 2+ owners, visitors, and a phone on a weak connection.

## See also

[[Genre Playbook - Roleplay and Social Hangouts]] · [[Instance Streaming]] · [[Level of Detail and Model Streaming]] · [[Grid Placement and Player Building Systems]] · [[Teleporting and Multi-Place Games]] · [[Memory Budgets and Leaks]] · [[Kill Planes, Map Boundaries and Out-of-Bounds Recovery]] · [[Client Zone Culling for Interiors and Cities]]

## Connected notes
<!-- auto-links:start -->
[[Lobby and Hub Design]] · [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] · Tycoon Plots and Droppers End to End
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Spawn Points Safe Zones and Respawn Flow]] · [[Level Design Principles - Flow Sightlines and Landmarks]] · [[Objective Mode Maps - Capture the Flag, King of the Hill and Control Points]] · [[Combat Arena and Encounter Layout]] · [[Playtest Heatmaps - Position and Death Maps]] · [[Teaching Through Level Design]]
<!-- related:end -->
