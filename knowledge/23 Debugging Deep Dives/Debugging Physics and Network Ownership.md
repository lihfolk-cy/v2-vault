---
tags: [debugging, physics, network-ownership, assemblies, jitter, flinging]
---
# Debugging Physics and Network Ownership

Physics bugs in Roblox look dramatic (players launched into the sky, NPCs vibrating, vehicles snapping back) and usually come from a small set of causes: the wrong machine simulating an assembly, an assembly that is not shaped the way you think, scripts fighting the solver, or collisions resolved with huge forces. This note is a diagnostic method: which tools show ownership and assemblies, how to log ownership over time, and a symptom-to-cause guide that goes past the short table in [[Network Ownership]].

The ownership rules and the security side are in [[Network Ownership]]; constraints in [[Physics Assemblies and Constraints]] and [[Mover Constraints and Physics Controllers]]; physics cost in [[Physics Performance]].

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. The two questions

Almost every physics bug is answered by two questions:

1. **What is the assembly?** Which parts move together (joined by welds, Motor6Ds, rigid constraints), which part is its root, what is its total mass, and is any part anchored?
2. **Who simulates it?** The server, one client, or nobody, and does that change over time?

Answer both before reading code. Many "my script is wrong" investigations end with "this part is welded to the character, so the player's client owns it".

---

## 2. Tools

### 2.1 Studio visualisation

| Tool | Shows | Source |
|---|---|---|
| Visualization options, **Network owners** (during a play test) | outline colour per owner: your client, buffer zone, server or other client, no owner | Docs ([[Network Ownership]] lists the colours) |
| Studio Settings, Physics: **Are Assemblies Shown** | each assembly in its own colour | Docs (`PhysicsSettings`) |
| Studio Settings, Physics: **Are Owners Shown** | ownership outlines (older equivalent of the visualization mode) | Docs (`PhysicsSettings`; mapping of each checkbox to the exact colour legend not confirmed, unverified) |
| Studio Settings, Physics: **Are Awake Parts Highlighted** | which parts are awake (simulating) vs asleep | Docs (`PhysicsSettings`, name as listed; behaviour summarised, unverified in detail) |
| Client/Server toggle | compare positions on each side | Docs |

In a multi-client test each client has its own ownership colour, and the server view shows all of them (Docs). Use at least two clients for any ownership bug: one client cannot show a hand-off.

### 2.2 Scripted inspection

There is no event for "network owner changed" (rule of thumb: none is documented as of October 2026), so poll. A small server-side watcher, run in a play test or gated live:

```lua
--!strict
-- Server: log ownership changes for tagged assemblies, at most every 0.25 s.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local last: { [BasePart]: string } = {}
local acc = 0

local function ownerName(part: BasePart): string
	if part.Anchored then
		return "anchored"
	end
	local ok, owner = pcall(function()
		return part:GetNetworkOwner()
	end)
	if not ok then
		return "error"
	end
	return if owner then owner.Name else "server"
end

RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then
		return
	end
	acc = 0
	for _, inst in CollectionService:GetTagged("WatchOwner") do
		if inst:IsA("BasePart") then
			local root = inst.AssemblyRootPart or inst
			local now = ownerName(root)
			if last[inst] ~= now then
				print(("[owner] %s: %s -> %s (auto=%s)"):format(
					inst:GetFullName(), last[inst] or "?", now,
					tostring(root:GetNetworkOwnershipAuto())))
				last[inst] = now
			end
		end
	end
end)

CollectionService:GetInstanceRemovedSignal("WatchOwner"):Connect(function(inst)
	if inst:IsA("BasePart") then
		last[inst] = nil
	end
end)
```

Tag the parts you care about (an NPC's root, a vehicle chassis) with `WatchOwner`. If you see the owner flip several times a second, you have ownership ping-pong.

Note: `GetNetworkOwner` and `GetNetworkOwnershipAuto` are server-only and error on anchored parts or parts welded to anchored ones (Docs describe `CanSetNetworkOwnership` returning a reason). The `pcall` keeps the watcher safe.

### 2.3 Assembly dump

```lua
-- Command bar (play test, server view): describe the assembly of the selected part.
local part = game.Selection:Get()[1]
local root = part.AssemblyRootPart
print("root", root and root:GetFullName())
print("mass", part.AssemblyMass, "linear vel", part.AssemblyLinearVelocity.Magnitude,
	"angular vel", part.AssemblyAngularVelocity.Magnitude)
local canSet, why = part:CanSetNetworkOwnership()
print("can set owner", canSet, why)
local count = 0
for _, p in part:GetConnectedParts(true) do
	count += 1
end
print("rigidly connected parts", count)
```

`GetConnectedParts(true)` returns parts connected through rigid joints recursively (Docs). If that number is far larger than you expect, something is welded that should not be (an NPC welded to a building piece, a tool welded to a door).

`game.Selection` works in the command bar in Studio; in the server view of a play test, select the part in the Explorer first.

---

## 3. Jitter and stutter

### 3.1 Ownership ping-pong

**Symptom:** an object near two players stutters, snaps back, or moves in steps. The watcher shows the owner flipping.

**Cause:** automatic ownership assigns the assembly to the nearest eligible client (Docs: based on proximity and other factors); when two players are at similar distances, it can change hands, and each hand-off causes a correction.

**Fix:** set an owner explicitly: `root:SetNetworkOwner(nil)` for server ownership (NPCs, shared props), or the one player who controls it (vehicles). Automatic ownership is right only for things nobody in particular controls and that do not matter much.

### 3.2 Script fighting physics

**Symptom:** an unanchored part jitters or moves at half speed while a script positions it.

**Cause:** a script sets `CFrame` (or `Position`) on an unanchored part every frame while the solver also moves it. Each frame, the script teleports it and physics pulls it back. Worse if the script runs on the server while a client owns the part: the server write and the owner's simulation contradict each other, and the owner's results keep replicating back.

**Fix:** choose one mover. Either anchor it and animate `CFrame` (kinematic), or leave it unanchored and drive it with constraints (`AlignPosition`, `AlignOrientation`, `LinearVelocity`) on the machine that owns it ([[Mover Constraints and Physics Controllers]]). Never set `CFrame` of a client-owned assembly from the server and expect it to stick, except as a deliberate teleport.

### 3.3 Interpolation vs owner updates

**Symptom:** a server-owned NPC looks smooth on the server and steppy on clients at low frame rates or high ping.

**Cause:** clients interpolate between received states of assemblies they do not own. Large gaps (lag spikes, low server heartbeat) show as steps. Check server heartbeat first ([[Developer Console and Stats]]): a server running at 30 Hz replicates fewer updates.

**Fix:** fix the server frame rate; reduce the number of moving server-owned assemblies; for purely visual motion (bobbing, orbiting decorations), animate on the client and keep the server copy simple.

### 3.4 Sleeping and waking

**Symptom:** a part stops responding to a slow force, then "jumps" when touched; or something hangs in mid-air.

**Cause:** the solver puts resting assemblies to sleep; a very small force may not wake it. Black outline in the ownership view means no owner and no simulation ([[Network Ownership]]).

**Fix:** apply forces that change velocity meaningfully, or nudge the assembly (set a tiny `AssemblyLinearVelocity`) when you start a force; check that it is not anchored or welded to something anchored.

---

## 4. Flinging

Flinging (an assembly launched at very high speed) has four common causes, and the fix differs.

| Cause | Tell | Fix |
|---|---|---|
| **Overlapping collision at spawn or teleport** | happens at the moment something appears or is moved into another collidable part | spawn above ground, check overlap with `GetPartsInPart` or a shapecast before placing, or disable collision briefly |
| **Constraint with huge force and a bad target** | happens when a constraint is enabled or its target jumps | limit `MaxForce`/`MaxTorque`/`MaxVelocity`; move targets smoothly |
| **Mass mismatch in a joint** | light part attached to heavy part through a spring or rope oscillates and explodes | `Massless` on decorative parts (Docs: only applies when welded to a non-massless part); reasonable stiffness and damping |
| **A client deliberately flinging others** (exploit) | other players flung when one player touches them | their client owns their character and can apply huge velocities; validate and use collision groups ([[Network Ownership]], [[Detecting Movement Exploits - Speed Fly Noclip Teleport]]) |

Players flung by **world objects** they own are a special case: a player's client simulates unanchored props near them, and a client-side bug (or slow device) that resolves a deep overlap can launch the prop into others. Server ownership for interactive props removes this.

A quick velocity watchdog helps find which assembly flings first:

```lua
--!strict
-- Studio-only: report any unanchored assembly that exceeds a speed threshold.
local RunService = game:GetService("RunService")
local THRESHOLD = 300 -- studs per second; tune to your game

if RunService:IsStudio() then
	local reported: { [BasePart]: boolean } = {}
	RunService.Heartbeat:Connect(function()
		for _, d in workspace:GetDescendants() do -- Studio only: expensive in big places
			if d:IsA("BasePart") and not d.Anchored and d.AssemblyRootPart == d then
				local v = d.AssemblyLinearVelocity.Magnitude
				if v > THRESHOLD and not reported[d] then
					reported[d] = true
					warn(("[fling] %s at %.0f studs/s"):format(d:GetFullName(), v))
				end
			end
		end
	end)
end
```

This walks the whole workspace every frame; it is a debugging tool for a small test scene, not something to leave on. In a big place, tag candidates and watch only those.

---

## 5. Ownership flips you did not expect

| Situation | What happens | Fix |
|---|---|---|
| Weld an unanchored part to a character | it joins the character's assembly; the player's client owns it | intended for held items; for others, use a separate assembly with a constraint, or keep it anchored |
| An NPC grabs or carries a player | NPC and player assemblies joined; ownership goes to one side | do not weld players to server-owned NPCs; move the player via their own client or anchor briefly |
| Seats | sitting creates a weld; the vehicle's ownership can move to the occupant (Docs describe seat ownership patterns) | set ownership to the driver explicitly on seat changes ([[Network Ownership]]) |
| Unanchoring a part that was anchored | it becomes a new assembly with automatic ownership | set ownership right after unanchoring if it matters |
| `SetNetworkOwner` on a non-root part | applies to the whole assembly; when the assembly changes (weld added), the setting may not carry over the way you expect (rule of thumb) | set it on the root, again after structural changes |
| Ragdoll or physics-based death | `BreakJointsOnDeath` and constraints change the assembly; ownership can change on death | re-assert ownership after changing assemblies |

The general rule (rule of thumb): **any time an assembly changes shape (weld added or removed, anchor toggled), re-check and re-assert its owner.**

---

## 6. Characters and Humanoids

The player's own character is always simulated by their client ([[Network Ownership]]). Humanoid physics bugs are their own category:

| Symptom | Likely cause |
|---|---|
| Character slides, cannot stop | heavy or unbalanced attached parts; `Massless` missing on accessories or weapons, or wrong `HipHeight` |
| Character trips into `FallingDown` or `Ragdoll` often | collisions with small fast parts; disable those states with `Humanoid:SetStateEnabled` if your game does not use them |
| Character stuck in `PlatformStand` or physics state after an ability | ability code did not restore state on every exit path (death, interruption) |
| Character sinks into terrain or floats | `HipHeight` and collision parts mismatched after scaling or custom rigs ([[Characters and Humanoids]]) |
| NPC Humanoids jitter when a player is near | NPC on automatic ownership; set server ownership |

**Measured note.** In the reference project, the ability controller keeps full control of the body while a kit is active (physics state, anchoring, platform stand, or a control attribute), with travel moves capped at 0.45 s plus 0.25 s after release. The lesson for debugging: any system that changes a Humanoid's state must restore it on **every** exit path, and a cap on how long it may hold control turns a stuck-forever bug into a short glitch.

---

## 7. Touched and collision events

Touched-based logic misbehaves in predictable ways:
- `Touched` fires on the machine that simulates the contact and replicates in some cases; for a client-owned character touching a server part, the server receives contact reports that originate from the client (a security concern, [[Network Ownership]]).
- `Touched` fires many times per contact (each part, each re-contact). Debounce per character, not per part.
- `TouchEnded` is unreliable for "left the area" logic. For zones, use spatial queries on a timer (`GetPartsInPart`, `GetPartBoundsInBox`) or region checks on the server ([[Raycasts Shapecasts and Spatial Queries]]).
- Parts with `CanTouch = false` never fire; parts with `CanCollide = false` still fire if `CanTouch` is true (Docs).

---

## 8. A worked example

**Report:** "The pushable crate sometimes launches players into the air."

1. **Assembly.** Assembly dump: the crate is one part, 40 mass. Normal.
2. **Owner.** Watcher with two clients: the owner flips between the two players as they approach.
3. **Repro.** Two players push from opposite sides with 150 ms lag: flings 3 of 10.
4. **Explain.** Each client briefly simulates the crate as it takes ownership. With latency, the new owner starts from a slightly stale position that overlaps the other player's character, and the solver separates them with a large impulse.
5. **Fix.** Server ownership (`SetNetworkOwner(nil)`). Pushing feels slightly less responsive at high ping, which is acceptable for a crate. Also cap crate velocity with a constraint.
6. **Verify.** 0 of 20 with the same setup.
7. **Guard.** `WatchOwner` tag remains on crates in Studio; the velocity watchdog is available for future tests.

---

## Common mistakes

- Reading code before checking who owns the assembly.
- Testing ownership bugs with one client.
- Setting `CFrame` on unanchored assemblies every frame.
- Leaving NPCs and shared props on automatic ownership.
- Welding things to characters without realising the client now owns them.
- Not restoring Humanoid state on every exit path of an ability.
- `TouchEnded` for zone exits.

## Checklist

- [ ] Assembly answered: root, connected parts, mass, anchored.
- [ ] Owner answered, with a watcher over time and two or more clients.
- [ ] One mover per assembly (kinematic or constraints, not both).
- [ ] Explicit ownership for NPCs, vehicles and interactive props; re-asserted after structural changes.
- [ ] Spawns and teleports avoid overlaps.
- [ ] Constraint forces and velocities capped.
- [ ] Ability code restores Humanoid state on all exit paths, with a time cap.

## See also

[[Debugging Start Here]] · [[Network Ownership]] · [[Physics Assemblies and Constraints]] · [[Mover Constraints and Physics Controllers]] · [[Physics Performance]] · [[Characters and Humanoids]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Debugging Client-Server Desync]] · [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] · [[Client Prediction and Reconciliation for Combat]]

## Connected notes
<!-- auto-links:start -->
[[Cars with Constraints - Suspension Steering and Drive]] · [[Snippets - Ragdoll]] · [[Links - Network ownership]] · [[Ragdolls and Physics-Based Animation]] · [[Boats Buoyancy and Water]] · [[Physics and Vehicles Start Here]]
<!-- auto-links:end -->
