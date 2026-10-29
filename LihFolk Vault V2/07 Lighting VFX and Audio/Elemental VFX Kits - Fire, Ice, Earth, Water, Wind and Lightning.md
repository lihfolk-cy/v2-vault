---
tags: [vfx, elements, fire, ice, earth, water, wind, lightning, particles, beams, palettes, recipes, type/guide, area/vfx]
---
# Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Colour as the only identifier. Red fire and red blood, blue ice and blue lightning collide.
> - Avoid: Ice that fades in. It reads as mist or magic, not ice.
> - Avoid: Wind with a dark smoke layer. Looks like fire smoke.
> - Palette table written per element, tested on your brightest and darkest map.
> - Each element has a distinct motion signature visible in greyscale.
> - Slashes and swing arcs spawn and emit only in the frontal arc; novas and auras may be radial.
>
> Cost: TL;DR ~160 tok · whole note ~2.5k tok. Read more: ## Palettes and signatures · ## Layer recipes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

An "element" in a Roblox combat or ability game is a contract with the player: one glance at the colour, shape and motion of an effect must tell them what it is and roughly what it will do (burn, slow, knock back, chain). This note gives a per-element kit: palette, shape language, motion signature and a layered emitter recipe, plus the shared rules that keep six elements consistent. It assumes you know `ParticleEmitter`, `Beam` and `Trail`; see [[Particle Emitters In Depth]] and [[Beams and Trails]] for the properties.

Source labels: **Roblox docs** (create.roblox.com engine reference), **Rule of thumb** (LihFolk practice, not measured), **Unverified** (believed true, not checked). No asset ids are given: every texture here is something you author or pick from your own licensed library.

## Shared rules for every element

1. **Direction rule.** Weapon slashes and swing-driven elemental arcs play **only in front of the character**, inside the frontal arc of the swing (rule of thumb: about 120 to 200 degrees centred on the facing direction, never behind the back). Explosions, novas, ground bursts and auras may be radial. If an elemental slash leaks behind the player, it reads as a hit that did not happen and players dodge into it.
2. **Three tones per frame.** White-hot core, element body colour, dark rim or smoke. The dark layer is what makes the element readable on bright maps ([[VFX Design Playbook]]).
3. **One motion signature per element.** Colour alone fails for colour-blind players and on small phone screens. Motion is the second channel: fire rises, ice snaps and holds, earth falls, water arcs and splashes, wind spirals, lightning jumps.
4. **Status effects reuse the element's idle layer.** The burn on a target is the fire kit's ember layer at low rate, not a new effect.
5. **Tier by count, not by new textures.** Light, medium and heavy versions differ in emitter rate, size and number of layers. Ship one texture set per element.

## Palettes and signatures

Colours are starting points (Rule of thumb); tune against your map's lighting and post-processing.

| Element | Core | Body | Dark layer | Motion signature | Shape language |
|---|---|---|---|---|---|
| Fire | near-white yellow | orange to red | brown-black smoke | rises, accelerates up, flickers | teardrops, licks, soft blobs |
| Ice | white | pale cyan to blue | deep navy edge | appears instantly, holds, shatters | hard shards, hexagons, straight edges |
| Earth | warm sand highlight | ochre to brown | dark grey dust | falls with gravity, heavy bounce | chunks, cracks, rings of debris |
| Water | white foam | teal to blue | deep blue shadow | arcs, splashes, drips down | curls, droplets, sheets |
| Wind | white streaks | pale mint or grey, low alpha | none; use distortion of other layers | spirals, sweeps sideways, fast fade | thin streaks, crescents, swirls |
| Lightning | white | electric blue or violet | dark violet afterimage | instant jumps, flicker, branching | jagged polylines, sparks |

Wind is the exception to the three-tone rule: a dark layer makes it look like smoke. Instead give wind contrast through motion (fast streaks against slow dust it kicks up).

## Layer recipes

Each recipe lists layers in priority order. On phones or in crowded fights, drop layers from the bottom ([[VFX Performance Budgets and Culling]]).

### Fire
1. Flame body: flipbook (`FlipbookLayout` 4x4 or 8x8), `LightEmission` around 0.5 to 1, `Acceleration` upward, size curve growing then shrinking, colour sequence white to orange to red.
2. Smoke: non-additive (`LightEmission` 0), dark, slower, larger, rises after the flame, `LightInfluence` near 1 so it sits in the scene's lighting.
3. Embers: small bright specks, `Emit` bursts, upward drift with `Drag`.
4. Heat light: a `PointLight` with flickered brightness, only on heavy tiers.

### Ice
1. Shards: mesh parts or flat cards spawned instantly at full size, tweened out by scale and transparency after a hold. Ice should *not* fade in; it appears.
2. Frost mist: low, slow, pale particles hugging the ground (`Acceleration` slightly down).
3. Glints: 2 to 5 star sparkles with short life.
4. Shatter: on expiry, emit small angular fragments with gravity. The shatter is the payoff; time it with the sound.

### Earth
1. Debris chunks: rock meshes or particle chunks with strong gravity and short bounce. Use `Squash` sparingly for impact frames.
2. Dust ring: a ground-hugging radial ring (radial is fine; it is an impact).
3. Crack decal: a pooled decal on the ground that fades over 2 to 4 s ([[Impact Decals and Material-Aware Hit Sparks]]).
4. Camera feedback: a small shake on heavy tiers only ([[Camera Shake and Camera FX]]).

### Water
1. Sheet or arc: a `Beam` with a scrolling texture (`TextureSpeed`) curved via `CurveSize0/1`, or a swept mesh.
2. Splash droplets: `Emit` bursts with gravity and drag, slightly additive.
3. Foam: white, short-lived, at contact points.
4. Wet decal: a dark, low-opacity splat that dries (fades) over a few seconds.

### Wind
1. Streaks: long thin `Trail`s or squashed particles moving fast, low transparency only for the first frames.
2. Swirl: particles with `RotSpeed` and an orbital spawn pattern, or a rotating ring mesh.
3. Kicked-up dust: reuse earth's dust layer, tinted to the floor, so the wind is shown by what it moves.

### Lightning
1. Bolt: segmented `Beam`s or neon parts along a jagged path, regenerated every 1 to 3 frames for flicker, lifetime under 0.2 s.
2. Branches: shorter forks off random segments.
3. Impact sparks: radial at the strike point (it is an impact).
4. Afterimage: the last bolt shape held faint and dark-violet for a few frames.

A small bolt path builder, reviewed but not run:

```lua
--!strict
-- Returns jagged points from a to b. Offsets shrink near the ends so the
-- bolt attaches cleanly to the caster's hand and the target.
local function boltPoints(a: Vector3, b: Vector3, segments: number, jitter: number, rng: Random): {Vector3}
	local points = {a}
	local dir = b - a
	local right = dir:Cross(Vector3.yAxis)
	if right.Magnitude < 1e-3 then
		right = Vector3.xAxis
	end
	right = right.Unit
	local up = right:Cross(dir).Unit
	for i = 1, segments - 1 do
		local t = i / segments
		local falloff = math.sin(t * math.pi) -- 0 at the ends, 1 in the middle
		local offset = (right * rng:NextNumber(-1, 1) + up * rng:NextNumber(-1, 1)) * jitter * falloff
		table.insert(points, a + dir * t + offset)
	end
	table.insert(points, b)
	return points
end
```

## Elemental slashes: keep the frontal arc

For a fire or ice sword swing, build the slash from the crescent recipe in [[Slash VFX Recipes - Crescent and Ring]] and swap only the body texture, colours and debris layer. Spawn the arc relative to the character's facing at the swing's hit marker, and clamp any secondary particles so their emission direction stays inside the frontal arc. A useful guard:

```lua
-- True if worldPos is inside the frontal arc of root (halfAngleDeg each side).
local function inFrontalArc(root: BasePart, worldPos: Vector3, halfAngleDeg: number): boolean
	local toPoint = worldPos - root.Position
	local flat = Vector3.new(toPoint.X, 0, toPoint.Z)
	if flat.Magnitude < 1e-3 then
		return true
	end
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit
	return flatLook:Dot(flat.Unit) >= math.cos(math.rad(halfAngleDeg))
end
```

Use it in QA tooling to assert that spawned slash parts and burst origins sit in front, not to filter at runtime.

## Common mistakes

- **Colour as the only identifier.** Red fire and red blood, blue ice and blue lightning collide. Give each element its motion signature.
- **Ice that fades in.** It reads as mist or magic, not ice. Snap it in, hold, shatter.
- **Wind with a dark smoke layer.** Looks like fire smoke. Use motion and kicked-up dust instead.
- **Lightning that lingers.** Bolts held for half a second look like neon tubes. Flicker and kill them under about 0.2 s.
- **Elemental slash particles spraying backwards.** Violates the frontal-arc rule and confuses hit reading.
- **Six texture sets per tier.** Tiers should be counts and sizes; extra textures cost memory on phones ([[Textures Decals and Texture Memory]]).
- **Status effects with a new look.** Players should recognise "I am burning" from the fire kit, not learn a new effect.

## Checklist

- [ ] Palette table written per element, tested on your brightest and darkest map.
- [ ] Each element has a distinct motion signature visible in greyscale.
- [ ] Slashes and swing arcs spawn and emit only in the frontal arc; novas and auras may be radial.
- [ ] Three tones per frame (wind excepted).
- [ ] Light, medium and heavy tiers defined by counts, sizes and layer drops.
- [ ] Status effects reuse the element's idle layer.
- [ ] Lightning bolt life under about 0.2 s; ice appears instantly and shatters on expiry.
- [ ] Mobile pass done with the bottom layers dropped.

## See also

- [[VFX Design Playbook]]
- [[Slash VFX Recipes - Crescent and Ring]]
- [[Particle Emitters In Depth]]
- [[Beams and Trails]]
- [[VFX Performance Budgets and Culling]]
- [[VFX Timing with Animation]]
- [[Status Effects Buffs and Stacking Rules]]

## Connected notes

[[Mesh VFX Packs Built in Blender]] · Dash VFX Presentation on an R15 Rig · [[Impact Decals and Material-Aware Hit Sparks]] · Camera Shake and Camera FX · Accessibility

<!-- related:start -->
## Related
[[VFX Previews in Blender for Roblox - Colour and Framing]] · [[Ice Ball Cast to Explosion - Approved Recipe]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Light Sources and Shadows]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Gore Policy and Kid-Friendly Hit Feedback]] · [[Stylized Lighting Recipes]]
<!-- related:end -->
