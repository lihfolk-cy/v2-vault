---
tags: [ui, layout, uilistlayout, flex, uigridlayout, uipagelayout, scrollingframe]
---
# UI Layout Objects - Lists Grids and Pages

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Tweening `Position` of a child under a layout (nothing happens).
> - Avoid: `SortOrder = Name`, then a rename reorders the menu.
> - Avoid: Duplicate `LayoutOrder`s (order varies between sessions).
> - Every layout uses `SortOrder = LayoutOrder` with gapped, unique orders.
> - Laid-out slots are static; animation happens on inner faces.
> - Tab bars use flex `Fill`; card rows with uneven content use `Stretch`.
>
> Read more (17 KB note): ## 3. Flex layouts · ## 7. ScrollingFrame with layouts · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Layout objects arrange the siblings they sit next to. Insert a `UIListLayout` into a frame and every other `GuiObject` child of that frame is positioned (and possibly sized) by the layout instead of by its own `Position`. This note covers `UIListLayout` (including wrapping and flex), `UIFlexItem`, `UIGridLayout`, `UIPageLayout`, `UITableLayout` and `ScrollingFrame` with automatic canvas size, plus the performance and ordering traps that show up in shops and inventories with hundreds of entries.

Sources: **Docs** (engine reference, "List and flex layouts", "Grid and table layouts", "Scrolling frames", October 2026), the **reference project** (one production game), and **rule of thumb**. Single-object sizing is in [[Layout - Scale Offset and Constraints]].

---

## 1. What a layout takes over

Docs warn that once a layout is inserted it "either overrides or influences" `Position`, `Rotation` and/or `Size` of its siblings, so editing those in Properties or scripts "will not have the normal effect". In practice:

| Property of a child | Under `UIListLayout` (no flex) | Under flex | Under `UIGridLayout` |
|---|---|---|---|
| `Position` | Ignored | Ignored | Ignored |
| `Size` | Used | Overridden on the flex axis | Overridden by `CellSize` |
| `AnchorPoint` | Ignored for placement | Ignored | Ignored |
| `Visible = false` | Skipped, no gap left | Skipped | Skipped |
| `LayoutOrder` | Sort key (if `SortOrder = LayoutOrder`) | Same | Same |

Two consequences:

- **You cannot animate a child's `Position` inside a layout.** To slide or bob an item, animate an inner frame inside the item, or a `UIScale`, never the laid-out child itself. This is why production cards are usually two levels deep: a laid-out "slot" and a free "face" inside it.
- **Hiding a child collapses the gap.** Great for HUD rails that hide locked buttons; bad when you want a stable grid (use transparency instead of `Visible` for placeholders).

`UIGridStyleLayout` (the base of list, grid and page layouts) exposes `AbsoluteContentSize`, the pixel size of everything laid out. It is the number you need for sizing a container to its content when `AutomaticSize` is not enough, and `ApplyLayout()` forces an immediate re-layout (Docs).

---

## 2. UIListLayout

Core properties (Docs):

- `FillDirection`: `Horizontal` or `Vertical`.
- `SortOrder`: `LayoutOrder` (ascending integers) or `Name` (alphanumeric). `Custom` with `SetCustomSortFunction` also exists on the base class.
- `HorizontalAlignment` / `VerticalAlignment`: where the whole list sits in the container, and how items align to each other.
- `Padding`: a `UDim` gap **between** items only. Use `UIPadding` on the container for space around the list.
- `Wraps`: when items exceed the container on the fill axis, continue on a new line.

### Sort order rules that save time

- Always use `SortOrder = LayoutOrder` in production. Sorting by `Name` means renaming an item reorders the menu.
- Leave gaps: order items 10, 20, 30, not 1, 2, 3, so a new item can slot in at 15 without renumbering.
- To reverse a horizontal list (right to left), negate the orders (Docs suggest `0, -1, -2, -3`).
- Ties are not a stable contract. Give every item a unique `LayoutOrder`.

### Wrapping: grids without UIGridLayout

`Wraps = true` turns a list into a flowing grid where items keep their own sizes. The reference project's HUD rail is a vertical `UIListLayout` with `Wraps` on, so the button column flows into a second column when it runs out of height, giving a two-wide grid of square buttons whose count can change (shop, upgrades, index, worlds, forge, and so on) without hand placement. On phones a script hides two of the squares and sets the rail's height so it wraps three high by two wide; their measured rule was that a three-wide rail collided with the hotbar and boss bar at 667 x 375.

---

## 3. Flex layouts

Flex adds distribution of spare space to `UIListLayout` (Docs):

- `HorizontalFlex` (horizontal lists) and `VerticalFlex` (vertical lists) take a `UIFlexAlignment`: `None`, `Fill`, `SpaceAround`, `SpaceBetween`, `SpaceEvenly`.
  - `Fill`: items resize to fill the line, overriding their own size on that axis. The number of items per line does not change.
  - The three `Space*` modes keep item sizes and distribute gaps.
- `ItemLineAlignment` (`Automatic`, `Start`, `Center`, `End`, `Stretch`) aligns items across the line. `Stretch` makes every item fill the line's cross size, which evens out cards whose content heights differ.

`UIFlexItem`, parented to one child, overrides flex for that child alone (Docs):

| `FlexMode` | Effective grow:shrink | Behaviour |
|---|---|---|
| `None` | 0:0 | Keeps its size |
| `Grow` | 1:0 | Takes spare space, never shrinks below its size (can overflow) |
| `Shrink` | 0:1 | Gives up space when cramped, never grows |
| `Fill` | 1:1 | Always fills the line |
| `Custom` | `GrowRatio` : `ShrinkRatio` | Your ratios |

`UIFlexItem.ItemLineAlignment` overrides the cross alignment for that item.

### When flex is the right answer

- **Tab bars.** `HorizontalFlex = Fill` gives equal tabs whatever their count; Docs use this exact example. Adding a sixth tab needs no maths.
- **Slider rows.** Fixed-width labels at both ends, one bar with `UIFlexItem` `Fill` between them.
- **Footer pill bars.** Pills keep their text widths with `SpaceBetween`.
- **Cards with uneven text.** `ItemLineAlignment = Stretch` so every card in a row is the same height.

### When it is not

Docs: flex "adds a slight performance cost above non-flex, especially when resizing the layout or dynamically adding/removing flex items", and a grid layout is preferable when items must align in both X and Y. Do not put flex on a list that gets items added every frame (a kill feed, a damage log); use a plain list.

```lua
--!strict
-- Equal-width tab bar that adapts to any number of tabs.
local function buildTabBar(parent: GuiObject, names: { string }): Frame
	local bar = Instance.new("Frame")
	bar.Name = "TabBar"
	bar.Size = UDim2.new(1, 0, 0, 48)
	bar.BackgroundTransparency = 1

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalFlex = Enum.UIFlexAlignment.Fill
	list.Padding = UDim.new(0, 6)
	list.Parent = bar

	for i, name in names do
		local tab = Instance.new("TextButton")
		tab.Name = "Tab_" .. name
		tab.LayoutOrder = i * 10
		tab.Size = UDim2.new(0, 80, 1, 0) -- 80 is the basis; Fill overrides width
		tab.Text = name
		tab.TextSize = 18
		tab.Parent = bar
	end

	bar.Parent = parent
	return bar
end
```

---

## 4. UIGridLayout

For strict two-dimensional grids where every cell is the same size (Docs):

- `CellSize` (`UDim2`) and `CellPadding` (`UDim2`).
- `FillDirection`: which axis fills first.
- `FillDirectionMaxCells`: cap on cells per row (or column) before wrapping. 0 means as many as fit.
- `StartCorner`: which corner the grid starts from.
- `AbsoluteCellSize` and `AbsoluteCellCount` (read-only): what the engine actually used.

### Responsive cell counts

A Scale `CellSize` like `UDim2.fromScale(0.2, 0.2)` gives five columns but non-square cells. The robust pattern computes Offset cell sizes from the container's width and a target column count:

```lua
--!strict
-- Keeps square-ish cards, picks how many fit, recomputes on resize.
local function fitGrid(container: GuiObject, grid: UIGridLayout, minCell: number, gap: number, aspect: number)
	local function apply()
		local width = container.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local columns = math.max(1, math.floor((width + gap) / (minCell + gap)))
		local cell = math.floor((width - gap * (columns - 1)) / columns)
		grid.CellPadding = UDim2.fromOffset(gap, gap)
		grid.CellSize = UDim2.fromOffset(cell, math.floor(cell / aspect))
		grid.FillDirectionMaxCells = columns
	end
	container:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	apply()
end
```

Note the trap: `AbsoluteSize` here is post-`UIScale`. If the grid lives inside a scaled panel, compute in design units (divide by the scale) or the column count changes when the panel pops open from 0.92 to 1 and the grid jumps mid-animation. The reference project hit exactly this class of bug: its card pops had to be made relative to the card's own base scale after phones drew cards larger.

### Grid versus wrapped list

| Need | Use |
|---|---|
| Identical cells, both axes aligned (inventory, index) | `UIGridLayout` |
| Items of different widths flowing like text (tags, chips) | `UIListLayout` with `Wraps` |
| Rows of uneven cards that should share a height | `UIListLayout` with `Wraps` and `ItemLineAlignment = Stretch` |

---

## 5. UIPageLayout

Turns children into pages shown one at a time with an animated scroll (Docs). Useful properties and members:

- `Animated`, `TweenTime`, `EasingStyle`, `EasingDirection`, `Circular`, `Padding`.
- Input switches, all default true: `GamepadInputEnabled` (overrides `NextSelection*` to page), `ScrollWheelInputEnabled`, `TouchInputEnabled` (swipe).
- `CurrentPage`, `JumpTo(page)`, `JumpToIndex(index)` (wraps modulo the page count), `Next()`, `Previous()`.
- Events `PageEnter`, `PageLeave`, `Stopped`.

Good for onboarding carousels, a codex, and "pick your world" pickers. Two cautions:

- **Built-in input can fight your input.** Touch swiping a page also scrolls a `ScrollingFrame` inside it; the mouse wheel pages when the player meant to scroll a list. Turn off the inputs you do not want.
- **All pages exist at once.** A page layout with ten heavy pages holds all ten in memory. For big tabbed menus, prefer one container with `Visible` tabs (or build pages on demand). Use `PageEnter` and `PageLeave` to start and stop page animation.

---

## 6. UITableLayout

Treats children as rows (or columns, via `MajorAxis`) and their children as cells, aligning columns across rows (Docs: `FillEmptySpaceColumns`, `FillEmptySpaceRows`, `MajorAxis`, `Padding`). It suits stat tables and leaderboards where the columns must line up. For most game UI a vertical list of row frames, each with a horizontal flex list and fixed-width columns, is easier to style and animate.

---

## 7. ScrollingFrame with layouts

The modern recipe:

1. A `ScrollingFrame` with `AutomaticCanvasSize = Enum.AutomaticSize.Y` (or X for horizontal strips) and `CanvasSize = UDim2.new()`.
2. A `UIListLayout` or `UIGridLayout` inside.
3. `UIPadding` inside for edge spacing.
4. `ScrollingDirection` set to the one axis you mean.

Docs: `AutomaticCanvasSize` "behaves the same" as `AutomaticSize` but resizes the canvas. Other properties worth knowing: `ElasticBehavior` (touch overscroll), `ScrollBarThickness`, `VerticalScrollBarInset` (whether the canvas is narrowed by the bar), and `CanvasPosition` for programmatic scrolling. `GetScrollVelocity` and `ResetScrollVelocity` control inertia (Docs).

Two production traps:

- **Scrollbar overlap.** With `VerticalScrollBarInset = None`, a 12 px bar covers the right edge of every card. Use `ScrollBar` inset, or pad the right side by the bar thickness.
- **Phones and nested scrolling.** A horizontal strip inside a vertical scroller is fine; two scrollers on the same axis fight for the finger. The reference project's phone layouts turned tabs, chips and categories into **horizontal** strips precisely so the main content could own vertical scrolling.

### Scrolling to the selected item

```lua
--!strict
local TweenService = game:GetService("TweenService")

-- Bring a child into view (vertical scroller), e.g. after gamepad selection.
local function scrollIntoView(scroller: ScrollingFrame, child: GuiObject, margin: number)
	local top = child.AbsolutePosition.Y - scroller.AbsolutePosition.Y + scroller.CanvasPosition.Y
	local bottom = top + child.AbsoluteSize.Y
	local viewTop = scroller.CanvasPosition.Y
	local viewBottom = viewTop + scroller.AbsoluteWindowSize.Y
	local target = viewTop
	if top - margin < viewTop then
		target = top - margin
	elseif bottom + margin > viewBottom then
		target = bottom + margin - scroller.AbsoluteWindowSize.Y
	end
	if target ~= viewTop then
		TweenService:Create(scroller, TweenInfo.new(0.15), {
			CanvasPosition = Vector2.new(scroller.CanvasPosition.X, math.max(0, target)),
		}):Play()
	end
end
```

The engine already scrolls to a gamepad-selected child, but not with your margin and not for selection you set from code; this helper makes both consistent. Note that this computes in absolute pixels, so it works inside a `UIScale`d panel too.

---

## 8. Big lists: when the layout itself is the problem

A layout recomputes when a child is added, removed, resized or reordered. For a backpack with 600 items, building 600 cards means 600 instances times every card's children (often 10 to 20 each), so 6,000 to 12,000 instances, and a re-layout every time one changes.

Measured guidance (rule of thumb, consistent with the reference project's inventory work):

| Item count | Approach |
|---|---|
| Under about 100 | Build all cards; fine everywhere |
| 100 to 500 | Build all, but reuse cards (pool) when filtering instead of destroying and rebuilding; batch inserts in one frame |
| Over 500 | Virtualise: build only the cards in view plus a buffer, place them by `Position` yourself (no layout), and set `CanvasSize` from the item count |

```lua
--!strict
-- Minimal vertical virtualiser: fixed row height, pooled rows, no UIListLayout.
type RowBinder = (row: Frame, index: number) -> ()

local function virtualList(scroller: ScrollingFrame, template: Frame, rowHeight: number, count: number, bind: RowBinder)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.None
	scroller.CanvasSize = UDim2.fromOffset(0, rowHeight * count)

	local pool: { Frame } = {}
	local function rowAt(i: number): Frame
		local row = pool[i]
		if not row then
			row = template:Clone()
			row.Parent = scroller
			pool[i] = row
		end
		return row
	end

	local function refresh()
		local viewH = scroller.AbsoluteWindowSize.Y
		local first = math.max(1, math.floor(scroller.CanvasPosition.Y / rowHeight))
		local visible = math.ceil(viewH / rowHeight) + 2
		for slot = 1, visible do
			local index = first + slot - 1
			local row = rowAt(slot)
			if index <= count then
				row.Visible = true
				row.Position = UDim2.fromOffset(0, (index - 1) * rowHeight)
				bind(row, index)
			else
				row.Visible = false
			end
		end
		for slot = visible + 1, #pool do
			pool[slot].Visible = false
		end
	end

	scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(refresh)
	scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(refresh)
	refresh()
end
```

Rebinding only writes properties that changed in a well-written `bind` (compare before assigning), which keeps the ScreenGui cache valid most frames ([[ScreenGui Fundamentals]]).

---

## 9. Layout objects and animation

- Animate faces inside slots, not slots (section 1).
- To animate an item entering a list, add it with a `UIScale` at 0 and tween to 1; the layout reserves its full size immediately, so neighbours jump. If that jump is ugly, animate the slot's `Size` on the fill axis from 0 instead (layouts do use child `Size` when flex is off).
- A pressed button inside a list that scales up overlaps its neighbours; that is fine for a 1.06 hover, ugly at 1.2. The reference project's hover scale is 1.06 with a 3 px lift for this reason.
- Grids keep scaled cells centred only if the scaling happens on an inner child with `AnchorPoint (0.5, 0.5)`. The same project re-anchored every zoom target to its centre in place, and for list items moved the scaled visuals into a centred inner "HoverContent" frame.

---

## Common mistakes

- Tweening `Position` of a child under a layout (nothing happens).
- `SortOrder = Name`, then a rename reorders the menu.
- Duplicate `LayoutOrder`s (order varies between sessions).
- Flex on a list that changes every frame.
- Scale `CellSize` that stretches cards on wide screens.
- Grid maths reading post-`UIScale` sizes during an open animation.
- A `UIPageLayout` swallowing the mouse wheel meant for a list.
- Building 600 cards with 15 children each on menu open.

## Checklist

- [ ] Every layout uses `SortOrder = LayoutOrder` with gapped, unique orders.
- [ ] Laid-out slots are static; animation happens on inner faces.
- [ ] Tab bars use flex `Fill`; card rows with uneven content use `Stretch`.
- [ ] Grids compute Offset cell size from available width.
- [ ] Scrollers use `AutomaticCanvasSize` on one axis and pad for the scrollbar.
- [ ] Lists over a few hundred items are pooled or virtualised.

See also: [[Layout - Scale Offset and Constraints]], [[Responsive UI for Phone Tablet Console and PC]], [[Menu Archetypes - Shop Settings Codes Rewards]], [[Gamepad and Console UX]], [[UI and GUI Animation]], [[Script Performance]].

## Connected notes
<!-- auto-links:start -->
[[Links - Layouts and constraints]] · [[Virtualized Lists and Large Inventories]] · [[Cookbook - UI]] · [[Debugging UI Layout and Input]] · [[Case Study - Phone UI Overhaul]] · [[Links - UI elements]]
<!-- auto-links:end -->
