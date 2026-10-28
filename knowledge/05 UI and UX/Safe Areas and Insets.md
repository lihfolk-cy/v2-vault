---
tags: [ui, safe-area, screeninsets, topbar, notch, mobile]
---
# Safe Areas and Insets

A phone screen is not a rectangle you fully own. Camera notches, rounded corners and home indicators cut into it, and on every device Roblox's own top bar (menu, chat and other controls) sits in the top-left. Roblox gives each `ScreenGui` a choice of which of these to avoid. Pick wrong and either your buttons hide under a notch, or your full-screen backgrounds and cinematic bars stop short of the edge with a gap the game world shows through.

This note covers `ScreenInsets`, `IgnoreGuiInset`, `ClipToDeviceSafeArea`, `SafeAreaCompatibility`, `GuiService.TopbarInset`, `GetGuiInset` and `GetInsetArea`, then the production cases: a letterbox that would not reach the edges, a health bar under the top bar, and custom buttons aligned with Roblox's.

Sources: **Docs** (ScreenGui, GuiService and the `ScreenInsets` / `SafeAreaCompatibility` enum references, "On-screen UI containers"; October 2026), the **reference project** (one production game), and **rule of thumb**.

---

## 1. The four areas

From largest to smallest:

| Area | What it excludes |
|---|---|
| Fullscreen | Nothing. The whole display, including notch and corners |
| Device safe area | Device cutouts (notch, camera hole, rounded corners, home indicator) |
| Top bar safe area | Device cutouts plus the region taken by the Roblox top bar controls, keeping UI between those controls and the right edge |
| Core UI safe area | Device cutouts plus Roblox core UI (the top bar region and other core UI) |

`ScreenGui.ScreenInsets` (`Enum.ScreenInsets`) picks which area the gui's descendants are laid out in (Docs):

| Value | Laid out in | Docs guidance |
|---|---|---|
| `CoreUISafeInsets` (default) | Core UI safe area | Recommended for interactive UI |
| `DeviceSafeInsets` | Device safe area; no inset for the top bar | Full-height UI that must stay clear of the notch |
| `TopbarSafeInsets` | Between the top bar controls and the right edge of the device safe area; "automatically flex[es] in horizontal size based on the top bar's content" | Custom top-bar rows |
| `None` | Fullscreen | Only for "noninteractive content like background images" |

The key mental model: **a `ScreenGui` with `ScreenInsets` is a smaller virtual screen.** `UDim2.fromScale(1, 1)` means "fill the safe area", not "fill the display". Scale coordinates, `AbsoluteSize` and `AbsolutePosition` of children are relative to that area.

---

## 2. IgnoreGuiInset (the old switch)

Before `ScreenInsets` existed, `IgnoreGuiInset` was the only control. It still works and is coupled to the new property (Docs):

- `IgnoreGuiInset = false` (default): `ScreenInsets` is `CoreUISafeInsets`.
- Setting `IgnoreGuiInset = true` while `ScreenInsets` is `CoreUISafeInsets` switches `ScreenInsets` to `DeviceSafeInsets`.

So `IgnoreGuiInset = true` today means "ignore the top bar, still respect the notch", **not** "fullscreen". Code written years ago that expects `IgnoreGuiInset` to give true fullscreen now gets a notch-sized gap on phones. Set `ScreenInsets` explicitly in new work and treat `IgnoreGuiInset` as legacy. Note also that `IgnoreGuiInset` is tagged not replicated and not saved separately (Docs list it as `can_save: false`); the saved truth is `ScreenInsets`.

---

## 3. ClipToDeviceSafeArea

`ClipToDeviceSafeArea` (default `true`) clips every descendant to the device safe area (Docs). The default exists "to maintain backwards compatibility of UI that is intentionally hidden offscreen", such as panels that slide in from an edge: without clipping, a panel parked just off the safe area would be visible in the notch region.

Two rules:

- It is **ignored** when `ScreenInsets = None` (Docs): choosing fullscreen means you accept cutouts.
- With `ScreenInsets = DeviceSafeInsets` or `CoreUISafeInsets` and clipping on, a deliberate overhang (a background that bleeds past the edge) is cut at the safe area boundary. If you want art to reach the physical edge, you need `None`.

---

## 4. SafeAreaCompatibility: the automatic stretch

`SafeAreaCompatibility` (`None` or `FullscreenExtension`, default `FullscreenExtension`) applies "automatic UI compatibility transformations" to descendants that look fullscreen (Docs). A descendant qualifies when its total area, including border and `UIStroke`, covers the device safe area in both directions. Its **background** is then extended to the full screen; its **content** is not moved or resized, except `ImageLabel`, `ImageButton` and `VideoFrame`, whose image or video is treated specially (Docs).

Why it exists: old games built full-screen backgrounds as `UDim2.fromScale(1, 1)` frames. On notched phones those would stop at the safe area and leave bars of world visible. The extension paints the background out to the edges automatically.

Why it bites: it is a heuristic. A dimmer frame meant to cover only the safe area, or a frame that is "fullscreen" only during an animation, gets extended too. Docs: "it's recommended that you avoid fullscreen extensions for new work; instead, use the `ScreenInsets` property". Set it to `None` on new guis and decide insets yourself.

---

## 5. Reading the insets from code

| API | Returns | Use |
|---|---|---|
| `GuiService.TopbarInset` (Rect, read-only) | The unoccupied area between Roblox's left-most controls and the edge of the device safe area (Docs) | Aligning custom buttons with the top bar; knowing its height |
| `GuiService:GetGuiInset()` | Two `Vector2`s: top-left and bottom-right inset of user GUIs in pixels (Docs) | Legacy maths; prefer the others |
| `GuiService:GetInsetArea(screenInsets)` | A `Rect` of the usable region for that `ScreenInsets` value, relative to the core UI safe area (Docs) | Converting between guis with different insets |

`TopbarInset` changes at runtime: Docs list health changes, `SetCoreGuiEnabled` calls and changes to Roblox controls, and recommend listening with `GetPropertyChangedSignal`. Never cache it once at startup.

The top bar's height is not a constant across devices and client versions. Older code assumed 36 px; the redesigned top bar is taller (commonly reported as 58 px on desktop, unverified; read it live). Hard-coded insets are the most common source of "everything is 22 px too high since the update".

### GetInsetArea example

Docs give an example on a phone: `GetInsetArea(Enum.ScreenInsets.None)` might return `-59, -58, 792, 334`, meaning the fullscreen rectangle starts 59 px left of and 58 px above the core UI safe area's top-left. That is how you place something in a `None` gui so that it lines up exactly with an object in a `CoreUISafeInsets` gui:

```lua
--!strict
local GuiService = game:GetService("GuiService")

-- Convert a point from CoreUISafeInsets space to another gui's inset space.
local function convertPoint(p: Vector2, toInsets: Enum.ScreenInsets): Vector2
	local area = GuiService:GetInsetArea(toInsets) -- relative to the core UI area
	return p - area.Min
end
```

---

## 6. The two-layer pattern

Almost every polished screen needs both edge-to-edge art and safely placed controls. Do not try to get both from one `ScreenGui`. Use two:

```lua
--!strict
local Players = game:GetService("Players")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local function makeLayer(name: string, insets: Enum.ScreenInsets, order: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = insets
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None -- no heuristics
	gui.DisplayOrder = order
	gui.Parent = playerGui
	return gui
end

-- Back layer: art that must reach the physical edges, no interaction.
local back = makeLayer("ShopBackdrop", Enum.ScreenInsets.None, 50)
-- Front layer: everything a finger can touch.
local front = makeLayer("Shop", Enum.ScreenInsets.CoreUISafeInsets, 51)

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.4
dim.Parent = back
```

Open and close both together. The backdrop's `DisplayOrder` is one below the panel's so they move as a pair in your band plan ([[ScreenGui Fundamentals]]).

---

## 7. Case study: the letterbox that would not reach the edge

**Context (reference project).** Rare-weapon ultimates play a short cinematic for the caster: camera moves, a title card and black letterbox bars top and bottom (see [[Cinematic Ultimates]] and [[Cameras and Cutscenes]]).

**What players saw.** On notched phones the bars were inset from the edges with a strip of game world visible between bar and screen edge, and on some devices they were shifted and scaled oddly, so the "cinema" looked broken.

**Causes, all stacked:**

1. The bars' `ScreenGui` used the default `CoreUISafeInsets`, so "full width" meant the safe area's width, and "top" meant below the top bar.
2. `ClipToDeviceSafeArea = true` cut any attempt to overhang.
3. `FullscreenExtension` extended some bars and not others depending on their animated size at the moment.
4. The game's global UI scaler (which applies a device `UIScale` to every gui) also scaled the bars, shrinking them towards their anchor.

**Fix:** the letterbox gui got `ScreenInsets = None`, `SafeAreaCompatibility = None`, `ClipToDeviceSafeArea = false`; the global scaler was told to skip it; and its root's own scale was pinned to 1. The bars are pure Scale (`UDim2.fromScale(1, 0.12)` anchored at the top and bottom edges), so they now touch the physical edges on every device.

**Lesson.** Anything decorative that must touch the screen edge (letterbox, vignette, damage flash, transition wipe, loading cover) goes in a `None` gui that no global scaler touches.

---

## 8. Case study: the health bar under the top bar

**What players saw (reference project).** On phones, the elite-enemy health bar sat half under Roblox's top bar.

**Cause.** The HUD's slot system stacked top-down elements from a fixed y offset tuned on desktop. The project notes record the symptom and the fix, not the exact root cause; the usual mechanism (and the one to check first in your own game) is a gui that ignores the top bar inset (`DeviceSafeInsets` or the old `IgnoreGuiInset = true`, often chosen to win vertical room on short phones), so y = 0 is behind the top bar.

**Fix.** Every top-down HUD slot on phones starts at `TopbarInset.Max.Y` plus a margin (a "below inset" flag on the slot), read live. The hotbar uses the same rule: its top must be at least the top bar's bottom plus the standard edge margin.

---

## 9. Aligning your own buttons with the top bar

Players read the top bar as one row. Custom buttons (settings gear, shop, events) placed in that row look native only if they share its vertical centre and sit to the right of Roblox's controls.

Two approaches:

**A. `TopbarSafeInsets`.** A gui with this inset is the free part of the top bar region and flexes horizontally with Roblox's controls (Docs). Put a horizontal `UIListLayout` in it and your buttons follow the Roblox controls automatically.

**B. Manual alignment from `TopbarInset`.** When the row must live in another gui:

```lua
--!strict
local GuiService = game:GetService("GuiService")

-- Keep a custom row vertically aligned with Roblox's top bar buttons.
local function alignToTopbar(row: GuiObject, buttonSize: number)
	local function apply()
		local inset = GuiService.TopbarInset
		local barHeight = inset.Height
		if barHeight <= 0 then
			-- no top bar reported (some contexts): fall back to a fixed margin
			row.Position = UDim2.new(0, 12, 0, 12)
			return
		end
		row.AnchorPoint = Vector2.new(0, 0.5)
		row.Position = UDim2.new(0, inset.Min.X, 0, inset.Min.Y + barHeight / 2)
		row.Size = UDim2.new(0, math.max(0, inset.Width), 0, buttonSize)
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(apply)
	apply()
end
```

The reference project used a variant of B for its settings row: the row's top padding is `TopbarInset.Height - 46` (46 being its own button height), recalculated live, with a fixed 12 px when no inset is reported. The live part matters: the top bar's content changes when a player's health changes or core UI is toggled, and a padding computed once drifts.

---

## 10. Decision table

| Content | ScreenInsets | ClipToDeviceSafeArea | SafeAreaCompatibility |
|---|---|---|---|
| HUD buttons, menus, anything tappable | `CoreUISafeInsets` | true | None |
| Full-height panel that may use the top-bar band (no interaction near the top-left) | `DeviceSafeInsets` | true | None |
| Custom top-bar buttons | `TopbarSafeInsets` | true | None |
| Backdrops, vignettes, letterbox, fades, loading covers | `None` | (ignored) | None |
| Legacy full-screen art you cannot rebuild yet | `CoreUISafeInsets` | true | `FullscreenExtension` |

---

## 11. Testing safe areas

- Use Studio's Device Emulator with a notched phone profile and both landscape orientations (the notch moves sides).
- Turn on a temporary debug frame in each gui with `Size = UDim2.fromScale(1, 1)` and a bright translucent fill: you see exactly what area that gui thinks it owns.
- Check with the health bar visible and hidden, and with the player list or chat toggled; the top bar region changes.
- Check the cinematic and any full-screen transition on a notched device: those are the ones that show gaps.

---

## Common mistakes

- Treating `IgnoreGuiInset = true` as fullscreen (it is device-safe, not fullscreen).
- Hard-coding the top bar height.
- Reading `TopbarInset` once at startup.
- Interactive buttons in a `None` gui (they end up under the notch).
- Decorative edge art in a safe-area gui (gaps at the edges).
- Letting a global UI scaler touch letterbox or vignette guis.
- Relying on `FullscreenExtension` for new work.

## Checklist

- [ ] Every `ScreenGui` sets `ScreenInsets` explicitly.
- [ ] `SafeAreaCompatibility = None` on new guis.
- [ ] Edge-to-edge art lives in a separate `None` gui, skipped by scalers.
- [ ] Top-down HUD slots start below `TopbarInset` on phones.
- [ ] Custom top-bar buttons use `TopbarSafeInsets` or live `TopbarInset` alignment.
- [ ] Tested on a notched profile in both landscape orientations.

See also: [[ScreenGui Fundamentals]], [[Responsive UI for Phone Tablet Console and PC]], [[HUD Design]], [[Layout - Scale Offset and Constraints]], [[Cinematic Ultimates]], [[Cameras and Cutscenes]].

## Connected notes
<!-- auto-links:start -->
[[Safe Area]] · [[Debugging UI Layout and Input]] · [[Skill - Roblox UI Builder]] · [[Links - Containers]] · [[Cookbook - UI]] · [[Camera Systems]]
<!-- auto-links:end -->
