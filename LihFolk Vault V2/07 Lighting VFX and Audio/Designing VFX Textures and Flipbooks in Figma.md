---
tags: [vfx, figma, textures, flipbook, particles, alpha, export, type/guide, area/vfx, level/intermediate, api/ParticleEmitter, area/modeling]
---
# Designing VFX Textures and Flipbooks in Figma

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Painting textures in their final colours, then fighting the emitter's `Color`.
> - Avoid: Gradients that fade to transparent *black*, giving grey or dark edge rings.
> - Avoid: Flipbook sheets that are not 1024 x 1024, or exported with trim on.
> - Art is white and grey with alpha; colour comes from the palette roles (main, hot, dark, glow, spark, debris, deep).
> - Flipbooks are 1024 x 1024 frames with a 2x2, 4x4 or 8x8 grid, one clipped frame per cell, in play order.
> - Every cell keeps a transparent margin (16 / 12 / 8 px for 512 / 256 / 128 cells); edges fade before it.
>
> Cost: TL;DR ~190 tok · whole note ~2.8k tok. Read more: ## 2. Sizes and the flipbook grid · ## 6. Wiring a Figma texture into an emitter · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Figma is a good tool for effect textures. Vector shapes, soft gradients, boolean cuts and layout grids make it quick to draw:
- slash crescents;
- glints;
- rings;
- spark streaks;
- smoke puffs;
- flipbook sheets laid out cell by cell.

What Figma does not know is how Roblox uses these images:
- Particles and beams **multiply** the texture by a colour.
- Flipbooks need an exact **1024 x 1024** grid.
- Soft edges exported the wrong way pick up dark fringes.

This note sets the rules so the textures plug straight into the `lihfolk-vfx` palette system.

Background reading:
- Emitter mechanics: [[Particle Emitters In Depth]].
- Effect design: [[VFX Design Playbook]], [[VFX Readability and Value - Lessons from Blind Reviews]].
- Ribbons: [[Beams and Trails]].
- Texture cost: [[Textures Decals and Texture Memory]].
- Budgets: [[VFX Performance Budgets and Culling]].
- The UI side of Figma: [[Figma to Roblox UI - Pipeline and Handoff]].

Sources: **Docs** (Roblox `ParticleEmitter` and flipbook reference, as summarised in the linked notes; October 2026), the **lihfolk-vfx** skill's palette and texture registry, and **rule of thumb** where marked.

---

## 1. Draw in white and grey; colour in the engine

A `ParticleEmitter`, `Beam` or `Trail` multiplies its texture by its `Color` sequence. A white texture takes any colour; a red texture can only get darker or redder. So:
- **Shapes are white**, with shading in greys. Brightness carries form: a white-hot core, grey falloff, transparent outside.
- **Alpha carries the shape.** In Figma, use white fills and white-to-transparent gradients. Both stops are white; only the opacity changes.
- **Colour comes from the palette roles** in `lihfolk-vfx`. Each element (teal, violet, fire, ice, lightning, void, holy) defines `main`, `hot`, `dark`, `glow`, `spark`, `debris` and `deep`. One white crescent texture serves:
  - the element body, tinted `main`;
  - the white rim, tinted `hot`;
  - the ink layer, tinted `dark` or `deep` with `LightEmission` 0.
- **Keep three tones in every frame:** white, element and dark. The dark layer reuses a white texture with a dark tint and normal blending; it is not a black texture. See [[VFX Design Playbook]].

Exceptions:
- textures whose colour is part of the art and must not be tinted (a painted icon, a rune with two fixed colours);
- textures for `SurfaceAppearance`.

Keep those rare, and name them so nobody tints them by mistake.

---

## 2. Sizes and the flipbook grid

| Texture | Canvas | Cell | Use |
|---|---|---|---|
| Single sprite (glint, spark, puff) | 256 or 512 square | none | Most particles; 256 is plenty for small, fast sprites |
| Strip (beam or trail body) | 512 x 128 or 1024 x 256 | none | Repeats along the length |
| Flipbook `Grid2x2` | **1024 x 1024** | 512 | 4 frames: slow, big shapes |
| Flipbook `Grid4x4` | **1024 x 1024** | 256 | 16 frames: crescents, rings, puffs (the `lihfolk-vfx` default) |
| Flipbook `Grid8x8` | **1024 x 1024** | 128 | 64 frames: small, fast or many-frame effects |

Roblox's flipbook check asks for 1024 by 1024. Uploads are capped at 1024 px on the long side, so a flipbook is always exactly one full-size image.

Set the flipbook up in Figma like this:
1. **Make the frame.** Create a 1024 x 1024 frame with no fill and clip content on, and name it after the texture key it will fill, for example `flip_crescent_4x4`.
2. **Add a grid.** Add a layout grid of 4 columns and 4 rows (or 2 or 8) with a gutter of 0, so cells snap exactly.
3. **One frame per cell.** Each cell is its own 256 x 256 frame with clip content on. Name the cells `f00` to `f15` in play order. Clipping stops one frame's glow spilling into the next.
4. **Play order.** Order cells left to right, top row first, then the next row. Play the first loop in Studio to confirm the order before drawing all the cells.
5. **Draw with a component.** Make the base shape a component and vary each instance (rotation, scale, an erosion mask). Fixing the shape then fixes every cell.

---

## 3. Padding per cell and soft edges

- **Padding.** Leave a transparent margin inside every cell. Mip-mapping samples neighbouring pixels at small on-screen sizes, so art touching the cell edge bleeds into the next frame (Docs). Rule of thumb:
  - 16 px for a 512 cell;
  - 12 px for a 256 cell;
  - 8 px for a 128 cell.

  Draw a `skip_` guide square inset by that amount and keep everything inside it.
- **Soft edges.** Fade every edge to fully transparent before the padding starts. A hard alpha edge shimmers when the particle shrinks and shows a visible rectangle when it rotates. Ways to get soft edges:
  - layer blur on a white shape;
  - a radial gradient from white at full opacity to white at zero opacity;
  - a feathered mask.
- **Hard on purpose.** Sparks and square debris can stay crisp. Even they need a 1 to 2 px anti-aliased edge and their own padding.

---

## 4. Edge halos: premultiplied alpha and the "fade to black" trap

A dark or coloured fringe around a soft texture is the most common Figma-to-Roblox texture bug. It happens when edge pixels carry the wrong colour:
- **The gradient trap.** If a gradient fades from white to *black at 0% opacity*, the half-transparent middle is grey. When tinted and blended, the edge shows a grey or dark ring. Set both stops to white and change only the opacity. Check every gradient stop: some colour pickers default the new stop to black.
- **Transparent pixels are not colourless.** Texture filtering mixes the RGB of fully transparent pixels with their visible neighbours. If the empty area is black, soft edges darken; if it is white, they stay clean.
- **Fixes, in order of preference:**
  1. Draw white on white: every fill and every gradient stop is white, with alpha alone shaping the art.
  2. Check the export by viewing the PNG over a mid-grey and over a white background. A ring that shows on white but not on grey is a dark fringe.
  3. If a fringe remains (blurs can create one), run an edge-padding ("dilate" or "bleed") pass in an image editor before upload. This copies edge colour out into the transparent area without changing alpha.
- **Additive versus normal blending.** With `LightEmission` 1 (additive), dark fringes add almost nothing and often go unnoticed. The same texture used for the dark ink layer, with `LightEmission` 0 and normal blending, shows every fringe. Test both uses.

---

## 5. Export settings

| Setting | Value |
|---|---|
| Format | PNG (alpha), never JPG |
| Scale | 1x for a 1024 frame. For a 256 sprite frame, 1x, or 2x when drawn at 128. Exact pixel sizes matter more than scale. |
| Trim | **Off** for flipbooks and strips (trimming breaks the grid and the repeat). Off for sprites too, to keep them square and centred. |
| Background | The frame has no fill, so it exports transparent |
| Colour | White and grey only (see section 1) |
| Name | The texture key from the `lihfolk-vfx` registry (`flip_crescent_4x4`, `glint_star4`, `spark_streak`, `smoke_puff`) |

**Upload.**
1. Upload through your own account.
2. Paste each id into the texture registry entry of the same name; entries left as `""` use the module's fallbacks.
3. Never paste ids you did not upload or check. Moderation can reject very bright or text-like images, so keep effect art abstract.

**Budget.** A 1024 sheet costs four times a 512 in texture memory, and clients may switch flipbooks off under memory pressure (Docs). Reuse a few sheets across many effects, and make the first frame acceptable on its own.

---

## 6. Wiring a Figma texture into an emitter

```lua
--!strict
-- A white 4x4 flipbook from Figma, tinted by palette roles. The texture id comes from your upload.
type Palette = { main: Color3, hot: Color3, dark: Color3 }

local function makeFlipbookEmitter(parent: Attachment, textureId: string, palette: Palette): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = textureId -- "rbxassetid://<your upload>"; leave "" until uploaded
	emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot -- plays the 16 cells once per lifetime
	emitter.Lifetime = NumberRange.new(0.3)
	emitter.Rate = 0 -- burst with :Emit()
	emitter.LightEmission = 1 -- additive body; a second emitter with 0 carries the dark layer
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, palette.hot), -- white-hot at birth
		ColorSequenceKeypoint.new(0.35, palette.main),
		ColorSequenceKeypoint.new(1, palette.main),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = parent
	return emitter
end

local attachment = Instance.new("Attachment")
local teal: Palette = {
	main = Color3.fromRGB(40, 215, 195),
	hot = Color3.fromRGB(225, 255, 250),
	dark = Color3.fromRGB(5, 20, 24),
}
makeFlipbookEmitter(attachment, "", teal):Emit(1)
```

`OneShot` plays the frames once across each particle's lifetime, so a 16-frame sheet over 0.3 s plays faster than the 30 fps cap that applies to `Loop` ([[Particle Emitters In Depth]]).

---

## Common mistakes

- Painting textures in their final colours, then fighting the emitter's `Color`.
- Gradients that fade to transparent *black*, giving grey or dark edge rings.
- Flipbook sheets that are not 1024 x 1024, or exported with trim on.
- Art touching the cell edge, so neighbouring frames bleed in at small sizes.
- Hard alpha edges on soft effects (shimmer and visible rectangles).
- Cells drawn in an order that does not match the grid's play order.
- A new 1024 sheet for every effect instead of reusing a few.
- Pasting texture ids that were never uploaded.

## Checklist

- [ ] Art is white and grey with alpha; colour comes from the palette roles (main, hot, dark, glow, spark, debris, deep).
- [ ] Flipbooks are 1024 x 1024 frames with a 2x2, 4x4 or 8x8 grid, one clipped frame per cell, in play order.
- [ ] Every cell keeps a transparent margin (16 / 12 / 8 px for 512 / 256 / 128 cells); edges fade before it.
- [ ] Every gradient stop is white, with only the opacity changing; checked over grey and white backgrounds.
- [ ] Exported as PNG at exact pixel size, trim off, named after the registry key.
- [ ] Tested with additive and normal blending; no fringes on the dark layer.
- [ ] Uploaded by you, ids pasted into the registry, few sheets reused across effects.

<!-- related:start -->
## Related
[[Slash VFX Recipes - Crescent and Ring]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[VFX Previews in Blender for Roblox - Colour and Framing]] · [[Projectile VFX - Muzzle, Travel and Impact]] · [[Escalation and Grandeur Without Clutter]] · [[Light Sources and Shadows]] · [[Impact Decals and Material-Aware Hit Sparks]] · [[AoE Telegraphs - Readable Ground Warnings]]
<!-- related:end -->
