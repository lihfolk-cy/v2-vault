---
tags: [modeling, texturing, trim-sheet, atlas, vertex-colors, optimization, type/guide, area/modeling, level/intermediate, api/SurfaceAppearance, area/performance]
---
# Trim Sheets Atlases and Vertex Colors

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Saturated base colour in tinted trim rows -> Near-white or grey tinted rows
> - Avoid: RGB cleared under alpha 0 in a TintMask map -> Export without premultiply; keep RGB
> - Avoid: Trim rows without horizontal tiling -> Make each row tile left-right
> - Technique chosen per kit (trim, palette, vertex, unique) before modelling.
> - Trim rows tile horizontally with padding; tinted rows near-white; untinted rows alpha 0 with real RGB.
> - TintMask maps exported without premultiplied alpha.
>
> Cost: TL;DR ~170 tok · whole note ~4.2k tok. Read more: ## 2. Trim sheets · ## 5. Vertex colours · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Unique textures for every mesh do not scale. A Roblox game with hundreds of props, dozens of armour pieces and a hundred weapons cannot give each a 1024 PBR set: memory, download size and upload churn all explode. Three techniques let many meshes share very few textures: **trim sheets** (a texture of reusable strips and panels that many meshes map onto), **atlases** (many small textures or colour swatches packed into one image) and **vertex colours** (colour stored on the mesh itself, no texture at all). This note explains each, when it is the right choice on Roblox, how they combine with `SurfaceAppearance` tinting, and the production lessons from one production game (the reference project), which used a shared tinted trim sheet for an entire armour line, palette atlases for kits, and learned the hard way how vertex colours interact with `Color`.

## 1. Choosing a technique

| Technique | Texture cost | Unique detail | Recolour per instance | Best for |
|---|---|---|---|---|
| Unique texture set per mesh | High | Full | Via SA `Color` | Hero assets, avatar items, bosses |
| Trim sheet | One set shared by a whole kit | Medium (from strips) | Via SA `Color` + TintMask | Armour lines, architecture, sci-fi panels, weapons families |
| Colour palette atlas | One tiny image | None (flat colours) | Swap the image or tint | Low-poly and voxel kits, stylised props |
| Gradient atlas | One small image | Gradients only | Swap or tint | Stylised props, foliage, toon shading |
| Vertex colours | Zero | Per-vertex only | `Color` multiplies | Voxel and blocky meshes, cheap AO, gradients on big low-poly forms |
| Built-in materials / MaterialVariant | Shared engine textures | Tiling only | `Color` | Large surfaces, terrain-like props |

The decision usually falls out of art style ([[Environment Art Styles]], [[Low-Poly and Stylized Modeling]]) and count: if more than about ten meshes share a look, a shared texture almost always wins (rule of thumb).

## 2. Trim sheets

A trim sheet is one texture laid out in horizontal (or vertical) strips: a bevelled metal edge, a row of rivets, a plate with an inset, a band of scales, a strip of trim with a gem. Meshes are UV-mapped so each face lands on the strip it should look like. Because strips tile along their length (horizontal tiling inside the 0 to 1 range is fine as long as the strip spans the full width), a long belt and a short bracer both reuse the same strip.

### Why trim sheets fit Roblox well

- **One `SurfaceAppearance` set for a whole kit.** Every MeshPart references the same uploaded maps; the client downloads and holds one set.
- **No custom shaders needed.** All the detail lives in the shared colour, normal, roughness and metalness maps.
- **Recolouring is free.** With `AlphaMode = TintMask`, alpha marks which texels take `SurfaceAppearance.Color`; one trim serves many colourways (docs: tinting does not affect performance).

### Layout

| Row type | Height (on 1024) | Notes |
|---|---|---|
| Edge bevels (two or three widths) | 16 to 64 px | The most reused rows; give them clean normal bevels |
| Panels / plates with inset | 128 to 256 px | Large flat areas of each mesh |
| Pattern rows (scales, lamellar, rivets, cloth weave) | 64 to 128 px | Character of the kit |
| Untinted accent rows (gold, silver, dark iron, glass) | 32 to 128 px | Alpha 0 under TintMask so they stay their own colour |
| Emissive rows (runes, visor slit, glow strips) | 32 to 64 px | Only if the kit uses `EmissiveMaskContent`; otherwise use separate Neon parts |
| A few square decals (emblem, gem) | 64 to 128 px squares | Unique-ish spots |

Rules:

- **Rows tile horizontally.** Paint or bake each row so its left and right edges match.
- **Leave padding between rows** (8 px or more at 1024) for the same mip reasons as any atlas ([[UV Unwrapping]]).
- **Author the normal map flat**, baked from a high-poly strip (a bevel profile extruded along X). Tangent-space maps make the detail follow each mesh's UV direction ([[Normal Maps and Detail Baking]]).
- **Mapping in Blender:** select a face strip, `Follow Active Quads` to straighten it, then scale and move it onto the row in the UV editor. Snap to row boundaries with the UV editor's snapping or a small script.

### The reference project's armour trim

The reference project built its armour as procedural Python in Blender (no store or AI assets). Its first, hard-surface line used one shared trim for all pieces:

- **One shared trim set**: colour (with a tint-mask alpha), normal, roughness and metalness, uploaded once.
- Every main armour MeshPart had a SurfaceAppearance with those four maps, **`AlphaMode = TintMask`**, and **`Color` = the set's colour**. Six sets and 78 pieces (plus glow companions) shared one texture set.
- Glows were separate `_Glow` MeshParts in `Neon` with the set's accent colour, not emissive texture rows.

The toon redesign kept the idea and refined the layout: painted gradients in **tinted rows** (plate, inset plate, fish scales, crystal, cracked stone) plus **painted, untinted rows** (gold, silver, dark iron, visor), "so every set is two-tone": the tint colours the body, the untinted accents stay metal. That is the key trim-sheet design trick: the same mesh reads as a different set purely by `Color`, while the accents keep material contrast.

Later, when the line grew to 18 sets with stronger per-set identity, the project switched to **per-set painted colour maps with SA `Color` white**. The trade-off is explicit:

| Shared tinted trim | Per-set painted maps |
|---|---|
| One texture set for the whole line | One colour map per set (normal, roughness and metalness can still be shared) |
| Sets differ by tint only, plus geometry | Sets can have different painted motifs, multicolour bodies |
| New set = pick a colour | New set = paint a map, upload |
| Tint must work on a near-white or grey base | Any colours |

Start with a tinted trim; move to per-set colour maps only when tint stops being enough. Keep normal, roughness and metalness shared even then if the layout is the same.

### TintMask authoring pitfalls

- **Keep RGB in transparent regions** (docs: avoid premultiplied alpha). Untinted gold is alpha 0 with gold RGB. Exporters that clear RGB under zero alpha turn it black.
- **Tinted regions should be near-white to mid-grey** with value variation only, because `Color` multiplies. A brown tinted region tinted blue becomes dark mud.
- **Alpha is a strength, not a switch.** Soft alpha blends between tinted and untinted; use it for worn edges where paint chips to bare metal.

```lua
--!strict
-- Apply a set colour to every armour piece that uses the shared trim.
-- Map ids are fixed (not scriptable at runtime); Color is.
local function tintSet(model: Model, setColor: Color3)
	for _, d in model:GetDescendants() do
		if d:IsA("SurfaceAppearance") and d.AlphaMode == Enum.AlphaMode.TintMask then
			d.Color = setColor
		end
	end
end
```

## 3. Colour palette atlases

The cheapest texture there is: a small image (32 x 32 to 256 x 256) of flat colour swatches. Every face's UVs are scaled down to a point (or a tiny island) inside the swatch it should be. Hundreds of meshes, one texture, no seams to care about.

How to make it in Blender:

1. Create the palette image (a grid of swatches, each at least 8 x 8 px so mips do not mix them).
2. Assign by selecting faces, then in the UV editor scaling their UVs to zero (`S 0`) and moving them into the swatch centre. Add-ons and short scripts automate "faces with material X go to swatch X".
3. Use one material per kit that uses that image.

Lessons from the reference project:

- Its imported kit meshes used a palette `TextureID` with **degenerate (collapsed) UVs**. When a later pass wanted real tiling materials on them, it could not tile anything (no usable UVs), so it **cleared `TextureID` and set `Color` to the sampled swatch**, storing the original in an attribute so the change could be reverted. Palette atlases are a one-way door: if you might want tiling or detail later, keep proper UVs on a second copy of the source.
- Its icon pipeline rebuilt each weapon's look from the GLB by **sampling the palette texture at each part's UVs, multiplied by vertex colours**. Palette textures are machine-readable colour data; that is a useful property for tools.
- A bug there: palette images from different files shared names, so a pixel cache keyed by image name returned the wrong colours. Key caches by file and image, not by name.

Nuance: a palette atlas looks flat because it is flat. Under Roblox lighting it reads like `SmoothPlastic`. Add a gradient atlas (each swatch a small vertical gradient) and lay faces out vertically to get top-lit or ground-darkened forms for free, a common stylised trick.

## 4. Gradient and noise atlases for VFX

VFX meshes in the reference project used per-effect textures baked from a gradient multiplied by noise, thresholded into alpha erosion, with the same grayscale in the emissive mask ([[Texturing and PBR Baking]]). Two atlas forms appeared:

- **Per-mesh textures** for bespoke meshes (each ring, swirl, crescent with its own map).
- **Flipbook sheets**: four erosion frames per piece packed into 4 x 4 grids for `ParticleEmitter` flipbooks, so a sprite dissolves over its life. See [[Particle Emitters In Depth]].

The atlas logic is the same as for props: tile size, padding, white or grayscale base so `Color` or `ParticleEmitter.Color` can tint.

## 5. Vertex colours

Vertex colours store an RGB (and optionally alpha) value per face corner on the mesh. The GPU interpolates them across triangles. On Roblox:

- The 3D Importer supports vertex colours in FBX and glTF, and has an option to ignore them per child (docs, see [[3D Importer Settings Reference]]).
- **They multiply with the part's `Color`** (measured). A vertex-coloured mesh with `Color` white shows exactly the vertex colours; any other `Color` darkens or tints them.
- They cost no texture memory and no download beyond a few bytes per vertex.
- Marketplace accessories must have `VertexColor` 1, 1, 1 (docs, rigid and layered specs), so vertex colours are not a way to colour UGC.

### When to use them

| Good use | Why |
|---|---|
| Voxel and blocky meshes | Each cube face one colour; no UVs needed |
| Baked AO on big low-poly forms | Soft darkening in corners, zero texture cost |
| Height or direction gradients | Darker base, lighter top on rocks and trees |
| Masks for stylised looks combined with a tiny texture | Texture gives detail, vertex colour gives variation |

### The reference project's vertex colour trap

A set of lobby rock walls and cliffs had been generated with **per-corner vertex colours**: hundreds of noisy orange and tan shades per mesh, strata bands, a slate underside. The owner saw "weird patchy lines" and asked for solid textured walls. Changing `Material` and `Color` could not fix it, because:

1. The vertex colours multiply with `Color`, so the streaks remained whatever the colour.
2. The meshes had **no UVs**, so no texture or material could add structure.

The fix was a rebuild in Blender: **white vertex colours**, world box-projected UVs at about 10 studs per tile, and splitting the mesh by face colour into separate `_Rock` and `_Grass` pieces so each could take its own `Color` and material. The original meshes stayed in place as invisible colliders so collision was unchanged.

Lessons:

- **Decide early whether colour lives in vertices or textures.** Mixing both on a mesh means every later recolour has to fight the vertex data.
- **Keep generated vertex colours subtle** (low contrast, low frequency). High-frequency noise in vertex colour shows triangle structure ("patchy lines").
- **Always export UVs** even on vertex-coloured meshes, so a texture can be added later without remodelling.
- **Check vertex colours at import** (`Ignore Vertex Colors` exists for a reason): a mesh that looks oddly dark or streaky may carry colours you did not intend, often from a sculpt or a generator.

### Vertex colours in Blender

Blender 3.2 and later stores them as **Color Attributes** (point or face-corner domain, byte or float). For export:

- **Face-corner, byte colour** is the usual choice and what exporters write as vertex colours.
- glTF exports the active colour attribute as `COLOR_0` (check the exporter's "Use Vertex Color" option, whose name and default changed across Blender 4.x versions; verify in yours).
- FBX writes vertex colours when present, with a colour space option in recent versions (sRGB vs linear); mismatches make colours look washed out or too dark. Test one mesh end to end before a batch.

## 6. Combining techniques

Real kits combine:

| Combination | Example |
|---|---|
| Trim sheet + Neon companion parts | Armour: shared tinted trim on plates, separate Neon glow strips |
| Palette atlas + vertex AO | Low-poly props with soft corner darkening |
| Built-in material + `Color` + one SurfaceAppearance overlay | The reference project's voxel lobby stations: one mesh per colour, `Color` set per mesh, and a shared SurfaceAppearance in `Overlay` mode with a stud pattern tiling about 8 studs per tile |
| Trim sheet + unique decal island | A weapon family sharing one trim, with each weapon's emblem in its own square |

The `Overlay` trick above deserves a note: a mostly transparent colour map in `Overlay` mode shows `MeshPart.Color` where alpha is 0 (docs). So one grayscale detail texture plus per-mesh `Color` gives every colour variant without tinting maths.

## 7. Draw calls and instancing

Sharing textures also helps rendering. Rule of thumb (Roblox does not document its batching rules in detail): identical meshes with identical materials can be instanced; different textures break batches. A kit of 50 meshes with 50 unique texture sets costs more than the same kit sharing one. See [[Rendering Performance]] and [[Art Budgets - Triangles Draw Calls Memory]].

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Saturated base colour in tinted trim rows | Muddy tints | Near-white or grey tinted rows |
| RGB cleared under alpha 0 in a TintMask map | Untinted accents black | Export without premultiply; keep RGB |
| Trim rows without horizontal tiling | Visible seams on long strips | Make each row tile left-right |
| Palette UVs on a mesh you later want to tile | Re-UV or remodel | Keep UVs on a source copy |
| Noisy vertex colours on large surfaces | Patchy, triangle-shaped streaks | Low-frequency, low-contrast vertex colour, or textures |
| Vertex colours on a UGC accessory | Fails validation (VertexColor must be 1,1,1) | Use textures |
| Swatches smaller than 8 px | Colours mix at distance | Larger swatches |
| Caching palette pixels by image name | Wrong colours across files | Key by file and image |

## Checklist

- [ ] Technique chosen per kit (trim, palette, vertex, unique) before modelling.
- [ ] Trim rows tile horizontally with padding; tinted rows near-white; untinted rows alpha 0 with real RGB.
- [ ] TintMask maps exported without premultiplied alpha.
- [ ] Palette swatches at least 8 x 8 px.
- [ ] Vertex colours intentional, subtle, and checked at import.
- [ ] Meshes keep usable UVs even when coloured another way.
- [ ] Per-instance variety via `Color`, not new textures.

## See also

[[UV Unwrapping]] · [[Texturing and PBR Baking]] · [[Normal Maps and Detail Baking]] · [[Hand-Painted and Stylized Texturing]] · [[Modular Environment Kits]] · [[Voxel and Blocky Modeling]] · [[Low-Poly and Stylized Modeling]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Textures Decals and Texture Memory]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[Accessories and Armor That Follow Animation]] · [[VFX Design Playbook]] · [[Exporting and Validating Models for Roblox]]

## Connected notes
<!-- auto-links:start -->
[[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[Substance Painter and Texturing Tools]] · The Gradient Palette Texture Workflow · Bevels Chamfers and Edge Highlights Without Textures · Tiling Trim Sheets and Decal Tricks · Baking Lighting and Detail into Textures
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[The Gradient Palette Texture Workflow]] · [[Modeling in Blender for Roblox]] · [[Modeling Fundamentals for Games]] · [[Hard-Surface Modeling]] · [[Mesh Optimization for Mobile]] · [[Blender Workflow for Roblox Creators]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]] · [[UGC Avatar Items and Accessories]] · [[Procedural Model Kits - Lessons]] · [[Retopology and Decimation]]
<!-- related:end -->
