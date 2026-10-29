---
tags: [worked-build, survival, crafting, resource-nodes, placement, building, datastore, saving, fast-ship, type/build, area/gameplay, level/intermediate]
---
# Weekend Build - Survival Gather, Craft and Place

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: World-space saves. Bases land on the wrong plot.
> - Avoid: Client-decided yield or recipe. Exploiters craft for free.
> - Avoid: Removing ingredients one by one with a yield in between.
> - Plot-relative, versioned save with inventory and pieces.
> - Gather: tag, distance (plus node size), rate and depletion checked on server.
> - Craft: check all, then remove all, no yield.
>
> Cost: TL;DR ~140 tok · whole note ~2.0k tok. Read more: ## 3. Gathering · ## 5. Placement · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The smallest complete survival loop: hit a resource node to gather wood and stone, craft a wall from a recipe, place it on a grid on your own plot, and have it come back when you rejoin. Every step is server-authoritative, and the save format is plot-relative and versioned so it survives map changes. Design background is in [[Genre Playbook - Survival and Crafting]]; this note is the build.

Source labels: **Roblox docs**, **Rule of thumb**. Code is original, reviewed but not run as a whole.

## 1. Scope

- Nodes: trees and rocks with health; respawn after 30 s.
- Inventory: counts per resource and per crafted item, saved.
- One recipe: Wall = 4 Wood + 2 Stone.
- Placement: 4-stud grid, 4 rotations, on the player's plot only, max 100 pieces.
- Saving: inventory plus placed pieces, plot-relative.

Out of scope for the weekend: hunger, combat, day-night, shared world building.

## 2. Data model

```lua
--!strict
export type Piece = { id: string, gx: number, gz: number, rot: number } -- grid coords on the plot
export type Save = {
	v: number,                       -- schema version
	inv: {[string]: number},         -- "Wood" = 12, "Wall" = 1
	pieces: {Piece},
}
local DEFAULT: Save = { v = 1, inv = {}, pieces = {} }
```

Store grid coordinates relative to the plot, never world positions. Plots get reassigned per server; a world-position save puts your wall on someone else's land after a rejoin.

Saving itself (session locking, retries, autosave, `BindToClose`) should come from your tested data layer, not be rewritten here; see [[Saved Inventory End to End]] and [[DataStore Fundamentals]].

## 3. Gathering

Nodes are tagged `ResourceNode` with attributes `Resource` ("Wood"), `Yield` (per hit), `MaxHealth`.

```lua
--!strict
-- Server: one RemoteEvent "Gather" with the node instance.
local CollectionService = game:GetService("CollectionService")
local GATHER_RANGE = 12
local GATHER_INTERVAL = 0.45
local lastHit: {[Player]: number} = {}

local function onGather(player: Player, node: Instance)
	if typeof(node) ~= "Instance" or not CollectionService:HasTag(node, "ResourceNode") then return end
	if not node:IsA("BasePart") then return end
	local now = os.clock()
	if now - (lastHit[player] or 0) < GATHER_INTERVAL then return end
	lastHit[player] = now
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - node.Position).Magnitude > GATHER_RANGE + node.Size.Magnitude / 2 then return end
	if node:GetAttribute("Depleted") then return end

	local hp = (node:GetAttribute("Health") or node:GetAttribute("MaxHealth")) :: number
	hp -= 1
	addItem(player, node:GetAttribute("Resource") :: string, node:GetAttribute("Yield") :: number)
	if hp <= 0 then
		node:SetAttribute("Depleted", true)
		node.Transparency = 1
		node.CanCollide = false
		task.delay(30, function()
			node:SetAttribute("Health", node:GetAttribute("MaxHealth"))
			node:SetAttribute("Depleted", false)
			node.Transparency = 0
			node.CanCollide = true
		end)
	else
		node:SetAttribute("Health", hp)
	end
end
```

`addItem` writes to the server-side session data and updates a replicated view (attributes on a folder under the player, or a remote). The client plays the swing, hit sound and wood-chip particles immediately on click; the inventory number updates when the server confirms. Distance includes half the node size so large trees are not unreachable.

## 4. Crafting

```lua
local RECIPES = {
	Wall = { Wood = 4, Stone = 2 },
}

local function onCraft(player: Player, recipeId: string)
	local recipe = typeof(recipeId) == "string" and RECIPES[recipeId]
	if not recipe then return end
	local inv = getInventory(player)
	for res, need in recipe do
		if (inv[res] or 0) < need then return end
	end
	for res, need in recipe do
		inv[res] -= need
	end
	inv[recipeId] = (inv[recipeId] or 0) + 1
	markDirty(player)
end
```

Check all ingredients before removing any. The check and removal happen in the same server function with no yield between them, so two rapid craft requests cannot both pass the check ([[Economy Exploits - Dupes Races and Purchase Abuse]]).

## 5. Placement

Client: a ghost preview snaps to the grid under the mouse, turns red when invalid, and `R` rotates. It sends `Place(gx, gz, rot)` in plot grid coordinates. Server re-validates everything:

```lua
local GRID = 4
local PLOT_CELLS = 16 -- 16 x 16 cells
local MAX_PIECES = 100

local function onPlace(player: Player, gx: number, gz: number, rot: number)
	if typeof(gx) ~= "number" or typeof(gz) ~= "number" or typeof(rot) ~= "number" then return end
	gx, gz, rot = math.floor(gx), math.floor(gz), math.floor(rot) % 4
	if gx < 0 or gz < 0 or gx >= PLOT_CELLS or gz >= PLOT_CELLS then return end
	local data = getSave(player)
	if #data.pieces >= MAX_PIECES or (data.inv.Wall or 0) < 1 then return end
	for _, p in data.pieces do
		if p.gx == gx and p.gz == gz then return end -- occupied
	end
	data.inv.Wall -= 1
	local piece = { id = "Wall", gx = gx, gz = gz, rot = rot }
	table.insert(data.pieces, piece)
	spawnPiece(player, piece) -- builds the instance at plot.CFrame * offset
	markDirty(player)
end
```

`spawnPiece` computes `plot.CFrame * CFrame.new((gx + 0.5) * GRID - half, height, (gz + 0.5) * GRID - half) * CFrame.Angles(0, rot * math.pi / 2, 0)`. Grid math and multi-cell footprints are covered in [[Grid Placement and Player Building Systems]].

On join: assign a free plot, then rebuild pieces in batches (for example 20 per frame with `task.wait()` between) nearest first, so a full base does not hitch the server.

## 6. Testing

- Two clients: one cannot place on the other's plot, or gather from across the map.
- Craft spam with an autoclicker: inventory never goes negative.
- Place 100 pieces, rejoin on a different server and plot: the base comes back identical.
- Change the plot size constant: old saves outside the new bounds are skipped and logged, not crash the load. Bump `v` and migrate when the format changes.

## Common mistakes

- **World-space saves.** Bases land on the wrong plot.
- **Client-decided yield or recipe.** Exploiters craft for free.
- **Removing ingredients one by one with a yield in between.** Race conditions dupe items.
- **Loading a whole base in one frame.** Server hitch on join.
- **Nodes destroyed and recreated.** Use attributes and visibility; cheaper and replication-friendly.
- **No piece cap.** One player can make the server's part count explode.

## Checklist

- [ ] Plot-relative, versioned save with inventory and pieces.
- [ ] Gather: tag, distance (plus node size), rate and depletion checked on server.
- [ ] Craft: check all, then remove all, no yield.
- [ ] Place: bounds, occupancy, cap and ownership on server; ghost preview on client.
- [ ] Batched, nearest-first rebuild on join.
- [ ] Cross-server rejoin test passed.

## See also

- [[Genre Playbook - Survival and Crafting]]
- [[Grid Placement and Player Building Systems]]
- [[Saved Inventory End to End]]
- [[CollectionService Patterns]]
- [[Server Authority and Validation]]

## Connected notes

[[Case Study - 99 Nights in the Forest]] · Economy Exploits - Dupes Races and Purchase Abuse · Tycoon Plots and Droppers End to End · [[Worked Builds Start Here]]

<!-- related:start -->
## Related
[[Global Leaderboards End to End]] · [[Weekend Build - Arena Shooter with Server-Checked Hits]] · [[Quest Chain System End to End]] · [[Weekend Build - Roleplay Town with Jobs and Paychecks]] · [[Rebirth and Prestige System End to End]] · [[LihFolk Systems - Data and Purchase Guarantees]] · [[Round-Based Minigame Loop End to End]] · [[Shop with Game Passes and Developer Products End to End]]
<!-- related:end -->
