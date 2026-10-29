---
tags: [weather, lightning, thunder, vfx, audio, procedural, accessibility, photosensitivity, type/recipe, area/vfx, area/audio, level/intermediate, api/Beam, api/ColorCorrectionEffect, api/GetServerTimeNow]
---
# Lightning Strikes and Thunder - Procedural Bolts and Sound Delay

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Creating parts per strike -> Pool segment parts or beams
> - Avoid: Each client randomises the bolt -> Seed from the server event
> - Avoid: Bolt visible half a second -> Total under ~0.3 s with flicker
> - Server sends `{seed, position, strikeAt}`; clients render identical bolts.
> - Segment parts or beams pooled; segment count capped.
> - Strike sequence under ~0.3 s with a weaker second stroke.
>
> Cost: TL;DR ~140 tok · whole note ~3.0k tok. Read more: ## 2. The bolt: midpoint displacement · ## 4. Thunder delay · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Storm lightning has four parts that must agree: a **bolt** that exists for a fraction of a second, a **flash** that lights the world, **thunder** that arrives later the further away the strike was, and optionally a **hazard** that damages what it hits. The server decides when and where strikes happen (so every client sees the same strike and damage is fair); each client renders the bolt, the flash and the delayed thunder locally. This note covers the bolt generator, the flash, the sound delay maths and the photosensitivity limits you must respect. Ability-style lightning (short caster-to-target arcs, palettes) is in [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]]; this note is about sky-to-ground storm strikes.

Source labels: **Roblox docs** (create.roblox.com, as of October 2026), **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

---

## 1. Server schedules, clients render

The server picks strike time and position and fires one event to all clients: `{ seed, position, strikeAt }`. Using `Workspace:GetServerTimeNow()` for `strikeAt` lets clients schedule the visuals at the same instant (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/Workspace#GetServerTimeNow). The seed lets every client generate the **same** bolt shape without sending vertices.

- Ambient strikes (no damage): the server can even skip remotes and derive strikes from the weather forecast seed so every server shows the same pattern ([[Weather System Architecture - State Machine, Transitions and Replication]]). Usually a remote at 0.05-0.3 strikes per second is trivial bandwidth.
- Hazard strikes: schedule `strikeAt = now + telegraph` (1-2 s), show a ground marker immediately, and apply damage on the server at `strikeAt` using a server-side overlap query. Never let the client report "I was hit".
- Only render strikes within a sensible radius (e.g. 1500 studs); beyond that play distant thunder only.

## 2. The bolt: midpoint displacement

Midpoint displacement: start with a line from sky to ground, repeatedly split each segment at its midpoint and push the midpoint sideways by a random offset that halves each generation. Branches spawn from some midpoints, shorter and thinner.

```lua
--!strict
export type Segment = { a: Vector3, b: Vector3, width: number }

local function perpendicular(dir: Vector3, rng: Random): Vector3
	local any = if math.abs(dir.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local p1 = dir:Cross(any).Unit
	local p2 = dir:Cross(p1).Unit
	local t = rng:NextNumber(0, math.pi * 2)
	return p1 * math.cos(t) + p2 * math.sin(t)
end

local function buildBolt(top: Vector3, bottom: Vector3, seed: number, generations: number): {Segment}
	local rng = Random.new(seed)
	local segments: {Segment} = { { a = top, b = bottom, width = 1.2 } }
	local offset = (bottom - top).Magnitude * 0.18
	for _ = 1, generations do
		local nextSegs: {Segment} = {}
		for _, s in segments do
			local dir = (s.b - s.a).Unit
			local mid = (s.a + s.b) / 2 + perpendicular(dir, rng) * rng:NextNumber(-offset, offset)
			table.insert(nextSegs, { a = s.a, b = mid, width = s.width })
			table.insert(nextSegs, { a = mid, b = s.b, width = s.width })
			if rng:NextNumber() < 0.12 and s.width > 0.4 then -- branch
				local branchEnd = mid + (mid - s.a).Unit * (s.b - s.a).Magnitude * 0.7
					+ perpendicular(dir, rng) * offset * 1.5
				table.insert(nextSegs, { a = mid, b = branchEnd, width = s.width * 0.45 })
			end
		end
		segments = nextSegs
		offset *= 0.5
	end
	return segments
end
```

Practical numbers (Rule of thumb): 5-6 generations gives 32-64 main segments, enough detail at 300 studs tall. More than 7 generations wastes parts without visible gain. The `0.18` and `0.5` factors control jaggedness; lower the first for straighter bolts.

Because `Random.new(seed)` is deterministic, every client builds an identical bolt from the same seed (Roblox docs: https://create.roblox.com/docs/reference/engine/datatypes/Random). Branch counts vary per seed, so cap total segments (e.g. 120) and stop branching once reached.

### Rendering the segments

| Option | How | Notes |
|---|---|---|
| Neon parts | One anchored part per segment, `Material = Neon`, size `(width, width, length)`, `CFrame.lookAt(mid, b)` | Simple, glows with bloom. Set `CanCollide`, `CanQuery`, `CanTouch` false, `CastShadow` false. Pool them |
| Beams | Two attachments per segment on one anchored part, a `Beam` with a bright texture, `LightEmission = 1`, `FaceCamera = true` | Fewer instances moving; nicer soft edges; widths via `Width0`/`Width1` |

Either way: **pool, do not create**. A storm with a strike every 3 s creating 60 parts each time is a steady stream of instance churn ([[Object Pooling]]).

### Timing a strike

Real lightning flickers as several return strokes along the same channel. A convincing sequence (Rule of thumb):

1. 0.00 s: show full bolt, flash peak.
2. 0.05 s: hide branches, main channel at 60 percent.
3. 0.10 s: full bolt again (second stroke), smaller flash.
4. 0.18 s: hide all. Optional faint afterglow on the main channel to 0.3 s.

Total visible time under ~0.3 s. Longer looks like neon tubing.

## 3. The flash

Light the scene for a few frames:
- `ColorCorrectionEffect` owned by the weather renderer: push `Brightness` up (e.g. +0.3 to +0.5) and slightly cool `TintColor`, then decay over 0.15-0.3 s.
- Or a large `PointLight` at the strike point with high `Range` (max 60 studs per Roblox docs for PointLight `Range`) for local ground illumination; only useful for close strikes.
- Optionally pulse `Atmosphere.Glare` or cloud colour for strikes hidden behind clouds ("sheet lightning").

Scale flash intensity by distance: close strikes are bright and sharp, distant ones are dim, slow flickers in the clouds.

## 4. Thunder delay

Sound travels at roughly 343 m/s in air (physics constant). Roblox docs state a character-scale conversion of about 1 stud = 0.28 m (https://create.roblox.com/docs/physics/units), so realistic thunder travels about 1225 studs/s.

```lua
--!strict
local SOUND_SPEED = 1225 -- studs per second, realistic; many games use 400-700 to make storms feel close

local function thunderDelay(strikePos: Vector3, listenerPos: Vector3): number
	return (strikePos - listenerPos).Magnitude / SOUND_SPEED
end
```

- Realistic delay means a strike 1000 studs away rumbles 0.8 s later, which is less dramatic than players expect. A stylised slower speed (Rule of thumb: 400-700 studs/s) exaggerates the "count the seconds" effect. Pick one constant and use it everywhere.
- **Choose the clip by distance:** close (< 200 studs) gets a sharp crack, mid gets a crack plus roll, far (> 800) gets a low rumble only. Attenuating one clip with volume alone sounds wrong because distance removes high frequencies.
- Play thunder non-positionally (it comes from the sky) but pan slightly toward the strike if you use the Audio API with an emitter far away; or simply use a `Sound` on a part at the strike point with a large `RollOffMaxDistance`. With `Sound`, volume rolloff is automatic; delay is not, so schedule playback with `task.delay(thunderDelay(...), ...)`.
- Schedule from `strikeAt`, not from when the remote arrived, so laggy clients still hear thunder at the right moment relative to their flash.

## 5. Photosensitivity and comfort

Flashing light can trigger seizures in people with photosensitive epilepsy. The widely used WCAG 2.3.1 guideline says content should not flash more than three times in any one-second period (https://www.w3.org/TR/WCAG21/#three-flashes-or-below-threshold). Rules for storms:

- Enforce a global flash limiter: no more than 3 flashes per rolling second, and prefer at most 1 strong flash per 2-3 s (Rule of thumb, stricter than the guideline).
- The multi-stroke sequence in section 2 counts as one flash only if the brightness dips are small; keep the second stroke's flash weaker.
- Avoid full-screen saturated red flashes entirely.
- Provide a "reduce flashing" setting that dims flashes to a small brightness bump and keeps bolts and thunder. Wire it into the same comfort toggles as hit flashes ([[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]], [[Motion Sensitivity and Camera Comfort]]).

```lua
--!strict
local recent: {number} = {}
local function allowFlash(now: number): boolean
	for i = #recent, 1, -1 do
		if now - recent[i] > 1 then table.remove(recent, i) end
	end
	if #recent >= 3 then return false end
	table.insert(recent, now)
	return true
end
```

## 6. Hazard strikes

- Telegraph with a ground ring and a rising crackle sound 1-2 s before; never strike players without warning ([[Lighting Mood and Time of Day]] notes the same rule).
- Damage on the server with `Workspace:GetPartBoundsInRadius` at the strike point at `strikeAt`, filtered to characters; apply through your one damage function.
- Tall-object attraction: bias strike positions toward tagged lightning rods or tall props within a radius. It reads as fair and gives players counterplay.
- Keep hazards out of lobbies, safe zones and spawn areas.

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Creating parts per strike | Hitches in long storms | Pool segment parts or beams |
| Each client randomises the bolt | Players describe different strikes | Seed from the server event |
| Bolt visible half a second | Looks like a neon tube | Total under ~0.3 s with flicker |
| Thunder played on remote arrival | Thunder before the flash on laggy clients | Schedule from `strikeAt` plus distance delay |
| One thunder clip, volume only | Distant thunder sounds like a close crack | Clip chosen by distance |
| Unlimited flashes | Photosensitivity risk | Global 3 per second limiter and a setting |
| Client reports hits | Exploiters immune, or framing others | Server overlap at `strikeAt` |

## Checklist

- [ ] Server sends `{seed, position, strikeAt}`; clients render identical bolts.
- [ ] Segment parts or beams pooled; segment count capped.
- [ ] Strike sequence under ~0.3 s with a weaker second stroke.
- [ ] Flash scaled by distance and routed through one renderer.
- [ ] Thunder delay uses one speed constant and distance-picked clips.
- [ ] Flash limiter at or below 3 per second plus a reduce-flashing option.
- [ ] Hazards telegraphed and resolved on the server.

## See also

[[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Weather System Architecture - State Machine, Transitions and Replication]] · [[Beams and Trails]] · [[Light Sources and Shadows]] · [[Atmosphere Sky Clouds and Post-Processing]] · [[Spatial Audio and Mixing]] · [[Feedback Timing - Sound Visual and Haptic Sync]] · [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]] · [[Object Pooling]] · [[Seeds Determinism and Reproducible Worlds]]

## Connected notes
<!-- auto-links:start -->
[[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Motion Sensitivity and Camera Comfort]] · [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[VFX Design Playbook]] · [[Stylized Lighting Recipes]] · [[VFX Readability and Value - Lessons from Blind Reviews]] · [[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[VFX Previews in Blender for Roblox - Colour and Framing]] · [[Game Feel and Juice]] · [[VFX Performance Budgets and Culling]] · [[Lighting Technologies and Settings]]
<!-- related:end -->
