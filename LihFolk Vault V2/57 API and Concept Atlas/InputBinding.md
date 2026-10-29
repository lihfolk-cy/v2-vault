---
tags: [atlas, api, type/atlas, area/accessibility, area/ui, api/InputBinding]
---
# InputBinding

<!-- tldr:start -->
> [!tldr] TL;DR
> - `InputBinding` has `Deadzone` and `ResponseCurve` properties (Roblox API); test their behaviour before relying on them.
> - One `InputBinding` per device family per action: give each a stable name like `KBM`, `Gamepad`, `Touch`.
> - `InputBinding`: one hardware mapping. (Input - UserInputService and ContextActionService)
> - Input Action System: set the action's touch `InputBinding.UIButton` to your `GuiButton` (Roblox docs), so pressing it drives...
>
> Cost: TL;DR ~150 tok · whole note ~410 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`InputBinding` has `Deadzone` and `ResponseCurve` properties (Roblox API); test their behaviour before relying on them. (from [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- One `InputBinding` per device family per action: give each a stable name like `KBM`, `Gamepad`, `Touch`. ([[Rebinding Controls with the Input Action System]])
- `InputBinding`: one hardware mapping. ([[Input - UserInputService and ContextActionService]])
- Input Action System: set the action's touch `InputBinding.UIButton` to your `GuiButton` (Roblox docs), so pressing it drives the same `InputAction` as the keyboard key. ([[Mobile Button Layout Editor]])

## Mentioned in

10 notes in 7 sections. The 10 most relevant are linked:

### 05 UI and UX
[[Input - UserInputService and ContextActionService]]

### 15 AI Tools
[[AI Pitfalls - UI and Input]]

### 25 Physics and Vehicles
[[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]]

### 42 Accessibility and Inclusive Design
[[Input Remapping and One-Handed Play]] · [[Onboarding Accessibility and Cross-Device Prompts]]

### 49 Roblox Platform Features
[[Server Authority and Input Migration 2026]]

### 58 Player QoL and Game Tweaks
[[Controller Support QoL]] · [[Mobile Button Layout Editor]] · [[Rebinding Controls with the Input Action System]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
