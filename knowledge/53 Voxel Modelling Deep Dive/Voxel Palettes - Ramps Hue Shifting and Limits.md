---
tags: [modeling, voxel, palette, colour, ramps, hue-shifting, oklab, luau, art-direction]
---
# Voxel Palettes - Ramps Hue Shifting and Limits

In voxel art the palette is the texture. There are no painted details to hide a weak colour choice behind: every cell is one flat colour, and the only things that turn those flat colours into form are the steps between them and the engine's lighting. [[Voxel and Blocky Modeling]] gives a three-tone ramp (shadow, body, lit top) built by plain mixing. This note goes further: why straight mixing towards black and white gives dull ramps, how hue shifting fixes it and how far to push it under Roblox lighting, how many colours a game palette should have and why exact colour equality matters for merging, how to lay a palette out so recolours are cheap, and a Luau quantiser that snaps a messy build onto a palette using perceptual distance.

## 1. What a ramp has to do

A ramp is the ordered set of colours used for one material: a grass ramp, a skin ramp, a stone ramp. On a voxel model it has three jobs.

1. **Separate the planes.** Top faces, side faces and undersides must read as different values even under flat lighting, because on phones and in the `Soft` lighting style the engine may not separate them much on its own.
2. **Describe the material.** Grass is saturated and warm in the light, stone is low in saturation, metal has a big jump between body and highlight.
3. **Stay distinct from every other ramp.** If the darkest grass equals the darkest stone, the two blur together where they meet.

Three steps per material is the right default at most Roblox cell sizes (rule of thumb, matching the existing note). Four steps earns its place only on large, close surfaces: a hero character's face at 0.125-stud cells, or a big building wall seen from 10 studs. Five or more steps on a 0.5-stud model almost always reads as noise.

## 2. Why mixing towards black and white looks dead

The simplest ramp mixes the body colour towards black for the shadow and towards white for the highlight. That desaturates both ends: the shadow goes grey-brown, the highlight goes chalky. Real light does not behave that way. A sunlit surface takes on the warm colour of the sun; a shadowed surface is lit by the blue sky and bounce light, so it shifts cool. Painters and pixel artists have used this for a long time, and it is called **hue shifting**.

The practical recipe (rule of thumb, in HSV terms):

| Step | Hue | Saturation | Value |
|---|---|---|---|
| Shadow | Rotate 10 to 25 degrees towards blue or purple (about 230 to 270 degrees) | Up slightly, 5 to 10 points | Down 20 to 30 points |
| Body | The base colour | Base | Base |
| Lit | Rotate 10 to 20 degrees towards yellow (about 50 to 60 degrees) | Down 5 to 15 points | Up 10 to 20 points |

Saturation usually peaks in the body or the shadow, not the highlight. Highlights that are both brighter and more saturated than the body glow unnaturally, which is the right look for Neon and the wrong look for grass.

The direction "towards blue" means rotating whichever way around the hue wheel is shorter. For a green (120 degrees), the shadow moves up towards 140 to 150 (blue-green) and the light moves down towards 90 to 100 (yellow-green). For a red (0 degrees), the shadow goes towards 340 (crimson-purple) and the light towards 15 to 20 (orange).

## 3. Hue shifting under Roblox lighting

Roblox already adds colour to light. The sun has a colour; `Ambient` and `OutdoorAmbient` add a tint to everything (Ambient everywhere, OutdoorAmbient outdoors only, per the docs' lighting page); `EnvironmentDiffuseScale` pulls ambient light from the skybox (Roblox docs, as of October 2026). Colour grading and Atmosphere change it again. Two consequences:

- **Do not double the shift.** If your lighting setup already gives cool blue shadows (a blue OutdoorAmbient, a strong sky), a palette with a 25-degree blue shadow shift will look purple in shade. Use the lighter end of the table (about 10 degrees) and let the lighting do the rest.
- **Flat lighting needs the palette to work harder.** Games that run a bright, flat look (high ambient, low shadow contrast, often the `Soft` style; see [[Lighting Technologies and Settings]]) get very little plane separation from the engine. There the palette's value steps carry the whole form, and the full shift is safe.

Test palettes in the actual lighting of each zone, at the lowest and highest graphics quality, on a phone. A ramp that reads in Studio's default lighting can collapse when a zone's colour correction desaturates it.

## 4. Value first, hue second

Hue shifting is the flavour; value is the structure. Two checks catch most palette failures:

1. **Greyscale check.** Desaturate a screenshot (or set a temporary `ColorCorrectionEffect` with `Saturation = -1`). Each ramp's three steps should still be clearly different greys, and the player, enemies and pickups should be clearly separated from the ground by value. If they are not, no amount of hue will save them, and colour-blind players will suffer first (see [[Colour-Blind Safe Design]]).
2. **Neighbour check.** The darkest step of a ramp should not equal any other ramp's darkest step within a few points of value, unless those materials are meant to merge visually.

A useful structure is to give the whole game a **value plan**: ground in the middle values, characters and interactables lighter or darker than the ground by at least 20 points, sky at the light end, and Neon glow reserved for the top of the range.

## 5. Use a perceptual colour space for the maths

HSV is fine for picking hue rotations, but its "value" is not how bright a colour looks. A pure yellow and a pure blue both have HSV value 100, yet yellow looks far brighter. If you generate ramps by stepping HSV value, the blue ramp's steps will look bigger than the yellow ramp's.

**OKLab** (and its polar form OKLCH, lightness, chroma, hue) is a modern perceptual space designed so equal numeric steps look like roughly equal visual steps. Use it for two jobs:

- **Generating ramps**: step lightness L by a fixed amount (0.10 to 0.15 per step works well) and rotate hue in LCH.
- **Measuring distance**: when snapping arbitrary colours to a palette, Euclidean distance in OKLab finds the colour that looks closest; distance in RGB often picks a colour with the wrong lightness.

## 6. How big should the palette be?

**Tool limits.** MagicaVoxel stores 256 palette entries with index 0 meaning empty, so 255 colours per file (file format specification). Goxel stores 24-bit RGB per voxel. Roblox has no palette limit: a Part's `Color` and a MeshPart's `Color` are arbitrary `Color3` values, and vertex colours are arbitrary too.

**Practical limits** are set by consistency and merging, not tools (rules of thumb):

| Scope | Size | Notes |
|---|---|---|
| One prop | 2 to 4 ramps, 6 to 12 colours | More than that and it stops reading as one object |
| One character | 4 to 6 ramps plus eyes and accent, 12 to 20 colours | Skin, two cloth ramps, hair, trim, eyes |
| One zone | 32 to 48 colours | A zone palette is a subset of the game palette plus a few zone-only accents |
| Whole game | 96 to 200 colours | Shared neutrals and skin ramps; zone ramps on top |

**Why exact equality matters.** Every merge step in this section treats two colours as "the same" only if they are bit-for-bit equal. The greedy Part merge in [[Voxel Art - Studs Outlines and Style Kits]] compares `Color3` values with `==`; the Blender per-colour split groups by exact palette index or exact RGB; greedy meshing only joins faces of equal colour. A model painted with 40 slightly different greens will produce many times the parts or triangles of the same model painted with 3 greens. Quantise to the palette before meshing, every time.

There is a subtle Roblox trap here. `Color3` stores floats, but the Properties window shows and edits 0 to 255 integers. A colour set by script with `Color3.new(0.5, 0.5, 0.5)` and one set as `Color3.fromRGB(128, 128, 128)` look the same in the Properties window and are not equal (0.5 versus 128 / 255 = 0.50196). Build palettes with `Color3.fromRGB` integers only, and compare by rounded RGB, as the quantiser below does.

## 7. Laying out the palette for cheap recolours

The order of colours in the palette is a tool, not an accident.

- **Ramps in fixed slots.** Slots 1 to 3 are the primary material ramp, 4 to 6 the secondary, 7 to 9 trim, 10 eyes, 11 to 12 accents. Every model in a set uses the same slots for the same roles.
- **Recolour by palette swap.** In MagicaVoxel, a recoloured variant is the same model with a different palette loaded. In a palette-texture pipeline, a recolour is a different palette image on the same mesh. In a one-mesh-per-colour pipeline, a recolour is a table of role colours applied by script to MeshParts named by role (`Body`, `Trim`, `Eyes`).
- **Shared neutrals at the end.** Blacks, whites, greys and skin ramps that every zone shares sit in reserved slots so a zone swap never touches them.

A role table in Luau keeps the whole thing data-driven:

```lua
--!strict
-- Role-based palettes: a model's MeshParts are named by role; a palette maps role -> colour.
export type Palette = { [string]: Color3 }

local Palettes: { [string]: Palette } = {
	Forest = {
		Body = Color3.fromRGB(86, 150, 70),
		BodyShadow = Color3.fromRGB(40, 92, 78),
		BodyLit = Color3.fromRGB(160, 196, 88),
		Trim = Color3.fromRGB(122, 84, 52),
		Eyes = Color3.fromRGB(255, 244, 214),
	},
	Ice = {
		Body = Color3.fromRGB(120, 180, 220),
		BodyShadow = Color3.fromRGB(70, 96, 170),
		BodyLit = Color3.fromRGB(206, 236, 246),
		Trim = Color3.fromRGB(230, 236, 244),
		Eyes = Color3.fromRGB(255, 220, 120),
	},
}

local function applyPalette(model: Model, paletteName: string)
	local palette = Palettes[paletteName]
	assert(palette, `unknown palette {paletteName}`)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local c = palette[d.Name]
			if c then
				d.Color = c
			end
		end
	end
end

return { Palettes = Palettes, applyPalette = applyPalette }
```

Note the shadow colours: the forest green's shadow is rotated towards blue-green and is more saturated than a straight darkening would give; the ice shadow rotates towards violet-blue; both lit steps lean towards yellow-white.

## 8. Generating a hue-shifted ramp in Luau

For quick iteration in Studio, a generator that follows the table in section 2. It works in HSV because Roblox provides `Color3:ToHSV()` and `Color3.fromHSV()`; for perceptual lightness steps, do the same in OKLCH in an external tool.

```lua
--!strict
-- Build a three-step hue-shifted ramp from a body colour.
-- Hue rotates toward COOL in shadow and toward WARM in light, by the shorter way round.
local COOL = 250 / 360   -- blue-violet
local WARM = 55 / 360    -- yellow

local function rotateToward(h: number, target: number, amount: number): number
	-- amount in turns (0..1). Move h toward target the shorter way, but not past it.
	local diff = ((target - h + 0.5) % 1) - 0.5
	local step = math.sign(diff) * math.min(math.abs(diff), amount)
	return (h + step) % 1
end

local function ramp(body: Color3, shift: number?): (Color3, Color3, Color3)
	local s = shift or 18 / 360
	local h, sat, v = body:ToHSV()
	local shadow = Color3.fromHSV(rotateToward(h, COOL, s), math.min(1, sat + 0.08), math.max(0, v - 0.25))
	local lit = Color3.fromHSV(rotateToward(h, WARM, s * 0.8), math.max(0, sat - 0.10), math.min(1, v + 0.15))
	return shadow, body, lit
end

return ramp
```

Run every generated colour through `Color3.fromRGB(math.round(c.R * 255), ...)` before saving it into a palette table, for the equality reason in section 6.

## 9. Snapping a messy build onto a palette (OKLab quantiser)

When you inherit a Part build with hundreds of near-identical colours, snap every part to the nearest palette colour in OKLab before merging. The conversion follows the published OKLab definition (linear sRGB to LMS, cube root, then to Lab).

```lua
--!strict
-- Quantise every BasePart under a root to the nearest colour of a palette, by OKLab distance.
type Lab = { L: number, a: number, b: number }

local function toLinear(c: number): number
	return if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

local function toOklab(col: Color3): Lab
	local r, g, b = toLinear(col.R), toLinear(col.G), toLinear(col.B)
	local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
	local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
	local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
	l, m, s = l ^ (1 / 3), m ^ (1 / 3), s ^ (1 / 3)  -- inputs are non-negative
	return {
		L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
	}
end

local function quantise(root: Instance, palette: { Color3 }): number
	local labs: { Lab } = {}
	for i, c in palette do
		labs[i] = toOklab(c)
	end
	local changed = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local p = toOklab(d.Color)
			local best, bestDist = 1, math.huge
			for i, q in labs do
				local dist = (p.L - q.L) ^ 2 + (p.a - q.a) ^ 2 + (p.b - q.b) ^ 2
				if dist < bestDist then
					best, bestDist = i, dist
				end
			end
			if d.Color ~= palette[best] then
				d.Color = palette[best]
				changed += 1
			end
		end
	end
	return changed
end

return quantise
```

Run it inside a ChangeHistoryService recording if you use it as a plugin, so the snap is undoable (see [[Undo and ChangeHistoryService Done Right]]). For a visual check, quantise a copy and compare side by side; if a colour snapped to the wrong ramp, the palette is missing a step, not the quantiser.

## 10. Worked example: a forest zone palette

1. **Value plan.** Ground in the middle, foliage slightly darker than ground, paths lighter, player gear brighter than everything except Neon.
2. **Pick five body colours**: grass green, leaf green, bark brown, stone grey-blue, path sand.
3. **Generate ramps** with an 18-degree shift (forest lighting here uses a neutral ambient, so the full shift is safe). Check in OKLab that each ramp's lightness steps are 0.10 to 0.15 apart.
4. **Greyscale check** in Studio with a temporary `ColorCorrectionEffect` at `Saturation = -1`. Here, leaf shadow and bark shadow came out within a few points of each other; darken bark by one step so tree trunks separate from canopy undersides.
5. **Add two accents** (a flower pink, a mushroom red) and the shared neutrals. Total: 15 ramp colours, 2 accents, 6 shared neutrals: 23 colours for the zone.
6. **Export the palette** as a MagicaVoxel palette image and as a Luau role table; load it in every tool ([[MagicaVoxel Goxel and Blockbench Workflows Compared]]).
7. **Test at night and dusk** if the zone has a day cycle: the shadow step must not go black under a dark ambient.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Shadows look grey and dirty | Ramp mixed straight towards black | Rotate shadow hue towards blue or violet; keep or raise saturation |
| Highlights look chalky | Mixed straight towards white | Rotate towards yellow; drop saturation only slightly |
| Shadows look purple in game | Palette shift doubled by a blue ambient or sky | Smaller shift (about 10 degrees) for that lighting |
| Greedy merge barely reduces parts | Near-identical colours, or float colours that differ invisibly | Quantise to a `Color3.fromRGB` palette before merging |
| Characters vanish against the ground | Similar values despite different hues | Greyscale check; separate by at least 20 points of value |
| Blue ramp steps look bigger than yellow ramp steps | Steps made in HSV value | Step lightness in OKLab or OKLCH |
| Every model looks slightly off-set | Each artist invented colours | One game palette, role slots, palette files loaded in every tool |

## Checklist

- [ ] Game value plan written: ground, characters, interactables, sky, glow.
- [ ] Three steps per material by default; four only on large close surfaces.
- [ ] Hue shift tuned to each zone's lighting; tested at low and high quality on a phone.
- [ ] Greyscale check passed; colour-blind check done for gameplay-critical colours.
- [ ] Palette built from `Color3.fromRGB` integers; exact equality preserved.
- [ ] Role slots fixed across tools; recolours are palette or role-table swaps.
- [ ] Builds quantised before any merge or meshing pass.

## Related

[[Voxel and Blocky Modeling]] · [[Voxel Art - Studs Outlines and Style Kits]] · [[Environment Art Styles]] · [[Zone and Biome Art Direction]] · [[Colour-Blind Safe Design]] · [[Lighting Technologies and Settings]] · [[Stylized Lighting Recipes]] · [[Trim Sheets Atlases and Vertex Colors]] · [[Undo and ChangeHistoryService Done Right]] · [[Voxel Shading - Baked AO Edges and Lighting]] · [[MagicaVoxel Goxel and Blockbench Workflows Compared]]

## Connected notes
<!-- auto-links:start -->
[[Colour Scripts and Value Structure for Untextured Art]] · [[Voxel Modelling Start Here]] · [[The Gradient Palette Texture Workflow]] · [[Lighting Untextured Art in Roblox]] · [[Untextured Stylised Modelling Start Here]] · [[Hand-Painted and Stylized Texturing]]
<!-- auto-links:end -->
