---
tags: [atlas, concept, type/atlas, area/animation, area/vfx]
---
# Combos

<!-- tldr:start -->
> [!tldr] TL;DR
> - A combo is a sequence where the victim cannot act between hits (they are in hitstun).
> - Avoid: Infinite combos -> Hitstun decay, combo time cap, get-up invulnerability, breaker.
> - Two-client test with simulated latency (100 and 250 ms) for every character's combos.
> - One-press buffer; combo window resets the step.
>
> Cost: TL;DR ~120 tok · whole note ~1000 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A combo is a sequence where the victim cannot act between hits (they are in hitstun). (from [[Genre Playbook - Battlegrounds and Arena Fighters]])

## Key facts

- Avoid: Infinite combos -> Hitstun decay, combo time cap, get-up invulnerability, breaker. ([[Genre Playbook - Battlegrounds and Arena Fighters]])
- Two-client test with simulated latency (100 and 250 ms) for every character's combos. ([[Genre Playbook - Battlegrounds and Arena Fighters]])
- One-press buffer; combo window resets the step. ([[Combat Combo Systems]])
- Combos drop when players mash: No buffer, or window shorter than hit-stop plus reaction -> Attack buffer 0.15 to 0.3 s; pause ageing during hit-stop. ([[Input Responsiveness Buffering and Coyote Time]])
- Evasive or escape option against combos. ([[Case Study - The Strongest Battlegrounds]])

## Mentioned in

73 notes in 20 sections. The 25 most relevant are linked:

### 07 Lighting VFX and Audio
[[Combat Sound Design and Feedback]] · [[Escalation and Grandeur Without Clutter]]

### 08 Animation
[[Ability Kits Architecture]] · [[Animating Creatures and Monsters]] · [[Animation Review Checklist]] · [[Boss Animation and Phases]] · [[Combat Animation Craft]] · [[Combat Combo Systems]] · [[Enemy Animation State Protocol]] · [[Enemy and NPC Animation]] · [[Principles of Animation for Games]] · [[Snippets - Animation Controller Module]] · [[VFX Timing with Animation]] · [[Weapon Swing Design]] · [[Weapon and Combat Animation]]

### 09 Gameplay Systems
[[AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses]] · [[Hitboxes and Hit Detection]]

### 10 Game Design and Genres
[[Genre Playbook - Battlegrounds and Arena Fighters]] · [[Genre Playbook - Combat and RPG]]

### 24 Worked Builds
[[Melee Combat System End to End]]

### 32 Case Studies of Top Roblox Games
[[Case Study - The Strongest Battlegrounds]]

### 47 Game Feel and Juice
[[Hit-Stop and Screen Shake Tuning by Numbers]] · [[Input Responsiveness Buffering and Coyote Time]]

### 52 Core Concepts
[[Input Buffering]]

### 60 High-Craft Game Teardowns
[[Teardown - Jujutsu Shenanigans]]

Also mentioned in (not linked): 00 Start Here · Animation Start Here · AnimationTrack Reference · Beams and Trails · Behaviour Trees Utility AI and State Machines for NPCs · Camera Shake and Camera FX · Case Study - Building a Game with AI Agents · Case Study - Enemy Roster Rebuild · Client Prediction and Reconciliation for Combat · Combat Systems Architecture · Creature Rig Conventions · Difficulty Options and Cognitive Load · Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder · Equip Draw and Flourish Systems · Feedback Timing - Sound Visual and Haptic Sync · Frame Order and RunService Timing · Game Feel Start Here · Game Feel and Juice · Hit Reactions Stagger and Hit-Stop · Input Remapping and One-Handed Play · Locomotion Systems · Locomotion and Melee Reference Numbers · Markers and Events · NPC AI and Behaviour · Onboarding by Genre - The First Five Minutes · Playback, Priorities and Blending · Post-Mortem - Building a Melee Action Game · Procedural Animation · Rate Limiting and Abuse Prevention · Replication and Ownership · Snippets - Enemy Client Animator · Snippets - Playing Animations · Social Design and Multiplayer Play · Sound Design Pitfalls - Reused Ids Onsets and Layered Loops · Sound Design for Games · Stance and Charge Moves · Stylised Weapons From a Concept · Teaching Through Level Design · Teardown - Deepwoken · Teardown - Funky Friday · Teardown - Plants vs Brainrots · Testing Strategies and Frameworks · Time-to-Kill Math and a Weapon Balance Sheet · Timing Spacing and Frame Charts · Tutorial Step Design Patterns - Teach by Doing · VFX Design Playbook · What Craft Looks Like on Roblox - Lessons from Top Studios · Worked Builds Start Here

<!-- atlas:generated -->
