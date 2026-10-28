---
tags: [modeling, retopology, decimation, remesh, lod, optimization, blender, python]
---
# Retopology and Decimation

Sooner or later every model has too many triangles: a sculpt with two million, a boolean-heavy prop with 60,000, an AI-generated or scanned mesh with a triangle soup, a kit piece that needs a cheaper far version. There are three ways down, and they produce very different meshes:

- **Decimation**: an algorithm removes edges while keeping the shape. Fast, automatic, keeps UVs mostly intact, makes triangle soup topology.
- **Remeshing**: an algorithm rebuilds the surface from scratch as an even grid (voxel) or a quad layout (Quadriflow). Fast, destroys UVs and detail, gives even topology.
- **Retopology**: you build a new clean mesh over the old one. Slow, best result, the only real answer for skinned characters.

This note says which to use when, gives Blender steps and settings for each, and covers level of detail (LOD) on Roblox, where the engine does part of the job for you.

---

## 1. Choosing the method

| Source mesh | Will it deform? | Use | Why |
|---|---|---|---|
| Sculpt of a character or creature | Yes | **Manual retopology** | The manual: automatic remeshers "generally don't result in topology that lends itself to deformation" |
| Sculpt of a rock, stump, statue | No | **Decimate** (then bake the sculpt detail to a normal map if needed) | Shape preservation is all that matters |
| Boolean-heavy hard-surface prop | No | Clean up by hand or **Decimate Planar** | Flat faces with stray edges collapse well |
| Over-subdivided low-poly | No | **Decimate Un-Subdivide** | Reverses grid subdivision cleanly |
| Messy mesh you want to keep sculpting | - | **Voxel remesh** | Even density for sculpting, not for games |
| Mesh needing a quick quad base for subdivision or multires | Maybe | **Quadriflow remesh** | The manual recommends it for this |
| Static model that needs a far LOD | No | **Decimate Collapse** at a ratio | Shape kept, triangles cut |
| Scanned or AI-generated mesh | Depends | Decimate for static props; retopologise if it must deform | Such meshes are usually dense triangle soup with baked-in shading noise |

---

## 2. Decimation in Blender

### Decimate modifier modes (manual)

**Collapse**: "merges vertices together progressively, taking the shape of the mesh into account".
- *Ratio*: the ratio of faces to keep (1.0 unchanged, 0.5 about half). The ratio is computed on **triangles**; if the mesh has quads and *Triangulate* is off, more faces remain than the ratio suggests.
- *Symmetry*: keep symmetry on one axis. Turn on for characters and symmetric props, or the result becomes subtly lopsided.
- *Triangulate*: keep the triangulated result.
- *Vertex Group* + *Factor*: protect areas (face, hands) from decimation.

**Un-Subdivide**: removes subdivision levels from grid-like topology (*Iterations*). Perfect for "I subdivided twice too many" and for terrain-like grids.

**Planar**: dissolves edges between faces whose angle is under the *Angle Limit*. Removes the triangle clutter on flat areas of hard-surface and boolean models without touching curves. Start at 1-5 degrees for hard-surface, 5-15 degrees for stylised rocks (rule of thumb).

The edit-mode equivalent of Collapse is *Mesh > Clean Up > Decimate Geometry* (manual), which adds vertex-weight control: higher weights make edges collapse first, or inverted, last.

### A sane decimation sequence for a static prop

1. Duplicate the source (keep the original hidden).
2. *Merge by Distance* first (duplicate vertices confuse the collapse).
3. Decimate **Planar** at a small angle to clear flat areas.
4. Decimate **Collapse** with Symmetry on until the triangle budget is met.
5. Shade: Smooth by Angle or Weighted Normal (decimated meshes often have bad smoothing).
6. Check silhouette from the game camera angles, and check UV seams for stretching.

### Decimate to an exact triangle budget

```python
# Blender: decimate the active mesh to a target triangle count with a binary search on the ratio.
import bpy

def tri_count(obj):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(deps)
    mesh = ev.to_mesh()
    n = sum(len(p.vertices) - 2 for p in mesh.polygons)
    ev.to_mesh_clear()
    return n

def decimate_to(obj, target_tris, symmetry_axis='X', tolerance=0.02):
    mod = obj.modifiers.new("DecimateToBudget", 'DECIMATE')
    mod.decimate_type = 'COLLAPSE'
    mod.use_symmetry = symmetry_axis is not None
    if symmetry_axis:
        mod.symmetry_axis = symmetry_axis
    lo, hi = 0.0, 1.0
    for _ in range(20):                                   # 20 halvings is far more precise than needed
        mod.ratio = (lo + hi) / 2
        n = tri_count(obj)
        if abs(n - target_tris) <= target_tris * tolerance:
            break
        if n > target_tris:
            hi = mod.ratio
        else:
            lo = mod.ratio
    return mod.ratio, tri_count(obj)

obj = bpy.context.active_object
print(decimate_to(obj, 5000))                            # e.g. a far LOD or a regular enemy budget
```

The modifier stays live until you apply it, so you can still tweak the ratio by hand.

### What decimation does badly

- **Deforming meshes**: triangle soup with no loops; joints crease.
- **UV seams and hard edges**: Collapse tries to preserve them, but heavy ratios distort UVs near seams. Bake after decimating, not before, when you can.
- **Thin parts**: at low ratios, thin features (fingers, antennae, sword tips) collapse first. Protect them with a vertex group, or split them into a separate object.
- **Shading**: expect to redo normals.

---

## 3. Remeshing

### Voxel remesh

Rebuilds the surface as an even grid of quads at a *Voxel Size*. Use it to clean up a sculpt or merge intersecting shapes into one surface. Results are dense and even, not game-ready: always decimate or retopologise afterwards. In Sculpt mode, Ctrl+R remeshes at the current voxel size.

### Quadriflow (Quad remesh)

*Mesh > Remesh > Quadriflow* (the operator `bpy.ops.object.quadriflow_remesh`) builds an all-quad layout. Options from the manual: *Use Mesh Symmetry*, *Preserve Sharp*, *Preserve Mesh Boundary*, *Preserve Attributes*, *Smooth Normals*, and a *Mode* of Ratio, Edge Length or target Faces, plus a *Seed* that changes the layout.

Good for: a quick quad base for further manual work, rocks and organic props that will be subdivided or sculpted. Not good for: final deforming topology (loops do not follow joints), hard-surface (corners round off), anything with UVs (they are lost).

---

## 4. Manual retopology

### Setup in Blender

1. Put the high-res sculpt in its own collection; make it unselectable (so clicks pass through to the new mesh).
2. Add a new mesh object (a single plane or a vertex) at the same location: this is the retopo mesh.
3. Turn on the **Retopology overlay** (edit mode overlays), which the manual describes as letting you "see the original mesh through the retopologized one and vice versa" without the confusion of full X-ray.
4. Snapping: *Snap to Face* with *Project Individual Elements* (newer versions call these targets *Face Project* and *Face Nearest*; menu names vary by version), so new vertices land on the sculpt surface.
5. Add a **Mirror** modifier (X, Clipping) to the retopo mesh so you build half.
6. Optionally a **Shrinkwrap** modifier targeting the sculpt (Wrap Method *Nearest Surface Point* or *Project*, small *Offset*) above the Mirror, so every edit stays on the surface.

### Tools

- **Poly Build** tool (edit mode toolbar): click to add vertices and faces, Ctrl-drag to extrude new quads from edges, Shift to delete faces. The manual recommends it for retopology.
- **Extrude edges** (E) along the surface, with snapping on.
- **Grid Fill** to close patches with even quads.
- **Edge Slide** (G G) to tune loops without leaving the surface.

### Order of work for a creature

1. **Major loops first**: eye rings, mouth ring, rings round the neck, shoulders, elbows, wrists, waist, hips, knees, ankles. These define everything else (see [[Topology and Edge Flow]]).
2. Connect the rings with strips of quads along the limbs and torso.
3. Fill between with grid fills; place poles on flat areas.
4. Check density: dense at joints and face, sparse on flats.
5. Pose test with a quick armature before UVs.
6. UV, then bake the sculpt's detail onto the new mesh (normal map, AO). See [[Normal Maps and Detail Baking]].

### Time and budget expectations

Rule of thumb: a stylised creature of 3,000-8,000 triangles takes a skilled artist half a day to two days to retopologise. That cost is why the segmented and voxel approaches in [[Organic and Creature Modeling]] and [[Voxel and Blocky Modeling]] are so popular in Roblox: they skip retopology entirely.

---

## 5. Level of detail on Roblox

### What the engine does for you

`MeshPart.RenderFidelity` set to **Automatic** (the default) switches detail by camera distance: full detail under 250 studs, medium from 250 to 500, lowest beyond 500 (Docs). The lower levels are generated by the engine from your mesh. For most props this is enough, and the reference project's decor rule was simply "meshes `RenderFidelity=Automatic`".

Limits of automatic LOD:
- You do not control what it removes; thin features may vanish early or late.
- It does not reduce the number of parts or draw calls, only triangles per mesh.
- Close-range costs (under 250 studs) are your full mesh: most gameplay happens there.

### Making your own LODs

For big landmarks, cliffs and anything seen from far and near, build explicit LOD meshes in Blender:

| LOD | Triangles vs LOD0 | Built by |
|---|---|---|
| LOD0 | 100 percent | Your model |
| LOD1 | 40-60 percent | Decimate Collapse with symmetry, silhouette protected |
| LOD2 / impostor | 10-20 percent, or a card | Heavy decimate, merged parts, or a billboard |

The reference project shipped its realm cliff ring modules and big stone dressing with `_LOD1` variants (for example a cliff "Tier3(+LOD1)" and "Mass(+LOD1)" module set), and its hand-modelled zone art budget planned "meshes <= 10K tris for landmarks, LOD via RenderFidelity" (Measured / project plan).

How to swap them in game:
- **Instance streaming** can replace a distant model with a low-detail representation using the Model's level-of-detail settings (see [[Instance Streaming]] and [[Level of Detail and Model Streaming]] for the current property names and behaviour).
- **A client script** that toggles which LOD model is parented (or transparent) based on camera distance, checked a few times per second, not every frame. Keep both LODs' pivots identical so the swap does not pop position.

```lua
--!strict
-- Client: swap between LOD0 and LOD1 models by camera distance, checked 4 times a second.
local camera = workspace.CurrentCamera

type LodPair = { root: Model, near: Model, far: Model, swapAt: number, showingNear: boolean }
local pairs_: { LodPair } = {}

local function register(root: Model, swapAt: number)
	local near = root:FindFirstChild("LOD0") :: Model
	local far = root:FindFirstChild("LOD1") :: Model
	far.Parent = nil                                   -- start with the detailed version
	table.insert(pairs_, { root = root, near = near, far = far, swapAt = swapAt, showingNear = true })
end

task.spawn(function()
	while true do
		local camPos = camera.CFrame.Position
		for _, p in pairs_ do
			local dist = (p.root:GetPivot().Position - camPos).Magnitude
			local wantNear = dist < p.swapAt
			if wantNear ~= p.showingNear then
				p.showingNear = wantNear
				p.near.Parent = if wantNear then p.root else nil
				p.far.Parent = if wantNear then nil else p.root
			end
		end
		task.wait(0.25)
	end
end)

for _, m in workspace:WaitForChild("Landmarks"):GetChildren() do
	if m:IsA("Model") and m:FindFirstChild("LOD0") and m:FindFirstChild("LOD1") then
		register(m, 300)
	end
end
```

Use hysteresis (swap to far at 320, back to near at 280) if you see popping at the boundary. Only do this for a handful of large landmarks; per-prop LOD scripts cost more than they save.

---

## 6. Splitting over-budget meshes

Roblox's per-mesh limit is 20,000 triangles (Docs). When a model is over it:

1. **Split by material or colour group first**: each group is already a separate MeshPart in Roblox.
2. **Split by body part or functional piece** (head, body, tail; base, canopy, sign).
3. **Decimate only what remains** over budget.

Splitting also helps culling (off-screen pieces are skipped) and lets the engine's automatic LOD treat each piece by its own size. The reference project's 31k-triangle boss was 32 parts with the largest at 6.5k: the 20k limit never came into play.

---

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Decimating a character that must deform | Creases, broken joints | Retopologise |
| Remeshing a UV-mapped model | UVs lost | Decimate, or redo UVs |
| Decimate without symmetry | Lopsided face or silhouette | Symmetry on |
| Baking before decimating heavily | Stretched textures | Decimate, then UV and bake |
| Thin features collapsing | Missing horns, tips | Vertex group protection or separate object |
| Per-prop LOD scripts for everything | More script cost than triangles saved | RenderFidelity Automatic; custom LOD only for landmarks |
| LOD meshes with different pivots | Visible pop on swap | Identical origins |

## Checklist

- [ ] Method picked by whether the mesh deforms and whether UVs exist.
- [ ] Source kept hidden; work on a duplicate.
- [ ] Merge by distance before decimating; symmetry on.
- [ ] Triangle target met per mesh (and under 20,000).
- [ ] Silhouette checked from the game camera; shading redone.
- [ ] Retopo: major loops first, pose test before UVs, sculpt detail baked.
- [ ] LOD: RenderFidelity Automatic by default; explicit LODs only for big landmarks, same pivots.

## See also

[[Topology and Edge Flow]] · [[Organic and Creature Modeling]] · [[Blender Workflow for Roblox Creators]] · [[Normal Maps and Detail Baking]] · [[Level of Detail and Model Streaming]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[AI 3D Model Generation Outside Roblox]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]]

## Connected notes
<!-- auto-links:start -->
[[Modeling Fundamentals for Games]] · [[Faceted Low-Poly - Flat Normals and Facet Size]] · [[Hard-Surface Modeling]] · [[Links - Topology]] · [[Modeling in Blender for Roblox]] · [[Clean Stylised Shading - Weighted and Custom Normals]]
<!-- auto-links:end -->
