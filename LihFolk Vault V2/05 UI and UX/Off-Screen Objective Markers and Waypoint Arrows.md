---
tags: [ui, hud, waypoints, markers, objectives, camera, type/guide, area/ui, level/intermediate, api/WorldToViewportPoint, api/BillboardGui, api/ScreenGui]
---
# Off-Screen Objective Markers and Waypoint Arrows

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No flip for Z < 0 -> Mirror `dir` when depth is negative
> - Avoid: Wrong projection for the inset mode -> `WorldToViewportPoint` with `IgnoreGuiInset = true`...
> - Avoid: Clamping to the raw viewport -> Safe rect plus HUD exclusion zones
> - Projection call matches the ScreenGui's inset mode.
> - Behind-camera case flipped and tested by turning 180 degrees.
> - Clamp rectangle respects safe insets and HUD exclusion zones on phone.
>
> Cost: TL;DR ~150 tok · whole note ~2.3k tok. Read more: ## 2. The projection and the behind-camera flip · ## 6. Driving the markers · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Quest arrows, teammate pings, "deliver here" diamonds and boss indicators all solve the same problem: show where something is when it is on screen, and which way to turn when it is not. There are two building blocks, a `BillboardGui` in the world and a `ScreenGui` element positioned from the camera projection, and most good markers use the second for the off-screen case because a billboard cannot leave the screen edge. This note covers the projection maths (including the behind-the-camera flip that every first attempt gets wrong), edge clamping with safe areas, distance labels, occlusion and fading rules, and budgets. Marker *data* (which objectives exist) comes from [[Quests and Objectives]].

Source labels: **Roblox docs** (create.roblox.com, as of October 2026), **Rule of thumb**. Code is strict Luau, **reviewed, not run**.

---

## 1. BillboardGui or screen-space?

| | BillboardGui | Screen-space frame |
|---|---|---|
| On-screen marker | Easy: `Adornee` + `StudsOffsetWorldSpace`, `AlwaysOnTop = true` | Needs projection every frame |
| Off-screen arrow | Impossible: it just leaves the view | Natural: clamp to the edge |
| Scaling with distance | `Size` in offset keeps a constant pixel size; scale sizes shrink with distance | You control it |
| Hiding at range | `MaxDistance` (Roblox docs) | Your own check |
| Cost | Engine-handled | One `WorldToViewportPoint` per marker per frame (cheap) |

Rule of thumb: use a BillboardGui for world labels that only matter on screen (names, shop signs; see [[World-Space UI - BillboardGui and SurfaceGui]]) and a screen-space marker for anything the player must find.

## 2. The projection and the behind-camera flip

Roblox docs: `Camera:WorldToViewportPoint(worldPoint)` returns a `Vector3` (X, Y in pixels from the viewport's top-left, ignoring the GUI inset; Z is depth from the camera) and a boolean "on screen". `WorldToScreenPoint` is the same but accounts for the GUI inset. Pick the one that matches your ScreenGui: with `ScreenGui.IgnoreGuiInset = true`, use `WorldToViewportPoint`.

The trap: for a point **behind** the camera, Z is negative and X, Y are mirrored. Clamping that point to the edge puts the arrow on the opposite side. Flip it:

```lua
--!strict
-- Returns a screen position for the marker and whether it is clamped (off screen).
local function projectMarker(camera: Camera, world: Vector3, insetPx: number): (Vector2, boolean, number)
	local viewport = camera.ViewportSize
	local p, onScreen = camera:WorldToViewportPoint(world)
	local centre = viewport / 2
	local pos = Vector2.new(p.X, p.Y)

	if onScreen and p.Z > 0 then
		return pos, false, 0
	end

	local dir = pos - centre
	if p.Z < 0 then
		dir = -dir -- behind the camera: mirror back to the real side
	end
	if dir.Magnitude < 1e-3 then
		dir = Vector2.new(0, 1) -- directly behind: point down
	end

	-- Clamp to an inset rectangle around the centre.
	local halfW, halfH = centre.X - insetPx, centre.Y - insetPx
	local scale = math.min(halfW / math.abs(dir.X + 1e-6), halfH / math.abs(dir.Y + 1e-6))
	local clamped = centre + dir * scale
	local angle = math.deg(math.atan2(dir.Y, dir.X)) + 90 -- arrow art points up
	return clamped, true, angle
end
```

Use the angle to rotate the arrow child, not the whole marker, so the distance label stays upright.

Rectangle versus ellipse: rectangle clamping keeps arrows in the corners when the target is diagonal, which reads well on wide screens. An ellipse (normalise `dir` by `halfW`, `halfH`) keeps arrows away from corner UI. Pick based on where your HUD lives.

## 3. Safe areas and HUD collisions

- Clamp to the **safe** rectangle, not the raw viewport. Phones with notches and the top bar eat edges; read the inset from your safe-area layer (see [[Safe Areas and Insets]]; `ScreenGui.ScreenInsets` controls which insets a ScreenGui respects, Roblox docs).
- Leave a margin of at least the marker's own size plus 8 to 16 px (rule of thumb) so arrows do not overlap the edge.
- Reserve HUD zones: if the minimap is bottom-left and the jump button bottom-right on mobile, shrink the clamp rectangle or push clamped markers out of those boxes. A marker under the thumb is a marker nobody sees.

## 4. Distance labels and fading

- Distance from the **character**, not the camera; third-person camera distance makes numbers jump when zooming.
- Round sensibly: integer studs under 100, then steps of 10, or convert to metres if your game uses metres in UI (the Roblox docs units page gives 1 stud = 0.28 m, https://create.roblox.com/docs/physics/units; pick one value and use it everywhere). Update the text at 4 to 10 Hz even if the position updates every frame, or the digits blur.
- Fade or shrink when very close (under ~10 studs the marker covers the target), and hide entirely at the goal.
- Fade, do not pop, when a marker switches between on-screen and clamped.

## 5. Occlusion rules

Should a marker show through walls? Decide per type:

| Type | Through walls | Why |
|---|---|---|
| Quest objective, delivery point | Yes | Navigation is the point |
| Teammate | Yes, dimmed when occluded | Coordination |
| Enemy ping (from a teammate) | Yes, for a few seconds only | Callout, not wallhack |
| Enemy (no ping) | Never | That is ESP; and the data should not be on the client at all |

To dim when occluded, raycast from camera to target at 2 to 5 Hz per marker with a filter excluding characters (see [[Raycasts Shapecasts and Spatial Queries]]), and lerp transparency. Never raycast every frame for every marker.

## 6. Driving the markers

```lua
--!strict
-- Client: one RenderStepped loop for all markers, pooled frames.
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera

type Marker = { frame: Frame, arrow: ImageLabel, target: () -> Vector3? }
local active: { Marker } = {}

RunService:BindToRenderStep("ObjectiveMarkers", Enum.RenderPriority.Camera.Value + 1, function()
	for _, marker in active do
		local world = marker.target()
		if not world then
			marker.frame.Visible = false
			continue
		end
		local pos, clamped, angle = projectMarker(camera, world, 48)
		marker.frame.Visible = true
		marker.frame.Position = UDim2.fromOffset(pos.X, pos.Y)
		marker.arrow.Visible = clamped
		marker.arrow.Rotation = angle
	end
end)
```

Bind after the camera priority so markers use this frame's camera, not last frame's (otherwise they lag a frame behind fast turns). `target` is a function so markers can follow moving parts and tolerate a streamed-out instance by returning `nil`; for streamed worlds, send objective positions as `Vector3` values, not instance references ([[Instance Streaming]]).

Rule of thumb: cap active screen-space markers at about 8 to 12. Past that the screen is noise; prioritise by distance and objective importance.

---

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| No flip for Z < 0 | Arrow points the wrong way when target is behind | Mirror `dir` when depth is negative |
| Wrong projection for the inset mode | Markers offset vertically by the top bar height | `WorldToViewportPoint` with `IgnoreGuiInset = true`, `WorldToScreenPoint` otherwise |
| Clamping to the raw viewport | Arrows under the notch or the thumbstick | Safe rect plus HUD exclusion zones |
| Update in `Heartbeat` | Markers lag a frame on fast turns | `BindToRenderStep` after Camera |
| Rotating the whole marker | Distance text upside down | Rotate only the arrow child |
| Raycasting occlusion every frame | Client frame time spikes with many markers | 2 to 5 Hz per marker |
| Instance targets in streamed worlds | Marker vanishes when target streams out | Send positions, not instances |

## Checklist

- [ ] Projection call matches the ScreenGui's inset mode.
- [ ] Behind-camera case flipped and tested by turning 180 degrees.
- [ ] Clamp rectangle respects safe insets and HUD exclusion zones on phone.
- [ ] Distance from character, rounded, updated at a lower rate than position.
- [ ] Occlusion policy per marker type; no enemy data on the client.
- [ ] Marker frames pooled; active count capped.

## See also

[[HUD Design]] · [[World-Space UI - BillboardGui and SurfaceGui]] · [[Safe Areas and Insets]] · [[Quests and Objectives]] · [[Camera Systems]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[Instance Streaming]]

## Connected notes
<!-- auto-links:start -->
[[Quest Chain System End to End]] · Teaching Through Level Design · [[Responsive UI for Phone Tablet Console and PC]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Nametags and Overhead Bars - Cost and Visibility Rules]] · [[Tutorial Step Design Patterns - Teach by Doing]] · [[Race HUD - Position, Laps, Splits, Speedometer and Minimap]] · [[Touch Gestures - Pinch, Pan, Swipe and Long Press]] · [[ScreenGui Fundamentals]] · [[Layout - Scale Offset and Constraints]] · [[Menu Archetypes - Shop Settings Codes Rewards]] · [[Onboarding and FTUE - Tutorials That Keep Players]]
<!-- related:end -->
