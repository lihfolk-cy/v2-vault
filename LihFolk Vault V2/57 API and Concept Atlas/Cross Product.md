---
tags: [atlas, concept, type/atlas, area/math, area/physics]
---
# Cross Product

<!-- tldr:start -->
> [!tldr] TL;DR
> - Cross products of nearly parallel vectors lose relative precision quickly, so `.Unit` on them amplifies noise into a wildly...
> - Avoid: Lift sign wrong -> Debug arrows, flip cross product.
> - Every normalisation of a cross product has a fallback.
> - Dot and Cross Products in Gameplay: the maths behind view cones and facing checks.
>
> Cost: TL;DR ~120 tok · whole note ~450 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Cross products of nearly parallel vectors lose relative precision quickly, so `.Unit` on them amplifies noise into a wildly wrong direction even when it does not produce NaN: always pick a fallback below a threshold like `1e-3` rather than `1e-9`. (from [[Dot and Cross Products in Gameplay]])

## Key facts

- Avoid: Lift sign wrong -> Debug arrows, flip cross product. ([[Aircraft and Flight Models]])
- Every normalisation of a cross product has a fallback. ([[Dot and Cross Products in Gameplay]])
- Dot and Cross Products in Gameplay: the maths behind view cones and facing checks. ([[Cookbook - Math CFrame and Vectors]])
- Dot and Cross Products in Gameplay: facing checks, cone tests and side tests that build on the vector recipes here. ([[Math Vectors and CFrames]])

## Mentioned in

15 notes in 8 sections. The 15 most relevant are linked:

### 02 Luau Scripting
[[Math Vectors and CFrames]]

### 08 Animation
[[Motor6D Math and CFrame Composition]] · [[Weapon Design Rig Builder]]

### 09 Gameplay Systems
[[Spawn Director - Credit Budgets and Player-Count Scaling]] · [[Squad AI - Attack Tokens, Flanking and Attacker Limits]]

### 25 Physics and Vehicles
[[Aircraft and Flight Models]] · [[Racing AI on a Racing Line - Spline Following and Rubber-Banding]] · [[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]]

### 29 Luau Cookbook
[[Cookbook - Math CFrame and Vectors]]

### 40 Game Math
[[Dot and Cross Products in Gameplay]] · [[Game Math Start Here]] · [[Intersection and Collision Math]] · [[Rotations Angles and Quaternions]]

### 58 Player QoL and Game Tweaks
[[Aim Assist and Generous Hitboxes]]

### Root notes
[[00 Start Here]]

<!-- atlas:generated -->
