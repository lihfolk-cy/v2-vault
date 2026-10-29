---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/FloorMaterial]
---
# FloorMaterial

<!-- tldr:start -->
> [!tldr] TL;DR
> - `FloorMaterial` works for parts and terrain alike, which is one reason to keep part materials meaningful even under a...
> - Avoid: Using `FloorMaterial` for grounded -> Server raycast.
> - grounded = `FloorMaterial ~= Air` and a solid-floor check of five short downward rays where at least one hit has `Normal.Y >=...
> - Wrong: `FloorMaterial ~= Air` as "grounded" for gameplay refills; `Humanoid.WalkSpeed` checks on the server as anti-speed...
>
> Cost: TL;DR ~150 tok · whole note ~560 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`FloorMaterial` works for parts and terrain alike, which is one reason to keep part materials meaningful even under a MaterialVariant: the sound system reads the base material. (from [[Terrain Deep Dive - Materials Water and Performance]])

`FloorMaterial` gives the base `Enum.Material` only. (from [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]])

API snapshot: member of `Humanoid` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Using `FloorMaterial` for grounded -> Server raycast. ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]])
- grounded = `FloorMaterial ~= Air` and a solid-floor check of five short downward rays where at least one hit has `Normal.Y >= 0.55`;. ([[Characters and Humanoids]])
- Wrong: `FloorMaterial ~= Air` as "grounded" for gameplay refills; `Humanoid.WalkSpeed` checks on the server as anti-speed; assuming every character uses Humanoid movement. ([[AI Pitfalls - Physics and Animation]])
- Safe-spot filter. `FloorMaterial ~= Air` says the character is on something, not that the something is safe. ([[Kill Planes, Map Boundaries and Out-of-Bounds Recovery]])

## Mentioned in

13 notes in 10 sections. The 13 most relevant are linked:

### 03 Architecture and Networking
[[Exploits and Anti-Cheat]]

### 06 World Building and Art
[[Terrain Deep Dive - Materials Water and Performance]]

### 07 Lighting VFX and Audio
[[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]]

### 08 Animation
[[Custom Locomotion Controller Design]] · [[Locomotion Systems]]

### 09 Gameplay Systems
[[Characters and Humanoids]] · [[Custom Character Controllers]]

### 15 AI Tools
[[AI Pitfalls - Networking and Security]] · [[AI Pitfalls - Physics and Animation]]

### 22 Anti-Exploit and Security
[[Detecting Movement Exploits - Speed Fly Noclip Teleport]]

### 33 Level Design
[[Kill Planes, Map Boundaries and Out-of-Bounds Recovery]]

### 44 Materials and Surfaces
[[MaterialService and Custom Materials]]

### 49 Roblox Platform Features
[[Server Authority and Input Migration 2026]]

<!-- atlas:generated -->
