---
tags: [level-design, boundaries, out-of-bounds, kill-plane, collision-groups, respawn, type/guide, area/level-design, level/intermediate, api/FallenPartsDestroyHeight, api/PhysicsService, api/PivotTo]
---
# Kill Planes, Map Boundaries and Out-of-Bounds Recovery

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Invisible wall blocks raycasts -> Exclude boundary folder or use raycast collision group
> - Avoid: Thin invisible walls -> Thick walls, vehicle collision group
> - Avoid: Only `Touched` on the kill plane -> Server bounds sweep
> - Every edge has a diegetic boundary; invisible walls only where players can jump past it.
> - Boundary walls in their own collision group; combat raycasts ignore them.
> - Server bounds sweep with server-tracked, filtered last-safe positions.
>
> Cost: TL;DR ~160 tok · whole note ~2.6k tok. Read more: ## 2. Invisible walls that only block players · ## 3. Server-side out-of-bounds detection · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Every map has an edge, and players will find it: by jumping off it, by glitching through a seam, by flinging a car over a wall, or by an exploiter teleporting under the map. A good boundary tells honest players "not this way" without feeling cheap, puts them back somewhere sensible when they get past it, and gives the server a hard line that exploit checks can trust. This note covers the boundary types and when to use each, collision-group walls that block players but not bullets, server-side out-of-bounds detection, and safe recovery. The engine's last-resort `Workspace.FallenPartsDestroyHeight` is documented in [[Spawn Points Safe Zones and Respawn Flow]]; this note is about everything you should build above it.

Source labels: **Roblox docs** (create.roblox.com, as of October 2026), **Rule of thumb**. Code is strict Luau, **reviewed, not run**.

---

## 1. Boundary types

| Type | Player experience | Use for | Watch out |
|---|---|---|---|
| **Diegetic edge** (cliff, water, fence, building) | Natural; reads as "end of world" | First choice everywhere | Players climb anything with a ledge; test with jumping and ladders |
| **Invisible wall** | Frustrating if it blocks a reachable-looking place | Above diegetic edges, to stop jump-overs | Must not block raycasts or projectiles you rely on (section 2) |
| **Soft boundary** (warning, then damage or teleport after N seconds) | Fair; explains itself | Open worlds, vehicles, battle royale zones | Needs UI and a countdown |
| **Kill plane / void** | Instant death | Obbies (falling is the challenge), sky islands | Feels cheap in non-obby games; loses items |
| **Recovery plane** | Fall, then reappear at last safe spot | Exploration games, platformers for young players | Exploitable as free teleport if the "safe spot" is client-reported |

Rule of thumb: the boundary should match the genre's promise. Obby players accept death on falling; a roleplay player who falls off a dock and loses their car and inventory will not.

## 2. Invisible walls that only block players

An invisible wall that is `CanCollide = true` blocks everything: characters, but also vehicles you may want stopped and projectiles you may not. Use collision groups (Roblox docs: `PhysicsService:RegisterCollisionGroup`, `PhysicsService:CollisionGroupSetCollidable`, and the part's `CollisionGroup` string property):

```lua
--!strict
-- Server, once at startup.
local PhysicsService = game:GetService("PhysicsService")

PhysicsService:RegisterCollisionGroup("Boundary")
PhysicsService:RegisterCollisionGroup("Players")
PhysicsService:CollisionGroupSetCollidable("Boundary", "Default", false) -- props and debris pass
PhysicsService:CollisionGroupSetCollidable("Boundary", "Players", true)

for _, wall in workspace.Boundaries:GetDescendants() do
	if wall:IsA("BasePart") then
		wall.CollisionGroup = "Boundary"
		wall.Transparency = 1
		wall.CanTouch = false
		wall.Anchored = true
	end
end
```

Assign character parts to `"Players"` on `CharacterAdded` (all `BasePart` descendants, plus `DescendantAdded` for late accessories). Vehicles get their own group, collidable with the boundary.

Raycasts: Roblox docs say `CanQuery` only takes effect when `CanCollide` is false, so a colliding invisible wall still blocks raycasts unless your `RaycastParams` exclude it. Either add the `Boundaries` folder to every combat raycast's exclude list, or set `RaycastParams.CollisionGroup` to a group that does not collide with `Boundary`. Forgetting this gives "my shots hit air" bug reports near map edges.

Make invisible walls tall (well above max jump plus any launchers) and thick (at least a few studs; thin walls let fast characters and vehicles tunnel through).

## 3. Server-side out-of-bounds detection

Do not trust kill-plane `Touched` events alone: they miss players who teleport past them, fast falls can skip a thin part between physics steps, and an exploiter can delete a client-side copy's touch interest. A cheap server sweep is more reliable:

```lua
--!strict
-- Server: OOB sweep at 2 Hz plus last-safe-position tracking.
local Players = game:GetService("Players")

local BOUNDS_MIN = Vector3.new(-2048, -64, -2048)
local BOUNDS_MAX = Vector3.new(2048, 1024, 2048)
local SAFE_SAMPLE = 0.5

local lastSafe: { [Player]: CFrame } = {}

local function inside(p: Vector3): boolean
	return p.X >= BOUNDS_MIN.X and p.X <= BOUNDS_MAX.X
		and p.Y >= BOUNDS_MIN.Y and p.Y <= BOUNDS_MAX.Y
		and p.Z >= BOUNDS_MIN.Z and p.Z <= BOUNDS_MAX.Z
end

local function recover(player: Player, root: BasePart)
	local target = lastSafe[player]
	if not target then
		task.spawn(player.LoadCharacterAsync, player) -- no history: plain respawn; spawned so the sweep does not yield
		return
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local character = root.Parent :: Model
	character:PivotTo(target + Vector3.new(0, 3, 0))
end

task.spawn(function()
	while true do
		task.wait(SAFE_SAMPLE)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and root and humanoid.Health > 0 then
				if not inside(root.Position) then
					recover(player, root)
				elseif humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.SeatPart == nil then
					lastSafe[player] = root.CFrame
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastSafe[player] = nil
end)
```

Refinements:

- **Safe-spot filter.** `FloorMaterial ~= Air` says the character is on something, not that the something is safe. Exclude moving platforms, kill bricks, enemy bases and the outer ring of the map (tag unsafe floors and check with a downward raycast if needed). Otherwise players get recovered onto a lava tile.
- **Debounce recovery.** If a player is recovered more than a few times a minute, treat it as a stuck loop and fall back to a normal respawn.
- **Bounds as data.** Store the box per map (or per zone); for irregular maps, use several boxes or the zone resolver from [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]].
- **Vehicles.** Recover the whole vehicle assembly with `PivotTo` on the vehicle model and zero its velocity; recovering only the driver leaves the car falling forever.
- **Exploit signal.** Repeated out-of-bounds positions far outside the map are a teleport signal. Log them into your movement checks rather than banning on one event ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]], [[False Positives Lag and Fair Enforcement]]).

## 4. Soft boundaries

For open worlds and vehicle maps, a soft boundary is kinder than a wall:

1. Player crosses the warning line: UI shows "Return to the area" with a 5 to 10 second countdown, screen edge tint, optional audio cue.
2. Player returns: cancel, no penalty.
3. Countdown expires: recover to last safe position (not death), or apply damage over time in competitive modes.

The server owns the timer; the client only renders the warning. Use the same bounds data as the hard sweep with a margin, so the hard limit sits some distance beyond the warning line.

## 5. Kill planes done well (obbies and sky maps)

- Place a kill volume (a thick, anchored, `CanCollide = false`, `CanTouch = true` part) a short fall below the course so death is quick: long falls into a void waste the player's time.
- Back it up with the server height check from section 3, so missed touches still count.
- Make the void read as deadly (dark fog, falling particles) so death never feels like a bug.
- Respawn at the last checkpoint, not the start, and do it fast ([[Obby and Platforming Level Design]]).
- Check `FallenPartsDestroyHeight` sits below your lowest legitimate geometry; sky maps built far below Y=0 can hit it.

---

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Invisible wall blocks raycasts | Shots stop in mid-air at edges | Exclude boundary folder or use raycast collision group |
| Thin invisible walls | Cars and fast players tunnel through | Thick walls, vehicle collision group |
| Only `Touched` on the kill plane | Teleporters and fast fallers survive | Server bounds sweep |
| Last safe position from the client | Exploiters choose where they "recover" | Server-sampled positions only |
| Safe spot on a moving platform or hazard | Recovery loop into lava | Filter unsafe floors |
| Recovering the driver, not the car | Car falls forever, player stranded | Pivot the vehicle model |
| Death on every fall in a non-obby game | Lost items, angry players | Recovery plane or soft boundary |

## Checklist

- [ ] Every edge has a diegetic boundary; invisible walls only where players can jump past it.
- [ ] Boundary walls in their own collision group; combat raycasts ignore them.
- [ ] Server bounds sweep with server-tracked, filtered last-safe positions.
- [ ] Vehicles recovered as whole assemblies.
- [ ] Soft boundary with server timer where genre suits it.
- [ ] `FallenPartsDestroyHeight` below the lowest geometry.
- [ ] Edges tested by jumping, driving, flinging and on a phone.

## See also

[[Spawn Points Safe Zones and Respawn Flow]] · [[Obby and Platforming Level Design]] · [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] · [[False Positives Lag and Fair Enforcement]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Physics Assemblies and Constraints]] · [[Level Design Principles - Flow Sightlines and Landmarks]]

## Connected notes
<!-- auto-links:start -->
[[Level Design Start Here]] · [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] · Cars with Constraints - Suspension Steering and Drive
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Instanced Interiors - Pooled House and Room Copies for Many Players]] · [[Objective Mode Maps - Capture the Flag, King of the Hill and Control Points]] · [[Playtest Heatmaps - Position and Death Maps]] · [[Combat Arena and Encounter Layout]] · [[Teaching Through Level Design]] · [[Lobby and Hub Design]]
<!-- related:end -->
