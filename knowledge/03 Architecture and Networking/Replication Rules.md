---
tags: [architecture, networking, replication, attributes, fundamentals]
---
# Replication Rules

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Client sets an attribute expecting the server to read it -> Remote request; server sets it
> - Avoid: "Send current state on join" code duplicated per system -> Use attributes; late joiners get them automatically
> - Avoid: Per-frame attribute writes -> Write on change, quantise, or use an unreliable remote
> - Every client-to-server path is one of the exceptions above, and each has validation.
> - Each piece of shared state has exactly one channel.
> - Late joiners see correct state with no extra code (attributes, not one-off remotes, for persistent state).
>
> Read more (17 KB note): ## Attributes as a replication channel · ## Pattern: attribute-driven client presentation · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Replication is the engine process that keeps every client's copy of the DataModel close to the server's. You do not call it; it happens whenever the server creates, destroys, reparents or changes an instance in a replicated container. Understanding exactly what replicates, in which direction, and in what order lets you move most client-server communication out of hand-written remotes and into plain property and attribute writes, which are cheaper, simpler and automatically correct for late joiners.

This note covers the direction rules, the exceptions that flow from client to server, ordering guarantees (and the lack of them), attributes as a replication channel, the "attribute-driven presentation" pattern used in production, and how to diagnose replication bugs. For the containers that never replicate, see [[Client-Server Model]]. For streaming (which changes *when* Workspace content reaches a client), see [[Instance Streaming]].

## The direction rule

Roblox's model is **server-authoritative** (Roblox docs, "Access control and confidentiality"):

1. For an instance to exist on all machines, the **server** must create it.
2. Most property changes must be made **on the server** to be seen by everyone.
3. Generally an instance either replicates to all connected clients or to none. Exceptions include streaming and per-player containers (`PlayerGui`, `Backpack`).

So by default, **client changes stay on the client.** A LocalScript that sets `part.Color`, destroys a door, creates a `Folder`, or sets an attribute changes only its own copy. The server never hears about it, and other players never see it. This used to be optional ("FilteringEnabled"); it is now always on.

That default is a feature: it is what lets each client freely build local-only UI, effects, preview models and predicted visuals without cost or risk.

## The client-to-server exceptions

A small set of things do travel up from a client. Each is a trust boundary and an attack surface.

| Exception | What travels | Trust it? |
|---|---|---|
| RemoteEvent / RemoteFunction / UnreliableRemoteEvent | Whatever arguments the client chooses | Never. Validate every argument ([[Server Authority and Validation]]) |
| Physics of parts the client owns | Position, rotation, velocity of its character and of unanchored assemblies it owns | No. Bound and validate; see [[Network Ownership]] |
| `Touched` on owned parts | Touch events the client reports | No. A client can fire them at any distance (Roblox docs) |
| `ProximityPrompt.Triggered`, `ClickDetector`, `DragDetector` events | Interaction events | No. ClickDetector has no server checks at all; only `Triggered` has a server-side distance check (Roblox docs) |
| Animator tracks on the player's own character | Which clip plays, weight, speed | Cosmetically yes; for gameplay timing no. See [[Replication and Ownership]] |
| Humanoid movement and state of the owned character | Walking, jumping, state changes, as a consequence of owned physics | No. WalkSpeed can be changed locally without any event the server sees |

Everything else a client does is local. If you see "the server noticed my client-side change", it went through one of the rows above.

## What the server replicates

| Change on the server | Replicates? | Notes |
|---|---|---|
| `Instance.new` parented into a replicated container | Yes | Including all descendants when it is parented |
| Property writes on replicated instances | Yes, for replicable properties | A few properties are not replicated (some are runtime-only or local); check the API reference tags |
| `SetAttribute` | Yes | Same rules as properties |
| `CollectionService:AddTag` | Yes | Tags replicate with the instance |
| `Destroy()` / reparent to nil | Yes, the instance disappears on clients | Clients holding references keep a dead object |
| Server writes inside `PlayerGui` / `Backpack` | Only to that player | Useful for per-player UI or private tools |
| Anything in ServerStorage / ServerScriptService | No | Moving it into ReplicatedStorage makes it replicate at that moment |
| Values computed in Luau tables | No | Tables are memory, not instances. Use attributes, Values or remotes |

### Replication is batched, not instant

The server collects changes and sends them to each client in batches. Two writes in the same frame usually arrive together; a write followed by an immediate revert (set `Transparency = 1` then `0` in one frame) may never be observed by clients at all. If you need clients to see an event rather than a final state, send an event (a remote) or encode a unique value (see "unique trigger values" below).

## Ordering: what is and is not guaranteed

The docs are explicit (Roblox docs, "Attributes", "Replication order"):

- The engine **does not guarantee** the order in which objects and changes replicate from server to client.
- If the server changes a property and then calls `RemoteEvent:FireAllClients()`, the property change **might arrive before or after** `OnClientEvent` fires.
- Changes **of the same type**, such as two attribute changes, **generally do** arrive in order.
- RemoteEvents among themselves are reliable and ordered per direction, even across different RemoteEvent instances (Roblox docs, "Remote events and callbacks"). RemoteFunctions are not ordered relative to RemoteEvents.

Practical rules that follow:

1. **Never assume a property has replicated when a remote arrives.** If a remote says "your new sword is ready" and the client immediately indexes `Backpack.NewSword`, it can be nil. Either send everything the client needs in the remote's arguments, or have the client react to the property itself (`ChildAdded`, `GetAttributeChangedSignal`).
2. **Pick one channel per piece of state.** If a value travels by attribute, read it from the attribute. If it travels by remote, carry the full value in the remote. Mixing them creates races.
3. **Use `WaitForChild` for replicated children**, always with a timeout on anything that might never come (streamed content, optional objects).

```lua
--!strict
-- A WaitForChild that does not hang forever and says why it failed.
local function waitChild(parent: Instance, name: string, timeout: number): Instance?
	local child = parent:FindFirstChild(name) or parent:WaitForChild(name, timeout)
	if not child then
		warn(("waitChild: %s.%s missing after %.1fs"):format(parent:GetFullName(), name, timeout))
	end
	return child
end

return waitChild
```

## Join order on the client

Some of the client start-up is predictable (Roblox docs, "Attributes", "Replication order"):

1. The client loads `ReplicatedFirst` (loading screen, assets, scripts).
2. LocalScripts in `ReplicatedFirst` run and can read `ReplicatedFirst` without `WaitForChild`.
3. The rest of the game loads; then LocalScripts in `StarterPlayerScripts`, `StarterGui` copies and the character's scripts run.

`game:IsLoaded()` and `game.Loaded` tell you when the initial snapshot has arrived. With streaming on, "loaded" does not mean the Workspace is complete; it never is. Code in ReplicatedFirst is the right place for a loading screen and a bootstrap that waits for the specific things it needs. See [[Project Structure and Bootstrapping]] and [[Case Study - Fast Join and Deferred Loading]].

## Attributes as a replication channel

Attributes are typed key-value pairs on any instance. They replicate like properties, fire `GetAttributeChangedSignal`, are visible in the Properties panel, and survive streaming out and back in (they belong to the instance). For server-to-client state they are usually the best channel available.

Limits (Roblox docs, `Instance:SetAttribute`):

- Names: alphanumeric plus `.`, `-`, `/`, `_`; no spaces or symbols; at most 100 characters; may not start with `RBX`.
- Values: supported types only (string, boolean, number, UDim, UDim2, BrickColor, Color3, Vector2, Vector3, CFrame, NumberSequence, ColorSequence, NumberRange, Rect, Font, EnumItem); unsupported types error. Setting `nil` removes the attribute.
- Under the new server authority model, an attribute on a **predicted** instance only replicates if it is among the first 64 attributes, its name has at most 50 characters, and string values have at most 50 characters (Roblox docs, "Server authority model"; a beta feature as of October 2026). Classic games are not bound by these three limits, but they are a good budget to design toward anyway.

### When to use what

| Need | Channel | Why |
|---|---|---|
| Persistent state that late joiners must see (`State = "Stunned"`, `Level = 12`) | Attribute on the relevant instance | Late joiners get it for free; no "send current state on join" code |
| A one-off event several clients must react to ("boss roared", "chest opened") | RemoteEvent, or a unique attribute value | A plain attribute will not fire twice for the same value |
| A stream of continuously changing values (aim direction 20 times a second) | UnreliableRemoteEvent | Old values are worthless; dropping is fine; see [[RemoteEvents RemoteFunctions and Unreliable Remotes]] |
| Private per-player state (inventory, quest progress) | Attribute on the `Player` or a remote to that player only | Attributes on `Player` replicate to everyone; put private data in a remote or in `PlayerGui` |
| Large structured data (a whole inventory) | A remote with the table, or one JSON attribute updated rarely | Many small attributes cost more than one batched message |

A subtle privacy point: attributes on the `Player` object are visible to every client, because `Players` replicates. One production game mirrored UI state through player attributes (`QuestsJson`, `PotionsJson`, a luck total). That is fine for data that is not secret, but do not mirror anything a player should not see about another player.

## Pattern: attribute-driven client presentation

The most useful replication pattern in practice: **the server writes small facts, and every client derives the full presentation.** It scales because the server sends a few bytes per state change instead of animation, VFX and sound data, and it is automatically correct for late joiners.

One production game used it for:

| Object | Attributes the server wrote | What every client derived |
|---|---|---|
| Enemies | `Anim`, `AnimT` (server time), `AnimSpeed`, `AnimLoop`, `Hurt`, `Phase` | The clip to play, joined part-way in by `(GetServerTimeNow() - AnimT) * AnimSpeed`; hit reactions; boss phase visuals |
| Player characters | `FlourishName`, `FlourishT0` | Equip flourish animation and blade spin, computed locally from shared data |
| Gates and shrines | `Spin = "<userId>:<index>:<serial>"` | A 4.4 s eased spin run by each client |
| Hidden or dropped parts | `Detach_<key>` | Hide or drop a detachable piece |

The server never loaded an enemy animation clip. Damage timing came from data (mark times in the enemy definition), not from the animation. See [[Enemy Animation State Protocol]] and [[Replication and Ownership]].

### Unique trigger values

An attribute set to the value it already has does not fire a change. To make a repeatable trigger, write a value that is unique per trigger:

```lua
--!strict
-- Server: fire a "spin" on a gate every time a player activates it.
local serial = 0

local function triggerSpin(gate: Instance, player: Player, index: number)
	serial += 1
	-- Unique every time, so GetAttributeChangedSignal fires even for repeats.
	gate:SetAttribute("Spin", ("%d:%d:%d"):format(player.UserId, index, serial))
	gate:SetAttribute("SpinT", workspace:GetServerTimeNow())
end
```

```lua
--!strict
-- Client: react to the trigger, skipping it if we joined long after it ended.
local Workspace = game:GetService("Workspace")
local SPIN_DURATION = 4.4

local function watchGate(gate: Instance)
	gate:GetAttributeChangedSignal("Spin"):Connect(function()
		local t0 = gate:GetAttribute("SpinT") :: number?
		if not t0 then return end
		local elapsed = Workspace:GetServerTimeNow() - t0
		if elapsed >= SPIN_DURATION then return end -- stale: already finished
		-- Start the local spin animation at `elapsed` seconds in.
	end)
end
```

Note the race: `Spin` and `SpinT` are two attribute changes. Same-type changes generally arrive in order, which is why `SpinT` is written in the same frame; to be fully robust, encode the time in the same string or listen to both.

### Cost of attribute churn

Attributes are cheap, not free. Each change is replicated to every client that has the instance. Writing a `Health` attribute on 300 enemies every frame is a bandwidth problem. Rules of thumb:

- Write on **change**, not on a timer.
- Quantise continuous values before writing (round health to integers, positions to a tenth of a stud) so tiny changes do not trigger writes.
- Prefer **one event attribute** that encodes a whole transition (`Anim = "Slam"` plus a start time) over several attributes that each change.
- With streaming, clients that do not have the instance streamed in do not receive its updates, which is a big saving for big worlds.

See [[Network Performance]] for measuring the real cost.

## Destroy, nil parents and dead references

- When the server destroys an instance, clients remove it. A client script holding a reference keeps a Luau object whose `Parent` is nil; connections on it are disconnected.
- With streaming, an instance that **streams out** is parented to nil on the client but **not destroyed**; if it streams back in, the same object returns and existing Luau state reconnects (Roblox docs, "Instance streaming"). Local-only property changes on it may be lost.
- An `Instance` passed through a remote that the receiver cannot see arrives as `nil` (for example a ServerStorage object sent to a client, or a client-created part sent to the server) (Roblox docs, "Remote events and callbacks").

So client code must treat every Workspace reference as possibly gone: check `instance.Parent` or use `Destroying` and `AncestryChanged`, and prefer CollectionService tag signals, which fire both added and removed as content streams.

## Things that look like replication bugs but are not

| Symptom | Real cause |
|---|---|
| Animation works in Studio, nobody sees it live, not even the player | Studio-only animation id or missing asset permission ([[Case Study - Abilities That Only Worked in Studio]]) |
| Other players do not see my effect | It was created on my client; relay through the server ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]) |
| Client sees `nil` for a part that exists on the server | Streaming: it is not streamed in yet, or it streamed out |
| Value correct on the server, stale on one client | That client's copy was changed locally (local writes do not get overwritten until the server writes again) |
| A remote's handler indexes a child that "should exist" | Replication order: the remote beat the instance |
| Change made and reverted in one frame never shows | Batching: send an event instead |
| A client-set attribute "works" in Play Solo | Play Solo still separates client and server; check that you are not reading on the same side you wrote |

## Diagnosing

1. In Studio, use the **Client/Server toggle** during a playtest to look at both DataModels. If the instance or value differs, you have found the side.
2. Print `RunService:IsServer()` in the code path you suspect; many bugs are a module running on the side you did not expect.
3. Test with **multiple clients** ([[Testing Modes - Play Run and Multi-Client]]): one client cannot reveal "others do not see it".
4. Add network latency in Studio's network settings to surface ordering races.
5. Watch the Network section of the Developer Console for receive rates when you suspect churn ([[Developer Console and Stats]]).

## Common mistakes

| Mistake | Fix |
|---|---|
| Client sets an attribute expecting the server to read it | Remote request; server sets it |
| "Send current state on join" code duplicated per system | Use attributes; late joiners get them automatically |
| Per-frame attribute writes | Write on change, quantise, or use an unreliable remote |
| Remote handler assumes children have replicated | Pass data in the remote or react to `ChildAdded` |
| Repeated identical attribute values used as triggers | Unique values or a remote |
| Private data in Player attributes | Remote to the owner, or the owner's `PlayerGui` |

## Checklist

- [ ] Every client-to-server path is one of the exceptions above, and each has validation.
- [ ] Each piece of shared state has exactly one channel.
- [ ] Late joiners see correct state with no extra code (attributes, not one-off remotes, for persistent state).
- [ ] No per-frame property or attribute writes on many instances.
- [ ] Client code tolerates instances arriving late, leaving, and returning.

## See also
[[Client-Server Model]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Instance Streaming]] · [[Network Ownership]] · [[Instances Attributes and Tags]] · [[CollectionService Patterns]] · [[Replication and Ownership]] · [[Enemy Animation State Protocol]] · [[Network Performance]]

## Connected notes
<!-- auto-links:start -->
[[Replication Boundary]] · [[Debugging Client-Server Desync]] · [[Script Types and Run Context]] · [[Interest Management and Per-Player Replication]] · [[How Exploits Work - The Client Boundary]] · [[Skill - Roblox Secure Remotes]]
<!-- auto-links:end -->
