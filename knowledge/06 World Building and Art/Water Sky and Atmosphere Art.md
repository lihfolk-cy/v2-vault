---
tags: [world-building, art, water, sky, skybox, atmosphere, clouds, environment]
---
# Water Sky and Atmosphere Art

Water, sky and air are the largest things on screen and the cheapest way to set mood. This note is the **art** side: choosing between terrain water and fake water, building waterfalls and rivers that read on phones, picking or painting skyboxes, and using `Atmosphere` and `Clouds` to tie a world's colours together. The lighting engine itself (technologies, post-processing, time of day) is covered in [[Lighting Technologies and Settings]], [[Atmosphere Sky Clouds and Post-Processing]] and [[Lighting Mood and Time of Day]]; this note links there instead of repeating it.

## Water

### Terrain water versus fake water

| | Terrain water | Flat part ("fake") water |
|---|---|---|
| Swimming, buoyancy | Yes (engine) | No (unless you script it) |
| Waves | Global `WaterWaveSize` / `WaterWaveSpeed` | Whatever you animate |
| Colour | **One global `WaterColor`** for the place | Per part |
| Refraction and reflection | Engine, scales with graphics quality | Material (Glass / SmoothPlastic + Reflectance) or a SurfaceAppearance |
| Cost over large areas | High | Very low |
| Shoreline blending | Automatic with terrain | Needs foam strips or careful edges |

One production game's rule: **never fill large areas with terrain water; a flat part fakes it.** Terrain water is for places players swim. Decorative oceans, moats, fountains, ponds behind fences, and anything stylised are flat parts.

Terrain water properties (Roblox docs): `WaterColor` (hue of all water), `WaterReflectance` 0..1, `WaterTransparency` 0..1 (1 = clear), `WaterWaveSize` 0..1, `WaterWaveSpeed` 0..100. Some of these only preview in Studio at the highest Editor Quality Level, so judge water in a playtest.

### Building fake water

A convincing stylised water surface is:
1. A flat anchored part slightly below the bank, `CanCollide = false` if players should "wade", or a hidden floor underneath.
2. A **colour gradient by depth**: lighter near edges, darker in the middle. Use two or three overlapping flat parts, or a mesh with vertex colours.
3. A **scrolling texture** (`Texture` with animated `OffsetStudsU/V`) for ripples or flow direction, animated on the client (see [[Textures Decals and Texture Memory]]).
4. **Foam** at edges and around objects: white strips, small sparkle particles.
5. A subtle **bob** or none at all; a bobbing water plane looks wrong where it meets fixed banks.

```lua
--!strict
-- Build a stylised flat pond: base plane + darker deep plane + scrolling ripple texture.
local RIPPLES = "rbxassetid://0000000000"

local function buildPond(centre: Vector3, size: Vector2, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Pond"

	local function plane(name: string, s: Vector2, y: number, colour: Color3, transparency: number): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Size = Vector3.new(s.X, 0.2, s.Y)
		p.CFrame = CFrame.new(centre + Vector3.new(0, y, 0))
		p.Color = colour
		p.Transparency = transparency
		p.Reflectance = 0.15
		p.Parent = model
		return p
	end

	local shallow = plane("Shallow", size, 0, Color3.fromRGB(86, 196, 214), 0.25)
	plane("Deep", size * 0.6, -0.15, Color3.fromRGB(28, 102, 150), 0)

	local ripple = Instance.new("Texture")
	ripple.Texture = RIPPLES
	ripple.Face = Enum.NormalId.Top
	ripple.StudsPerTileU, ripple.StudsPerTileV = 16, 16
	ripple.Transparency = 0.6
	ripple:SetAttribute("Speed", 1.5) -- read by a client scroller tagged below
	ripple:AddTag("ScrollTexture")
	ripple.Parent = shallow

	model.Parent = parent
	return model
end
```

Stacking transparent water planes causes overdraw; two layers is fine, five is not.

### Waterfalls and rivers

Falling water is where stylised games most often look cheap. What worked in one production game:
- **A stepped sheet mesh** for the fall itself (a rock lip, the sheet, side stacks), not a single flat card.
- **Two scrolling streak Beams per drop** with their own streak texture (`TextureSpeed` drives the scroll; see [[Beams and Trails]]). Check the scroll direction in Play: if water climbs, flip the sign.
- **Lip foam** at the top, **mist, spray and ripples** at the base from particle emitters using simple smoke/sparkle textures.
- **Sleep beyond a distance** (650 studs in that project): the controller disables the effects for far falls.
- **Positions from invisible markers**: designers move marker parts in Studio; the client builds the costly effects at runtime from the markers. That kept the effects editable without shipping heavy instances in the place.

Rivers are flat water with a strong directional scroll, foam lines along banks, and a few floating props (leaves, logs) drifting with a simple client tween.

### Shorelines and where water meets ground

- Bury the water edge under the bank: water planes should extend under the terrain or bank meshes so no gap shows at any angle.
- Watch for **terrain grass poking through** water or paving. One project found a stream and moat buried under terrain grass 2 studs above the water and cleared the terrain columns over the water footprint (with a backup), then removed 97 grass tufts standing in the water.
- Foam strips hide hard intersections.

## Sky

### Skybox basics

A `Sky` object in `Lighting` holds six faces (`SkyboxBk`, `SkyboxDn`, `SkyboxFt`, `SkyboxLf`, `SkyboxRt`, `SkyboxUp`), sun and moon textures and angular sizes, `StarCount`, `CelestialBodiesShown`, and `SkyboxOrientation` (a Vector3 in degrees, which can rotate the sky, including slowly over time) (Roblox API reference).

Art guidance (rule of thumb):
- **Seams.** Faces must match at edges. Render skyboxes from a 3D tool with a 90-degree camera per face, or use a cubemap export, rather than painting six images separately.
- **Resolution.** Six faces at 1024 is six 1024 textures of memory; a soft painted sky often looks identical at 512 (see [[Textures Decals and Texture Memory]]).
- **No baked sun** if you use the engine sun: two suns look wrong, and shadows will disagree with the painted one.
- **Horizon behaviour.** Atmosphere haze covers the bottom of the skybox; design the sky so the horizon band can be hidden.
- **A flat colour sky** (Atmosphere doing all the work, no skybox detail) is a legitimate stylised choice: one style study found a whole showcase used a flat tinted sky with the horizon melted into haze.

### Sky dressing

Big, slow, distant objects sell a sky better than a detailed skybox: floating islands, a ringed moon, distant castle spires, giant planets. One production game's hub scale pass added castle-spire clusters on floating isles, a ringed moon and waterfalls on every isle. They are geometry, so they parallax as the camera moves, which a skybox cannot.

Keep sky props **non-colliding, non-queryable, no shadows**, and consider whether they should be streamed (Persistent) so they never pop in.

## Atmosphere and clouds

`Atmosphere` (in Lighting) controls air: `Density`, `Offset`, `Color`, `Decay`, `Glare`, `Haze`. `Clouds` (a child of `Terrain`) adds dynamic clouds with `Cover`, `Density` and `Color`. Full property behaviour is in [[Atmosphere Sky Clouds and Post-Processing]].

Art uses:
- **Depth.** Even light haze separates foreground from background and hides the streaming edge.
- **Hiding the edge of the world.** Higher density hides distant terrain and the point where streamed content ends.
- **Theme tinting.** Tint `Color` and `Decay` toward the zone's hue and keep the floor neutral. A neon voxel style study used Atmosphere Color and Decay set to the theme's sky hue, Density about 0.35 to 0.45 and Haze about 1 to 2, so the horizon melted into a flat coloured sky; OutdoorAmbient was tinted toward the hue at about 40 percent value.
- **Clouds for scale.** A few slow clouds make a sky feel big; heavy cover flattens lighting.

### Per-zone air

Games with biomes usually change air per zone: a client controller interpolates Atmosphere, ambient and colour grading as the player crosses zones. One production game's weather controller blended a live sky, terrain clouds, per-zone air and grading, rain and precipitation layers following the player, and per-zone flavour on top of a global weather state.

Two production pitfalls:
- **The base air must be restored.** That project's weather controller read the place's Atmosphere as its base air when Play started, so any preview script that changed Lighting or Atmosphere in Edit and forgot to switch itself off **changed the game's baseline**. Previews had to be switched off right after screenshots.
- **Presets as modules.** Lighting presets were ModuleScripts with Snapshot, Apply and Restore functions (parking the Sky object while applied, never setting it to nil) so a preset could be tried and exactly reverted.

```lua
--!strict
-- A minimal lighting/atmosphere preset with exact snapshot and restore.
local Lighting = game:GetService("Lighting")

local KEYS = { "Ambient", "OutdoorAmbient", "Brightness", "ExposureCompensation", "ClockTime",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale" }
local ATMO_KEYS = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" }

type Snapshot = { lighting: { [string]: any }, atmo: { [string]: any }? }

local Preset = {}

function Preset.snapshot(): Snapshot
	local s: Snapshot = { lighting = {}, atmo = nil }
	for _, k in KEYS do
		s.lighting[k] = (Lighting :: any)[k]
	end
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		s.atmo = {}
		for _, k in ATMO_KEYS do
			(s.atmo :: any)[k] = (atmo :: any)[k]
		end
	end
	return s
end

function Preset.apply(values: { lighting: { [string]: any }?, atmo: { [string]: any }? })
	for k, v in values.lighting or {} do
		(Lighting :: any)[k] = v
	end
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo and values.atmo then
		for k, v in values.atmo do
			(atmo :: any)[k] = v
		end
	end
end

function Preset.restore(s: Snapshot)
	Preset.apply({ lighting = s.lighting, atmo = s.atmo })
end

return Preset
```

Use it for screenshots and previews: snapshot, apply, capture, restore, in one script, so you cannot forget the restore.

## Night, weather and special skies

- **Night needs readable ground.** Raise ambient enough that paths and enemies stay visible; a moon and a few lamps carry the mood.
- **Weather layers follow the player.** Rain and snow emitters parented to a part that tracks the camera, not spread over the whole map.
- **Special event skies** (a rare starfall, a glitch sky) work best as a full swap of skybox, atmosphere and grading for the event's duration, announced in UI, then restored.
- **Underwater moods** need fog-like atmosphere, caustic decals or light cookies, particles (bubbles, motes) and swimming creatures; one project built a whole underwater realm this way before removing it.

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| A terrain ocean | Frame drops, one global water colour | Flat part water |
| Water planes stacked five deep | Overdraw | Two layers max |
| Waterfall as one flat card | Cheap look | Stepped sheet + streak beams + foam + mist |
| Skybox with a painted sun plus engine sun | Two suns | Remove one |
| 1024 skybox faces for a soft sky | Memory waste | 512 |
| Preview script leaves Atmosphere changed | Baseline mood silently altered | Snapshot/restore in one script |
| No haze | Streaming edge and pop-in visible | Light atmosphere |

## Checklist

- [ ] Terrain water only where players swim.
- [ ] Fake water: depth gradient, scrolling ripples, foam, buried edges.
- [ ] Waterfalls: sheet mesh, streak beams, foam, mist, distance sleep.
- [ ] Skybox seams checked, sun handled once, resolution justified.
- [ ] Atmosphere hides the streaming edge; tinted per zone.
- [ ] Every preview restores Lighting exactly.

## See also

- [[Atmosphere Sky Clouds and Post-Processing]], [[Lighting Technologies and Settings]], [[Lighting Mood and Time of Day]], [[Light Sources and Shadows]]
- [[Beams and Trails]], [[Particle Emitters In Depth]], [[VFX Design Playbook]]
- [[Terrain Tools and Terrain API]], [[Textures Decals and Texture Memory]], [[Environment Art Styles]]

## Nuances and edge cases

1. **Water is a gameplay object first.** Before choosing terrain water or a part plane, decide what players do with it: swim, drive boats, fall in and die, or only look at it. Terrain water gives swimming for free; fake water needs custom swim or kill logic. Choosing the wrong one for the gameplay is expensive to undo after the map is built.
2. **Transparency and overdraw on phones.** Every transparent surface over another costs fill rate, and phones are fill-limited. Stacked transparent water layers, mist cards and glass in one view can drop low-end frame rates sharply even with few triangles. Rule of thumb: no more than two transparent layers over any large screen area.
3. **Sky and atmosphere set the streaming horizon.** A clear sky with sharp distant geometry exposes the streaming edge; haze hides it. On large streamed maps, atmosphere density is not only mood but a technical tool, and phones with smaller streaming radii benefit most.
4. **Quality levels change water and sky.** Reflections, clouds and some atmosphere effects degrade at low graphics quality. A water surface that relies on reflections looks like flat plastic at low quality; give it colour variation and foam edges that survive without reflections.
5. **Water physics at scale.** Many unanchored objects floating in terrain water (debris, boats) each run buoyancy physics on the server or their owner. Ten boats are fine; two hundred floating props are a physics budget problem. Anchor decorative floating objects and bob them visually on the client.
6. **Shorelines carry most of the realism.** The line where water meets land is where players look. Foam, wet darker ground and a slight colour shift near the shore improve the look more than any water setting.
7. **Skybox resolution versus memory.** Six large skybox faces are always in memory. Soft skies hold up well at modest resolutions; save memory there and spend it on gameplay textures (the existing table in this note gives a starting point).
8. **Sky continuity across zones and places.** A sky that changes abruptly at a zone border or after a teleport breaks immersion. Blend sky-related properties at borders, and set the destination place's sky to match the source's last look when teleporting between related places.

The senior trade-off: water and sky are large screen areas, so small changes affect the whole frame. Spend art time here early, because the sky's colour sets the palette every other asset is judged against.

## Common mistakes (advanced)

1. **Fake water with no gameplay behaviour.** Symptom: players walk on water or fall through it without effect. Fix: a swim or kill volume under every fake water surface.
2. **Floating debris simulated by physics.** Symptom: server physics time rises near water areas. Fix: anchored props with client-side bobbing.
3. **Clear sky on a streamed map.** Symptom: visible holes and pop-in at the horizon. Fix: atmosphere haze tuned to the streaming radius.
4. **Water that only looks good with reflections.** Symptom: phone players see flat grey water. Fix: colour, foam and texture detail that work at low quality.
5. **Changing sky per zone with a hard cut.** Symptom: the sky snaps when crossing a border. Fix: blend over a second or two.
6. **Glass and mist cards everywhere.** Symptom: frame drops in scenic areas on phones. Fix: limit transparent layers and use opaque or dithered alternatives.

## Related decisions

- [[Boats Buoyancy and Water]]: water as a physics surface.
- [[Atmosphere Sky Clouds and Post-Processing]]: the lighting side of the same objects.
- [[Terrain Deep Dive - Materials Water and Performance]]: terrain water costs.
- [[Stylized Lighting Recipes]]: sky colour as the base of a palette.
- [[Rendering Performance]]: transparency and overdraw measurement.
- [[Instance Streaming]]: matching haze to streaming radius.
- [[Teleporting and Multi-Place Games]]: keeping the sky consistent across places.
- [[Environment Art Styles]]: stylised versus realistic water choices.

## Connected notes
<!-- auto-links:start -->
[[Materials and Surfaces Start Here]] · [[Lighting Untextured Art in Roblox]] · [[Links - Lighting]] · [[Zone and Biome Art Direction]] · [[Bevels Chamfers and Edge Highlights Without Textures]] · [[Environment and Level Pipeline]]
<!-- auto-links:end -->
