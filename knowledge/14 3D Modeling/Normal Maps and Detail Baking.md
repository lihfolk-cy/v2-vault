---
tags: [modeling, normal-maps, baking, tangent-space, blender, surfaceappearance]
---
# Normal Maps and Detail Baking

A normal map lets a 2,000-triangle low-poly mesh shade like a 200,000-triangle sculpt by storing, per texel, which way the surface "really" faces. On Roblox, where every mesh is capped at 20,000 triangles and avatar items at 4,000 (Creator Hub, checked October 2026), normal maps are how detailed armour, weapons and creatures stay inside budget. They are also the map most often broken by invisible technical mismatches: wrong convention, wrong tangent basis, wrong smoothing, wrong bake distance. This note explains the mechanism, the Roblox convention, the Blender bake in detail, and how to diagnose every common artefact.

General PBR setup and other maps are in [[Texturing and PBR Baking]].

## 1. What a tangent-space normal map stores

At each texel the map stores a direction as RGB:

- R = X component, G = Y component, B = Z component, each remapped from the range -1..1 into 0..255.
- The directions are expressed **in tangent space**: a little coordinate frame that sits on the surface at that point, with Z along the mesh's interpolated vertex normal, X along the tangent (the direction U increases in the UV map) and Y along the bitangent (the direction V increases).
- A texel that says "straight out along the vertex normal" is (0, 0, 1), which encodes as RGB (127 or 128, 127 or 128, 255): the familiar lavender. Roblox docs: a uniform [127, 127, 255] is a flat normal map.

The renderer rebuilds the same tangent frame at runtime from the mesh's normals, tangents and UVs, and rotates the stored direction into world space. The result is only correct if **the renderer's tangent frame matches the baker's tangent frame**. Most normal map bugs come from that one sentence.

### Why tangent space and not object space

Object-space normal maps store absolute directions; they break when the mesh deforms (skinned characters, layered clothing) and cannot be reused across mirrored or rotated UV islands. Tangent space follows the surface, so it survives animation, mirroring and trim sheet reuse. Roblox supports **only tangent-space normal maps in the OpenGL convention** (docs).

## 2. OpenGL vs DirectX

The two conventions differ only in the direction of the green channel:

| Convention | Green channel means | Used by (defaults) |
|---|---|---|
| **OpenGL (Y+)** | Up in the texture = +V | **Roblox**, Blender, Maya (recent), Godot |
| DirectX (Y-) | Up in the texture = -V | Unreal Engine, Substance 3D Painter's default "DirectX" setting in many templates, 3ds Max, many texture libraries |

A DirectX map in Roblox makes bumps look like dents when lit from above and vice versa; it is most visible on bevelled edges, rivets and panel lines. Fixes:

- Bake or export in OpenGL from the start (Blender's Normal bake defaults to +X +Y +Z, which is OpenGL).
- In Substance Painter, set the project's normal map format to OpenGL, or use an export template with OpenGL normals (see [[Substance Painter and Texturing Tools]]).
- To convert an existing map, **invert only the green channel**. In Blender's compositor or shader: Separate Color, Invert on G, Combine. In any image editor: invert the green channel only.

Identify a convention by eye: on a raised round rivet in a map, OpenGL has the lighter green on the **top** half (the surface facing up looks up); DirectX has it on the bottom (rule of thumb, holds for maps viewed with V up).

## 3. Tangent basis: MikkTSpace and why your exporter matters

Bakers and renderers must compute tangents the same way. The industry standard is **MikkTSpace**. Blender bakes and computes tangents with MikkTSpace. Whether Roblox reconstructs tangents with MikkTSpace or reads tangents from the file is **not documented** (unverified as of October 2026). In practice, Blender-baked maps on Blender-exported meshes look correct in Studio on well-prepared meshes (measured in the reference project's armour and weapons). To keep the risk low:

- **Triangulate before baking and exporting.** A quad can be split along either diagonal; if the baker splits one way and the importer the other, the tangent frame differs on that face and shows as a faint diagonal crease. Add a Triangulate modifier (Beauty or Fixed, the same one for bake and export), apply it on the export copy (rule of thumb, standard practice).
- **Export the same normals you baked with.** If you bake with custom split normals or a Weighted Normal modifier, export with them. A change in smoothing after the bake invalidates the map.
- **Do not edit the low-poly after baking.** Moving vertices is fine in small amounts; changing smoothing, triangulation or UV islands is not.

## 4. Smoothing, hard edges and the bake

The low-poly's vertex normals decide what the normal map has to correct. Three strategies:

| Strategy | Low-poly normals | Normal map does | Result |
|---|---|---|---|
| All smooth | One smoothing group | Large gradients to fix the shading of flat faces | Works, but needs high bit depth to avoid banding; 8-bit maps show gradients and compression artefacts |
| Hard edges at UV seams | Sharp at angles above about 60 degrees, each a UV seam | Small corrections only | **Recommended.** Clean, compresses well |
| Weighted normals | Weighted Normal modifier, keep sharp off | Almost nothing on flat faces | Excellent for hard-surface with bevels; may need no normal map at all for stylised assets |

The rule: **every hard edge must be a UV seam** with padding on both sides (see [[UV Unwrapping]]). A hard edge inside one island produces a visible line because bilinear filtering mixes the two incompatible corrections.

Blender 4.1 and later: auto smooth moved from a mesh setting to a "Smooth by Angle" modifier (or the Shade Auto Smooth operator, which adds it). Apply it, or export with modifiers applied, so the exported normals match what you baked with.

### Weighted normals as an alternative to baking

For stylised hard-surface (chunky armour, sci-fi crates), a mid-poly model with real bevels and a Weighted Normal modifier often looks better on Roblox than a low-poly with a baked map, costs no texture memory, and has nothing to go wrong in the bake. The reference project's toon armour used real geometric bevels (bevel width 0.035 studs, one segment) instead of baked normal detail, and stayed at about 3,300 triangles per mesh at most. Use baking when the detail is fine (engraving, stitching, scales, rivets) and geometry is too expensive.

## 5. Baking a normal map in Blender, step by step

1. **High-poly**: sculpt or subdivided model with the detail. It may overlap itself and does not need clean topology. Floating details (a separate rivet mesh hovering just above a plate) bake perfectly onto the plate below and save sculpting time.
2. **Low-poly**: the game mesh. Unwrapped, hard edges split, triangulated, transforms applied, roughly enclosing or matching the high-poly.
3. **Explode the parts** if pieces sit close together (fingers, straps over a torso, a blade inside a scabbard). Move each high/low pair apart by the same offset (shape keys or an "exploded" copy) so rays cannot hit the wrong part. This is the most reliable fix for cross-projection.
4. **Material on the low-poly** with an Image Texture node: new image (1024 or the target size), **Non-Color**, 8-bit, node selected and active.
5. Render engine **Cycles**. Bake Type **Normal**, Space **Tangent**, swizzle **+X +Y +Z**.
6. Select high-poly, then low-poly (active). Enable **Selected to Active**.
7. Set **Extrusion** (or enable Cage and pick a cage object), and a **Max Ray Distance** slightly larger.
8. Margin (padding) 16 px for 1024; Margin Type "Extend".
9. Bake. Save the image as PNG.
10. Apply the map on the low-poly (Image Texture, Non-Color, into a Normal Map node set to Tangent Space, into the Principled BSDF Normal input) and check under a rotating light in Blender before you go to Studio. Roblox's own Blender guidance uses the same Normal Map node hookup.

```python
# Blender 4.x: selected-to-active tangent normal bake with a cage or extrusion.
import bpy

def bake_normal(high, low, size=1024, extrusion=0.03, cage=None, path="//N.png"):
    scn = bpy.context.scene
    scn.render.engine = 'CYCLES'
    scn.cycles.samples = 16

    img = bpy.data.images.new(f"{low.name}_Normal", size, size, alpha=False)
    img.colorspace_settings.name = 'Non-Color'
    for slot in low.material_slots:
        nt = slot.material.node_tree
        node = nt.nodes.new('ShaderNodeTexImage')
        node.image = img
        for n in nt.nodes:
            n.select = False
        node.select = True
        nt.nodes.active = node

    bpy.ops.object.select_all(action='DESELECT')
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low

    args = dict(type='NORMAL', normal_space='TANGENT',
                normal_r='POS_X', normal_g='POS_Y', normal_b='POS_Z',
                use_selected_to_active=True, margin=16, margin_type='EXTEND',
                max_ray_distance=extrusion * 2.0, use_clear=True)
    if cage is not None:
        args.update(use_cage=True, cage_object=cage.name)
    else:
        args.update(cage_extrusion=extrusion)
    bpy.ops.object.bake(**args)

    img.filepath_raw = bpy.path.abspath(path)
    img.file_format = 'PNG'
    img.save()

bake_normal(bpy.data.objects["Helm_high"], bpy.data.objects["Helm_low"],
            extrusion=0.03, path="//Helm_Normal.png")
```

## 6. Other detail maps worth baking

Roblox has no slots for AO, curvature, thickness or height, but these maps are the **masks** that drive texturing in Substance Painter, Blender or a script:

| Map | Bake in Blender | Used for |
|---|---|---|
| Ambient occlusion | Bake Type AO, selected to active | Dirt in crevices; multiply lightly into albedo; roughness variation |
| Curvature | No bake type; use the Pointiness attribute (Cycles) or Geometry Nodes edge angle into an Emit bake | Edge wear (convex), grime (concave) |
| Position / gradient | Bake Type `Position` (Blender 4.x) or a Gradient texture into Emit | Top-down dust, bottom-up dirt, VFX gradients |
| ID / material mask | Diffuse Color bake of flat colours per material | Fast masking in Painter |
| Height | No direct type; bake displacement as Emit from the high-poly's shader | Hand-painting guides; not used by Roblox |

The reference project generated all its stylised textures from such masks in Python without any external texturing tool: painted gradients and edge highlights for the toon armour trim, gradient x noise for VFX. See [[Hand-Painted and Stylized Texturing]] and [[Trim Sheets Atlases and Vertex Colors]].

## 7. Normal maps on trim sheets and mirrored UVs

- **Trim sheets.** A trim sheet's normal map is authored flat (a strip of bevel or a plate inset baked once from a high-poly strip). Any mesh whose UVs sit on that strip borrows the detail. It works in tangent space because the tangent frame follows each mesh's UVs. Keep islands aligned with the strip direction; rotating an island 90 degrees rotates the lighting of the detail with it, which is correct, but flipping an island (mirroring U) inverts the X component unless the tangent basis handles mirrored UVs.
- **Mirrored UVs.** MikkTSpace handles mirrored islands by flipping the bitangent sign per vertex, so mirrored overlaps usually work. Whether Roblox handles the bitangent sign the same way is not documented. If a mirrored half shows inverted bumps in Studio but not in Blender, give it unique UV space. (The usual trick elsewhere, offsetting the mirrored island by exactly 1 UV unit, is out of spec on Roblox because UVs must stay within 0 to 1.) Rule of thumb for Roblox: avoid mirrored UVs on normal-mapped hero assets; it is cheap insurance.

## 8. Normal maps on skinned and layered meshes

Tangent-space maps deform correctly with skinning because tangents are recomputed from the deformed surface. Two Roblox-specific notes:

- Layered clothing is wrapped (fitted to a body via cages) and skinned at runtime. Large wraps (a jacket on a much bigger body) stretch the surface; the normal map stretches with it. Keep fine high-frequency detail modest on garments (rule of thumb). See [[Layered Clothing Cages and Animation]].
- On avatar items, normal maps count against the same 2048 x 2048 Marketplace cap (docs) and are part of the SurfaceAppearance.

## 9. Diagnosing artefacts

| What you see | Cause | Fix |
|---|---|---|
| Bumps look like dents in Studio, fine in Blender | DirectX map | Invert green, or re-export OpenGL |
| Faint diagonal creases across quads | Triangulation differs between bake and engine | Triangulate before bake and export |
| Lines along edges of UV islands | Hard edge without seam, or too little padding | Seam at hard edges; padding 16 px at 1024 |
| Large dark or light gradients across flat faces | All-smooth low-poly with strong correction, compressed to 8 bit | Hard edges at seams, or weighted normals |
| Black or noise patches | Rays started inside the high-poly | More extrusion, or a cage |
| Detail from one part appears on another (finger on finger) | Rays too long or parts too close | Explode bake, shorter Max Ray Distance, cage |
| Wavy straight lines (bent panel lines) | Low-poly silhouette deviates a lot from the high-poly; projection skews | More low-poly support, or cage |
| Entire map lavender | Bake hit nothing (selection or active object wrong, Selected to Active off) | Recheck selection order |
| Map looks right but lighting seems reversed on the mirrored side | Mirrored UVs | Unique UVs for that island |
| Normal map seems to have no effect in Studio | Assigned to the wrong slot (for example `ColorMap`), or detail too fine for the texel density | Assign to `NormalMap` on the SurfaceAppearance; check density |
| Normal map looks washed and weak | Saved through an sRGB conversion | Non-Color image, re-save |

A good test object in Studio: one MeshPart with your map, a PointLight orbiting it via a small script in Run mode, under a dim `Lighting` preset. Bump direction errors are obvious under a moving light.

```lua
--!strict
-- Studio test: orbit a PointLight around a part to judge normal map direction.
-- Run in Run mode (F8); delete afterwards.
local RunService = game:GetService("RunService")

local target = workspace:WaitForChild("NormalTest") :: BasePart
local holder = Instance.new("Part")
holder.Anchored = true
holder.CanCollide = false
holder.Transparency = 1
holder.Size = Vector3.one * 0.2
holder.Parent = workspace

local light = Instance.new("PointLight")
light.Range = 12
light.Brightness = 3
light.Parent = holder

local t = 0
RunService.Heartbeat:Connect(function(dt: number)
	t += dt
	local offset = Vector3.new(math.cos(t) * 4, 2, math.sin(t) * 4)
	holder.Position = target.Position + offset
end)
```

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Baking in DirectX (Painter default in some templates) | Inverted lighting | OpenGL everywhere |
| Changing smoothing after baking | Seams and gradients | Lock smoothing, rebake |
| Quads exported untriangulated | Diagonal creases | Triangulate first |
| One extrusion for a model with thin and thick parts | Holes on one, bleed on the other | Cage |
| Mirrored UVs on hero assets | Possible inverted half | Unique UVs |
| Normal map where a bevel would do | Texture memory and bake risk for nothing | Real bevel plus weighted normals |
| Saving 16-bit PNG and assuming Roblox keeps it | Converted to 8-bit (docs list 24-bit RGB) | Bake 8-bit with dithering, or avoid strong gradients |

## Checklist

- [ ] OpenGL convention, tangent space.
- [ ] Hard edges are UV seams; triangulated low-poly; smoothing final.
- [ ] Exploded bake for close parts; cage when one extrusion cannot fit all.
- [ ] Non-Color image, padding set, saved.
- [ ] Verified under a moving light in Blender and in Studio.
- [ ] No mirrored UVs on normal-mapped hero assets.

## See also

[[Texturing and PBR Baking]] · [[UV Unwrapping]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Substance Painter and Texturing Tools]] · [[Hard-Surface Modeling]] · [[Retopology and Decimation]] · [[Organic and Creature Modeling]] · [[Topology and Edge Flow]] · [[Exporting and Validating Models for Roblox]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Layered Clothing Cages and Animation]]

## Connected notes
<!-- auto-links:start -->
[[SurfaceAppearance PBR Workflow]] · [[Voxel Shading - Baked AO Edges and Lighting]] · [[Modeling in Blender for Roblox]] · [[Baking Lighting and Detail into Textures]] · [[Materials and Surfaces Start Here]] · [[Clean Stylised Shading - Weighted and Custom Normals]]
<!-- auto-links:end -->
