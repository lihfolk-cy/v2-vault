---
tags: [atlas, api, type/atlas, area/gameplay, area/world, api/ForceField]
---
# ForceField

<!-- tldr:start -->
> [!tldr] TL;DR
> - ForceField is animated and view-dependent; good for shields and holograms, poor for architecture.
> - Players killed instantly at spawn: No protection -> ForceField or server flag.
> - ForceField ignored: Damage sets `Health` directly -> Check in the damage function.
> - Attacking ends protection. When the protected player deals damage, remove their ForceField immediately.
>
> Cost: TL;DR ~130 tok · whole note ~460 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

ForceField is animated and view-dependent; good for shields and holograms, poor for architecture. (from [[Materials MaterialVariants and SurfaceAppearance]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Players killed instantly at spawn: No protection -> ForceField or server flag. ([[Quick Respawn and Spawn Protection]])
- ForceField ignored: Damage sets `Health` directly -> Check in the damage function. ([[Quick Respawn and Spawn Protection]])
- Attacking ends protection. When the protected player deals damage, remove their ForceField immediately. ([[Spawn Points Safe Zones and Respawn Flow]])
- Spawn invulnerability is not universal. The ForceField only protects against damage that uses `TakeDamage` or checks for ForceFields (Docs). ([[Characters and Humanoids]])

## Mentioned in

12 notes in 8 sections. The 12 most relevant are linked:

### 06 World Building and Art
[[Art Budgets - Triangles Draw Calls Memory]] · [[Materials MaterialVariants and SurfaceAppearance]]

### 07 Lighting VFX and Audio
[[Highlights and Selection Effects]]

### 09 Gameplay Systems
[[Characters and Humanoids]] · [[Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations]] · [[Spawning Teams and Rounds]]

### 24 Worked Builds
[[Weekend Build - Arena Shooter with Server-Checked Hits]]

### 33 Level Design
[[Combat Arena and Encounter Layout]] · [[Spawn Points Safe Zones and Respawn Flow]]

### 46 Resource Library
[[Links - Checkpoints and spawning]]

### 54 Untextured Stylised Modelling
[[Lighting Untextured Art in Roblox]]

### 58 Player QoL and Game Tweaks
[[Quick Respawn and Spawn Protection]]

<!-- atlas:generated -->
