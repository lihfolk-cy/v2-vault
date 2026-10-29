---
tags: [atlas, concept, type/atlas, area/ui, area/gameplay]
---
# Damage Numbers

<!-- tldr:start -->
> [!tldr] TL;DR
> - Damage numbers are not a comfort issue for most players but a clutter issue; some like them, some find them noisy.
> - Damage numbers: All / Mine only / Off, merged, capped, pooled.
> - Avoid: Trusting client damage numbers -> Server computes damage from server stats.
> - Pool on the client for visuals. Most pooled things (tracers, hit sparks, damage numbers) should exist only on the client.
>
> Cost: TL;DR ~140 tok · whole note ~660 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Damage numbers are not a comfort issue for most players but a clutter issue; some like them, some find them noisy. (from [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]])

## Key facts

- Damage numbers: All / Mine only / Off, merged, capped, pooled. ([[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]])
- Avoid: Trusting client damage numbers -> Server computes damage from server stats. ([[Hitboxes and Hit Detection]])
- Pool on the client for visuals. Most pooled things (tracers, hit sparks, damage numbers) should exist only on the client. ([[Object Pooling]])

## Mentioned in

38 notes in 17 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Instances Attributes and Tags]]

### 03 Architecture and Networking
[[Client Prediction and Reconciliation for Combat]] · [[Client-Server Model]]

### 04 Data and Persistence
[[Global State and Live Config]]

### 05 UI and UX
[[Accessibility]] · [[HUD Design]] · [[World-Space UI - BillboardGui and SurfaceGui]]

### 07 Lighting VFX and Audio
[[Game Feel and Juice]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]]

### 09 Gameplay Systems
[[Combat Systems Architecture]] · [[Damage Formula Pipeline - Armor, Resistances, Crits and Order of Operations]] · [[Explosions - Radius Damage, Falloff and Cover Checks]] · [[Hitboxes and Hit Detection]]

### 10 Game Design and Genres
[[Core Loops and Session Design]] · [[Genre Playbook - Combat and RPG]] · [[Genre Playbook - Tower Defense]]

### 40 Game Math
[[Intersection and Collision Math]]

### 42 Accessibility and Inclusive Design
[[Readable Text and UI Scale]]

### 47 Game Feel and Juice
[[Juice on a Budget - Mobile and Low-End]]

### 52 Core Concepts
[[Object Pooling]]

### 56 Field Notes
[[Client Hit Prediction for Melee Feedback]]

### 58 Player QoL and Game Tweaks
[[Accessibility Cross-Links for QoL Settings]] · [[Colourblind Palettes Text Size and Tooltips]] · [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]] · [[QoL Audit Checklist]]

Also mentioned in (not linked): Making Numbers Feel Good - Cooldowns Buffering and Coyote Time · Melee Combat System End to End · Memory Budgets and Leaks · Network Bandwidth Budgets and Measuring Them · Performance Fundamentals · Player QoL Start Here · Rendering Performance · ScreenGui Fundamentals · Settings Menu Essentials and Persistence · Teardown - Natural Disaster Survival · Teardown - Pressure · Top 25 QoL Wins by Effort · What Craft Looks Like on Roblox - Lessons from Top Studios

<!-- atlas:generated -->
