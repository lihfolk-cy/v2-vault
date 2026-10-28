---
tags: [physics, constraints, ropes, chains, soft-bodies, verlet, bones, procedural]
---
# Ropes Chains and Soft Bodies

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Expecting RopeConstraint to collide or wrap -> Accept it, or visual verlet with collision
> - Avoid: Negative WinchSpeed to reel out -> Positive speed, change `WinchTarget` (Docs)
> - Avoid: Winch force below weight -> `WinchForce > mass * g` with headroom
> - Each rope or soft thing classified: physics (carries load) or visual (client only).
> - RopeConstraint uses: restitution chosen, winch force above weight, explicit ownership.
> - Physical chains: few fat links, matched masses, no self-collision, limits on.
>
> Read more (18 KB note): ## 4. Client-side verlet: ropes and cloth for free · ## 7. Worked example: a grappling hook · ## 8. Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox has a `RopeConstraint`, and it is not a rope. It is a maximum-distance limit between two attachments with a visual line drawn between them. That is exactly what you want for a grappling hook or a tethered balloon, and exactly wrong for a rope that drapes over a branch, a chain that swings links against a wall, a flag, a jiggly slime or a bridge that sags under players. This note covers what the built-in rope does and does not do, physical chains built from parts, client-side verlet ropes and cloth that cost almost nothing, bone-driven soft bodies on skinned meshes, the grappling hook as a worked example, and which approach to pick for each job.

Prerequisites: [[Physics Assemblies and Constraints]] (constraint basics), [[Bones and Skinned Meshes]] (for section 5), [[Springs Damping and Smoothing]].

Source labels: **Docs** (Roblox docs, as of October 2026), **Rule of thumb**. Code is strict Luau, **reviewed, not run**.

---

## 1. Pick the approach by job

| Job | Best approach | Why |
|---|---|---|
| Grapple, tether, leash, wrecking ball | `RopeConstraint` | Real physics force, one constraint, winch built in |
| Swinging bridge players walk on | Physical chain of planks with hinges or ball sockets | Must carry characters |
| Hanging chain that hits things | Physical chain (few links) | Collisions matter |
| Decorative rope, power line, vine | `Beam` with curve, or client verlet | No physics needed |
| Rope that drapes and wraps around objects (visual) | Client verlet with collision against a few shapes | Constraints cannot wrap |
| Cape, flag, scarf, cloth | Client verlet on bones of a skinned mesh | Thousands of cheap points, smooth deformation |
| Jiggle (hair, tails, slimes, bellies) | Spring-driven bones | Cheap, stylised, stable |
| Soft body that physically deforms on collision | Usually do not; fake it | Engine has no soft-body solver; spring networks of parts are unstable and expensive |

The key split: **does the rope need to push on the world or carry weight?** Then it is physics, and it costs. If it only needs to look right, it is a client-side visual and costs nearly nothing.

---

## 2. RopeConstraint: what it really is

From the Docs:

- `Length` is the **maximum** distance between the attachments. They "can move closer together than this length and both can freely rotate". So a rope pulls, never pushes. That is correct rope behaviour.
- `Restitution` (0 to 1) controls how elastic the stop is when the rope reaches full length.
- `Thickness` is purely visual.
- The winch: `WinchEnabled`, `WinchTarget` (the length it reels toward), `WinchSpeed` (must be positive; a negative value is treated as 0 and does **not** reverse the motor), `WinchForce` (maximum force) and `WinchResponsiveness`.
- `CurrentDistance` reports the current distance between the attachments.

What it does not do (rule of thumb, consistent with the Docs' description): the rope line does not collide with anything. A rope from a hook on a ceiling to a player will pass straight through a beam between them. It cannot wrap around a pole. It has no mass of its own and no sag; the drawn line is a visual curve, not simulated segments.

### Tuning notes

- **Mass ratio.** A heavy wrecking ball on a rope tied to a light, unanchored crane will drag the crane. Anchor the anchor point or make the crane much heavier ([[Debugging Physics and Network Ownership]], mass mismatch).
- **Restitution at 0** for grapples and leashes. At high restitution the swinging object bounces at the end of the rope and players feel yanked.
- **Winch force** must exceed the weight it lifts: at least `mass * workspace.Gravity`, with headroom for acceleration. A winch that "does nothing" is usually under-powered.
- **Ownership.** If a player drags something on a rope, both ends should be owned by that player (they form one mechanism); otherwise the rope fights across the network. Set it explicitly ([[Network Ownership]]).

`RodConstraint` is the rigid cousin (fixed distance, pushes and pulls), and `SpringConstraint` is the stretchy one (pulls toward a free length). A bungee is a `SpringConstraint` with limits, not a rope.

---

## 3. Physical chains

Build a chain of small parts joined by `BallSocketConstraint`s (or hinges for planks that should only swing one way). It collides, carries weight and interacts with players.

Rules of thumb that make chains stable:

- **Few, fat links.** 8 to 15 links, not 60. Each link is a body and each joint is a constraint the solver must satisfy; long chains of small, light links are the textbook unstable case and jitter or explode.
- **Equal masses.** Keep neighbouring links within about a factor of 10 of each other in mass. A heavy weight on the end of a chain of feather-light links is unstable; make links heavier or put a `RopeConstraint` from the anchor to the end weight as a "safety" limit so the chain cannot over-stretch.
- **No self-collision.** Neighbouring links should not collide with each other (put links in a collision group that does not collide with itself). Overlapping colliders at a joint are a constant fight.
- **Ball-socket limits** (`LimitsEnabled`, `UpperAngle`, twist limits) reduce wild motion on bridges.
- **Anchor ends** on bridges. A bridge with both ends anchored and 10 to 20 hinged planks is stable for many players. Planks should be wide and light enough that a character's weight bends the bridge a little, not so light that one jump launches it.

### Rope bridges and players

Characters standing on a moving physical bridge are simulated by their own clients while the bridge is server-owned (or owned by whichever client is closest, if left automatic). Each player pushes the bridge on their own screen while seeing others' pushes late, so bridges can jitter with several players on them. Set the bridge to server ownership so all players see the same bridge, and accept slight lag in how it reacts. For long bridges in busy areas, consider an anchored bridge animated on clients (a sine sag that responds to nearby characters) instead of physics. Nobody can tell from a few metres away.

---

## 4. Client-side verlet: ropes and cloth for free

Verlet integration is the standard way games simulate ropes and cloth visually. Each point stores its current and previous position; velocity is implied by the difference. Each step:

1. Move each free point: `new = pos + (pos - prev) * damping + gravity * dt^2`.
2. Repeat a few times (iterations): for every link between two points, push them apart or together so their distance equals the rest length.
3. Optionally, push points out of a few collision shapes (spheres, the ground plane).

It is unconditionally stable (points can never explode), extremely cheap, and needs no physics bodies at all. Render the points as `Beam`s between attachments, as thin parts, or as the bones of a skinned mesh.

```lua
--!strict
-- Client-only verlet rope rendered with Beams between Attachments.
local RunService = game:GetService("RunService")

local Rope = {}
Rope.__index = Rope

export type Rope = typeof(setmetatable({} :: {
	points: { Vector3 },
	prev: { Vector3 },
	pinned: { [number]: Attachment }, -- point index -> world anchor attachment
	segmentLength: number,
	iterations: number,
	attachments: { Attachment },
	beams: { Beam },
	conn: RBXScriptConnection?,
}, Rope))

local GRAVITY = Vector3.new(0, -workspace.Gravity * 0.5, 0) -- visual gravity, tuned
local DAMPING = 0.98

function Rope.new(startAtt: Attachment, endAtt: Attachment, count: number,
	slack: number, holder: BasePart): Rope
	local a = startAtt.WorldPosition
	local b = endAtt.WorldPosition
	local total = (b - a).Magnitude * slack
	local points: { Vector3 } = table.create(count)
	local prev: { Vector3 } = table.create(count)
	local atts: { Attachment } = table.create(count)
	for i = 1, count do
		local p = a:Lerp(b, (i - 1) / (count - 1))
		points[i] = p
		prev[i] = p
		local att = Instance.new("Attachment")
		att.WorldPosition = p
		att.Parent = holder -- holder: an anchored, invisible part at the origin
		atts[i] = att
	end
	local beams: { Beam } = {}
	for i = 1, count - 1 do
		local beam = Instance.new("Beam")
		beam.Attachment0 = atts[i]
		beam.Attachment1 = atts[i + 1]
		beam.Width0 = 0.2
		beam.Width1 = 0.2
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Parent = holder
		table.insert(beams, beam)
	end
	return setmetatable({
		points = points,
		prev = prev,
		pinned = { [1] = startAtt, [count] = endAtt },
		segmentLength = total / (count - 1),
		iterations = 6,
		attachments = atts,
		beams = beams,
		conn = nil,
	}, Rope)
end

function Rope.step(self: Rope, dt: number)
	local pts, prev = self.points, self.prev
	local dt2 = dt * dt
	for i, p in pts do
		local anchor = self.pinned[i]
		if anchor then
			pts[i] = anchor.WorldPosition
			prev[i] = pts[i]
		else
			local vel = (p - prev[i]) * DAMPING
			prev[i] = p
			pts[i] = p + vel + GRAVITY * dt2
		end
	end
	local L = self.segmentLength
	for _ = 1, self.iterations do
		for i = 1, #pts - 1 do
			local p1, p2 = pts[i], pts[i + 1]
			local delta = p2 - p1
			local dist = delta.Magnitude
			if dist > 1e-6 then
				local diff = (dist - L) / dist
				local pin1 = self.pinned[i] ~= nil
				local pin2 = self.pinned[i + 1] ~= nil
				if pin1 and not pin2 then
					pts[i + 1] = p2 - delta * diff
				elseif pin2 and not pin1 then
					pts[i] = p1 + delta * diff
				elseif not pin1 and not pin2 then
					pts[i] = p1 + delta * (diff * 0.5)
					pts[i + 1] = p2 - delta * (diff * 0.5)
				end
			end
		end
	end
	for i, att in self.attachments do
		att.WorldPosition = pts[i]
	end
end

function Rope.start(self: Rope)
	self.conn = RunService.PreRender:Connect(function(dt: number)
		self:step(math.min(dt, 1 / 30)) -- clamp: a long frame must not fling the rope
	end)
end

function Rope.destroy(self: Rope)
	if self.conn then
		self.conn:Disconnect()
	end
	for _, b in self.beams do
		b:Destroy()
	end
	for _, a in self.attachments do
		a:Destroy()
	end
end

return Rope
```

Notes:

- `PreRender` runs before the frame is drawn, which is where visual-only simulation belongs. Physics-affecting code goes in `PreSimulation`.
- The `dt` clamp matters: after a hitch, a 0.5 s step makes verlet ropes whip violently.
- Iterations trade stiffness for cost. 4 to 10 is typical; more makes the rope less stretchy.
- **Collision:** after the constraint loop, for each point, if it is inside a sphere (centre `c`, radius `r`), push it to `c + (p - c).Unit * r`. A handful of spheres (character root, a pole) is cheap. Raycasting every point every frame is not; if you need world collision, raycast from `prev` to `pos` for a few points only, at reduced rate.
- Sixty points across ten ropes is trivial. A few thousand points per frame is still fine in Luau if the code avoids allocations (Vector3 is a value type in Luau, so the maths above does not create garbage).
- Only simulate ropes near the camera. Freeze or hide distant ones.

### Cloth

Cloth is the same algorithm on a grid: each point links to its right and lower neighbours (structural), optionally diagonals (shear) and two-apart neighbours (bending). Pin the top row to a character's back or a flagpole. Render it by driving the bones of a skinned plane mesh, one bone per point (section 5). A 6 x 8 cape is 48 points, around 150 links, and costs well under a millisecond per frame (rule of thumb; profile on your lowest target device with the [[MicroProfiler Guide]]).

Wind: add a small force per point along `workspace.GlobalWind`, varied with a noise function (`math.noise`). The Docs describe `GlobalWind` as the wind direction and strength for the experience; reading it keeps your cloth consistent with grass and particles.

---

## 5. Bones: the rendering half of soft bodies

A `MeshPart` with a skinned mesh deforms when its `Bone` instances move. Setting `Bone.WorldCFrame` or `Bone.Transform` from a script on the client moves the mesh smoothly, with no physics cost. This is how capes, tails, hair strands, jelly and flags are rendered in most polished Roblox games.

- **Verlet-driven bones** (capes, flags, ropes with thickness): one bone per simulated point; each frame set each bone's position and orient it toward the next point.
- **Spring-driven bones** (jiggle): each bone has a rest offset from its parent; a spring pulls the bone toward the rest pose and a damper slows it. When the parent moves fast, the bone lags and wobbles. One spring per bone, a few lines of maths ([[Springs Damping and Smoothing]]).
- Keep bone counts modest on mobile and update only for characters near the camera. Distant characters can skip the simulation and hold the rest pose.

Bone rigs, skinning and weight painting are covered in [[Bones and Skinned Meshes]] and [[Weight Painting and Skinning for Roblox]]. Procedural secondary motion in general is in [[Procedural Animation]].

### Is it networked?

No, and it should not be. Each client simulates capes and ropes locally from the replicated character motion. Two players see slightly different cape folds; nobody can tell. Never replicate per-point positions.

---

## 6. Physical soft bodies: mostly, do not

Roblox has no soft-body solver. People build "soft bodies" from a lattice of small parts joined by `SpringConstraint`s. It works in a demo and fails in a game:

- Dozens to hundreds of bodies and constraints for one jelly: heavy on physics.
- Springs between small light parts need stiffness high enough to hold shape, which is exactly the regime where the solver becomes unstable.
- Ownership: every lattice part replicates.

What to do instead:

- **Fake the deformation, keep a rigid collider.** A single rigid part (or a small assembly) does the physics. The visual is a skinned mesh whose bones are spring-driven from the collider's acceleration and contacts. A slime that squashes on landing is a scale animation on landing (stretch on the way up, squash on impact), not a lattice.
- **Scripted deformation on impact.** On a hit, push nearby bones in along the hit direction and let springs restore them. Cheap, controllable, reads as soft.
- If a lattice is truly the game (a physics toy), keep it to under 30 parts, server-owned, with moderate stiffness and real damping, and test the worst case: a player standing on it while it is pushed into a wall.

---

## 7. Worked example: a grappling hook

A grapple is a projectile followed by a rope.

1. **Fire.** The client casts from the camera along the aim (a simulated projectile, [[Projectiles and Ballistics]]). On hit, it asks the server to attach, sending the hit position and the hit part.
2. **Validate.** The server checks range (distance from character to hit point), line of sight (cast from the character to the point), cooldown, and that the hit part is grappleable (a tag or attribute). Never let the client attach to arbitrary parts, or exploiters grapple to other players and drag them.
3. **Attach.** Create an `Attachment` at the hit point on the target part, and a `RopeConstraint` from the character's root attachment to it, `Length` set to the current distance, `Restitution = 0`. If the target is anchored, nothing else is needed. If it is unanchored, decide who owns it: grappling another player's part is a common exploit path for flinging, so typically only allow anchored targets.
4. **Reel.** Enable the winch with `WinchTarget` a few studs, `WinchSpeed` your reel speed, and a `WinchForce` above `characterMass * workspace.Gravity * 2` so it can lift the player. Because the player's character is client-owned, the pull is simulated on their client and replicates naturally.
5. **Swing.** With the winch off, the rope limits distance and gravity does the swinging. Add a small `VectorForce` from move input on the client for air control. The Humanoid's own state machine may fight this; keep the character in the `Freefall` state or use the approaches in [[Mover Constraints and Physics Controllers]] section 6.
6. **Release.** Destroy the rope and the anchor attachment; preserve velocity (the player keeps their swing momentum, which is the fun part).
7. **Visual.** The rope's own line is fine. For a nicer look, hide it (`Visible = false`) and draw a verlet rope with slack when the rope is not taut (`CurrentDistance < Length`) and a straight beam when it is.

Server movement checks must allow grapple speeds while a grapple is active ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]]).

---

## 8. Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Expecting RopeConstraint to collide or wrap | Rope passes through beams and poles | Accept it, or visual verlet with collision |
| Negative WinchSpeed to reel out | Winch stops instead of reversing | Positive speed, change `WinchTarget` (Docs) |
| Winch force below weight | Winch does nothing | `WinchForce > mass * g` with headroom |
| Chain of 60 tiny links | Jitter, explosions | 8 to 15 fat links, similar masses |
| Links collide with neighbours | Constant shaking | Non-self-colliding group |
| Physics for decorative ropes | Server physics and bandwidth for scenery | Beams or client verlet |
| No dt clamp on verlet | Ropes whip after a hitch | Clamp to 1/30 s |
| Replicating cloth points | Bandwidth waste, jitter | Client-local simulation |
| Spring-lattice soft bodies in production | Unstable, expensive | Rigid collider + spring bones |
| Client-chosen grapple targets unvalidated | Players grapple and fling others | Server range, LOS, tag checks |

## Checklist

- [ ] Each rope or soft thing classified: physics (carries load) or visual (client only).
- [ ] RopeConstraint uses: restitution chosen, winch force above weight, explicit ownership.
- [ ] Physical chains: few fat links, matched masses, no self-collision, limits on.
- [ ] Verlet ropes and cloth: client-side, dt clamped, iterations tuned, distant ones frozen.
- [ ] Soft bodies faked with spring-driven bones on a rigid collider.
- [ ] Grapple validated on the server: range, line of sight, allowed targets, cooldown.
- [ ] Profiled with the worst case on a phone.

## See also

[[Physics and Vehicles Start Here]] · [[Physics Assemblies and Constraints]] · [[Mover Constraints and Physics Controllers]] · [[Springs Damping and Smoothing]] · [[Bones and Skinned Meshes]] · [[Weight Painting and Skinning for Roblox]] · [[Procedural Animation]] · [[Ragdolls and Physics-Based Animation]] · [[Beams and Trails]] · [[Projectiles and Ballistics]] · [[Destruction and Fracture]] · [[Network Ownership]]

## Connected notes
<!-- auto-links:start -->
[[Links - Constraints]] · [[Multi-Bone IK - FABRIK and CCD]] · [[Cars with Constraints - Suspension Steering and Drive]] · [[Links - Beams and trails]] · [[Squash Stretch and Anticipation in UI and Characters]] · [[Rigging in Blender]]
<!-- auto-links:end -->
