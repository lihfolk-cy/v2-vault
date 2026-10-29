---
tags: [weather, performance, particles, mobile, quality-tiers, budgets, low-end, type/guide, area/performance, area/vfx, level/intermediate, api/ParticleEmitter, api/UserGameSettings, api/RenderStepped]
---
# Weather Performance Budgets and Quality Tiers

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Budgeting by `Rate` -> Budget alive count = rate x lifetime
> - Avoid: Tiers thin the fog -> Air identical on every tier
> - Avoid: Relying on engine auto-scaling -> Your own per-tier caps
> - Per-tier budgets written for alive particles, large particles, rays, segments and script time.
> - Visibility and gameplay identical across tiers.
> - Starting tier from saved quality where manual, else platform default.
>
> Cost: TL;DR ~150 tok · whole note ~2.8k tok. Read more: ## 4. Choosing the starting tier · ## 5. Adaptive governor · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Weather is the one effect that is on screen for every player, all the time, for minutes. A storm that costs 2 ms on a desktop GPU can cost 8 ms on a mid-range phone through overdraw alone, and it never goes away like a hit spark does. This note sets budgets for weather specifically, defines quality tiers that cut cost without changing what players can see (a fairness rule, not just a performance one), and gives a small adaptive governor that steps down when frame time suffers. General VFX budgeting, pooling and the cost model for emitters are in [[VFX Performance Budgets and Culling]]; this note applies them to persistent, full-screen effects.

Source labels: **Roblox docs** (create.roblox.com, as of October 2026), **Measured** (none yet in this note; add your own MicroProfiler captures), **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

---

## 1. Where weather cost goes

| Cost | Comes from | Scales with |
|---|---|---|
| Overdraw (GPU fill) | Large transparent particles covering the screen: dust sheets, near snowflakes, fog cards | Screen coverage times layers stacked; worst on phones |
| Particle simulation and upload | Particle count alive at once (`Rate * Lifetime` per emitter) | Count; mostly CPU on the render side |
| Script cost | Per-frame renderer, splash raycasts, roof rays, gust lerps | Number of operations per frame |
| Instance churn | Creating and destroying bolt parts, splash attachments, footprint decals | Strikes and events per second |
| Lighting changes | Frequent `Lighting` and `Atmosphere` writes; material override swaps | Usually small; swaps can hitch (Unverified) |
| Audio | Many simultaneous loops and one-shots | Voices playing |

Two facts worth internalising (Rule of thumb):
- **Alive count, not rate, is the budget.** An emitter with `Rate = 150` and `Lifetime = 8` keeps about 1200 flakes alive. Halve lifetime before halving rate if the look allows it.
- **Screen coverage dominates on mobile.** Ten 15-stud dust sheets near the camera cost more than a thousand tiny rain streaks.

## 2. Budgets per tier

Starting budgets for the whole weather system on one client (Rule of thumb; validate with your own captures on target devices):

| Tier | Target device | Alive weather particles | Large (> 4 stud) transparent particles | Splash raycasts/s | Lightning segments | Weather script time |
|---|---|---|---|---|---|---|
| High | Desktop, recent consoles | 2500 | 30 | 100 | 120 | < 0.5 ms |
| Medium | Recent phones and tablets | 1000 | 12 | 40 | 60 | < 0.3 ms |
| Low | Older phones, low graphics setting | 300 | 4 | 0 | 30 | < 0.2 ms |
| Off (player setting) | Anyone | 0 | 0 | 0 | 0 (flash only) | < 0.1 ms |

The engine already reduces some rendering work at lower graphics quality levels; how much it reduces particle emission per level is **Unverified** (not documented as a per-level table). Do not rely on it; enforce your own caps.

## 3. What tiers may and may not change

| May change per tier | Must stay identical on every tier |
|---|---|
| Particle rates, lifetimes, layer count | `Atmosphere` density and haze (visibility) |
| Splash and footprint systems on or off | Cloud cover that hides or reveals sky objectives |
| Lightning segment count and branches | Lightning **telegraphs** for hazard strikes |
| Wet material swaps on or off | Gameplay multipliers (grip, sight, hearing) |
| Gust audio one-shots | Weather state itself |

The right column is a fairness rule: if low tier means thinner fog, low-end players see further in PvP ([[Weather That Changes Gameplay - Grip, Visibility and Hearing]]). Make the air do the reading, and let particles be the luxury layer ([[Snow, Sandstorm, Blizzard and Ash Recipes]]).

## 4. Choosing the starting tier

`UserGameSettings.SavedQualityLevel` reports the player's graphics setting as an `Enum.SavedQualitySetting`; when the player uses automatic quality it reports `Automatic`, which tells you nothing about the actual level (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/UserGameSettings). So:

1. Start at Medium (or High on non-touch platforms, Medium on touch).
2. If the saved level is set manually, map it: 1-3 to Low, 4-7 to Medium, 8-10 to High (Rule of thumb).
3. Let the governor (section 5) adjust from there.
4. Always honour an in-game "Weather effects: Full / Reduced / Off" setting above all of this, saved in the player's settings data.

```lua
--!strict
local UserInputService = game:GetService("UserInputService")

export type Tier = "High" | "Medium" | "Low" | "Off"

local function initialTier(): Tier
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if ok and level ~= Enum.SavedQualitySetting.Automatic then
		local n = level.Value -- QualityLevel1 .. QualityLevel10 have values 1..10
		if n <= 3 then return "Low" elseif n <= 7 then return "Medium" else return "High" end
	end
	return if UserInputService.TouchEnabled then "Medium" else "High"
end
```

The `.Value` mapping assumes the enum items `QualityLevel1` to `QualityLevel10` carry values 1 to 10 and `Automatic` is 0: check in Studio before relying on it (Unverified).

## 5. Adaptive governor

Measure frame time on the client and step down when it stays bad, step up slowly when it stays good. Hysteresis prevents oscillation.

```lua
--!strict
local RunService = game:GetService("RunService")

local ORDER: {string} = { "Low", "Medium", "High" }
local index = 2
local avg = 1 / 60
local badSince: number? = nil
local goodSince: number? = nil
local cap = 3 -- player setting can lower this; never step above it

local onTierChanged: (tier: string) -> () = function(_tier) end -- assigned by the weather renderer

RunService.RenderStepped:Connect(function(dt: number)
	avg = avg + (dt - avg) * 0.05 -- exponential moving average
	local now = os.clock()
	if avg > 1 / 40 then -- below ~40 fps sustained
		goodSince = nil
		badSince = badSince or now
		if now - (badSince :: number) > 4 and index > 1 then
			index -= 1; badSince = nil
			onTierChanged(ORDER[index])
		end
	elseif avg < 1 / 55 then
		badSince = nil
		goodSince = goodSince or now
		if now - (goodSince :: number) > 30 and index < cap then
			index += 1; goodSince = nil
			onTierChanged(ORDER[index])
		end
	else
		badSince, goodSince = nil, nil
	end
end)
```

Gotchas:
- **Frame time is not only weather.** A big fight drops FPS too. Only step down weather if the drop correlates with weather being active, or share one governor across all VFX systems ([[VFX Performance Budgets and Culling]] section 4).
- **Step up slowly** (30 s) and down quickly (4 s). Players notice flicker between tiers more than a slightly thinner storm.
- **Change rates, not emitters.** Toggling `Enabled` on a full emitter makes existing particles vanish only when they die, which is fine; destroying emitters makes the storm pop out.
- **Pause when backgrounded.** If the window loses focus the frame rate can drop and the governor will wrongly step down. Ignore samples while `UserInputService.WindowFocused` has not fired since the last `WindowFocusReleased` (Rule of thumb).

## 6. Distance and visibility culling

- **Camera-local only.** Precipitation exists only near the camera; never place emitters across the map ([[Rain - Camera-Local Particles, Splashes and Wet Surfaces]]).
- **Indoors means off.** Inside interior zones, rate goes to 0 and splash rays stop; keep only muffled audio.
- **Lightning far away is flash and sound only.** Beyond ~1500 studs skip bolt geometry entirely.
- **Underwater and in menus:** pause the renderer's per-frame work when the camera is underwater or a full-screen menu covers the view.
- **Footprints and decals:** hard cap the pool (e.g. 40 on High, 10 on Low, 0 on Off); recycle oldest first ([[Object Pooling]]).

## 7. Measuring

1. Pick the worst storm and the busiest place in the map.
2. Capture with the MicroProfiler on a target phone (Ctrl+F6 on desktop; on device via the developer console and MicroProfiler web export) ([[MicroProfiler Guide]], [[Mobile and Low-End Optimization]]).
3. Toggle weather off with the debug command and capture again. The difference is your weather cost.
4. Repeat per tier and record the numbers in the defs file as comments, labelled Measured with device and date.

Use the Developer Console's memory view to check texture memory for weather flipbooks and wet material variants ([[Textures Decals and Texture Memory]]).

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Budgeting by `Rate` | Snow with long lifetime tanks phones | Budget alive count = rate x lifetime |
| Tiers thin the fog | Low-end players see further in PvP | Air identical on every tier |
| Relying on engine auto-scaling | Phones still overloaded | Your own per-tier caps |
| Governor without hysteresis | Storm flickers between tiers | Fast down, slow up, sustained thresholds |
| Governor blames weather for fights | Storm vanishes in every battle | Shared VFX governor or weather-only correlation |
| Destroying emitters on tier change | Storm pops | Change `Rate` and lifetime |
| No player setting | Complaints from low-end and photosensitive players | Full / Reduced / Off option |

## Checklist

- [ ] Per-tier budgets written for alive particles, large particles, rays, segments and script time.
- [ ] Visibility and gameplay identical across tiers.
- [ ] Starting tier from saved quality where manual, else platform default.
- [ ] Governor with hysteresis, capped by the player's setting.
- [ ] Indoors, underwater, menus and far lightning culled.
- [ ] Weather cost measured on a target phone with weather on and off.

## See also

[[VFX Performance Budgets and Culling]] · [[Mobile and Low-End Optimization]] · [[Juice on a Budget - Mobile and Low-End]] · [[Particle Emitters In Depth]] · [[Weather System Architecture - State Machine, Transitions and Replication]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Object Pooling]] · [[Textures Decals and Texture Memory]]

## Connected notes
<!-- auto-links:start -->
[[Weather That Changes Gameplay - Grip, Visibility and Hearing]] · [[Client Zone Culling for Interiors and Cities]] · [[Memory Budgets and Leaks]] · Lighting Technologies and Settings
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Graphics and Performance Toggles for Low-End Devices]] · [[Rendering Performance]] · [[Performance Fundamentals]] · [[Developer Console and Stats]] · [[Network Bandwidth Budgets and Measuring Them]] · [[Script Performance]] · [[QA Checklists Before Release]]
<!-- related:end -->
