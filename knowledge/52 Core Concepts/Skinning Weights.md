---
tags: [core-concept, animation, rigging, 3d-modeling]
---
# Skinning Weights

**Skinning weights** say how strongly each bone moves each vertex of a skinned mesh. A vertex on the forearm might be 100 percent forearm bone; a vertex at the elbow might be 50 percent upper arm and 50 percent forearm. The weights are painted or computed in a modelling tool and exported with the mesh.

## Why it matters on Roblox

Roblox supports skinned meshes driven by `Bone` instances, used for creatures, custom characters, layered clothing and soft props. Each vertex can be influenced by at most 4 bones (Roblox docs, "Skinned meshes", as of October 2026). Weights decide whether a joint bends like flesh or collapses like folded paper, and bad weights are one of the most common reasons an imported character looks broken even when the animation is fine.

## The nuance most people miss

1. **Extra influences are dropped, not merged gracefully.** Blender happily paints 6 or 8 bones onto a vertex. On import only the strongest 4 survive and get renormalised, which can create sudden pops. Limit to 4 influences and normalise in Blender before exporting.
2. **Weights must sum to 1.** Unnormalised weights shrink or inflate vertices when bones move. Normalise all before export.
3. **Joints need edge loops.** No weight painting saves a joint with one edge loop at the elbow. Two or three loops around each bending joint give the weights room to blend.
4. **Twist needs its own bones or loops.** Forearms and wrists collapse ("candy wrapper") when one bone rotates 90 degrees. Add a twist bone or spread the rotation across loops.
5. **Rigid things should be rigid.** Armour plates, buttons and weapons fused into a skinned mesh should be 100 percent one bone; smooth weights there make metal bend.
6. **Test at extreme poses.** Weights that look fine in idle break at full crouch or arm-over-head. Make a test animation with extreme poses and check it in Studio, not only in Blender.

## Tiny example

An elbow with weights blended evenly from 0 to 100 percent across five edge loops bends smoothly to 120 degrees. The same elbow with a hard 50/50 split on one loop pinches the inside of the arm into a sharp crease at 90 degrees. The fix is geometry first (add loops) and weights second (spread the blend), not the reverse.

## Where this shows up

- [[Weight Painting and Skinning for Roblox]]: the deep dive.
- [[Bones and Skinned Meshes]]: how Roblox drives skinned meshes.
- [[Rigging in Blender]]: building the skeleton.
- [[Topology and Edge Flow]]: loops that make good weights possible.
- [[Modeling Characters for R15 and Custom Rigs]]: characters that deform well.
- [[Organic and Creature Modeling]]: creatures that bend.
- [[Layered Clothing Cages and Animation]]: weights on clothing.
- [[Layered Clothing Creation Workflow]]: the UGC version.
- [[Character and Creature Pipeline]]: weights as a pipeline step.
- [[Exporting FBX vs GLB]]: export settings for skin data.
- [[Debugging Animation Problems]]: telling bad weights from bad animation.
- [[Chibi Character Rules in Practice]]: simple characters with simple weights.
- [[Skeleton Library]]: ready skeletons to weight against.

Related concepts: [[Triangle Budget]], [[Texel Density]], [[Anticipation]].

## Connected notes
<!-- auto-links:start -->
[[Voxel Characters - Proportions Joints and Rigging]] · [[Matching a Concept Sheet - Boss Creature Case Study]] · [[3D Importer Settings Reference]] · [[Snippets - IK]] · [[Accessories and Armor That Follow Animation]] · [[Facial Animation and Dynamic Heads]] · [[Core Concepts Start Here]]
<!-- auto-links:end -->
