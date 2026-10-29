---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/ChangeState]
---
# ChangeState

<!-- tldr:start -->
> [!tldr] TL;DR
> - ChangeState works from a LocalScript when the client owns the character, or from the server when the server owns it.
> - Humanoid state is decided by the owner. `Humanoid:ChangeState` only works on the owner, and `SetStateEnabled` does not replicate.
> - Humanoid state calls (`ChangeState`) only work on the owner; `SetStateEnabled` does not replicate.
>
> Cost: TL;DR ~130 tok · whole note ~390 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

ChangeState works from a LocalScript when the client owns the character, or from the server when the server owns it. (from [[Humanoid - Engine Reference Card]])

API snapshot: member of `Humanoid` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Humanoid state is decided by the owner. `Humanoid:ChangeState` only works on the owner, and `SetStateEnabled` does not replicate. ([[Network Ownership]])
- Humanoid state calls (`ChangeState`) only work on the owner; `SetStateEnabled` does not replicate. ([[Replication and Ownership]])

## Mentioned in

14 notes in 8 sections. The 14 most relevant are linked:

### 03 Architecture and Networking
[[Network Ownership]]

### 08 Animation
[[Humanoid States and Animation]] · [[Ragdolls and Physics-Based Animation]] · [[Replication and Ownership]] · [[Snippets - Ragdoll]]

### 09 Gameplay Systems
[[Characters and Humanoids]] · [[Combat Systems Architecture]] · [[Mover Constraints and Physics Controllers]] · [[Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run]]

### 29 Luau Cookbook
[[Cookbook - Players and Characters]]

### 47 Game Feel and Juice
[[Input Responsiveness Buffering and Coyote Time]]

### 49 Roblox Platform Features
[[Engine and API Changes 2025-2026]]

### 58 Player QoL and Game Tweaks
[[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]]

### 62 Engine Reference Cards
[[Humanoid - Engine Reference Card]]

<!-- atlas:generated -->
