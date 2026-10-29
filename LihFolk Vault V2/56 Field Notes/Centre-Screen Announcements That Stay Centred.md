---
tags: [field-notes, ui, announcements, layout, queue, notifications, luau, type/guide, area/ui, level/intermediate, api/AnchorPoint, area/scripting]
---
# Centre-Screen Announcements That Stay Centred

<!-- tldr:start -->
> [!tldr] TL;DR
> - Message sits right of centre on some devices: Offset from a width measured on another container -> `AnchorPoint (0.5, 0.5)` and scale 0.5
> - Off-centre by half the label width: `AnchorPoint` left at (0, 0) -> Centre anchor
> - Wrong after phone rotation: Width measured once at startup -> Scale positions recompute automatically
> - Announcements anchored at (0.5, 0.5) and positioned by scale.
> - Parent is a full-screen frame in its own `ScreenGui`.
> - Vertical position clears the top bar on phones.
>
> Cost: TL;DR ~170 tok · whole note ~1.7k tok. Read more: ## 1. Centre by scale, never by a width measured elsewhere · ## 2. One centre slot, one queue · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Big centre-screen messages ("Boss defeated", "Level up", "Zone unlocked") are the loudest UI a game has, so two failures are very visible: the message sits a little right of centre on some screens, and two messages arrive at once and draw on top of each other. Both have simple fixes: position by scale, and send every announcement through one centre slot with a queue. Toast systems for smaller messages are in [[Notification and Toast Systems]]; layout rules in [[Layout - Scale Offset and Constraints]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. Centre by scale, never by a width measured elsewhere

**Measured.** In the reference project, announcements were positioned at `UDim2.fromOffset(lane.AbsoluteSize.X / 2, y)`, where `lane` was a container measured in another part of the GUI. On some devices the message drifted right of centre. Ways this shape goes wrong (rule of thumb; any one is enough):

- The measured container was not the announcement's parent, so its width and origin differed (a side panel, a safe-area inset, a different `ScreenGui` with other inset settings).
- The width was measured once at startup, before layout settled or before a phone rotated.
- `AnchorPoint` was left at (0, 0), so the label's *left edge* sat at the centre, pushing it right by half its own width.

The fix is to let the engine centre it:

```lua
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.fromScale(0.5, 0.28) -- centre horizontally, upper third vertically
```

Scale positions are relative to the **parent's** size at every frame, so rotation, resizing and different devices all stay correct with no code. Parent the announcement to a full-screen frame in its own `ScreenGui` so "the parent" is the screen.

Vertical placement needs one more consideration: Roblox's top bar. `GuiService.TopbarInset` gives the rectangle the top bar occupies (Roblox docs), and `ScreenGui.ScreenInsets` controls whether your GUI is laid out inside device safe areas. Keep announcements in the upper third but below the top bar; a scale position around 0.25 to 0.3 works on phones and PC (rule of thumb), and `TopbarInset` lets you push it lower if your top bar is unusually tall.

## 2. One centre slot, one queue

Without a queue, a boss kill that triggers "Boss defeated", "Level up" and "Quest complete" in the same frame draws three overlapping texts. Every system that wants the centre of the screen must go through one module that owns the slot.

```lua
-- Client: Announcer. The only code that writes to the centre slot.
local TweenService = game:GetService("TweenService")

local Announcer = {}

type Item = { text: string, priority: number, duration: number, key: string? }

local queue: { Item } = {}
local showing = false
local MAX_QUEUE = 4

local slot: TextLabel -- set in Announcer.init

local function playNext()
	local item = table.remove(queue, 1)
	if not item then
		showing = false
		return
	end
	showing = true
	slot.Text = item.text
	slot.TextTransparency = 1
	slot.Visible = true
	TweenService:Create(slot, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
	task.delay(item.duration, function()
		local out = TweenService:Create(slot, TweenInfo.new(0.2), { TextTransparency = 1 })
		out.Completed:Once(function()
			slot.Visible = false
			playNext()
		end)
		out:Play()
	end)
end

function Announcer.init(label: TextLabel)
	slot = label
	slot.AnchorPoint = Vector2.new(0.5, 0.5)
	slot.Position = UDim2.fromScale(0.5, 0.28)
	slot.Visible = false
end

function Announcer.show(text: string, priority: number?, duration: number?, key: string?)
	local item: Item = { text = text, priority = priority or 0, duration = duration or 2, key = key }
	-- Drop duplicates of something already waiting.
	for _, q in queue do
		if (key and q.key == key) or q.text == text then
			return
		end
	end
	-- Higher priority goes first among waiting items; equal priority keeps arrival order.
	local index = #queue + 1
	for i, q in queue do
		if item.priority > q.priority then
			index = i
			break
		end
	end
	table.insert(queue, index, item)
	-- Keep the queue short: drop the lowest-priority item (the last one).
	while #queue > MAX_QUEUE do
		table.remove(queue)
	end
	if not showing then
		playNext()
	end
end

return Announcer
```

Rules of thumb for the queue:

- **Short queue.** Four waiting items at most. Old announcements are stale; showing "Level up" twelve seconds late is worse than not showing it.
- **Shorten under load.** When more than two are waiting, reduce each duration (for example to 1.2 s) so the backlog clears quickly.
- **Merge, don't stack.** Three "+1 level" messages become one "Level 14" message if a key is shared; update the waiting item instead of adding another.
- **Small stuff goes elsewhere.** Coins, pickups and minor quest steps belong in the toast lane, not the centre slot. The centre is for moments ([[Reward Moments and Celebrations]]).

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Message sits right of centre on some devices | Offset from a width measured on another container | `AnchorPoint (0.5, 0.5)` and scale 0.5 |
| Off-centre by half the label width | `AnchorPoint` left at (0, 0) | Centre anchor |
| Wrong after phone rotation | Width measured once at startup | Scale positions recompute automatically |
| Overlapping messages | Several systems write to the centre | One announcer module and queue |
| Messages arrive long after the event | Unbounded queue | Cap the queue, shorten durations under load |

## Checklist

- [ ] Announcements anchored at (0.5, 0.5) and positioned by scale.
- [ ] Parent is a full-screen frame in its own `ScreenGui`.
- [ ] Vertical position clears the top bar on phones.
- [ ] One module owns the centre slot; all systems call it.
- [ ] Queue capped, deduplicated, prioritised, and faster under load.
- [ ] Minor messages routed to toasts, not the centre.

## Connected notes
<!-- auto-links:start -->
[[Notification and Toast Systems]] · Layout - Scale Offset and Constraints · Safe Area · Reward Moments and Celebrations · [[Shared Close Buttons and Headers Across Many Screens]] · [[Field Notes Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Notification Queues and Limits]] · [[Safe Areas and Insets]] · [[HUD Design]] · [[Safe Area]] · [[Debugging UI Layout and Input]] · [[Streaming Joins - Frozen Players and Loading Screen Teardown]]
<!-- related:end -->
