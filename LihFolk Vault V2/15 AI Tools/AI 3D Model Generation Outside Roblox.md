---
tags: [ai, 3d, meshy, tripo, rodin, blender, retopology, type/guide, area/ai, level/intermediate, area/modeling]
---
# AI 3D Model Generation Outside Roblox

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Importing a 400,000 triangle generated model and letting the importer fail or split it.
> - Avoid: Keeping baked lighting in the colour map.
> - Avoid: Decimating a hard-surface object and keeping its wobbly edges.
> - Licence on the plan used: commercial use, attribution, ownership noted.
> - Transforms applied, origin set, scale and facing correct.
> - Under 20,000 triangles per mesh and within your own budget.
>
> Cost: TL;DR ~150 tok · whole note ~3.6k tok. Read more: ## 1. The tools · ## 3. Cleanup pipeline (Blender) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Outside Roblox, a crowded market of tools turns text or images into 3D models: Meshy, Tripo, Hyper3D Rodin, and open-weight models such as Roblox's own Cube 3D. Their output is impressive in a turntable video and awkward in a game: dense triangulated surfaces, baked-in lighting, messy UVs, no LODs, and sizes that mean nothing. This note covers what these tools actually output, the licence traps, and a concrete cleanup pipeline to turn a generated model into a Roblox-ready MeshPart, plus the reference project's reasons for banning generated meshes from its shipping art.

Related: [[Roblox Generative AI - Cube Mesh and Texture Generation]] (Roblox's in-Studio generation), [[Retopology and Decimation]], [[UV Unwrapping]], [[Texturing and PBR Baking]], [[Exporting and Validating Models for Roblox]], [[Blender Workflow for Roblox Creators]].

Product facts are as of October 2026, from vendor documentation and third-party listings where noted. These tools release new model versions every few months; re-check formats, limits and licences before relying on them.

---

## 1. The tools

| Tool | Inputs | Outputs (reported) | Notable features (reported) | Licence notes (reported) |
|---|---|---|---|---|
| Meshy | Text, image | FBX, OBJ, GLB, USDZ (third-party listing) | Remesh, rigging and animation listed at 0 credits on its pricing docs; generation costs credits | Pricing docs list the Free plan under CC BY 4.0: commercial use allowed **with attribution** to Meshy; paid plans have no attribution requirement. Free plan: 100 credits a month; failed generations do not use credits |
| Tripo | Text, image | GLB, FBX, OBJ, STL, USD, 3MF (varies by source) | "Smart Mesh" quad output with controlled polygon counts (a directory cites roughly 500 to 25,000) | A third-party guide says the free plan has no commercial licence; check the vendor terms |
| Hyper3D Rodin | Text, image | GLB, FBX, OBJ, STL, USDZ (third-party listing) | Quad or triangle output; several quality tiers | A listing says commercial use is allowed on generated models; free-tier download terms unclear. Check the vendor terms |
| Open-weight models (Cube 3D from Roblox, and others) | Text, image | Usually a mesh file you export yourself | Run locally; no per-model fee | The model's own licence; your hardware |

"Reported" means the fact came from a vendor page or third-party listing found in October 2026 and could not be confirmed in full on the vendor's own current terms. Treat the licence column as a list of questions to check, not answers.

### What all of them have in common

- **Topology**: dense triangle soup or auto-quads that follow the surface, not the deformation or the silhouette. Fine for a static prop after reduction; poor for anything that bends.
- **Texture**: a single baked colour map, sometimes with PBR maps. Lighting and ambient occlusion are often baked into the colour, so the model looks lit twice in Roblox.
- **UVs**: automatic islands, many seams, inefficient packing. Hard to hand-paint over.
- **Scale and orientation**: arbitrary. A sword might be 1 unit long; a house might be 1 unit tall.
- **Back and underside**: guessed. Image-to-3D in particular invents the parts the image did not show.
- **Thin parts**: blades, fingers, straps and chains come out thick, fused or broken.
- **Style**: generic. Each generation has its own interpretation of "stylised".

---

## 2. Roblox targets the cleanup must hit

From the Roblox mesh specifications (October 2026):
- **20,000 triangles maximum per mesh.** Avatar items have their own budgets ([[UGC Avatar Items and Accessories]]).
- Watertight geometry, no exposed holes or backfaces, real thickness (no zero-thickness surfaces).
- Quads where possible, avoid N-gons in the source.
- For skinned meshes: frozen bone transforms (scale 1, rotation 0), root at the origin, at most 4 influences per vertex, no influences on the root.

Project budgets (rules of thumb, from the reference project and common practice): small props 300-2,000 triangles, hero weapons a few thousand to around 25,000 across all parts (one hand-made hero weapon in the reference project was 26,800 triangles across 32 parts, each part under the per-mesh cap), large set pieces split into several meshes with LODs. See [[Art Budgets - Triangles Draw Calls Memory]].

A typical generated model arrives with 100,000 to over a million triangles. Reduction is not optional.

---

## 3. Cleanup pipeline (Blender)

The order matters: fix scale and orientation before anything else, reduce before UV work, bake last.

### Step 1: Import and normalise

- Import the GLB or FBX.
- Apply all transforms. Set the origin to the base centre (props) or the grip (weapons).
- Scale to real game size. Roblox's importer can treat 1 Blender unit as 1 stud; decide your convention and keep it ([[Blender Workflow for Roblox Creators]]).
- Face the model down Blender's -Y, which lands as Roblox forward. (The reference project measured that GLB imports are turned 180 degrees about Y: a model authored facing -Y arrives facing the Roblox LookVector, so do not add a 180 degree "fix". See [[Enemy Import Axis Fix]].)

### Step 2: Decide reduce or rebuild

| Model | Approach |
|---|---|
| Static prop, organic shape (rock, stump, statue) | Decimate (collapse) to budget, then clean |
| Static prop, hard-surface (crate, barrel, gun) | Rebuild with simple geometry, using the generated mesh as a reference; generated hard surfaces have wobbly edges that decimation keeps |
| Anything that deforms (characters, creatures, cloth) | Retopologise properly ([[Retopology and Decimation]], [[Topology and Edge Flow]]) |
| Anything with thin parts (blades, chains) | Rebuild those parts by hand |

### Step 3: Reduce with a script

```python
# Blender: decimate selected meshes to a triangle budget and report.
import bpy

TARGET_TRIS = 4000  # per object; choose per asset class

def tri_count(obj):
    deps = bpy.context.evaluated_depsgraph_get()
    mesh = obj.evaluated_get(deps).to_mesh()
    mesh.calc_loop_triangles()
    n = len(mesh.loop_triangles)
    obj.evaluated_get(deps).to_mesh_clear()
    return n

for obj in [o for o in bpy.context.selected_objects if o.type == 'MESH']:
    before = tri_count(obj)
    if before <= TARGET_TRIS:
        print(obj.name, before, "already under budget")
        continue
    mod = obj.modifiers.new("AI_Decimate", 'DECIMATE')
    mod.decimate_type = 'COLLAPSE'
    mod.ratio = TARGET_TRIS / before
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    print(obj.name, before, "->", tri_count(obj))
```

After decimation: merge by distance, recalculate normals outside, delete loose geometry, check for holes, and use [[weighted normals]] or shade-auto-smooth so faceting does not look accidental.

### Step 4: UVs and texture transfer

If you keep the generated texture:
1. Duplicate the original high-poly model before reducing.
2. UV unwrap the reduced model cleanly ([[UV Unwrapping]]).
3. Bake the high-poly's colour (and normal detail, if wanted) onto the low-poly ([[Normal Maps and Detail Baking]]).
4. Remove baked lighting from the colour map where you can (lift dark crevices, reduce large gradients), because Roblox will light it again.

If your game uses flat colours (as the reference project did), skip the texture: assign a few materials or vertex colours that match your palette ([[Trim Sheets Atlases and Vertex Colors]]). This is often faster and gives better style consistency than any texture cleanup.

### Step 5: Collision, LOD, export

- Simple collision: in Roblox, set `CollisionFidelity` to Box or Hull for props, or add invisible collider parts ([[Collision and Physics Geometry]]).
- LODs for large pieces ([[Level of Detail and Model Streaming]]).
- Export GLB or FBX with transforms applied; import through the 3D Importer ([[3D Importer Settings Reference]]); validate ([[Exporting and Validating Models for Roblox]]).

### Step 6: Record provenance

Keep the tool name, model version, plan, date and prompt with the source file. If the licence requires attribution (Meshy's free plan, for example), add it where the licence says (for a game, typically the experience description).

---

## 4. Time and quality: honest numbers

Rules of thumb from production experience (not vendor claims):

| Asset | Generated + cleanup | Modelled from scratch by a competent artist |
|---|---|---|
| Rock or stump, decimate and recolour | 10-20 minutes | 20-45 minutes |
| Hard-surface crate or barrel | 30-60 minutes (often a rebuild) | 20-40 minutes |
| Stylised weapon with hinges | 2+ hours, mostly rebuild | 1-3 hours |
| Rigged creature | Often longer than modelling, because retopology and skinning dominate | Depends on complexity |

Generated meshes save the most time where a human would spend the most time on organic surface detail that survives decimation, and save the least where clean geometry is the whole point.

---

## 5. Why the reference project banned generated meshes

Early in development the reference project used AI-generated meshes for some underwater set pieces and a run of dungeon set pieces. Within weeks the owner wrote a hard rule for every agent: build every model in Blender ourselves with clean topology, controlled triangulation, weighted normals, consistent texel density, a packed atlas and LODs for big pieces; never use generated meshes, generated procedural models, Toolbox assets or the existing AI-generated meshes; greybox with temporary blockout parts and replace each one by a Blender asset.

The recorded reasons:
- **Style.** The game had one look: chunky stylised shapes, flat colours, modelled leaf geometry, SmoothPlastic. Generated pieces did not match and stood out.
- **Proportions.** Generated set pieces came in with wrong aspect ratios and had to be checked one by one.
- **Control.** LODs, collision shapes and atlas packing were easier on hand-built meshes with known topology.

The interesting part is what replaced them: AI agents writing Blender Python that builds models procedurally from parameters (templates for swords, trees, cliffs), then uploading through a scripted add-on and swapping blockouts one for one. The AI was still doing the work, through code a human could read and re-run, rather than through an opaque generator. See [[Blender Automation with Python]] and [[Blender MCP]].

---

## 6. When generated 3D is the right call

- **Concept sculpts.** Generate, look from all sides, then model the idea properly.
- **Rocks, stumps, roots, rubble.** Organic detail that survives decimation and rarely needs style precision.
- **Prototypes and jams.** Speed matters more than topology.
- **Background props seen only at distance**, after reduction and recolouring.
- **Kitbash sources.** Cut useful chunks (a carved ornament, a skull) and integrate them into a hand-built model.

And when it is not: characters that animate, weapons that the player looks at all game, anything whose silhouette defines your game's identity.

---

## 7. Prompting 3D generators for game use

Rules of thumb that reduce cleanup:
- **Ask for one object, centred, in a neutral pose.** "A single wooden barrel, isolated, no ground, no props." Scenes and groups fuse into one lump.
- **Image-to-3D: use a clean front or three-quarter view** on a plain background. Generate the concept image first with that framing in mind ([[AI Image Generation for Icons Thumbnails and Concepts]]).
- **Name the style in shape words, not art-movement words.** "Chunky, bevelled, oversized proportions, simple shapes" gives better low-poly results than the name of a famous game.
- **Ask for low polygon output where the tool offers it** rather than reducing a dense mesh later; generated low-poly modes usually keep silhouettes better than decimation does.
- **Avoid thin parts in the request.** A sword with a long thin blade often comes out thick or broken; generate the hilt and model the blade.
- **Generate several and pick.** Credits for five attempts cost less than an hour of fixing the first one.

---

## Common mistakes

- Importing a 400,000 triangle generated model and letting the importer fail or split it.
- Keeping baked lighting in the colour map.
- Decimating a hard-surface object and keeping its wobbly edges.
- Skipping attribution required by a free plan.
- Trusting the back side of an image-to-3D result.
- Rigging a generated character without retopology.
- Mixing generated and hand-made assets with no shared palette or material rules.

## Checklist

- [ ] Licence on the plan used: commercial use, attribution, ownership noted.
- [ ] Transforms applied, origin set, scale and facing correct.
- [ ] Under 20,000 triangles per mesh and within your own budget.
- [ ] Clean normals, no holes, real thickness.
- [ ] Clean UVs and baked texture, or palette materials.
- [ ] Collision, LOD, validation in Studio.
- [ ] Provenance recorded with the source file.

## See also
[[Roblox Generative AI - Cube Mesh and Texture Generation]] · [[Modeling Fundamentals for Games]] · [[Retopology and Decimation]] · [[UV Unwrapping]] · [[Texturing and PBR Baking]] · [[Exporting and Validating Models for Roblox]] · [[Art Pipeline - Concept to In-Game Asset]] · [[Blender Automation with Python]]

## Connected notes
<!-- auto-links:start -->
[[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[AI in Roblox Development Overview]] · Modeling in Blender for Roblox · [[Roblox Policies on AI-Generated Content]] · Low-Poly and Stylized Modeling · Keeping a Mixed Asset Library Consistent
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Modeling in Blender for Roblox]] · [[AI Pitfalls - Assets and Import]] · [[AI Material and Texture Generation]] · [[Who Owns AI-Generated Code and Assets]] · [[Evaluating AI Tools - A Practical Rubric]] · [[AI Animation and Motion from Video]] · [[AI Audio - Voice Music and SFX]] · [[Roblox Studio Assistant]] · [[AI Agents and Autonomous Workflows]]
<!-- related:end -->
