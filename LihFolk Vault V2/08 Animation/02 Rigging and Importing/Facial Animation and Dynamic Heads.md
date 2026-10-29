---
tags: [rigging, facial, dynamic-heads, facs, facecontrols, blender, type/guide, area/animation, level/intermediate, api/FaceControls, area/modeling]
---
# Facial Animation and Dynamic Heads

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Frame 0 not neutral, or Animation Offset not 0 on import -> Neutral at frame 0; offset 0
> - Avoid: Same FACS name on two frames -> One frame per pose
> - Avoid: Corrective with 4 names -> At most 3 names
>
> Cost: TL;DR ~90 tok · whole note ~3.1k tok. Read more: ## 1. How a dynamic head works · ## 2. Building a dynamic head in Blender (Roblox's process) · ## Common mistakes
<!-- tldr:end -->

Roblox faces come in two very different technologies. **Dynamic heads** are skinned head meshes driven by a standard set of [[FACS]] controls through a `FaceControls` instance; they work with the Animation Editor's face tools, camera-based capture and avatar systems. **Custom faces** on your own rigs are just bones or parts (a jaw hinge, eyelids, swapped decals) animated like any other joint. This note covers both, with the Roblox specifications (Creator Hub, checked October 2026) and the craft choices behind them.

## 1. How a dynamic head works

- The head is a MeshPart (`Head_Geo` in the source file) skinned to **face joints** that hang under a **root face joint** (conventionally `DynamicHead`) under the R15 `Head` bone.
- On import Studio creates a **`FaceControls`** instance on the head. It hides the face joints under the mapped root, and stores pose data, including the correction data for combination poses.
- You **do not animate the face bones directly**. Roblox docs: "You can't access the facial Bones of a head mesh directly"; you combine [[FaceControls]] poses.
- `FaceControls` exposes **50 number properties**, one per base FACS pose, grouped by region:

| Region | Properties (examples) |
|---|---|
| Brows | `LeftBrowLowerer`, `RightBrowLowerer`, `Corrugator`, `LeftInnerBrowRaiser`, `RightInnerBrowRaiser`, `LeftOuterBrowRaiser`, `RightOuterBrowRaiser` |
| Eyes | `EyesLookUp`, `EyesLookDown`, `EyesLookLeft`, `EyesLookRight`, `LeftEyeClosed`, `RightEyeClosed`, `LeftEyeUpperLidRaiser`, `RightEyeUpperLidRaiser` |
| Mouth and lips | `LipsTogether`, `LipPresser`, `Pucker`, `FlatPucker`, `Funneler`, `UpperLipSuck`, `LowerLipSuck`, `MouthLeft`, `MouthRight`, `JawDrop`, `JawLeft`, `JawRight`, lip corner, stretcher and upper/lower lip controls |
| Cheeks and nose | `LeftCheekPuff`, `RightCheekPuff`, `LeftCheekRaiser`, `RightCheekRaiser`, `LeftDimpler`, `RightDimpler`, `LeftNoseWrinkler`, `RightNoseWrinkler` |
| Tongue | `TongueOut`, `TongueUp`, `TongueDown` |

Each value is a pose intensity: 0 is neutral, 1 is the pose as authored (Roblox's validation tests use values like 0.85 and 1). The class reference lists these properties as **not replicated**: a value set by a server script does not reach clients. Drive faces with animation tracks (which replicate through the Animator like any clip) or set values on each client.

FACS names follow the **character's** sides, not the viewer's: `LeftEyeClosed` closes the character's left eye.

## 2. Building a dynamic head in Blender (Roblox's process)

### 2.1 Bones

1. Start from an R15 armature. Extrude a child from the `Head` joint and name it **`DynamicHead`**. It must parent all other face joints (another name is allowed if you map it, see 2.4).
2. Eyes: `LeftEye`, `RightEye` under `DynamicHead`, front-facing and horizontal around the irises.
3. Eyelids (8): `LeftUpperOuterEyelid`, `RightUpperOuterEyelid`, `LeftLowerOuterEyelid`, `RightLowerOuterEyelid`, `LeftUpperInnerEyelid`, `RightUpperInnerEyelid`, `LeftLowerInnerEyelid`, `RightLowerInnerEyelid`.
4. Add jaw, lip, cheek, brow and tongue joints as your design needs. Roblox recommends **fewer than 50 face joints** where possible: joint and vertex counts cost performance.
5. Optional controller rig: duplicate the armature as `Controller`, delete non-face bones, suffix them `_Con`, and drive the face joints with Copy Location and Copy Rotation constraints. Animators then pose controllers, and the export bakes the result (the same "bake the helper" idea as in [[Weight Painting and Skinning for Roblox]]).

### 2.2 Skinning

- Weight `Head_Geo` one joint at a time in Weight Paint mode. Pupils fully on their eye joints. Eyelid joints get the vertices nearest them; the **bottom corners** of the eyes matter for cheek-raise poses.
- Auto Normalize on for shared influences; at most 4 influences per vertex like any Roblox mesh.
- Plan the full pose list first: every pose you will need must be reachable by moving joints, and reworking weights after posing means re-posing everything.

### 2.3 Poses on the timeline

| Frame | Content |
|---|---|
| 0 | **Neutral**: every joint and controller at default |
| 1 to N | one FACS pose per frame at its **maximum realistic** intensity |
| after the base poses | combination (corrective) poses |

Key all face joints on every pose frame (Pose mode, select all, Insert Keyframe with Location and Rotation). Set the timeline from 0 to the last pose frame. Roblox suggests saving base poses alphabetically, then combinations.

There are **50 base poses**. The Marketplace requires at least these **17**: `LeftEyeClosed`, `RightEyeClosed`, `EyesLookDown`, `JawDrop`, `Pucker`, `LeftLipCornerPuller`, `RightLipCornerPuller`, `ChinRaiser`, `ChinRaiserUpperLip`, `LeftCheekRaiser`, `RightCheekRaiser`, `LeftInnerBrowRaiser`, `RightInnerBrowRaiser`, `LeftLipCornerDown`, `RightLipCornerDown`, `LeftLowerLipDepressor`, `RightLowerLipDepressor`.

### 2.4 Mapping frames to poses (custom properties)

On the `Head_Geo` object, add **string** custom properties:

| Property | Value |
|---|---|
| `RootFaceJoint` | `DynamicHead` (the root face joint's name) |
| `Frame0`, `Frame1`, ... | the exact FACS name for that frame (`EyesLookLeft`), or for a combination the base names joined by underscores (`Funneler_JawDrop_Pucker`) |

Rules from the docs: each FACS pose or corrective maps to **one** frame only; a frame must hold the neutral pose; correctives use **at most 3** control names; names must match the standard FACS names exactly; joint names must be unique. Unmapped poses, empty strings or duplicate mappings fail the import. Errors you will see include "Duplicate control name found" and a `FrameX` property pointing at a frame the timeline does not have.

### 2.5 Correctives: why and when

Linear combinations of poses break where two poses move the same vertices: `LeftEyeClosed` plus `LeftCheekRaiser` drives the lower lid into the upper lid. A corrective frame holds the **desired** combined shape; Studio stores the difference and applies it when both controls are active. Author correctives only where you see collisions or volume loss in testing (eyes closed while smiling, jaw open while puckering), not for every pair: each one is extra data and authoring work.

### 2.6 Export and import

- FBX export: select everything under the head's objects; Include > **Custom Properties** on; Armature > **Add Leaf Bones** off; **Animation** on with **NLA Strips**, **All Actions** and **Force Start/End Keyframes** off.
- Studio import: set **Animation Offset** to 0 so frame 0 (neutral) is included. The head gets its `FaceControls`.
- Apply the head texture to the head MeshPart.
- Avatar Setup can generate a head cage and facial animation components automatically, which you can edit or export as glTF to refine elsewhere.

## 3. Validation (Marketplace heads)

The outer cage must mark three **landmarks** (left eye, right eye, mouth; mouth landmark vertices on the second vertex loop from the mouth opening), even for non-human faces. Validation then runs five actions and fails if the head does not deform at those landmarks:

| Action | Controls set |
|---|---|
| Left blink | `LeftEyeClosed` = 1, `EyesLookDown` = 1 |
| Right blink | `RightEyeClosed` = 1, `EyesLookDown` = 1 |
| Mouth open | `JawDrop` = 1 |
| Happy | `Pucker`, `LeftLipCornerPuller`, `RightLipCornerPuller` = 1 |
| Sad | `ChinRaiser`, `ChinRaiserUpperLip`, both `InnerBrowRaiser`, both `LipCornerDown`, both `LowerLipDepressor` = 1; both `CheekRaiser` = 0.85 |

Marketplace bodies also require Plastic material, Transparency 0, VertexColor 1, 1, 1, no scripts or extra parts, and eyebrows and eyelashes as separate Accessory objects bundled with the body or makeup.

## 4. Animating faces

- **Animation Editor:** face tracks key FaceControls properties; Roblox's docs describe animating by adding individual tracks or with the **Face Animation Editor**. See [[Animation Editor Advanced]].
- **Capture:** camera-based face capture records FaceControls from a webcam. See [[Animation Capture and Mocap]].
- **In saved clips:** face channels are numbers, not CFrames. The engine has a `NumberPose` class (a `PoseBase` with a single numeric `Value`) for such channels. Inspect a saved face clip in your Studio to see the exact hierarchy the editor writes before generating face clips in code.
- **Layering:** a face-only clip keys only FaceControls channels, so it layers over body clips without touching joints. Keep face clips separate from body clips; it makes reuse (the same blink on every idle) trivial.
- **Procedural faces** (blinks, look-at with the eyes, lip flap for dialogue) can be driven on the client by setting FaceControls values each frame, keeping in mind they do not replicate. A random blink every 2-6 s (rule of thumb), closing over about 0.06 s and opening over about 0.1 s, makes any idle look alive.

## 5. Faces on your own rigs (no FaceControls)

Most game creatures do not need FACS. Options, cheapest first:

| Technique | How | Good for |
|---|---|---|
| Texture swap | Swap the face decal or `TextureID` per expression; flipbooks for blinks | Stylised characters, mascots, blocky NPCs |
| Jaw on a hinge | A `Jaw` bone (skinned) or a jaw part on a Motor6D, keyed in clips | Roars, bites, talking creatures |
| Eyelids and brows as parts | Small parts on Motor6Ds; or neon eye pieces toggled | Robots, masks, golems |
| Bone-driven face | A few skinned face bones in normal clips | Bosses that need snarls and grins |

The reference project built creature heads with the skull "in anatomical order" and a **lofted jaw on the real hinge**, so pieces carried bones `Head` and `Jaw` and attack clips could open the mouth for bites and roars. Craft notes:

- Put the jaw pivot at the **jaw joint** (in front of and below the ear on a mammal), not at the mouth corners. Opening then swings the chin down and slightly back, which reads as a real bite; a pivot at the mouth corners makes the jaw slide like a drawer.
- Exaggerate: a creature roar reads at 40-60 degrees of jaw open at game distance (rule of thumb), far beyond anatomy.
- Teeth on the jaw part or rigidly on the jaw bone, never skinned across the hinge.
- Eye glows and pupils as separate parts welded to the head (the project added "cute eyes" to pets as five welded balls per eye), so expressions can tint or scale them in code.

## Common mistakes

| Mistake | Result | Fix |
|---|---|---|
| Frame 0 not neutral, or Animation Offset not 0 on import | Every pose offset by the first pose | Neutral at frame 0; offset 0 |
| Same FACS name on two frames | Import fails ("Duplicate control name found") | One frame per pose |
| Corrective with 4 names | Import fails | At most 3 names |
| Face joints outside `DynamicHead` | Not hidden or not driven | Parent every face joint under the root face joint |
| Setting FaceControls on the server | Clients see nothing | Animation tracks, or set on clients |
| Sides authored from the viewer's view | `LeftEyeClosed` closes the right eye | FACS sides are the character's |
| Leaf bones exported | Extra joints under every face chain | Add Leaf Bones off |

## See also

[[Rigging in Blender]] · [[Weight Painting and Skinning for Roblox]] · [[Exporting FBX vs GLB]] · [[R15 Rig Anatomy and Attachments]] · [[Layered Clothing Cages and Animation]] · [[Animation Capture and Mocap]] · [[Animation Editor Advanced]] · [[Animating Creatures and Monsters]] · [[Open Questions]]

## Connected notes
<!-- auto-links:start -->
[[Organic and Creature Modeling]] · Topology and Edge Flow · Modeling Characters for R15 and Custom Rigs · Skinning Weights · Voxel Characters - Proportions Joints and Rigging · Skeleton Library · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Blender Armature and Bone Roll Conventions]] · [[3D Importer Settings Reference]] · [[Creature Rig Conventions]] · [[Bones and Skinned Meshes]] · [[Animation Data from Blender to Roblox]] · [[Custom Characters and StarterCharacter]] · [[Accessories and Armor That Follow Animation]] · [[Importing Models and Rigs]]
<!-- related:end -->
