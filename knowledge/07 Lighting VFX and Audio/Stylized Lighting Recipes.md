---
tags: [lighting, stylized, recipes, mood, post-processing, atmosphere, art-direction]
---
# Stylized Lighting Recipes

The other lighting notes explain the machinery: [[Lighting Technologies and Settings]] for every global property and its trap, [[Atmosphere Sky Clouds and Post-Processing]] for air, sky and screen effects, [[Light Sources and Shadows]] for local lights, and [[Lighting Mood and Time of Day]] for clocks and zone blending. This note is the cookbook: complete, numbered starting points for the stylised looks Roblox games actually ship (bright cartoon, toon arena, golden hour, readable night, neon city, fog horror, underwater, crystal cave, lava, frost, void), the reasoning behind each number, and the ways each recipe breaks.

Every number here is a **rule of thumb** starting point unless labelled otherwise. Lighting is relative: your materials, colours and camera change the result, so treat each recipe as the first draft you then tune by eye on a phone and a PC. Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. What makes lighting "stylised"

Realistic lighting tries to simulate light. Stylised lighting tries to **separate shapes and tell the player what matters**. In practice that means:

| Principle | How it shows up in properties |
|---|---|
| Colour does the work shadows would do | A warm `ColorShift_Top` and a cool `Ambient` give every object a lit side and a shadow side, even where shadows are off |
| Few values, clearly separated | Background darker or lighter than the play space; characters and pickups at a value nothing else uses |
| Saturation is a budget | Saturated colours where the player should look; the rest calmer. The grade adds a little, the materials add the rest |
| Specular is usually off | `EnvironmentSpecularScale` low or 0, so plastic stays flat and readable; metal is painted, not reflected |
| Haze for depth, not realism | `Atmosphere` density separates near, middle and far into value bands |
| Bloom is controlled | Threshold chosen so only effects and Neon glow, not white walls |

The most important constraint for Roblox specifically: **shadows turn off entirely below graphics quality level 4** (Roblox docs), and many phones run there. A stylised recipe must still read with no shadows at all. That is why the colour terms (ambient, colour shifts, grade) carry the look in every recipe below, and shadows are a bonus.

Two settings come first, before any recipe:

- **`LightingStyle`**: `Soft` for flat cartoon and low-poly, `Realistic` when local lights and PBR materials matter (night cities, interiors). `Technology` is deprecated and not scriptable (Roblox docs); see [[Lighting Technologies and Settings]].
- **Material style**: flat colour (`SmoothPlastic`) versus textured materials. Recipes for flat colour can push saturation and ambient harder because there is no texture detail to lose. Near-black colours (luminance under about 0.06) hide material textures entirely (measured in the reference project), so dark textured surfaces need a slightly lifted colour.

---

## 2. How to read the recipes

Each recipe gives values for these objects. Anything not listed stays at your project's neutral baseline.

| Group | Properties |
|---|---|
| `Lighting` | `Ambient`, `OutdoorAmbient`, `Brightness`, `ColorShift_Top`, `ColorShift_Bottom`, `EnvironmentDiffuseScale`, `EnvironmentSpecularScale`, `ExposureCompensation`, `ClockTime`, `GeographicLatitude` |
| `Atmosphere` | `Density`, `Offset`, `Color`, `Decay`, `Glare`, `Haze` |
| `BloomEffect` | `Intensity`, `Size`, `Threshold` |
| `ColorCorrectionEffect` | `Brightness`, `Contrast`, `Saturation`, `TintColor` |
| `SunRaysEffect` | `Intensity`, `Spread` (only when the sun is in the composition) |

Colours are written as RGB 0 to 255. Remember the docs' clamping rule: `OutdoorAmbient` is held at least as bright as `Ambient` per channel, and if `Ambient` exceeds `OutdoorAmbient` it starts to apply outdoors too. When `GlobalShadows` is off, only `Ambient` applies. And `Fog*` properties are ignored while an `Atmosphere` exists (Roblox docs).

---

## 3. The recipes

### 3.1 Bright cartoon (simulators, tycoons, hubs)

The look of most top simulator hubs: saturated flat colours, soft shadows, nothing ever dark.

| Object | Values |
|---|---|
| Style | `Soft`, `GlobalShadows` true |
| Lighting | Ambient (110, 110, 125), OutdoorAmbient (150, 150, 160), Brightness 2.5, ColorShift_Top (255, 240, 215), ColorShift_Bottom (0, 0, 0), EnvironmentDiffuseScale 0.3, EnvironmentSpecularScale 0, ClockTime 13.5 |
| Atmosphere | Density 0.25, Offset 0.1, Color (200, 225, 255), Decay (120, 160, 210), Glare 0, Haze 0.5 |
| Bloom | Intensity 0.5, Size 24, Threshold 1.2 |
| Grade | Brightness 0.02, Contrast 0.08, Saturation 0.15, Tint white |

Why: high outdoor ambient means shadowed sides are never darker than mid-value, which is what makes it read as "cartoon". The warm top shift gives a lit side. Specular 0 keeps plastic flat. Threshold above 1 stops white UI-coloured parts from glowing.

Materials matter more than lighting here. The reference project converted its hub to this style by changing walls and grass to `SmoothPlastic` with bright flat colours (grass about (74, 202, 70), earth about (204, 112, 60), darker earth bands about (178, 94, 50)) and adding proud slabs and a bullnose lip on cliff tops. The light did not change much; the palette and the bevels did. See [[Environment Art Styles]].

Breaks when: you add realistic PBR props (they look grey and out of place under specular 0), or a zone needs to feel dangerous (this recipe cannot be scary; switch recipe, do not darken it).

### 3.2 Toon arena (combat with heavy effects)

Combat needs the opposite of a bright hub: a calmer, slightly darker world so effects and characters pop.

| Object | Values |
|---|---|
| Style | `Soft` or `Realistic`, `GlobalShadows` true |
| Lighting | Ambient (70, 70, 85), OutdoorAmbient (100, 100, 115), Brightness 2, ColorShift_Top (255, 225, 190), EnvironmentDiffuseScale 0.2, EnvironmentSpecularScale 0.1, ClockTime 16 |
| Atmosphere | Density 0.3, Offset 0.15, Color (180, 190, 210), Decay (90, 100, 130), Haze 1 |
| Bloom | Intensity 1, Size 40, Threshold 1.6 |
| Grade | Contrast 0.12, Saturation -0.05 |

Why: environment saturation slightly below zero leaves saturation for effects. Bloom threshold around 1.5 to 2 means only over-bright effect particles (Brightness well above 1, `LightInfluence` 0) glow; [[Atmosphere Sky Clouds and Post-Processing]] covers why. One studied professional VFX pack set bloom to Intensity 1.6, Size 56, Threshold 2 (measured in the reference project's study) and tuned all its flashes against that.

Breaks when: the arena is also a dark zone. The reference project's stylised effect set, designed in daylight, nearly vanished in its dark zones and had to be rebaked brighter (emissive raised from 1.1 to 1.9, a small coloured light on large pieces). Test every effect in the darkest arena, not only this one.

### 3.3 Golden hour

The cheapest "beautiful" look there is.

| Object | Values |
|---|---|
| Lighting | ClockTime 17.6, GeographicLatitude 30, Ambient (90, 70, 70), OutdoorAmbient (130, 100, 90), Brightness 2.2, ColorShift_Top (255, 190, 120), ColorShift_Bottom (60, 40, 80), EnvironmentDiffuseScale 0.4 |
| Atmosphere | Density 0.35, Offset 0.2, Color (255, 200, 160), Decay (200, 120, 110), Glare 0.4, Haze 1.5 |
| Bloom | Intensity 0.7, Size 32, Threshold 1.1 |
| Grade | Contrast 0.1, Saturation 0.1, TintColor (255, 245, 235) |
| Sun rays | Intensity 0.06, Spread 0.6 |

Why: a low sun and long shadows, warm top, purple bottom shift (complementary), warm haze with `Glare` for the sun halo. Sun rays only help when the sun is on screen; otherwise they cost and do nothing.

Breaks when: players face away from the sun (everything is back-lit and muddy). Pick `ClockTime` and the map layout so the main play direction looks across the light, not into or away from it. Also: on quality levels without shadows, the long shadows vanish and the look collapses to "orange". The colour shift has to carry it.

### 3.4 Readable night

Night is where most stylised games fail: realistic night is black, and black is unplayable.

| Object | Values |
|---|---|
| Lighting | ClockTime 0, Ambient (60, 70, 110), OutdoorAmbient (80, 95, 140), Brightness 0.6, ColorShift_Top (150, 170, 255), EnvironmentDiffuseScale 0.2, ExposureCompensation 0.2 |
| Atmosphere | Density 0.3, Offset 0, Color (60, 75, 120), Decay (30, 35, 70), Haze 0.5 |
| Bloom | Intensity 0.8, Size 30, Threshold 0.95 |
| Grade | Contrast 0.1, Saturation -0.1, TintColor (220, 230, 255) |

Why: night is shown by **hue** (blue), **lower saturation** and **lit windows**, not by darkness. Ambient stays around a third of full brightness so silhouettes read. Bloom threshold drops so lanterns and Neon glow, which is the payoff of night. [[Lighting Mood and Time of Day]] says "night must still be playable"; this is how.

Breaks when: you lower `Ambient` further for drama. Check a screenshot in greyscale: if the player character and the ground are within about 10 percent value of each other, it is too dark.

### 3.5 Neon city

| Object | Values |
|---|---|
| Style | `Realistic` (local lights matter) |
| Lighting | ClockTime 22, Ambient (40, 30, 60), OutdoorAmbient (60, 45, 90), Brightness 0.4, EnvironmentDiffuseScale 0.2, EnvironmentSpecularScale 0.6 |
| Atmosphere | Density 0.4, Offset 0, Color (90, 50, 120), Decay (40, 20, 80), Haze 2 |
| Bloom | Intensity 1.2, Size 36, Threshold 0.9 |
| Grade | Contrast 0.15, Saturation 0.2, TintColor (240, 225, 255) |

Why: dark purple base, high specular so wet-looking floors catch Neon signs, low bloom threshold so Neon glows. Here the Neon parts *are* the lighting. Haze 2 makes distant signs bleed into colour fields.

Breaks when: every surface is Neon (it becomes a flat glowing mess and bloom washes shapes out; one style study capped glow at about 16 percent of an object's pixels). Also expensive: many local lights. Fake most "light pools" with Neon decals or transparent coloured parts and keep real lights to a handful near the play space, shadows off ([[Light Sources and Shadows]]).

### 3.6 Fog horror

| Object | Values |
|---|---|
| Style | `Realistic` |
| Lighting | ClockTime 20.5, Ambient (35, 35, 40), OutdoorAmbient (55, 55, 60), Brightness 0.5, EnvironmentDiffuseScale 0.1 |
| Atmosphere | Density 0.55, Offset 0, Color (120, 125, 130), Decay (70, 75, 80), Haze 2.5 |
| Bloom | Intensity 0.3, Size 20, Threshold 1.5 |
| Grade | Contrast 0.05, Saturation -0.45, TintColor (235, 245, 240) |

Why: heavy desaturation, flat fog that hides the far distance (and saves rendering), one warm light source the player carries or follows. Horror is about what you cannot see, which is also what you do not have to model.

Breaks when: fog density is pushed until the near field disappears. Roblox's atmosphere is distance-based; at very high density the skybox can ghost through distant geometry (see [[Atmosphere Sky Clouds and Post-Processing]]). And keep gameplay readable: the threat must be readable at a distance the player can react to. See [[Genre Playbook - Horror and Story]].

### 3.7 Underwater

| Object | Values |
|---|---|
| Lighting | Ambient (40, 90, 110), OutdoorAmbient (60, 130, 150), Brightness 1.2, ColorShift_Top (120, 220, 230) |
| Atmosphere | Density 0.6, Offset 0, Color (40, 140, 160), Decay (10, 60, 90), Haze 0 |
| Bloom | Intensity 0.6, Size 40, Threshold 1 |
| Grade | Saturation -0.1, TintColor (200, 240, 245), Contrast 0.05 |
| Extras | Moving caustic texture on the floor, rising bubble particles, a low-pass on audio |

Why: water absorbs red first, so the tint removes it; density gives a short, coloured view distance. The reference project's underwater zones used per-area moods, caustics and floating creatures on top of this kind of base.

Breaks when: you fill a large area with real terrain water to get the look. In the reference project a 5,000 by 1,900 stud terrain sea stalled joins; it was replaced by a flat part surface and a lighting mood. Fake it.

### 3.8 Crystal cave

| Object | Values |
|---|---|
| Lighting | Ambient (50, 40, 80), OutdoorAmbient (60, 50, 90), Brightness 0.3, EnvironmentSpecularScale 0.8, ExposureCompensation 0.3 |
| Atmosphere | Density 0.45, Color (90, 70, 140), Decay (40, 30, 80), Haze 1 |
| Bloom | Intensity 1, Size 30, Threshold 0.9 |
| Grade | Saturation 0.2, Contrast 0.12 |

Why: crystals are the light source (Neon or glass with high specular), the walls are dark and cool, saturation is up because the palette is limited to two hues. `ExposureCompensation` lifts the whole set without changing ratios, which is exactly the "dim interior set" case the docs describe for it.

### 3.9 Lava and ember

| Object | Values |
|---|---|
| Lighting | Ambient (90, 45, 30), OutdoorAmbient (120, 60, 40), Brightness 1.2, ColorShift_Top (255, 150, 90), ColorShift_Bottom (255, 80, 30) |
| Atmosphere | Density 0.45, Color (180, 90, 60), Decay (110, 40, 30), Glare 0.2, Haze 2 |
| Bloom | Intensity 0.9, Size 36, Threshold 1 |
| Grade | Contrast 0.15, Saturation 0.1, TintColor (255, 235, 220) |

Why: the bottom colour shift is the trick. Lava lights from below, so `ColorShift_Bottom` orange makes every underside glow without a single local light.

Breaks when: fire-coloured effects are used in this zone (they disappear into the background). Give fire effects a white-hot core and a dark rim, or shift their palette.

### 3.10 Frost

| Object | Values |
|---|---|
| Lighting | ClockTime 11, Ambient (120, 135, 160), OutdoorAmbient (160, 175, 200), Brightness 2.5, ColorShift_Top (220, 235, 255), EnvironmentSpecularScale 0.4 |
| Atmosphere | Density 0.35, Color (210, 225, 245), Decay (150, 170, 210), Glare 0.3, Haze 1 |
| Bloom | Intensity 0.5, Size 24, Threshold 1.4 |
| Grade | Saturation -0.2, Contrast 0.08, TintColor (240, 248, 255) |

Why: snow is the brightest surface in any game; keep bloom threshold high so it does not glow. Saturation down for cold. Snow needs blue shadows to read as snow: the cool ambient gives them.

Breaks when: exposure is too high and everything clips to white. Check a greyscale screenshot: snow should be the brightest value but still have shape.

### 3.11 Void

| Object | Values |
|---|---|
| Lighting | Ambient (30, 20, 45), OutdoorAmbient (40, 25, 60), Brightness 0.2 |
| Atmosphere | Density 0.5, Color (40, 20, 60), Decay (10, 0, 20), Haze 3 |
| Bloom | Intensity 1.2, Size 48, Threshold 0.9 |
| Grade | Contrast 0.2, Saturation 0.1, TintColor (230, 215, 255) |

Why: near-black purple base, bright emissive edges on everything that matters. The rule the reference project learned with its "void" effect palette: near-black colour on a near-black zone draws nothing. Its fix was an **inverted treatment**: dark body, bright emissive rim. Apply the same rule to world art here: dark surfaces, glowing outlines and cracks.

---

## 4. Recipes as data

Store recipes as tables and apply them with one function. That makes zone blending, weather overrides and testing simple, and it keeps the values reviewable in one file.

```lua
--!strict
-- LightingRecipes: apply a recipe table to Lighting, Atmosphere and owned post effects.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

export type Recipe = {
	lighting: { [string]: any }?,
	atmosphere: { [string]: any }?,
	bloom: { [string]: any }?,
	grade: { [string]: any }?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Recipes: { [string]: Recipe } = {
	BrightCartoon = {
		lighting = {
			Ambient = rgb(110, 110, 125), OutdoorAmbient = rgb(150, 150, 160),
			Brightness = 2.5, ColorShift_Top = rgb(255, 240, 215),
			EnvironmentDiffuseScale = 0.3, EnvironmentSpecularScale = 0,
		},
		atmosphere = { Density = 0.25, Offset = 0.1, Color = rgb(200, 225, 255), Decay = rgb(120, 160, 210), Glare = 0, Haze = 0.5 },
		bloom = { Intensity = 0.5, Size = 24, Threshold = 1.2 },
		grade = { Brightness = 0.02, Contrast = 0.08, Saturation = 0.15, TintColor = rgb(255, 255, 255) },
	},
	-- More recipes here, one per mood.
}

-- Find or create the objects this module owns. It never touches effects it did not create.
local function owned(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

local function tweenProps(target: Instance, props: { [string]: any }, time: number)
	-- Tween what can be tweened; set the rest (booleans, enums) directly.
	local tweenable: { [string]: any } = {}
	for key, value in props do
		local t = typeof(value)
		if t == "number" or t == "Color3" then
			tweenable[key] = value
		else
			(target :: any)[key] = value
		end
	end
	if time <= 0 then
		for key, value in tweenable do
			(target :: any)[key] = value
		end
	else
		TweenService:Create(target, TweenInfo.new(time, Enum.EasingStyle.Sine), tweenable):Play()
	end
end

local LightingRecipes = {}

function LightingRecipes.apply(name: string, time: number?)
	local recipe = Recipes[name]
	assert(recipe, "Unknown lighting recipe: " .. name)
	local t = time or 0
	if recipe.lighting then
		tweenProps(Lighting, recipe.lighting, t)
	end
	if recipe.atmosphere then
		local atmo: Instance = Lighting:FindFirstChildOfClass("Atmosphere") or owned("Atmosphere", "Atmosphere")
		tweenProps(atmo, recipe.atmosphere, t)
	end
	if recipe.bloom then
		tweenProps(owned("BloomEffect", "RecipeBloom"), recipe.bloom, t)
	end
	if recipe.grade then
		tweenProps(owned("ColorCorrectionEffect", "RecipeGrade"), recipe.grade, t)
	end
end

LightingRecipes.Recipes = Recipes
return LightingRecipes
```

Notes on the code:

- It runs on the **client** when each player can be in a different zone (the "server publishes facts, client renders mood" pattern in [[Lighting Technologies and Settings]]). On the server it would apply one mood to everyone.
- It **owns** its bloom and grade by name and never edits other post effects. Personal effects (low-health tint, ultimate grade) belong in the camera, managed by a priority stack ([[Atmosphere Sky Clouds and Post-Processing]]), so a zone change never overwrites them.
- Exactly one system should call `apply`. If weather and zones both want to change lighting, merge their wishes into one recipe first (zone base, then weather overrides) and apply the result. Two tweens on `Ambient` at once flicker.
- In Edit previews, take a snapshot first and restore it after: the reference project shipped a wrong base atmosphere once because a mood controller read the place's `Atmosphere` at Play start and an Edit preview had been left on.

---

## 5. Checking a recipe objectively

Eyes adapt; in ten minutes any recipe looks "fine". Two cheap checks keep you honest:

1. **The greyscale test.** Take a screenshot, desaturate it (or push the grade's `Saturation` to -1 for a moment). The player character, enemies, pickups and the path must each be a distinct value from what surrounds them. If the scene only reads in colour, colour-blind players and phones in sunlight will not read it. See [[Accessibility]].
2. **The no-shadow test.** Set graphics quality to 1 to 3 in Studio's Editor Quality Level (or set `GlobalShadows` false briefly). If the scene goes flat and unreadable, the recipe relies on shadows; push more of the contrast into `ColorShift_Top`, ambient tint and material colour.

A third, for effects-heavy games: play your brightest and darkest effect in every recipe. An effect palette that disappears in one zone is a lighting problem as much as an effect problem.

A small helper for the greyscale test, using relative luminance (Rec. 709 weights):

```lua
--!strict
-- Relative luminance of a Color3 (0..1), for comparing value contrast between surfaces.
local function luminance(c: Color3): number
	local function lin(v: number): number
		return if v <= 0.04045 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * lin(c.R) + 0.7152 * lin(c.G) + 0.0722 * lin(c.B)
end

-- Contrast ratio as used by accessibility guidelines: (L1 + 0.05) / (L2 + 0.05), L1 the lighter.
local function contrast(a: Color3, b: Color3): number
	local la, lb = luminance(a), luminance(b)
	if la < lb then
		la, lb = lb, la
	end
	return (la + 0.05) / (lb + 0.05)
end
```

This measures material colours, not the lit result, so it only catches palette problems (a character colour too close to the floor colour). Rule of thumb: aim for a ratio of at least 3 between a gameplay object and its usual background colour before lighting is applied.

---

## 6. Transitions between recipes

- **Duration:** 1.5 to 3 s for walking between zones, 0.3 to 0.6 s for a teleport (hidden by a screen fade), 5 to 20 s for weather.
- **Blend by position, not by trigger,** for long borders: lerp between two recipes by distance across a border band, so walking back and forth does not pop. [[Lighting Mood and Time of Day]] has a blending approach.
- **Do not tween every frame from several sources.** Compute the target once per change.
- **Interiors:** a small indoor recipe (lower `OutdoorAmbient`, warmer ambient, no atmosphere glare) applied on entering a building. Remember `GlobalShadows` must be on for indoor and outdoor ambient to differ at all.

---

## 7. When not to use a recipe

- **Realistic showcases** need physically motivated light: PBR materials, specular near 1, `EnvironmentDiffuseScale` up with ambient down. These recipes will make them look like toys.
- **One look for the whole game** is fine for small games. Recipes per zone pay off only when zones are a feature (progression, biomes).
- **Do not stack a recipe on top of heavy materials work you have not finished.** Fix the palette and material colours first; lighting cannot rescue a muddy palette.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Looks great on PC, flat on phone | Look depends on shadows; phones below quality 4 have none | Contrast in colour shifts and ambient tint |
| Night unplayable | Ambient lowered instead of hue shifted | Blue hue, less saturation, ambient around a third |
| White walls glow | Bloom threshold under 1 | Threshold 1.2 to 2; let effects exceed it |
| Fog does nothing | `Atmosphere` exists, so `Fog*` is ignored | Tune the Atmosphere |
| Effects vanish in one zone | Effect palette matches the zone | Brighter core, dark rim, or inverted treatment |
| Mood flickers on borders | Two systems tween Lighting | One owner; merge zone and weather first |
| Wrong base mood at Play start | Edit preview left on | Snapshot and restore around previews |
| Metal looks like grey plastic | `EnvironmentSpecularScale` 0 in a realistic scene | Raise it for that recipe only |

## Checklist

- [ ] `LightingStyle` and material style chosen before tuning.
- [ ] Each zone has a named recipe stored as data.
- [ ] Greyscale test passed: characters, enemies, pickups and paths are distinct values.
- [ ] No-shadow test passed at quality 1 to 3.
- [ ] Bloom threshold chosen for the art style and the effect brightness.
- [ ] Brightest and darkest effects tested in every recipe.
- [ ] One system owns Lighting; transitions blended, not popped.
- [ ] Edit previews snapshot and restore lighting.

See also: [[Lighting Technologies and Settings]], [[Atmosphere Sky Clouds and Post-Processing]], [[Light Sources and Shadows]], [[Lighting Mood and Time of Day]], [[Environment Art Styles]], [[Water Sky and Atmosphere Art]], [[VFX Design Playbook]], [[Accessibility]], [[Mobile and Low-End Optimization]].

## Connected notes
<!-- auto-links:start -->
[[Lighting Untextured Art in Roblox]] · [[Colour Scripts and Value Structure for Untextured Art]] · [[Zone and Biome Art Direction]] · [[Voxel Palettes - Ramps Hue Shifting and Limits]] · [[Baking Lighting and Detail into Textures]] · [[Voxel Shading - Baked AO Edges and Lighting]]
<!-- auto-links:end -->
