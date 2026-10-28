---
tags: [physics, vehicles, boats, buoyancy, water, terrain, network-ownership]
---
# Boats Buoyancy and Water

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Light hull in terrain water plus float points -> Make the hull sink on its own, or drop the float points
> - Avoid: Same drag in all directions -> Side drag 10 to 20 times forward drag
> - Avoid: No depth clamp -> `maxDepth` clamp
> - Chosen engine buoyancy or float points per boat type, with a reason.
> - `k` computed from mass, gravity, point count and draft; bob frequency checked.
> - Damping ratio 0.5 to 0.7; depth clamp set.
>
> Cost: TL;DR ~150 tok · whole note ~5.1k tok. Read more: ## 3. The float-point model · ## 5. Players on a moving deck · ## 9. Common mistakes · ## Checklist
<!-- tldr:end -->

Boats look like the easy vehicle: drop a light hull into terrain water and it floats. The trouble starts when you want waves that move the boat, a ship players can walk around on, a hull that turns instead of sliding sideways, or water that is not terrain at all. This note covers the two ways to float things on Roblox (engine buoyancy in terrain water, and your own float-point model), how to calibrate buoyancy so a hull sits at the draft you want, why a boat needs different drag forward and sideways, deterministic waves that every client agrees on, propulsion and steering, the "players slide off the moving ship" problem, and the ownership and security choices.

Prerequisites: [[Physics Assemblies and Constraints]] for mass and density, [[Mover Constraints and Physics Controllers]] for `VectorForce` and `AlignOrientation`, and [[Terrain Deep Dive - Materials Water and Performance]] for terrain water itself (shorelines, materials, swim state).

Source labels: **Docs** (Roblox docs, as of October 2026), **Community-tested** (reported on the DevForum, not in official docs), **Rule of thumb**. Code is strict Luau, **reviewed, not run**.

---

## 1. Two ways to float

| | Engine buoyancy (terrain water) | Float-point model (scripted) |
|---|---|---|
| Water | Terrain `Water` material | Anything: terrain, a flat plane, a moving wave function, lava |
| Floating | Automatic, from part density versus water | You apply forces at chosen points |
| Waves that move boats | No (rule of thumb: terrain wave settings are visual; the physical surface is the voxel surface) | Yes, if your height function moves |
| Tuning | Change densities | Full control: draft, bob, roll stiffness |
| Cost | Engine, cheap | One query or function call per float point per step on the owner |
| Characters swim | Yes, `Swimming` state is automatic | Only if the water is also terrain, or you script swimming |

Use engine buoyancy for floating props, rafts, debris and simple boats in calm water. Use a float-point model when the boat is a core vehicle, when you want waves, or when the "water" is not terrain. You can combine them: terrain water for swimming and visuals, scripted float points for the hero ship with engine buoyancy cancelled (section 2).

---

## 2. Engine buoyancy in terrain water

Unanchored parts in terrain water float or sink by density. The official reference pages do not state the threshold; DevForum testing reports that water behaves as density 1: parts below 1 float, parts at exactly 1 hover, parts above sink (**Community-tested**, verify in your build). Roblox Plastic is well below 1, so most default-material builds float.

Practical consequences:

- An **assembly** floats as a whole. A dense engine part welded to a light hull floats if the assembly's average buoyancy wins. That is how you make metal boats: a big, light, invisible "flotation" part welded inside the hull.
- How high it floats depends on the submerged volume of each part, so the shape of your colliders matters. Thin decorative parts barely contribute; thick hull blocks do.
- There is no control over bobbing frequency or roll stiffness except through shape and density. A tall narrow hull will roll over just like a real one.
- To **opt a part out** of engine buoyancy (you want only your scripted forces), the simplest route is to make it dense enough to sink and let your float points carry the weight. Do not try to cancel buoyancy with an opposite force; you cannot know its exact value each step.

### Detecting water

`BuoyancySensor` reports a part's interaction with terrain water through two outputs: `FullySubmerged` (the whole part is under water with at least one water voxel above it) and `TouchingSurface` (any point touches water). The Docs warn that detection is approximate and may use the bounding box (**Docs**). Use it for "is the propeller in the water" or "play splash sound", not for precise force maths.

For precise queries, `Terrain:ReadVoxels` over a small region gives occupancy per voxel, and a downward raycast whose `RaycastParams.IgnoreWater` is false returns `Enum.Material.Water` on hit. Both are fine at a few points per boat; neither belongs in a per-part, per-frame loop for dozens of boats.

---

## 3. The float-point model

Place a handful of attachments along the hull's waterline: four is the minimum (bow, stern, port, starboard), six to eight gives smoother behaviour for long ships. Each physics step on the owning machine:

1. Find the water height `h` under the point (your wave function, a raycast, or a constant).
2. Depth `d = h - pointY`. If `d <= 0`, the point is out of the water: no force.
3. Buoyant force up, proportional to depth, clamped at a maximum depth (a fully submerged point cannot push harder).
4. Damping: subtract a force proportional to the point's vertical velocity.
5. Drag: oppose the point's horizontal velocity, with a much higher coefficient sideways than forward (section 4).

Apply the result with one `VectorForce` per point, `RelativeTo = World`, `ApplyAtCenterOfMass = false`. Forces at the corners create the pitch and roll for you.

### Calibrating so the hull sits at a chosen draft

You want the boat at rest with each point `draft` studs under the surface. With `N` points sharing the weight equally:

```
k (force per stud of depth, per point) = mass * g / (N * draft)
```

At `d = draft` the total upward force equals the weight, so the boat rests there. That is a spring, and its natural bobbing frequency is:

```
f = sqrt(g / draft) / (2 * pi)
```

### Worked example and the Roblox gravity surprise

With the default 196.2 studs/s² gravity (**Docs**) and a 1-stud draft, `f = sqrt(196.2) / 6.28 = 2.2 Hz`. That is a fast, nervous bob, closer to a cork than a ship. Real ships bob at well under 0.5 Hz. To slow it down you have three levers:

- **Deeper draft.** A 4-stud draft gives about 1.1 Hz.
- **Lower gravity on the boat only.** Add a constant upward `VectorForce` at the centre of mass equal to a fraction of the weight (say 40%), and calibrate `k` for the remaining 60%. The boat now behaves as if gravity were 60%, and bobs at about 0.77 of the frequency. Characters are unaffected.
- **More damping.** Damping ratio around 0.5 to 0.7 removes the cork feel without slowing the period. Critical damping per point is `2 * sqrt(k * m / N)`.

Usually you use all three. Note the same gravity issue appears in car suspension ([[Cars with Constraints - Suspension Steering and Drive]]).

### Code

A shared wave module both server and clients can require, so everyone computes the same surface:

```lua
--!strict
-- ReplicatedStorage/Shared/Waves.lua
-- Sum of a few directional sine waves. Deterministic: same (x, z, t) -> same height everywhere.
local Waves = {}

type Wave = { dirX: number, dirZ: number, amplitude: number, wavelength: number, speed: number }

local WAVES: { Wave } = {
	{ dirX = 1, dirZ = 0, amplitude = 0.8, wavelength = 60, speed = 12 },
	{ dirX = 0.6, dirZ = 0.8, amplitude = 0.4, wavelength = 25, speed = 8 },
	{ dirX = -0.3, dirZ = 0.95, amplitude = 0.15, wavelength = 9, speed = 5 },
}

Waves.SeaLevel = 0

function Waves.heightAt(x: number, z: number, t: number): number
	local h = Waves.SeaLevel
	for _, w in WAVES do
		local k = 2 * math.pi / w.wavelength
		local phase = k * ((x * w.dirX + z * w.dirZ) - w.speed * t)
		h += w.amplitude * math.sin(phase)
	end
	return h
end

-- Use the shared clock so all machines agree on t.
function Waves.now(): number
	return workspace:GetServerTimeNow()
end

return Waves
```

The float controller, run by whichever machine owns the boat (the driver's client, or the server when nobody drives):

```lua
--!strict
-- Float controller for one boat. Call :step() from PreSimulation on the owner.
local Waves = require(game:GetService("ReplicatedStorage").Shared.Waves)

local Float = {}
Float.__index = Float

export type FloatPoint = { attachment: Attachment, force: VectorForce }

export type Boat = typeof(setmetatable({} :: {
	root: BasePart,
	points: { FloatPoint },
	k: number,
	damping: number,
	maxDepth: number,
	forwardDrag: number,
	sideDrag: number,
}, Float))

function Float.new(root: BasePart, attachments: { Attachment }, draft: number,
	dampingRatio: number): Boat
	local mass = root.AssemblyMass
	local g = workspace.Gravity
	local n = #attachments
	local k = mass * g / (n * draft)
	local perPointMass = mass / n
	local points: { FloatPoint } = {}
	for _, a in attachments do
		local vf = Instance.new("VectorForce")
		vf.Attachment0 = a
		vf.RelativeTo = Enum.ActuatorRelativeTo.World
		vf.ApplyAtCenterOfMass = false
		vf.Force = Vector3.zero
		vf.Parent = a.Parent
		table.insert(points, { attachment = a, force = vf })
	end
	return setmetatable({
		root = root,
		points = points,
		k = k,
		damping = dampingRatio * 2 * math.sqrt(k * perPointMass),
		maxDepth = draft * 2.5,
		forwardDrag = perPointMass * 0.2,
		sideDrag = perPointMass * 3.0, -- keel: resist sideways much more
	}, Float)
end

function Float.step(self: Boat)
	local t = Waves.now()
	local cf = self.root.CFrame
	local fwd = cf.LookVector
	local right = cf.RightVector
	for _, p in self.points do
		local pos = p.attachment.WorldPosition
		local depth = Waves.heightAt(pos.X, pos.Z, t) - pos.Y
		if depth <= 0 then
			p.force.Force = Vector3.zero
		else
			local d = math.min(depth, self.maxDepth)
			local v = self.root:GetVelocityAtPosition(pos)
			local lift = self.k * d - self.damping * v.Y
			local drag = -fwd * v:Dot(fwd) * self.forwardDrag
				- right * v:Dot(right) * self.sideDrag
			p.force.Force = Vector3.new(0, math.max(lift, 0), 0) + drag
		end
	end
end

function Float.destroy(self: Boat)
	for _, p in self.points do
		p.force:Destroy()
	end
	table.clear(self.points)
end

return Float
```

Remarks:

- Calibrate with the hull **dense enough not to float on its own** if it sits in terrain water, or the two buoyancies add up and the boat rides high.
- `maxDepth` clamps the force when a wave buries the bow. Without it, a nose-dive produces a huge spike and the boat launches.
- `math.max(lift, 0)` stops the damping term from pulling the hull down into the water on a fast rise.
- Visual waves must use the same `Waves.heightAt` (an `EditableMesh` plane, a grid of bones on a skinned plane, or a scrolling texture that roughly matches). If the rendered water and the physical water disagree, boats appear to float in the air. When exact match is too expensive, keep amplitudes small; players forgive a few tenths of a stud.

---

## 4. Moving: thrust, rudder and the keel

### Why boats slide

Without anisotropic drag, a boat is a puck on ice: turning rotates the hull but the velocity keeps going the old way. The `sideDrag` in the float controller is the keel. A ratio of 10:1 to 20:1 between side and forward drag feels like a boat; 3:1 feels like a hovercraft (rule of thumb). Racing jet skis often want 5:1 so they can powerslide.

### Thrust

Apply thrust with a `VectorForce` at a stern attachment, `RelativeTo = Attachment0`, force along the attachment's forward axis, scaled by throttle. Only apply it when the propeller point is under water (a depth check at that attachment, or a `BuoyancySensor` on a small propeller part). Boats that keep thrusting while airborne off a wave feel wrong immediately.

Top speed is where thrust equals forward drag. With linear drag `c`, `vmax = thrust / c`; with quadratic drag it is `sqrt(thrust / c)`. Linear drag is simpler to tune; quadratic drag feels more natural at high speed. Pick one and compute the thrust from the top speed you want instead of guessing.

### Steering

Two common options:

- **Rudder torque.** A `Torque` about the boat's up axis, scaled by steering input **and by forward speed**. A real rudder does nothing at a standstill. Clamp it with a maximum so high speed does not spin the hull.
- **Thrust vectoring.** Rotate the thrust direction a few degrees left or right. Works at low speed, which suits small craft.

Read input the same way as cars: a `VehicleSeat`'s `ThrottleFloat` and `SteerFloat` on the driver's client give keyboard, gamepad and touch for free (**Docs**: `Throttle`/`Steer` integers are deprecated).

### Staying upright

Real hulls self-right because buoyancy acts at the centre of the submerged volume, which moves sideways when the hull rolls. Float points reproduce this if they are wide enough apart. A ship with points only along the centreline has no roll stiffness and capsizes. If players can climb the mast and tip the ship, add a weak `AlignOrientation` (`PrimaryAxisParallel` to world up, low `MaxTorque`).

---

## 5. Players on a moving deck

This is the boat problem that sinks most ship games.

A player's character is simulated by their own client. The ship, if owned by the captain's client, arrives at everyone else's machine through replication, interpolated and slightly late. So a passenger's client simulates their character standing on a deck that is being moved by snapshots. The character's feet are on a surface that teleports a little every update; friction does not carry them smoothly; they slide, jitter and sometimes fall through on big waves.

Options, best first:

1. **Seats for the people who matter.** Crew positions as `Seat`s. Seated characters are welded into the ship's assembly and move with it exactly. Fine for small boats.
2. **Platform-relative movement on each client.** Each frame, if the local character is standing on the ship (cast down from the root, check the hit is a ship part), compute the ship's CFrame change since last frame and apply the same change to the character's root before physics. This is the classic "moving platform" technique and makes walking on a deck feel solid. It must run on the passenger's client in `PreSimulation`.
3. **Server-owned ship.** Every client, including the captain, sees the ship replicated. Passengers no longer fight the captain's simulation, but the captain's steering now has a round-trip delay. Large, slow ships tolerate this well; fast boats do not.
4. **Kinematic ship.** Anchor the ship and move it by `PivotTo` on a fixed timestep on the server, with clients smoothing. No physics fighting at all, at the cost of no physical collisions for the ship. Common for huge ships whose motion is mostly scripted anyway.

A sketch of option 2:

```lua
--!strict
-- LocalScript: carry the local character with the ship it stands on.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local lastShip: BasePart? = nil
local lastShipCf: CFrame = CFrame.identity

RunService.PreSimulation:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if character == nil or root == nil then
		lastShip = nil
		return
	end
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params)
	local shipRoot: BasePart? = nil
	if hit then
		local model = hit.Instance:FindFirstAncestorWhichIsA("Model")
		if model and CollectionService:HasTag(model, "Ship") then
			shipRoot = hit.Instance.AssemblyRootPart
		end
	end
	if shipRoot and shipRoot == lastShip then
		local delta = shipRoot.CFrame * lastShipCf:Inverse()
		root.CFrame = delta * root.CFrame
	end
	lastShip = shipRoot
	lastShipCf = if shipRoot then shipRoot.CFrame else CFrame.identity
end)
```

Edge cases: jumping (keep carrying for a short time after leaving the deck, or the deck moves out from under the player mid-air), ladders, and the moment of boarding (first frame has no previous CFrame, which the code handles by requiring the same ship two frames running). Movement anti-cheat on the server must know about ships, or every passenger looks like a speed hacker ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]).

---

## 6. Ownership and security

- **Driver owns the boat** while driving, set on the seat's `Occupant` change exactly as for cars ([[Cars with Constraints - Suspension Steering and Drive]], section 6; the pattern comes from the Docs' network ownership page). Hand loose cargo on deck to the same owner, as the Docs advise for vehicles.
- **Nobody driving:** server ownership, and the server runs the float controller for that boat. If you have many idle boats, anchor them at sea level and switch the float controller off; nobody can tell a calm anchored boat from a floating one.
- **The wave function must be shared**, otherwise the server's validation, the captain's simulation and passengers' visuals disagree. Using `workspace:GetServerTimeNow()` as the clock keeps every machine on the same phase.
- **Validate** like any client-owned vehicle: top speed with margin, position over water (a boat on land is either a glitch or an exploit), map bounds, and distance per check. Boats legitimately jump off waves, so give vertical checks a generous allowance.

---

## 7. Performance

- Float points cost one function call each per step on the owner, plus one replicated assembly. Ten boats with eight points each is trivial.
- Raycasting for water height per point is heavier than a function; prefer a function when the water is a plane or waves.
- `VectorForce` instances are cheap; create them once and update `Force`, never create per frame.
- Wave visuals are usually the real cost. A large animated mesh updated every frame on mobile is expensive; update only near the camera and at reduced rate, and fall back to a static plane on low-end devices ([[Mobile and Low-End Optimization]]).

---

## 8. When not to do this

- **Decor boats** that bob in a harbour: tween them on the client. Nobody touches them.
- **A lake players never boat on:** terrain water for looks and swimming, no scripts.
- **Huge ships with crews of 20:** a kinematic, server-driven ship (option 4 in section 5) usually beats physics, because the deck must be rock solid for walking and fighting.

---

## 9. Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Light hull in terrain water plus float points | Boat rides high, bounces out of the water | Make the hull sink on its own, or drop the float points |
| Same drag in all directions | Boat slides sideways in turns | Side drag 10 to 20 times forward drag |
| No depth clamp | Boat launches after a nose-dive | `maxDepth` clamp |
| Float points on the centreline only | Capsizes at a touch | Spread points to the hull's width |
| Waves using `os.clock()` | Every client sees different waves | `workspace:GetServerTimeNow()` |
| Rendered waves differ from physical | Boats hover or sink visually | One shared height function |
| Thrust while airborne | Boats accelerate in the air | Only thrust when the propeller is wet |
| Passengers walking on a client-owned ship | Sliding, jitter, falling through | Seats, platform carry, or server-owned ship |
| Anti-cheat unaware of ships | Passengers flagged for speed | Subtract ship velocity before checks |

## Checklist

- [ ] Chosen engine buoyancy or float points per boat type, with a reason.
- [ ] `k` computed from mass, gravity, point count and draft; bob frequency checked.
- [ ] Damping ratio 0.5 to 0.7; depth clamp set.
- [ ] Side drag much higher than forward drag.
- [ ] Shared deterministic wave function on server time; visuals use it.
- [ ] Driver owns while driving; server or anchored when idle.
- [ ] Passenger strategy chosen and tested with 3+ clients on rough water.
- [ ] Server checks for speed, land, bounds; ship-aware movement checks.

## See also

[[Physics and Vehicles Start Here]] · [[Terrain Deep Dive - Materials Water and Performance]] · [[Water Sky and Atmosphere Art]] · [[Physics Assemblies and Constraints]] · [[Mover Constraints and Physics Controllers]] · [[Network Ownership]] · [[Cars with Constraints - Suspension Steering and Drive]] · [[Aircraft and Flight Models]] · [[Springs Damping and Smoothing]] · [[Custom Character Controllers]]

## Connected notes
<!-- auto-links:start -->
[[Genre Playbook - Racing and Driving]] · [[Debugging Physics and Network Ownership]] · [[Terrain Tools and Terrain API]] · [[Racing Laps and Checkpoints End to End]] · [[Links - Constraints]] · [[Links - Forces and movers]]
<!-- auto-links:end -->
