---
tags: [physics, vehicles, rides, roller-coaster, zipline, elevator, cable-car, splines, type/guide, area/physics, level/intermediate, api/PrismaticConstraint, api/GetServerTimeNow, api/AlignPosition]
---
# Rides and Attractions - Roller Coasters, Ziplines, Elevators and Cable Cars

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Tweening an anchored platform on the server -> Server-owned physics mover
> - Avoid: Replicating the coaster pose every frame -> Shared clock, local pose
> - Avoid: Using `os.time()` or `tick()` for ride time -> `workspace:GetServerTimeNow()`
> - Each ride's driver chosen: clock, server physics, or rider client.
> - Schedules stored as `DepartAt` server time; speed profile is a shared pure function.
> - Standing rides are unanchored, server-owned, with limits and sized force.
>
> Cost: TL;DR ~160 tok · whole note ~2.2k tok. Read more: ## 2. Coasters on a shared clock · ## 3. Elevators that people stand in · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Theme-park and hangout games are full of things that carry players along a fixed path: coasters, ziplines, elevators, gondolas, trams. None of them need a tyre model, and almost all of them break in the same three ways: they jitter for everyone except the server, riders slide off or fall through, and the ride state desyncs between servers or after a rejoin. The fix is choosing the right driver for the ride (shared clock on clients, a server-owned physics mover, or the rider's own client) and attaching riders in a way the engine actually supports. Path maths lives in [[Curves in Luau - Paths Beams and Motion]]; this note is the ride layer.

Source labels: **Roblox docs** (create.roblox.com, checked October 2026), **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

---

## 1. Pick the driver per ride

| Ride | Best driver | Why |
|---|---|---|
| Roller coaster, tram, ghost train (seated, no interaction) | **Shared clock**: each client computes the train pose from server time | Perfectly smooth, zero per-frame bandwidth |
| Elevator, lift platform, ferry players stand on | **Server-owned physics** (`PrismaticConstraint` servo or `AlignPosition`) | Humanoids standing on simulated parts inherit platform motion |
| Zipline, grind rail, rope swing | **Rider's own client** moves its own character | Character is already client-owned; no handoff |
| Gondola / cable car with closed cabins | Shared clock (seated) or server physics (standing) | Same rule: seated or standing |

The single most common mistake: tweening an **anchored** platform on the server with `TweenService` and expecting standing players to ride it. Anchored parts moved by CFrame have no physical velocity for characters to inherit, and server-side CFrame updates arrive at network rate, so players jitter, slide and fall. Use physics for anything people stand on ([[Mover Constraints and Physics Controllers]]).

## 2. Coasters on a shared clock

The server owns the *schedule*, not the pose. It sets `DepartAt` (from `workspace:GetServerTimeNow()`, Roblox docs: https://create.roblox.com/docs/reference/engine/classes/Workspace) as an attribute on the ride when the train leaves. Every client evaluates the same arc-length-parameterised spline at `GetServerTimeNow() - DepartAt` and pivots its **local** train copy.

```lua
--!strict
-- Client. RideModel is a local clone; Track exposes sampleAt(distance): CFrame and Length.
local RunService = game:GetService("RunService")

type Track = { Length: number, sampleAt: (number) -> CFrame }

local function runRide(ride: Instance, train: Model, track: Track, speedProfile: (number) -> number)
	RunService.PreRender:Connect(function()
		local departAt = ride:GetAttribute("DepartAt") :: number?
		if not departAt then return end
		local elapsed = workspace:GetServerTimeNow() - departAt
		if elapsed < 0 then return end
		local distance = math.min(speedProfile(elapsed), track.Length)
		train:PivotTo(track.sampleAt(distance))
	end)
end
```

- `speedProfile` maps time to distance and is the same pure function on every machine (precompute a table: lift hill at constant speed, then energy-based speed `v = sqrt(v0^2 + 2 * g * drop)` with a friction term). Same input, same pose.
- **Riders**: the server seats riders in the server-side train (anchored, parked at the station). Once the ride departs, each rider's own client, which owns its character, pins its character to its seat on the *local* train every frame. Other players see riders slightly behind the locally rendered train by their latency. Rule of thumb: hide that by locking riders into a sit pose and accepting a small offset, or render other riders as local ghost copies driven by seat index. For tight coasters the ghost approach looks best.
- Late joiners and rejoins work for free: they read `DepartAt` and land at the right point.
- Server still validates: riders are released (teleported to the exit) when `elapsed` passes the ride duration, whatever the client did.

## 3. Elevators that people stand in

Use an unanchored car on a `PrismaticConstraint` in servo mode: `ActuatorType = Servo`, then set `TargetPosition`, `Speed` and `ServoMaxForce` (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/PrismaticConstraint). The shaft side is anchored; call `car:SetNetworkOwner(nil)` on the cab so the server simulates it and every client sees the same smooth, interpolated motion.

- `ServoMaxForce` must exceed the cab's weight plus the heaviest crowd (characters standing on it add load). Undersize it and the cab sags under a full lobby. Rule of thumb: 2 to 3 times the loaded weight.
- Limits: enable `LimitsEnabled` with `LowerLimit`/`UpperLimit` matching the shaft so an exploited or glitched target cannot fling the cab.

**Queue logic** for multi-floor lifts: keep a set of requested floors and a direction; serve all requests in the current direction, then reverse (the SCAN or "elevator" algorithm). Open doors (another prismatic or a client-side tween on a non-colliding visual plus a collision part toggled by the server) only when the cab's `CurrentPosition` is within 0.05 studs of the floor target and velocity is near zero.

## 4. Ziplines and rails

The rider's client owns its character, so the zipline is a client-side controller with server bookends:

1. Server: a `ProximityPrompt` at the top validates distance, sets `ZipActive` on the player with the line id and start time.
2. Client: anchors nothing; drives the HumanoidRootPart along the line with an `AlignPosition` + `AlignOrientation` attached to the root, or a `LinearVelocity` along the line direction, and plays a hang animation. Release on jump or at the end.
3. Server: expects arrival near the end after roughly `length / speed` seconds. Earlier arrival, or being far off the line while `ZipActive`, feeds your movement-exploit checks ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]).

Give the rider a short velocity carry-over on release (the line's direction times exit speed) so dismounts feel continuous.

## 5. Cable cars and gondolas

Closed, seated cabins: use the coaster pattern (shared clock, cabins evenly spaced in distance along a looping path, `distance = (elapsed * speed + i * spacing) % length`). Open cabins people stand in: a server-owned unanchored cabin driven by `AlignPosition` and `AlignOrientation` toward the clock-computed target, so humanoids inherit the motion. Set `AlignPosition.MaxForce` high but finite and `Responsiveness` around 20 to 40 so the cabin tracks without overshoot. Rule of thumb.

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Tweening an anchored platform on the server | Players slide off and jitter | Server-owned physics mover |
| Replicating the coaster pose every frame | Choppy train, bandwidth spike | Shared clock, local pose |
| Using `os.time()` or `tick()` for ride time | Clients disagree by seconds | `workspace:GetServerTimeNow()` |
| Elevator servo force too low | Cab sinks when full | Size force for crowd load; limits on |
| Zipline fully server-driven | Rider rubber-bands | Rider's client drives, server checks timing |
| Parametric `t` instead of arc length | Train speeds up on tight bends | Arc-length table for the spline |

## Checklist

- [ ] Each ride's driver chosen: clock, server physics, or rider client.
- [ ] Schedules stored as `DepartAt` server time; speed profile is a shared pure function.
- [ ] Standing rides are unanchored, server-owned, with limits and sized force.
- [ ] Riders released by the server at ride end regardless of client state.
- [ ] Zipline timing and path checked on the server.
- [ ] Tested with late join, two clients and a full cab.

## See also

[[Curves in Luau - Paths Beams and Motion]] · [[Mover Constraints and Physics Controllers]] · [[Tween and CFrame Animation of Objects]] · [[Network Ownership]] · [[ProximityPrompt]] · [[Genre Playbook - Roleplay and Social Hangouts]] · [[Interpolation Easing and Curves Math]]

## Connected notes
<!-- auto-links:start -->
[[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · [[Physics Assemblies and Constraints]] · Bezier Curves and Splines for Modellers
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Standing on Moving Vehicles and Platforms - Keeping Players Glued]] · [[Cars with Constraints - Suspension Steering and Drive]] · [[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Racing AI on a Racing Line - Spline Following and Rubber-Banding]] · [[Centre of Mass, Anti-Flip and Self-Righting]]
<!-- related:end -->
