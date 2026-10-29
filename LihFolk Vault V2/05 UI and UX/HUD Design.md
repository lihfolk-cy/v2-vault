---
tags: [ui, hud, layout, overlap, popups, mobile, type/guide, area/ui, level/intermediate, area/design]
---
# HUD Design

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Hand-positioned HUD elements added feature by feature.
> - Avoid: Checks with their own copy of positions (they drift from the game).
> - Avoid: Popups with no queue and no gating (celebrations over death screens).
> - A zone map agreed before building.
> - Every stackable element is a slot row; the checker runs the game's placement code.
> - 0 overlaps at five viewports and every scenario.
>
> Cost: TL;DR ~140 tok · whole note ~3.8k tok. Read more: ## 2. The overlap problem · ## 3. Popup arbitration · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The HUD is the UI that is always on: currencies, the main action button, navigation into menus, objectives, boosts, health and the transient things (toasts, reward banners, damage numbers) that compete for the same screen. Unlike a menu, it shares the screen with gameplay, so every pixel it uses is a pixel the player cannot see the world through, and on a phone it shares that space with the player's thumbs. This note covers HUD zones, a slot system that prevents overlaps by construction, popup arbitration, unlock gating, and motion and performance budgets, with the reference project's numbers.

Sources: the **reference project** (one production game whose HUD went through several redesigns with automated overlap checking; numbers measured there), **Docs** where engine behaviour is cited, and **rule of thumb**. Device strategy is in [[Responsive UI for Phone Tablet Console and PC]]; insets in [[Safe Areas and Insets]].

---

## 1. Zones

Players scan a screen in predictable places, and genres converge on similar maps. A common simulator / action layout, which the reference project ended up with:

| Zone | Contents | Notes |
|---|---|---|
| Top-left | Roblox top bar (not yours), then settings row aligned to it | Never put critical info under the top bar |
| Top-centre | Boost pill (active boosts with timers), goal card under it | Short-lived status; tooltips on hover/tap |
| Left edge | Navigation rail: a 2-wide grid of square buttons (Store, Upgrades, Quests, Items, Rebirth, Forge, Worlds, Index) | Badges for "something new" |
| Bottom-left | Currency stack (rebirths, gems, cash with rate) | Under the rail on phones |
| Bottom-centre | Primary action bar: Backpack, a giant Roll button, Auto toggle | The one thing the player presses most |
| Right edge | A dock of tabs (Rewards, Quests, Settings, Profile) opening side panels | Folds to a single top-right row on phones |
| Bottom-right (touch) | Movement / combat buttons | Reserved for Roblox's jump button and your combat cluster |

Rules of thumb:

- **One giant primary action.** If the core loop is "press Roll", the Roll button is the biggest thing on the HUD and sits where the thumb or the eye rests. Everything else is smaller.
- **Navigation is grouped**, not scattered. A rail of identical squares reads as "menus live here".
- **Status is near the top, actions near the bottom.** Thumbs reach the bottom; eyes check the top.
- **Leave the centre third clear** for the world, except for short-lived feedback.

---

## 2. The overlap problem

HUDs break by accretion. Each feature adds one element positioned by hand: a quest tracker at the right, a boost row at the top, a boss bar, an elite bar, a tutorial banner, a toast lane. Each looks fine alone at 1920 x 1080. Together, on a 667 x 375 phone during a boss fight with the quest dock open, three of them are on top of each other.

The reference project's fix was structural: **a slot system** plus **an automated overlap check**.

### Slots

Every transient or stackable HUD element is declared in one table with a direction, an order and flags. A layout controller places them in order, each below (or above) the previous visible one, with a fixed gap:

```lua
--!strict
-- ReplicatedStorage/HudSlots: one place declares who stacks where.
export type Slot = {
	name: string,         -- ScreenGui or object name
	dir: number,          -- 1 = stacks downward from the top, -1 = upward from the bottom
	fit: boolean?,        -- may shrink (UIScale) if the lane is too short
	belowInset: boolean?, -- start under Roblox's top bar
}

local HudSlots = {}

HudSlots.GAP = 8 -- px between stacked elements

HudSlots.TOP = {
	{ name = "BoostPill", dir = 1, belowInset = true },
	{ name = "NextGoal", dir = 1, fit = true },
	{ name = "BossBar", dir = 1, fit = true },
	{ name = "EliteBar", dir = 1, fit = true },
	{ name = "Banners", dir = 1 },
} :: { Slot }

HudSlots.RIGHT_BOTTOM = {
	{ name = "QuestTracker", dir = -1, fit = true },
	{ name = "Toasts", dir = -1 },
} :: { Slot }

return HudSlots
```

```lua
--!strict
-- Place a column of slots top-down; shrink 'fit' slots if the lane runs out.
local GuiService = game:GetService("GuiService")

local function placeColumn(objects: { [string]: GuiObject }, slots: { any }, top: number, bottomLimit: number, gap: number)
	local y = top
	for _, slot in slots do
		local obj = objects[slot.name]
		if obj and obj.Visible then
			if slot.belowInset then
				y = math.max(y, GuiService.TopbarInset.Max.Y + gap)
			end
			local scale = obj:FindFirstChild("SlotScale") :: UIScale?
			local h = obj.AbsoluteSize.Y / (if scale then scale.Scale else 1)
			local room = bottomLimit - y
			if slot.fit and scale then
				scale.Scale = math.clamp(room / h, 0.55, 1)
				h *= scale.Scale
			end
			obj.AnchorPoint = Vector2.new(0.5, 0)
			obj.Position = UDim2.new(0.5, 0, 0, y)
			y += h + gap
		end
	end
end
```

(The real controller also handled direction -1, re-ran on `Visible` and `AbsoluteSize` changes, and exported the same function for the checker.)

Measured outcomes: boss bars on short phones drew at 0.64 to 0.72 scale in the boss scenario instead of colliding with the stamina bar; a new "Next Goal" card was added as one slot row and never collided with anything.

### The checker

The overlap check places every HUD element **with the same placement code** in five viewports (1920 x 1080 down to 667 x 375) and several scenarios (lobby, combat, boss bar, quest dock open, tutorial fight), then counts intersecting rectangles. A separate tap check measures every touch target's drawn size. Both had to return 0 before any HUD change was considered done. Rule: **adding a HUD element means adding a slot row and a checker scenario**, never a hand position.

---

## 3. Popup arbitration

Transient UI is the real source of HUD chaos: level-up banners, rare drop reveals, quest completions, gift notices, "boss has spawned", tutorial steps. Without arbitration two of them play at once, or one appears mid-cutscene, or a celebration plays over a death screen.

The reference project routed all of them through two pieces:

- **A centre stage queue**: celebrations enqueue; one plays at a time in a reserved lane. Banners fit the lane (shrinking to at most 0.55) and wait up to 8 s for a taller lane before falling back to the middle.
- **A popup gate**: rules that defer popups. None during the tutorial; wait out cutscenes, death (plus 8 s after any death, then a 20 s gap after a death before the next one, and a minimum 15 s alive), a finale screen, or any open panel, for up to 20 s; the daily greeting waits 20 s after the tutorial finishes.

```lua
--!strict
-- Minimal popup queue with gating rules.
type Popup = { kind: string, play: () -> () } -- play yields until the popup is finished

local queue: { Popup } = {}
local running = false
local blockers: { [string]: boolean } = {} -- "tutorial", "cutscene", "dead", "panel"

local Popups = {}

function Popups.block(reason: string, on: boolean)
	blockers[reason] = if on then true else nil
end

local function blocked(): boolean
	return next(blockers) ~= nil
end

local function pump()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #queue > 0 do
			local waited = 0
			while blocked() and waited < 20 do -- wait out blockers for at most 20 s
				waited += task.wait(0.25)
			end
			local p = table.remove(queue, 1)
			if p then
				p.play()
			end
		end
		running = false
	end)
end

function Popups.enqueue(p: Popup)
	-- merge duplicates of the same kind that are still waiting
	for _, q in queue do
		if q.kind == p.kind then
			return
		end
	end
	table.insert(queue, p)
	pump()
end

return Popups
```

### Numbers and toasts

Floating numbers ("+250", "-38") are pooled (cap 12 live at once in the reference project) and same-kind numbers within 0.55 s merge into one ("+250" and "+250" become "+500") rather than stacking into an unreadable column. See [[Game Feel and Juice]].

---

## 4. Unlock gating and progressive disclosure

A new player's HUD should be nearly empty, and grow as features become relevant.

What the reference project's tutorial does:

- **Hide everything not needed by the current step.** The bottom bar shows only the Roll button on the roll step, only Backpack on the equip step, nothing on the walk step. Auto-roll, the settings circles and proximity prompts stay off until the tutorial is done. The dock's tab bar and the boost pill hide during the tutorial; the quest tracker stays hidden until onboarding is complete.
- **Show locked features as locked**, with the condition, once the player could plausibly want them: a lock veil and "Unlocks in Zone 4".
- **Badge sparingly.** A red dot on the rail means "you can do something useful here now" (claimable reward, affordable upgrade), not "this exists".
- **Point, then get out of the way.** The tutorial hand sits on top of everything ([[DisplayOrder]] 205), glides between targets, and the spotlight (a dark cut-out with a pulsing outline) lives at 204. Targets are found by a dedicated attribute (`TutHook`), not by name, so redesigns do not break the tutorial.

A related lesson: a feature that is only reachable from a hidden HUD element is a broken feature. A free gift button once sat in a hidden top-right container, so quests requiring players to collect the gift could never be completed. Every quest or tutorial target needs a visible route.

See [[First-Time User Experience and Onboarding]] and [[Progression Levels and Unlocks]].

---

## 5. Phone HUD

Specific changes the reference project made for phones (more in [[Responsive UI for Phone Tablet Console and PC]]):

- The rail wraps 2 wide by 4 high; secondary squares move into other menus. A 3-wide rail collided with the hotbar and boss bar at 667 x 375.
- The right dock folds to a single row of tabs at the top right, at the boost pill's height, showing only visible tabs. Previously it was a vertical column centred on the right edge, on top of the touch combat cluster.
- Open panels hide the HUD on phones; desktop keeps it with no blur.
- Small buttons get invisible 48 px tap pads that forward presses.
- HP and stamina bars draw 1.85 times larger on phones, with 15 px labels on 30 px bars.
- Captions are set so they draw at no less than 12.5 px after scaling.
- The quest tracker folds by default on phones into a small 70 x 96 tab, and shows two rows at most on screens under 420 px tall.
- Every touch combat button is separated by a final pass over real rectangles.

---

## 6. Primary action buttons

The main button deserves extra care:

- **Size.** Big enough to hit without looking (the reference project's Roll button is the largest element; its plate gaps are kept even, 27/26 px at 1080p and 13/13 at 667 x 375, and the group is centred within 1 px on all five viewports).
- **Anchoring relative to the bar, not the screen.** The auto toggle once drifted onto the Roll button at other resolutions because it was placed with absolute offsets measured at 1080p. It is now positioned from the bar's bottom-centre (`UDim2.new(0.5, dx, 1, dy)`) and re-placed whenever the slot's `AbsolutePosition` or `AbsoluteSize` changes.
- **State visible at a glance.** Auto-roll ON animates (dice rocking plus or minus 12 degrees, a dot pulsing 22 to 27 px every 0.45 s) using looping tweens, with a 0.2 s ease back to rest when turned off, and is still for reduced-motion players.
- **Keyboard and gamepad equivalents** shown as hints ([[Input - UserInputService and ContextActionService]]).

---

## 7. Motion and performance budgets

HUDs are on screen 100% of the time, so their cost is paid every frame:

- **No idle per-frame code.** The reference project's motion module uses one `RenderStepped` connection that exists only while a spring is moving; idle HUD has zero per-frame Lua. A later performance pass also gated the tutorial controller's render loop off when nothing was showing and cut a quest timer to 4 updates per second, writing text only when it changed.
- **Looping tweens over loops.** Idle life (bobbing icons, breathing glows) runs as engine tweens with `RepeatCount = -1`, which cost far less than Lua per frame.
- **Write only on change.** Currency labels update when values change, not every frame. Every write invalidates the `ScreenGui`'s cached appearance ([[ScreenGui Fundamentals]]).
- **Separate the busy from the static.** Constantly animated HUD pieces in their own small `ScreenGui`.
- **Hover is cheap, celebrations are budgeted.** Hover: scale 1.06 and a 3 px lift. Celebrations: queued, one at a time.

---

## 8. Information design

- **Show rates, not just totals,** where they drive decisions: "$12.4K/s" under the cash total.
- **Boosts with timers** in one pill, with a tooltip for details (multiplier, source, remaining time) and a toast when one starts.
- **Show the truth.** Luck displays included every active multiplier ("incl. charm x2") and the cap for the current area; odds shown were true per-roll odds at the player's current luck. Players notice when HUD numbers disagree with outcomes.
- **One objective at a time** for new players (a "Next Goal" card with a progress bar and a trail in the world), more for experienced players (the quest dock).

---

## Common mistakes

- Hand-positioned HUD elements added feature by feature.
- Checks with their own copy of positions (they drift from the game).
- Popups with no queue and no gating (celebrations over death screens).
- Every feature visible and badged at minute one.
- Features reachable only through a hidden element.
- Absolute pixel offsets for buttons that must sit relative to a bar.
- Idle `RenderStepped` loops for decorative HUD motion.

## Checklist

- [ ] A zone map agreed before building.
- [ ] Every stackable element is a slot row; the checker runs the game's placement code.
- [ ] 0 overlaps at five viewports and every scenario.
- [ ] All popups go through one queue with gating rules.
- [ ] Tutorial shows only what the step needs; targets found by attribute or tag.
- [ ] Phones: folded docks, tap pads, larger bars, 12 px text.
- [ ] No per-frame Lua while the HUD is idle.

See also: [[Safe Areas and Insets]], [[Responsive UI for Phone Tablet Console and PC]], [[Menu Archetypes - Shop Settings Codes Rewards]], [[UI Design Systems]], [[Game Feel and Juice]], [[UI and GUI Animation]], [[First-Time User Experience and Onboarding]], [[Accessibility]].

## Connected notes
<!-- auto-links:start -->
[[Case Study - Phone UI Overhaul]] · Links - Menus, HUDs, inventories and shops · [[Notification and Toast Systems]] · [[Layout - Scale Offset and Constraints]] · Debugging UI Layout and Input · Cookbook - UI
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[UI Asset Pipeline]] · [[Gamepad and Console UX]] · [[UI Layout Objects - Lists Grids and Pages]] · [[UI Motion Language and Timing]] · [[Declarative UI - React-Lua and Fusion]] · [[Touch Gestures - Pinch, Pan, Swipe and Long Press]] · [[Off-Screen Objective Markers and Waypoint Arrows]] · [[Tutorial Step Design Patterns - Teach by Doing]] · [[Virtualized Lists and Large Inventories]]
<!-- related:end -->
