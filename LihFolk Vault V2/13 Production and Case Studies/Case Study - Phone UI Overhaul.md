---
tags: [case-study, ui, mobile, phone, responsive, testing, production, type/case-study, area/production, level/intermediate, api/UserInputService, area/ui]
---
# Case Study: Phone UI Overhaul

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Testing on one mock viewport only.
> - Avoid: Pixel offsets inside scale-sized frames.
> - Avoid: Forgetting the top bar inset.
> - One phone definition (touch plus short side) and one scale rule.
> - Every screen has a phone arrangement or an explicit "fits as is" mark.
> - Desktop values stored and restored exactly.
>
> Cost: TL;DR ~120 tok · whole note ~3.4k tok. Read more: ## Approach 3: real phone layouts (the following days) · ## Bugs the checker found · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most Roblox players are on phones, and most Roblox UI is designed on a desktop monitor. This case study follows one live action game (the reference project) from "the desktop UI, scaled down" to real phone layouts for every screen, with automated checks that prove nothing overlaps and every button is big enough to tap. It covers the three approaches tried, why the first two were not enough, the framework that worked, the bugs it found, and the numbers.

General technique lives in [[Responsive UI for Phone Tablet Console and PC]], [[Layout - Scale Offset and Constraints]] and [[Safe Areas and Insets]]. This note is about the production path.

## Starting point

The game had many full-screen menus (inventory with several tabs, shop, crafting and upgrade screens, quests, settings, daily rewards, collection index, pets, trading, move list) plus a busy HUD (currency, boosts, ability bar, quest tracker, touch combat buttons, a tutorial pointer). All were built at a 1920 x 1080 reference size, with pixel offsets inside scaled panels.

## Approach 1: scale everything (first week)

The first mobile pass was a single `ScreenScaler`: on phones, every ScreenGui got a `UIScale` so the desktop layout fitted the screen. It was checked on one mock viewport (a landscape phone of about 844 x 390) only.

Why it was not enough:

- **Text shrank below readability.** A label authored at 14 px on a 1080-tall design, scaled to a 390-tall screen, draws at about 5 px.
- **Tap targets shrank below finger size.** A 40 px desktop button becomes about 15 px.
- **One mock is not a test.** The project's known-issues list carried "mobile layout checked only on one phone mock: worth a real-device check" for weeks.

## Approach 2: zoom and pan (weeks later)

The next pass ("make phone text bigger") zoomed each open panel until its smallest text drew at 12 px, up to 1.0 overall, and let the player pan the panel with a one-finger drag, with edge bars to show more content. HUD elements got per-element boosts.

It made text readable and was fast to apply to every screen at once. Its problems:

- A panel bigger than the screen is a panel players do not finish reading.
- Panning conflicts with scrolling lists inside the panel.
- Buttons near the edge are off-screen until you pan.

It was a good stopgap and the right call for a first day, but it was explicitly retired the same week.

## Approach 3: real phone layouts (the following days)

The framework that stuck had three parts.

### Part 1: one definition of "phone" and one scale rule

```lua
--!strict
local UserInputService = game:GetService("UserInputService")

local PhoneLayout = {}

PhoneLayout.SHORT_SIDE_MAX = 520 -- below this short side, with touch, we use phone layouts
PhoneLayout.PANEL_H = 430        -- every phone panel is designed W x 430 units
PhoneLayout.MIN_TAP = 54         -- design target; the checker accepts 44 px
PhoneLayout.GAP = 10

function PhoneLayout.isPhone(viewport: Vector2): boolean
	return UserInputService.TouchEnabled and math.min(viewport.X, viewport.Y) < PhoneLayout.SHORT_SIDE_MAX
end

-- Scale so a 430-unit-tall panel fills 97% of the screen height; width follows the screen.
function PhoneLayout.panelScale(viewport: Vector2): (number, number)
	local s = 0.97 * viewport.Y / PhoneLayout.PANEL_H
	local width = viewport.X / s -- panel width in design units at this scale
	return s, width
end

return PhoneLayout
```

Measured results: at 844 x 390 the scale is about 0.880 and the panel is about 930 units wide; at 667 x 375 the scale is about 0.846 and the panel about 764 units wide. Every phone panel is designed for "W x 430" with W between about 760 and 930, which is a narrow enough range to design for directly.

The "touch and short side under 520" rule matters: a small desktop window is not a phone (no touch), and a tablet's short side is well above 520. See [[Responsive UI for Phone Tablet Console and PC]].

### Part 2: per-screen phone arrangements, with exact restore

Each screen got a phone arrangement function. Common patterns:

| Desktop pattern | Phone arrangement |
|---|---|
| Side-by-side list and detail | List full width; detail opens as a full-panel page with a BACK button |
| Tab row | Horizontal scrolling strip |
| Chips and categories | Horizontal strip |
| Wide card grid | Fewer, bigger cards per row via the card's UIScale |
| Preview stage beside info | Preview page, then info page |
| Long single column | One scroll, bigger text |

The critical design rule: **store the desktop layout before changing anything, and restore it exactly** when the device changes (rotation, window resize in Studio's device emulator, or a test round trip). The framework stored position, size, visibility and parent per touched element as attributes, and restored from them.

```lua
--!strict
-- Store once, apply phone values, restore exactly. Attributes hold the desktop values.
local function store(g: GuiObject)
	if g:GetAttribute("DeskPos") == nil then
		g:SetAttribute("DeskPos", g.Position)
		g:SetAttribute("DeskSize", g.Size)
		g:SetAttribute("DeskVisible", g.Visible)
	end
end

local function restore(g: GuiObject)
	local pos, size, vis = g:GetAttribute("DeskPos"), g:GetAttribute("DeskSize"), g:GetAttribute("DeskVisible")
	if typeof(pos) == "UDim2" then g.Position = pos end
	if typeof(size) == "UDim2" then g.Size = size end
	if typeof(vis) == "boolean" then g.Visible = vis end
end

local function place(g: GuiObject, pos: UDim2, size: UDim2)
	store(g)
	g.Position = pos
	g.Size = size
end
```

Screens that already fitted (code entry, community prompts) got a static attribute marking them as phone-ready so the zoom fallback skipped them. Screens migrated one by one; the zoom fallback stayed alive only for screens not yet migrated, and was disabled once all were done.

### Part 3: an automated phone checker

The piece that made the overhaul trustworthy was a Studio harness that tested phone layouts without a phone and without Play mode:

1. Clone each screen into a container frame placed far off-screen (x = -20000) and sized to a phone viewport (844 x 390 and 667 x 375).
2. Run the screen's real phone arrangement code on the copy.
3. Walk every visible GuiObject and measure: text size as actually drawn (for `TextScaled` text, the size the engine computes), tap target size for buttons, gaps between siblings, overlaps between interactive elements, anything outside the panel.
4. Restore to desktop and compare against the original (the "round trip" must be exact).
5. Destroy the copies.

```lua
--!strict
-- Core measurements used by the checker (absolute values are valid once the copy is laid out).
local function rect(g: GuiObject): (Vector2, Vector2)
	return g.AbsolutePosition, g.AbsolutePosition + g.AbsoluteSize
end

local function overlaps(a: GuiObject, b: GuiObject): boolean
	local a0, a1 = rect(a)
	local b0, b1 = rect(b)
	return a0.X < b1.X and b0.X < a1.X and a0.Y < b1.Y and b0.Y < a1.Y
end

local function tooSmallToTap(b: GuiButton, minPx: number): boolean
	return b.AbsoluteSize.X < minPx or b.AbsoluteSize.Y < minPx
end

local function drawnTextSize(t: TextLabel | TextButton | TextBox): number
	-- TextScaled text: TextBounds reflects the size the engine actually drew
	if t.TextScaled then
		local lines = math.max(1, select(2, string.gsub(t.ContentText, "\n", "")) + 1)
		return t.TextBounds.Y / lines
	end
	return t.TextSize
end
```

The approximation for scaled text (bounds height divided by line count) assumes no wrapping; a wrapped scaled label reports a smaller per-line size than real, which errs on the safe side. Also note that `AbsoluteSize` includes the effect of ancestor `UIScale`s, which is what you want for "what a finger touches".

Pass criteria at the end of the overhaul (measured): all text at least 12 px, all taps at least 44 px, gaps at least 8 px, zero overlaps, zero elements outside, desktop round trip exact, across about two dozen screens at both phone sizes. A companion **GUI audit** scored every screen out of 10 for visual defects (fill painting past rounded corners, double strokes, nested rounding, uneven rows, off-centre captions) at desktop and phone sizes, averaging 10.00 over more than 80 screen views after fixes. A **HUD overlap check** placed every HUD element in several scenarios (combat, boss bar, lobby, dock open) at 5 viewports and reported intersections: zero.

## Bugs the checker found

| Bug | Cause | Fix |
|---|---|---|
| The armour page was never arranged on phones; its parts sat up to 654 px outside the panel | After a tab was removed, a list of pages was built as `ipairs({ root:FindFirstChild("AbilityPage"), root:FindFirstChild("ArmorPage") })`; the first lookup returned nil and `ipairs` stopped there, silently skipping the armour page | Look pages up by name in a loop; the checker had the same skip and was fixed too |
| Combat buttons overlapping (slide on top of attack) | Only one button was separated in the final layout pass | Separate every combat button in a fixed order with rounded-up pushes |
| Folded side rail sat on top of the hotbar and touch controls | Rail centred on the right edge | On phones, the rail becomes one row top-right at the height of the boost pill |
| Top elements half under the Roblox top bar | Slots started at y = 0 | Every top-down slot starts below the inset ([[Safe Areas and Insets]]) |
| Boss bar met the stamina bar on short phones | Fixed size | The boss bar shrinks to fit |

The `ipairs` bug is worth remembering on its own:

```lua
-- WRONG: ipairs stops at the first nil, so a missing page hides every page after it
for _, page in ipairs({ root:FindFirstChild("AbilityPage"), root:FindFirstChild("ArmorPage") }) do
	arrange(page)
end

-- RIGHT: iterate names, skip the missing ones
for _, name in { "AbilityPage", "ArmorPage" } do
	local page = root:FindFirstChild(name)
	if page then arrange(page) end
end
```

## Input on phones is part of the UI

Two gameplay changes came out of the phone work:

- **Sprint on move.** On touch, players now sprint the moment they move; the separate touch run toggle was removed. Holding a sprint button while steering with a thumbstick is a two-thumb task phones do badly.
- **Ability bar for touch.** The touch bar scale went from 1.7 to 1.9, giving about 44.6 px taps at 667 x 375 (measured), with key labels shown per device (number keys on keyboard, button names on gamepad, none on touch).

See [[Input - UserInputService and ContextActionService]] and [[Gamepad and Console UX]].

## What it cost

The overhaul ran over about five days of a UI workstream, interleaved with other UI work. The biggest costs were not layout code: they were screens whose content was built at runtime (cards, lists), which the checker could only test through static copies and stand-ins, and screens owned by other workstreams that had their own phone hooks to call in the right order.

## Lessons

1. **Scaling is not a phone layout.** It shrinks text and taps below usable size.
2. **Zoom-and-pan is a stopgap.** Ship it to buy time; retire it on a schedule.
3. **Design phone panels at one fixed height** (here 430 units) so W is the only variable.
4. **Store and restore desktop values exactly**; the round trip is a test.
5. **Automate the mechanical checks**: text size as drawn, tap size, gaps, overlaps, outside, round trip, at two or more phone sizes.
6. **Run the checker after every UI change**, including changes that "only remove" something; the worst bug came from a removal.
7. **Change input, not just layout**: sprint on move, bigger touch bars.

## Common mistakes

- Testing on one mock viewport only.
- Pixel offsets inside scale-sized frames.
- Forgetting the top bar inset.
- Building lists of lookups with `ipairs`.
- Letting each screen invent its own phone behaviour.

## Checklist

- [ ] One phone definition (touch plus short side) and one scale rule.
- [ ] Every screen has a phone arrangement or an explicit "fits as is" mark.
- [ ] Desktop values stored and restored exactly.
- [ ] Checker: text >= 12 px, taps >= 44 px, gaps >= 8 px, 0 overlaps, 0 outside, exact round trip, at 2+ sizes.
- [ ] HUD overlap check across scenarios and viewports.
- [ ] Real-device test before release.

## See also

- [[Responsive UI for Phone Tablet Console and PC]], [[UI Layout Objects - Lists Grids and Pages]], [[HUD Design]], [[UI Design Systems]]
- [[Mobile and Low-End Optimization]], [[Accessibility]]
- [[UI and GUI Animation]] (Animation section)
- [[Post-Mortem - Building a Melee Action Game]], [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[UI Asset Pipeline]] · Skill - Roblox UI Builder · Debugging UI Layout and Input · Cookbook - UI · Safe Area · Readable Text and UI Scale
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Debugging UI Layout and Input]] · [[AI Pitfalls - UI and Input]] · [[Team Roles and Workflows]] · [[Case Study - Fast Join and Deferred Loading]] · [[Case Study - Instance Cleanup and Place Size]] · [[Release Process and Rollbacks]] · [[Documentation and Knowledge Bases]] · [[Case Study - Enemy Roster Rebuild]] · [[Planning and Scoping a Roblox Game]] · [[Working with AI Assistants in Studio]]
<!-- related:end -->
