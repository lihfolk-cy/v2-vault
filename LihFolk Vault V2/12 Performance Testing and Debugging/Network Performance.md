---
tags: [performance, networking, replication, remotes, bandwidth, ping, type/guide, area/performance, level/intermediate, api/UnreliableRemoteEvent, area/networking]
---
# Network Performance

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Large values in attributes on the Player or on Workspace objects that change often.
> - Avoid: `FireAllClients` for effects only nearby players can see.
> - Avoid: Firing remotes on mouse move, RenderStepped or Heartbeat without throttling.
> - Outgoing kbps per player measured with a multi-client test during combat and menus.
> - Data ping close to network ping under load.
> - No large or frequently changing attributes on Player or broadly replicated instances.
>
> Cost: TL;DR ~160 tok · whole note ~3.6k tok. Read more: ## 2. Measuring · ## 4. Patterns that cut traffic · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Network problems look like everything else: "lag", rubber-banding, hits that land late, a server that feels slow although its heartbeat is fine. The cause is usually **replicating more than needed, to more players than needed, more often than needed**. This note covers what goes over the wire, how to measure it, the limits that matter, and the patterns that cut traffic: results instead of simulation, batching, distance filtering, owner-only state, client-side effects, and load-time replication.

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

Architecture background: [[Client-Server Model]], [[Replication Rules]], [[RemoteEvents RemoteFunctions and Unreliable Remotes]].

---

## 1. What goes over the wire

| Traffic | Direction | Triggered by |
|---|---|---|
| Property changes | server to clients | any write to a replicated instance's property (including from server tweens) |
| **Attributes** | server to clients | `SetAttribute` on a replicated instance; every client that has the instance receives it |
| New and destroyed instances | server to clients | `Instance.new` + parent, `Clone`, `Destroy` in replicated containers |
| Remote events and functions | both | your `FireClient`, `FireAllClients`, `FireServer`, `InvokeServer` |
| Physics | owner to others | unanchored assemblies' motion |
| Humanoid and animation state | server and owners to others | characters and NPCs |
| Streaming | server to client | regions entering a client's streaming radius |
| Join payload | server to client | ReplicatedFirst, ReplicatedStorage, the initial Workspace region, StarterGui copies |

The trap in this list is that **only remotes look like networking in your code**. A single innocent-looking `player:SetAttribute("Inventory", json)` replicates the whole string to every client in the server, every time it changes.

---

## 2. Measuring

| Tool | Shows |
|---|---|
| `Stats.DataSendKbps`, `DataReceiveKbps`, `PhysicsSendKbps`, `PhysicsReceiveKbps` | live rates on the side that reads them |
| Performance Stats bar (Ctrl+Alt+F7, Docs) | network data and ping |
| Shift+F3 (Docs) | per-connection data ping |
| Developer Console, Server Stats (Docs) | average data ping |
| MicroProfiler | `Replicator/ProcessPackets` (incoming), `Allocate Bandwidth and Run Senders` (outgoing), `Dispatch StreamJob` (streaming) |
| Studio Network Simulator (Alt+S, Docs) | test under latency, jitter and packet loss |
| Studio Settings, Network, **Print Join Size Breakdown** (Docs) | largest contributors to the join payload |

### Network ping versus data ping (Docs)
- **Network ping**: round trip of a packet; mostly the player's connection.
- **Data ping**: round trip through the replication system, including queueing and retransmission; always at least network ping.

If data ping is far above network ping, something is queueing: the server is sending more than the connection can take, or the server's heartbeat is degraded (Docs: degraded heartbeat raises ping). Inspect outgoing traffic in a server MicroProfiler dump.

### A quick traffic probe
```lua
--!strict
-- Server: log outgoing data rate once per second while a test scenario runs.
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")

task.spawn(function()
	while true do
		task.wait(1)
		local n = math.max(1, #Players:GetPlayers())
		print(string.format("send %.1f kbps total, %.1f kbps per player, physics send %.1f kbps",
			Stats.DataSendKbps, Stats.DataSendKbps / n, Stats.PhysicsSendKbps))
	end
end)
```
Run it with a multi-client test ([[Multi-Client and Live Testing]]) while doing the suspect action. A number that grows with the square of players means a broadcast inside a per-player loop.

---

## 3. Limits worth knowing

| Limit | Value | Source |
|---|---|---|
| `UnreliableRemoteEvent` payload | events over **1000 bytes are dropped**; Studio logs how far over | Docs |
| `UnreliableRemoteEvent` rate | roughly 500 requests per second per client, shared across all unreliable remotes; RemoteEvents have a separate limit of the same size | Docs |
| Unreliable ordering and delivery | no ordering, no guaranteed delivery, no resend | Docs |
| Remote with no listener | may log "Remote event invocation discarded" | Docs |
| HttpService | about 500 requests per minute per server | widely documented; see [[HttpService and External APIs]] |

Sustained per-player bandwidth: Roblox does not publish a single cap. Rule of thumb: keep average outgoing game data per player in the low tens of kbps and avoid bursts of hundreds of KB on common actions; phones on mobile data feel bursts first.

---

## 4. Patterns that cut traffic

### 4.1 Replicate results, not simulation
Send "enemy 12 died at this position", not enemy 12's health every frame. Send "player cast Fireball at target T at server time S", and let every client draw the fireball. Docs: let clients create explosions and spells locally; the server only needs the outcome.

### 4.2 Never tween or animate replicated properties on the server
Docs: server tweens replicate every frame, causing jitter and extra traffic. Tween on the client. Same for per-frame `CFrame` updates of decorative parts from the server: let clients move them ([[Physics Performance]] for `BulkMoveTo`).

### 4.3 Only on change, and throttled
Docs: don't replicate data every frame if it doesn't change; throttle replication triggered by user input. A mouse-aim direction sent on every mouse move is hundreds of events per second; send at 10 to 20 Hz and only when it changed by more than a threshold.

### 4.4 Send only what changed
Docs example: send the purchased item, not the whole inventory. Design state messages as deltas with a full snapshot on join (late joiners need the snapshot; see [[Multi-Client and Live Testing]]).

### 4.5 Batch high-frequency messages
Many tiny remotes per frame cost per-message overhead. Collect them and send one per tick.

```lua
--!strict
-- Server: batch per-tick hit events per client, distance-filtered, sent on an unreliable remote.
-- Each hit is { x, y, z, kind } packed as numbers; payload must stay under 1000 bytes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HitFx = Instance.new("UnreliableRemoteEvent")
HitFx.Name = "HitFx"
HitFx.Parent = ReplicatedStorage

local RADIUS = 320 -- studs; beyond this a client does not need the effect
-- 4 numbers per hit. Assume roughly 9 bytes per number on the wire (rule of thumb, unverified):
-- 20 hits = 80 numbers = about 720 bytes, a margin under the 1000-byte limit.
local MAX_PER_PACKET = 20
local TICK = 1 / 20

local pending: { { number } } = {}

local HitBroadcast = {}

function HitBroadcast.queue(position: Vector3, kind: number)
	table.insert(pending, { position.X, position.Y, position.Z, kind })
end

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < TICK or #pending == 0 then
		return
	end
	acc = 0
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character.PrimaryPart
		if root then
			local here = root.Position
			local flat: { number } = {}
			for _, h in pending do
				local dx, dy, dz = h[1] - here.X, h[2] - here.Y, h[3] - here.Z
				if dx * dx + dy * dy + dz * dz < RADIUS * RADIUS then
					table.move(h, 1, 4, #flat + 1, flat)
					if #flat >= MAX_PER_PACKET * 4 then
						break -- drop the rest: cosmetic only
					end
				end
			end
			if #flat > 0 then
				HitFx:FireClient(player, flat)
			end
		end
	end
	table.clear(pending)
end)

return HitBroadcast
```

Notes:
- Cosmetic effects on an unreliable channel: a lost packet loses a spark, not a game state.
- Distance filter per recipient. **Measured:** the reference project's server audit distance-filtered per-hit broadcasts (blood effects, hit sounds, projectile positions) at 320 studs, matching its enemy "near" radius, instead of sending them to everyone.
- For tighter packing, encode into a `buffer` (see [[Buffers and Binary Data]]); Docs warn it is hard to predict the encoded size, so keep a safety margin under 1000 bytes.

### 4.6 Owner-only private state
Anything only the owning player needs (inventory, quest progress, bestiary, settings) should not be replicated to everyone.

**Measured, the biggest single network fix in the reference project.** After a report of "immense lag", the audit found five large JSON strings (inventory, bestiary, quests, potions, collection progress) stored as **attributes on the Player object**. Player objects replicate to every client, so every update to any player's inventory was sent to every player in the server. With full servers and frequent updates this was a steady flood. The fix:
- The server writes those values as attributes on an instance inside **that player's PlayerGui** (a disabled ScreenGui with `ResetOnSpawn = false`, rebuilt if removed). PlayerGui contents replicate only to the owning client.
- A small client script mirrors them onto the local Player object locally, so existing client code that read `player:GetAttribute("InventoryJson")` kept working unchanged.
- Other players' data, when genuinely needed (inspecting someone's inventory), is requested on demand through a remote.
- A rule went into the project notes: never `player:SetAttribute` these again.

In the same pass, a 3-second per-player state push loop was made to yield between players, and a potion resync went from every 5 s for everyone to every 30 s only while a potion is active.

A remote-based alternative is equally valid: `FireClient` the delta to its owner. The PlayerGui trick is attractive when lots of existing client code already reads attributes.

### 4.7 Instance trees
Creating or destroying large hierarchies at runtime is network-heavy (Docs). Chunk big builds over several frames ([[Script Performance]] time-slicing), keep templates on the client when only clients need them, and prefer toggling existing instances to cloning new ones.

### 4.8 Animation data
Docs: remove animation metadata from rigs, especially Animation Editor data, before publishing. The reference project's replicated enemy clips were keyed on every joint at 16 to 25 fps (about 323k instances in ReplicatedStorage); publishing clips as animation assets instead of shipping KeyframeSequences would cut that sharply. See [[Case Study - Cutting a Million Instances]].

---

## 5. Join-time replication

Docs: everything in ReplicatedStorage replicates before players can interact; keep only what is needed at join and move large assets to ServerStorage. ReplicatedFirst should hold only loading-screen essentials. With instance streaming, only the area near spawn is sent first.

Checklist for a fast join (Docs plus rule of thumb):
- Run Print Join Size Breakdown; fix the top entries.
- Move rarely used content to ServerStorage and clone it to the client's area when needed.
- Enable instance streaming ([[Instance Streaming]]); stream the destination before teleporting a player within the place (`Player:RequestStreamAroundAsync`).
- Defer non-essential UI and systems until after the first frame of play. See [[Case Study - Fast Join and Deferred Loading]].

**Measured streaming setup** in the reference project (a hub plus realms): StreamingMinRadius 256, StreamingTargetRadius 1024, StreamOutBehavior Opportunistic, ModelStreamingBehavior Improved, StreamingIntegrityMode MinimumRadiusPause; every server-side teleport within the place streamed the destination first. These Workspace properties are set in Studio's Properties panel and could not be set by script. Project choices, not universal recommendations.

---

## 6. Physics replication
Unanchored assemblies replicate their motion from the owner to everyone else; many moving server-owned parts is steady physics traffic (`PhysicsSendKbps`). Anchor and move cosmetic pieces on the client; give server ownership only to what must be authoritative ([[Network Ownership]]).

---

## Common mistakes

- Large values in attributes on the Player or on Workspace objects that change often.
- `FireAllClients` for effects only nearby players can see.
- Firing remotes on mouse move, RenderStepped or Heartbeat without throttling.
- Server-side TweenService on world objects.
- Sending full state instead of deltas, or deltas with no join snapshot.
- Unreliable remotes for state that must arrive (purchases, inventory).
- Payloads near 1000 bytes on unreliable remotes (silently dropped).
- Giant ReplicatedStorage "because the client might need it".

## Checklist

- [ ] Outgoing kbps per player measured with a multi-client test during combat and menus.
- [ ] Data ping close to network ping under load.
- [ ] No large or frequently changing attributes on Player or broadly replicated instances.
- [ ] Private per-player state replicates only to its owner.
- [ ] Cosmetic events batched, distance-filtered and on unreliable remotes with a size margin.
- [ ] No server tweens or per-frame server property writes for cosmetics.
- [ ] Join size breakdown reviewed; ReplicatedStorage contains only join-time essentials.
- [ ] Tested with the Network Simulator at high latency and some packet loss.

## See also

[[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Replication Rules]] · [[Instance Streaming]] · [[Network Ownership]] · [[Rate Limiting and Abuse Prevention]] · [[Buffers and Binary Data]] · [[Script Performance]] · [[Case Study - Fast Join and Deferred Loading]] · [[Replication and Ownership]]

## Connected notes
<!-- auto-links:start -->
[[Network Bandwidth Budgets and Measuring Them]] · [[Interest Management and Per-Player Replication]] · Replication Boundary · [[Performance Fundamentals]] · Debugging Client-Server Desync · Cookbook - Remotes and Networking
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Replication Boundary]] · [[Debugging Client-Server Desync]] · [[StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs]] · [[MicroProfiler Guide]] · [[Load and Soak Testing Servers - Long Sessions and Many Clients]] · [[Developer Console and Stats]] · [[Mobile and Low-End Optimization]] · [[Memory Budgets and Leaks]] · [[QA Checklists Before Release]]
<!-- related:end -->
