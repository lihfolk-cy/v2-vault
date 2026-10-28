---
tags: [luau, collectionservice, tags, architecture, patterns]
---
# CollectionService Patterns

<!-- tldr:start -->
> [!tldr] TL;DR
> - Pre-placed objects do nothing: Only connected to the added signal -> Iterate `GetTagged` too
> - Behaviour runs twice on one object: Non-idempotent setup -> Track active instances
> - Memory grows as player explores: Streaming cycles leak per-instance state -> Complete cleanup on removed
> - Each tag has one module that binds it, on the side that owns the behaviour.
> - Removed-signal connected, `GetTagged` iterated, setup idempotent.
> - Cleanup releases connections, effects and table entries.
>
> Read more (20 KB note): ## 3. A binder with per-instance cleanup · ## 8. Worked example: doors driven by tags and attributes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

`CollectionService` turns tags into behaviour. Instead of copying a script into every lava brick, door, coin or enemy, you tag the instances and one module handles all of them: present ones at startup, new ones as they appear, removed ones as they go. Roblox's own guidance recommends this: avoid attaching scripts directly to Workspace instances, tag them and work with them from a single ModuleScript (Docs: script types and locations). This note covers the tag API and its guarantees, the binder pattern with correct cleanup, streaming and replication interactions, the newer query-based `Collection` API, and when tags are the wrong tool.

---

## 1. The API (Docs)

| Member | Notes |
|---|---|
| `Instance:AddTag(tag)` / `CollectionService:AddTag(inst, tag)` | No-op if already tagged; fires the added signal |
| `Instance:RemoveTag(tag)` / `CollectionService:RemoveTag(inst, tag)` | Fires the removed signal |
| `Instance:HasTag(tag)`, `Instance:GetTags()` | |
| `CollectionService:GetTagged(tag)` | Array of tagged instances **in the DataModel**; no ordering guarantee; instances with `Parent = nil` are excluded |
| `CollectionService:GetInstanceAddedSignal(tag)` | Fires when the tag is added to an instance in the DataModel, **or** a tagged instance enters the DataModel. Same signal object for the same tag |
| `CollectionService:GetInstanceRemovedSignal(tag)` | Fires when the tag is removed, or a tagged instance leaves the DataModel (including destruction and streaming out) |
| `CollectionService:GetAllTags()` | Tags with at least one tagged instance in the DataModel |
| `CollectionService:CreateCollection(query, root?)` | Newer query-based live collection (section 6) |

Deprecated: `GetCollection` and the old `ItemAdded`/`ItemRemoved` events.

Tags can be edited in Studio's Tags section of the Properties window (and with the Tag Editor). They save with the place and replicate server to client.

---

## 2. The core pattern: existing, then future

`GetInstanceAddedSignal` does not fire for instances that were already tagged before you connected. Handle both:

```lua
--!strict
local CollectionService = game:GetService("CollectionService")

local TAG = "KillBrick"

local function onAdded(inst: Instance)
	if not inst:IsA("BasePart") then return end
	-- set up behaviour
end

local function onRemoved(inst: Instance)
	-- tear down behaviour
end

CollectionService:GetInstanceRemovedSignal(TAG):Connect(onRemoved)
CollectionService:GetInstanceAddedSignal(TAG):Connect(onAdded)
for _, inst in CollectionService:GetTagged(TAG) do
	task.spawn(onAdded, inst)   -- isolate errors and yields per instance
end
```

Connecting before iterating closes the gap where an instance is tagged between the two calls. The cost is that the same instance could theoretically be seen twice (tagged after `Connect`, then included in `GetTagged`), so `onAdded` must be **idempotent**: track which instances are set up.

---

## 3. A binder with per-instance cleanup

Most real behaviours create connections, effects or state per instance. They must be cleaned up when the instance loses the tag or leaves the DataModel, or they leak ([[Events Signals and Connections]]). A small binder handles the bookkeeping:

```lua
--!strict
local CollectionService = game:GetService("CollectionService")

export type Cleanup = () -> ()

-- setup(inst) returns a cleanup function (or nil). Binder guarantees
-- one setup per instance at a time and exactly one cleanup per setup.
local function bindTag(tag: string, setup: (Instance) -> Cleanup?): () -> ()
	local active: { [Instance]: Cleanup | false } = {}

	local function add(inst: Instance)
		if active[inst] ~= nil then return end      -- idempotent
		active[inst] = false                          -- reserve while setup runs
		local ok, result = pcall(setup, inst)
		if not ok then
			warn(`[{tag}] setup failed for {inst:GetFullName()}: {result}`)
			active[inst] = nil
			return
		end
		if active[inst] == nil then                   -- removed during a yielding setup
			if result then result() end
			return
		end
		active[inst] = result or false
	end

	local function remove(inst: Instance)
		local cleanup = active[inst]
		if cleanup == nil then return end
		active[inst] = nil
		if cleanup then
			local ok, err = pcall(cleanup)
			if not ok then warn(`[{tag}] cleanup failed: {err}`) end
		end
	end

	local addedConn = CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	local removedConn = CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
	for _, inst in CollectionService:GetTagged(tag) do
		task.spawn(add, inst)
	end

	return function()   -- unbind everything
		addedConn:Disconnect()
		removedConn:Disconnect()
		for inst in table.clone(active) do
			remove(inst)
		end
	end
end

return bindTag
```

Usage, a spinning coin on the client:

```lua
local RunService = game:GetService("RunService")
local bindTag = require(script.Parent.bindTag)

local coins: { [BasePart]: CFrame } = {}

bindTag("Coin", function(inst)
	if not inst:IsA("BasePart") then return nil end
	coins[inst] = inst.CFrame
	return function()
		coins[inst] = nil
	end
end)

-- One Heartbeat for all coins instead of one connection per coin
RunService.PreRender:Connect(function()
	local angle = os.clock() * 2
	for coin, base in coins do
		coin.CFrame = base * CFrame.Angles(0, angle, 0)
	end
end)
```

Note the split: per-instance setup stores data; a **single** per-frame loop processes all instances. That scales to thousands of tagged objects, where a connection per instance would not ([[Luau Performance and Native Codegen]]).

---

## 4. Server vs client binders

Tags replicate, so the same tag can drive behaviour on both sides:

| Side | Typical responsibilities |
|---|---|
| Server | Gameplay truth: damage on touch, pickups, door state, spawners |
| Client | Presentation: spinning, glowing, sounds, highlight on hover, prompts UI |

For a coin: the server binder handles `Touched` and awards currency (with validation); the client binder animates it and plays a sound when the server destroys it. Never let the client's binder grant anything.

### Streaming

With Instance Streaming enabled, the client only has nearby instances. Streaming in fires the added signal; streaming out fires the removed signal, as the instance leaves the client's DataModel. Your client binder therefore runs setup and cleanup many times per instance as the player moves. That is correct behaviour, but it means:
- Setup must be cheap and cleanup complete; leaked state per stream cycle grows quickly.
- Client-side state that must survive streaming (for example "already collected" flags) belongs in a table keyed by a stable ID attribute, not on the instance.
- Client-only tags or attributes are reset when the instance streams back in (Docs).

See [[Instance Streaming]] and [[Level of Detail and Model Streaming]].

### Client-side tags get overwritten

Docs: all tags on an instance replicate together. If the client tags an instance locally and the server then changes any tag on it, the client's tags are replaced. Keep client-only markers in Luau tables, or on client-created instances.

---

## 5. Designing tags

- **Name tags like components**: `Interactable`, `Damageable`, `Coin`, `SpawnPoint`, `LavaDamage`. One behaviour per tag; instances can carry several.
- **Configure with attributes** on the same instance: tag `Door`, attributes `Locked`, `KeyId`, `OpenAngle`. Designers edit both in Properties without touching scripts.
- **Use a tag on the model, not each part**, when the behaviour belongs to the whole object. Then `inst:IsA("Model")` and work with `PrimaryPart` or `GetPivot()`.
- **Prefix project tags** if you use third-party packages, to avoid collisions (`MyGame_Coin`).
- **Keep a registry module** of tag names (`Tags.Coin = "Coin"`) so a typo does not silently bind nothing. `GetTagged` with a misspelled tag returns an empty array without warning.

```lua
--!strict
local Tags = table.freeze({
	Coin = "Coin",
	KillBrick = "KillBrick",
	Door = "Door",
})
return Tags
```

---

## 6. Query-based collections (newer API)

The 2026 API reference documents `CollectionService:CreateCollection(query, root?)`, which returns a live `Collection` that tracks instances matching a CSS-like selector, the same grammar as `Instance:QueryDescendants` (Docs): `ClassName`, `#Name`, `.Tag`, `[Property = value]`, `[$Attribute]`, `[$Attribute = value]`, combinators `>` and `>>`, and `:has(...)`, `:not(...)`. The root defaults to `Workspace`.

Callbacks are assigned once as fields:

```lua
local CollectionService = game:GetService("CollectionService")

local killBricks = CollectionService:CreateCollection("Part.KillBrick")

function killBricks.OnAdded(brick: Part)        -- fires for existing matches when assigned, then new ones
	brick.Color = Color3.new(1, 0, 0)
end

function killBricks.OnTouched(brick: Part, other: BasePart)   -- wraps the Touched event of every member
	local humanoid = other.Parent and other.Parent:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.Health = 0 end
end

function killBricks.OnRemoved(brick: Part) end
```

Documented behaviour: the collection owns per-member connections and tears them down when an instance leaves; `OnHeartbeat`, `OnPreRender`, `OnPreSimulation`, `OnPostSimulation`, `OnPreAnimation` (and `OnSimulate`) aliases subscribe once and dispatch per instance with `deltaTime`; `OnPropertyChanged.X` and `OnAttributeChanged.X` wrap change signals; each callback can be assigned only once; lifecycle callbacks are queued (they may fire at a later resumption point); `Enabled = false` fires `OnRemoved` for all; `Destroy()` (or destroying the root) ends it; `ForEach` iterates a snapshot.

This removes most of the binder boilerplate above. As of October 2026 it is new: confirm it is enabled in your Studio and live servers before building on it, and keep the classic tag pattern for packages that must run in older places.

---

## 7. When tags are the wrong tool

- **State that changes often.** Tags are for "what kind of thing is this"; use attributes for "what state is it in". Adding and removing tags every frame churns signals and replication.
- **Data you need to query by value.** Tags are presence-only. "All doors with KeyId 3" is a tag plus an attribute filter (or a selector query).
- **Non-instance entities.** Thousands of bullets or particles should not be Instances at all; keep them in Luau arrays ([[Entity Component Systems]]).
- **Ordering.** `GetTagged` is unordered. Spawn points that need an order need an `Order` attribute and a sort.

---

## 8. Worked example: doors driven by tags and attributes

A complete server binder for doors that designers place and configure without code. Tag the door `Model` with `Door`; give it a `Hinge` part and attributes `OpenAngle` (number, degrees), `Locked` (boolean) and `AutoCloseSeconds` (number). A `ProximityPrompt` inside opens it.

```lua
--!strict
local TweenService = game:GetService("TweenService")
local bindTag = require(script.Parent.bindTag)
local Tags = require(game:GetService("ReplicatedStorage").Shared.Tags)

local function numberAttr(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

bindTag(Tags.Door, function(inst)
	if not inst:IsA("Model") then return nil end
	local hinge = inst:FindFirstChild("Hinge")
	local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not (hinge and hinge:IsA("BasePart") and prompt) then
		warn(`Door {inst:GetFullName()} is missing Hinge or ProximityPrompt`)
		return nil
	end

	local closedPivot = inst:GetPivot()
	local closedHinge = hinge.CFrame     -- capture once: the hinge moves with the door
	local isOpen = false
	local closeThread: thread? = nil
	local value = Instance.new("CFrameValue")      -- tween a value, then pivot the model
	value.Value = closedPivot

	local function setOpen(open: boolean)
		if open == isOpen then return end
		isOpen = open
		local angle = math.rad(numberAttr(inst, "OpenAngle", 90))
		local goal = if open
			then closedHinge * CFrame.Angles(0, angle, 0) * closedHinge:ToObjectSpace(closedPivot)
			else closedPivot
		TweenService:Create(value, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Value = goal }):Play()
	end

	local changed = value.Changed:Connect(function(cf: CFrame)
		inst:PivotTo(cf)
	end)

	local triggered = prompt.Triggered:Connect(function(_player: Player)
		if inst:GetAttribute("Locked") == true then return end
		setOpen(not isOpen)
		if closeThread then task.cancel(closeThread) closeThread = nil end
		local autoClose = numberAttr(inst, "AutoCloseSeconds", 0)
		if isOpen and autoClose > 0 then
			closeThread = task.delay(autoClose, function()
				closeThread = nil
				setOpen(false)
			end)
		end
	end)

	return function()
		triggered:Disconnect()
		changed:Disconnect()
		if closeThread then task.cancel(closeThread) end
		value:Destroy()
	end
end)
```

What this shows: validation with a clear warning instead of an error (one broken door does not stop the others), configuration read from attributes at use time (designers can change `OpenAngle` live), every connection, thread and helper instance released in cleanup, and no per-frame code. The hinge maths composes CFrames as described in [[Math Vectors and CFrames]]. Physics-based doors (`HingeConstraint`) are an alternative when players should be able to push them ([[Physics Assemblies and Constraints]]).

### Testing tag-driven systems

- In Studio, add and remove the tag on an instance while the game runs (Properties window) and watch setup and cleanup run. Then delete the instance. Then undo the delete. Each path must leave no warnings and no leaked connections.
- Duplicate a tagged model 500 times and check the frame time and memory: per-instance cost should be flat.
- On the client, fly away and back with streaming enabled to exercise stream-out and stream-in.

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Pre-placed objects do nothing | Only connected to the added signal | Iterate `GetTagged` too |
| Behaviour runs twice on one object | Non-idempotent setup | Track active instances |
| Memory grows as player explores | Streaming cycles leak per-instance state | Complete cleanup on removed |
| Nothing binds, no error | Misspelled tag | Tag registry module |
| Client tag disappears | Server changed tags on the same instance | Client state in tables |
| One connection per object, lag with many | Per-instance Heartbeat | One loop over a set |
| Tag on parts, logic needs the model | Wrong granularity | Tag the model |

## Checklist

- [ ] Each tag has one module that binds it, on the side that owns the behaviour.
- [ ] Removed-signal connected, `GetTagged` iterated, setup idempotent.
- [ ] Cleanup releases connections, effects and table entries.
- [ ] Per-frame work runs in one shared loop.
- [ ] Tag names come from a frozen registry; configuration from attributes.
- [ ] Streaming in and out tested on the client.

## See also

[[Instances Attributes and Tags]] · [[Events Signals and Connections]] · [[Module Scripts and Requiring]] · [[Project Structure and Bootstrapping]] · [[Instance Streaming]] · [[Entity Component Systems]] · [[Script Types and Run Context]]

## Nuances and edge cases

1. **Tags replicate, but only for instances the client has.** A tag added on the server reaches the client only when the instance replicates; with streaming, `GetTagged` on the client returns only what is currently streamed in. Treat the client's tagged set as "what is near me", not "everything in the game". Server-side counts and client-side counts disagree by design.
2. **Instance-removed signals fire on stream-out too.** On the client, an instance leaving the streaming radius fires the tag-removed signal just like a destroy. Per-instance state must be fully rebuilt on the next add, and anything long-lived (quest progress, ownership) must live on the server or in a module keyed by a stable id, not on the instance.
3. **Tag granularity determines cost.** Tagging 5,000 individual parts for a "lava" behaviour creates 5,000 bindings. Tagging the 40 lava models and handling touches per model costs far less. Rule of thumb: tag the thing that owns the behaviour, usually a model, not its parts.
4. **Tags are not a permission system.** A client can add tags locally; those tags do not replicate, but client-side systems will treat the instance as tagged. Never let a server check rely on anything a client could have tagged, and never trust a client claim like "I touched a tagged checkpoint" without a server check of position.
5. **Ordering between tags and attributes.** When a tagged instance replicates, its attributes come with it, but code that tags an instance and then sets attributes in a later frame on the server can let the client binder run before the attributes exist. Set attributes first, tag last, so the binder always sees complete data.
6. **Scale with many players.** With 1 player, a per-instance Heartbeat connection is harmless. With 50 clients each running 500 bindings, every client pays the cost independently, which is fine on PC and painful on low-end phones. One system loop over a set of active instances is cheaper than many per-instance connections.
7. **Edit-time tags versus runtime tags.** Tags placed in Studio are part of the place file and survive saves; tags added by scripts at runtime are gone on the next server. Mixing the two for the same tag name confuses designers ("I removed the tag but it came back"). Reserve some tags for authoring and others for runtime state, and name them so the difference is obvious.

The senior trade-off: tags make level designers productive (drop a model, tag it, behaviour appears) and make data flow implicit. Keep a tag registry module listing every tag, its owner system, which side binds it and which attributes it expects.

## Common mistakes (advanced)

1. **Binder runs twice after a stream-out and back.** Symptom: duplicate effects or doubled sounds after walking away and back. Fix: idempotent setup plus complete cleanup on removal.
2. **Setting attributes after tagging.** Symptom: binder reads `nil` attributes the first time, works on later loads. Fix: attributes first, then `AddTag`.
3. **Using `FindFirstChild` chains inside binders on the client.** Symptom: random failures on phones when children stream separately. Fix: atomic models for tagged objects, or wait with a timeout.
4. **Server binder per tagged part for touch damage.** Symptom: server time grows with map size. Fix: spatial queries in one loop, or tag fewer, larger zones.
5. **Tag names typed as strings across many scripts.** Symptom: a renamed tag silently disables a system. Fix: constants in one module.
6. **Assuming `GetTagged` order is stable.** Symptom: "first spawn point" changes between servers. Fix: sort by a name or attribute.

## Related decisions

- [[Instance Streaming]]: the reason client tag sets are partial.
- [[Instances Attributes and Tags]]: attributes as the data half of tag-driven design.
- [[Selection Editing and Bulk Tools]]: plugin tools for tagging many objects safely.
- [[Entity Component Systems]]: tags as a lightweight component system.
- [[Spawn Points Safe Zones and Respawn Flow]]: tag-driven spawns with stable ordering.
- [[Detecting Movement Exploits - Speed Fly Noclip Teleport]]: server checks that must not trust client tags.
- [[Level Design for Roblox]]: designer-facing workflow built on tags.
- [[VFX Performance Budgets and Culling]]: binding effects only to nearby tagged objects.

## Connected notes
<!-- auto-links:start -->
[[Debugging Race Conditions and Yield Order]] · [[Replication Rules]] · [[Hunting Memory Leaks Step by Step]] · [[Obby Checkpoints and Stage Saves End to End]] · [[Building a Signal Library]] · [[Explorer Properties and Selection]]
<!-- auto-links:end -->
