---
tags: [modeling, export, import, validation, pivots, collision, meshpart, type/guide, area/modeling, level/intermediate, api/DoubleSided, api/Model]
---
# Exporting and Validating Models for Roblox

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Unapplied scale -> Apply transforms
> - Avoid: Scaling in Studio to fix units -> Fix at export
> - Avoid: Origin left at world centre for every piece -> Set origins on purpose
> - Transforms applied; 1 unit = 1 stud; origin placed.
> - Normals outward; no internal faces; triangles within limit.
> - One UV map, one material; textures embedded or uploaded.
>
> Cost: TL;DR ~130 tok · whole note ~4.7k tok. Read more: ## 5. Pivots · ## 6. Collision and render fidelity · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The last mile from Blender to a working MeshPart is where good models go wrong: the wrong scale, a pivot floating 12 studs above a tree, a sword that faces sideways, a collider that blocks a doorway, a texture that silently did not come through, 400 meshes uploaded to the wrong owner. This note is a pre-export checklist, the export settings that matter, what the 3D Importer and upload add-ons do to pivots and axes, collision fidelity and `AssetService:CreateMeshPartAsync`, and a Studio validation script you can run on every import. Specs from the Creator Hub (checked October 2026); "measured" items are from one production game, the reference project, which imported and uploaded thousands of meshes.

Importer options in full: [[3D Importer Settings Reference]]. Format choice: [[Exporting FBX vs GLB]]. Rigs: [[Importing Models and Rigs]].

## 1. Hard limits

| Limit | Value | Source |
|---|---|---|
| Triangles per mesh | 20,000 | Roblox docs (modeling specifications) |
| Avatar accessories | 4,000 triangles, one mesh | Roblox docs |
| Geometry | Watertight, no exposed holes or backfaces, some volume (no zero thickness) | Roblox docs |
| Topology | Quads where possible, avoid n-gons (the mesh is triangulated anyway) | Roblox docs |
| UVs | One set, 0 to 1 | Roblox docs |
| Materials | One per mesh | Roblox docs |
| Textures | `.png`, `.jpg`, `.tga`, `.bmp`; 4096 maximum per spec page (also lists 1024 for UV maps); Marketplace 2048 | Roblox docs |
| Rigged transforms | Bones frozen, scale 1, rotation 0, root at origin | Roblox docs |
| Mesh formats | `.fbx`, `.obj`, `.gltf` / `.glb` | Roblox docs |

"Watertight" is a guideline for general meshes (props with open backs import fine) and a hard validation rule for avatar items. Open meshes also cause collision and shadow artefacts, so close them unless you have a reason (rule of thumb).

## 2. Before you export: the Blender pass

| Check | How in Blender | Why |
|---|---|---|
| Scale applied | `Ctrl+A > Scale` (and rotation) | Unapplied scale changes normals, bakes and import size |
| Units | 1 Blender unit = 1 stud (vault convention); importer Scale Unit "Studs" | Avoids the 0.28 m per stud conversion and 100x FBX errors |
| Origin (pivot) placed on purpose | `Object > Set Origin`; for props usually bottom centre | Becomes the MeshPart pivot when "Use Imported Pivot" is on |
| Facing | Model the front facing a fixed axis and keep it consistent across a kit | Kits placed by script assume one forward |
| Normals outward | Overlay "Face Orientation" (blue out, red in); `Shift+N` to recalc | Inverted faces render invisible from outside (backface culling) |
| No internal or duplicate faces | `Merge by Distance`, `Select All by Trait > Interior Faces` | Wasted triangles, z-fighting, broken bakes |
| Non-manifold | `Select All by Trait > Non Manifold` | Holes break watertight rules and collision hulls |
| Triangle count | Statistics overlay | Under 20,000 (4,000 for UGC) |
| Smoothing final | Smooth by Angle modifier applied or exported | Normals match bakes ([[Normal Maps and Detail Baking]]) |
| One UV map, one material | Object Data > UV Maps; material slots | Roblox reads one of each |
| Naming | Object and mesh names meaningful and unique | Names become MeshPart names; scripts look them up |
| Modifiers | Apply or export with "Apply Modifiers" | Mirror, bevel, solidify otherwise lost |

Mesh pieces that should be separate MeshParts (a door and its frame, a blade and its guard for a rig) must be separate objects; parts that will never move independently should usually be joined (fewer instances, see [[Art Budgets - Triangles Draw Calls Memory]]). Very large meshes cut into chunks stream and cull better ([[Level of Detail and Model Streaming]]).

## 3. Export settings

**FBX** (Roblox docs, Blender): Path Mode `Copy` with Embed Textures on; Transform > Apply Scalings `FBX Unit Scale`; Armature > Add Leaf Bones off; Bake Animation off unless exporting animation.

**glTF/GLB** (rule of thumb from the reference project): Format GLB (one file), Include selected objects, Transform +Y Up (default), Mesh: Apply Modifiers, UVs, Normals; vertex colours only if you use them; Materials export for embedded textures. glTF is metres by spec; with 1 unit = 1 stud and importer Scale Unit "Studs" sizes match.

Format choice in one line: GLB for static props and kits, FBX for rigs and when Roblox docs or an add-on expect it. Details in [[Exporting FBX vs GLB]].

## 4. Importing: what to set and what to check

Key importer options for static models (full list in [[3D Importer Settings Reference]]):

| Option | For props and kits |
|---|---|
| Name | Set it; GLBs otherwise arrive as a Model named `Scene` (measured) |
| Upload to Roblox | **Off while iterating**, on for the final import |
| Creator | The user or group that owns the experience; assets owned by someone else may not load in the game |
| Set Pivot to Scene Origin | On for kits modelled around the origin |
| Use Imported Pivot | On, so Blender origins become pivots |
| Merge Meshes | Off for kits (keeps names and pivots) |
| Scale Unit | Studs |
| Ignore Vertex Colors | Off only if you use them; on if a generator left junk colours ([[Trim Sheets Atlases and Vertex Colors]]) |

Read the importer's warnings panel every time: missing textures, too many triangles, non-manifold geometry and scale anomalies are reported there before you commit.

## 5. Pivots

Every `BasePart` has a pivot defined by `PivotOffset` (a CFrame relative to the part); a `Model`'s pivot is `WorldPivot`, or the PrimaryPart's pivot when a PrimaryPart is set. `PivotTo`, `GetPivot` and Studio's move tools use it.

### Measured pivot traps

- **Upload add-ons can leave a rotated `PivotOffset`.** Meshes uploaded from Blender through an Open Cloud upload add-on arrived with a rotated `PivotOffset` (measured, on armour pieces and on creature parts). Code that calls `GetBoundingBox`, `ScaleTo` or `PivotTo` then works in a rotated frame and places things wrongly. The reference project reset every uploaded part: `part.PivotOffset = CFrame.new()`.
- **With a PrimaryPart, `WorldPivot` writes are ignored.** A tree library's models had pivots 12 to 23 studs above the trunk bottom; setting `Model.WorldPivot` did nothing because the PrimaryPart owned the pivot. The fix was to set `PrimaryPart.PivotOffset` (measured).
- **Bounding-box pivots are not ground pivots.** Trees and rocks whose trunk or base is off-centre float or sink when placed by bounding box. The reference project re-pivoted trees to the trunk-bottom centroid and then re-seated them with downward ray scans.
- **`PivotTo` with a mirrored CFrame does not mirror a model** (measured). Mirror in Blender.
- **Axes survived the upload route.** Uploaded meshes needed no yaw fix (checked on an asymmetric lamp pole), and 156 armour meshes showed 0.000 axis drift between Blender and Studio via the FBX upload route (measured). Animated GLB imports were a different story ([[Enemy Import Axis Fix]]).

```lua
--!strict
-- Command bar / plugin: reset pivots on freshly uploaded MeshParts and give each
-- model a bottom-centre pivot through its PrimaryPart (or WorldPivot if none).
local function resetPartPivots(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.PivotOffset = CFrame.new()
		end
	end
end

local function bottomCentrePivot(model: Model)
	local cf, size = model:GetBoundingBox()
	local bottom = cf * CFrame.new(0, -size.Y / 2, 0)
	local primary = model.PrimaryPart
	if primary then
		-- WorldPivot writes are ignored when a PrimaryPart exists.
		primary.PivotOffset = primary.CFrame:ToObjectSpace(bottom)
	else
		model.WorldPivot = bottom
	end
end

for _, m in workspace.ImportedKit:GetChildren() do
	if m:IsA("Model") then
		resetPartPivots(m)
		bottomCentrePivot(m)
	end
end
```

Note `GetBoundingBox` is oriented by the model's current pivot orientation, which is why resetting rotated part pivots first matters.

## 6. Collision and render fidelity

### CollisionFidelity

Each MeshPart's physics shape is computed from its mesh according to `CollisionFidelity` (enum values: `Default`, `Hull`, `Box`, `PreciseConvexDecomposition`, and a newer `Tunable`):

| Value | Shape | Use for |
|---|---|---|
| `Box` | Bounding box | Small props, debris, anything players do not need to touch accurately; cheapest |
| `Hull` | One convex hull | Rocks, crates, simple convex shapes |
| `Default` | Approximate decomposition | General use; may block concave openings |
| `PreciseConvexDecomposition` | Many convex pieces closely following the mesh | Arches, doorways, stairs, walkable sculpted floors |
| `Tunable` | Newer option; parameters not covered here | Verify current docs before use |

Rules of thumb:

- **Most decorative meshes should not collide at all.** `CanCollide = false`, `CanQuery = false` (unless raycasts need them), `CanTouch = false`. Collision geometry costs memory and physics time.
- **Use invisible primitive colliders** for complex walkable shapes: a few anchored Parts approximating the floor and walls, the visual mesh non-colliding. The reference project kept original meshes as invisible colliders when it replaced visuals, so collision stayed identical.
- **`PreciseConvexDecomposition` only where precision matters** (big walkable set pieces).
- Check with Studio's collision fidelity visualisation (Studio settings, "Show Decomposition Geometry") before trusting a doorway. See [[Collision and Physics Geometry]] and [[Physics Performance]].

### Setting CollisionFidelity from code

The reference does not mark `CollisionFidelity` as Plugin security, but the reference project found that **it cannot be changed on an already loaded MeshPart from a script or tool call** (measured; the collision geometry is built when the part is created). Set it in the Properties window in Studio, or create the part with the fidelity you want using `AssetService:CreateMeshPartAsync`:

```lua
--!strict
-- Create a MeshPart with a chosen collision fidelity from a mesh asset.
-- Yields. Works in Studio (command bar, plugins) and at runtime on the server.
local AssetService = game:GetService("AssetService")

local function meshWithCollision(meshId: string, fidelity: Enum.CollisionFidelity): MeshPart?
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
			CollisionFidelity = fidelity,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
	end)
	if not ok then
		warn("CreateMeshPartAsync failed:", result)
		return nil
	end
	return result :: MeshPart
end

-- Replace a collider's geometry in place, keeping its name, CFrame and parent.
local function rebuildCollider(old: MeshPart, fidelity: Enum.CollisionFidelity)
	local fresh = meshWithCollision(old.MeshId, fidelity)
	if not fresh then
		return
	end
	-- ApplyMesh copies the mesh (and its collision data) from 'fresh' onto 'old'.
	-- The exact list of copied properties is not documented; verify on one part.
	old:ApplyMesh(fresh)
	fresh:Destroy()
end

rebuildCollider(workspace.Arena.Floor :: MeshPart, Enum.CollisionFidelity.PreciseConvexDecomposition)
```

`CreateMeshPartAsync(meshContent: Content, options)` returns a new MeshPart; the options table accepts `CollisionFidelity`, `RenderFidelity` and `FluidFidelity`, defaulting to `Default`, `Automatic` and `Automatic` when absent (docs). It exists because `MeshId` cannot be assigned by scripts. The reference project built its big kit colliders with `PreciseConvexDecomposition` this way. Reading `old.MeshId` needs plugin-level access, so `rebuildCollider` is a Studio-side tool; at runtime, keep mesh ids in your own config instead.

### RenderFidelity

`Automatic` (default) lowers mesh detail with distance; `Precise` always renders full detail; `Performance` always uses lower detail. Leave `Automatic` for most things; `Precise` for silhouettes that pop visibly (large hero landmarks) after you have checked the cost. See [[Level of Detail and Model Streaming]].

### DoubleSided

`MeshPart.DoubleSided` renders back faces. Use it for leaves, cloth cards and single-plane VFX instead of duplicating faces; it is cheaper in memory than doubled geometry but still costs fill. Avatar items must be watertight instead.

## 7. Uploading at scale

| Route | When | Notes |
|---|---|---|
| 3D Importer with Upload on | One-off assets | Creator must match the experience owner |
| Roblox's official Blender plugin | Frequent pushes from Blender | Roblox docs describe it as an open-source Open Cloud implementation that sends objects from Blender to Studio |
| Open Cloud scripts | Batches of hundreds | See [[Asset Upload Automation with Open Cloud]] |
| Packages | Kits installed into several places | Upload once, update everywhere ([[Packages and Asset Reuse]]) |

Reference project practice for big kits: upload meshes once from Blender, record every returned asset id in a JSON map, insert the uploaded package into Studio, then run an installer module that builds the library (names, pivots reset, SurfaceAppearances, attributes, collision settings) from that map. Every change is re-runnable, and the Blender file keeps the ids, so re-uploads only touch changed meshes. See [[Asset Pipelines]] and [[Batch Processing Tools in Studio]].

## 8. A validation script for every import

Run in the command bar after an import. It reports common problems without changing anything.

```lua
--!strict
-- Read-only import audit. Select a Model (or folder) and run.
local Selection = game:GetService("Selection")

type Issue = { path: string, problem: string }

local function audit(root: Instance): { Issue }
	local issues: { Issue } = {}
	local function add(inst: Instance, problem: string)
		table.insert(issues, { path = inst:GetFullName(), problem = problem })
	end

	for _, d in root:GetDescendants() do
		if d:IsA("MeshPart") then
			-- Scale sanity: Size vs the mesh's native size.
			local ratio = d.Size / d.MeshSize
			if ratio.X > 50 or ratio.X < 0.02 then
				add(d, `odd scale ratio {ratio} (unit mistake?)`)
			end
			if d.Size.Magnitude > 2048 then
				add(d, "very large part, consider splitting")
			end
			-- Rotated pivots (e.g. from upload add-ons).
			if d.PivotOffset.Rotation ~= CFrame.new().Rotation then
				add(d, "rotated PivotOffset")
			end
			-- Collision on decorative meshes.
			if d.CanCollide and d.CollisionFidelity == Enum.CollisionFidelity.PreciseConvexDecomposition
				and d.Size.Magnitude < 4 then
				add(d, "small part with precise collision")
			end
			-- Textures.
			local sa = d:FindFirstChildOfClass("SurfaceAppearance")
			if sa == nil and d.TextureID == "" then
				add(d, "no texture (fine if coloured by Color/Material)")
			end
			if sa and sa.AlphaMode == Enum.AlphaMode.Transparency and d.Transparency == 0 then
				add(d, "Transparency AlphaMode with part Transparency 0: soft alpha will hard-clip")
			end
			if not d.Anchored and not d:FindFirstAncestorOfClass("Tool") then
				add(d, "unanchored")
			end
		elseif d:IsA("Model") and d.Name == "Scene" then
			add(d, "unnamed GLB root 'Scene'")
		end
	end
	return issues
end

for _, sel in Selection:Get() do
	local issues = audit(sel)
	print(`{sel.Name}: {#issues} issue(s)`)
	for _, i in issues do
		print(" -", i.path, ":", i.problem)
	end
end
```

`MeshSize` is the mesh's native size; a huge or tiny ratio usually means a unit mismatch you should fix at export, not by scaling in Studio. The checks are heuristics, adjust thresholds to your game.

## 9. Placement checks for kits

When a kit is placed by script, validate the placement numerically rather than by screenshot (screenshots of large scenes are unreliable): the reference project checked every placed model for overlap with keep-out zones, floating (downward rays from the base), blocked walk areas and gate mouths, and reported counts (0 overlaps, 0 floats) before calling a zone done. See [[Environment and Level Pipeline]] and [[QA Checklists Before Release]].

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Unapplied scale | Wrong size, broken normals | Apply transforms |
| Scaling in Studio to fix units | Texture density, pivots and offsets off | Fix at export |
| Origin left at world centre for every piece | Pivots far from meshes | Set origins on purpose |
| Leaving uploader pivots | Rotated placement and bounding boxes | Reset `PivotOffset` |
| Setting `WorldPivot` on a model with a PrimaryPart | Ignored | Set `PrimaryPart.PivotOffset` |
| Precise collision everywhere | Memory and physics cost | Non-colliding visuals, primitive colliders |
| Trying to set CollisionFidelity by script on a loaded part | No effect | Properties window, or `CreateMeshPartAsync` |
| Upload on while iterating | Inventory full of test assets | Upload off until final |
| Uploading under the wrong creator | Assets will not load in a group game | Match the experience owner |
| Inverted normals | Invisible faces | Recalculate outside |

## Checklist

- [ ] Transforms applied; 1 unit = 1 stud; origin placed.
- [ ] Normals outward; no internal faces; triangles within limit.
- [ ] One UV map, one material; textures embedded or uploaded.
- [ ] Correct export preset (FBX unit scale or GLB).
- [ ] Importer: name, Upload, Creator, pivots, Merge Meshes, Scale Unit.
- [ ] Uploaded `PivotOffset`s reset; model pivots bottom-centre.
- [ ] Collision: off for decoration; fidelity chosen; doorways verified.
- [ ] Audit script clean; placement checked numerically.

## See also

[[3D Importer Settings Reference]] · [[Exporting FBX vs GLB]] · [[Importing Models and Rigs]] · [[Blender Workflow for Roblox Creators]] · [[Modeling Fundamentals for Games]] · [[Parts Unions and MeshParts]] · [[Collision and Physics Geometry]] · [[Level of Detail and Model Streaming]] · [[Asset Upload Automation with Open Cloud]] · [[Blender Automation with Python]] · [[UGC Avatar Items and Accessories]] · [[UV Unwrapping]] · [[Texturing and PBR Baking]]

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox Asset Import]] · Official Docs - Asset Creation · Modeling in Blender for Roblox · Meshing Voxels for Roblox - Greedy Meshing and Export · Art Pipeline - Concept to In-Game Asset · Rigging in Blender
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[AI Pitfalls - Assets and Import]] · [[Modular Environment Kits]] · [[Meshing Voxels for Roblox - Greedy Meshing and Export]] · [[Mesh Optimization for Mobile]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[Substance Painter and Texturing Tools]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Modeling Weapons and Props]] · [[Topology and Edge Flow]] · [[Hard-Surface Modeling]]
<!-- related:end -->
