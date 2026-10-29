---
tags: [atlas, api, type/atlas, area/animation, area/world, api/PrimaryPart]
---
# PrimaryPart

<!-- tldr:start -->
> [!tldr] TL;DR
> - PrimaryPart is nil until you set it; Roblox characters set it to HumanoidRootPart.
> - Avoid: MoveTo without a PrimaryPart. Symptom: an unpredictable root part is used; set PrimaryPart first.
> - Set PrimaryPart (or WorldPivot) deliberately for every movable model.
> - Egg model names match `PetConfig.Eggs` keys; each egg has a ProximityPrompt and a PrimaryPart.
>
> Cost: TL;DR ~130 tok · whole note ~590 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

PrimaryPart is nil until you set it; Roblox characters set it to HumanoidRootPart. (from [[Model - Engine Reference Card]])

API snapshot: member of `Model` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: MoveTo without a PrimaryPart. Symptom: an unpredictable root part is used; set PrimaryPart first. ([[Model - Engine Reference Card]])
- Set PrimaryPart (or WorldPivot) deliberately for every movable model. ([[Model - Engine Reference Card]])
- Egg model names match `PetConfig.Eggs` keys; each egg has a ProximityPrompt and a PrimaryPart. ([[Pet Hatching and Following End to End]])
- Avoid: parenting a prompt to a Model with no PrimaryPart. ([[ProximityPrompt - Engine Reference Card]])

## Mentioned in

29 notes in 13 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[CollectionService Patterns]]

### 03 Architecture and Networking
[[Instance Streaming]] · [[Network Ownership]]

### 06 World Building and Art
[[Foliage Props and Scatter]] · [[Grid Placement and Player Building Systems]] · [[Modeling in Blender for Roblox]] · [[Parts Unions and MeshParts]]

### 08 Animation
[[Custom Characters and StarterCharacter]] · [[Custom Rigs - Weapons and Props]] · [[Importing Models and Rigs]] · [[Pipeline - Importing Animated Enemies]] · [[Pipeline - New Animated Weapon]]

### 09 Gameplay Systems
[[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]]

### 14 3D Modeling
[[Exporting and Validating Models for Roblox]] · [[Modeling Weapons and Props]] · [[Modular Environment Kits]]

### 15 AI Tools
[[AI Code Assistants for Luau]]

### 16 MCP and Agents
[[MCP Workflows for Building Worlds]]

### 24 Worked Builds
[[Pet Hatching and Following End to End]] · [[Round-Based Minigame Loop End to End]]

### 43 Genre Systems End to End
[[Racing Laps and Checkpoints End to End]] · [[Tower Defense Waves and Placement End to End]]

### 62 Engine Reference Cards
[[Model - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[ProximityPrompt - Engine Reference Card]]

Also mentioned in (not linked): Selection Editing and Bulk Tools · Skill - Roblox Asset Import · Tween and CFrame Animation of Objects · Weapon Design Rig Builder

<!-- atlas:generated -->
