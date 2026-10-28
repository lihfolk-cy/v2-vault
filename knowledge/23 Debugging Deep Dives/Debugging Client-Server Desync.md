---
tags: [debugging, networking, replication, desync, attributes, remotes]
---
# Debugging Client-Server Desync

A desync is any bug where the client and the server disagree about the state of the game: the client shows 1,500 coins and the server has 1,200; a door is open for one player and closed for another; an enemy is dead on the server and still walking on a client. Desyncs are hard because each side, looked at alone, seems fine. This note gives a classification of desyncs, the replication facts that cause each kind, a debug tool that compares both sides directly, and fixes that remove whole families of the bug.

The rules of what replicates and when are in [[Replication Rules]] and [[Client-Server Model]]. Prediction for combat (where some desync is intended) is in [[Client Prediction and Reconciliation for Combat]]. Physics-specific desync (positions, ownership) is in [[Debugging Physics and Network Ownership]].

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. Four kinds of desync

Naming the kind narrows the cause immediately.

| Kind | Symptom | Typical cause |
|---|---|---|
| **Missing** | client has no copy at all (nil, or "not a valid member") | not replicated (server-only container), not streamed in, created on the client only |
| **Stale** | client has an old value that never updates | client wrote locally, so it no longer matches; or the server changed and reverted within one batch; or the UI cached a value and stopped listening |
| **Divergent** | both sides change the value independently | duplicated logic (client simulates and server simulates, with different inputs or timing) |
| **Out of order** | correct final state, wrong intermediate one; or an event handled before the data it refers to | remote arrives before an instance; unreliable remote reordered; deferred handlers |

Most desync bugs are **stale** (rule of thumb from reviewing many of them), and most stale bugs are one of two things: a client-side write to a replicated value, or a UI that read a value once.

---

## 2. Replication facts that cause desync

### 2.1 Client writes are local and sticky

When a LocalScript changes a property or attribute on a replicated instance, the change stays on that client only (Docs: changes on the client do not replicate, except for specific cases such as owned physics and some character properties). The server value has not changed, so **the server will not send it again** until it changes on the server. The client now shows its own value indefinitely.

Example: a client sets `player:SetAttribute("Coins", 0)` as a "reset display" while a menu is open. The server still has 1,500. No new value arrives until the next server change, so the UI shows 0 until the player earns a coin.

Rule: replicated state that the server owns is **read-only on the client**. Enforce it by convention and by a Studio check (section 5).

### 2.2 Batching hides quick changes

The server sends changes in batches (Docs describe replication as not instant; [[Replication Rules]] covers the details). A value set to 5 and back to 0 within one frame may never reach clients at all. If the client is supposed to react to "it happened", a property flip is the wrong channel: send an event, or use a counter (see 4.2).

### 2.3 Ordering between remotes and instances

A common out-of-order bug: the server creates an instance and fires a remote referring to it in the same frame. On the client, the handler runs, but the instance is not there yet, or the Instance argument arrives as nil (an Instance the client cannot see serialises as nil). [[Replication Rules]] covers what is and is not guaranteed. The robust approach is not to rely on the guarantee at all: send ids and let the client resolve the instance when it appears, or put the data on the instance as attributes so it arrives with it.

### 2.4 Unreliable remotes drop and reorder

`UnreliableRemoteEvent` (Docs) can drop or reorder messages. That is fine for cosmetic, frequently refreshed data (a laser pointer position). It is a desync generator for anything stateful: "door opened" sent unreliably may never arrive. If you see occasional permanent desync on a system using unreliable remotes, that is the first suspect ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]).

### 2.5 Streaming removes things

With `StreamingEnabled`, parts of the world stream out on the client. A client script that held a reference to a streamed-out part now holds a part with `Parent == nil`. When it streams back in, it is **a different instance** (rule of thumb: treat any streamed instance as replaceable). Desync appears as "my highlight disappeared after walking away and back". Fix: rebind on `CollectionService` tag added/removed, not on references held at startup ([[Instance Streaming]], [[CollectionService Patterns]]).

### 2.6 Time

`os.time()` and `os.clock()` differ between machines. Using them to compare client and server events (cooldowns, timers, countdowns) produces "the timer ends early on my client". Use `workspace:GetServerTimeNow()` (Docs: a server-synchronised clock on clients) for anything shown to the player that must match the server. Still never trust the client's notion of time for authority ([[Server Authority and Validation]]).

---

## 3. Attributes vs remotes: choosing to avoid desync

The channel decision is a desync decision.

| Need | Channel | Why it resists desync |
|---|---|---|
| Persistent state of an object ("door open", "enemy health") | attribute or property set by the server | late joiners and re-streamed clients get the current value automatically |
| A moment ("explosion here", "level up") | RemoteEvent | an event is not state; a late joiner does not need it |
| High-rate cosmetic data | UnreliableRemoteEvent | loss is acceptable because the next update fixes it |
| Private per-player data (inventory) | RemoteEvent with full snapshots or versioned deltas | attributes on the Player are visible to every client |
| Large structured state | a replicated value container or remotes with snapshots | attributes are flat; big tables do not fit well |

The most common design error behind desyncs: **state sent as events.** "Door opened" fired as a remote works until someone joins late, streams the door back in, or misses a message. Then that client's door is closed forever. If it is state, make it state.

The reverse error also exists: **events sent as state** (a "LastHit" attribute that flips) loses events through batching and fires again on re-stream.

### 3.1 Snapshots and versions for remote-driven state

When state must go through remotes (private inventories, for example), send it in a way a client can recover from:

```lua
--!strict
-- Server: each change bumps a version; deltas carry the version they produce.
type Delta = { version: number, op: "add" | "remove", itemId: string, count: number }

-- Client: apply deltas in order; on a gap, ask for a full snapshot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InventoryDelta = Remotes:WaitForChild("InventoryDelta") :: RemoteEvent
local RequestSnapshot = Remotes:WaitForChild("RequestInventorySnapshot") :: RemoteFunction

local inventory: { [string]: number } = {}
local version = 0
local resyncing = false

local function resync()
	if resyncing then
		return
	end
	resyncing = true
	local ok, snap = pcall(function()
		return RequestSnapshot:InvokeServer()
	end)
	if ok and type(snap) == "table" then
		inventory = snap.items
		version = snap.version
	end
	resyncing = false
end

InventoryDelta.OnClientEvent:Connect(function(d: Delta)
	if d.version <= version then
		return -- old or duplicate
	end
	if d.version ~= version + 1 or resyncing then
		task.spawn(resync) -- gap: something was missed or reordered
		return
	end
	version = d.version
	local cur = inventory[d.itemId] or 0
	inventory[d.itemId] = if d.op == "add" then cur + d.count else math.max(0, cur - d.count)
end)
```

Design notes: deltas that arrive during a resync are dropped and the snapshot covers them; the snapshot handler on the server must validate and rate-limit like any remote ([[Remote Abuse Patterns and Rate Limiting in Practice]]). The version number turns silent desync into a detected, self-healing one, and a counter of resyncs is an excellent health metric.

---

## 4. A desync inspector

The fastest way to debug desync is to stop inferring and **compare both sides directly**. A Studio-gated tool that asks the server for its view of an instance and diffs it against the client's.

### 4.1 Server side

```lua
--!strict
-- ServerScriptService/Debug/DesyncInspector.server.luau (Studio or allow-listed only)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ALLOWED: { [number]: boolean } = {} -- developer UserIds for live use; empty = Studio only

local remote = Instance.new("RemoteFunction")
remote.Name = "DebugInspect"
remote.Parent = ReplicatedStorage

local function snapshot(inst: Instance): { [string]: any }
	local out: { [string]: any } = {}
	for k, v in inst:GetAttributes() do
		out["@" .. k] = v
	end
	if inst:IsA("BasePart") then
		out.Position = inst.Position
		out.Anchored = inst.Anchored
		out.Transparency = inst.Transparency
	end
	out.ChildCount = #inst:GetChildren()
	return out
end

remote.OnServerInvoke = function(player: Player, target: unknown)
	if not (RunService:IsStudio() or ALLOWED[player.UserId]) then
		return nil
	end
	if typeof(target) ~= "Instance" then
		return nil -- instance the server cannot see, or bad input
	end
	return snapshot(target)
end
```

### 4.2 Client side

```lua
--!strict
-- Client debug helper: compare one instance. Call from a debug UI or the client console.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Inspect = ReplicatedStorage:WaitForChild("DebugInspect") :: RemoteFunction

local function localSnapshot(inst: Instance): { [string]: any }
	local out: { [string]: any } = {}
	for k, v in inst:GetAttributes() do
		out["@" .. k] = v
	end
	if inst:IsA("BasePart") then
		out.Position = inst.Position
		out.Anchored = inst.Anchored
		out.Transparency = inst.Transparency
	end
	out.ChildCount = #inst:GetChildren()
	return out
end

local function diff(inst: Instance)
	local server = Inspect:InvokeServer(inst)
	if server == nil then
		warn("server cannot see", inst:GetFullName(), "(client-only instance?)")
		return
	end
	local client = localSnapshot(inst)
	for k, v in server do
		local c = client[k]
		local same = c == v
		if typeof(v) == "Vector3" and typeof(c) == "Vector3" then
			same = (v - c).Magnitude < 0.5 -- positions drift; tolerance
		end
		if not same then
			print(("DIFF %s  server=%s  client=%s"):format(k, tostring(v), tostring(c)))
		end
	end
	for k, c in client do
		if server[k] == nil then
			print(("ONLY CLIENT %s = %s"):format(k, tostring(c)))
		end
	end
end
```

Reading the output:
- "server cannot see": the client is looking at a client-created instance (missing kind, in reverse).
- An attribute that differs and **stays** different across several checks: stale. Search for client code that writes it.
- Positions that differ by a lot on unanchored parts: ownership, see [[Debugging Physics and Network Ownership]].
- `ChildCount` differs: streaming, or children created client-side.

Security: this remote exists only in Studio or for an allow-list, validates its input, and returns only data the client could see anyway. Even so, do not ship it to live servers without the gate ([[Server Authority and Validation]]).

### 4.3 Catching client-side writes in Studio

To find the stale-kind cause (a client writing server state), log every attribute change on the client and compare with the server's log: a change that appears on the client without a matching server change is a local write.

```lua
--!strict
-- Studio-only client watcher: report attribute changes on tagged instances.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

if RunService:IsStudio() then
	local function watch(inst: Instance)
		inst.AttributeChanged:Connect(function(name)
			print(("[C attr] %s.%s = %s @%.2f"):format(
				inst:GetFullName(), name, tostring(inst:GetAttribute(name)), workspace:GetServerTimeNow()))
		end)
	end
	for _, inst in CollectionService:GetTagged("DebugWatch") do
		watch(inst)
	end
	CollectionService:GetInstanceAddedSignal("DebugWatch"):Connect(watch)
end
```

Run the same on the server (prefix `[S attr]`). Using `GetServerTimeNow` on both sides gives comparable timestamps. The attribute signal does not tell you who wrote the value; if a client change has no server counterpart, search client code for `SetAttribute("<name>"`.

---

## 5. Divergent desync: duplicated logic

Divergent desync happens when both sides compute the same thing. Typical: a client counts down a cooldown locally and the server counts its own. A dropped frame, a hitch, or a different start time makes them disagree, and the player sees "ready" while the server rejects the attack.

Fixes, in order of preference:
1. **One source of truth, others display it.** The server sets `CooldownEndsAt` (server time) as an attribute. The client shows `CooldownEndsAt - workspace:GetServerTimeNow()`. No independent counting.
2. **Prediction with reconciliation.** If responsiveness demands that the client acts first, the client predicts and the server corrects, explicitly ([[Client Prediction and Reconciliation for Combat]]).
3. **Deterministic simulation** (same inputs, same code, same order) is rarely achievable in Roblox for anything involving physics or floats across machines. Avoid relying on it (rule of thumb).

---

## 6. UI desync

A specific and very common case: the data is right on the client, the UI is wrong.

| Symptom | Cause |
|---|---|
| UI shows the value at join, never updates | read once in a setup function, never subscribed |
| UI updates, then shows an older value | two listeners (old UI instance not destroyed) write the same label |
| UI correct after reopening the menu | the menu rebuilds on open, but does not listen while open |
| UI correct for the first character, wrong after respawn | listeners bound to the old character's Humanoid ([[Debugging Race Conditions and Yield Order]]) |

Debug move: print from the place that **writes the label**, not from the data. If the label writer is not running, the subscription is missing; if it runs with the wrong value, the data is wrong; if two writers run, you have duplicate UI.

---

## 7. A worked example

**Report:** "Sometimes the shop says I cannot afford something, but I have enough gems."

1. **Kind?** The client UI shows 900 gems; the item costs 800; the server rejects the purchase. Server value: 700. So the client is stale or divergent, not the server.
2. **Inspector.** `@Gems` on the Player: server 700, client 900. Stays that way.
3. **Watcher.** The client log shows `Gems = 900` with no matching server change. A local write.
4. **Search.** A LocalScript for an "instant spend" visual effect had done `SetAttribute("Gems", current - spent)`, then later a refund path did `+ spent`, but only on the client, after a failed purchase. The server never changed, so it never sent a correction.
5. **Fix.** The client never writes `Gems`. The animated counter shows a local display value that always converges to the replicated attribute.
6. **Guard.** The Studio watcher stays as a debug tool; a lint rule (Selene custom check or a simple grep in CI) flags `SetAttribute("Gems"` in client code ([[External Tooling - Rojo Wally Selene StyLua]]).

---

## 8. Measured notes from the reference project

- A recurring class of "works in Studio, broken live" bugs was assets (animations, sounds) that only the developer's account could load, which looks like desync ("others do not see it") but is permissions. Check permissions before debugging replication ([[Replication Rules]] lists it).
- A cosmetic weapon flourish that every client must see uses both channels on purpose: the owning client fires a remote, the server checks it against the tool's attribute (rate-limited to 1 per second) and then writes character attributes (which flourish, and a start time). Every client samples the motion from those attributes on its own clock. The attributes are the state; nobody depends on catching a single event, so a client that looks over late still plays the right frame.

---

## Common mistakes

- Debugging one side only. Always look at both.
- Sending state as events (late joiners and re-streams break).
- Client code writing replicated server state "just for display".
- Comparing client and server times with `os.clock()` or `os.time()`.
- Holding references to streamed instances across stream-out.
- Unreliable remotes for stateful messages.
- Independent client and server timers for the same cooldown.

## Checklist

- [ ] Desync classified: missing, stale, divergent or out of order.
- [ ] Both sides inspected (Client/Server toggle or inspector tool).
- [ ] Server-owned state is read-only on the client, with a check that flags violations.
- [ ] State goes through attributes or snapshots; moments go through remotes.
- [ ] Remote-driven state carries versions and can resync.
- [ ] Timers shown to players use `GetServerTimeNow` and a server-set end time.
- [ ] Debug remotes are Studio or allow-list gated and validate input.

## See also

[[Debugging Start Here]] · [[Replication Rules]] · [[Client-Server Model]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Instances Attributes and Tags]] · [[Instance Streaming]] · [[Client Prediction and Reconciliation for Combat]] · [[Debugging Physics and Network Ownership]] · [[Debugging Race Conditions and Yield Order]] · [[Network Bandwidth Budgets and Measuring Them]]

## Connected notes
<!-- auto-links:start -->
[[Replication Boundary]] · [[Cookbook - Remotes and Networking]] · [[Network Performance]] · [[Skill - Roblox Secure Remotes]] · [[Server Authority]] · [[Skill - Roblox Debugging]]
<!-- auto-links:end -->
