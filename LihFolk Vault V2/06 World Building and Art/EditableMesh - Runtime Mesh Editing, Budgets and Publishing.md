---
tags: [world-building, editablemesh, meshparts, procedural, deformation, memory, permissions, luau, type/guide, area/world, level/advanced, api/EditableMesh, api/AssetService, area/modeling]
---
# EditableMesh - Runtime Mesh Editing, Budgets and Publishing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Mesh APIs not enabled for the published experience -> Turn on Enable Mesh / Image APIs in Creator Dashboard settings
> - Avoid: Loading a mesh asset the player or owner cannot edit -> Use your own or shared assets only
> - Avoid: Treating vertex ids as array indices -> Iterate `GetVertices()` / `GetFaces()`
> - Enable Mesh / Image APIs turned on for the published experience; Terms of Use reviewed.
> - Every creation call wrapped in `pcall` with a nil check and a static fallback.
> - Each mesh stays under 60,000 vertices and 20,000 triangles.
>
> Cost: TL;DR ~180 tok · whole note ~3.2k tok. Read more: ## 3. Building geometry · ## 4. Showing it, and collision · ## Common mistakes · ## Checklist
<!-- tldr:end -->

`EditableMesh` lets a script build or change triangle geometry while the game runs: a heightfield that players dig craters into, a road ribbon that follows a spline, a sculpting tool, a customised avatar body. It is the mesh twin of `EditableImage` ([[EditableImage for Pixel Buffers and Procedural 2D]]) and shares its rules: it costs real memory, it is off by default in published games, and it only loads assets you are allowed to edit. This note covers creation, display and collision, the hard limits, the publishing switch, and the patterns that keep it cheap.

Source labels: **Roblox docs** (the `EditableMesh` and `AssetService` reference pages, checked as of November 2026), **Rule of thumb**, **Unverified**. Reference: https://create.roblox.com/docs/reference/engine/classes/EditableMesh

---

## 1. When to reach for it (and when not)

| Job | Use `EditableMesh`? | Usually better |
|---|---|---|
| Craters, dents, snow tracks on a small surface | Yes | |
| Spline roads, rivers, ribbons, trails with real geometry | Yes, built once then frozen | [[Roads, Rivers and Paths Carved Along Curves in Terrain]] for terrain-based paths |
| Player-customised avatar bodies and accessories | Yes, through the in-experience creation flow | [[In-Experience Avatar Creation - Tokens, Editing and Prompting]] |
| Large destructible worlds | Rarely | Parts plus [[Destruction and Fracture]], or Terrain |
| Animated water or cloth every frame | Rarely; per-frame vertex edits are costly | Bones and skinned meshes, `Beam`s, Terrain water |
| Static art | No | Import a mesh ([[Exporting and Validating Models for Roblox]]) |

**Rule of thumb:** if the geometry stops changing after load, build it, freeze it (section 5) and destroy the editable copy.

## 2. Creating one

- `AssetService:CreateEditableMesh(options?)` makes a **blank** mesh. **Roblox docs.**
- `AssetService:CreateEditableMeshAsync(content, options?)` loads an existing mesh asset (for example `Content.fromUri("rbxassetid://...")` or a `MeshPart`'s `MeshContent`). It yields. **Roblox docs.**
- Loaded meshes are **fixed-size by default**: you can move vertices but not add or remove them. Pass `{ FixedSize = false }` when you need to add geometry. Fixed-size meshes use less memory. **Roblox docs.**
- `CreateEditableMeshAsync` only loads assets **owned by, or explicitly shared with,** the experience owner, the logged-in Studio user, or (on a client) the logged-in player; group assets count when that person's role can edit the group's assets. Anything else throws. **Roblox docs.** This is why "load a random catalog mesh and deform it" does not work.

## 3. Building geometry

Each `Add*` call returns a numeric **id**: `AddVertex(position)`, `AddTriangle(v0, v1, v2)`, `AddNormal`, `AddUV`, `AddColor`, and `SetFaceNormals` / `SetFaceUVs` to attach them to a face. **Roblox docs.**

**Ids are stable but not indices.** Removing vertex 4 from `{1, 2, 3, 4, 5}` leaves `{1, 2, 3, 5}`; ids may be out of order and have gaps. Always iterate the arrays from `GetVertices()` / `GetFaces()`, never `for i = 1, count`. **Roblox docs.**

### Hard limits
- **60,000 vertices and 20,000 triangles per mesh**; a quad counts as two triangles. Going over **errors** (for example `AddVertex` on a mesh that already has 60,000 vertices). **Roblox docs.**
- A square grid of `n` by `n` cells costs `2n²` triangles, so the largest full grid is **100 by 100 cells** (20,000 triangles). Plan tiles below that, for example 96 by 96 with room for skirts. **Rule of thumb** derived from the limit.

### A heightfield tile

```lua
--!strict
local AssetService = game:GetService("AssetService")

-- Builds a cells x cells grid centred on the origin. Keep cells <= 100 (20,000 triangle cap).
local function buildHeightTile(size: number, cells: number, height: (number, number) -> number): EditableMesh?
	local ok, mesh = pcall(function()
		return AssetService:CreateEditableMesh()
	end)
	if not ok or mesh == nil then
		return nil -- APIs disabled, or this device is over its memory budget
	end

	local row = cells + 1
	local ids = table.create(row * row)
	local step = size / cells
	for z = 0, cells do
		for x = 0, cells do
			local px = x * step - size / 2
			local pz = z * step - size / 2
			ids[z * row + x + 1] = mesh:AddVertex(Vector3.new(px, height(px, pz), pz))
		end
	end

	for z = 0, cells - 1 do
		for x = 0, cells - 1 do
			local a = ids[z * row + x + 1]
			local b = ids[z * row + x + 2]
			local c = ids[(z + 1) * row + x + 1]
			local d = ids[(z + 1) * row + x + 2]
			-- If the tile is invisible from above, swap two ids in each triangle (winding order)
			mesh:AddTriangle(a, c, b)
			mesh:AddTriangle(b, c, d)
		end
	end
	return mesh
end
```

## 4. Showing it, and collision

- An `EditableMesh` is drawn only once it is **linked to a MeshPart**: `AssetService:CreateMeshPartAsync(Content.fromObject(mesh))` returns a new `MeshPart`. To swap the mesh on an existing part, call `existingPart:ApplyMesh(newPart)`. **Roblox docs.**
- **Visual edits show immediately**; **collision and fluid geometry do not update** until you call `CreateMeshPartAsync` and `ApplyMesh` again. Do that at the end of a conceptual edit (the crater is finished), not per vertex. **Roblox docs.**
- One `EditableMesh` can feed several MeshParts, which saves memory for repeated shapes. **Roblox docs.**

```lua
--!strict
local AssetService = game:GetService("AssetService")

local function showMesh(mesh: EditableMesh, parent: Instance): MeshPart?
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
	end)
	if not ok then
		warn("CreateMeshPartAsync failed:", part)
		return nil
	end
	part.Anchored = true
	part.Parent = parent
	return part
end

-- Dig a smooth crater around a world point; call refreshCollision once the dig is done
local function dig(mesh: EditableMesh, part: MeshPart, worldPoint: Vector3, radius: number, depth: number)
	local localPoint = part.CFrame:PointToObjectSpace(worldPoint)
	for _, vertexId in mesh:FindVerticesWithinSphere(localPoint, radius) do
		local p = mesh:GetPosition(vertexId)
		local t = 1 - (p - localPoint).Magnitude / radius
		mesh:SetPosition(vertexId, p - Vector3.new(0, depth * t * t, 0))
	end
end

local function refreshCollision(mesh: EditableMesh, part: MeshPart)
	local ok, fresh = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
	end)
	if ok then
		part:ApplyMesh(fresh)
		fresh:Destroy()
	end
end
```

**Scale trap (Rule of thumb):** the crater maths above works in the mesh's local space. If you resize the MeshPart after creating it, local mesh units no longer equal studs, so convert with the size ratio or simply never resize generated parts.

## 5. Memory: the budget is the design constraint

- "Editable assets are currently expensive for memory usage." Clients have **strict memory budgets**; the server, Studio and plugins do not. The docs publish no number for the client budget. **Roblox docs.**
- Treat creation failure as a normal outcome: wrap creation in `pcall`, handle a `nil` result, and fall back to a static mesh. `EditableImage` creation is documented to return `nil` when the budget is used up; assume the same for meshes. **Unverified** for meshes specifically.
- Ways to spend less (all **Roblox docs**):
  - keep `FixedSize` on when you only move vertices;
  - share one mesh across many MeshParts;
  - once a mesh stops changing, convert it to opaque content with `AssetService:CreateDataModelContentAsync()`, use that, then call `Destroy()` on the editable mesh.
- `RemoveUnused()` drops orphaned vertices, normals, UVs and colours after heavy editing.
- Budget per device class like any other memory ([[Memory Budgets and Leaks]], [[Mobile and Low-End Optimization]]): test on the weakest phone you support, not in Studio, where memory is unlimited.

## 6. Publishing switch and permissions

- **Using `EditableMesh` fails by default in published games.** Turn on **Enable Mesh / Image APIs** in the Creator Dashboard (the experience's Configure ⟩ Settings), and in Studio turn on **Allow Mesh / Image APIs** under Experience Settings ⟩ Security. Review the Terms of Use the page links before enabling it. **Roblox docs.**
- The same switch gates `EditableImage` and several `AvatarCreationService` methods, so one setting decides all runtime-asset features.
- A game that works in Studio and fails live with errors from `AssetService` is almost always this switch, or an asset the live player cannot access (section 2).

## 7. Client or server?

The reference page does not describe how `EditableMesh` contents replicate. **Unverified:** whether a MeshPart created from an editable mesh on the server shows the same geometry to clients in every case. The safe pattern, which works either way (**Rule of thumb**):

1. The server owns the **edit operations** (seed, crater centre, radius, depth), validates them like any player request ([[Server Authority and Validation]]) and stores them.
2. Each client rebuilds the mesh from the seed and replays the operations, so late joiners get the same result ([[Seeds Determinism and Reproducible Worlds]]).
3. If gameplay collision matters, the server keeps its own copy for hit checks and does not trust client geometry.

## 8. Performance habits

- Batch edits, then refresh collision once per conceptual edit (section 4). **Roblox docs.**
- Spatial queries (`FindVerticesWithinSphere`, `FindClosestVertex`, `RaycastLocal`) are cheaper than looping every vertex yourself.
- Tile big surfaces into several meshes, edit only the tiles a change touches, and stream distant tiles out like any model ([[Level of Detail and Model Streaming]]).
- Avoid per-frame vertex animation on many meshes; profile with the [[MicroProfiler Guide]] before shipping it.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Mesh APIs not enabled for the published experience | Works in Studio, errors live | Turn on Enable Mesh / Image APIs in Creator Dashboard settings |
| Loading a mesh asset the player or owner cannot edit | `CreateEditableMeshAsync` throws | Use your own or shared assets only |
| Treating vertex ids as array indices | Wrong vertices move after a removal | Iterate `GetVertices()` / `GetFaces()` |
| Grid larger than 100 by 100 cells | `AddTriangle` errors part-way through the build | Tile the surface; stay under 20,000 triangles per mesh |
| Expecting collision to follow visual edits | Players walk over the crater's old surface | `CreateMeshPartAsync` + `ApplyMesh` after each finished edit |
| Adding vertices to a loaded mesh | Add calls fail | Load with `{ FixedSize = false }` |
| No fallback when creation fails | Blank or missing geometry on low-memory phones | `pcall`, handle nil, fall back to a static mesh |
| Keeping editable meshes alive after they stop changing | Memory climbs; later creations fail | Freeze with `CreateDataModelContentAsync`, then `Destroy()` |
| Resizing the generated MeshPart | Edits land in the wrong place | Never resize, or convert by the size ratio |

## Checklist
- [ ] Enable Mesh / Image APIs turned on for the published experience; Terms of Use reviewed.
- [ ] Every creation call wrapped in `pcall` with a nil check and a static fallback.
- [ ] Each mesh stays under 60,000 vertices and 20,000 triangles.
- [ ] Vertex and face loops iterate the id arrays, never a counter.
- [ ] Collision refreshed once per finished edit, not per vertex.
- [ ] Finished meshes frozen to opaque content and the editable copy destroyed.
- [ ] Edits are server-validated operations that late joiners can replay.
- [ ] Tested on the lowest-memory phone you support.

## See also
[[EditableImage for Pixel Buffers and Procedural 2D]] · [[Parts Unions and MeshParts]] · [[Procedural World Generation]] · [[Noise Functions and Terrain Generation]] · [[Destruction and Fracture]] · [[In-Experience Avatar Creation - Tokens, Editing and Prompting]] · [[Memory Budgets and Leaks]] · [[Art Budgets - Triangles Draw Calls Memory]]

<!-- related:start -->
## Related
[[Textures Decals and Texture Memory]] · [[Collision and Physics Geometry]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Terrain Deep Dive - Materials Water and Performance]] · [[Terrain Tools and Terrain API]] · [[Voxel Art - Studs Outlines and Style Kits]] · [[Modeling in Blender for Roblox]] · [[Foliage Props and Scatter]]
<!-- related:end -->
