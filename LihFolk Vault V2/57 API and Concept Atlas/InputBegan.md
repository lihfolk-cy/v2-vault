---
tags: [atlas, api, type/atlas, area/ui, area/studio, api/InputBegan]
---
# InputBegan

<!-- tldr:start -->
> [!tldr] TL;DR
> - `InputBegan` does not capture mouse wheel movement; read the wheel through `InputChanged`.
> - Detect: `rg -n "InputBegan|BindAction|GetControls\(\)"` in new code.
> - For gameplay buttons (attack, jump, ability), react to the press: `InputBegan` on the button, or a `ContextActionService`...
> - ContextActionService / custom: connect the button's `InputBegan`/`InputEnded` to the same handler the keyboard uses.
>
> Cost: TL;DR ~140 tok · whole note ~460 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`InputBegan` does not capture mouse wheel movement; read the wheel through `InputChanged`. (from [[UserInputService - Engine Reference Card]])

API snapshot: member of `GuiObject`, `PluginGui`, `UserInputService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Detect: `rg -n "InputBegan|BindAction|GetControls\(\)"` in new code. ([[AI Pitfalls - UI and Input]])
- For gameplay buttons (attack, jump, ability), react to the press: `InputBegan` on the button, or a `ContextActionService` action, which receives `Enum.UserInputState.Begin`. ([[Input Responsiveness Buffering and Coyote Time]])
- ContextActionService / custom: connect the button's `InputBegan`/`InputEnded` to the same handler the keyboard uses. ([[Mobile Button Layout Editor]])

## Mentioned in

13 notes in 9 sections. The 13 most relevant are linked:

### 01 Studio and Workflow
[[Plugins - Using and Writing]]

### 05 UI and UX
[[Designing Roblox UI in Figma - Frames, Safe Areas and Tokens]] · [[Drag-and-Drop Inventories and Sliders with UIDragDetector]] · [[Input - UserInputService and ContextActionService]] · [[Touch Gestures - Pinch, Pan, Swipe and Long Press]]

### 15 AI Tools
[[AI Pitfalls - UI and Input]]

### 23 Debugging Deep Dives
[[Debugging UI Layout and Input]]

### 39 Studio Plugins and Tooling
[[Plugin UI with DockWidgets]]

### 47 Game Feel and Juice
[[Input Responsiveness Buffering and Coyote Time]]

### 51 2D Game Development
[[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

### 58 Player QoL and Game Tweaks
[[Mobile Button Layout Editor]] · [[Rebinding Controls with the Input Action System]]

### 62 Engine Reference Cards
[[UserInputService - Engine Reference Card]]

<!-- atlas:generated -->
