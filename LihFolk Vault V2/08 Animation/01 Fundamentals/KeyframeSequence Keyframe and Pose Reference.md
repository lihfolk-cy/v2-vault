---
tags: [fundamentals, api, reference, keyframesequence, data, type/reference, area/animation, level/beginner, api/KeyframeSequence, area/data, api/KeyframeMarker, api/Part1]
---
# KeyframeSequence, Keyframe and Pose Reference

<!-- tldr:start -->
> [!tldr] TL;DR
> - Top-level pose is `HumanoidRootPart` (or the rig's root) at Weight 0; motion starts on its child.
> - Every Pose name matches a Part1 (or Bone) name on the target rig.
> - Placeholders are Weight 0; real keys are Weight 1.
> - Easing written on the key that starts each segment; no legacy `Cubic`.
> - No key-to-key turn near 180 degrees; ideally under 120.
> - Markers carry gameplay events; Keyframe names left as "Keyframe" unless a legacy listener needs them.
>
> Cost: TL;DR ~160 tok · whole note ~4.0k tok. Read more: ## Class reference · ## Semantics the reference does not spell out · ## Checklist for a clean KeyframeSequence
<!-- tldr:end -->

`KeyframeSequence` is the classic clip format: what the Animation Editor saves, what the 3D importer writes, what most code-built clips use, and what gets uploaded when you publish. This note documents every class in the format (`KeyframeSequence`, `Keyframe`, `PoseBase`, `Pose`, `NumberPose`, `KeyframeMarker`) and the services around it (`KeyframeSequenceProvider`, `AnimationClipProvider`), then explains the semantics the reference pages leave out: what counts as a key, where easing lives, why the root pose is ignored, and how instance counts explode.

Member lists verified against the engine API dump and class pages (October 2026).

## The shape of the data

```
KeyframeSequence  (Loop, Priority, AuthoredHipHeight)
├── Keyframe  Time = 0       (Name "Keyframe", or a custom name = legacy event)
│   ├── KeyframeMarker  Name "Hit", Value "heavy"
│   └── Pose  "HumanoidRootPart"   Weight 0      <- top-level pose: never applied
│       └── Pose  "LowerTorso"     Weight 1      <- drives the joint whose Part1 is LowerTorso (R15 "Root")
│           ├── Pose "UpperTorso"                <- joint "Waist"
│           │   ├── Pose "Head"                  <- "Neck"
│           │   └── Pose "RightUpperArm"         <- "RightShoulder"
│           │       └── Pose "RightLowerArm"     <- "RightElbow"
│           │           └── Pose "RightHand"     <- "RightWrist"
│           ├── Pose "LeftUpperLeg" ...
│           └── ...
├── Keyframe  Time = 0.2
│   └── ...
└── Keyframe  Time = 0.6   <- the highest Time defines the clip's Length
```

## Class reference

### KeyframeSequence (inherits AnimationClip)
| Member | Type | Notes |
|---|---|---|
| `Loop` | boolean | Default loop flag for tracks loaded from it. `AnimationTrack.Looped` overrides at runtime. |
| `Priority` | `Enum.AnimationPriority` | Default priority. `AnimationTrack.Priority` overrides. |
| `Length` | number, read-only | From AnimationClip. |
| `AuthoredHipHeight` | number, hidden, Plugin security | The Humanoid hip height of the rig the clip was authored on. Docs default 1.35 (standard R15). Its effect on playback is undocumented. Lua tools that rebuild clips should copy it across so nothing changes. |
| `AddKeyframe(kf)` | method | Same as setting `kf.Parent`. Does not type-check (any instance gets parented). |
| `GetKeyframes()` | method | All Keyframe children. **Not guaranteed sorted by time**: sort them yourself. |
| `RemoveKeyframe(kf)` | method | Sets parent to nil; does not destroy. |

### Keyframe
| Member | Notes |
|---|---|
| `Time` | Seconds from the start. |
| `Name` | "Keyframe" by default. Any other name fires `AnimationTrack.KeyframeReached(name)` and is found by `GetTimeOfKeyframe(name)`. |
| `AddPose(pose)`, `GetPoses()`, `RemovePose(pose)` | Top-level poses (parenting helpers, no type checks). `GetPoses` returns only direct children. |
| `AddMarker(marker)`, `GetMarkers()`, `RemoveMarker(marker)` | `KeyframeMarker` children. |

### PoseBase (abstract) and Pose
| Member | Type | Notes |
|---|---|---|
| `EasingStyle` | `Enum.PoseEasingStyle` | `Linear`, `Constant`, `Elastic`, `Cubic` (legacy, reversed), `Bounce`, `CubicV2`. |
| `EasingDirection` | `Enum.PoseEasingDirection` | `In`, `Out`, `InOut`. |
| `Weight` | number | 1 = a key. **0 = a placeholder that is not a key at all** (see below). |
| `Pose.CFrame` | CFrame | The joint's local animated offset: written into `Transform`, with C0/C1 untouched. Identity = the rest pose. |
| `Pose.MaskWeight` | number, deprecated | Ignore. Use track weights. |
| `AddSubPose(pose)`, `GetSubPoses()`, `RemoveSubPose(pose)` | methods | Parenting helpers; `GetSubPoses` returns all children, including non-Poses. |

### NumberPose
A `PoseBase` with `Value: number` instead of a CFrame. It keys scalar channels (for example `FaceControls` properties) inside a KeyframeSequence, following the same Weight and easing rules.

### KeyframeMarker
| Member | Notes |
|---|---|
| `Name` | The event name you pass to `GetMarkerReachedSignal(name)`. |
| `Value` | String passed to the listener. Free-form: a single value, comma-separated parameters, or `key=value` lists. |

## Semantics the reference does not spell out

### 1. A key is a Pose with Weight > 0
For each joint, the Animator collects the Poses with `Weight > 0` across all Keyframes; those are its keys. A `Weight = 0` Pose exists only to hold the hierarchy together (a parent you must have so a child can hang under it). It is skipped when finding the keys around a time. So:
- A joint does **not** need a Pose in every Keyframe. Between its keys it interpolates as if the keyframes in between did not exist for it.
- A Weight-0 Pose cannot be used to "release" a joint at one keyframe. If you need a joint to stop being driven, it must be absent from the clip (or the track must stop).
- Tools that write upper-body clips set lower-body poses to Weight 0 or omit them. One project's upper-body copies were "the same clip with hips and legs at Weight 0", published separately.

### 2. Pose names bind to joints by Part1 name
The Pose's Name matches a `BasePart` name, and the CFrame is applied to the joint connecting **that part to the part of the parent Pose**. Example from the docs: the `LowerTorso` Pose drives the R15 motor named `Root` (HumanoidRootPart to LowerTorso). For bones, the Pose name is the Bone name. Nothing errors when a name does not match; the key is simply inert. That is also how weapon rig players bind: one production Lua player keyed motors by `Part0.Name .. "\0" .. Part1.Name` from the parent-Pose/Pose pair, which disambiguates rigs where two hinges share a Part1 name.

### 3. The top-level pose is never applied
Measured in one production project: the Pose directly under a Keyframe (`HumanoidRootPart`, or the `Root` bone on bone rigs) is ignored, only the poses under it animate. That is consistent with the docs' sample, which creates the HumanoidRootPart pose at Weight 0. Consequences:
- Root lift, crouch drops and root travel go on the first child (`LowerTorso` on R15, a `Body`/`Hips` bone on custom rigs).
- An imported clip that keyed the whole-body facing on the root pose played turned 180 degrees in one game, because that root rotation was thrown away while the children kept theirs. See [[Pipeline - Importing Animated Enemies]].

### 4. Easing belongs to the segment's first key
`EasingStyle` and `EasingDirection` on a Pose shape the motion **from this key to the next key of the same joint**. The easing on the last key of a joint does nothing. Tools that think in "how do I arrive at this key" must write each key's easing onto the previous key. One team's convention, from their builder's comments: "a key's easing is the shape of the move INTO it, so the leaving pose carries it". Full easing semantics, including the reversed legacy `Cubic`, are in [[Keyframes, Easing and Interpolation]].

### 5. Keyframe order and evenly spaced keyframes
The Animator picks its rotation interpolation model from the **keyframe spacing of the whole sequence** (measured): evenly spaced keyframes with all-Linear keys get [[Quaternions|quaternion]] nlerp; anything else gets a linear blend of rotation vectors. A marker-only Keyframe off the grid counts and switches the model. See [[How the Animator Really Behaves]].

### 6. Length is the last Keyframe's time
Not the last Pose, not the last marker: the highest `Keyframe.Time`. A marker after the last motion key extends the clip.

### 7. Pose CFrames should be rotation-only on most joints
Translation on an R15 arm joint reads as a detached limb. One QA tool flagged any arm-joint translation over 0.05 studs as a "detached shoulder". Keep translations for the root child (hips travel), for deliberate squash, and for rigs whose joints genuinely slide.

## Building a KeyframeSequence in code

```lua
--!strict
-- Builds a minimal two-key arm raise for an R15 rig. Poses must nest like the rig.
local function pose(name: string, cf: CFrame, weight: number, style: Enum.PoseEasingStyle?, dir: Enum.PoseEasingDirection?): Pose
	local p = Instance.new("Pose")
	p.Name = name
	p.CFrame = cf
	p.Weight = weight
	p.EasingStyle = style or Enum.PoseEasingStyle.Linear
	p.EasingDirection = dir or Enum.PoseEasingDirection.In
	return p
end

local function keyframe(t: number, shoulder: CFrame, style: Enum.PoseEasingStyle, dir: Enum.PoseEasingDirection): Keyframe
	local kf = Instance.new("Keyframe")
	kf.Time = t
	-- Placeholders (Weight 0) carry the hierarchy down to the arm.
	local hrp = pose("HumanoidRootPart", CFrame.identity, 0)
	local lower = pose("LowerTorso", CFrame.identity, 0)
	local upper = pose("UpperTorso", CFrame.identity, 0)
	local arm = pose("RightUpperArm", shoulder, 1, style, dir)
	arm.Parent = upper
	upper.Parent = lower
	lower.Parent = hrp
	kf:AddPose(hrp)
	return kf
end

local ks = Instance.new("KeyframeSequence")
ks.Name = "RaiseArm"
ks.Loop = false
ks.Priority = Enum.AnimationPriority.Action
-- The easing on the FIRST key shapes the move to the second key.
ks:AddKeyframe(keyframe(0, CFrame.identity, Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.Out))
local last = keyframe(0.4, CFrame.Angles(0, 0, math.rad(120)), Enum.PoseEasingStyle.Linear, Enum.PoseEasingDirection.In)
local hit = Instance.new("KeyframeMarker")
hit.Name = "Hit"
hit.Value = ""
last:AddMarker(hit)
ks:AddKeyframe(last)
```

To play it you still need an id. In Studio you can register it (below); for a live game you either publish it or sample it yourself with a Lua player. More builders in [[Authoring Clips in Code]] and [[Snippets - Building and Sampling Clips]].

## Reading a KeyframeSequence as joint tracks

```lua
--!strict
type Key = { t: number, cf: CFrame, style: Enum.PoseEasingStyle, dir: Enum.PoseEasingDirection }

-- Returns per-joint sorted key lists, skipping the top-level pose and Weight-0 placeholders,
-- which is exactly what the Animator treats as keys.
local function jointKeys(ks: KeyframeSequence): {[string]: {Key}}
	local out: {[string]: {Key}} = {}
	local kfs = ks:GetKeyframes()
	table.sort(kfs, function(a, b) return (a :: Keyframe).Time < (b :: Keyframe).Time end)
	local function walk(parent: Instance, t: number)
		for _, child in parent:GetChildren() do
			if child:IsA("Pose") then
				if child.Weight > 0 then
					local list = out[child.Name]
					if not list then list = {}; out[child.Name] = list end
					table.insert(list, { t = t, cf = child.CFrame, style = child.EasingStyle, dir = child.EasingDirection })
				end
				walk(child, t)
			end
		end
	end
	for _, kf in kfs do
		local k = kf :: Keyframe
		for _, top in k:GetChildren() do
			if top:IsA("Pose") then walk(top, k.Time) end -- 'top' itself is the ignored root pose
		end
	end
	return out
end
```

## KeyframeSequenceProvider

| Member | Notes |
|---|---|
| `RegisterKeyframeSequence(ks): string` | Temporary hash id usable in `Animation.AnimationId`. **Studio only.** |
| `RegisterActiveKeyframeSequence(ks): string` | Same, returns an `active://` URL. **Studio only.** |
| `GetKeyframeSequenceAsync(assetId): KeyframeSequence?` | Downloads a published animation's KeyframeSequence. Yields; wrap in `pcall`. |
| `GetAnimationsAsync(userId): InventoryPages` | Pages of a user's animations (plugin browsing). |
| `GetKeyframeSequence`, `GetKeyframeSequenceById` | Deprecated, Plugin security, can freeze while loading. |
| `GetAnimations` | Deprecated in favour of the Async version. |

The docs now describe `AnimationClipProvider` as the replacement service; it has the same Register/Get pair for any AnimationClip plus `GetClipEvaluatorAsync`.

**The production trap.** A registered id plays perfectly in Studio, including in Play Solo, and plays **nothing** in a live server. No error is raised. One game shipped dozens of abilities whose clips were registered at runtime: in live servers the abilities "did nothing", weapon hinges stood still and marker-driven specials never fired, while every Studio test passed. The rule they wrote afterwards: never call `RegisterKeyframeSequence` for a clip that must play live; publish it or play it with your own Lua player. A templated kit generator later reintroduced the register path in a new weapon, so add a check to your build tools that greps for it.

**Fresh-registration gotcha (Studio).** A just-registered clip plays nothing until the track's `Length > 0`. Wait for it before calling `StepAnimations`:

```lua
local KSP = game:GetService("KeyframeSequenceProvider")
local a = Instance.new("Animation")
a.AnimationId = KSP:RegisterKeyframeSequence(ks)
local tr = animator:LoadAnimation(a)
tr.Priority = Enum.AnimationPriority.Action4
local w0 = os.clock()
while tr.Length <= 0 and os.clock() - w0 < 2 do task.wait() end
tr:Play(0)
animator:StepAnimations(1 / 60) -- dt must be > 0 (measured)
```

## Instance cost: the hidden problem with KeyframeSequences

Every Pose is an Instance. A full-body R15 key is about 16 Poses; a 2-second clip baked at 30 keys/s is 60 Keyframes x 16 Poses = about 1,000 instances for one clip. Libraries grow fast:

| Measured in one production game | Instances |
|---|---|
| Animation Editor saves folder | 642k |
| A pose-thinning backup | 512k |
| Enemy clips baked at 16-25 fps, every joint keyed | 323k in ReplicatedStorage |
| ReplicatedStorage after converting player kit clips to Pose-free stubs | 392k to 107k |
| ServerStorage after converting well over a thousand enemy clips to stubs and archiving | 1.96M to 712k, then 420k |

Ways out, in order of effort: keep source clips out of ReplicatedStorage; thin keys (drop keys that interpolation reproduces within a tolerance); publish the clips and keep only `Animation` pointers; or bake each clip into a compact binary buffer stored in an attribute and play it with a Lua player (see [[Baked Clip Stubs and Archiving]] and [[Clip Buffer Format]]). Each extra key on an arm costs 3 Poses; each new Keyframe also costs its placeholder chain (HumanoidRootPart, LowerTorso, UpperTorso) unless it reuses an existing keyframe time.

## Checklist for a clean KeyframeSequence

- [ ] Top-level pose is `HumanoidRootPart` (or the rig's root) at Weight 0; motion starts on its child.
- [ ] Every Pose name matches a Part1 (or Bone) name on the target rig.
- [ ] Placeholders are Weight 0; real keys are Weight 1.
- [ ] Easing written on the key that **starts** each segment; no legacy `Cubic`.
- [ ] No key-to-key turn near 180 degrees; ideally under 120.
- [ ] Markers carry gameplay events; Keyframe names left as "Keyframe" unless a legacy listener needs them.
- [ ] First and last poses close to the rig's idle.
- [ ] Translation only where joints really move (root child, sliding parts).
- [ ] Instance count checked against your folder budget.

## See also
[[Animation Objects]] · [[Keyframes, Easing and Interpolation]] · [[How the Animator Really Behaves]] · [[Markers and Events]] · [[CurveAnimation and Curve Channels]] · [[Authoring Clips in Code]] · [[Publishing Animations]] · [[Baked Clip Stubs and Archiving]]

## Connected notes
<!-- auto-links:start -->
[[Weapon Rig Player]] · [[Engine Gotchas]] · [[Animation Data from Blender to Roblox]] · [[Lua Keyframe Player]] · [[AI Animation and Motion from Video]] · Easing · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Animation Glossary]] · [[AnimationTrack Reference]] · [[Animation Editor Advanced]] · [[Animator Deep Dive]] · [[Animation Editor Workflow]] · [[Lua Keyframe Player Internals]] · [[Snippets - Lua Keyframe Player Core]] · [[Performance and Memory]]
<!-- related:end -->
