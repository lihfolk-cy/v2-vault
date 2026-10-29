---
tags: [luau, instances, attributes, tags, datamodel, replication, type/guide, area/scripting, level/intermediate, api/CollectionService, area/networking, api/RemoteEvent]
---
# Instances Attributes and Tags

<!-- tldr:start -->
> [!tldr] TL;DR
> - A system silently stops working after content is added: Name collision found the wrong child -> Separate folders; `IsA` checks; reserved-name list
> - `Size is not a valid member` style confusion: Child named like a property -> `FindFirstChild`
> - "Infinite yield possible" on client: Wrong name, never created, or streamed out -> Fix the path; timeout; streaming-aware design
> - Configure, then parent.
> - `Destroy` objects you are done with; pools use `Parent = nil` intentionally.
> - Lookups that expect a class check `IsA`.
>
> Cost: TL;DR ~170 tok · whole note ~4.1k tok. Read more: ## 2. Finding instances · ## 3. Attributes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Everything in a Roblox place is an `Instance` in one tree, the DataModel (`game`). Scripts create, find, clone, configure and destroy instances, and they attach their own data with **attributes** (typed key-value pairs) and **tags** (string labels). This note covers the instance lifecycle and lookup methods, the traps in naming and lookup, attributes (types, limits, replication, change signals, when they cause lag), tags, and how to choose between attributes, Value objects, tags and plain Luau tables.

---

## 1. Creating, parenting, cloning, destroying

```lua
--!strict
local part = Instance.new("Part")
part.Name = "Crate"
part.Size = Vector3.new(4, 4, 4)
part.Anchored = true
part:SetAttribute("Loot", "Common")
part.Parent = workspace           -- set Parent LAST
```

**Set `Parent` last.** Once an instance is in the replicated world, each property change is a separate change that may replicate and fire listeners. Configuring before parenting means one replication of the finished object and no half-built states visible to other scripts. Do not use the second argument of `Instance.new(class, parent)` for the same reason.

```lua
local clone = template:Clone()    -- deep copy of the instance and descendants; Archivable must be true
clone:PivotTo(spawnCFrame)        -- move models with PivotTo, not by setting each part
clone.Parent = workspace.Enemies
```

`Clone` skips instances whose `Archivable` is `false` (and returns `nil` for the root in that case). Attributes and tags are copied.

**`Destroy` vs `Parent = nil`:**

| | `Destroy()` | `Parent = nil` |
|---|---|---|
| Removes from tree | Yes, with descendants | Yes |
| Can be re-parented | No: `Parent` is locked | Yes |
| Disconnects connections on it and descendants | Yes | No |
| Fires `Destroying` | Yes | No |
| Memory freed | When no Luau references remain | Only if nothing references it |

Use `Destroy` for anything you are done with. `Parent = nil` is for objects you will reuse (pools). `Debris:AddItem(obj, t)` destroys after a delay; `task.delay(t, obj.Destroy, obj)` does the same and is easier to cancel.

A destroyed instance still exists as a Luau object while referenced. Its properties are readable, `Parent` is `nil`, and writing `Parent` errors. A quick validity check is `instance.Parent ~= nil` (for instances that should be in the tree) or `instance:IsDescendantOf(game)`.

---

## 2. Finding instances

| Method | Returns | Use |
|---|---|---|
| `parent.Child` | Child or error | Only when the child must exist **and** its name cannot clash with a property |
| `FindFirstChild(name, recursive?)` | `Instance?` | Optional children; recursive search is O(descendants) |
| `WaitForChild(name, timeout?)` | `Instance` (or `Instance?` with timeout) | Client access to replicated objects; streaming |
| `FindFirstChildOfClass(class)` / `FindFirstChildWhichIsA(class)` | `Instance?` | Exact class / `IsA` match |
| `FindFirstAncestor(name)`, `FindFirstAncestorOfClass`, `FindFirstAncestorWhichIsA` | `Instance?` | From a hit part to its model |
| `GetChildren()` / `GetDescendants()` | `{ Instance }` | Allocates a new array each call |
| `QueryDescendants(selector)` | `{ Instance }` | CSS-like selectors (`Part.Tag`, `#Name`, `[$Attr]`, `>`), newer API (Docs, 2026) |
| `IsA(class)` | `boolean` | Type test that respects inheritance; narrows types |

### Name traps

- **Dot access collides with properties and methods.** A child called `Name`, `Parent`, `Size` or `Destroy` is shadowed: `model.Size` returns the property, not the child. Use `FindFirstChild`.
- **Names are not unique.** `FindFirstChild("Origin")` returns the first child with that name, of any class. In the reference project an animation clip named `Origin` was added to a weapon kit folder that also contained a `RemoteEvent` named `Origin`; the server code found the clip instead, and all damage for that kit silently stopped (Measured). Rules that came out of it: keep different kinds of children in separate folders, never reuse a reserved name, and check `IsA` on every lookup that expects a class:

```lua
local remote = kit:FindFirstChild("Origin")
if not (remote and remote:IsA("RemoteEvent")) then
	warn(`{kit:GetFullName()}: Origin is missing or not a RemoteEvent`)
	return
end
```

- Instance names are limited to 100 characters (Docs).

### WaitForChild

- On the client, replicated children may not exist yet; use `WaitForChild`. On the server, objects you placed in Studio exist when scripts start; `WaitForChild` is only needed for things created at runtime.
- Without a timeout it yields forever and, after 5 seconds, prints an "Infinite yield possible" warning (Rule of thumb: the warning text and delay are long-standing engine behaviour). With a timeout it returns `nil` on expiry; handle it.
- With **Instance Streaming** on, workspace objects can be absent or removed at any time on the client; `WaitForChild` on a far-away model may never return. Design client code to handle streaming in and out ([[Instance Streaming]]).
- Chains like `a:WaitForChild("B"):WaitForChild("C")` are fine; each step yields only as long as needed.

---

## 3. Attributes

Attributes are custom typed properties on any instance (Docs). They are visible and editable in the Properties window, saved with the place, copied by `Clone`, and **replicated** from server to client like properties.

```lua
crate:SetAttribute("Loot", "Rare")         -- creates or updates
print(crate:GetAttribute("Loot"))          --> Rare
print(crate:GetAttribute("Missing"))       --> nil
crate:SetAttribute("Loot", nil)            -- deletes
for name, value in crate:GetAttributes() do print(name, value) end

crate:GetAttributeChangedSignal("Loot"):Connect(function()
	print("loot is now", crate:GetAttribute("Loot"))
end)
crate.AttributeChanged:Connect(function(name: string) end)
```

**Supported types** (Docs, Studio properties page): `string`, `boolean`, `number`, `UDim`, `UDim2`, `BrickColor`, `Color3`, `Vector2`, `Vector3`, `CFrame`, `NumberSequence`, `ColorSequence`, `NumberRange`, `Rect`, `Font`. Setting any other type (a table, an Instance, a function) throws. (EnumItem attribute support has been reported but is unverified here.)

**Naming rules** (Docs): alphanumeric plus `.`, `-`, `/`, `_`; no spaces or other symbols; 100 characters or less; must not start with `RBX`.

**Typed reads.** `GetAttribute` returns `any`-ish values in practice; a designer can type a string where you expect a number. Read defensively:

```lua
local function numberAttr(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

local damage = numberAttr(tool, "Damage", 10)
```

### Replication and authority

- Server-set attributes replicate to clients that can see the instance. Client-set attributes stay local and are **overwritten** when the server changes that attribute.
- Changes of the same type (two attribute changes) generally arrive in order; changes of different types (a property change and a remote event) have no ordering guarantee (Docs). Do not fire a remote and assume the attribute it depends on has arrived; listen to the attribute.
- Attributes on a `Player` or `Character` are visible to every client. Never put secrets there, and remember exploiters read them freely.

### When attributes cause lag

Every change to a replicated attribute is sent to every client that has the instance. In the reference project, several large JSON strings (inventory, bestiary, quests, potions, fragments) were stored as attributes on the `Player` object and rewritten every few seconds. Because `Player` replicates to everyone, each client received every other player's full inventory JSON on every write; players reported "immense lag" (Measured). The fix: keep that state **owner-only** by storing the attributes on a container inside the player's `PlayerGui` (which only replicates to that player), mirror it locally on the client, and send other players' data only on request; also slow the periodic resync from 5 s for everyone to 30 s and only while relevant.

Rules of thumb:
- Attributes are for small, frequently read values that UI or other systems observe: level, team, state flags, cooldown end times.
- Do not stream large blobs through attributes. Base64 data of a few hundred KB is acceptable for **static** data (it also slows the Properties window, Measured), not for state that changes.
- Write only when the value actually changes; `SetAttribute` with the same value is cheap but still work, and loops that rewrite many attributes every frame add up.

---

## 4. Tags

Tags are strings attached to instances, managed with `Instance:AddTag`, `RemoveTag`, `HasTag`, `GetTags` (or the equivalent `CollectionService` methods). They replicate and save with the place. CollectionService indexes them so you can find all instances with a tag cheaply and react when tags are added or removed (Docs).

```lua
part:AddTag("Lava")
print(part:HasTag("Lava"))   --> true
print(part:GetTags())        --> { "Lava" }
```

Replication nuance (Docs): **all tags on an instance replicate together**. If a client adds a local tag and the server later adds or removes any tag on the same instance, the client's local tags are overwritten. Under streaming, an instance that streams out and back in is re-synchronized from the server, dropping client-side changes.

Patterns built on tags are in [[CollectionService Patterns]].

---

## 5. Choosing where data lives

| Option | Replicates | Types | Observable | Best for |
|---|---|---|---|---|
| Property | Yes | Fixed per class | Changed signals | Engine behaviour |
| Attribute | Yes | 15 datatypes | `GetAttributeChangedSignal` | Small per-instance config and state |
| Tag | Yes | Presence only | CollectionService signals | "This instance has behaviour X" |
| Value object (`IntValue`, `ObjectValue`...) | Yes | One per class | `Changed` | Instance references (`ObjectValue`), legacy leaderstats |
| Luau table in a module | No | Anything | Your own signals | Server-only state, complex data |
| Remote event payload | On send | Plain data | Handler | Events and big state diffs |

Notes:
- Attributes cannot hold Instance references. Use an `ObjectValue`, a tag, or store a path/ID.
- `leaderstats` (a Folder named `leaderstats` with `IntValue`/`NumberValue`/`StringValue` children under the Player) is still how the default player list shows stats.
- Authoritative state (currency, inventory) lives in server tables and the save profile; attributes are a **view** of it for clients ([[Server Authority and Validation]]).

---

## 6. Properties worth knowing on every instance

- `Name`, `Parent`, `ClassName`, `Archivable`.
- `GetFullName()` for logs: `Workspace.Map.Crate`.
- `GetDebugId()` is not stable across sessions; do not save it.
- `Destroying` event: fires before destruction (under Deferred events, the handler runs after; see [[Events Signals and Connections]]).
- `AncestryChanged`, `ChildAdded`, `ChildRemoved`, `DescendantAdded`, `DescendantRemoving`.
- `GetPropertyChangedSignal(name)` for one property.

Instance counts matter: memory, replication, and Studio responsiveness all scale with them. The reference project deleted about 191,000 unused instances in one cleanup pass ([[Case Study - Instance Cleanup and Place Size]], [[Case Study - Cutting a Million Instances]]).

---

## 7. Patterns

### Object pools

Creating and destroying many short-lived instances (projectiles, hit markers, damage numbers) costs CPU and GC. A pool parks unused instances instead of destroying them:

```lua
--!strict
local Pool = {}
Pool.__index = Pool

function Pool.new(template: Instance, prewarm: number)
	local self = setmetatable({ template = template, free = {} :: { Instance } }, Pool)
	for _ = 1, prewarm do
		table.insert(self.free, template:Clone())
	end
	return self
end

function Pool.get(self: any, parent: Instance): Instance
	local inst = table.remove(self.free) or self.template:Clone()
	inst.Parent = parent
	return inst
end

function Pool.release(self: any, inst: Instance)
	inst.Parent = nil                 -- intentionally NOT Destroy: we reuse it
	table.insert(self.free, inst)
end

return Pool
```

Pool rules: reset every property you change before reuse; disconnect per-use connections on release (they survive `Parent = nil`); cap the free list. For parts that must move every frame, parking them far away (anchored, non-collidable) instead of unparenting avoids re-parenting costs; measure which is cheaper for your case ([[Rendering Performance]]).

### Configuration on instances

Designer-facing tuning (door angle, spawn rate, enemy level) fits attributes on the placed instance: visible in Properties, editable live in Studio during a play test, copied with the model. Code reads it with defaults and validation (see `numberAttr` above). Game-wide tuning belongs in a config module or [[Global State and Live Config]].

### Marking state for other systems

Attributes like `Stunned`, `InCombat` or `Downed` on a character let independent systems (UI, animation, AI) react through change signals without depending on each other's modules. Keep one writer per attribute (usually the server system that owns that state) and document it. In the reference project, a later audit found an attribute read by ten scripts that nothing set any more after a refactor (Measured), a cheap bug to catch with a static scan of `GetAttribute`/`SetAttribute` names.

### Serializing instance state

To save a player-built structure, convert instances to plain data (class name, CFrame components, color, attributes) and back; never try to save instances themselves. Attribute values are already plain datatypes; CFrames need converting to numbers (`cf:GetComponents()`) for JSON ([[Data Schema Design and Migrations]]).

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| A system silently stops working after content is added | Name collision found the wrong child | Separate folders; `IsA` checks; reserved-name list |
| `Size is not a valid member` style confusion | Child named like a property | `FindFirstChild` |
| "Infinite yield possible" on client | Wrong name, never created, or streamed out | Fix the path; timeout; streaming-aware design |
| Lag that scales with player count | Large attributes on Player rewritten often | Owner-only containers, deltas, lower frequency |
| Client attribute changes revert | Server changed the same attribute/tags | Client-only state in Luau tables |
| Memory not freed after removal | `Parent = nil` with live connections | `Destroy` |
| `SetAttribute` throws | Unsupported type (table, Instance) or bad name | Serialize, or use another channel |

## Checklist

- [ ] Configure, then parent.
- [ ] `Destroy` objects you are done with; pools use `Parent = nil` intentionally.
- [ ] Lookups that expect a class check `IsA`.
- [ ] Client code uses `WaitForChild` (with timeouts where streaming applies).
- [ ] Attributes small and changed only on real changes; no per-player blobs on `Player`.
- [ ] Authoritative data in server tables; attributes only mirror it.

## See also

[[CollectionService Patterns]] · [[Events Signals and Connections]] · [[Replication Rules]] · [[Instance Streaming]] · [[Explorer Properties and Selection]] · [[Memory Budgets and Leaks]] · [[Network Performance]] · [[Global State and Live Config]]

## Connected notes
<!-- auto-links:start -->
[[Debugging Race Conditions and Yield Order]] · Debugging Client-Server Desync · [[Tables Metatables and OOP]] · Streaming Radius · Replication Boundary · RemoteEvents RemoteFunctions and Unreliable Remotes
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Script Types and Run Context]] · [[Metatables and OOP - When and When Not]] · [[Functions Closures and Upvalues]] · [[Module Scripts and Requiring]] · [[Luau Performance and Native Codegen]] · [[Luau Type System and Strict Mode]] · [[Task Library Coroutines and Yielding]] · [[Luau Performance Patterns with Benchmarks]]
<!-- related:end -->
