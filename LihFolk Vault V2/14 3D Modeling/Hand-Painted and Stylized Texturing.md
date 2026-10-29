---
tags: [modeling, texturing, stylized, hand-painted, toon, blender, type/guide, area/modeling, level/intermediate]
---
# Hand-Painted and Stylized Texturing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Strong painted directional light -> Subtle painting, let engine light
> - Avoid: Low roughness on painted assets -> Roughness near 1 for painted non-metals
> - Avoid: Metalness on hand-painted metal -> Metalness 0, paint the shine, or go stylised PBR properly
> - Style chosen and documented; values checked in grayscale.
> - Painted lighting subtle; AO allowed, directional light minimal.
> - Roughness and metalness set to stop the engine fighting the paint.
>
> Cost: TL;DR ~160 tok · whole note ~3.4k tok. Read more: ## 2. The engine problem: no unlit shading · ## 4. Toon and cel textures · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most successful Roblox games are stylised: chunky shapes, readable colours, painted or flat-shaded surfaces. Stylised texturing is not "PBR but simpler"; it is a different set of goals (readability at a glance on a phone, consistency with blocky avatars, low memory) and it fights the engine in a few specific ways, because Roblox has no unlit or custom shaders. This note covers the styles (hand-painted, toon, gradient, flat), how to paint and generate them in Blender, how to make them survive Roblox's PBR lighting, and how one production game (the reference project) produced a whole stylised armour line and its VFX textures procedurally.

Technical foundations are in [[Texturing and PBR Baking]], [[UV Unwrapping]] and [[Trim Sheets Atlases and Vertex Colors]].

## 1. The styles

| Style | What the texture carries | Maps used | Example look |
|---|---|---|---|
| Hand-painted (classic) | Lighting, AO, highlights and material, all painted in colour | Colour only (sometimes roughness) | Painted fantasy props, stylised MMOs |
| Toon / cel | Flat bands of colour with hard steps, outlines | Colour (+ emissive for glows) | Anime weapons, toon VFX |
| Gradient stylised | Large soft gradients, top-light and bottom-dark, little texture noise | Colour or vertex colour | Simulator games, clean low-poly |
| Flat / palette | One colour per surface | Palette atlas or `Color` | Low-poly and voxel games |
| Stylised PBR | PBR maps with exaggerated wear, chunky normal details, painted colour | Full SurfaceAppearance | Modern stylised shooters and RPGs |

Pick one per game and write it down in a style guide ([[Environment Art Styles]], [[Art Pipeline - Concept to In-Game Asset]]). Mixing hand-painted props with realistic PBR next to each other is the most common way a Roblox game looks "asset-flipped".

## 2. The engine problem: no unlit shading

Roblox lights every surface. A hand-painted texture that already contains a highlight and a shadow gets **lit again**: the painted top highlight darkens when the object turns, the painted shadow side gets an extra real shadow, metals reflect the sky on top of their painted shine. Options, from simplest:

| Approach | How | Trade-off |
|---|---|---|
| Paint lighting softly | Keep painted light and shadow subtle (value range compressed); let Roblox's light do the rest | Safest; works under every lighting preset |
| High roughness, zero metalness | Set roughness near 1 and metalness 0 so specular does not compete with paint | Metals then only read through painted colour and value |
| Emissive mask as "unlit" | Put the painted texture in the colour map and a uniform emissive mask with low `EmissiveStrength` so it glows at its own colour regardless of light | Looks flat and bright at night; Marketplace limits strength to 0 to 40; upload fee higher for emissive UGC |
| `Neon` material for small accents | Glows independent of lighting (and blooms) | Only for flat colours; not textured |
| Lighting design | Use `Lighting.Ambient`/`OutdoorAmbient`, low shadow softness, and a lighting technology that suits stylised art | Affects the whole game, so decide globally |

The reference project combined these: painted gradients with moderate value range on the armour, high roughness on non-metal rows, separate `Neon` glow parts for runes and visors, and bloom tuned so Neon blooms but white trim does not (Bloom Threshold about 1.2 to 1.5 in its style reference). See [[Lighting Mood and Time of Day]] and [[Atmosphere Sky Clouds and Post-Processing]].

Nuance: **painted AO is fine; painted directional light is fragile.** Dark crevices stay correct from any angle. A painted sun direction is only correct for one orientation, so it breaks the moment a player rotates the item or the camera orbits a held weapon.

## 3. Hand-painting in Blender

Blender's Texture Paint mode is enough for Roblox-scale assets:

1. **Unwrap for painting**: few, large, straight islands; seams hidden; 90 degree rotations only ([[UV Unwrapping]]).
2. **Base fill**: flat colours per material (bake an ID map or fill per face selection).
3. **Bake helpers**: AO, a top-down gradient (Position or Gradient texture into an Emit bake), and edge masks (curvature). Multiply or overlay them softly into the base; this gives most of the "painted" read before you touch a brush ([[Normal Maps and Detail Baking]] for how to bake them).
4. **Paint in 3D** to cross seams: Blender projects strokes onto all islands under the brush. Use "Clone" and "Smear" sparingly.
5. **Paint in 2D** in the Image Editor for clean straight details (planks, trim lines).
6. **Edge highlights**: thin lighter lines on convex edges, the signature of the style. Drive them from the curvature mask, then refine by hand.
7. **Save often** (Image > Save). Painted images are not saved with the `.blend` unless packed or saved.

Brush and palette rules of thumb:

- **Hue-shift shadows and highlights**: shadows cooler and more saturated, highlights warmer and less saturated. Pure black and white mixed in looks dull.
- **Value first**: check the texture in grayscale. If forms do not read in grayscale they will not read on a phone.
- **Texel density lower than PBR**: painted textures hold up at 32 to 64 px per stud because they have no high-frequency detail.
- **Big shapes, few strokes**: on Roblox, objects are often seen small on a phone screen; a painted crack 2 px wide disappears.

## 4. Toon and cel textures

Toon textures have hard value steps instead of gradients. On Roblox the steps must be in the texture, because the engine's lighting is smooth.

Recipe (the reference project's toon VFX and armour followed this shape):

1. A smooth source: a gradient along the UV, AO, or a lighting bake.
2. Optional noise to break the edges.
3. A **constant-interpolation colour ramp** with 3 or 4 bands (Blender's Color Ramp node with Interpolation "Constant").
4. Optional outline band: the darkest step at the silhouette edge or the island border.
5. Bake to the colour map; for VFX, threshold the same signal into alpha.

The project's toon VFX pipeline did exactly this in Python with numpy (UV gradient, then noise, then a constant 4-tone ramp, then an alpha threshold) and produced four erosion frames per piece, packed into 4 x 4 flipbooks. Its second brightness pass raised emissive to 1.9, saturated the bands, and used only a dark outline (with one element inverted: dark body, bright outline). Elements had their own palettes and motifs (flames, glyph bands, tendrils, swirls, star specks, wave crests, jagged bolts, cracks, shards, leaves) from one shared code path. That is the advantage of a procedural toon recipe: eleven element styles from one generator, each re-bakeable in seconds.

### Outlines

Roblox has no post-process outline shader. Options:

| Outline method | Cost | Notes |
|---|---|---|
| Painted dark band at the texture's island edges | None at runtime | Only follows UV edges, not the silhouette |
| Inverted hull: a duplicated, slightly inflated mesh with flipped normals, black | Doubles triangles | Classic; needs flipped faces to render as back faces; test that Roblox culls as expected |
| `Highlight` instance | Limited count per scene (see [[Highlights and Selection Effects]]) | True silhouette outline; best for a few objects |
| Viewport outline tricks | UI cost | The reference project outlined a ViewportFrame preview with 8 black silhouette copies offset by 3 px |

## 5. Gradients as the stylised default

The cheapest convincing stylised look on Roblox is gradient-heavy:

- **Top-light gradient**: each surface slightly lighter at the top. Bake a world-Z gradient into the colour (or into vertex colours for very low-poly meshes).
- **Ground darkening**: the bottom 10 to 20 percent of tall props darker, so they sit in the world.
- **Colour gradient on emissive parts**: the hottest colour at the core, cooler at the edge.

The reference project's toon armour trim was "painted gradients" on every row, generated by a script, which is why the line looked consistent across 18 sets: the gradients were maths, not brush strokes.

## 6. Procedural "painting" with scripts

Hand-painting is slow and hard to iterate. For kits, the reference project generated all stylised textures in Blender Python, not in a paint tool:

- Trim rows (plate, inset plate, scales, crystal, cracked stone; gold, silver, dark iron, visor) drawn as images with numpy: base value, vertical gradient, edge highlight lines, small noise.
- Masks by mesh property: convex edges brighter, concave darker, alpha for tint.
- Everything re-generated by one command when the style changed (the armour line went from hard-surface to toon and back to per-set colour maps without repainting by hand).

A tiny example of a painted-gradient row in numpy:

```python
import numpy as np

def painted_row(w=1024, h=128, base=(0.82, 0.82, 0.86), edge=0.12):
    """A tintable plate row: vertical gradient, bright top lip, dark bottom lip."""
    y = np.linspace(0.0, 1.0, h)[:, None]          # 0 at top, 1 at bottom
    value = 1.0 - 0.25 * y                           # top lighter
    value = np.where(y < edge * 0.3, 1.15, value)    # bright top highlight
    value = np.where(y > 1.0 - edge * 0.3, 0.55, value)  # dark bottom lip
    rgb = np.clip(np.array(base)[None, None, :] * value[..., None], 0, 1)
    rgb = np.repeat(rgb, w, axis=1)                  # tile along the row
    alpha = np.ones((h, w, 1))                       # fully tinted (TintMask)
    return np.concatenate([rgb, alpha], axis=2)      # h x w x 4, linear 0..1
```

Write such arrays into a Blender image (`img.pixels.foreach_set(arr[::-1].ravel())`, since Blender images start at the bottom row) or save with any imaging library. Remember Blender `pixels` are linear floats for sRGB images: convert or set values knowing that the saved PNG will be sRGB-encoded.

See [[Blender Automation with Python]] and [[AI Material and Texture Generation]] for other generation routes.

## 7. Stylised PBR

Many recent Roblox games use full SurfaceAppearance with stylised content:

- **Colour**: painted, saturated, with soft painted AO.
- **Normal**: chunky bevels and big shapes (stone blocks, wood planks), not pores and scratches.
- **Roughness**: mostly uniform per material with a few broad variations; avoid fine noise, it reads as dirt.
- **Metalness**: strictly 0 or 1.

This gets real lighting response (helpful in a day-night game) while keeping the painted read. It costs texture memory like any PBR asset, so it pairs best with trim sheets ([[Trim Sheets Atlases and Vertex Colors]]).

## 8. Matching Roblox avatars

Players' avatars are on screen with your art. Classic blocky avatars and many UGC items are smooth, bright and lightly textured. Rules of thumb:

- Keep **saturation and value** of the world in the same family as avatars, or characters look pasted on.
- **Avoid photo textures** on stylised geometry.
- Give gameplay-relevant objects (pickups, enemies, interactables) higher saturation or emissive accents than background art ([[Level Design for Roblox]], [[Game Feel and Juice]]).

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Strong painted directional light | Wrong when rotated; double lighting | Subtle painting, let engine light |
| Low roughness on painted assets | Sky reflections over paint | Roughness near 1 for painted non-metals |
| Metalness on hand-painted metal | Dark, reflective, fights the paint | Metalness 0, paint the shine, or go stylised PBR properly |
| Fine detail at low texel density | Mush on phones | Big shapes, bold strokes |
| Mixing styles | Asset-flip look | One style guide |
| Uniform emissive to fake unlit everywhere | Flat, glowing world at night; Marketplace limits | Use selectively |
| Painting each asset by hand for a 100-piece kit | Weeks, inconsistent | Procedural rows, trims, generated masks |

## Checklist

- [ ] Style chosen and documented; values checked in grayscale.
- [ ] Painted lighting subtle; AO allowed, directional light minimal.
- [ ] Roughness and metalness set to stop the engine fighting the paint.
- [ ] Toon steps baked into the texture; outlines chosen deliberately.
- [ ] Tested under every lighting preset in the game and on a phone.
- [ ] Kit textures generated or shared rather than painted one by one.

## See also

[[Texturing and PBR Baking]] · [[Trim Sheets Atlases and Vertex Colors]] · [[UV Unwrapping]] · [[Substance Painter and Texturing Tools]] · [[Low-Poly and Stylized Modeling]] · [[Voxel and Blocky Modeling]] · [[Environment Art Styles]] · [[VFX Design Playbook]] · [[Highlights and Selection Effects]] · [[Lighting Technologies and Settings]] · [[Blender Automation with Python]] · [[AI Image Generation for Icons Thumbnails and Concepts]]

## Connected notes
<!-- auto-links:start -->
[[Baking Lighting and Detail into Textures]] · Stylised vs Realistic Material Pipelines · Materials and Surfaces Start Here · SurfaceAppearance PBR Workflow · Bevels Chamfers and Edge Highlights Without Textures · Lighting Untextured Art in Roblox
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Stylised vs Realistic Material Pipelines]] · [[Bevels Chamfers and Edge Highlights Without Textures]] · [[Hard-Surface Modeling]] · [[Modeling Fundamentals for Games]] · [[Mesh Optimization for Mobile]] · [[Modular Environment Kits]] · [[Blender Workflow for Roblox Creators]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]]
<!-- related:end -->
