---
tags: [world-building, lod, streaming, slim, renderfidelity, performance, type/guide, area/world, level/intermediate, api/CollectionService, area/performance, api/Model]
---
# Level of Detail and Model Streaming

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Huge streaming radius -> Defaults or smaller; Opportunistic
> - Avoid: Moving players without streaming ahead -> `RequestStreamAroundAsync` before moving
> - Avoid: Nonatomic buildings -> Atomic
> - Streaming settings chosen deliberately and documented.
> - Every server move streams the destination first.
> - Buildings Atomic; essentials Persistent; nothing else Persistent.
>
> Cost: TL;DR ~140 tok · whole note ~4.8k tok. Read more: ## Layer 2: instance streaming · ## Layer 3: Model.LevelOfDetail · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Large Roblox worlds stay fast by not drawing (or not even loading) what is far away. Roblox gives you four layers of distance management: **mesh RenderFidelity** (per MeshPart detail), **instance streaming** (what exists on the client), **Model.LevelOfDetail** (what a streamed-out model looks like: nothing, a coarse imposter, or a SLIM composite) and **your own scripted LOD** (swapping models, sleeping effects). This note covers the art side of all four. Networking details of streaming (replication foci, scripts and `WaitForChild` patterns) are in [[Instance Streaming]].

## Layer 1: RenderFidelity on meshes

`MeshPart.RenderFidelity` (Roblox docs):

| Value | Behaviour |
|---|---|
| `Automatic` (default) | Highest detail under 250 studs, Medium 250 to 500, Lowest beyond 500 |
| `Precise` | Always highest |
| `Performance` | Always low |

The engine generates the lower levels; you do not author them. Leave `Automatic` on almost everything. Use `Precise` only where a distant silhouette visibly breaks (a thin landmark spire seen across a map), and `Performance` for small props never seen up close. The docs name "too many MeshParts set to Precise" as a common performance problem.

Hand-authored LOD meshes are still useful for **very large** pieces whose automatic reduction looks bad. One production game exported `_LOD1` versions of its gate stone and dressing meshes alongside the full meshes and swapped them by script.

## Layer 2: instance streaming

With `Workspace.StreamingEnabled`, the client only receives parts of the Workspace near its replication focus (normally the character). It is on by default for new places and cannot be set from a script (Roblox docs). Key properties (defaults from the docs):

| Property | Default | Meaning |
|---|---|---|
| `StreamingMinRadius` | 64 | Highest-priority radius; "use the default of 64" to let low-end devices scale down |
| `StreamingTargetRadius` | 1024 | Max distance content streams in; may be kept further if memory allows |
| `StreamOutBehavior` | `LowMemory` | Only streams out under memory pressure. `Opportunistic` (recommended) removes content beyond the target radius even without pressure |
| `StreamingIntegrityMode` | | `PauseOutsideLoadedArea` (recommended) pauses the player if they move into unloaded space; `MinimumRadiusPause` pauses until the minimum radius is loaded |
| `ModelStreamingBehavior` | `Legacy` | `Improved` (recommended) streams a model in only when one of its parts is eligible |

### Per-model streaming modes

`Model.ModelStreamingMode` (docs):
- `Nonatomic` (default): parts stream individually.
- `Atomic`: the model streams in and out as a unit. Use for anything whose parts must all exist together (a station, a vehicle, a gate with scripts).
- `Persistent`: sent soon after join and **never** streamed out. Use rarely: sky props, a landmark visible from everywhere, hooks that scripts must always find. Overuse "may hurt performance" (docs).
- `PersistentPerPlayer`: persistent for chosen players, atomic for others.

Set it in Studio or in server Scripts, never from LocalScripts (docs).

### An art-driven streaming story

One production game had its hub and its first realm in one place, more than 11,000 studs apart. Players in the hub could see realm models on the horizon, which meant the streaming setup was far too generous. The fix was a set of Workspace settings chosen deliberately (set by hand in Studio's Properties panel, since the project's tooling could not set them from a script): min radius 256, target radius 1,024, `Opportunistic` stream-out, `Improved` model streaming, and `MinimumRadiusPause` integrity mode. Before switching, every server-side move of a player (travel, death, teleports between hub and zones) was checked to **stream the destination first** with `Player:RequestStreamAroundAsync`, and client code that waited on Workspace children was audited.

The project also set `LevelOfDetail` to `Disabled` on all 7,861 models in its map, storing the old value in an attribute, because the owner wanted streamed-out content to vanish entirely rather than show far-away stand-ins. That is a design choice, not a universal rule: imposters and SLIM are often better (below).

```lua
--!strict
-- Server: move a player and make sure the destination is streamed before they arrive.
local function teleportStreamed(player: Player, target: CFrame)
	local ok, err = pcall(function()
		player:RequestStreamAroundAsync(target.Position, 10) -- timeout in seconds
	end)
	if not ok then
		warn("stream request failed", err)
	end
	local character = player.Character
	if character then
		character:PivotTo(target + Vector3.new(0, 4, 0))
	end
end
```

### Designing art for streaming

- **Group by visibility.** A building's parts in one Atomic model, so it never appears half-built.
- **Landmarks as Persistent sparingly**, or rely on SLIM for distant visibility.
- **Hide the streaming edge** with atmosphere haze, terrain shape, walls and zone gates (see [[Water Sky and Atmosphere Art]], [[Level Design for Roblox]]).
- **Scripts must tolerate missing parts.** Anything client-side that animates world art (sway, scrolling textures, station effects) must react to parts appearing and disappearing, typically through CollectionService signals (see [[CollectionService Patterns]]).
- **Effects from markers.** One project kept its costly waterfall and station effects client-built from invisible marker parts in a Persistent folder, so the markers always existed while the effects were created and destroyed by distance.

## Layer 3: Model.LevelOfDetail

`Model.LevelOfDetail` applies only with streaming enabled. Values (`Enum.ModelLevelOfDetail`): `Automatic`, `StreamingMesh`, `Disabled`, `SLIM`.

- **Disabled:** nothing renders once the model streams out.
- **StreamingMesh:** a "lower resolution imposter mesh", a coarse coloured mesh wrapping the model's parts, rendered outside the streaming radius. No textures, physics, collision or raycasts (docs).
- **Automatic:** a community reference says it currently behaves like Disabled; the official enum page lists it without description. Treat it as "engine decides" and set an explicit value where it matters.
- **SLIM** (Scalable Lightweight Interactive Models): the newest option, described below.

### SLIM

SLIM serialises a model's rendering data (geometry, materials, textures, transforms), uploads it to a cloud transcoder on first publish or play, and generates a composited mesh with several LODs, hidden geometry removed and textures optimised; clients fetch it from the CDN (Roblox docs, October 2026). Benefits: better distant visuals than StreamingMesh, all parts of a model change LOD together, fewer draw calls, triangles and memory.

Requirements and limits (docs):
- Streaming enabled; the place saved to Roblox (not a local file); Team Create enabled.
- **Static models only**: no runtime part changes, no animated models; models containing a `Humanoid` are excluded.
- SLIM regenerates UVs, so tiling materials may look slightly different at distance; use SurfaceAppearance for important surfaces.
- **Unions and negations may render missing or distorted**; move the operation into its own model.
- **Coplanar faces z-fight**; separate overlapping parts by about 0.01 studs.
- The first generation can take a minute or two; rejoin to see it.
- Unsupported platforms fall back to `Disabled`.

Batch conversion (from the docs, run in the command bar):

```lua
for _, descendant in workspace:GetDescendants() do
	if descendant:IsA("Model") and descendant.LevelOfDetail == Enum.ModelLevelOfDetail.StreamingMesh then
		descendant.LevelOfDetail = Enum.ModelLevelOfDetail.SLIM
	end
end
```

A safer project version records the previous value so the change can be reverted:

```lua
--!strict
local function setLod(root: Instance, value: Enum.ModelLevelOfDetail, filter: (Model) -> boolean)
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and filter(d) then
			if d:GetAttribute("PreLOD") == nil then
				d:SetAttribute("PreLOD", d.LevelOfDetail.Name)
			end
			d.LevelOfDetail = value
			n += 1
		end
	end
	print("set", n, "models to", value.Name)
end

local function revertLod(root: Instance)
	for _, d in root:GetDescendants() do
		local prev = d:GetAttribute("PreLOD")
		if d:IsA("Model") and typeof(prev) == "string" then
			d.LevelOfDetail = (Enum.ModelLevelOfDetail :: any)[prev]
			d:SetAttribute("PreLOD", nil)
		end
	end
end

-- Example: SLIM for static landmark and building models only (no Humanoids)
setLod(workspace, Enum.ModelLevelOfDetail.SLIM, function(m)
	return m:FindFirstChildWhichIsA("Humanoid", true) == nil and m:GetAttribute("Landmark") == true
end)
```

Avatars have their own switch, `Workspace.EnableSLIMAvatars` (docs).

### Which LevelOfDetail to choose

| Model type | Choice |
|---|---|
| Landmarks, buildings, cliffs visible from afar | SLIM (or StreamingMesh if SLIM is unavailable) |
| Small props, interiors, clutter | Disabled (nobody misses them far away) |
| Animated or scripted models | Disabled, or keep them Atomic/Persistent if they must be visible |
| Zones the design wants hidden until reached | Disabled, plus walls and haze |

## Layer 4: scripted LOD

Some things the engine cannot decide for you:
- **Effects sleep by distance.** Waterfalls slept beyond 650 studs; voxel showpiece particles paused beyond about 150 studs and halved on low graphics settings (one style study's numbers).
- **Animation LOD.** Distant NPCs update less often ([[Animation LOD]]).
- **Swap detailed models for simple ones** when there are many copies (crowds of the same prop).

```lua
--!strict
-- Client: swap between a detailed and a simple version of tagged models by distance,
-- with hysteresis so they do not flicker at the threshold.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local NEAR, FAR = 140, 170 -- show detailed under NEAR, simple over FAR
local camera = workspace.CurrentCamera
local state: { [Model]: boolean } = {} -- true = detailed visible
local refs: { [Model]: { hi: Instance, lo: Instance } } = {}
local acc = 0

local function setDetailed(m: Model, detailed: boolean)
	local r = refs[m]
	if not r then
		local hi, lo = m:FindFirstChild("High"), m:FindFirstChild("Low")
		if not hi or not lo then return end
		r = { hi = hi, lo = lo }
		refs[m] = r
	end
	-- Parent swap is cheaper than toggling many Transparency values
	r.hi.Parent = if detailed then m else nil
	r.lo.Parent = if detailed then nil else m
end

CollectionService:GetInstanceRemovedSignal("ScriptedLOD"):Connect(function(m)
	state[m :: Model] = nil
	refs[m :: Model] = nil
end)

RunService.Heartbeat:Connect(function(dt: number)
	acc += dt
	if acc < 0.25 then return end -- four checks a second is plenty
	acc = 0
	local camPos = camera.CFrame.Position
	for _, m in CollectionService:GetTagged("ScriptedLOD") do
		if m:IsA("Model") then
			local d = (m:GetPivot().Position - camPos).Magnitude
			local detailed = state[m]
			if detailed ~= true and d < NEAR then
				state[m] = true
				setDetailed(m, true)
			elseif detailed ~= false and d > FAR then
				state[m] = false
				setDetailed(m, false)
			end
		end
	end
end)
```

This only changes what the local client renders. References are cached because a child parented to nil can no longer be found by name. Keep collision on separate invisible colliders so swaps never change gameplay (see [[Collision and Physics Geometry]]).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Huge streaming radius | Far zones visible, memory high on phones | Defaults or smaller; Opportunistic |
| Moving players without streaming ahead | Falling through unloaded floors | `RequestStreamAroundAsync` before moving |
| Nonatomic buildings | Half-built buildings popping in | Atomic |
| Persistent everywhere | Streaming benefits lost | Persistent only for essentials |
| Precise RenderFidelity by default | Heavy distant geometry | Automatic |
| Unions in SLIM models | Missing or distorted distant shapes | Separate model or mesh |
| Client effects assuming parts exist | Errors after stream-out | Tag signals, nil checks |
| LOD flicker at one threshold | Popping | Hysteresis |

## Checklist

- [ ] Streaming settings chosen deliberately and documented.
- [ ] Every server move streams the destination first.
- [ ] Buildings Atomic; essentials Persistent; nothing else Persistent.
- [ ] LevelOfDetail chosen per model class; old values stored for revert.
- [ ] RenderFidelity Automatic except justified cases.
- [ ] Effects and animations sleep by distance.
- [ ] Streaming edge hidden by haze, terrain or walls.

## See also

- [[Instance Streaming]], [[Art Budgets - Triangles Draw Calls Memory]], [[Rendering Performance]], [[Mobile and Low-End Optimization]]
- [[Parts Unions and MeshParts]], [[Collision and Physics Geometry]], [[Level Design for Roblox]], [[Water Sky and Atmosphere Art]]
- [[Animation LOD]], [[Case Study - Fast Join and Deferred Loading]], [[Teleporting and Multi-Place Games]]

## Nuances and edge cases

1. **The server never streams.** Instance streaming only changes what clients hold; the server always has the whole place in memory and simulates every unanchored assembly. A map that is "fine because of streaming" can still run a server out of memory or physics time. Budget server memory separately, and keep physics on decorative props off (anchored, no collisions) regardless of streaming.
2. **Streaming is device-adaptive.** Clients under memory pressure may keep less content than the target radius, while strong devices keep more (Roblox docs, as of October 2026, describe streaming adapting to available memory; exact thresholds are not published, so treat them as unknown). The result: a bug that only happens on phones ("the door is missing") is often a script assuming content that low-memory devices streamed out.
3. **Scale changes the server picture, not the client one.** One player or 50, each client streams only around itself. But the server sends streaming data to every player, so 50 players spread across a big map cost more server bandwidth than 50 players huddled in a lobby. With very large player counts, design maps so players cluster in shared spaces.
4. **Atomic is a trade, not a fix.** Making a building atomic stops half-built pop-in but means the whole model streams at once, which spikes when a player arrives at a dense district. Split very large atomic models into a few atomic chunks (exterior shell, interior) so arrival cost is spread out.
5. **Persistent models cost every player all the time.** A persistent model is sent to every client and never streamed out. A dozen persistent "landmarks" with full interiors can quietly undo the memory savings. Keep persistent content to tiny, gameplay-critical objects and use a cheap distant proxy for visual landmarks.
6. **LOD and gameplay must agree.** If a distant tower is a low-detail proxy on the client, raycasts and line-of-sight checks on the client hit the proxy shape, not the real one. Do hit and visibility checks on the server, which has the full model, or make proxies non-collidable and exclude them from queries.
7. **Teleports within a place need streaming ahead.** Moving a character 2,000 studs in one frame lands it in empty space on slower devices. Request streaming around the destination on the server before moving, and give the player a short fade to hide the remaining load.
8. **Scripted LOD on PC versus phone.** The same distance thresholds feel different on a 27-inch monitor and a 6-inch phone; the phone shows fewer pixels per object, so it can drop detail earlier. A device-tier multiplier on LOD distances (smaller on low-end) is a cheap win.
9. **Version changes.** Streaming defaults and features have changed several times (new model modes, mesh streaming for LOD). Re-test after major engine updates rather than assuming behaviour from an old tutorial.

The senior trade-off: streaming saves client memory and join time but makes every client script uncertain about what exists. The cost is paid in defensive code. Decide early, because retrofitting streaming onto a game whose scripts assume everything exists is a multi-week job.

## Common mistakes (advanced)

1. **Client scripts indexing world parts with dot syntax.** Symptom: errors on phones, works in Studio on a strong PC. Fix: tag-based setup with `GetInstanceAddedSignal` and removal handling.
2. **Proxies left collidable.** Symptom: players or projectiles hit invisible or low-detail shapes. Fix: `CanCollide`, `CanQuery` and `CanTouch` off on proxies.
3. **Testing streaming only in Studio with a high-end machine.** Symptom: pop-in and missing content complaints from mobile players after launch. Fix: test on a real low-end phone and with the Studio device emulator plus a low memory profile ([[Multi-Client and Device Playtesting Protocols]]).
4. **One giant atomic model for a whole zone.** Symptom: a long hitch on arrival. Fix: several smaller atomic chunks.
5. **Server-side code waiting for client-streamed content.** Symptom: confusion about why the server "sees" things the client does not. Fix: remember the server has everything; design client code to tolerate absence.
6. **LOD thresholds with no hysteresis and moving cameras.** Symptom: visible flicker as the camera bobs at the boundary. Fix: separate in and out distances, a few studs apart.

## Related decisions

- [[Instance Streaming]]: the networking view of the same feature.
- [[Infinite and Streamed Worlds]]: designing world generation around streaming.
- [[Mesh Optimization for Mobile]]: making the high-detail version cheap in the first place.
- [[Case Study - Fast Join and Deferred Loading]]: join time as a streaming benefit.
- [[Case Study - Cutting a Million Instances]]: instance count as the other half of the budget.
- [[Spawn Points Safe Zones and Respawn Flow]]: where streaming ahead matters most.
- [[Raycasts Shapecasts and Spatial Queries]]: excluding proxies from queries.
- [[Mobile and Low-End Optimization]]: device tiers for LOD multipliers.
- [[Zone and Biome Art Direction]]: designing landmarks that read at low detail.

## Connected notes
<!-- auto-links:start -->
[[Streaming Radius]] · Links - StreamingEnabled · Interest Management and Per-Player Replication · Performance and Memory · Network Performance · Retopology and Decimation
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]] · [[StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs]] · [[Foliage Props and Scatter]] · [[Textures Decals and Texture Memory]] · [[Procedural World Generation]] · [[Terrain Deep Dive - Materials Water and Performance]] · [[Terrain Tools and Terrain API]] · [[Modeling in Blender for Roblox]]
<!-- related:end -->
