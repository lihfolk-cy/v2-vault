---
tags: [atlas, api, type/atlas, area/animation, area/networking, api/SetStateEnabled]
---
# SetStateEnabled

<!-- tldr:start -->
> [!tldr] TL;DR
> - SetStateEnabled changes stay on the side that made them.
> - Avoid: `SetStateEnabled` on the server for a player -> Run it on the client.
> - `SetStateEnabled` does not replicate. (Humanoid States and Animation)
> - Disable unneeded states with `Humanoid:SetStateEnabled()` (for example Climbing, unless NPCs climb).
>
> Cost: TL;DR ~120 tok · whole note ~300 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

SetStateEnabled changes stay on the side that made them. (from [[Humanoid - Engine Reference Card]])

API snapshot: member of `Humanoid` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: `SetStateEnabled` on the server for a player -> Run it on the client. ([[Characters and Humanoids]])
- `SetStateEnabled` does not replicate. ([[Humanoid States and Animation]])
- Disable unneeded states with `Humanoid:SetStateEnabled()` (for example Climbing, unless NPCs climb). ([[Physics Performance]])

## Mentioned in

8 notes in 6 sections. The 8 most relevant are linked:

### 03 Architecture and Networking
[[Network Ownership]]

### 08 Animation
[[Humanoid States and Animation]] · [[Ragdolls and Physics-Based Animation]] · [[Replication and Ownership]]

### 09 Gameplay Systems
[[Characters and Humanoids]]

### 12 Performance Testing and Debugging
[[Physics Performance]]

### 23 Debugging Deep Dives
[[Debugging Physics and Network Ownership]]

### 62 Engine Reference Cards
[[Humanoid - Engine Reference Card]]

<!-- atlas:generated -->
