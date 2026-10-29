---
tags: [vfx, particles, particleemitter, flipbooks, performance, type/guide, area/vfx, level/intermediate, api/LightInfluence, area/performance, api/ParticleEmitter, api/Emit]
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
> Cost: TL;DR ~180 tok · whole note ~5.5k tok. Read more: ## 2. Property reference with traps · ## 5. Motion recipes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

`ParticleEmitter` is the workhorse of Roblox VFX: sparks, smoke, slash cards, ground rings, flashes, rain, auras and magic dust are all camera-facing (or velocity-aligned) textured quads with a few curves. It looks simple, and that is the danger: most of its properties have a non-obvious rule (which ones affect live particles, which only new ones, which are world space, which silently cap), and a professional-looking effect is almost always a stack of six to twenty tuned emitters rather than one clever one.

This note goes property by property with the traps, then covers bursts versus streams, flipbooks, performance budgets, pooling and testing. Design method and recipes are in [[VFX Design Playbook]]; timing to animation is in [[VFX Timing with Animation]].

Source labels: **Docs** (October 2026), **API dump** (defaults), **Reference project** (one production combat game built with this vault), **Rule of thumb**.

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

**About `Drag`.** The docs describe it as the rate at which particles lose half their speed via exponential decay. In practice treat it as a decay rate: bigger means faster stopping. A useful mental model is that speed roughly halves every `1/Drag` seconds (rule of thumb; the exact formula is not documented). It explains the two classic uses: a very high speed paired with a very high drag gives a streak that shoots out a short, fixed distance and stops dead, while a moderate speed with a little drag and gravity gives sparks that burst out and then fall.

**`LockedToPart` vs `VelocityInheritance = 1`.** Locked particles stay glued to the emitter forever (an aura orbiting the body). Inherited velocity only gives the starting speed; particles then drift free (dust kicked from a running foot). Use locked for anything that must stay "on" the caster; inherited for anything that should trail behind.

### Flipbooks

| Property | Notes (Docs) |
|---|---|
| `FlipbookLayout` | `None`, `Grid2x2` (4 frames), `Grid4x4` (16), `Grid8x8` (64), `Custom` (with `FlipbookSizeX/Y`). |
| `FlipbookMode` | `Loop`, `OneShot` (once across the particle's lifetime: frame rate = frame count / lifetime, `FlipbookFramerate` ignored), `PingPong`, `Random` (random order with crossfades). |
| `FlipbookFramerate` | Range, **maximum 30 fps**. |
| `FlipbookStartRandom` | Each particle starts on a random frame. With a framerate at or near 0, every particle shows one random static frame, a cheap way to get variety from one sheet. |
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

Rule of thumb, from building and reviewing effects for the reference project:

- **`LightInfluence = 0` on all VFX.** Otherwise effects go dark in dark zones and colourless in shade.
- **`LightEmission = 1` is additive glow**; `LightEmission = 0` with high `Brightness` gives solid saturated colour that does not wash to white.
- **The bigger the sprite on screen, the lower its brightness.** Additive light adds up per pixel, so a large glowing card quickly turns the whole screen white while a tiny spark needs a lot of brightness to be noticed at all. Start large sprites well below 1, mid-size ones around 1, and small specks or one-frame flashes several times higher, then tune with bloom on.
- **Give every bright stack one dark layer.** A darker ring, a grey smoke puff with `LightEmission = 0`, or a shadowed debris layer gives the glow something to read against. Some creators also push `LightEmission` below 0 to darken and thicken smoke or water; that is outside the documented 0 to 1 range, so treat it as undocumented and re-check it after engine updates.
- **Water and dense matter** look solid when they are not additive: low or zero `LightEmission`, a saturated colour and enough brightness to stay vivid.

---

## 5. Motion recipes

All rows are **Rule of thumb** starting points; tune speeds and sizes to your character scale.

| Effect | Recipe |
|---|---|
| Sparks | `VelocityParallel` so they stretch along their path, a wide speed range, some drag, gravity pulling down, size shrinking to 0 |
| Debris that bursts then hangs | Fast start, higher drag, weak gravity: it pops out and lingers before settling |
| Streaks | Very high speed with very high drag and a very short lifetime: a sharp line that stops at a fixed distance |
| Rising energy | `LockedToPart`, slow speed, a gentle upward acceleration, fade in and out |
| Pull in, then float | Negative speed (particles move toward the emitter) plus a small upward acceleration |
| Split spray | Two emitters with mirrored sideways acceleration, so the spray parts like a bow wave |
| Twinkle | A size curve with two bumps (grow, shrink, grow, shrink) over a short life |
| Flat card (slash, ground ring) | `VelocityPerpendicular`, a tiny speed (direction only), `SpreadAngle` 0; `EmissionDirection` Top or Bottom mirrors the card |
| Random 3D cards | `VelocityParallel` with `SpreadAngle` 360 |
| Ground ring | Flat card on a Disc shape, size growing fast and easing out, a little rotation, low brightness once it is large |

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
| Fast fade, long tail | (0, 0) (0.25, 0.5) (0.8, 0.9) (1, 1) |
| Hold then fade | (0, 0) (0.4, 0.2) (0.75, 0.8) (1, 1) |
| Breathing sprite | (0, 1) (0.5, 0) (1, 1) |
| Fade in and out card | (0, 1) (0.2, 0) (0.7, 0) (1, 1) |

Add a keypoint rather than bending the curve: if a particle should be invisible before the end of its life, put a keypoint with value 1 at that time and another at the end. Explicit keypoints stay correct whatever the engine does with out-of-range values.

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
[[VFX Performance Budgets and Culling]] · [[Official Docs - Visual Effects]] · [[Light Sources and Shadows]] · Mesh VFX Packs Built in Blender · Juice on a Budget - Mobile and Low-End · Dash VFX Presentation on an R15 Rig
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[ParticleEmitter - Engine Reference Card]] · [[Designing VFX Textures and Flipbooks in Figma]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Slash VFX Recipes - Crescent and Ring]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Projectile VFX - Muzzle, Travel and Impact]] · [[VFX Readability and Value - Lessons from Blind Reviews]]
<!-- related:end -->
