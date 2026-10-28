---
tags: [performance, physics, collision, humanoids, network-ownership, bulkmoveto]
---
# Physics Performance

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Unanchored decoration. Check with a script: count unanchored parts not in characters.
> - Avoid: `PreciseConvexDecomposition` by default on imported meshes.
> - Avoid: Leaving `CanQuery` and `CanTouch` on visual geometry.
> - All static geometry anchored; visual-only parts have `CanCollide`, `CanTouch`, `CanQuery` off.
> - Collision fidelity audited; no precise fidelity on small or distant meshes.
> - Large complex meshes use simple invisible colliders.
>
> Read more (15 KB note): ## 3. Collision: fidelity and flags · ## 6. Moving many parts: `BulkMoveTo` · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Physics cost on Roblox is rarely about one heavy simulation. It is about **how many things the engine thinks it has to simulate, collide or query**: thousands of decorative parts left unanchored, precise collision on every rock, Humanoids on statues, ownership ping-ponging between players, and scripts that move hundreds of parts one property set at a time. This note explains what the physics engine actually spends time on, the switches that remove work (anchoring, collision flags, fidelity, stepping method, Humanoid states), network ownership costs, moving many parts cheaply with `BulkMoveTo`, and how to diagnose physics load.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

Background on assemblies and constraints: [[Physics Assemblies and Constraints]]. Collision geometry authoring: [[Collision and Physics Geometry]].

---

## 1. What physics costs

| Cost | Driven by | Where it shows |
|---|---|---|
| Simulation | number of **awake, unanchored assemblies**, constraints and joints | `physicsStepped`, `worldStep`, `stepWorld` |
| Contacts | pairs of touching or near colliding parts | `stepContacts`; `Stats.ContactsCount` |
| Broadphase and islands | spatial structure updates as parts move | `SpatialFilter/filterStep` |
| Humanoids | state machine, floor detection, movement | `stepHumanoid` |
| Queries | raycasts, shapecasts, overlap queries against geometry | your script labels; `Raycast` children in the profiler |
| Touch events | `Touched`/`TouchEnded` processing | scripts plus contact work |
| Replication | owned assemblies sending and receiving motion | `Dispatch Physics Senders`, `interpolateNetworkedAssemblies` |
| Memory | collision geometry | `PhysicsCollision`, `PhysicsParts` in the console |

The alarm label: **`stepWorldThrottled`**. Docs: when the engine is overloaded it runs this instead of the full step and only simulates real-time assemblies such as Humanoids. If you see it, everything else is being starved.

Live counters from the `Stats` service: `PrimitivesCount`, `MovingPrimitivesCount`, `ContactsCount`, `PhysicsStepTime`, `PhysicsSendKbps`, `PhysicsReceiveKbps` ([[Developer Console and Stats]]).

---

## 2. Remove simulation work

### 2.1 Anchor everything that does not need to move by physics
An anchored part is not simulated. Docs: anchor parts that don't need physics, such as static NPCs. Map geometry, props, decorations, UI parts in the world, VFX geometry moved by script: anchor them all.

Moving an anchored part by setting its `CFrame` is not physics; it is a transform update (cheap per part, but see `BulkMoveTo` below for hundreds).

### 2.2 Physics sleep
Unanchored assemblies that come to rest go to sleep and stop costing simulation time until something wakes them. Things that keep them awake (rule of thumb): constant small forces, constraints that never settle, scripts that touch their velocity or CFrame every frame, overlapping collision that keeps resolving. A pile of 300 unanchored debris parts that never quite settles is a constant cost. `PhysicsSettings.AreAwakePartsHighlighted` (Studio Settings, Physics) shows which parts are awake.

### 2.3 Fewer joints and constraints
Docs: minimise constraints and joints; in ragdolls, limit self-collision with limits or `NoCollisionConstraint`s. A ragdoll with every limb colliding with every other limb is many contact pairs per character.

### 2.4 Stepping method
Docs: in **Adaptive** mode the solver steps assemblies at 60, 120 or 240 Hz as needed; **Fixed** steps all of them at 240 Hz, which costs much more per frame. `Workspace.PhysicsSteppingMethod` is set in Studio (not scriptable). Keep Adaptive unless you have a measured reason (for example, fast mechanisms that tunnel).

---

## 3. Collision: fidelity and flags

### 3.1 Collision fidelity (Docs)
| `CollisionFidelity` | Cost | Use for |
|---|---|---|
| `Box` | lowest | small or non-interactive objects; small anchored parts (generally safe) |
| `Hull` | low | small to medium objects |
| `Default` | medium-high | rarely the right choice for big meshes |
| `PreciseConvexDecomposition` | highest, most memory | only where players really touch the shape closely |

For large complex meshes, Docs recommend custom collision from invisible simpler parts. Default and Precise also use significantly more memory than Box and Hull (`PhysicsParts` memory).

Find offenders: Visualization Options can show collision fidelity, and the Explorer filter `CollisionFidelity=PreciseConvexDecomposition` lists precise parts (Docs).

**Measured.** The reference project's hub buildings and landmarks were imported as visual meshes with collision handled by a handful of invisible, simple collider parts (one landmark used 13 invisible collision parts under a high-detail visual mesh with collision off). Visual meshes were set `CanCollide`, `CanTouch` and `CanQuery` false. The walkable shape became predictable, and the high-poly meshes stopped costing collision memory.

### 3.2 The three flags
| Property | When false | Turn off for |
|---|---|---|
| `CanCollide` | nothing physically collides with it | decoration, VFX geometry, foliage, visual meshes over colliders |
| `CanTouch` | it fires no `Touched` events and costs no touch processing | anything nobody listens to touches on |
| `CanQuery` | raycasts and spatial queries ignore it (only meaningful when `CanCollide` is false) | VFX, decals-on-parts, foliage, visual-only meshes |

Docs: set all three to false on parts that don't need them. This is the cheapest physics win in most games: a map with 40,000 decorative parts that are queryable makes every raycast in the game pay to consider them.

**Measured.** Map passes in the reference project followed a fixed rule: colliding props only outside the enemy walk areas; decorative pieces inside walk areas non-colliding; scenery `CastShadow` off where it did not matter; meshes `RenderFidelity` Automatic. Collision changes were verified by re-running a fixed 1,620-ray grid before and after and checking results were identical.

### 3.3 Collision groups
Collision groups decide which groups collide with which. Use them for logic (players pass through each other, projectiles ignore their owner) rather than performance, but they do remove contact pairs you would otherwise compute.

---

## 4. Humanoids

Docs are blunt: Humanoids are expensive.
- Static NPCs (shopkeepers, statues) usually don't need a Humanoid; use an `AnimationController` with an `Animator` for animation.
- Disable unneeded states with `Humanoid:SetStateEnabled()` (for example Climbing, unless NPCs climb).
- Pool NPC models instead of destroying and re-creating them on frequent respawns.
- Spawn NPCs only near players; cull them when players leave.
- Play NPC animations on the client, not the server.
- For procedural motion, write `Motor6D.Transform`, not `C0`/`C1`.
- Avoid frequent size and scale changes on avatars; they rebuild render clusters (`updateInvalidatedFastClusters`, over 4 ms is a red flag).

Custom controllers that move NPCs with anchored CFrame updates or mover constraints avoid the Humanoid state machine entirely; see [[Custom Character Controllers]] and [[NPC AI and Behaviour]].

```lua
--!strict
-- Trim states a ground-only NPC never uses.
local function trimHumanoid(humanoid: Humanoid)
	for _, state in {
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Flying,
	} do
		humanoid:SetStateEnabled(state, false)
	end
end
```

Disable states on the side that owns the Humanoid's physics (rule of thumb: the server for server-owned NPCs; the owning client for player characters), or the state will still be entered where it is simulated.

---

## 5. Network ownership

Unanchored assemblies are simulated by an **owner**: the server or one client. The engine assigns ownership automatically (usually to the nearest player), and changing owners has a cost (`Distributed Physics Ownership` in the profiler, Docs).

Problems and fixes:
| Problem | Fix |
|---|---|
| NPCs or vehicles flicker between owners as players move near them | `part:SetNetworkOwner(nil)` on the server for server-driven assemblies |
| A client can push or teleport server objects it owns | server ownership for anything gameplay-critical ([[Exploits and Anti-Cheat]]) |
| A player's projectile feels laggy | give the shooter ownership of their own cosmetic projectile, or simulate it client-side |

Show owners in Studio: Studio Settings, Physics, **Are Owners Shown**. Details in [[Network Ownership]].

---

## 6. Moving many parts: `BulkMoveTo`

`workspace:BulkMoveTo(parts, cframes, mode)` moves an array of BaseParts to an array of CFrames in one call (Docs). The arrays must be the same length. `Enum.BulkMoveMode.FireAllEvents` (default) fires Changed for Position, Orientation and CFrame; `FireCFrameChanged` fires only the CFrame Changed event. Docs caveat: plain CFrame setting is fast enough in most cases; use `BulkMoveTo` when part movement is a confirmed bottleneck.

**Measured uses** in the reference project:
- Foliage sway: leaves near the camera swayed at **30 Hz** using `BulkMoveTo`; far leaves did not move.
- Arena floaters: floating rock pieces in a boss arena orbited via `BulkMoveTo` on Heartbeat, only while the fight was active, and only at higher graphics quality.

```lua
--!strict
-- Client: sway anchored decorative parts near the camera at 30 Hz with one BulkMoveTo call.
local RunService = game:GetService("RunService")

local RANGE = 120 -- studs
local RATE = 1 / 30

type Sway = { part: BasePart, base: CFrame, phase: number }
local items: { Sway } = {}

local partsBuf: { BasePart } = {}
local cfBuf: { CFrame } = {}
local acc = 0
local t = 0

local function register(part: BasePart)
	assert(part.Anchored, "sway parts must be anchored")
	table.insert(items, { part = part, base = part.CFrame, phase = math.random() * math.pi * 2 })
end

RunService.Heartbeat:Connect(function(dt: number)
	t += dt
	acc += dt
	if acc < RATE then
		return
	end
	acc = 0

	local camPos = workspace.CurrentCamera.CFrame.Position
	table.clear(partsBuf)
	table.clear(cfBuf)
	for _, s in items do
		if (s.base.Position - camPos).Magnitude < RANGE then
			local angle = math.sin(t * 1.7 + s.phase) * math.rad(4)
			table.insert(partsBuf, s.part)
			table.insert(cfBuf, s.base * CFrame.Angles(0, 0, angle))
		end
	end
	if #partsBuf > 0 then
		workspace:BulkMoveTo(partsBuf, cfBuf, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

return register
```

Notes:
- Buffers are reused with `table.clear`, so the loop allocates no new arrays.
- Parts that left the range stay at their last pose (a small, invisible discontinuity). If that matters, snap them back to `base` once when they leave.
- Keep these parts `CanCollide`, `CanTouch` and `CanQuery` false; moving collidable parts every frame invalidates broadphase work.
- With many thousands of parts, the distance loop itself becomes the cost: bucket parts into spatial cells and only scan nearby cells.

---

## 7. Queries

Raycasts and shapecasts are cheap individually and expensive in bulk. The Docs walkthrough's example of 1,500 random raycasts per second cost a visible 15 fps.

- Use `RaycastParams` filters (include lists are often cheaper to reason about than exclude lists).
- Mark visual geometry `CanQuery = false`.
- Cache results that change slowly: the reference project replaced per-think ground raycasts for enemies with a cached height grid (2-stud cells, rebuilt every 4 s, exact raycast only for ambiguous cells; measured max error 0.233 studs).
- Spread queries across frames with per-entity phase.

See [[Raycasts Shapecasts and Spatial Queries]].

---

## 8. Touched events

`Touched` fires per contact start and can fire many times per second for a moving part. Costs: the event itself, your handler, and debouncing logic. Prefer:
- `CanTouch = false` on everything that does not need it.
- Spatial queries on a cadence (`GetPartBoundsInBox` every 0.1 s) for zones and hitboxes rather than `Touched` on big parts ([[Hitboxes and Hit Detection]]).
- Per-player debounce tables, cleared on `PlayerRemoving`.

---

## 9. Diagnosing physics load

1. Server or client? Ownership decides who simulates what. Server physics shows in a server MicroProfiler dump.
2. Look for `physicsStepped`, `worldStep`, `stepContacts`, `stepHumanoid`, and especially `stepWorldThrottled`.
3. Check counters: `MovingPrimitivesCount` (should be small relative to `PrimitivesCount`), `ContactsCount`.
4. Visualise in Studio: awake parts (`AreAwakePartsHighlighted`), owners (Are Owners Shown), assemblies (`AreAssembliesShown`), collision fidelity.
5. Find the cause: an unanchored pile, a ragdoll field, a mechanism that never sleeps, a precise-collision mesh crowd, too many Humanoids.

| Symptom | Likely cause |
|---|---|
| Server heartbeat drops when many enemies fight | Humanoids, contacts between crowded enemies, pathfinding |
| Physics cost high with nothing moving visibly | parts awake but jittering; unsettled constraints |
| Memory high in `PhysicsCollision` | precise fidelity on many meshes |
| Objects stutter near players | ownership switching |
| Parts falling forever, `handleFallenParts` visible | unanchored debris dropping out of the world; check `FallenPartsDestroyHeight` |

---

## Common mistakes

- Unanchored decoration. Check with a script: count unanchored parts not in characters.
- `PreciseConvexDecomposition` by default on imported meshes.
- Leaving `CanQuery` and `CanTouch` on visual geometry.
- Humanoids on static NPCs.
- Switching the place to Fixed stepping "for accuracy".
- Moving collidable parts every frame for cosmetic motion.
- Raycasting per entity per frame without caching or phase spreading.

## Checklist

- [ ] All static geometry anchored; visual-only parts have `CanCollide`, `CanTouch`, `CanQuery` off.
- [ ] Collision fidelity audited; no precise fidelity on small or distant meshes.
- [ ] Large complex meshes use simple invisible colliders.
- [ ] Static NPCs use AnimationController; NPC Humanoids have unused states disabled.
- [ ] Server-driven assemblies have server ownership.
- [ ] Cosmetic motion of many parts uses `BulkMoveTo` at a reduced rate, near the camera only.
- [ ] Queries are filtered, cached where possible and spread over frames.
- [ ] Physics changes to walkable areas verified with a fixed ray grid before and after.

## See also

[[Physics Assemblies and Constraints]] · [[Collision and Physics Geometry]] · [[Network Ownership]] · [[Characters and Humanoids]] · [[Raycasts Shapecasts and Spatial Queries]] · [[MicroProfiler Guide]] · [[Script Performance]] · [[Ragdolls and Physics-Based Animation]] · [[Performance and Memory]]

## Connected notes
<!-- auto-links:start -->
[[Debugging Physics and Network Ownership]] · [[Links - Collisions]] · [[Tween and CFrame Animation of Objects]] · [[Links - Raycasting and spatial queries]] · [[Exporting and Validating Models for Roblox]] · [[Resource Library - Physics]]
<!-- auto-links:end -->
