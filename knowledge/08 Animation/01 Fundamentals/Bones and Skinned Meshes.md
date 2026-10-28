---
tags: [fundamentals, bones, skinning, rigging]
---
# Bones and Skinned Meshes

A skinned mesh is one mesh whose vertices are deformed by a hierarchy of `Bone` objects, each vertex weighted to a few bones. It is how smooth creatures, tails, capes, tentacles, dragons and modern avatar bodies bend without visible seams. This note covers the `Bone` class, how the Animator drives bones, how skinned rigs differ from part rigs in practice (collision, replication, hit detection, root motion), the limits, and the patterns one production game used for dozens of skinned enemies and bosses.

## Bone in one paragraph

`Bone` inherits from `Attachment`. Its `CFrame` (inherited) is the **rest pose** relative to its parent (a parent Bone, or the part it sits in). `Transform` is the animated offset applied on top, exactly like `Motor6D.Transform`. The animated result is readable as `TransformedCFrame` (local, hidden) and `TransformedWorldCFrame` (world). Vertices skinned to the bone follow its animated frame, blended by their weights. Bones are not rendered.

| Member | Type | Notes |
|---|---|---|
| `CFrame`, `WorldCFrame`, `Position`... | from Attachment | The **rest** pose. `WorldCFrame` does not include `Transform`. |
| `Transform` | CFrame, not replicated, not saved | Animated offset relative to `CFrame`. Written by the Animator; writable by scripts. |
| `TransformedCFrame` | CFrame, hidden, read-only | `CFrame * Transform` in local space. |
| `TransformedWorldCFrame` | CFrame, read-only | The bone's current animated world frame. Use this for "where is the hand bone now". |

```
bone.TransformedWorldCFrame = parentAnimatedFrame * bone.CFrame * bone.Transform
```

## How a skinned rig is put together

```
Model "Wyrm"
├── HumanoidRootPart        (invisible, non-colliding box; the gameplay root)
├── AnimationController
│   └── Animator
└── Body (MeshPart, skinned)          <- the mesh, its vertices carry bone weights
    └── Bone "Root"                   <- top bone; its key in a clip is NOT applied
        └── Bone "Body"               <- put root motion here
            ├── Bone "Neck" > Bone "Head" > Bone "Jaw"
            ├── Bone "Wing_L" > ...
            └── Bone "Tail1" > Bone "Tail2" > ...
```

- The 3D importer creates the Bones from the file's armature and places them under the mesh (or the rig's root part), named as in the source file.
- Animation data binds **by bone name**, exactly as Poses bind to Part1 names on part rigs. Rename a bone and its keys go inert.
- A rig can mix: skinned meshes for the body, plus rigid parts attached to bones (armour plates, weapons, horns).

## Skinned rigs vs part rigs

| Concern | Part rig (Motor6D) | Skinned rig (Bones) |
|---|---|---|
| Look | Rigid segments, visible seams at joints | Smooth bending |
| Collision | Every part can collide and be raycast; parts follow the animation | The MeshPart collides with its **rest** shape; animated deformation is visual only |
| Hit detection | Raycasts and touches see the animated limbs | Need separate hitboxes (parts attached to bones) or math against `TransformedWorldCFrame`s |
| Replication of motion | Track state replicates; joints are evaluated per client | Same; `Bone.Transform` itself never replicates |
| Cost | Per-part transforms and physics | Per-vertex skinning plus per-bone transforms |
| Authoring | Easy to build in Studio by hand | Built in Blender/Maya, imported |
| Attaching props | Weld or Motor6D to a part | `RigidConstraint` (or a Weld) to a Bone, which is an Attachment |

The collision row surprises people most. A dragon whose wing sweeps down to the ground does not hit anything with that wing; its MeshPart's collision geometry is the bind pose. Enemy systems therefore put invisible hitbox parts on key bones, or do damage from data (distances and marker times), not from physical touches. See [[Enemy and NPC Animation]].

## Limits and specs

| Spec | Value | Source |
|---|---|---|
| Max bone influences per vertex | 4 | Roblox docs (modeling specifications) |
| Root bone | at 0,0,0; no skin weights on the root | Roblox docs |
| Bone transforms in the source tool | frozen: scale 1, rotation 0 | Roblox docs |
| Triangles per mesh | 20,000 | Roblox docs |
| Animations per exported file | one track per mesh or model export | Roblox docs |
| Deforming bones per creature | 40 for regular enemies, 60 for bosses | Rule of thumb: one production game's family-rig budget |
| Weights | normalised, no zero-weight vertices | Same production conventions |

No maximum bone count per mesh is documented. Bone count drives CPU cost per frame (each animated bone is a transform evaluation), so keep deforming chains purposeful: a 12-bone tail that only ever swings as a whole is 11 bones of waste.

## The root bone rule

Measured in one production project: the top-level pose of a keyframe is never applied. On bone rigs that is the `Root` bone's key. One boss rig had all its lift (the body rising and dropping) authored on `Root`, and it played flat; moving the lift to the `Body` bone fixed it. Rule: **root motion goes on the first child of the root**. If your exporter bakes the armature object's motion into the root bone, add a dummy root above it in Blender, or re-path the root keys onto the child after import.

A related import bug in the same game: clips imported from GLB carried a 180 degree conversion on the root while child bones were written in their own rest frames. Since the root key was ignored, every imported creature played facing backwards relative to its HumanoidRootPart ("attacked from behind") while server logic using the root's LookVector stayed correct. The fix was a data transform on every clip (see [[Enemy Import Axis Fix]]).

## Driving bones from code

### Procedural layer on top of a clip
Same rules as Motor6D: the Animator rewrites `Transform` every frame for bones its tracks key; write in `PreSimulation`, compose with the animated value, and redo it every frame.

```lua
--!strict
local RunService = game:GetService("RunService")

-- Adds a sine sway to a tail chain on top of whatever the clip does.
local function swayTail(bones: {Bone}, amplitude: number, frequency: number)
	local t0 = os.clock()
	return RunService.PreSimulation:Connect(function()
		local t = os.clock() - t0
		for i, bone in bones do
			-- Phase lag down the chain gives a travelling wave; amplitude grows toward the tip.
			local a = amplitude * (i / #bones) * math.sin(2 * math.pi * frequency * t - i * 0.6)
			bone.Transform = bone.Transform * CFrame.Angles(0, a, 0)
		end
	end)
end
```
Caution: if the clip does **not** key these bones, the Animator does not rewrite them, and `bone.Transform * extra` accumulates every frame. For bones no clip touches, keep your own base (`rest * extra`) and assign it, never multiply onto the previous value. The same applies on Animator throttled frames (see [[Animator Deep Dive]]).

### Reading where a bone is
```lua
local handWorld: CFrame = handBone.TransformedWorldCFrame -- animated, this frame's evaluation
```
Use it to spawn projectiles from a mouth, drop a detached part where it really is, or aim VFX. Read it after the Animator has run (PreSimulation or later). One enemy system dropped "detachable" armour pieces as a copy placed at the bone's **animated** pose, then faded it: using `WorldCFrame` instead would have spawned the piece at the bind pose, metres away from where the player saw it.

## Bone adapters: when your tools speak Motor6D

Many tools (Lua players, ground fitters, look-at code) were written for Motor6D rigs. A thin adapter that exposes bones with the same interface lets them work on skinned rigs:

| Motor6D concept | Bone equivalent |
|---|---|
| `joint.Transform` | `bone.Transform` |
| Part1 name (for matching) | `bone.Name` |
| `Part0.CFrame * C0` (joint frame in world, unanimated child) | parent's `TransformedWorldCFrame * bone.CFrame` |
| `Part1.CFrame` (animated) | `bone.TransformedWorldCFrame` |

One production "bone adapter" for death ground-fitting did this: sample a 3x3 grid of ground heights under the creature, find the deepest bone below the ground, lift the `Root` child bone by that depth minus a skin pad, and tilt to the slope. It ran right after the frame's animation writes. See [[Ground Fitting Pipeline]].

## Clip conventions that make skinned creatures reusable

From one game's creature "family" conventions (rules of thumb that held across 20 enemy kits):
- Rest pose A-pose with arms about 40 degrees down; bone roll so +X is the creature's right, which makes +X rotation lift a limb forward consistently.
- Shared clips are **rotation-only**, plus root-child translation at the family's reference height. Retarget the root translation to other members by their height ratio.
- Clips match by name, so the same clip also plays on a part-based rig whose parts are named like the bones.
- Rigid props attach with `RigidConstraint` to a bone.
- Pieces that only spin (orbiting rings, halos, lanterns) are better **stripped from the clips and spun client-side**: they cost keys every frame in the clip and look identical procedurally. One boss with 42 bones and 23 clips had its orbiting pieces removed from every clip this way.
- Markers like `Tele`, `Hit`, `Proj`, `Step`, `FX_<name>` are exported to the enemy's data so the server never needs to load the clip.

## Skinned avatars

Roblox avatar bodies can be skinned meshes across the 15 R15 body parts: the parts and their joints (Motor6D or AnimationConstraint) still exist and are what clips drive; the skinning lets the mesh deform smoothly across part boundaries. Animating them is the same as animating any R15 rig: Poses named after the parts. Layered clothing then wraps the deformed body (see [[Layered Clothing Cages and Animation]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Root motion on the `Root` bone | Creature never lifts or travels | Key the root's child |
| Using `Bone.WorldCFrame` for animated position | Effects spawn at the bind pose | `TransformedWorldCFrame` |
| Relying on MeshPart collision for animated limbs | Swipes pass through players; hits land on empty air | Hitbox parts on bones, or data-driven hits |
| Renaming bones after authoring | Clips play, nothing moves | Keep names stable; rename in clip data too |
| More than 4 influences per vertex in the source | Import warnings or lost weights | Limit and normalise in Blender before export |
| Multiplying onto `Transform` of bones no clip keys | Endless spinning or drift | Assign from your own base |
| Many identical creatures each with long bone chains | CPU cost scales with bones x rigs | LOD the animation (see [[Animation LOD]]), simplify chains |

## See also
[[Rigs and Joints]] · [[Motor6D Math and CFrame Composition]] · [[Weight Painting and Skinning for Roblox]] · [[Creature Rig Conventions]] · [[Rigging in Blender]] · [[Pipeline - Importing Animated Enemies]] · [[Animating Creatures and Monsters]]

## Nuances and edge cases

1. **Skinning cost lands on the client's GPU and CPU together.** Per-bone transforms are CPU work; per-vertex deformation is mostly GPU work. A 10,000-triangle creature with 40 bones is fine alone. Thirty of them on screen on a low-end phone can cost more than the rest of the scene. Budget creatures by "bones times visible instances" and "triangles times visible instances", not per asset. Mesh LOD helps the vertex side; animation LOD helps the bone side; you usually need both.
2. **Rigid accessories on bones.** Props attached to bones through a `RigidConstraint` follow the bone's animated transform. At large distances where the rig's animation is throttled, props and mesh still agree because both follow the same bone, but anything you position manually from `TransformedWorldCFrame` in a script updates only when your script runs. Prefer constraints to script-driven attachment.
3. **Collision is the bind pose.** This is the most important design nuance: a skinned dragon's collision is its rest pose. If players can walk under the raised wing in the bind pose, they can also walk through the wing when it sweeps down. Decide early whether the creature's body blocks players (simple invisible collision parts on bones) or not (`CanCollide = false` on the mesh, hitboxes for damage only).
4. **Hitbox parts on bones and network ownership.** Unanchored hitbox parts welded to a server-owned creature are fine. Hitbox parts on a client-owned creature (a player-controlled mount or form) are owned by that client and can be moved by an exploiter. Do server-side hit checks from bone transforms computed from server data, not from client-owned hitbox positions.
5. **Weight painting quality shows at extremes.** Joints that bend past about 90 degrees (elbows, knees, necks of creatures) expose candy-wrapper twisting and volume loss. Helper bones (twist bones on forearms) fix it but cost bones. Spend them on hero creatures and close-up characters, not on crowd enemies.
6. **Import validation changes over time.** Studio's importer warnings and accepted specs have changed across versions (for example around bone counts, influences and naming). Re-check the current modeling specifications page before a large import batch rather than relying on last year's checklist.
7. **Avatar skinned bodies vary.** Player avatars can be skinned meshes from the marketplace with their own weights. Procedural code that assumes a particular deformation (a breathing chest scale, a squash on landing) can look different on different avatars. Keep procedural layers on joints, not on assumptions about how a body deforms.

## Common mistakes in production

1. **Creature budgets per asset only.** Symptom: each creature passes review, the wave mode lags on phones. Fix: budget by visible count times bones and triangles.
2. **Hit detection from client-owned bone hitboxes.** Symptom: exploitable reach for transformed players or mounts. Fix: server computes hits from data and server-side transforms.
3. **Twist bones on every enemy.** Symptom: CPU cost with no visible benefit at gameplay distance. Fix: twist bones only on hero rigs.
4. **Body collision left on a big skinned mesh.** Symptom: players stuck on invisible bind-pose wings and tails. Fix: turn off mesh collision, add simple collision parts where the body should block.
5. **Scripted prop attachment from `TransformedWorldCFrame`.** Symptom: props lag a frame or jitter on far creatures. Fix: attach with constraints to the bone.

## Related decisions

- [[Organic and Creature Modeling]]: modeling creatures with deformation and bone counts in mind.
- [[Exporting and Validating Models for Roblox]]: current import specs for skinned meshes.
- [[Topology and Edge Flow]]: topology that bends well at joints.
- [[Hitboxes and Hit Detection]]: hitboxes that follow animated limbs without trusting clients.
- [[Collision and Physics Geometry]]: why skinned collision is the bind pose and what to use instead.
- [[Art Budgets - Triangles Draw Calls Memory]]: budgeting creatures by visible count.
- [[Mesh Optimization for Mobile]]: reducing vertex cost for skinned meshes on phones.
- [[Character and Creature Pipeline]]: the end to end path from Blender rig to animated creature.
- [[Matching a Concept Sheet - Boss Creature Case Study]]: a worked boss creature build.

## Connected notes
<!-- auto-links:start -->
[[Skinning Weights]] · [[Skeleton Library]] · [[Modeling Characters for R15 and Custom Rigs]] · [[3D Importer Settings Reference]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Modeling Fundamentals for Games]] · [[Animation Start Here]]
<!-- auto-links:end -->
