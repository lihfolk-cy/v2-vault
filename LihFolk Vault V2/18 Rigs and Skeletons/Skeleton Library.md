---
tags: [rigs, skeletons, animation, assets, type/guide, area/animation, level/intermediate, api/Humanoid]
---
# Skeleton Library

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Renaming R15 bones. Symptom: the importer does not build a Humanoid, and catalog animations do nothing.
> - Avoid: Scaling the armature object instead of applying it.
> - Avoid: Joint orientation flipped on one side. Symptom: a mirrored animation bends the left knee the wrong way.
>
> Cost: TL;DR ~110 tok · whole note ~2.1k tok. Read more: ## The rigs · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

Nine starter rigs you can import, animate and reskin. Each folder in this section holds the same rig three ways:

| File | Use it for |
|---|---|
| `.fbx` | Roblox Studio's 3D Importer, or any other engine |
| `.glb` | Roblox Studio's 3D Importer, web viewers, Three.js |
| `.blend` | Editing in Blender: the armature, the bone names and one box mesh per bone |

![[00 Skeleton Library - Overview.png]]

## The rigs

| Rig | Bones | Built for | Sheet |
|---|---|---|---|
| R6_Blocky | 7 | Classic 6-part body, R6 part names | [[R6_Blocky - Rig Sheet.png]] |
| R15_Blocky | 16 | Roblox R15 part names, so the importer builds a Humanoid | [[R15_Blocky - Rig Sheet.png]] |
| Quadruped_Wolf | 26 | Dogs, wolves, horses, mounts: digitigrade back legs, tail, jaw, ears | [[Quadruped_Wolf - Rig Sheet.png]] |
| Bird_Winged | 19 | Birds, dragons, bats: three-bone wings, tail fan | [[Bird_Winged - Rig Sheet.png]] |
| Spider_8Leg | 30 | Spiders, crabs, mechs: eight three-bone legs for procedural IK | [[Spider_8Leg - Rig Sheet.png]] |
| Serpent_Chain | 16 | Snakes, worms, eels, tentacles: a 12-bone spine chain | [[Serpent_Chain - Rig Sheet.png]] |
| Weapon_Sword | 6 | Swords with a hinged or bending blade | [[Weapon_Sword - Rig Sheet.png]] |
| Weapon_Bow | 9 | Bows: bending limbs, string halves, a StringPull bone carrying the arrow | [[Weapon_Bow - Rig Sheet.png]] |
| Weapon_Flail | 8 | Flails, chains, whips: six links between Handle and Head | [[Weapon_Flail - Rig Sheet.png]] |

## How they are built
- **Scale:** 1 Blender unit = 1 stud. In the Roblox 3D Importer set the file dimensions to studs.
- **Facing:** characters face -Y in Blender, which is forward in Roblox after export. Left is +X.
- **Rigid parts:** each box is 100% weighted to one bone, like Roblox's own R6 / R15 bodies. Swap a box for your own mesh, keep the bone name, and the rig still works.
- **Roots:** characters have a `HumanoidRootPart` (R6 / R15) or `RootPart` bone with no mesh. Weapons use `Handle` as the root and grip, so the model drops straight into a Tool.
- **Names:** the R15 rig uses the exact R15 names (UpperTorso, LeftUpperArm, RightFoot...). Renaming them breaks the importer's Humanoid setup.

## Importing into Roblox Studio
1. File > Import 3D, pick the `.fbx` or `.glb`.
2. Set the file dimensions to studs. For R6 / R15, set the rig type to match. For creatures and weapons, import it as a rigged model.
3. Check the joints in the Explorer: one Bone per bone, or Motor6Ds if you rebuild it as parts.
4. Animate with the Animation Editor, or with Blender and export the clip (see [[Animation Start Here]]).

**Measured:** the files were exported from Blender 5.2 and checked by name and size. They have **not** been imported into Roblox Studio in this build, so test-import one before relying on it.

Related: [[Blender Workflow for Roblox Creators]], [[Exporting and Validating Models for Roblox]], [[Concept Sheets]].

## Nuances and edge cases

1. **Rigid boxes versus skinned meshes.** These rigs weight each box 100% to one bone, which is the simplest and most robust setup: no stretching, no weight bugs. The moment you swap a box for one continuous body mesh (a wolf with a single fur mesh, a snake with one skin), you are in skinned mesh territory. Roblox supports up to 4 bone influences per vertex (Roblox docs, as of October 2026), and every joint now needs careful weights at the bends. Budget extra time for the first skinned variant of any rig.
2. **Bone transforms in the rest pose.** Roblox's modeling specification asks for bones with rotation 0, 0, 0 and scale 1, 1, 1 in the bind pose, frozen, with the root bone at the origin (Roblox docs, as of October 2026). Edit a rig in Blender, rotate a bone in edit mode for convenience, forget to reset it, and animations will import offset or twisted. Check the rest pose after any rig edit, not only on first export.
3. **Bones versus Motor6Ds.** An imported rigged model arrives with Bone instances. R15 characters made of separate parts use Motor6Ds. The two animate through the same Animator, but they behave differently: Bones deform skinned meshes and live inside a MeshPart; Motor6Ds connect parts and drive physics assemblies. Tools, ragdolls, hitboxes and equipment usually want parts and Motor6Ds; creatures with one smooth skin want Bones. Pick per rig, and do not mix both on one limb.
4. **One animation per file.** The importer takes one animation track per exported model (Roblox docs, as of October 2026). Exporting a wolf with walk, run and bite in one FBX gives you only one. Export each clip separately from the same rig.
5. **Chains and procedural motion.** The 12-bone serpent spine and the 6-link flail are meant to be driven procedurally (springs, follow-the-leader, IK) as much as by keyframes. Keyframing 12 bones by hand per clip is slow; a code-driven chain costs a little CPU per frame per creature. At 50 serpents on a server, run the chain motion on the client only and replicate just the root.
6. **Spider legs and IK cost.** Eight three-bone legs with per-frame IK is 8 solves per spider. One spider is trivial; 40 spiders in view on a phone is noticeable. Update far spiders at a lower rate or freeze them to canned clips beyond a distance.
7. **Facing and handedness.** The rigs face -Y in Blender so they face forward in Roblox. If you rebuild a rig from scratch and model it facing +Y, every walk cycle will move the character backwards. Keep the convention for any new rig added to the library.
8. **Weapon roots and grips.** The weapons use `Handle` as root so they drop into a Tool. If the visible grip of your replacement sword sits somewhere else on the mesh, the hand will hold the blade. Move the mesh, not the Handle bone.
9. **These files are not tested in Studio.** The note above says so: treat each rig as unverified until one test import works, and record the importer settings that worked next to the rig.

## Common mistakes

1. **Renaming R15 bones.** Symptom: the importer does not build a Humanoid, and catalog animations do nothing. Fix: keep the exact R15 part names.
2. **Scaling the armature object instead of applying it.** Symptom: the rig imports at the right size but animations play with stretched or shrunken limbs. Fix: apply scale in Blender so bones have scale 1.
3. **Joint orientation flipped on one side.** Symptom: a mirrored animation bends the left knee the wrong way. Fix: check bone roll symmetry on both sides before animating.
4. **Leaving the root bone off the origin.** Symptom: the model jumps or offsets on import or when the first animation plays. Fix: place the root at 0, 0, 0.
5. **Anchoring the wrong part.** Symptom: an imported creature falls apart or stays frozen while the animation plays. Fix: anchor the root part only for static display; unanchor for animated, moving creatures.
6. **Animating weapon bones on the server.** Symptom: bow strings jitter or lag behind the hand for other players. Fix: play weapon clips on the client that owns the tool and replicate state, not per-frame poses.

## Related decisions

- [[R15 Rig Anatomy and Attachments]]: the exact part and attachment names the R15 rig depends on.
- [[Bones and Skinned Meshes]]: what changes when a box rig becomes a single skinned mesh.
- [[Weight Painting and Skinning for Roblox]]: the work needed for smooth bends.
- [[Motor6D Math and CFrame Composition]]: how part-based rigs pose under the hood.
- [[Procedural Animation]]: driving serpent and flail chains from code.
- [[Multi-Bone IK - FABRIK and CCD]]: solvers for the spider's legs.
- [[Custom Rigs - Weapons and Props]]: putting the sword, bow and flail rigs into Tools.
- [[Organic and Creature Modeling]]: replacing the boxes with real creature meshes.
- [[Animation LOD]]: lowering update rates for crowds of these creatures.
- [[Avatar Body Types and Scale in Gameplay]]: how player body scales interact with custom rigs.

## Connected notes
<!-- auto-links:start -->
[[Rigging in Blender]] · Modeling Characters for R15 and Custom Rigs · Skinning Weights · 3D Importer Settings Reference · Rigs and Joints · Creature Rig Conventions
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Modeling Characters for R15 and Custom Rigs]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[3D Importer Settings Reference]] · [[Rigs and Joints]] · [[Blender Armature and Bone Roll Conventions]] · [[Skinning Weights]]
<!-- related:end -->
