---
tags: [ui, drag-and-drop, uidragdetector, inventory, sliders, reordering, input, mobile, gamepad, type/guide, area/ui, level/advanced, api/UIDragDetector, api/PlayerGui]
---
# Drag-and-Drop Inventories and Sliders with UIDragDetector

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Dragging a child of a layout -> Custom response style plus ghost
> - Avoid: Snapping after release -> Constraint function during drag
> - Avoid: Ghost in the same clipped frame -> Top-level drag layer
> - Sliders use `TranslateLine` with bounds, constraint-based snapping and keyboard/gamepad steps.
> - Slot drags use custom response, a top-level ghost and `GetGuiObjectsAtPosition`.
> - Moves are server-validated intents; locked items disable their detectors.
>
> Cost: TL;DR ~160 tok · whole note ~2.5k tok. Read more: ## 2. Pattern: a slider · ## 3. Pattern: drag-and-drop between slots · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Before `UIDragDetector`, every drag in Roblox UI was hand-rolled from `InputBegan`/`InputChanged`, with separate code for mouse and touch and usually no gamepad support at all. `UIDragDetector` is an instance you parent to a `GuiObject` to make it draggable, with built-in styles (move in a plane, along a line, rotate), bounds, constraint callbacks and events. This note covers the API at the level you need, three patterns (slider, drag-and-drop between slots, list reordering), the server side of inventory moves, and the traps with layouts and scaling. Inventory data and virtualised grids are in [[Saved Inventory End to End]] and [[Virtualized Lists and Large Inventories]].

Source labels: **Roblox docs** (reference: https://create.roblox.com/docs/reference/engine/classes/UIDragDetector and the UI drag detectors guide at https://create.roblox.com/docs/ui/ui-drag-detectors), **Rule of thumb**. The class is relatively new; check the reference for members added since this was written.

---

## 1. The parts of the API you will use

| Member | Purpose |
|---|---|
| `DragStyle` | `TranslatePlane` (free move), `TranslateLine` (along `DragAxis`), `Rotate`, or `Scriptable` (you compute the result) |
| `ResponseStyle` | `Offset` / `Scale`: the detector moves the object itself. `CustomOffset` / `CustomScale`: it computes the drag but leaves the object alone, so you decide what moves |
| `BoundingUI` | A GuiObject the drag is confined to (a slider track, an inventory panel) |
| `DragAxis` | Direction for `TranslateLine` |
| `DragUDim2`, `DragRotation` | Current drag result; read these in custom response styles |
| `DragStart`, `DragContinue`, `DragEnd` | Events with the input position |
| `AddConstraintFunction(priority, fn)` | Adjust the proposed position/rotation every frame (snapping, clamping) |
| `SetDragStyleFunction(fn)` | Full control for `Scriptable` style |
| `Enabled` | Turn dragging on and off (locked items, during trades) |

Mouse and touch work automatically. Gamepad users can drag through selection-based input when the object is selectable; test it rather than assuming ([[Gamepad and Console UX]]).

## 2. Pattern: a slider

```lua
--!strict
local function makeSlider(track: Frame, knob: GuiButton, onChanged: (number) -> ()): UIDragDetector
	local det = Instance.new("UIDragDetector")
	det.DragStyle = Enum.UIDragDetectorDragStyle.TranslateLine
	det.DragAxis = Vector2.new(1, 0)
	det.ResponseStyle = Enum.UIDragDetectorResponseStyle.Scale
	det.BoundingUI = track
	det.Parent = knob

	local function value(): number
		local w = track.AbsoluteSize.X - knob.AbsoluteSize.X
		if w <= 0 then return 0 end
		return math.clamp((knob.AbsolutePosition.X - track.AbsolutePosition.X) / w, 0, 1)
	end
	det.DragContinue:Connect(function() onChanged(value()) end)
	det.DragEnd:Connect(function() onChanged(value()) end)
	return det
end
```

- Use `Scale` response so the knob stays in place relative to the track when the screen resizes.
- **Snapping** (volume in steps of 5, a quantity picker) belongs in a constraint function that rounds the proposed X before it is applied; reading the value and snapping afterwards makes the knob jump on release.
- Let players **tap the track** to jump the knob, and support left/right on gamepad and keyboard for the focused slider. A slider that only drags fails accessibility ([[Accessibility]]).
- Settings sliders change client settings; quantity sliders in shops only choose a number, and the server still validates the purchase ([[Menu Archetypes - Shop Settings Codes Rewards]]).

## 3. Pattern: drag-and-drop between slots

Do **not** drag the slot itself. Slots live in a `UIGridLayout` or `UIListLayout`, and layouts reposition children every time anything changes, which fights the detector and snaps the item back. Instead:

1. Put the detector on the slot with `ResponseStyle = CustomOffset`, so the slot never moves.
2. On `DragStart`, create a **ghost** (a copy of the icon) in a top-level `ScreenGui` with high `DisplayOrder`, and dim the source slot.
3. On `DragContinue`, move the ghost to the input position.
4. On `DragEnd`, find what is under the pointer with `PlayerGui:GetGuiObjectsAtPosition(x, y)` (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/BasePlayerGui#GetGuiObjectsAtPosition), pick the first object with a `SlotId` attribute, destroy the ghost, restore the slot.
5. Send `MoveItem(fromSlot, toSlot)` to the server; update the UI optimistically or wait for the server's inventory update.

```lua
--!strict
local Players = game:GetService("Players")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
local dragLayer = playerGui:WaitForChild("DragLayer") :: ScreenGui

local function makeDraggableSlot(slot: GuiObject, icon: ImageLabel, onDrop: (fromId: string, toId: string) -> ())
	local det = Instance.new("UIDragDetector")
	det.ResponseStyle = Enum.UIDragDetectorResponseStyle.CustomOffset
	det.Parent = slot
	local ghost: ImageLabel? = nil

	det.DragStart:Connect(function(pos: Vector2)
		local g = icon:Clone()
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Size = UDim2.fromOffset(icon.AbsoluteSize.X, icon.AbsoluteSize.Y)
		g.Position = UDim2.fromOffset(pos.X, pos.Y)
		g.Parent = dragLayer
		ghost = g
		icon.ImageTransparency = 0.6
	end)
	det.DragContinue:Connect(function(pos: Vector2)
		if ghost then ghost.Position = UDim2.fromOffset(pos.X, pos.Y) end
	end)
	det.DragEnd:Connect(function(pos: Vector2)
		if ghost then ghost:Destroy() ghost = nil end
		icon.ImageTransparency = 0
		for _, obj in playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
			local target = obj:GetAttribute("SlotId")
			local from = slot:GetAttribute("SlotId")
			if typeof(target) == "string" and typeof(from) == "string" and target ~= from then
				onDrop(from, target)
				return
			end
		end
	end)
end
```

Check whether the input positions you receive include the top bar inset for your `ScreenGui` setup (`IgnoreGuiInset`), and make the drag layer use the same setting as the inventory so the ghost lines up with the finger ([[Safe Areas and Insets]]).

### Server side
- `MoveItem(from, to)` is an intent. Validate slot ids exist, the item is in `from`, the move is legal (equipment slot accepts that type), the item is not locked by an active trade, and rate-limit ([[Server Authority and Validation]], [[Trading Systems Without Duplication]]).
- Swap or merge stacks on the server; send back the new inventory state or a delta.
- Dropping outside any slot: either cancel (safest) or "drop to world", which must go through the server's drop flow with its own checks.

## 4. Pattern: reordering a list

- Same ghost approach. While dragging, compute the insertion index from the pointer's Y against the slots' `AbsolutePosition`, and show a placeholder gap by changing `LayoutOrder` of a spacer frame.
- On drop, set the dragged entry's `LayoutOrder` and renumber; persist the order if it matters (hotbar order) through a validated remote.
- For long lists, auto-scroll the `ScrollingFrame` when the ghost is near the top or bottom edge (a few pixels per frame scaled by distance into the edge zone).

## 5. Touch and feel

- On touch, start drags only after a short hold (150 to 250 ms) in scrolling inventories, or every scroll attempt picks up an item. Implement by enabling the detector after a long-press, or by using a drag handle ([[Touch Gestures - Pinch, Pan, Swipe and Long Press]]).
- Ghosts slightly larger (1.1x) and offset above the finger so the finger does not hide the item.
- Haptics and a short sound on pick-up and drop help a lot on phones ([[Feedback Timing - Sound Visual and Haptic Sync]]).
- Always offer a non-drag path: tap item, tap destination; or a context menu with "Equip", "Move to".

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Dragging a child of a layout | Item snaps back or jitters | Custom response style plus ghost |
| Snapping after release | Knob jumps | Constraint function during drag |
| Ghost in the same clipped frame | Ghost cut off at panel edges | Top-level drag layer |
| Client moves items without server | Desync and dupes | Intent remote, server validates and replies |
| Immediate drag on touch in scroll views | Cannot scroll inventory | Hold-to-drag or handles |
| Drag as the only way | Gamepad and accessibility failures | Tap-to-move alternative |

## Checklist
- [ ] Sliders use `TranslateLine` with bounds, constraint-based snapping and keyboard/gamepad steps.
- [ ] Slot drags use custom response, a top-level ghost and `GetGuiObjectsAtPosition`.
- [ ] Moves are server-validated intents; locked items disable their detectors.
- [ ] Reorder lists show insertion feedback and auto-scroll.
- [ ] Touch uses hold-to-drag in scroll views; non-drag alternative exists.

## See also
[[Saved Inventory End to End]] · [[Virtualized Lists and Large Inventories]] · [[Tools and Inventory Systems]] · [[UI Layout Objects - Lists Grids and Pages]] · [[Input - UserInputService and ContextActionService]] · [[Gamepad and Console UX]]

## Connected notes
<!-- auto-links:start -->
[[Touch Gestures - Pinch, Pan, Swipe and Long Press]] · [[UI Motion Language and Timing]] · [[Debugging UI Layout and Input]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[ScreenGui Fundamentals]] · [[Responsive UI for Phone Tablet Console and PC]] · [[Layout - Scale Offset and Constraints]] · [[HUD Design]] · [[UI Design Systems]] · [[Off-Screen Objective Markers and Waypoint Arrows]] · [[Notification and Toast Systems]] · [[Declarative UI - React-Lua and Fusion]]
<!-- related:end -->
