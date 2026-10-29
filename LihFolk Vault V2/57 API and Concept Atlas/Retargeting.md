---
tags: [atlas, concept, type/atlas, area/animation, area/math]
---
# Retargeting

<!-- tldr:start -->
> [!tldr] TL;DR
> - Retargeting is making a clip authored on one rig play correctly on another.
> - Avoid: Delta retarget across different rest poses -> Absolute retarget, or pose-match the rests.
> - Avoid: Leaving tiny translations on every limb after retargeting.
> - Avoid: Root translation not retargeted -> Scale translation by the height ratio.
>
> Cost: TL;DR ~120 tok · whole note ~590 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Retargeting is making a clip authored on one rig play correctly on another. (from [[Retargeting Animations Between Rigs]])

Retargeting: Making a clip from one rig play correctly on another. (from [[Animation Glossary]])

## Key facts

- Avoid: Delta retarget across different rest poses -> Absolute retarget, or pose-match the rests. ([[Retargeting Animations Between Rigs]])
- Avoid: Leaving tiny translations on every limb after retargeting. ([[Animation Capture and Mocap]])
- Avoid: Root translation not retargeted -> Scale translation by the height ratio. ([[Creature Rig Conventions]])

## Mentioned in

39 notes in 11 sections. The 25 most relevant are linked:

### 05 UI and UX
[[UI Motion Language and Timing]]

### 07 Lighting VFX and Audio
[[Beams and Trails]]

### 08 Animation
[[Animation Asset Permissions and Groups]] · [[Animation Capture and Mocap]] · [[Animation Data from Blender to Roblox]] · [[Animation Glossary]] · [[AnimationConstraint and Physically Simulated Characters]] · [[Animator Deep Dive]] · [[Blender Armature and Bone Roll Conventions]] · [[Bones and Skinned Meshes]] · [[Creature Rig Conventions]] · [[CurveAnimation and Curve Channels]] · [[Custom Characters and StarterCharacter]] · [[Free Mocap and Mixamo Licensing for Roblox]] · [[Open Questions]] · [[Procedural Animation]] · [[Retargeting Animations Between Rigs]] · [[Rigging in Blender]] · [[Troubleshooting Table]] · [[UI and GUI Animation]]

### 09 Gameplay Systems
[[Character Select and Class Systems with Different Rigs]]

### 14 3D Modeling
[[Bezier Curves and Splines for Modellers]]

### 15 AI Tools
[[AI Animation and Motion from Video]]

### 40 Game Math
[[Curves in Luau - Paths Beams and Motion]] · [[Interpolation Easing and Curves Math]]

Also mentioned in (not linked): 00 Start Here · Animation Start Here · Game Math Start Here · How the Animator Really Behaves · Luau Performance and Native Codegen · Moon Animator and Third-Party Tools · Motor6D Math and CFrame Composition · Pipeline - Importing Animated Enemies · Publishing Animations · R15 Rig Anatomy and Attachments · Rigs and Joints · Teardown - Blade Ball · Thumbnails Icons and Store Page · Tween and CFrame Animation of Objects

<!-- atlas:generated -->
