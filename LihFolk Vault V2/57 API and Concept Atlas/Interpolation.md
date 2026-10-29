---
tags: [atlas, concept, type/atlas, area/animation, area/modeling]
---
# Interpolation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Interpolation is how a game turns "from here to there" into motion, colour, damage falloff and difficulty ramps.
> - Avoid: Setting position on receipt -> Interpolate at a delayed render time.
> - Fixed timestep with accumulator, frame clamp, max steps per frame, and interpolation alpha.
> - Spans are at most 0.4 s long and must turn less than 120 deg (the Animator's interpolation becomes ambiguous for big turns).
>
> Cost: TL;DR ~140 tok · whole note ~1.6k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Interpolation is how a game turns "from here to there" into motion, colour, damage falloff and difficulty ramps. (from [[Interpolation Easing and Curves Math]])

## Key facts

- Avoid: Setting position on receipt -> Interpolate at a delayed render time. ([[Snapshot Interpolation for Custom Replication]])
- Fixed timestep with accumulator, frame clamp, max steps per frame, and interpolation alpha. ([[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]])
- Spans are at most 0.4 s long and must turn less than 120 deg (the Animator's interpolation becomes ambiguous for big turns). ([[Arm Baker Internals]])
- Avoid: Linear texture interpolation on a palette. ([[Low-Poly Creature From a Flat Reference Sheet]])
- Avoid: Solving each key independently and trusting interpolation. ([[Arm Twist and Grip Roll - Lessons from Baked Sword Clips]])

## Mentioned in

133 notes in 33 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Luau Language Essentials]] · [[Math Vectors and CFrames]] · [[Strings Patterns and Formatting]]

### 03 Architecture and Networking
[[Snapshot Interpolation for Custom Replication]]

### 08 Animation
[[Animation Data from Blender to Roblox]] · [[Animation Editor Advanced]] · [[Arm Baker Internals]] · [[Case Study - Fixing Hundreds of Attack Clips]] · [[CurveAnimation and Curve Channels]] · [[Engine Gotchas]] · [[How the Animator Really Behaves]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Keyframes, Easing and Interpolation]] · [[Lua Keyframe Player Internals]] · [[Open Questions]] · [[Snippets - Building and Sampling Clips]] · [[Weapon Rig Player]]

### 14 3D Modeling
[[Bezier Curves and Splines for Modellers]]

### 23 Debugging Deep Dives
[[Debugging Physics and Network Ownership]]

### 40 Game Math
[[Curves in Luau - Paths Beams and Motion]] · [[Interpolation Easing and Curves Math]] · [[Rotations Angles and Quaternions]]

### 51 2D Game Development
[[2D Multiplayer - Server Authority and Replicating GUI Worlds]] · [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]

### 56 Field Notes
[[Animation Data Hygiene - Euler Wrap Joint Holes and Easing]]

Also mentioned in (not linked): 00 Start Here · 2D Game Development Start Here · AI Animation and Motion from Video · AI Code Assistants for Luau · AI Pitfalls - Stale APIs and Luau · Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools · Animating Creatures and Monsters · Animation Capture and Mocap · Animation Editor Workflow · Animation Glossary · Animation Start Here · Animator Deep Dive · Arm QA Metrics Reference · Arm Twist and Grip Roll - Lessons from Baked Sword Clips · Atmosphere Sky Clouds and Post-Processing · Authoring Clips in Code · Baked Clip Stubs and Archiving · Bevels Chamfers and Edge Highlights Without Textures · Big Numbers Precision and Formatting · Boats Buoyancy and Water · Camera - Engine Reference Card · Case Study - Building LihFolk V2 with AI Agents · Case Study - Cutting a Million Instances · Choosing GUI 2D or Locked-Camera 2.5D · Clean Stylised Shading - Weighted and Custom Normals · Client Prediction and Reconciliation for Combat · Client-Server Model · Clip Buffer Format · Combat Animation Craft · Cookbook - Math CFrame and Vectors · Custom Schedulers and Coroutine Patterns · Detecting Combat Exploits - Reach Rate and Aim · Detecting Movement Exploits - Speed Fly Noclip Teleport · Easing · Enemy Animation State Protocol · Enemy and NPC Animation · Engine, Gearbox and Torque Curve Model for Arcade Cars · Equip Draw and Flourish Systems · Flat Colour vs Gradient Atlas vs Vertex Colour · Flight Flocks and Path Animation · Foot Placement and Ground IK · Game Math Start Here · Genre Playbook - Shooters FPS and TPS · Genre Systems Start Here · Ground Fitting Pipeline · Hand-Painted and Stylized Texturing · Hitboxes and Hit Detection · Human Swing Biomechanics · IKControl Reference · Idle Breathing and Secondary Motion · Importing Models and Rigs · Interest Management and Per-Player Replication · Inverse Kinematics · Layered Clothing Cages and Animation · Layered Clothing Creation Workflow · LihFolk R15 Keyframe Pipeline · LihFolk Systems Library · Locomotion Systems · Low-Poly Creature From a Flat Reference Sheet · Lua Keyframe Player · Luau Performance Patterns with Benchmarks · Luau Performance and Native Codegen · Luau Type System and Strict Mode · Melee Combat System End to End · Modeling Fundamentals for Games · Moon Animator and Third-Party Tools · Motor6D Math and CFrame Composition · Mover Constraints and Physics Controllers · Multi-Bone IK - FABRIK and CCD · Network Bandwidth Budgets and Measuring Them · Noise Functions and Terrain Generation · Normal Maps and Detail Baking · Open Questions - Whole Vault · Performance and Memory · Pricing Curves and Upgrade Costs · Principles of Animation for Games · Procedural Animation · Procedural Weapon Motion · Projectiles and Ballistics · Publishing Animations · R15 Run Cycle Key Poses · Race HUD - Position, Laps, Splits, Speedometer and Minimap · Racing AI on a Racing Line - Spline Following and Rubber-Banding · Racing Laps and Checkpoints End to End · Ragdolls and Physics-Based Animation · Rides and Attractions - Roller Coasters, Ziplines, Elevators and Cable Cars · Snippets - Procedural Motion · Spec-Driven Move Authoring · Spin and Whole-Body Rotation Moves · Springs Damping and Smoothing · Standing on Moving Vehicles and Platforms - Keeping Players Glued · Stylized Creatures - Soft Forms, Painted Gradients and Light Rigs · Teardown - Anime Vanguards · Teardown - Blade Ball · The Audio API - Players Emitters Wires and Effects · Timing Spacing and Frame Charts · Trim Sheets Atlases and Vertex Colors · Tween and CFrame Animation of Objects · Tween vs Spring · TweenService - Engine Reference Card · UI and GUI Animation · UV Unwrapping · Voxel Shading - Baked AO Edges and Lighting · Water Sky and Atmosphere Art · Weapon Design Rig Builder · Weapon Swing Design · Weather System Architecture - State Machine, Transitions and Replication · Wildlife and Ambient Creature AI - Passive, Neutral and Hostile

<!-- atlas:generated -->
