---
tags: [weather, snow, sandstorm, blizzard, ash, particles, atmosphere, recipes, type/recipe, area/vfx, area/lighting, level/intermediate, api/ParticleEmitter, api/Atmosphere, api/GlobalWind]
---
# Snow, Sandstorm, Blizzard and Ash Recipes

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Storm sold only by particles -> Push Atmosphere, clouds and grade first
> - Avoid: Sand colour with low Haze -> Raise Haze so `Color` shows
> - Avoid: Snow host too small -> Wider box, offset upwind
> - Each storm has Atmosphere, clouds, wind, grade, particles and sound in one look table.
> - Air values chosen so the storm reads with particles off.
> - Hosts sized for lifetime times wind drift; offset upwind.
>
> Cost: TL;DR ~150 tok · whole note ~2.8k tok. Read more: ## 2. Atmosphere and cloud values · ## 3. Particle recipes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Rain is fast, thin and vertical. Every other precipitation type is slow, soft and mostly sold by the **air**, not the particles: Atmosphere density and colour, cloud cover, wind, a colour grade and a sound bed. This note gives per-storm recipes as tables you can drop into the look data of a weather renderer ([[Weather System Architecture - State Machine, Transitions and Replication]]), plus the specific gotchas of each. The camera-local emitter host, shelter test and splash approach are shared with [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] and not repeated here.

Source labels: **Roblox docs** (create.roblox.com, as of October 2026), **Rule of thumb**, **Unverified**. All numeric values are tuning starting points, labelled Rule of thumb unless stated; they are not engine limits. Code is strict Luau, reviewed, not run.

---

## 1. What carries each storm

| Storm | Particles | Air (Atmosphere) | Wind | Grade | Sound |
|---|---|---|---|---|---|
| Light snow | Large, slow, sparse flakes | Slightly denser, cool haze | Low | Slight cool tint, brightness up a touch | Near silence, muffled |
| Blizzard | Many small fast streaks plus a few big flakes | Dense, bright white haze, low visibility | High, gusting | Desaturated, bright | Howling wind loop, gust one-shots |
| Sandstorm | Few visible grains; mostly drifting dust sheets | Dense, warm orange-brown `Color`, high `Haze` | High, steady direction | Warm, lower contrast | Hiss and low rumble |
| Ash fall | Slow dark flakes, some glowing embers | Grey-brown, medium density | Low, swirling | Desaturated, warm shadows | Distant rumble, crackle |

The key insight (Rule of thumb): on phones the particles are tiny and the air fills the whole screen. If the Atmosphere is right, players read the storm even when the particle tier is reduced to almost nothing.

## 2. Atmosphere and cloud values

`Atmosphere` properties are `Density`, `Offset`, `Color`, `Decay`, `Glare` and `Haze`; adding one hides the legacy fog properties (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/Atmosphere). Starting values (Rule of thumb):

| Storm | Density | Offset | Color | Decay | Glare | Haze | Clouds Cover |
|---|---|---|---|---|---|---|---|
| Clear baseline | 0.3 | 0.25 | (199,199,199) | (106,112,125) | 0 | 0 | 0.5 |
| Light snow | 0.38 | 0.2 | (215,225,235) | (170,180,195) | 0 | 1.5 | 0.8 |
| Blizzard | 0.6 | 0.05 | (235,240,245) | (220,225,235) | 0 | 6 | 1.0 |
| Sandstorm | 0.55 | 0.05 | (200,150,95) | (150,100,60) | 0 | 7 | 0.9 |
| Ash fall | 0.48 | 0.1 | (120,110,100) | (80,65,55) | 0 | 4 | 1.0 |

Gotchas:
- **Atmosphere colour is invisible at low Haze.** The docs note `Color` needs higher `Haze` to show; a "sandstorm" with Haze 1 just looks grey.
- **Density above ~0.6 swallows the skybox and distant terrain entirely.** That is the point in a blizzard, but check that objectives and teammates still read; pair it with [[Off-Screen Objective Markers and Waypoint Arrows]].
- **Atmosphere fog is client-side.** An exploiter can delete it. Do not build competitive hiding on fog alone ([[Weather That Changes Gameplay - Grip, Visibility and Hearing]]).
- `Clouds` must be a child of `Terrain`; `Cover` and `Density` are the two controls that matter (Roblox docs).

## 3. Particle recipes

Assume a camera-local box emitter host (Section 1 of the rain note). Values are per layer.

### Light snow

| Property | Value |
|---|---|
| Host box | 80 x 4 x 80, ~30 studs above camera |
| `Rate` | 60-150 |
| `Lifetime` | 6-9 |
| `Speed` | 2-4, `EmissionDirection = Bottom` |
| `Size` | 0.15-0.3, slight variation via `NumberSequence` keypoint envelope |
| `RotSpeed` | -40 to 40 |
| `Acceleration` | (0, -1, 0) |
| `Drag` | 1-2 with `WindAffectsDrag = true` |
| `Orientation` | `FacingCamera` |
| `LightEmission` | 0; `Brightness` 1-1.5 so flakes are white at dusk |

Long lifetimes mean the slab must be wide: a flake drifting at wind speed 6 for 8 s travels ~48 studs sideways. If the box is too small, the upwind side of the screen is empty. Offset the host upwind by `GlobalWind * lifetime * 0.5` (Rule of thumb).

### Blizzard

Two emitters on the same host:
- **Streaks:** `Rate` 400-800 at full tier, `Speed` 20-35, `Lifetime` 1.5-2, `Orientation = VelocityParallel`, `Squash` 1-2, `Size` 0.06-0.1, transparency 0.5-0.8. Wind does most of the motion; set `Drag` 2-3.
- **Big flakes:** 20-40 per second, `Size` 0.3-0.5, transparency 0.3, close to the camera for parallax.

Add **gusts**: every 4-10 s (random), lerp `GlobalWind` up by 50-80 percent over 1 s and back over 2-3 s, and play a gust one-shot in sync. Gusts are what make a blizzard feel alive rather than a constant white noise (Rule of thumb). Changing `GlobalWind` locally is fine because it is a render property; if gameplay needs wind (projectile drift), the server owns the gust schedule and replicates it the same way as weather state.

### Sandstorm

- **Dust sheets, not grains.** Large (`Size` 8-20), very transparent (0.85-0.95) soft-noise textures, `Rate` 10-25, `Lifetime` 3-5, moving horizontally with the wind. These do most of the work.
- **Grains:** a sparse streak layer close to the camera (`Rate` 100-200, `Size` 0.04-0.06, fast) so near motion reads.
- Ground-hugging: put a second host at camera height minus 3 with a short, wide box so dust rolls along the floor.
- Large transparent particles are the most expensive kind on phones because of overdraw ([[VFX Performance Budgets and Culling]]). Keep sheet counts low and cap them first on lower tiers.

### Ash fall

- **Ash:** like light snow but dark grey, `Rate` 40-100, slower `RotSpeed`, some flakes with a flipbook flutter if you have one.
- **Embers:** 5-15 per second, `LightEmission` 1, orange-to-dark `Color` sequence, `Lifetime` 3-5, slight upward `Acceleration` early. Embers are the "this is volcanic" signal; without them ash reads as dirty snow.
- Pair with a red-orange low sun or a `ColorCorrectionEffect` tint, and optionally a distant glowing plume model.

## 4. Ground and world response

- **Snow accumulation:** do not write terrain at runtime for weather. `Terrain:FillBlock` and similar calls on the server replicate voxel changes to everyone and are heavy (Rule of thumb). Instead pre-author a snowy variant (MaterialVariant swap on grass and rock, or `Terrain:SetMaterialColor` to whiten `Grass`, client-side) and blend it in over minutes. `SetMaterialColor` exists on Terrain (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/Terrain#SetMaterialColor).
- **Footprints:** pooled decals or thin parts placed on the client under feet while on snow, faded after ~20 s. Cap the pool.
- **Sand drifts:** art-placed dune meshes faded in; never procedural at runtime.
- **Ash:** a dark grade on surfaces via material override, same technique as wet surfaces.

## 5. Sound beds

| Storm | Loop | One-shots |
|---|---|---|
| Light snow | Very quiet wind, high frequencies cut | Occasional creak, crunch footsteps swap |
| Blizzard | Loud wind loop, pitch lifted slightly with gust intensity | Gusts every 4-10 s, synced with wind lerp |
| Sandstorm | Hiss plus low rumble | Gusts, debris rattles near props |
| Ash | Low rumble, crackle | Distant booms, synced with plume flashes |

Snow muffles the world: drop the ambience bus and other environmental loops a few dB or add a gentle low-pass during snowfall (Rule of thumb). It is a subtle but strong cue. See [[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]].

## 6. Data shape

Keep every value in the weather look table so transitions lerp them all together:

```lua
--!strict
export type StormLook = {
	atmosphere: { density: number, offset: number, haze: number, color: Color3, decay: Color3 },
	cloudsCover: number,
	wind: Vector3,
	gustStrength: number, -- 0 disables gusts
	layers: { [string]: number }, -- emitter name -> rate at full intensity and full quality
	grade: { brightness: number, saturation: number, tint: Color3 },
}

local Sandstorm: StormLook = {
	atmosphere = { density = 0.55, offset = 0.05, haze = 7,
		color = Color3.fromRGB(200, 150, 95), decay = Color3.fromRGB(150, 100, 60) },
	cloudsCover = 0.9,
	wind = Vector3.new(30, 0, 6),
	gustStrength = 0.5,
	layers = { DustSheets = 18, Grains = 150 },
	grade = { brightness = -0.05, saturation = -0.15, tint = Color3.fromRGB(255, 230, 200) },
}

return Sandstorm
```

The quality tier multiplies `layers` rates; the air values stay the same on every tier ([[Weather Performance Budgets and Quality Tiers]]).

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Storm sold only by particles | Looks like confetti on phones | Push Atmosphere, clouds and grade first |
| Sand colour with low Haze | Grey storm, no orange | Raise Haze so `Color` shows |
| Snow host too small | Empty upwind half of the screen | Wider box, offset upwind |
| Blizzard with constant wind | Monotone, lifeless | Gust schedule with synced audio |
| Runtime terrain writes for snow | Network spikes, server hitches | Client material colour or variant blend |
| Huge sand sheets everywhere | Phone frame rate halves | Few sheets, capped first on low tiers |
| Ash without embers | Reads as dirty snow | Sparse glowing embers |

## Checklist

- [ ] Each storm has Atmosphere, clouds, wind, grade, particles and sound in one look table.
- [ ] Air values chosen so the storm reads with particles off.
- [ ] Hosts sized for lifetime times wind drift; offset upwind.
- [ ] Gusts drive wind and audio from one schedule.
- [ ] Ground response pre-authored and blended, not generated at runtime.
- [ ] Objectives and teammates readable at the densest setting.
- [ ] Low tier tested with particle layers reduced.

## See also

[[Weather System Architecture - State Machine, Transitions and Replication]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Atmosphere Sky Clouds and Post-Processing]] · [[Particle Emitters In Depth]] · [[VFX Performance Budgets and Culling]] · [[Terrain Materials and Painting]] · [[Zone and Biome Art Direction]] · [[Water Sky and Atmosphere Art]] · [[Weather Performance Budgets and Quality Tiers]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]]

## Connected notes
<!-- auto-links:start -->
[[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Lighting Mood and Time of Day]] · [[MaterialService and Custom Materials]] · [[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Stylized Lighting Recipes]] · [[VFX Design Playbook]] · [[Impact Decals and Material-Aware Hit Sparks]] · [[Lighting Technologies and Settings]] · [[Light Sources and Shadows]] · [[Slash VFX Recipes - Crescent and Ring]] · [[Music and Adaptive Audio]] · [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]]
<!-- related:end -->
