---
tags: [networking, replication, interpolation, snapshots, extrapolation, unreliable-remotes, buffers, npcs, type/guide, area/networking, level/advanced, api/UnreliableRemoteEvent, api/Workspace]
---
# Snapshot Interpolation for Custom Replication

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Setting position on receipt -> Interpolate at a delayed render time
> - Avoid: Delay of one interval -> 2 to 3 intervals
> - Avoid: Reliable remotes for snapshots -> Unreliable for state, reliable for events
> - Server sends packed snapshots at a fixed rate with server timestamps.
> - Spawns, despawns and critical state on a reliable channel.
> - Client ring buffer per entity; out-of-order handling.
>
> Cost: TL;DR ~140 tok · whole note ~2.4k tok. Read more: ## 3. Server: sending snapshots · ## 4. Client: buffers and interpolation · ## Common mistakes · ## Checklist
<!-- tldr:end -->

When you stop replicating entities as physics parts (hundreds of tower-defense enemies, projectiles, server-simulated NPCs rendered on clients, a 2D world in a GUI), you take over the job Roblox's replicator was doing: sending positions and making them look smooth despite jitter, packet loss and a send rate far below the frame rate. The standard answer is **snapshot interpolation**: the server sends timestamped snapshots at a fixed rate; each client renders entities slightly in the past, interpolating between the two snapshots around its render time, and extrapolates briefly when data is late. This note covers the clock, buffers, render delay, extrapolation limits, packing and the gotchas. Interest management (who gets which entities) is in [[Interest Management and Per-Player Replication]].

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. Why not just set positions on receipt

Setting `CFrame` when a message arrives shows motion at the send rate (10 to 20 Hz) with network jitter added: stutter, then bursts. Lerping toward the latest position on receipt ("chase smoothing") hides some of it but adds variable lag and cuts corners. Snapshot interpolation trades a small fixed delay for perfectly smooth, correct paths.

## 2. The clock

Snapshots carry **server time**: `workspace:GetServerTimeNow()` on the server at simulation time (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/Workspace#GetServerTimeNow). Clients call the same function, which is synchronised to the server, so both sides share a timeline without your own ping-pong protocol.

```
renderTime = GetServerTimeNow() - interpDelay
```

**Rule of thumb.** `interpDelay = 2 to 3 send intervals` plus a little: at 20 Hz (50 ms), 100 to 150 ms. One interval is too little: a single late or dropped packet leaves you without a "next" snapshot.

Optionally adapt the delay per client from observed jitter (arrival time minus snapshot time, its variance over the last few seconds), within bounds, changing it slowly so playback speed does not visibly change.

## 3. Server: sending snapshots

- Fixed send rate (10 to 20 Hz), not per frame. Gather all changed entities for each client's interest set and send **one** message per client per tick.
- Use `UnreliableRemoteEvent` (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent): late data is useless, so you never want reliable ordering and retransmission to delay the next snapshot. Unreliable payloads have a size limit (around 1 KB; check the page for the current value), and oversize events are dropped, so chunk large sets across messages.
- Spawns, despawns and state changes that must not be lost (death, type change) go on a **reliable** `RemoteEvent` with the entity id, or are repeated in several consecutive snapshots.
- Pack data in a `buffer` (**Roblox docs**: https://create.roblox.com/docs/reference/engine/libraries/buffer): entity id as u16/u32, position quantised (for example i16 per axis at 1/16 stud inside a known arena, or f32 if the world is large), yaw as u8 or u16, plus a small state byte. A `buffer` sent through a remote stays compact, unlike tables of numbers ([[Buffers and Binary Data]], [[Network Bandwidth Budgets and Measuring Them]]).

```lua
--!strict
-- Server: pack N entities into one buffer (id u16, x/y/z f32, yaw u16)
local RECORD = 2 + 12 + 2

local function pack(t: number, ids: { number }, positions: { Vector3 }, yaws: { number }): buffer
	local n = #ids
	local b = buffer.create(8 + 2 + n * RECORD)
	buffer.writef64(b, 0, t)
	buffer.writeu16(b, 8, n)
	local o = 10
	for i = 1, n do
		local p = positions[i]
		buffer.writeu16(b, o, ids[i])
		buffer.writef32(b, o + 2, p.X)
		buffer.writef32(b, o + 6, p.Y)
		buffer.writef32(b, o + 10, p.Z)
		buffer.writeu16(b, o + 14, math.floor((yaws[i] % (2 * math.pi)) / (2 * math.pi) * 65535))
		o += RECORD
	end
	return b
end
```

## 4. Client: buffers and interpolation

Per entity, keep a small ring of `(t, pos, yaw)` snapshots sorted by `t` (they can arrive out of order on unreliable channels; drop anything older than the newest you have minus the buffer length). Each frame:

1. Compute `renderTime`.
2. Find snapshots `a` and `b` with `a.t <= renderTime < b.t`.
3. `alpha = (renderTime - a.t) / (b.t - a.t)`; position `a.pos:Lerp(b.pos, alpha)`; yaw by shortest-angle lerp.
4. If `renderTime` is beyond the newest snapshot, **extrapolate** from the last two snapshots' velocity, for at most a cap (100 to 250 ms), then **hold**. Never extrapolate indefinitely; entities fly through walls.
5. When data resumes after extrapolation, blend back over 100 to 200 ms instead of snapping.

```lua
--!strict
type Snap = { t: number, pos: Vector3, yaw: number }
local MAX_EXTRAP = 0.2

local function sample(snaps: { Snap }, renderTime: number): (Vector3?, number?)
	local n = #snaps
	if n == 0 then return nil, nil end
	if renderTime <= snaps[1].t then return snaps[1].pos, snaps[1].yaw end
	for i = 1, n - 1 do
		local a, b = snaps[i], snaps[i + 1]
		if renderTime < b.t then
			local alpha = (renderTime - a.t) / math.max(b.t - a.t, 1e-4)
			local dy = (b.yaw - a.yaw + math.pi) % (2 * math.pi) - math.pi
			return a.pos:Lerp(b.pos, alpha), a.yaw + dy * alpha
		end
	end
	local last = snaps[n]
	if n >= 2 then
		local prev = snaps[n - 1]
		local over = math.min(renderTime - last.t, MAX_EXTRAP)
		local vel = (last.pos - prev.pos) / math.max(last.t - prev.t, 1e-4)
		return last.pos + vel * over, last.yaw
	end
	return last.pos, last.yaw
end
```

Render with `Workspace:BulkMoveTo` for many anchored entity models, or by setting `CFrame` on client-only parts, or by updating GUI positions for 2D worlds ([[2D Multiplayer - Server Authority and Replicating GUI Worlds]]).

## 5. Consequences of rendering in the past

- **Hit validation**: what a player aims at is `interpDelay + latency` in the past. The server must rewind entity history to the shooter's view time (capped) to validate hits fairly ([[Hitboxes and Hit Detection]], [[Client Prediction and Reconciliation for Combat]]). Store a short history of server positions per entity for this.
- **Local player** is not interpolated; it is predicted. Mixing an interpolated world with a predicted player is normal; interactions between them (being hit by an interpolated enemy) need the same rewind thinking.
- **Teleports**: send a "discontinuity" flag so the client snaps instead of interpolating across the map.
- **Events tied to positions** (an enemy reaching the base) should be timestamped and played at their time on the render timeline, not on receipt, or they appear before the entity arrives.

## 6. Tuning and testing

- Measure bytes per second per client at peak entity count ([[Network Bandwidth Budgets and Measuring Them]]). Reduce with interest management, quantisation, lower rates for far entities (send far entities every second or third tick), and delta-against-last-acked if you build acknowledgements.
- Test with Studio's network simulation (incoming replication lag and packet loss settings) and on a real phone on mobile data ([[Multi-Client and Live Testing]]).
- Visual check: draw the raw snapshot positions as small dots next to the interpolated entity in a debug mode; the entity should glide through the dots, one or two behind the newest.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Setting position on receipt | Stutter at send rate | Interpolate at a delayed render time |
| Delay of one interval | Hitches on every late packet | 2 to 3 intervals |
| Reliable remotes for snapshots | Bursty catch-up after loss | Unreliable for state, reliable for events |
| Unlimited extrapolation | Entities fly through walls | Cap, hold, blend back |
| Local `os.clock()` timestamps | Drift between server and client | `GetServerTimeNow` on both sides |
| One remote per entity | Bandwidth and overhead explode | One packed buffer per client per tick |
| No rewind for hits | "I hit him on my screen" | Server history plus capped rewind |

## Checklist
- [ ] Server sends packed snapshots at a fixed rate with server timestamps.
- [ ] Spawns, despawns and critical state on a reliable channel.
- [ ] Client ring buffer per entity; out-of-order handling.
- [ ] Render delay 2 to 3 intervals; extrapolation capped; discontinuity flag for teleports.
- [ ] Hit validation rewinds to the shooter's view time.
- [ ] Bandwidth measured at peak; tested with simulated lag and loss.

## See also
[[Interest Management and Per-Player Replication]] · [[Client Prediction and Reconciliation for Combat]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Buffers and Binary Data]] · [[Network Performance]] · [[Tower Defense Waves and Placement End to End]]

## Connected notes
<!-- auto-links:start -->
[[Replication Rules]] · [[Debugging Client-Server Desync]] · Serialization Formats for Saves and Networking · [[Entity Component Systems]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Client-Server Model]] · [[Rate Limiting and Abuse Prevention]] · [[Network Ownership]] · [[Frameworks - Knit Matter and Others]] · [[Remote Abuse Patterns and Rate Limiting in Practice]] · [[Server Authority and Validation]] · [[Cross-Server Messaging]] · [[Exploits and Anti-Cheat]]
<!-- related:end -->
