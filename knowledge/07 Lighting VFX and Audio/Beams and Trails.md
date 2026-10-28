---
tags: [vfx, beams, trails, slashes, bezier]
---
# Beams and Trails

Particles are points; beams and trails are ribbons. A `Beam` draws a textured ribbon along a cubic Bézier curve between two attachments: lasers, lightning arcs, waterfalls, force-field skins, slash crescents, tractor beams, tutorial guide lines. A `Trail` records where two attachments have been and fills the space between: sword trails, dash streaks, limb afterimages, tyre marks. Both are cheap, both are easy to make ugly, and both have a handful of rules that explain nearly every bug.

Source labels: **Docs** (October 2026), **API dump** (defaults), **Reference project** (one live action game and its studied VFX packs), **Rule of thumb**.

---

## 1. Beam fundamentals

A beam needs `Attachment0` and `Attachment1` set to two different attachments; remove either and it stops rendering (Docs).

### The curve

The beam is a cubic Bézier with four control points (Docs):

- **P0** = `Attachment0` world position.
- **P1** = P0 + `CurveSize0` studs along `Attachment0`'s **positive X** axis.
- **P2** = P3 - `CurveSize1` studs along `Attachment1`'s X axis (i.e. `CurveSize1` studs in its **negative X** direction).
- **P3** = `Attachment1` world position.

So the curve's shape comes from the **orientation** of the attachments as much as from the CurveSize numbers. Rotate an attachment and the bend changes. Both `CurveSize` values at 0 give a straight beam.

### Exact arcs

A cubic Bézier approximates a circular arc of angle θ when the handles are `k = 4/3 * tan(θ/4) * r` long. For a semicircle (θ = 180°) that is `k = 4/3 * r`, the number used by the studied slash packs (end attachments at ±r, `CurveSize0 = CurveSize1 = 1.333 * r`, handles both pointing toward the bulge). A full ring is two semicircle beams sharing the end attachments with the bulge on opposite sides.

### Width, segments, texture

| Property | Default (API dump) | Notes (Docs unless stated) |
|---|---|---|
| `Width0`, `Width1` | 1, 1 | Studs at each end, linear in between. Negative values are reset to 0. Width0 large and Width1 0 = a crescent or comet taper. |
| `Segments` | 10 | Straight pieces approximating the curve. More = smoother curve. Colour and transparency need at least n - 1 segments for n keypoints. Arcs in studied packs used 50 to 360. |
| `Texture` | none | If unset, invalid **or not loaded yet**, the beam draws as a **solid** colour ribbon. |
| `TextureMode` | `Stretch` | `Stretch`: texture repeats `TextureLength` times over the whole beam. `Wrap` and `Static`: repeats every `TextureLength` studs. |
| `TextureLength` | 1 | Meaning depends on mode (above). |
| `TextureSpeed` | 1 | Texture cycles per second, from Attachment0 toward Attachment1; negative reverses; 0 static. |
| `SetTextureOffset(o)` | | Sets the texture cycle position (0 to 1 wraps). Reset an animation to its start with 0. |
| `Color` | white | `ColorSequence` along the beam. |
| `Transparency` | 0.5 everywhere | `NumberSequence` along the beam. Note the default is half transparent. |
| `FaceCamera` | false | When true the ribbon always faces the camera. |
| `LightEmission` | 0 | 0 normal, 1 additive. Does not light the world. |
| `LightInfluence` | 0 | 0 to 1. Keep 0 for VFX. |
| `Brightness` | 1 | 0 to 10000; scales emitted light when LightInfluence is below 1. |
| `ZOffset` | 0 | Studs toward the camera; separates beams that share attachments to avoid z-fighting. |

### The "solid white bar" bug

Because an unloaded texture renders as a solid ribbon (Docs), the first time a slash plays with a never-seen texture, the player can see a flat coloured slab for a frame or more. This is worse for **freshly uploaded images**: the reference project found that new uploads fail `ContentProvider:PreloadAsync` for roughly 20 to 60 seconds after upload. Consequences:

- Preload every beam and trail texture when the effect's owner loads (when a weapon is equipped, not when it first swings).
- After uploading new textures, wait a minute before judging "it does not load", and do not ship a build that uses textures uploaded seconds earlier without a test.
- If you build the effect on the fly, keep `Transparency` at 1 until `PreloadAsync` reports success, then reveal.

### Texture orientation

How a texture maps onto the ribbon is a frequent source of confusion. The reference project recorded that the texture's Y axis runs along the beam and that the ribbon's width follows the attachments' orientation; it also saw faint hairlines at the joins where several beams meet. Do not author a sheet on faith: test with an asymmetric arrow texture first, and overlap beam ends slightly (or hide joins under a flash) when chaining.

`FaceCamera = true` sidesteps most width-orientation problems for VFX ribbons, which is why slash arcs in the studied packs use it. Use `FaceCamera = false` when the ribbon must lie on a surface (a force-field skin, a waterfall sheet, smoke dragging along the ground).

---

## 2. Slash crescents with beams

In the reference project, wide melee swings drew **crescents** instead of trails (see section 4 for why). A crescent is a semicircular beam in the swing's plane that appears on the hit and sweeps or fades within 0.18 to 0.3 s. Recipe from the studied packs:

- End attachments at ±r on the pivot's X axis, handles 4/3 r toward the bulge.
- Main beam `Width0 = 30`, `Width1 = 0` (crescent taper), `FaceCamera = true`, `Segments = 50` or more, `LightEmission = 1`.
- "Band" copies of the same beam with transparency opaque only over 35 to 70% of the length read as a travelling highlight streak.
- Sweep: rotate the pivot about 175 degrees (linear) over 0.18 to 0.25 s while widths shrink from about 3x to 0.
- 4 to 6 smaller filament arcs tilted 6 to 10 degrees and offset 1 to 2 studs add richness.
- Copy the impact stack to the far end of the arc with a 0.1 s delay so the hit "travels".

Attachments must be parented to a `BasePart` (or `Terrain`), not to other attachments, so the pivot is an invisible anchored part:

```lua
--!strict
-- CrescentBeam: a semicircular beam arc in the pivot's XZ plane, swept and shrunk over `life`.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local function makePivot(cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = "CrescentPivot"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = Workspace
	return p
end

-- Semicircle from +X to -X bulging toward +Z (local to the pivot).
local function makeArc(pivot: BasePart, radius: number, texture: string, color: Color3): Beam
	local a0 = Instance.new("Attachment")
	-- X axis of A0 points +Z: P1 = P0 + k * (+Z)
	a0.CFrame = CFrame.fromMatrix(Vector3.new(radius, 0, 0), Vector3.zAxis, Vector3.yAxis)
	a0.Parent = pivot

	local a1 = Instance.new("Attachment")
	-- X axis of A1 points -Z: P2 = P3 - k * (-Z) = P3 + k * (+Z)
	a1.CFrame = CFrame.fromMatrix(Vector3.new(-radius, 0, 0), -Vector3.zAxis, Vector3.yAxis)
	a1.Parent = pivot

	local k = 4 / 3 * radius -- exact cubic approximation of a semicircle
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.CurveSize0 = k
	beam.CurveSize1 = k
	beam.Segments = 60
	beam.FaceCamera = true
	beam.Texture = texture
	beam.TextureSpeed = 0
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Brightness = 2
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new(0)
	beam.Width0 = radius * 2
	beam.Width1 = 0
	beam.Parent = pivot
	return beam
end

-- Plays one crescent. `cf` sets the swing plane: its XZ plane is the plane of the arc.
local function playCrescent(cf: CFrame, radius: number, texture: string, color: Color3, life: number, sweepDeg: number)
	local pivot = makePivot(cf)
	local beam = makeArc(pivot, radius, texture, color)
	local startWidth = beam.Width0
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.PreRender:Connect(function()
		local a = math.clamp((os.clock() - t0) / life, 0, 1)
		pivot.CFrame = cf * CFrame.Angles(0, -math.rad(sweepDeg) * a, 0) -- linear sweep
		local fade = 1 - a
		beam.Width0 = startWidth * fade * fade -- ease-in shrink
		beam.Transparency = NumberSequence.new(a * a)
		if a >= 1 then
			conn:Disconnect()
			pivot:Destroy()
		end
	end)
end

return playCrescent
```

Use it on the client on the hit beat: `playCrescent(rootCFrame * CFrame.new(0, 1, -3), 12, "rbxassetid://0000000000", weaponColor, 0.22, 175)`. Pool the pivot and beam if you play many per second. Orient `cf` so its XZ plane matches the swing (tilt it for diagonals; flip it for the opposite direction).

Reference numbers: crescent radius about 15 studs at 1.6x character scale, one crescent shape per swing direction (horizontal each way, rising diagonal, a full ring for spin finishers), recoloured by the weapon's colour. Timing and placement on the hit are in [[VFX Timing with Animation]].

---

## 3. Other beam patterns

| Pattern | Construction |
|---|---|
| Laser | Straight beam, `Width` small, `TextureSpeed` 2 to 5 with a noise texture, `LightEmission 1`, a `PointLight` at the impact end |
| Lightning arc | Several straight beams between jittered attachments, re-jittered every 0.05 to 0.1 s; or scripted Neon segments (studied pack: 5 segments, ±3 stud jitter, width swell then pinch over 0.35 s, 10 ms between segments) |
| Tractor or guide line | Beam from player to target, `TextureMode = Wrap`, chevron texture, `TextureSpeed` positive toward the target. The reference project's tutorial guide used a gold sparkle beam from player to target |
| Spiral | Ring halves with attachments at different heights |
| Waterfall sheet | `FaceCamera = false`, wide beam down the fall, `TextureSpeed` scrolling the water texture; 2 overlapping layers at different speeds |
| Aura cage | Beams along a limb's box edges plus face "skins" flaring past the limb (studied aura pack) |
| Smoke drag | Beam with a smoke texture, `FaceCamera = false`, `TextureSpeed` 0.5, Brightness tweened up then down |

Animating beams: tween `Width0/Width1`, `Transparency` (build a new `NumberSequence` each step), `Brightness`, or the attachments. Sequences cannot be tweened by `TweenService` directly; drive them from a `RunService` loop or tween a `NumberValue` and rebuild the sequence on `Changed`.

---

## 4. Trail fundamentals

A trail records the positions of its two attachments every frame while `Enabled`, and connects each frame's pair to the previous one, filling the polygon (Docs).

| Property | Default (API dump) | Notes (Docs) |
|---|---|---|
| `Attachment0`, `Attachment1` | | Width is the distance between them. **Changing attachments while drawing removes all drawn segments.** |
| `Lifetime` | 2 | Seconds each segment lives; 0.01 to 20. Changing it applies to existing segments immediately (older ones vanish at once if past the new lifetime). |
| `WidthScale` | 1 | `NumberSequence` 0 to 1 over a segment's life, multiplying the attachment distance; the trail stays centred. A taper 1 to 0 is the classic sword trail. |
| `Color`, `Transparency` | white, 0.5 | Over segment lifetime. Changing `Color` recolours old segments too. |
| `MinLength` | 0.1 | No new segment until an attachment moves this far; the current segment's end follows instead. Affects only new segments. |
| `MaxLength` | 0 | 0 = no cap; otherwise oldest segments are erased past this length. |
| `TextureMode` | `Stretch` | `Stretch` stretches over the trail's lifetime and shrinks in when attachments stop; `Wrap` tiles by `TextureLength` studs; `Static` stays where drawn. |
| `FaceCamera`, `LightEmission`, `LightInfluence`, `Brightness` | false, 0, 0, 1 | As for beams. |
| `Enabled` | true | Setting false stops new segments; existing ones expire naturally. |
| `Clear()` | | Removes all segments now. To clear and stop, set `Enabled = false` at the same time. |

### The two trail bugs everyone hits

1. **The teleport streak.** A trail enabled after the blade moved draws a segment from where the blade was when the trail was last enabled to where it is now: a streak across the body. **Call `Clear()` immediately before enabling.**
2. **The wraparound sheet.** Trails left on through wind-up and follow-through draw a flat sheet under or around the character. The reference project first limited basic swings to a window (`hit - 0.12 s`, on for 0.24 s), then removed trails from basic swings entirely: the combo's arm sweeps carried the blade 150 to 350 degrees around the body, and even a 0.24 s window wrapped the character. **Trails suit arcs under about 120 degrees**; wider sweeps need a drawn crescent (section 2).

Also: a VFX runtime the reference project used never disables trails it turns on (`Enabled = true` only). If you mix such a runtime with your own windows, own the trail yourself.

### Trail windows from markers

```lua
--!strict
-- Turn a trail on for a window, cleanly. Call from a TrailOn marker or a scheduled beat.
local function trailWindow(trail: Trail, duration: number, token: {}, current: () -> {})
	trail:Clear() -- no streak from the last position
	trail.Enabled = true
	task.delay(duration, function()
		if current() == token then -- the move was not cancelled or replaced
			trail.Enabled = false -- existing segments fade out over Lifetime
		end
	end)
end
```

### Afterimages with trails

A studied pack built limb afterimages with four trails sharing one `Attachment0` (on the torso) and each `Attachment1` on a hand or foot: Lifetime 0.3, WidthScale 0.3 to 0, transparency 0.5, LightEmission 1, very low Brightness. Blade trails in the same pack: Lifetime 0.2, LightEmission 1.

### Trails on fast movers

- At low frame rates a trail is a few long straight segments; a fast spin looks polygonal. Short lifetimes (0.15 to 0.3 s) hide it.
- `MinLength` higher than the per-frame movement of a slow object stops trails flickering on idle jitter.
- Trails on projectiles: set `Lifetime` so the tail is 3 to 6 projectile lengths at its speed.

---

## 5. Performance and lifecycle

- Beams and trails are cheap per instance but overdraw like particles when wide and additive. Budgets from the reference project: about 140 beams per swing, 210 on a finisher, layered by distance and detail.
- Create on the client. Parent effect beams under the effect root so they die with it.
- A VFX runtime used in the reference project required beams to be **inside Workspace when emitted** or they would not animate. More generally: a beam whose attachments are not in Workspace does not render.
- Pool crescents and lasers; rebuilding attachments and beams per hit churns instances.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Solid coloured slab instead of the texture | Texture not loaded (or invalid id) | Preload; new uploads need about a minute. |
| Beam missing | One attachment missing, same attachment twice, or not in Workspace | Two distinct attachments in Workspace. |
| Gradient looks stepped | Too few segments for the keypoints | Segments at least keypoints - 1, more for curves. |
| Arc is lopsided | Handles not 4/3 r, or attachments not oriented toward the bulge | Use the arc construction above. |
| Ribbon invisible edge-on | `FaceCamera` false on a VFX ribbon | Turn on FaceCamera for camera-facing effects. |
| Streak across the body when a trail starts | Trail not cleared before enabling | `Clear()` then enable. |
| Sheet wrapped around the character | Trail on for a wide sweep or wind-up | Window it, or crescents for sweeps over about 120 degrees. |
| Trail vanishes when retargeted | Changing attachments clears segments | Keep attachments fixed; move them instead. |
| Trail lingers after ability | Only `Enabled = false` | Also `Clear()` if it must vanish now. |

## Checklist

- [ ] All beam and trail textures preloaded with the owning item.
- [ ] Arcs built with 4/3 r handles and enough segments.
- [ ] VFX ribbons at LightInfluence 0 with appropriate LightEmission.
- [ ] Trails cleared before every enable and windowed by markers.
- [ ] Wide sweeps drawn as crescents, not trails.
- [ ] Everything created on the client, pooled, and owned by an effect root.

See also: [[Particle Emitters In Depth]], [[VFX Design Playbook]], [[VFX Timing with Animation]], [[Weapon Swing Design]], [[Combat Animation Craft]], [[Textures Decals and Texture Memory]], [[Snippets - Camera Shake and FX]].

## Connected notes
<!-- auto-links:start -->
[[Links - Beams and trails]] · [[Mesh VFX Packs Built in Blender]] · [[Light Sources and Shadows]] · [[Dash VFX Presentation on an R15 Rig]] · [[Mover Constraints and Physics Controllers]] · [[Water Sky and Atmosphere Art]]
<!-- auto-links:end -->
