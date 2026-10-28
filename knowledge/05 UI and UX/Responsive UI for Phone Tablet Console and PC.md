---
tags: [ui, responsive, mobile, phone, tablet, console, cross-platform]
---
# Responsive UI for Phone Tablet Console and PC

Roblox players arrive on 4.7 inch phones, tablets, laptops, ultrawide monitors and living-room TVs, and the same player may switch device between sessions. Mobile is a large share of the audience, so a UI signed off only at Studio's default desktop window is broken for many of your players. This note is about strategy: how to classify devices without guessing, which viewports to test, the measurable rules (text size, tap size, gaps, overlaps) that define "fits", and why the reference project ended up building real phone layouts instead of shrinking or zooming desktop ones.

Sources: **Docs** ("Cross-platform development", `GuiService.ViewportDisplaySize`, `UserInputService.PreferredInput`, styling queries; October 2026), the **reference project** (one production game whose phone UI was rebuilt screen by screen; numbers measured there), and **rule of thumb**.

Mechanics of sizing are in [[Layout - Scale Offset and Constraints]]; notches and the top bar are in [[Safe Areas and Insets]]; gamepad specifics in [[Gamepad and Console UX]].

---

## 1. Classify by capability, not by guessing the device

Roblox does not tell you "this is an iPhone". It tells you capabilities, and you combine them:

| Signal | What it means | Use for |
|---|---|---|
| `Camera.ViewportSize` | Render size in pixels | Layout maths |
| `GuiService.ViewportDisplaySize` | `Small` (most phones, tablets, handhelds), `Medium` (laptops, monitors), `Large` (TVs) (Docs) | Picking a layout family |
| `UserInputService.PreferredInput` | `KeyboardAndMouse`, `Gamepad`, `Touch`, `MicroGamepad`; updates as the player switches (Docs) | Which prompts and controls to show |
| `UserInputService.TouchEnabled` | The device has a touch screen | Not "is a phone": many laptops have touch |

Docs: "attempting to predict screen size by pixels often leads to misinterpretation", and `GuiService:IsTenFootInterface()` is deprecated in favour of `ViewportDisplaySize`.

### The reference project's phone rule

`phone = TouchEnabled and shortSide < 520` (short side of the viewport in pixels). It was chosen because the phones they cared about report 375 to 430 px short sides in landscape (667 x 375, 844 x 390, 932 x 430) while the smallest tablets report 600 or more. An earlier rule (`TouchEnabled and uiScale < 0.75`) mis-classified a touch laptop and missed a large phone, which is why a size threshold on the **short** side replaced it.

A practical device profile combines all of it:

```lua
--!strict
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

export type Profile = {
	kind: "phone" | "tablet" | "desktop" | "tv",
	input: Enum.PreferredInput,
	viewport: Vector2,
	shortSide: number,
}

local PHONE_SHORT_SIDE = 520 -- reference project threshold (px, landscape short side)

local function profile(): Profile
	local camera = Workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
	local short = math.min(vp.X, vp.Y)
	local display = GuiService.ViewportDisplaySize
	local kind: "phone" | "tablet" | "desktop" | "tv"
	if display == Enum.DisplaySize.Large then
		kind = "tv"
	elseif UserInputService.TouchEnabled and short < PHONE_SHORT_SIDE then
		kind = "phone"
	elseif display == Enum.DisplaySize.Small then
		kind = "tablet"
	else
		kind = "desktop"
	end
	return {
		kind = kind,
		input = UserInputService.PreferredInput,
		viewport = vp,
		shortSide = short,
	}
end

local Device = {}
Device.changed = Instance.new("BindableEvent")
Device.current = profile()

local function recompute()
	local p = profile()
	local old = Device.current
	Device.current = p
	if p.kind ~= old.kind or p.input ~= old.input or p.viewport ~= old.viewport then
		Device.changed:Fire(p)
	end
end

UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(recompute)
GuiService:GetPropertyChangedSignal("ViewportDisplaySize"):Connect(recompute)
local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(recompute)
end

return Device
```

Keep layout family (`kind`) and input (`input`) separate. A tablet with a Bluetooth keyboard is a small-screen layout with keyboard prompts. A phone with a gamepad needs selection rings on the phone layout.

---

## 2. The viewports to test

Studio's Device Emulator and Controller Emulator are the baseline tools (Docs). The reference project standardised on a fixed list and ran its automated checks at every one of them:

| Viewport | Represents | Why it is on the list |
|---|---|---|
| 1920 x 1080 | Desktop baseline | Design resolution |
| 1366 x 768, 1024 x 600 | Laptops, small tablets | Where "compact desktop" layouts start |
| 932 x 430 | Large phone | Widest phone; side-by-side layouts fit here |
| 844 x 390 | Common phone | Primary phone target |
| 667 x 375 | Small phone | Worst case; every overlap shows here first |

Plus a notched variant of 844 x 390 (the notch eats width, see [[Safe Areas and Insets]]) and, for TV, 1920 x 1080 with the `Large` display size and gamepad input.

**Landscape only?** Games that lock orientation (the reference project uses landscape sensor) do not need portrait layouts. If you allow portrait (`PlayerGui.ScreenOrientation`), every layout needs a portrait test too, and the phone short side becomes the width.

---

## 3. Define "fits" as numbers, then measure them

"Looks fine" is not testable. These are the reference project's pass criteria (measured on the drawn result, after all scaling):

| Rule | Threshold | Notes |
|---|---|---|
| Smallest drawn text | 12 px | `TextScaled` text measured at the size the engine actually draws |
| Smallest drawn tap target | 44 px (48 for HUD buttons, 54 design units in phone panels) | Invisible tap pads count |
| Gap between tap targets | 8 px | Fat-finger mis-taps below this |
| Overlaps between interactive objects | 0 | At every viewport and scenario |
| Objects outside the screen | 0 | Except deliberate overhangs, listed by name |
| Desktop round trip | 0 differences | Switching phone layout on and off restores desktop exactly |

Docs say only "Do not use MinTextSize values lower than 9". The 12 px floor is stricter on purpose: 9 px is legible on a monitor at arm's length, not on a 375 px tall phone in a moving car.

### Automate it

The reference project wrote three Edit-mode tools, and they paid for themselves within a week:

- **A phone check** lays out each screen's phone arrangement on a copy, off-screen (at x = -20000), at 844 x 390 and 667 x 375, and reports minimum text, minimum tap, minimum gap, overlaps, out-of-bounds objects and the desktop round trip. Copies are always destroyed afterwards.
- **A HUD overlap check** places every HUD element with the same placement code the game uses, across five viewports and several scenarios (lobby, combat, boss bar showing, quest dock open, tutorial running), and counts rectangle intersections. Target: 0.
- **A tap check** measures the drawn size of every touch target, including invisible pads.

The key design decision: **the checks call the real placement code**, not a copy of its numbers. Every time a check had its own copy of the maths, the game and the check drifted apart and the check went green while players saw overlaps.

```lua
--!strict
-- Core of an overlap check: given placed GuiObjects, report intersecting pairs.
local function rectsOverlap(a: GuiObject, b: GuiObject, tolerance: number): boolean
	local ap, as = a.AbsolutePosition, a.AbsoluteSize
	local bp, bs = b.AbsolutePosition, b.AbsoluteSize
	return ap.X + as.X - tolerance > bp.X
		and bp.X + bs.X - tolerance > ap.X
		and ap.Y + as.Y - tolerance > bp.Y
		and bp.Y + bs.Y - tolerance > ap.Y
end

local function findOverlaps(objects: { GuiObject }): { string }
	local hits = {}
	for i = 1, #objects do
		for j = i + 1, #objects do
			local a, b = objects[i], objects[j]
			if a.Visible and b.Visible and rectsOverlap(a, b, 1) then
				table.insert(hits, a:GetFullName() .. " x " .. b:GetFullName())
			end
		end
	end
	return hits
end
```

---

## 4. Four strategies for small screens, ranked by what survived

### 4.1 Shrink (one global UIScale)

Fast, and what most games ship. It fails the 12 px rule as soon as the panel was designed for a monitor: 15 px text at the 667 x 375 scale of 0.347 draws at 5 px. It is fine for elements designed big (a giant roll button, a currency pill).

### 4.2 Zoom and pan

The reference project's first phone pass: on a phone, an open panel zoomed until its smallest authored text drew at 12 px (capped at 1.0 overall), and the player panned the oversized panel with a one-finger drag. It was quick to build for 40 screens and it met the text rule. Players disliked it: half of every panel was off-screen, and dragging a panel competes with scrolling lists inside it. It was **retired** once real layouts existed and is kept only as a reference.

### 4.3 Real phone layouts (what shipped)

Each screen got a second arrangement for phones, applied and removed by code:

- **Fixed panel height, computed scale.** Panels are laid out at `W x 430` design units and scaled by `s = 0.97 * screenHeight / 430`. At 844 x 390 that is `s = 0.880` with `W = 930`; at 667 x 375, `s = 0.846` with `W = 764`. Width comes from the screen's aspect ratio; height is always the full usable height.
- **Minimum tap 54 units, gap 10 units**, so at `s = 0.846` taps draw at about 46 px and gaps at 8.5 px.
- **Pages instead of panes.** Desktop shows list and detail side by side; on phones the detail opens as a full-panel page with a BACK button. On wide phones (an available area of 890 units or more, so 844 x 390 and 932 x 430) the detail card still fits beside the list; on 667 x 375 it becomes a page.
- **Horizontal strips for navigation.** Tabs, filter chips and categories move into horizontal scrolling strips so the main content owns vertical scrolling.
- **Bigger cards, fewer columns.** Cards scale by a per-screen factor (1.37 for shop cards, 1.48 for pet cards) and the grid drops columns.
- **Store, set, restore.** Before applying the phone arrangement, every property it will touch is stored; switching back restores desktop exactly. The automated "round trip" check proves it.

Results across 24 screens: every screen at or above 12 px text, 44 px taps, 8 px gaps, 0 overlaps, 0 round-trip differences.

### 4.4 Separate screens per device family

Building a dedicated phone UI from scratch is the cleanest result and the most expensive to maintain (every feature ships twice). The reference project's approach (one tree, two arrangements) was the compromise: same instances, same names (so tutorials and controllers keep working), different placement.

### Tablets and compact desktops

Tablets landed between: the reference project's backpack used a scale of 0.92 to 1.1 with 50-unit taps on tablets, a static desktop design wherever its 15-unit text still drew at 12 px or more, and a compact desktop variant (scale 0.8) for 1024 x 600 laptops.

---

## 5. Scale by device kind with style queries (engine option)

Roblox's UI styling system supports **style queries**: conditions such as viewport display size and preferred input that switch style tokens without code. Docs mention intrinsic selectors like `@ViewportDisplaySizeSmall` and `@PreferredInputTouch` that let UI "automatically swap tokens for text sizes, container dimensions" and more. If your UI is built on `StyleSheet`s ([[UI Design Systems]]), this is the least-code way to make text and tap sizes larger on small screens. It does not rearrange layouts (pages instead of panes); that still needs code or separate arrangements.

---

## 6. Phone HUD rules

The HUD is where phones hurt most, because the thumb zones (bottom-left movement stick, bottom-right jump and action buttons) and the Roblox top bar take space you cannot use. The reference project's phone HUD rules after its fixes:

- **Hide, do not shrink.** On phones the HUD keeps only what is needed in moment-to-moment play. Secondary squares move into a menu; the right rail of tabs folds into one row at the top right.
- **Panels hide the HUD on phones** (desktop keeps it). A full-height phone panel over a HUD just creates overlaps.
- **Every top-down slot starts below the top bar.** An elite enemy health bar placed at a fixed y sat half under the Roblox top bar on phones. HUD slots gained a "below inset" flag that adds `GuiService.TopbarInset` height.
- **Boss bars shrink to fit** instead of meeting the stamina bar on short phones (scale 0.64 to 0.72 in the boss scenario on phones).
- **Combat buttons are separated by a final real-rectangle pass.** Six touch buttons (attack, dash, throw, slide, run, block) were placed by percentages; on some phones slide sat on attack. A last pass reads every button's actual rectangle and pushes overlapping ones apart.
- **Tap pads.** Small visual buttons get an invisible 48 px `ImageButton` under them that forwards the press.

See [[HUD Design]] for the layout system behind this.

---

## 7. TV and console

- Treat `ViewportDisplaySize.Large` plus gamepad as "ten-foot UI": players sit 2 to 3 m away. Text that is fine at 1080p on a monitor is small on a TV; a rule of thumb is to raise body text by about 1.25 to 1.5x relative to desktop.
- Cap growth: with pure Scale, a 4K TV makes panels enormous (Docs warn about this). Use a `UISizeConstraint` or a scale clamp (the cartoon UI kit clamps at 1.18).
- Everything must be reachable with a gamepad and show a visible selection. See [[Gamepad and Console UX]].
- Older TVs overscan; keep critical UI out of the outer few percent of the screen (rule of thumb, roughly 5%).

---

## 8. Testing workflow that worked

1. Build at 1920 x 1080.
2. Run the automated checks at all five viewports.
3. Look at screenshots at 667 x 375 first: it fails first.
4. Test a notched phone emulation for safe areas.
5. Test with the Controller Emulator for selection.
6. Play on a real phone before release. Emulators do not show thumb occlusion, heat, or how small 12 px really is in your hand.

The reference project's changelog shows the cost of skipping step 6: many phone passes were marked "Edit only, not play-tested", and the "fix phone GUI" pass that followed (folded rail colliding with the touch combat cluster, elite bar under the top bar, overlapping combat buttons) came straight from a player's phone screenshot.

---

## Common mistakes

- `TouchEnabled` used as "is a phone".
- One global `UIScale` with no floor; phone text at 6 px.
- Zoom-and-pan instead of real phone layouts.
- Tap targets that pass on desktop and draw at 30 px on a phone.
- Checks with their own copy of placement numbers (they drift).
- Never testing 667 x 375 or a notched device.
- Signing off phone UI without playing on a phone.

## Checklist

- [ ] Device profile separates layout family from input.
- [ ] Five viewports plus a notched phone in every test pass.
- [ ] Numbers enforced: 12 px text, 44 px taps, 8 px gaps, 0 overlaps.
- [ ] Phone arrangements store and restore desktop exactly.
- [ ] Automated checks call the game's own placement code.
- [ ] HUD hides secondary items on phones; top-down slots start below the top bar.
- [ ] TV text enlarged and growth capped.
- [ ] Played on a real phone.

See also: [[Layout - Scale Offset and Constraints]], [[Safe Areas and Insets]], [[HUD Design]], [[Gamepad and Console UX]], [[Accessibility]], [[Mobile and Low-End Optimization]], [[QA Checklists Before Release]], [[Case Study - Phone UI Overhaul]].

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox UI Builder]] · [[Safe Area]] · [[Cookbook - UI]] · [[Readable Text and UI Scale]] · [[UI Asset Pipeline]] · [[Links - Scale vs offset and responsive design]]
<!-- auto-links:end -->
