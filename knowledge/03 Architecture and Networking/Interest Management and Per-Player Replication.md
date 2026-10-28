---
tags: [networking, replication, streaming, interest-management, bandwidth, privacy]
---
# Interest Management and Per-Player Replication

<!-- tldr:start -->
> [!tldr] TL;DR
> - Entities flicker in and out at range: Single radius -> Enter/leave hysteresis
> - Ghost entities that never disappear: Despawn sent unreliably, or lost on teleport -> Reliable enter/leave; recompute after teleports
> - Bandwidth grows with players squared: Broadcast inside a per-player loop -> Per-player batches of relevant entities only
> - Each data kind has a channel chosen deliberately: streaming, owner-only, remote per player, or broadcast.
> - Bandwidth estimated as entities x rate x bytes per relevant player, against a low tens of kbps target.
> - Relevance sets use hysteresis; enter carries a snapshot; enter/leave are reliable.
>
> Read more (20 KB note): ## 1. What the engine gives you · ## 4. Building a relevance layer · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Interest management means deciding, **per player**, what that player's client needs to know, how often, and at what detail. By default Roblox replicates the server's DataModel to everyone, filtered only by Instance Streaming distance and a few owner-only containers. That default is fine for small games and wasteful or leaky for large ones: 40 enemies across a 4 km map do not all need 20 updates per second to every player, and one player's hidden loot table should never reach anyone else.

This note covers what the engine gives you for per-player replication, what it does not, how to build an interest layer for remote-driven data (relevance sets, distance tiers, priority accumulation, hysteresis), the bandwidth arithmetic that justifies it, hidden information, and the failure modes. It builds on [[Replication Rules]], [[Instance Streaming]] and [[Network Performance]].

Engine facts are from the Roblox docs (as of October 2026). Numbers marked measured come from the reference project; the rest are rules of thumb.

---

## 1. What the engine gives you

| Mechanism | What it filters | Notes |
|---|---|---|
| **Instance Streaming** (`StreamingEnabled`) | Workspace instances by distance from each player's replication focus | Spatial interest for instances; `StreamingTargetRadius` is the maximum stream-in distance, `StreamingMinRadius` the highest-priority radius (Roblox docs) |
| **`Player.ReplicationFocus`, `AddReplicationFocus`, `RemoveReplicationFocus`** | Moves or adds the points streaming is centred on | Each extra focus adds server streaming work (the docs' example: one player with nine moving foci costs about as much as ten players) |
| **`ModelStreamingMode`** | Per-model streaming behaviour: `Default`, `Atomic`, `Persistent`, `PersistentPerPlayer`, `Nonatomic` | `PersistentPerPlayer` behaves as `Persistent` for players added with `Model:AddPersistentPlayer()` and as `Atomic` for everyone else (Roblox docs); revert with `RemovePersistentPlayer()` |
| **`PlayerGui`, `PlayerScripts`** | Only the owning client receives them | The only built-in containers that replicate to exactly one player ([[Client-Server Model]]) |
| **ServerStorage, ServerScriptService** | Never replicate | Server-private |
| **Client-created instances** | Exist only on that client | The client builds them from data you send |
| **`RemoteEvent:FireClient`** | You choose the recipient | Full control, full responsibility |

What the engine does **not** give you, as far as the docs and DevForum show as of October 2026: a general way to say "replicate this Workspace instance to these players only". `PersistentPerPlayer` does not hide a model from other players; it only changes whether it is kept loaded for the listed players. DevForum feature requests for selective replication exist; no shipped API was found. Treat any Workspace instance as visible to every client that streams that area.

Consequences:

- **Spatial interest for instances**: let streaming do it. Do not fight it.
- **Per-player interest for data** (who sees which enemy's health, which player sees which quest marker, private state): use remotes or owner-only containers.
- **Heavy presentation** (effects, decorations, per-player cosmetics): send a small recipe, build client-side.

---

## 2. The bandwidth arithmetic

Interest management pays off when update volume grows as entities x players x rate. Work the numbers before building anything.

Suppose each server-driven entity update is about 16 bytes of payload (an id plus a quantised position and a few flags, packed into a buffer; see [[Buffers and Binary Data]]), plus per-message overhead (rule of thumb: assume tens of bytes per remote call, which is why batching matters).

| Design | Entities | Rate | Per player per second | Notes |
|---|---|---|---|---|
| Every entity to every player, one remote call each | 60 | 20 Hz | 1,200 calls, about 19 KB payload plus overhead | Overhead dominates; far too much for phones |
| Same, batched into one call per tick | 60 | 20 Hz | 20 calls, about 19 KB | Much better, still about 150 kbps |
| Interest tiers (near 15 at 20 Hz, mid 20 at 5 Hz, far 25 at 0 Hz) batched | 35 relevant | mixed | 20 calls, about 6.4 KB | About 51 kbps |
| Tiers plus send-on-change (idle enemies skip) | 35 | mixed | 20 calls, typically 2 to 4 KB | Low tens of kbps |

[[Network Performance]] suggests keeping average outgoing game data per player in the low tens of kbps (rule of thumb). Only the last two rows meet that. Note what made the difference: relevance and frequency, not compression.

Server cost scales too. If the server computes one batch per player, CPU is players x relevant entities per tick, which is why the relevance query must be cheap (section 4).

---

## 3. Choosing a channel per kind of data

| Data | Visible to | Channel |
|---|---|---|
| Map, props, static world | Everyone nearby | Workspace + streaming |
| NPC bodies and their animation state | Everyone nearby | Workspace model + attributes (streaming filters by distance). **Measured:** the reference project writes enemy animation state as attributes only; clip data is streamed once per client as compiled buffers |
| High-rate NPC positions for custom-moved NPCs | Nearby players, tiered | Batched remote per player, unreliable for position, reliable for spawn/despawn |
| Own private state (currency, inventory, quests, cooldowns) | Owner only | `FireClient` deltas, or attributes on an object inside the owner's `PlayerGui` ([[Network Performance]] section 4.6) |
| Hidden information (other players' hands, role in a social deduction game, loot rolls before reveal) | Nobody until revealed | Server only; send at reveal time to the right players |
| Cosmetic effects from other players | Players who can see them | Server relays a recipe to players in range |
| World events (boss spawned, server message) | Everyone | `FireAllClients`, reliable |

Attributes and properties on Workspace instances are **broadcast** to everyone who has that instance streamed in. Use them for data that is truly public and spatially relevant. The moment data is per-player or private, it belongs in a remote or `PlayerGui`.

---

## 4. Building a relevance layer

### 4.1 Relevance sets with hysteresis

Each player has a set of entities they are subscribed to. Each tick (or every few ticks), the server recomputes it from distance, with **two radii**: enter at a smaller radius, leave at a larger one. Without hysteresis, an entity hovering at the boundary flaps in and out, causing a spawn/despawn message pair every tick.

```lua
--!strict
-- Server: per-player interest sets with hysteresis and enter/leave messages.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ENTER_RADIUS = 220
local LEAVE_RADIUS = 260
local RECOMPUTE_EVERY = 0.25 -- seconds

type Entity = { id: number, position: Vector3 }

local entities: { [number]: Entity } = {}
local subscribed: { [Player]: { [number]: boolean } } = {}

local Spawned: RemoteEvent -- reliable: (entityId, snapshot)
local Despawned: RemoteEvent -- reliable: (entityId)

local function focusOf(player: Player): Vector3?
	local char = player.Character
	local root = char and char.PrimaryPart
	return root and root.Position
end

local function recompute(player: Player)
	local focus = focusOf(player)
	if not focus then return end
	local set = subscribed[player]
	if not set then
		set = {}
		subscribed[player] = set
	end
	local enter2, leave2 = ENTER_RADIUS * ENTER_RADIUS, LEAVE_RADIUS * LEAVE_RADIUS

	for id, e in entities do
		local d = e.position - focus
		local dist2 = d:Dot(d)
		if set[id] then
			if dist2 > leave2 then
				set[id] = nil
				Despawned:FireClient(player, id)
			end
		elseif dist2 <= enter2 then
			set[id] = true
			Spawned:FireClient(player, id, snapshotOf(e)) -- full state on enter
		end
	end
	-- entities removed from the world entirely
	for id in set do
		if not entities[id] then
			set[id] = nil
			Despawned:FireClient(player, id)
		end
	end
end

local accum = 0
RunService.Heartbeat:Connect(function(dt)
	accum += dt
	if accum < RECOMPUTE_EVERY then return end
	accum = 0
	for _, player in Players:GetPlayers() do
		recompute(player)
	end
end)

Players.PlayerRemoving:Connect(function(p) subscribed[p] = nil end)
```

This loop is players x entities per recompute. With 30 players and 500 entities at 4 Hz that is 60,000 distance checks per second, cheap in Luau. Past a few thousand entities, swap the inner loop for a spatial hash query ([[Luau Performance Patterns with Benchmarks]], spatial hashing). Also spread players across ticks (recompute a third of them each tick) to avoid a spike every 0.25 s.

Rules that matter:

- **Snapshot on enter, deltas after.** A client that just subscribed has no prior state; send everything it needs in the enter message.
- **Enter and leave are reliable; position updates can be unreliable.** A lost position is replaced by the next one; a lost despawn leaves a ghost forever.
- **Ordering across remotes is not guaranteed** between different remote instances in general ([[Replication Rules]]). If a position update for an entity arrives before its spawn message, ignore it; do not create a half-initialised entity.

### 4.2 Distance tiers

Not every relevant entity needs the same rate:

| Tier | Distance | Rate | Detail |
|---|---|---|---|
| Near | under 60 studs | 20 Hz | Position, facing, animation state, health |
| Mid | 60 to 160 | 5 Hz | Position, coarse state |
| Far | 160 to 260 | 1 Hz or on change | Existence and position only |
| Out | beyond leave radius | none | Despawned |

The client interpolates between updates. Lower tiers need longer interpolation buffers (at 5 Hz, interpolate over about 250 ms; at 1 Hz, simply tween to the new position). Distances depend on camera and map scale; tie them to what the player can actually see, not to round numbers.

**Measured:** the reference project's server audit distance-filtered per-hit broadcasts (blood effects, hit sounds, projectile positions) at 320 studs, matching its enemy "near" radius, instead of sending them to every player ([[Network Performance]]). It uses the same idea client-side for presentation: map animations run only within a range (900 studs for gate frames, 280 to 650 for hub effects), flocks unparent beyond 900 studs, foliage sway runs near the camera only, and arena floaters are quality-gated. Relevance is as much a client CPU tool as a network one ([[Script Performance]]).

### 4.3 Priority accumulation under a byte budget

Tiers are fixed. A priority accumulator adapts to load. Each entity gains priority every tick in proportion to its importance for that player (closer, in view, targeting the player, recently changed); each tick, the server sends the highest-priority entities until a byte budget is spent, and resets their priority to zero. Entities that were skipped keep accumulating, so they are guaranteed to be sent eventually.

```lua
--!strict
-- Continues the module above (uses `entities` and `Entity`).
-- Per-player priority send with a byte budget. Call once per network tick per player.
local BYTES_PER_TICK = 400 -- e.g. 20 Hz x 400 B = 8 KB/s payload ceiling
local ENTRY_BYTES = 16

local priority: { [Player]: { [number]: number } } = {}
local candidates: { number } = {} -- reused scratch list

local function weight(e: Entity, focus: Vector3, changed: boolean): number
	local d = (e.position - focus).Magnitude
	local w = 1 / math.max(d / 20, 1) -- 1 at 20 studs or closer, falls off with distance
	if changed then w *= 4 end
	return w
end

local function selectToSend(player: Player, focus: Vector3, set: { [number]: boolean },
	changedThisTick: { [number]: boolean }): { number }
	local pri = priority[player]
	if not pri then
		pri = {}
		priority[player] = pri
	end
	table.clear(candidates)
	for id in set do
		local e = entities[id]
		if e then
			pri[id] = (pri[id] or 0) + weight(e, focus, changedThisTick[id] == true)
			table.insert(candidates, id)
		end
	end
	table.sort(candidates, function(a, b)
		local pa, pb = pri[a], pri[b]
		if pa ~= pb then return pa > pb end
		return a < b -- strict tie-break, see Tables Metatables and OOP
	end)
	local maxEntries = BYTES_PER_TICK // ENTRY_BYTES
	local out = table.create(math.min(maxEntries, #candidates))
	for i = 1, math.min(maxEntries, #candidates) do
		local id = candidates[i]
		pri[id] = 0
		out[i] = id
	end
	return out
end
```

Then pack the selected entities into one `buffer` and send it with an `UnreliableRemoteEvent`. Mind the unreliable payload limit (1,000 bytes per call per the Roblox docs, see [[RemoteEvents RemoteFunctions and Unreliable Remotes]]); `BYTES_PER_TICK = 400` keeps one call per tick comfortably below it. Clear `priority[player]` entries when an entity leaves that player's set, and the whole table on `PlayerRemoving`.

Sorting all candidates every tick is O(n log n) per player. For a few dozen relevant entities this is trivial. For hundreds, take the top K with a partial selection or bucket by priority.

---

## 5. Per-player private state

Two proven patterns ([[Network Performance]] section 4.6):

1. **Remote deltas.** The server sends `FireClient(player, changes)` after each mutation, coalesced per tick. Precise and flexible.
2. **Owner-only attribute holder.** The server keeps a disabled `ScreenGui` (with `ResetOnSpawn = false`) inside the player's `PlayerGui` and writes attributes on it. Only the owner receives them. Client code reads attributes and listens with `GetAttributeChangedSignal`. **Measured:** the reference project's biggest single network fix was exactly this move. Five large JSON strings (inventory, bestiary, quests, potions, collection progress) had been attributes on the `Player` object, so every update to any player's inventory went to every client. Moving them to a `PlayerGui` holder, with a small client script mirroring them locally so existing readers kept working, ended a server-wide "immense lag" report. Other players' data, when genuinely needed, is fetched on demand through a remote.

What not to do: put private values as attributes on the player's **character** or the `Player` object. Those replicate to everyone. Leaderstats are public by design; never store anything there you would not show on the leaderboard.

---

## 6. Hidden information and exploit visibility

Anything that reaches a client is readable by an exploiter on that client: instances, attributes, remote payloads, ModuleScripts in ReplicatedStorage. Interest management is therefore also an **information security** tool ([[Exploits and Anti-Cheat]], ESP and data mining):

| Leak | Example | Fix |
|---|---|---|
| Positions of hidden players | Stealth or hide-and-seek characters streamed with full position | Do not replicate the hidden character's true position to opponents; the server decides visibility and sends only what is seen. With client-owned characters this is hard; consider a server-owned stand-in or the server authority model ([[Client Prediction and Reconciliation for Combat]]) |
| Future content | Next wave's spawn list, loot tables with exact weights, unreleased items in ReplicatedStorage | Keep in ServerStorage; send on use |
| Other players' private data | Inventories in public attributes | Owner-only channels; send others only what the UI shows |
| Roles | "Impostor" as a public attribute | Server-only; reveal to the right players at the right time |
| Rewards before reveal | Case-opening result sent before the animation | Fine if the animation is cosmetic and the result is already final; never send the roll seed |

Streaming does not hide things: anything within the stream radius, or set to `Persistent`, is sent. [[Instance Streaming]] says this directly: streaming is not a security boundary.

---

## 7. Client-built presentation

The cheapest replication is none. For effects and decoration, send the **recipe** and let each relevant client build it:

- Server: `EffectRelay:FireClient(player, "ShockRing", position, radius, serverTime)` to players in range.
- Client: looks up the recipe, builds or clones from a local template, fast-forwards by `GetServerTimeNow() - serverTime`, cleans up itself.

Benefits: no server-side parts (no replication of creation, property changes and destruction), per-client quality settings, and no physics on the server. **Measured:** the reference project relays player flourishes through a server-validated relay, computes blade-in-hand offsets on every client from shared data instead of replicating CFrames, and plays synchronised one-off animations by writing a single attribute that every client turns into the same 4.4 s eased spin. Each replaces a stream of replicated property changes with one small message.

When not to: anything that affects gameplay (hitboxes, collisions, pickups) must exist on the server, and anything that must look identical for fairness (a telegraph that players dodge) must use the same data on every client.

---

## 8. Streaming interplay

Remote-driven interest and Instance Streaming run side by side, and they disagree at the edges:

- A remote may mention an instance the client has not streamed in. Instance references in remote arguments arrive as `nil` when the client does not have that instance. Send ids and resolve them locally, and tolerate "not here yet".
- Your relevance radius and `StreamingTargetRadius` should be chosen together. If your interest radius is larger than the stream radius, clients receive data for models they cannot render; if it is much smaller, streamed models sit frozen without state.
- Teleports: after moving a player, their old subscriptions are all wrong. Run `recompute` immediately for that player, and use `Player:RequestStreamAroundAsync` before the move so the destination is loaded ([[Instance Streaming]]).
- Extra replication foci (spectating, cameras following a remote object) also need matching interest updates, or the spectator sees a streamed world with no entity state.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Entities flicker in and out at range | Single radius | Enter/leave hysteresis |
| Ghost entities that never disappear | Despawn sent unreliably, or lost on teleport | Reliable enter/leave; recompute after teleports |
| Bandwidth grows with players squared | Broadcast inside a per-player loop | Per-player batches of relevant entities only |
| Half-initialised entities on the client | Update arrived before spawn | Ignore updates for unknown ids |
| Exploiters see hidden players or future loot | Data replicated publicly | Owner-only or server-only; reveal on demand |
| Server spikes every recompute | All players recomputed in one tick | Stagger across ticks; spatial hash |
| Unreliable sends silently dropped | Payload above the unreliable limit | Budget bytes per tick below it |
| Private values visible on others' clients | Attributes on character or Player | `PlayerGui` holder or `FireClient` |

## Checklist

- [ ] Each data kind has a channel chosen deliberately: streaming, owner-only, remote per player, or broadcast.
- [ ] Bandwidth estimated as entities x rate x bytes per relevant player, against a low tens of kbps target.
- [ ] Relevance sets use hysteresis; enter carries a snapshot; enter/leave are reliable.
- [ ] Position updates are batched, tiered by distance, and unreliable within the payload limit.
- [ ] Priority or tiering keeps per-player bytes per tick under a budget.
- [ ] Private and hidden data never sits in public attributes, leaderstats or ReplicatedStorage.
- [ ] Effects are relayed as recipes and built on clients in range.
- [ ] Interest radius chosen together with streaming radii; teleports trigger recompute.
- [ ] All per-player interest state cleared on `PlayerRemoving`.

## See also

[[Replication Rules]] · [[Instance Streaming]] · [[Network Performance]] · [[Client-Server Model]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Buffers and Binary Data]] · [[Exploits and Anti-Cheat]] · [[Client Prediction and Reconciliation for Combat]] · [[Remote Abuse Patterns and Rate Limiting in Practice]] · [[Script Performance]] · [[Level of Detail and Model Streaming]]

## Connected notes
<!-- auto-links:start -->
[[Network Bandwidth Budgets and Measuring Them]] · [[2D Multiplayer - Server Authority and Replicating GUI Worlds]] · [[Streaming Radius]] · [[Replication Boundary]] · [[Cookbook - Remotes and Networking]] · [[How Exploits Work - The Client Boundary]]
<!-- auto-links:end -->
