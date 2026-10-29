---
tags: [rigging, blender, armature, axes, bone-roll, conventions]
---
# Blender Armature and Bone Roll Conventions

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Roll recalculated with different options on different limbs -> One scripted rule for the whole rig
> - Avoid: Editing the rest pose after clips exist -> Re-bake clips from world-space targets, or never touch rest after...
> - Avoid: Assuming glTF +Z front means Roblox +Z front -> Know the measured importer turn; test with the calibration clip
>
> Cost: TL;DR ~130 tok · whole note ~4.2k tok. Read more: ## 2. The axis chain from Blender to Roblox (measured) · ## 4. The roll convention (project rule, recommended) · ## Common mistakes
<!-- tldr:end -->

Axis bugs are the most expensive bugs in a Blender to Roblox pipeline, because they look like animation bugs. An arm that lifts sideways instead of forward, a creature that attacks from behind, a shared clip that works on four family members and twists the fifth: all of these are frame conventions, not keys. This note pins down every frame involved, from Blender world space to a Roblox joint's `Transform`, and gives the conventions one production game used to make one clip drive many rigs.

## 1. What a Blender bone actually is

| Term | Meaning | Python |
|---|---|---|
| Head, tail | Two points in armature space. Only their direction matters to Roblox; the length is cosmetic | `edit_bone.head`, `.tail` |
| Local Y | Always points from head to tail | |
| Roll | Rotation of the bone's X and Z axes about its Y axis | `edit_bone.roll`, `edit_bone.align_roll(vec)` |
| Rest matrix | The bone's rest frame in armature space | `bone.matrix_local` |
| Basis | The animated local transform, relative to rest, in the bone's own frame | `pose_bone.matrix_basis` (what keyframes store) |
| Pose matrix | Posed frame in armature space, after constraints | `pose_bone.matrix` |

Three consequences matter for Roblox:

1. **Bone length is irrelevant to Roblox.** A Roblox `Bone` is an Attachment: a frame, not a segment. The tail only exists to define the Y axis. FBX's "Add Leaf Bones" option adds an extra `_end` bone at every chain tip so other packages can see the last length; Roblox does not need it and the Roblox export docs say to **disable it**.
2. **Roll defines the axes that keys rotate about.** A keyframe that says "rotate 30 degrees about X" means "about this bone's roll-defined X". Two rigs with the same names but different roll will play the same clip differently.
3. **Keys are relative to rest.** Change the rest pose (or roll) after animating and every clip silently changes meaning.

## 2. The axis chain from Blender to Roblox (measured)

### World axes

| Space | Right | Up | Character front |
|---|---|---|---|
| Blender (convention used here) | character right = **-X** | +Z | **-Y** (faces you in Front view) |
| glTF file (exported with "+Y Up") | -X | +Y | **+Z** (the glTF convention for "front") |
| Roblox after the 3D Importer | +X | +Y | **-Z** (`LookVector`) |

The Blender glTF exporter with "+Y Up" maps Blender `(x, y, z)` to glTF `(x, z, -y)`. The reference project then **measured** that Studio's 3D Importer turns each GLB 180 degrees about Y: glTF x and z land on Roblox -x and -z. Composed:

```
Blender (x, y, z)  ->  Roblox (-x, z, y)
```

So a model authored facing **-Y** lands with its front on the Roblox `LookVector`, and its right side (-X in Blender) on Roblox +X. Nothing needs a yaw fix. Older project tools assumed raw glTF axes and defaulted to a 180 degree yaw fix, which put level art backwards; the rule became "pass `YawFix = 0` explicitly", because a stale cached module once served the old default.

This also agrees with the Roblox avatar specification, which asks for bodies that "face positive Z and stand up along positive Y" in the exported file: +Z in the file is the front, and the importer's turn makes it face -Z in Studio.

For FBX the Roblox Blender guide says to export with "Forward: Z Forward, Up: Y Up" and import with World Forward "Front", World Up "Top". The reference project's FBX route (via an Open Cloud upload add-on) kept axes with zero measured drift and needed no yaw fix either. Different routes, same destination; verify once per route with a test model (section 7).

### Quaternions and CFrames under the axis change

The map `(x, y, z) -> (-x, z, y)` is a proper rotation (its determinant is +1), so it maps rotations to rotations without mirroring. A Blender rotation quaternion `(w, x, y, z)` expressed in Blender world axes becomes, in Roblox axes:

```
(w, x, y, z)  ->  (w, -x, z, y)
```

That is, the scalar part is unchanged and the vector part goes through the same axis map. In Luau: `CFrame.new(px, py, pz, -qx, qz, qy, qw)` after mapping the position the same way. This identity is what makes a hand-written exporter short (see [[Animation Data from Blender to Roblox]]).

## 3. Roblox joint frames: what "rotate about X" means on the other side

### R15 (measured)

On a default R15 rig every `*RigAttachment` has **zero rotation** (measured on a rig generated in Studio). A joint's frame is therefore aligned with the body at rest: X right, Y up, Z back. The signs that follow:

| Pose rotation | Downward limb (arm, leg) | Upward segment (torso, neck) |
|---|---|---|
| +X | swings forward (arm raises in front) | leans back, chin up |
| -X | swings back | bends forward |
| +Y | twists about its length (its front turns toward the character's left) | turns left |
| +Z | swings toward the character's right (right arm abducts, left arm adducts across the body) | tilts toward the character's left |

The project's authoring tools used exactly this convention: "rx > 0 leans back / chin up; ry > 0 turns left". See [[R15 Rig Anatomy and Attachments]].

### Rigs whose joints you build by script

The reference project's weapon and pet rig builders create each Motor6D from a **world-aligned** joint frame: `jcf = CFrame.new(jointPosition)`, then `C0 = Part0.CFrame:ToObjectSpace(jcf)` and `C1 = Part1.CFrame:ToObjectSpace(jcf)`. The joint frame then has world axes at rest, just like R15. Roll in Blender does not matter for such rigs: the exporter computes rotations relative to rest in world axes. This is the most forgiving setup and the reason the project preferred it for props.

### Imported skinned rigs (Bones)

A Roblox `Bone` created by the importer keeps the source bone's rest frame: `Bone.CFrame` is the rest relative to the parent bone and the Animator writes `Bone.Transform` in that local frame. Here roll matters exactly as much as in Blender. If the family's convention is "X = right" in Blender, it is "X = right" on the Roblox Bone too.

Note one importer quirk measured on animated GLB imports: the clip's root pose was written at the keyframe's top level (never applied) and the root transform was conjugated by a 180 degree turn, so whole bodies played turned around. That is a clip-data issue rather than a bone-frame one; it is covered in [[Enemy Import Axis Fix]].

## 4. The roll convention (project rule, recommended)

> Every bone's local **X axis points to the character's right**. A positive X rotation lifts a limb forward and pitches a spine back. Bones lying sideways (wings) get X = forward on the left side and backward on the right, so +X flaps both tips **up**.

Why this rule:

- It **matches R15** (section 3), so poses authored in Blender read the same as poses in the Roblox Animation Editor, and procedural code written for R15 ("pitch = X") works on creatures.
- It makes **pitch a single channel** on every limb and spine segment. Walk cycles become mostly X curves; clip tables shrink; a key thinner removes more.
- **Mirrored clips are cheap**: mirroring a pose swaps L and R names and negates Y and Z rotations (X stays), because both sides share the same X direction.
- A procedural layer (springs, hit reactions, a "caught" pose) can say "pitch the spine back 20 degrees" without a per-rig table. The project's creature motion code classified bones by name and applied exactly such generic rotations.

### Setting roll by script

The reference project computed roll per bone when building family rigs. A cleaned-up version:

```python
import bpy
from mathutils import Vector

def build_rig(name, bones):
    """bones: [(name, parent, head, tail)] in Blender units (= studs).
    Roll: local X = character right (-X world) so +X lifts limbs forward.
    Bones lying along world X (wings) get X = forward (-Y) on the left side,
    backward (+Y) on the right side, so +X flaps both tips up."""
    arm = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, arm)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.edit_bones
    for nm, par, h, t in bones:
        b = eb.new(nm)
        b.head, b.tail = Vector(h), Vector(t)
        if par:
            b.parent = eb[par]
            b.use_connect = False          # keep heads where we put them
        y = (b.tail - b.head).normalized()
        if abs(y.x) > 0.8:                  # sideways bone (wing, arm in T-pose)
            xd = Vector((0, -1 if y.x > 0 else 1, 0))
        else:
            xd = Vector((-1, 0, 0))         # character right
        z = xd.cross(y)                     # align_roll aims the bone's Z axis
        b.align_roll(z.normalized() if z.length > 1e-4 else Vector((0, 0, 1)))
        b.use_deform = nm != 'Root'         # root carries no weights
    bpy.ops.object.mode_set(mode='OBJECT')
    for pb in ob.pose.bones:
        pb.rotation_mode = 'XYZ'            # or 'QUATERNION'; see section 6
    return ob
```

`align_roll(v)` rotates the bone about its Y so that its **Z** axis points along `v` (projected). Aiming Z at `X_wanted x Y` is the same as aiming X at `X_wanted`.

### Doing it by hand

Edit Mode, select bones, **Armature > Bone Roll > Recalculate Roll** (Shift+N in current Blender). Options worth knowing (Blender manual): "Global Axis" aims each bone's Z at a world axis; "Local Tangent" uses the bend between bone and parent; "Active Bone" copies the active bone's Z direction; "Flip Axis" adds 180 degrees; "Shortest Rotation" keeps |roll| under 90.

The trap: aiming Z at one global axis gives "X = right" for bones that point **down** but "X = left" for bones that point **up** (Y flips, Z stays, so X = Y x Z flips). With X = character right (-X world): a bone pointing down (Y = -Z world) needs Z = X x Y aimed at world **-Y** (forward); a bone pointing up (Y = +Z world) needs Z aimed at world **+Y** (backward). So select the downward bones (legs, arms in A or I pose) and use Global -Y Axis, then the upward bones (spine, neck, head) and use Global +Y Axis. The script above avoids the case split. By hand, always verify with the axis display (Bone properties > Viewport Display > Axes).

## 5. Names, sides and mirroring

| Convention | Blender mirror tools recognise it? | Roblox / R15 friendly? |
|---|---|---|
| `LeftUpperArm` / `RightUpperArm` | Yes (full words, no separator needed) | Yes, these are the R15 names |
| `Arm.L` / `Arm.R`, `Arm_L` / `Arm_R` | Yes | Fine for custom rigs; dots are legal in Roblox names but awkward in code paths |
| `ArmL` / `ArmR`, `WingL1` | **No** (Blender only recognises short L/R with a separator) | Fine in Roblox |
| `L_Arm` / `R_Arm` | Yes | Fine |

The reference project used suffix `L` / `R` without a separator (`ShieldL`, `WingL1`, `EarR`) because its runtime classifier keyed off names and side came from X position. That works in Roblox, but Blender's X-Axis Mirror, Symmetrize and Flip Names will not pair those bones. If you rely on Blender symmetry tools, use `_L` / `_R` or full `Left` / `Right` words. Pick one before you start; renaming bones later breaks every clip that references them.

Blender's "Auto-Name Left/Right" assigns `.L` to bones with positive X. For a character facing -Y, +X is the character's **left**, so the tool agrees with anatomical sides under this note's convention.

Other naming rules for Roblox:

- Unique across the whole rig (KeyframeSequence poses and runtime lookups are by name).
- No `.001` suffixes (they appear when duplicating; Blender strips them for mirroring but Roblox keeps them literally).
- Do not give a mesh object the same name as a bone unless you want the importer's part-joint behaviour ([[Rigging in Blender]] section 4).
- Avoid names that collide with child names your code uses on the same parent (the project broke a kit by naming a clip `Origin`, which replaced a RemoteEvent of that name).

## 6. Rotation modes, scale and other pose-bone settings

| Setting | Recommendation | Why |
|---|---|---|
| Rotation mode | Quaternion for export, or XYZ Euler with care | Roblox stores CFrames; Euler order only matters while authoring. Quaternion f-curves avoid gimbal lock but are harder to edit by hand. An exporter should read evaluated matrices, so either works. |
| Bone scale keys | **Do not animate scale** | Roblox `Pose.CFrame` and `Bone.Transform` carry no scale. Squash and stretch must be faked (translation of child bones, separate meshes, shape tricks) or done procedurally. |
| Inherit Scale | Default (Full), with all rest scales 1 | Non-uniform parent scale shears children; glTF warns this can produce non-decomposable matrices ("Flatten Bone Hierarchy" exists for that case). |
| Connected bones | Fine, but disconnect where you need translation | A connected bone cannot translate; root, hips and slide joints (pistons, sliding chest plates) must be unconnected. |
| Bendy bones (B-Bones) | Do not rely on them | Only the bone transforms export, not the B-Bone curve. Bake to real bone chains. |
| Constraints and drivers | Fine on control bones | Bake on export; Roblox only gets sampled transforms. |

## 7. Rest pose choice

| Rest pose | Deforms best at | Weakness | Use when |
|---|---|---|---|
| T-pose (arms horizontal) | Arms raised | Shoulders collapse when arms hang; long-standing mocap convention | Retargeting from T-pose mocap |
| A-pose (arms 35-45 degrees down) | The middle of the range | Slightly harder to place the clavicle | Most game characters; the project's creatures used 40 degrees down, floaters 30 |
| I-pose (arms down) | Idle and walk | Poor when arms raise high | Matches default R15 parts, which hang straight at rest (measured) |

The Roblox avatar spec accepts I, A or T pose for bodies and notes the upper arms may carry rotations to achieve the pose. For animation, what matters is that **clips and rig agree on rest**. Delta-based retargeting carries rest differences into the result (an A-pose rig playing T-pose deltas holds its arms 40 degrees low); absolute retargeting fixes that. See [[Retargeting Animations Between Rigs]].

## 8. Verify once per pipeline: the calibration clip

Before a batch, export one test rig with a 3-key clip:

1. Frame 0: rest.
2. Frame 10: `RightUpperArm` (or your right shoulder bone) +90 degrees X.
3. Frame 20: `UpperTorso` +30 degrees Y.

In Studio, the right arm must rise **in front of** the character (toward `LookVector`) and the torso must turn to the character's **left**. If the arm goes back, an axis is flipped; if it goes sideways, roll is wrong; if the whole body faces away, the root conjugation issue is present ([[Enemy Import Axis Fix]]). This 10-minute test would have saved the reference project its "enemies attack from behind" bug.

A quick roll audit in Blender, printing any bone whose X axis does not point roughly to the character right:

```python
import bpy
from mathutils import Vector
rig = bpy.context.object
right = Vector((-1, 0, 0))                    # character right in Blender
for b in rig.data.bones:
    x = b.matrix_local.to_3x3().col[0]         # bone X axis in armature space
    y = b.matrix_local.to_3x3().col[1]
    if abs(y.x) > 0.8:                          # sideways bones: skip or check separately
        continue
    if x.dot(right) < 0.9:
        print(f"{b.name}: X axis {tuple(round(c, 2) for c in x)} not character-right")
```

## Common mistakes

| Mistake | On screen | Fix |
|---|---|---|
| Roll recalculated with different options on different limbs | Shared clip lifts one arm forward and twists the other | One scripted rule for the whole rig |
| Editing the rest pose after clips exist | Every clip shifts by the rest change | Re-bake clips from world-space targets, or never touch rest after animating |
| Assuming glTF +Z front means Roblox +Z front | Model faces away, someone adds a 180 degree fix, then the fix gets applied twice | Know the measured importer turn; test with the calibration clip |
| Animating bone scale | Scale silently dropped | Use translation or separate meshes |
| `ArmL` naming plus Blender mirror tools | Mirror edits do nothing or pair wrong bones | Use `_L` / `_R` or `Left` / `Right` |

## See also

[[Rigging in Blender]] · [[Rigs and Joints]] · [[Motor6D Math and CFrame Composition]] · [[Bones and Skinned Meshes]] · [[R15 Rig Anatomy and Attachments]] · [[Enemy Import Axis Fix]] · [[Retargeting Animations Between Rigs]] · [[Animation Data from Blender to Roblox]] · [[Creature Rig Conventions]]

## Connected notes
<!-- auto-links:start -->
[[Exporting FBX vs GLB]] · [[Pipeline - Importing Animated Enemies]] · [[Moon Animator and Third-Party Tools]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Skeleton Library]] · [[Rotations Angles and Quaternions]] · [[Animation Start Here]]
<!-- auto-links:end -->
