---
tags: [blender, export, keyframesequence, python, pipeline, clips, type/guide, area/animation, level/intermediate, api/Animator, area/data, api/KeyframeSequence]
---
# Animation Data from Blender to Roblox

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Reading `matrix_basis` when constraints drive the rig -> Use evaluated `pose_bone.matrix` as in the exporter
> - Avoid: Root travel keyed on the top pose -> Key the first child
> - Avoid: Axis map applied twice, or not at all -> Calibration clip; one conversion in one place
>
> Cost: TL;DR ~110 tok · whole note ~4.9k tok. Read more: ## 3. The Blender exporter · ## 4. The Studio builder · ## Common mistakes
<!-- tldr:end -->

There are three ways to get motion authored in Blender into a Roblox clip: let the 3D Importer bring the animations, import a file in the Animation Editor, or export the transforms yourself and build the KeyframeSequence (or a compact buffer) in Studio. The first two are quick and come with quirks you cannot control. The third is more work once and then gives you exact markers, names, partial clips, thinning, easing and root handling for every clip after. This note covers all three, with a complete exporter and builder, the maths that makes them correct, and the measured pitfalls from one production game.

## 1. The three routes

| Route | Steps | Gives you | Costs you |
|---|---|---|---|
| **3D Importer** | Export GLB/FBX with animations; import the model | Clips as KeyframeSequences in `ServerStorage.RBX_ANIMSAVES.<model>` (and, since 2026, saved to AnimSaves automatically) | Measured on GLB: root pose at the keyframe top level (never applied) and a 180 degree conjugation, so bodies played turned around; clips named after the file or `Scene`; no markers; dense keys on every bone |
| **Animation Editor file import** | Select the rig in the editor; import from a file | One clip loaded onto a rig you already have; 2026 options for Rig Scale, Rest Pose Source, Rig Type and track selection | One take at a time; matching rests and names is on you; markers and thinning by hand |
| **Custom export** | Blender Python samples each bone per frame to JSON; Studio Luau builds the clip | Exact control: names, markers, partial clips, root on the right joint, axis conventions explicit, thinning, easing, deterministic rebuilds | You write and maintain two scripts (below) |

The reference project used the importer for its first enemy roster (and paid with a data fix on every clip: [[Enemy Import Axis Fix]]), and generated almost everything else as data: specs and pose tables evaluated offline, written into KeyframeSequences or binary buffers by its own tools ([[Authoring Clips in Code]], [[Spec-Driven Move Authoring]]).

## 2. What Roblox needs per joint

A KeyframeSequence pose is the joint's `Transform` at that time, relative to rest:

| Joint type | Roblox applies | So the exporter must produce |
|---|---|---|
| `Motor6D` / `AnimationConstraint` | `Part1 = Part0 * C0 * Transform * C1^-1` (C0/C1 or the RigAttachments give the joint frame) | The rotation (and rare translation) **in the joint frame** |
| `Bone` | `world = parentWorld * Bone.CFrame * Transform` | The local transform relative to rest, **in the bone's own frame** |

Two frame situations cover almost every rig:

- **World- or body-aligned joint frames.** R15 (every RigAttachment has zero rotation, measured) and rigs whose Motor6Ds you build in Studio from a manifest with `CFrame.new(jointPoint)` frames. Here the Transform is the joint's rotation relative to its parent, **in model axes**.
- **Imported bone frames.** Skinned rigs where the Roblox Bone keeps the Blender bone's frame (Y along the bone, X and Z from roll). Here the Transform is Blender's local pose (the evaluated "basis") as is.

### Maths for world-aligned joint frames

Let `Q` be a bone's **world delta**: the rotation that takes it from rest to its posed orientation, in armature space:

```
Q_bone = rot(pose_bone.matrix) * rot(bone.matrix_local)^-1
```

For a joint whose frame is world-aligned at rest, the parent's joint frame at pose time is rotated by `Q_parent`, and the child's by `Q_child`, so:

```
Transform = Q_parent^-1 * Q_child          (in Blender axes)
```

Then convert axes. With the conventions in [[Blender Armature and Bone Roll Conventions]] (character faces -Y in Blender), Blender `(x, y, z)` maps to Roblox `(-x, z, y)`. That map is a proper rotation, so a [[Quaternions|quaternion]] `(w, x, y, z)` converts to `(w, -x, z, y)` and a vector `(x, y, z)` to `(-x, z, y)`. Bone roll does not matter at all in this mode, which is why it is the most forgiving.

Translations: export them only where the clip means them (the root child for hip travel, slide joints such as pistons). For the root child under a static `HumanoidRootPart`, the Transform translation is simply the joint's displacement from rest in model axes. Limb translations are a smell: the reference project wrote arm poses rotation-only because any arm translation over 0.05 studs "reads as a detached shoulder".

### Maths for imported bone frames

Blender's evaluated local transform relative to rest, including constraints and drivers (which `matrix_basis` alone does not include):

```
rel   = parent.matrix_local^-1 * child.matrix_local      (rest offset, armature space)
local = (parent_pose.matrix * rel)^-1 * child_pose.matrix
```

For a root bone, `local = bone.matrix_local^-1 * pose_bone.matrix`. This is already in the bone's own frame; no axis conversion is needed for rotations, and translations only need unit scaling (1 here, with 1 Blender unit = 1 stud). Verify on your import route with the calibration clip, because importers can re-orient root frames.

## 3. The Blender exporter

```python
# export_clips.py: run in Blender (interactive or blender -b file.blend -P export_clips.py)
import bpy, json
from mathutils import Quaternion

FPS = 30

def q_rbx(q):            # Blender-axes rotation -> Roblox axes; (x, y, z) -> (-x, z, y) is a proper rotation
    return [q.w, -q.x, q.z, q.y]

def v_rbx(v):
    return [-v.x, v.z, v.y]

def export_action(rig, action, mode, root_child, out_path, only=None, scale=1.0):
    """mode 'world': Motor6D / R15 rigs with world-aligned joint frames.
       mode 'bone' : skinned rigs whose Roblox Bones keep the Blender bone frames.
       root_child  : the first child of the root (hip travel goes here, never on the root).
       only        : optional list of bones for partial (layer) clips."""
    scene = bpy.context.scene
    rig.animation_data.action = action
    f0, f1 = (int(round(x)) for x in action.frame_range)
    bones = [b for b in rig.data.bones if b.use_deform and (only is None or b.name in only)]
    rest_q = {b.name: b.matrix_local.to_quaternion() for b in rig.data.bones}
    frames = []
    for f in range(f0, f1 + 1):
        scene.frame_set(f)                         # evaluates constraints, drivers and IK at this frame
        pose = {}
        for b in bones:
            pb = rig.pose.bones[b.name]
            if mode == "bone":
                if b.parent:
                    rel = b.parent.matrix_local.inverted() @ b.matrix_local
                    L = (rig.pose.bones[b.parent.name].matrix @ rel).inverted() @ pb.matrix
                else:
                    L = b.matrix_local.inverted() @ pb.matrix
                q, t = L.to_quaternion(), L.to_translation() * scale
                pose[b.name] = {"q": [q.w, q.x, q.y, q.z], "p": [t.x, t.y, t.z]}
            else:
                qc = pb.matrix.to_quaternion() @ rest_q[b.name].inverted()        # world delta, child
                if b.parent:
                    pp = rig.pose.bones[b.parent.name]
                    qp = pp.matrix.to_quaternion() @ rest_q[b.parent.name].inverted()
                else:
                    qp = Quaternion()
                d = qp.inverted() @ qc                                             # Transform, Blender axes
                p = [0.0, 0.0, 0.0]
                if b.name == root_child:
                    p = v_rbx((pb.head - b.head_local) * scale)                   # hip travel, model axes
                pose[b.name] = {"q": q_rbx(d), "p": p}
        frames.append({"t": round((f - f0) / FPS, 4), "pose": pose})
    data = {
        "name": action.name,
        "length": round((f1 - f0) / FPS, 4),
        "loop": bool(action.get("loop", False)),
        "frames": frames,
        "markers": [{"name": m.name, "t": round((m.frame - f0) / FPS, 4)}
                    for m in sorted(action.pose_markers, key=lambda m: m.frame)],
        "parents": {b.name: (b.parent.name if b.parent else None) for b in rig.data.bones},
    }
    with open(out_path, "w") as fh:
        json.dump(data, fh, separators=(",", ":"))

rig = bpy.data.objects["Rig"]
for act in bpy.data.actions:
    if act.use_fake_user:
        export_action(rig, act, "world", "LowerTorso", bpy.path.abspath("//clips/%s.json" % act.name))
```

Notes on the exporter:

- **Apply the armature object's transforms first.** The maths treats armature space as world space.
- `scene.frame_set` evaluates everything, so IK, constraints and drivers are baked by construction. This is also how helper bones (twist, caps) reach Roblox ([[Weight Painting and Skinning for Roblox]]).
- The **parents table covers every bone**, so placeholder poses can be built for non-exported parents.
- Markers come from the Action's **pose markers**. The reference project's exporter also wrote a per-model clip table (`{dur, frames, loop, marks}`) as JSON and Lua, and computed the `Hit - Tele` gap of every attack clip to check it against design.
- `only` produces a true partial clip, which the glTF exporter cannot (it keys every bone in every animation; the project had to strip channels from GLBs afterwards).

## 4. The Studio builder

```lua
--!strict
local HttpService = game:GetService("HttpService")

type FramePose = { q: { number }, p: { number } }
type ClipData = {
	name: string,
	length: number,
	loop: boolean,
	frames: { { t: number, pose: { [string]: FramePose } } },
	markers: { { name: string, t: number } },
	parents: { [string]: string },          -- JSON null parents simply do not appear
}

local function toCFrame(fp: FramePose): CFrame
	local q, p = fp.q, fp.p                  -- q = {w, x, y, z}
	return CFrame.new(p[1], p[2], p[3], q[2], q[3], q[4], q[1])   -- (x, y, z, qx, qy, qz, qw)
end

-- rootPoseName: "HumanoidRootPart" for Humanoid/R15 or root-part rigs; the model's root part name otherwise.
local function buildClip(json: string, rootPoseName: string, priority: Enum.AnimationPriority): KeyframeSequence
	local clip = HttpService:JSONDecode(json) :: ClipData
	local ks = Instance.new("KeyframeSequence")
	ks.Name = clip.name
	ks.Loop = clip.loop
	ks.Priority = priority
	local keyframes: { Keyframe } = {}

	for _, fr in clip.frames do
		local kf = Instance.new("Keyframe")
		kf.Time = fr.t
		local top = Instance.new("Pose")
		top.Name = rootPoseName
		top.Weight = 0                       -- the top-level pose is never applied: placeholder only
		kf:AddPose(top)

		local made: { [string]: Pose } = {}
		local function poseFor(name: string): Pose
			local existing = made[name]
			if existing then
				return existing
			end
			local p = Instance.new("Pose")
			p.Name = name
			p.EasingStyle = Enum.PoseEasingStyle.Linear   -- dense samples: let the samples carry the curve
			local fp = fr.pose[name]
			if fp then
				p.CFrame = toCFrame(fp)
				p.Weight = 1
			else
				p.Weight = 0                 -- kept only so its children sit at the right depth
			end
			local parentName = clip.parents[name]
			if parentName then
				poseFor(parentName):AddSubPose(p)
			else
				top:AddSubPose(p)
			end
			made[name] = p
			return p
		end
		for name in fr.pose do
			poseFor(name)
		end
		ks:AddKeyframe(kf)
		table.insert(keyframes, kf)
	end

	-- Markers go on the nearest existing keyframe, so keyframe spacing stays even (see section 5).
	for _, m in clip.markers do
		local best, bestDt = keyframes[1], math.huge
		for _, kf in keyframes do
			local dt = math.abs(kf.Time - m.t)
			if dt < bestDt then
				best, bestDt = kf, dt
			end
		end
		local mk = Instance.new("KeyframeMarker")
		mk.Name = m.name
		mk.Value = m.name
		best:AddMarker(mk)
	end
	return ks
end
```

The pose tree must mirror the rig: on a Motor6D rig `HumanoidRootPart > LowerTorso > UpperTorso > ...` (part names), on a bone rig `<root part> > Root > ...` (bone names). The reference project's importer fix had to re-path imported enemy poses to `<root part> > Root > ...` for exactly this reason. Root travel goes on the **first child** of the top pose.

For Motor6D and R15 rigs, the armature's own root bone (`Root`, or `HumanoidRootNode` in the avatar skeleton) has no matching part. Remove it from the `parents` table before building (set its children's parent to nothing), or the builder will insert a weight-0 `Root` pose between `HumanoidRootPart` and `LowerTorso` and the Animator will not find `LowerTorso` where the rig has it.

Getting the JSON into Studio: paste it into a ModuleScript or StringValue (mind the 200,000-character `Source` limit; split long clips), or fetch it from a local file server with `HttpService:GetAsync` in Studio (HTTP requests enabled, about 500 requests a minute for the whole place, so batch per model rather than per clip). The project's tools loaded data that way, with a cache-busting query string.

## 5. Make the clip small and play it exactly

### Instance count

A dense clip is `frames x joints` Poses: 30 fps x 2 s x 25 joints is 1,500 Pose instances for one clip. The reference project's ReplicatedStorage once held about 600k instances, 323k of them in enemy clips "with every joint keyed at 16-25 fps", and every client paid for them at load. Thin before shipping:

| Thinner (project) | Tolerance | Use |
|---|---|---|
| Buffer encoder | 0.03 degrees / 0.002 studs | Lossless-looking compression for a Lua player |
| Arm baker body thinning | 0.75 degrees (hips 0.5) / 0.03 studs, checked at 60 Hz | Shipping KeyframeSequences |
| Spec baker key fit | 5 degrees / 0.09 studs per span, with eased spans | Authored-style clips with few keys |
| Hinge clips | 0.004 rad / 0.003 units, at most 0.5 s between keys | Weapon rigs |

Thin **per joint** (a still joint loses all its keys while a busy one keeps many), keep first and last keys and any key near a marker, and drop keyframes left with only placeholders unless they carry markers. Details: [[Snippets - Building and Sampling Clips]] and [[Baked Clip Stubs and Archiving]].

### Interpolation changes when you thin

The Animator interpolates rotations by quaternion nlerp only when all keyframes are evenly spaced (marker-only keyframes count) and every key is Linear; otherwise it linearly blends rotation vectors measured from rest (measured; up to about 10 degrees apart from [[slerp]] on big turns far from rest). Dense, evenly spaced samples play the same either way. A thinned clip has uneven spacing, so:

- Check the thinned result against the dense one **with the Animator's actual model**, not with slerp. The project switched every offline tool to a rotation-vector model and then matched the Animator to within 0.24 degrees.
- Keep every key-to-key segment under about 120 degrees (the project's flip guard), and never write a key exactly 180 degrees from its neighbour: the Animator picks the direction inconsistently.

See [[How the Animator Really Behaves]] and [[Keyframes, Easing and Interpolation]].

### Easing

Dense samples need **Linear** easing. If you thin to few keys, choose each span's easing by testing which style reproduces the samples (the project tried Linear, then CubicV2 InOut, Out, In) and remember the easing of a segment is read from the segment's **first** pose. Avoid legacy `Cubic` (its directions play reversed, measured).

### Quaternion signs

`q` and `-q` are the same rotation, and `CFrame.new` accepts either. Your own thinner, interpolator or buffer encoder does care: keep consecutive samples in the same hemisphere (flip a sample if its dot product with the previous one is negative) before comparing or compressing.

## 6. Skip KeyframeSequences entirely

Clips do not have to exist as Pose instances at all. The reference project shipped most motion as base64 buffers played by a Lua keyframe player (smallest-three quaternion packing plus per-joint thinning, 19-235 KB per enemy kit, about 1.6 MB for the whole roster), leaving "stub" KeyframeSequences with only named and marker keyframes for tools that read lengths and markers. That cut ReplicatedStorage from 392k to 107k instances on every client. If you go that way, your exporter can write the buffer format directly. See [[Lua Keyframe Player]] and [[Clip Buffer Format]].

## 7. Shipping the clip

- `KeyframeSequenceProvider:RegisterKeyframeSequence` ids **only work in Studio**. A whole class of the reference project's abilities and weapon rigs worked in Studio and did nothing in live servers because of this. Publish clips as Animation assets ([[Publishing Animations]]) or play them with a Lua player.
- Preload clips used by abilities. A stance clip that loaded on first use made an ability feel about 5 s late in the project; preloading tracks and `ContentProvider:PreloadAsync` on kit load fixed it.

## 8. Verify

1. **Calibration clip** once per route: right arm +90 degrees forward must rise in front of the character, torso +30 degrees yaw must turn left ([[Blender Armature and Bone Roll Conventions]] section 8).
2. **Parity check:** play the built clip with `Animator:StepAnimations(dt)` in Edit (dt greater than 0; a just-registered clip may need its track `Length` to become positive before it steps), read each joint's `Transform`, and compare with the JSON samples. The reference project's Lua player matched the Animator within 0.084 degrees on R15 clips and 0.056 degrees on 60 enemy clips; your builder should be in the same range on dense clips.
3. **Markers:** count fired markers against the JSON (the project's player hit 319 of 319).
4. **Root motion:** confirm leaps and rises actually travel, and that the top-level pose carries nothing.

## Common mistakes

| Mistake | On screen | Fix |
|---|---|---|
| Reading `matrix_basis` when constraints drive the rig | IK and helper motion missing in Roblox | Use evaluated `pose_bone.matrix` as in the exporter |
| Root travel keyed on the top pose | Character stays in place | Key the first child |
| Axis map applied twice, or not at all | Arm lifts backward or sideways | Calibration clip; one conversion in one place |
| Armature object rotated or scaled | Every pose skewed by the object transform | Apply transforms before export |
| Markers on new off-grid keyframes | Interpolation model changes; subtle pose differences | Snap markers to existing keyframes |
| Shipping dense clips | Load-time instance bloat | Thin per joint; or ship buffers |
| Partial clip exported through glTF | Layer pins the whole body | Export only the layer's bones |
| `RegisterKeyframeSequence` in live code | Works in Studio, nothing live | Publish or play in Lua |

## See also

[[Rigging in Blender]] · [[Exporting FBX vs GLB]] · [[Blender Armature and Bone Roll Conventions]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[How the Animator Really Behaves]] · [[Authoring Clips in Code]] · [[Snippets - Building and Sampling Clips]] · [[Lua Keyframe Player]] · [[Enemy Import Axis Fix]] · [[Retargeting Animations Between Rigs]] · [[Publishing Animations]]

## Connected notes
<!-- auto-links:start -->
[[Moon Animator and Third-Party Tools]] · [[Open Questions]] · [[Importing Models and Rigs]] · [[Weapon Design Rig Builder]] · [[AI Animation and Motion from Video]] · Modeling Characters for R15 and Custom Rigs · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Weapon Rig Player]] · [[Engine Gotchas]] · [[Pipeline - Importing Animated Enemies]] · [[Animation Editor Advanced]] · [[3D Importer Settings Reference]] · [[Animation Glossary]] · [[Performance and Memory]] · [[Creature Rig Conventions]]
<!-- related:end -->
