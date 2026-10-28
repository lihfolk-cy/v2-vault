---
tags: [lighting, rendering, environment, settings, performance]
---
# Lighting Technologies and Settings

<!-- tldr:start -->
> [!tldr] TL;DR
> - Fog settings do nothing: An `Atmosphere` is in `Lighting` (fog properties are hidden and... -> Use `Atmosphere.Density`/`Haze` instead, or remove the Atmosphere.
> - Indoors is as bright as outdoors: `GlobalShadows` off, or `Ambient` channels above `OutdoorAmbient` -> Turn shadows on; keep `Ambient` at or below `OutdoorAmbient` per...
> - Light leaks through walls: Voxel-style path with walls under 4 studs thick -> Thicker or doubled walls, or a shadow-map path.
> - `LightingStyle` and `PrioritizeLightingQuality` chosen deliberately, not inherited from a template.
> - `GlobalShadows` on unless the art style needs it off; interiors sealed and thick enough.
> - `Ambient` at or below `OutdoorAmbient` in every channel.
>
> Read more (19 KB note): ## 1. Technology is deprecated: what replaced it · ## 3. The global properties, one by one · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The `Lighting` service decides how every pixel of your world is shaded: which shading path the renderer uses, how bright the sun is, what colour the shadows take, how far players can see when their device is struggling, and what "indoors" means. Most lighting problems people bring to a forum ("my game looks flat", "light leaks through the wall", "it looks great in Studio and grey on my phone", "shadows vanished") come from four or five properties and one deprecated setting that still appears in every old tutorial.

This note covers the lighting system as a whole: the old `Technology` modes and what replaced them, every global `Lighting` property and its trap, how quality scaling changes what players see, and how to manage lighting safely from code. The look itself (atmosphere, sky, clouds, post-processing) is in [[Atmosphere Sky Clouds and Post-Processing]]; local lights in [[Light Sources and Shadows]]; time of day and zone moods in [[Lighting Mood and Time of Day]].

Source labels: **Docs** = the official Roblox reference and guides (checked October 2026). **API dump** = the engine's own API dump (defaults are what `Instance.new` gives you). **Reference project** = one live action game whose lessons are anonymised here. **Rule of thumb** = experience, not a hard rule.

---

## 1. Technology is deprecated: what replaced it

For years the first lighting decision was `Lighting.Technology`: `Voxel`, `ShadowMap` or `Future` (plus the dead `Legacy` and `Compatibility`). As of October 2026 the docs mark `Lighting.Technology` as **deprecated**, superseded by two properties:

| New property | Type | Default (API dump) | Meaning (Docs) |
|---|---|---|---|
| `LightingStyle` | `Enum.LightingStyle` (`Realistic`, `Soft`) | `Realistic` | The artistic intent. `Realistic` is "the most advanced and realistic lighting and shadows Roblox can deliver"; `Soft` is "a flat, retro-Roblox look with softer lights and shadows". |
| `PrioritizeLightingQuality` | bool | `true` | When the device lowers its rendering quality, `true` keeps advanced shadows and high-quality shaders close to the camera at the cost of view distance; `false` keeps view distance and drops shading quality first. |

Two consequences matter in practice:

1. **Scripts cannot touch `Technology`.** Its security is `RobloxScriptSecurity` for both read and write (Docs). It was always "only modifiable in Studio"; now it is also hidden behind the new pair. Any tutorial that tells you to "set Technology to Future" is describing the old Properties window.
2. **The shading path is chosen by the engine from the pair.** The docs give exactly one mapping example: `Soft` with `PrioritizeLightingQuality` enabled "uses shadow maps rather than voxel lighting". Everything else about the mapping is not documented.

### The old enum, for reading old places and tutorials

| `Enum.Technology` item | Value | Status (Docs) | What it did |
|---|---|---|---|
| `Legacy` | 0 | Deprecated, cannot be selected | The pre-2019 renderer. |
| `Voxel` | 1 | Not deprecated as an enum item | Light and shadow from a 4 x 4 x 4 stud voxel grid. |
| `Compatibility` | 2 | Deprecated, cannot be selected | Simulated Legacy. Docs: to get the look now, use Voxel lighting plus a `ColorGradingEffect` set to `TonemapperPreset.Retro`. |
| `ShadowMap` | 3 | Not deprecated as an enum item | Shadow mapping: crisp sun (directional) shadows. |
| `Future` | 4 | Not deprecated as an enum item | "The most advanced technology for high-fidelity lighting and shadows." |
| `Unified` | 5 | Deprecated, cannot be selected | Briefly offered; gone. |

### Approximate equivalence (rule of thumb, partly unverified)

| Old setting you are migrating from | Closest new setting | Confidence |
|---|---|---|
| `Future` | `Realistic`, `PrioritizeLightingQuality = true` | Rule of thumb. Realistic is described the same way Future was. |
| `ShadowMap` | `Soft`, `PrioritizeLightingQuality = true` | Docs give this example (Soft + priority = shadow maps). |
| `Voxel` | `Soft`, `PrioritizeLightingQuality = false` | Unverified. Implied by the docs' example, not stated. |
| `Compatibility` / Legacy look | `Soft` plus `ColorGradingEffect` (`Retro`), light brightness at most 1 | Docs (for the colour part). |

When you open an old place, do not trust your memory of what it "was set to". Look at the current Properties window, play it on a phone and a PC, and compare captures. If the look changed after the migration, the culprit is usually `ShadowSoftness`, `EnvironmentDiffuseScale` or local lights that used to leak through voxels and no longer do.

---

## 2. How the shading paths differ (and why it matters for content)

The engine's internals are not documented in detail, so this section is the behaviour you can observe and design around.

### Voxel-style lighting
- The world is sampled into a grid of 4 x 4 x 4 stud cells (Docs, `GlobalShadows`). Objects smaller than a cell do not cast a believable sun shadow. Thin walls (under a cell thick) leak light from one side to the other.
- Shadows are "recalculated when parts are moving" (Docs). Many moving parts mean continuous relighting work.
- Local lights light the grid, not the pixel: a torch on a wall lights a soft blob, not a sharp pool.
- It is the cheapest path and the most forgiving on low-end phones.

**Content rules under voxel lighting:** walls and roofs at least 4 studs thick where light separation matters (or double them up), interiors sealed on all sides, and do not rely on small props to cast readable shadows.

### Shadow-map lighting
- Sun and moon cast crisp shadows from geometry of any size. `ShadowSoftness` blurs their edges.
- Local lights still light the scene, but whether they cast their own shadows depends on the path (see [[Light Sources and Shadows]]).

### Realistic (the old Future)
- Per-pixel local lighting with specular highlights, shadows from local lights where enabled, and the environment terms (`EnvironmentDiffuseScale`, `EnvironmentSpecularScale`) doing visible work on PBR materials.
- The most expensive path. On weak devices the engine scales it down; `PrioritizeLightingQuality` decides whether it gives up shading quality or view distance first.

### What players actually see

Players do not all see your "Realistic" scene. The device's graphics quality level (automatic for most players) decides how much of the path survives. The docs repeatedly advise testing at the lowest and highest **Editor Quality Level** in Studio Settings, because post-processing effects and particle detail change with it. A scene lit only by fine local-light shadows can collapse to flat ambient on a phone.

**Rule of thumb:** design the scene to read under the cheapest path first (silhouette, value contrast, colour zones), then let the realistic path add richness. Never make gameplay information (a dark doorway that means danger, a lit path that means "go here") depend on shadows alone.

---

## 3. The global properties, one by one

Defaults below are the API dump's `Instance.new`-style defaults. **Studio's place templates ship their own values** (a new Baseplate is not lit with these numbers), so always read your own place rather than assuming.

| Property | Default (API dump) | What it really does | Trap |
|---|---|---|---|
| `Ambient` | (0.5, 0.5, 0.5) | Hue for areas occluded from the sky (indoors). | Docs: if a channel of `Ambient` exceeds the same channel of `OutdoorAmbient`, it starts applying outdoors too. With `GlobalShadows` off, `Ambient` applies everywhere and `OutdoorAmbient` is ignored. |
| `OutdoorAmbient` | (0.5, 0.5, 0.5) | Hue for outdoor areas. | Clamped to be at least `Ambient` per channel (Docs). |
| `Brightness` | 1 | Strength of the sun or moon's direct light. | Does not brighten shadowed areas; ambient does. Raising it on a dark scene raises contrast, not visibility. |
| `ColorShift_Top` | (0, 0, 0) | Tint on surfaces facing the sun or moon. | Interacts with ambient values above black (Docs). A strong warm top shift is a cheap golden-hour. |
| `ColorShift_Bottom` | (0, 0, 0) | Tint on surfaces facing away from the sun. | Docs note its influence depends on sun position; at noon it only reaches downward faces. |
| `EnvironmentDiffuseScale` | 0 | Ambient light derived from the sky, changing with sky and time of day. | Docs: when you raise it, lower `Ambient` and `OutdoorAmbient`, or the scene washes out. |
| `EnvironmentSpecularScale` | 0 | Sky reflections on smooth and metallic surfaces. | At 0, metal looks like grey plastic. Near 1 it reads as metal (Docs). |
| `ExposureCompensation` | 0 | Exposure bias before tonemapping. Range -5 to 5; +1 is twice the exposure, -1 half (Docs). | A blunt instrument: it brightens UI-adjacent world too. Use it for whole-scene corrections (a dim cave set), not for single objects. |
| `GlobalShadows` | false (API dump) | Turns on the sky-occlusion system: shadows and the indoor/outdoor distinction. | Off means "everything is outdoors and nothing is outdoors": `Ambient` everywhere. Changing it does not fire `LightingChanged` (Docs). |
| `ShadowSoftness` | 0.5 (API dump) | Blur of sun shadows, 0 hard to 1 soft. | Docs say it only works with `LightingStyle = Realistic`; the reference page still says "default 0.2" and mentions ShadowMap/Future. Defaults disagree between sources; set it explicitly. |
| `ClockTime` / `TimeOfDay` | 14 / "14:00:00" | Time of day as hours (number) or a 24-hour string; changing one changes the other. | Not replicated as a property (`NotReplicated` in the API dump) and does not advance by itself. See [[Lighting Mood and Time of Day]]. |
| `GeographicLatitude` | 41.73 | Moves the sun and moon path. | Does not change `ClockTime` (Docs). High latitudes give long, low shadows all day. |
| `FogColor`, `FogStart`, `FogEnd` | 0.75 grey, 0, 100000 | Linear distance fog. | **Hidden when `Lighting` contains an `Atmosphere`** (Docs). If your fog "does nothing", check for an Atmosphere. Fog changes do not fire `LightingChanged`. |
| `ShadowColor` | n/a | Docs: "supposed to change the color of player shadows, but currently doesn't do anything". | Do not waste an afternoon on it. |
| `LightingStyle`, `PrioritizeLightingQuality` | `Realistic`, `true` | See section 1. | Set by intent, not by habit. A stylised low-poly game often looks better and runs better on `Soft`. |

Methods worth knowing (Docs): `GetSunDirection()` and `GetMoonDirection()` return world directions (still pointing below the horizon after setting), `SetMinutesAfterMidnight(n)` sets the time numerically (values over 24 hours roll into the next day), `GetMoonPhase()` always returns 0.75 because the phase cannot be changed.

### `LightingChanged` is not a full change signal

`Lighting.LightingChanged(skyChanged)` fires when a `Lighting` property changes or a `Sky` is added or removed, **except** `GlobalShadows` and the fog properties (Docs). A system that watches it to rebuild something (a cached mood, a UI preview) will miss those. Use `GetPropertyChangedSignal` for the specific properties you care about.

---

## 4. Who owns Lighting: server or client?

`Lighting` and its children replicate from server to client like any other service content. But mood is a per-player thing: a player in a cave and a player on a beach in the same server should not share one `Ambient`.

| Pattern | When | How |
|---|---|---|
| Server sets everything | Single-area games, round-based maps where everyone is in the same place | Server script writes `Lighting` properties; they replicate. |
| Server publishes facts, client renders mood | Open worlds, zones, weather, day/night | Server writes **attributes** (time epoch, cycle length, current weather, weather end time); each client computes and applies its own `Lighting` values locally. |
| Client only | Purely cosmetic per-player effects (low-health tint, menu blur, cutscene grades) | LocalScript, effects parented to the camera (see [[Atmosphere Sky Clouds and Post-Processing]]). |

The reference project used the middle pattern: the server owns a weather service that sets attributes such as the current weather, its start and end times, and the day epoch and cycle length; one client controller turns those into sky, clouds, zone air, colour grade, rain and lightning. Client-side changes to `Lighting` do not replicate, which is exactly what you want here.

**The one rule that keeps this sane:** exactly one client system writes each `Lighting` property at a time. When a cutscene needs the lighting, it sets a flag (the reference project used a player attribute) and the weather and mood controller steps aside until the flag clears. Two systems tweening `Ambient` against each other produce a flicker that is very hard to trace.

---

## 5. Safe lighting changes in Studio

Lighting is global state, and Edit-mode previews leak. The reference project learned two lessons:

1. **Captures must restore lighting exactly.** Previews that apply a zone preset to `Lighting` and `Atmosphere` for a screenshot must put back every value afterwards. One preview left on shipped a wrong look.
2. **A client mood controller that reads the place's `Atmosphere` as its "base air" at Play start will bake in whatever was left there in Edit.** If an Edit preview changed the atmosphere and nobody switched it off, every play session started from the wrong base.

A snapshot and restore helper prevents both. Run it from the command bar or a plugin around any preview.

```lua
--!strict
-- LightingSnapshot: capture and restore Lighting properties and its children.
local Lighting = game:GetService("Lighting")

local PROPS = {
	"Ambient", "OutdoorAmbient", "Brightness", "ColorShift_Top", "ColorShift_Bottom",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ExposureCompensation",
	"GlobalShadows", "ShadowSoftness", "ClockTime", "GeographicLatitude",
	"FogColor", "FogStart", "FogEnd", "LightingStyle", "PrioritizeLightingQuality",
}

export type Snapshot = {
	props: { [string]: any },
	children: { Instance },
}

local LightingSnapshot = {}

function LightingSnapshot.take(): Snapshot
	local props: { [string]: any } = {}
	for _, name in PROPS do
		props[name] = (Lighting :: any)[name]
	end
	local children: { Instance } = {}
	for _, child in Lighting:GetChildren() do
		-- Sky, Atmosphere, post effects. Clone needs Archivable = true.
		if child.Archivable then
			table.insert(children, child:Clone())
		end
	end
	return { props = props, children = children }
end

function LightingSnapshot.restore(snap: Snapshot)
	for name, value in snap.props do
		(Lighting :: any)[name] = value
	end
	for _, child in Lighting:GetChildren() do
		if child.Archivable then
			child:Destroy()
		end
	end
	for _, clone in snap.children do
		clone:Clone().Parent = Lighting -- keep the snapshot reusable
	end
end

return LightingSnapshot
```

Usage: `local s = LightingSnapshot.take()` before the preview, `LightingSnapshot.restore(s)` after it. Keep the snapshot in a module so a crashed preview can still be restored from the command bar.

---

## 6. Choosing a setup

| Game | `LightingStyle` | `PrioritizeLightingQuality` | `GlobalShadows` | Notes |
|---|---|---|---|---|
| Stylised simulator, tycoon, obby | `Soft` | false | true | Bright ambient, strong colour shifts, bloom on Neon. Readability over realism. View distance matters for open maps. |
| Combat game with heavy VFX | `Soft` or `Realistic` | true | true | VFX carry their own light (additive particles, Neon). Local lights capped per effect. See [[VFX Design Playbook]]. |
| Horror, interiors, exploration | `Realistic` | true | true | Darkness is content. Local-light shadows matter. Test hard on phones. See [[Genre Playbook - Horror and Story]]. |
| Showcase, realistic architecture | `Realistic` | true | true | `EnvironmentSpecularScale` near 1, `EnvironmentDiffuseScale` up with ambient down, PBR materials. |
| Huge open world for low-end devices | `Soft` | false | true | Keep view distance. Fake depth with `Atmosphere` and colour. |

---

## 7. Performance notes

- Shadows from local lights are among the more expensive lighting features; many overlapping shadow-casting lights in one view cost the most (rule of thumb). See [[Light Sources and Shadows]] for budgets.
- Voxel-based shadow updates are triggered by moving parts (Docs). A spinning windmill made of 200 parts relights constantly; collapse it into one mesh.
- `GlobalShadows = false` is a valid look for some stylised games and removes a class of problems (indoor darkness on badly sealed buildings), but you lose the indoor/outdoor split.
- The reference project kept a tag (`ThinnedForPerf`) on lights it disabled for performance: **disabled, not deleted**, so they could be re-enabled per quality tier later and so nobody re-added them by accident.
- Measure with the MicroProfiler and the render stats in [[Developer Console and Stats]], not by eye in Studio on a fast PC. See [[Rendering Performance]] and [[Mobile and Low-End Optimization]].

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Fog settings do nothing | An `Atmosphere` is in `Lighting` (fog properties are hidden and ignored) | Use `Atmosphere.Density`/`Haze` instead, or remove the Atmosphere. |
| Indoors is as bright as outdoors | `GlobalShadows` off, or `Ambient` channels above `OutdoorAmbient` | Turn shadows on; keep `Ambient` at or below `OutdoorAmbient` per channel. |
| Light leaks through walls | Voxel-style path with walls under 4 studs thick | Thicker or doubled walls, or a shadow-map path. |
| Metal looks like plastic | `EnvironmentSpecularScale` at 0 | Raise it toward 1 on scenes with metal. |
| Scene washed out after raising environment diffuse | Ambient not lowered to compensate | Docs: lower `Ambient` and `OutdoorAmbient` when raising it. |
| "It looked different yesterday" | An Edit preview left `Lighting` or `Atmosphere` changed | Snapshot and restore around previews. |
| Day/night flickers | Two scripts writing `ClockTime` or `Ambient` | One owner per property; others step aside by flag. |
| Script error setting `Technology` | Property is deprecated and script-locked | Use `LightingStyle` and `PrioritizeLightingQuality`. |
| Shadow colour change ignored | `ShadowColor` does nothing (Docs) | Tint with `Ambient` and `ColorShift_Bottom`. |
| Perfect on PC, flat on phone | Look depends on high-quality shading | Design for the low path; test at lowest Editor Quality Level. |

## Checklist

- [ ] `LightingStyle` and `PrioritizeLightingQuality` chosen deliberately, not inherited from a template.
- [ ] `GlobalShadows` on unless the art style needs it off; interiors sealed and thick enough.
- [ ] `Ambient` at or below `OutdoorAmbient` in every channel.
- [ ] Environment terms set to match the materials (diffuse with lowered ambient, specular for metal).
- [ ] Fog vs Atmosphere: one system, not both.
- [ ] One owner per `Lighting` property at runtime; cutscenes take over by flag.
- [ ] Previews snapshot and restore `Lighting` and its children.
- [ ] Tested at lowest and highest Editor Quality Level and on a real phone.

See also: [[Atmosphere Sky Clouds and Post-Processing]], [[Light Sources and Shadows]], [[Lighting Mood and Time of Day]], [[Water Sky and Atmosphere Art]], [[Environment Art Styles]], [[Materials MaterialVariants and SurfaceAppearance]], [[Rendering Performance]], [[Mobile and Low-End Optimization]], [[Studio Settings and Shortcuts]].

## Connected notes
<!-- auto-links:start -->
[[Stylized Lighting Recipes]] · [[Lighting Untextured Art in Roblox]] · [[Links - Lighting]] · [[Baking Lighting and Detail into Textures]] · [[Voxel Shading - Baked AO Edges and Lighting]] · [[Stylised vs Realistic Material Pipelines]]
<!-- auto-links:end -->
