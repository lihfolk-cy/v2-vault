---
tags: [vfx, particles, particleemitter, flipbooks, performance]
---
# Particle Emitters In Depth

<!-- tldr:start -->
> [!tldr] TL;DR
> - Effect dark in caves, grey in shade: `LightInfluence` 1 (Studio insert default) -> Set 0 explicitly.
> - Emitter built in code looks different from the Studio template: Different `LightInfluence` defaults between insert paths -> Set every property explicitly in code or...
> - Sphere/Cylinder shape looks wrong: Emitter on an Attachment -> Put it on a part.
> - `LightInfluence` set explicitly on every VFX emitter (usually 0).
> - Brightness chosen by screen area; one dark contrast layer per bright stack.
> - Bursts via `Emit` with your own quality scaling; streams capped.
>
> Read more (20 KB note): ## 2. Property reference with traps · ## 5. Motion recipes (studied packs) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

`ParticleEmitter` is the workhorse of Roblox VFX: sparks, smoke, slash cards, ground rings, flashes, rain, auras and magic dust are all camera-facing (or velocity-aligned) textured quads with a few curves. It looks simple, and that is the danger: most of its properties have a non-obvious rule (which ones affect live particles, which only new ones, which are world space, which silently cap), and a professional-looking effect is almost always a stack of six to twenty tuned emitters rather than one clever one.

This note goes property by property with the traps, then covers bursts versus streams, flipbooks, performance budgets, pooling and testing. Design method and recipes are in [[VFX Design Playbook]]; timing to animation is in [[VFX Timing with Animation]].

Source labels: **Docs** (October 2026), **API dump** (defaults), **Reference project** (one production combat game and its studied VFX packs), **Rule of thumb**.

---

## 1. Where particles come from

A `ParticleEmitter` must be parented to a `BasePart` or an `Attachment` inside one (Docs):
- **On a part:** particles spawn within the part's bounding box or chosen `Shape`. `EmissionDirection` picks the face.
- **On an attachment:** particles spawn at the attachment's position. Rotate the attachment instead of using `EmissionDirection` (Docs). This is the standard for effects: one invisible anchored part carries many attachments, each with emitters.

Shape caveat: `Sphere` and `Cylinder` shapes "will not display correctly" when the emitter is on an `Attachment` (Docs). Use them only on parts.

| Shape | `ShapePartial` meaning (Docs) |
|---|---|
| `Box` | not used |
| `Sphere` | Hemispherical angle: 1 full sphere, 0.5 half dome, 0 a single point at the north pole |
| `Cylinder` | Top radius proportion: 0 makes a cone |
| `Disc` | Inner radius: 0 filled disc, 1 only the rim, between = annulus |

`ShapeStyle` = `Volume` (anywhere inside) or `Surface` (only the outside). `ShapeInOut` = `Outward`, `Inward`, `InAndOut`. A `Disc` with `ShapePartial = 0.7`, `Surface`, `Outward` is a ring that spits particles outward, the basis of many ground bursts.

---

## 2. Property reference with traps

Defaults from the API dump (what `Instance.new` gives). **Inserting through Studio's UI gives different values for some properties**, notably `LightInfluence`: 1 when inserted with Studio tools, 0 via `Instance.new()` (Docs). Templates authored in Studio and emitters built in code therefore light differently unless you set it explicitly.

### Appearance

| Property | Default | Notes |
|---|---|---|
| `Texture` | built-in sparkle | Transparent PNG works best. Greyscale textures with no alpha: set `LightEmission = 1` to hide dark regions (Docs). Greyscale plus `Color` lets one texture serve every element colour. |
| `Color` | white | `ColorSequence` over each particle's life; up to 20 keypoints (Docs, datatype). With `LightEmission > 0`, darker colours look more transparent. |
| `Transparency` | 0 | `NumberSequence` over life; keypoint envelopes randomise per particle. Fading in and out avoids popping (Docs). |
| `Size` | 1 | `NumberSequence` in studs, linear between keypoints; envelopes randomise per particle. Max 20 keypoints. |
| `Squash` | 0 | Non-uniform scale over life: positive stretches vertically and thins horizontally, negative the reverse (Docs). Rain, speed lines, anamorphic flash streaks. |
| `LightEmission` | 0 | 0 normal blend, 1 additive. **Does not light the world** (Docs). Negative values are used in practice to darken (see section 5). |
| `LightInfluence` | 0 | 0 unaffected by scene light; 1 fully lit like a part (black in darkness). Docs: keep in 0 to 1; outside is undefined. Set 0 on almost every VFX layer. |
| `Brightness` | 1 | Scales emitted light when `LightInfluence` is 0 (Docs). Above 1 drives bloom; see brightness rules below. |
| `Orientation` | `FacingCamera` | `FacingCamera`, `FacingCameraWorldUp` (only yaws around world up), `VelocityParallel` (long axis along motion), `VelocityPerpendicular` (card faces along motion, i.e. lies flat across it). |
| `ZOffset` | 0 | Studs toward (+) or away from (-) the camera without changing screen size (Docs). Sorts layers; large negative values push particles behind their parent. |
| `Rotation` | 0 | Degrees for new particles; `[0, 360]` randomises. Changes affect new particles only. |
| `RotSpeed` | 0 | Degrees per second, random per particle. Very high speeds can alias to looking slow or still (Docs: 360 degrees per frame looks stationary). |

### Emission and lifetime

| Property | Default | Notes |
|---|---|---|
| `Enabled` | true | False stops new particles; existing ones finish their life. `Clear()` removes them (Docs). |
| `Rate` | 20 | Particles per second while enabled. **Cap: 400 per second per emitter, 100 on mobile** (Docs). Changing it does not affect live particles. |
| `Lifetime` | 5 to 10 | `NumberRange`, chosen per particle at birth. **Maximum 20 seconds** (Docs; higher values are capped). Lifetime 0 prevents emission. |
| `Speed` | 5 | Studs per second, random in range at birth, along `EmissionDirection`. Negative reverses. Changing it does not affect live particles. |
| `SpreadAngle` | (0, 0) | Degrees around the emission axis on X and Z. One axis 360 = a circle, both 360 = a sphere (Docs). |
| `EmissionDirection` | `Top` | Face of the parent; use attachment orientation instead when on an attachment. |
| `TimeScale` | 1 | 0 to 1: 0.5 half speed, 0 frozen (Docs). Slow motion and stills for captures. |

### Motion

| Property | Default | Notes |
|---|---|---|
| `Acceleration` | (0, 0, 0) | **World-space** studs/s squared, applied to all live particles (Docs). Gravity is a negative Y. Because it is world space, it does not rotate with the emitter. |
| `Drag` | 0 | Exponential decay of speed; negative values grow speed exponentially (Docs). See the note below. |
| `VelocityInheritance` | 0 | Fraction of the parent part's velocity given at birth. With drag, a moving part "sheds" particles (Docs). |
| `LockedToPart` | false | Live particles move rigidly with the parent. Auras, charge-ups, rising energy around a moving character. |
| `WindAffectsDrag` | false | Follows `Workspace.GlobalWind`, only if `Drag > 0` (Docs). Rain and leaves that sway with the world's wind. |

**About `Drag`.** The docs describe it as the rate at which particles lose half their speed via exponential decay. In practice treat it as a decay rate: bigger means faster stopping. A model consistent with studied packs is that speed roughly halves every `1/Drag` seconds (rule of thumb; the exact formula is not documented). Check against a real pack: zip streaks at Speed 1200 with Drag about 200 and life 0.05 to 0.09 s travel a short, sharp distance and stop, exactly what the model predicts. Sparks at Speed 68 to 170 with Drag 4.8 and gravity -129 burst out and fall.

**`LockedToPart` vs `VelocityInheritance = 1`.** Locked particles stay glued to the emitter forever (an aura orbiting the body). Inherited velocity only gives the starting speed; particles then drift free (dust kicked from a running foot). Use locked for anything that must stay "on" the caster; inherited for anything that should trail behind.

### Flipbooks

| Property | Notes (Docs) |
|---|---|
| `FlipbookLayout` | `None`, `Grid2x2` (4 frames), `Grid4x4` (16), `Grid8x8` (64), `Custom` (with `FlipbookSizeX/Y`). |
| `FlipbookMode` | `Loop`, `OneShot` (once across the particle's lifetime: frame rate = lifetime / frame count, `FlipbookFramerate` ignored), `PingPong`, `Random` (random order with crossfades). |
| `FlipbookFramerate` | Range, **maximum 30 fps**. |
| `FlipbookStartRandom` | Each particle starts on a random frame. With framerate 0 (studied packs use 0.001), every particle shows one random static frame. |
| `FlipbookBlendFrames` | Crossfade between frames (default true) or hard swap. |

Texture rules:
- The editor's incompatibility message reads "Particle texture must be 1024 by 1024 to use flipbooks" (API dump), while the reference page says the size must be an exact multiple of the layout. **Author flipbooks at 1024 x 1024** to satisfy both.
- Leave transparent spacing around each frame; mip filtering can bleed neighbouring frames (Docs).
- Flipbooks cost texture memory, and **clients deactivate flipbooks automatically when low on memory**, likely on older phones (Docs). An effect that is only a flipbook can therefore degrade to a static first frame. Reuse a few sheets across effects.

`OneShot` with a short lifetime is the standard for slash cards and explosions: a 16-frame 4x4 sheet over 0.3 s plays at about 53 fps of animation, faster than the 30 fps cap allows in `Loop` mode, because OneShot derives its rate from lifetime.

---

## 3. Bursts versus streams

| | Stream (`Enabled` + `Rate`) | Burst (`:Emit(n)`) |
|---|---|---|
| Use | Continuous: fire, aura, rain, trails of dust | Moments: impacts, flashes, slashes, pickups |
| Setup | `Enabled = true` | Keep `Enabled = false`; call `Emit(n)` |
| Quality scaling | Engine scales density with graphics quality (Docs: particle quality changes with settings) | **Not scaled** in the reference project's measurements: `Emit` bypassed the automatic thinning, so burst-heavy effects had to thin themselves |
| Edit mode | **Does not run in Edit** (reference project) | Works in Edit |

The Edit-mode behaviour matters for authoring: Studio only steps particles when it renders, and rate emission does not run in Edit at all (reference project). To preview a stream effect in Edit, temporarily convert it to bursts, or test in Play.

### A burst helper that respects your own quality setting

You cannot reliably read the engine's automatic quality level from scripts (`UserGameSettings.SavedQualityLevel` reports the saved setting, which is `Automatic` for most players). So keep your own detail scalar: from a settings menu, from measured frame time, or both.

```lua
--!strict
-- Burst: quality-aware emission for templates authored with attributes.
-- Each emitter may carry: EmitCount (number), EmitDelay (seconds), MinDetail (0..1).
local Burst = {}

Burst.detail = 1 -- 0..1, set by your graphics setting or frame-time monitor

local function emitOne(emitter: ParticleEmitter, scale: number)
	local count = emitter:GetAttribute("EmitCount")
	local n = if type(count) == "number" then count else 1
	local minDetail = emitter:GetAttribute("MinDetail")
	if type(minDetail) == "number" and Burst.detail < minDetail then
		return -- this layer is decoration; skip it at low detail
	end
	-- Keep at least one particle for hero layers so the effect still reads.
	local scaled = math.max(1, math.floor(n * scale * Burst.detail + 0.5))
	emitter:Emit(scaled)
end

-- Fire every emitter under root, honouring per-emitter delays.
function Burst.play(root: Instance, scale: number?)
	local s = scale or 1
	for _, d in root:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local delay = d:GetAttribute("EmitDelay")
			if type(delay) == "number" and delay > 0 then
				task.delay(delay, function()
					if d.Parent then
						emitOne(d, s)
					end
				end)
			else
				emitOne(d, s)
			end
		end
	end
end

return Burst
```

The `MinDetail` attribute lets an artist mark which layers are essential (flash, body) and which are decoration (extra sparks, haze) without touching code.

---

## 4. Brightness, blending and contrast

Rules distilled from decoded professional packs (reference project study):

- **`LightInfluence = 0` on all VFX.** Otherwise effects go dark in dark zones and colourless in shade.
- **`LightEmission = 1` is additive glow**; `LightEmission = 0` with high `Brightness` gives solid saturated colour that does not wash to white.
- **Brightness inversely proportional to screen area.** Big sprites (5 to 20 studs) at LightEmission 1 need tiny brightness (0.001 to 0.1) or they white out the screen; mid sprites (1 to 4 studs) 0.2 to 1; specks under 0.5 studs 5 to 30; sub-0.1 s flashes 10 to 40 with bloom (Threshold around 2) to catch them.
- **Every bright stack gets one dark layer.** Black-coloured rings at LightEmission 0.25, grey smoke (84, 84, 84) at LightEmission 0 under additive smoke, or negative LightEmission (-0.4 to -2) on smoke, debris and splash layers. Negative values darken and densify; they are outside the documented 0 to 1 description, so treat them as an undocumented technique that works today, and verify after engine updates.
- **Water and dense matter** use LightEmission slightly negative (-0.1 to -0.5) with high Brightness (10 to 45): saturated, opaque-looking water.

---

## 5. Motion recipes (studied packs)

| Effect | Recipe |
|---|---|
| Sparks | `VelocityParallel`, Speed 68 to 170, Acceleration (0, -129, 0), Drag 4.8, Size 3.5 to 0 |
| Debris that bursts then hangs | Speed 80 to 100, Drag 7, gravity about -31 |
| Zip streaks | Speed 1200, Drag 200, Lifetime 0.05 to 0.09 |
| Rising energy | `LockedToPart`, Speed 12 to 24, Drag 4.7, Acceleration +30 Y |
| Pull in, then float | Negative Speed plus an equal upward Acceleration |
| Split spray | Mirrored emitter pairs with Acceleration (+15, -20, +15) and (-15, -20, -15) |
| Twinkle | Size double hump 0, 1.9, 0, 1.6, 0 and Drag 5 |
| Flat card (slash, ground ring) | `VelocityPerpendicular`, Speed 0.001 (direction only), SpreadAngle 0; `EmissionDirection` Top or Bottom mirrors the card |
| Random 3D cards | `VelocityParallel` with SpreadAngle 360 |
| Ground ring | Flat card on a Disc, Size 0 to 25 to 35 eased out, RotSpeed -1050 to -100, TimeScale 0.7 to 0.8, Brightness at most 0.15 when big |

The flat-card trick is the most important one to understand: `VelocityPerpendicular` orients the quad perpendicular to its velocity, and a tiny speed (0.001) gives the card a direction without moving it. Point the attachment along the card's normal and you have a flat slash or ring in any plane.

### Size curves

Effects feel punchy when they grow fast and settle: about 80% of final size by 35% of life. A linear 0 to 1 `Size` sequence looks mechanical. Build eased curves in code with up to 20 keypoints:

```lua
--!strict
-- Ease-out size curve: fast growth that settles. Max 20 keypoints per NumberSequence (Docs).
local function easeOutSize(from: number, to: number, keys: number?): NumberSequence
	local n = math.clamp(keys or 12, 2, 20)
	local points = table.create(n)
	for i = 0, n - 1 do
		local t = i / (n - 1)
		local e = 1 - (1 - t) ^ 3 -- cubic ease-out
		points[i + 1] = NumberSequenceKeypoint.new(t, from + (to - from) * e)
	end
	return NumberSequence.new(points)
end

-- Example: a ground ring that expands from 0 to 30 studs.
-- emitter.Size = easeOutSize(0, 30)
```

### Transparency presets

| Preset | Keypoints (time, value) |
|---|---|
| Fast fade, long tail | (0, 0) (0.24, 0.49) (0.83, 0.94) (1, 1) |
| Hold then fade | (0, 0) (0.34, 0.25) (0.74, 0.81) (1, 1) |
| Breathing sprite | (0, 1) (0.5, 0) (1, 1) |
| Fade in and out card | (0, 1) (0.2, 0) (0.7, 0) (1, 1) |

A trick from studied packs: a final keypoint value **above 1** (for example 1.5) is invalid as transparency but makes the interpolated curve reach 1 earlier, an early fade without extra keypoints. It relies on undocumented clamping; prefer explicit keypoints if you want to be safe.

---

## 6. Performance

From the docs:
- **Fill rate:** particle size costs GPU because big particles cover more pixels.
- **Overdraw:** overlapping transparent particles are the main cost. Many layers stacked on one spot cost more than the same count spread out.
- **Rate cap:** 400 per second per emitter (100 on mobile).
- **Flipbook memory:** can be switched off on low-memory devices.

Budgets from the reference project:

| Budget | Value |
|---|---|
| Per premium effect library | 3,200 particles per 2 s per caster; onlookers half |
| Ultimate caster | 5,600 particles per 2 s |
| Per sword swing | At most about 30 emitters and 140 beams; finisher about 44 and 210 |
| Emitters per ability kit folder | 16 (reduced from 24) |
| Distance | Drop decoration layers for other players' effects beyond about 160 studs; skip small juice beyond 220 |

Other rules:
- **Effects are client-side.** The server fires one remote or sets an attribute; every client builds the effect. Server-created emitters replicate as instances and cost bandwidth for no reason ([[Client-Server Model]]).
- **Pool emitters.** Memory stays allocated until instances are destroyed, and creating and destroying effects per hit churns the garbage collector. Clone templates once, then reposition and `Emit`.
- **Clear before reuse.** A pooled emitter reused while its last burst is alive will show both; call `Clear()` when recycling for an unrelated hit.
- **Do not `Destroy` the emitter the instant you emit.** Destroying the emitter destroys its live particles. Keep it until `Lifetime.Max` has passed.

```lua
--!strict
-- Release an effect root after its longest particle can still be alive.
local function longestLife(root: Instance): number
	local maxLife = 0
	for _, d in root:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local delay = d:GetAttribute("EmitDelay")
			local extra = if type(delay) == "number" then delay else 0
			maxLife = math.max(maxLife, d.Lifetime.Max + extra)
		end
	end
	return maxLife
end

local function releaseLater(root: Instance, onRelease: (Instance) -> ())
	task.delay(longestLife(root) + 0.1, function()
		onRelease(root) -- return to pool, or root:Destroy()
	end)
end
```

---

## 7. Precipitation and ambient particles

- Attach the rain or snow emitter to an invisible part that follows the camera (updated in `PreRender`) a few studs above it; never cover the whole map.
- Use `Squash` (positive) on a thin texture for rain streaks (Docs: squash is especially useful for rain), `WindAffectsDrag` with a small Drag to follow wind.
- Keep the box shape large enough that moving fast does not outrun it; spawn ahead in the direction of motion.
- Scale rate with your detail scalar; a phone does not need 400 drops per second.

---

## 8. Testing

- Test at the lowest and highest Editor Quality Level (Docs).
- Check effects in Play, because streams do not run in Edit.
- Slow motion for review: set `TimeScale` to 0.2 to 0.4 on all emitters of an effect; set it to 0 to freeze for a still capture (the reference project's QA used a "still" flag and a slow factor on its effect layer).
- View from the player's real camera distance and on a phone screen size. Effects tuned in a close-up Studio view are usually too small and too busy in play.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Effect dark in caves, grey in shade | `LightInfluence` 1 (Studio insert default) | Set 0 explicitly. |
| Emitter built in code looks different from the Studio template | Different `LightInfluence` defaults between insert paths | Set every property explicitly in code or clone the template. |
| Sphere/Cylinder shape looks wrong | Emitter on an Attachment | Put it on a part. |
| Burst invisible | Lifetime 0, or emitter destroyed right after `Emit` | Lifetime above 0; delay cleanup. |
| Particles vanish after 20 s | Lifetime cap | Re-emit or use a different technique. |
| Flipbook shows one frame on old phones | Flipbooks disabled under memory pressure | Reuse sheets; make the first frame acceptable. |
| Flipbook error in Properties | Texture not 1024 x 1024 | Author sheets at 1024. |
| Gravity points the wrong way on a rotated rig | Acceleration is world space | Compute it in world space from the rig's orientation. |
| Effect does nothing in Edit | Rate emission does not run in Edit | Test in Play or temporarily emit bursts. |
| Phones stutter on big fights | Bursts bypass quality thinning | Own detail scalar; per-layer `MinDetail`. |
| Effect stacks of the same hit draw twice | Two systems fired one beat | Claim beats (see [[VFX Design Playbook]]). |

## Checklist

- [ ] `LightInfluence` set explicitly on every VFX emitter (usually 0).
- [ ] Brightness chosen by screen area; one dark contrast layer per bright stack.
- [ ] Bursts via `Emit` with your own quality scaling; streams capped.
- [ ] Flipbooks 1024 x 1024 with spacing, few unique sheets.
- [ ] Emitters pooled; roots released after the longest lifetime.
- [ ] Effects built on clients only.
- [ ] Reviewed in Play, slowed, at low and high quality, on a phone.

See also: [[VFX Design Playbook]], [[Beams and Trails]], [[VFX Timing with Animation]], [[Game Feel and Juice]], [[Textures Decals and Texture Memory]], [[Rendering Performance]], [[Memory Budgets and Leaks]], [[Performance and Memory]].

## Connected notes
<!-- auto-links:start -->
[[VFX Performance Budgets and Culling]] · [[Links - Particle emitters]] · [[Light Sources and Shadows]] · [[Mesh VFX Packs Built in Blender]] · [[Juice on a Budget - Mobile and Low-End]] · [[Dash VFX Presentation on an R15 Rig]]
<!-- auto-links:end -->
