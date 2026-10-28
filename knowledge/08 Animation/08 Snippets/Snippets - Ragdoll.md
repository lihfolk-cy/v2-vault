---
tags: [snippets, luau, ragdoll, physics, humanoid]
---
# Snippets: Ragdoll

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Changing a player character's Humanoid state from the server.
> - Avoid: Leaving the Animator playing locomotion during the ragdoll (limbs fight physics or the body slides).
> - Avoid: Editing the R15 rig attachments to set socket axes (create your own).
>
> Read more (20 KB note): ## 3. Server module · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

Turning an animated R15 character (or NPC) into a physics ragdoll and back: prebuilt ball-socket constraints with per-joint limits, disabling `Motor6D` **or** `AnimationConstraint` joints, the Humanoid state and ownership rules that decide where each step must run, carrying the animation's momentum into the fall, death ragdolls, getting up without a pop, and a note on physically driven ("active") ragdolls with `AnimationConstraint`.

Background: [[Ragdolls and Physics-Based Animation]], [[AnimationConstraint and Physically Simulated Characters]], [[Humanoid States and Animation]], [[Procedural Death Knockdown and Hit Reactions]].

---

## 1. Where each step has to run

| Step | Player character | Server-owned NPC |
|---|---|---|
| Build sockets, disable joints, collisions | server (replicates) | server |
| `Humanoid:ChangeState(Physics)` / `GettingUp` | **owning client** (the client simulates its character) | server |
| Stop or stand aside the animation tracks | owning client (it plays them) | whoever plays them |
| `Animator:ApplyJointVelocities` (carry momentum) | owning client (it simulates) | server |

Getting this table wrong is the usual reason a ragdoll "works for the owner but others see a T-pose", or "the server sees it but the player keeps walking". The Humanoid state machine of a player's character runs on that player's client, so a server-side `ChangeState` on a player character does not reliably stick.

---

## 2. Shared limits table

```lua
--!strict
-- ReplicatedStorage.RagdollLimits
-- axis: the limb's direction in the rest pose (the socket's cone is measured around it), in Part0 space.
-- cone: max swing in degrees. twist: min/max twist about the axis in degrees.
export type Limit = { axis: Vector3, cone: number, twistMin: number, twistMax: number }

return {
	Neck          = { axis = Vector3.yAxis,  cone = 35, twistMin = -45, twistMax = 45 },
	Waist         = { axis = Vector3.yAxis,  cone = 25, twistMin = -25, twistMax = 25 },
	LeftShoulder  = { axis = -Vector3.yAxis, cone = 85, twistMin = -60, twistMax = 60 },
	RightShoulder = { axis = -Vector3.yAxis, cone = 85, twistMin = -60, twistMax = 60 },
	LeftElbow     = { axis = -Vector3.yAxis, cone = 70, twistMin = -10, twistMax = 10 },
	RightElbow    = { axis = -Vector3.yAxis, cone = 70, twistMin = -10, twistMax = 10 },
	LeftWrist     = { axis = -Vector3.yAxis, cone = 40, twistMin = -20, twistMax = 20 },
	RightWrist    = { axis = -Vector3.yAxis, cone = 40, twistMin = -20, twistMax = 20 },
	LeftHip       = { axis = -Vector3.yAxis, cone = 60, twistMin = -30, twistMax = 30 },
	RightHip      = { axis = -Vector3.yAxis, cone = 60, twistMin = -30, twistMax = 30 },
	LeftKnee      = { axis = -Vector3.yAxis, cone = 70, twistMin = -5,  twistMax = 5 },
	RightKnee     = { axis = -Vector3.yAxis, cone = 70, twistMin = -5,  twistMax = 5 },
	LeftAnkle     = { axis = -Vector3.yAxis, cone = 30, twistMin = -10, twistMax = 10 },
	RightAnkle    = { axis = -Vector3.yAxis, cone = 30, twistMin = -10, twistMax = 10 },
} :: { [string]: Limit }
```
The angles are rules of thumb, tuned for "loose but not broken". Elbows and knees as ball sockets with small twist are a compromise: they can bend sideways within the cone. For anatomically correct hinges use `HingeConstraint` with limits on those four joints, and check the hinge direction on your rig (the bend sign depends on the attachment orientation).

---

## 3. Server module

```lua
--!strict
-- ServerScriptService.Ragdoll
local Limits = require(game.ReplicatedStorage.RagdollLimits)

local Ragdoll = {}

type Built = {
	joints: { Instance },          -- the animated joints we disable
	sockets: { BallSocketConstraint },
	collide: { [BasePart]: boolean }, -- original CanCollide per limb
}
local built: { [Model]: Built } = {}

local function framesOf(j: Instance): (BasePart?, BasePart?, Vector3, Vector3)
	-- joint pivot position in Part0 space and in Part1 space
	if j:IsA("Motor6D") then
		return j.Part0, j.Part1, j.C0.Position, j.C1.Position
	elseif j:IsA("AnimationConstraint") and j.Attachment0 and j.Attachment1 then
		local a0, a1 = j.Attachment0 :: Attachment, j.Attachment1 :: Attachment
		local p0, p1 = a0.Parent, a1.Parent
		if p0 and p0:IsA("BasePart") and p1 and p1:IsA("BasePart") then
			return p0, p1, a0.Position, a1.Position
		end
	end
	return nil, nil, Vector3.zero, Vector3.zero
end

local function perpendicular(v: Vector3): Vector3
	local p = v:Cross(Vector3.zAxis)
	if p.Magnitude < 1e-3 then p = v:Cross(Vector3.xAxis) end
	return p.Unit
end

-- Build once per character (sockets disabled). Toggling later is cheap.
function Ragdoll.build(character: Model)
	if built[character] then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.BreakJointsOnDeath = false   -- we ragdoll on death instead of letting the engine break joints
		humanoid.RequiresNeck = false         -- a disabled neck joint must not kill a knocked-down character
	end
	local b: Built = { joints = {}, sockets = {}, collide = {} }
	for _, j in character:GetDescendants() do
		local p0, p1, pos0, pos1 = framesOf(j)
		if not (p0 and p1) then continue end
		if j.Name == "Root" then continue end            -- keep HumanoidRootPart rigidly on LowerTorso
		local lim = Limits[j.Name]
		if not lim then continue end
		-- Our own attachments: never edit the rig attachments (Docs advise against changing RigAttachment CFrames).
		local a0 = Instance.new("Attachment")
		a0.Name = "RagdollA0_" .. j.Name
		a0.Position = pos0
		a0.Axis = lim.axis                                -- primary axis: the cone and twist are about this
		a0.SecondaryAxis = perpendicular(lim.axis)
		a0.Parent = p0
		local a1 = Instance.new("Attachment")
		a1.Name = "RagdollA1_" .. j.Name
		a1.Position = pos1
		a1.Axis = lim.axis                                -- same rest direction in Part1 space (R15 parts are aligned at rest)
		a1.SecondaryAxis = perpendicular(lim.axis)
		a1.Parent = p1

		local s = Instance.new("BallSocketConstraint")
		s.Name = "Ragdoll_" .. j.Name
		s.Attachment0, s.Attachment1 = a0, a1
		s.LimitsEnabled = true
		s.UpperAngle = lim.cone
		s.TwistLimitsEnabled = true
		s.TwistLowerAngle = lim.twistMin
		s.TwistUpperAngle = lim.twistMax
		s.Enabled = false
		s.Parent = p1

		-- adjacent parts touching at the joint would jitter against each other
		local nc = Instance.new("NoCollisionConstraint")
		nc.Part0, nc.Part1 = p0, p1
		nc.Parent = p1

		table.insert(b.joints, j)
		table.insert(b.sockets, s)
		b.collide[p1] = p1.CanCollide
	end
	built[character] = b
	character.Destroying:Once(function() built[character] = nil end)
end

function Ragdoll.set(character: Model, on: boolean)
	Ragdoll.build(character)
	local b = built[character]
	if not b then return end
	if (character:GetAttribute("Ragdoll") == true) == on then return end
	for _, s in b.sockets do s.Enabled = on end
	for _, j in b.joints do
		(j :: any).Enabled = not on                      -- Motor6D.Enabled / Constraint.Enabled
	end
	for part, original in b.collide do
		part.CanCollide = on or original                 -- limbs collide with the world while ragdolled
	end
	character:SetAttribute("Ragdoll", on)            -- owning client reacts (state + tracks + momentum)

	-- NPCs: the server owns the Humanoid, so it changes state itself
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and not game.Players:GetPlayerFromCharacter(character) then
		humanoid:ChangeState(on and Enum.HumanoidStateType.Physics or Enum.HumanoidStateType.GettingUp)
	end
end

return Ragdoll
```

Notes:
- **Prebuild.** Creating constraints at the moment of a hit costs a frame and replicates a burst of instances. Build on spawn, toggle `Enabled`.
- **Keep the Root joint.** Disabling it detaches the HumanoidRootPart from the body: the camera (which follows the root) and anything welded to it stay behind. Keeping it rigid makes LowerTorso and the root one piece, which is what most games want.
- **`Attachment.Axis` and `SecondaryAxis`** set the attachment's orientation (Docs: primary and secondary axes). The ball socket's cone and twist limits are measured about the primary axis, so it must point along the limb at rest.
- **Accessories** are welded to body parts and follow. Accessories that are separate physical assemblies (rare) need `Massless` and collisions off.

---

## 4. Owning client

```lua
--!strict
-- StarterCharacterScripts.RagdollClient (LocalScript)
local character = script.Parent :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local animator = humanoid:WaitForChild("Animator") :: Animator

local function onRagdollChanged()
	local on = character:GetAttribute("Ragdoll") == true
	if on then
		-- Stop our own tracks so they do not fight physics. If you use an animation controller with
		-- stand-aside flags, it already stands aside on the "Ragdoll" attribute and this is redundant.
		for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0.1) end
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)

		-- Carry the animation's motion into the fall (Docs: computes relative velocities for the given
		-- Motor6Ds and applies them to each Part1; joints must already be disabled, and joints whose parts
		-- are still one assembly are skipped).
		local motors = {}
		for _, d in character:GetDescendants() do
			if d:IsA("Motor6D") and not d.Enabled then table.insert(motors, d) end
		end
		if #motors > 0 then animator:ApplyJointVelocities(motors) end
	else
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

character:GetAttributeChangedSignal("Ragdoll"):Connect(onRagdollChanged)
if character:GetAttribute("Ragdoll") then onRagdollChanged() end
```

`ApplyJointVelocities` is documented for `Motor6D`s. Whether it does anything for `AnimationConstraint` joints is not documented (unverified); on those rigs, set the parts' `AssemblyLinearVelocity` from the root's velocity as a fallback so the body at least keeps its travel.

Use `Physics`, not `Enum.HumanoidStateType.Ragdoll`: the `Ragdoll` state is marked deprecated in the docs, and older tutorials that use it (often together with `FallingDown`) should be updated.

While in the `Physics` state, the Humanoid stops controlling the body: no walking, no auto-rotate, no getting up on its own. Make sure your input and animation controllers know (a stand-aside flag, see [[Snippets - Animation Controller Module]]).

---

## 5. Death ragdoll

```lua
-- Server: ragdoll on death instead of the default joint break.
local Ragdoll = require(game.ServerScriptService.Ragdoll)

local function setupCharacter(character: Model)
	Ragdoll.build(character)                          -- also sets BreakJointsOnDeath = false
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Once(function()
		Ragdoll.set(character, true)
	end)
end
```
For player characters, the client-side state change to `Physics` after death matters less (a dead Humanoid stays dead), but the momentum carry still needs the owner. If your game plays an authored death clip first (the reference project played a recoil, kneel and fall clip, with a fizzle-out at 1.55 s and the camera change at 2.45 s), ragdoll only at a marker near the end of the clip, or skip the ragdoll and ground-fit the clip instead ([[Ground Fitting Pipeline]]).

---

## 6. Getting up without a pop

Re-enabling the joints snaps every limb back to the animated pose in one frame. Ways to hide it, from simplest:
1. **Play a get-up clip that starts lying down.** Choose face-up or face-down by the UpperTorso's `LookVector.Y` at the moment of recovery, align the root to the body's position and heading on the ground, then re-enable joints and play the clip with fade 0. The snap now lands on a pose close to where the body already is.
2. **Fade from a captured pose.** Before re-enabling, read every limb's current CFrame relative to its parent, compute the matching `Transform`s, write them as a "pose snapshot" layer, and blend from the snapshot to the animation over 0.2 to 0.4 s in `PreSimulation` (an additive layer, see [[Snippets - Procedural Motion]]).
3. **Wait for rest.** Only allow recovery when the root's speed is under about 1 stud/s, so the body is not mid-tumble.

```lua
-- Choose a get-up clip by orientation (face-down if the chest faces the ground).
local function getUpClip(character: Model): string
	local chest = character:FindFirstChild("UpperTorso") :: BasePart
	return chest.CFrame.LookVector.Y < 0 and "GetUpFaceDown" or "GetUpFaceUp"
end
```

---

## 7. Active ragdolls with AnimationConstraint (physically driven animation)

`AnimationConstraint` (Docs) can be kinematic (the default: parts follow `Transform` exactly, like a Motor6D) or force-based: with `IsKinematic = false` it applies forces and torques, capped by `MaxForce` and `MaxTorque`, with stiffness `AngularStrength`/`LinearStrength` (normalised frequency, default 1) and damping `AngularDamping`/`LinearDamping` (1 = critical). That makes a body that tries to follow its animation but can be pushed, which is the basis of "active ragdoll" hit reactions.

```lua
-- Soften the upper body for 0.4 s after a heavy hit, then stiffen again (AnimationConstraint rigs only).
local function wobble(character: Model, duration: number)
	local joints = {}
	for _, name in { "Waist", "Neck", "LeftShoulder", "RightShoulder" } do
		local part = character:FindFirstChild(name == "Waist" and "UpperTorso" or name == "Neck" and "Head"
			or (name:gsub("Shoulder", "UpperArm")))
		local j = part and part:FindFirstChildWhichIsA("AnimationConstraint")
		if j then table.insert(joints, j) end
	end
	for _, j in joints do
		j.IsKinematic = false
		j.AngularStrength = 0.35          -- softer than default (1); values above 1 can be unstable (Docs)
		j.AngularDamping = 0.8
	end
	task.delay(duration, function()
		for _, j in joints do j.IsKinematic = true end
	end)
end
```
This has not been tested in production by the reference project (it baked everything), and the right `MaxTorque` depends on part masses; tune it on your rig. Docs also note a workspace setting (`ImprovedAnimationConstraint`) that changes how linear and angular strength and damping are separated. Remote characters may be throttled by engine animation LOD; on throttled frames the Animator reuses the previous pose.

---

## Common mistakes
- Changing a player character's Humanoid state from the server.
- Leaving the Animator playing locomotion during the ragdoll (limbs fight physics or the body slides).
- Editing the R15 rig attachments to set socket axes (create your own).
- Disabling the Root joint and losing the camera.
- `BreakJointsOnDeath` left true, so the engine deletes the joints you wanted to re-enable.
- `RequiresNeck` left true, so a knock-down ragdoll kills the character.
- Re-enabling joints with no get-up pose (one-frame snap).

## See also
[[Ragdolls and Physics-Based Animation]] · [[AnimationConstraint and Physically Simulated Characters]] · [[Humanoid States and Animation]] · [[Procedural Death Knockdown and Hit Reactions]] · [[Replication and Ownership]] · [[Snippets - Animation Controller Module]]

## Nuances and edge cases

1. **Ragdolls are physics assemblies, and physics scales badly.** One R15 ragdoll adds about 15 parts and 14 constraints to the simulation. Five at once is nothing; a 50-player battleground where a big ultimate knocks down 20 players adds about 300 active parts and constraints in one frame, plus their contacts with the map. Rule of thumb: cap simultaneous non-death ragdolls per server, shorten their duration under load, and despawn corpse ragdolls quickly.
2. **Ownership decides smoothness.** A player's ragdoll simulated by its owner looks smooth to them and slightly late to others. An NPC ragdoll owned by the server looks smooth to nobody on high ping, because positions arrive in bursts. For short knock-downs, letting the nearest client own the NPC is smoother; for anything that decides gameplay (where a body lands, whether it falls off a ledge), keep the server as owner and accept the visual cost.
3. **Exploit surface.** A client that owns its ragdoll owns its position. A knocked-down player can teleport while ragdolled, and the server sees a legal-looking physics state. Validate position on get-up against where the ragdoll could plausibly have gone (start position plus maximum launch distance).
4. **Momentum transfer and frame rate.** Reading limb velocities from the animation's last frame and applying them works at 60 FPS. At 20 FPS the sampled velocity is averaged over 50 ms and can overshoot on fast swings, launching limbs. Clamp per-limb launch speed (around 40 to 60 studs/s for limbs is a sane rule of thumb).
5. **Collision groups.** Ragdoll limbs colliding with the player's own other limbs jitter. Put limbs in a group that does not collide with itself but does collide with the world, and decide explicitly whether ragdolls collide with other players. Letting 20 ragdolls collide with each other is a common server-lag source.
6. **StreamingEnabled.** A ragdoll that falls out of a client's stream radius stops updating there; when it streams back in it can pop to its current pose. For cinematic deaths near the edge of streaming, it is acceptable; for get-up sequences, ensure the owner keeps the area streamed (the owner's own character always is).
7. **Layered clothing and accessories.** Accessories welded to limbs follow fine. Layered clothing cages deform with the body, but very large limb angles at joint limits can show clipping; tighter limits on shoulders and hips hide most of it.
8. **Console and TV.** Nothing platform specific in the physics, but the camera following a ragdolling head looks violent on a big screen. Follow the torso, not the head, and smooth the camera subject.

## Common mistakes in production

1. **Creating constraints at the moment of ragdoll.** Symptom: a hitch of several milliseconds when many players ragdoll together. Fix: prebuild disabled constraints on spawn, as the module does, and only toggle `Enabled`.
2. **Ragdolling on the server only.** Symptom: owner sees a delay of a full round trip, then a snap. Fix: server decides, owner client starts the ragdoll as soon as it is told, server mirrors.
3. **No despawn for corpse ragdolls.** Symptom: physics step time grows across a long round. Fix: anchor and fade bodies after 3 to 8 seconds, or replace with a static pose.
4. **Massless left at default.** Symptom: accessories with large handles swing the body around. Fix: set accessory handles `Massless = true` during the ragdoll.
5. **Get-up from a face-down pose with a face-up clip.** Symptom: the body flips. Fix: pick the get-up clip by the torso's up vector.
6. **Hit reactions firing on a ragdolled body.** Symptom: animation tracks start mid-fall and fight physics. Fix: the animation controller stands aside while a `Ragdolled` attribute is set.

## Related decisions

- [[Physics Assemblies and Constraints]]: what an assembly is and why ragdoll parts join or split them.
- [[Network Ownership]]: who simulates the ragdoll and what that means for smoothness and trust.
- [[Debugging Physics and Network Ownership]]: diagnosing stutter and snapping on ragdolls.
- [[Detecting Movement Exploits - Speed Fly Noclip Teleport]]: closing the teleport-while-ragdolled hole.
- [[Physics Performance]]: measuring the cost of many simultaneous ragdolls.
- [[Destruction and Fracture]]: sharing a physics budget between debris and bodies.
- [[Genre Playbook - Battlegrounds and Arena Fighters]]: the genre where knock-down ragdolls are core.
- [[Instance Streaming]]: what happens to ragdolls at the edge of the stream radius.
- [[Motion Sensitivity and Camera Comfort]]: keeping the death camera comfortable.

## Connected notes
<!-- auto-links:start -->
[[Animator Deep Dive]] · [[Accessories and Armor That Follow Animation]] · [[Rigs and Joints]] · [[Characters and Humanoids]] · [[Mover Constraints and Physics Controllers]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Animation Start Here]]
<!-- auto-links:end -->
