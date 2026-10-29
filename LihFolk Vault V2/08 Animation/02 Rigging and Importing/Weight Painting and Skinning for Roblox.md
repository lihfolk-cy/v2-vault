---
tags: [rigging, blender, skinning, weights, deformation, type/guide, area/animation, level/intermediate, api/RigidConstraint, area/modeling]
---
# Weight Painting and Skinning for Roblox

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: More than 4 influences -> Limit Total 4, Normalize All, re-export
> - Avoid: Unnormalised weights -> Normalize All; paint with Auto Normalize
> - Avoid: Weights on the root bone -> Move influence to the hips or body bone
> - ROM action covers every joint's extremes.
> - Preserve Volume off while judging.
> - Clean, Limit Total 4, Normalize All.
>
> Cost: TL;DR ~130 tok · whole note ~3.7k tok. Read more: ## 4. Painting workflow in Blender · ## 7. Making joints deform well without correctives · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Skinning decides whether a perfectly keyed animation looks good. A clean clip on bad weights reads as rubber elbows, collapsing wrists and shoulders that cave in; the animator gets blamed. This note covers what Roblox does with your weights, the hard limits, how to paint and generate weights in Blender, how to make joints deform well without the corrective machinery Roblox lacks, and how to test.

## 1. What Roblox does with weights

- A skinned mesh imports as **one MeshPart plus a tree of `Bone` instances**. Each vertex stores up to **4 bone influences** (Roblox docs: "a maximum of 4 bones or joints" per vertex, for meshes, bodies and layered accessories alike).
- At runtime each vertex is moved by the weighted blend of its bones' transforms. Treat it as **linear blend skinning** (the standard game-engine method; Roblox does not document dual-[[Quaternions|quaternion]] skinning). Linear blending is why twisting a forearm 180 degrees pinches it to a point ("candy wrapper") and why a bent elbow loses volume.
- Weights are baked into the mesh asset. **You cannot edit weights in Studio.** Every weight fix is a Blender round trip and a re-import, so get them right before the batch.
- Roblox docs rules: no influences on the **root** bone or joint; keep influences symmetric where possible; freeze bone transforms (scale 1, rotation 0) and keep the root at the origin.
- Bones with no influence are **removed on import** unless "Keep Zero Influence Bones" is enabled in the importer (Roblox docs, File General settings). That matters for socket bones that only carry props (section 6).

## 2. Hard limits and house budgets

| Limit | Value | Source |
|---|---|---|
| Influences per vertex | 4 | Roblox docs |
| Root influences | none | Roblox docs |
| Triangles per mesh | 20,000 | Roblox docs (modeling specifications) |
| Dynamic head face joints | "fewer than 50 where possible" | Roblox docs (dynamic head guide) |
| Avatar body budgets | 10,742 tris total across 15 parts | Roblox docs (body specifications) |
| Deforming bones, regular enemy | 40 | Project house rule |
| Deforming bones, boss | 60 | Project house rule |
| Weight floor | drop influences under about 4% after normalising | Project generator setting |

The project bone budgets were chosen for runtime cost (each Bone is an instance, and a Lua clip player writes every animated joint every frame) and for clip size (instances per KeyframeSequence scale with joints times keys), not because Roblox refused more. Treat them as a starting point.

## 3. The two traps that make Blender lie to you

### Blender normalises for you at display time

Blender's Armature modifier divides each vertex's result by the sum of its weights. A vertex with weights 0.6 + 0.6 looks perfect in Blender. What the exporter writes, and what Roblox then does with a sum of 1.2, is a different story: glTF requires weights that sum to 1 and Blender's glTF exporter normalises, while other routes may not. **Normalise in Blender** (Weights > Normalize All, "Lock Active" off) so that what you see is what ships.

### Blender has no influence limit; the export does

Blender happily deforms a vertex with 7 influences. The glTF exporter keeps a fixed number ("Bone influences", 4 by default; "Include All Bone Influences" off) and drops the smallest, so the shipped deformation differs from the viewport wherever more than 4 bones overlap: shoulders, hips, the base of tails, faces. **Limit in Blender** (Weights > Limit Total, limit 4) and then Normalize All, so the viewport preview equals the result.

Also turn **off** "Preserve Volume" on the Armature modifier while checking deformation. It switches Blender to dual-quaternion skinning, which hides exactly the volume loss that a linear-blend engine will show.

## 4. Painting workflow in Blender

1. **Bind:** parent mesh to armature with Automatic Weights (Ctrl+P > With Automatic Weights). Good start for organic meshes; poor for meshes with many separate islands (stylised armour, voxel shells), where heat diffusion fails and leaves islands unweighted or bleeding into neighbours.
2. **Pose a range-of-motion (ROM) action** before painting: every joint to its extremes, a few frames each (shoulder up, forward, back; elbow fully bent; wrist twist; hip kick and splits; spine bend and twist; neck look around). Paint while scrubbing the ROM, not in rest pose.
3. **Paint with Auto Normalize on** (Tool settings > Options) for areas shared by several bones; it keeps the sum at 1 as you paint.
4. **Use the gradient tool** for long falloffs (spine, tails) instead of brushing.
5. **Clean up:** Weights > Clean (remove weights under a small threshold such as 0.01), Limit Total 4, Normalize All. Optionally Quantize (steps of 0.05 to 0.1) for stylised rigs where crisp transitions look better and make debugging easier.
6. **Mirror:** paint one side, then Mirror vertex group weights (needs Blender-recognised side names; see [[Blender Armature and Bone Roll Conventions]]).
7. **Check for zero-weight vertices:** select by vertex group in Edit Mode or run a script (below). The project rule was "no zero-weight vertices": a vertex with no influence does not follow the skeleton and shows up as a spike or a patch left behind at rest.

```python
import bpy
ob = bpy.context.object
deform = {b.name for b in ob.parent.data.bones if b.use_deform}
idx = {vg.index: vg.name for vg in ob.vertex_groups}
bad, over = [], []
for v in ob.data.vertices:
    ws = [g for g in v.groups if idx.get(g.group) in deform and g.weight > 1e-4]
    if not ws:
        bad.append(v.index)                       # follows nothing
    elif len(ws) > 4:
        over.append(v.index)                      # will be truncated on export
    elif abs(sum(g.weight for g in ws) - 1.0) > 1e-3:
        print("not normalised:", v.index)
print(len(bad), "unweighted,", len(over), "over 4 influences")
```

## 5. Generating weights by script (the project's approach)

For stylised, multi-island meshes the reference project generated weights from a per-island spec instead of painting. Each island ("shell") of the mesh was tagged when it was built, and the spec said how it binds:

| Spec | Meaning | Used for |
|---|---|---|
| `static` | no influence (left to the root part) | rarely; avoid on skinned meshes |
| `('rigid', bone)` | weight 1.0 to one bone | armour plates, claws, horns, teeth, swarm units |
| `('smooth', [bones], power)` | inverse-distance weights to the listed bones' segments | organic skin, tails, cloth, wing membranes |

The smooth weight for a vertex `v` and bone segment `[a, b]` was `1 / (d + 0.05) ^ 4`, where `d` is the distance from `v` to the segment. Keep the 4 largest, normalise, drop any under 4%, normalise again. Why it works:

- **Power 4** gives short, controllable falloff near joints (power 1 or 2 smears every bone over the whole limb).
- The **+0.05** stops a vertex sitting on a bone from getting an infinite weight.
- **Segments, not points**, so a long bone owns its whole length, not just its head.
- Rigid shells never stretch: a horn stays a horn while the skin under it bends.

Swarm-class enemies used rigid binding throughout (one bone per vertex) as a rule-of-thumb saving: rigid sections are cheaper to evaluate and never show blend artefacts.

## 6. Rigid things on skinned rigs: attach, don't skin

Weapons, shields, armour plates, lanterns, a back-mounted arch: anything that must never bend should be a **separate MeshPart attached to a Bone** with a `RigidConstraint` (Bones are Attachments). The project did this for every enemy prop. Advantages:

- The prop keeps its own collision, material, textures and can be **released at runtime** (breakable props, thrown weapons, dropped shields) by disabling the constraint.
- No weights to paint, no influence slots used.
- Swapping props (a different weapon per enemy variant) needs no re-skinning.

Gotchas:

- The socket bone needs to exist after import. If it has no vertex influences, enable **Keep Zero Influence Bones** in the importer, or give it a token influence on a hidden vertex (rule of thumb; the importer option is cleaner).
- Orient the socket bone so its frame matches the prop's grip convention; the prop's offset then lives in `Attachment1` of the constraint, set once.
- `Weld` and `WeldConstraint` connect parts, not Bones. For Bone sockets use `RigidConstraint` (attachment based). See [[Accessories and Armor That Follow Animation]].

## 7. Making joints deform well without correctives

Roblox has no drivers, no shape-key correctives on bodies (dynamic heads are the exception, see [[Facial Animation and Dynamic Heads]]) and no pose-space deformers. What you have is bones, weights and topology. Techniques, roughly in order of value:

### 7.1 Topology at joints
- **Three edge loops** across every bending joint (one at the pivot, one each side), more on the inside of the bend.
- Put the **pivot where the anatomy hinges:** the elbow pivot slightly toward the back of the arm, the knee slightly toward the front. A centred pivot pinches the inside and stretches the outside.
- For blocky and stylised characters, **design the seam instead of hiding it**: overlapping sleeve and cuff shapes, a ball at the elbow, a rigid gauntlet that slides over the forearm. This is why part-based rigs are attractive for hard-surface designs.

### 7.2 Twist distribution
A single forearm bone twisting 90 degrees drags the wrist skin and collapses the forearm. Split the twist:

- Add a **forearm twist bone** (or two) between elbow and wrist, each taking part of the hand's roll.
- In Blender, drive the twist bones with constraints (Copy Rotation, Y only, influence 0.33 and 0.66) from the hand.
- **Bake on export.** Roblox receives the twist bones' keys as ordinary keyframes. The constraint is gone; its result is in the clip.

This "bake the helper" idea is the general Roblox answer to correctives: any helper deform bone driven by constraints or drivers in Blender gets sampled at export and plays in Roblox as keyed motion. The cost is clip size (more animated joints) and the fact that **procedural motion in Roblox** (IK, look-at, springs) will not move the helpers. If your game IK-drives the hand at runtime, drive the twist bone in the same Lua code (for example, set the twist bone's `Transform` to a fraction of the hand roll each frame).

### 7.3 Helper bones for volume
- **Knee and elbow caps:** a small bone at the joint that rotates half the joint angle (baked as above) holds the kneecap or elbow point in shape.
- **Shoulder:** a clavicle bone that takes part of the arm raise prevents the deltoid from collapsing into the neck. Weight the deltoid partly to the clavicle.
- **Hips and buttocks:** weight the upper thigh partly to the pelvis; a hip helper rotating with a fraction of the leg pitch keeps the crease.

### 7.4 Weight falloff width
Make the blend zone about as wide as the joint's thickness. Too narrow and the joint folds like paper; too wide and the whole limb bends like a hose.

### 7.5 Limit the range in the animation, not just the weights
Some poses cannot be skinned well with 4 linear influences (wrist twist past 120 degrees, shoulder raise past 160). Authoring rules and IK limits are part of skinning quality: the project's arm solver clamped wrist flex to 70, deviation to 30 and twist to 85 degrees, partly for this reason. See [[Elbow Poles Swivel and Joint Limits]].

## 8. Testing in Roblox

1. Import the mesh with the ROM action (or build the ROM as a KeyframeSequence from exported data).
2. Play it with an `AnimationController` + `Animator` (or `Animator:StepAnimations(dt)` in Edit; see [[Testing Animations in Studio]]).
3. Compare against the Blender viewport with "Preserve Volume" off. Differences mean influence truncation, unnormalised weights or a wrong bone frame.
4. Check far-from-origin vertices (tail tips, wing tips) for "lag": a sign that a vertex group lost its bone on import (renamed or removed zero-influence bone).

## Common mistakes

| Mistake | On screen | Fix |
|---|---|---|
| More than 4 influences | Shoulders and hips look fine in Blender, crumple in Roblox | Limit Total 4, Normalize All, re-export |
| Unnormalised weights | Parts of the mesh swell or shrink when animated | Normalize All; paint with Auto Normalize |
| Weights on the root bone | Mesh partly ignores root motion, or validation complains | Move influence to the hips or body bone |
| Zero-weight vertices | Spikes stretching back to the rest position | Weight every vertex; run the audit script |
| Vertex group names not matching bones | Region frozen at rest | Rename groups to bone names exactly |
| Helper bones driven only in Blender | Twist and caps work in Blender, not in Roblox | Bake on export; drive from Lua if runtime IK moves the parent |
| Automatic weights on many-island meshes | Islands unweighted or following the wrong bone | Generate per-island weights, or join islands into a proxy and transfer |
| Skinning a weapon to the hand | Weapon bends with wrist blending | Separate MeshPart on a `RigidConstraint` to a socket bone |

## Checklist

- [ ] ROM action covers every joint's extremes.
- [ ] Preserve Volume off while judging.
- [ ] Clean, Limit Total 4, Normalize All.
- [ ] No zero-weight vertices; no root influences.
- [ ] Twist bones for forearms (and thighs on long-legged rigs), baked.
- [ ] Rigid props on socket bones, Keep Zero Influence Bones enabled if sockets have no weights.
- [ ] Test import plays the ROM correctly in Studio.

## See also

[[Rigging in Blender]] · [[Bones and Skinned Meshes]] · [[Blender Armature and Bone Roll Conventions]] · [[Exporting FBX vs GLB]] · [[Layered Clothing Cages and Animation]] · [[Facial Animation and Dynamic Heads]] · [[Accessories and Armor That Follow Animation]] · [[Creature Rig Conventions]]

## Connected notes
<!-- auto-links:start -->
[[Skinning Weights]] · Topology and Edge Flow · Modeling Characters for R15 and Custom Rigs · Organic and Creature Modeling · Voxel Characters - Proportions Joints and Rigging · Layered Clothing Creation Workflow · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Topology and Edge Flow]] · [[Modeling Characters for R15 and Custom Rigs]] · [[3D Importer Settings Reference]] · [[Animation Data from Blender to Roblox]] · [[Retargeting Animations Between Rigs]] · [[Importing Models and Rigs]] · [[R15 Rig Anatomy and Attachments]] · [[Pipeline - Importing Animated Enemies]] · [[Rigs and Joints]] · [[Custom Characters and StarterCharacter]]
<!-- related:end -->
