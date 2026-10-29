---
tags: [ai, animation, mocap, video, animation-capture, type/guide, area/ai, level/intermediate, api/KeyframeSequence, area/animation, api/Animator]
---
# AI Animation and Motion from Video

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Feet out of frame in the source video.
> - Avoid: Shipping captured clips without key reduction (hundreds of keys per second).
> - Avoid: Captured combat swings with no designed contact frame.
> - Video: under 15 s, one person, full body, stable camera, neutral start and end.
> - Cleanup: jitter filtered, feet locked, root handled, wrists unrolled.
> - Keys reduced with an error bound; no segment over about 120 degrees; none at 180.
>
> Cost: TL;DR ~150 tok · whole note ~3.3k tok. Read more: ## 1. Roblox Animation Capture · ## 6. How the reference project used AI for animation (without capture) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

AI can now turn a phone video into keyframes. Roblox has this built into the Animation Editor (Animation Capture), and several external services do the same with more control. For emotes, idles, dances and social animation this is a real shortcut. For combat, where contact frames, weapon arcs and timing are the whole design, video capture is at best reference. This note covers Roblox's capture tools, external options, the cleanup that video motion always needs, Roblox-specific pitfalls when importing it, and how the reference project used AI agents for animation without any motion capture at all.

Deeper animation background lives in the Animation section: [[Animation Capture and Mocap]], [[Retargeting Animations Between Rigs]], [[Animation Data from Blender to Roblox]], [[How the Animator Really Behaves]], [[Animation Quality Standard]].

As of October 2026, verified against the Roblox Creator Hub Animation Capture page. External products change often.

---

## 1. Roblox Animation Capture

Animation Capture lives in the Animation Editor (Clip Editor). It has two modes.

### Body from video

From the Roblox docs:
- **Input:** a video file, `.mp4` or `.mov`.
- **Length:** under 15 seconds, one continuous shot.
- **Filming:** a stable camera, one person, visible throughout, well lit.
- **Rig:** R15 only.
- **Beta:** enable it under File > Beta Features first (the page names the "Live Animation Creator" feature).
- **Workflow:** select the R15 rig in the Clip Editor, create the animation, open the "..." menu in the media and playback controls, choose Import and the capture option, and pick the video. Processing takes about a minute.
- **Output:** keyframes matching the movement appear on the timeline. Then clean up, save and export.
- **Content:** the video must follow the Community Rules and Terms of Use.

### Face from webcam

- Live webcam recording, up to 60 seconds per take.
- Needs an animation-compatible (dynamic) head ([[Facial Animation and Dynamic Heads]]).
- Enable the Face Capture beta; accept the consent prompt; record; re-record as needed.
- Output is facial keyframes on the timeline.

### Filming tips that matter more than any setting

Rules of thumb from capture practice:
- Full body in frame the whole time, including feet. Feet leaving the frame is the most common cause of broken legs in the result.
- Fitted clothing, contrasting with the background. Loose robes hide the joints.
- Side-on or three-quarter view for motions with depth (lunges, kicks); front view for arm-heavy emotes.
- Start and end in a neutral pose for a second, so you have clean frames to blend from and to.
- Film at the speed you want. Speeding up captured motion afterwards exaggerates jitter.
- Exaggerate. Captured human motion reads small and floaty on a Roblox character; animators push poses further ([[Principles of Animation for Games]]).

---

## 2. External video-to-motion and text-to-motion tools

Several commercial services turn video into skeletal animation (FBX or BVH) with more control than Roblox's built-in capture: multi-camera capture, longer clips, finger tracking, root motion options. Names in this space include Rokoko Vision, Move AI, DeepMotion and Plask; capabilities and plans vary and change, so check each one. Text-to-motion generators, which produce motion from a description ("a tired walk"), also exist as products and research models.

What to check before choosing:

| Question | Why |
|---|---|
| Output format and skeleton | You will retarget to R15 or your custom rig; a standard humanoid skeleton is easier |
| Root motion handling | Roblox characters are usually moved by the Humanoid or your controller, not by clip root motion |
| Foot contact / ground lock | Saves the most cleanup time |
| Clip length and frame rate | Long takes for dances; 30 fps is plenty for Roblox |
| Commercial terms on your plan | Same as any AI output: [[Roblox Policies on AI-Generated Content]] |

Retarget in Blender (or the tool's own retargeter) onto an R15-proportioned armature, then bring the animation to Roblox as an FBX animation import or through your pipeline. See [[Retargeting Animations Between Rigs]] and [[Exporting FBX vs GLB]].

---

## 3. Cleanup: what video motion always needs

| Problem | Looks like | Fix |
|---|---|---|
| Jitter | Small high-frequency shaking, worst on hands and head | Smooth curves (a filter over 3-5 frames), then reduce keys |
| Foot sliding | Planted feet drift | Lock contacts with IK or key the feet; [[Foot Placement and Ground IK]] |
| Floating or sinking | Character hovers or sinks during the clip | Adjust the hip height curve; check at your game's character scale |
| Root drift | Character walks away from its origin in an in-place clip | Remove root travel, keep it as data if you need it |
| Wrist flips | Hands snap through 180 degrees | Unroll rotations, re-key the wrist |
| Too many keys | Every frame keyed on every joint | Key reduction with an error bound |
| Dead hands | Hands stiff or in odd poses | Hand-key fingers and grips; capture rarely helps |
| Weak poses | Correct but boring | Push key poses and timing by hand |

### Key reduction

Captured clips arrive with a key on every frame for every joint. On Roblox that is many `Pose` instances per clip (instance counts matter: the reference project budgeted kit folders at 2,500 instances). Reduce keys with an error bound: drop a key if interpolating its neighbours reproduces it within a small tolerance (the reference project's tools used tolerances around 0.75 to 1.5 degrees for body joints and 0.03 studs for positions, and kept keys near markers). See [[Baked Clip Stubs and Archiving]] and [[Performance and Memory]].

---

## 4. Roblox Animator pitfalls when importing motion

These come from measurements in the reference project (see [[Engine Gotchas]] and [[How the Animator Really Behaves]]):

- **Big key-to-key turns take unexpected paths.** For most clips the Animator blends rotation vectors between keys, not a [[slerp]]. After key reduction, keep each joint's turn between consecutive keys under about 120 degrees.
- **Exactly 180 degree segments are ambiguous**; the engine may go either way.
- **Legacy `Cubic` easing runs reversed**; use `CubicV2` or Linear. Captured and reduced clips usually use Linear, which is safe.
- **The top-level root pose is never applied.** Root lift and travel must be on its first child (LowerTorso).
- **Scale**: on characters scaled through body scale values, clip translations apply literally; a crouch captured at default scale leaves the feet hovering on a larger character. The reference project's characters were scaled 1.6x and its clips stored root offsets at game scale.
- **Ids**: test clips in a live server using published ids, not Studio-only temporary ids ([[Publishing Animations]], [[Animation Asset Permissions and Groups]]).

A small check for the first two pitfalls on a `KeyframeSequence`:

```lua
--!strict
-- Flag joint segments that are too large between consecutive keys.
local MAX_DEG = 120
local NEAR_180 = 178

local function collectPoses(ks: KeyframeSequence): { [string]: { { t: number, cf: CFrame } } }
	local byJoint: { [string]: { { t: number, cf: CFrame } } } = {}
	for _, kf in ks:GetKeyframes() do
		local keyframe = kf :: Keyframe
		for _, d in keyframe:GetDescendants() do
			if d:IsA("Pose") and d.Weight > 0 then -- weight-0 poses are placeholders, not keys
				local list = byJoint[d.Name]
				if not list then
					list = {}
					byJoint[d.Name] = list
				end
				table.insert(list, { t = keyframe.Time, cf = d.CFrame })
			end
		end
	end
	for _, list in byJoint do
		table.sort(list, function(a, b)
			return a.t < b.t
		end)
	end
	return byJoint
end

local function checkSegments(ks: KeyframeSequence)
	local issues = 0
	for joint, keys in collectPoses(ks) do
		for i = 2, #keys do
			local rel = keys[i - 1].cf:ToObjectSpace(keys[i].cf)
			local _, angle = rel:ToAxisAngle()
			local deg = math.deg(math.abs(angle))
			if deg >= NEAR_180 then
				issues += 1
				warn(("%s %.3f-%.3f: %.1f deg (ambiguous, split it)"):format(joint, keys[i - 1].t, keys[i].t, deg))
			elseif deg > MAX_DEG then
				issues += 1
				warn(("%s %.3f-%.3f: %.1f deg (over %d, add a key)"):format(joint, keys[i - 1].t, keys[i].t, deg, MAX_DEG))
			end
		end
	end
	print(ks.Name, issues == 0 and "ok" or (issues .. " issues"))
end
```

---

## 5. What capture is good for, and what it is not

| Animation type | Capture fit | Notes |
|---|---|---|
| Emotes, dances, social gestures | Very good | Exactly what Animation Capture is built for ([[Emotes and Social Animation]]) |
| Idles and breathing | Good, after exaggeration | Loop cleanly; [[Idle Breathing and Secondary Motion]] |
| Locomotion | Fair | Needs foot locking and loop cleanup; speed must match movement speed |
| NPC ambient actions (sitting, sweeping) | Good | Low precision needed |
| Cutscene acting | Good as a base | Then hand polish |
| Melee combat | Reference only | Contact frames, weapon arcs and anticipation need deliberate design ([[Combat Animation Craft]], [[Weapon Swing Design]]) |
| Creatures and non-humans | Poor | Humans are not quadrupeds; see [[Animating Creatures and Monsters]] |

### Why combat resists capture

A combat animation is a game design object: its hit frame drives the server's damage timing, its anticipation is the player's telegraph, and its recovery is a balance number. A captured swing has human timing, which is too even and too soft. The reference project's server never played clips at all: it used marker times exported into data, with the server hit time set slightly before the marker (marker minus 0.06 s). That only works if markers are placed deliberately on designed frames, which captured motion does not give you.

---

## 6. How the reference project used AI for animation (without capture)

The reference project produced hundreds of combat clips with AI agents, but not by capture or by generative motion models. The approach:

1. **Specs, not curves.** Agents wrote each move as a list of key poses in a compact spec: time, hand target, blade direction, foot placements, root offset, easing, markers. A shared library of named poses (ready, overhead, chop, thrust, crouch) kept style consistent.
2. **A deterministic baker** solved the full body from those targets with inverse kinematics and wrote `KeyframeSequence`s.
3. **An offline arm re-solver** later re-solved every arm with exact two-bone IK, collision costs against the body and a smoothness search across the whole clip.
4. **Numeric QA**: dozens of metrics (arm in body, pops over a degrees-per-frame threshold, elbow flips, wrist limits, rest flashes, entry and exit distance from the idle) combined into a score, with hard "do not install" rules: a new critical or a lower score blocked installation.
5. **Engine check**: the real `Animator` stepped each test clip in Edit, and the result had to match the offline model within 3 degrees.

The AI agents designed moves and operated the tools; the tools themselves were readable code with measurable output. The details are in [[Spec-Driven Move Authoring]], [[Pipeline - Arm IK Baking and QA]] and [[Arm QA Metrics Reference]]. The lesson for anyone using AI motion: whatever generates the motion, a numeric QA step that can say no is what makes it shippable.

Publishing the final clips and play-testing stayed manual, done by the owner.

---

## Common mistakes

- Feet out of frame in the source video.
- Shipping captured clips without key reduction (hundreds of keys per second).
- Captured combat swings with no designed contact frame.
- Root travel left in an in-place clip.
- Testing only in Studio with temporary ids.
- Ignoring character scale when the game scales characters.

## Checklist

- [ ] Video: under 15 s, one person, full body, stable camera, neutral start and end.
- [ ] Cleanup: jitter filtered, feet locked, root handled, wrists unrolled.
- [ ] Keys reduced with an error bound; no segment over about 120 degrees; none at 180.
- [ ] Markers placed on designed frames.
- [ ] Tested on the real rig at game scale with a published id in a live server.

## See also
[[Animation Capture and Mocap]] · [[Animation Editor Workflow]] · [[Retargeting Animations Between Rigs]] · [[Emotes and Social Animation]] · [[Spec-Driven Move Authoring]] · [[Pipeline - Arm IK Baking and QA]] · [[Character and Creature Pipeline]] · [[AI in Roblox Development Overview]]

## Connected notes
<!-- auto-links:start -->
[[Animation Review Checklist]] · Animation Start Here · Authoring Clips in Code · Moon Animator and Third-Party Tools · Animation Glossary · Animation Editor Advanced
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Moon Animator and Third-Party Tools]] · [[Authoring Clips in Code]] · [[AI Pitfalls - Physics and Animation]] · [[AI 3D Model Generation Outside Roblox]] · [[Prompting and Verifying AI Output]] · [[AI Image Generation for Icons Thumbnails and Concepts]] · [[AI Agents and Autonomous Workflows]] · [[Roblox Built-In AI Tools Timeline 2023-2026]] · [[Roblox Studio Assistant]] · [[AI Pitfalls - Assets and Import]]
<!-- related:end -->
