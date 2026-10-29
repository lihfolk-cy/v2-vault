---
tags: [atlas, concept, type/atlas, area/animation, area/gameplay]
---
# Telegraphing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Telegraph (Tele): A readable wind-up warning before an enemy attack.
> - Avoid: Telegraph bigger than the escape distance -> `R <= speed * (warning - 0.25)` or add a dash.
> - Avoid: Arena too large -> Keep the edge within about 3 telegraph radii.
> - Enemy telegraphs must outlast latency plus reaction time.
>
> Cost: TL;DR ~120 tok · whole note ~820 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Telegraph (Tele): A readable wind-up warning before an enemy attack. (from [[Animation Glossary]])

## Key facts

- Avoid: Telegraph bigger than the escape distance -> `R <= speed * (warning - 0.25)` or add a dash. ([[Combat Arena and Encounter Layout]])
- Avoid: Arena too large -> Keep the edge within about 3 telegraph radii. ([[Combat Arena and Encounter Layout]])
- Enemy telegraphs must outlast latency plus reaction time. ([[Anticipation]])
- Avoid: Attacks without telegraphs -> 0.4 to 0.8 s telegraph, ground markers. ([[Genre Playbook - Combat and RPG]])
- Every attack telegraphed; roles distinct in silhouette. ([[Genre Playbook - Combat and RPG]])

## Mentioned in

54 notes in 15 sections. The 25 most relevant are linked:

### 03 Architecture and Networking
[[Client Prediction and Reconciliation for Combat]]

### 07 Lighting VFX and Audio
[[Combat Sound Design and Feedback]] · [[Lighting Mood and Time of Day]] · [[VFX Performance Budgets and Culling]]

### 08 Animation
[[Animating Creatures and Monsters]] · [[Animation Glossary]] · [[Animation Review Checklist]] · [[Boss Animation and Phases]] · [[Combat Animation Craft]] · [[Enemy Animation State Protocol]] · [[Enemy and NPC Animation]] · [[Snippets - Enemy Client Animator]]

### 09 Gameplay Systems
[[AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses]] · [[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Hitboxes and Hit Detection]] · [[NPC AI and Behaviour]] · [[Squad AI - Attack Tokens, Flanking and Attacker Limits]]

### 10 Game Design and Genres
[[Boss Fight Design Patterns]] · [[Genre Playbook - Combat and RPG]] · [[Genre Playbook - Horror and Story]]

### 13 Production and Case Studies
[[Case Study - Enemy Roster Rebuild]]

### 33 Level Design
[[Combat Arena and Encounter Layout]]

### 42 Accessibility and Inclusive Design
[[Colour-Blind Safe Design]]

### 47 Game Feel and Juice
[[Juice on a Budget - Mobile and Low-End]]

### 52 Core Concepts
[[Anticipation]]

Also mentioned in (not linked): AI Animation and Motion from Video · Accessibility · Accessibility Start Here · Animation Capture and Mocap · Animation LOD · Emotes and Social Animation · Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder · Explosions - Radius Damage, Falloff and Cover Checks · Feedback Timing - Sound Visual and Haptic Sync · Game Feel Start Here · Genre Playbook - Tower Defense · Graphics and Performance Toggles for Low-End Devices · Interest Management and Per-Player Replication · Level Design Start Here · Level Design for Roblox · Lightning Strikes and Thunder - Procedural Bolts and Sound Delay · Locomotion and Melee Reference Numbers · Markers and Events · Mobile and Low-End Optimization · Pipeline - Importing Animated Enemies · Post-Mortem - Building a Melee Action Game · QoL Audit Checklist · Stance and Charge Moves · Timing Spacing and Frame Charts · Troubleshooting Table · VFX Design Playbook · Weather Performance Budgets and Quality Tiers · Weather System Architecture - State Machine, Transitions and Replication · Weather That Changes Gameplay - Grip, Visibility and Hearing

<!-- atlas:generated -->
