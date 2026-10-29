---
tags: [atlas, api, type/atlas, area/physics, area/accessibility, api/InputAction]
---
# InputAction

<!-- tldr:start -->
> [!tldr] TL;DR
> - `InputAction` has `Pressed`, `Released` and `StateChanged` events, `GetState()`, and a read-only `PreferredBinding`.
> - One `InputAction` per mechanic, named stably (`Sprint`, `Dash`, `UseQuickSlot1`).
> - `InputAction`: one mechanic ("Sprint", "Shoot", "CameraRotate").
> - Show the right glyphs. `InputAction.PreferredBinding` tells you which binding matches the active device so hints show "RT" or...
>
> Cost: TL;DR ~140 tok · whole note ~500 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`InputAction` has `Pressed`, `Released` and `StateChanged` events, `GetState()`, and a read-only `PreferredBinding`. (from [[Input Remapping and One-Handed Play]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- One `InputAction` per mechanic, named stably (`Sprint`, `Dash`, `UseQuickSlot1`). ([[Rebinding Controls with the Input Action System]])
- `InputAction`: one mechanic ("Sprint", "Shoot", "CameraRotate"). ([[Input - UserInputService and ContextActionService]])
- Show the right glyphs. `InputAction.PreferredBinding` tells you which binding matches the active device so hints show "RT" or a touch icon correctly. ([[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]])
- Read input from `InputAction` objects, not `UserInputService.InputBegan`. ([[Server Authority and Input Migration 2026]])

## Mentioned in

13 notes in 8 sections. The 13 most relevant are linked:

### 03 Architecture and Networking
[[Client Prediction and Reconciliation for Combat]]

### 05 UI and UX
[[Input - UserInputService and ContextActionService]]

### 15 AI Tools
[[AI Pitfalls - UI and Input]]

### 25 Physics and Vehicles
[[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]]

### 42 Accessibility and Inclusive Design
[[Input Remapping and One-Handed Play]] · [[Onboarding Accessibility and Cross-Device Prompts]]

### 46 Resource Library
[[Links - Input services]]

### 49 Roblox Platform Features
[[Console and VR Release Checklists]] · [[Server Authority and Input Migration 2026]]

### 58 Player QoL and Game Tweaks
[[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]] · [[Mobile Button Layout Editor]] · [[Rebinding Controls with the Input Action System]]

<!-- atlas:generated -->
