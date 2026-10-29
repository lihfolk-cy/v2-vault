---
tags: [modeling, texturing, substance-painter, tools, export, pbr, type/guide, area/modeling, level/intermediate, api/SurfaceAppearance]
---
# Substance Painter and Texturing Tools

<!-- tldr:start -->
> [!tldr] TL;DR
> - Painter project: metallic-roughness, OpenGL normals, no UDIMs.
> - One texture set per Roblox MeshPart.
> - Export template with separate gray roughness and metalness, alpha matched to the intended `AlphaMode`.
> - Dilation padding on; PNG 8-bit; size by texel density.
> - Untinted RGB preserved under alpha 0 for TintMask.
> - Final judgement under Studio lighting, not in Painter's viewport.
>
> Cost: TL;DR ~140 tok · whole note ~3.3k tok. Read more: ## 3. Export presets for Roblox · ## 6. Alternatives · ## Checklist
<!-- tldr:end -->

Adobe Substance 3D Painter is the industry-standard tool for painting PBR textures on 3D meshes, and it is widely used for Roblox assets, UGC especially. It is also not required: Blender alone, free tools and procedural scripts can produce everything a `SurfaceAppearance` needs. This note covers setting Painter up correctly for Roblox (the settings that silently break assets), export presets and a custom template for every Roblox alpha mode, and how the alternatives compare. Roblox specs are from the Creator Hub, checked October 2026; product details are as of October 2026 and change often, so verify in your version.

Background: [[Texturing and PBR Baking]] (maps and colour spaces), [[Normal Maps and Detail Baking]] (conventions), [[UV Unwrapping]].

## 1. What Roblox needs from any texturing tool

Whatever tool you use, the output must be:

| Output | Format | Notes (Roblox docs unless marked) |
|---|---|---|
| Colour map | RGB 8-bit per channel, plus alpha if you use `Transparency` or `TintMask` | sRGB |
| Normal map | RGB, **OpenGL**, tangent space | Linear data |
| Roughness | Single-channel grayscale 8-bit | Separate file |
| Metalness | Single-channel grayscale 8-bit | Separate file |
| Emissive mask | Single-channel grayscale 8-bit | Optional |
| File type | `.png`, `.jpg`, `.tga` or `.bmp` | PNG recommended (lossless, alpha) (rule of thumb) |
| Size | Up to 4096 per the texture spec page, which also lists 1024 for UV maps; Marketplace items at most 2048 | Size by texel density, not by maximum |
| UVs | One set, 0 to 1 | Painter UDIMs are not usable |

Roblox does not use packed channel textures (ORM/ARM maps common in Unreal or glTF). That is the main change from other engine presets: roughness and metalness must be separate grayscale files.

## 2. Setting up a Painter project for Roblox

New project settings that matter:

| Setting | Value | Why |
|---|---|---|
| Template | A PBR metallic-roughness template | Roblox is metalness workflow only |
| Document resolution | Your target (1024 typical), can change later | Painter is resolution independent for procedural layers; painted strokes resample |
| **Normal map format** | **OpenGL** | Roblox supports only OpenGL tangent-space normals. Painter templates may default to DirectX; this is the setting most often missed |
| Compute tangent space per fragment | On (default) | Matches MikkTSpace-style bakes |
| Use UV tile workflow | Off | Roblox has one 0 to 1 UV set; no UDIMs |
| Import cameras / auto-unwrap | Off | Unwrap in Blender where you control it |

Mesh preparation before import (from Blender):

- Triangulated (same triangulation you will export to Roblox), smoothing final, transforms applied ([[Normal Maps and Detail Baking]]).
- One material per texture set. In Painter each material on the mesh becomes a texture set; for Roblox that should mean one texture set per MeshPart.
- Name meshes `_low` and `_high` with matching prefixes if you bake by mesh name in Painter (Painter's "Match by mesh name" option).

### Baking in Painter

Painter's baker produces normal, world space normal, ID, AO, curvature, position and thickness maps that its smart materials and generators use as masks. Settings to check:

- **Output size** at or above the document size.
- **Max frontal/rear distance** or a cage: same concepts as Blender's extrusion and cage ([[Texturing and PBR Baking]]).
- **Antialiasing** (subsampling) 4x or higher for clean edges.
- **Normal format**: inherits the project's OpenGL setting; confirm.

You can also bake in Blender and import the maps into Painter's mesh map slots.

## 3. Export presets for Roblox

Adobe's documentation lists default export presets for Roblox: **"Roblox (SurfaceAppearance)"**, which outputs a colour map with alpha, and **"Roblox (MaterialVariant)"**, which outputs albedo without alpha support (Adobe docs, default presets page; preset names may vary by version). Use them as a starting point and check what each produces in your version. Community reports exist of exports coming out as plain colours with the preset; in those threads the cause was the layer stack, not the preset, so test with a simple painted layer if your export looks empty.

### A custom template that covers every case

Build your own export template (Export Textures > Output Templates) so you control alpha and names. Suggested template, "Roblox SA":

| Output file | Channels | Source | Notes |
|---|---|---|---|
| `$mesh_$textureSet_Color` | RGB | Base Color | sRGB, 8-bit |
| (same file) | A | Opacity, or a user channel for tint mask, or none | Choose per asset (see below) |
| `$mesh_$textureSet_Normal` | RGB | Normal OpenGL (the converted "Normal" with height mixed in) | 8-bit |
| `$mesh_$textureSet_Roughness` | Gray | Roughness | 8-bit |
| `$mesh_$textureSet_Metalness` | Gray | Metallic | 8-bit |
| `$mesh_$textureSet_Emissive` | Gray | Emissive (converted to grayscale) or a user channel | Only if the asset glows |

Export settings: PNG, 8-bit, size as needed, **padding: Dilation infinite or dilation plus default background** so islands bleed into the gaps (see margins in [[UV Unwrapping]]).

### Alpha per AlphaMode

| Asset uses | Colour map alpha should be | How in Painter |
|---|---|---|
| `Overlay` (default) | Where `MeshPart.Color` should show through: 0; elsewhere 1 | A user channel painted as a "show base" mask, mapped to alpha |
| `Transparency` | Opacity (cutouts, soft fades) | Add the Opacity channel to the texture set; use an alpha-blend or alpha-test shader in the viewport |
| `TintMask` | Tint strength: 1 = fully tinted, 0 = untinted | A user channel (for example `user0`) painted as tint mask, mapped to alpha |
| Fully opaque | No alpha (export RGB only) | Leave alpha unmapped |

`TintMask` caution from Roblox docs: keep colour in transparent regions and avoid premultiplied alpha. Painter exports straight (unpremultiplied) alpha into PNG, but some image editors you might touch the file with afterwards clear RGB under zero alpha on save. Open the result in a viewer that can show RGB without alpha and confirm the untinted areas still have colour.

For tinted regions, paint Base Color near-white or neutral grey with only value variation; `SurfaceAppearance.Color` multiplies it ([[Trim Sheets Atlases and Vertex Colors]]).

## 4. Making Painter's viewport match Studio

Painter's viewport and Roblox's renderer differ. Roblox docs warn that brightness and reflectivity may differ between Studio and authoring tools such as Substance Painter. To narrow the gap:

- Use a neutral, moderately bright HDRI environment, exposure around 0, and turn off strong post effects (bloom, heavy tone mapping) in Painter's display settings.
- Keep a calibration asset: a grey sphere, a chrome sphere and a colour chart exported once and set up in Studio under your game's `Lighting`. Compare side by side.
- Judge **final** roughness and colour in Studio, then adjust in Painter. Expect a couple of round trips on the first asset of a new style; after that the offsets are known.
- Raise roughness slightly (about 0.1) where Fresnel makes rims shine too much in Studio (docs suggestion).

## 5. The import loop into Studio

1. Export textures.
2. Either:
   - Assign textures in Blender to the material (Principled BSDF) and export FBX/GLB with embedded textures; the 3D Importer creates the SurfaceAppearance (docs: FBX and glTF support PBR textures); or
   - Upload textures as images and assign them to a SurfaceAppearance in Studio by hand or with a plugin.
3. Check in your lighting test room.
4. Iterate. While iterating, turn off "Upload to Roblox" in the importer so you do not fill your inventory with test assets ([[3D Importer Settings Reference]]).

Plugin note: SurfaceAppearance map properties are Plugin security, so a Studio plugin or the command bar can assign them, but game scripts cannot ([[Texturing and PBR Baking]]).

## 6. Alternatives

| Tool | Cost (as of October 2026; verify) | Strengths for Roblox | Weaknesses |
|---|---|---|---|
| **Blender** (Texture Paint, bake, shader nodes) | Free, open source | Everything in one place; scriptable; procedural bakes; what the reference project used for all textures | Painting UX weaker than Painter; layer system limited without add-ons |
| **Substance 3D Painter** | Subscription or perpetual licence via Adobe/Steam options | Smart materials, masks from bakes, fastest for realistic and stylised PBR | Paid; DirectX defaults; Studio look differs from viewport |
| **Substance 3D Designer** | Adobe subscription | Procedural tileable materials (great for MaterialVariants) and trim sheets | Node graph learning curve |
| **ArmorPaint** | Open source; paid prebuilt binaries | Painter-like layer painting, node materials | Smaller community |
| **3DCoat / 3DCoatTextura** | Paid | Painting plus retopology and UV in one | Paid; UI dense |
| **Material Maker** | Free, open source | Procedural materials like Designer | Less mature |
| **Krita, GIMP, Photoshop, Affinity** | Free to paid | 2D painting of palettes, trims, decals, flipbooks | No 3D projection (except Photoshop 3D, which Adobe removed) |
| **Python + numpy in Blender** | Free | Reproducible kits, procedural trims and VFX textures, batch re-generation | Programming required |
| **Roblox's in-Studio material and texture generation** | Free in Studio | Fast MaterialVariants and textures from prompts | Variable quality; see [[AI Material and Texture Generation]] and [[Roblox Generative AI - Cube Mesh and Texture Generation]] |

### When Painter is worth it

- UGC items and hero assets where texture quality sells the item.
- Realistic or stylised PBR with lots of edge wear and material breakup.
- Teams with an existing Painter workflow.

### When it is not

- Kits of dozens to hundreds of meshes sharing a trim or palette: the reference project textured 400+ armour meshes, hundreds of environment props and all VFX meshes with Blender and Python, re-generating everything by command when the style changed.
- Flat, palette, voxel or toon styles where the texture is simple and procedural.
- Prototyping: colour with `Color` and built-in materials until the shape is final.

## 7. Common Painter-to-Roblox problems

| Symptom in Studio | Cause | Fix |
|---|---|---|
| Bumps look inverted | Project normal format DirectX | Set OpenGL in project settings, re-export (or invert green) |
| Asset glossier than in Painter | Roughness exported in sRGB or through a colour-managed conversion | Export roughness as linear grayscale |
| Thin coloured lines at island borders at distance | No dilation/padding | Dilation infinite |
| Colour map exported with black areas | Alpha premultiplied or cleared, or Opacity mapped where not wanted | Check alpha mapping |
| Untinted trim black under TintMask | RGB cleared under zero alpha by a later edit | Keep RGB; re-export |
| Texture set appears on the wrong mesh | Several materials per mesh | One texture set per MeshPart |
| UDIM tiles missing | UV tile workflow on | Single 0 to 1 UV |
| Emissive glows too much or too little | Emissive strength in Painter is not Roblox's `EmissiveStrength` | Export a mask only; set strength and tint in Studio (Marketplace: 0 to 40) |
| Marketplace upload refused for texture size | Exported 4096 | 2048 or less for avatar items |

## Checklist

- [ ] Painter project: metallic-roughness, **OpenGL normals**, no UDIMs.
- [ ] One texture set per Roblox MeshPart.
- [ ] Export template with separate gray roughness and metalness, alpha matched to the intended `AlphaMode`.
- [ ] Dilation padding on; PNG 8-bit; size by texel density.
- [ ] Untinted RGB preserved under alpha 0 for TintMask.
- [ ] Final judgement under Studio lighting, not in Painter's viewport.

## See also

[[Texturing and PBR Baking]] · [[Normal Maps and Detail Baking]] · [[UV Unwrapping]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Hand-Painted and Stylized Texturing]] · [[UGC Avatar Items and Accessories]] · [[Exporting and Validating Models for Roblox]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[AI Material and Texture Generation]] · [[Art Pipeline - Concept to In-Game Asset]]

## Connected notes
<!-- auto-links:start -->
[[SurfaceAppearance PBR Workflow]] · Links - Texturing · Materials and Surfaces Start Here · Stylised vs Realistic Material Pipelines · Baking Lighting and Detail into Textures · MagicaVoxel Goxel and Blockbench Workflows Compared
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[MagicaVoxel Goxel and Blockbench Workflows Compared]] · [[Stylised vs Realistic Material Pipelines]] · [[Blender Workflow for Roblox Creators]] · [[Modeling Fundamentals for Games]] · [[Low-Poly and Stylized Modeling]] · [[Mesh Optimization for Mobile]] · [[Modular Environment Kits]] · [[Voxel and Blocky Modeling]] · [[Hard-Surface Modeling]] · [[Procedural Model Kits - Lessons]]
<!-- related:end -->
