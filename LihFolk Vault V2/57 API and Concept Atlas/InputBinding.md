---
tags: [atlas, api, type/atlas, area/accessibility, area/platform, api/InputBinding]
---
# InputBinding

<!-- tldr:start -->
> [!tldr] TL;DR
> - `InputBinding` has `Deadzone` and `ResponseCurve` properties (Roblox API); test their behaviour before relying on them.
> - One `InputBinding` per device family per action: give each a stable name like `KBM`, `Gamepad`, `Touch`.
> - `InputBinding`: one hardware mapping. (Input - UserInputService and ContextActionService)
> - Input Action System: set the action's touch `InputBinding.UIButton` to your `GuiButton` (Roblox docs), so pressing it drives...
>
> Cost: TL;DR ~150 tok · whole note ~460 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`InputBinding` has `Deadzone` and `ResponseCurve` properties (Roblox API); test their behaviour before relying on them. (from [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- One `InputBinding` per device family per action: give each a stable name like `KBM`, `Gamepad`, `Touch`. ([[Rebinding Controls with the Input Action System]])
- `InputBinding`: one hardware mapping. ([[Input - UserInputService and ContextActionService]])
- Input Action System: set the action's touch `InputBinding.UIButton` to your `GuiButton` (Roblox docs), so pressing it drives the same `InputAction` as the keyboard key. ([[Mobile Button Layout Editor]])

## Mentioned in

13 notes in 8 sections. The 13 most relevant are linked:

### 05 UI and UX
[[Input - UserInputService and ContextActionService]]

### 15 AI Tools
[[AI Pitfalls - UI and Input]]

### 25 Physics and Vehicles
[[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]]

### 42 Accessibility and Inclusive Design
[[Input Remapping and One-Handed Play]] · [[Onboarding Accessibility and Cross-Device Prompts]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Server Authority and Input Migration 2026]]

### 58 Player QoL and Game Tweaks
[[Controller Support QoL]] · [[Mobile Button Layout Editor]] · [[Rebinding Controls with the Input Action System]]

### 62 Engine Reference Cards
[[ContextActionService - Engine Reference Card]] · [[UserInputService - Engine Reference Card]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
