---
tags: [gameplay, movement, parkour, vault, mantle, ledge-grab, wall-run, raycasts, anti-exploit, type/guide, area/gameplay, level/advanced, api/WorldRoot, api/Humanoid]
---
# Parkour Moves - Vault, Ledge Grab, Mantle and Wall-Run

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Moving the root while the Humanoid is in Running -> Physics state or PlatformStand during moves
> - Avoid: No clearance test -> Box query at the landing spot
> - Avoid: Server unaware of moves -> Sanctioned move budgets
> - Probe set with classification thresholds in config.
> - Moves executed on the client with controlled Humanoid state and restored on every exit.
> - Clips and curves share timing; hand contact markers aligned.
>
> Cost: TL;DR ~150 tok · whole note ~2.4k tok. Read more: ## 1. Detection: a probe set, not a physics query soup · ## 2. Executing moves without fighting the Humanoid · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Parkour on Roblox is a client-side feature with a server-side conscience. The character is owned and simulated by the player's client, so the moves must run there to feel responsive; but every move is a sanctioned teleport-ish displacement that a movement anti-cheat will flag unless it knows about it. This note covers detection with a small set of raycasts, executing moves without fighting the Humanoid, animation sync, and server validation. Controller architecture is in [[Custom Character Controllers]]; movement exploits in [[Detecting Movement Exploits - Speed Fly Noclip Teleport]].

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. Detection: a probe set, not a physics query soup

Every frame while moving (or at 30 Hz), cast a few rays from the root part along the flattened move direction `f`:

| Probe | From | Direction | Detects |
|---|---|---|---|
| Knee | root - 1.5 Y | `f * 2.5` | Low obstacle (vault candidate) |
| Chest | root + 0.5 Y | `f * 2.5` | Wall (wall-run or climb candidate) |
| Head | root + 2.5 Y | `f * 2.5` | Clear above obstacle? (vault/mantle allowed) |
| Ledge-down | hit point + `f * 0.6` + up 4 | down 5 | Top surface height and walkability |
| Side L/R | root | `±right * 2` | Wall for wall-run |

Use `Workspace:Raycast` with an exclude filter of the character (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Raycast). For mantles, finish with a **clearance test**: `Workspace:GetPartBoundsInBox` (or a `Blockcast`) at the landing spot with the character's size to make sure the player fits on top ([[Raycasts Shapecasts and Spatial Queries]]).

Classify:
- **Vault**: knee hit, chest clear, obstacle top within 1 to 3.5 studs above feet, obstacle depth under about 3 studs (cast from the far side back to find thickness), landing ground found beyond.
- **Mantle / climb-up**: chest hit, ledge-down finds a walkable top 3.5 to 7 studs above feet, clearance passes.
- **Ledge grab**: airborne, falling, chest hit, ledge top within hand reach (near head height): hang, then climb up or drop.
- **Wall-run**: airborne or sprinting, side probe hits a wall whose normal is roughly horizontal (`|normal.Y| < 0.2`), speed above a threshold, angle between move direction and wall under about 60 degrees.

Tag surfaces to opt in or out: `NoParkour` attribute on parts that should not be climbable (map boundaries, kill-plane walls, enemy bases). This is your first anti-abuse line.

## 2. Executing moves without fighting the Humanoid

The Humanoid controller will fight any motion you impose. For the duration of a move:
- Put the Humanoid in a controlled state: `Humanoid:ChangeState(Enum.HumanoidStateType.Physics)` or set `PlatformStand`, disable `AutoRotate`, and drive the root yourself; or use a constraint-based approach (`AlignPosition`/`AlignOrientation` in one-attachment mode) toward a target ([[Mover Constraints and Physics Controllers]]).
- Move along a **short authored curve**: for a vault, from the start point to a midpoint above the obstacle to the landing point, over the animation's duration (0.35 to 0.6 s). Sample the curve per frame and set the root `CFrame` (client-owned, so it replicates).
- Restore state on completion, on interruption (damage, stun), and on character removal: back to `Running` or `Freefall`, `AutoRotate = true`.

```lua
--!strict
local RunService = game:GetService("RunService")

local function bezier(a: Vector3, b: Vector3, c: Vector3, t: number): Vector3
	local u = 1 - t
	return a * u * u + b * 2 * u * t + c * t * t
end

local function performVault(hum: Humanoid, root: BasePart, top: Vector3, landing: Vector3, duration: number, onDone: () -> ())
	local start = root.Position
	local mid = Vector3.new(top.X, top.Y + 2, top.Z)
	local look = (landing - start) * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 1e-3 then look.Unit else root.CFrame.LookVector
	hum.AutoRotate = false
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	local elapsed = 0
	local conn: RBXScriptConnection
	conn = RunService.PreSimulation:Connect(function(dt: number)
		elapsed += dt
		local t = math.clamp(elapsed / duration, 0, 1)
		local p = bezier(start, mid, landing, t)
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.lookAt(p, p + look)
		if t >= 1 then
			conn:Disconnect()
			hum.AutoRotate = true
			hum:ChangeState(Enum.HumanoidStateType.Running)
			onDone()
		end
	end)
end
```

`RunService.PreSimulation` runs before physics each frame (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/RunService#PreSimulation). Keep the velocity zeroed during the move so physics does not add to it, then give exit velocity on completion (forward momentum after a vault feels much better than a dead stop).

### Wall-run
Not a curve but a constrained state: keep the player at a fixed distance from the wall along its tangent, reduce gravity with a `VectorForce` or a `LinearVelocity` constraint that holds vertical speed near zero and decays it over the run (0.8 to 1.5 s max), and end on: wall ends (side probe misses), jump pressed (jump away along the normal plus up), time out, or speed too low.

## 3. Animation sync

- Each move has a clip; its duration defines the curve duration, or the clip is time-scaled to the measured distance (`AdjustSpeed`). Hands must touch the obstacle top: put a marker at the contact frame and align the curve's midpoint time to it ([[Markers and Events]]).
- Ledge hang uses an IK-friendly pose; small hand placement errors are hidden by `IKControl` on the arms toward the ledge point (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/IKControl; see [[Foot Placement and Ground IK]]).
- Play the move animation on the local Animator; it replicates to others through the Animator ([[Replication and Ownership]]).

## 4. Server validation

The server does not run the moves; it **audits** them:
1. The client tells the server it began a move (type, start, target) via a remote, or the server infers it from a `ParkourState` attribute the client sets on its character (attributes set by the client on its own character do **not** replicate; use a remote).
2. The server re-runs the same probes from its view of the character position, with tolerance (latency, a few studs). If the geometry does not support a vault there, reject: the movement checker treats the displacement as unexplained.
3. The movement anti-cheat gets a **budget** for the move: allowed displacement and vertical gain for its duration. Outside a sanctioned move, the normal speed and fly limits apply ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]).
4. Rate-limit moves (a vault every 0.3 s at most) and cap chains (wall-run, jump, wall-run again only up to N times before touching the ground).

Responses follow the usual fair-enforcement approach: rubber-band to the last valid position, log, and only escalate on repeated, clear cases ([[False Positives Lag and Fair Enforcement]]).

## 5. Level design contract

Parkour lives or dies on consistent geometry: standard vault heights (2 to 3 studs), mantle heights (4 to 6 studs), ledge thickness, and clear tagging of what is climbable. Document the metrics and build greybox kits to them ([[Obby and Platforming Level Design]], [[Level Design for Roblox]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Moving the root while the Humanoid is in Running | Jitter, snapping back | Physics state or PlatformStand during moves |
| No clearance test | Mantling into ceilings | Box query at the landing spot |
| Server unaware of moves | Anti-cheat rubber-bands every vault | Sanctioned move budgets |
| Server trusts the client's move claim | Wall-climb anywhere exploits | Re-run probes on the server with tolerance |
| No surface opt-out | Players climb out of the map | `NoParkour` attribute on boundaries |
| Dead stop after a vault | Clunky flow | Exit velocity along the move direction |

## Checklist
- [ ] Probe set with classification thresholds in config.
- [ ] Moves executed on the client with controlled Humanoid state and restored on every exit.
- [ ] Clips and curves share timing; hand contact markers aligned.
- [ ] Server audits moves with probes, budgets, rate limits and chain caps.
- [ ] Climbable and non-climbable surfaces tagged; level metrics documented.

## See also
[[Custom Character Controllers]] · [[Mover Constraints and Physics Controllers]] · [[Locomotion Systems]] · [[Input Responsiveness Buffering and Coyote Time]] · [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] · [[Raycasts Shapecasts and Spatial Queries]]

## Connected notes
<!-- auto-links:start -->
[[Custom Locomotion Controller Design]] · Obby and Platforming Level Design · 2D Collision Physics and Platformer Movement · [[Characters and Humanoids]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Grabs, Carries and Throws - Moving Players Safely]] · [[Pathfinding Edge Cases and Fallbacks]] · [[Physics Assemblies and Constraints]] · [[Hitboxes and Hit Detection]] · [[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]] · [[Explosions - Radius Damage, Falloff and Cover Checks]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]]
<!-- related:end -->
