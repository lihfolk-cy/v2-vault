---
tags: [procedural, ragdoll, physics, humanoid, ballsocketconstraint, animationconstraint, network-ownership]
---
# Ragdolls and Physics-Based Animation

A ragdoll hands a character's body from the Animator to the physics engine: joints stop following clips and become limited sockets, and gravity and collisions do the animating. Done well it gives deaths, knockdowns and explosions that never repeat. Done badly it gives bodies that explode, jitter, sink through floors, kill living players, or look completely different on every client. This note covers the Humanoid side, building the constraints, network ownership, physically simulated `AnimationConstraint` joints, getting back up, and when not to ragdoll at all.

## The Humanoid gets a vote

A Humanoid actively stands its character up. Ragdolling without telling it means your limp body is being pushed upright every physics step.

| Member | Default | What it does (official docs) | Ragdoll relevance |
|---|---|---|---|
| `BreakJointsOnDeath` | `true` | whether the joints break in the `Dead` state | set `false` *before* death if you want to build a ragdoll from the death pose; otherwise the body falls apart into loose parts |
| `RequiresNeck` | `true` | a player character dies if the Neck joint is removed or disconnected, even briefly | **disabling the neck to ragdoll a living player kills them** unless this is `false` |
| `ChangeState(state)` | | forces a state. For a player character it must be called by a LocalScript on the client that owns the character (or the server if it owns it) | call ragdoll state changes on the owner |
| `SetStateEnabled(state, enabled)` | | whether a state can be entered at all; does not replicate between server and client | set it where the Humanoid is simulated (the owner) |
| `EvaluateStateMachine` | | `false` stops the Humanoid's internal physics and state logic (no forces, no sensors, no automatic transitions); state events still fire | the cleanest "Humanoid, stand down" switch |
| `PlatformStand` | | free-fall, cannot move; jumping does not end it | a lighter alternative to the Physics state |

The relevant states (`Enum.HumanoidStateType`, from the docs):

| State | Entered | Leaves | Use |
|---|---|---|---|
| `Physics` | only via `ChangeState` | only when you change it | ragdolls you fully control |
| `FallingDown` | automatically when tripped, or via `ChangeState` | tries to get up after a short delay | a brief knockdown the Humanoid recovers from itself |
| `Ragdoll` | only via `ChangeState`; **the docs mark it deprecated** | must be unset manually | avoid in new code; use `Physics` |
| `GettingUp` | after FallingDown or Ragdoll | to running / standing | the recovery |
| `Dead` | on death, or `ChangeState` (owner only) | never | `BreakJointsOnDeath` acts here |

The reference project (one live action game) did not ragdoll at all, and its notes show why that can be the right call: its locomotion system handed `Ragdoll`, `PlatformStanding`, `Climbing`, `Swimming` and `Seated` back to the default Animate script, and its death flow ended with a watchdog that, for the first 4 s after respawn, unanchored the root, cleared `PlatformStand` and `Sit`, and forced any character still in `Physics`, `Ragdoll` or `FallingDown` into `GettingUp`, because "players get stuck on respawn". Ragdoll state left behind by a race is a classic stuck-player bug.

## Building a ragdoll

For each joint you want to go limp (all except the root, usually):

1. Create a `BallSocketConstraint` (or a `HingeConstraint` for elbows and knees) between two attachments at the joint pivot.
2. Disable the kinematic joint: `Motor6D.Enabled = false`, or `AnimationConstraint.Enabled = false` (see the physically simulated option below for an alternative).
3. Make the limbs collide with the world, but not with their neighbours.

### Limit axes

`BallSocketConstraint` properties (docs): `LimitsEnabled`, `UpperAngle` (max tilt from `Attachment0`), `TwistLimitsEnabled`, `TwistLowerAngle`, `TwistUpperAngle` (twist measured between the two attachments' Y axes), `MaxFrictionTorque` (resists rotation: stiff, slow-flopping joints), `Restitution` (bounce at the cone edge, 0-1). The official IK guide sets up its wrist cone with `Attachment0`'s primary axis pointing toward the fingertips, which is the convention to follow: the guide's setup implies the cone is centred on `Attachment0`'s primary (X) axis (the class reference itself only says the tilt is measured from `Attachment0`; check with the constraint visualiser).

R15 rig attachments are not oriented that way (their axes follow the parts, not the bones), so a ragdoll built straight on the `*RigAttachment`s gets cones pointing sideways. Create dedicated attachments whose X axis runs along the child bone **in the rest pose**, so the limits are centred on rest regardless of the pose the body was in when it went limp.

### Suggested limits (rule of thumb)

| Joint | Type | Cone (`UpperAngle`) | Twist | Notes |
|---|---|---|---|---|
| Neck | ball | 30-40 | +-30 | tighter reads as "unconscious", looser as "broken" |
| Waist | ball | 20-30 | +-20 | |
| Shoulder | ball | 70-90 | +-45 | |
| Elbow | hinge or tight ball | hinge 0..135 | small | a ball elbow bends sideways |
| Wrist | ball | 30-45 | +-20 | the IK guide uses 80 for a living wrist |
| Hip | ball | 50-70 | +-30 | |
| Knee | hinge | 0..135 (backward only) | small | check the sign on your rig |
| Ankle | ball | 20-30 | +-15 | |

Raise `MaxFrictionTorque` a little to stop limbs swinging forever, and keep `Restitution` near 0 unless you want cartoon bounce.

### Code

```lua
--!strict
-- R15 ragdoll for Motor6D or AnimationConstraint rigs. Build once on spawn (rest-centred limits),
-- toggle at runtime on the machine that owns the character.
local Ragdoll = {}

local function jointFrames(j: Instance): (CFrame, CFrame)
	if j:IsA("Motor6D") then return j.C0, j.C1 end
	local c = j :: AnimationConstraint
	return c.Attachment0.CFrame, c.Attachment1.CFrame
end

-- limits in degrees: [Part1 name] = { cone, twist }
local LIMITS = {
	Head = { 35, 30 }, UpperTorso = { 25, 20 },
	LeftUpperArm = { 80, 45 }, RightUpperArm = { 80, 45 }, LeftLowerArm = { 10, 5 }, RightLowerArm = { 10, 5 },
	LeftHand = { 40, 20 }, RightHand = { 40, 20 },
	LeftUpperLeg = { 60, 30 }, RightUpperLeg = { 60, 30 }, LeftLowerLeg = { 10, 5 }, RightLowerLeg = { 10, 5 },
	LeftFoot = { 25, 15 }, RightFoot = { 25, 15 },
}

function Ragdoll.build(char: Model)
	for _, j in char:GetDescendants() do
		if not (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then continue end
		local jj = j :: any
		local p0, p1 = jj.Part0 :: BasePart, jj.Part1 :: BasePart
		local lim = p1 and LIMITS[p1.Name]
		if not (p0 and lim) then continue end                  -- skips the Root joint and props
		local c0, c1 = jointFrames(j)
		-- the rest pose (Transform = identity): pivot and the child's rest CFrame
		local pivot = p0.CFrame * c0
		local childRest = pivot * c1:Inverse()
		local x = childRest.Position - pivot.Position          -- along the bone at rest
		if x.Magnitude < 1e-3 then x = -pivot.UpVector end
		x = x.Unit
		local up = if math.abs(x:Dot(pivot.UpVector)) < 0.9 then pivot.UpVector else pivot.LookVector
		local y = (up - x * up:Dot(x)).Unit
		local socketWorld = CFrame.fromMatrix(pivot.Position, x, y)   -- X = cone axis, Y = twist reference
		local a0 = Instance.new("Attachment")
		a0.Name = "RagA0_" .. p1.Name
		a0.CFrame = p0.CFrame:ToObjectSpace(socketWorld)
		a0.Parent = p0
		local a1 = Instance.new("Attachment")
		a1.Name = "RagA1_" .. p1.Name
		a1.CFrame = childRest:ToObjectSpace(socketWorld)       -- coincides with a0 at rest
		a1.Parent = p1
		local bs = Instance.new("BallSocketConstraint")
		bs.Name = "RagSocket"
		bs.Attachment0, bs.Attachment1 = a0, a1
		bs.LimitsEnabled = true
		bs.UpperAngle = lim[1]
		bs.TwistLimitsEnabled = true
		bs.TwistLowerAngle, bs.TwistUpperAngle = -lim[2], lim[2]
		bs.MaxFrictionTorque = 5                               -- tune per scale
		bs.Enabled = false
		bs.Parent = p1
		jj:SetAttribute("RagJoint", true)
	end
end

-- Call on the owner of the character (the player's client, or the server for NPCs).
function Ragdoll.set(char: Model, on: boolean)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		if on then hum.RequiresNeck = false end               -- or the neck joint kills a living player
		hum:ChangeState(if on then Enum.HumanoidStateType.Physics else Enum.HumanoidStateType.GettingUp)
	end
	for _, d in char:GetDescendants() do
		if d:GetAttribute("RagJoint") then
			(d :: any).Enabled = not on
		elseif d:IsA("BallSocketConstraint") and d.Name == "RagSocket" then
			d.Enabled = on
		elseif d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.CanCollide = on                                 -- see the collision notes below
		end
	end
end

return Ragdoll
```

The root joint (HumanoidRootPart to LowerTorso) is left enabled in this version, so the root part rides along with the pelvis as one rigid body and the camera keeps following. Set the root part's `CanCollide` to false while ragdolled so it does not prop the body up.

`hum.RequiresNeck = false` should be restored after recovery if your game relies on neck-removal deaths. Set `hum.BreakJointsOnDeath = false` on spawn if death should ragdoll instead of shattering.

### Collisions

- Limbs must collide with the world or they sink through floors. The Humanoid normally manages limb collision itself, so set `CanCollide` explicitly while ragdolled and restore afterwards.
- Adjacent parts overlap at the joints. Colliding with each other there makes the body jitter or explode. Use `NoCollisionConstraint`s between neighbours (created once, with `build`), or put ragdoll limbs in a collision group that does not collide with itself.
- Thin, fast limbs tunnel through thin floors. Thicker floors, or invisible collision slabs under arenas, are cheaper than fighting it.

## Network ownership

Physics runs on whichever machine owns an assembly.

| Body | Default owner | Effect | Option |
|---|---|---|---|
| A player's character | that player's client | smooth for them; others see replicated positions (interpolated, slightly delayed) | ragdoll state changes must happen on that client (`ChangeState` requires ownership) |
| An unanchored NPC | automatic: the server, or a nearby player | ownership can switch mid-fall: the body hitches | `part:SetNetworkOwner(nil)` on the server pins it to the server; `SetNetworkOwnershipAuto()` returns it to automatic. Ownership cannot be set on anchored parts |
| A local visual corpse | the client that created it | perfectly smooth, zero network cost, but every client sees a different fall | fine for cosmetic deaths |

A popular pattern for deaths: on each client, clone the character's visible parts into a local ragdoll and hide the original. Bodies then differ between players, which almost never matters for a corpse, and nothing replicates.

## Physically simulated joints: `AnimationConstraint` with `IsKinematic = false`

The Avatar Joint Upgrade made R15 joints `AnimationConstraint`s. Per the docs, with `IsKinematic = true` (default) they behave like `Motor6D`; with `IsKinematic = false` the parts follow the `Transform` target **with forces and torques** instead of exactly:

| Property | Meaning (docs) |
|---|---|
| `MaxForce`, `MaxTorque` | caps on the force and torque used to reach the target |
| `AngularStrength`, `LinearStrength` | stiffness as `f / 60`, `f` the target frequency in Hz (default 1 = 60 Hz); 0 applies none |
| `AngularDamping`, `LinearDamping` | damping ratio (1 = critical, 0 = none) |

This is the door to **active ragdolls**: the Animator keeps writing the clip into `Transform`, and the body tries to follow it with limited strength. Low `MaxTorque` on the arms gives arms that are knocked aside by hits and return; zero strength gives a limp joint without disabling anything. Because the docs only describe the properties, tune by testing; physically simulated characters are new enough that their interaction with Humanoid states and replication is worth verifying in a live server before you build a system on it. See [[AnimationConstraint and Physically Simulated Characters]].

## Getting back up

The hard part of ragdolls is the end. A body lying in an arbitrary pose must become a standing character playing clips, without a pop.

1. **Wait for it to settle.** For example, the pelvis speed under 2 studs/s for 0.3 s (rule of thumb), or a time cap.
2. **Face up or face down?** Read the torso: `lowerTorso.CFrame.LookVector.Y < 0` means the chest faces the ground. Pick the matching get-up clip.
3. **Move the root without moving the body.** Choose the new root CFrame: on the ground under the pelvis at standing height, yawed along the body (the horizontal direction from the pelvis to the head is a good choice for clips authored lying head-forward). In the same frame, set the root joint's `Transform` so the pelvis stays exactly where it lies:

```lua
-- Keep Part1 where it is while moving Part0: solve the joint formula for Transform.
local function holdInPlace(joint: Instance, newPart0CF: CFrame, part1CF: CFrame): CFrame
	local c0, c1 = jointFrames(joint)
	return (newPart0CF * c0):Inverse() * part1CF * c1
end
```

4. **Capture the lying pose of every joint** as Transforms, with the same formula using each joint's current `Part0` and `Part1` CFrames.
5. **Re-enable the kinematic joints, start the get-up clip, and blend** from the captured Transforms to the clip over 0.2-0.3 s in `PreSimulation`: `joint.Transform = captured:Lerp(joint.Transform, alpha)`, with `alpha` eased from 0 to 1. The root joint's captured Transform carries the body's tilt, so the same blend rotates the body upright as the clip begins.
6. **Hand back to the Humanoid** (`GettingUp`, restore `RequiresNeck`, restore collisions) once the blend finishes.

Author get-up clips whose first frame is a plausible lying pose (on the back, on the front), so the blend distance is short. If the captured pose is far from both, a longer blend (0.4 s) with a little upward root motion hides it.

## When not to ragdoll

| Need | Better tool | Why |
|---|---|---|
| A readable, consistent death everyone sees the same | authored death clip + ground clamp | ragdolls are non-deterministic and network-dependent |
| A short stagger | spring hit reaction | no state changes, no ownership issues |
| A "pulled into an ultimate" sequence | procedural motion families | the reference project's caught motion: deterministic, timed to the cinematic's climax |
| A cheap fallback death | anchored topple | one CFrame tween, no physics |

The reference project used exactly these: a death clip (hit recoil, kneel, fall onto the back, hold), a fizzle-out at 1.55 s, and an anchored side-topple as the fallback; enemies used their own death clips with a runtime ground clamp. See [[Procedural Death Knockdown and Hit Reactions]].

## Testing

- **Edit mode has no physics.** Ragdolls can only be tested in Play or Run.
- Test with a second client: ownership and replication bugs only show to *other* players.
- Test on slopes, stairs, against walls and on moving platforms.
- Test death during a ragdoll, respawn during a ragdoll, and leaving the game during a ragdoll.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Living player dies the instant the ragdoll starts | neck joint disabled with `RequiresNeck = true` | set it false first |
| Body falls apart into loose parts on death | `BreakJointsOnDeath = true` | set false before death and build sockets |
| Ragdoll stands back up or slides around | Humanoid still in a normal state | `Physics` state on the owner, or `EvaluateStateMachine = false` |
| `ChangeState` does nothing | called on the server for a client-owned character | call it on the owning client |
| Body jitters and explodes | neighbouring limbs colliding at the joints | `NoCollisionConstraint`s or a collision group |
| Limbs bend sideways at elbows and knees | ball sockets with wide cones | hinges with limits |
| Cones point the wrong way | built on R15 rig attachments | dedicated attachments with X along the bone at rest |
| NPC corpse hitches mid-fall | network ownership switching | pin ownership with `SetNetworkOwner(nil)` |
| Players stuck after respawn | state or anchoring left behind | a watchdog that restores everything for the first seconds |
| Get-up pops | joints re-enabled straight into the clip | capture and blend Transforms; move the root with `holdInPlace` |

Related: [[Humanoid States and Animation]], [[AnimationConstraint and Physically Simulated Characters]], [[Procedural Death Knockdown and Hit Reactions]], [[Replication and Ownership]], [[Snippets - Ragdoll]].

## Connected notes
<!-- auto-links:start -->
[[Characters and Humanoids]] · [[IKControl Reference]] · [[Foot Placement and Ground IK]] · [[Debugging Physics and Network Ownership]] · [[Physics Assemblies and Constraints]] · [[Mover Constraints and Physics Controllers]] · [[Animation Start Here]]
<!-- auto-links:end -->
