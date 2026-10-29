---
tags: [modeling, optimization, mobile, performance, meshes, draw-calls, blender, budgets]
---
# Mesh Optimization for Mobile

<!-- tldr:start -->
> [!tldr] TL;DR
> - FPS dies looking at foliage: Overlapping alpha cards, `DoubleSided` transparency -> Geometry clumps, opaque styles, fewer overlaps
> - Phones crash or textures go blurry: Too many unique large textures -> Shared trim sheets and palettes; 512 and under
> - Low triangles, still slow: Draw calls from unique meshes and textures -> Reuse meshes and SurfaceAppearances; clone, do not re-import
> - Budget per asset class written down, phone first.
> - Repeated props are one mesh, cloned in Studio, sharing textures.
> - Unique detail merged per object; large world pieces split for culling.
>
> Cost: TL;DR ~190 tok · whole note ~5.7k tok. Read more: ## 6. Worked example: a market stall · ## 7. Audit scripts · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most Roblox players are on phones, and phones fail differently from PCs: they run out of memory before they run out of triangles, they pay heavily for transparent pixels, and they get hot and throttle after ten minutes. This note is about making meshes that survive that: what a phone actually pays for when it draws your model, per-asset budgets for mid-range phones, when to merge meshes and when to split them, the properties that quietly double a mesh's cost, a full worked optimisation of one prop, and two audit scripts (one in Blender, one in Studio) that find problems before players do.

What a mesh is to the engine (GPU vertices, vertex splits at seams and hard edges, normals) is already in [[Modeling Fundamentals for Games]]. Decimation and retopology techniques are in [[Retopology and Decimation]]; export and import settings in [[Exporting and Validating Models for Roblox]]; scene-wide budgets in [[Art Budgets - Triangles Draw Calls Memory]]. This note links to them rather than repeating them.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project** (one production game with hand-modelled Blender environments, weapons and creatures), **rule of thumb**.

---

## 1. What a phone pays for

| Cost | Driven by (for meshes) | Why phones suffer more |
|---|---|---|
| **Draw calls** | Unique mesh plus texture or SurfaceAppearance combinations in view | Phone CPUs are slower at submitting work; draw calls cost CPU time every frame |
| **Texture memory** | Pixel count of unique images, including every SurfaceAppearance map | Phones have a few GB shared between the OS, the app and the GPU; running out means blurry textures or a crash |
| **Fill rate and overdraw** | Screen pixels covered, times transparent layers | Mobile GPUs have far less fill rate; alpha cards and double-sided transparency are the classic killers |
| **Vertex work** | GPU vertices (after splits), more for skinned meshes | Matters for dense hero meshes and crowds of skinned creatures |
| **Triangles** | Visible triangle total | Matters, but less than the rows above (docs: triangle count "matters less than draw call count") |
| **Collision and physics** | Collision geometry of meshes that collide or are queried | CPU time and memory for collision data |
| **Shadows** | Meshes that cast shadows, especially small and moving ones | Shadow passes redraw geometry; but note shadows are off entirely below quality level 4 (Roblox docs), which many phones use |

The ordering is the point. A mesh team that only counts triangles optimises the fifth row and ignores the first three. In practice, the phone wins come from **fewer unique meshes and textures, smaller textures, and less transparency**, then triangles.

Roblox also helps you in three ways you should design for, not against:

- **Instancing.** Copies of the same mesh with identical SurfaceAppearance (or identical TextureID, or identical material when neither exists) are drawn together (Roblox docs). Ten unique meshes copied a hundred times each is cheap; a thousand unique meshes is not.
- **RenderFidelity.** `Automatic` (or `Performance`) lets distant meshes fall back to simpler versions; `Precise` on too many meshes is a common performance problem named in the docs.
- **Texture streaming by quality.** The engine loads lower-quality textures first and raises them according to device memory and distance (Roblox docs). This saves you on phones only if your textures have detail to drop; it does not fix 50 unique 1024 maps.

---

## 2. Budgets for mid-range phones

There is no official per-asset budget beyond the hard limit of **20,000 triangles per mesh** (Roblox docs, modelling specifications). These starting budgets are rules of thumb for a game targeting mid-range phones, cross-checked against shipped numbers where the reference project had them:

| Asset class | Triangles | Unique textures | Notes |
|---|---|---|---|
| Small repeated prop (crate, lamp, bush) | 100 to 800 | Shared trim or palette | Multiplied by every copy in view; the most important budget |
| Medium prop (stall, statue, cart) | 800 to 3,000 | One shared atlas or trim sheet | |
| Hero piece (centrepiece, fountain) | 5,000 to 10,000 | One set, at most 1024 | Reference project hub hero pieces: about 7,000 to 9,000 |
| Landmark gate or arch | 6,000 to 12,000 | Shared | Reference project gates; pair with streaming |
| Tree | 1,000 to 5,000 | Shared bark and leaf textures | Leaves as geometry clusters, not big alpha cards (section 4) |
| Weapon (held) | 1,000 to 5,000 | 256 to 512 | Seen up close but small on screen |
| Enemy (several on screen) | 3,000 to 10,000 | 512 | Reference project restyled enemies reached 10,000 to 42,000 across about 30 parts: fine for one boss, heavy for a pack |
| Boss (one on screen) | 10,000 to 30,000 total | 1024 | Split across meshes, each under 20,000 |

Texture sizing from the docs: about 256 x 256 for a 5 x 5 stud object, 512 for 10 x 10, 1024 for 20 x 20; most images need no more than 512 and minor ones should stay under 256; a 1024 texture costs four times the memory of a 512 (Roblox docs). Uploads above 1024 are accepted in some places (the texture specification page mentions up to 4096), but UV texture maps on meshes are documented at up to 1024 x 1024 and phones benefit from smaller anyway.

Outline hulls (an inverted, slightly inflated copy of the mesh for a cartoon outline) **double the triangles** and add a draw. The reference project kept outline hulls out of game meshes for exactly that reason and got outlines from art style and lighting instead. See [[Voxel Art - Studs Outlines and Style Kits]].

---

## 3. Merge or split?

This is the decision with the most nuance, and the obvious answer ("merge everything to save draw calls") is often wrong.

| Merge into one mesh when | Split into several meshes when |
|---|---|
| The pieces are always seen together (a stall's planks, posts and roof) | The object is large enough that parts of it are often off-screen or behind things (culling works per object) |
| They share one texture or palette | The pieces are reused elsewhere (keep them as shared, instanced pieces) |
| The result stays well under 20,000 triangles | Parts need different collision (walkable floor versus decorative trim) |
| None of them move independently | Parts move, animate or get destroyed |
| | The merged mesh would exceed the per-mesh limit |

### The instancing trap

Merging three copies of the same barrel into one "barrel cluster" mesh turns three instanced draws (nearly free) into one unique mesh (one more unique asset in memory) and removes your ability to rearrange them. For **repeated** props, keeping them as separate copies of one mesh is usually better than merging. Merge **unique** detail that belongs to one object.

### The culling trap

A 600-stud cliff merged into one mesh is always drawn if any corner is in view. Split it into chunks of roughly a screen's width at typical distance (rule of thumb: 50 to 150 studs for world chunks) so the off-screen chunks are culled. The docs confirm the engine skips draw calls for objects outside the field of view and for occluded objects, but that only helps if the object boundaries let it.

### The reference project's experience

Its rebuilt hub came in at about 2,000 instances (1,231 parts, of which trees were about 970) against 4,531 for the hand-built hub it replaced, mostly by turning many small parts into fewer meshes and reusing a small tree library as instanced copies. Its rule for new assets: build in Blender with clean topology and LODs in a shared library style, upload once, clone in Studio (re-importing the same model creates new asset ids, which breaks instancing; the docs give the same warning).

---

## 4. The properties that silently double the cost

| Property or habit | What it costs | What to do |
|---|---|---|
| **Transparency between 0 and 1** on large meshes | Overdraw: every pixel behind is drawn again; transparent objects also sort and batch worse | Opaque where possible; if you need a hole, model it |
| **Alpha cards** (leaves, grass, fences, hair planes) | Overdraw on every overlapping card; the main reason foliage kills phone FPS | Fewer, larger leaf clumps as geometry; or opaque cutout styles that read at distance; cap overlaps |
| **`DoubleSided = true`** | Both faces are drawn; on transparent meshes, doubles overdraw | Only on genuinely thin surfaces seen from both sides (banners, leaves); otherwise give the mesh thickness |
| **`RenderFidelity = Precise`** | No distant fallback | `Automatic` on almost everything (the reference project's decor convention) |
| **`CastShadow = true` on small or distant meshes** | Shadow passes draw them again | Off for small props, Neon, moving decorations (reference project convention: tiny parts and Neon never cast shadows) |
| **Precise collision on decoration** | Collision memory and physics time for something nobody touches | `CanCollide`, `CanTouch`, `CanQuery` off on decoration; `CollisionFidelity` `Box` or `Hull` where collision is needed. See [[Collision and Physics Geometry]] |
| **Many SurfaceAppearances** | Each unique one is a full set of maps in memory and breaks instancing with others | Share SurfaceAppearances across a kit; prefer `TextureID` palettes or trim sheets for small props |
| **Unique texture per small prop** | Memory and draws for objects that are a few pixels tall | Palette textures and trim sheets ([[Trim Sheets Atlases and Vertex Colors]]) |
| **Skinned meshes where rigid would do** | Skinning work per vertex every frame; spatial cluster rebuilds when skinned parts move (Roblox docs) | Rigid parts on Motor6Ds for mechanical things (doors, turrets); skinning only for organic deformation |

A note on `CollisionFidelity`: it cannot be changed on an already-loaded MeshPart from a normal script. Set it at import, in Studio's Properties, or create the part with `AssetService:CreateMeshPartAsync` and the collision options you want (measured in the reference project; the existing collision note covers the details).

---

## 5. Skinned and animated meshes

Phones feel crowds of skinned meshes more than anything static:

- **Vertex count matters more here.** A skinned vertex does bone blending every frame; a static one does not. Keep enemies that appear in packs near the low end of the budget table.
- **Four influences per vertex maximum** (Roblox docs). Prune weights in Blender to 4 and normalise before export, or the importer decides for you. See [[Weight Painting and Skinning for Roblox]].
- **Skinned MeshParts in a Model without a Humanoid use spatial clusters, and moving them forces cluster rebuilds** (Roblox docs). A Humanoid gives a single unified cluster at some memory cost; the docs advise profiling. Long `updateInvalidatedFastClusters` MicroProfiler tags (over 4 ms) indicate excessive invalidation (Roblox docs).
- **Fewer parts per creature.** A creature split into 30 MeshParts costs 30 draws per copy. Merge parts that never need separate collision or visibility, keep under 20,000 triangles per mesh.
- **Animation LOD** cuts the script and pose cost of distant creatures ([[Animation LOD]]). The reference project updated character animation every frame within 60 studs, every second frame to 150, every fourth to 300, and only advanced time beyond.

---

## 6. Worked example: a market stall

A first-pass market stall straight from a sculpting and kitbashing session:

| Measure | Before |
|---|---|
| Triangles | 14,200 |
| GPU vertices (after splits) | about 21,000 (flat-shaded crates, every face split) |
| MeshParts | 11 (planks, posts, roof, awning, 6 crates, sign) |
| Unique textures | 7 SurfaceAppearances at 1024, each with colour, normal and roughness (21 maps) |
| Awning | Transparent cloth, `DoubleSided`, alpha-fringed edge |
| Collision | Default fidelity on everything |

The stall appears 12 times along a market street. Do the arithmetic: 12 x 14,200 = 170,400 triangles for one street's stalls, 21 maps of 1024 (about 4 MB each uncompressed RGBA, so roughly 84 MB of texture before mips, though the engine compresses and may downscale; the ratio is what matters), and 132 MeshParts.

The pass, in order of payoff:

1. **Textures first.** Replace the 7 SurfaceAppearances with one 512 trim sheet (wood planks, cloth stripes, painted sign strip) shared with the rest of the market kit, plus a palette for crates. Memory: from 21 maps at 1024 to 3 maps at 512 shared by the whole kit, about a 28x reduction for this asset.
2. **Crates become one shared mesh.** The six crates were six unique imports. Make one crate mesh, place copies: they instance with every other crate in the game.
3. **Merge the stall body.** Planks, posts, roof and sign become one mesh (they are always seen together). Keep the awning separate (different material behaviour).
4. **Awning opaque.** Model the fringe as geometry with a scalloped edge; make it opaque and single-sided with thickness. No overdraw.
5. **Smooth shading with sharps on seams.** Mark sharp edges only where UV seams already are, so splits coincide ([[Modeling Fundamentals for Games]]).
6. **Decimate the body** to budget with a planar-aware decimation and clean-up ([[Retopology and Decimation]]).
7. **Collision.** Body: `Box` fidelity (players do not walk inside a stall). Crates: `CanCollide` off; `CanQuery` off. Awning: no collision.
8. **Shadows.** Crates `CastShadow` off.

| Measure | After |
|---|---|
| Triangles | 2,400 (body 1,700, awning 300, crate 64 x 6) |
| GPU vertices | about 3,000 |
| MeshParts per stall | 8 (body, awning, 6 crate copies) |
| Unique textures | 0 new (shared kit trim sheet and palette) |
| Transparency | None |
| Street of 12 | 28,800 triangles, 1 body mesh and 1 crate mesh instanced, no new texture memory |

Nobody will see the difference at play distance. That is the target: **lose what the camera cannot see.** Check it at the real camera distance on a phone, not in Blender's close-up viewport.

---

## 7. Audit scripts

### Blender: what will this cost?

Run this on selected objects before export. It reports triangles, Blender vertices, an estimate of GPU vertices (unique position, UV and normal combinations), materials and whether the object exceeds the Roblox per-mesh limit. It evaluates modifiers, so it measures what you will actually export.

```python
# Blender (4.x): estimate the export cost of the selected meshes.
import bpy

LIMIT = 20000  # Roblox per-mesh triangle limit (Roblox docs)

def cost(obj):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(deps)
    me = ev.to_mesh()
    try:
        me.calc_loop_triangles()
        tris = len(me.loop_triangles)
        uv = me.uv_layers.active.data if me.uv_layers.active else None
        if hasattr(me, "corner_normals"):  # Blender 4.1+
            normals = [tuple(round(c, 4) for c in n.vector) for n in me.corner_normals]
        else:  # older versions
            me.calc_normals_split()
            normals = [tuple(round(c, 4) for c in l.normal) for l in me.loops]
        keys = set()
        for i, loop in enumerate(me.loops):
            uvk = tuple(round(c, 5) for c in uv[i].uv) if uv else ()
            keys.add((loop.vertex_index, uvk, normals[i]))
        mats = len([m for m in obj.material_slots if m.material])
        return tris, len(me.vertices), len(keys), mats
    finally:
        ev.to_mesh_clear()

total = 0
for obj in bpy.context.selected_objects:
    if obj.type != 'MESH':
        continue
    tris, verts, gpu, mats = cost(obj)
    total += tris
    flags = []
    if tris > LIMIT:
        flags.append("OVER 20k: split")
    if gpu > 2 * max(verts, 1):
        flags.append("many splits: check sharps and seams")
    if mats > 1:
        flags.append(f"{mats} materials: Roblox meshes use one material each")
    print(f"{obj.name}: tris {tris}, verts {verts}, gpu verts ~{gpu}, mats {mats} {' | '.join(flags)}")
print("TOTAL tris:", total)
```

The "many splits" flag fires when GPU vertices exceed twice the Blender vertex count, which usually means flat shading or sharps and seams that do not coincide. The material warning reflects the docs' rule that each mesh can have only one material: multi-material objects are split on import or need an atlas.

### Studio: what is in the place?

Run in the command bar on a folder of art. It groups MeshParts by what can instance together and flags the costly properties from section 4.

```lua
--!strict
-- Mesh audit for mobile: instancing groups and costly flags under a root.
local function meshAudit(root: Instance)
	local groups: { [string]: number } = {}
	local flags = { precise = 0, doubleSided = 0, transparent = 0, smallShadow = 0, decorCollide = 0 }
	local total = 0

	for _, d in root:GetDescendants() do
		if not d:IsA("MeshPart") then
			continue
		end
		total += 1
		local sa = d:FindFirstChildOfClass("SurfaceAppearance")
		-- Approximate instancing key: same mesh and same texture source.
		local texKey = if sa then "SA:" .. sa.Name else "TX:" .. d.TextureID .. "|" .. d.Material.Name
		local key = d.MeshId .. "|" .. texKey
		groups[key] = (groups[key] or 0) + 1

		if d.RenderFidelity == Enum.RenderFidelity.Precise then
			flags.precise += 1
		end
		if d.DoubleSided then
			flags.doubleSided += 1
		end
		if d.Transparency > 0 and d.Transparency < 1 then
			flags.transparent += 1
		end
		local s = d.Size
		if d.CastShadow and math.max(s.X, s.Y, s.Z) < 2 then
			flags.smallShadow += 1
		end
		if d.CanCollide and d:GetAttribute("Decor") then
			flags.decorCollide += 1
		end
	end

	local unique, singles = 0, 0
	for _, count in groups do
		unique += 1
		if count == 1 then
			singles += 1
		end
	end
	print(("MeshParts %d, instancing groups %d, used once %d"):format(total, unique, singles))
	print(("Precise %d, DoubleSided %d, semi-transparent %d, small shadow casters %d, colliding decor %d")
		:format(flags.precise, flags.doubleSided, flags.transparent, flags.smallShadow, flags.decorCollide))
end

meshAudit(workspace)
```

Read the result as ratios. If most groups are "used once", the world is made of unique meshes and will be draw-call bound on phones; reuse more. The SurfaceAppearance key uses the instance name as a stand-in, because two SurfaceAppearances only instance when identical; if you name shared ones consistently, the grouping is close enough to act on. The `Decor` attribute is a project convention (tag decoration so tools can find it); adapt it to yours.

---

## 8. Testing on a device

The Studio Device Emulator shows layout, not performance ([[Mobile and Low-End Optimization]]). For meshes:

1. Publish to a test place and join on a real mid-range phone.
2. Stand in the densest view and the most transparent view (foliage, water, effects). Open Shift+F2 for draw calls and frame time, and the Developer Console memory tab for graphics texture memory ([[Developer Console and Stats]]).
3. Compare against a PC in the same spot. A phone frame time several times the PC's in one view but not others points at overdraw or textures in that view, not triangles.
4. Play 10 to 15 minutes. Phones throttle when hot; a scene that holds 60 FPS for two minutes and 35 after ten is over budget.
5. Check the lowest graphics quality: shadows off, lower detail. Does the scene still read? See [[Stylized Lighting Recipes]] for the no-shadow test.

---

## 9. When not to optimise

- **Hero moments seen once** (a boss arena centrepiece, a cutscene prop) can spend budget; spend it where the camera lingers and claw it back from repeated props.
- **Do not decimate silhouettes.** Players read shapes. Remove interior and back-facing detail first, never the outline.
- **Do not merge things you will need to change.** A merged mesh is fast and frozen. If designers move props weekly, keep them separate until the layout is final.
- **Do not chase triangles while a 1024 SurfaceAppearance sits on a pebble.** Fix the biggest cost first.

---

## Common mistakes

| Symptom | Likely cause | Fix |
|---|---|---|
| FPS dies looking at foliage | Overlapping alpha cards, `DoubleSided` transparency | Geometry clumps, opaque styles, fewer overlaps |
| Phones crash or textures go blurry | Too many unique large textures | Shared trim sheets and palettes; 512 and under |
| Low triangles, still slow | Draw calls from unique meshes and textures | Reuse meshes and SurfaceAppearances; clone, do not re-import |
| Copies do not instance | Re-imported duplicates with new ids, or slightly different SurfaceAppearances | Import once, clone in Studio; share SurfaceAppearances |
| A big merged mesh is always drawn | One object spanning the whole view | Split into world chunks |
| Creature packs tank FPS | Dense skinned meshes, many parts each | Lower budgets for pack enemies, fewer parts, animation LOD |
| Import fails on a hero mesh | Over 20,000 triangles | Split or decimate |
| Collision lag near decoration | Default or precise collision on props | Turn collision off on decoration; Box or Hull where needed |

## Checklist

- [ ] Budget per asset class written down, phone first.
- [ ] Repeated props are one mesh, cloned in Studio, sharing textures.
- [ ] Unique detail merged per object; large world pieces split for culling.
- [ ] Textures: trim sheets and palettes; 512 or less unless justified.
- [ ] No large semi-transparent meshes; `DoubleSided` only where needed.
- [ ] `RenderFidelity` Automatic; small props do not cast shadows.
- [ ] Decoration collision off; Box or Hull where collision is needed.
- [ ] Skinned meshes only for organic deformation; 4 influences; pack enemies under budget.
- [ ] Blender audit run before export; Studio audit run after import.
- [ ] Tested on a real phone, densest and most transparent views, 10+ minutes.

See also: [[Modeling Fundamentals for Games]], [[Retopology and Decimation]], [[Exporting and Validating Models for Roblox]], [[Art Budgets - Triangles Draw Calls Memory]], [[Level of Detail and Model Streaming]], [[Textures Decals and Texture Memory]], [[Trim Sheets Atlases and Vertex Colors]], [[Low-Poly and Stylized Modeling]], [[Modular Environment Kits]], [[Collision and Physics Geometry]], [[Rendering Performance]], [[Mobile and Low-End Optimization]].

## Connected notes
<!-- auto-links:start -->
[[Draw Calls]] · [[Triangle Budget]] · [[Modeling in Blender for Roblox]] · [[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[Foliage Props and Scatter]] · [[Parts Unions and MeshParts]]
<!-- auto-links:end -->
