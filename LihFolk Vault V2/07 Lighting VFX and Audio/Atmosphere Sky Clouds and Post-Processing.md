---
tags: [lighting, atmosphere, sky, clouds, post-processing, environment, type/guide, area/vfx, level/intermediate, api/Atmosphere, area/lighting, api/ColorCorrectionEffect]
---
# Atmosphere Sky Clouds and Post-Processing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Fog stopped working: An `Atmosphere` was added -> Use Atmosphere density and haze.
> - Skybox visible through mountains: `Offset` too low for the `Density` -> Raise `Offset`.
> - Glare or Decay does nothing: `Haze` is 0 (and Glare 0 for Decay) -> Raise Haze first.
> - Atmosphere or fog, not both.
> - Density and Offset tuned together; no ghosting at the horizon.
> - Clouds under Terrain, moved by `GlobalWind`.
>
> Cost: TL;DR ~140 tok · whole note ~4.3k tok. Read more: ## 1. Atmosphere · ## 4. Post-processing effects · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Global lighting ([[Lighting Technologies and Settings]]) decides how surfaces are shaded. The objects in this note decide what the air, the sky and the camera do: the `Atmosphere` that turns distance into haze, the `Sky` cube with its sun, moon and stars, dynamic `Clouds` under `Terrain`, and the six post-processing effects that tint, blur and bloom the final image. Together they carry most of a scene's mood for very little cost, which is why they are also the first things to be misused: a bloom that turns every white UI-coloured part into a glowing blob, an atmosphere so dense the skybox ghosts through mountains, a red low-health tint that a cutscene grade overwrites.

Source labels: **Docs** = official reference and guides (October 2026). **API dump** = engine defaults. **Reference project** = one production game. **Rule of thumb** = experience.

---

## 1. Atmosphere

`Atmosphere` lives in `Lighting`. It simulates aerial perspective: distant objects lose contrast and take the air's colour, and sunlight scatters into a glow around the sun.

| Property | Default (API dump) | Meaning (Docs) | Practical range (rule of thumb) |
|---|---|---|---|
| `Density` | 0.395 | Amount of particles in the air. Higher obscures objects and terrain more. It does not directly affect the skybox; you just see the sky through obscured objects. | 0.25 to 0.35 clear day, 0.4 to 0.55 hazy, 0.6+ fog and storms |
| `Offset` | 0 | How light transmits between the camera and the sky background. Higher: distant objects silhouette against the sky. Lower: they blend into it. | 0 to 0.25 for open worlds that should feel endless, 0.25 to 0.5 for a crisp horizon |
| `Haze` | 0 | Haziness above the horizon and into the distance. | 0 to 3; most moods sit at 1 to 2 |
| `Color` | warm (200, 170, 108) | Atmosphere hue. Docs: combine with higher `Haze` to see it. | Tint toward the zone's palette |
| `Glare` | 0 | Glow around the sun. **Needs `Haze` above 0** to show. | 0 to 2 |
| `Decay` | brown (92, 60, 14) | Hue away from the sun, falling off from `Color`. **Needs `Haze` and `Glare` above 0.** | Cooler than `Color` for sunsets |

### Traps

- **Fog vanishes.** The moment `Lighting` contains an `Atmosphere`, the `FogColor/FogStart/FogEnd` properties are hidden and ignored (Docs). Pick one system. Modern scenes use Atmosphere.
- **Ghosting.** A low `Offset` with a high `Density` can let the skybox show through objects and terrain (Docs). If a mountain looks transparent at the horizon, raise `Offset` until it silhouettes.
- **"My Glare does nothing."** It needs `Haze` above 0. `Decay` needs both (Docs).
- **Density is not a draw-distance tool.** It hides distant geometry visually, but the geometry still renders. Pair dense air with streaming or LOD if the goal is performance ([[Instance Streaming]], [[Level of Detail and Model Streaming]]).
- **Base air is state.** A mood controller that captures the place's `Atmosphere` at Play start as "the base" inherits any Edit-mode experiment left in the place. The reference project hit this: always switch previews off and restore values exactly (snapshot helper in [[Lighting Technologies and Settings]]).

### Tuning order (rule of thumb)

1. `Density` until distant terrain fades where you want the "edge of interest" to be.
2. `Offset` until the horizon silhouette looks right and nothing ghosts.
3. `Haze` and `Color` for mood.
4. `Glare` and `Decay` last, looking toward the sun.

---

## 2. Sky

`Sky` lives in `Lighting`. It is a cube of six images plus celestial bodies.

| Property | Default (API dump) | Notes (Docs) |
|---|---|---|
| `SkyboxBk/Dn/Ft/Lf/Rt/Up` | built-in sky textures | Six faces. Each image must be seamless along all edges with its neighbours when folded into a cube. There are matching `Content`-typed properties (`SkyboxBackContent` etc.). |
| `CelestialBodiesShown` | true | Hides sun, moon and stars together. |
| `SunAngularSize` | 21 | Degrees, clamped 0 to 60. 0 hides just the sun. |
| `MoonAngularSize` | 11 | Degrees. 0 hides just the moon. |
| `SunTextureId`, `MoonTextureId` | built-in | Custom sun and moon images. |
| `StarCount` | 3000 | Only with celestial bodies shown. |
| `SkyboxOrientation` | (0, 0, 0) | Rotates the skybox faces; applied Y first, then X and Z. |

### SkyboxOrientation caveats (Docs)

- Only the six faces rotate. **Celestial bodies are not affected**, and neither are dynamic clouds.
- Indoor reflections of the sky (a mirror seen through a window) are not rotated.
- A `Sky` inside a `ViewportFrame` uses the global orientation; you cannot rotate it per frame.
- Keep the angle wrapped with `% 360` in a running animation to avoid precision drift.

A slowly spinning sky (1 to 5 degrees per second around Y with a fixed X tilt) is a cheap way to make a night or an otherworldly realm feel alive. Run it on the client; there is no reason to replicate it.

```lua
--!strict
-- Client: slow sky spin with a fixed tilt. Cheap on all platforms (Docs).
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local DEG_PER_SEC = 3
local TILT_X = 20

local sky = Lighting:FindFirstChildOfClass("Sky")
if sky then
	local yaw = sky.SkyboxOrientation.Y
	RunService.Heartbeat:Connect(function(dt: number)
		yaw = (yaw + DEG_PER_SEC * dt) % 360
		sky.SkyboxOrientation = Vector3.new(TILT_X, yaw, 0)
	end)
end
```

### Swapping skies

Changing sky per zone or weather: keep the alternative `Sky` objects in `ReplicatedStorage` and parent one into `Lighting` on the client. Adding or removing a `Sky` fires `Lighting.LightingChanged(true)` (Docs). Preload the six textures first (`ContentProvider:PreloadAsync` on the stored `Sky`), otherwise the first swap shows the default sky or blank faces for a moment while images stream in.

Art direction for skies (painted vs photographic, matching the horizon to terrain) is in [[Water Sky and Atmosphere Art]].

---

## 3. Dynamic clouds

`Clouds` render volumetric-looking clouds that drift with global wind.

- **They only render when parented under `Terrain`** (Docs). You can store a `Clouds` object elsewhere for replication or organisation, but it draws only under `Workspace.Terrain`.
- `Cover` (default 0.5): 0 sparse to 1 full cover.
- `Density` (default 0.7): particle density, mostly affecting transparency. Low = light wispy; high = heavy dark storm clouds.
- `Color` (default white): material colour, but strongly influenced by `Lighting` and `Atmosphere` settings, so it is not a sunset control on its own (Docs).
- `Enabled`: switch between several `Clouds` objects.
- Motion comes from `Workspace.GlobalWind` (direction and strength). The same vector moves terrain grass and, when `WindAffectsDrag` is on and `Drag > 0`, particles (Docs). Grass animation speed (not direction) drops for players with Reduce Motion enabled.

Weather transitions read well when cloud `Cover` and `Density` move together with `Atmosphere.Density` and `Haze` over 5 to 20 seconds (rule of thumb). The reference project's weather controller drove live sky, terrain clouds, zone air and a grade from one weather state, so a storm darkened all of them together.

---

## 4. Post-processing effects

Six effect classes exist (Docs): `BloomEffect`, `BlurEffect`, `ColorCorrectionEffect`, `DepthOfFieldEffect`, `SunRaysEffect`, `ColorGradingEffect`.

**Where you parent them decides who sees them** (Docs):
- In `Lighting`: every player sees them. Use for world mood (sun rays, base grade, base bloom).
- In the `Camera` (`Workspace.CurrentCamera`): only that player sees them. Use for personal feedback (menu blur, low-health tint, hit flash, ultimate grade).

Some effects may not show in Studio at a low **Editor Quality Level**; raise it to the highest level when authoring (Docs). Equally, test at the lowest level to see what weak devices get.

### Effect reference

| Effect | Properties and defaults (API dump) | Meaning (Docs) and use |
|---|---|---|
| `BloomEffect` | `Intensity` 0.4, `Size` 24, `Threshold` 0.95 | Colours brighter than `Threshold` glow. Threshold 1 = only pure white blooms, 0 = everything blooms. `Size` is the radius in pixels; 0 disables the bleed. |
| `BlurEffect` | `Size` 24 | Gaussian blur of the 3D view, radius in pixels. Menu backgrounds. Does not blur UI. |
| `ColorCorrectionEffect` | `Brightness` 0, `Contrast` 0, `Saturation` 0, `TintColor` white | Brightness -1 all black to 1 all white. Saturation -1 = greyscale. [[TintColor]] multiplies channels (red tint zeroes green and blue). |
| `DepthOfFieldEffect` | `FarIntensity` 0.75, `FocusDistance` 0.05, `InFocusRadius` 10, `NearIntensity` 0.75 | Blurs what is out of focus. Distances in studs from the camera. Shop previews, cutscene focus. |
| `SunRaysEffect` | `Intensity` 0.25, `Spread` 1 | Rays around the sun, shaped by objects between the camera and the sun. `Spread` should stay 0 to 1 (outside is undefined). |
| `ColorGradingEffect` | `TonemapperPreset` `Default` | How renderer colours map to screen range. `Retro` imitates pre-2019 Roblox (less saturation, less contrast). Must be parented to `Lighting`; only the most recently parented one applies; multiple do not combine. |

### Bloom and HDR brightness

Particles, beams and trails have a `Brightness` that can go far above 1 (beams and trails accept 0 to 10000, Docs). With `LightInfluence = 0`, a high-brightness additive particle produces scene colour above 1.0, and bloom catches it. That is why studied professional VFX packs ship with a strong bloom: one decoded pack set bloom to Intensity 1.6, Size 56, Threshold 2, and its flash particles at Brightness 10 to 40 rely on it (reference project study). With Threshold above 1, ordinary white parts and UI-coloured surfaces stop blooming, and only deliberately over-bright effects glow.

**Rule of thumb:** a combat game that wants glowing VFX without glowing white walls sets bloom Threshold around 1.5 to 2 and lets VFX Brightness do the work. A stylised game that wants Neon parts to glow sets Threshold near 0.9 to 1 and keeps white surfaces off-white.

### Ownership and stacking

Screen effects are shared state. In the reference project, ultimates owned screen grade, shake and FOV; every other VFX system was forbidden to draw them during an ultimate. Without that rule, a low-health red tint, a hit flash and an ultimate's purple grade all wrote `ColorCorrectionEffect.TintColor` and the last writer won every frame.

A small grade stack solves it: systems push requests with a priority, and one owner applies the winning request to one camera effect.

```lua
--!strict
-- GradeStack: one ColorCorrectionEffect in the camera, many requesters.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

export type Grade = {
	tint: Color3?,
	saturation: number?,
	contrast: number?,
	brightness: number?,
}

type Request = { id: string, priority: number, grade: Grade }

local GradeStack = {}
local requests: { [string]: Request } = {}
local effect: ColorCorrectionEffect? = nil
local current: Tween? = nil

local NEUTRAL: Grade = { tint = Color3.new(1, 1, 1), saturation = 0, contrast = 0, brightness = 0 }

local function getEffect(): ColorCorrectionEffect
	local cam = Workspace.CurrentCamera
	if effect and effect.Parent == cam then
		return effect
	end
	local e = Instance.new("ColorCorrectionEffect")
	e.Name = "GradeStack"
	e.Parent = cam
	effect = e
	return e
end

local function apply(fade: number)
	local best: Request? = nil
	for _, r in requests do
		if best == nil or r.priority > best.priority then
			best = r
		end
	end
	local g = if best then best.grade else NEUTRAL
	local e = getEffect()
	if current then
		current:Cancel()
	end
	current = TweenService:Create(e, TweenInfo.new(fade, Enum.EasingStyle.Quad), {
		TintColor = g.tint or Color3.new(1, 1, 1),
		Saturation = g.saturation or 0,
		Contrast = g.contrast or 0,
		Brightness = g.brightness or 0,
	})
	current:Play()
end

function GradeStack.push(id: string, priority: number, grade: Grade, fade: number?)
	requests[id] = { id = id, priority = priority, grade = grade }
	apply(fade or 0.25)
end

function GradeStack.pop(id: string, fade: number?)
	requests[id] = nil
	apply(fade or 0.4)
end

return GradeStack
```

Typical priorities: base zone grade 0, low health 10, status effects 20, cutscene or ultimate 100. A cutscene pushes at 100 and pops when done; the low-health tint is still in the stack and returns by itself.

### Blur behind menus

Blur behind a menu is the classic camera effect. Two cautions:
- Tween `Size` from 0 to 12 to 20 (rule of thumb) rather than snapping, and pop it on close. A blur left on after a menu errors out is a common "my screen is blurry" bug report; tie the blur's lifetime to the menu's lifetime (destroy it in the same cleanup that closes the menu).
- Players with motion sensitivity may prefer no blur; respect a reduce-motion or "simple effects" setting ([[Accessibility]]).

### Depth of field

`FocusDistance` and `InFocusRadius` are in studs from the camera. For a shop preview with the camera 8 studs from a model: `FocusDistance = 8`, `InFocusRadius = 3`, `FarIntensity = 0.6`, `NearIntensity = 0` (rule of thumb). Do not leave depth of field on during gameplay in a third-person action game: the character and the enemy are at different distances and one of them will be soft.

### Sun rays

`SunRaysEffect` only shows when the sun is on screen, and objects between camera and sun shape it (Docs). It costs little and sells a sunrise. Lower `Intensity` (0.05 to 0.15) reads as natural; the default 0.25 is already strong.

---

## 5. Putting it together: a mood is a bundle

A "mood" is never one property. A useful mood record names every value it touches, so that blending between moods is mechanical:

| Layer | Fields |
|---|---|
| Lighting | Ambient, OutdoorAmbient, Brightness, ColorShift_Top, [[ColorShift_Bottom]], ExposureCompensation |
| Atmosphere | Density, Offset, Haze, Color, Glare, Decay |
| Clouds | Cover, Density, Color |
| Grade (Lighting-level) | ColorCorrection Tint, Saturation, Contrast, Brightness |
| Bloom | Intensity, Size, Threshold |
| Sky | which Sky object, StarCount |

[[Lighting Mood and Time of Day]] shows how to interpolate such bundles across the day and across zones.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Fog stopped working | An `Atmosphere` was added | Use Atmosphere density and haze. |
| Skybox visible through mountains | `Offset` too low for the `Density` | Raise `Offset`. |
| Glare or Decay does nothing | `Haze` is 0 (and Glare 0 for Decay) | Raise Haze first. |
| Clouds do not appear | `Clouds` not under `Terrain` | Parent to `Workspace.Terrain`. |
| Clouds do not move | `GlobalWind` is zero | Set a wind vector. |
| Everything glows, including white walls | Bloom Threshold below 1 with bright surfaces | Threshold 1.5 to 2; let VFX Brightness exceed it. |
| Personal effect shown to everyone | Effect parented to `Lighting` from the server | Parent to `CurrentCamera` on the client. |
| Two ColorGradingEffects, one ignored | Only the most recently parented applies (Docs) | Keep one. |
| Screen stays blurry after closing a menu | Blur not tied to menu lifetime | Destroy it in the menu's cleanup. |
| Low-health tint lost after a cutscene | Two systems writing one effect | Grade stack with priorities. |
| Sky swap flashes default sky | Textures not preloaded | Preload the stored `Sky` first. |

## Checklist

- [ ] Atmosphere or fog, not both.
- [ ] Density and Offset tuned together; no ghosting at the horizon.
- [ ] Clouds under Terrain, moved by `GlobalWind`.
- [ ] World effects in `Lighting`, personal effects in the camera.
- [ ] Bloom threshold chosen for the art style; VFX brightness planned around it.
- [ ] One owner (or a priority stack) for screen grade, blur, shake and FOV.
- [ ] Alternative skies preloaded before swapping.
- [ ] Tested at lowest and highest Editor Quality Level.

See also: [[Lighting Technologies and Settings]], [[Lighting Mood and Time of Day]], [[Water Sky and Atmosphere Art]], [[VFX Design Playbook]], [[Game Feel and Juice]], [[Camera Shake and Camera FX]], [[Cinematic Ultimates]], [[Accessibility]].

## Connected notes
<!-- auto-links:start -->
[[Stylized Lighting Recipes]] · [[Links - Post-processing]] · Lighting Untextured Art in Roblox · Colour-Blind Safe Design · Environment Art Styles · Zone and Biome Art Direction
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Light Sources and Shadows]] · [[Weather System Architecture - State Machine, Transitions and Replication]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Particle Emitters In Depth]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[VFX Performance Budgets and Culling]]
<!-- related:end -->
