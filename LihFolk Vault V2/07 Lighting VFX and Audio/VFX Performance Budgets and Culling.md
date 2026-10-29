---
tags: [vfx, performance, budgets, culling, particles, mobile, optimization, type/guide, area/vfx, level/intermediate, api/Beam, area/performance]
---
# VFX Performance Budgets and Culling

<!-- tldr:start -->
> [!tldr] TL;DR
> - Fine alone, lags with a full server: No onlooker share or global cap -> Governor with a global cap; onlookers at half or less
> - Hitch every few seconds in long fights: Cloning and destroying per hit -> Pools with a cap
> - Phones lag only when an effect is near the camera: Overdraw from big transparent pieces -> Shrink, raise transparency on the camera line, fewer stacked layers
> - Budgets written per cast, per caster window and per client, with onlooker share and distances.
> - Cost estimation script run on every template; worst offenders listed.
> - Gameplay effects flagged; never skipped, only simplified.
>
> Cost: TL;DR ~200 tok · whole note ~6.3k tok. Read more: ## 2. Budget units that actually work · ## 4. Culling and degrading: the governor · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[VFX Design Playbook]] tells you how to make an effect look good, and [[Particle Emitters In Depth]] covers the emitter properties and their traps. This note is about the other half of the job: keeping the frame rate when eight players fire their best effects at once on a mid-range phone. It covers where VFX cost actually goes, how to turn "it lags in big fights" into budgets you can count, how to cull and degrade effects by distance, view and importance, and how to measure all of it. The working code is a small client-side **governor** that decides, per effect, whether to play it in full, reduced or not at all.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project** (one live action game with hundreds of ability effects), **rule of thumb**.

---

## 1. Where VFX cost goes

People say "particles are expensive" as if there were one cost. There are at least seven, and they fail differently.

| Cost | Driven by | What it looks like | Main lever |
|---|---|---|---|
| **Fill rate / overdraw** | Screen area covered by transparent pixels, times the number of layers | FPS drops when the effect is close to the camera or fills the screen; fine from far away | Smaller sprites, fewer stacked layers, keep big pieces off the camera line |
| **Particle simulation** | Particles alive (rate times lifetime, plus bursts) | Steady CPU cost that grows with the number of casters, even off-screen if nothing stops it | Particle budgets, shorter lifetimes, fewer streams |
| **Draw calls** | Distinct emitters, beams, trails and textures | Cost scales with the *number* of pieces, not their size. Docs: "Decals, textures, and particles don't batch well and add draw calls" | Fewer, richer emitters; shared textures |
| **Instance churn** | Cloning and destroying effect instances per hit | Garbage collector spikes, hitching every few seconds in long fights | Pools |
| **Property churn** | Scripts writing emitter properties every frame | Docs: "property changes to ParticleEmitters can have a dramatic impact on performance" | Set once, `Emit`, leave alone |
| **Lights and shadows** | Light instances, especially shadow-casting ones | Lighting update cost; worse under realistic lighting | Few lights, `Shadows = false`, short range |
| **Script per frame** | Tweens, `RenderStepped` loops animating meshes and beams | CPU time in your scripts; worst with many concurrent effects each owning a loop | One shared stepper, idle gates |

Two facts drive most of the decisions below:

1. **Overdraw scales with screen area, not particle count.** One 40-stud smoke puff in front of the camera can cost more than 300 tiny sparks across the room. The docs list overlapping transparency as the cause: overlapping partially transparent objects force the engine to render the same pixels several times.
2. **Simulation scales with particles alive.** Alive particles are roughly `Rate * Lifetime` for a stream and the burst count for an `Emit`, summed over every emitter in the effect. This is the number you can budget.

The server does no rendering (Roblox docs). Every cost in this note is a client cost, which is one more reason effects are built on clients ([[Client-Server Model]]).

---

## 2. Budget units that actually work

A budget only helps if you can count it before you ship. These units are countable from the template alone:

| Unit | How to count | Why it matters |
|---|---|---|
| **Peak particles alive** | Sum of burst counts plus `Rate * Lifetime.Max` of enabled streams | Simulation cost |
| **Pieces** | Emitters plus beams plus trails plus meshes | Draw calls and per-piece overhead |
| **Large pieces** | Pieces bigger than some screen fraction at typical camera distance | Overdraw |
| **Lights** | Light instances, and how many cast shadows | Lighting cost |
| **Highlights** | Highlight instances live | Each one is a separate outline pass; the old engine limit was 31, the docs now say 255 (see [[Highlights and Selection Effects]]) |
| **Lifetime** | Longest life of any piece | How long all the above stays on the bill |
| **Screen share** | Fraction of the screen covered at peak | Readability and overdraw together |

The reference project's budgets, as measured and enforced in code (see also the summary in [[VFX Design Playbook]]):

| Budget | Value (measured in the reference project) |
|---|---|
| Premium effect library | 3,200 particles per 2 s per caster; ultimate caster 5,600; onlookers half |
| One sword swing | At most about 140 beams and 30 emitters (measured max 128 and 28); finisher 210 and 44 |
| Low-detail swing | 44 beams and 10 emitters |
| Emitters per ability kit folder | 16 (cut from 24 in a readability pass) |
| Lights per ability kit | 2 (range 18, brightness 1.6); stylised effect lights at most 4 at once (range 14, brightness 1.5) |
| Highlights in the shared tier layer | 3 |
| Large non-floor pieces per cast | 3, plus one ground "floor" at a time |
| Screen share per cast | 35 percent, 55 percent during an ultimate (scale pieces down to no less than 0.6, else drop them) |
| Life caps | 1.4 s (floors 2.2 s; ultimate 2.0 and 2.8 s) |
| Others' effects | Decoration layers dropped beyond about 160 studs, small juice beyond 220 |

Notice the shape: a per-cast budget (what one effect may contain), a per-caster budget over a window (what one player may produce over time), and a distance rule for other people's effects. You need all three. A per-cast budget alone lets a player who casts four times a second exceed everything; a window budget alone lets one ultimate spike a single frame.

### Worked arithmetic: will a full server hold?

Rule-of-thumb starting point: a mid-range phone stays smooth with a few thousand simple particles alive and a few dozen effect pieces on screen. Do the sum before you build:

- 8 players in one fight, each swinging about twice a second.
- One swing effect: a 30-particle spark burst (life 0.4 s), two 6-particle slash cards (life 0.3 s), one 20-particle-per-second haze stream (life 1 s). Peak alive per swing is about 30 + 12 + 20 = 62. With two swings overlapping per player, about 124 per player.
- Your own swings: 124. Seven onlookers at half detail: 7 * 62 = 434. Total about 560 alive. Fine.
- Now everyone presses their ultimate in the same second, each 5,600 for the caster and 2,800 for onlookers: 5,600 + 7 * 2,800 = 25,200. Not fine on any phone.

That last line is the real design question. Either the ultimate budget is per server view (a global cap, section 4), or the onlooker share for ultimates is far below half, or both. The reference project used half for onlookers plus distance drops, and fights rarely had all ultimates at once; a governor with a global cap is the safer answer.

---

## 3. Count it: cost estimation from templates

Put the counting in code so the budget is checked by a script, not by eye. Effects authored for the VFX Forge style runtime carry their burst size in an `EmitCount` attribute; plain templates can carry your own attribute. This function estimates peak particles alive and piece counts for any effect root:

```lua
--!strict
-- Estimate the cost of an effect template. Run in the command bar or at load.
export type Cost = {
	particles: number, -- peak alive, approximate
	emitters: number,
	beams: number,
	trails: number,
	meshes: number,
	lights: number,
	shadowLights: number,
	highlights: number,
	longestLife: number,
}

local function estimateCost(root: Instance): Cost
	local c: Cost = {
		particles = 0, emitters = 0, beams = 0, trails = 0, meshes = 0,
		lights = 0, shadowLights = 0, highlights = 0, longestLife = 0,
	}
	for _, d in root:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			c.emitters += 1
			local burst = d:GetAttribute("EmitCount")
			if type(burst) == "number" then
				c.particles += burst
			end
			if d.Enabled then
				-- A stream holds about Rate * Lifetime particles once it is warm.
				c.particles += d.Rate * d.Lifetime.Max
			end
			local delay = d:GetAttribute("EmitDelay")
			local extra = if type(delay) == "number" then delay else 0
			c.longestLife = math.max(c.longestLife, d.Lifetime.Max + extra)
		elseif d:IsA("Beam") then
			c.beams += 1
		elseif d:IsA("Trail") then
			c.trails += 1
			c.longestLife = math.max(c.longestLife, d.Lifetime)
		elseif d:IsA("MeshPart") then
			c.meshes += 1
		elseif d:IsA("Light") then
			c.lights += 1
			if d.Shadows then
				c.shadowLights += 1
			end
		elseif d:IsA("Highlight") then
			c.highlights += 1
		end
	end
	return c
end

return estimateCost
```

Run it across every template folder and print the worst offenders. In the reference project an audit of this kind found ability kit folders far over their instance budget (2,973 to 5,249 instances against 2,500), and a readability audit found 170 of 373 moves below the *minimum* layer count for their tier. Budgets cut both ways: the same script tells you which effects are too thin.

Things the estimate misses, so treat it as a lower bound: scripted spawns at runtime (bolt segments, debris), effects that call `Emit` in a loop, and the screen area of big sprites (overdraw cannot be counted from properties alone; you have to look).

---

## 4. Culling and degrading: the governor

Culling means not playing an effect; degrading means playing less of it. Both need a decision made **once, when the effect starts**, from facts the client has:

| Fact | Question it answers |
|---|---|
| Owner | Is this mine, my party's, or a stranger's? |
| Gameplay flag | Is this information (telegraph, hazard, objective) or decoration? |
| Distance to camera | Will anyone see the detail? |
| In view | Is it on screen now, or about to be? |
| Current load | How many particles are already alive on this client? |
| Detail setting | What did the player (or your device heuristic) choose? |

The rule that must never bend: **gameplay information is never culled for performance.** A telegraph that disappears on low settings is a fairness bug. Gameplay effects can be simplified (fewer layers, no sparks), never skipped. Mark them with an attribute on the template and let the governor exempt them.

```lua
--!strict
-- FxGovernor: one place that decides how much of each effect to play on this client.
-- Returns a detail scale: 0 = skip, 1 = full, values between = play reduced.
local Players = game:GetService("Players")

export type Request = {
	cost: number,          -- estimated peak particles (estimateCost(...).particles)
	position: Vector3,
	radius: number,        -- rough size of the effect in studs
	life: number,          -- seconds the cost stays on the bill
	owner: Player?,
	gameplay: boolean?,    -- telegraphs and hazards: never skipped
}

local FxGovernor = {}

local BUDGET = 3000        -- particles alive on this client (rule of thumb starting point)
local FAR_DECOR = 160      -- studs: others' effects lose decoration beyond this
local FAR_ALL = 220        -- studs: others' small effects are skipped beyond this
local ONLOOKER = 0.5       -- others' effects play at half detail

local live = 0
local detail = 1           -- player setting, 0..1

function FxGovernor.setDetail(d: number)
	detail = math.clamp(d, 0, 1)
end

function FxGovernor.liveParticles(): number
	return live
end

-- Conservative view test: is any part of a sphere inside the camera's horizontal or vertical cone?
local function inView(pos: Vector3, radius: number): boolean
	local cam = workspace.CurrentCamera
	if not cam then
		return true
	end
	local cf = cam.CFrame
	local to = pos - cf.Position
	local dist = to.Magnitude
	if dist <= radius then
		return true -- the camera is inside the effect
	end
	local vp = cam.ViewportSize
	local halfV = math.rad(cam.FieldOfView) * 0.5
	local halfH = math.atan(math.tan(halfV) * vp.X / math.max(vp.Y, 1))
	local half = math.max(halfV, halfH)
	local angle = math.acos(math.clamp(cf.LookVector:Dot(to / dist), -1, 1))
	return angle <= half + math.asin(math.min(radius / dist, 1))
end

function FxGovernor.request(r: Request): number
	local cam = workspace.CurrentCamera
	local dist = if cam then (r.position - cam.CFrame.Position).Magnitude else 0
	local mine = r.owner == Players.LocalPlayer

	local scale = detail
	if not mine then
		scale *= ONLOOKER
	end

	if r.gameplay then
		-- Never skipped. Still counted, so decoration makes room for it.
		scale = math.max(scale, 0.5)
	else
		if not mine then
			if dist > FAR_ALL then
				return 0
			end
			if not inView(r.position, r.radius) then
				return 0
			end
			if dist > FAR_DECOR then
				scale *= 0.5
			end
		end
		local cost = r.cost * scale
		if live + cost > BUDGET then
			-- Try once at half before refusing; your own effects get the benefit of the doubt.
			if mine and live + cost * 0.5 <= BUDGET * 1.2 then
				scale *= 0.5
			else
				return 0
			end
		end
	end

	local spent = r.cost * scale
	live += spent
	task.delay(r.life, function()
		live -= spent
	end)
	return scale
end

return FxGovernor
```

How the effect player uses the scale: layers carry a `MinDetail` attribute (0 to 1). At scale 0.5, layers with `MinDetail > 0.5` are not played and burst counts are multiplied by the scale. That keeps degradation **authored**: the artist decides which layers are decoration, not the code. The same pattern is in the burst helper in [[Particle Emitters In Depth]].

### Design choices hidden in that code

- **Decide at start, not per frame.** Re-evaluating every frame (turning emitters on and off as the camera moves) causes popping and costs script time. An effect's life is under 2 seconds; decide once.
- **Off-screen culling is for strangers only.** Your own effects play even when the camera faces away, because you will turn around mid-effect after a dash and an empty ultimate looks broken. For strangers, a missed 1-second decoration is invisible.
- **The view test is conservative.** It uses the wider of the two half-angles and adds the effect's angular radius, so an effect at the edge of the screen still plays. Prefer playing a few invisible effects over cutting visible ones.
- **No occlusion culling by raycast.** Raycasting from camera to every effect costs more than it saves for short effects, and partial occlusion (behind a thin pillar) is common. The engine already skips drawing objects outside the field of view and occluded objects (Roblox docs); your job is to skip *simulation and spawning*, which the engine cannot know is optional.
- **Global cap, then distance, then view.** The order matters only for clarity. What matters is that a global cap exists: distance and view rules do not protect you when eight players stand in one spot.
- **Hysteresis on distance.** If something long-lived (an aura, a portal) is culled by distance, use two thresholds (turn off beyond 230, back on inside 200) so standing at the boundary does not make it flicker.

### Long-lived effects: sleep, do not cull

Auras, portals, waterfalls and station effects run for minutes. They need a different rule: a periodic check (every 0.5 to 1 s, staggered) that **sleeps** them beyond a distance and wakes them inside it, by toggling `Enabled` on streams and pausing the script that animates them. The reference project slept waterfalls and station effects beyond about 650 studs, trimmed portal layers on graphics quality 1 to 3 and slept them beyond 300 studs. Sleep means `Enabled = false` and stopping loops; the instances stay, so waking is instant.

```lua
--!strict
-- Sleep long-lived ambient effects by distance, with hysteresis and a staggered check.
local RunService = game:GetService("RunService")

type Sleeper = { root: Instance, pos: Vector3, sleepAt: number, wakeAt: number, awake: boolean }
local sleepers: { Sleeper } = {}

local function setAwake(s: Sleeper, awake: boolean)
	s.awake = awake
	for _, d in s.root:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			d.Enabled = awake
		end
	end
	s.root:SetAttribute("Asleep", not awake) -- animating scripts read this and idle
end

local function register(root: Instance, pos: Vector3, sleepAt: number)
	table.insert(sleepers, { root = root, pos = pos, sleepAt = sleepAt, wakeAt = sleepAt * 0.85, awake = true })
end

local index = 0
RunService.Heartbeat:Connect(function()
	-- Check a few sleepers per frame instead of all of them every frame.
	local cam = workspace.CurrentCamera
	if not cam or #sleepers == 0 then
		return
	end
	for _ = 1, math.min(4, #sleepers) do
		index = index % #sleepers + 1
		local s = sleepers[index]
		local d = (s.pos - cam.CFrame.Position).Magnitude
		if s.awake and d > s.sleepAt then
			setAwake(s, false)
		elseif not s.awake and d < s.wakeAt then
			setAwake(s, true)
		end
	end
end)

return register
```

One caveat on beams: setting `Beam.Enabled = false` hides it immediately. If you sleep something in view (because of a quality change, say), fade it first.

---

## 5. Churn: pools and lifetimes

Most "random hitch every few seconds in fights" reports are instance churn: every hit clones a 40-instance template and destroys it 2 seconds later. The fixes, from [[Particle Emitters In Depth]] and the reference project:

- **Clone templates once per client** into a pool, reposition, `Emit`, release after the longest lifetime.
- **Do not destroy an emitter while its particles live.** Destroying the emitter destroys its particles; release after `Lifetime.Max` plus any emit delay.
- **`Clear()` before reusing** a pooled emitter for an unrelated hit, or the old burst shows with the new one.
- **Pool size is a budget too.** A pool that grows without bound in a long fight is a leak. Cap it (rule of thumb: enough for your peak concurrency plus 25 percent) and refuse or recycle the oldest when it is full. See [[Memory Budgets and Leaks]].

Memory note: pooled instances hold memory until destroyed. That is the trade: steady memory instead of churn. Measure `Instances` and the graphics memory categories in the [[Developer Console and Stats]] before and after a 5-minute fight; the curve should flatten, not climb.

---

## 6. The traps that break budgets silently

| Trap | Why it bites | Fix |
|---|---|---|
| `Emit` ignores engine quality scaling | Measured in the reference project: bursts were not thinned on low settings, so a burst-heavy style ran at full cost on phones | Your own detail scalar applied to `EmitCount` |
| You cannot read the effective quality level | `UserGameSettings.SavedQualityLevel` reports the saved setting, which is `Automatic` for most players | An in-game preset; see [[Mobile and Low-End Optimization]] |
| Streams do not run in Edit | Rate emission does not run in Edit and Studio only steps particles while it renders (measured) | Count in Edit, judge cost in Play |
| Server-built effects | Instances replicate to everyone and arrive late | Server sends an event; clients build |
| Big sprites near the camera | Overdraw explodes when a ground ring or dome surrounds the camera | Force pieces on the camera line to at least 0.75 transparency (reference project), or shrink them |
| Beams with high `Segments` and many copies | Each beam is a draw; staggered beam slashes multiply them | Budget beams like emitters (the swing budget above) |
| Effect lights left with shadows on | Shadow-casting lights are the expensive kind (Roblox docs) | `Shadows = false` on all VFX lights; cap per kit |
| Highlights per hit | Every live Highlight is an outline pass | Pool a few, cap them (3 in the tier layer, 8 for enemy hit flashes in the reference project) |
| One `RenderStepped` loop per effect | 30 effects, 30 loops, each allocating | One shared stepper that iterates live effects |
| EditableImage or EditableMesh for runtime VFX | Fails in published games unless the experience setting allows it, with strict memory budgets (Roblox docs) | Bake offline, upload |

---

## 7. Measuring

Budgets are hypotheses until measured on a device.

1. **Draw calls:** Studio's Render Stats (Timing) or Shift+F2 in a client (Roblox docs). Compare a quiet frame with a full-party ultimate.
2. **MicroProfiler:** the docs name "Prepare and Perform" for overall rendering and `computeLightingPerform`, `ShadowMapSystem` for lighting and shadows. If lights in effects are the problem, the lighting scopes grow during casts. See [[MicroProfiler Guide]].
3. **Script cost:** label your effect stepper with `debug.profilebegin("FxStep")` / `debug.profileend()` so it shows as its own bar.
4. **Particles alive:** expose `FxGovernor.liveParticles()` in a debug overlay. If it sits at the cap during normal fights, your cap or your effects are wrong.
5. **The stress protocol** (rule of thumb): one phone, one tablet, one PC in the same server, plus 4 to 8 test clients or friends. Everyone casts their strongest ability at the same spot, then at the phone's camera, then 200 studs away. Record FPS on each device for all three. Then repeat at the lowest and highest graphics quality. See [[Multi-Client and Live Testing]].

A useful target from practice: the phone's frame time during the worst repeatable fight should stay under about 33 ms (30 FPS) at its default setting. If it does not, cut in this order: onlooker share, decoration layers on others' effects, big transparent pieces, stream lifetimes, then your own effects.

One thing this note cannot confirm: whether the engine stops simulating particles of an emitter that is entirely off-screen. The docs say the engine skips *drawing* objects outside the view; they do not say simulation stops. Assume it does not and cull spawning yourself.

---

## 8. When not to do this

- **Small games with few simultaneous casters.** A solo-player puzzle game with one effect at a time does not need a governor; a template audit and pools are enough.
- **Do not cull your own feedback.** The player's own hit confirmation is the most important effect on their screen. Degrade others' effects to zero before you touch it.
- **Do not distance-cull bosses, telegraphs or objectives.** Simplify them instead.
- **Do not tune budgets on a PC.** A budget tuned on a desktop GPU will be wrong by a factor of several on phones.
- **Do not make the budget invisible to artists.** If the governor silently drops layers, artists will add more layers to compensate. Put the cost estimate next to the template (an attribute or a build report) so everyone sees it.

---

## Common mistakes

| Symptom | Likely cause | Fix |
|---|---|---|
| Fine alone, lags with a full server | No onlooker share or global cap | Governor with a global cap; onlookers at half or less |
| Hitch every few seconds in long fights | Cloning and destroying per hit | Pools with a cap |
| Phones lag only when an effect is near the camera | Overdraw from big transparent pieces | Shrink, raise transparency on the camera line, fewer stacked layers |
| Low settings do not help | Bursts via `Emit` bypass engine thinning | Own detail scalar on burst counts |
| Particles cut off mid-effect | Emitter destroyed or recycled too early | Release after the longest lifetime |
| Ambient effects cost frame time across the map | Never sleep | Distance sleep with hysteresis |
| Telegraph missing on a phone | Gameplay effect culled as decoration | Gameplay flag; simplify, never skip |
| Effect flickers at a distance boundary | Single threshold re-checked often | Two thresholds |

## Checklist

- [ ] Budgets written per cast, per caster window and per client, with onlooker share and distances.
- [ ] Cost estimation script run on every template; worst offenders listed.
- [ ] Gameplay effects flagged; never skipped, only simplified.
- [ ] Governor decides once per effect: owner, distance, view, global load, detail setting.
- [ ] Layers carry `MinDetail`; degradation is authored, not guessed.
- [ ] Long-lived effects sleep by distance with hysteresis.
- [ ] Pools capped; release after the longest lifetime; `Clear()` on reuse.
- [ ] VFX lights without shadows, capped per kit; Highlights pooled and capped.
- [ ] Measured on a real phone with a full party, at low and high quality.

See also: [[VFX Design Playbook]], [[Particle Emitters In Depth]], [[Beams and Trails]], [[Highlights and Selection Effects]], [[Light Sources and Shadows]], [[Rendering Performance]], [[Mobile and Low-End Optimization]], [[Art Budgets - Triangles Draw Calls Memory]], [[Animation LOD]], [[Ability Kits Architecture]], [[Cinematic Ultimates]], [[Game Feel and Juice]].

## Connected notes
<!-- auto-links:start -->
[[Juice on a Budget - Mobile and Low-End]] · Object Pooling · VFX Timing with Animation · Resource Library - Visual Effects · Draw Calls · Links - Particle emitters
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Weather Performance Budgets and Quality Tiers]] · [[Graphics and Performance Toggles for Low-End Devices]] · [[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Impact Decals and Material-Aware Hit Sparks]] · [[Slash VFX Recipes - Crescent and Ring]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]]
<!-- related:end -->
