---
cssclasses: [vault-hub]
tags: [math, game-math, hub, vectors, rotations, probability, collision, numbers, type/hub, area/math, level/beginner, area/gameplay]
---
# Game Math Start Here

This section is the maths behind gameplay, taught through gameplay. Every note starts from a game problem (a backstab check, a turret on a tilting boat, a drop rate that might be bugged, a coin counter that shows "1000K") and works down to the formula, the Luau, and the ways it breaks. It builds on two older notes that you should read first if vectors and CFrames are new to you:

- [[Math Vectors and CFrames]]: the `math` library, `Random`, `Vector3`, CFrame construction and composition, spaces, Euler orders, smoothing with `dt`, float basics.
- [[Cookbook - Math CFrame and Vectors]]: twelve small recipes (facing, cones, orbits, random points, cone spread, launch velocity, grid snapping, closest point on a segment).

The notes here go a level deeper without repeating them.

## The six notes

| Note | Gameplay it unlocks | Key ideas |
|---|---|---|
| [[Dot and Cross Products in Gameplay]] | Backstabs and flanks, jitter-free steering, homing and aggro leashes, lap progress and gate crossing, wall running, bounce pads, aim assist | Dot as signed length, `atan2(cross, dot)`, closing speed, projections, building frames |
| [[Interpolation Easing and Curves Math]] | Damage falloff, UI motion, camera FX envelopes, rails and paths, constant-speed carts, smooth retargeting | `invLerp, clamp, shape, lerp`, easing derivatives, overshoot budgets, [[Bezier Curves\|Bezier]], Catmull-Rom, arc length, Hermite |
| [[Probability and Statistics for Designers]] | Fair crit and dodge stacking, build balance at breakpoints, streak control, verifying drop rates, reading analytics | At-least-once odds, stacking models, variance, PRD, shuffle bags, Wilson intervals, sample sizes |
| [[Rotations Angles and Quaternions]] | Turrets with limits, rate-limited turning, throws that keep spin, head and item limits, compact replication | Angle wrapping, axis-angle, swing-twist, [[Quaternions\|quaternion]] toolkit, [[slerp]] vs nlerp, smallest-three packing |
| [[Intersection and Collision Math]] | Zones without `Touched`, building cursors, lag-compensated melee, bullets that cannot tunnel, leading targets, big fights | Containment tests, ray vs plane, sphere and box, capsules, swept spheres, intercepts, spatial hashing |
| [[Big Numbers Precision and Formatting]] | Simulators past 10^15, worlds far from the origin, long timers, huge leaderboards, honest number display | Container types and limits, float32 gaps, mantissa-exponent numbers, integer currency, order-preserving encodings |

## Suggested reading paths

- **Combat programmer:** Dot and Cross, then Intersection and Collision, then Rotations. Pair with [[Hitboxes and Hit Detection]], [[Projectiles and Ballistics]] and [[Client Prediction and Reconciliation for Combat]].
- **Simulator or idle game:** Big Numbers, then Probability, then Interpolation (for counters and UI). Pair with [[Economy Inflation Sinks and Faucets Math]], [[Rarity Ladders and Drop Pacing Math]] and [[Genre Playbook - Simulators]].
- **Designer who wants the numbers right:** Probability first, then the Interpolation sections on remaps and curves. Pair with [[Balancing with Spreadsheets and Data]] and [[RNG Drops and Luck Systems]].
- **Camera, vehicles and movement:** Rotations, Interpolation, Dot and Cross. Pair with [[Camera Systems]], [[Custom Character Controllers]] and [[Springs Damping and Smoothing]].
- **UI and game feel:** Interpolation, then the formatting part of Big Numbers. Pair with [[UI Motion Language and Timing]] and [[Game Feel and Juice]].

## Related notes elsewhere in the vault

- Animation maths: [[Motor6D Math and CFrame Composition]], [[Two-Bone IK Math]], [[Keyframes, Easing and Interpolation]], [[How the Animator Really Behaves]].
- Engine queries that complement the geometry here: [[Raycasts Shapecasts and Spatial Queries]], [[Collision and Physics Geometry]].
- Numbers on the wire and on disk: [[Buffers and Binary Data]], [[Network Bandwidth Budgets and Measuring Them]], [[OrderedDataStores and Leaderboards]].
- Fast maths code: [[Luau Performance and Native Codegen]], [[Luau Performance Patterns with Benchmarks]], [[Parallel Luau and Actors]].

## Conventions used in this section

- Roblox is right-handed and Y up; a CFrame's `LookVector` is its negative Z axis. Angles in code are radians; degrees appear only at config and UI boundaries.
- Facts are labelled "Roblox docs (as of October 2026)", "measured in the reference project" or "rule of thumb". Where a behaviour is undocumented, the note says so.
- Code is `--!strict` Luau as pure functions, reviewed but not run in every engine build: test in your own place first.
- Every note ends with common mistakes and a checklist: if a bug matches a row, start there.

## Connected notes
<!-- auto-links:start -->
[[Snippets - Building and Sampling Clips]] · Luau Cookbook Start Here · CurveAnimation and Curve Channels · Look-At Aim and Head Tracking · Expected Value · Animation Editor Advanced
<!-- auto-links:end -->
