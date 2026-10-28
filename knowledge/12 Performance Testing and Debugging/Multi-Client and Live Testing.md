---
tags: [testing, multiplayer, multi-client, live-testing, cheat-tools, network-simulation]
---
# Multi-Client and Live Testing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Only ever testing as the first player in the server.
> - Avoid: No snapshot path for late joiners.
> - Avoid: Testing timing-sensitive features with zero latency.
> - Two-client test with join order both ways for every multiplayer feature.
> - Leave and rejoin mid-interaction tested.
> - Network Simulator on for timing features.
>
> Cost: TL;DR ~120 tok · whole note ~3.3k tok. Read more: ## 2. The multiplayer test matrix · ## 3. Gated cheat tooling · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A solo play test in Studio proves that a feature works for one player, on one fast machine, with zero latency, joining first. Real players join late, leave mid-trade, lag, run on phones and share a server with thirty strangers. Most shipped multiplayer bugs live in that gap. This note covers Studio's multi-client and network simulation tools, the multiplayer test matrix (join order, leave and rejoin, streaming), gated cheat tooling to reach states fast, testing in real servers, and the hazards of testing inside a place other people are also working in.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

Studio test modes in general: [[Testing Modes - Play Run and Multi-Client]].

---

## 1. Studio's tools

### Test modes (Docs)
| Mode | Key | What it does |
|---|---|---|
| Test (Play) | F5 | server and one client with your avatar at a SpawnLocation |
| Test Here | | avatar in front of the camera |
| Run | F8 | simulation without an avatar; good for watching NPCs and physics |
| Stop | Shift+F5 | end and reset |
| **Server & Clients** | F7 / Play | one server window plus N client windows; Docs say up to **eight** clients, though one or two usually suffice |
| **Team Test** | | collaborators join one shared test session; only one at a time |

In a solo Test, Docs note the client and server simulations are separate and you can toggle the view between them; the Output marks client lines blue and server lines green. That is still one machine and zero latency.

### Simulators (Docs)
| Tool | Use |
|---|---|
| **Network Simulator** (Alt+S during testing) | adds latency, jitter and packet loss |
| **Device Simulator** | screen sizes, pixel density, on-screen keyboard, touch |
| **Controller Emulator** | gamepads, VR controllers, TV remotes |
| **Player Emulator** | locale, pseudo-localisation, region settings |
| **Party Simulator** | parties for test players in Server & Clients |
| **Pause/Resume, Step** | pause physics and animation (client, server or both); step 1/60 s |

### Practical setup (rule of thumb)
- **Two clients** catch most replication bugs. Four catch "works with two, breaks with more" (team assignment, round logic, trading with a third party).
- Turn on the **Network Simulator at about 150 to 250 ms with some jitter** for any feature with timing (combat hit windows, cooldown UI, trading confirmations).
- Multi-client tests are heavy: each client is a full instance. On a large place, close other heavy apps; Studio slowness distorts timing.

---

## 2. The multiplayer test matrix

Run these for every feature that has state other players can see or affect.

| Scenario | Bug it catches |
|---|---|
| **A joins, then B** | B does not see A's existing state (no "snapshot on join", only incremental updates) |
| **B joins while A is mid-action** | late-joiner sees a half state: an effect stuck on, a door half open |
| **A leaves during an interaction** (trade, party, dungeon, open shop) | locks never released, items duplicated or lost, B stuck in a dialog |
| **A rejoins quickly** (same or different server) | session lock conflicts, double rewards, stale data ([[Session Locking and Profile Libraries]]) |
| **Both act at the same moment** | race conditions in claims, double purchases, two winners |
| **UI isolation** | A's UI shows B's data (a client handler that ignores which player an event is for) |
| **Respawn** | connections duplicated per respawn; state reset that should persist |
| **Streaming: walk far away and back** | client code that assumed an instance exists; state lost when a model streamed out ([[Instance Streaming]]) |
| **Latency on** | client prediction and server validation disagree; double-click exploits |

The late-joiner case is the most common real bug (rule of thumb): every system needs a path that sends a full snapshot to a joining player, not only change events.

```lua
--!strict
-- Pattern: state service with a join snapshot plus deltas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DoorEvent = Instance.new("RemoteEvent")
DoorEvent.Name = "DoorEvent"
DoorEvent.Parent = ReplicatedStorage

local doorOpen: { [string]: boolean } = {}

local function setDoor(id: string, open: boolean)
	if doorOpen[id] == open then
		return
	end
	doorOpen[id] = open
	DoorEvent:FireAllClients("delta", id, open)
end

Players.PlayerAdded:Connect(function(player: Player)
	-- Late joiners get the whole state once.
	DoorEvent:FireClient(player, "snapshot", doorOpen)
end)

return setDoor
```

The client must handle a delta arriving before its snapshot (apply snapshot, then any later deltas), or request the snapshot when its handler is ready. A common variant: the client fires a "ready" remote once its listeners are connected and the server answers with the snapshot, which avoids events sent before the client listened.

---

## 3. Gated cheat tooling

Reaching a state by playing (level 40, a rare item, a boss phase, a full backpack) takes hours. QA tooling reaches it in seconds. It must be safe.

### The command bar trap
`require`-ing a ModuleScript from the Studio command bar returns a **separate module instance** from the one the running game uses. Changing values there changes nothing in the live game (Measured in the reference project, and widely reported). Do not test live state through the command bar. Use remotes that call the real systems.

### A cheat service

```lua
--!strict
-- ServerScriptService/CheatService.server.luau
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent.Economy) -- the real system API
local Progression = require(script.Parent.Progression)
local Profiles = require(script.Parent.Profiles)

local DEV_USER_IDS: { [number]: true } = {
	-- [00000000] = true,
}

local function authorised(player: Player): boolean
	return RunService:IsStudio() or DEV_USER_IDS[player.UserId] == true
end

type Handler = (player: Player, ...any) -> ()
local handlers: { [string]: Handler } = {
	GiveCoins = function(player, amount)
		if type(amount) == "number" and amount > 0 and amount <= 1e9 then
			Economy.addCoins(player, math.floor(amount), "cheat") -- same path as gameplay
		end
	end,
	SetLevel = function(player, level)
		if type(level) == "number" and level >= 1 and level <= 1000 then
			Progression.setLevel(player, math.floor(level))
		end
	end,
	ResetProfile = function(player)
		Profiles.resetToDefault(player)
	end,
}

local remote = Instance.new("RemoteEvent")
remote.Name = "Cheat"
remote.Parent = ReplicatedStorage

remote.OnServerEvent:Connect(function(player: Player, command: unknown, ...: any)
	if not authorised(player) then
		return -- gate on the server in every call
	end
	if type(command) ~= "string" then
		return
	end
	local handler = handlers[command]
	if handler then
		print(("[cheat] %s ran %s"):format(player.Name, command)) -- audit trail
		handler(player, ...)
	end
end)
```

Rules (rule of thumb, matching the roblox-testing playbook used in the reference project):
- The **server-side gate** is the security. A hidden button is not. Remote names are visible to every client ([[Exploits and Anti-Cheat]]).
- Cheats call the **same APIs** gameplay calls. A cheat that pokes raw data tests a code path players never run.
- Cover the matrix: currency, items, levels, time skips (for daily rewards and timers), spawn and clear enemies, trigger rare events, god mode, **reset profile to default**.
- Log every cheat use. In a live server, cheats leave a trail.
- An admin panel in the reference project used an owner-only branch on the server for profile edits; everything was validated server-side.

---

## 4. Live testing

Studio cannot reproduce: real network paths, real devices, real asset loading from Roblox servers, live DataStores and MemoryStores at scale, purchases, teleports between places, and many players at once.

### Where to test live
| Option | Notes |
|---|---|
| A separate **test place** (or test experience) with the same code | safe for destructive tests; data stores separate if configured so |
| A **private server** of the live experience | real environment; be careful with live data |
| The live game with a **feature flag** limited to developers | final check; the flag also gives you a kill switch ([[Global State and Live Config]]) |

### Live test protocol (rule of thumb)
1. Publish to the test place; join with 2 to 4 people on mixed devices (PC, low phone, tablet, controller).
2. Run the written test scripts for the changed features ([[Testing Strategies and Frameworks]]).
3. Open the Developer Console: server Log for errors, Memory baseline, server heartbeat ([[Developer Console and Stats]]).
4. Have one tester leave and rejoin, one switch servers, one play on mobile data if possible.
5. Check the Error Report for the test place after the session ([[Crash and Error Telemetry]]).
6. Record numbers: join time on a phone, fps in the heaviest area, server memory.

### Load testing
There is no official bot framework for Roblox servers. Options (rule of thumb):
- Many real people (a playtest group, friends, a community test event).
- Server-side simulated load: spawn the NPCs, projectiles and effects that 30 players would cause, and measure server heartbeat. It does not simulate replication to 30 clients, but it finds server CPU limits.
- Multi-client in Studio up to eight clients for replication logic, not for performance numbers.

---

## 5. Testing in a shared place

When several people (or several automated tools) work in the same place, testing becomes a shared-resource problem.

**Measured lessons from the reference project** (anonymised):
- **Someone else may be playing.** Odd server-side events during a test were sometimes another person's play session. Check the server log for activity you did not cause first.
- **Edit previews leak into play.** A lighting preview left on in Edit was read as the base atmosphere by the weather system at Play start. Rule: switch previews off right after capturing.
- **Never use undo as a recovery tool in a shared session.** Studio's undo history is shared by everything editing the session: one undo to recover terrain went about 40 steps back and rolled back other people's instance changes, and each scripted change adds a step that wipes redo. Snapshot before risky edits instead (for terrain, `Terrain:CopyRegion` into a stored `TerrainRegion`), and never regenerate a large area without agreement.
- **Compare before overwrite.** Before overwriting a script, compare the place's current source with the version you started from; someone may have changed it since.
- **Temporary moves must be restored.** Objects moved to inspect something (a zone cover, a blocker) were sometimes forgotten; a checklist step "put back what you moved" fixed it.

See [[Safe Changes in a Shared Place]] and [[Team Create and Collaboration]].

---

## 6. What "tested" means in a report

Use explicit levels ([[Testing Strategies and Frameworks]]):
- "Edit dry run passed" (code paths, structure).
- "Solo play-tested" (runtime for one player).
- "Multi-client tested: join order both ways, leave mid-trade" (name the scenarios).
- "Live-tested on phone and PC in a private server".
- "Not play-tested" (say it; it goes on the list).

---

## Common mistakes

- Only ever testing as the first player in the server.
- No snapshot path for late joiners.
- Testing timing-sensitive features with zero latency.
- Cheat remotes gated only by hiding the UI, or bypassing the real system APIs.
- Treating Studio multi-client as a performance test.
- Undoing in a shared session; forgetting to turn off previews.

## Checklist

- [ ] Two-client test with join order both ways for every multiplayer feature.
- [ ] Leave and rejoin mid-interaction tested.
- [ ] Network Simulator on for timing features.
- [ ] Streaming in and out tested for world-bound systems.
- [ ] Cheat tooling server-gated, logged, using real APIs, with profile reset.
- [ ] Live test on mixed devices before release; console and Error Report checked.
- [ ] Shared-place hygiene: previews off, no undo, compare before overwrite, restore moved objects.

## See also

[[Testing Modes - Play Run and Multi-Client]] · [[Testing Strategies and Frameworks]] · [[QA Checklists Before Release]] · [[Instance Streaming]] · [[Session Locking and Profile Libraries]] · [[Exploits and Anti-Cheat]] · [[Safe Changes in a Shared Place]] · [[Team Create and Collaboration]] · [[Network Performance]]

## Connected notes
<!-- auto-links:start -->
[[Multi-Client and Device Playtesting Protocols]] · [[Client-Server Model]] · [[Command Bar and Studio Scripting]] · [[Debugging Start Here]] · [[Anti-Exploit Start Here]] · [[MCP Workflows for Scripting and Debugging]]
<!-- auto-links:end -->
