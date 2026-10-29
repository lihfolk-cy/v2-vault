---
tags: [ui, input, touch, mobile, gestures, pinch, pan, swipe, long-press, maps, type/guide, area/ui, level/advanced, api/UserInputService, api/GuiObject]
---
# Touch Gestures - Pinch, Pan, Swipe and Long Press

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Applying cumulative pinch scale each frame -> Store at Begin, apply ratio or delta
> - Avoid: World gestures with default camera active -> Custom camera or processed touches in the mode
> - Avoid: Fixed pixel thresholds -> Scale by screen size
> - Each touch feature chooses GuiObject events, UIS events or the custom recogniser deliberately.
> - Gestures in a mode do not conflict with camera and thumbstick.
> - Pinch zoom anchors around the pinch centre; pan has inertia where it fits.
>
> Cost: TL;DR ~160 tok · whole note ~2.5k tok. Read more: ## 1. The built-in gesture events · ## 2. Your own recogniser from raw touches · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most Roblox players are on phones, yet most games treat touch as "a mouse with a fat cursor". Maps that cannot be pinch-zoomed, inventories without long-press details, and build modes where dragging rotates the camera instead of moving the object are the result. Roblox gives you two layers: built-in gesture events (on `UserInputService` and on each `GuiObject`) and raw touch `InputObject`s. This note explains when each works, a small recogniser you control, how to coexist with the default camera and thumbstick, and per-feature recipes (world map, top-down camera, inventory, build mode). The input basics are in [[Input - UserInputService and ContextActionService]].

Source labels: **Roblox docs**, **Rule of thumb**, **Unverified**.

---

## 1. The built-in gesture events

| Event | Where | Signature (summary) |
|---|---|---|
| `TouchTap` | `UserInputService`, `GuiObject` | positions, processed flag |
| `TouchLongPress` | both | positions, `UserInputState`, processed |
| `TouchPan` | both | positions, total translation, velocity, state, processed |
| `TouchPinch` | both | positions, scale (relative to start), velocity, state, processed |
| `TouchRotate` | both | positions, rotation (degrees from start), velocity, state, processed |
| `TouchSwipe` | both | direction (`Enum.SwipeDirection`), touch count, processed |

References (**Roblox docs**): https://create.roblox.com/docs/reference/engine/classes/UserInputService, https://create.roblox.com/docs/reference/engine/classes/GuiObject.

Key behaviours:
- The `GuiObject` versions fire only for touches that **started on that object**: perfect for a map frame or an inventory slot, and they do not leak to the world.
- The `UserInputService` versions fire for the whole screen, including touches that the default camera and thumbstick are also using; check `gameProcessedEvent` and your own UI state before acting.
- `TouchPinch.scale` and `TouchPan.totalTranslation` are **cumulative since the gesture began**. Store the value at `Begin` and apply deltas, or zoom compounds.
- Gestures are recognised by the engine with its own thresholds; you cannot tune when a pan becomes a swipe or how long a long press takes. If you need control, use the recogniser below.

## 2. Your own recogniser from raw touches

Raw touches arrive as `InputObject`s with `UserInputType.Touch` through `InputBegan`, `InputChanged`, `InputEnded` (and `TouchStarted`/`TouchMoved`/`TouchEnded`). Each finger keeps the same `InputObject` for its lifetime, so you can key a table by it.

```lua
--!strict
local UserInputService = game:GetService("UserInputService")

type Finger = { start: Vector2, pos: Vector2, t0: number }
local fingers: { [InputObject]: Finger } = {}

local LONG_PRESS = 0.45   -- seconds
local TAP_SLOP = 12       -- pixels
local SWIPE_MIN = 80      -- pixels
local SWIPE_MAX_TIME = 0.3

export type Handlers = {
	onTap: (Vector2) -> (),
	onLongPress: (Vector2) -> (),
	onPan: (delta: Vector2) -> (),
	onPinch: (factor: number, center: Vector2) -> (),
	onSwipe: (dir: Vector2) -> (),
}

local function count(): number
	local n = 0
	for _ in fingers do n += 1 end
	return n
end

local function twoFingers(): (Finger?, Finger?)
	local a, b
	for _, f in fingers do
		if not a then a = f elseif not b then b = f end
	end
	return a, b
end

local function bind(isInZone: (Vector2) -> boolean, h: Handlers)
	local lastPinchDist: number? = nil
	local longPressFired: { [InputObject]: boolean } = {}

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Touch or processed then return end
		local p = Vector2.new(input.Position.X, input.Position.Y)
		if not isInZone(p) then return end
		fingers[input] = { start = p, pos = p, t0 = os.clock() }
		lastPinchDist = nil
		task.delay(LONG_PRESS, function()
			local f = fingers[input]
			if f and count() == 1 and (f.pos - f.start).Magnitude < TAP_SLOP then
				longPressFired[input] = true
				h.onLongPress(f.pos)
			end
		end)
	end)

	UserInputService.InputChanged:Connect(function(input)
		local f = fingers[input]
		if not f then return end
		local p = Vector2.new(input.Position.X, input.Position.Y)
		local delta = p - f.pos
		f.pos = p
		if count() == 1 then
			if (f.pos - f.start).Magnitude >= TAP_SLOP then h.onPan(delta) end
		else
			local a, b = twoFingers()
			if a and b then
				local d = (a.pos - b.pos).Magnitude
				if lastPinchDist and lastPinchDist > 0 then
					h.onPinch(d / lastPinchDist, (a.pos + b.pos) / 2)
				end
				lastPinchDist = d
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		local f = fingers[input]
		if not f then return end
		fingers[input] = nil
		lastPinchDist = nil
		if longPressFired[input] then longPressFired[input] = nil return end
		local moved = f.pos - f.start
		local dt = os.clock() - f.t0
		if moved.Magnitude < TAP_SLOP and dt < LONG_PRESS then
			h.onTap(f.pos)
		elseif moved.Magnitude >= SWIPE_MIN and dt <= SWIPE_MAX_TIME then
			h.onSwipe(moved.Unit)
		end
	end)
end

return bind
```

Thresholds are in pixels; scale them by screen density if you target tablets and phones equally (a fraction of the shorter screen side works well: `TAP_SLOP = 0.02 * minSide`). **Rule of thumb** values: tap slop 8 to 16 px, long press 0.4 to 0.6 s, swipe at least 60 to 100 px in under 0.3 s.

`input.Position` for touches is in screen pixels with the top bar inset applied the same way as other GUI input; compare against `AbsolutePosition` of frames from the same coordinate space ([[Safe Areas and Insets]]).

## 3. Coexisting with the default camera and controls

- On phones the default control scheme puts a **thumbstick** (or dynamic thumbstick) on the left part of the screen and uses drags elsewhere for camera rotation and two-finger pinch for zoom. Your world-space gestures will fight it.
- For gestures in a **GUI region** (map, inventory), use `GuiObject` events or set `Active = true` on the frame so touches on it are marked processed and the camera ignores them.
- For **world gestures** (top-down strategy camera, build mode), switch to a custom camera (`Scriptable`) while the mode is active and disable default movement controls with your controls module, or bind gestures through `ContextActionService` with a higher priority. Restore on exit ([[Camera Systems]]).
- Never bind two different meanings to the same gesture in the same context (pan moves the map **and** rotates the camera).

**Unverified:** newer releases added APIs that report the player's current preferred input type; prefer them over `TouchEnabled` checks where available, because many devices have both touch and a keyboard.

## 4. Recipes

| Feature | Gestures | Notes |
|---|---|---|
| World map / minimap expanded | Pan to move, pinch to zoom around the pinch centre, double-tap to recentre | Zoom around the centre point: adjust offset so the point under the fingers stays put |
| Top-down camera | One-finger pan to move, pinch zoom, two-finger rotate | Inertia after pan release (decay velocity) feels native |
| Inventory | Tap to select, long press for details, drag to move | Long-press tooltip doubles as hover replacement ([[Drag-and-Drop Inventories and Sliders with UIDragDetector]]) |
| Build mode | One-finger drag moves the ghost object, two-finger rotates it, tap places, explicit confirm button | Never place on tap alone on touch; accidental placements are the top complaint |
| Card or menu pages | Horizontal swipe to change page | Also show arrows; swipes are not discoverable |

## 5. Accessibility and discoverability

- Every gesture needs a **visible alternative** (buttons for zoom, rotate, next page). Gestures are shortcuts, not the only path ([[Accessibility]]).
- Hint on first use (a small animated hand), then never again (flag in the profile).
- Respect left-handed layouts if your HUD supports mirroring.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Applying cumulative pinch scale each frame | Zoom explodes | Store at Begin, apply ratio or delta |
| World gestures with default camera active | Map pans and camera spins together | Custom camera or processed touches in the mode |
| Fixed pixel thresholds | Different feel per device | Scale by screen size |
| Tap to place in build mode | Accidental placements | Confirm button |
| Gestures without buttons | Features undiscoverable | Visible alternatives and first-use hints |
| `TouchEnabled` as "is phone" | Wrong UI on touch laptops | Detect last input type |

## Checklist
- [ ] Each touch feature chooses GuiObject events, UIS events or the custom recogniser deliberately.
- [ ] Gestures in a mode do not conflict with camera and thumbstick.
- [ ] Pinch zoom anchors around the pinch centre; pan has inertia where it fits.
- [ ] Thresholds scale with screen size.
- [ ] Every gesture has a button alternative and a one-time hint.
- [ ] Tested on a small phone, a large phone and a tablet.

## See also
[[Input - UserInputService and ContextActionService]] · [[Responsive UI for Phone Tablet Console and PC]] · [[Safe Areas and Insets]] · [[Case Study - Phone UI Overhaul]] · [[Camera Systems]] · [[Debugging UI Layout and Input]]

## Connected notes
<!-- auto-links:start -->
[[Drag-and-Drop Inventories and Sliders with UIDragDetector]] · [[Grid Placement and Player Building Systems]] · AI Pitfalls - UI and Input
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Gamepad and Console UX]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[HUD Design]] · [[Off-Screen Objective Markers and Waypoint Arrows]] · [[ScreenGui Fundamentals]] · [[Layout - Scale Offset and Constraints]] · [[UI Layout Objects - Lists Grids and Pages]] · [[Race HUD - Position, Laps, Splits, Speedometer and Minimap]]
<!-- related:end -->
