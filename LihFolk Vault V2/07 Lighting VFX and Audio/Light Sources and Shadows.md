---
tags: [lighting, lights, shadows, performance, vfx, type/guide, area/vfx, level/intermediate, api/CollectionService, area/lighting, api/TweenService, api/Lighting]
---
# Light Sources and Shadows

<!-- tldr:start -->
> [!tldr] TL;DR
> - Light does not reach far enough: Range too low; Brightness does not extend it -> Raise Range (max 120).
> - Light seems not to exist: Parented to something that is not an Attachment or BasePart, or... -> Parent correctly.
> - Lamp casts a black shadow from its own shade: Light inside geometry with Shadows on -> Move it out, or CastShadow off on the shade.
> - Each light has a job; decoration lights have Shadows off.
> - Shadow-casting lights limited to a few hero lights per view.
> - VFX parts have CastShadow off; VFX lights have Shadows off and expire.
>
> Cost: TL;DR ~180 tok · whole note ~3.5k tok. Read more: ## 2. Shadows: sun versus local lights · ## 5. Managing many lights in code · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Local lights are where lighting stops being global and starts telling the player things: the lantern on the safe path, the glow under a charging ability, the red alarm strobe, the flicker that says "this corridor is wrong". They are also the lighting feature that most often ruins frame rate, because each one is cheap until there are forty of them overlapping the camera with shadows on.

This note covers the three light classes, what they share, how shadows work for the sun and for local lights, how to fake light that you cannot afford, and how to budget and manage lights from code. Global settings are in [[Lighting Technologies and Settings]].

Source labels: **Docs**, **API dump**, **Reference project** (one production game), **Rule of thumb**.

---

## 1. The three light classes

All inherit from `Light` (Docs): `Brightness` (default 1), `Color`, `Enabled`, `Shadows`.

| Class | Shape | Extra properties | Best for (Docs) |
|---|---|---|---|
| `PointLight` | Sphere from a point | `Range` | Bulbs, torches, fireballs, glowing pickups, ability cores |
| `SpotLight` | Cone from a face | `Range`, `Angle` (max 180 = full half sphere), `Face` | Street lamps, flashlights, headlights, a down-light under an aura |
| `SurfaceLight` | Light from a whole part face | `Range`, `Angle` (0 straight out, 180 spreads perpendicular), `Face` | Screens, signs, billboards, fluorescent panels, light from a portal surface |

**Range is capped at 120 studs** for all three (Docs; the hidden `Lighting.ExtendLightRangeTo120` property is documented as unused because the clamp is always 120).

**Brightness does not extend range** (Docs). A light with Range 12 and Brightness 50 still stops at 12 studs; it just burns out the middle of its circle. If a light "does not reach", raise `Range`, not `Brightness`.

**Parent to an `Attachment`** for point-specific emission (Docs recommend it for PointLight). An attachment gives you a precise position and orientation without a dedicated part, and SpotLights on attachments aim along the attachment. SurfaceLight needs a `BasePart` face.

Turn on **Show Light Guides** in Studio Settings to see each light's colour and cone (Docs). It removes guesswork when placing spotlights.

---

## 2. Shadows: sun versus local lights

### Sun and moon
Sun shadows depend on `Lighting.GlobalShadows` and the shading path (see [[Lighting Technologies and Settings]]):
- Voxel-style: soft shadows on a 4-stud grid; small objects do not shadow; thin walls leak.
- Shadow-map and realistic paths: crisp shadows from any geometry; edges controlled by `Lighting.ShadowSoftness`.

### Local lights
`Light.Shadows = true` makes the light project shadows where blocked (Docs). Whether you actually see them depends on the shading path and the player's quality level. Historically only the Future path drew local-light shadows; under voxel lighting local lights leaked through walls (rule of thumb from the old Technology modes; the new `LightingStyle` docs do not spell this out).

Practical consequences:
- **Design lights to work without their shadows.** A light whose job is "show the path" must not depend on its shadow to read.
- **Shadows on few lights.** Turn `Shadows` on for the hero lights that shape a room (a ceiling lamp, a window spot) and off for fill, decoration, ability glows and anything that moves fast. The reference project's lobby lanterns were seven PointLights with shadows off; they read as cosy without any shadow cost.
- **Lights inside geometry.** A light inside a lamp mesh with shadows on is shadowed by the lamp itself. Either move the attachment just outside the shade, or set `CastShadow = false` on the shade part.

### `CastShadow` on parts
`BasePart.CastShadow` decides whether a part casts shadows at all. Turn it off on:
- VFX parts (Neon shells, slash meshes, rings, beams' helper parts). The reference VFX playbook sets `CastShadow` off on every Neon effect mesh.
- Small clutter that adds nothing (pebbles, grass cards, tiny props).
- Large transparent or glass parts that should not darken the floor.

A slash mesh with `CastShadow` on draws a dark crescent on the ground for a frame, which reads as a bug.

---

## 3. Neon, emission and fake light

Three different things are often confused:

| Feature | Lights the environment? | What it does |
|---|---|---|
| `Light` objects | Yes | Real light within Range. |
| `Material.Neon` parts | No | Self-lit surface that glows under bloom. |
| `ParticleEmitter/Beam/Trail.LightEmission` | No | Additive blending (Docs: "does not cause particles to light the environment"; use a PointLight for that). |

So a glowing sword is usually three layers: a Neon or emissive blade, a bloom-friendly bright trail or particles, and one small `PointLight` (range 6 to 14) so the ground and the hand pick up the colour. Drop the PointLight first when budgets are tight; the other two layers still read as "glowing".

Cheaper ways to suggest light:
- **Light pools as decals or flat particles** (a soft circle texture on the floor under a lamp, `Orientation = VelocityPerpendicular` card or a Decal) cost nothing in lighting.
- **Surface colour**: paint the area around a fake lamp slightly warmer.
- **Ambient zones**: in a cave, lower ambient and use one or two big soft lights instead of a lamp every 10 studs.

---

## 4. Budgets

Roblox does not publish a hard per-scene light limit, so budgets are project rules. Numbers from the reference project:

| Context | Budget (reference project) |
|---|---|
| Lights per ability kit (any one cast) | 2, Range 18, Brightness 1.6 |
| Stylised toon VFX glow light | PointLight Range 14, Brightness 1.5, coloured, fading with its piece, at most 4 alive at once |
| Aura floor tint | One down-facing SpotLight 6 to 7 studs above the feet, Brightness 5, Angle 90, Range 10 to 12, in the aura colour |
| Lobby decoration | PointLights with `Shadows = false` |
| Performance thinning | Lights tagged and **disabled, not deleted**, so they can return per quality tier |

**Rule of thumb budgets** for mid-range phones: no more than 8 to 12 local lights visibly affecting the screen at once, and no more than 2 to 3 with shadows. Measure your own game: the GPU time in the MicroProfiler ([[MicroProfiler Guide]]) is the authority, not this table.

**VFX lights must expire.** An ability that creates a PointLight and errors before cleanup leaves a light in the world forever. Create lights from a pool, or parent them under the effect's root so destroying the effect destroys the light.

---

## 5. Managing many lights in code

### Distance culling and flicker in one loop

Hundreds of torches each with its own flicker script is a classic performance and leak problem. One client loop over tagged lights does it better: it flickers only lights near the camera and disables lights far away.

```lua
--!strict
-- LightDirector (client): flicker and distance-cull lights tagged "Flicker" or "Culled".
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CULL_DISTANCE = 220 -- studs; beyond this, lights are disabled locally
local UPDATE_INTERVAL = 0.1 -- seconds between culling passes

type Entry = { light: Light, base: number, seed: number, flicker: boolean }
local entries: { [Light]: Entry } = {}

local function lightPosition(light: Light): Vector3?
	local parent = light.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("BasePart") then
		return parent.Position
	end
	return nil
end

local function add(inst: Instance, flicker: boolean)
	if not inst:IsA("Light") then
		return
	end
	local existing = entries[inst]
	if existing then
		existing.flicker = existing.flicker or flicker
		return
	end
	entries[inst] = {
		light = inst,
		base = inst.Brightness,
		seed = math.random() * 1000,
		flicker = flicker,
	}
end

local function remove(inst: Instance)
	entries[inst :: any] = nil
end

for _, tag in { "Flicker", "Culled" } do
	local isFlicker = tag == "Flicker"
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst, isFlicker)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
		add(inst, isFlicker)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	local t = os.clock()

	acc += dt
	local doCull = acc >= UPDATE_INTERVAL
	if doCull then
		acc = 0
	end

	for light, e in entries do
		if not light.Parent then
			entries[light] = nil
			continue
		end
		if doCull then
			local pos = lightPosition(light)
			light.Enabled = pos ~= nil and (pos - camPos).Magnitude <= CULL_DISTANCE
		end
		if e.flicker and light.Enabled then
			-- Two incommensurate sines plus a rare dip read as a live flame.
			local n = math.sin(t * 13.1 + e.seed) * 0.08 + math.sin(t * 5.3 + e.seed * 2) * 0.12
			local dip = if math.sin(t * 0.7 + e.seed) > 0.97 then -0.35 else 0
			light.Brightness = e.base * (1 + n + dip)
		end
	end
end)
```

Notes on the code:
- Changing `Enabled` and `Brightness` on the client does not replicate, which is what you want for culling.
- The culling pass runs at 10 Hz, the flicker every frame only for nearby enabled lights.
- If lights are part of streamed content ([[Instance Streaming]]), the tag signals handle them arriving and leaving.

### Ability lights that fade with their piece

```lua
--!strict
local TweenService = game:GetService("TweenService")

-- Attach a short-lived coloured light to an effect root; it fades and dies with it.
local function flashLight(root: Instance, color: Color3, range: number, brightness: number, life: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.min(range, 120) -- engine clamps at 120 anyway (Docs)
	light.Brightness = brightness
	light.Shadows = false -- VFX lights never cast shadows (rule of thumb)
	light.Parent = root -- destroyed with the effect if the effect is destroyed early
	local tween = TweenService:Create(light, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Brightness = 0,
	})
	tween.Completed:Once(function()
		light:Destroy()
	end)
	tween:Play()
	return light
end
```

`root` must be an `Attachment` or `BasePart` for the light to emit. Use a global counter if you need a hard cap ("at most 4 alive"): refuse to create a new light when the counter is full, and the effect still reads from its particles.

---

## 6. Lighting for gameplay

- **Lights are wayfinding.** A warm light at a door is a stronger "go here" than an arrow. In level design, light the critical path and leave the optional path darker ([[Level Design for Roblox]]).
- **Colour language.** Keep a consistent meaning: warm white safe, red danger, cyan or green interactable. Do not light a harmless area red.
- **Enemy readability.** Enemies standing in darkness must still read. Rim them with a `Highlight` outline ([[Highlights and Selection Effects]]) rather than adding lights around every enemy.
- **Dark zones break VFX.** In the reference project, a stylised VFX set designed in daylight vanished in dark zones and had to be rebaked brighter with a small coloured light added per large piece. Test every effect in your darkest and brightest zone.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Light does not reach far enough | Range too low; Brightness does not extend it | Raise Range (max 120). |
| Light seems not to exist | Parented to something that is not an Attachment or BasePart, or Enabled false | Parent correctly. |
| Lamp casts a black shadow from its own shade | Light inside geometry with Shadows on | Move it out, or CastShadow off on the shade. |
| Frame drops near a market of lanterns | Dozens of overlapping lights, some with shadows | Shadows off on decoration, distance culling, fewer bigger lights. |
| Dark crescent under slash VFX | Effect mesh casts shadow | `CastShadow = false` on VFX parts. |
| Glowing particle does not light the floor | LightEmission is blending, not lighting | Add one small PointLight. |
| Lights left behind after abilities | Effect errored before cleanup | Parent lights under the effect root; pool them. |
| Flicker scripts multiply | One script per torch | One tagged loop. |

## Checklist

- [ ] Each light has a job; decoration lights have Shadows off.
- [ ] Shadow-casting lights limited to a few hero lights per view.
- [ ] VFX parts have CastShadow off; VFX lights have Shadows off and expire.
- [ ] Distance culling for decorative lights on large maps.
- [ ] Gameplay information does not depend on shadows alone.
- [ ] Every effect checked in the darkest and brightest zone.

See also: [[Lighting Technologies and Settings]], [[Lighting Mood and Time of Day]], [[Highlights and Selection Effects]], [[VFX Design Playbook]], [[Rendering Performance]], [[Level Design for Roblox]], [[CollectionService Patterns]].

## Connected notes
<!-- auto-links:start -->
[[Lighting Untextured Art in Roblox]] · [[Stylized Lighting Recipes]] · Baking Lighting and Detail into Textures · [[VFX Performance Budgets and Culling]] · Voxel Shading - Baked AO Edges and Lighting · Art Budgets - Triangles Draw Calls Memory
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Particle Emitters In Depth]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Atmosphere Sky Clouds and Post-Processing]] · [[Beams and Trails]] · [[Slash VFX Recipes - Crescent and Ring]] · [[VFX Previews in Blender for Roblox - Colour and Framing]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]]
<!-- related:end -->
