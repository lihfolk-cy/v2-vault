---
tags: [modeling, characters, r15, avatar, custom-rigs, proportions, blender, python, type/guide, area/modeling, level/intermediate, api/Motor6D]
---
# Modeling Characters for R15 and Custom Rigs

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No R15 proxy while modelling -> Build the proxy; model on its pivots
> - Avoid: Shoulder geometry centred on the arm's centre -> Cap centred on the inner-top shoulder pivot
> - Avoid: Modelling 15 parts separately -> Model one body, then cut and cap
> - Route chosen: A (avatar body), B (R15-compatible), or C (custom rig).
> - R15 proxy in the scene at the right scale; character faces -Y.
> - Joint geometry centred on R15 pivots (inner-top shoulder, hips, knees, elbows).
>
> Cost: TL;DR ~160 tok · whole note ~4.3k tok. Read more: ## 2. R15 proportions and pivots (measured) · ## 3. A Blender proxy that matches R15 · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A character model on Roblox is never just a mesh. It has to match a rig contract: the R15 skeleton that the default Animate script, emotes, accessories, layered clothing and most community animations assume, or a custom rig that your own code drives. Modelling a character without knowing which contract it targets is the most expensive mistake in character art: the result either cannot use any existing animation, or cannot wear any accessory, or does not fit the hit boxes the game was balanced around.

This note covers the three routes (a marketplace-grade R15 body, an R15-compatible game character, and a custom rig), the R15 proportions and pivots measured from a real rig, how to set up a proxy in Blender so your model lands on those pivots, how to model armour and outfits that fit every body, and the reference project's characters, NPCs and pets as examples. Rigging and weights are in the Animation section ([[Rigging in Blender]], [[Weight Painting and Skinning for Roblox]]); this note stops at the mesh.

---

## 1. Pick the route

| Route | What it is | Animations | Accessories / clothing | Effort |
|---|---|---|---|---|
| **A. R15 avatar body (spec-compliant)** | 15 skinned `_Geo` meshes on the R15 skeleton, cages, attachments; passes Roblox's body validation | All R15 animations, emotes | Yes, including layered clothing | Highest |
| **B. R15-compatible game character** | A StarterCharacter or NPC with the 15 R15 part names and joints, rigid or skinned meshes, not validated for the Marketplace | All R15 animations | Rigid accessories by attachment name; layered clothing only with cages | Medium |
| **C. Custom rig** | Any skeleton or part hierarchy driven by an `AnimationController` | Only clips made for it | Your own system | Varies |

- Avatar bodies sold or used as avatars: **A**, following Roblox's specification exactly ([[R15 Rig Anatomy and Attachments]] section 5 summarises it; [[UGC Avatar Items and Accessories]] covers the validation side).
- Player characters in a game that should still play default and community animations: **B**.
- Creatures, bosses, pets, vehicles, anything non-humanoid: **C** ([[Organic and Creature Modeling]], [[Creature Rig Conventions]]).

---

## 2. R15 proportions and pivots (measured)

Measured in Studio (October 2026) on a default blocky R15 rig, studs, relative to the HumanoidRootPart centre, +X right, +Y up, -Z forward (from [[R15 Rig Anatomy and Attachments]]):

| Part | Size (X, Y, Z) | Centre |
|---|---|---|
| HumanoidRootPart | 2.000, 2.000, 1.000 | 0, 0, 0 |
| Head | 1.159, 1.182, 1.161 | 0, 1.586, 0 |
| UpperTorso | 1.943, 1.698, 1.004 | 0, 0.200, 0 |
| LowerTorso | 1.991, 0.401, 1.004 | 0, -0.800, 0 |
| Left/RightUpperArm | 1.001, 1.242, 1.002 | -/+1.500, 0.369, 0 |
| Left/RightLowerArm | 1.001, 1.118, 1.002 | -/+1.500, -0.224, 0 |
| Left/RightHand | 0.984, 0.316, 1.028 | -/+1.500, -0.850, 0 |
| Left/RightUpperLeg | 0.993, 1.363, 0.973 | -/+0.500, -1.421, 0 |
| Left/RightLowerLeg | 0.993, 1.301, 0.973 | -/+0.500, -2.201, 0 |
| Left/RightFoot | 1.009, 0.312, 1.001 | -/+0.500, -2.850, 0 |

Key facts for modellers:

- **Height** about 5.2 studs as stored (head top +2.18, soles -3.01 from the root centre), and about 5.5 studs once the joints solve in game (soles -3.19, matching `HipHeight` 2.19). The table above is the stored layout; see [[R15 Rig Anatomy and Attachments]] for the jointed centres.
- **The shoulder pivot is at the inner top edge of the upper arm** (0.501 studs in from the arm's centre line, 0.419 up), not at the arm's centre. Model shoulder geometry so it rotates cleanly around that point: a rounded deltoid cap centred there, not a square block corner.
- **Elbow pivot** 0.355 below the upper arm's centre; **knee pivot** 0.449 below the upper leg's centre; **hip pivots** at ±0.5, 0.2 below the LowerTorso centre; **neck** 0.849 above the UpperTorso centre.
- Blocky legs are short relative to typical game characters, which affects how walk cycles look ([[Locomotion Systems]]).
- Scaled bodies: the Humanoid's body scale values resize parts and move attachments. The reference project played at 1.6x through body scales (about 9 studs tall, hip about 3.5 studs above ground). Model at scale 1 for R15 bodies (the scaling system does the rest); model game NPCs and outfits at the scale they will be used, or at 1 with a known scale factor.

### Proportion choices for stylised characters

The default blocky body is roughly 4.4 heads tall. Stylised game characters typically use:

| Style | Heads tall | Notes |
|---|---|---|
| Chibi / cute | 2-3 | Big head, tiny body: emotes read, weapons look huge |
| Blocky classic | about 4-4.5 | The default R15 look |
| Heroic stylised | 5-6 | Rthro-like; longer legs |
| Realistic | 7-8 | Rarely right for Roblox's camera and screens |

Whatever you choose, keep the **joint pivots** of route A and B characters where R15 expects them relative to each part, or default animations will bend limbs at the wrong place.

---

## 3. A Blender proxy that matches R15

Model on top of a proxy built from the measured table so your parts and pivots land where Roblox expects them. With GLB export (+Y up) and Studio's import turn, Blender (x, y, z) arrives as Roblox (-x, z, y) ([[Enemy Import Axis Fix]]): so a character facing Blender -Y faces Roblox -Z, and its **right side is Blender -X**.

```python
# Blender: build an R15 proxy (boxes at measured sizes) standing on the floor, facing -Y.
# Roblox (X, Y, Z) relative to HumanoidRootPart -> Blender (-X, Z, Y), lifted so the soles sit at z = 0.
import bpy

SOLE = 3.01            # stored layout: soles 3.01 below the root centre (3.19 once jointed in game)
SCALE = 1.0            # set 1.6 to match a game that scales players 1.6x

R15 = {  # name: (size X, Y, Z), centre X, Y, Z   (Roblox space, studs)
    "HumanoidRootPart": ((2.000, 2.000, 1.000), (0, 0, 0)),
    "Head":            ((1.159, 1.182, 1.161), (0, 1.586, 0)),
    "UpperTorso":      ((1.943, 1.698, 1.004), (0, 0.200, 0)),
    "LowerTorso":      ((1.991, 0.401, 1.004), (0, -0.800, 0)),
    "LeftUpperArm":    ((1.001, 1.242, 1.002), (-1.5, 0.369, 0)),
    "RightUpperArm":   ((1.001, 1.242, 1.002), (1.5, 0.369, 0)),
    "LeftLowerArm":    ((1.001, 1.118, 1.002), (-1.5, -0.224, 0)),
    "RightLowerArm":   ((1.001, 1.118, 1.002), (1.5, -0.224, 0)),
    "LeftHand":        ((0.984, 0.316, 1.028), (-1.5, -0.850, 0)),
    "RightHand":       ((0.984, 0.316, 1.028), (1.5, -0.850, 0)),
    "LeftUpperLeg":    ((0.993, 1.363, 0.973), (-0.5, -1.421, 0)),
    "RightUpperLeg":   ((0.993, 1.363, 0.973), (0.5, -1.421, 0)),
    "LeftLowerLeg":    ((0.993, 1.301, 0.973), (-0.5, -2.201, 0)),
    "RightLowerLeg":   ((0.993, 1.301, 0.973), (0.5, -2.201, 0)),
    "LeftFoot":        ((1.009, 0.312, 1.001), (-0.5, -2.850, 0)),
    "RightFoot":       ((1.009, 0.312, 1.001), (0.5, -2.850, 0)),
}

col = bpy.data.collections.get("R15_Proxy") or bpy.data.collections.new("R15_Proxy")
if col.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(col)

for name, ((sx, sy, sz), (cx, cy, cz)) in R15.items():
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    ob = bpy.context.active_object
    ob.name = "Proxy_" + name
    ob.scale = (sx * SCALE, sz * SCALE, sy * SCALE)                 # Roblox X,Z,Y sizes -> Blender X,Y,Z
    ob.location = (-cx * SCALE, cz * SCALE, (cy + SOLE) * SCALE)     # Roblox -> Blender, feet on floor
    ob.display_type = 'WIRE'
    ob.hide_render = True
    for c in ob.users_collection:
        c.objects.unlink(ob)
    col.objects.link(ob)
    if name == "HumanoidRootPart":
        ob.hide_set(True)                                            # usually invisible; keep for reference
```

Exclude the `R15_Proxy` collection from export. Add empties at the joint pivots from the RigAttachment table in [[R15 Rig Anatomy and Attachments]] if you need them visible while modelling shoulders and hips. If you export with FBX instead of GLB, re-check the facing once with a marked front: the axis mapping depends on the exporter settings.

---

## 4. Route A: spec-compliant R15 bodies (summary)

Roblox's character body specification (Creator Hub, see [[R15 Rig Anatomy and Attachments]] section 5 and [[UGC Avatar Items and Accessories]]):

- **15 meshes** named `<Part>_Geo`, each limb capped to be watertight when separated.
- Skeleton `Root > HumanoidRootNode > LowerTorso > ...`; LowerTorso and Root at 0,0,0; only the upper arms may carry rotation (A or T rest pose); facing +Z, up +Y in the exported file; transforms frozen.
- Attachments from meshes with the `_Att` suffix; cages (`_InnerCage`, `_OuterCage`) for layered clothing.
- Skinning: at most 4 influences, none on the root, symmetric.
- **Triangle budgets: head 4,000, torso 1,750, each limb 1,248, total 10,742.**
- Bounding boxes per part and in total (total between 1.0 x 4.0 x 0.5 and 8.0 x 10.0 x 4.0 studs).

Modelling consequences:

- 1,248 triangles for a whole leg segment set is tight: limbs must be simple tubes with good joint loops ([[Topology and Edge Flow]]). Spend detail on the head, which has a third of the budget.
- Model as one continuous body, then **split along the R15 cut lines** into 15 meshes and cap each cut. Cutting first and modelling pieces separately gives mismatched seams.
- Keep the border loops at each cut matching on both sides so the body looks continuous at rest.
- Follow Roblox's spec documents for the exact export settings (FBX is the documented route for avatar bodies; see [[Exporting FBX vs GLB]]).

---

## 5. Route B: R15-compatible game characters

Many games want a custom look for players or NPCs without Marketplace validation. The engine only needs the 15 parts with R15 names, the RigAttachments, joints and a Humanoid; see [[Custom Characters and StarterCharacter]].

### Rigid per-part characters (the simplest custom character)

Model each body part as its own rigid mesh, fitted to the part's box and pivots:

1. Model on the proxy; each piece's **origin at its part centre** (where the R15 part's CFrame is).
2. Shape joints as overlapping caps (a rounded shoulder cap that rotates inside the torso's armhole; a knee cap) so bending shows no gap ([[Organic and Creature Modeling]]).
3. Name objects exactly like the parts (`LeftUpperArm`).
4. In Studio, replace each part's mesh in a copy of an R15 rig (or build the rig and set `MeshId`/sizes), keeping every RigAttachment and joint. `Humanoid:BuildRigFromAttachments()` rebuilds joints from matching RigAttachment pairs.

This gives a toy or armoured look with zero skinning work, and every R15 animation plays.

### Skinned custom bodies

For organic custom bodies, follow route A's structure (15 meshes on the R15 skeleton) without needing every validation rule. Keep: part names, skeleton names and hierarchy, zero-rotation rest frames, 4 influences. Do not add bones between existing R15 joints (for example a separate neck bone between UpperTorso and Head): R15 clips would stop driving the head ([[R15 Rig Anatomy and Attachments]] common mistakes).

### NPCs from the default body plus an outfit

The cheapest good-looking NPC: a default R15 body (scaled), with modelled outfit pieces welded to body parts. The reference project's shopkeeper was "R15 default body (scale 1.7) + Blender outfit (turban, beard, vest, belt, cuffs, blade, rag, coin)", animated procedurally (polish, look, wave, head turn) by writing joint transforms. No custom rig, every R15 tool works.

---

## 6. Armour and outfits that fit every body

Worn pieces must follow the body through every animation and fit every body scale. The reference project's method for 156 armour meshes (13 pieces per set, 6 sets plus glow companions):

- **Author each piece in its body part's local space**, against a measured reference rig at scale 1.
- **Fit-check every mesh against its own part box and every other R15 part box at rest**: 0 intrusions shipped.
- **Leave limb inner sides open** (toward the torso or the other leg), so arms and legs do not collide with their own armour.
- **Respect joint zones**: pauldrons above the lower-arm box, bracers within y -0.45 to -0.03 of the lower arm, thigh plates stop above the knee, shin plates below it (with a knee cop in front).
- **Scale per axis at runtime**: each piece is cloned, scaled per axis by the wearer's part size divided by the reference size, and welded (Massless, no collisions) to its body part with a stored fit offset. No joint, Motor6D or scale value on the character is touched, so every animation is unchanged.
- **Budget**: max 3,140 triangles per mesh, 15.0k-20.3k per set (glows included).

That is a rigid-accessory approach, good for plates and helmets. Cloth that must stretch (sleeves, capes, skirts) needs layered clothing with cages; see [[Layered Clothing Cages and Animation]] and [[Accessories and Armor That Follow Animation]].

---

## 7. Route C: custom rigs

For non-humanoids, the rig contract is yours. Use the reference project's conventions ([[Creature Rig Conventions]]) as a template:

| Convention | Value |
|---|---|
| Units and size | 1 Blender unit = 1 stud; author at final stud height |
| Facing | -Y in Blender (lands on Roblox -Z) |
| Root | Armature at the origin; one armature per file |
| Root motion | On a body bone, not the top-level root (the top-level root pose is not applied) |
| Bone roll | Local X = creature right, so +X rotation lifts a limb forward (matches R15) |
| Export | GLB, transforms applied, +Y up; import Scale Unit Stud |

Part-based (Motor6D) custom rigs follow the segmented modelling rules: one object per rigid piece, origin at its joint. The project's pets were Motor6D part rigs built by an auto-fit installer from a rig description (part centres and roles per species); a healthy install reported "fit err 0.002, 11 motors, 27 welded pieces" ([[Custom Rigs - Weapons and Props]] section 6). For that kind of automation, model with consistent piece names per species and record joint centres.

---

## 8. Heads and faces

- Route A heads follow Roblox's dynamic head specification for facial animation ([[Facial Animation and Dynamic Heads]]).
- Stylised game characters often use a **separate face decal or face plate** instead of facial geometry. Keep a flat, evenly-UV'd face area if faces are swapped as textures.
- The head is the most viewed part in close-ups, icons and avatars: the head's 4,000-triangle allowance in the body spec reflects that. Spend triangles on the head before the limbs.

---

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| No R15 proxy while modelling | Limbs bend at the wrong points | Build the proxy; model on its pivots |
| Shoulder geometry centred on the arm's centre | Shoulders shear when arms rise | Cap centred on the inner-top shoulder pivot |
| Modelling 15 parts separately | Mismatched seams | Model one body, then cut and cap |
| Renamed parts or extra bones in the R15 chain | Default Animate, emotes, accessories break | Exact R15 names and hierarchy |
| Armour authored on one scaled body | Intersections on other bodies | Author at reference scale, scale per axis at runtime |
| Closed armour on limb inner sides | Self-collision in animations | Open inner sides |
| Over-budget limbs on avatar bodies | Validation fails | 1,248 per limb; detail on the head |
| Character facing +Y in Blender | Walks backwards | Face -Y (GLB route) |

## Checklist

- [ ] Route chosen: A (avatar body), B (R15-compatible), or C (custom rig).
- [ ] R15 proxy in the scene at the right scale; character faces -Y.
- [ ] Joint geometry centred on R15 pivots (inner-top shoulder, hips, knees, elbows).
- [ ] Route A: 15 `_Geo` meshes, capped, budgets 4,000 / 1,750 / 1,248, cages and `_Att` markers, FBX per spec.
- [ ] Route B: exact part names; RigAttachments preserved; no extra bones in the R15 chain.
- [ ] Armour: authored in part space, 0 intrusions, inner sides open, per-mesh budget.
- [ ] Route C: conventions table written for the project and followed.

## See also

[[R15 Rig Anatomy and Attachments]] · [[Custom Characters and StarterCharacter]] · [[Rigging in Blender]] · [[Weight Painting and Skinning for Roblox]] · [[Creature Rig Conventions]] · [[Accessories and Armor That Follow Animation]] · [[Layered Clothing Cages and Animation]] · [[UGC Avatar Items and Accessories]] · [[Characters and Humanoids]] · [[Character and Creature Pipeline]] · [[Topology and Edge Flow]]

## Connected notes
<!-- auto-links:start -->
[[Voxel Characters - Proportions Joints and Rigging]] · Skinning Weights · 3D Importer Settings Reference · Skeleton Library · Bones and Skinned Meshes · Rigs and Joints
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[3D Importer Settings Reference]] · [[Rigs and Joints]] · [[Blender Workflow for Roblox Creators]] · [[Modeling Weapons and Props]] · [[Modeling Fundamentals for Games]] · [[Exporting and Validating Models for Roblox]] · [[UV Unwrapping]] · [[Hard-Surface Modeling]] · [[Procedural Creatures - Fused Shells, Quad Cages and Faceting]] · [[Voxel and Blocky Modeling]]
<!-- related:end -->
