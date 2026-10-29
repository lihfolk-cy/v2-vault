---
tags: [performance, developer-console, stats, memory, overlays, debugging, type/guide, area/performance, level/intermediate, api/UserInputService, area/debugging, api/Animation]
---
# Developer Console and Stats

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Reading memory in Studio and trusting it.
> - Avoid: Treating high memory as a bug. Docs: high usage alone is not necessarily a problem; investigate if the crash rate exceeds 2 to...
> - Avoid: Looking only at the client. The server view needs owner or edit permission; ask the owner to check.
> - The team knows how to open the console on every platform, including the menu route on phones.
> - Server output is checked in a live server after every release.
> - Baseline memory per category recorded per release (client on a mid phone, server at full load).
>
> Cost: TL;DR ~180 tok · whole note ~4.7k tok. Read more: ## 3. Memory categories · ## 6. A gated debug overlay · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The Developer Console is the only debugging window that exists in a **live** game, on any device, including the server side of a real server. The `Stats` service is the scripting side of the same numbers. Together they let you answer "how much memory, in which category, how fast is the server ticking, what errors are firing" on a phone in a real server with real players, which Studio can never fully reproduce. This note covers the console's tools, the memory categories and what each means, the on-screen stat overlays, the `Stats` service API, and how to build your own gated debug overlay.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. Opening the console

Docs give three ways:
- Press **F9** (Ctrl+F9 / Cmd+F9 is also cited on the MicroProfiler page).
- Type **`/console`** in chat.
- Roblox menu, Settings tab, scroll to Developer Console, Open.

On a phone the menu route is the only practical one. The console works in Studio play tests too, but Docs recommend reading memory on the real client, not Studio, for accuracy.

### Who sees what
- **Client view**: anyone can see their own client's output and stats.
- **Server view**: Docs: only the experience owner, or group members with edit permission, can view server output. Everyone else sees only the client side.

The shortcut bar at the top shows the count of errors and warnings, client memory, and average ping (Docs). Watching that error counter tick up while you play is the cheapest bug detector there is.

---

## 2. The tools

The Docs page for the console lists four tools in the tools dropdown; other Docs pages refer to more tabs, and the console's contents have changed over the years. As of October 2026:

| Tool | What it shows | Source |
|---|---|---|
| **Log** | output from scripts, with a Client/Server toggle; filter by type, search | Docs (console page) |
| **Memory** | memory in MB per category, with a chart over time; Client/Server | Docs |
| **Luau heap** | snapshots of the Luau heap, comparable over time | Docs |
| **Network** | web (HTTP) call activity: counts, failures, timing, per-call detail | Docs |
| **Script Profiler** | sampling CPU profile of scripts | Docs |
| **MicroProfiler** | server recording of up to 60 frames | Docs (MicroProfiler page) |
| **Server Jobs** | engine job rates; Docs: check "Steps Per Sec" under Heartbeat for server tick rate | Docs (identify page) |
| **Server Stats** | includes average data ping | Docs (identify page) |

The console page and the "identify performance issues" page disagree about which tabs exist (the second mentions Server Jobs and Server Stats, the first does not). If a tab described here is missing in your client, check the tools dropdown; layouts change. Recorded for [[Open Questions - Whole Vault]].

Note that the **Network** tool here is about HTTP web calls (asset fetches, HttpService), not game replication traffic. Replication is in the stat overlays and the MicroProfiler networking labels ([[Network Performance]]).

### Log tool tips
- Server output during a live session is the fastest way to see a server-only error that never happens in Studio (DataStore throttling, a remote receiving an unexpected argument shape).
- Errors in the log include a stack trace; click to expand.
- Docs: client messages come from LocalScripts and Scripts with `RunContext = Client`; server messages from Scripts with `RunContext = Server` or `Legacy`.
- The console also has a command line for running Luau in the session for authorised users (Docs mention the command bar is reachable from the Developer Console). Treat it as you would any production console: read-only commands unless you mean it.

---

## 3. Memory categories

### Top level (Docs)
| Category | Meaning | Can you control it? |
|---|---|---|
| **CoreMemory** | engine core: networking, avatars, built-in GUI | little |
| **PlaceMemory** | how you built the game: models, terrain, parts, scripts, assets | yes, this is yours |
| **PlaceScriptMemory** | your scripts, per script and per custom memory tag | yes |
| **CoreScriptMemory** | Roblox's internal scripts | no |
| **UntrackedMemory** | allocations the engine cannot attribute | indirectly |

Docs: PlaceMemory and PlaceScriptMemory matter most.

### PlaceMemory subcategories (Docs)
| Subcategory | What grows it | Typical fix |
|---|---|---|
| `Instances` | instance count | streaming, deleting unused content, fewer parts |
| `Signals` | connections between instances | disconnect, destroy |
| `LuaHeap` | tables, closures, strings in scripts (core and yours) | fix leaks, reuse tables ([[Memory Budgets and Leaks]]) |
| `Script` | script bytecode | fewer, smaller scripts; generated code bloat |
| `PhysicsCollision` | collision data | lower `CollisionFidelity`, `CanCollide`/`CanQuery` off |
| `PhysicsParts` | physics geometry and kinetics | anchor, fewer parts |
| `GraphicsMeshParts` | mesh geometry for rendering | fewer unique meshes, lower poly, reuse ids |
| `GraphicsTexture` | textures | smaller textures, reuse ids ([[Textures Decals and Texture Memory]]) |
| `GraphicsTextureCharacter` | character textures | avatar-heavy servers |
| `GraphicsParticles`, `GraphicsParts`, `GraphicsSolidModels`, `GraphicsSpatialHash`, `GraphicsTerrain` | rendering data | scene density, terrain size |
| `Sounds`, `StreamingSounds` | loaded audio | do not preload every sound |
| `TerrainVoxels`, `TerrainPhysics` | terrain | smaller terrain, fewer materials in view |
| `Gui` | UI elements | destroy closed menus you will not reopen, avoid giant hidden UIs |
| `Animation` | pose data and cached KeyframeSequence data | track leaks, clip data in replicated containers |
| `Navigation` | pathfinding structures | fewer agents, smaller nav areas |
| `HttpCache` | assets fetched from Roblox and cached | many unique images and meshes |

### Reading patterns

| What you see | Likely cause |
|---|---|
| `LuaHeap` rising steadily while idle | leaked tables or closures (connections never disconnected) |
| `Instances` rising steadily | instances created and never destroyed, or destroyed but still referenced |
| `Animation` rising on equip and unequip | a new track per use ([[Engine Gotchas]]) |
| `GraphicsTexture` jumping when a menu opens | the menu loads many unique images; fine once, bad if it repeats |
| `Signals` rising | connections accumulating per respawn or per menu open |
| Server memory rising per player and never falling | per-player tables not cleared on `PlayerRemoving` |

Docs make the same points: high or growing LuaHeap suggests a leak, steadily growing instance counts suggest uncollected references, and Player objects are not destroyed automatically after leaving (enable `Workspace.PlayerCharacterDestroyBehavior` or clean up yourself).

### The `DeveloperMemoryTag` enum (Docs)

These are the tags you can query from scripts with `Stats:GetMemoryUsageMbForTag`:

`Internal` (0), `HttpCache` (1), `Instances` (2), `Signals` (3), `LuaHeap` (4), `Script` (5), `PhysicsCollision` (6), `BaseParts` (7), `GraphicsSolidModels` (8), `GraphicsMeshParts` (10), `GraphicsParticles` (11), `GraphicsParts` (12), `GraphicsSpatialHash` (13), `GraphicsTerrain` (14), `GraphicsTexture` (15), `GraphicsTextureCharacter` (16), `Sounds` (17), `StreamingSounds` (18), `TerrainVoxels` (19), `Gui` (21), `Animation` (22), `Navigation` (23), `GeometryCSG` (24), `GraphicsSlimModels` (25).

The enum and the console's category list do not match exactly: the console page lists `PhysicsParts` and `TerrainPhysics`, the enum has `BaseParts`, `GeometryCSG`, `GraphicsSlimModels` and `Internal`. Query by enum in code; read by name in the console.

---

## 4. On-screen stats

| Overlay | Shortcut (Docs) | Shows |
|---|---|---|
| Performance Stats bar | Ctrl+Alt+F7 (Cmd+Opt+F7) | memory, CPU, GPU, network, ping |
| Debug stats | Shift+Ctrl+F1 to F5 (identify page) | graphics, physics, network, fps overlays |
| Frame rate | Shift+F5 in the client (identify page) | fps summary |
| Render stats | Shift+F2 in the client; "Render Stats, Timing" in Studio (improve page) | draw calls and render timing |
| Data ping | Shift+F3 (identify page) | per-connection data ping |
| Studio stats | Window, Performance, Stats | Studio-side (skewed) |
| Network simulation | Alt+S (Opt+S) in Studio testing | add latency, jitter, loss |

The Docs pages use both "Shift+F" and "Shift+Ctrl+F" forms for the debug overlays; the Shift+Fn forms are the long-standing client shortcuts (rule of thumb). Try both.

**Two pings.** Docs distinguish network ping (round trip of a packet, mostly outside your control) from data ping (round trip through the replication system, including queueing). Data ping is always at least network ping. If data ping is far above network ping, the server or the connection's send queue is backed up: see [[Network Performance]].

---

## 5. The `Stats` service

`game:GetService("Stats")` exposes the same numbers to scripts. Properties (Docs; all read-only, not replicated, readable in parallel):

| Property | Use |
|---|---|
| `InstanceCount` | total instances in this DataModel |
| `PrimitivesCount`, `MovingPrimitivesCount` | parts, and parts currently moving |
| `ContactsCount` | physics contacts |
| `DataReceiveKbps`, `DataSendKbps` | replication data rates |
| `PhysicsReceiveKbps`, `PhysicsSendKbps` | physics replication rates |
| `HeartbeatTime`, `PhysicsStepTime`, `FrameTime` | time per heartbeat, physics step, frame |
| `RenderCPUFrameTime`, `RenderGPUFrameTime` | render cost (client) |
| `SceneDrawcallCount`, `SceneTriangleCount` | scene draw calls and triangles |
| `ShadowsDrawcallCount`, `ShadowsTriangleCount` | shadow pass |
| `UI2DDrawcallCount`, `UI2DTriangleCount`, `UI3DDrawcallCount`, `UI3DTriangleCount` | UI rendering |
| `MemoryTrackingEnabled` | whether memory tracking is on |

`HeartbeatTimeMs` and `PhysicsStepTimeMs` are **deprecated** in favour of `HeartbeatTime` and `PhysicsStepTime` (Docs). The reference page does not state units for the non-Ms versions; check in your build before you hard-code thresholds (unverified).

Methods usable from game scripts:
- `Stats:GetTotalMemoryUsageMb(): number`
- `Stats:GetMemoryUsageMbForTag(tag: Enum.DeveloperMemoryTag): number`

Other methods on the page (`GetMemoryCategoryNames`, `GetMemoryUsageMbAllCategories`, the Harmony methods) are tagged InternalTest; do not rely on them.

---

## 6. A gated debug overlay

A small overlay that developers can toggle on a phone in a live server is worth more than any amount of Studio profiling. It reads client stats locally and asks the server for its own numbers through a gated remote.

### Server side

```lua
--!strict
-- ServerScriptService/DebugStatsService.server.luau
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEV_USER_IDS: { [number]: true } = {
	-- [00000000] = true, -- add your team's UserIds
}

local function isDeveloper(player: Player): boolean
	return RunService:IsStudio() or DEV_USER_IDS[player.UserId] == true
end

-- Rolling heartbeat timing: 120 samples (about 2 s at 60 Hz).
local SAMPLE_COUNT = 120
local samples: { number } = table.create(SAMPLE_COUNT, 1 / 60)
local cursor = 0
RunService.Heartbeat:Connect(function(dt: number)
	cursor = cursor % SAMPLE_COUNT + 1
	samples[cursor] = dt
end)

local function heartbeatSummary(): (number, number)
	local total, worst = 0, 0
	for _, dt in samples do
		total += dt
		if dt > worst then
			worst = dt
		end
	end
	return SAMPLE_COUNT / total, worst * 1000 -- average Hz, worst ms
end

local remote = Instance.new("RemoteFunction")
remote.Name = "DebugServerStats"
remote.Parent = ReplicatedStorage

local lastAsk: { [Player]: number } = {}

remote.OnServerInvoke = function(player: Player)
	if not isDeveloper(player) then
		return nil -- the gate lives on the server, always
	end
	local now = os.clock()
	if now - (lastAsk[player] or 0) < 0.5 then
		return nil -- simple rate limit
	end
	lastAsk[player] = now

	local hz, worstMs = heartbeatSummary()
	return {
		hz = hz,
		worstMs = worstMs,
		totalMb = Stats:GetTotalMemoryUsageMb(),
		luaHeapMb = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.LuaHeap),
		instances = Stats.InstanceCount,
		players = #Players:GetPlayers(),
		sendKbps = Stats.DataSendKbps,
	}
end

Players.PlayerRemoving:Connect(function(player: Player)
	lastAsk[player] = nil -- no per-player leak
end)
```

### Client side

```lua
--!strict
-- StarterPlayerScripts/DebugOverlay.client.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("DebugServerStats") :: RemoteFunction

local gui = Instance.new("ScreenGui")
gui.Name = "DebugOverlay"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 1000
local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(320, 150)
label.Position = UDim2.fromOffset(8, 60)
label.BackgroundTransparency = 0.35
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.TextColor3 = Color3.new(1, 1, 1)
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.Font = Enum.Font.Code
label.TextSize = 14
label.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

-- Client frame timing.
local frames, frameAccum, worstFrame = 0, 0, 0
RunService.PreRender:Connect(function(dt: number)
	if not gui.Enabled then
		return -- gate: no work while hidden
	end
	frames += 1
	frameAccum += dt
	if dt > worstFrame then
		worstFrame = dt
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if not processed and input.KeyCode == Enum.KeyCode.F7 and input:IsModifierKeyDown(Enum.ModifierKey.Shift) then
		gui.Enabled = not gui.Enabled
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		if gui.Enabled and frames > 0 then
			local ok, server = pcall(function()
				return remote:InvokeServer()
			end)
			local lines = {
				string.format("client %.0f fps  worst %.1f ms", frames / frameAccum, worstFrame * 1000),
				string.format("client mem %.0f MB  heap %.0f MB", Stats:GetTotalMemoryUsageMb(),
					Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.LuaHeap)),
				string.format("instances %d  draw calls %d", Stats.InstanceCount, Stats.SceneDrawcallCount),
			}
			if ok and type(server) == "table" then
				table.insert(lines, string.format("server %.1f Hz  worst %.1f ms", server.hz, server.worstMs))
				table.insert(lines, string.format("server mem %.0f MB  heap %.0f MB  inst %d",
					server.totalMb, server.luaHeapMb, server.instances))
				table.insert(lines, string.format("players %d  send %.0f kbps", server.players, server.sendKbps))
			end
			label.Text = table.concat(lines, "\n")
			frames, frameAccum, worstFrame = 0, 0, 0
		end
	end
end)
```

Notes on the design:
- **The server gate is the security.** The overlay being hidden on the client protects nothing; anyone can fire any remote ([[Exploits and Anti-Cheat]]).
- **Worst frame, not just average.** A 60 fps average with a 90 ms worst frame is a hitch problem.
- **The overlay itself costs.** It updates text once per second and does no work while disabled.
- For phones, replace the keyboard toggle with a hidden button or a chat command that the server validates.

---

## 7. Using it in practice

### A memory leak hunt on a live server
1. Join a busy server as a developer. Open the console, Memory, Server view.
2. Note `LuaHeap`, `Instances`, `Signals` and total.
3. Wait 20 minutes of normal play, check again. Healthy servers plateau; leaking servers climb in a line.
4. If climbing, switch to Luau heap, take a snapshot, wait, take another, compare ([[Memory Budgets and Leaks]]).

### Confirming a phone crash cause
1. On the target phone, open the console via the menu.
2. Watch the client memory in the shortcut bar while doing the crashy action.
3. Memory tool, sort by size. A texture-heavy menu or a large map region usually stands out.
4. Cross-check the Performance dashboard's memory chart by device ([[Mobile and Low-End Optimization]]).

### Checking server tick health
Docs: the server heartbeat is capped at 60; check Server Jobs, Heartbeat, Steps Per Sec. A server holding 60 with 5 players and 40 with 30 players has a per-player cost to find. Record a server MicroProfiler dump at full load ([[MicroProfiler Guide]]).

---

## Common mistakes

- Reading memory in Studio and trusting it. Studio's numbers include Studio.
- Treating high memory as a bug. Docs: high usage alone is not necessarily a problem; investigate if the crash rate exceeds 2 to 3%, especially after an update.
- Looking only at the client. The server view needs owner or edit permission; ask the owner to check.
- Confusing the Network tool (HTTP calls) with replication bandwidth.
- Polling `Stats` every frame in a shipped overlay with no gate.
- Hard-coding thresholds on deprecated `...Ms` properties.

## Checklist

- [ ] The team knows how to open the console on every platform, including the menu route on phones.
- [ ] Server output is checked in a live server after every release.
- [ ] Baseline memory per category recorded per release (client on a mid phone, server at full load).
- [ ] A gated debug overlay exists, with server-side authorisation and rate limiting.
- [ ] Per-player state is cleared on `PlayerRemoving`.
- [ ] Memory-tag queries use `Enum.DeveloperMemoryTag` values that exist.

## See also

[[Performance Fundamentals]] · [[MicroProfiler Guide]] · [[Memory Budgets and Leaks]] · [[Script Performance]] · [[Network Performance]] · [[Crash and Error Telemetry]] · [[Debugger Breakpoints and Logging]] · [[Multi-Client and Live Testing]]

## Connected notes
<!-- auto-links:start -->
[[Hunting Memory Leaks Step by Step]] · [[Debugging Live Servers]] · Skill - Roblox Performance Audit · Official Docs - Performance · Studio Settings and Shortcuts
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Load and Soak Testing Servers - Long Sessions and Many Clients]] · [[Network Bandwidth Budgets and Measuring Them]] · [[Physics Performance]] · [[Rendering Performance]] · [[QA Checklists Before Release]] · [[Weather Performance Budgets and Quality Tiers]]
<!-- related:end -->
