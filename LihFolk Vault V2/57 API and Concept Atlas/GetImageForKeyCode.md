---
tags: [atlas, api, type/atlas, area/ui, area/platform, api/GetImageForKeyCode]
---
# GetImageForKeyCode

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetImageForKeyCode` returns an image appropriate to the connected controller type, so PlayStation players see PlayStation...
> - PlayStation players see Xbox glyphs: Custom glyph sheet -> `GetImageForKeyCode` (Controller Support QoL)
> - Fallback for any system: `UserInputService:GetImageForKeyCode(keyCode)` gives platform-specific gamepad images, and...
> - Button prompts match the device: `InputActionLabel` for Input Action System bindings, otherwise...
>
> Cost: TL;DR ~160 tok · whole note ~340 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetImageForKeyCode` returns an image appropriate to the connected controller type, so PlayStation players see PlayStation glyphs (Roblox docs). (from [[Controller Support QoL]])

API snapshot: member of `UserInputService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- PlayStation players see Xbox glyphs: Custom glyph sheet -> `GetImageForKeyCode` ([[Controller Support QoL]])
- Fallback for any system: `UserInputService:GetImageForKeyCode(keyCode)` gives platform-specific gamepad images, and `GetStringForKeyCode` gives keyboard strings (Docs). ([[Input - UserInputService and ContextActionService]])
- Button prompts match the device: `InputActionLabel` for Input Action System bindings, otherwise `UserInputService:GetStringForKeyCode()` or `GetImageForKeyCode()`. ([[Console and VR Release Checklists]])

## Mentioned in

5 notes in 3 sections. The 5 most relevant are linked:

### 05 UI and UX
[[Gamepad and Console UX]] · [[Input - UserInputService and ContextActionService]]

### 49 Roblox Platform Features
[[Console and VR Release Checklists]]

### 58 Player QoL and Game Tweaks
[[Controller Support QoL]] · [[Rebinding Controls with the Input Action System]]

<!-- atlas:generated -->
