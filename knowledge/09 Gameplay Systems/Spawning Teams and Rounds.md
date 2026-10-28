---
tags: [gameplay, spawning, teams, rounds, zones, gates, enemies]
---
# Spawning Teams and Rounds

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Relying on random SpawnLocation choice -> Place in `CharacterAdded`
> - Avoid: Countdown sent every second -> Publish end time, use server time
> - Avoid: No late-join handling -> Explicit lobby/spectate state
> - Respawn rules per context (realm, PvP, tutorial).
> - Teams with unique colours; friendly fire in the damage core.
> - Round loop is a server state machine publishing end times.
>
> Cost: TL;DR ~140 tok · whole note ~4.5k tok. Read more: ## 4. Enemy spawning: tables, caps and waking · ## 5. Zone gates · ## 6. Common mistakes · ## Checklist
<!-- tldr:end -->

Three related problems: where **players** appear (spawn points, teams, respawn after death), how a **match** is structured (rounds, intermission, win conditions), and where **enemies** appear (spawn tables, caps, waking areas near players). Plus the glue that most progression games need: **zone gates** that decide which areas a player may enter. This note covers the built-in objects, server-driven round loops, data-driven enemy spawners, and gate enforcement, with numbers from one production game.

Related: [[Characters and Humanoids]] (respawning), [[NPC AI and Behaviour]], [[Progression Levels and Unlocks]] (what gates cost), [[Teleporting and Multi-Place Games]].

Source labels: **Docs** (SpawnLocation, Team references, checked October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. SpawnLocation

| Property | Behaviour (Docs) |
|---|---|
| `Enabled` | Disabled spawns are never used and team-change-on-touch stops |
| `Neutral` | True: anyone may spawn here. False: only players whose `TeamColor` matches |
| `TeamColor` | The team this spawn belongs to |
| `AllowTeamChangeOnTouch` | Touching sets the player's team to this spawn's |
| `Duration` | Seconds of spawn ForceField; default 10; 0 = none |

With several eligible spawns, one is chosen at random, and players can overlap if they respawn together (Docs). The ForceField protects only against damage that uses `TakeDamage` or checks for ForceFields.

### Controlling spawn position yourself
Random choice among spawns is fine for a deathmatch. Progression games usually want "spawn where it makes sense": the furthest area unlocked, the realm you died in, the tutorial landing. Do it in `CharacterAdded` on the server:

```lua
--!strict
local Players = game:GetService("Players")

local function spawnCFrameFor(player: Player): CFrame?
	-- Your logic: last checkpoint, current realm's return point, tutorial landing...
	local cf = player:GetAttribute("RespawnCF")
	return if typeof(cf) == "CFrame" then cf else nil
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local cf = spawnCFrameFor(player)
		if not cf then return end
		local root = character:WaitForChild("HumanoidRootPart") :: BasePart
		-- Wait one frame so the default spawn placement has happened, then move.
		task.defer(function()
			character:PivotTo(cf + Vector3.new(0, 4, 0))
		end)
	end)
end)
```

The "+4 up" offset avoids spawning inside the floor; the reference project's "go to spawn" paths all add 4 studs above the spawn part.

**Measured.** In the reference project, deaths in the second realm respawn at that realm's return portal, PvP deaths at an alcove picked at death time (kept unless another player stands within 24 studs), and tutorial knock-outs at a tutorial landing point with a 3 s ForceField. Each context has its own respawn rule; a single global SpawnLocation could not express that.

### Spawn safety
- Spawn ForceField or your own shield for 2 to 10 s.
- Spawns away from enemies: a spawner rule that never spawns enemy groups within 140 studs of a tutorial landing (measured) is the enemy-side mirror of spawn protection.
- Do not place SpawnLocations where map edits can bury them; check after every level change.

---

## 2. Teams

| Fact | Source |
|---|---|
| Teams live only under the `Teams` service | Docs |
| `AutoAssignable` teams get new players; with several, Roblox evens them out on join, but does nothing when players leave | Docs |
| `TeamColor` must be unique per team because spawns match by colour | Docs |
| Changing `Player.TeamColor` switches `Player.Team` to the matching team | Docs |
| `Player.Neutral = true` detaches from the team without clearing `Team` | Docs |
| `Team:GetPlayers()`, `Team.PlayerAdded`, `Team.PlayerRemoved` | Docs |
| No built-in friendly-fire prevention | Docs |

Friendly fire belongs in the damage core:

```lua
--!strict
local function canDamage(attacker: Player, victim: Player): boolean
	if attacker == victim then return false end
	if attacker.Neutral or victim.Neutral then return true end
	return attacker.Team ~= victim.Team
end
```

Rebalancing on leave is your job (Docs). A simple rule: when the team difference reaches 2 at round end, move the most recently joined player of the larger team.

**Rule of thumb.** Teams are also useful outside PvP: a "Lobby" vs "In Match" team gives you free player-list grouping and spawn separation. Do not use teams for persistent progression (they reset per server).

---

## 3. Rounds: a server state machine

Round-based games (minigames, survival, deathmatch) need one authoritative loop on the server, with its state published so every client can draw timers and banners.

```lua
--!strict
local Players = game:GetService("Players")

type Phase = "Intermission" | "Starting" | "Playing" | "Ending"

local MIN_PLAYERS = 2
local INTERMISSION = 20
local ROUND_TIME = 180

local function setPhase(phase: Phase, endsAt: number)
	workspace:SetAttribute("RoundPhase", phase)
	workspace:SetAttribute("PhaseEndsAt", endsAt) -- clients count down locally
end

local function waitUntil(t: number, abort: () -> boolean): boolean
	while workspace:GetServerTimeNow() < t do
		if abort() then return false end
		task.wait(0.25)
	end
	return true
end

local function aliveParticipants(): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if p:GetAttribute("InRound") and hum and hum.Health > 0 then
			table.insert(out, p)
		end
	end
	return out
end

while true do
	setPhase("Intermission", workspace:GetServerTimeNow() + INTERMISSION)
	waitUntil(workspace:GetServerTimeNow() + INTERMISSION, function() return false end)
	if #Players:GetPlayers() < MIN_PLAYERS then
		continue
	end

	for _, p in Players:GetPlayers() do
		p:SetAttribute("InRound", true)
		-- teleport to arena spawns, give round tools...
	end

	local endsAt = workspace:GetServerTimeNow() + ROUND_TIME
	setPhase("Playing", endsAt)
	waitUntil(endsAt, function()
		return #aliveParticipants() <= 1
	end)

	setPhase("Ending", workspace:GetServerTimeNow() + 5)
	-- award winners, show results
	task.wait(5)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("InRound", nil)
		-- return to lobby
	end
end
```

Principles:
- **Publish end times, not countdown ticks.** `Workspace:GetServerTimeNow()` is synchronised across server and clients, so clients compute remaining time locally with no per-second remote traffic.
- **Every player state change has a reason to end.** Players who leave mid-round, die, or join late must be handled at each phase.
- **Abort conditions** (one player left, everyone dead, objective done) are checked continuously, not only at the timer's end.
- **Late joiners** wait in the lobby or spectate; decide explicitly.
- **Rewards on the server at the end**, with a minimum participation rule so AFK players do not farm wins.

---

## 4. Enemy spawning: tables, caps and waking

Open-world combat games spawn enemies continuously around players. The parts:

### Spawn tables
A spawn table per zone describes **what** spawns, **how many**, and **how often**:

```lua
--!strict
export type SpawnRow = {
	enemy: string,
	weight: number,
	group: { min: number, max: number }, -- pack size
}

export type ZoneSpawns = {
	cap: number,                 -- max live enemies (scaled by area)
	respawnDelay: number,        -- seconds after a death
	rows: { SpawnRow },
	elite: { enemy: string, chance: number }?,
	mega: { enemy: string, respawn: number }?,
	miniBoss: { enemy: string, center: Vector3, radius: number }?,
}
```

**Measured** values from the reference project:
- Caps are written "per 600 x 360 studs" and scaled by the zone's real floor area: a 1,340 x 520 area got x1.8 (a cap of 16 became 29), with an overall cap multiplier limit of 1.5x in a later pass.
- Each zone had 2 basic enemy types plus an elite and a "mega", and some zones a mini-boss at a fixed ring.
- Elite chance rose with zone depth, 5% in the first zone of the second realm to 10% in its ninth.
- Rare spawns rolled separately (see [[RNG Drops and Luck Systems]]).

### Where to spawn
- **Near players, not on them.** A share of groups spawns within a radius of a player in the area, the rest anywhere. The reference project's share was tuned from 0.65 to 0.3 of groups within 200 studs of a player; always at least 45 studs from any player.
- **Only on walkable floor.** A flood-filled grid of walkable cells per zone (8-stud cells) guarantees spawn points are reachable; a random point is retried up to 16 times against "no hole, no trunk, no colliding part in an 8-stud box", then pushed out of obstacles.
- **Avoid protected spots:** arrival pads (a 50-stud hole), mini-boss rings, tutorial landings.

### Waking and sleeping areas
Simulating every zone all the time wastes the server. Wake an area's spawner when a player is within a wake radius and despawn it beyond a larger sleep radius (hysteresis prevents flicker). **Measured:** wake 220 / sleep 260 was too large because standing at your own gate filled the next zone; it became 160 / 210.

```lua
--!strict
local WAKE, SLEEP = 160, 210

local function updateArea(area: { center: Vector3, awake: boolean }, playerPositions: { Vector3 })
	local nearest = math.huge
	for _, p in playerPositions do
		nearest = math.min(nearest, (p - area.center).Magnitude)
	end
	if not area.awake and nearest <= WAKE then
		area.awake = true -- start spawning
	elseif area.awake and nearest > SLEEP then
		area.awake = false -- despawn live enemies, stop timers
	end
end
```

Measure distance to the area's nearest edge rather than its centre for long zones.

---

## 5. Zone gates

Progression games divide the world into zones behind gates bought with currency or opened by beating a boss ([[Progression Levels and Unlocks]]). The gate has two halves:

| Half | Runs on | Job |
|---|---|---|
| Presentation | Client | Gate frame and veil, price label, states BUY / LOCKED / "DEFEAT X" / ARENA SEALED |
| Enforcement | Server | Players may not stand in zones they have not unlocked |

**A collision wall is not enforcement.** Clients own their characters; a wall that only blocks physics can be walked through by an exploiter, and lag or knockback can push honest players through. The server must check positions.

**Measured.** The reference project's zones are strips along +X, so its gate guard judges a player's zone by X alone (the cheapest possible test). Players found in a zone beyond their unlocks are sent back (to the lobby, or for unopened worlds to the hub). Gotchas it hit:
- **Development teleports.** A developer teleport into a locked zone was bounced by the guard; testing needed a Studio-only exemption. Build exemptions in from the start (an attribute the guard respects, honoured only in Studio).
- **Rebirth resets.** Rebirth resets gates, but keeps the furthest built world's first gate, so a reborn player is not stranded in a world they can no longer enter.
- **Map changes.** When the map moved, the guard (which assumed the old layout) had to stop asserting so it did not bounce everyone.

```lua
--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GATE_X = { 720, 1344, 1968, 2592, 3216 } -- zone n starts at GATE_X[n]

local function zoneAtX(x: number): number
	local z = 0
	for i, gx in GATE_X do
		if x >= gx then z = i end
	end
	return z
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.5 then return end
	acc = 0
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local unlocked = (p:GetAttribute("ZonesUnlocked") :: number?) or 0
		if root and zoneAtX(root.Position.X) > unlocked and not (RunService:IsStudio() and p:GetAttribute("DevBypass")) then
			local back = GATE_X[unlocked + 1] or GATE_X[1]
			p:SetAttribute("ServerTeleported", true) -- tell the movement checker
			p.Character:PivotTo(CFrame.new(back - 20, root.Position.Y + 4, root.Position.Z))
		end
	end
end)
```

Use a general "zone at position" function (boxes or a spatial index) if your zones are not strips.

---

## 6. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Relying on random SpawnLocation choice | Players spawn far from progress | Place in `CharacterAdded` |
| Countdown sent every second | Network spam, drift | Publish end time, use server time |
| No late-join handling | Players stuck in limbo | Explicit lobby/spectate state |
| Enemy caps not scaled by area | Empty big zones, crowded small ones | Cap per area unit |
| Spawning on players | Unfair hits on arrival | Minimum distance, safe zones |
| Wake = sleep radius | Areas flicker on and off | Hysteresis |
| Gates enforced by walls only | Exploiters and knockback skip zones | Server position check |

## Checklist
- [ ] Respawn rules per context (realm, PvP, tutorial).
- [ ] Teams with unique colours; friendly fire in the damage core.
- [ ] Round loop is a server state machine publishing end times.
- [ ] Spawn tables in data, caps scaled by area, walkable spawn points.
- [ ] Areas wake and sleep with hysteresis.
- [ ] Gates enforced on the server with Studio-only bypass.

## See also
[[Characters and Humanoids]] · [[NPC AI and Behaviour]] · [[Progression Levels and Unlocks]] · [[Combat Systems Architecture]] · [[Teleporting and Multi-Place Games]] · [[Level Design for Roblox]] · [[Genre Playbook - Combat and RPG]]

## Nuances and edge cases

1. **Round state must survive players leaving mid-transition.** The most common round bug is a state machine that waits for "all players ready" or "last player alive" and never re-checks when someone leaves. Every transition should re-evaluate the player list at the moment it runs, and every waiting state needs a timeout.
2. **Minimum players changes with server size.** A round that needs 4 players works in a 12-player server and stalls forever in a quiet 3-player server at off-peak hours. Lower the minimum after a waiting period, fill with bots, or start a practice mode, so a quiet server is still fun.
3. **Team balance has two meanings.** Even numbers is easy; even skill is hard. Shuffling by join order produces stacked teams when friends join together. Assign by a simple rating or by alternating picks from a sorted list, and keep parties together only when the game design wants that.
4. **Spawn protection needs both sides.** A newly spawned player should not take damage for a short window, but should also not deal damage, or spawn protection becomes an exploit (spawn, attack, retreat). A common rule of thumb is 2 to 3 seconds, ending early when the player attacks.
5. **Spawn points at scale.** With 50 players and 8 spawn points, a team wipe sends players into the same spots at once and they overlap or get spawn-camped. Use more spawns than the maximum team size, pick the spot farthest from enemies, and add a small random offset.
6. **Enemy caps should be global and per area.** A per-area cap alone lets a server with players spread across 10 zones run 10 times the enemies; a global cap alone starves busy zones. Use both, and lower both on servers that measure high heartbeat times.
7. **Late joiners are a separate case.** A player who joins mid-round needs a defined experience: spectate, join a team immediately, or wait in a lobby. Undefined, they spawn into the arena without the round's setup (no loadout, no team, no UI).
8. **Phones and long countdowns.** Players on phones switch apps during long intermissions; their client may be suspended. Keep intermission short (rule of thumb: under 30 seconds) and do not kick players who appear idle during intermission.

The senior trade-off: a strict round loop is predictable and fair but empties quiet servers; a flexible loop keeps players but makes every state more complex. Start strict, then add exactly the flexibility your server-size data says you need.

## Common mistakes (advanced)

1. **No timeout in waiting states.** Symptom: servers stuck on "Waiting for players" forever. Fix: timeouts and a re-check on every leave.
2. **Teams assigned once at join.** Symptom: lopsided teams after a few players leave. Fix: rebalance between rounds.
3. **Spawn protection that allows attacks.** Symptom: players fight from inside protection. Fix: end protection on the first attack.
4. **Rewards granted at round end only.** Symptom: players who disconnect at the last second lose rewards and complain; or rewards are granted twice when the end runs twice. Fix: grant on the server once per round id, idempotently.
5. **Round state stored in many scripts.** Symptom: UI shows "intermission" while the server runs a round. Fix: one authoritative state value replicated through an attribute or a single remote.
6. **Enemy spawns ignoring players' positions.** Symptom: enemies appear on top of players. Fix: minimum distance from all players, with a fallback spawn list.

## Related decisions

- [[Round-Based Minigame Loop End to End]]: a full round loop implementation.
- [[Arena Rounds with Teams and Spectating End to End]]: teams, spectating and late join.
- [[Spawn Points Safe Zones and Respawn Flow]]: spawn placement from the level design side.
- [[Matchmaking Queues with MemoryStore]]: filling rounds across servers.
- [[Parties and Group Teleports]]: keeping friends together.
- [[Social Design and Multiplayer Play]]: why quiet servers need a fallback mode.
- [[Genre Playbook - Party and Minigame Collections]]: round pacing for minigame games.
- [[Debugging Race Conditions and Yield Order]]: state machines that break on mid-transition leaves.

## Connected notes
<!-- auto-links:start -->
[[Links - Rounds and matchmaking]] · [[Links - Checkpoints and spawning]] · [[Combat Arena and Encounter Layout]] · [[Level Design Start Here]] · [[Lobby and Hub Design]] · [[Cookbook - Players and Characters]]
<!-- auto-links:end -->
