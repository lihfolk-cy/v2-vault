---
tags: [ui, inventory, scrollingframe, virtualization, performance, pooling, search, gamepad, networking, type/guide, area/ui, level/intermediate]
---
# Virtualized Lists and Large Inventories

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Rebuilding all cards on any change -> Rebind only the affected index
> - Avoid: State stored on the cell -> Store state by item key; apply in `bind`
> - Avoid: Connecting events inside `bind` -> Connect once at creation; read an attribute
> - Items stacked where possible; unique-item cap designed and shown in UI.
> - Under ~100 entries: plain layout. Over ~300 or growing: virtualised.
> - View array built by filter then sort, with a unique tiebreaker.
>
> Cost: TL;DR ~160 tok · whole note ~6.1k tok. Read more: ## 3. A grid virtualiser that rebinds only what changed · ## 4. Search, filter and sort at scale · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Inventories grow. A collection game that starts with 30 items at launch has 400 after six months of updates, and a dedicated player owns 2,000 entries. The UI that was fine at 30 (build a card per item inside a `UIGridLayout`) becomes the slowest screen in the game: it takes a second to open, it hitches when an item is added, and on a low-end phone it eats memory that the world needed.

[[UI Layout Objects - Lists Grids and Pages]] (section 8) gives the thresholds and a minimal vertical virtualiser. This note goes further: a grid virtualiser that only rebinds cells that changed, the data model behind it, search and sort at scale, gamepad selection in recycled cells, how to get the inventory to the client without a giant payload, and when virtualisation is the wrong answer.

---

## 1. Where the cost actually is

An inventory card is rarely one instance. A typical card has a frame, a UICorner, a UIStroke, a gradient, an icon image, a name label, a count label, a rarity strip, a "new" badge, an equipped tick and a lock icon: 10 to 20 instances. Multiply:

| Items | Instances (15 per card) | What you feel |
|---|---|---|
| 50 | 750 | Nothing |
| 300 | 4,500 | Open takes a few frames; adding an item hitches if the whole grid rebuilds |
| 1,000 | 15,000 | Opening stalls; memory noticeably up; layout passes visible in the MicroProfiler |
| 3,000 | 45,000 | Unusable on phones |

These are rules of thumb; the real cost depends on what each card contains. Three separate costs add up:

1. **Creation**: cloning thousands of instances in one frame.
2. **Layout**: a `UIGridLayout` or `UIListLayout` recomputes when children are added, removed, resized or reordered, and touches every child.
3. **Rendering and memory**: each visible image needs its texture; each instance costs memory even when scrolled out of view, and text labels hold shaped text.

Virtualisation attacks all three: you only ever have about `visible + 2 buffer rows` cells, you position them yourself (no layout object), and you rebind data into recycled cells as the player scrolls.

### When not to virtualise

- **Under about 100 items**, just build them. Virtualisation adds code and bugs (selection, animation, accessibility) for no measurable gain.
- **Variable-height rich content** (a quest log where each entry expands, a changelog) is hard to virtualise correctly because you must know every row's height before you render it. Paginate instead (tabs or "page 1 of 6").
- **Lists that need layout features** (wrapping text that decides height, flex fill) are a poor fit. Fixed cell sizes are what make virtualisation simple.
- **If the items can be stacked**, do that first. A player with 900 copies of 40 item types has 40 entries, not 900. Stacking is a data decision that removes the problem.

---

## 2. Separate the data from the cells

The core idea: the **view** is an array of item keys after filtering and sorting. Cells display `view[index]`. A cell has no identity of its own; it is a window onto whatever index it currently shows.

```
inventory (server truth, replicated)  ->  view (filtered, sorted array of keys)  ->  cells (recycled)
```

Consequences:

- Sorting or filtering rebuilds `view` (cheap, it is an array of strings or numbers) and then rebinds visible cells only.
- An item changing (count, equipped) means: find its index in `view`; if a cell currently shows that index, rebind that one cell. Everything else is untouched.
- Nothing about a cell (selection, highlight, "new" badge) may be stored on the cell itself between binds. Store it in the data, keyed by item key, and let `bind` apply it.

The last point is where most bugs come from. A "selected" outline set directly on a cell stays on that cell after it scrolls away and gets reused for a different item, so a random item looks selected.

---

## 3. A grid virtualiser that rebinds only what changed

The minimal virtualiser in the layout note rebinds every visible row on every scroll event. That is fine for rows that are cheap to bind. For cards with icons, it means rewriting dozens of properties per frame while scrolling, and every property write invalidates the ScreenGui's cached render ([[ScreenGui Fundamentals]]). The version below keeps a map from **data index to cell** so a scroll only binds cells for indices that just entered the window.

```lua
--!strict
-- Virtualised grid: fixed cell size, responsive column count, pooled cells,
-- binds only indices that newly enter the visible range.
export type Binder = (cell: GuiObject, index: number) -> ()

export type VGrid = {
	setCount: (n: number) -> (),     -- call after the view array changes length
	refreshAll: () -> (),            -- rebind every visible cell (after sort/filter)
	refreshIndex: (i: number) -> (), -- rebind one index if it is visible
	cellFor: (i: number) -> GuiObject?,
	scrollToIndex: (i: number) -> (),
	destroy: () -> (),
}

local BUFFER_ROWS = 2

local function createVGrid(
	scroller: ScrollingFrame,
	template: GuiObject,
	cellSize: Vector2,
	gap: number,
	bind: Binder
): VGrid
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.None
	scroller.ScrollingDirection = Enum.ScrollingDirection.Y

	local count = 0
	local columns = 1
	local active: { [number]: GuiObject } = {} -- data index -> cell
	local free: { GuiObject } = {}
	local connections: { RBXScriptConnection } = {}

	local strideX = cellSize.X + gap
	local strideY = cellSize.Y + gap

	local function recomputeMetrics()
		local width = scroller.AbsoluteWindowSize.X
		columns = math.max(1, math.floor((width + gap) / strideX))
		local rows = math.ceil(count / columns)
		scroller.CanvasSize = UDim2.fromOffset(0, math.max(0, rows * strideY - gap))
	end

	local function acquire(): GuiObject
		local cell = table.remove(free)
		if not cell then
			cell = template:Clone()
			cell.Size = UDim2.fromOffset(cellSize.X, cellSize.Y)
			cell.Parent = scroller
		end
		cell.Visible = true
		return cell
	end

	local function release(i: number)
		local cell = active[i]
		if cell then
			active[i] = nil
			cell.Visible = false
			table.insert(free, cell)
		end
	end

	local function place(cell: GuiObject, i: number)
		local zero = i - 1
		cell.Position = UDim2.fromOffset((zero % columns) * strideX, (zero // columns) * strideY)
	end

	local function update(rebindAll: boolean)
		local top = scroller.CanvasPosition.Y
		local viewH = scroller.AbsoluteWindowSize.Y
		local firstRow = math.max(0, math.floor(top / strideY) - BUFFER_ROWS)
		local lastRow = math.floor((top + viewH) / strideY) + BUFFER_ROWS
		local first = firstRow * columns + 1
		local last = math.min(count, (lastRow + 1) * columns)

		-- Release cells that left the window (collect first, then release).
		local leaving: { number } = {}
		for i in active do
			if i < first or i > last then
				table.insert(leaving, i)
			end
		end
		for _, i in leaving do
			release(i)
		end

		for i = first, last do
			local cell = active[i]
			if not cell then
				cell = acquire()
				active[i] = cell
				place(cell, i)
				bind(cell, i)
			elseif rebindAll then
				place(cell, i)
				bind(cell, i)
			end
		end
	end

	table.insert(connections, scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		update(false)
	end))
	table.insert(connections, scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
		recomputeMetrics()
		update(true) -- column count may have changed, so every position may be stale
	end))

	local grid = {} :: VGrid

	function grid.setCount(n: number)
		count = n
		recomputeMetrics()
		update(true)
	end

	function grid.refreshAll()
		update(true)
	end

	function grid.refreshIndex(i: number)
		local cell = active[i]
		if cell then
			bind(cell, i)
		end
	end

	function grid.cellFor(i: number): GuiObject?
		return active[i]
	end

	function grid.scrollToIndex(i: number)
		local y = ((i - 1) // columns) * strideY
		local top = scroller.CanvasPosition.Y
		local viewH = scroller.AbsoluteWindowSize.Y
		if y < top then
			scroller.CanvasPosition = Vector2.new(0, y)
		elseif y + cellSize.Y > top + viewH then
			scroller.CanvasPosition = Vector2.new(0, y + cellSize.Y - viewH)
		end
		update(false) -- make sure the cell exists right now, not next signal
	end

	function grid.destroy()
		for _, c in connections do
			c:Disconnect()
		end
		for _, cell in active do
			cell:Destroy()
		end
		for _, cell in free do
			cell:Destroy()
		end
		table.clear(active)
		table.clear(free)
	end

	return grid
end

return createVGrid
```

Points that are easy to get wrong:

- **Do not put a `UIGridLayout` in the scroller.** The virtualiser owns `Position`; a layout would fight it. Padding goes into the `gap` and into the offsets, or into a `UIPadding` on an inner frame if you need margins.
- **Cell size is in pixels.** That is deliberate: column count is what changes with screen width, not cell size. If you want cells to grow on large screens, pick the size from a few breakpoints when the grid is created and recreate the grid when the breakpoint changes ([[Responsive UI for Phone Tablet Console and PC]]).
- **`AbsoluteWindowSize` is zero until the frame has been laid out.** If the panel is created hidden, metrics compute one column and an empty range. Call `setCount` after the panel is visible, or let the size-changed signal fix it (it will, because the size changes from 0).
- **Release, then acquire.** Releasing cells that left the window before acquiring new ones keeps the pool size at the visible count. The reverse order briefly doubles it during fast scrolls.
- **Fast flings skip ranges.** A fling can jump the canvas by thousands of pixels between signals. The code handles that because it computes the range from scratch each time; versions that "shift by one row" break.

### Binding without waste

`bind` is called often, so make it cheap and make it skip identical work:

```lua
--!strict
local lastKey: { [GuiObject]: string } = setmetatable({}, { __mode = "k" }) :: any

local function bindCard(cell: GuiObject, index: number)
	local key = view[index]
	local item = inventory[key]
	local signature = key .. "|" .. item.count .. "|" .. (if item.equipped then "E" else "") .. (if item.isNew then "N" else "")
	if lastKey[cell] == signature then
		return -- nothing changed for this cell
	end
	lastKey[cell] = signature

	local icon = cell:FindFirstChild("Icon") :: ImageLabel
	local countLabel = cell:FindFirstChild("Count") :: TextLabel
	icon.Image = itemDefs[item.defId].icon
	countLabel.Text = if item.count > 1 then "x" .. item.count else ""
	countLabel.Visible = item.count > 1
	;(cell:FindFirstChild("Equipped") :: GuiObject).Visible = item.equipped
	;(cell:FindFirstChild("New") :: GuiObject).Visible = item.isNew
	cell:SetAttribute("ItemKey", key) -- for click handlers and debugging
end
```

Here `view`, `inventory` and `itemDefs` are your client-side data tables. Cache child references per cell on first bind if `FindFirstChild` shows up in profiles; for a few dozen cells it will not.

Click handling: connect `Activated` once per cell when the cell is created, and read the cell's `ItemKey` attribute at click time. Never connect inside `bind`, or every rebind adds another connection and one click fires twenty handlers.

---

## 4. Search, filter and sort at scale

### Build the view, do not mutate it

```lua
--!strict
type Item = { key: string, defId: string, count: number, rarity: number, obtainedAt: number, equipped: boolean, isNew: boolean }

local function buildView(items: { [string]: Item }, query: string, rarityFilter: number?, sortMode: "rarity" | "recent" | "name"): { string }
	local q = string.lower(query)
	local out: { string } = {}
	for key, item in items do
		local def = itemDefs[item.defId]
		if rarityFilter and item.rarity ~= rarityFilter then
			continue
		end
		if q ~= "" and not string.find(def.searchName, q, 1, true) then -- plain find: no pattern magic
			continue
		end
		table.insert(out, key)
	end
	table.sort(out, function(a: string, b: string): boolean
		local ia, ib = items[a], items[b]
		if sortMode == "rarity" and ia.rarity ~= ib.rarity then
			return ia.rarity > ib.rarity
		elseif sortMode == "recent" and ia.obtainedAt ~= ib.obtainedAt then
			return ia.obtainedAt > ib.obtainedAt
		end
		local na, nb = itemDefs[ia.defId].searchName, itemDefs[ib.defId].searchName
		if na ~= nb then
			return na < nb
		end
		return a < b -- final tiebreaker: always a total order
	end)
	return out
end
```

Three details that matter:

- **`string.find(s, q, 1, true)`**: the fourth argument turns off Lua patterns. Without it, a player typing `%` or `[` into the search box raises an error ("malformed pattern") and the inventory breaks for that session.
- **Precompute `searchName`** (lower case, accents stripped if you localise) once per definition, not per keystroke. With [[Localization]], search the translated name the player sees, not the internal id.
- **Always end the comparator with a unique tiebreaker.** `table.sort` is not stable. Without a tiebreaker, items with equal rarity swap places every time the view is rebuilt, so the grid visibly shuffles when the player equips something. A comparator that is not a strict weak ordering (for example `>=`) can also raise "invalid order function for sorting".

### Debounce typing

Rebuilding a 2,000-item view takes on the order of a millisecond or two in Luau (rule of thumb; measure yours), which is fine once, but on phones each keystroke also rebinds the grid. Debounce search input by about 0.15 to 0.25 s:

```lua
local pending = 0
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	pending += 1
	local ticket = pending
	task.delay(0.2, function()
		if ticket == pending then
			rebuild()
		end
	end)
end)
```

### Scroll position rules

| Event | Scroll position |
|---|---|
| Search text or filter changes | Reset to top (the old position is meaningless) |
| Sort mode changes | Reset to top |
| An item's count or state changes | Keep position |
| A new item arrives while the inventory is open | Keep position; show a "new" badge or a small "1 new item" pill at the top rather than jumping |
| Item removed (sold, traded) above the viewport | Keep the item the player was looking at in place: adjust `CanvasPosition` by the rows removed above it |

The last one is subtle: removing an item shifts every later index by one, so cells "slide" under the player's thumb. For grids it is usually acceptable to let it shift; for sell-many workflows, consider marking sold items as greyed placeholders until the panel closes.

---

## 5. Selection and gamepad in recycled cells

Gamepad navigation uses `GuiService.SelectedObject` and the engine's automatic neighbour search ([[Gamepad and Console UX]]). Virtualisation breaks both assumptions:

- The neighbour below the bottom visible row **does not exist yet**, so pressing down at the edge either does nothing or jumps out of the grid.
- When the selected cell scrolls out and gets recycled, `SelectedObject` still points at that cell, which now shows a different item.

The robust pattern: **selection is a data index, not an instance.**

```lua
--!strict
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local selectedIndex = 1

local function select(i: number)
	selectedIndex = math.clamp(i, 1, #view)
	grid.scrollToIndex(selectedIndex)
	local cell = grid.cellFor(selectedIndex)
	if cell then
		GuiService.SelectedObject = cell
	end
end

local function onNav(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local cols = currentColumns() -- expose from the grid, or recompute
	if input.KeyCode == Enum.KeyCode.DPadDown then
		select(selectedIndex + cols)
	elseif input.KeyCode == Enum.KeyCode.DPadUp then
		select(selectedIndex - cols)
	elseif input.KeyCode == Enum.KeyCode.DPadRight then
		select(selectedIndex + 1)
	elseif input.KeyCode == Enum.KeyCode.DPadLeft then
		select(selectedIndex - 1)
	else
		return Enum.ContextActionResult.Pass
	end
	return Enum.ContextActionResult.Sink
end

-- Bind while the inventory is open; unbind on close.
ContextActionService:BindActionAtPriority("InventoryNav", onNav, false, Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight)
```

Thumbstick navigation needs the same treatment with a repeat delay (about 0.35 s first repeat, then 0.08 to 0.12 s) if you want it; many games accept D-pad only inside dense grids. Add `currentColumns` to the grid API (it is the `columns` local). Whatever you do, in `bind` set the cell's selected look from `index == selectedIndex`, never from whether the instance is selected.

---

## 6. Images, previews and memory

- **Icons, not ViewportFrames, in cells.** A ViewportFrame per cell renders a 3D scene per cell. Even virtualised, 30 visible viewports are expensive on phones. Render icons offline ([[Icon and Thumbnail Rendering Pipeline]]) and use one ViewportFrame in the detail pane for the selected item.
- **Image loading pops.** A recycled cell changing `Image` shows blank until the texture loads. Preload the first screen's icons when the game starts (`ContentProvider:PreloadAsync` on a list of image ids or instances), not every icon in the game. For the rest, a neutral rarity-coloured backdrop in the cell hides the pop better than a spinner.
- **Atlas small icons** if you have hundreds: one sheet with `ImageRectOffset`/`ImageRectSize` per icon means one texture for many cells ([[Textures Decals and Texture Memory]]). The trade-off is a harder upload pipeline and that changing one icon re-uploads the sheet.
- **Do not destroy and recreate the grid on every open.** Keep it alive and hidden; rebuilding the pool on each open costs the creation spike every time. Destroy it only when memory matters more (for example, when the player leaves a lobby for a match).

---

## 7. Getting the inventory to the client

The UI can only be as fast as its data arrives. Two patterns:

| Pattern | When | Cost |
|---|---|---|
| **Snapshot then deltas** over a RemoteEvent | Most games | One larger message on join, then small `{key, count}` updates |
| **Replicated folder of values or attributes** | Small inventories (under ~100 entries) | Simple, but thousands of instances replicate slowly and cost memory on both sides |

For snapshot then deltas:

- Send the snapshot **after the client says it is ready**, not in `PlayerAdded`, so it is not lost before the client's listener connects.
- Make deltas **idempotent and versioned**: each carries a sequence number; the client ignores anything older than what it has. If a gap is detected (seq jumps by more than 1), ask for a fresh snapshot rather than guessing.
- Keep the snapshot compact: send definition ids and counts, not names, icons or descriptions, which the client already has in a shared definitions module. For very large inventories, pack into a `buffer` ([[Buffers and Binary Data]]).
- Measure the snapshot in the Developer Console network stats ([[Developer Console and Stats]], [[Network Performance]]). There is no reason a 2,000-item snapshot should exceed a few tens of KB if ids are short.

### Storage caps are a design decision

A DataStore key holds up to 4 MB (Roblox docs, as of October 2026), which sounds unlimited until you store per-item metadata (rolls, enchant data, timestamps, trade history) for unique items. Long before that limit, large profiles slow saves and loads. Set an explicit cap on unique items (with clear UI: "Backpack 480 / 500") and a stacking rule for duplicates. A cap you design for is better than one players hit in production. See [[Data Schema Design and Migrations]] and [[Tools and Inventory Systems]].

---

## 8. Animation inside virtualised lists

- **Entrance staggers** only make sense on open, and only for the first visible screen. Cells that scroll in later appear instantly; animating them while scrolling looks like lag.
- **Never tween a cell's `Position`.** The virtualiser writes it on every rebind; a running tween will override it for its duration and the cell will drift to the wrong slot. Animate an inner "Face" frame (`UIScale`, transparency) instead.
- **Cancel in-flight tweens on rebind.** A "count increased" pop playing on a cell that gets recycled will finish on the new item. Keep a reference per cell and cancel it in `bind` (or check the bound key when the tween completes).

Motion tokens and the reasons behind them are in [[UI Motion Language and Timing]].

---

## 9. How the reference project framed it

The reference project's backpack was a fixed 1160 x 720 panel scaled to fit 84% by 80% of the screen (ignoring the top inset), with tabs, a search box, a filter and live-updating cards. The lessons that carried over:

- Tabs (weapons, armour, materials) cut each list to a size where virtualisation was rarely needed; tabs are the cheapest virtualisation.
- Live updates (counts, equipped state) rebound one card, not the list.
- Rarity polish (colour strips, glows) lived inside the card face, so recycling a card only meant swapping colours from a theme table ([[UI Design Systems]]).

---

## Common mistakes

| Mistake | How to spot it | Fix |
|---|---|---|
| Rebuilding all cards on any change | Hitch when one item's count changes | Rebind only the affected index |
| State stored on the cell | Wrong item looks selected or "new" after scrolling | Store state by item key; apply in `bind` |
| Connecting events inside `bind` | One click triggers many handlers | Connect once at creation; read an attribute |
| Unstable sort | Grid shuffles when equipping | Unique final tiebreaker |
| Pattern search on player input | Error when the player types `%` | `string.find(s, q, 1, true)` |
| Layout object in a virtualised scroller | Cells jump or stack in one corner | Remove the layout; position manually |
| Computing metrics while hidden | One column, nothing shows | Compute after visible, or on size change |
| ViewportFrame per cell | Low fps while the inventory is open | Static icons; one preview viewport |
| Snapshot sent in `PlayerAdded` | Empty inventory on slow joins | Client requests snapshot when ready |
| No inventory cap | Saves slow down for top players | Cap unique items; stack duplicates |

---

## Checklist

- [ ] Items stacked where possible; unique-item cap designed and shown in UI.
- [ ] Under ~100 entries: plain layout. Over ~300 or growing: virtualised.
- [ ] View array built by filter then sort, with a unique tiebreaker.
- [ ] Search uses plain find and is debounced.
- [ ] Cells pooled; only newly visible indices are bound; `bind` skips unchanged signatures.
- [ ] Selection and badges are data, keyed by item, applied in `bind`.
- [ ] Gamepad navigation handled by index, scrolling the target into view.
- [ ] Icons are images (preloaded for the first screen); one preview viewport.
- [ ] Inventory synced by snapshot on client ready, then sequenced deltas.
- [ ] Tested with a 2,000-item fake inventory on a low-end phone.

## See also

[[UI Layout Objects - Lists Grids and Pages]], [[Tools and Inventory Systems]], [[Menu Archetypes - Shop Settings Codes Rewards]], [[Gamepad and Console UX]], [[ScreenGui Fundamentals]], [[UI Motion Language and Timing]], [[Network Performance]], [[Data Schema Design and Migrations]], [[Genre Playbook - RNG and Collection Games]], [[Mobile and Low-End Optimization]]

## Connected notes
<!-- auto-links:start -->
[[Cookbook - UI]] · Debugging UI Layout and Input · Plugin UI with DockWidgets · Grid Placement and Player Building Systems · AvatarEditorService and In-Game Avatar Editors
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Inventory QoL - Sort Filter Search Stack and Lock]] · [[Settings Menu Design for Roblox - Layout, Controls and Motion]] · [[Layout - Scale Offset and Constraints]] · [[Drag-and-Drop Inventories and Sliders with UIDragDetector]] · [[Designing Roblox UI in Figma - Frames, Safe Areas and Tokens]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[Declarative UI - React-Lua and Fusion]] · [[Figma to Roblox UI - Pipeline and Handoff]] · [[HUD Design]]
<!-- related:end -->
