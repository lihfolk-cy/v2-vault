---
tags: [animation, mounts, creatures, riding, locomotion, replication, type/guide, area/animation, area/gameplay, level/intermediate, api/Animator, api/AnimationController, api/Humanoid]
---
# Mounts and Rideable Creatures

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Mount parts with mass welded to rider -> `Massless`, no collision on mount parts
> - Avoid: Mount Animator created on client -> Create or clone it on the server
> - Avoid: Design B mount tracks played on rider client -> Server plays, or replicated gait attribute
> - Architecture picked for a stated reason (A, B or C).
> - Mount parts massless and non-colliding in Design A; ownership handoff in Design B.
> - Animators created server-side; replication path matches the design.
>
> Cost: TL;DR ~160 tok · whole note ~2.4k tok. Read more: ## 1. Choose the architecture · ## 3. Design B: mount as vehicle · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A horse, a dragon or a giant pet you can ride is a vehicle and a character at the same time, and the architecture you pick decides which half is easy. The three workable designs are: the mount **welded under the rider's character** (rider's Humanoid does the moving), the mount **as a vehicle** with its own movers and a seat, and the rider **morphing into** the mount. Each has different animation replication, network ownership and exploit surfaces. This note picks between them, then covers rider pose, gait blending from speed, mounting and dismount rules. Creature animation craft is in [[Animating Creatures and Monsters]]; the replication rules quoted here are from [[Replication and Ownership]].

Source labels: **Roblox docs** (create.roblox.com, checked October 2026), **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

---

## 1. Choose the architecture

| Design | How it moves | Strengths | Costs |
|---|---|---|---|
| **A. Welded to rider** | Mount model welded to the rider's HumanoidRootPart; rider's Humanoid walks, jumps, climbs | Uses Humanoid movement, ownership is already the rider's, mount anims replicate from the rider's client | Collision is the rider's capsule, not the mount's body; big mounts clip walls |
| **B. Mount as vehicle** | Mount has its own root, `LinearVelocity`/`AlignOrientation` or a `ControllerManager`; rider sits on a seat | Real mount-sized collision, custom physics (gallop momentum, flight) | You write the controller; ownership handoff on mount; mount anims follow non-character rules |
| **C. Morph** | Rider's character replaced by a mount character (`StarterCharacter`-style swap or `Player.Character` reassignment) | Simplest for "play as the creature" | Rider is not visible unless you rebuild them on top; swapping characters resets state |

Rule of thumb: A for sims and hangouts (pets you ride, small horses); B for anything where the mount's size, speed or flight is the gameplay (dragons, war horses, mounts in PvP); C for transformation abilities, not riding.

## 2. Design A: welded under the character

Server, on mount:

1. Clone the mount from `ServerStorage`, set every mount part `Massless = true`, `CanCollide = false`, `CanQuery = false` (so it does not block your own raycasts).
2. Parent it inside the rider's character model and weld its root to the HumanoidRootPart with a `WeldConstraint` (or a `Motor6D` if you want to bob the saddle procedurally).
3. Raise `Humanoid.HipHeight` so the mount's feet reach the ground. [[HipHeight]] is the R15 distance from the ground to the bottom of the HumanoidRootPart (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/Humanoid). Store the old value and restore it on dismount.
4. Set `WalkSpeed`/`JumpPower` (or `JumpHeight`) for the mount on the server; your movement checks read the same values.

Animation replication: the mount's `AnimationController` + `Animator` sit inside the player's character, so tracks **started on the rider's client** replicate to everyone, provided the Animator was **created on the server** (it is, because the server cloned the model). An Animator created on a client never replicates tracks. Roblox docs: https://create.roblox.com/docs/animation/using.

## 3. Design B: mount as vehicle

- Rider sits on a `Seat` welded to the saddle; the mount's root gets `SetNetworkOwner(rider)` on sit and back to the server on leave, exactly like a car ([[Cars with Constraints - Suspension Steering and Drive]], section 6).
- Movement: read the rider's `Humanoid.MoveDirection` on their client (it still reflects input while seated in a plain Seat; **Unverified** for every control scheme, check on gamepad and touch) or bind your own actions, then drive the mount with `LinearVelocity` (planar) plus `AlignOrientation` toward the move direction. Ground it with a downward raycast and a hover spring, as in a raycast car. For walking creatures, a `ControllerManager` with a `GroundController` is the newer engine-supported option (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/ControllerManager); see [[Custom Character Controllers]].
- Mount animations: the mount is **not** a player character, so per the Animator rules its tracks must be loaded and played **on the server** to replicate, or the server writes a replicated `Gait` attribute and every client plays the matching track locally. The attribute approach scales better and has no extra latency for the rider ([[Replication and Ownership]], architecture 3).

## 4. Rider pose

Sitting gives the default sit animation, which looks wrong on anything but a chair.

- Load a looped riding pose on the **rider's** Animator with `Priority = Enum.AnimationPriority.Action` (or Action2 to Action4 if your combat uses Action), played from the rider's client so it replicates.
- In Design A the rider is walking, so the default Animate script keeps trying to play walk and jump tracks underneath. Either stop the Animate script's tracks while mounted or make sure your riding pose fully covers the legs at a higher priority. Partial-weight leg poses produce the "running in the saddle" bug. See [[The Default Animate Script]].
- Add a small procedural lean into turns and a bob synced to the mount's gait phase (sample the gait track's `TimePosition`). Cheap and sells weight ([[Procedural Animation]]).

## 5. Gait from speed

One blend function, run on every client that renders the mount:

```lua
--!strict
type Gaits = { Idle: AnimationTrack, Walk: AnimationTrack, Run: AnimationTrack }

local WALK_SPEED, RUN_SPEED = 8, 24 -- studs/s at which each clip's footfalls match the ground

local function updateGait(g: Gaits, speed: number)
	local walkW = math.clamp(speed / WALK_SPEED, 0, 1)
	local runW = math.clamp((speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0, 1)
	g.Idle:AdjustWeight(math.max(1 - walkW, 0.001), 0.15)
	g.Walk:AdjustWeight(math.max(walkW * (1 - runW), 0.001), 0.15)
	g.Run:AdjustWeight(math.max(runW, 0.001), 0.15)
	-- match playback to ground speed so hooves do not skate
	g.Walk:AdjustSpeed(math.clamp(speed / WALK_SPEED, 0.5, 1.5))
	g.Run:AdjustSpeed(math.clamp(speed / RUN_SPEED, 0.6, 1.4))
end
```

Play all three looped once at mount time and only adjust weights. Weight 0.001 instead of 0 keeps tracks evaluating so phase is continuous. Speed comes from `AssemblyLinearVelocity` flattened to XZ on the root. Rule of thumb: author each gait clip at a known ground speed and write it down; that number is the divisor.

## 6. Mount and dismount rules

- Mounting goes through the server: a `ProximityPrompt` or inventory action, ownership of the mount checked, cooldown after combat, not in water unless the mount swims, not inside interiors flagged no-mount.
- Dismount triggers: jump key (Design B; in Design A jump is the mount's jump, so use a dedicated key), damage above a threshold, entering a no-mount zone, mount death.
- On dismount, restore HipHeight, WalkSpeed and the Animate script state; place the rider beside the mount with a clearance check; destroy or park the mount. Forgetting to restore HipHeight leaves the player floating.
- Respawn and character reset must clean up: listen to `Humanoid.Died` and `Player.CharacterRemoving`.

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Mount parts with mass welded to rider | Rider walks slowly, tips, flings | `Massless`, no collision on mount parts |
| Mount Animator created on client | Only the rider sees the mount animate | Create or clone it on the server |
| Design B mount tracks played on rider client | Others see a frozen mount | Server plays, or replicated gait attribute |
| Sit animation left on | Rider sits like on a chair | Looped riding pose at Action priority |
| Gait clips at fixed speed | Hooves skate | [[AdjustSpeed]] from ground speed |
| HipHeight not restored | Player floats after dismount | Store and restore on every exit path |

## Checklist

- [ ] Architecture picked for a stated reason (A, B or C).
- [ ] Mount parts massless and non-colliding in Design A; ownership handoff in Design B.
- [ ] Animators created server-side; replication path matches the design.
- [ ] Riding pose overrides walk/sit on the rider.
- [ ] Gait blend by speed with matched playback speed.
- [ ] Server-validated mount and dismount; cleanup on death, reset and leave.

## See also

[[Animating Creatures and Monsters]] · [[Replication and Ownership]] · [[Custom Character Controllers]] · [[Custom Locomotion Controller Design]] · [[Humanoid States and Animation]] · [[The Default Animate Script]] · [[Pet Hatching and Following End to End]] · [[Aircraft and Flight Models]]

## Connected notes
<!-- auto-links:start -->
[[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · [[Procedural Gait and Footstep Planning]] · [[Creature Rig Conventions]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Locomotion Systems]] · [[Snippets - Animation Controller Module]] · [[Custom Characters and StarterCharacter]] · [[R15 Run Cycle Key Poses]] · [[Scale and Animation]] · [[Playback, Priorities and Blending]] · [[First-Person Viewmodels - Arms Rig, Sway and Camera Binding]] · [[Enemy and NPC Animation]]
<!-- related:end -->
