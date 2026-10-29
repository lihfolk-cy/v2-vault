---
tags: [vfx, telegraph, aoe, ground-warning, boss, readability, fairness, handleadornment, lihfolk, type/guide, area/vfx, level/intermediate, area/gameplay]
---
# AoE Telegraphs - Readable Ground Warnings

<!-- tldr:start -->
> [!tldr] TL;DR
> - Warning vanishes on bright floors: Only a bright rim -> Dark outline under the shape
> - Warning vanishes on dark floors: Only a dark outline -> Bright rim inside the edge
> - Players "dodged but got hit": Pop and damage on different frames, or different shape numbers -> One shared shape table; damage at the pop
> - Four layers: dark outline, base fill, progress fill with a hot edge, bright rim.
> - Duration covers 0.25 s reaction plus escape at walk speed; longer for bosses and touch.
> - Fill eases in; pop flashes on the damage frame and fades in about 0.22 s.
>
> Cost: TL;DR ~180 tok · whole note ~2.6k tok. Read more: ## 3. Shapes from HandleAdornments · ## 5. The server test matches the drawing · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A telegraph is gameplay information drawn as an effect: **where** the attack lands (shape), **when** it lands (fill), and **whose** it is (colour). Players dodge what they can read, so a telegraph earns its keep by reading the same on a white marble floor, a black cave floor and a slope, on a phone at game distance. This note covers the layer stack, timing numbers, shapes built from HandleAdornments, ground placement and the matching server test. The shared visual language comes from [[VFX Design Playbook]] (section 4), boss pacing from [[Boss Animation and Phases]], enemy roles from [[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]], and the "simplify, never skip" rule from [[VFX Performance Budgets and Culling]]. The LihFolk VFX skill ships it as `Telegraph(cf, shape, opts)` in `LihFolkVFX_Abilities.luau`.

Source labels: **Roblox docs**, **LihFolk module** (shipped values, untested in Studio at the time of writing), **rule of thumb**.

---

## 1. Four layers, bottom to top

| Layer | Numbers (LihFolk module) | Reads on |
|---|---|---|
| Dark outline | 0.32 studs wider than the shape, element dark colour, transparency 0.2 | bright floors (sand, snow, marble) |
| Base fill | the full shape, element body colour, transparency 0.78 | everything: shows the whole area at once |
| Progress fill + leading edge | grows from the origin over the duration, transparency 0.45; a 0.22-stud hot edge rides its front at 0.15 | everything: shows time left |
| Bright rim | 0.16 studs inside the edge, body colour 45 percent toward white, transparency 0.05 | dark floors (caves, night, lava rock) |

Two edges are the point: on a pale floor the rim fades into the ground and the dark outline carries the border; on a dark floor the outline vanishes and the rim carries it. Every floor gets one strong edge. Keep the fills translucent so players still see the ground (and any second telegraph) underneath.

## 2. Timing

The fill duration has to cover reaction plus escape. Reaction to a visual cue is about 0.25 s for an alert player (**rule of thumb**); the default walk speed is 16 studs/s (**Roblox docs**, `Humanoid.WalkSpeed`). Escaping from the centre of a circle of radius `r` takes `r / 16` seconds.

| Shape and size | Escape at 16 studs/s | Minimum fair duration | Comfortable |
|---|---|---|---|
| Circle r = 6 | 0.38 s | 0.65 s | 0.8-1.0 s |
| Circle r = 10 | 0.63 s | 0.9 s | 1.1-1.4 s |
| Cone r = 14, 60 deg (step sideways ~4 studs) | 0.25 s | 0.5 s | 0.7-0.9 s |
| Line 24 x 4 (step sideways 2-3 studs) | 0.19 s | 0.45 s | 0.6-0.8 s |
| Boss ultimate, r = 20 | 1.25 s | 1.5 s | 2.0-2.5 s |

Add 0.1-0.2 s on mobile-heavy games (touch movement starts slower, **rule of thumb**).

- **Ease the fill in** (exponent about 1.3): the last third moves fastest, which reads as urgency without changing the total time.
- **Pop exactly at the damage frame.** The fill flashes toward white and everything fades in about 0.22 s. A pop that lands before or after the damage teaches players to distrust the fill.
- **Fade in over about 0.08 s**, not instantly: a hard pop-in on the first frame looks like a glitch.

## 3. Shapes from HandleAdornments

HandleAdornments draw flat unlit colour, need no texture upload, never collide and render the same under any lighting, which suits gameplay information. `CylinderHandleAdornment` has `Radius`, `InnerRadius` (rings) and `Angle` (sectors); `BoxHandleAdornment` has `Size` (lines). They draw along their own Z axis, so a flat disc on the floor is rotated 90 degrees about X.

```lua
--!strict
-- A flat ring (or disc when width is nil) lying on `anchor`'s top plane.
local FLAT = CFrame.Angles(math.rad(90), 0, 0)

local function flatRing(anchor: BasePart, radius: number, width: number?, color: Color3, transparency: number): CylinderHandleAdornment
	local a = Instance.new("CylinderHandleAdornment")
	a.Adornee = anchor
	a.CFrame = FLAT
	a.Height = 0.03
	a.Radius = radius
	a.InnerRadius = if width then math.max(0, radius - width) else 0
	a.Color3 = color
	a.Transparency = transparency
	a.AlwaysOnTop = false -- walls and players still hide it
	a.Parent = anchor
	return a
end

return flatRing
```

- **Circle:** outline disc, base disc, progress disc (`Radius` grows), edge ring, rim ring.
- **Cone:** the same pieces with `Angle` set, plus two thin boxes for the straight sides of the rim. The sector's start direction needs one check in Studio; the LihFolk module exposes `Config.coneSectorOffset` for it. Push the dark outline sector back along the axis by `outline / sin(angle / 2)` so its straight sides show as well as its arc.
- **Line:** boxes. The progress box grows in length from the start point; the rim is two side boxes and one end box (a rim box under a translucent fill would tint the whole area).
- **Stack heights:** lift each layer about 0.012 studs above the last so nothing z-fights; `AlwaysOnTop` stays false so walls hide telegraphs behind them.

Parts with Neon or Decals also work. Neon blooms (nice at night, washed out at noon) and Decals need an uploaded texture; adornments read the same everywhere, which is the property a warning needs.

## 4. Placing it on the ground

1. Raycast down from 3 studs above the requested point, about 40 studs long, excluding characters and effect folders.
2. Build the frame from the hit normal (Y = normal, forward projected onto the surface), so the warning follows ramps.
3. Lift it about 0.04 studs along the normal.
4. On uneven ground with a radius above about 12 studs, sample 4-5 points and lift to the highest, or raise the whole telegraph to 0.15 studs (**rule of thumb**): a big flat disc on bumpy terrain disappears into the bumps.

## 5. The server test matches the drawing

Damage uses the same shape maths at the pop time, in the same frame the client drew. Keep the shape numbers in one shared table so the art and the hit test never drift apart.

```lua
--!strict
-- Is `point` inside a telegraph? `cf` = centre (circle), apex (cone) or start (line), flat on the floor.
export type Shape = { kind: string, radius: number?, angle: number?, length: number?, width: number? }

local function inside(cf: CFrame, shape: Shape, point: Vector3): boolean
	local p = cf:PointToObjectSpace(point)
	local flat = Vector3.new(p.X, 0, p.Z)
	if math.abs(p.Y) > 6 then
		return false -- far above or below the floor
	end
	if shape.kind == "circle" then
		return flat.Magnitude <= (shape.radius or 8)
	elseif shape.kind == "cone" then
		local d = flat.Magnitude
		if d > (shape.radius or 12) then
			return false
		elseif d < 1e-3 then
			return true -- at the apex
		end
		local half = math.rad((shape.angle or 60) * 0.5)
		return math.acos(math.clamp(-flat.Unit.Z, -1, 1)) <= half
	elseif shape.kind == "line" then
		local len, w = shape.length or 20, shape.width or 4
		return -p.Z >= 0 and -p.Z <= len and math.abs(p.X) <= w * 0.5
	end
	return false
end

return inside
```

Test against the character's root position plus a small margin (0.5-1 stud) in the player's favour: a hit that "clearly missed" on screen costs more trust than a lucky dodge.

## 6. Networking and late arrivals

- **The server starts the telegraph** with one payload: shape id, CFrame, element index, and the server time it began (`Workspace:GetServerTimeNow()`). See [[Replicating VFX - Server Validates, Clients Render]].
- **A client that receives it late fills only the remainder**: `duration - (GetServerTimeNow() - startedAt)`. If that is under about 0.15 s, draw the pop alone; a warning that arrives after the hit is noise. The LihFolk module takes this as `opts.elapsed` (seconds already gone); add the start time to your payload when telegraphs are long enough for it to matter.
- **Never culled.** Telegraphs are important by default in the LihFolk module: no distance cull, no live-cap skip. On low quality they lose nothing here, because they have no particles.

## 7. Colour language

- **One hue family for enemy danger** (warm red to orange) across the whole game, one for friendly areas (teal or blue), one for heals (green). Players learn it once.
- **Shape and motion carry the meaning, hue supports it.** The outline, rim and filling motion read without colour, which keeps colour-blind players covered ([[Accessibility Contrast]]).
- **Severity by size and duration, not by new colours.** A boss ultimate is a bigger circle with a longer fill and a stronger pop, in the same palette.

---

## Common mistakes

| Symptom | Likely cause | Fix |
|---|---|---|
| Warning vanishes on bright floors | Only a bright rim | Dark outline under the shape |
| Warning vanishes on dark floors | Only a dark outline | Bright rim inside the edge |
| Players "dodged but got hit" | Pop and damage on different frames, or different shape numbers | One shared shape table; damage at the pop |
| Telegraph flickers on the floor | Layers at the same height | Stack each layer about 0.012 studs higher |
| Disappears into terrain | Flat disc on bumpy ground | Sample several points, lift to the highest |
| Visible through walls | `AlwaysOnTop` on | `AlwaysOnTop` false |
| Late joiners see a full-length fill | Duration not adjusted by server time | Fill the remainder from `GetServerTimeNow()` |
| Missing on phones | Telegraph treated as decoration | Gameplay effects are never culled |

## Checklist

- [ ] Four layers: dark outline, base fill, progress fill with a hot edge, bright rim.
- [ ] Duration covers 0.25 s reaction plus escape at walk speed; longer for bosses and touch.
- [ ] Fill eases in; pop flashes on the damage frame and fades in about 0.22 s.
- [ ] Raycast to the floor and align to its normal; lift 0.04 studs; layers stacked without z-fighting.
- [ ] Server hit test uses the same shape numbers, with a small margin for the player.
- [ ] Late arrivals fill only the remaining time.
- [ ] One danger palette for the whole game; meaning carried by shape and motion.
- [ ] Never culled for performance.

<!-- related:start -->
## Related
[[Auras, Shields and Status Effects]] · [[Projectile VFX - Muzzle, Travel and Impact]] · [[VFX Readability and Value - Lessons from Blind Reviews]] · [[Highlights and Selection Effects]] · [[Slash VFX Recipes - Crescent and Ring]] · [[Light Sources and Shadows]] · [[Escalation and Grandeur Without Clutter]] · [[Designing VFX Textures and Flipbooks in Figma]]
<!-- related:end -->
