---
tags: [atlas, api, type/atlas, area/ui, area/design, api/ContextActionService]
---
# ContextActionService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ContextActionService` is not deprecated (only its `BindActionToInputTypes` method is superseded) and remains common in...
> - `ContextActionService:GetAllBoundActionInfo()` lists every CAS action with its inputs and priority (Docs): print it when "the...
> - `ContextActionService:BindAction(name, handler, createTouchButton, ...inputTypes)` binds inputs to a handler; bindings form a...
> - The block action uses `ContextActionService` with an on-screen touch button.
>
> Cost: TL;DR ~160 tok · whole note ~900 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ContextActionService` is not deprecated (only its `BindActionToInputTypes` method is superseded) and remains common in existing code. (from [[Input - UserInputService and ContextActionService]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `ContextActionService:GetAllBoundActionInfo()` lists every CAS action with its inputs and priority (Docs): print it when "the key does nothing". ([[Input - UserInputService and ContextActionService]])
- `ContextActionService:BindAction(name, handler, createTouchButton, ...inputTypes)` binds inputs to a handler; bindings form a stack where the most recently bound handler for an input runs first. ([[Input Remapping and One-Handed Play]])
- The block action uses `ContextActionService` with an on-screen touch button. ([[Melee Combat System End to End]])
- ContextActionService / custom: connect the button's `InputBegan`/`InputEnded` to the same handler the keyboard uses. ([[Mobile Button Layout Editor]])

## Mentioned in

48 notes in 23 sections. The 25 most relevant are linked:

### 05 UI and UX
[[Gamepad and Console UX]] · [[Input - UserInputService and ContextActionService]] · [[ScreenGui Fundamentals]] · [[Touch Gestures - Pinch, Pan, Swipe and Long Press]] · [[Virtualized Lists and Large Inventories]]

### 06 World Building and Art
[[Grid Placement and Player Building Systems]]

### 09 Gameplay Systems
[[Custom Character Controllers]]

### 15 AI Tools
[[AI Pitfalls - UI and Input]]

### 23 Debugging Deep Dives
[[Debugging UI Layout and Input]]

### 24 Worked Builds
[[Melee Combat System End to End]]

### 25 Physics and Vehicles
[[Aircraft and Flight Models]] · [[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]]

### 26 Community and Moderation
[[Working with Content Creators]]

### 42 Accessibility and Inclusive Design
[[Input Remapping and One-Handed Play]]

### 46 Resource Library
[[Links - Input services]]

### 47 Game Feel and Juice
[[Input Responsiveness Buffering and Coyote Time]]

### 49 Roblox Platform Features
[[Server Authority and Input Migration 2026]]

### 51 2D Game Development
[[Choosing GUI 2D or Locked-Camera 2.5D]] · [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

### 56 Field Notes
[[Hold-to-Attack Input That Never Sticks]] · [[ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab]] · [[Shift-Lock Sprint and Gamepad B for Menus]]

### 58 Player QoL and Game Tweaks
[[Mobile Button Layout Editor]] · [[Rebinding Controls with the Input Action System]]

Also mentioned in (not linked): 00 Start Here · 2D Collision Physics and Platformer Movement · Accessibility Start Here · Cameras and Cutscenes · Case Study - Phone UI Overhaul · Colourblind Palettes Text Size and Tooltips · Cookbook - UI · Drag-and-Drop Inventories and Sliders with UIDragDetector · Field Notes Start Here · First-Time User Experience and Onboarding · Functions Closures and Upvalues · Genre Playbook - Battlegrounds and Arena Fighters · Genre Playbook - Shooters FPS and TPS · Genre Playbook - Sports · HUD Design · Input Buffering · Notification and Toast Systems · Onboarding Accessibility and Cross-Device Prompts · Open Questions - Whole Vault · Player QoL Start Here · Stance and Charge Moves · Teaching Through Level Design · Tools and Inventory Systems

<!-- atlas:generated -->
