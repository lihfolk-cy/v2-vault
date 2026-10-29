---
tags: [art-direction, untextured, stylised, colour, value, palette, colour-script, readability, luau, type/guide, area/modeling, level/intermediate]
---
# Colour Scripts and Value Structure for Untextured Art

<!-- tldr:start -->
> [!tldr] TL;DR
> - Zone looks muddy though each colour is pretty: No value structure; everything mid-value -> Plan 3 to 5 value bands; check in greyscale
> - Players cannot find the chest or the exit: Interactables share a value band with scenery -> Reserve the lightest band or a saturation spike for interactables
> - Second zone feels like more of the first: Neighbouring zones share hue, value key and saturation -> Change at least two of the three; check the colour script row
> - Colour script row made: one thumbnail per zone, in play order, with key light, shadow hue, dominant, accent, value key.
> - Neighbouring zones differ in at least two of hue, value key, saturation; the hub is distinct.
> - Each zone has 3 to 5 value bands with roles assigned; about 60/30/10 by area.
>
> Cost: TL;DR ~230 tok · whole note ~4.0k tok. Read more: ## Value first, hue second · ## Building a colour script for a Roblox game · ## Common mistakes · ## Checklist
<!-- tldr:end -->

When art has no painted texture, its colour choices are its entire surface. A flat-coloured world lives or dies on two things: **value structure** (how light or dark each thing is relative to everything else) and **colour planning across the game** (how palettes change from zone to zone so the journey feels designed). Film studios plan the second with a **colour script**: a strip of small, rough images showing the colour and light of every sequence in order. Pixar's colour scripts, published in "The Art of Pixar" and discussed by production designer Lou Romano in public interviews, exist mostly to set "the emotional tone of each scene" with abstract shapes and colour rather than detail. Game zones are sequences too.

[[Environment Art Styles]] gives a palette derivation table, [[Zone and Biome Art Direction]] covers per-zone art direction, and [[Stylized Lighting Recipes]] gives the lighting side. This note is the planning layer for untextured art specifically: value groups and what to put in each, how Roblox lighting moves values after you pick them, building a colour script for a multi-zone Roblox game, palette sizes, and a Studio greyscale workflow with a Luau value audit.

## Value first, hue second

The eye reads value (lightness) before hue. A flat-coloured scene with good values works in greyscale; one with bad values looks muddy in full colour no matter how nice each hue is. Rule of thumb from illustration and film practice:

- **3 to 5 value groups** per view, each a clear band: for example darkest (shadow shapes, deep background), dark-mid (ground, large structures), mid (props, walls), light-mid (paths, lit tops), lightest (focal points, interactables, sky near the horizon).
- **Area ratio about 60 / 30 / 10.** One value group dominates the frame, a second supports it, and a small one (usually the lightest or the most saturated) marks where to look. Equal areas of every value read as noise.
- **Group things by role, not by object.** All walkable ground in one band, all background structures in another. A single rock that is much lighter than the rest of the ground reads as "interactable" whether you intended it or not.

### Roles and value bands for a Roblox playfield

| Role | Value band (HSV value, 0 to 100, under game lighting) | Saturation | Notes |
|---|---|---|---|
| Far background, skyline, distant cliffs | Close to the sky value, low contrast | Low | Atmosphere pushes these toward the haze colour anyway |
| Ground and floors | Mid to dark-mid (35 to 60) | Low to medium | The largest area; must not compete with avatars |
| Walls and big structures | One band away from the ground (lighter or darker) | Medium | Separation from ground is what makes the layout readable |
| Props and dressing | Within the structure band, varied by hue | Medium | Detail lives here; keep it inside the band |
| Interactables (doors, chests, pickups, buttons) | Lightest band, or a saturation spike | High | The 10 percent; nothing else should share it |
| Characters and enemies | Separated from the ground by at least one band | High on enemies | Silhouette plus value contrast |
| VFX and glows | Above everything (Neon, bloom) | High | Keep glow area small ([[Environment Art Styles]] gives coverage budgets) |

(Values are rule of thumb planning numbers measured as the colour on screen, not the `Color` property value; lighting changes them, see below.)

### The avatar problem

Roblox players wear anything: black outfits, white outfits, neon green. You cannot value-plan them. Two consequences:

1. **Keep the ground and main structures mid-value and moderately saturated**, so both very dark and very light avatars separate from it. A pure white floor loses white avatars; a near-black floor loses black outfits.
2. **Do not use avatar-like colours for interactables.** If the "collect this" orb is the same bright cyan many avatars wear, it stops reading as special. Use shape and glow (Neon, a `Highlight`, motion) as well as colour ([[Highlights and Selection Effects]]).

## How Roblox lighting moves your values

A `Color3` you pick is not the value players see. Lighting multiplies and adds:

- **Sun-facing faces** get `Brightness`-scaled direct light tinted by `ColorShift_Top`; shadowed faces get `Ambient` or `OutdoorAmbient` (and `ColorShift_Bottom`); see [[Lighting Technologies and Settings]].
- **Bloom** lifts light colours and Neon further.
- **`ColorCorrectionEffect`** shifts everything at the end.
- **`Atmosphere`** blends distant objects toward its colour, compressing far values.

So the same mid-grey part can be value 75 on its sunny side and 35 in shadow. Practical rules:

- **Pick colours under the game's lighting, never in a colour picker.** Sample the rendered result.
- **Design the sun-to-shadow ratio once, globally.** If ambient is very bright, every object's two sides collapse to one value and form disappears; if ambient is very dark, shadows swallow detail on phones. A sunny side about 1.5 to 2.5 times brighter than the shadow side is a readable stylised range (rule of thumb).
- **Flat colours do not have built-in shading.** Unlike painted textures, they get all their light-and-dark from the engine. A gradient palette or vertex-colour gradient adds a second, lighting-independent value step ([[The Gradient Palette Texture Workflow]]).

## Hue shifting and ramps

A ramp is the set of values one colour takes from shadow to light. Flat-coloured art usually needs ramps in two places: gradient atlas strips, and parts that are deliberately darker or lighter variants (a dark trim on a light wall).

- **Shift hue with value.** Shadows move toward the scene's shadow hue (often blue or purple outdoors, a deep warm tone indoors by firelight); lights move toward the light colour (warm yellow in sunlight, cool blue under moonlight). A ramp that only changes value looks grey and dead in the shadows.
- **Typical shift:** 10 to 25 degrees of hue across the ramp, saturation peaking in the mid-tones and dropping a little at both ends (rule of thumb from [[pixel art]] and illustration practice).
- **Avoid pure black and pure white** in the environment. Reserve them for UI, eyes and special effects. Pure black shadows on a phone in daylight are just holes.

Voxel-specific ramps and palette limits are covered in depth by the voxel section; the principles here apply to every untextured style.

## Building a colour script for a Roblox game

A game with zones (worlds, biomes, floors, levels) has a sequence players experience in order, usually with rising stakes. A colour script makes that sequence deliberate.

### Steps

1. **List zones in play order**, with one emotional word each: "safe", "curious", "eerie", "hostile", "triumphant".
2. **Make one tiny thumbnail per zone**, about 200 x 120 px, using only big flat shapes: sky band, ground band, one structure, one focal glow. No detail. Paint in any tool, or block it out in Studio with Parts and screenshot it.
3. **Assign each zone:** a key light colour, a shadow hue, a dominant hue for structures, one accent hue, and a value key (high key = mostly light values, low key = mostly dark).
4. **Lay the thumbnails in a row** and look at the sequence, not the frames. Check:
   - Neighbouring zones differ in at least two of: dominant hue, value key, saturation. If two adjacent zones are both "mid-value green", the second will feel like more of the first.
   - The sequence has a shape: for example bright and warm at the start, cooling and darkening through the middle, a high-saturation climax, a calm return to the hub.
   - Your hub's colours are distinct from every zone, so returning there feels like home.
5. **Lock it.** The thumbnails become the reference for every zone's palette, lighting preset and atmosphere. Store them in the style sheet ([[Keeping a Mixed Asset Library Consistent]]).

### Example: a five-zone adventure (generic)

| Zone | Word | Key light | Shadow hue | Dominant | Accent | Value key |
|---|---|---|---|---|---|---|
| Meadow | Safe | Warm white | Soft blue | Yellow-green | Red flowers | High |
| Forest | Curious | Warm, filtered | Teal | Deep green | Mushroom orange | Mid |
| Swamp | Eerie | Sickly green-yellow | Purple | Olive, brown | Firefly cyan | Low-mid |
| Volcano | Hostile | Orange | Deep red-brown | Charcoal | Lava yellow | Low, high contrast |
| Sky temple | Triumphant | Cool white | Lavender | White-gold | Turquoise | High |

Notice the alternation: high, mid, low, low with high contrast, high. Neighbours never share a dominant hue. The accent is always complementary or near-complementary to the dominant, so focal points pop without needing more saturation everywhere.

### Public references worth studying

Described from public material only, as examples of the principle:

- **Monument Valley** (ustwo games): flat colour, gradients and lighting baked into colour, a distinct palette per chapter. Almost no texture.
- **Alto's Adventure** (Snowman): one landscape, transformed by time-of-day colour scripts into very different moods.
- **Firewatch** (Campo Santo, art by Olly Moss and team): large flat colour shapes and strong atmospheric value bands.
- **Bright simulator-style Roblox games** (pet and collection simulators): very high value key, saturated flat colours, each world a new dominant hue, which keeps a long progression feeling fresh on small screens.

## Palette size

How many colours should an untextured game use? Rule of thumb ranges:

| Scope | Colours | Notes |
|---|---|---|
| Shared base (UI-adjacent, trims, neutrals, metals) | 12 to 20 | Used in every zone |
| Per zone | 8 to 16 | Dominant ramps, shadow hue, accents |
| Per prop | 2 to 4 | More than 4 reads as busy at Roblox camera distances |
| Whole game | 60 to 120 | Including all ramps; fewer is easier to keep consistent |

A gradient atlas strip is one "colour" in this count. Small palettes are not a limit to fight; they are the reason flat art looks coherent.

## Greyscale checks in Studio

`ColorCorrectionEffect` with `Saturation = -1` gives full desaturation (Roblox docs, as of October 2026: values move toward "full desaturation" at -1). Put one in `Lighting` (or in the camera for a single client) and toggle it while you build.

What to look for in greyscale:

- Can you tell ground from walls from props without hue?
- Are interactables still the lightest or most contrasting thing in view?
- Do characters separate from the floor?
- Are there accidental "focal points" (a light rock, a pale sign) that pull the eye?

Also run a colour-blind pass; values do most of the work for colour-blind players, which is another reason to plan them first ([[Colour-Blind Safe Design]]).

## A Luau value audit

The greyscale toggle shows the rendered result. This Command Bar script complements it by checking the authored colours: it computes a perceived lightness for every BasePart's `Color` under a model and buckets them, so you can see whether the zone really has 3 to 5 value groups and where the outliers are. It ignores textures and lighting, so treat it as a first pass.

```lua
--!strict
-- Edit-time value audit: bucket part colours by perceived lightness.
-- Uses Rec. 601 luma weights on sRGB values, a common quick approximation.
local root = workspace:FindFirstChild("SwampZone")
assert(root, "zone not found")

local BUCKETS = 5
local counts = table.create(BUCKETS, 0)
local areaByBucket = table.create(BUCKETS, 0)
local outliers: {BasePart} = {}

local function luma(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B   -- 0 to 1
end

for _, d in root:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 then
		local v = luma(d.Color)
		local b = math.clamp(math.floor(v * BUCKETS) + 1, 1, BUCKETS)
		counts[b] += 1
		local s = d.Size
		-- Rough visible area: the two largest faces of the bounding box.
		local faces = {s.X * s.Y, s.Y * s.Z, s.X * s.Z}
		table.sort(faces)
		areaByBucket[b] += faces[2] + faces[3]
		if v > 0.85 and not d:IsA("MeshPart") then
			table.insert(outliers, d)   -- very light Parts: accidental focal points?
		end
	end
end

local totalArea = 0
for _, a in areaByBucket do totalArea += a end
for b = 1, BUCKETS do
	local pct = if totalArea > 0 then 100 * areaByBucket[b] / totalArea else 0
	print(string.format("value %.1f to %.1f: %4d parts, %5.1f%% of area",
		(b - 1) / BUCKETS, b / BUCKETS, counts[b], pct))
end
print("very light Parts to review:", #outliers)
```

Reading the output: if one bucket holds about 60 percent of the area and the lightest bucket holds 5 to 10 percent, the structure is healthy. If area is spread evenly over all five, the zone will read as noisy. If the lightest bucket is large, the focal band has been spent on scenery.

## When not to follow these rules

- **Horror and stealth games** deliberately break the 60/30/10 rule with huge dark areas and tiny lit pools; value structure still matters, the ratio changes.
- **Player-built worlds** (building games, sandbox) cannot control values; design the default materials and the lighting instead.
- **Competitive games** may prefer flat, evenly lit maps over mood so that players are always visible; readability beats the colour script there.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Zone looks muddy though each colour is pretty | No value structure; everything mid-value | Plan 3 to 5 value bands; check in greyscale |
| Players cannot find the chest or the exit | Interactables share a value band with scenery | Reserve the lightest band or a saturation spike for interactables |
| Second zone feels like more of the first | Neighbouring zones share hue, value key and saturation | Change at least two of the three; check the colour script row |
| Colours picked in Studio's picker look wrong in game | Lighting, bloom and grading change values | Sample colours under the game's lighting |
| Dead grey shadows | Ramps change value only | Shift hue 10 to 25 degrees across ramps |
| Avatars vanish against the floor | Floor very light or very dark | Mid-value, moderately saturated ground |
| Palette creep over months | No palette size limit or base palette | Shared base plus per-zone palettes, written down |

## Checklist

- [ ] Colour script row made: one thumbnail per zone, in play order, with key light, shadow hue, dominant, accent, value key.
- [ ] Neighbouring zones differ in at least two of hue, value key, saturation; the hub is distinct.
- [ ] Each zone has 3 to 5 value bands with roles assigned; about 60/30/10 by area.
- [ ] Interactables own the lightest band or a saturation spike.
- [ ] Ramps shift hue; no pure black or white in the environment.
- [ ] Palette sizes written: base, per zone, per prop.
- [ ] Greyscale (`Saturation = -1`) and colour-blind checks done in Studio under the game's lighting.

## Related

- [[Environment Art Styles]]
- [[Zone and Biome Art Direction]]
- [[Stylized Lighting Recipes]]
- [[Lighting Untextured Art in Roblox]]
- [[The Gradient Palette Texture Workflow]]
- [[Keeping a Mixed Asset Library Consistent]]
- [[Colour-Blind Safe Design]]
- [[Highlights and Selection Effects]]
- [[Atmosphere Sky Clouds and Post-Processing]]
- [[Shape Language and Silhouette Testing]]
- [[Untextured Stylised Modelling Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Voxel Palettes - Ramps Hue Shifting and Limits]] · Thumbnail Contrast · Hand-Painted and Stylized Texturing · Voxel and Blocky Modeling · Voxel Shading - Baked AO Edges and Lighting · Lighting Mood and Time of Day
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Flat Colour vs Gradient Atlas vs Vertex Colour]] · [[Hand-Painted and Stylized Texturing]] · [[Lighting Mood and Time of Day]] · [[Voxel and Blocky Modeling]] · [[Faceted Low-Poly - Flat Normals and Facet Size]] · [[Clean Stylised Shading - Weighted and Custom Normals]]
<!-- related:end -->
