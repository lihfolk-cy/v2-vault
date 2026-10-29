---
tags: [atlas, api, type/atlas, area/ui, area/performance, api/UserInputService]
---
# UserInputService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `UserInputService.ModalEnabled` (hide mobile controls) is superseded by `GuiService.TouchControlsEnabled` (Docs).
> - Every `UserInputService` gameplay handler checks `gameProcessedEvent`.
> - Simulation code is in `BindToSimulation`, uses `time()`, and has no Destroy, reparent, EquipTool or UserInputService calls.
> - The `UserInputService` versions fire for the whole screen, including touches that the default camera and thumbstick are also...
>
> Cost: TL;DR ~150 tok · whole note ~1.2k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`UserInputService.ModalEnabled` (hide mobile controls) is superseded by `GuiService.TouchControlsEnabled` (Docs). (from [[Input - UserInputService and ContextActionService]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Every `UserInputService` gameplay handler checks `gameProcessedEvent`. ([[Input - UserInputService and ContextActionService]])
- Simulation code is in `BindToSimulation`, uses `time()`, and has no Destroy, reparent, EquipTool or UserInputService calls. ([[Server Authority and Input Migration 2026]])
- The `UserInputService` versions fire for the whole screen, including touches that the default camera and thumbstick are also using; check `gameProcessedEvent` and your own UI state before acting. ([[Touch Gestures - Pinch, Pan, Swipe and Long Press]])
- `UserInputService:GetStringForKeyCode(keyCode)` returns the character the player should actually press for a `KeyCode`. ([[Input Remapping and One-Handed Play]])

## Mentioned in

77 notes in 30 sections. The 25 most relevant are linked:

### 05 UI and UX
[[Gamepad and Console UX]] · [[Input - UserInputService and ContextActionService]] · [[Notification and Toast Systems]] · [[Responsive UI for Phone Tablet Console and PC]] · [[Touch Gestures - Pinch, Pan, Swipe and Long Press]]

### 06 World Building and Art
[[Grid Placement and Player Building Systems]]

### 07 Lighting VFX and Audio
[[Game Feel and Juice]]

### 08 Animation
[[Cameras and Cutscenes]]

### 10 Game Design and Genres
[[First-Time User Experience and Onboarding]]

### 12 Performance Testing and Debugging
[[In-Game Bug Report Button with Automatic Context]] · [[Mobile and Low-End Optimization]] · [[UI Automation with VirtualInput and StudioTestService]]

### 13 Production and Case Studies
[[Case Study - Phone UI Overhaul]]

### 15 AI Tools
[[AI Pitfalls - UI and Input]]

### 23 Debugging Deep Dives
[[Debugging UI Layout and Input]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 42 Accessibility and Inclusive Design
[[Input Remapping and One-Handed Play]] · [[Readable Text and UI Scale]]

### 46 Resource Library
[[Links - Input services]]

### 47 Game Feel and Juice
[[Input Responsiveness Buffering and Coyote Time]]

### 51 2D Game Development
[[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

### 56 Field Notes
[[Hold-to-Attack Input That Never Sticks]]

### 58 Player QoL and Game Tweaks
[[Controller Support QoL]] · [[Mobile Button Layout Editor]] · [[Rebinding Controls with the Input Action System]]

Also mentioned in (not linked): 00 Start Here · 2D Collision Physics and Platformer Movement · 2D Multiplayer - Server Authority and Replicating GUI Worlds · A 2D Engine in a ScreenGui - Game Loop Entities and Rendering · Accessibility Start Here · Aim Assist and Generous Hitboxes · Aircraft and Flight Models · Arena Rounds with Teams and Spectating End to End · Camera Settings - FOV Shake Sensitivity and Shift-Lock · Choosing GUI 2D or Locked-Camera 2.5D · Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits · Client Prediction and Reconciliation for Combat · Colourblind Palettes Text Size and Tooltips · Console and VR Release Checklists · Cookbook - UI · Custom Character Controllers · Developer Console and Stats · Drag-and-Drop Inventories and Sliders with UIDragDetector · Emotes and Social Animation · Events Signals and Connections · Field Notes Start Here · First-Person Viewmodels - Arms Rig, Sway and Camera Binding · Functions Closures and Upvalues · Genre Playbook - Battlegrounds and Arena Fighters · Genre Playbook - Shooters FPS and TPS · Genre Playbook - Sports · Graphics and Performance Toggles for Low-End Devices · HUD Design · Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots · Input Buffering · Links - Devices · Making Numbers Feel Good - Cooldowns Buffering and Coyote Time · Melee Combat System End to End · Multi-Seat Vehicles - Driver, Passenger and Gunner Roles · Player QoL Start Here · Plugin UI with DockWidgets · Plugins - Using and Writing · Racing Laps and Checkpoints End to End · ScreenGui Fundamentals · Script Types and Run Context · Server Authority and Input Migration 2026 · Server Authority and Validation · Settings Menu Essentials and Persistence · Shift-Lock Sprint and Gamepad B for Menus · Short-Form Video Marketing · Stance and Charge Moves · Teaching Through Level Design · Testing Modes - Play Run and Multi-Client · Tools and Inventory Systems · Tower Defense Waves and Placement End to End · Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer · Weather Performance Budgets and Quality Tiers

<!-- atlas:generated -->
