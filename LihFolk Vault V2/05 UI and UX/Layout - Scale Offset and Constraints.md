---
tags: [ui, layout, udim2, uiscale, constraints, responsive, type/guide, area/ui, level/intermediate, api/UIScale, area/physics, api/AnchorPoint]
---
# Layout - Scale Offset and Constraints

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Square icons sized with Scale on both axes (stretched everywhere but the design screen).
> - Avoid: One global `UIScale` with no lower clamp, making phone text unreadable.
> - Avoid: Two `UIScale`s on the same object (device scale and pop scale fighting).
> - Every object's Scale or Offset choice is deliberate (table in section 2).
> - Panels are authored at one design resolution with one device `UIScale`.
> - Clamp floor computed from the smallest authored text (12 px drawn minimum).
>
> Cost: TL;DR ~160 tok · whole note ~4.3k tok. Read more: ## 4. Design resolution plus UIScale · ## 6. The constraints · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox UI is laid out with one data type, `UDim2`, and a handful of modifier objects that sit as children of the thing they modify. This note covers the maths of `UDim2`, when to use Scale and when Offset, the design-resolution approach with `UIScale`, and every size constraint, including the cases where they silently override each other. Layout objects that arrange many children (lists, grids, pages, flex) are in [[UI Layout Objects - Lists Grids and Pages]]. Per-device strategy is in [[Responsive UI for Phone Tablet Console and PC]].

Sources: **Docs** (engine reference and the "Size modifiers and constraints" and "Position and size" guides, October 2026), the **reference project** (one production game, measured), and **rule of thumb**.

---

## 1. UDim2 in one paragraph

A `UDim2` is two `UDim`s, X and Y. Each `UDim` is `Scale` (a fraction of the parent's size on that axis) plus `Offset` (pixels). The engine computes:

```
absolute = parentAbsoluteSize * Scale + Offset
```

So `UDim2.new(0.5, -20, 1, 0)` means "half the parent's width minus 20 pixels, and the full parent height". `UDim2.fromScale(x, y)` and `UDim2.fromOffset(x, y)` are the readable shortcuts.

Position works the same way, then `AnchorPoint` shifts the object by a fraction of its **own** size:

```
topLeft = parentAbsolutePosition + parentAbsoluteSize * Position.Scale + Position.Offset - ownAbsoluteSize * AnchorPoint
```

That is why `AnchorPoint = (0.5, 0.5)` with `Position = UDim2.fromScale(0.5, 0.5)` centres anything regardless of its size, and why `AnchorPoint = (1, 1)` with `Position = UDim2.new(1, -16, 1, -16)` pins an object 16 pixels from the bottom-right corner.

`AbsoluteSize` and `AbsolutePosition` (on `GuiBase2d`) are the engine's final answer in screen pixels. They are what you read for hit tests, overlap checks and world-to-screen effects. They update after layout, so reading them on the same frame you change `Size` can return the old value; wait for `GetPropertyChangedSignal("AbsoluteSize")` or a `task.wait()`.

---

## 2. Scale versus Offset: the real trade-off

The usual advice is "use Scale, not Offset". It is half right.

| | Scale | Offset |
|---|---|---|
| Adapts to screen size | Yes, linearly | No |
| Keeps aspect ratio | No: 0.3 x 0.3 is a wide rectangle on a 16:9 screen | Yes |
| Readable text on phones | Shrinks with the screen, can go illegible | Constant pixels, but phones have fewer of them |
| Crisp borders | 1 px lines become 0.6 px or 1.4 px | Exact |
| Huge TV screens | Grows forever (a 75% wide panel on a 4K TV is enormous) | Stays the authored size |

The trap with pure Scale is that both axes scale independently. A square icon sized `UDim2.fromScale(0.1, 0.1)` is 192 x 108 pixels at 1920 x 1080 and 84 x 39 at 844 x 390: stretched and tiny. Docs explicitly note that 75% width "would render to a huge size on 4K TVs for console players".

The trap with pure Offset is that a 400 px panel that looks right at 1920 x 1080 covers 47% of an 844 px phone width and does not fit vertically on a 375 px tall phone at all.

**What works in practice is a hybrid, chosen per object:**

| Object | Use |
|---|---|
| Full-screen overlays, dimmers, letterbox bars | Scale `(1, 1)` |
| Panels and windows | Offset at a design resolution, scaled by one `UIScale` (section 4) |
| Icons, buttons, slots | Offset, or Scale plus `UIAspectRatioConstraint` |
| Hairlines, strokes, borders | Offset (or `UIStroke` thickness in pixels) |
| Margins from screen edges | Offset (a 16 px gutter should be 16 px on every device) |
| Bars that should span a fraction of a container | Scale on one axis, Offset on the other |

---

## 3. SizeConstraint: square things from Scale

`GuiObject.SizeConstraint` chooses which parent axis each Scale is measured against: `RelativeXY` (default), `RelativeXX` (both axes from parent width) or `RelativeYY` (both from parent height). With `RelativeYY`, `UDim2.fromScale(0.1, 0.1)` is a square 10% of the parent's height on every screen. It is the cheapest way to get square Scale-sized icons inside a horizontal bar, and it does not fight layouts the way `UIAspectRatioConstraint` does (section 6).

---

## 4. Design resolution plus UIScale

`UIScale.Scale` multiplies the parent's `AbsoluteSize`, and with it every descendant, including `UIStroke` thickness and `UICorner` radius (Docs). That makes a powerful pattern:

1. Author a panel entirely in Offset at a **design resolution** (for example 1920 x 1080, or a smaller baseline like 1050 x 620).
2. Put one `UIScale` on the panel root.
3. Set `Scale = min(viewportX / designX, viewportY / designY)`, clamped.

Everything inside keeps its exact proportions, strokes stay proportional, nothing stretches, and you design once.

```lua
--!strict
-- Responsive scaler: one UIScale per registered root, updated on viewport change.
local Workspace = game:GetService("Workspace")

local DESIGN = Vector2.new(1920, 1080)
local MIN_SCALE = 0.5
local MAX_SCALE = 1.25

local roots: { [GuiObject]: { scale: UIScale, fit: number } } = {}

local function computeScale(viewport: Vector2, fit: number): number
	if viewport.X <= 0 or viewport.Y <= 0 then
		return 1
	end
	local s = math.min(viewport.X / DESIGN.X, viewport.Y / DESIGN.Y) * fit
	return math.clamp(s, MIN_SCALE, MAX_SCALE)
end

local function refresh()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local vp = camera.ViewportSize
	for _, entry in roots do
		entry.scale.Scale = computeScale(vp, entry.fit)
	end
end

local Scaler = {}

-- fit lets one root be a bit bigger or smaller than the global rule (1 = rule)
function Scaler.register(root: GuiObject, fit: number?)
	local scale = root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = root
	roots[root] = { scale = scale, fit = fit or 1 }
	root.Destroying:Once(function()
		roots[root] = nil
	end)
	refresh()
end

local function hookCamera()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	refresh()
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)
hookCamera()

return Scaler
```

### Choosing the design resolution and clamps

Two real configurations:

- **A cartoon simulator UI kit** uses a 1050 x 620 baseline clamped to `[0.52, 1.18]` (rule of thumb from that kit). The low baseline means panels are drawn at roughly the size they will appear on a laptop, and the clamp stops them becoming tiny on phones or giant on monitors.
- **The reference project** uses 1920 x 1080 for its popups (tooltips use a 1300 x 800 reference so they stay readable) and a separate phone path that is not just a smaller scale (see [[Responsive UI for Phone Tablet Console and PC]]).

The clamp floor is the important number. On a 667 x 375 phone, `min(667/1920, 375/1080) = 0.347`. A panel whose body text was authored at 18 px draws at 6.2 px: unreadable. That is why the reference project's phone pass set a hard rule of **at least 12 px drawn text** and **at least 44 px drawn tap targets**, and checked it with a tool (numbers measured there; Apple's and Google's touch guidance is in the same 44 to 48 point range). Solve for the floor: `scale_min = 12 / smallestAuthoredText`. With 15 px body text the floor is 0.8, which means panels cannot simply shrink on phones; they need phone layouts.

### Two UIScales on one branch multiply

A pop animation usually tweens a `UIScale` from 0.92 to 1. If the panel also has a device `UIScale`, put them on **different** objects (device scale on the root, pop scale on an inner frame) and they multiply correctly. Two `UIScale`s on the same object are a bug waiting to happen; the reference project's motion system explicitly skips any object that already carries a "foreign" `UIScale` for this reason, and stores the device scale as an attribute `BaseScale` so pops can be relative to it ("pop to `BaseScale * 1.06`", not "pop to 1.06").

### UIScale and input

Hit testing uses the scaled result, so a button scaled to 0.5 is half as easy to tap. Never put a pop-down scale on a small button's hit area; scale the visual child and keep the hit area full size. The reference project solved tiny phone buttons with invisible 48 px "tap pads" placed under them (see [[HUD Design]]).

---

## 5. AutomaticSize

`GuiObject.AutomaticSize` (`None`, `X`, `Y`, `XY`) grows an object to fit its children or its text. Key rules (Docs):

- **`Size` becomes the minimum.** A frame with `Size.X.Offset = 100` and `AutomaticSize = X` is never narrower than 100 px.
- **It grows from the `AnchorPoint`.** A label anchored at `(1, 0.5)` grows to the left. Use this for right-aligned currency pills.
- **Text grows in Y only with wrapping.** Text objects resize along Y only if `TextWrapped` is on.
- **`ScrollingFrame` uses `AutomaticCanvasSize`** instead, which resizes the canvas, not the frame.
- Docs recommend **not** combining `AutomaticSize` with `TextScaled` on the same label: the two feed each other.

AutomaticSize is the right tool for anything whose content length you do not control: localised text ([[Localization]]), player names, rich text with mixed sizes, tooltips. It also responds to the player's `PreferredTextSize` setting, while `TextScaled` text does not ([[Accessibility]]).

```lua
--!strict
-- A pill that hugs its text and stays pinned to the right edge.
local function makePill(parent: GuiObject, text: string): TextLabel
	local pill = Instance.new("TextLabel")
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(64, 36)      -- 64 px minimum width, fixed height
	pill.AnchorPoint = Vector2.new(1, 0)       -- grows leftwards
	pill.Position = UDim2.new(1, -16, 0, 16)
	pill.Text = text
	pill.TextSize = 20
	pill.FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = pill

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)     -- pill shape at any size
	corner.Parent = pill

	pill.Parent = parent
	return pill
end
```

---

## 6. The constraints

Constraints are children of the object they constrain.

### UIAspectRatioConstraint

Forces width-to-height ratio. `AspectRatio = 2` means twice as wide as tall (Docs). `AspectType`:

- `FitWithinMaxSize`: the largest size with that ratio that fits inside the object's own computed size.
- `ScaleWithParentSize`: the largest size with that ratio that fits inside the parent.

`DominantAxis` chooses which axis drives the other (`Width` or `Height`).

**Override warning (Docs):** when an object is controlled by both a layout (such as `UIListLayout`) and a `UIAspectRatioConstraint`, the constraint wins and controls the size. In a grid of cards, an aspect constraint on each card can make cards ignore the grid's cell size. Put the constraint on the `UIGridLayout`'s parent or use `CellSize` maths instead.

### UISizeConstraint

`MinSize` and `MaxSize` in pixels. It also overrides layouts (Docs). Typical use: a Scale-sized panel with `MaxSize = (900, 640)` so it stops growing on monitors, and `MinSize` so a button never drops under a tap target. Note the pixels are pre-`UIScale`: a `MinSize` of 44 inside a branch scaled 0.5 draws at 22. Put minimum-size logic where you know the final scale.

### UITextSizeConstraint

`MinTextSize` and `MaxTextSize` for text objects. With `TextScaled` on, text scales with the box but is clamped to this range (Docs). Docs warn against `MinTextSize` below 9. Note that the constraint also caps the player's `PreferredTextSize` boost: text will not grow past `MaxTextSize` even if the player asked for larger text ([[Accessibility]]).

### UIPadding

Insets the content area on each side, as `UDim` (Scale is relative to the parent's size). Layout objects respect it. Padding is the right way to keep text off a button's edge; nudging a label's `Position` by hand breaks the moment the button resizes.

A subtle production bug: legacy panels whose root had `UIPadding` drew their full-width headers inset by the padding. The reference project's audit found headers shifted by exactly `-UIPadding.Left` on several older panels; the fix was to place the header relative to the padding (or move the padding to an inner body frame so the header is unaffected).

### UICorner and UIStroke as layout-affecting objects

They do not change `AbsoluteSize`, but they affect what players perceive as the edge:

- `UIStroke` with `ApplyStrokeMode.Border` draws centred on the border by default. `BorderStrokePosition` (`Center`, `Inner`, `Outer`) and `BorderOffset` now control this (Docs). A 4 px centred stroke adds 2 px outside the box: two adjacent cards with 8 px padding look 4 px apart.
- `UICorner` with Scale `0.5` or more makes a pill whatever the size (Docs).

---

## 7. Order of operations (how the engine resolves a size)

Rule of thumb model, consistent with the docs' override notes:

1. Compute `Size` from the parent (`Scale * parent + Offset`), honouring `SizeConstraint`.
2. Apply a layout's size if a layout controls it (flex fill, grid `CellSize`, table).
3. Apply `UISizeConstraint` and `UIAspectRatioConstraint` (they override layouts).
4. Apply `AutomaticSize` growth (with `Size` as the minimum).
5. Multiply by every `UIScale` on this object and its ancestors.
6. Place with `Position` and `AnchorPoint`.

When an object refuses to take the size you set, walk this list: almost always a layout or a constraint is overriding you.

---

## 8. Pixel snapping and odd numbers

Offsets are snapped to whole pixels after scaling. Two practical effects:

- A centred object with an odd size inside an even container cannot be exactly centred; one side is a pixel wider. The reference project's audit flags captions more than a pixel off-centre (`centre`), and accepts deliberate nudges only when marked with an `OpticalOffset` attribute. Text that sits optically low because of descenders is commonly lifted by 1 px on purpose.
- Strokes at fractional thickness after scaling (a 3 px stroke at scale 0.846 is 2.54 px) render slightly soft. For hairlines, prefer whole-pixel thicknesses at the most common scales, or accept the softness.

---

## 9. A worked example: a shop card that survives every screen

Requirements: cards in a grid, square art, a price button that is always at least 44 px tall when drawn, text never under 12 px.

- Grid cell: Offset `180 x 230` at the 1920 x 1080 design size.
- Art: `UIAspectRatioConstraint` 1:1 inside the top 60% of the card.
- Price button: Offset height 54 so that at the phone floor scale of 0.82 it still draws 44 px.
- Body text: authored 15 px, so 12.3 px at 0.82.
- Device scale: the scaler in section 4 with a `0.82` floor on phones; when the panel cannot fit at 0.82, the phone layout drops a column instead of shrinking further.

The reference project arrived at the same answer by measurement: its phone layouts keep panels at scale 0.82 or above with 54-unit tap targets, and drop columns (5 or 6 armour cards a row on desktop, fewer on phones) rather than shrinking the cards.

---

## Common mistakes

- Square icons sized with Scale on both axes (stretched everywhere but the design screen).
- One global `UIScale` with no lower clamp, making phone text unreadable.
- Two `UIScale`s on the same object (device scale and pop scale fighting).
- `UIAspectRatioConstraint` inside a grid cell, fighting the grid.
- `MinSize` in pixels inside a scaled branch, so the minimum is not the minimum.
- Reading `AbsoluteSize` in the same frame as setting `Size`.
- Using `Position` nudges instead of `UIPadding` for text insets.

## Checklist

- [ ] Every object's Scale or Offset choice is deliberate (table in section 2).
- [ ] Panels are authored at one design resolution with one device `UIScale`.
- [ ] Clamp floor computed from the smallest authored text (12 px drawn minimum).
- [ ] Tap targets at least 44 px drawn at the floor scale.
- [ ] Square things use `SizeConstraint` or `UIAspectRatioConstraint`.
- [ ] Variable-length text uses `AutomaticSize`, not `TextScaled`.
- [ ] Pop scales live on a child of the device-scaled root.

See also: [[ScreenGui Fundamentals]], [[UI Layout Objects - Lists Grids and Pages]], [[Responsive UI for Phone Tablet Console and PC]], [[Safe Areas and Insets]], [[Text Fonts and Rich Text]], [[UI and GUI Animation]].

## Connected notes
<!-- auto-links:start -->
[[Readable Text and UI Scale]] · Links - Layouts and constraints · Debugging UI Layout and Input · Cookbook - UI · Case Study - Phone UI Overhaul · Skill - Roblox UI Builder
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Debugging UI Layout and Input]] · [[UI Design Systems]] · [[AI Pitfalls - UI and Input]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[Virtualized Lists and Large Inventories]] · [[Gamepad and Console UX]] · [[UI Motion Language and Timing]] · [[World-Space UI - BillboardGui and SurfaceGui]] · [[Race HUD - Position, Laps, Splits, Speedometer and Minimap]] · [[Menu Archetypes - Shop Settings Codes Rewards]]
<!-- related:end -->
