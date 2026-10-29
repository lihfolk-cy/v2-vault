---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/WalkSpeed]
---
# WalkSpeed

<!-- tldr:start -->
> [!tldr] TL;DR
> - WalkSpeed is client-replicated: a client can change it locally, so validate movement on the server.
> - Avoid: Trusting client-side character properties (`WalkSpeed`, `Health` set locally) as server truth.
> - Heavy slow effects get "fixed": WalkSpeed compared with a constant -> Compare with the expected speed.
> - Anchored root, WalkSpeed, PlatformStand, controls and stale locks handled.
>
> Cost: TL;DR ~140 tok · whole note ~650 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

WalkSpeed is client-replicated: a client can change it locally, so validate movement on the server. (from [[Humanoid - Engine Reference Card]])

API snapshot: member of `Humanoid` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Trusting client-side character properties (`WalkSpeed`, `Health` set locally) as server truth. ([[Cookbook - Players and Characters]])
- Heavy slow effects get "fixed": WalkSpeed compared with a constant -> Compare with the expected speed. ([[A Stuck Player Watchdog That Logs the Cause]])
- Anchored root, WalkSpeed, PlatformStand, controls and stale locks handled. ([[A Stuck Player Watchdog That Logs the Cause]])
- Ground speed in the clip JSON matches the `WalkSpeed` it's played at (foot slide 0) ([[Locomotion and Melee Reference Numbers]])
- Avoid: Effects write `WalkSpeed` or `Health` directly -> Modifiers plus one owner that recomputes. ([[Status Effects Buffs and Stacking Rules]])

## Mentioned in

26 notes in 14 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Luau Type System and Strict Mode]]

### 03 Architecture and Networking
[[Exploits and Anti-Cheat]] · [[Network Ownership]] · [[Replication Rules]]

### 08 Animation
[[Humanoid States and Animation]] · [[Locomotion Readability - Lessons from Blind Panels]] · [[Locomotion and Melee Reference Numbers]] · [[Mounts and Rideable Creatures]] · [[R15 Run Cycle Key Poses]] · [[Snippets - Animation Controller Module]] · [[The Default Animate Script]]

### 09 Gameplay Systems
[[Characters and Humanoids]] · [[Custom Character Controllers]] · [[Mover Constraints and Physics Controllers]] · [[Status Effects Buffs and Stacking Rules]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]]

### 15 AI Tools
[[AI Pitfalls - Networking and Security]]

### 22 Anti-Exploit and Security
[[How Exploits Work - The Client Boundary]]

### 24 Worked Builds
[[Melee Combat System End to End]]

### 29 Luau Cookbook
[[Cookbook - Players and Characters]]

### 43 Genre Systems End to End
[[Horror Monster Chase AI End to End]]

### 49 Roblox Platform Features
[[Engine Limits, Quotas and Defaults - Cheat Sheet]]

### 56 Field Notes
[[A Stuck Player Watchdog That Logs the Cause]]

### 58 Player QoL and Game Tweaks
[[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]]

### 62 Engine Reference Cards
[[Humanoid - Engine Reference Card]]

Also mentioned in (not linked): Open Questions - Whole Vault

<!-- atlas:generated -->
