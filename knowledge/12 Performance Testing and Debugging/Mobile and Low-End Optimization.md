---
tags: [performance, mobile, low-end, graphics-quality, device-testing, memory]
---
# Mobile and Low-End Optimization

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Testing phones only in the Device Simulator.
> - Avoid: Effects designed on high and "scaled down" by just lowering rate, leaving overdraw-heavy layers in.
> - Avoid: Gameplay information that disappears on low quality.
> - Baseline device chosen and kept in the office (low Android, older iOS).
> - 15-minute soak on a real phone each release, numbers recorded.
> - In-game graphics preset with a sensible default and live switching.
>
> Read more (13 KB note): ## 3. An in-game graphics preset · ## 9. Joins and first-use stutter on phones · ## Common mistakes · ## Checklist
<!-- tldr:end -->

On most Roblox games, a large share of sessions are on phones and tablets (check your own analytics; the split varies by genre and audience). A game that is smooth on a developer's PC can be unplayable on a three-year-old phone: it runs hot after ten minutes, drops to 20 fps in combat, and crashes when a big menu opens. This note covers why low-end devices fail differently, how to detect and respect graphics quality, an in-game graphics preset system, memory on phones, touch-sized UI checks, and how to test on real devices instead of trusting the Studio Device Simulator.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. How phones fail

| Failure | Why | What you see |
|---|---|---|
| **Out of memory** | phones have far less RAM, shared with the OS and other apps | crash or "unexpected exit" with no error, often when opening a menu or entering a new area |
| **GPU fill rate** | high-DPI screens, weak GPUs; transparency and particles cost per pixel | fps drops when effects fill the screen, worst when the camera is inside an aura |
| **Thermal throttling** | sustained load heats the device; the OS lowers clock speeds | fps fine for 5 minutes, then steadily worse |
| **CPU single-thread** | slower cores; your Lua runs mostly on one | script-heavy moments (UI builds, many NPCs) hitch |
| **Asset download** | mobile networks, slower storage | long joins, pop-in, first-use stutter |

Rule of thumb: design for a **mid-range phone from about three years ago** as the baseline, and treat anything that only runs well on new flagships as broken.

Docs (Performance dashboard): client memory is charted as a **percentage of device memory** by platform; a line approaching 100% means most devices on that platform risk out-of-memory crashes. The dashboard also charts **unexpected out-of-memory exits** separately from crashes. Investigate when crash rate exceeds 2 to 3% (Docs). Charts require at least 100 DAU.

---

## 2. Graphics quality

Roblox scales rendering with a graphics quality level (1 to 10). On Automatic, the engine adjusts by itself. On manual, the player picks.

What changes with quality (Docs, partial): shadows are disabled below quality level 4; shadow quality degrades with settings; lower levels use the voxel light grid; draw distance and detail shrink.

Reading it on the client:

```lua
--!strict
local UserGameSettings = UserSettings():GetService("UserGameSettings")

-- Enum.SavedQualitySetting: Automatic, QualityLevel1 .. QualityLevel10
local function savedQuality(): number?
	local q = UserGameSettings.SavedQualityLevel
	if q == Enum.SavedQualitySetting.Automatic then
		return nil -- engine-managed; you do not know the effective level
	end
	return q.Value
end
```

The catch: on **Automatic** (the default for most players) you do not learn the effective level this way. So games that need reliable tiers usually add **their own** graphics preset.

---

## 3. An in-game graphics preset

**Measured.** The reference project shows a "choose your graphics" card on first launch with three presets, stored in the player's saved settings:

| Preset | Effects tier | Engine quality hint |
|---|---|---|
| Performance | low | low |
| Balanced | high | low |
| Quality | high | high |

A `recommend()` function pre-selects one: phones get Performance, tablets and consoles Balanced, PCs by the Roblox quality slider (1 to 4 Performance, 5 to 7 Balanced, 8 and up or Automatic Quality). The game's own effects read the chosen tier (VFX quality, foliage sway, ambient effect layers). Players can change it later in Settings.

```lua
--!strict
-- ReplicatedStorage/GraphicsPreset.luau (client)
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

export type Tier = "Performance" | "Balanced" | "Quality"

local GraphicsPreset = {}

local current: Tier = "Balanced"
local changed = Instance.new("BindableEvent")
GraphicsPreset.Changed = changed.Event

-- Heuristic only: touch without keyboard is usually a phone or tablet.
local function isLikelyPhone(): boolean
	local camera = workspace.CurrentCamera
	local shortSide = math.min(camera.ViewportSize.X, camera.ViewportSize.Y)
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and shortSide < 500
end

function GraphicsPreset.recommend(): Tier
	if GuiService:IsTenFootInterface() then
		return "Balanced" -- console
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return if isLikelyPhone() then "Performance" else "Balanced"
	end
	local q = UserGameSettings.SavedQualityLevel
	if q == Enum.SavedQualitySetting.Automatic then
		return "Quality"
	elseif q.Value <= 4 then
		return "Performance"
	elseif q.Value <= 7 then
		return "Balanced"
	end
	return "Quality"
end

function GraphicsPreset.get(): Tier
	return current
end

function GraphicsPreset.set(tier: Tier)
	if tier ~= current then
		current = tier
		changed:Fire(tier)
	end
end

-- Convenience for effect code.
function GraphicsPreset.effectsLow(): boolean
	return current == "Performance"
end

return GraphicsPreset
```

Notes:
- Device detection is **heuristic**. Touch plus no keyboard is usually mobile, but tablets with keyboards and touch laptops exist. Never lock content behind it; only pick defaults.
- Persist the choice with your settings save ([[Saving Correctly - Autosave and BindToClose]]); first-launch detection is only a default.
- Effect modules subscribe to `Changed` so switching takes effect without rejoining.

---

## 4. What to cut on low tiers

Ordered by payoff (rule of thumb, consistent with the reference project's budgets):

| Cut | Why it helps phones | Measured example |
|---|---|---|
| Effect layer counts and particle rates | fill rate and particle simulation | swing VFX 140 beams/30 emitters on high, 44/10 on low |
| Onlooker effects | other players' effects matter less | onlookers get half the particles |
| Ambient world effects | run constantly | portals trim layers on quality 1 to 3, sleep beyond 300 studs |
| Cosmetic motion | CPU per frame | foliage sway near-camera only, 30 Hz; arena floaters only on higher quality |
| Transparent layers and glows | overdraw | one glow layer, no stacked flares |
| Dynamic lights and shadows | lighting cost | lights thinned; shadows off on scenery |
| UI motion | layout and render | reduced-motion mode: fades only, no scale or lift |

Keep gameplay information identical across tiers. A telegraph that only shows on high quality is a fairness bug.

---

## 5. Memory on phones

The cheapest wins (Docs and Measured):
- **Instance streaming** is the highest-impact client memory reduction (Docs). Lower `StreamingTargetRadius` for more aggressive streaming.
- **Textures** by pixel count: 512x512 or smaller for most, 256x256 for minor images (Docs). One 2048 UI background costs as much as sixteen 512 ones.
- **Reuse asset ids**; tint instead of re-uploading.
- **ReplicatedStorage** holds only join-time essentials. The reference project's 600k-instance ReplicatedStorage was a phone memory problem as much as a join-time one.
- **Destroy menus** you will not reopen soon; do not keep five hidden 300-element menus alive.
- **Do not preload everything.** Docs: preload loading-screen images, key menu images and the spawn area, not the whole Workspace.

Check on a real phone: Developer Console (via the in-game menu), Memory, Client. Note `GraphicsTexture`, `GraphicsMeshParts`, `Sounds`, `Instances`, `LuaHeap` in a heavy area and with your largest menu open.

---

## 6. Touch UI is a performance concern too

Phones fail UI in ways that look like bugs, not slowness: buttons too small to hit, text unreadable, panels overflowing the screen. The reference project ran automated checks on every screen at phone viewports.

**Measured check rules** (applied at 844x390 and 667x375):
- text at least 12 px as actually drawn (including `TextScaled` text measured at its rendered size),
- tap targets at least 44 px,
- gaps between targets at least 8 px,
- zero overlaps and nothing outside the screen,
- a "round trip" check that switching to the phone layout and back to desktop restores the desktop layout exactly.

These ran on off-screen copies of each screen (laid out far off-canvas and destroyed afterwards), so they did not disturb the live UI. Details in [[Responsive UI for Phone Tablet Console and PC]] and [[Safe Areas and Insets]].

---

## 7. Testing on devices

### The Studio Device Simulator is for layout, not performance
Docs: the Device Simulator previews screen dimensions, pixel density, on-screen keyboard and touch input; the Controller Emulator covers gamepads and other inputs; `StudioDeviceSimulatorService` can script resolution and DPI overrides and custom device profiles. It runs on your PC's hardware. It tells you whether the UI fits; it tells you nothing about frame time, thermals or memory on a phone.

### Real-device protocol (rule of thumb)
1. Keep at least one low-end Android phone and one older iPhone or iPad for testing.
2. Publish to a test place or use a private server of the live place ([[Multi-Client and Live Testing]]).
3. Run a fixed route for **15 minutes**: spawn, heaviest area, a full combat encounter, open every major menu, change zones. Thermal problems appear after 5 to 10 minutes.
4. Record fps (Shift+F5 overlay or your debug overlay), client memory at the heaviest point, and any crash.
5. Profile on the phone with the MicroProfiler web UI if a section is slow ([[MicroProfiler Guide]]).
6. Compare with the previous release's numbers. Regressions are easier to fix the week they happen.

### Live data
After release, the Performance dashboard by platform and OS (Docs) is the truth: client frame rate, crash rate, OOM exits, memory percentage. The Error Report can be broken down by platform. See [[Crash and Error Telemetry]].

---

## 8. Frame-rate caps and battery

Docs: the default client cap is 60 fps (players on Windows can raise it to 240). Phones generally run at or below 60. Running at a steady 30 is better than oscillating between 60 and 25; the engine's automatic quality also tries to hold the frame rate. A game that keeps the GPU at full load in a menu (animated backgrounds, particles behind UI) drains batteries and heats phones for nothing: pause world effects while a full-screen menu is open.

---

## 9. Joins and first-use stutter on phones

Phones feel load problems first: slower storage, slower decompression, mobile networks.

- **Join payload.** Everything in ReplicatedFirst and ReplicatedStorage arrives before the player can interact (Docs). Run Studio's Print Join Size Breakdown and fix the top entries before any other mobile work on load time. See [[Case Study - Fast Join and Deferred Loading]].
- **Defer non-essential systems.** Build the HUD first; build the shop, codes, index and settings menus the first time they are opened, or a few seconds after spawn, time-sliced over frames ([[Script Performance]]).
- **Preload selectively.** `ContentProvider:PreloadAsync` the loading screen, the HUD icons and the spawn area, not the whole game (Docs). Do not poll `ContentProvider.RequestQueueSize` as a completion check; Docs call it slow and unreliable.
- **First-use assets.** The first time a phone plays a new animation, sound or effect it may need to fetch it; preload per kit or zone when it is equipped or entered, not when the button is pressed ([[Engine Gotchas]]).
- **Stream before teleporting** within the place (`Player:RequestStreamAroundAsync`) so the player does not land in an empty world ([[Instance Streaming]]).

Measure join time with a stopwatch on the baseline phone (Docs: there is no built-in join timer; a ReplicatedFirst script can approximate it, excluding connection and avatar load). Record it every release next to fps and memory.

---

## Common mistakes

- Testing phones only in the Device Simulator.
- Effects designed on high and "scaled down" by just lowering rate, leaving overdraw-heavy layers in.
- Gameplay information that disappears on low quality.
- Assuming Automatic quality tells you the device class.
- Giant UI textures and hidden menus kept alive.
- No thermal soak; testing for 60 seconds.
- Locking features by device detection heuristics.

## Checklist

- [ ] Baseline device chosen and kept in the office (low Android, older iOS).
- [ ] 15-minute soak on a real phone each release, numbers recorded.
- [ ] In-game graphics preset with a sensible default and live switching.
- [ ] Every effect has a low tier; onlookers reduced; ambient effects sleep.
- [ ] Client memory checked at the heaviest point with the largest menu open.
- [ ] UI passes phone checks: text, tap size, gaps, overlaps, safe area.
- [ ] Performance dashboard reviewed by platform after release.

## See also

[[Rendering Performance]] · [[Memory Budgets and Leaks]] · [[Responsive UI for Phone Tablet Console and PC]] · [[Safe Areas and Insets]] · [[Gamepad and Console UX]] · [[Accessibility]] · [[Instance Streaming]] · [[Textures Decals and Texture Memory]] · [[Crash and Error Telemetry]] · [[Animation LOD]]

## Connected notes
<!-- auto-links:start -->
[[Juice on a Budget - Mobile and Low-End]] · [[QA Checklists Before Release]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[Skill - Roblox Performance Audit]] · [[VFX Performance Budgets and Culling]] · [[Testing Modes - Play Run and Multi-Client]]
<!-- auto-links:end -->
