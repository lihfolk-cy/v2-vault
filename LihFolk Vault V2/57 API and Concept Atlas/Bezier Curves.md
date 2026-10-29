---
tags: [atlas, concept, type/atlas, area/animation, area/math]
---
# Bezier Curves

<!-- tldr:start -->
> [!tldr] TL;DR
> - A Bezier curve is defined by control points.
> - Designer paths use centripetal Catmull-Rom converted to Bezier segments.
> - Repeating a knot lowers continuity at that spot (a deliberate crease) and lets a NURBS curve reproduce Bezier pieces exactly.
> - Resolution U sets how many evaluated points each Bezier segment gets, uniformly, whether the segment bends or not.
>
> Cost: TL;DR ~130 tok · whole note ~360 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A Bezier curve is defined by control points. (from [[Bezier Curves and Splines for Modellers]])

## Key facts

- Designer paths use centripetal Catmull-Rom converted to Bezier segments. ([[Curves in Luau - Paths Beams and Motion]])
- Repeating a knot lowers continuity at that spot (a deliberate crease) and lets a NURBS curve reproduce Bezier pieces exactly. ([[Bezier Curves and Splines for Modellers]])
- Resolution U sets how many evaluated points each Bezier segment gets, uniformly, whether the segment bends or not. ([[Curve-Based Modelling in Blender for Roblox]])
- Keys become Bezier F-curves with real handles, never linear interpolation. ([[LihFolk R15 Keyframe Pipeline]])

## Mentioned in

11 notes in 5 sections. The 11 most relevant are linked:

### 06 World Building and Art
[[Roads, Rivers and Paths Carved Along Curves in Terrain]]

### 07 Lighting VFX and Audio
[[Beams and Trails]]

### 08 Animation
[[Exporting FBX vs GLB]] · [[Flight Flocks and Path Animation]] · [[LihFolk R15 Keyframe Pipeline]] · [[Moon Animator and Third-Party Tools]]

### 14 3D Modeling
[[Bezier Curves and Splines for Modellers]] · [[Curve-Based Modelling in Blender for Roblox]]

### 40 Game Math
[[Curves in Luau - Paths Beams and Motion]] · [[Game Math Start Here]] · [[Interpolation Easing and Curves Math]]

<!-- atlas:generated -->
