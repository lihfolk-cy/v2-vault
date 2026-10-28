---
tags: [2d, multiplayer, networking, server-authority, replication, snapshots, prediction, buffers, unreliable-remotes, luau]
---
# 2D Multiplayer - Server Authority and Replicating GUI Worlds

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Moving a Frame and expecting others to see it.
> - Avoid: Sending positions from the client in a competitive game.
> - Avoid: Consuming every queued input per tick. Symptom: players with spikes surge forward, and speed hacks work.
> - Architecture chosen (server simulation, client authority with checks, or commands) and written down.
> - Shared step module: fixed `dt`, seeded `Random`, arrays not dictionary order, no clock reads.
> - Server loop on `Heartbeat` with accumulator; one input per player per tick; queue capped.
>
> Read more (29 KB note): ## 3. The server match loop · ## 4. Packing data into buffers · ## 10. Common mistakes · ## 11. Checklist
<!-- tldr:end -->

A GUI-rendered 2D world does not exist on the network. The `ImageLabel` that is your player was created by a LocalScript inside a `PlayerGui`, the server never heard of it, and no other client can see it. In a 2.5D game the engine replicates characters, physics and parts for you; in a GUI game you are writing netcode for every moving thing. This note is the plan for doing that well: which of three architectures fits your game, how to keep a shared deterministic simulation, how to pack inputs and snapshots into buffers that fit the remote limits, how other players are interpolated, how your own player is predicted and corrected, and how to stop the obvious cheats.

Read [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]] first: everything here assumes its rule that the simulation is plain data in tables and the renderer only draws. If you are still deciding between routes, the multiplayer question in [[Choosing GUI 2D or Locked-Camera 2.5D]] is the one that should decide it. The general theory behind prediction is in [[Client Prediction and Reconciliation for Combat]]; remote basics are in [[RemoteEvents RemoteFunctions and Unreliable Remotes]].

Source labels: **Roblox docs (as of October 2026)**, **rule of thumb**. I have not measured the bandwidth figures below on a live server; they are arithmetic from the packet layouts plus rules of thumb. Measure your own game with the tools in [[Network Bandwidth Budgets and Measuring Them]].

---

## 1. Pick the architecture before writing code

There are three honest ways to make a GUI world multiplayer. They differ in who owns the truth, and switching later means rewriting the game.

| Architecture | Who owns the truth | Fits | Cost |
|---|---|---|---|
| **Server simulation, client rendering** (snapshots) | Server runs the game; clients send inputs, render snapshots, predict their own player | Real-time competitive play: 2D arenas, versus platformers, top-down shooters | Most code. Server CPU per match. Input latency hidden by prediction |
| **Client authority with server checks** | Each client simulates its own player and reports its state; server relays and checks plausibility | Casual co-op, hangouts, races where cheating only hurts the cheater | Little code; cheats are limited by checks, never prevented |
| **Turn or command based** (lockstep or plain events) | Server holds the rules and state; clients send commands, server broadcasts results | Card battlers, board and puzzle versus games, tactics | Simple and very secure; only works when moves are discrete |

Rules of thumb for choosing:

- If anything valuable (currency, ranked score, tradeable items) depends on who wins a real-time fight, use server simulation. Client authority there ends with teleporting, invincible players and a rewrite.
- If players cooperate and nothing tradeable comes out of the session, client authority with the checks in section 8 is fine.
- If the game is discrete (a move, a card, a column drop), skip snapshot netcode entirely (section 9).

A hybrid is common: server simulation for players and enemies, purely cosmetic effects (particles, screen shake, hit sparks) generated locally on each client from events, never replicated as entities.

---

## 2. The shared simulation

Server simulation needs the same step function on the server and the client. Put it in a `ModuleScript` under `ReplicatedStorage`, written with no reference to GUI, `Players.LocalPlayer`, or anything that differs between machines. The client requires it for prediction; the server requires it to run the match.

Rules that make the module safe to share:

- **Input is the only thing that varies.** `step(state, inputs, dt)` reads a table of per-player button masks. It never reads `UserInputService`, the clock, or `math.random`.
- **Fixed `dt`.** The server and the client both step at the same rate (for example 60 Hz), and the step always receives exactly `1 / 60`. A variable step on either side guarantees divergence.
- **Seeded randomness only.** Use `Random.new(seed)` stored in the state, with the seed chosen by the server at match start. Never the global `math.random`, which other code also consumes.
- **Arrays, not dictionary iteration, for order.** Luau does not promise an iteration order for `pairs` over a dictionary, so two machines can process the same entities in different orders and resolve a collision differently. Keep entities in an array and iterate it with a numeric loop. Sort by id when order matters.
- **No `os.clock`, `tick`, or `time` inside the step.** Time is the step counter.
- **Be careful with transcendental math.** Addition, subtraction, multiplication, division and square roots on doubles give identical results on every IEEE 754 machine for the same operations in the same order. Functions like `math.sin` and `math.atan2` are computed by platform libraries and are not guaranteed bit identical across devices (rule of thumb; not documented by Roblox either way). For prediction that only needs to be close, this is fine. For replay validation (section 8) that must match exactly, avoid trig in the simulated state, or quantise the result (round to 1/256 of a pixel) right after computing it.

Prediction tolerates tiny divergence because the server corrects it; replay validation does not.

---

## 3. The server match loop

The server has no `PreRender`, because it fires before a frame is rendered and the server renders nothing; on the server use `RunService.Heartbeat` (or `PostSimulation`) and drive the same accumulator pattern as the client loop. Each match is a table, so one server can run several matches without separate scripts.

```lua
--!strict
-- ServerScriptService/MatchServer: runs one 2D match at a fixed rate.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Sim = require(ReplicatedStorage.Shared.Sim) -- the shared step module
local Net = require(ReplicatedStorage.Shared.Net) -- packing, section 4

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InputRemote = Remotes:WaitForChild("Input2D") :: UnreliableRemoteEvent
local SnapshotRemote = Remotes:WaitForChild("Snapshot2D") :: UnreliableRemoteEvent

local STEP_HZ = 60
local SNAPSHOT_EVERY = 3 -- 60 / 3 = 20 snapshots per second
local MAX_QUEUED = 8 -- inputs buffered per player; extra ones are dropped
local FIXED_DT = 1 / STEP_HZ

type PlayerSlot = {
	entityId: number,
	queue: { [number]: number }, -- seq -> button mask
	nextSeq: number, -- the next sequence number the server will consume
	lastMask: number, -- repeated when an input is missing
}

local state = Sim.newMatch(Random.new():NextInteger(1, 2 ^ 30))
local slots: { [Player]: PlayerSlot } = {}
local serverTick = 0
local accumulator = 0

local function onInput(player: Player, payload: unknown)
	local slot = slots[player]
	if not slot or typeof(payload) ~= "buffer" then
		return
	end
	local firstSeq, masks = Net.readInputs(payload)
	if not firstSeq then
		return -- malformed: wrong length or count
	end
	for i, mask in masks do
		local seq = firstSeq + i - 1
		-- Ignore old inputs and anything too far ahead (flooding cannot speed you up).
		if seq >= slot.nextSeq and seq < slot.nextSeq + MAX_QUEUED then
			slot.queue[seq] = mask
		end
	end
end

local function stepOnce()
	local inputs: { [number]: number } = {}
	for _, slot in slots do
		local mask = slot.queue[slot.nextSeq]
		if mask then
			slot.queue[slot.nextSeq] = nil
			slot.lastMask = mask
		else
			mask = slot.lastMask -- packet lost or late: repeat the last input
		end
		slot.nextSeq += 1
		inputs[slot.entityId] = mask
	end
	Sim.step(state, inputs, FIXED_DT)
	serverTick += 1

	if serverTick % SNAPSHOT_EVERY == 0 then
		local body = Net.writeSnapshotBody(state, serverTick, workspace:GetServerTimeNow())
		for player, slot in slots do
			-- Shared body plus a small per-player tail with the ack and private state.
			SnapshotRemote:FireClient(player, Net.withTail(body, state, slot.entityId, slot.nextSeq - 1))
		end
	end
end

InputRemote.OnServerEvent:Connect(onInput)

Players.PlayerAdded:Connect(function(player)
	local id = Sim.spawnPlayer(state, player.UserId)
	slots[player] = { entityId = id, queue = {}, nextSeq = 1, lastMask = 0 }
end)

Players.PlayerRemoving:Connect(function(player)
	local slot = slots[player]
	if slot then
		Sim.removeEntity(state, slot.entityId)
		slots[player] = nil
	end
end)

RunService.Heartbeat:Connect(function(dt: number)
	accumulator += math.min(dt, FIXED_DT * 5)
	while accumulator >= FIXED_DT do
		stepOnce()
		accumulator -= FIXED_DT
	end
end)
```

The important decisions in that loop:

- **One input consumed per player per tick.** This is the core defence against speed hacks. A client that sends 200 inputs a second still moves at 60 steps a second, because the server takes exactly one from the queue each tick and drops anything more than `MAX_QUEUED` ahead.
- **Missing input repeats the last one.** On a lost packet the player keeps doing what they were doing, which is almost always right (holding run). The alternative, treating it as "no buttons", makes players stutter on bad connections.
- **Join mid-match.** A new slot starts at sequence 1, and the client's first input must also be 1. If you reconnect a player into an existing slot, send them the expected sequence in a reliable message first.
- **Server CPU.** Every match costs `players x entities` work per step on a single Luau thread. Rule of thumb: keep one match step under about 0.5 ms on the server, and budget the number of matches per server from that. Heavy simulations can move into [[Parallel Luau and Actors]], one actor per match, but measure before reaching for it.

---

## 4. Packing data into buffers

Roblox docs (as of October 2026) on `UnreliableRemoteEvent`: events "with payloads larger than 1000 bytes are dropped", events can arrive out of order, and remotes are rate limited at "approximately 500 requests per second, per client", shared among all remote events of the same type. Older versions of the same page said 900 bytes; design for 900 so a change in either direction does not break you. The same page notes the engine will "encode and compress certain object types, such as buffers", which means your precomputed size is an upper bound, not the exact wire size.

The [[Buffers and Binary Data]] note explains the `buffer` library. For netcode the reasons to use it are concrete:

- A table of numbers is serialised with type tags and keys; a buffer is exactly the bytes you wrote.
- You control precision. A position stored as a 16-bit integer of half pixels is 2 bytes instead of 8.
- You can validate length on receipt in one comparison.

### Snapshot layout

| Field | Type | Bytes |
|---|---|---|
| server time | f64 | 8 |
| tick | u32 | 4 |
| entity count | u8 | 1 |
| per entity: id | u16 | 2 |
| per entity: x, y in half pixels | u16, u16 | 4 |
| per entity: sprite index | u8 | 1 |
| per entity: animation frame | u8 | 1 |
| per entity: flags (flipX, hurt, ...) | u8 | 1 |

That is 13 bytes of header plus 9 bytes per entity: 900 bytes fit 98 entities. At 20 snapshots per second and 40 visible entities that is `20 x (13 + 360) = 7.5 KB/s` per player downstream before the per-player tail, and the server sends it to every player. Half-pixel `u16` covers 0 to 32,767 pixels, which is 2,048 tiles of 16 pixels; a longer level needs `u32` or positions relative to a room origin.

```lua
--!strict
-- ReplicatedStorage/Shared/Net: packs inputs and snapshots into buffers.
local Net = {}

local HEADER = 13
local PER_ENTITY = 9
local TAIL = 4 + 4 + 4 -- ack seq, vx, vy (f32 each for velocity)
Net.MAX_ENTITIES = (900 - HEADER - TAIL) // PER_ENTITY

export type NetEntity = { id: number, x: number, y: number, vx: number, vy: number, spriteIndex: number, frame: number, flags: number }
export type NetState = { entities: { NetEntity }, byId: { [number]: NetEntity } }

local function half(v: number): number
	return math.clamp(math.round(v * 2), 0, 65535)
end

function Net.writeSnapshotBody(state: NetState, tick: number, serverTime: number): buffer
	local count = math.min(#state.entities, Net.MAX_ENTITIES)
	local b = buffer.create(HEADER + count * PER_ENTITY)
	buffer.writef64(b, 0, serverTime)
	buffer.writeu32(b, 8, tick)
	buffer.writeu8(b, 12, count)
	local o = HEADER
	for i = 1, count do
		local e = state.entities[i]
		buffer.writeu16(b, o, e.id)
		buffer.writeu16(b, o + 2, half(e.x))
		buffer.writeu16(b, o + 4, half(e.y))
		buffer.writeu8(b, o + 6, e.spriteIndex)
		buffer.writeu8(b, o + 7, e.frame)
		buffer.writeu8(b, o + 8, e.flags)
		o += PER_ENTITY
	end
	return b
end

-- Copies the shared body and appends this player's ack and exact velocity.
function Net.withTail(body: buffer, state: NetState, entityId: number, ackSeq: number): buffer
	local n = buffer.len(body)
	local b = buffer.create(n + TAIL)
	buffer.copy(b, 0, body)
	local me = state.byId[entityId]
	buffer.writeu32(b, n, ackSeq)
	buffer.writef32(b, n + 4, if me then me.vx else 0)
	buffer.writef32(b, n + 8, if me then me.vy else 0)
	return b
end

-- Inputs: u32 first sequence, u8 count (1..8), then count button masks (u8).
function Net.writeInputs(firstSeq: number, masks: { number }): buffer
	local b = buffer.create(5 + #masks)
	buffer.writeu32(b, 0, firstSeq)
	buffer.writeu8(b, 4, #masks)
	for i, m in masks do
		buffer.writeu8(b, 4 + i, m)
	end
	return b
end

function Net.readInputs(b: buffer): (number?, { number })
	local len = buffer.len(b)
	if len < 6 or len > 13 then
		return nil, {}
	end
	local count = buffer.readu8(b, 4)
	if count < 1 or count > 8 or len ~= 5 + count then
		return nil, {}
	end
	local masks = table.create(count)
	for i = 1, count do
		masks[i] = buffer.readu8(b, 4 + i)
	end
	return buffer.readu32(b, 0), masks
end

return Net
```

Notes on the layout:

- **Entity cap is explicit.** If the match can exceed `MAX_ENTITIES`, you need interest management: send each player only the entities near their camera ([[Interest Management and Per-Player Replication]]). In a 2D game this is cheap, because "near" is a rectangle test against the view plus a margin. Then the body is per player, not shared, and the copy trick in `withTail` goes away.
- **Velocities for the local player only.** Remote players are interpolated between positions and do not need velocity. The local player needs exact state for reconciliation, so it gets full precision in its tail. If your controller has more hidden state (coyote timer, jump buffer, dash cooldown), the tail grows; send all of it, or reconciliation will drift.
- **Spawns and deaths are implicit.** Every snapshot is a complete list of what it covers. An id that disappears from the list has despawned. That makes lost packets harmless. A design that sends "spawn" and "despawn" as separate unreliable events breaks the first time one is dropped.
- **Score, chat, match end, and anything that must arrive** go on a reliable `RemoteEvent`, separate from the stream.

### Input layout and redundancy

Each step the client samples buttons into a bitmask (bit 0 left, bit 1 right, bit 2 jump, bit 3 attack ...). Sending one event per step is 60 events a second, well under the documented rate limit, but unreliable events can be lost. The fix is **redundancy**: every packet carries the last 4 masks. A single lost packet costs nothing, because the next one repeats its inputs, and the server's queue ignores sequences it already consumed. Sending every second step with the last 4 masks halves the event count (30 per second) and still survives one lost packet in a row (rule of thumb).

---

## 5. Rendering other players: snapshot interpolation

Remote players should never be extrapolated by default. Draw them slightly in the past, between two snapshots you already have. With 20 snapshots a second they arrive every 50 ms, so render about 100 ms behind the newest server time (two intervals). That survives one lost or late snapshot without freezing.

`workspace:GetServerTimeNow()` is the right clock. Roblox docs (as of October 2026) describe it as "the client's best approximation of the current time on the server", smoothed so it is monotonic and moves at the local clock rate within 0.6%. Stamp each snapshot with the server's value, and render at `GetServerTimeNow() - INTERP_DELAY` on the client.

```lua
--!strict
-- Client: buffers snapshots and samples remote entity positions in the past.
local Interp = {}

local INTERP_DELAY = 0.1 -- seconds behind the server (2 snapshots at 20 Hz)
local MAX_KEEP = 16

export type Pose = { x: number, y: number, spriteIndex: number, frame: number, flags: number }
export type Snapshot = { time: number, tick: number, poses: { [number]: Pose } }
export type Buffer = { list: { Snapshot }, lastTick: number }

function Interp.new(): Buffer
	return { list = {}, lastTick = -1 }
end

function Interp.decode(b: buffer): Snapshot
	local count = buffer.readu8(b, 12)
	local poses: { [number]: Pose } = {}
	local o = 13
	for _ = 1, count do
		poses[buffer.readu16(b, o)] = {
			x = buffer.readu16(b, o + 2) / 2,
			y = buffer.readu16(b, o + 4) / 2,
			spriteIndex = buffer.readu8(b, o + 6),
			frame = buffer.readu8(b, o + 7),
			flags = buffer.readu8(b, o + 8),
		}
		o += 9
	end
	return { time = buffer.readf64(b, 0), tick = buffer.readu32(b, 8), poses = poses }
end

function Interp.push(ib: Buffer, snap: Snapshot)
	if snap.tick <= ib.lastTick then
		return -- unreliable events can arrive out of order; drop stale ones
	end
	ib.lastTick = snap.tick
	table.insert(ib.list, snap)
	if #ib.list > MAX_KEEP then
		table.remove(ib.list, 1)
	end
end

-- Returns the pose of every entity at renderTime, interpolated.
function Interp.sample(ib: Buffer, renderTime: number): { [number]: Pose }
	local list = ib.list
	if #list == 0 then
		return {}
	end
	-- Find the pair (a, b) with a.time <= renderTime < b.time.
	for i = #list - 1, 1, -1 do
		local a, b = list[i], list[i + 1]
		if a.time <= renderTime then
			local t = math.clamp((renderTime - a.time) / (b.time - a.time), 0, 1)
			local out: { [number]: Pose } = {}
			for id, pb in b.poses do
				local pa = a.poses[id]
				if pa then
					out[id] = {
						x = pa.x + (pb.x - pa.x) * t,
						y = pa.y + (pb.y - pa.y) * t,
						spriteIndex = pb.spriteIndex,
						frame = if t < 0.5 then pa.frame else pb.frame,
						flags = pb.flags,
					}
				end
				-- An id only in b has just spawned: it appears once renderTime reaches b.
			end
			return out
		end
	end
	return list[1].poses -- renderTime is older than everything: hold the oldest
end

Interp.INTERP_DELAY = INTERP_DELAY
return Interp
```

Edge cases worth handling:

- **Teleports and respawns** interpolate across the screen. Set a "teleported" bit in the flags; when the newer pose has it, skip interpolation and snap.
- **Starvation.** If `renderTime` passes the newest snapshot (a long lag spike), the loop above holds the latest pair at `t = 1`. Extrapolating a little (up to one interval) hides short gaps, but extrapolated players walk into walls and snap back, which looks worse than a brief freeze in a platformer.
- **Adaptive delay.** On a jittery connection 100 ms is not enough. Measure how often you starve and grow the delay by 25 ms when it happens more than a few times per second, shrink it slowly when it never happens (rule of thumb).
- **The renderer stays the same.** Feed the sampled poses into the pooled renderer from the engine note. Remote entities have no `prevX`; interpolation already happened, so draw them at alpha 1.

---

## 6. Your own player: prediction and reconciliation

If the local player also waited for snapshots, every press would show up a full round trip plus 100 ms later. On a 120 ms ping that is over 200 ms of lag for movement, which is unplayable in a platformer. So the client runs the shared step for its own player immediately (**prediction**) and fixes mistakes when the server's answer arrives (**reconciliation**).

The loop on the client:

1. Each step, sample buttons, give the step a sequence number, store `{seq, mask}` in a history list, send it (with redundancy), and run `Sim.stepPlayer` locally with that mask.
2. When a snapshot arrives, read the ack sequence from the tail: the server has applied every input up to `ack`. Drop history entries with `seq <= ack`.
3. Set the local player's state to the server's state for that snapshot (position from the body, velocity and hidden state from the tail).
4. Replay every remaining history entry through `Sim.stepPlayer` in order. The result is where the player should be now, given what the server knows.
5. If the corrected position differs from what you were drawing by a pixel or two, smooth the visual difference out over about 100 ms instead of snapping (keep a render offset that decays with `1 - math.exp(-k * dt)`, from [[Springs Damping and Smoothing]]). If it differs by more than a tile, snap: something real happened (you were hit, a platform moved).

```lua
--!strict
-- Client: reconcile the predicted local player against a server snapshot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sim = require(ReplicatedStorage.Shared.Sim)

type InputRecord = { seq: number, mask: number }

local Reconcile = {}

function Reconcile.apply(
	me: Sim.PlayerBody, -- the predicted local body (mutated)
	history: { InputRecord },
	serverX: number,
	serverY: number,
	serverVx: number,
	serverVy: number,
	ack: number,
	dt: number
): { InputRecord }
	-- 1. Forget inputs the server has already applied.
	local pending: { InputRecord } = {}
	for _, rec in history do
		if rec.seq > ack then
			table.insert(pending, rec)
		end
	end
	-- 2. Rewind to the authoritative state.
	me.x, me.y, me.vx, me.vy = serverX, serverY, serverVx, serverVy
	-- 3. Replay what the server has not seen yet.
	for _, rec in pending do
		Sim.stepPlayer(me, rec.mask, dt)
	end
	return pending
end

return Reconcile
```

The caveat that catches everyone: the server position in the body is **quantised to half pixels**, but the client's internal position had fractions. Rewinding to a rounded value and replaying produces a tiny difference every time, which shows up as a constant one pixel shimmer. Either send the local player's exact position in the tail (f32 is enough for a 2D level), or compare with a tolerance and skip the rewind when the difference is below half a pixel.

What prediction cannot hide: interactions with other players. Your client predicts that your attack hit the enemy you see, but the enemy you see is 100 ms in the past. The server decides. For melee in a 2D brawler, rule of thumb is to accept a hit on the server when it overlaps either the target's current box or its box from about 100 to 150 ms ago (a simple form of lag compensation), and cap how far back you rewind so laggy players cannot hit through walls. [[Client Prediction and Reconciliation for Combat]] covers the trade-offs in depth.

---

## 7. Moving platforms, enemies and shared objects

Everything that is not a player is simulated only by the server and interpolated on clients like remote players. That creates the classic 2D netcode problem: **your predicted player stands on a platform drawn 100 ms in the past.** You land on where the platform was, then the server says you missed.

Fixes, in order of preference:

- **Deterministic movers.** If a platform's position is a pure function of the tick (`x = baseX + 64 * math.sin(tick * speed)`, or better a triangle wave with no trig), the client computes it for the predicted tick, not the interpolated one. No data needs to be sent for it at all, and prediction is exact. Most platformer movers can be written this way.
- **Carry by reference.** When the player is grounded on a mover, store its position relative to the mover. The client draws the player relative to the interpolated mover. Collision still runs against the predicted mover position.
- **Accept the error** for slow, wide platforms, where a 100 ms difference is a pixel or two and reconciliation smooths it.

Do not predict enemies; their decisions depend on other players' inputs, which you do not have.

---

## 8. Client authority with checks, and replay validation

For casual co-op, letting each client own its own player is far less work: the client sends its position, sprite and frame 20 times a second, the server relays to others, and other clients interpolate exactly as in section 5. The server's job becomes plausibility checking ([[Server Authority and Validation]]):

- **Speed.** Distance between two reports must be at most `maxSpeed x elapsed x 1.2` plus a small slack, with `elapsed` measured by the server, not the client.
- **Solidity.** The server holds the tilemap (it is data, so this is cheap) and rejects positions inside solid tiles.
- **Bounds and gates.** No position past a locked door, no position outside the level.
- **Rate.** At most the expected reports per second; extra ones are dropped ([[Remote Abuse Patterns and Rate Limiting in Practice]]).

When a check fails, correct the player (send them back to their last good position), log it, and only escalate after repeated failures. Single failures happen to honest players on bad connections.

**Replay validation** is the middle ground for single-player GUI games that award something valuable, such as a leaderboard time. The client records its input masks per step and sends the log at the end of a level. The server runs the shared simulation over the log, headless, and checks that it reaches the goal at the claimed step. A 60-second level is 3,600 steps, which runs in a few milliseconds of server time for a small platformer (rule of thumb; measure yours). The log is 3,600 bytes as raw masks, smaller with run-length encoding, and goes through a reliable `RemoteEvent`. This only works if the simulation is bit deterministic across devices (section 2), and every change to the step function invalidates old replays, so version them.

---

## 9. Discrete games: send commands, not state

Turn-based and puzzle-versus games do not need any of the above. The pattern:

1. Client sends a command through a reliable `RemoteEvent`: `{ kind = "PlayCard", hand = 3, target = 2 }`.
2. Server validates (is it your turn, is slot 3 a card you hold, is target 2 legal), applies it with the shared rules module, and increments a state version.
3. Server broadcasts the resulting events or the new state to both players.
4. Clients animate the result. They never change game state on their own; they may show the move tentatively and roll back if the server rejects it.

Never send hidden information (the opponent's hand, the next piece) to a client that should not see it: anything sent is readable by an exploiter. That is also why replicating state through value objects or attributes is a poor fit here.

---

## 10. Common mistakes

- **Moving a Frame and expecting others to see it.** Symptom: everything works in solo Play, and other players see nobody in a two-player test.
- **Sending positions from the client in a competitive game.** Symptom: teleporting and "invisible" players a week after launch.
- **Consuming every queued input per tick.** Symptom: players with spikes surge forward, and speed hacks work.
- **Separate spawn and despawn events on an unreliable channel.** Symptom: ghost entities that never disappear for one player.
- **Payloads over the limit.** Symptom: in Studio a dropped-event warning in Output; in a live game, other players freeze when the arena gets busy. Count entities against `MAX_ENTITIES`.
- **`pairs` over dictionaries inside the shared step.** Symptom: rare desyncs that only happen with more than two players.
- **Reconciling against quantised positions.** Symptom: the local player shimmers by a pixel while standing still.
- **Extrapolating remote players.** Symptom: other players walk into walls and snap back.
- **`ResetOnSpawn` on the playfield ScreenGui.** Symptom: the match vanishes for one player when their hidden 3D character resets.

---

## 11. Checklist

- [ ] Architecture chosen (server simulation, client authority with checks, or commands) and written down.
- [ ] Shared step module: fixed `dt`, seeded `Random`, arrays not dictionary order, no clock reads.
- [ ] Server loop on `Heartbeat` with accumulator; one input per player per tick; queue capped.
- [ ] Inputs as buffers with sequence numbers and redundancy; length validated on receipt.
- [ ] Snapshots as buffers under 900 bytes; entity cap or interest management; out-of-order snapshots dropped.
- [ ] Remote players interpolated about 100 ms behind `GetServerTimeNow()`; teleport flag snaps.
- [ ] Local player predicted; reconciled with ack sequence and exact private state.
- [ ] Movers deterministic by tick where possible.
- [ ] Reliable remotes for score, chat, match end; no hidden information sent to the wrong client.
- [ ] Tested with two or more clients in Studio and with simulated latency before launch ([[Multi-Client and Live Testing]]).

## See also

- [[2D Game Development Start Here]]
- [[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]
- [[2D Collision Physics and Platformer Movement]]
- [[Choosing GUI 2D or Locked-Camera 2.5D]]
- [[Client Prediction and Reconciliation for Combat]]
- [[Interest Management and Per-Player Replication]]
- [[Buffers and Binary Data]]
- [[Network Performance]]
- [[Exploits and Anti-Cheat]]
- [[Matchmaking Queues with MemoryStore]]

## Connected notes
<!-- auto-links:start -->
[[Deterministic Simulation]] · [[Entity Component Systems]] · [[Tilemaps Cameras and Parallax for 2D Levels]] · [[Links - Latency and prediction]] · [[Debugging Client-Server Desync]] · [[Serialization Formats for Saves and Networking]]
<!-- auto-links:end -->
