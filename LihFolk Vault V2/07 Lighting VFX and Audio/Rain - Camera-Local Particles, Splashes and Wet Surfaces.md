---
tags: [weather, rain, particles, vfx, raycast, materials, wetness, type/recipe, area/vfx, level/intermediate, api/ParticleEmitter, api/MaterialService, api/Raycast]
---
# Rain - Camera-Local Particles, Splashes and Wet Surfaces

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: One emitter covering the whole map -> Camera-local slab
> - Avoid: `LockedToPart = true` -> Leave unlocked
> - Avoid: Host lerped to the camera -> Snap to camera each frame
> - Rain host is client-only, anchored, non-colliding, snapped above the camera.
> - `Rate`, sound volume and wetness all driven by one intensity value.
> - Near and far layers; streaks use `VelocityParallel` and `Squash`.
>
> Cost: TL;DR ~140 tok · whole note ~2.9k tok. Read more: ## 1. The camera-local volume · ## 3. Splashes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Convincing rain is not "a big emitter over the map". It is a small volume of streaks that follows the camera, a sparse set of splashes placed where drops would actually land, a roof test so it does not rain indoors, a darker and shinier ground, and a sound bed. Every piece runs on the client and scales with the intensity value handed down by the weather renderer ([[Weather System Architecture - State Machine, Transitions and Replication]]). This note gives a recipe for each layer and the gotchas that make rain look cheap or cost too much.

Source labels: **Roblox docs** (create.roblox.com, as of October 2026), **Rule of thumb**, **Unverified**. Numbers are starting points to tune, not engine limits. Code is strict Luau, reviewed, not run.

---

## 1. The camera-local volume

Make one anchored, invisible, non-colliding part (`CanCollide`, `CanQuery`, `CanTouch` all false) as the rain emitter host, parented to a client-only folder under the camera or `Workspace`. Each frame move it above the camera.

| ParticleEmitter property | Starting value | Why |
|---|---|---|
| `Shape` | `Box`, `ShapeStyle = Volume` | Spawn throughout the box, not on its faces (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter) |
| Host part size | 70 x 4 x 70 studs | Thin slab ~25 studs above the camera; drops fall into view |
| `EmissionDirection` | `Bottom` | Falls down from the slab |
| `Speed` | 60-80 | Fast enough to read as streaks |
| `Lifetime` | 0.5-0.8 | Long enough to reach the ground from the slab, short enough to die below it |
| `Orientation` | `VelocityParallel` | Streak aligns with its velocity, so wind tilts it automatically |
| `Size` | 0.08-0.12 | Thin; width is the texture's job |
| `Squash` | positive (e.g. 2-3) | Stretches along velocity for a streak look (Roblox docs) |
| `Transparency` | 0.4-0.7 | Rain is mostly read through motion |
| `LightEmission` | 0 to 0.2 | Above that it glows at night |
| `WindAffectsDrag` + `Drag` ~0.5 | on | `GlobalWind` slants it with no code |
| `Rate` | `intensity * maxRate` | Single knob from the weather state |

Gotchas:
- **Do not set `LockedToPart = true`.** Locked particles move with the host, so when the camera turns or the player runs, the whole curtain slides with them and looks like a screen overlay. Unlocked particles stay in world space once spawned, which is what rain does (Roblox docs describe `LockedToPart` as making particles follow the emitter).
- **Lead the camera when moving fast.** In a car at 100 studs/s the slab is behind you by the time drops fall. Offset the host by `velocity * 0.3` along the camera's motion (Rule of thumb).
- **Two layers beat one dense layer.** A near layer (small box, few, larger, blurry drops) and a far layer (bigger box, many thin streaks, higher transparency) give depth for fewer particles than one huge box.
- **Snap, do not lerp,** the host position. Lerping makes drops visibly drift sideways during turns.

## 2. Indoors and under roofs

The emitter cannot know about roofs. Two complementary tests:

1. **Zone volumes** for interiors (preferred): when the player is inside an interior zone, fade rain `Rate` to 0 and switch to the muffled indoor rain loop. See [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]].
2. **Roof ray** for everywhere else: every 0.2 s cast a ray straight up from the camera for ~60 studs. If it hits, the player is sheltered; ramp rate down over 0.3 s.

```lua
--!strict
local Workspace = game:GetService("Workspace")
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local function isSheltered(camPos: Vector3, ignore: {Instance}): boolean
	params.FilterDescendantsInstances = ignore -- player's character + rain folder
	return Workspace:Raycast(camPos, Vector3.new(0, 60, 0), params) ~= nil
end
```

A single upward ray flickers under trees and lattices. Cast 3 rays in a small triangle and require 2 hits, or tag leafy canopies with a collision group the rain ray ignores (Rule of thumb).

Drops still fall through roofs visually when the slab is above a roof but the camera is outside under the eaves. Accept it, or shrink the slab when the roof ray hits something within 10 studs.

## 3. Splashes

Particles have no collision, so splashes must be placed separately. Cheapest convincing approach (Rule of thumb):

- Every 0.05-0.1 s, pick N random points in a disc of radius ~35 around the camera (N scales with intensity, e.g. 2-8).
- Raycast down from 40 studs above each point. Skip if the hit is a sheltered surface (ray hit something above head height on the way down, or the hit instance is tagged `NoRain`).
- Move a pooled attachment to the hit position and call `Emit(2)` on a small splash emitter there (short lifetime 0.15-0.25 s, upward speed 4-8, small flipbook ring if you have one). `ParticleEmitter:Emit(count)` spawns a burst immediately (Roblox docs).
- On water (`hit.Material == Enum.Material.Water`), emit a ring instead of a crown.

```lua
--!strict
local Workspace = game:GetService("Workspace")
local rng = Random.new()

local function splashTick(center: Vector3, count: number, emitters: {ParticleEmitter}, params: RaycastParams)
	for i = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = 35 * math.sqrt(rng:NextNumber()) -- uniform over the disc
		local origin = center + Vector3.new(math.cos(angle) * radius, 40, math.sin(angle) * radius)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -80, 0), params)
		local emitter = emitters[(i - 1) % #emitters + 1]
		if hit and emitter.Parent and emitter.Parent:IsA("Attachment") then
			(emitter.Parent :: Attachment).WorldPosition = hit.Position + hit.Normal * 0.05
			emitter:Emit(2)
		end
	end
end
```

Use a small pool (8-16) of attachments on one anchored part and round-robin them; an attachment can be moved after `Emit` because already-emitted, unlocked particles stay where they spawned (Rule of thumb, consistent with world-space emission). Raycasts this frequent are cheap compared with the particles they spawn, but keep them under ~100 per second.

## 4. Wet surfaces

Options from cheapest to most work:

| Approach | Effect | Cost and gotchas |
|---|---|---|
| Darker grade | `ColorCorrectionEffect` lower brightness, slight saturation drop, cooler tint | Free; affects everything including UI-coloured parts, so keep it subtle |
| Atmosphere | Higher `Haze`, lower `Glare` | Free; already part of the weather look |
| Material override swap | Client calls `MaterialService:SetBaseMaterialOverride(Enum.Material.Concrete, "WetConcrete")` etc. pointing at `MaterialVariant`s with a darker colour map and smoother roughness map | Client-local, affects every part using that base material. Swapping causes new textures to load; preload variants with `ContentProvider:PreloadAsync` and swap at alpha ~0.5 behind haze (Rule of thumb) |
| Per-part tag | Tag hero surfaces (`Wettable`) and swap their `MaterialVariant` name | Precise; costs a loop over tagged parts once per transition |
| Puddles | Pre-placed flat decals or thin parts, transparency faded by intensity | Art-directed and cheap; place them in dips where water would collect |
| Terrain water tweaks | `Terrain.WaterWaveSize` and `WaterWaveSpeed` up slightly during storms | Real properties; affects all terrain water |

`MaterialService:SetBaseMaterialOverride` exists and is per-client when called from a LocalScript (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/MaterialService). Whether the override swap causes a frame hitch on low-end devices: **Unverified**; measure with the MicroProfiler before shipping it as an always-on effect. See [[MaterialService and Custom Materials]].

Wetness should lag the rain: start darkening ~10 s after rain begins and dry over ~60 s after it stops (Rule of thumb). Instant dry ground when the rain stops is the most common tell.

## 5. Sound

- A non-positional loop (`Sound` under `SoundService` or a local `AudioPlayer` wired to the listener) with volume tied to intensity.
- Swap to a muffled "rain on roof" loop when sheltered, cross-faded over ~0.5 s; or run the same loop through an `AudioFilter` low-pass when indoors with the Audio API ([[The Audio API - Players Emitters Wires and Effects]]).
- Optional positional drips near gutters and tin roofs, placed by artists, faded by intensity.
- Keep it in the ambience bus so players can turn it down ([[Spatial Audio and Mixing]]).

## 6. Accessibility and readability

- Heavy rain plus a dark grade can make enemies and pickups unreadable. Cap the screen-space opacity of near drops and never lower contrast on interactables ([[Accessibility Contrast]]).
- Offer a "weather effects: full / reduced / off" setting. Reduced drops near-layer particles and splashes; off keeps only sound and grade ([[Weather Performance Budgets and Quality Tiers]]).

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| One emitter covering the whole map | Huge particle count, thin rain near the player | Camera-local slab |
| `LockedToPart = true` | Rain slides with the camera like a filter | Leave unlocked |
| Host lerped to the camera | Drops drift sideways in turns | Snap to camera each frame |
| No shelter test | Rain inside houses and tunnels | Interior zones plus roof ray |
| Splash on every drop | Particle count doubles | Sparse random raycast splashes |
| Instant dry ground | Weather feels fake | Delay wet-in and slow dry-out |
| Material swap at alpha 0 | Visible texture pop | Preload, swap behind haze |
| Server-side rain emitters | Every client renders everyone's rain | Client only |

## Checklist

- [ ] Rain host is client-only, anchored, non-colliding, snapped above the camera.
- [ ] `Rate`, sound volume and wetness all driven by one intensity value.
- [ ] Near and far layers; streaks use `VelocityParallel` and `Squash`.
- [ ] Interior zones and roof ray stop rain indoors without flicker.
- [ ] Splashes pooled, sparse and skipped on sheltered surfaces.
- [ ] Wet look delayed in and slow out; material variants preloaded.
- [ ] Reduced and off settings tested on a low-end phone.

## See also

[[Weather System Architecture - State Machine, Transitions and Replication]] · [[Particle Emitters In Depth]] · [[Raycasts Shapecasts and Spatial Queries]] · [[MaterialService and Custom Materials]] · [[Materials MaterialVariants and SurfaceAppearance]] · [[Atmosphere Sky Clouds and Post-Processing]] · [[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Object Pooling]] · [[Weather Performance Budgets and Quality Tiers]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]]

## Connected notes
<!-- auto-links:start -->
[[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] · Terrain Deep Dive - Materials Water and Performance · [[VFX Performance Budgets and Culling]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Weather That Changes Gameplay - Grip, Visibility and Hearing]] · [[Impact Decals and Material-Aware Hit Sparks]] · [[Lighting Mood and Time of Day]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Stylized Lighting Recipes]] · [[VFX Design Playbook]] · [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]] · [[Designing VFX Textures and Flipbooks in Figma]] · [[Music and Adaptive Audio]]
<!-- related:end -->
