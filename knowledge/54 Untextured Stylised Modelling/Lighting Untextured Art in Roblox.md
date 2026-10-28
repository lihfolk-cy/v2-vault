---
tags: [lighting, untextured, stylised, flat-colour, materials, look-dev, roblox, phone, luau]
---
# Lighting Untextured Art in Roblox

Painted textures carry their own light: an artist paints the highlight on the top of a barrel and the shadow under its rim, and the barrel reads even in dull light. Untextured art (flat colour, gradient atlases, vertex colour) carries little or none. Every bit of form a player sees on a flat-coloured MeshPart comes from three sources: the mesh's normals, any gradient baked into its colour, and Roblox's lighting. That makes lighting a much bigger share of the look than in a textured game, and it makes untextured art sensitive to things textured art shrugs off: ambient balance, sun angle, material choice, and how the game degrades on low graphics settings.

[[Stylized Lighting Recipes]] gives full property sets for common moods, and [[Lighting Technologies and Settings]] explains what each `Lighting` property does. This note is about the interaction with untextured surfaces specifically: which built-in materials to use under flat colour, how to set the sun-to-ambient balance so forms read, how to make art that survives phones and low quality levels, and how to build a look-dev room that tells the truth.

## What lights a flat-coloured face

A simplified model of what players see on an opaque, flat-coloured face (rule of thumb description, not Roblox's exact shader):

- **Direct light** from the sun or moon, scaled by `Lighting.Brightness`, tinted by `ColorShift_Top`, strongest on faces pointing at the sun and falling off as they turn away. Blocked where `GlobalShadows` casts a shadow.
- **Ambient light**: `OutdoorAmbient` outdoors and `Ambient` in sky-occluded areas (Roblox docs describe `Ambient` as a hue for the whole game and `OutdoorAmbient` as a hue for outdoor areas). Faces facing away from the sun also pick up `ColorShift_Bottom`.
- **Environment diffuse**: with `EnvironmentDiffuseScale` above 0, ambient light is "derived from the environment" (Roblox docs), so upward faces take on sky colour and side faces a mix. This is a free, directional ambient gradient.
- **Environment specular**: with `EnvironmentSpecularScale` near 1, smooth objects "better reflect the environment" (Roblox docs).
- **Local lights**: PointLight, SpotLight and SurfaceLight.
- Then **bloom**, **colour correction** and **atmosphere** on the whole image.

For a face with no texture, the difference between its lit side and its shadow side is the only thing showing its form. Everything below is about controlling that difference.

## Choosing a built-in material under flat colour

Untextured meshes still have a `Material`. It changes surface response and, if the mesh has usable UVs, adds the material's own subtle pattern.

| Material | Under flat colour | Use for | Watch out |
|---|---|---|---|
| SmoothPlastic | Clean, even, no pattern | The default for flat stylised art | Shows every normal error and every gradient across flat faces ([[Clean Stylised Shading - Weighted and Custom Normals]]) |
| Plastic | Very subtle surface pattern | Large surfaces where perfect evenness looks sterile | Pattern smears on collapsed or missing UVs |
| Neon | Glows at its colour regardless of lighting, blooms | Accents, eyes, gems, lamps, rune lines | Large Neon areas flatten form and wash out under bloom; low graphics may lose the bloom |
| Glass | Transparent, reflective | Windows, ice, potions | Transparency sorting and overdraw; avoid large areas on phones |
| ForceField | Animated, translucent | Shields, magic | Not a general surface |
| Wood, Slate, Fabric and others | Visible material pattern | Only if the mesh has real UVs and you want texture after all | Breaks the "non-textured" look; check against the style sheet |

Rule of thumb: **SmoothPlastic for almost everything**, Neon for a small budget of glowing accents, and nothing patterned unless the style sheet says so. If the game mixes Parts built in Studio with imported meshes, put both on the same material or they will look like two different games next to each other ([[Keeping a Mixed Asset Library Consistent]]).

### Neon as "unlit"

Roblox has no unlit material for arbitrary colours. Neon is the closest: it ignores the scene's light for its own colour and adds bloom. For flat stylised games that want a few surfaces to read the same day and night (signs, interactables, eyes), Neon is the tool. Budget it: [[Environment Art Styles]] suggests keeping glow coverage to a small share of the frame. Neon also reads very differently with and without bloom, so check it at low graphics settings where bloom may be reduced (rule of thumb; Roblox does not list which post effects each quality level disables).

## The sun-to-ambient balance

This is the most important single setting for untextured art.

- **Ambient too bright** (for example `OutdoorAmbient` near white, `Brightness` low): lit and shadow sides end up the same value. Every object turns into a flat cut-out. Faceted art loses its facets; smooth art loses its volume.
- **Ambient too dark** (near black): shadow sides become holes, especially on phones in daylight where screens look dimmer. Dark-coloured props vanish entirely.
- **Readable range**: lit faces about 1.5 to 2.5 times the brightness of shadow faces (rule of thumb). Measure it by eye with a white SmoothPlastic cube: its sun face and its shadow face should be clearly different, and the shadow face should still be well above black.

### Tint the two sides differently

Flat colour has no painted hue shift, so put it in the light:

- A **warm `ColorShift_Top`** (for example a light warm yellow) and a **cool ambient** (slightly blue) make every lit face warm and every shadow face cool. This is the single most effective trick for flat art: it adds a hue shift to every object for free.
- **`EnvironmentDiffuseScale`** at 0.2 to 0.5 adds sky-coloured light on upward faces, giving a gentle top-to-bottom gradient on every object. Roblox docs warn that raising it means lowering `Ambient` and `OutdoorAmbient` or the scene washes out (the vault's lighting notes cover this).
- **`ColorShift_Bottom`** can add a ground bounce colour (a green tint in a meadow, an orange one in a desert) to downward faces, depending on sun position.

[[Stylized Lighting Recipes]] gives tested numeric presets; start there and adjust the balance for your palette.

## Sun angle

- **Overhead sun** (`ClockTime` around 12 at the default latitude) lights all upward faces equally and leaves vertical faces in similar grazing light. Facets and bevels on sides read poorly.
- **Sun 30 to 50 degrees above the horizon**, from a quarter angle to the main camera direction, gives each object a clear lit side, a clear shadow side and a readable top. Most stylised games pick a fixed mid-morning or mid-afternoon time.
- **Low sun** (golden hour) exaggerates every shading error and lengthens shadows across the playfield. Lovely for a hub screenshot, risky for gameplay readability.
- **`GeographicLatitude`** moves the sun path; use it to get a good angle at the time of day you want.

## Shadows

Untextured art leans on shadows more than textured art, because shadows are one of the few sources of contrast.

- **`GlobalShadows` on** for outdoor stylised scenes; it also creates the indoor and outdoor ambient distinction.
- **`ShadowSoftness`** only applies with `LightingStyle = Realistic` (Roblox docs, as of October 2026). Soft shadows suit cartoon art; very soft ones lose contact under small props.
- **`CastShadow` off on small props** (pebbles, flowers, coins) to save cost and remove speckled noise from the ground ([[Art Budgets - Triangles Draw Calls Memory]]).
- **Contact shadow in the colour.** Because shadows may be reduced on low settings, bake a darker band into the bottom of props (gradient atlas contact shadow, vertex colour, or a flat dark "shadow blob" mesh under characters and big props). This keeps objects seated on every device.

## LightingStyle and quality levels

Roblox docs (as of October 2026) describe two `LightingStyle` values: **Realistic** ("the most advanced and realistic lighting and shadows Roblox can deliver") and **Soft** ("a flat, retro-Roblox look with softer lights and shadows"). `PrioritizeLightingQuality` decides whether, as rendering quality reduces, advanced shadows are kept at the cost of view distance.

For untextured art:

- **Soft** suits bright, flat cartoon worlds; it also matches the soft look many simulator-style games have.
- **Realistic** gives crisper sun shadows and better local light shading; flat art can look great under it, but shading errors show more.
- Either way, **design for the bottom of the range**. Phones and low quality levels reduce shadow quality and view distance (rule of thumb; Roblox does not publish a per-level feature list). Art whose form comes from geometry, normals and baked gradients survives this. Art whose form comes only from shadows does not.

The safest untextured recipe across devices: clear sun-to-ambient balance, warm-top and cool-bottom tints, baked contact shadows, and gradient colour on large forms ([[The Gradient Palette Texture Workflow]]).

## Local lights on flat colour

PointLights and SpotLights look excellent on flat colour because there is no texture noise to fight: a warm lantern makes a clean warm pool on a SmoothPlastic wall.

- **Shadows on local lights are expensive**; turn them off unless the light is a hero (rule of thumb repeated across the vault's lighting notes).
- **Colour the light, not the surface**, for mood changes: the same blue-grey dungeon wall becomes warm by torchlight and cold by crystal light.
- **Range** in studs matters more than brightness for readability: a pool of light roughly the size of the play area around a feature reads as "this matters here".

## Night and interiors

Untextured art at night is the hardest case: little direct light, so form collapses.

- Keep **ambient colourful, not just dark**: a deep blue night ambient keeps shapes visible.
- Make **moonlight directional and cool** with a clear angle, like a weaker sun.
- Use **Neon accents and local lights** to create value structure: lit pools and dark gaps, with paths always in the lit pools.
- Interiors use `Ambient` (sky-occluded). If interiors look flat, the interior ambient is too close to the light from windows or lamps.

## Building a look-dev room

A look-dev room is a small area of the place with fixed reference objects you check every asset against, under the real lighting. For untextured art it must include perfect reference shapes, because there is no texture to compare.

```lua
--!strict
-- Edit-time (Command Bar): build a look-dev strip of reference objects at the origin of a folder.
-- Reference set: white, mid-grey and black SmoothPlastic cubes and spheres, plus palette chips.
local folder = Instance.new("Folder")
folder.Name = "LookDev"
folder.Parent = workspace

local ORIGIN = Vector3.new(0, 3, -200)   -- out of the play area
local SPACING = 6

local function make(shape: Enum.PartType, color: Color3, material: Enum.Material, x: number, z: number, name: string)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = Vector3.new(4, 4, 4)
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.Position = ORIGIN + Vector3.new(x * SPACING, 0, z * SPACING)
	p.Parent = folder
end

local greys: {{name: string, color: Color3}} = {
	{name = "White", color = Color3.new(1, 1, 1)},
	{name = "MidGrey", color = Color3.fromRGB(128, 128, 128)},
	{name = "Black", color = Color3.fromRGB(20, 20, 20)},
}
for i, g in greys do
	make(Enum.PartType.Block, g.color, Enum.Material.SmoothPlastic, i - 1, 0, g.name .. "Cube")
	make(Enum.PartType.Ball, g.color, Enum.Material.SmoothPlastic, i - 1, 1, g.name .. "Sphere")
end

-- Palette chips: replace with your zone palette (from the style sheet).
local palette = {
	Color3.fromRGB(122, 164, 74), Color3.fromRGB(86, 120, 60), Color3.fromRGB(140, 102, 70),
	Color3.fromRGB(176, 170, 160), Color3.fromRGB(230, 200, 90), Color3.fromRGB(90, 140, 200),
}
for i, c in palette do
	make(Enum.PartType.Block, c, Enum.Material.SmoothPlastic, i - 1, 2, "Chip" .. i)
end

-- A ground plate in the zone's ground colour, so contact and shadow read correctly.
local ground = Instance.new("Part")
ground.Name = "Ground"
ground.Size = Vector3.new(60, 1, 30)
ground.Color = Color3.fromRGB(110, 140, 80)
ground.Material = Enum.Material.SmoothPlastic
ground.Anchored = true
ground.Position = ORIGIN + Vector3.new(12, -2.5, 6)
ground.Parent = folder
print("LookDev built at", ORIGIN)
```

How to use it:

1. Drop each new asset next to the white cube and sphere. Flat faces should be as even as the cube; curves as smooth as the sphere.
2. Compare its colours against the chips: do they belong to the zone palette under this light?
3. Check the mid-grey cube: its lit and shadow faces show your sun-to-ambient ratio at a glance.
4. Toggle a `ColorCorrectionEffect` with `Saturation = -1` for a value check ([[Colour Scripts and Value Structure for Untextured Art]]).
5. Repeat with each lighting preset the game uses (day, night, each zone), and in Studio's device emulator with a lower graphics quality level. Studio lets you set the quality level used in edit and play (Studio settings, rendering); check the current menu names in your version.

Delete or move the look-dev folder out of the published place (for example to `ServerStorage`) before shipping, or keep it in a separate look-dev place.

## When lighting cannot fix it

- **Values were wrong in the palette.** No lighting rescues a zone where everything is the same value; fix colours first.
- **Normals are broken.** Gradients across flat faces need mesh fixes, not light tweaks.
- **Too much Neon.** Bloom will wash it out on high settings and it will look flat on low ones; reduce coverage.
- **Mixed materials across sources.** Plastic next to SmoothPlastic next to imported textured meshes will never match under one light; normalise materials.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Everything looks like flat cut-outs | Ambient too bright relative to the sun | Lower ambient or raise `Brightness`; target lit faces 1.5 to 2.5 times shadow faces |
| Dark props vanish on phones | Ambient too dark, dark palette colours | Lift ambient, colourful (not grey) shadows, avoid near-black colours |
| Shadows look grey and lifeless | No hue difference between lit and shadow light | Warm `ColorShift_Top`, cool ambient |
| Scene washes out after raising environment diffuse | Ambient not lowered to compensate | Lower `Ambient` and `OutdoorAmbient` as Roblox docs advise |
| Props float on phones | Relied on shadows for contact | Bake contact darkening into colour; shadow blob meshes |
| Neon accents wash the scene | Too much Neon area under bloom | Budget Neon; raise bloom threshold |
| Studio Parts and imported meshes do not match | Different materials (Plastic vs SmoothPlastic) | One material rule in the style sheet; audit script |
| Art looks great in Studio, flat in game on phones | Checked only at high quality | Check at low quality levels and in the device emulator |

## Checklist

- [ ] SmoothPlastic as default material; Neon budgeted; patterned materials only by rule.
- [ ] Sun 30 to 50 degrees up at the chosen time; lit faces about 1.5 to 2.5 times shadow faces.
- [ ] Warm top tint and cool ambient (or the zone's equivalent) set.
- [ ] Contact shadows baked into colour; `CastShadow` off on small props.
- [ ] `LightingStyle` chosen by intent; art checked at low quality levels.
- [ ] Look-dev room with white, grey and black reference shapes and palette chips, checked under every lighting preset.

## Related

- [[Stylized Lighting Recipes]]
- [[Lighting Technologies and Settings]]
- [[Lighting Mood and Time of Day]]
- [[Light Sources and Shadows]]
- [[Atmosphere Sky Clouds and Post-Processing]]
- [[Colour Scripts and Value Structure for Untextured Art]]
- [[Clean Stylised Shading - Weighted and Custom Normals]]
- [[Faceted Low-Poly - Flat Normals and Facet Size]]
- [[Materials MaterialVariants and SurfaceAppearance]]
- [[Mobile and Low-End Optimization]]
- [[Untextured Stylised Modelling Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Baking Lighting and Detail into Textures]] · [[Voxel Shading - Baked AO Edges and Lighting]] · [[Bevels Chamfers and Edge Highlights Without Textures]] · [[Hand-Painted and Stylized Texturing]] · [[Voxel Palettes - Ramps Hue Shifting and Limits]] · [[Links - Lighting]]
<!-- auto-links:end -->
