---
tags: [atlas, api, type/atlas, area/scripting, area/data, api/BindableEvent]
---
# BindableEvent

<!-- tldr:start -->
> [!tldr] TL;DR
> - `BindableEvent` gives you an engine signal for your own events, on one side of the client/server boundary.
> - BindableEvents copy arguments. Tables passed through a `BindableEvent` arrive as copies without metatables, functions are...
> - The BindableEvent fires with the selected player when the option is used.
> - A connection to a long-lived signal (`RunService.Heartbeat`, `Players.PlayerAdded`, a global BindableEvent) keeps its closure...
>
> Cost: TL;DR ~150 tok · whole note ~720 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`BindableEvent` gives you an engine signal for your own events, on one side of the client/server boundary. (from [[Events Signals and Connections]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- BindableEvents copy arguments. Tables passed through a `BindableEvent` arrive as copies without metatables, functions are dropped, and mixed keys can be lost. ([[Events Signals and Connections]])
- The BindableEvent fires with the selected player when the option is used. ([[Avatar Context Menus Profiles and Social Surfaces]])
- A connection to a long-lived signal (`RunService.Heartbeat`, `Players.PlayerAdded`, a global BindableEvent) keeps its closure alive, which keeps every captured table and Instance alive, until you `Disconnect`. ([[Functions Closures and Upvalues]])
- If you used a `BindableEvent` to pass the table, the listener would receive a copy (bindables serialize tables, Roblox docs), and every change it made would silently vanish. ([[Round-Based Minigame Loop End to End]])

## Mentioned in

27 notes in 18 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Error Handling - pcall xpcall and Promise Patterns]] · [[Events Signals and Connections]] · [[Functions Closures and Upvalues]] · [[Module Scripts and Requiring]]

### 04 Data and Persistence
[[Global State and Live Config]] · [[Session Locking and Profile Libraries]]

### 05 UI and UX
[[Localization]] · [[Responsive UI for Phone Tablet Console and PC]]

### 08 Animation
[[Ability Kits Architecture]] · [[Pipeline - New Animated Weapon]]

### 11 Monetization Publishing and Live Ops
[[Game Passes]]

### 12 Performance Testing and Debugging
[[Mobile and Low-End Optimization]]

### 17 Pipelines
[[Live Content Pipeline]]

### 24 Worked Builds
[[Round-Based Minigame Loop End to End]]

### 35 Advanced Luau
[[Building a Signal Library]] · [[Serialization Formats for Saves and Networking]]

### 41 Multiplayer Services
[[Server Shutdowns Soft Updates and Migration]]

### 42 Accessibility and Inclusive Design
[[Colour-Blind Safe Design]] · [[Motion Sensitivity and Camera Comfort]]

### 49 Roblox Platform Features
[[Avatar Context Menus Profiles and Social Surfaces]]

### 50 Team Collaboration and Project Management
[[Working with Contractors and Revenue Splits]]

### 51 2D Game Development
[[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

### 52 Core Concepts
[[Event Bus]]

### 58 Player QoL and Game Tweaks
[[Block and Mute Respecting Platform Rules]] · [[Settings Menu Essentials and Persistence]]

Also mentioned in (not linked): Links - Remote events and functions · Zone Detection - Area Enter and Exit for Music, Lighting and Ambience

<!-- atlas:generated -->
