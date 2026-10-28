---
tags: [fundamentals, api, reference, curveanimation, curves]
---
# CurveAnimation and Curve Channels

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Calling `X()` on a read-only inspection pass (Creates empty FloatCurves inside clips you meant only to read)
> - Avoid: Setting `RightTangent` on a Linear key (Runtime error)
> - Avoid: Assuming tangents are per frame (Overshoot 30x or 60x too large or small; test the unit)
>
> Read more (16 KB note): ## Curve classes · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

`CurveAnimation` is Roblox's second clip format. Instead of whole-rig snapshots at keyframe times (a [[KeyframeSequence Keyframe and Pose Reference|KeyframeSequence]]), it stores **one independent curve per channel**: a position curve and a rotation curve per joint, a float curve per face control, and a marker curve for events. The Animation Editor's curve editor produces it, it publishes like any other animation, and it is the natural format for tangent-level polish and facial animation.

This note is the full reference for `CurveAnimation`, `FloatCurve`, `RotationCurve`, `EulerRotationCurve`, `Vector3Curve`, `MarkerCurve` and the key datatypes, plus guidance on when the format is worth it. Verified against the engine API dump and class pages (October 2026). Where the docs are silent (tangent units, angle units in Euler curves) this note says so instead of guessing.

## Structure

Illustrative layout for an R15 rig (inspect an editor-made clip for the exact top-level naming your Studio version writes):

```
CurveAnimation  (Loop, Priority, Length from AnimationClip)
├── Folder "HumanoidRootPart"            <- folders mirror the joint hierarchy
│   └── Folder "LowerTorso"
│       ├── Vector3Curve "Position"      <- local translation (X/Y/Z FloatCurves inside)
│       ├── EulerRotationCurve "Rotation"  or  RotationCurve "Rotation"
│       └── Folder "UpperTorso"
│           ├── Vector3Curve "Position"
│           ├── EulerRotationCurve "Rotation"
│           └── ...
├── Folder "FaceControls"                <- named after the FaceControls instance in the model
│   ├── FloatCurve "JawDrop"             <- one FloatCurve per FaceControls property
│   └── FloatCurve "LeftEyeClosed"
└── MarkerCurve                          <- events (see below; exact placement is whatever the editor writes)
```

Rules from the docs:
- Each animated joint is a `Folder`; folders nest to match the joint tree of the target's `Motor6D` or `Bone` instances.
- Inside a joint folder, a child named `Position` (`Vector3Curve`) drives local translation and a child named `Rotation` (`EulerRotationCurve` or `RotationCurve`) drives local rotation.
- Not every joint must exist on the target: existing ones still apply (same "missing joints are inert" behaviour as KeyframeSequences).
- A root folder may match a **sub-hierarchy** of the model rather than the top: a clip whose root folder is `UpperTorso` can drive just the upper body of a rig.
- Facial channels: a `Folder` named after an existing `FaceControls` instance holds one `FloatCurve` per animated property (`JawDrop`, `LeftEyeClosed` and so on).

Publishing and testing work exactly as for KeyframeSequences: it must be uploaded to play in a live game; `AnimationClipProvider:RegisterAnimationClip` gives a temporary, **Studio-only** id; `AnimationClipProvider:GetAnimationClipAsync` downloads a published one.

## Key datatypes

### FloatCurveKey
`FloatCurveKey.new(time: number, value: number, interpolation: Enum.KeyInterpolationMode?)`

| Field | Default | Meaning |
|---|---|---|
| `Time` | 0 | Position on the curve's timeline (seconds). Keys stay sorted; inserting at an existing time replaces that key. |
| `Value` | 0 | Value at this time. |
| `Interpolation` | `Cubic` | Shape of the segment **from this key to the next**: `Constant` holds this value, `Linear` lerps, `Cubic` is a cubic Hermite spline. Setting a non-cubic mode clears `RightTangent`. |
| `RightTangent` | nil (treated as 0) | Slope leaving this key. Can only be set when `Interpolation` is `Cubic`; setting it otherwise is a runtime error. |
| `LeftTangent` | nil (treated as 0) | Slope arriving at this key. Can be set in any mode because the previous segment may be cubic. |

When a key's `LeftTangent` and `RightTangent` differ, the curve has a corner at that key (a broken tangent); equal tangents give a smooth pass-through. **Tangent units are not documented**: they are slopes, value per unit time, but the docs never state whether the time unit is seconds. Test with a known curve before computing tangents numerically (for example, key 0 to 1 over 1 s with both tangents 1 should be a straight line if units are per second).

### RotationCurveKey
`RotationCurveKey.new(time: number, cframe: CFrame, interpolation: Enum.KeyInterpolationMode?)`

| Field | Meaning |
|---|---|
| `Time` | Seconds. |
| `Value` | CFrame; **only the rotation is used**. |
| `Interpolation` | `Constant` holds; `Linear` is documented as **spherical interpolation (slerp)** between the two rotations; `Cubic` (default) uses a Hermite spline shaped by this key's `RightTangent` and the next key's `LeftTangent`. |
| `LeftTangent`, `RightTangent` | Scalar slopes (units undocumented). What a scalar tangent means for a rotation is also undocumented: in practice it shapes the progress along the rotation path rather than the axis. |

### Enum.KeyInterpolationMode
`Constant` (0), `Linear` (1), `Cubic` (2).

## Curve classes

### FloatCurve
| Member | Notes |
|---|---|
| `Length` | Number of keys (not seconds). |
| `GetKeys()` | Copy of all keys as an array. |
| `GetKeyAtIndex(i)` | Copy of key `i` (1-based). |
| `GetKeyIndicesAtTime(t)` | Two 1-based indices bracketing `t`: last key with time <= t, first key with time >= t (edge cases clamp to the ends). |
| `GetValueAtTime(t)` | Samples the curve. Return type is `number?`; the docs do not say when it returns nil (treat an empty curve as nil). |
| `InsertKey(key)` | Adds or replaces at the same time. Returns `{added: boolean, index: number}`. |
| `RemoveKeyAtIndex(start, count = 1)` | Returns the number removed. |
| `SetKeys(keys)` | Replaces all keys; sorts by time, removes duplicate times (stable), returns the count inserted. |

No maximum key count is documented.

### RotationCurve
Same members as FloatCurve but with `RotationCurveKey`s; `GetValueAtTime` returns `CFrame?` and an empty curve evaluates to `CFrame.identity`.

### EulerRotationCurve
Three child `FloatCurve`s named `X`, `Y`, `Z`, combined in the order given by `RotationOrder` (`Enum.RotationOrder`: XYZ, XZY, YZX, YXZ, ZXY, ZYX).

| Member | Notes |
|---|---|
| `RotationOrder` | Composition order. Default not stated on the docs page. |
| `GetAnglesAtTime(t)` | Array of three samples; a missing channel or no key gives nil for that channel. |
| `GetRotationAtTime(t)` | CFrame; empty channels count as 0. |
| `X()`, `Y()`, `Z()` | Return the child FloatCurve with that name, **creating an empty one if missing** (a side effect: calling `X()` on a read path adds an instance). |

The docs do not state whether the angles are radians or degrees. Roblox CFrame maths is radians throughout and editor-made curves behave as radians in practice, but verify on your own clip before writing a converter.

### Vector3Curve
Three child FloatCurves `X`, `Y`, `Z` (the `X()/Y()/Z()` accessors behave like EulerRotationCurve's). `GetValueAtTime(t)` returns an array of three values (nil for empty channels), not a Vector3.

### MarkerCurve
| Member | Notes |
|---|---|
| `Length` | Number of markers. |
| `GetMarkers()`, `GetMarkerAtIndex(i)` | Markers as tables (time and name). |
| `InsertMarkerAtTime(time, marker: string)` | Adds a marker. |
| `RemoveMarkerAtIndex(start, count = 1)` | Removes markers. |

Markers in a CurveAnimation fire through the same `AnimationTrack:GetMarkerReachedSignal(name)` as KeyframeMarkers.

## Evaluating a CurveAnimation yourself

Useful for previews, retargeting tools, or a Lua player that supports both formats.

```lua
--!strict
-- Samples one joint folder of a CurveAnimation at time t, as the local Transform CFrame.
local function sampleJointFolder(folder: Folder, t: number): CFrame
	local pos = Vector3.zero
	local posCurve = folder:FindFirstChild("Position")
	if posCurve and posCurve:IsA("Vector3Curve") then
		local v = posCurve:GetValueAtTime(t)
		pos = Vector3.new(v[1] or 0, v[2] or 0, v[3] or 0) -- empty channels come back nil
	end
	local rot = CFrame.identity
	local rotCurve = folder:FindFirstChild("Rotation")
	if rotCurve then
		if rotCurve:IsA("EulerRotationCurve") then
			rot = rotCurve:GetRotationAtTime(t) -- composes in RotationOrder, empty channels = 0
		elseif rotCurve:IsA("RotationCurve") then
			rot = rotCurve:GetValueAtTime(t) or CFrame.identity
		end
	end
	return CFrame.new(pos) * rot
end

-- Walk every joint folder, returning {[jointName] = CFrame}
local function samplePose(anim: CurveAnimation, t: number): {[string]: CFrame}
	local out: {[string]: CFrame} = {}
	local function walk(parent: Instance)
		for _, child in parent:GetChildren() do
			if child:IsA("Folder") then
				out[child.Name] = sampleJointFolder(child, t)
				walk(child)
			end
		end
	end
	walk(anim)
	return out
end
```

Caveats: whether the root folder's own channels are applied (the KeyframeSequence root pose is not), and whether the Animator interpolates `RotationCurve` Linear keys exactly as `GetValueAtTime` reports, were **not measured** in the reference project. If you build tools on this, run the same A/B check that was done for KeyframeSequences: play the clip on the real Animator with `StepAnimations` and compare joint `Transform`s to your sampler (see [[How the Animator Really Behaves]]).

## Converting a KeyframeSequence to curves

Per joint, each Pose with `Weight > 0` becomes a key on that joint's curves:

| KeyframeSequence | CurveAnimation |
|---|---|
| Pose `CFrame.Position` | `Position` Vector3Curve X/Y/Z keys |
| Pose rotation | `Rotation` RotationCurve key (or Euler X/Y/Z keys) |
| `Linear` easing | `KeyInterpolationMode.Linear` |
| `Constant` easing | `KeyInterpolationMode.Constant` (matches "Out = hold"; the KeyframeSequence `Constant In` and `InOut` variants have no direct equivalent) |
| `CubicV2` In/Out/InOut | `Cubic` with tangents chosen to mimic the ease (0 tangents give an ease-in-out shape) |
| Elastic / Bounce | No equivalent: bake them to dense keys |
| `KeyframeMarker` | `MarkerCurve` entry |

**Important difference.** A KeyframeSequence with uneven keys interpolates rotations as a linear blend of rotation vectors (measured; see [[How the Animator Really Behaves]]), while `RotationCurve` Linear is documented as slerp. On big turns far from the joint's rest pose those differ by many degrees (one shoulder measured 9-12 degrees apart, and slerp-based predictions up to 178 degrees off). A converted clip can therefore look different from its source on large swings. Add in-between keys on big turns before converting, or bake densely.

## Why choose curves, why not

| For CurveAnimation | Against |
|---|---|
| Per-channel keys: animate the head on 3 keys and the hand on 30 without placeholder chains | Fewer community tools, importers and Lua players understand it |
| Real tangents: overshoot and settles without Elastic/Bounce presets | Euler channels can gimbal-lock and need care around +-180 |
| Native facial animation through FaceControls FloatCurves | Instance count is still per curve and per key-bearing object; not automatically smaller |
| Editor curve view for polish | Behaviour of Animator vs `GetValueAtTime` not independently measured here |

Rule of thumb: hand-polished hero animation and faces are good fits for curves. Generated, baked or tool-processed clips (IK bakes, mocap cleanups, thinning) are easier as KeyframeSequences, because every tool you will write already speaks that format and the measured Animator model is known for it. The reference project deliberately did not use CurveAnimation for that reason.

## Common mistakes

| Mistake | Result |
|---|---|
| Calling `X()` on a read-only inspection pass | Creates empty FloatCurves inside clips you meant only to read |
| Setting `RightTangent` on a Linear key | Runtime error |
| Assuming tangents are per frame | Overshoot 30x or 60x too large or small; test the unit |
| Naming a joint folder after the joint (`RightShoulder`) | Inert channel; use the Part1 or Bone name |
| Shipping a `RegisterAnimationClip` id | Nothing plays live |
| Euler channel jumping from +179 to -179 degrees | Joint spins the long way; unwrap angles or use RotationCurve |

## See also
[[Animation Objects]] · [[KeyframeSequence Keyframe and Pose Reference]] · [[Keyframes, Easing and Interpolation]] · [[Facial Animation and Dynamic Heads]] · [[Animation Editor Advanced]] · [[Markers and Events]]

## Nuances and edge cases

1. **Publishing is the same; tooling is not.** Once published, a CurveAnimation plays like any other animation asset through the Animator, with the same permission rules and replication. The difference is entirely on the authoring and tooling side. If your team only uses the Animation Editor and publishes, the format choice barely matters; if you write tools, it matters a lot.
2. **Mixed libraries.** Many projects end up with both formats: hand-polished clips as curves, generated clips as KeyframeSequences. That is fine for playback, but any tool that walks clips (marker extraction, validation, thinning, retargeting) now needs two code paths. Budget for that, or pick one format for everything tool-processed.
3. **Facial animation scale.** FaceControls curves add dozens of float channels per clip (one per FACS control used). For a talking NPC that is fine; for 50 players with emote faces animating at once on a phone, face evaluation adds up. Gate facial animation by distance and drop it for characters beyond conversational range.
4. **Tangent units.** As the existing mistakes table notes, tangent units are easy to get wrong. Verify against the Animation Editor's own curve view on one known key before batch-converting a library; a unit error multiplies every overshoot in every clip.
5. **Euler vs rotation curves.** Euler curves are easier to edit by hand but suffer gimbal lock near 90 degrees on the middle axis and wrapping at plus or minus 180. Rotation curves avoid both but are harder to tweak numerically. For limbs that spin or swing through large arcs (weapon twirls, flips), use rotation curves; for subtle head and spine motion, Euler is acceptable.
6. **Instance counts are not automatically lower.** Curves avoid placeholder Pose chains, but every curve and every key-bearing object is still an instance. A clip keyed on every channel at every frame can be larger as curves than as a KeyframeSequence. Sparse keys are where curves win.
7. **Behaviour can differ from KeyframeSequence.** The documented slerp for linear RotationCurve keys differs from the measured rotation-vector blend of uneven KeyframeSequences. Converting a library from one format to the other can subtly change motion on large rotations; A/B the result before replacing originals.
8. **Version risk.** CurveAnimation is newer and its tooling and documentation are still evolving. Re-check class pages before relying on undocumented behaviour, and keep source files for anything converted.

## Common mistakes in production

1. **Converting a whole library without A/B.** Symptom: subtle wrist and spine differences that animators spot weeks later. Fix: convert a sample, compare against originals, then batch.
2. **Facial curves on every character at every distance.** Symptom: frame time grows in crowded social spaces. Fix: distance gating for faces.
3. **Tool assumes one format.** Symptom: marker extraction silently skips curve clips. Fix: tools detect format and handle both, or refuse with a clear message.
4. **Euler curves on twirling weapons.** Symptom: weapons flip at certain angles. Fix: rotation curves for large arcs.
5. **Assuming curves are smaller.** Symptom: place size grows after a conversion. Fix: measure instance counts before and after.

## Related decisions

- [[Interpolation Easing and Curves Math]]: tangents, cubic curves and easing shapes behind curve keys.
- [[Rotations Angles and Quaternions]]: gimbal lock and why rotation curves avoid it.
- [[Case Study - Instance Cleanup and Place Size]]: measuring whether a format change actually saves instances.
- [[AI Animation and Motion from Video]]: generated motion, which tends to arrive dense and suits keyframe tooling.
- [[Blender Automation with Python]]: exporting curves or keyframes from Blender.
- [[Pipeline Design Principles]]: choosing one canonical format for tool-processed data.
- [[Dialogue System End to End]]: where facial animation channels meet talking NPCs.
- [[Mobile and Low-End Optimization]]: gating facial animation on weak devices.

## Connected notes
<!-- auto-links:start -->
[[Snippets - Building and Sampling Clips]] · [[Authoring Clips in Code]] · [[Animation Glossary]] · [[Animation Data from Blender to Roblox]] · [[Easing]] · [[Game Math Start Here]] · [[Animation Start Here]]
<!-- auto-links:end -->
