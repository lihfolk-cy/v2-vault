---
tags: [testing, qa, studio, tools, type/guide, area/animation, level/intermediate, api/Animator, area/studio, api/StepAnimations, api/KeyframeSequence, api/Animation]
---
# Testing Animations in Studio

<!-- tldr:start -->
> [!tldr] TL;DR
> - Clip stepped in Edit on a correctly scaled dummy with real joints (Motor6D and AnimationConstraint variants).
> - Lua models A/B'd against the Animator on originals, not stubs.
> - Filmstrip and marker contact sheet reviewed.
> - Static lint clean; dynamic QA within thresholds.
> - Two-client test with late join and simulated lag.
> - Published test place run for any clip or system that could use Studio-only ids.
>
> Cost: TL;DR ~140 tok · whole note ~4.6k tok. Read more: ## 3. Test dummies that actually animate · ## 6. Automated QA ideas · ## Checklist
<!-- tldr:end -->

Animation testing in Roblox is split between two worlds that behave differently. **Edit mode** has no physics and no animation step, but it is where tools can freeze time, step the real Animator frame by frame, and read exact joint values. **Play mode** has everything running, but you cannot single-step it and normal scripts cannot call the Animator's stepping API. A good test setup uses Edit for exact, repeatable measurement and Play (including multi-client tests) for behaviour, timing and replication.

This note covers both, plus the traps that made "Edit-verified" mean less than people thought in the reference project (one live action game).

---

## 1. What works where

| Capability | Edit (command bar / plugin) | Play solo | Local server + clients | Live server |
|---|---|---|---|---|
| `Animator:StepAnimations(dt)` | yes (plugin security, Docs) | command bar only | command bar only | no |
| Physics, `Transform` moving parts | no | yes | yes | yes |
| KSP-registered ids | yes | yes | yes | **no** |
| Published ids | yes | yes | yes | yes, if the owner matches |
| Replication to other clients | n/a | partial (one client) | yes | yes |
| Real network latency | no | no | simulated (Studio network settings) | yes |
| ViewportFrame animation advancing | no (measured) | yes | yes | yes |
| Frame-rate variation | n/a | your machine | your machine | every device |

Two consequences:
- **Play solo hides replication bugs.** Use Test, Clients and Servers with at least two clients for anything that another player should see.
- **Studio hides asset bugs.** KSP registration works in every Studio mode. Only a live server (or a published test place) proves your ids.

---

## 2. Stepping the real Animator in Edit

`Animator:StepAnimations(deltaTime)` advances every playing track on that Animator and applies the result to the model. Docs: plugin-level security (command bar and plugins only), intended for previews; after stopping you must reset the joints yourself.

Measured details:
- `dt` must be greater than 0 to advance. Whether `StepAnimations(0)` applies the current pose is unsettled (a project tool calls it, the measured rule says dt > 0; see [[Open Questions]]); step a tiny `1e-4` instead to apply the start pose.
- A freshly registered `KeyframeSequence` plays nothing until the track's `Length > 0`. Wait for it (with a timeout) before stepping, or the first run reports nonsense: one verify run showed `loaded false` with about 117 degrees of error for this reason. A just-baked clip sometimes needs to be loaded again before it steps.
- In Edit, `Transform` changes but parts do not move (no simulation). Read the `Transform` values, or compute part positions by forward kinematics.

A minimal stepping harness (command bar):

```lua
-- Play a KeyframeSequence on a rig in Edit and record every joint's Transform at 60 Hz.
-- rig: a Model with Humanoid or AnimationController + Animator, under Workspace.
local KSP = game:GetService("KeyframeSequenceProvider")

local function jointsOf(model: Model): { Instance }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then table.insert(out, d) end
	end
	return out
end

local function stepClip(rig: Model, ks: KeyframeSequence, hz: number?)
	local animator = rig:FindFirstChildWhichIsA("Animator", true) :: Animator
	assert(animator, "no Animator")
	local anim = Instance.new("Animation")
	anim.AnimationId = KSP:RegisterKeyframeSequence(ks)       -- Studio-only id: fine for testing
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = false

	local t0 = os.clock()
	while track.Length <= 0 and os.clock() - t0 < 2 do task.wait() end
	if track.Length <= 0 then warn("clip did not load"); return nil end

	local joints = jointsOf(rig)
	local dt = 1 / (hz or 60)
	local frames = {}
	track:Play(0)                    -- no fade: we want the clip's own poses
	animator:StepAnimations(1e-4)    -- apply the start pose (a zero step is not guaranteed to apply it)
	local n = math.ceil(track.Length / dt)
	for i = 0, n do
		local pose = {}
		for _, j in joints do pose[(j :: any).Part1.Name] = (j :: any).Transform end
		frames[i + 1] = { t = i * dt, pose = pose }
		animator:StepAnimations(dt)
	end

	-- clean up: stop, flush, and put every joint back to rest
	track:Stop(0)
	animator:StepAnimations(dt)
	track:Destroy()
	for _, j in joints do (j :: any).Transform = CFrame.identity end
	return frames, track.Length
end
```

Keep each command-bar call short. The reference project's rule was every Studio call under 1.5 s, with long jobs split into slices that return "stopped early at index i" and resume. A long synchronous loop freezes Studio and, with several tools sharing one Studio, can stall everything.

---

## 3. Test dummies that actually animate

### The Edit-mode rig trap
Measured: `Players:CreateHumanoidModelFromDescriptionAsync` in Edit returns a rig **without Motor6Ds**, and `Humanoid:BuildRigFromAttachments` on it fails quietly. The rig looks right and nothing animates.

Build the R15 joints yourself from the `*RigAttachment` pairs:

```lua
-- R15 joint table: joint name, Part0, Part1, rig attachment name (present on both parts)
local R15 = {
	{ "Root",          "HumanoidRootPart", "LowerTorso",    "RootRigAttachment" },
	{ "Waist",         "LowerTorso",       "UpperTorso",    "WaistRigAttachment" },
	{ "Neck",          "UpperTorso",       "Head",          "NeckRigAttachment" },
	{ "LeftShoulder",  "UpperTorso",       "LeftUpperArm",  "LeftShoulderRigAttachment" },
	{ "LeftElbow",     "LeftUpperArm",     "LeftLowerArm",  "LeftElbowRigAttachment" },
	{ "LeftWrist",     "LeftLowerArm",     "LeftHand",      "LeftWristRigAttachment" },
	{ "RightShoulder", "UpperTorso",       "RightUpperArm", "RightShoulderRigAttachment" },
	{ "RightElbow",    "RightUpperArm",    "RightLowerArm", "RightElbowRigAttachment" },
	{ "RightWrist",    "RightLowerArm",    "RightHand",     "RightWristRigAttachment" },
	{ "LeftHip",       "LowerTorso",       "LeftUpperLeg",  "LeftHipRigAttachment" },
	{ "LeftKnee",      "LeftUpperLeg",     "LeftLowerLeg",  "LeftKneeRigAttachment" },
	{ "LeftAnkle",     "LeftLowerLeg",     "LeftFoot",      "LeftAnkleRigAttachment" },
	{ "RightHip",      "LowerTorso",       "RightUpperLeg", "RightHipRigAttachment" },
	{ "RightKnee",     "RightUpperLeg",    "RightLowerLeg", "RightKneeRigAttachment" },
	{ "RightAnkle",    "RightLowerLeg",    "RightFoot",     "RightAnkleRigAttachment" },
}

local function buildR15Joints(rig: Model)
	for _, row in R15 do
		local name, p0n, p1n, attName = row[1], row[2], row[3], row[4]
		local p0 = rig:FindFirstChild(p0n) :: BasePart?
		local p1 = rig:FindFirstChild(p1n) :: BasePart?
		if not (p0 and p1) then continue end
		if p1:FindFirstChild(name) then continue end            -- already jointed
		local a0 = p0:FindFirstChild(attName) :: Attachment?
		local a1 = p1:FindFirstChild(attName) :: Attachment?
		if not (a0 and a1) then warn("missing", attName); continue end
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0, m.Part1 = p0, p1
		m.C0, m.C1 = a0.CFrame, a1.CFrame                      -- joint pivot as seen from each part
		m.Parent = p1                                          -- R15 convention: the joint lives in Part1
	end
end
```

Also remember:
- **Production characters may use `AnimationConstraint` joints**, not Motor6D (Docs: the default for R15 when the avatar joint upgrade is on). Test on both, and make every tool accept both.
- **Scale your dummy like the game.** The reference project's characters were 1.6x via body scales (about 9 studs tall). A dummy at scale 1 hides "feet hover" bugs that come from unscaled root offsets. And a dummy scaled with `Model:ScaleTo` behaves differently again (the Animator multiplies translations by `GetScale()`). See [[Scale and Animation]].
- **QA dummies are blocky.** Arm-clearance QA on a blocky R15 dummy is pessimistic: slimmer avatars clear the body more easily than scores suggest.

---

## 4. A/B: the real Animator against a Lua model

If you have a Lua sampler that claims to reproduce the Animator (a keyframe player, a QA model, an offline baker), prove it by stepping both and diffing:

```lua
-- angle between two rotations, in degrees (ignores translation)
local function angDeg(a: CFrame, b: CFrame): number
	local _, ang = (a:Inverse() * b):ToAxisAngle()
	ang = math.abs(ang)
	if ang > math.pi then ang = 2 * math.pi - ang end
	return math.deg(ang)
end

-- frames: from stepClip above. sampleLua(name, t) -> CFrame from your own sampler.
local function compare(frames, sampleLua: (string, number) -> CFrame?)
	local worst, worstAt = 0, ""
	for _, f in frames do
		for joint, cf in f.pose do
			local mine = sampleLua(joint, f.t)
			if mine then
				local d = angDeg(cf, mine)
				if d > worst then worst, worstAt = d, ("%s @ %.3f"):format(joint, f.t) end
			end
		end
	end
	print(("max diff %.3f deg at %s"):format(worst, worstAt))
end
```

Acceptance levels used in the reference project:
- A Lua keyframe player: at most 0.084 degrees on 10 R15 clips; 0.056 degrees and 0.002 studs on 60 enemy clips; 0.04 degrees on a five-track blend; 319 of 319 markers on time.
- An offline baker's model against the Animator: under 3 degrees on arm joints (up to about 5 on near-180 segments, which you inspect by eye).
- The only real failures were exact 180-degree keys, where the Animator itself flips direction unpredictably.

Gotchas:
- **Stubs cannot be A/B'd.** If clips are stored as stubs (Poses removed, data in an attribute), the real Animator has nothing to play. Restore the originals first.
- **Fresh registrations.** See section 2.
- **Fades and priorities.** Play both with fade 0 and the same priority, or you are comparing the mixers too.
- **Float32 time.** The Animator keeps track time in float32 (measured). A float64 mirror ends a clip a frame later at some lengths.

---

## 5. Filmstrips

A filmstrip is a sequence of poses at fixed times laid out side by side (or overlaid as ghosts) and captured as one image. It is the most useful single artefact for reviewing a clip and for bug reports, because it turns motion into something you can point at.

How the reference project made them in Edit:
1. Sample the clip at times `0, dt, 2*dt, ...` (dt 0.05 to 0.1 s), either by stepping the Animator (section 2) or with a Lua sampler straight from the `KeyframeSequence`.
2. Run forward kinematics to get every part's world CFrame: `Part1 = Part0 * C0 * Transform * C1:Inverse()` (for `AnimationConstraint`, use `Attachment0.CFrame` and `Attachment1.CFrame`).
3. Clone each part as an anchored, non-colliding copy at that CFrame, shifted sideways per frame (for example 5 studs per frame on a 9-stud character), with the held weapon attached at the grip.
4. Point a camera at the strip and capture. Restore `Camera.CameraType` to `Custom` afterwards (positioned captures can leave it `Scriptable`).

Capture gotchas (measured): Edit-mode captures can come back black when Studio is not the focused window; particle `Rate` emission does not show in Edit captures (use `:Emit()` bursts).

Variants worth building:
- **Ghost overlay**: all frames in place, transparency increasing with age. Shows arcs and spacing.
- **Contact sheet**: one frame per marker (`Hit`, `TrailOn`), labelled. Shows whether the hit frame really is the impact pose.
- **Path trace**: a small part at the blade tip and grip for every 1/60 s. Shows corners and snaps in the hand path.

FK and sampling code: [[Snippets - Building and Sampling Clips]].

---

## 6. Automated QA ideas

### Static checks (no playback needed)
Run these over every clip folder before publishing:

```lua
-- Static lint for a KeyframeSequence. Returns a list of problems.
local function lintKS(ks: KeyframeSequence, rigPartNames: { [string]: boolean }): { string }
	local problems = {}
	local function add(s: string) table.insert(problems, ks.Name .. ": " .. s) end
	local kfs = ks:GetKeyframes()
	table.sort(kfs, function(a, b) return a.Time < b.Time end)
	if #kfs < 2 then add("fewer than 2 keyframes") end

	local last: { [string]: CFrame } = {}
	for _, kf in kfs do
		for _, d in kf:GetDescendants() do
			if not d:IsA("Pose") then continue end
			local p = d :: Pose
			if p.Parent == kf then
				-- top-level pose: the rig root. The Animator never applies it (measured).
				local _, rootAng = p.CFrame:ToAxisAngle()
				if p.Weight > 0 and (p.CFrame.Position.Magnitude > 1e-4 or math.abs(rootAng) > 1e-4) then
					add(("t=%.3f root pose %s is keyed but never applied"):format(kf.Time, p.Name))
				end
				continue
			end
			if p.Weight <= 0 then continue end
			if not rigPartNames[p.Name] then add(("t=%.3f pose %s has no matching part"):format(kf.Time, p.Name)) end
			if p.EasingStyle == Enum.PoseEasingStyle.Cubic then add(("t=%.3f %s uses legacy Cubic (runs reversed)"):format(kf.Time, p.Name)) end
			if p.Name:find("Arm") or p.Name:find("Hand") then
				if p.CFrame.Position.Magnitude > 0.05 then add(("t=%.3f %s translates %.2f studs"):format(kf.Time, p.Name, p.CFrame.Position.Magnitude)) end
			end
			local prev = last[p.Name]
			if prev then
				local _, ang = (prev:Inverse() * p.CFrame):ToAxisAngle()
				ang = math.deg(math.abs(ang))
				if math.abs(ang - 180) < 0.01 then add(("t=%.3f %s exact 180 deg segment"):format(kf.Time, p.Name))
				elseif ang > 120 then add(("t=%.3f %s %.0f deg segment (>120)"):format(kf.Time, p.Name, ang)) end
			end
			last[p.Name] = p.CFrame
		end
	end
	return problems
end
```

Plus folder-level checks:
- Instance count per kit folder against the budget (2,500 in the reference project).
- No child named like something the code looks up (`Attack`, `Origin`, `FX`, `LocalCast`, `Moves` were reserved there).
- Attack clips carry the markers gameplay needs (`Hit`, `TrailOn`, `TrailOff`), and their times match the data table the server uses.
- No `RegisterKeyframeSequence` anywhere in runtime scripts (search every Source).
- Every `<Clip>Id` attribute is either empty or a well-formed `rbxassetid://` string.

### Dynamic checks (sampled at 60 Hz)
From the reference project's arm QA (full table in [[Arm QA Metrics Reference]]):
- **Entry/exit**: first frame within 90 degrees of the idle, last within 75.
- **Pops**: a one-frame turn of 30 degrees or more that is also 3 times the frames around it; any arm joint over 50 degrees in one frame is critical.
- **Rest flash**: both arm joints passing within 8 degrees of rest between poses at least 40 degrees from it, within 0.2 s.
- **Joint speed limits** (deg/s): LowerTorso 1500, UpperTorso 1100, Head 1000, UpperArm 2400, LowerArm 2600, Hand 2200.
- **Floor clearance**: lowest foot point per frame; flag below about -0.1 studs except in deliberate kneels.
- **Dead hold**: every joint under about 4 deg/s for more than 0.3 s, except at the end.
- **Penetration**: limb capsules into torso and head boxes.

Score clips and keep the history. A pass that makes the score worse on any clip gets rolled back.

---

## 7. Play-mode testing protocol

1. **Play solo** for feel: timing, readability, input response. Test at a capped low frame rate once (30 fps) and once high (144+), because frame-rate-dependent smoothing shows up only at the extremes.
2. **Local server with two clients** for anything visible to others: your character seen from the other client, NPCs, late joining (start the second client mid-fight), weapon and flourish relays.
3. **Network simulation**: turn on incoming replication lag in Studio's network settings and repeat step 2.
4. **Published test place** for asset ownership and anything that used Studio-only paths. This is the only Studio-independent proof that ids load.
5. **Devices**: one low-end phone. LOD and particle budgets behave differently there.

Write down what each test covered. In the reference project, a long stretch of work was "Edit-verified" (stepped Animator and maths checks) but never play-tested; live blending and replication were the unverified part. Label results honestly: "verified on the model (Animator check pending)" is a valid status, and "verified" is not the same thing.

---

## 8. Stale modules in Studio tools

Measured: `require()` from the command bar or a plugin can return a cached copy of a module you just edited. Tools that read shared modules (config, kit definitions, the Lua player) should clone the ModuleScript beside the original, require the clone, then destroy it. Do not require a destroyed clone that calls `WaitForChild` on its children; it hangs. Before saving a script, the reference project compiled it with `loadstring` and ran a use-before-definition scan.

---

## Checklist
- [ ] Clip stepped in Edit on a correctly scaled dummy with real joints (Motor6D and [[AnimationConstraint]] variants).
- [ ] Lua models A/B'd against the Animator on originals, not stubs.
- [ ] Filmstrip and marker contact sheet reviewed.
- [ ] Static lint clean; dynamic QA within thresholds.
- [ ] Two-client test with late join and simulated lag.
- [ ] Published test place run for any clip or system that could use Studio-only ids.
- [ ] Results labelled with how they were verified.

## See also
[[Debugging Animation Problems]] · [[Troubleshooting Table]] · [[Arm QA Metrics Reference]] · [[Pipeline - Arm IK Baking and QA]] · [[Studio Tooling Architecture]] · [[Snippets - Building and Sampling Clips]] · [[Animation Review Checklist]]

## Connected notes
<!-- auto-links:start -->
[[Engine Gotchas]] · [[Snippets - Lua Keyframe Player Core]] · [[Authoring Clips in Code]] · [[Lua Keyframe Player]] · [[AI Animation and Motion from Video]] · Testing Strategies and Frameworks · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[How the Animator Really Behaves]] · [[Animator Deep Dive]] · [[Animation Editor Workflow]] · [[Animation Glossary]] · [[Animation Data from Blender to Roblox]] · [[Case Study - Abilities That Only Worked in Studio]] · [[Rigs and Joints]] · [[Weapon Rig Player]]
<!-- related:end -->
