---
cssclasses: [vault-hub]
tags: [index, start, type/hub, area/animation, level/beginner, api/Animator, api/Motor6D]
---
# Animation Start Here

A field guide to **everything about animation in Roblox**: how the engine really plays clips, rigging and importing from Blender, the craft of animating for games, procedural motion and IK, the systems that run a combat game (locomotion, combos, abilities, enemies, cameras), production pipelines and tooling, debugging, performance, and a library of working Luau.

120 notes, about 286,000 words.

## Where the knowledge comes from
- **Roblox docs**: the official engine reference and Creator Hub guides, checked in October 2026. Notes say "Roblox docs" or "Docs".
- **Measured**: one live action game (the "reference project") with:
  - around a hundred weapon kits;
  - several hundred attack clips repaired by an offline IK baker;
  - well over a thousand enemy clips;
  - a Lua keyframe player that matched the real Animator to under 0.1 degrees.

  The project measured its claims by stepping the real `Animator` and reading joint transforms. Some of them aren't in any doc.
- **Rule of thumb**: experience and craft knowledge, labelled as such.
- Conflicts and unverified points are never hidden: they are collected in [[Open Questions]].

## Reading paths

**New to Roblox animation (a weekend):**
1. [[Animation Objects]] and [[Rigs and Joints]]
2. [[Animation Editor Workflow]] and [[Principles of Animation for Games]]
3. [[Playback, Priorities and Blending]] and [[Markers and Events]]
4. [[Publishing Animations]] and [[Animation Asset Permissions and Groups]]
5. [[Snippets - Playing Animations]]
6. Keep [[Troubleshooting Table]] open

**Animator coming from Blender / Maya:**
1. [[Rigging in Blender]], [[Blender Armature and Bone Roll Conventions]], [[Exporting FBX vs GLB]]
2. [[3D Importer Settings Reference]], [[Importing Models and Rigs]]
3. [[Animation Data from Blender to Roblox]], [[Retargeting Animations Between Rigs]]
4. [[How the Animator Really Behaves]] (why your clip plays differently in Roblox)

**Building a combat game:**
1. [[Combat Animation Craft]], [[Weapon Swing Design]], [[Timing Spacing and Frame Charts]]
2. [[Combat Combo Systems]], [[Hit Reactions Stagger and Hit-Stop]], [[Ability Kits Architecture]]
3. [[VFX Timing with Animation]], [[Camera Shake and Camera FX]], [[Cinematic Ultimates]]
4. [[Enemy and NPC Animation]], [[Enemy Animation State Protocol]], [[Boss Animation and Phases]]

**Technical animator / tools programmer:**
1. [[How the Animator Really Behaves]], [[Motor6D Math and CFrame Composition]], [[Frame Order and RunService Timing]]
2. [[Authoring Clips in Code]], [[Spec-Driven Move Authoring]]
3. [[Studio Tooling Architecture]], [[Pipeline - Arm IK Baking and QA]], [[Arm Baker Internals]], [[Arm QA Metrics Reference]]
4. [[Lua Keyframe Player]], [[Lua Keyframe Player Internals]], [[Clip Buffer Format]], [[Baked Clip Stubs and Archiving]]

**Procedural motion and IK:**
[[Procedural Animation]] → [[Springs Damping and Smoothing]] → [[Two-Bone IK Math]] → [[Elbow Poles Swivel and Joint Limits]] → [[Foot Placement and Ground IK]] → [[Procedural Gait and Footstep Planning]]

**Something is broken:**
[[Troubleshooting Table]] → [[Debugging Animation Problems]] → [[Engine Gotchas]] → [[Testing Animations in Studio]]

## Map

### 01 Fundamentals (the engine)
- [[Animation Objects]]: every animation object and how they connect
- [[Animator Deep Dive]]: loading, evaluation, LOD, replication, methods and events
- [[AnimationTrack Reference]]: every member, defaults, lifecycle traps
- [[KeyframeSequence Keyframe and Pose Reference]]: the classic clip format, instance by instance
- [[CurveAnimation and Curve Channels]]: the curve-based clip format
- [[Rigs and Joints]]: Motor6D, Bone, [[AnimationConstraint]], R6 vs R15
- [[Motor6D Math and CFrame Composition]]: the joint equation, inverted and applied
- [[Bones and Skinned Meshes]]
- [[AnimationConstraint and Physically Simulated Characters]]: the Avatar Joint Upgrade
- [[Humanoid States and Animation]]
- [[The Default Animate Script]]: how Roblox's default animation works, and how to replace it
- [[Playback, Priorities and Blending]]: the measured weight distribution rule
- [[Keyframes, Easing and Interpolation]]: easing shapes, and why rotations aren't slerped
- [[How the Animator Really Behaves]]: measured behaviour, with a Luau model
- [[Markers and Events]]: exact firing rules and data-driven timing
- [[Replication and Ownership]]: who plays what, three scalable architectures
- [[Animation Asset Permissions and Groups]]
- [[Frame Order and RunService Timing]]
- [[Scale and Animation]]

### 02 Rigging and Importing
- [[Rigging in Blender]] (hub)
- [[Blender Armature and Bone Roll Conventions]]
- [[Weight Painting and Skinning for Roblox]]
- [[Exporting FBX vs GLB]]
- [[Importing Models and Rigs]]
- [[3D Importer Settings Reference]]
- [[Custom Rigs - Weapons and Props]]
- [[Creature Rig Conventions]]: five rig families that share clips
- [[R15 Rig Anatomy and Attachments]]: every part, joint and attachment, measured
- [[Custom Characters and StarterCharacter]]
- [[Facial Animation and Dynamic Heads]]
- [[Layered Clothing Cages and Animation]]
- [[Accessories and Armor That Follow Animation]]
- [[Retargeting Animations Between Rigs]]
- [[Animation Data from Blender to Roblox]]

### 03 Authoring (tools and craft)
- [[Animation Editor Workflow]], [[Animation Editor Advanced]]
- [[Moon Animator and Third-Party Tools]], [[Animation Capture and Mocap]]
- [[Principles of Animation for Games]], [[Timing Spacing and Frame Charts]], [[Posing and Silhouettes]]
- [[Combat Animation Craft]], [[Weapon Swing Design]]
- [[Animating Creatures and Monsters]], [[Idle Breathing and Secondary Motion]]
- [[Animation Quality Standard]]: measurable rules for human-looking arms
- [[Authoring Clips in Code]], [[Spec-Driven Move Authoring]]
- [[Publishing Animations]], [[Animation Review Checklist]]

### 04 Procedural (code-driven motion and IK)
- [[Procedural Animation]] (hub), [[Springs Damping and Smoothing]]
- [[Inverse Kinematics]] (hub), [[IKControl Reference]], [[Two-Bone IK Math]], [[Multi-Bone IK - FABRIK and CCD]]
- [[Elbow Poles Swivel and Joint Limits]], [[Foot Placement and Ground IK]], [[Procedural Gait and Footstep Planning]]
- [[Look-At Aim and Head Tracking]], [[Ragdolls and Physics-Based Animation]]
- [[Procedural Weapon Motion]], [[Procedural Death Knockdown and Hit Reactions]]
- [[Tween and CFrame Animation of Objects]], [[Flight Flocks and Path Animation]]

### 05 Systems (game architecture)
- [[Locomotion Systems]], [[Custom Locomotion Controller Design]]
- [[Weapon and Combat Animation]] (hub), [[Combat Combo Systems]], [[Ability Kits Architecture]]
- [[Hit Reactions Stagger and Hit-Stop]], [[Equip Draw and Flourish Systems]], [[Stance and Charge Moves]]
- [[Enemy and NPC Animation]], [[Enemy Animation State Protocol]], [[Boss Animation and Phases]]
- [[Cameras and Cutscenes]], [[Camera Shake and Camera FX]], [[Cinematic Ultimates]]
- [[Emotes and Social Animation]], [[UI and GUI Animation]], [[VFX Timing with Animation]]

### 06 Pipelines and Tooling (production)
- [[Studio Tooling Architecture]]
- [[Pipeline - Arm IK Baking and QA]], [[Arm Baker Internals]], [[Arm QA Metrics Reference]]
- [[Pipeline - New Animated Weapon]], [[Weapon Design Rig Builder]], [[Weapon Rig Player]]
- [[Pipeline - Importing Animated Enemies]], [[Enemy Import Axis Fix]], [[Ground Fitting Pipeline]]
- [[Lua Keyframe Player]], [[Lua Keyframe Player Internals]]
- [[Baked Clip Stubs and Archiving]], [[Clip Buffer Format]], [[Clip Archive Server]]
- Case studies: [[Case Study - Fixing Hundreds of Attack Clips]], [[Case Study - Abilities That Only Worked in Studio]], [[Case Study - Cutting a Million Instances]]

### 07 Gotchas (when things go wrong)
- [[Troubleshooting Table]]: about 100 symptoms, causes and fixes
- [[Debugging Animation Problems]], [[Engine Gotchas]], [[Testing Animations in Studio]]
- [[Performance and Memory]], [[Animation LOD]]
- [[Open Questions]]

### 08 Snippets (working Luau)
- [[Snippets - Playing Animations]], [[Snippets - Animation Controller Module]]
- [[Snippets - Procedural Motion]], [[Snippets - IK]], [[Snippets - Ragdoll]]
- [[Snippets - Building and Sampling Clips]], [[Snippets - Lua Keyframe Player Core]]
- [[Snippets - Enemy Client Animator]], [[Snippets - Camera Shake and FX]]

### Reference
- [[Animation Glossary]]

## A caution about the code
The snippets were reviewed carefully by hand against the API docs, but test them in your own place before relying on them. Roblox evolves: where a note says "check your Studio version", do.

## Connected notes
<!-- auto-links:start -->
[[AI Animation and Motion from Video]] · Official Docs - Asset Creation · Modeling Characters for R15 and Custom Rigs · Voxel Characters - Proportions Joints and Rigging · Official Docs - Characters and Animation · Skeleton Library
<!-- auto-links:end -->
