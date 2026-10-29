---
tags: [fundamentals, animationconstraint, physics, ragdoll, avatar-joint-upgrade, type/guide, area/animation, level/beginner, api/AnimationConstraint, area/physics, api/Motor6D, api/Part0]
---
# AnimationConstraint and Physically Simulated Characters

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Testing only in a baseplate with an old dummy.
> - Avoid: Leaving `IsKinematic = false` after a get-up.
> - Avoid: Ramping `MaxTorque` on the server for a player's character.
> - Every joint lookup accepts AnimationConstraint and Motor6D.
> - No per-frame C0 writes on characters; procedural layers write `Transform` in `PreSimulation` and skip throttled frames.
> - No server-side pose writes; inputs replicate, clients compute.
>
> Cost: TL;DR ~150 tok · whole note ~4.0k tok. Read more: ## What breaks in old code · ## Nuances and edge cases · ## Checklist for a codebase · ## Common mistakes in production
<!-- tldr:end -->

`AnimationConstraint` is the joint that replaces `Motor6D` on R15 player characters under the **Avatar Joint Upgrade** (AJU). In its default kinematic mode it behaves like a Motor6D: the Animator writes `Transform` and the child part follows exactly. In simulated mode it pulls the child toward the animated pose with bounded forces, which is what makes physics-blended characters and ragdolls possible without swapping joints. This note covers the class, the rollout timeline, what breaks in old code, how to migrate, and how to use simulation deliberately.

## The class

| Property | Type | Default | Applies when | Meaning |
|---|---|---|---|---|
| `Transform` | CFrame | identity in practice (not stated in docs) | always | Target offset between the two attachments; what the Animator writes. |
| `IsKinematic` | boolean | `true` | always | `true`: parts follow `Transform` exactly, no physics, like a Motor6D. `false`: parts are driven toward the target by forces. |
| `AngularStrength` | number | `1` | not kinematic | Normalised stiffness as a frequency, `f / 60` with f in Hz (1 = about 60 Hz). 0 = no torque. Above 1 can destabilise. |
| `LinearStrength` | number | `1` | not kinematic | Same for position. |
| `AngularDamping` | number | (not stated) | not kinematic | Damping ratio; 1 = critical. |
| `LinearDamping` | number | (not stated) | not kinematic | Damping ratio; no effect if `LinearStrength` is 0. |
| `MaxTorque` | number | (not stated) | not kinematic | Cap on torque. Too low and the limb cannot hold the pose. |
| `MaxForce` | number | (not stated) | not kinematic | Cap on force. |
| `Attachment0`, `Attachment1` | Attachment | | always | The joint geometry (from `Constraint`). Part0/Part1 are the attachments' parents. |
| `C0`, `C1`, `Part0`, `Part1` | | | | **Deprecated, hidden, read-only aliases** of `Attachment0.CFrame`, `Attachment1.CFrame` and the attachments' parents. Writing them errors. |

`Workspace.ImprovedAnimationConstraint` (a rollout setting) gives the constraint separate linear and angular strength and damping; that is why the Linear*/Angular* pairs exist.

Equation in kinematic mode (same as Motor6D with attachments as C0/C1):
```
Part1.CFrame = Part0.CFrame * Attachment0.CFrame * Transform * Attachment1.CFrame:Inverse()
```

## What the Avatar Joint Upgrade does to a character

From the beta announcement and the Phase 2 post:
- Each `Motor6D` in a spawned R15 character is replaced by an `AnimationConstraint` plus a `BallSocketConstraint` (and on some parts a `NoCollisionConstraint`).
- The `BallSocketConstraint` keeps limbs attached during simulation and applies human-like cone limits. Those limits also constrain `IKControl` (a look-at no longer twists the neck 180 degrees); set `LimitsEnabled = false` or disable the constraint to remove them.
- R6 is not affected.
- Kinematic mode is described as slightly faster than Motor6D, with about 2% more average avatar memory.

### Timeline (as published)
| Date | Event |
|---|---|
| Nov 2024 | Studio beta; opt in with `StarterPlayer.AvatarJointUpgrade = Enabled` |
| Jan 26, 2026 | Graduated from beta, live |
| May 27, 2026 | Phase 2: experiences with the setting at `Default` get AnimationConstraints automatically. `Disabled` is a temporary opt-out (republish needed). |
| End of 2026 (target) | Phase 3: forced migration for all experiences; Motor6D stays supported for non-avatar rigs |

The class pages already say the upgrade is the default for new experiences. One production game discovered mid-project that its live characters used AnimationConstraints while its tools assumed Motor6Ds; every procedural system had to learn both.

## What breaks in old code

| Old pattern | Why it breaks | Replacement |
|---|---|---|
| `char.RightUpperArm:FindFirstChild("RightShoulder")` expecting a Motor6D | The joint is an [[AnimationConstraint]], possibly elsewhere | Find by class, accept both (see [[Rigs and Joints]]) |
| `if joint:IsA("Motor6D") then` | False for AnimationConstraint | `joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")` |
| Writing `neck.C0` every frame for look-at | `C0` is a read-only alias; writing errors | Write `Transform` in `PreSimulation`, or use `IKControl` |
| Editing `RigAttachment.CFrame` per frame instead | Allowed, but Roblox staff say it hurts performance and breaks retargeting | `Transform` |
| Server writes `C0` so others see the head turn | Does not work; also wasteful | Replicate the *input* (aim direction) with an attribute or `UnreliableRemoteEvent`; each client computes the pose |
| Disabling Motor6Ds to ragdoll | Different joints | Toggle `IsKinematic`, or rely on the BallSockets with the AnimationConstraints disabled |
| `Character:ScaleTo` | Reported broken under AJU in the Phase 2 thread | Test scaling on upgraded characters; body scale values still work |

### Roblox's recommended procedural pattern
From the Phase 2 migration post, almost verbatim in spirit:

```lua
--!strict
local RunService = game:GetService("RunService")

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local animator = humanoid:WaitForChild("Animator") :: Animator

local function findNeck(): Instance?
	for _, d in character:GetDescendants() do
		if (d:IsA("AnimationConstraint") or d:IsA("Motor6D")) and d.Name == "Neck" then
			return d
		end
	end
	return nil
end
local neck: any = findNeck() -- Motor6D or AnimationConstraint: both have Transform

local function computeNeckRotation(): CFrame
	return CFrame.Angles(0, math.rad(20), 0) -- your look logic here
end

RunService.PreSimulation:Connect(function()
	if not neck or animator.EvaluationThrottled then
		return -- on throttled frames Transform still holds last frame's result: do not stack again
	end
	-- Pre-multiply: rotate the whole animated neck pose in the parent joint's frame.
	neck.Transform = computeNeckRotation() * neck.Transform
end)
```

Pre- versus post-multiplying is a real choice; see [[Motor6D Math and CFrame Composition]].

### A known issue to plan around
Bug reports on the forum (acknowledged by Roblox staff) say that with `Workspace.UseFixedSimulation` enabled (required for Server Authority), setting `Transform` on Motor6Ds and AnimationConstraints does not take effect while an animation is playing; a fix needs a new API and client updates. If you adopt server authority, test every procedural layer under it. Status as of October 2026: unverified whether fixed.

## Using simulation on purpose

### Physics-blended limbs
With `IsKinematic = false`, the limb is a spring toward the animated target:
- `AngularStrength` 1 (about 60 Hz) with damping 1 tracks the animation closely; it looks almost kinematic but reacts to hits.
- Lower strength (0.2-0.4) gives visible lag and follow-through: heavy arms, drunk walk, zero-g. Rule of thumb; tune per rig.
- Low `MaxTorque` makes the limb unable to hold poses against gravity: the "defensive curl" demo in the announcement shows a character naturally failing to hold a pose.
- Roblox staff recommend keeping `Root` (and often `Waist`) kinematic so the torso stays rigid; community testers found fully non-kinematic characters "extremely wobbly and bouncy". A root-level constraint can oscillate at low frequency even at damping 1; raising both strength and damping helps.
- The Animation Editor does **not** preview simulated joints. You only see the result in Play.

### Ragdoll on death and knockdowns
- `Humanoid.BreakJointsOnDeath = false` keeps the joints so the body can ragdoll instead of falling apart. `StarterPlayer.ClassicDeath` (added May 2025) enables ragdoll on death without scripts when disabled.
- A simple ragdoll: set the AnimationConstraints to `IsKinematic = false` with `MaxTorque` near 0 (or disable them), keep the BallSockets, put the Humanoid in the `Physics` state (or `Ragdoll`, deprecated but still usable with `GettingUp` disabled), and give the parts the animation's velocity first with `Animator:ApplyJointVelocities` so they do not start from rest.
- Getting up: ramp `MaxTorque` back up over 0.2-0.5 s while playing a get-up clip, then return to kinematic. Ramping prevents the snap.

Full recipes in [[Ragdolls and Physics-Based Animation]] and [[Snippets - Ragdoll]].

## Replication and ownership

- `Transform` is evaluated per client from replicated track state, like Motor6D. Procedural `Transform` writes stay local.
- A simulated character is simulated by its network owner (the player's client for their own character). Other clients see the physical result through physics replication, which is coarser and later than the owner's view. Big physics reactions on characters therefore look smoothest for the owner; for spectators, prefer authored hit reactions with a little simulation on top.

## Diagnosing AJU problems

| Symptom | Likely cause |
|---|---|
| Head-look, IK, recoil scripts do nothing on some players | `IsA("Motor6D")` checks or name lookups that only find Motor6Ds |
| Error "C0 is not writable" or similar | Code writing C0/C1/Part0/Part1 on an AnimationConstraint |
| Limbs jelly-like after a script toggled something | `IsKinematic` false with low strength or damping |
| Neck look-at stops at a limit | BallSocket cone limits applied to IK |
| Accessories missing or duplicated constraints right after spawn | Known Phase 2 issues listed by Roblox; reproduce on a fresh baseplate and report |
| Your offline tools disagree with live play | Your test dummy uses Motor6Ds; live characters use AnimationConstraints (and possibly retargeting). Build test rigs the way live characters spawn |

## Checklist for a codebase

- [ ] Every joint lookup accepts AnimationConstraint and Motor6D.
- [ ] No per-frame C0 writes on characters; procedural layers write `Transform` in `PreSimulation` and skip throttled frames.
- [ ] No server-side pose writes; inputs replicate, clients compute.
- [ ] Ragdoll code toggles `IsKinematic` (or disables AnimationConstraints) rather than deleting Motor6Ds.
- [ ] Studio test dummies built the same way as live characters.
- [ ] `StarterPlayer.AvatarJointUpgrade` set deliberately, not left to drift with rollouts.

## See also
[[Rigs and Joints]] · [[Motor6D Math and CFrame Composition]] · [[Animator Deep Dive]] · [[Ragdolls and Physics-Based Animation]] · [[IKControl Reference]] · [[Frame Order and RunService Timing]] · [[Humanoid States and Animation]]

## Nuances and edge cases

1. **Phase 3 timing matters now.** With the forced migration targeted for the end of 2026 (as published; check the latest DevForum post before planning around a date), a `Disabled` opt-out is a short-term crutch. Any experience still relying on it in late 2026 should treat migration as scheduled work, not a someday item.
2. **Kinematic is cheap; simulated is not.** In kinematic mode the upgrade is close to free (Roblox describes it as slightly faster than Motor6D with about 2 percent more avatar memory). Turning characters non-kinematic adds them to the physics solver: 15 or so constrained parts per character. One or two simulated characters are fine; a 50-player server where every character is physics-blended all the time is a physics budget problem on both server and clients. Reserve simulation for moments (hits, knockdowns, death) and return to kinematic quickly.
3. **Ownership decides who sees the "real" motion.** The owner simulates; everyone else sees a replicated, smoothed result up to a round trip late. A physics-blended flinch that looks crisp to the victim may look mushy to the attacker, who is the person the flinch is for. For combat readability, play an authored flinch clip in kinematic mode for onlookers' benefit and keep simulation for the owner's own view only if it adds something.
4. **NPC ownership.** Server-owned simulated NPCs are simulated on the server, which costs server CPU and replicates at physics replication rates. For many NPCs, keep them kinematic and fake physical reactions with clips.
5. **Exploits.** The owner can do anything to its own simulated limbs. As always, never use limb positions on the server for hit validation.
6. **Low-end devices.** Physics substeps on phones are the same, but CPU headroom is not. A crowd scene where every character ragdolls on a round end can drop a low-end phone well under 30 FPS for a second or two. Stagger ragdoll starts over a few frames and cap simultaneous simulated characters per client.
7. **Custom rigs and StarterCharacter.** AJU applies to R15 player characters spawned by the engine. A custom `StarterCharacter` with its own Motor6Ds may or may not be converted depending on how it is built; check what your live characters actually contain (a quick descendant scan in a live test server) instead of assuming.
8. **Tool code that clones characters.** Viewport previews, mannequins and photo modes that clone a live character get AnimationConstraints and BallSockets too. Ballsockets in a ViewportFrame do nothing harmful, but code that expects Motor6Ds in the clone will fail the same way gameplay code did.

## Common mistakes in production

1. **Testing only in a baseplate with an old dummy.** Symptom: everything works in Studio, procedural layers die live. Fix: test with a spawned player character, or build dummies from `Players:CreateHumanoidModelFromDescription` so they match.
2. **Leaving `IsKinematic = false` after a get-up.** Symptom: characters wobble subtly for the rest of the life. Fix: always restore kinematic at the end of the get-up, with a timeout fallback.
3. **Ramping `MaxTorque` on the server for a player's character.** Symptom: no visible effect or a late snap. Fix: the owner client ramps; the server only signals.
4. **Turning off BallSocket limits globally to free IK.** Symptom: ragdolls fold into impossible poses. Fix: disable limits only on the neck or spine joints that IK needs, or only while IK is active.
5. **Assuming `ScaleTo` works on upgraded characters.** Symptom: scaled characters with detached or misplaced limbs. Fix: test scaling on upgraded characters before shipping, and use body scale values where possible.

## Related decisions

- [[Physics Assemblies and Constraints]]: what simulated joints add to the solver.
- [[Network Ownership]]: who simulates a non-kinematic character and what others see.
- [[Physics Performance]]: measuring the cost of simulated characters.
- [[Debugging Physics and Network Ownership]]: diagnosing wobble and late snaps.
- [[Characters and Humanoids]]: Humanoid states used for ragdoll and get-up.
- [[Avatar Body Types and Scale in Gameplay]]: scaling characters safely after the upgrade.
- [[Release Process and Rollbacks]]: planning a platform-forced migration like a release.
- [[Hitboxes and Hit Detection]]: keeping hits independent of simulated limb positions.
- [[Genre Playbook - Battlegrounds and Arena Fighters]]: where physical reactions are worth their cost.

## Connected notes
<!-- auto-links:start -->
[[Procedural Animation]] · [[R15 Rig Anatomy and Attachments]] · [[Animation Glossary]] · [[Custom Characters and StarterCharacter]] · [[Mover Constraints and Physics Controllers]] · Modeling Characters for R15 and Custom Rigs · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Bones and Skinned Meshes]] · [[Animation Objects]] · [[Replication and Ownership]] · [[Snippets - Procedural Motion]] · [[Accessories and Armor That Follow Animation]] · [[Testing Animations in Studio]] · [[Scale and Animation]] · [[How the Animator Really Behaves]]
<!-- related:end -->
