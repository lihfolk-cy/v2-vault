---
tags: [authoring, code, keyframesequence, luau, baking, type/guide, area/animation, level/intermediate, api/Animator, area/scripting, api/KeyframeSequence, api/KeyframeMarker]
---
# Authoring Clips in Code

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Easing written on the wrong key -> convert "into" to "leaving" on write
> - Avoid: Legacy Cubic -> CubicV2
> - Avoid: Root keyed on HumanoidRootPart -> key LowerTorso; HRP weight 0
>
> Cost: TL;DR ~90 tok · whole note ~5.7k tok. Read more: ## 2. Construction rules the engine cares about · ## 6. Predicting what the Animator plays (a sampler) · ## 10. Common mistakes
<!-- tldr:end -->

Building `KeyframeSequence`s from data lets you generate hundreds of consistent clips, re-bake them when the rig changes, run IK or physics offline, enforce budgets, and verify the result against the real Animator. The reference project (one live action game) authored almost all of its 600+ ability clips this way.

This note covers the construction rules that the engine actually cares about, the easing-placement convention, placeholders, markers, key fitting and thinning, previewing in Studio, and a sampler that predicts what the Animator will play. The spec format and pose library that sit on top are in [[Spec-Driven Move Authoring]].

Labels: "Roblox docs" = official API reference; "measured" = measured in the reference project against `Animator:StepAnimations`; "rule" = a rule the reference project's tools enforce.

## 1. The data model in one paragraph

A `KeyframeSequence` holds `Keyframe`s (each with a `Time` in seconds). Each Keyframe holds a tree of `Pose`s mirroring the rig's joint tree: the top Pose is named after the root part (`HumanoidRootPart`), its child Poses after the parts below it (`LowerTorso`, then `UpperTorso`, and so on). A Pose's `CFrame` is the joint's **Transform** at that time (relative to the joint's rest, which is `C0`/`C1` or the constraint's attachments). `Weight`, `EasingStyle` and `EasingDirection` live on the Pose (`PoseBase`). `KeyframeMarker`s under a Keyframe are events. Full reference: [[KeyframeSequence Keyframe and Pose Reference]].

## 2. Construction rules the engine cares about

### 2a. Hierarchy and names
- Pose names are **Part1 names** (for Motor6D rigs) or **bone names**. A Pose binds to a joint by its own name and its parent Pose's name, so the tree must match the rig: `HumanoidRootPart > LowerTorso > UpperTorso > RightUpperArm > RightLowerArm > RightHand`.
- Create parents before children. Use `Keyframe:AddPose(pose)` for the top pose and `Pose:AddSubPose(pose)` for children (Roblox docs), or set `Parent` directly.
- Joints the clip keys that the rig does not have are ignored (the Animator binds by name). Keys for missing joints are inert, not errors. This silently hides typos: check that every Pose name exists on the target rig.

### 2b. Weights and placeholders
- Per joint, **only Poses with `Weight > 0` are keys** (measured; consistent with a 2018 Roblox staff statement). Weight-0 Poses are **placeholders**: they only exist to hold the tree together for keyed children.
- A keyframe that keys only `RightHand` still needs `HumanoidRootPart`, `LowerTorso`, `UpperTorso`, `RightUpperArm` and `RightLowerArm` Poses at weight 0 above it. Those placeholders cost instances.
- **Cost model** (rule, from the reference project's budgeting): each arm key costs 3 Poses (shoulder, elbow, wrist), and a **new keyframe** costs 1 Keyframe plus about 3 placeholders (HumanoidRootPart, LowerTorso, UpperTorso). Snapping keys onto existing keyframe times avoids the placeholder cost.

### 2c. The root pose
- **The top-level pose is never applied** (measured): keys on `HumanoidRootPart` (or a top `Root` bone) do nothing. Write it at weight 0 and put body translation and rotation on **LowerTorso** (the root joint's child).
- Root offsets must be written at the **character's game scale**. The Animator applies clip translations literally on characters scaled through body-scale values, and multiplies them by `Model:GetScale()` on model-scaled rigs (measured). The reference project's characters were 1.6x via body scales, so its baker multiplied LowerTorso offsets by **1.6** on write ("a crouch baked at scale 1 would leave the feet hovering"). See [[Scale and Animation]].

### 2d. Limbs are rotation only
Write arm (and usually leg) Poses with **zero translation**. Any translation over **0.05 studs** on an arm joint reads as a detached shoulder (rule).

### 2e. Easing placement
**The easing on a Pose shapes the segment from that key to the joint's next key.** Roblox docs describe `PoseBase.EasingStyle` as "the easing style to use to reach the next Pose's value", and measurement agrees: a segment's alpha comes from its **first** pose.

Two conventions are common in source data, and mixing them is a classic bug:
- **"Leaving" convention** (what the engine uses): the key's easing describes the move *out of* it. The reference project's spec baker used this.
- **"Into" convention** (how animators often think: "ease into this pose"): the key's easing describes the move *into* it. The reference project's early set builder used this and therefore wrote the easing listed on frame i+1 onto frame i's poses.

Pick one for your source format, write it down, and convert on write.

### 2f. Easing styles
- Use **`CubicV2`** (In = slow start, Out = slow end, like TweenService; measured).
- Never **legacy `Cubic`**: deprecated in the API ("Use CubicV2") and measured to run **reversed**.
- **Constant**: measured In = jump to the next value at once, Out = hold until the next key, InOut = jump at the midpoint. Docs disagree with each other here; the `PoseEasingDirection` enum page still describes directions in the legacy reversed sense. See [[Open Questions]].
- Avoid Elastic and Bounce on joints (their direction is disputed and they overshoot in joint space).
- Linear is the default in the editor; code should always set easing explicitly.

### 2g. Markers and named keyframes
- A marker is a `KeyframeMarker` (Name = event name, `Value` = a parameter string) added with `Keyframe:AddMarker(m)` (Roblox docs). It fires `AnimationTrack:GetMarkerReachedSignal(name)` with the value.
- A Keyframe whose `Name` is not the default "Keyframe" fires `KeyframeReached` with that name. `End` is the name default-animation replacements need.
- **Attach markers to an existing keyframe at that time** if there is one. A marker-only Keyframe is still a Keyframe: it costs an instance, and the reference project measured that **marker-only keyframes count** when the Animator decides whether keys are evenly spaced (which changes its interpolation model, see section 6).
- A useful extension (rule): let a spec write `mk = "Name=value"` to produce a marker with a value, for example `StaffSpin=2,0.4,1,F,0,0`.

### 2h. Times
- Round keyframe times (the reference project used **1 ms**). Floating-point noise creates near-duplicate keyframes.
- The first and last keyframes define the length. Keep them even if empty, and keep any keyframe that carries a marker or a name.

### 2i. Things never to write
- **Identity keys mid-motion** (an all-zero pose on an arm because the solver failed). They produce a T-pose or rest flash.
- **Key-to-key turns over 120 degrees** on any joint. The Animator may take the long way. **Exactly 180 degrees** is ambiguous in the Animator itself (measured: the only parity failures in 60 enemy clips were exact-180 keys).
- **Reserved names** for clips that live in folders scripts index by name. In the reference project a move named "Origin" replaced a kit's `Origin` RemoteEvent and the kit stopped dealing damage. Its reserved list: Attack, Origin, FX, LocalCast, Moves, ItemRig.

## 3. A builder

Typed Luau that follows every rule above. Input keys use the engine's "leaving" convention.

```lua
--!strict
-- R15 joint tree: Pose name -> parent Pose name (the top pose has no parent).
local PARENT: { [string]: string } = {
	LowerTorso = "HumanoidRootPart", UpperTorso = "LowerTorso", Head = "UpperTorso",
	RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm", RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm",
	RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg", RightFoot = "RightLowerLeg",
	LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg", LeftFoot = "LeftLowerLeg",
}
local LIMBS = { RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true }

export type JointKey = { cf: CFrame, style: Enum.PoseEasingStyle?, dir: Enum.PoseEasingDirection? }
export type Key = { t: number, joints: { [string]: JointKey }, name: string? }
export type Marker = { t: number, name: string, value: string? }
export type Spec = { name: string, loop: boolean?, priority: Enum.AnimationPriority?,
	keys: { Key }, markers: { Marker }?, rootScale: number? }

local function round(t: number): number
	return math.floor(t * 1000 + 0.5) / 1000 -- 1 ms grid avoids near-duplicate keyframes
end

local function build(spec: Spec): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = spec.name
	ks.Loop = spec.loop or false
	ks.Priority = spec.priority or Enum.AnimationPriority.Action
	local rootScale = spec.rootScale or 1

	local byTime: { [number]: Keyframe } = {}
	local function keyframeAt(t: number): Keyframe
		local rt = round(t)
		local kf = byTime[rt]
		if not kf then
			kf = Instance.new("Keyframe")
			kf.Time = rt
			ks:AddKeyframe(kf)
			byTime[rt] = kf
		end
		return kf :: Keyframe
	end

	for _, key in spec.keys do
		local kf = keyframeAt(key.t)
		if key.name then kf.Name = key.name end -- fires KeyframeReached(name)
		local made: { [string]: Pose } = {}
		local function poseFor(name: string): Pose
			local existing = made[name]
			if existing then return existing end
			local p = Instance.new("Pose")
			p.Name = name
			p.Weight = 0 -- placeholder unless keyed below
			local parentName = PARENT[name]
			if parentName then
				poseFor(parentName):AddSubPose(p) -- parents are created first, recursively
			else
				kf:AddPose(p) -- the top pose (HumanoidRootPart): never applied, stays weight 0
			end
			made[name] = p
			return p
		end
		for jointName, jk in key.joints do
			assert(PARENT[jointName], "not a keyable joint: " .. jointName) -- also rejects the root
			local cf = jk.cf
			if jointName == "LowerTorso" then
				cf = cf.Rotation + cf.Position * rootScale -- root offsets at game scale
			elseif LIMBS[jointName] then
				assert(cf.Position.Magnitude <= 0.05, jointName .. " has translation (detached limb)")
			end
			local p = poseFor(jointName)
			p.CFrame = cf -- the joint Transform at this time
			p.Weight = 1
			p.EasingStyle = jk.style or Enum.PoseEasingStyle.CubicV2 -- shapes the segment LEAVING this key
			p.EasingDirection = jk.dir or Enum.PoseEasingDirection.InOut
		end
	end

	for _, m in spec.markers or {} do
		local mk = Instance.new("KeyframeMarker")
		mk.Name = m.name
		mk.Value = m.value or ""
		keyframeAt(m.t):AddMarker(mk) -- reuses an existing keyframe at that time when there is one
	end
	return ks
end
```

Notes:
- Easing on a joint's **last** key does nothing (there is no next segment).
- If a key keys only some joints, the others interpolate straight across it from their own previous key to their own next key. That is a feature (sparser data) and a trap (a joint you forgot to key drifts through a pose).
- Converting from the "into" convention: for each joint, move each key's easing to that joint's previous key.

## 4. Fitting keys from dense samples (toSequence)

Bakers produce dense samples (every 0.035 to 0.1 s, or every 60 Hz frame). Writing all of them wastes instances. The reference project's spec baker wrote each joint on its own:

1. Keep every **authored key time** as a candidate, plus the first and last frames.
2. For each joint and each span between authored keys: if the span's **own authored easing** reproduces every baked in-between within **5 degrees / 0.09 studs**, write only the key, with that easing.
3. Otherwise **split** the span where the samples stray most from the fitted curve, and for each piece take the **first easing that fits**, in this order: Linear, CubicV2 InOut, Out, In.
4. A joint **holding still** through a key gets no pose there.
5. A parent kept only for a child becomes a **weight-0 placeholder**.
6. **Empty keyframes are dropped**, except the first, the last and any with markers.
7. Stamp diagnostics as attributes (`PosesKept`, `PosesDropped`).

The tolerance (5 degrees / 0.09 studs) was loose because of a kit-folder budget of **2,500 instances**. A later arm re-solver used tighter per-joint tolerances (shoulder 1.0, elbow 1.2, wrist 1.5 degrees, times a factor stepped up only as far as the budget needed), spans at most 0.4 s and under 120 degrees, splits snapped to existing keyframe times within 2 to 3 frames, and a growth cap of 15% + 30 instances per clip. See [[Pipeline - Arm IK Baking and QA]].

A known flaw worth copying the lesson from: the spec baker's own fit check used `CFrame:Lerp` (a [[slerp]]), not the Animator's measured rotation-vector blend, so on big turns far from rest its kept keys played slightly differently than it assumed. **Fit against the model of what the engine actually does.**

## 5. Thinning existing clips

Drop a key if interpolating its kept neighbours (with the joint's own easing) reproduces it, and every point between, within tolerance. Tolerances in use:

| Use | Rotation | Position | Notes |
|---|---|---|---|
| Body joints of attack clips | 0.75 degrees (hips 0.5) | 0.03 studs | checked at 60 Hz; planted feet held to 0.05 studs in HRP space, airborne 0.12 |
| Runtime buffer encoder | 0.03 degrees | 0.002 studs | near-lossless, for compression |
| Weapon hinge clips | 0.004 rad (nlerp check) | 0.003 units | at most 0.5 s between kept keys; static joints dropped |

Always keep: first and last keys, keys within a frame of a marker, and any segment over 150 degrees (split instead). After thinning, re-check that no segment exceeds 120 degrees.

Key density benchmarks from the reference project: **22 to 30 keys/s** typical for normal moves, about **16** for long ultimates, weapon-part clips under **80** instances; enemy clips baked with every joint at 16 to 25 fps reached **323k** instances in one folder.

## 6. Predicting what the Animator plays (a sampler)

To verify clips offline, or to drive your own player, sample them the way the engine does. Measured behaviour:
- Offsets **lerp linearly**.
- Rotations: if **every keyframe is evenly spaced (marker-only keyframes count) and every key is Linear**, the Animator nlerps [[quaternions]]. **Otherwise** it blends **rotation vectors**: each key's rotation as axis x angle from rest, choosing between each key's two representations (`v` and `v - 2 pi axis`) the pair closest together, then lerping. (A weapon-rig player study found the switch per joint; whether "evenly spaced" is judged per joint or per sequence is an open question.)
- The two models agree on small steps and diverge on big turns far from rest (an overhead off-hand shoulder was 9 to 12 degrees off). A slerp model was up to **178 degrees** wrong on some segments; the rotation-vector model matched to **0.24 degrees**.

```lua
--!strict
local function toRotVec(cf: CFrame): Vector3
	local axis, angle = cf:ToAxisAngle()
	return axis * angle
end

local function fromRotVec(v: Vector3): CFrame
	local a = v.Magnitude
	if a < 1e-9 then return CFrame.identity end
	return CFrame.fromAxisAngle(v / a, a)
end

-- Each rotation vector v also equals v - 2*pi*unit(v) (same rotation, other way round).
-- The Animator lerps the pair of representations that lie closest together.
local function nearestPair(va: Vector3, vb: Vector3): (Vector3, Vector3)
	local function alt(v: Vector3): Vector3
		local m = v.Magnitude
		return if m < 1e-9 then v else v - v / m * (2 * math.pi)
	end
	local best, ba, bb = math.huge, va, vb
	for _, a in { va, alt(va) } do
		for _, b in { vb, alt(vb) } do
			local d = (a - b).Magnitude
			if d < best then best, ba, bb = d, a, b end
		end
	end
	return ba, bb
end

-- Easing alpha for a segment, using the FIRST pose's style/direction (measured semantics).
local function ease(style: Enum.PoseEasingStyle, dir: Enum.PoseEasingDirection, u: number): number
	if style == Enum.PoseEasingStyle.Linear then return u end
	if style == Enum.PoseEasingStyle.Constant then
		if dir == Enum.PoseEasingDirection.In then return if u > 0 then 1 else 0 end -- jump now
		if dir == Enum.PoseEasingDirection.Out then return if u >= 1 then 1 else 0 end -- hold
		return if u >= 0.5 then 1 else 0 -- InOut: jump at the midpoint
	end
	if style == Enum.PoseEasingStyle.Cubic then -- legacy Cubic plays reversed: swap In and Out
		if dir == Enum.PoseEasingDirection.In then dir = Enum.PoseEasingDirection.Out
		elseif dir == Enum.PoseEasingDirection.Out then dir = Enum.PoseEasingDirection.In end
	elseif style ~= Enum.PoseEasingStyle.CubicV2 then
		error("Elastic/Bounce not modelled") -- unused in the reference pipeline; behaviour disputed
	end
	if dir == Enum.PoseEasingDirection.In then return u * u * u end
	if dir == Enum.PoseEasingDirection.Out then local v = 1 - u; return 1 - v * v * v end
	if u < 0.5 then return 4 * u * u * u end
	local v = 2 - 2 * u
	return 1 - v * v * v / 2
end

-- Sample one joint between its keys a (time ta) and b (time tb) at time t (rotation-vector model).
local function sampleSegment(a: Pose, ta: number, b: Pose, tb: number, t: number): CFrame
	local u = math.clamp((t - ta) / math.max(tb - ta, 1e-6), 0, 1)
	local w = ease(a.EasingStyle, a.EasingDirection, u)
	local ra, rb = nearestPair(toRotVec(a.CFrame), toRotVec(b.CFrame))
	local pos = a.CFrame.Position:Lerp(b.CFrame.Position, w)
	return CFrame.new(pos) * fromRotVec(ra:Lerp(rb, w))
end
```

For the nlerp case (evenly spaced, all Linear), blend quaternions on the short arc instead. Full details and the layering maths are in [[How the Animator Really Behaves]] and [[Lua Keyframe Player Internals]].

The ground truth is always the engine: play the clip on a dummy, step with `Animator:StepAnimations(dt)` (works in Edit mode with dt > 0), and read each joint's `Transform`. See [[Testing Animations in Studio]].

## 7. Previewing in Studio

```lua
--!strict
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local function previewInStudio(animator: Animator, ks: KeyframeSequence): AnimationTrack
	local anim = Instance.new("Animation")
	anim.AnimationId = KeyframeSequenceProvider:RegisterKeyframeSequence(ks) -- temporary, Studio-only id
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action4
	local t0 = os.clock()
	while track.Length <= 0 and os.clock() - t0 < 2 do
		task.wait() -- a fresh registration plays nothing until Length > 0 (measured)
	end
	track:Play(0)
	return track
end
```

- Roblox docs: ids from `RegisterKeyframeSequence` / `RegisterActiveKeyframeSequence` are **temporary and cannot be used outside of Studio**.
- A verify run that reported "loaded false" and a 117-degree error was simply a fresh registration stepped too early.
- **Never ship a registered id.** In the reference project every runtime-registered clip silently did nothing in live servers ("abilities don't work in server"), dozens of weapon kits had hinge parts that never moved live, and templated kit code kept reintroducing the call. Publish the clip, or play the `KeyframeSequence` data with your own player. See [[Publishing Animations]], [[Lua Keyframe Player]] and [[Case Study - Abilities That Only Worked in Studio]].
- `require` caches modules in Edit mode: tools that read shared clip modules should clone the ModuleScript, require the clone, then destroy it, or they read stale data.

## 8. Weapon-part (hinge) clips

Weapons with moving parts (hinged guards, orbiting pieces) get small clips on their own joints. Reference format:

```lua
-- { Name = { len = 2.4, keys = { { t = 0, poses = { GuardL = { xDeg, yDeg, zDeg } }, e = "Linear", d = "In" }, ... } } }
```
Written as: a weight-0 root Pose named after the weapon's root part (`Handle`), child Poses named after each hinge's Part1 with `CFrame.Angles` in degrees, chained hinges nested under their parent hinge's Pose, priority Action2, no loop, default easing Linear / In. Clips for joints the weapon model lacks are inert. See [[Weapon Design Rig Builder]] and [[Weapon Rig Player]].

## 9. Budgets and size limits

- **Instance budget**: the reference project capped each ability kit folder (moves + weapon clips + scripts) at **2,500 instances**. kit2-style clips ran about 300 to 700 instances each; one ultimate reached 719.
- **Script source limit**: a Script's Source is limited to **200,000 characters** (measured: saving fails with "Unable to assign property Source"). Generated clip-data modules hit this; split them into child modules.
- **Local variable limit**: a function can have at most 200 locals; generated code with many top-level locals fails to compile.
- Large libraries: after publishing, archive the sources and leave stubs, or ship compressed buffers (see [[Baked Clip Stubs and Archiving]] and [[Clip Buffer Format]]).

## 10. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Easing written on the wrong key | eases happen one segment late | convert "into" to "leaving" on write |
| Legacy Cubic | backwards easing | CubicV2 |
| Root keyed on HumanoidRootPart | no lift or travel | key LowerTorso; HRP weight 0 |
| Root offsets at scale 1 on a 1.6x character | hovering or sunk feet | multiply by the game scale |
| Arm translation | detached shoulders | rotation only; assert |
| Marker on its own keyframe | extra instance; changes the evenly-spaced test | attach to an existing keyframe |
| Fit checked with slerp | small playback differences on big turns | fit with the rotation-vector model |
| Thinning across a 150+ degree turn | wrong-way spins | split, keep under 120 |
| Shipping [[RegisterKeyframeSequence]] ids | nothing plays live | publish or use a Lua player |
| Stale `require` in Edit | tools use old data | clone-require |

## See also
[[Spec-Driven Move Authoring]], [[KeyframeSequence Keyframe and Pose Reference]], [[Keyframes, Easing and Interpolation]], [[How the Animator Really Behaves]], [[Markers and Events]], [[Snippets - Building and Sampling Clips]], [[Publishing Animations]], [[Lua Keyframe Player]], [[Pipeline - Arm IK Baking and QA]], [[Open Questions]].

## Connected notes
<!-- auto-links:start -->
[[Animation Data from Blender to Roblox]] · [[Engine Gotchas]] · [[Performance and Memory]] · [[Animation Editor Advanced]] · [[AI Animation and Motion from Video]] · Interpolation Easing and Curves Math · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Animation Editor Workflow]] · [[Animation Glossary]] · [[Snippets - Lua Keyframe Player Core]] · [[Moon Animator and Third-Party Tools]] · [[Pipeline - New Animated Weapon]] · [[Timing Spacing and Frame Charts]] · [[Animation Review Checklist]] · [[Animation Quality Standard]]
<!-- related:end -->
