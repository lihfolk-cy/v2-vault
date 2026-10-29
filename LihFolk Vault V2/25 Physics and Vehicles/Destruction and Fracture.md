---
tags: [physics, destruction, fracture, csg, geometryservice, explosions, performance, type/guide, area/physics, level/intermediate, api/Terrain, area/performance]
---
# Destruction and Fracture

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Server-side debris for cosmetic breaks -> Client-only debris (technique A)
> - Avoid: One welded assembly for the whole building -> Anchored chunks + adjacency graph
> - Avoid: Default explosion joint breaking -> `DestroyJointRadiusPercent = 0`, server damage
> - Each breakable classified: cosmetic, structural, terrain or sandbox.
> - Cosmetic breaks are client-only with pooled debris.
> - Structural breaks: server-owned, pre-fractured or queued runtime fracture, connectivity checked.
>
> Cost: TL;DR ~160 tok · whole note ~4.5k tok. Read more: ## 3. Technique B: pre-fractured models · ## 4. Technique C: runtime fracture with GeometryService · ## 9. Common mistakes · ## Checklist
<!-- tldr:end -->

Breaking things is one of the most satisfying verbs in a game and one of the easiest ways to wreck a Roblox server. Every new fragment is an instance that must replicate to every client, every unanchored fragment is a physics body, and every client's frame rate pays for the debris it can see. This note covers the five ways to make things break (swap models, pre-fractured welds, runtime fracture with `GeometryService`, explosions, terrain and voxel destruction), how to decide what breaks on the server, the budgets that keep it running on phones, debris lifecycles, rebuilding, and the exploits destruction invites.

Prerequisites: [[Physics Assemblies and Constraints]] (assemblies, welds, collision groups), [[Physics Performance]], [[Collision and Physics Geometry]].

Source labels: **Docs** (Roblox docs, as of October 2026), **Rule of thumb**. Code is strict Luau, **reviewed, not run**.

---

## 1. Decide what "destruction" means in your game

| Kind | Example | Gameplay effect | Approach |
|---|---|---|---|
| **Cosmetic** | Crates shatter, glass breaks | None, or a pickup drops | Swap + client-only debris |
| **Structural** | Walls break open, bridges collapse | Line of sight and paths change | Pre-fractured or runtime fracture, server-authoritative |
| **Terrain** | Craters, digging, tunnels | Ground shape changes | Terrain edits or voxel grid |
| **Sandbox** | Everything is breakable, players build and destroy | Is the game | Voxel/grid model plus strict budgets |

The single biggest decision: does the destruction change gameplay? If not, it can be **client-only** and costs the server nothing. If it does, the server must own the result, and you pay replication for every piece.

---

## 2. Technique A: swap and fake

Replace the intact model with a broken-looking model (or nothing), and spawn short-lived debris and particles on each client.

- The server changes one thing (deletes the crate, or sets an attribute `Broken = true`).
- Each client sees the change and plays the effect locally: spawns a handful of debris parts from a pool, applies impulses, fades them out after a few seconds.
- No fragments replicate, no server physics.

This is the right answer for the large majority of "breakable" objects. Players cannot tell the debris is different on each screen. Pair it with good sound and camera shake and it reads as heavy destruction ([[Game Feel and Juice]], [[Camera Shake and Camera FX]]).

```lua
--!strict
-- LocalScript: play a client-side shatter when a breakable gets Broken = true.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local DEBRIS_COUNT = 8

local function shatter(model: Model)
	local cf, size = model:GetBoundingBox()
	local rng = Random.new()
	for _ = 1, DEBRIS_COUNT do
		local p = Instance.new("Part")
		p.Size = size / 3 * rng:NextNumber(0.4, 1)
		p.CFrame = cf * CFrame.new(
			rng:NextNumber(-size.X / 3, size.X / 3),
			rng:NextNumber(-size.Y / 3, size.Y / 3),
			rng:NextNumber(-size.Z / 3, size.Z / 3))
		p.CanTouch = false
		p.CanQuery = false
		p.CollisionGroup = "Debris"
		p.Parent = workspace
		p:ApplyImpulse(rng:NextUnitVector() * p.AssemblyMass * 30)
		Debris:AddItem(p, 3)
	end
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("Broken"):Connect(function()
		if model:GetAttribute("Broken") == true then
			shatter(model)
		end
	end)
end

for _, m in CollectionService:GetTagged("Breakable") do
	watch(m)
end
CollectionService:GetInstanceAddedSignal("Breakable"):Connect(watch)
```

For production, replace `Instance.new` with a pool and match debris colour and material to the source model. `Debris:AddItem` is fine for small counts; a pool with its own timer is better for heavy use. `ApplyImpulse` works here because the client created the part and owns it.

---

## 3. Technique B: pre-fractured models

Model the object already cut into chunks (in Blender, or with Studio's CSG or `FragmentAsync` at edit time, section 4), weld the chunks together, and break welds at runtime.

- The intact object is one assembly of welded chunks. Anchor one chunk (or the base) so it stands.
- On damage, the server destroys the welds around the impact point and unanchors the chunks that are no longer connected to anything anchored.
- Chunks fall with physics. You get real structural collapse with designer-controlled pieces.

### Deciding what falls: connectivity

Breaking welds at the impact point is easy. The hard part is knowing which remaining chunks have lost support. Store the chunk graph (which chunk is welded to which, and which chunks are "grounded") in a table when the model loads. After removing edges, flood-fill from grounded chunks; everything not reached falls. The graph has tens to low hundreds of nodes, so this is microseconds.

```lua
--!strict
-- Server: chunk connectivity for one pre-fractured structure.
export type Graph = {
	neighbours: { [BasePart]: { [BasePart]: WeldConstraint } },
	grounded: { [BasePart]: boolean },
}

local function supported(graph: Graph): { [BasePart]: boolean }
	local reached: { [BasePart]: boolean } = {}
	local stack: { BasePart } = {}
	for chunk in graph.grounded do
		reached[chunk] = true
		table.insert(stack, chunk)
	end
	while #stack > 0 do
		local c = table.remove(stack) :: BasePart
		for other in graph.neighbours[c] or {} do
			if not reached[other] then
				reached[other] = true
				table.insert(stack, other)
			end
		end
	end
	return reached
end

local function breakAt(graph: Graph, center: Vector3, radius: number)
	-- Remove every weld touching a chunk inside the radius.
	for chunk, links in graph.neighbours do
		if (chunk.Position - center).Magnitude <= radius then
			for other, weld in links do
				weld:Destroy()
				links[other] = nil
				local back = graph.neighbours[other]
				if back then
					back[chunk] = nil
				end
			end
			graph.grounded[chunk] = nil
		end
	end
	local keep = supported(graph)
	for chunk in graph.neighbours do
		if not keep[chunk] and chunk.Anchored then
			chunk.Anchored = false
		end
	end
end
```

In this design chunks are anchored individually (each standing chunk anchored, welds only recording adjacency) so that unanchoring exactly the unsupported ones drops them. That avoids one huge welded assembly whose root changes as pieces leave ([[Physics Assemblies and Constraints]], "root part").

### Breakable joints in the engine

`RigidConstraint` has hidden properties named `DestructionEnabled`, `DestructionForce` and `DestructionTorque` in the API dump, but this note could not find official documentation of their behaviour as of October 2026. Do not build structural gameplay on them without testing in your Studio build. A scripted threshold (break when an impact's relative velocity times mass exceeds a value) is predictable and documented by you.

### Chunk budgets (rule of thumb)

- 10 to 40 chunks per breakable wall. More looks better in a trailer and worse on a phone.
- Make chunks fall once, then settle and **anchor** or delete them after a few seconds. A pile of 200 sleeping chunks still costs memory and replication; a pile of 200 anchored chunks costs only memory.
- Put falling chunks in a `Debris` collision group that does not collide with characters, or players get launched by a collapsing wall (fun once, a support ticket after).

---

## 4. Technique C: runtime fracture with GeometryService

`GeometryService` provides solid-modelling operations at runtime (**Docs**):

- `SubtractAsync(part, parts, options)`, `UnionAsync`, `IntersectAsync`: CSG on primitive Parts, PartOperations and MeshParts. Results are returned **without a parent**; you parent them and destroy the originals. If any input is a MeshPart, results are MeshParts. Options include `CollisionFidelity`, `RenderFidelity`, `FluidFidelity` and `SplitApart` (default true: disconnected pieces become separate parts). Terrain is not supported.
- `GenerateFragmentSites(part, options)` returns Vector3 sites for fracturing, either across the whole part or, with `Origin` and `Radius`, a local area. Sites are partly random, so results differ between calls. `SiteSpacing` sets the approximate fragment size.
- `FragmentAsync(part, sites, options)` splits a part into MeshParts by Voronoi decomposition around the sites. Results are `{ Instance, Index }` dictionaries, unparented.
- `CalculateConstraintsToPreserve` helps re-attach constraints and welds to the new pieces after a subtract.
- All of these yield, are not thread safe, and require the CSG capability. The Docs examples wrap calls in `pcall`.

```lua
--!strict
-- Server: blow a local hole in a wall part.
local GeometryService = game:GetService("GeometryService")

local function fractureAround(part: BasePart, hitPos: Vector3, radius: number): boolean
	local sites = GeometryService:GenerateFragmentSites(part, {
		Origin = hitPos,
		Radius = radius,
	})
	local ok, results = pcall(function()
		return GeometryService:FragmentAsync(part, sites, {
			CollisionFidelity = Enum.CollisionFidelity.Hull,
		})
	end)
	if not ok or typeof(results) ~= "table" then
		return false
	end
	-- With Origin/Radius, the first entry of `sites` is the group of sites outside the radius
	-- (Docs), so pieces with Index 1 form the remaining wall; the others are fragments.
	for _, r in results do
		local piece = r.Instance :: BasePart
		if r.Index == 1 then
			piece.Anchored = true
		else
			piece.Anchored = false
			piece.CollisionGroup = "Debris"
		end
		piece.Parent = part.Parent
	end
	part:Destroy()
	return true
end
```

Trade-offs of runtime fracture:

- **It yields and is not free.** A fracture can take noticeable time on a complex mesh. Queue fractures, and never fracture the same part twice concurrently (the second call works on a part that is about to be destroyed).
- **Every result replicates.** New MeshParts with new geometry are sent to every client. Ten simultaneous fractures of large walls is a bandwidth spike. Measure it ([[Network Bandwidth Budgets and Measuring Them]]).
- **Results are unpredictable.** Site randomness means the wall breaks differently each time. Good for variety, bad for level design that relies on a specific opening. For designed openings, pre-fracture.
- **Fragments accumulate.** Each hit on a wall creates more, smaller pieces. Cap the number of fracture generations per object, and below a minimum size delete pieces instead of fracturing them.
- **Edit-time use is excellent.** Run `FragmentAsync` from the command bar or a plugin to build pre-fractured models (technique B) with no Blender work.

---

## 5. Technique D: explosions

The `Explosion` instance applies an outward impulse to parts within `BlastRadius` scaled by `BlastPressure`, and breaks joints for parts within `DestroyJointRadiusPercent` of the radius. Its `Hit` event fires for each part hit with the distance. `ExplosionType` controls terrain craters. Rule of thumb: these properties are long-standing, but check the current reference before relying on exact behaviour.

Practical guidance:

- Set `DestroyJointRadiusPercent = 0` unless you want joint breaking, because the default behaviour can break character joints and kill players outright, bypassing your damage system.
- Apply gameplay damage yourself from the server, using distance falloff and a line-of-sight cast, not from `Hit` alone. `Hit` fires per part, so a character is "hit" many times; deduplicate by character model.
- Visual-only explosions: set `BlastPressure = 0` and use your own VFX, or skip the instance entirely and use particles ([[VFX Design Playbook]]).
- For destruction, the explosion's job is to call your `breakAt` (technique B) or queue a fracture (C), then let the falling chunks' physics look dramatic.

---

## 6. Technique E: terrain and voxels

### Terrain

`Terrain:FillBall(center, radius, Enum.Material.Air)` carves a crater; `FillBlock`, `FillCylinder` and `FillWedge` give other shapes. Terrain edits replicate; the Terrain note says each edit replicates and that destructible ground is a strength of terrain at a replication cost ([[Terrain Deep Dive - Materials Water and Performance]]). Batch small craters, and rate-limit digging tools on the server ([[Rate Limiting and Abuse Prevention]]).

Edge cases: carving under a character drops them (intended); carving under anchored props leaves them floating (check with a downward cast and unanchor or delete). Carving through a map's floor into the void needs a minimum depth or an indestructible bottom layer.

### Voxel/grid destruction for sandboxes

For "everything breaks" games, model the world as a grid of cells stored in a table (or a `buffer` for large worlds, [[Buffers and Binary Data]]). Parts are only the **rendering** of the grid: merge runs of identical cells into larger parts (greedy meshing) so a wall of 1,000 cells might be 20 parts. On damage, edit the grid, rebuild only the affected chunk's parts, and replicate cell changes as compact messages so clients rebuild locally. This is the only approach that scales to large destructible worlds, and it is a big engineering project. Prototype the merging and replication before committing a game to it.

---

## 7. Server authority and exploits

- **The server decides what breaks.** Clients request ("I hit this wall here with this weapon"), the server validates range, rate and weapon, and applies the break. Never let a client remote say "break wall X".
- **Rate-limit destruction requests per player.** Destruction is expensive on the server, so it is a denial-of-service lever: one exploiter spamming fracture requests can lag a whole server. Hard caps per player per second, plus a global queue with a maximum depth.
- **Debris and physics flings.** Fragments that collide with characters at high speed can fling players. `Debris` collision group off characters, or impulses capped.
- **Rebuild on a timer or round reset.** Keep an intact template in `ServerStorage` and restore by cloning. Do not try to re-weld fragments.
- **Persisted destruction** (a player's base was damaged) belongs in data, not in instances: save the grid or the health of each structure, rebuild visuals on load ([[Data Schema Design and Migrations]]).

---

## 8. Budgets and performance

Rules of thumb for a mixed-device audience:

| Budget | Phone-friendly | Notes |
|---|---|---|
| Simultaneously falling server-owned chunks | 50 to 150 | Then anchor or delete |
| Client-only debris pieces alive at once | 100 to 300 | Pooled, short-lived, no touch/query |
| Runtime fractures per second, server-wide | A few | Queued, capped per player |
| Fragments kept per structure | Under 100 | Delete below a size threshold |

- Unanchored fragments that come to rest go to sleep and cost little simulation, but they still replicate if bumped and still count toward instance counts. Anchor settled pieces.
- Debris should have `CanTouch = false` and `CanQuery = false` unless it is gameplay, so it never pays for touch events or slows your casts ([[Physics Performance]]).
- Check the MicroProfiler's physics section during a big collapse on a low-end device ([[MicroProfiler Guide]]).
- Streaming: fragments created on the server are streamed like other parts; a player far away may not receive them at all, which is usually what you want ([[Instance Streaming]]).

---

## 9. Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Server-side debris for cosmetic breaks | Server lag, bandwidth spikes | Client-only debris (technique A) |
| One welded assembly for the whole building | Pieces float, root jumps, odd collapses | Anchored chunks + adjacency graph |
| Default explosion joint breaking | Players die outside your damage system | `DestroyJointRadiusPercent = 0`, server damage |
| `Hit` used as damage per part | Characters take damage many times | Deduplicate per character |
| Fracturing fragments of fragments | Thousands of tiny parts | Generation cap, minimum size |
| No rate limit on break requests | One exploiter lags the server | Per-player caps, global queue |
| Debris collides with characters | Players flung | `Debris` collision group |
| Never anchoring settled pieces | Memory and replication creep | Settle timer, anchor or delete |
| Relying on undocumented joint destruction props | Behaviour changes or never triggers | Scripted thresholds |

## Checklist

- [ ] Each breakable classified: cosmetic, structural, terrain or sandbox.
- [ ] Cosmetic breaks are client-only with pooled debris.
- [ ] Structural breaks: server-owned, pre-fractured or queued runtime fracture, connectivity checked.
- [ ] Explosion joint breaking disabled unless intended; damage computed on the server.
- [ ] Per-player and global destruction rate limits.
- [ ] Debris collision group, no touch/query, settle-and-anchor timer.
- [ ] Rebuild path from a template; persisted destruction stored as data.
- [ ] Worst-case collapse profiled on a low-end phone.

## See also

[[Physics and Vehicles Start Here]] · [[Physics Assemblies and Constraints]] · [[Physics Performance]] · [[Collision and Physics Geometry]] · [[Terrain Deep Dive - Materials Water and Performance]] · [[Terrain Tools and Terrain API]] · [[Projectiles and Ballistics]] · [[VFX Design Playbook]] · [[Game Feel and Juice]] · [[Rate Limiting and Abuse Prevention]] · [[Ropes Chains and Soft Bodies]]

## Connected notes
<!-- auto-links:start -->
[[Parts Unions and MeshParts]] · Instance Count · Debugging Physics and Network Ownership · Network Ownership · Object Pooling · Infinite and Streamed Worlds
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Explosions - Radius Damage, Falloff and Cover Checks]] · [[Vehicle Damage, Repair and Wreck States]] · [[Instance Count]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Debugging Physics and Network Ownership]] · [[Standing on Moving Vehicles and Platforms - Keeping Players Glued]]
<!-- related:end -->
