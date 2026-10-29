---
tags: [atlas, concept, type/atlas, area/2d, area/game-feel]
---
# Coyote Time

<!-- tldr:start -->
> [!tldr] TL;DR
> - Coyote time is one member of a family of small, invisible kindnesses.
> - Coyote time and jump buffer present. (Custom Character Controllers)
> - Coyote time quietly smooths these too, which is a feature: a jump pressed on a staircase works.
> - Coyote time and jump buffer on the local character.
>
> Cost: TL;DR ~110 tok · whole note ~610 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Coyote time is one member of a family of small, invisible kindnesses. (from [[Input Responsiveness Buffering and Coyote Time]])

Coyote time is the mirror image. Buffering forgives pressing too early; coyote time forgives pressing slightly too late (a jump just after leaving a ledge). (from [[Input Buffering]])

## Key facts

- Coyote time and jump buffer present. ([[Custom Character Controllers]])
- Coyote time quietly smooths these too, which is a feature: a jump pressed on a staircase works. ([[Input Responsiveness Buffering and Coyote Time]])
- Coyote time and jump buffer on the local character. ([[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]])
- Coyote time not zeroed on jump. Symptom: a free second jump right after a ledge jump. ([[2D Collision Physics and Platformer Movement]])

## Mentioned in

30 notes in 10 sections. The 25 most relevant are linked:

### 08 Animation
[[Frame Order and RunService Timing]] · [[Snippets - Playing Animations]] · [[Stance and Charge Moves]]

### 09 Gameplay Systems
[[Custom Character Controllers]] · [[Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run]]

### 47 Game Feel and Juice
[[Game Feel Start Here]] · [[Hit-Stop and Screen Shake Tuning by Numbers]] · [[Input Responsiveness Buffering and Coyote Time]] · [[Squash Stretch and Anticipation in UI and Characters]]

### 51 2D Game Development
[[2D Collision Physics and Platformer Movement]] · [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] · [[Choosing GUI 2D or Locked-Camera 2.5D]] · [[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

### 52 Core Concepts
[[Input Buffering]] · [[Rate Limiting]]

### 56 Field Notes
[[Hold-to-Attack Input That Never Sticks]]

### 58 Player QoL and Game Tweaks
[[Accessibility Cross-Links for QoL Settings]] · [[Aim Assist and Generous Hitboxes]] · [[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]] · [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]] · [[QoL Audit Checklist]] · [[Top 25 QoL Wins by Effort]]

### 60 High-Craft Game Teardowns
[[Teardown - Blade Ball]] · [[Teardown - Evade]] · [[Teardown - Grace]]

Also mentioned in (not linked): 00 Start Here · 2D Game Development Start Here · Player QoL Start Here · Teardown - Fish It · Teardown - Fling Things and People

<!-- atlas:generated -->
