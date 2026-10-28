---
tags: [core-concept, ui, mobile, console, layout]
---
# Safe Area

<!-- tldr:start -->
> [!tldr] TL;DR
> - Most Roblox players are on phones, and phones are where screen edges lie.
> - Backgrounds should ignore the safe area; content should respect it.
> - Thumb reach is a second safe area. On phones the bottom corners are easiest to reach and the top centre is hardest.
> - Orientation changes the shape. A notch is on the left or right depending on which way the phone is turned.
>
> Read more (3 KB note): ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

The **safe area** is the part of the screen where UI can be placed without being covered by hardware (notches, rounded corners, camera cut-outs, home indicators), Roblox's own top bar and buttons, or the overscan edge of a TV. Anything outside it may be hidden or hard to tap.

## Why it matters on Roblox

Most Roblox players are on phones, and phones are where screen edges lie. A shop button in the top-left corner can sit under the Roblox menu buttons; a currency counter in the top-right can sit under a notch in landscape. On console, TVs can crop the outer edge.

Roblox handles this through `ScreenGui.ScreenInsets`: `CoreUISafeInsets` keeps content clear of Roblox's own UI and device cut-outs, `DeviceSafeInsets` clears only the device's unsafe areas, `TopbarSafeInsets` clears the top bar area, and `None` uses the full screen (Roblox docs, "ScreenGui" and "Safe areas", as of October 2026). `GuiService:GetGuiInset()` reports the top bar inset.

## The nuance most people miss

1. **Backgrounds should ignore the safe area; content should respect it.** A full-screen dimmer or a menu backdrop with `ScreenInsets = None` looks right; the buttons on it belong in an inset container. Use two ScreenGuis or a nested frame.
2. **Thumb reach is a second safe area.** On phones the bottom corners are easiest to reach and the top centre is hardest. The jump button and the default thumbstick own the bottom corners; do not put your own buttons on top of them.
3. **Orientation changes the shape.** A notch is on the left or right depending on which way the phone is turned. Test both landscape directions, not only one.
4. **Text near the edge clips first.** Even inside the safe area, leave a margin of a few percent so text does not touch rounded corners.
5. **Studio's device emulator is a start, not proof.** Test on a real notched phone before release.

## Tiny example

```lua
-- Two layers: backdrop fills the screen, content stays safe.
local back = Instance.new("ScreenGui")
back.ScreenInsets = Enum.ScreenInsets.None
back.Parent = playerGui

local content = Instance.new("ScreenGui")
content.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
content.Parent = playerGui
```

## Where this shows up

- [[Safe Areas and Insets]]: the full reference.
- [[Responsive UI for Phone Tablet Console and PC]]: layouts across devices.
- [[HUD Design]]: placing HUD elements.
- [[Case Study - Phone UI Overhaul]]: a real phone layout fix.
- [[Gamepad and Console UX]]: TV overscan.
- [[Layout - Scale Offset and Constraints]]: margins that scale.
- [[Debugging UI Layout and Input]]: diagnosing hidden buttons.
- [[Readable Text and UI Scale]]: text near edges.
- [[Input Remapping and One-Handed Play]]: reach and placement.
- [[Choosing GUI 2D or Locked-Camera 2.5D]]: full-screen 2D games and insets.
- [[Skill - Roblox UI Builder]]: a review checklist that includes safe areas.
- [[Menu Archetypes - Shop Settings Codes Rewards]]: where menu buttons sit.

Related concepts: [[Accessibility Contrast]], [[Onboarding Funnel]], [[Thumbnail Contrast]].

## Connected notes
<!-- auto-links:start -->
[[Cookbook - UI]] · [[Links - Scale vs offset and responsive design]] · [[ScreenGui Fundamentals]] · [[UI Asset Pipeline]] · [[Accessibility Start Here]] · [[LihFolk UI Design System]] · [[Core Concepts Start Here]]
<!-- auto-links:end -->
