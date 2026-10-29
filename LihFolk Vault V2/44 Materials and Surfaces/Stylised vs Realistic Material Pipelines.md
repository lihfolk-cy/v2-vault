---
tags: [materials, art-direction, pipeline, stylized, realistic, pbr, production]
---
# Stylised vs Realistic Material Pipelines

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Direction set by the first imported asset -> Write the pipeline down before importing
> - Avoid: Realistic metal with environment specular 0 -> Configure environment lighting
> - Avoid: Realistic scene judged on desktop only -> Test on low-end devices early
> - Pipeline chosen and written down: flat, stylised PBR or realistic, with the reason.
> - Maps per asset class, texel density band and metal rules defined.
> - Lighting settings (style, ambient, environment scales) part of the material spec.
>
> Cost: TL;DR ~170 tok · whole note ~4.2k tok. Read more: ## 2. What realism costs on Roblox specifically · ## 5. Turning realistic CC0 sets into stylised materials · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Every Roblox project picks a material pipeline, usually by accident: the first asset someone imports sets the direction, and six months later the game has photoscanned cobbles next to SmoothPlastic trees. [[Environment Art Styles]] covers style families and palettes, and [[Hand-Painted and Stylized Texturing]] covers how to paint stylised textures. This note compares the **whole material pipelines** end to end: what each costs to produce and to run, what lighting each needs, how they behave on phones, how to convert the vault's realistic CC0 sets into stylised ones, the hybrid that most successful games actually ship, and how to switch direction mid-project without redoing everything.

## 1. Three pipelines, not two

| | Flat stylised | Stylised PBR (hybrid) | Realistic PBR |
|---|---|---|---|
| Surface source | `Color` on SmoothPlastic/Plastic, palette atlases, vertex colour | Painted or simplified colour maps, chunky normals, high roughness | Photo-based or scanned sets, full map sets |
| Maps per asset | 0 to 1 | 1 to 3 (colour, normal, maybe roughness) | 3 to 4 (colour, normal, roughness, metalness) |
| Typical texel density | None or very low | 32 to 64 px per stud | 64 to 128 px per stud |
| Custom materials | Few or none | A small library of simplified variants | Large library, terrain details per face |
| Lighting dependence | Low: colour carries the read | Medium | High: needs good environment light and reflections |
| Look on low-end phones | Almost identical to desktop | Close | Noticeably flatter |
| Fits Roblox avatars | Naturally | Well | Clashes unless avatars are restricted |
| Production speed | Fastest | Medium | Slowest per asset; fastest if you only reuse a library |
| Typical genres | Simulators, tycoons, obbies, hangouts | Adventure, combat RPGs, tower defense, most "polished" games | Horror, military shooters, showcase builds |

The sections below are about choosing between these and running each well. The verdict up front: **most games should pick stylised PBR, run it with a small strict library, and keep flat stylised as the cheap tier inside it.** Realistic PBR is right only when the game's whole pitch depends on it.

## 2. What realism costs on Roblox specifically

Realism is not just more pixels. Roblox makes it harder in ways other engines do not:

- **Avatars are stylised.** Blocky and proportioned characters in a photoreal world look like toys in a diorama. Realistic games often restrict avatar types or scales, which is a design and audience decision, not an art one.
- **No custom shaders, no lightmaps, no screen-space reflections you control.** Realism comes from map quality and the engine's lighting only. You cannot fix a material with a shader tweak.
- **Environment lighting must be configured.** `EnvironmentSpecularScale` and `EnvironmentDiffuseScale` default to 0 (Roblox docs, as of October 2026). The docs call environment specular especially important for metal; at 0, metalness has no effect at all. A realistic pipeline that forgets this ships plastic-looking metal.
- **Lighting quality varies by device.** `ShadowSoftness` only works with ShadowMap or Future technology on devices that can render shadow maps, and quality scales down on weaker hardware (Roblox docs). Realistic materials lose more of their look when lighting degrades than stylised ones do.
- **Memory multiplies.** Four maps at 1024 for every unique asset is the expensive end of [[Textures Decals and Texture Memory]]. A realistic scene with 40 unique hero props is a phone-memory problem before it is a draw-call problem.

None of this forbids realism. It means a realistic Roblox game is mostly a **library-reuse discipline**: a fixed set of high-quality tiling materials and trim sheets used everywhere, few unique assets, and tight control of lighting.

## 3. What stylised costs

Stylised is not free either:

- **Consistency is harder than fidelity.** A photo texture looks "right" automatically; a painted texture only looks right next to other paintings by the same rules. Style guides, palette rules and review time are the cost ([[Environment Art Styles]]).
- **Roblox has no unlit shading.** Painted light gets lit again ([[Hand-Painted and Stylized Texturing]]). Stylised pipelines must decide how much light lives in textures and how much in the engine ([[Baking Lighting and Detail into Textures]]).
- **Flat colour can look cheap.** SmoothPlastic everywhere with default lighting is the "free model" look. Stylised games that look premium invest in lighting, gradients and shape language, not in texture count.

## 4. Pipeline steps side by side

| Step | Flat stylised | Stylised PBR | Realistic PBR |
|---|---|---|---|
| Concept | Palette and shape sheet | Palette, shape sheet, material swatches painted at target scale | Reference photos, material reference boards |
| Source material | Hex palette | Simplified CC0 or painted tiles; painted trim sheets | CC0 scans, Substance materials |
| Modelling | Low poly, bevels for silhouette | Low to mid poly, chunky bevels, normals from high-poly where it pays | Mid poly, baked normals from high-poly |
| UVs | Palette islands or none | Trim sheets, shared atlases | Unique UVs for hero assets, trims for kits |
| Texturing | Colour per face or vertex | Gradient and curvature bakes plus paint; colour, normal, sometimes roughness | Full PBR set per asset, wear passes |
| Roblox setup | `Color` and material; no SurfaceAppearance on most meshes | SurfaceAppearance templates; MaterialVariants with Organic patterns | SurfaceAppearance and MaterialVariant libraries; terrain details per face |
| Lighting | Soft style, bright ambient, mild bloom | Either style; environment diffuse moderate | Realistic style, environment specular and diffuse tuned, atmosphere |
| QA | Grayscale and colour-blind checks | Plus neighbour test for style match | Plus look-dev room per lighting preset ([[SurfaceAppearance PBR Workflow]]) |

## 5. Turning realistic CC0 sets into stylised materials

The vault ships 869 realistic PBR sets ([[CC0 Texture and HDRI Library]]). A stylised project can still use them as a starting point. The conversion is about removing information, not adding it:

1. **Simplify colour.** Reduce colour variation: blur at a radius of a few pixels, then posterize to 4 to 8 value bands per hue, then shift the palette towards your style's hues.
2. **Lower normal intensity.** Scale the normal map towards flat (127, 127, 255) by 40 to 70 percent so small pores disappear and only large forms (stones, planks) remain.
3. **Flatten roughness.** Replace the roughness map with a near-constant high value (0.7 to 0.9), or drop it and leave the slot blank.
4. **Scale up.** Raise `StudsPerTile` 1.5 to 2 times so features are big enough to read at avatar scale on a phone.
5. **Remove unique features** that repeat visibly ([[Tiling Trim Sheets and Decal Tricks]]).

Steps 1 and 2 can be scripted in Blender's Python with numpy, so a whole library converts in one batch run ([[Blender Automation with Python]]):

```python
import bpy
import numpy as np

def load_rgba(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return img, px.reshape(h, w, 4)

def save_rgba(arr, w, h, path, name):
    out = bpy.data.images.new(name, w, h, alpha=True)
    out.pixels.foreach_set(arr.ravel())
    out.filepath_raw = path
    out.file_format = 'PNG'
    out.save()

def box_blur(rgb, r):
    """Cheap separable box blur with wrap-around, so tiling is preserved."""
    out = rgb.copy()
    for axis in (0, 1):
        acc = np.zeros_like(out)
        for k in range(-r, r + 1):
            acc += np.roll(out, k, axis=axis)
        out = acc / (2 * r + 1)
    return out

def stylise_color(src, dst, bands=6, blur=2, saturation=1.15):
    img, px = load_rgba(src)
    h, w = px.shape[0], px.shape[1]
    rgb = box_blur(px[:, :, :3], blur)
    # Posterize value while keeping hue: quantise luminance, rescale colour.
    lum = (rgb * np.array([0.2126, 0.7152, 0.0722])).sum(axis=2, keepdims=True)
    q = np.round(lum * bands) / bands
    rgb = rgb * (q / np.maximum(lum, 1e-4))
    # Mild saturation boost around the luminance.
    rgb = q + (rgb - q) * saturation
    px[:, :, :3] = np.clip(rgb, 0.0, 1.0)
    save_rgba(px, w, h, dst, "stylised_color")

def soften_normal(src, dst, keep=0.4):
    img, px = load_rgba(src)
    h, w = px.shape[0], px.shape[1]
    flat = np.array([0.5, 0.5, 1.0], dtype=np.float32)
    n = px[:, :, :3] * 2.0 - 1.0
    n[:, :, 0:2] *= keep            # shrink the slope components
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    px[:, :, :3] = n * 0.5 + 0.5
    save_rgba(px, w, h, dst, "soft_normal")

stylise_color("//cobblestone_floor_01_diff_2k.jpg", "//CobbleStylised_Color.png")
soften_normal("//cobblestone_floor_01_nor_gl_2k.jpg", "//CobbleStylised_Normal.png")
```

Notes on the script:

- `np.roll` wraps around the edges, so the blurred result **still tiles**. A normal blur would break the seams the CC0 set came with.
- The normal map is processed as vectors, not colours. Scaling X and Y and renormalising keeps it valid; blending the image towards flat blue in colour space does not.
- Normal map images should be loaded as Non-Color data in Blender for exact values. If you load them as sRGB, set the image's `colorspace_settings.name = 'Non-Color'` after loading ([[Texturing and PBR Baking]] explains why).
- The box blur loops are slow on 2K images in pure numpy (a few seconds each); fine for a batch, not for interactive use.

Judge results in Studio next to your hand-made assets, not in Blender. Converted sets tend to stay a little too busy; a second pass of blur or fewer bands usually helps.

## 6. The hybrid that ships: rules for stylised PBR

Stylised PBR works when its rules are explicit and few. A rule set that holds up in production (rule of thumb, refined from several stylised projects and the reference project's armour and VFX work):

1. **Colour carries identity; normals carry form; roughness is mostly constant.** One varying map is enough for most props.
2. **One texel density band** for everything the camera sees at play distance: for example 48 px per stud, with hero assets allowed 64.
3. **Metal is rare and deliberate.** Gold and steel accents only; everything else metalness 0. Set environment specular high enough that the few metals actually shine.
4. **Large shapes, few details.** No feature smaller than about 0.25 studs in a texture; it disappears on a phone.
5. **Shared everything.** Trim sheets for kits, a material library of 15 to 30 variants for the whole game, templates for every SurfaceAppearance ([[MaterialService and Custom Materials]], [[SurfaceAppearance PBR Workflow]]).
6. **Flat stylised is the cheap tier inside the hybrid.** Background props, distant buildings and filler use `Color` only. Viewers do not notice the absence of textures at distance; they do notice memory-related hitches.
7. **Lighting is part of the material spec.** Write down `LightingStyle`, ambient values and environment scales next to the material rules ([[Stylized Lighting Recipes]]).

## 7. Mixing pipelines on purpose

Mixing is not always wrong; mixing by accident is. Deliberate mixes that work:

| Mix | Why it works |
|---|---|
| Realistic terrain and rock, stylised characters and props | Ground is background; players focus on stylised foreground |
| Stylised world, realistic lighting style | Lighting quality reads as polish without forcing texture realism |
| Flat stylised hub, stylised PBR adventure zones | Different spaces, different jobs; the hub stays cheap for fast joins |
| Realistic horror interiors, stylised UI and VFX | UI and VFX are read as a separate layer |

Mixes that fail: photo textures on one prop in a painted room; realistic metal on a flat-coloured character; one zone in a different texel density from its neighbour so the border looks like a seam. The neighbour test from [[Baking Lighting and Detail into Textures]] catches these.

## 8. Changing direction mid-project

Projects do change direction, most often from accidental-realistic to deliberate-stylised. Because of how Roblox resolves materials, some changes are cheap:

| Layer | Cost to change | How |
|---|---|---|
| MaterialVariants | Low | Same names, new maps: the adaptive-materials theme swap restyles every part at once ([[MaterialService and Custom Materials]]) |
| Terrain | Low to medium | Swap override variants; repaint pass by script ([[Terrain Materials and Painting]]) |
| SurfaceAppearance templates | Medium | Update templates, re-clone to users with a script ([[SurfaceAppearance PBR Workflow]]) |
| Trim sheets | Medium | Repaint the sheet; every mesh using it updates |
| Unique hero textures | High | Each one repainted |
| Meshes and silhouettes | Highest | Remodel; stylised shapes differ from realistic ones |

The lesson for new projects: **route as much of the look as possible through shared layers** (variants, templates, trims) because those are the layers you can change in an afternoon. A game built from 400 unique texture sets is locked into its first style.

## 9. Deciding

Answer these in order; the first strong answer usually decides:

1. **Is realism the pitch?** (Horror that depends on dread, a military sim, an architectural showcase.) If yes, realistic PBR with strict library reuse. If no, continue.
2. **What share of players are on phones?** For most Roblox games it is the majority. If it is high, avoid realistic as the base.
3. **How many artists, and how consistent are they?** One artist can hold a hand-painted style; four artists need trim sheets, a variant library and written rules, which favours stylised PBR.
4. **How much unique content per update?** Live games that ship new zones monthly need a pipeline where a new zone is mostly reuse plus a few hero assets.
5. **Does the genre have a visual convention?** Simulators, tycoons and obbies read as flat or stylised; fighting that convention costs discoverability ([[Thumbnails Icons and Store Page]]).

## When not to agonise

- **Prototypes.** Use built-in materials and colour. Pick the pipeline when the core loop is fun.
- **Game jams.** Flat stylised wins every time.
- **When an existing library decides it.** If your team already has a polished stylised variant library, that is your pipeline.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Direction set by the first imported asset | Mixed styles, "asset flip" look | Write the pipeline down before importing |
| Realistic metal with environment specular 0 | Metal looks like grey plastic | Configure environment lighting |
| Realistic scene judged on desktop only | Flat, muddy on phones | Test on low-end devices early |
| Stylised textures with photo-level detail | Noise on phones, style breaks | Remove detail below 0.25 studs |
| Unique textures everywhere | Locked into the first style; high memory | Shared variants, templates and trims |
| Converted CC0 sets that no longer tile | Seams after blur | Wrap-around filters only |

## Checklist

- [ ] Pipeline chosen and written down: flat, stylised PBR or realistic, with the reason.
- [ ] Maps per asset class, texel density band and metal rules defined.
- [ ] Lighting settings (style, ambient, environment scales) part of the material spec.
- [ ] Material library size target set (for example 15 to 30 variants).
- [ ] CC0 conversions keep tiling; judged in Studio beside hand-made assets.
- [ ] Deliberate mixes listed; neighbour test done at every zone border.
- [ ] Look routed through shared layers so a direction change stays affordable.

## See also

[[Materials and Surfaces Start Here]] · [[Environment Art Styles]] · [[Hand-Painted and Stylized Texturing]] · [[Low-Poly and Stylized Modeling]] · [[Baking Lighting and Detail into Textures]] · [[MaterialService and Custom Materials]] · [[SurfaceAppearance PBR Workflow]] · [[Terrain Materials and Painting]] · [[Tiling Trim Sheets and Decal Tricks]] · [[CC0 Texture and HDRI Library]] · [[Stylized Lighting Recipes]] · [[Lighting Technologies and Settings]] · [[Mobile and Low-End Optimization]] · [[Art Pipeline - Concept to In-Game Asset]]

## Connected notes
<!-- auto-links:start -->
[[AI Material and Texture Generation]] · [[Texel Density]] · [[Substance Painter and Texturing Tools]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Untextured Stylised Modelling Start Here]] · [[Bevels Chamfers and Edge Highlights Without Textures]]
<!-- auto-links:end -->
