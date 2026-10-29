---
tags: [modeling, texturing, pbr, baking, blender, cycles, surfaceappearance, type/guide, area/modeling, level/intermediate, api/SurfaceAppearance, api/Part]
---
# Texturing and PBR Baking

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Baking colour with lighting contributions -> Color only
> - Avoid: Data maps in sRGB -> Non-Color everywhere
> - Avoid: Image node not active before bake -> Select and activate the node in each material
> - Metalness workflow; spec/gloss converted.
> - Colour map sRGB, all other maps Non-Color, verified pixel values.
> - Metalness binary except transitions; dielectric albedo within range.
>
> Cost: TL;DR ~140 tok · whole note ~5.3k tok. Read more: ## 1. The SurfaceAppearance maps · ## 4. Baking in Blender with Cycles · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox renders custom-textured meshes through `SurfaceAppearance`, a metalness-workflow PBR material with five maps. This note explains what each map means to the renderer, which colour space each must be authored in, how to bake them in Blender with Cycles (including selected-to-active baking with a cage), the roughness and metalness conventions that make assets look right under Roblox lighting, and what a texture set costs. Specs are from the Creator Hub (checked October 2026); "measured" items come from one production game, the reference project.

Prerequisites: a clean unwrap ([[UV Unwrapping]]). For normal maps specifically, see [[Normal Maps and Detail Baking]]. For the tool side, see [[Substance Painter and Texturing Tools]].

## 1. The SurfaceAppearance maps

| Map | Property (Content version) | Channels | Colour space to author in | Meaning |
|---|---|---|---|---|
| Colour (albedo) | `ColorMap` (`ColorMapContent`) | RGB 24-bit, plus alpha | sRGB | Base colour "with little or no lighting" (docs). Alpha drives `AlphaMode` |
| Normal | `NormalMap` (`NormalMapContent`) | RGB 24-bit | Linear (Non-Color) | Tangent-space surface direction. **OpenGL convention only** |
| Roughness | `RoughnessMap` (`RoughnessMapContent`) | Grayscale 8-bit | Linear (Non-Color) | 0 = glossy sharp reflection, 1 = matte |
| Metalness | `MetalnessMap` (`MetalnessMapContent`) | Grayscale 8-bit | Linear (Non-Color) | 0 = dielectric, 1 = metal |
| Emissive mask | `EmissiveMaskContent` | Grayscale 8-bit | Linear (Non-Color) | Where the surface glows; tinted by `EmissiveTint`, scaled by `EmissiveStrength` |

Other properties: `AlphaMode`, `Color` (tint), `EmissiveStrength`, `EmissiveTint`, `ResampleMode`. All from the Creator Hub `SurfaceAppearance` reference and PBR textures guide.

Facts that shape the pipeline:

- **Metalness workflow only.** Studio uses metalness/roughness, not specular/glossiness (docs). If a library gives you spec/gloss, convert: roughness = 1 minus glossiness, and derive albedo and metalness from the specular colour by hand or in a texturing tool.
- **Map properties are not writable by game scripts.** The map properties carry Plugin security; the PBR guide says SurfaceAppearance properties cannot be modified by scripts during a game because the engine pre-processes them. Plan texture swaps as instance swaps: clone a prepared MeshPart or SurfaceAppearance from storage.
- **But some properties do change at runtime.** `Color`, `EmissiveStrength` and `EmissiveTint` carry no security tag in the reference. The reference project set `SurfaceAppearance.Color` from scripts to tint VFX meshes and armour at runtime, and it worked (measured). The guide's blanket statement and the reference tags disagree; treat map ids as fixed and these three as scriptable, and test on a live server.
- **SurfaceAppearance replaces the mesh's `TextureID`** (docs: PBR maps override the existing TextureID).
- **Emissive and the Marketplace:** EmissiveStrength must be between 0 and 40 for Marketplace items, and items using an emissive mask pay a higher upload fee (see [[UGC Avatar Items and Accessories]]).

### AlphaMode

| Mode | What alpha does (docs) | Use it for |
|---|---|---|
| `Overlay` (default) | Transparent areas show `MeshPart.Color` underneath | One mesh with painted details over a recolourable base |
| `Transparency` | Transparent areas remove the surface | Foliage cards, lace, chain mail, VFX erosion |
| `TintMask` | Alpha controls how strongly `SurfaceAppearance.Color` tints the colour map | Recolourable trim sheets, team colours, one texture for many variants |
| `Opaque` | Ignores alpha | Beta at the time of writing (File > Beta Features > MaterialVariant Alpha Mode) |

Two easy-to-miss rules from the docs:

- In `Transparency` mode, **`MeshPart.Transparency` 0 gives hard-edged cutouts**; for semi-transparent gradients set it to at least 0.02. A VFX mesh with a soft fade baked into alpha will look hard-clipped until you set the part's Transparency slightly above zero.
- In `TintMask` mode, **keep colour in transparent regions and do not use premultiplied alpha**. Alpha 0 means "untinted", not "invisible", so the RGB under alpha 0 is what players see. Many painting tools write black RGB under zero alpha; that turns your untinted gold trim black.

### The tint: SurfaceAppearance.Color

`Color` multiplies the colour map texel by texel (docs). So a near-white or grayscale colour map gives the strongest, most predictable tint; a saturated map shifts hue in ugly ways. Tinting costs nothing and lets one map serve many variants. It tints only the colour map, not `MeshPart.Color` showing through in Overlay mode.

Measured nuance: an opaque colour map ignores `Part.Color`. The reference project's VFX helper mirrored each part's `Color` into its SurfaceAppearance's `Color` and `EmissiveTint` so that existing code that tinted parts still worked. Because signals are deferred, the mirrored tint landed one frame after `Color` was set.

```lua
--!strict
-- Keep a SurfaceAppearance tint in sync with its MeshPart's Color, so code
-- that recolours parts (team colours, rarity tints) also recolours PBR meshes.
local function bindTint(part: MeshPart)
	local sa = part:FindFirstChildOfClass("SurfaceAppearance")
	if not sa then
		return
	end
	local function apply()
		sa.Color = part.Color
		sa.EmissiveTint = part.Color
	end
	apply()
	-- Deferred signals: this runs after the change, typically next resumption point.
	part:GetPropertyChangedSignal("Color"):Connect(apply)
end
```

## 2. Colour space: the single biggest source of wrong-looking textures

Colour textures store perceptual values (sRGB). Data textures (normal, roughness, metalness, masks) store numbers that the shader uses directly and must be read **linearly**. If a data map is treated as sRGB anywhere in the chain, its mid values shift: a roughness of 0.5 written through an sRGB conversion becomes about 0.21 linear, so the surface looks far glossier than you painted.

| Step | Colour map | Data maps |
|---|---|---|
| Blender Image Texture node | Color Space `sRGB` | Color Space `Non-Color` |
| Bake target image | `sRGB` | `Non-Color` |
| File saved | 8-bit PNG | 8-bit PNG (grayscale or RGB for normal) |
| Roblox | sRGB colour map | Read as data |

Roblox does not ask you for a colour space at upload; it treats each map by the slot it is in. Your job is to make sure the pixels in the file are right: a roughness PNG should contain the number you meant, not a gamma-encoded version. A quick check: a 50 percent roughness region should read RGB 128 in an image viewer.

Also check Blender's view transform. Filmic and AgX change how renders look but do not change saved data images when "Save as Render" is off. Set the view transform to `Standard` while texturing so the viewport shows the colours you will get in Studio.

## 3. Roughness and metalness conventions

### Metalness

Docs: use 0 or 1 in most cases; partial values for things like satin or silk. Rules of thumb that follow:

- **Metal is 1, everything else 0.** Painted metal is paint (0). Rusty metal is a mask: rust 0, bare steel 1.
- **Avoid large mid-grey metalness.** Values around 0.5 render as dirty, darkened plastic. Mid values belong only at blended boundaries (a few pixels of transition) and in deliberate fabrics.
- **Metal colour comes from the albedo.** For metals the albedo is the reflection colour: gold around RGB (255, 195, 85), silver and steel around (190, 190, 195), copper (240, 160, 125) (common PBR reference values; rule of thumb). Dark metal albedo makes metal look black in dim zones.
- **Dielectric albedo range.** Keep non-metal albedo roughly between RGB 30 and 240 (sRGB). Pure black has no light to reflect and kills PBR shading; pure white blows out under bright Roblox sun.

### Roughness

- **Most game surfaces sit between 0.4 and 0.9.** Very low roughness (below about 0.2) shows mirror-sharp sky reflections that change with every lighting setting.
- **Roughness carries the material read.** Variation in roughness (fingerprints, wear on edges, grime in crevices) does more for realism than variation in colour.
- **Fresnel surprise.** The docs warn that Fresnel can cause unexpected specular response at grazing angles and suggest raising roughness by about 0.1 in such cases. Rims of round objects (helmets, barrels) light up more in Studio than in Blender.
- **Studio and authoring tools differ.** The docs say brightness and reflectivity may differ between Studio and tools such as Substance Painter. Always judge final values in Studio under your game's actual `Lighting` and `Atmosphere`.

### Under Roblox lighting

The same asset looks different under each lighting technology and each zone's ambient. The reference project's armour checklist explicitly included "how the tinted SurfaceAppearance reads in each zone's lighting" as a play-test item. Build a lighting test room in your place: one copy of each lighting preset your game uses, a grey sphere, a chrome sphere, and your asset (see [[Lighting Technologies and Settings]]).

## 4. Baking in Blender with Cycles

"Baking" renders a property of a surface into a texture. Two flavours:

| Flavour | Source | Target | Typical maps |
|---|---|---|---|
| Self-bake | The object's own shader | Its own UVs | Procedural colour, roughness, gradients, VFX textures, AO |
| Selected to active | A high-poly or detail object | The low-poly game mesh | Normal, AO, curvature, colour from high-poly vertex paint |

Baking requires the Cycles render engine.

### Setup steps (Blender 4.x)

1. Render engine: **Cycles**. Device GPU if available. Samples: low (16 to 64) is fine for normal, roughness and colour bakes; AO needs more (128 or more) to avoid noise.
2. On the target (low-poly) object's material, add an **Image Texture** node with a new image at the target resolution. Set its colour space (sRGB for colour, Non-Color for everything else). Do not connect it to anything.
3. **Select that node and make it active** in the node editor. Blender bakes into the active Image Texture node of each material on the target object. Forgetting this is the classic "Bake succeeded, image is empty" problem.
4. Bake panel (Render Properties > Bake): choose Bake Type, set **Margin** (padding) to 16 px for 1024 (rule of thumb; see [[UV Unwrapping]]), Margin Type "Extend" or "Adjacent Faces".
5. For selected to active: select the high-poly, then shift-select the low-poly so it is active; enable **Selected to Active**; set **Extrusion** or a **Cage** (below); set Max Ray Distance.
6. Bake, then **save the image** (Image > Save As). Baked images live only in memory until saved.

### Bake types and what to tick

| Map | Bake Type | Settings |
|---|---|---|
| Colour (albedo) | `Diffuse` | Contributions: **Color only** (untick Direct and Indirect, or you bake lighting into albedo) |
| Roughness | `Roughness` | Non-Color target |
| Metalness | No dedicated type | Temporarily route the metallic value into an Emission shader (Emission strength 1), bake `Emit`, restore |
| Emissive mask | `Emit` | Feed the mask into Emission colour |
| Normal | `Normal` | Space Tangent, swizzle +X +Y +Z (Blender's default is the OpenGL convention Roblox wants) |
| AO | `Ambient Occlusion` | More samples; multiply into albedo (lightly) since Roblox has no AO slot |

There is no AO map slot on SurfaceAppearance. Either multiply AO into the colour map at low strength (dark crevices that will not move), or bake it into roughness (crevices rougher) or skip it. Over-strong baked AO looks dirty under Roblox's own ambient occlusion and shadows (rule of thumb).

### Cage and extrusion

When baking from a high-poly onto a low-poly, Blender casts a ray from each low-poly texel toward the high-poly. Where the rays start matters:

- **Extrusion** pushes the ray start outward along the low-poly normals by a distance. Too small: rays start inside the high-poly and miss (black or flat patches). Too large: rays hit the wrong part (a finger bakes onto the neighbouring finger).
- **Cage** is a duplicate of the low-poly, inflated by hand, used as the ray start surface. Use a cage when a single extrusion distance cannot work everywhere (a weapon with a thin blade and a thick pommel). The cage must have **identical topology and vertex order** to the low-poly; duplicate the low-poly, then push vertices along normals (`Alt+S` in Edit Mode) and fix problem areas.
- **Max Ray Distance** caps how far a ray may travel. Set it a little larger than the extrusion so rays do not hit geometry across the model.

Rule of thumb for Roblox-scale assets (1 Blender unit = 1 stud): start extrusion at 0.02 to 0.05 studs for weapons and props, 0.05 to 0.1 for characters, then look at the result and adjust.

### A scripted self-bake

The reference project generated most textures procedurally in background Blender. This is the shape of such a script (correct for Blender 4.x; adapt names):

```python
import bpy

def bake_map(obj, bake_type, size=1024, non_color=True, path="//tex.png",
             pass_filter=None):
    """Bake one map of obj's own material into a new image and save it."""
    scn = bpy.context.scene
    scn.render.engine = 'CYCLES'
    scn.cycles.samples = 32

    img = bpy.data.images.new(f"{obj.name}_{bake_type}", size, size, alpha=False)
    img.colorspace_settings.name = 'Non-Color' if non_color else 'sRGB'

    # Add an image node to every material slot and make it active (bake target).
    for slot in obj.material_slots:
        nt = slot.material.node_tree
        node = nt.nodes.new('ShaderNodeTexImage')
        node.image = img
        for n in nt.nodes:
            n.select = False
        node.select = True
        nt.nodes.active = node

    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    kwargs = dict(type=bake_type, margin=16, margin_type='EXTEND', use_clear=True)
    if pass_filter:
        kwargs['pass_filter'] = pass_filter
    bpy.ops.object.bake(**kwargs)

    img.filepath_raw = bpy.path.abspath(path)
    img.file_format = 'PNG'
    img.save()
    return img

obj = bpy.data.objects["Crate"]
bake_map(obj, 'DIFFUSE', non_color=False, path="//Crate_Color.png",
         pass_filter={'COLOR'})
bake_map(obj, 'ROUGHNESS', path="//Crate_Roughness.png")
```

Run it headless with `blender -b file.blend --python bake.py`. See [[Blender Automation with Python]] for batching.

### Baking VFX textures (the reference project's method)

The reference project's ability VFX meshes (rings, swirls, crescents, bursts) used SurfaceAppearance textures baked from a small node graph in the style of a popular stylised VFX approach: a **grayscale gradient along the mesh's UV multiplied by noise (fBm or Voronoi), then thresholded** into an alpha erosion that makes wispy edges. Each mesh got:

- `ColorMap` with alpha from that erosion, `AlphaMode` `Transparency`;
- `EmissiveMaskContent` = the same grayscale, `EmissiveStrength` 4;
- tint from `Part.Color` mirrored into the SurfaceAppearance (snippet above);
- fading still driven by tweening `Part.Transparency`.

A later toon variant went further: UV gradient, then noise, then a **constant (stepped) colour ramp with four tones**, then an alpha threshold, baked as four erosion frames per piece and packed into 4 x 4 flipbooks for particle sprites. Because the gradient runs along U, the UV layout is the design (see [[UV Unwrapping]]). For how these play in effects, see [[VFX Design Playbook]] and [[Particle Emitters In Depth]].

Why bake rather than generate in engine: Roblox has no custom shaders. Anything procedural must become a texture (or vertex colours) before upload.

## 5. What a texture set costs

Each SurfaceAppearance can reference five textures. Rules of thumb for memory (Roblox's exact GPU formats are not documented):

| Size | Uncompressed RGBA | With mips (+33%) | Block-compressed (about 4:1) |
|---|---|---|---|
| 512 | 1 MB | 1.3 MB | about 0.35 MB |
| 1024 | 4 MB | 5.3 MB | about 1.3 MB |
| 2048 | 16 MB | 21 MB | about 5.3 MB |

A full 1024 set (colour, normal, roughness, metalness, emissive) is several megabytes on device. Fifty unique hero props at 1024 each is a phone-crashing budget. That is why shared trim sheets and atlases ([[Trim Sheets Atlases and Vertex Colors]]) and built-in materials matter. Measure in the Developer Console's memory view (see [[Developer Console and Stats]] and [[Textures Decals and Texture Memory]]).

Cost-saving rules:

- **Skip maps that carry no information.** A fully non-metal prop does not need a metalness map; a flat-normal stylised prop does not need a normal map.
- **Pack density, not maps.** Since Roblox expects separate grayscale files, you cannot pack roughness and metalness into channels of one image as in other engines.
- **Size per map.** Roughness and metalness can often be half the colour map's resolution with no visible loss (rule of thumb).
- **Share.** Twenty crates using one 1024 set cost one set.

## 6. Checking the result in Studio

1. Import the mesh and textures, or upload textures separately (`.png`, `.jpg`, `.tga`, `.bmp`; docs) and assign them.
2. Look under at least two lighting presets, at near and far distance, and on a low graphics quality level (Studio's graphics quality can be lowered in the Studio settings to approximate low-end clients).
3. Compare with a reference: a chrome sphere and a grey plastic sphere next to the asset.

| Symptom | Likely cause |
|---|---|
| Everything looks glossy and wet | Roughness saved through an sRGB conversion, or roughness and metalness swapped |
| Metal looks black | Metal albedo too dark; or no reflections in a dim zone (metals need environment to reflect) |
| Lighting baked into the colour (shadow under a ledge that stays when lights move) | Diffuse bake with Direct/Indirect ticked |
| Inverted bumps | DirectX-convention normal map; see [[Normal Maps and Detail Baking]] |
| Black or flat patches on a selected-to-active bake | Extrusion too small, rays started inside the high-poly |
| Untinted trim turned black under TintMask | Zero RGB under zero alpha (premultiplied or cleared) |
| Soft alpha fade renders as a hard edge | Transparency mode with `MeshPart.Transparency` 0; set at least 0.02 |
| Script cannot set `ColorMap` | Plugin security; swap instances instead |

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Baking colour with lighting contributions | Fixed shadows in albedo | Color only |
| Data maps in sRGB | Wrong roughness and metal values | Non-Color everywhere |
| Image node not active before bake | Empty image or baked into the wrong image | Select and activate the node in each material |
| Forgetting to save baked images | Lost on close | Save each image |
| Mid-grey metalness everywhere | Dirty plastic look | 0 or 1, transitions only at edges |
| Saturated colour map under TintMask | Muddy hue shifts | Near-white grayscale tinted regions |
| Five 2048 maps on a small prop | Memory with no visible gain | Size to texel density |

## Checklist

- [ ] Metalness workflow; spec/gloss converted.
- [ ] Colour map sRGB, all other maps Non-Color, verified pixel values.
- [ ] Metalness binary except transitions; dielectric albedo within range.
- [ ] Normal map OpenGL, tangent space.
- [ ] Bake padding set; images saved.
- [ ] AlphaMode chosen deliberately; Transparency parts at 0.02 or more where alpha is soft.
- [ ] Emissive strength within 0 to 40 if the item goes to the Marketplace.
- [ ] Checked in Studio under every lighting setup the asset will live in.

## See also

[[UV Unwrapping]] · [[Normal Maps and Detail Baking]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Hand-Painted and Stylized Texturing]] · [[Substance Painter and Texturing Tools]] · [[Exporting and Validating Models for Roblox]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Textures Decals and Texture Memory]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[VFX Design Playbook]] · [[Blender Automation with Python]] · [[AI Material and Texture Generation]] · [[Art Pipeline - Concept to In-Game Asset]]

## Connected notes
<!-- auto-links:start -->
[[SurfaceAppearance PBR Workflow]] · Baking Lighting and Detail into Textures · Stylised vs Realistic Material Pipelines · Materials and Surfaces Start Here · Flat Colour vs Gradient Atlas vs Vertex Colour · Voxel Shading - Baked AO Edges and Lighting
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Baking Lighting and Detail into Textures]] · [[Stylised vs Realistic Material Pipelines]] · [[Mesh Optimization for Mobile]] · [[Low-Poly and Stylized Modeling]] · [[Hard-Surface Modeling]] · [[Voxel and Blocky Modeling]] · [[Modeling Fundamentals for Games]] · [[Blender Workflow for Roblox Creators]]
<!-- related:end -->
