---
tags: [materials, baking, lighting, ambient-occlusion, blender, textures, stylized, optimization]
---
# Baking Lighting and Detail into Textures

The Roblox PBR guide says the colour map "shouldn't contain baked-in lighting or shading" (Roblox docs, as of October 2026), and [[Texturing and PBR Baking]] teaches the correct default: bake colour with **Color only** so real lights do the lighting. This note is about the deliberate exceptions. Roblox gives you no lightmaps, no custom shaders, no AO slot and, on many phones, coarse lighting. So almost every good-looking Roblox game bakes *something* into its textures or vertices: ambient occlusion, edge wear, gradients, contact shadows, sometimes whole rooms of light. The skill is knowing which kinds of baked light survive a dynamic engine and which ones break the moment a player turns around.

## 1. What survives and what breaks

The test for any baked detail: **does it stay correct if the object rotates, the sun moves, or a light switches off?**

| Baked into the texture | Survives rotation | Survives time of day | Verdict |
|---|---|---|---|
| Ambient occlusion (crevices, corners) | Yes | Yes, mostly | Safe at moderate strength |
| Cavity and edge wear (curvature) | Yes | Yes | Safe; the core of stylised looks |
| Height gradient (darker at the base, lighter at the top) | Yes, if the object stays upright | Yes | Safe for static props and buildings |
| Contact shadows under fixed objects | Yes, if both objects stay put | Mostly | Safe for static scenes |
| Bounce light (indirect only) | Yes, for static geometry | Partly: colour may disagree at night | Good for fixed interiors |
| Directional sunlight and cast shadows | No | No | Avoid, except in fully controlled scenes |
| Specular highlights | No | No | Never; the engine draws its own |

[[Hand-Painted and Stylized Texturing]] makes the same point for painted art: painted AO is fine, painted directional light is fragile. This note is about doing it with bakes, at scale, and measuring the result.

## 2. Why Roblox needs baked detail more than most engines

Facts from the docs (as of October 2026) that explain the gap baking fills:

- **Coarse lighting on some paths.** The `Technology` enum describes Voxel lighting as using "a 4x4x4 voxel map for light and shadow calculation", and the `Lighting` reference says `GlobalShadows` is voxel-based. Light at that resolution cannot darken a 0.3-stud crevice in a crate. Only a texture can.
- **Lighting is chosen per place, not per object.** `Lighting.Technology` is deprecated and superseded by `LightingStyle` (`Realistic` or `Soft`) plus `PrioritizeLightingQuality`. `ShadowSoftness` only applies with ShadowMap or Future and when "the device can render shadow maps". What you see in Studio on a desktop is not what a phone draws; baked detail is the part of the look that is identical on every device.
- **No ambient occlusion map slot.** SurfaceAppearance has colour, normal, roughness, metalness and an emissive mask. AO has to go into one of those.
- **Environment lighting defaults to off.** `EnvironmentDiffuseScale` and `EnvironmentSpecularScale` both default to 0. Without environment diffuse, shadowed areas are lit by flat `Ambient`/`OutdoorAmbient`, which flattens form. Baked AO restores the form.

Nuance: as lighting quality rises (Realistic style on a strong desktop), baked AO starts to double up with the engine's own shading. That is why strength matters more than technique (section 3).

## 3. Ambient occlusion into the colour map

### Strength

Multiplying full-strength AO into albedo makes assets look dirty under good lighting and fine under poor lighting. The answer is a moderate blend:

`colour_out = colour_in * lerp(1, ao, strength)`

| Target | Strength (rule of thumb) |
|---|---|
| Realistic PBR game, Realistic lighting | 0.2 to 0.35 |
| Mixed, many phone players | 0.35 to 0.5 |
| Stylised, Soft lighting or flat ambient | 0.5 to 0.8 |
| Small props seen from far (rocks, crates) | Upper end of the band |
| Large architecture | Lower end; large-scale AO looks like dirt stains |

Two refinements that help a lot:

- **Clamp the floor.** Never let AO push a texel below about 40 to 50 percent of its original value. Fully black crevices read as holes.
- **Tint the occlusion.** Real occluded areas pick up the colour of nearby surfaces and sky. Multiplying by a slightly warm or cool grey (for example RGB 0.85, 0.82, 0.9 at full occlusion) looks richer than pure darkening.

### Using the CC0 AO maps

Most texture sets in [[CC0 Texture and HDRI Library]] include `_ao_2k.jpg`, and the `_arm_2k.jpg` file packs AO in its red channel. Roblox ignores both, so combine them into the colour map before upload. For tiling MaterialVariants keep strength low (0.2 to 0.3): tiled AO repeats with the tile and becomes part of the pattern you are trying to hide.

### A Blender script for the composite

Blender ships with numpy, so the composite can run headless in the same pipeline that bakes ([[Blender Automation with Python]]).

```python
import bpy
import numpy as np

def bake_ao_into_color(color_path, ao_path, out_path, strength=0.4,
                       floor=0.5, tint=(0.88, 0.85, 0.92)):
    """colour * lerp(1, tinted_ao, strength), with a minimum brightness floor."""
    col = bpy.data.images.load(color_path)
    ao = bpy.data.images.load(ao_path)
    if tuple(col.size) != tuple(ao.size):
        ao.scale(col.size[0], col.size[1])

    w, h = col.size
    c = np.empty(w * h * 4, dtype=np.float32)
    a = np.empty(w * h * 4, dtype=np.float32)
    col.pixels.foreach_get(c)
    ao.pixels.foreach_get(a)
    c = c.reshape(h, w, 4)
    a = a.reshape(h, w, 4)[:, :, 0:1]  # AO is grayscale; use red

    t = np.array(tint, dtype=np.float32).reshape(1, 1, 3)
    # Tinted occlusion: 1 where open (ao = 1), 0 where fully occluded,
    # and shifted towards the tint colour in between.
    tinted = t * a + (1.0 - t * a) * a
    factor = 1.0 + (tinted - 1.0) * strength
    factor = np.maximum(factor, floor)

    c[:, :, 0:3] *= factor
    out = bpy.data.images.new("ao_composite", w, h, alpha=True)
    out.pixels.foreach_set(c.ravel())
    out.filepath_raw = out_path
    out.file_format = 'PNG'
    out.save()

bake_ao_into_color("//mossy_rock_diff_2k.jpg", "//mossy_rock_ao_2k.jpg",
                   "//mossy_rock_color_ao.png", strength=0.3)
```

A precision note: for 8-bit images Blender's `pixels` array holds the stored (sRGB-encoded) values, so this multiplies in encoded space. That darkens slightly more than a linear-space multiply would. At the strengths above the difference is small; if you need exactness, convert to linear, multiply, and convert back.

## 4. Gradients and curvature: the stylised workhorses

Two cheap bakes give most of the "authored" look in stylised games:

1. **Height gradient.** Bake a gradient from the object's base (darker, slightly cooler) to its top (lighter, slightly warmer) into the colour map or vertex colours. Rocks, trees, buildings and characters all read as lit from above without depending on the engine's light. In Blender, feed a Gradient Texture driven by object-space Z into an Emission shader and bake `EMIT`; [[Texturing and PBR Baking]] shows the self-bake pattern.
2. **Curvature (edge wear).** Lighter, less saturated convex edges and darker concave ones. Bake a pointiness or geometry-based curvature mask, threshold it, and lighten convex edges by 10 to 20 percent. This is what makes chunky stylised props look carved instead of plastic.

Both survive rotation (for upright objects) and every time of day, which is why they are the safe default for [[Low-Poly and Stylized Modeling]].

## 5. Baking into vertex colours instead

For low-poly meshes, vertex colours can carry AO and gradients at zero texture memory. Blender can bake straight into a colour attribute: set the bake **Target** to **Color Attributes** (Render Properties, Bake, Output; Python `scene.render.bake.target = 'VERTEX_COLORS'`) and bake AO or Emit as usual.

When this is the right call:

| Good fit | Poor fit |
|---|---|
| Meshes with enough vertices where the shading changes (corners, bevels) | Large flat quads (one value per corner, nothing in between) |
| Voxel and blocky art | High-frequency detail |
| Kits that already share one palette texture | Meshes that need different AO per instance |

Remember the measured trap from [[Trim Sheets Atlases and Vertex Colors]]: vertex colours multiply with `Color`, and noisy vertex colour on big surfaces shows triangle structure. Keep vertex AO soft and low-contrast.

## 6. Full lighting bakes: when and how

Sometimes you control everything: a lobby room, a menu diorama, a shop interior, a horror corridor with a fixed lamp, a cutscene set. There, a full bake can look far better than the engine's real-time light, especially on phones.

### The cost model

A lighting bake needs **unique UVs**: every surface must own its own texels, so nothing can tile and nothing can be shared. A 40 x 40-stud room at 32 px per stud is 1280 x 1280 texels of floor alone. Full lighting bakes are a memory decision before they are an art decision ([[Textures Decals and Texture Memory]]).

Rule of thumb budget: one bake atlas per room at 1024, maybe two for a hero room. If a scene needs more than that, it should not be fully baked.

### Bake indirect, let Roblox draw direct

The most robust hybrid: bake **only the indirect (bounce) light** into the colour map, and let Roblox draw the direct sun and lamps with real shadows. In Blender, a `DIFFUSE` bake with the Indirect and Color contributions ticked and Direct unticked gives "albedo lit by bounce light". The room keeps its soft, colour-bled look; the engine's direct light still moves correctly with day-night cycles and flickering lamps.

### Fully baked, "unlit" scenes

When even direct light is fixed, bake `COMBINED` or `DIFFUSE` with all contributions and make the surface ignore the engine as much as possible:

- Colour map = the full bake.
- Roughness map flat near 1, no metalness, so the engine's specular does not add highlights on top.
- Emissive mask = uniform white with a low `EmissiveStrength` so the surface keeps its baked brightness even where Roblox thinks it is dark. Tune by eye against the room's real lights; too much emission flattens everything ([[Hand-Painted and Stylized Texturing]] lists this "emissive as unlit" trick with its trade-offs).
- Turn off real lights inside the room, or keep one very soft fill so dynamic objects (avatars) are not pitch black.

The catch is avatars and anything that moves: they are lit by the engine, not by your bake. A baked warm lamp glow on the walls with a cold, flat-lit avatar in the middle looks wrong. Add a real `PointLight` that matches the baked lamp's colour and position so dynamic objects agree with the bake ([[Light Sources and Shadows]]).

### Match the bake environment to the game sky

If the bake uses Blender's default grey world, bounce light will be neutral grey while the Roblox sky is blue and warm. Use the same HDRI for the Blender world that you convert into the game's `Sky` (the vault's 997 HDRIs are in [[CC0 Texture and HDRI Library]]). Baked bounce colour then agrees with the sky the player sees.

## 7. Consolidation bakes: many materials into one set

A different kind of baking with a performance goal: a Blender prop with six materials becomes six submeshes or six draw calls when imported. Baking all six into one texture set on a single new UV layout turns it into one MeshPart with one SurfaceAppearance.

Steps (Blender 4.x):

1. Duplicate the object; on the copy, add a new UV map and **Smart UV Project** or unwrap it into one atlas layout. Make that UV map active for baking.
2. Give the copy one material with an empty image node selected (the bake target).
3. Bake **Selected to Active** from the original (all six materials) to the copy: colour with Color only, roughness, normal as needed.
4. Delete the old UV map on the copy (keep the atlas layout as the only UV set), export, import.

Result: fewer draw calls and one template to share ([[SurfaceAppearance PBR Workflow]]). The cost: you lose tiling detail where a material used to tile at high density; the atlas texel density decides how sharp the result is. Bake at 2x the final size and downscale for cleaner edges (rule of thumb).

## 8. Fake contact shadows for things that move

Dynamic objects (pets, vehicles, dropped loot) on Soft lighting or low-end devices often float because there is no visible contact shadow. A **blob shadow**: a soft dark radial gradient on a small transparent host under the object, raycast down to the ground each frame (or at a lower rate for many objects). It is a baked shadow that moves with its owner. Keep it on the client, fade it with height, and skip it when the device draws real shadows if you can detect that reliably (in practice, most games just keep the blob subtle enough to look fine either way). Pool hosts the same way as impact decals in [[Tiling Trim Sheets and Decal Tricks]].

## 9. Verifying a bake in Studio

Run every baked asset through four checks:

1. **Rotate test.** Spin it 90 and 180 degrees. Anything that now looks lit from the wrong side is baked directional light.
2. **Time-of-day test.** Run your day-night presets ([[Stylized Lighting Recipes]]). At night, baked bright sides glow; at noon, baked dark sides look dirty.
3. **Grayscale test.** Screenshot, convert to grayscale. AO should read as form, not as stains.
4. **Neighbour test.** Place it next to an unbaked asset of the same style. If one looks like it belongs to another game, adjust strength until they match ([[Stylised vs Realistic Material Pipelines]]).

## When not to bake lighting

- **Objects that move or rotate freely** (tools, held weapons, physics props): only AO and curvature, never directional light.
- **Tiling materials on large surfaces**: baked AO repeats with the tile; keep it faint.
- **Scenes whose lighting changes** (day-night, flickering, destructible lights): bake only indirect or nothing.
- **When memory is tight**: a full room bake costs unique texels; a stylised room with SmoothPlastic and good lighting may look as good for no memory.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Full-strength AO in albedo | Dirty look under good lighting | 0.2 to 0.5 strength with a floor |
| Baking with Direct ticked for a dynamic scene | Shadows that disagree with the sun | Color only, or Indirect only |
| Grey Blender world for bounce | Neutral bounce under a blue sky | Same HDRI as the game sky |
| Lighting bake with tiling UVs | Light repeating across the floor | Unique UVs for lighting bakes |
| Fully baked room with dark avatars | Avatars look pasted in | Matching real lights for dynamic objects |
| Noisy AO bake at low samples | Speckled dirt | More samples (128 plus) or denoise |
| Strong AO on tiled CC0 materials | Grid of dark blotches | Faint AO or none on tiling variants |

## Checklist

- [ ] Each baked asset lists what was baked: AO, curvature, gradient, indirect, or full.
- [ ] AO strength chosen per target lighting with a minimum floor.
- [ ] Directional light baked only in fully controlled scenes.
- [ ] Lighting bakes use unique UVs and fit a per-room memory budget.
- [ ] Bake environment matches the game sky.
- [ ] Dynamic objects get real lights matching baked lamps.
- [ ] Rotate, time-of-day, grayscale and neighbour tests passed.

## See also

[[Materials and Surfaces Start Here]] · [[Texturing and PBR Baking]] · [[Normal Maps and Detail Baking]] · [[Hand-Painted and Stylized Texturing]] · [[Trim Sheets Atlases and Vertex Colors]] · [[CC0 Texture and HDRI Library]] · [[Lighting Technologies and Settings]] · [[Stylized Lighting Recipes]] · [[Light Sources and Shadows]] · [[Blender Automation with Python]] · [[SurfaceAppearance PBR Workflow]] · [[Stylised vs Realistic Material Pipelines]]

## Connected notes
<!-- auto-links:start -->
[[Lighting Untextured Art in Roblox]] · [[Voxel Shading - Baked AO Edges and Lighting]] · [[Bevels Chamfers and Edge Highlights Without Textures]] · [[Texel Density]] · [[Substance Painter and Texturing Tools]] · [[Untextured Stylised Modelling Start Here]]
<!-- auto-links:end -->
