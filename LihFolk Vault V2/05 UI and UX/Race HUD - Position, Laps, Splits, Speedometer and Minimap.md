---
tags: [ui, hud, racing, vehicles, speedometer, splits, minimap, type/guide, area/ui, level/intermediate, api/GetServerTimeNow, api/GetAttributeChangedSignal, api/RunService]
---
# Race HUD - Position, Laps, Splits, Speedometer and Minimap

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Server sends timer text every frame -> Local timer from server start time
> - Avoid: `os.clock()` for the race timer -> `workspace:GetServerTimeNow()`
> - Avoid: Client computes its own splits -> Server-sent split events
> - HUD reads server attributes; nothing per-frame comes from the server.
> - Timers computed from server time locally; monospaced digits.
> - Splits from a server event with signed deltas.
>
> Cost: TL;DR ~140 tok · whole note ~2.2k tok. Read more: ## 1. What the server sends, and how often · ## 5. Speedometer · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The race layer in [[Racing Laps and Checkpoints End to End]] already computes positions, laps, wrong-way and lap start times on the server and exposes them as player attributes (`RacePosition`, `RaceLap`, `RaceLapStartedAt`, `RaceWrongWay`, `BestLap`) plus `RaceState`/`RaceEndsAt` on `workspace`. This note is the presentation side: a HUD that reads those values without spamming the network, timers that tick locally from server time, split deltas players can trust, a speedometer that does not flicker, and a mini track map. General HUD rules are in [[HUD Design]]; projection maths for maps in [[Minimap and World Map UI - Projection, Rotation and Fog of War]].

Source labels: **Roblox docs** (create.roblox.com, checked October 2026), **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

---

## 1. What the server sends, and how often

| Element | Source | Update path |
|---|---|---|
| Position (3/8) | `RacePosition` attribute | Changes only when order changes |
| Lap (2/3) | `RaceLap` attribute | Once per lap |
| Lap timer | `RaceLapStartedAt` (server time) | Ticks **locally** from `workspace:GetServerTimeNow()` |
| Race countdown / DNF timer | `RaceEndsAt` on workspace | Ticks locally |
| Split delta | One reliable event per gate crossing | Per gate |
| Speed, RPM, gear | Local car (driver owns the physics) | Every frame, local only |
| Other racers on map | Replicated chassis positions | Read locally at 10 to 15 Hz |

Never replicate a running timer. `GetServerTimeNow()` is synchronised to the server clock (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/Workspace), so a timer computed as `GetServerTimeNow() - RaceLapStartedAt` on the client matches the server's recorded lap time to within clock sync error, which is exactly what the race note relies on.

## 2. Splits that match the server

The client cannot compute splits itself without duplicating gate logic, and if it did, its numbers would disagree with the server's interpolated crossing times. Have the server fire the driver a small reliable event on each gate crossing: `{ gate, lapTime, deltaToBest }`, where the server computes `deltaToBest` from the player's stored best-lap gate times. Show it for ~2.5 s:

- Negative delta: "-0.42" in the "good" colour; positive: "+0.31" in the "bad" colour.
- Always include the sign. Colour alone fails colour-blind players ([[Accessibility]]). Rule of thumb: green/red plus sign, or a blue/orange pair.
- On a lap with no best yet, show the raw sector time.

## 3. Timers without jitter

Proportional fonts make a running timer's width wobble every frame. Use a monospaced font for all numbers that change: `Enum.Font.RobotoMono` via `TextLabel.FontFace = Font.fromEnum(Enum.Font.RobotoMono)` (Roblox docs: https://create.roblox.com/docs/reference/engine/datatypes/Font). Format `m:ss.mmm` with `string.format("%d:%06.3f", minutes, seconds)`.

Update text at most every frame, and only when the displayed string changes. Setting `Text` to the same value is cheap but not free across many labels; caching the last string is one line.

## 4. Position display that does not flicker

Two cars nose to nose swap `RacePosition` several times a second. The server's ordering is correct, but the HUD looks broken. Debounce on the client: only show a new position if it has held for 0.3 s, except at the finish line where you show the server value immediately. Animate the change (a short scale punch on gain, a small drop on loss; see [[UI Motion Language and Timing]]). Show the ordinal suffix ("1st", "2nd", "3rd", "4th") through your localisation layer, not hard-coded English ([[Localization]]).

## 5. Speedometer

```lua
--!strict
local RunService = game:GetService("RunService")

local DISPLAY_SCALE = 1.0 -- studs/s -> display units; choose once, document it
local SMOOTH = 12         -- higher = snappier needle

local function bindSpeedo(chassis: BasePart, label: TextLabel, needle: GuiObject, maxDisplay: number)
	local shown = 0
	local lastText = ""
	return RunService.PreRender:Connect(function(dt: number)
		local v = chassis.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude * DISPLAY_SCALE
		shown += (speed - shown) * (1 - math.exp(-SMOOTH * dt)) -- frame-rate independent
		local text = tostring(math.floor(shown + 0.5))
		if text ~= lastText then
			label.Text = text
			lastText = text
		end
		needle.Rotation = -120 + 240 * math.clamp(shown / maxDisplay, 0, 1)
	end)
end
```

- Read speed on the driver's client: it owns the car, so its velocity is the freshest anywhere.
- Flatten to XZ, or the number jumps on every bump.
- **Units**: Roblox does not mandate a stud-to-metre conversion for game UI, and community conventions differ. Pick a `DISPLAY_SCALE` that makes your top speed read like a believable number, label it ("km/h" or just "SPD"), and use the same scale everywhere (HUD, leaderboards, shop stats). Rule of thumb.
- Gear and RPM come from the local engine model ([[Engine, Gearbox and Torque Curve Model for Arcade Cars]]). A shift light at 90% redline is the most useful single element for racing players.

## 6. Mini track map

For a closed circuit, a fixed track map beats a rotating minimap: players learn its shape.

1. Bake the track outline into an image (top-down render or a traced path) and record its world-space bounds (min X/Z, max X/Z) in a config.
2. Each dot: `u = (pos.X - minX) / (maxX - minX)`, `v = (pos.Z - minZ) / (maxZ - minZ)`, `dot.Position = UDim2.fromScale(u, v)`, `AnchorPoint = Vector2.new(0.5, 0.5)`. Watch the axis direction: decide which world axis is "up" on the map and flip `v` if needed.
3. Update dots for other racers at 10 to 15 Hz from their replicated chassis positions, and the local car every frame. Use `UIAspectRatioConstraint` so the map stays undistorted on phones ([[Layout - Scale Offset and Constraints]]).
4. Highlight the next gate and the leader. Hide racers who finished or DNF'd.

For open-world races, use the general minimap from the minimap note and draw the route as a polyline.

## 7. Layout by platform

- Phone: position and lap top-left, timer top-centre, speedometer above the throttle thumb area but never under it, map top-right, small. Respect safe areas ([[Safe Areas and Insets]]).
- Console: larger text at 10-foot distance; avoid the outer 5% edge ([[Gamepad and Console UX]]).
- Show the split and wrong-way warnings centre-screen, briefly, and big. They are the only things a racer reads mid-corner.
- Countdown: large, centre, rounding **up** so "1" is shown until GO, matching the server unanchor in the race note.

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Server sends timer text every frame | Bandwidth spike, choppy timer | Local timer from server start time |
| `os.clock()` for the race timer | HUD disagrees with saved lap times | `workspace:GetServerTimeNow()` |
| Client computes its own splits | Splits differ from leaderboard | Server-sent split events |
| Proportional font on timers | Digits wobble | RobotoMono `FontFace` |
| Raw speed on the needle | Needle jitters on bumps | XZ speed, exponential smoothing |
| Position updated instantly | Flicker in close racing | 0.3 s debounce except at finish |
| Colour-only splits | Unreadable for colour-blind players | Sign plus colour |

## Checklist

- [ ] HUD reads server attributes; nothing per-frame comes from the server.
- [ ] Timers computed from server time locally; monospaced digits.
- [ ] Splits from a server event with signed deltas.
- [ ] Position debounced, animated, localised.
- [ ] Speedometer smoothed, unit scale documented and reused.
- [ ] Track map from baked bounds; other racers at 10-15 Hz.
- [ ] Layout checked on phone, console and PC.

## See also

[[Racing Laps and Checkpoints End to End]] · [[HUD Design]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[Responsive UI for Phone Tablet Console and PC]] · [[Text Fonts and Rich Text]] · [[Genre Playbook - Racing and Driving]] · [[UI Motion Language and Timing]]

## Connected notes
<!-- auto-links:start -->
[[Engine, Gearbox and Torque Curve Model for Arcade Cars]] · [[Safe Areas and Insets]] · [[Accessibility]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Off-Screen Objective Markers and Waypoint Arrows]] · [[Notification and Toast Systems]] · [[UI Design Systems]] · [[Touch Gestures - Pinch, Pan, Swipe and Long Press]] · [[World-Space UI - BillboardGui and SurfaceGui]] · [[ScreenGui Fundamentals]] · [[Virtualized Lists and Large Inventories]] · [[Drag-and-Drop Inventories and Sliders with UIDragDetector]]
<!-- related:end -->
