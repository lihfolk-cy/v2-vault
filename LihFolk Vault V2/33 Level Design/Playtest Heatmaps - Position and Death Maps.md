---
tags: [level-design, playtesting, heatmaps, analytics, telemetry, deaths, type/guide, area/level-design, level/intermediate, api/DataStoreService, api/UpdateAsync, api/Humanoid]
---
# Playtest Heatmaps - Position and Death Maps

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No map version tag -> Version string, bumped per change
> - Avoid: `SetAsync` from every server -> `UpdateAsync` merge
> - Avoid: Flushing per event -> Batch, flush every few minutes
> - Server-side capture of positions, deaths (with cause and attacker cell) and quits.
> - Cells quantised; map version and new/veteran split on every record.
> - Per-server counters merged with `UpdateAsync`, batched, sharded if large.
>
> Cost: TL;DR ~150 tok · whole note ~2.4k tok. Read more: ## 2. Death capture · ## 3. Aggregating across servers · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Level Design Principles - Flow Sightlines and Landmarks]] already shows a coarse server sampler that records where players stand. This note goes further: **death maps** (where players die, who killed them and from where), aggregating data across many servers and sessions, storing it inside DataStore budgets, drawing it back over the map in Studio, and reading the result into concrete layout fixes. Position heatmaps tell you where people go; death maps tell you where your level is unfair, confusing or too hard.

Source labels: **Roblox docs** (create.roblox.com, as of October 2026), **Rule of thumb**. Code is strict Luau, **reviewed, not run**.

---

## 1. What to record

| Event | Fields | Answers |
|---|---|---|
| Position sample | cell, map version, session minute | Flow, dead zones, chokepoints |
| Death | victim cell, cause (fall, enemy, hazard id, player), killer cell, distance | Unfair angles, hazard difficulty, spawn camping |
| Quit / leave | cell, session minute | Where frustrated players give up |
| Checkpoint / objective reached | id, time since spawn | Pace and stuck points (pairs with funnels in [[Analytics and Funnels]]) |

Rules:

- Record on the **server**. Client-reported positions are spoofable and add remote traffic.
- **Quantise immediately** into grid cells (4 to 16 studs, rule of thumb: about one character's "decision space", smaller for obbies, larger for open worlds). You almost never need raw coordinates, and cells compress well.
- Tag every record with a **map version** string you bump on every layout change. Mixing data from two layouts produces heatmaps that describe neither.
- Separate **new players** (first session, or under N minutes total) from veterans; they reveal different problems.
- No personal data: store counts per cell, not user ids per position. You do not need to know who died at a cell, only how many and how.

## 2. Death capture

```lua
--!strict
-- Server: death events into per-server counters.
local Players = game:GetService("Players")

local CELL = 8
local MAP_VERSION = "arena_v7"

local deathCells: { [string]: number } = {}
local killFromCells: { [string]: number } = {}

local function cellKey(p: Vector3): string
	return string.format("%d,%d", p.X // CELL, p.Z // CELL)
end

local function bump(t: { [string]: number }, key: string)
	t[key] = (t[key] or 0) + 1
end

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local root = character:WaitForChild("HumanoidRootPart") :: BasePart
		humanoid.Died:Connect(function()
			local cause = character:GetAttribute("LastDamageCause") :: string? -- set by your damage system
			bump(deathCells, cellKey(root.Position) .. "|" .. (cause or "unknown"))
			local killerPos = character:GetAttribute("LastAttackerPosition") :: Vector3?
			if killerPos then
				bump(killFromCells, cellKey(killerPos))
			end
		end)
	end)
end)
```

The damage system ([[Combat Systems Architecture]]) should stamp `LastDamageCause` and `LastAttackerPosition` when it applies damage; inferring cause after death is unreliable. Fall deaths: stamp "fall" from your out-of-bounds or fall-damage code ([[Kill Planes, Map Boundaries and Out-of-Bounds Recovery]]).

**Kill-from map** is the underrated half: a hot cell of attacker positions overlooking a spawn or a lane exit is a sniper perch you did not intend.

## 3. Aggregating across servers

One server's data is noise. Merge counts from all servers into one record per map version and event type:

- Each server flushes every 5 to 10 minutes and on `game:BindToClose` (bounded by the shutdown time limit; see [[Server Lifecycle and Shutdown]]).
- Use `DataStore:UpdateAsync` on a key like `heat/arena_v7/deaths`, merging this server's counter table into the stored table, then clear the local counters on success. `UpdateAsync` handles concurrent writers from many servers correctly; `SetAsync` would lose other servers' counts ([[DataStore Fundamentals]]).
- **Size**: DataStore values are limited to 4 MB (Roblox docs). A 512 x 512 stud map at 8-stud cells is 4,096 cells, small. A huge open world at 4-stud cells is not; shard keys by region (`heat/v7/deaths/r3_5`).
- **Budget**: a flush every few minutes per server is a tiny fraction of the per-server write budget, but do not flush per event.
- **Sampling**: on a popular game, record a random 10 to 20 percent of servers (decide at server start); the shape of a heatmap does not need every player.
- **Retention**: delete or stop writing old map versions; they are only useful for before/after comparison.

For playtests with a handful of testers, skip the DataStore entirely: print a compact string at the end of the session from a test server, or write to a `StringValue` you copy out of Studio.

## 4. Drawing it back in Studio

With "Enable Studio Access to API Services" on in a test copy of the place (Roblox docs: Game Settings, Security), a command bar or plugin script can read the merged key and draw it:

- **Parts per cell**: a flat, non-colliding, anchored part at each cell's centre (raycast down to place it on the floor), colour from a ramp (blue to yellow to red by count, normalised by the 95th percentile so one outlier does not wash everything out), `Transparency` around 0.4. Put them all in a `HeatmapOverlay` folder you delete after review. Simple and accurate in 3D, including multi-floor maps when you also record Y bands.
- **Top-down image**: build a pixel buffer and show it through an `EditableImage` on a big `SurfaceGui` or the minimap ([[EditableImage for Pixel Buffers and Procedural 2D]], [[Minimap and World Map UI - Projection, Rotation and Fog of War]]). Faster for big maps, flat only.
- Draw **death cause as separate layers** (fall, enemy, hazard). A single red blob hides whether the problem is a jump or a sniper.
- Normalise position heatmaps by **time**, not samples, if sample rates changed between versions.

Never ship overlay parts or Studio-only read scripts in the live place.

## 5. Reading the maps

| Pattern | Likely cause | Typical fix |
|---|---|---|
| Death cluster at a jump | Gap too far, landing unreadable, mobile timing | Shorten, widen landing, add a sight line to the landing ([[Obby and Platforming Level Design]]) |
| Deaths right outside spawn, kill-from cell overlooking it | Spawn sightline | Block line of sight, add exit options ([[Spawn Points Safe Zones and Respawn Flow]]) |
| Hot kill-from cell nobody should reach | Unintended perch | Block access or remove cover |
| Position cold zone | Players do not know it exists or it has no reward | Landmark, reward or remove it |
| Position hot spot that is not an objective | Players stuck, or a bright decoration attracting them | Check for collision snags; tone down decor |
| Quit cluster | Frustration point | Look at deaths and timing at the same cells |
| New players and veterans differ sharply | Teaching gap | Fix onboarding path ([[Teaching Through Level Design]]) |

Change **one thing** per map version, bump the version, and compare. Without the version discipline, heatmaps become decoration.

---

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| No map version tag | Heatmap mixes old and new layouts | Version string, bumped per change |
| `SetAsync` from every server | Counts reset to one server's data | `UpdateAsync` merge |
| Flushing per event | DataStore throttling | Batch, flush every few minutes |
| Cause inferred after death | "Unknown" dominates the map | Damage system stamps cause and attacker |
| Raw linear colour scale | One hot cell, everything else blue | Normalise by a percentile |
| Recording user ids per position | Unneeded personal data | Counts per cell only |
| Overlay shipped to live | Coloured tiles in the game | Separate folder, deleted; test copy only |

## Checklist

- [ ] Server-side capture of positions, deaths (with cause and attacker cell) and quits.
- [ ] Cells quantised; map version and new/veteran split on every record.
- [ ] Per-server counters merged with `UpdateAsync`, batched, sharded if large.
- [ ] Studio overlay script with percentile colour scale and per-cause layers.
- [ ] Findings turned into one change per version with before/after comparison.

## See also

[[Level Design Principles - Flow Sightlines and Landmarks]] · [[Analytics and Funnels]] · [[DataStore Fundamentals]] · [[Server Lifecycle and Shutdown]] · [[Combat Systems Architecture]] · [[Spawn Points Safe Zones and Respawn Flow]] · [[Obby and Platforming Level Design]] · [[Multi-Client and Device Playtesting Protocols]]

## Connected notes
<!-- auto-links:start -->
[[Level Design Start Here]] · [[A-B Testing and Experiments on Roblox]] · [[Kill Planes, Map Boundaries and Out-of-Bounds Recovery]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Objective Mode Maps - Capture the Flag, King of the Hill and Control Points]] · [[Combat Arena and Encounter Layout]] · [[Lobby and Hub Design]] · [[Economy Telemetry and Balancing Live]] · [[Global State and Live Config]] · [[Instanced Interiors - Pooled House and Room Copies for Many Players]]
<!-- related:end -->
