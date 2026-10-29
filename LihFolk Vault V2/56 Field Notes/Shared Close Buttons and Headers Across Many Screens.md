---
tags: [field-notes, ui, close-button, layout, clipsdescendants, attributes, design-system, type/guide, area/ui, level/intermediate, api/ZIndex, area/design]
---
# Shared Close Buttons and Headers Across Many Screens

<!-- tldr:start -->
> [!tldr] TL;DR
> - X sizes vary panel to panel: Built by hand per panel -> One helper, sized from the header
> - X tiny on phones, huge on PC: Pixel sizes -> `RelativeYY` scale relative to header height
> - X cut in half: `ClipsDescendants` on header or panel -> Clip only the inner content frame
> - Every panel's X comes from the shared helper.
> - X is square, about 1.1 times the header height, anchored (1, 1) at the header's bottom-right.
> - Overhang recomputed when the header resizes.
>
> Cost: TL;DR ~160 tok · whole note ~1.7k tok. Read more: ## 1. Size and place the X relative to the header · ## 3. One helper, applied everywhere, undoable · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A game with thirty panels built by different people (and different agents) ends up with thirty close buttons: different sizes, some inside the header, some floating at the corner, some half cut off. Players notice inconsistency in the X more than almost anything else, because they use it on every screen. The fix that held up is one shared helper that builds or normalises the X relative to the header, plus attributes that make the change undoable. Layout rules are in [[Layout - Scale Offset and Constraints]]; design systems in [[UI Design Systems]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. Size and place the X relative to the header

**Rule of thumb, used across every panel of the reference project:**

- The X is square, about **1.1 times the header's height**. Slightly bigger than the header reads as a confident, tappable target; smaller than the header looks timid on phones.
- **AnchorPoint (1, 1)**, positioned at the header's **bottom-right corner**, so the X sits flush with the header's bottom edge and pokes above its top by the extra 10%.
- A **slight overhang** to the right (a few percent of the X's own size) so it breaks the panel's outline, the usual cartoon-UI convention.

Expressing "1.1 times the header height" without pixel maths: `SizeConstraint = Enum.SizeConstraint.RelativeYY` makes both scale components relative to the parent's height (Roblox docs), so `Size = UDim2.fromScale(1.1, 1.1)` gives a square 1.1 times the header height on any screen.

```lua
-- Shared helper: build or normalise a panel's close button.
local OVERHANG = 0.12 -- fraction of the X's own size that sticks out to the right

local function storeOriginal(button: GuiObject)
	if button:GetAttribute("PreSize") == nil then
		button:SetAttribute("PreSize", button.Size)
		button:SetAttribute("PrePosition", button.Position)
		button:SetAttribute("PreAnchorPoint", button.AnchorPoint)
		button:SetAttribute("PreParent", button.Parent and button.Parent:GetFullName() or "")
	end
end

local function placeClose(header: GuiObject, button: GuiButton)
	storeOriginal(button)
	button.Parent = header
	button.SizeConstraint = Enum.SizeConstraint.RelativeYY
	button.Size = UDim2.fromScale(1.1, 1.1)
	button.AnchorPoint = Vector2.new(1, 1)

	local function reposition()
		local side = header.AbsoluteSize.Y * 1.1
		button.Position = UDim2.new(1, math.round(side * OVERHANG), 1, 0)
	end
	reposition()
	header:GetPropertyChangedSignal("AbsoluteSize"):Connect(reposition)
end
```

The overhang is an offset because there is no "relative to height" option for `Position`; recomputing it when the header's `AbsoluteSize` changes keeps it proportional on rotation and resize.

## 2. ClipsDescendants pitfalls

The overhang only works if no ancestor clips it. **Measured:** on several panels the X appeared cut in half or missing its top edge, because the header or the panel had `ClipsDescendants = true` for a scrolling list or rounded corners.

- **Clipping cuts the overhang and the input.** A clipped part of a button is not visible and does not receive clicks or taps (rule of thumb), so half the target disappears on phones.
- **Move clipping down a level.** Put `ClipsDescendants` on the inner content frame that actually needs it (the scrolling area), not on the panel or the header.
- **`ScrollingFrame` always clips its contents.** Never parent the X inside one.
- **Rotation is not clipped.** Clipping ignores rotated descendants (see [[Debugging UI Layout and Input]]), so a rotated X can look fine while a sibling is clipped; do not use that as evidence the clipping is right.
- **`ZIndex`**: with the default `ZIndexBehavior.Sibling`, `ZIndex` orders siblings only. Give the X a higher `ZIndex` than any sibling header art (title plate, ribbon) so the overhang draws on top of it.

## 3. One helper, applied everywhere, undoable

Run the helper on every panel at build time (or once as a migration), finding headers by a `CollectionService` tag or a naming convention. Then:

- **Store `Pre*` attributes before changing anything.** `UDim2` and `Vector2` are valid attribute types (Roblox docs), so the original values sit on the button itself. An undo script restores them exactly; it also survives a Studio restart, unlike the undo history.
- **Skip buttons already normalised** (check an attribute such as `CloseNormalised`), so running the migration twice does not drift.
- **Log what changed** (panel path, old size, new size) so a reviewer can spot a header whose height is wrong, which a relative X will faithfully amplify.

```lua
local function undoClose(button: GuiObject)
	local size = button:GetAttribute("PreSize")
	if size == nil then
		return
	end
	button.Size = size
	button.Position = button:GetAttribute("PrePosition")
	button.AnchorPoint = button:GetAttribute("PreAnchorPoint")
	for _, name in { "PreSize", "PrePosition", "PreAnchorPoint", "PreParent" } do
		button:SetAttribute(name, nil)
	end
end
```

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| X sizes vary panel to panel | Built by hand per panel | One helper, sized from the header |
| X tiny on phones, huge on PC | Pixel sizes | `RelativeYY` scale relative to header height |
| X cut in half | `ClipsDescendants` on header or panel | Clip only the inner content frame |
| Top half of X not tappable | Clipped region receives no input | Same |
| Migration cannot be reverted | No record of old values | `Pre*` attributes before every change |

## Checklist

- [ ] Every panel's X comes from the shared helper.
- [ ] X is square, about 1.1 times the header height, anchored (1, 1) at the header's bottom-right.
- [ ] Overhang recomputed when the header resizes.
- [ ] No clipping ancestor above the X; clipping lives on content frames.
- [ ] `Pre*` attributes stored before changes; undo script tested.
- [ ] Checked on a phone emulator in portrait and landscape.

## Connected notes
<!-- auto-links:start -->
[[Layout - Scale Offset and Constraints]] · UI Design Systems · Debugging UI Layout and Input · Cookbook - UI · [[Centre-Screen Announcements That Stay Centred]] · [[Field Notes Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[ScreenGui Fundamentals]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[UIStroke on Text - Glyph Counters and the Stroke Ratio]] · [[Held Weapons on Motor6D - Locking the Grip During Attacks]] · [[Running Many AI Agents on One Roblox Place]] · [[Shift-Lock Sprint and Gamepad B for Menus]]
<!-- related:end -->
