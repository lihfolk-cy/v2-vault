---
tags: [architecture, ecs, data-oriented, performance, npc, type/guide, area/networking, level/advanced, api/CollectionService, area/data]
---
# Entity Component Systems

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: ECS for the whole game including UI and data -> Use it for simulation subsystems
> - Avoid: Replicating every component -> Classify components: server-only, replicated, client-only
> - Avoid: Systems in arbitrary order -> One explicit ordered list
> - The subsystem has enough entities or behaviour combinations to justify an ECS.
> - Systems run in one explicit order and never yield.
> - Each component is classified for replication; late joiners get a snapshot.
>
> Cost: TL;DR ~160 tok · whole note ~4.8k tok. Read more: ## A small ECS in Luau · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

An **Entity Component System** ([[Entity Component System|ECS]]) organises game state as data rather than objects. An **entity** is just an id. **Components** are plain data attached to entities (`Position`, `Health`, `Target`, `Burning`). **Systems** are functions that run every frame over all entities that have a given set of components ("for every entity with `Velocity` and `Position`, move it"). On Roblox, an ECS can make large simulations (hundreds of NPCs, thousands of projectiles, crops, units) faster, simpler to reason about and easier to replicate. It can also add a layer of indirection a ten-object game never needed. This note explains the model, how it maps to Roblox instances, when to use it, a small working ECS in Luau, how to replicate ECS state, and how the libraries (Matter, jecs) fit.

## Objects vs ECS

| Question | Object-oriented style | ECS style |
|---|---|---|
| Where does "enemy" live? | An `Enemy` class with fields and methods | An entity id with `Health`, `AI`, `Model`, `Faction` components |
| How do you add "burning"? | A flag and branches in many methods, or a subclass | Add a `Burning` component; one `burnSystem` handles every burning entity, enemy or player or crate |
| What runs each frame? | Each object's `Update`, in arbitrary order | A fixed list of systems in a fixed order |
| Where is behaviour shared? | Inheritance or mixins | Systems that query component sets |
| Memory layout | Objects scattered | Components stored together (archetype tables in libraries) |

The big wins are **composition** (behaviour attaches by data, not by class) and **explicit frame order** (systems run in a known sequence, so "who updates first" stops being a bug source). Performance gains come from iterating tight arrays instead of calling methods on scattered objects, but in Luau the bigger performance win is usually just doing less per entity.

## Mapping to Roblox

Roblox already has an instance tree with attributes and tags, which behaves like a crude ECS:

| ECS concept | Roblox equivalent | Limits |
|---|---|---|
| Entity | An Instance (Model) | Instances are heavy (memory, replication, property changes are costly) |
| Component | An attribute or a tag | Attributes are slow to read every frame compared to Luau tables; types limited |
| System | A CollectionService manager iterating tagged instances | Iteration over `GetTagged` allocates arrays |
| Query | `CollectionService:GetTagged` | One tag at a time |

That "instance ECS" is the right tool for world objects with low update rates (doors, chests, pickups): see [[CollectionService Patterns]]. A **Luau-table ECS** is for things that update every frame in large numbers. The common hybrid: the ECS world holds the authoritative simulation state in tables, and a **render system** writes the results to Instances (or the instances exist only on clients).

## When to use an ECS (and when not)

| Use one when | Avoid it when |
|---|---|
| Hundreds or thousands of similar simulated things | A few dozen objects with distinct behaviour |
| Many overlapping behaviours (status effects, AI traits, auras) combining freely | Behaviour is mostly UI and one-off scripted events |
| Frame order bugs keep appearing between systems | The team does not know the pattern and the deadline is close |
| You want server simulation separate from client rendering | Physics does most of the work (the engine already simulates it) |

Rule of thumb: introduce an ECS for **one subsystem** (projectiles, enemies, crops) rather than rewriting the whole game. UI, data saving, purchases and menus gain little from it.

## A small ECS in Luau

This is deliberately minimal so its behaviour is obvious: sparse component tables keyed by entity id, queries that iterate the smallest component set. Libraries are faster (archetype storage, cached queries), but the programming model is the same.

```lua
--!strict
-- ReplicatedStorage/Shared/World.luau: a minimal ECS.
export type Entity = number

local World = {}
World.__index = World

export type World = typeof(setmetatable({} :: {
	nextId: number,
	alive: { [Entity]: boolean },
	components: { [string]: { [Entity]: any } },
}, World))

function World.new(): World
	return setmetatable({ nextId = 0, alive = {}, components = {} }, World)
end

function World.spawn(self: World): Entity
	self.nextId += 1
	local id = self.nextId
	self.alive[id] = true
	return id
end

function World.despawn(self: World, id: Entity)
	self.alive[id] = nil
	for _, store in self.components do
		store[id] = nil
	end
end

function World.set(self: World, id: Entity, component: string, value: any)
	assert(self.alive[id], "set on dead entity")
	local store = self.components[component]
	if not store then
		store = {}
		self.components[component] = store
	end
	store[id] = value
end

function World.get(self: World, id: Entity, component: string): any
	local store = self.components[component]
	return store and store[id]
end

function World.remove(self: World, id: Entity, component: string)
	local store = self.components[component]
	if store then store[id] = nil end
end

-- Iterate entities that have ALL listed components. Calls fn(id, c1, c2, ...).
function World.each(self: World, names: { string }, fn: (Entity, ...any) -> ())
	-- Drive the loop from the smallest store.
	local smallest: { [Entity]: any }? = nil
	local smallestCount = math.huge
	for _, name in names do
		local store = self.components[name]
		if not store then return end -- some component has no entities: empty result
		local n = 0
		for _ in store do n += 1 end
		if n < smallestCount then
			smallest, smallestCount = store, n
		end
	end
	if not smallest then return end

	local values = table.create(#names)
	for id in smallest do
		local ok = true
		for i, name in names do
			local v = self.components[name][id]
			if v == nil then ok = false break end
			values[i] = v
		end
		if ok then fn(id, table.unpack(values, 1, #names)) end
	end
end

return World
```

Note: removing components or despawning other entities inside `each` while iterating is safe for *other* entries in Luau only if you do not add new keys to the store being iterated; collect changes in a list and apply after the loop when in doubt.

### Systems and a scheduler

```lua
--!strict
-- Server: projectile simulation as ECS systems, run in a fixed order each Heartbeat.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local World = require(game.ReplicatedStorage.Shared.World)

local world = World.new()

type Projectile = { speed: number, damage: number, owner: Player, life: number }

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function moveProjectiles(dt: number)
	local toDespawn: { number } = {}
	world:each({ "Position", "Direction", "Projectile" }, function(id, pos: Vector3, dir: Vector3, p: Projectile)
		local step = dir * p.speed * dt
		local hit = Workspace:Raycast(pos, step, rayParams)
		if hit then
			world:set(id, "Hit", { instance = hit.Instance, position = hit.Position })
		else
			world:set(id, "Position", pos + step)
		end
		p.life -= dt
		if p.life <= 0 then table.insert(toDespawn, id) end
	end)
	for _, id in toDespawn do world:despawn(id) end
end

local function resolveHits()
	local done: { number } = {}
	world:each({ "Hit", "Projectile" }, function(id, hit, p: Projectile)
		-- Server-side damage from server data (p.damage), never from a client message.
		local model = hit.instance:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:TakeDamage(p.damage) end
		table.insert(done, id)
	end)
	for _, id in done do world:despawn(id) end
end

-- The frame order is explicit and visible.
local SYSTEMS = { moveProjectiles, resolveHits }

RunService.Heartbeat:Connect(function(dt)
	for _, system in SYSTEMS do
		system(dt)
	end
end)

local function fire(owner: Player, origin: Vector3, direction: Vector3)
	local id = world:spawn()
	world:set(id, "Position", origin)
	world:set(id, "Direction", direction.Unit)
	world:set(id, "Projectile", { speed = 120, damage = 25, owner = owner, life = 3 } :: Projectile)
	return id
end

return { fire = fire, world = world }
```

No Instance exists for the projectile on the server. Clients receive "projectile id, origin, direction, speed, start time" once and simulate the visual themselves. That is the replication strategy that makes an ECS pay off on Roblox.

## Replicating ECS state

The ECS world lives in Luau memory; nothing replicates automatically. Options, from simplest:

| Strategy | How | Good for |
|---|---|---|
| **Spawn event + deterministic client simulation** | Server sends the initial state once (reliable remote); clients simulate; server sends corrections or the end event | Projectiles, tweened movers, anything predictable |
| **State attributes on a proxy instance** | Each replicated entity has a lightweight Instance (a Model or even a Folder) with attributes for the components clients need | Enemies with models anyway; works with streaming |
| **Snapshot deltas** | Server collects changed components per frame and sends a batched (unreliable or reliable) delta at 10 to 20 Hz | Many moving units; buffers keep it small ([[Buffers and Binary Data]]) |
| **Client-only ECS** | Purely cosmetic entities (debris, birds, ambient life) created and simulated on each client | Visual density at zero network cost |

Rules: decide per component whether it is **server-only** (AI internals, aggro tables), **replicated** (health, state, target) or **client-only** (animation phase, LOD level). Replicate on change and quantised. Late joiners need a full snapshot of replicated components on join.

### Production example: enemies as server state plus client presentation

One production game ran a few hundred enemies across zones without an ECS library but with the same split. The server's enemy system held AI and combat state in Luau tables (effectively components: position target, aggro, cooldowns, stagger thresholds at 75, 50 and 25% health) and wrote only small replicated attributes on each enemy model (`Anim`, `AnimT`, `AnimSpeed`, `Hurt`, `Phase`). Each client ran its own enemy animator that read those attributes, played clips, joined late by server time, culled off-screen enemies and reduced detail by distance. Hits were data-driven on the server (mark times in each enemy's definition), so the server never needed animated parts. The server's animation cost was close to zero. See [[Enemy Animation State Protocol]], [[Snippets - Enemy Client Animator]] and [[Replication and Ownership]].

That is the ECS idea applied to Roblox even without the library: **simulation state in tables on the server, presentation as a system on every client, a narrow replicated component set in between.**

## Libraries: Matter and jecs

| | Matter | jecs |
|---|---|---|
| Status | Maintained by the `matter-ecs` organisation (originally by evaera) (verified October 2026) | Maintained by Ukendio (verified repository October 2026) |
| Storage | Archetype-based world | Archetype-based, struct-of-arrays |
| Distinctive features | System scheduler with per-system hooks (`useEvent`, throttle helpers), a visual debugger | Entity **relationships** (pairs), high iteration throughput, typed API, zero dependencies |
| Typical fit | Teams that want a full ECS workflow with tooling | Performance-sensitive simulations; teams comfortable building their own scheduler |

Both APIs have changed across versions (constructors, query iteration), so follow the docs for the version you install rather than older tutorials; pin it with Wally. The concepts above (entities, components, queries, systems in order, explicit replication) transfer directly.

## ECS pitfalls on Roblox

- **Instance references in components** keep instances alive after they are destroyed. Clean them up in a system that watches `Destroying` or checks `Parent`.
- **Yielding inside systems** breaks frame order. Systems should never yield; spawn async work and write the result back as a component later.
- **Per-frame allocation**: creating tables for every component update each frame churns the garbage collector. Mutate in place where safe, reuse tables ([[Script Performance]]).
- **Parallel Luau**: systems over independent data can run in parallel with Actors, but writes to the DataModel must be synchronised; see [[Parallel Luau and Actors]].
- **Debuggability**: "which systems touched this entity?" needs tooling. Name components clearly and add a debug view (Matter ships one).
- **Security unchanged**: an ECS on the server is still fed by remotes; components set from client requests still need validation.

## Common mistakes

| Mistake | Fix |
|---|---|
| ECS for the whole game including UI and data | Use it for simulation subsystems |
| Replicating every component | Classify components: server-only, replicated, client-only |
| Systems in arbitrary order | One explicit ordered list |
| Mutating stores while iterating them | Collect, then apply after the loop |
| Holding destroyed Instances in components | Cleanup system |

## Checklist

- [ ] The subsystem has enough entities or behaviour combinations to justify an ECS.
- [ ] Systems run in one explicit order and never yield.
- [ ] Each component is classified for replication; late joiners get a snapshot.
- [ ] Client presentation is a system on clients, not server-side instance churn.
- [ ] Library version pinned and its current API documented in the project.

## See also
[[Frameworks - Knit Matter and Others]] · [[CollectionService Patterns]] · [[Replication Rules]] · [[Buffers and Binary Data]] · [[Parallel Luau and Actors]] · [[NPC AI and Behaviour]] · [[Enemy Animation State Protocol]] · [[Script Performance]]

## Nuances and edge cases

1. **ECS speed comes from data layout, and Luau limits it.** In C++ engines, ECS is fast because components sit in contiguous memory. Luau tables are references, so a "component array" is an array of pointers to tables, and much of the cache benefit disappears. Libraries such as jecs work hard to recover some of it with archetype storage. The main gains on Roblox are usually architectural (clear systems, easy queries), with speed a secondary benefit; measure before claiming a performance win.
2. **Instances are the expensive part, not entities.** An ECS with 10,000 entities and no instances is cheap. The same ECS that creates a Model per entity hits instance-count, replication and memory limits long before the ECS itself matters. Keep many entities as pure data and give instances only to those near players.
3. **Replication is not automatic.** Roblox replicates instances and their properties, not your component tables. You must decide which components go to clients, how often and to whom. A naive "send all changed components every tick" works at 1 player and overwhelms bandwidth at 50 with hundreds of entities (see [[Interest Management and Per-Player Replication]]).
4. **Systems order is a hidden dependency graph.** Movement before collision before damage before death is a real order; getting it wrong produces one-frame bugs (an entity damaged after it died). Keep one explicit ordered list and write the reason for each position next to it.
5. **Deferred structural changes.** Adding or removing components during a query can invalidate iteration or skip entities. Queue structural changes (spawn, despawn, add or remove component) and apply them at a fixed point in the frame.
6. **Mixing ECS and Roblox objects.** Humanoids, tools and UI already have their own object models and events. Wrapping them in components often adds a sync layer that can drift. Use ECS for your simulation (enemies, projectiles, buffs) and leave engine objects as engine objects with a thin link (an entity id attribute).
7. **Team skills matter more than the pattern.** A team used to OOP can be slower in an ECS for months. For a small team on a deadline, a well-organised OOP or module-per-system design may ship faster; choose ECS when entity counts or system interactions genuinely need it.
8. **Debugging needs tools.** Without an inspector, an entity is just a number. Build a debug view early (a list of entities with components, filterable) or use the one your library provides.

The senior trade-off: ECS makes "do X to everything with Y" trivial and makes "what is this one thing" harder. It pays off with hundreds of similar entities and many cross-cutting behaviours; it is overhead for a game with ten unique objects.

## Common mistakes (advanced)

1. **One Model per entity regardless of distance.** Symptom: high instance count and slow joins. Fix: data-only entities far from players, instances near them.
2. **Systems that yield.** Symptom: a system pauses mid-frame and leaves state half-updated. Fix: systems never yield; spawn async work and write results back through a queue.
3. **Components holding Instances without cleanup.** Symptom: memory growth and errors on destroyed parts. Fix: a cleanup system that runs on despawn and on instance removal.
4. **Storing behaviour in components.** Symptom: components become classes again. Fix: components are plain data; functions live in systems.
5. **Replicating component changes per change instead of per tick.** Symptom: many tiny remote calls. Fix: batch per tick per player.
6. **No ids that survive the network.** Symptom: client and server cannot agree which entity a message is about. Fix: server-assigned ids sent with every replicated entity.

## Related decisions

- [[Frameworks - Knit Matter and Others]]: ECS libraries compared with other frameworks.
- [[Interest Management and Per-Player Replication]]: sending entity state only where needed.
- [[Tables Metatables and OOP]]: the object-oriented alternative.
- [[Luau Performance Patterns with Benchmarks]]: measuring whether ECS helped.
- [[Case Study - Cutting a Million Instances]]: why instances, not entities, are the limit.
- [[Tower Defense Waves and Placement End to End]]: a genre with many similar entities.
- [[Status Effects Buffs and Stacking Rules]]: buffs as components.
- [[Parallel Luau and Actors]]: when systems could run in parallel.

## Connected notes
<!-- auto-links:start -->
[[Official Docs - Scripting and Luau]] · Metatables and OOP - When and When Not · 2D Multiplayer - Server Authority and Replicating GUI Worlds · Advanced Luau Start Here · Deterministic Simulation · Genre Playbook - Tower Defense
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Snapshot Interpolation for Custom Replication]] · [[Client-Server Model]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Project Structure and Bootstrapping]] · [[Instance Streaming]] · [[Network Ownership]] · [[Client Prediction and Reconciliation for Combat]] · [[Remote Abuse Patterns and Rate Limiting in Practice]]
<!-- related:end -->
