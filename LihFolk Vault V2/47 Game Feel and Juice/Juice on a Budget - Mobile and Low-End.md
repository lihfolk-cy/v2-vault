---
tags: [game-feel, juice, performance, mobile, low-end, pooling, budgets, luau, type/guide, area/game-feel, level/intermediate, api/ParticleEmitter]
---
# Juice on a Budget - Mobile and Low-End

<!-- tldr:start -->
> [!tldr] TL;DR
> - Random hitches seconds after big moments: Instances created and destroyed per effect; GC catches up later -> Pools, pre-warmed, bounded
> - Phone drops frames on rewards only: Full-screen glows and post-processing -> Substitutes on low tiers; smaller, more opaque effects
> - Quality flickers between tiers: No hysteresis -> Slow to rise, quick to fall, ignore spikes
> - Each juice effect classified by cost bucket and tagged `info` or `decor`.
> - Tier from the player's setting as a ceiling, adjusted by measured frame time with hysteresis.
> - Per-frame spawn and per-second particle budgets enforced by one governor.
>
> Cost: TL;DR ~200 tok · whole note ~5.3k tok. Read more: ## 1. Where juice costs go · ## 3. A juice governor · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most Roblox players are on phones, many of them old, hot or both. Juice that is cheap on a developer's PC can be what pushes a phone from 40 fps into the twenties, and a stutter at the moment of a hit or a reward undoes the very feeling the juice was meant to create. [[Mobile and Low-End Optimization]] covers phones in general (quality presets, memory, what to cut first); [[VFX Performance Budgets and Culling]] covers combat effects. This note is narrower and deeper: what each kind of juice actually costs, a governor that adapts juice to the device in real time, pooling and spawn budgets, cheap substitutes for expensive effects, and the rule that keeps degraded juice fair. All code is full strict Luau.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. Where juice costs go

Juice costs fall into four buckets, and phones are weak in different ones than PCs:

| Bucket | What consumes it | Why phones suffer |
|---|---|---|
| CPU, script | Creating instances, tweens, per-frame Luau loops, text updates | Slow single-core speed; thermal throttling after minutes of load |
| CPU, engine | Layout and text shaping, particle simulation, physics on moving props | Same |
| GPU, fill rate | Large transparent surfaces: particles near the camera, full-screen frames, glows, post-processing | Mobile GPUs have far less fill rate; overdraw is the classic phone killer |
| Memory | Textures for effects, `CanvasGroup` render targets, pools that never shrink | Low memory limits; the app is killed rather than slowed |

A useful rule of thumb: **on phones, the size of an effect on screen matters more than its count**. Twenty small sparks cost less than one large soft glow that covers a third of the screen, because the glow is drawn over hundreds of thousands of pixels, possibly several times if it overlaps itself.

### Cost of common juice, roughly ranked

| Juice | Cost class (rule of thumb) | Notes |
|---|---|---|
| Camera shake, FOV punch, kick | Negligible | A few CFrame operations per frame; the cost is comfort, not performance |
| Sound one-shots | Low | Cap concurrent voices; see [[Combat Sound Design and Feedback]] |
| `UIScale` pop, `Position` slide | Low | Cheapest UI motion ([[UI Motion Language and Timing]]) |
| `UIGradient` offset sweep | Low | Good shine for the price |
| Text count-ups | Low to medium | Each text change re-shapes the string; cap update rate |
| UI `Size` tweens inside layouts | Medium | Re-layout of siblings every frame |
| Particle bursts, small | Medium | Simulation plus fill; scale with count and size |
| `Highlight` flashes | Medium | Engine render pass per highlight; the reference project capped flashes at 8 live and decorative highlights at 3 |
| Beams and trails | Medium | Segments and transparency overdraw |
| `CanvasGroup` fades | Medium to high | Each group renders to an off-screen texture: memory plus a pass |
| Full-screen frames and glows | High on phones | Fill rate over the whole screen |
| Post-processing (`BlurEffect`, `BloomEffect`, `DepthOfFieldEffect`, `SunRaysEffect`) | High on phones | Full-screen passes. Whether the engine itself scales these down at low quality levels is not documented clearly enough to rely on (unverified); budget as if they always run |
| Creating instances per event | Hidden cost | Allocation plus garbage collection hitches later; the cost lands somewhere else in time |

The last row is the one that surprises people. An effect that creates 30 instances and destroys them 0.4 s later looks cheap in a profiler capture of that frame; the garbage it creates shows up as a hitch a few seconds later, at a random moment, possibly during the next big hit.

---

## 2. Decide the tier: settings plus measurement

Two signals tell you how much juice a device can afford.

**The player's graphics setting.** `UserGameSettings.SavedQualityLevel` is readable from client scripts and is an `Enum.SavedQualitySetting` with values `Automatic` and `QualityLevel1` through `QualityLevel10` (Roblox docs, as of October 2026). It is a useful hint when the player chose a manual level. When it is `Automatic`, which is the default, it tells you nothing about the level the engine actually picked.

**Measured frame time.** The only reliable signal is how the device is coping right now. A smoothed average of frame time over a couple of seconds, compared with the frame rate you target, tells you whether you can afford more juice or must shed some.

Combine them: start from the setting (Automatic starts in the middle), then let measurement move you, with **hysteresis** so the tier does not flicker:

| Condition (rule of thumb) | Action |
|---|---|
| Average frame time above 1.15x the target for 2 s | Drop one tier |
| Average frame time below 0.8x the target for 10 s | Raise one tier, never above the setting's tier |
| Big spike (one frame over 0.25 s) | Ignore for tiering; it is a hitch, not a trend |

Slow to rise, quick to fall: a device that is struggling needs relief now; a device that has recovered can wait before you spend the headroom. And never rise above the player's own choice: a player who set graphics to low did it for a reason (battery, heat, data).

### Thermal throttling

Phones slow down after sustained load. A device that holds 60 fps for the first five minutes may drop to 40 after fifteen as it heats (rule of thumb). Two consequences:

- The governor must keep running for the whole session, not only at startup.
- Test juice changes after 15 to 20 minutes of continuous play on a real phone, not on a cold device. The [[Multi-Client and Device Playtesting Protocols]] note has a device protocol.

---

## 3. A juice governor

The governor owns the tier and a set of **per-frame budgets** that effects must ask for before spawning anything. Asking is cheap; it turns "every effect does what it likes" into a global cap that holds even when ten systems fire at once.

```lua
--!strict
-- JuiceGovernor (client): picks a juice tier from settings and measured frame time,
-- and hands out per-frame spawn budgets so bursts of effects cannot stack into a hitch.
local RunService = game:GetService("RunService")

local JuiceGovernor = {}

export type Tier = number -- 1 low, 2 mid, 3 high

export type Budget = {
	spawnsPerFrame: number,     -- new instances or pool takes per frame
	particlesPerSecond: number, -- total ParticleEmitter:Emit count per second
	liveHighlights: number,     -- concurrent Highlight flashes
	postFx: boolean,            -- full-screen blur, bloom pulses, colour punches
	particleScale: number,      -- multiply emit counts by this
}

local BUDGETS: { [Tier]: Budget } = {
	[1] = { spawnsPerFrame = 3, particlesPerSecond = 120, liveHighlights = 2, postFx = false, particleScale = 0.4 },
	[2] = { spawnsPerFrame = 8, particlesPerSecond = 400, liveHighlights = 5, postFx = false, particleScale = 0.7 },
	[3] = { spawnsPerFrame = 20, particlesPerSecond = 1200, liveHighlights = 8, postFx = true, particleScale = 1 },
}

local TARGET_FRAME = 1 / 60
local DROP_RATIO, RAISE_RATIO = 1.15, 0.8
local DROP_AFTER, RAISE_AFTER = 2, 10
local SPIKE = 0.25

local tier: Tier = 2
local ceilingTier: Tier = 3
local average = TARGET_FRAME
local overFor, underFor = 0, 0
local spawnsLeft = BUDGETS[2].spawnsPerFrame
local particleTokens = BUDGETS[2].particlesPerSecond
local liveHighlights = 0
local listeners: { (Tier) -> () } = {}

local function readSettingTier(): Tier
	local ok, result = pcall(function(): Enum.SavedQualitySetting
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok then
		return 3
	end
	local level = result :: Enum.SavedQualitySetting
	if level == Enum.SavedQualitySetting.Automatic then
		return 3 -- unknown: allow up to high, and let measurement decide
	end
	local n = level.Value -- QualityLevel1 .. QualityLevel10 have values 1 .. 10
	if n <= 3 then
		return 1
	elseif n <= 7 then
		return 2
	end
	return 3
end

local function setTier(newTier: Tier)
	newTier = math.clamp(newTier, 1, ceilingTier)
	if newTier == tier then
		return
	end
	tier = newTier
	for _, fn in listeners do
		task.spawn(fn, tier)
	end
end

function JuiceGovernor.tier(): Tier
	return tier
end

function JuiceGovernor.budget(): Budget
	return BUDGETS[tier]
end

function JuiceGovernor.onTierChanged(fn: (Tier) -> ())
	table.insert(listeners, fn)
end

-- Ask before creating or taking an effect instance. Returns false when this frame's budget is spent.
function JuiceGovernor.trySpawn(): boolean
	if spawnsLeft <= 0 then
		return false
	end
	spawnsLeft -= 1
	return true
end

-- Ask before ParticleEmitter:Emit. Returns the count you may emit (possibly 0).
function JuiceGovernor.particles(wanted: number): number
	local scaled = math.floor(wanted * BUDGETS[tier].particleScale + 0.5)
	local granted = math.clamp(scaled, 0, math.floor(particleTokens))
	particleTokens -= granted
	return granted
end

-- Highlight flashes: acquire before showing, release when the flash ends.
function JuiceGovernor.acquireHighlight(): boolean
	if liveHighlights >= BUDGETS[tier].liveHighlights then
		return false
	end
	liveHighlights += 1
	return true
end

function JuiceGovernor.releaseHighlight()
	liveHighlights = math.max(0, liveHighlights - 1)
end

function JuiceGovernor.setTargetFps(fps: number)
	TARGET_FRAME = 1 / math.max(fps, 20)
end

function JuiceGovernor.start()
	ceilingTier = readSettingTier()
	tier = math.min(2, ceilingTier) -- start in the middle, or lower if the player chose low
	RunService.PreRender:Connect(function(dt: number)
		local b = BUDGETS[tier]
		spawnsLeft = b.spawnsPerFrame
		particleTokens = math.min(b.particlesPerSecond, particleTokens + b.particlesPerSecond * dt)

		if dt > SPIKE then
			return -- a hitch, not a trend
		end
		average += (dt - average) * math.min(1, dt * 2) -- roughly a half-second time constant
		if average > TARGET_FRAME * DROP_RATIO then
			overFor += dt
			underFor = 0
			if overFor >= DROP_AFTER then
				overFor = 0
				setTier(tier - 1)
			end
		elseif average < TARGET_FRAME * RAISE_RATIO then
			underFor += dt
			overFor = 0
			if underFor >= RAISE_AFTER then
				underFor = 0
				setTier(tier + 1)
			end
		else
			overFor, underFor = 0, 0
		end
	end)
end

return JuiceGovernor
```

Design notes:

- **Target frame rate is a choice.** On a device that cannot reach 60, comparing against 60 would drop to the lowest tier and stay there even when the device is stable at 40. A reasonable policy (rule of thumb): target 60 at first; if the lowest tier still averages above 1.15x, switch the target to 30 with `setTargetFps(30)` and let tiers recover against that.
- **Budgets refill per frame**, so a burst is spread over a few frames rather than dropped entirely when possible. Effects that cannot wait (a hit spark) should ask once and skip if refused; effects that can (decorative ambient bursts) can retry next frame.
- **The particle bucket refills by time**, which caps particles per second regardless of frame rate.
- **`UserSettings()` is wrapped in `pcall`.** Reading user settings from scripts is allowed per the docs' capability notes, but defensive code costs nothing here.

---

## 4. Pools that do not leak

Every juice system that creates instances should take them from a pool. A typed, bounded pool:

```lua
--!strict
-- Pool: bounded object pool. Objects beyond `max` are destroyed instead of kept.
export type Pool<T> = {
	take: (self: Pool<T>) -> T,
	give: (self: Pool<T>, item: T) -> (),
	size: (self: Pool<T>) -> number,
}

local Pool = {}

function Pool.new<T>(make: () -> T, reset: (T) -> (), destroy: (T) -> (), max: number): Pool<T>
	local free: { T } = {}

	local function take(_self: Pool<T>): T
		local item = table.remove(free)
		if item ~= nil then
			return item
		end
		return make()
	end

	local function give(_self: Pool<T>, item: T)
		if #free >= max then
			destroy(item)
			return
		end
		reset(item)
		table.insert(free, item)
	end

	local function size(_self: Pool<T>): number
		return #free
	end

	return { take = take, give = give, size = size }
end

return Pool
```

Example: a pool of floating number labels for [[Reward Moments and Celebrations]] or damage numbers.

```lua
--!strict
local Players = game:GetService("Players")
local Pool = require(script.Parent.Pool)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local layer = playerGui:WaitForChild("Popups") :: ScreenGui -- your popup ScreenGui

local labels = Pool.new(function(): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = UDim2.fromOffset(120, 32)
	l.Visible = false
	l.Parent = layer
	return l
end, function(l: TextLabel)
	l.Visible = false -- keep it parented: reparenting costs more than hiding
	l.TextTransparency = 0
end, function(l: TextLabel)
	l:Destroy()
end, 24)
```

Pool rules (rule of thumb):

- **Bound every pool.** An unbounded pool after one huge fight keeps hundreds of hidden instances alive for the rest of the session; that is a memory leak by another name ([[Memory Budgets and Leaks]]).
- **Hide, do not reparent.** Setting `Visible = false` (UI) or moving parts far away / disabling emitters is cheaper than moving them in and out of the tree.
- **Reset everything the effect can change.** A reused label that keeps the previous rarity colour is a visible bug.
- **Pre-warm** the pools you need in the first fight during the loading screen, a few per frame, so the first big moment does not allocate.

### Particle emitters: emit, do not create

For bursts, keep a few emitters per effect type with `Rate = 0`, move their attachment to the effect position, and call `ParticleEmitter:Emit(count)` with the count the governor grants. One emitter can serve many bursts as long as they share appearance. Flipbook textures (`FlipbookLayout`, `FlipbookMode`, `FlipbookFramerate` on `ParticleEmitter`, Roblox docs as of October 2026) let one sprite sheet replace several emitters with different images, which saves both memory and instances ([[Particle Emitters In Depth]]).

---

## 5. Cheap substitutes

When a tier rules out an expensive effect, substitute rather than delete, so the moment still lands:

| Expensive (high tier) | Substitute (low tier) | Keeps |
|---|---|---|
| `BlurEffect` pulse on impact | A full-screen black or white `Frame` at 0.85 transparency for 2 frames | The "punch" |
| `BloomEffect` intensity pulse | Brighter `Color3` on the hit spark only | The flash |
| `ColorCorrectionEffect` colour punch | A coloured vignette image at the screen edges, faded over 0.3 s | The tint |
| Large soft glow particles | Fewer, smaller, more opaque sparks | The burst shape |
| `Highlight` flash on every enemy hit | Highlight only on bosses and the current target; others get a hit spark | Hit confirmation |
| Trails on every swing | Trails only on heavy beats | Weight on the moments that need it |
| Count-up at 30 Hz text updates | Count-up at 10 Hz plus a final pop | The roll-up |
| Particle confetti on reward | A `UIGradient` shine sweep across the item card | The celebration |
| Camera shake | Keep it. Shake is nearly free on the CPU and GPU | |

The vignette substitute deserves a note: a full-screen image is itself a fill-rate cost. A thin vignette (edges only, centre fully transparent and cut out of the texture's alpha) is drawn over far fewer opaque pixels than it looks, but the engine still processes the whole quad (rule of thumb). Test it on the target phone before assuming it is cheap.

---

## 6. The fairness rule

**Information never degrades; decoration does.** Every gameplay signal must look the same on every tier:

- Enemy telegraphs (wind-up glows, ground warnings) keep full size, colour and timing. A telegraph that shrinks on low quality is a fairness bug that punishes players for their device ([[Mobile and Low-End Optimization]] makes the same point).
- Hit confirmation keeps at least one visual layer and the sound.
- Rarity colours, tier labels and reward banners stay identical.
- Status effect indicators stay visible.

Tag each effect in your data as `info` or `decor`. The governor only ever scales or removes `decor`. If you ever find yourself thinking "this telegraph is too expensive for phones", the answer is a cheaper telegraph for everyone, not a missing one for some.

---

## 7. UI juice specifics on phones

- **One frame loop for all UI motion**, running only while something animates (the reference project's approach, described in [[Game Feel and Juice]]). A dozen idle `RenderStepped` connections each doing nothing still cost a function call per frame each.
- **Avoid `TextScaled` on anything that animates.** Scaled text recomputes size when its container changes; combined with a `Size` tween it re-shapes every frame. Use a fixed `TextSize` with a `UIScale` parent for pops.
- **`CanvasGroup` only for whole-panel fades**, and only while fading. Each group renders its contents to a texture; on phones that is memory plus a pass. Swap to plain transparency or disable the fade on low tiers.
- **Cap concurrent floating numbers.** The reference project merged same-kind numbers within 0.55 s and kept at most 12 on screen (measured in the reference project). On the lowest tier, halve that.
- **Do not animate what is off screen.** A hidden shop panel with looping shine tweens keeps paying for them; stop loops when a panel closes.

---

## 8. Measuring juice cost

- **Label it.** Wrap your juice systems' per-frame work in `debug.profilebegin("Juice:FloatNumbers")` and `debug.profileend()` so they show up by name in the [[MicroProfiler Guide]] capture.
- **Stress the worst case.** A scripted test that triggers the heaviest moment (a top-tier reward during a boss fight with five players using ultimates) on the weakest phone you support. Record frame times through it.
- **Watch memory after the stress.** In the [[Developer Console and Stats]] memory view, check that instance counts and Lua heap fall back after the moment. If they do not, a pool is unbounded or something is not being returned.
- **Log the governor.** In playtests, log tier changes with timestamps. A device that bounces between tiers every few seconds needs wider hysteresis; a device that drops to tier 1 within a minute of joining needs a lower starting tier.

---

## 9. When not to scale juice down

- **When the bottleneck is elsewhere.** If a phone is at 30 fps because of terrain and lighting, cutting juice saves a little and costs a lot of feel. Profile first; juice is rarely the main cost unless effects are full-screen or allocation-heavy.
- **For the player's own key moments.** A low tier may skip onlooker juice entirely but should keep a reduced version of the player's own hit and reward feedback. Onlooker effects are the first and largest cut ([[VFX Performance Budgets and Culling]]).
- **Shake and sound.** Both are close to free. Reduce them for comfort settings, not for performance.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Random hitches seconds after big moments | Instances created and destroyed per effect; GC catches up later | Pools, pre-warmed, bounded |
| Phone drops frames on rewards only | Full-screen glows and post-processing | Substitutes on low tiers; smaller, more opaque effects |
| Quality flickers between tiers | No hysteresis | Slow to rise, quick to fall, ignore spikes |
| Juice fine at first, laggy later | Thermal throttling | Governor runs all session; test after 15 to 20 minutes |
| Memory grows after each boss fight | Unbounded pools or emitters never cleaned | Bound pools; check memory after stress tests |
| Players on low settings miss attacks | Telegraphs treated as decoration | Tag info versus decor; never scale info |
| Count-ups stutter on phones | Text updated every frame with scaled text | Cap update rate; fixed text size with `UIScale` |

## Checklist

- [ ] Each juice effect classified by cost bucket and tagged `info` or `decor`.
- [ ] Tier from the player's setting as a ceiling, adjusted by measured frame time with hysteresis.
- [ ] Per-frame spawn and per-second particle budgets enforced by one governor.
- [ ] Every effect instance comes from a bounded, pre-warmed pool.
- [ ] Bursts use `Emit` on pooled emitters; flipbooks instead of extra emitters.
- [ ] Substitutes for post-processing, big glows and highlights on low tiers.
- [ ] Information identical on every tier.
- [ ] Juice work labelled in the MicroProfiler; worst case tested on the weakest phone after 15 minutes.

## Connected notes
<!-- auto-links:start -->
[[Game Feel Start Here]] · [[Object Pooling]] · Rendering Performance · Links - Post-processing · UI and GUI Animation · Frame Budget
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Weather Performance Budgets and Quality Tiers]] · [[Graphics and Performance Toggles for Low-End Devices]] · [[Rendering Performance]] · [[Hit-Stop and Screen Shake Tuning by Numbers]] · [[Squash Stretch and Anticipation in UI and Characters]] · [[Feedback Timing - Sound Visual and Haptic Sync]]
<!-- related:end -->
