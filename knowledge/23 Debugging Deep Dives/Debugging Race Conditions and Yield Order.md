---
tags: [debugging, race-conditions, task-library, yielding, characters, players]
---
# Debugging Race Conditions and Yield Order

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `task.wait(n)` as a fix for load order.
> - Avoid: Connecting `PlayerAdded` or `CharacterAdded` after a yield, without handling players or characters already present.
> - Avoid: Holding a character reference across a yield without re-checking it is still current.
> - Every "on added" subscription uses connect, then iterate existing, with a double-init guard.
> - Character bindings clean up on respawn and re-check `player.Character == character` after waits.
> - Server handlers change state before yielding, or hold a per-player busy flag.
>
> Read more (18 KB note): ## 5. Character load order · ## 8. Tools for catching races · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Luau in Roblox runs one thread at a time per Luau VM (outside Parallel Luau), so people often assume races cannot happen. They happen constantly. A race in Roblox is not two threads writing the same memory at the same instant; it is **two pieces of code whose relative order is not fixed**, where one order works and the other does not. The order changes with network latency, device speed, streaming, deferred signals and which script the engine happens to start first. That is why race bugs show up on phones and in live servers and hide in Studio.

This note is about finding and fixing them. The `task` library itself and the basic ordering of `spawn` and `defer` are covered in [[Task Library Coroutines and Yielding]]; signal behaviour in [[Events Signals and Connections]].

Source labels: **Docs** (Creator Hub, as of October 2026), **Measured** (the reference project), **Rule of thumb**.

---

## 1. Where races come from

A Luau thread runs until it **yields**. Every yield is a point where other code can run and change the world. So the race surface of a function is exactly its yields:

| Yields (common) | Why it matters |
|---|---|
| `task.wait`, `task.delay` callbacks | obvious |
| `WaitForChild` (when the child is not there yet) | resumes at an unknown later time |
| `require` of a module whose top level yields | the requirer waits on someone else's load |
| DataStore, MemoryStore, HttpService, MarketplaceService calls | 50 ms to many seconds |
| `RemoteFunction:InvokeServer` / `InvokeClient` | a full network round trip, or forever |
| `Players:GetUserIdFromNameAsync` and other `Async` calls | network |
| `Event:Wait()` | until someone fires |
| `Humanoid:MoveToFinished:Wait()`, tween `Completed:Wait()` | gameplay time |

And there are races without any yield in your code:
- **Scripts start in an order you do not control.** Two server Scripts in ServerScriptService run in an order that is not guaranteed (rule of thumb: never rely on it).
- **Deferred signals.** Under `SignalBehavior = Deferred`, handlers run at the next resumption point, after the code that fired them has moved on.
- **Replication.** On the client, instances arrive over time, in batches.

The debugging consequence: when you suspect a race, **list the yields between the cause and the symptom**. Each one is a candidate.

---

## 2. `task.spawn`, `task.defer`, `task.delay`: ordering traps

The basic order (spawn runs now up to its first yield, defer runs after the current work) is in [[Task Library Coroutines and Yielding]]. The traps:

### 2.1 spawn runs before your next line

```lua
local state = { ready = false }
task.spawn(function()
	print(state.ready) -- false: runs before the line below
end)
state.ready = true
```

If the spawned function needs the caller to finish setting things up, `task.spawn` is wrong; use `task.defer`, or finish setup first.

### 2.2 defer is not "later, safely"

`task.defer` runs at the next resumption point in the current frame cycle, not "after everything has loaded". Deferring a lookup of a replicated child does not wait for replication. Only an explicit wait for the condition does.

### 2.3 `task.wait(n)` as a fix is a longer fuse

`task.wait(1)` before reading something "makes it work" because on your machine it arrives in 0.2 s. On a phone on a bad network it arrives in 1.5 s. You have moved the failure from 30% of players to 3%, which is harder to debug. Wait for the **condition**: a child, an attribute, a signal.

### 2.4 Re-entrancy through events

A handler that fires an event that is handled by code that calls back into the first system is a race in disguise: the second call sees half-updated state. Under Deferred signals the order flips compared with Immediate, so code that "worked" for years can break when the place switches. Fix by updating all state first, then firing, and by making handlers tolerate being called at any moment ([[Events Signals and Connections]]).

---

## 3. `WaitForChild` pitfalls

`WaitForChild` is the most used race fix in Roblox and a common race cause.

| Pitfall | What happens | Fix |
|---|---|---|
| Waiting on the **old** character or GUI | the child is added to the new one; you wait forever | re-acquire the parent on respawn (section 5) |
| Waiting on the client for a server-only instance | never arrives; "Infinite yield possible" after 5 s (Docs) | keep shared things in ReplicatedStorage; server-only in ServerStorage |
| Waiting on the server for an instance another script creates | works only if that script runs; deadlock if it waits on you | create shared instances in one bootstrap, or create them where they are defined |
| Two children with the same name | returns whichever it finds first | unique names; never rely on name order |
| Streaming | a workspace child outside the streaming radius never streams in | use tags and `GetInstanceAddedSignal`, or `Player:RequestStreamAroundAsync` ([[Instance Streaming]]) |
| Chained waits `a:WaitForChild("b"):WaitForChild("c"):WaitForChild("d")` on every call | slow join and yields in hot paths | resolve once at startup and cache, revalidating on respawn |
| No timeout where nil is legal | silent hang after the warning | pass a timeout and handle nil |

A rule of thumb that removes most of them: **replicated containers are waited for once, at startup, by a single loader; gameplay code receives references, it does not wait.**

---

## 4. "PlayerAdded fired before I connected"

The classic: a server script does

```lua
Players.PlayerAdded:Connect(onPlayerAdded)
```

and in Studio Play Solo, `onPlayerAdded` never runs for you. The player joined before the script reached that line, because something above it yielded (a `require` of a module that loads config, a `WaitForChild`), or simply because in Play Solo the local player can exist very early.

Live servers have the same bug in a rarer form: a server that starts with a player already teleporting in.

The fix is a pattern, not a delay:

```lua
--!strict
local Players = game:GetService("Players")

local initialised: { [Player]: boolean } = {}

local function onPlayerAdded(player: Player)
	if initialised[player] then
		return -- already handled (connect and loop can both see the same player)
	end
	initialised[player] = true
	-- ... setup ...
end

Players.PlayerAdded:Connect(onPlayerAdded) -- connect FIRST
for _, player in Players:GetPlayers() do -- then catch anyone already here
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	initialised[player] = nil
end)
```

Why connect first: if you loop first and then connect, a player who joins between the loop and the connect is missed. Why the guard: with connect first, a player who joins in that window is seen by both. Why `task.spawn`: each setup may yield (data load), and players should not wait for each other.

The same pattern applies to `CharacterAdded` (section 5), `CollectionService` tags (`GetTagged` plus `GetInstanceAddedSignal`), `ChildAdded` with existing children, and attribute signals (read the current value, then subscribe).

---

## 5. Character load order

Characters are the richest source of race bugs because they are created repeatedly and replicate in pieces.

### 5.1 The sequence (rule of thumb, verify per feature)

On the server, when a character spawns:
1. The character model is built and `player.Character` is set.
2. `Player.CharacterAdded` fires.
3. The model is parented into the workspace.
4. Appearance (accessories, clothing) loads; `Player.CharacterAppearanceLoaded` fires when done (Docs).

On the client, the model arrives through replication, and **children can arrive after `CharacterAdded` fires** on the client. Code that does `character.Humanoid` in a client `CharacterAdded` handler works on fast connections and fails on slow ones.

### 5.2 Patterns

```lua
--!strict
-- Client: robust character binding with cleanup on respawn.
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local connections: { RBXScriptConnection } = {}

local function cleanup()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
end

local function onCharacter(character: Model)
	cleanup()
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return -- slow or broken spawn; the next CharacterAdded will try again
	end
	if player.Character ~= character then
		return -- respawned while we were waiting: this character is already stale
	end
	table.insert(connections, humanoid.Died:Connect(function()
		-- ...
	end))
	-- ... bind UI, camera, input to this humanoid ...
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end
```

The key line is `if player.Character ~= character then return end` **after** the waits. Without it, a quick double respawn (reset twice) leaves two bindings, one to a dead character. That is the source of many "UI shows health 0 after respawn" and "ability fires twice after reset" bugs.

Where to put character code:
- `StarterCharacterScripts`: a fresh copy runs in every new character; its references are naturally scoped to that life. Simplest for per-life logic.
- `StarterPlayerScripts`: runs once per session; must rebind on each `CharacterAdded` (as above). Better for systems that persist across lives (inventory UI, settings).

Mixing both for one system is a common source of duplicated handlers.

### 5.3 Server races around death and leaving

- A damage handler yields (plays a sound, waits for a tween), then applies a reward. If the target left or respawned in between, the reward goes to a stale reference. Re-check `target.Parent` and the player's current character after every yield.
- `PlayerRemoving` while a data load is still in flight: the save on leave runs before the load finished and saves an empty profile. This is the most expensive race in Roblox. Track the load state and refuse to save a profile that never finished loading ([[Saving Correctly - Autosave and BindToClose]], [[Session Locking and Profile Libraries]]).

---

## 6. Request races on the server

Two requests from the same player can be in flight at once whenever a handler yields. That is the root of most duplication bugs.

```lua
-- BROKEN: two quick clicks both pass the check before either spends.
Remote.OnServerEvent:Connect(function(player, itemId)
	local profile = getProfile(player)
	if profile.Gems >= PRICE then
		local ok = grantFromExternal(player, itemId) -- yields
		if ok then
			profile.Gems -= PRICE
		end
	end
end)
```

Both handler threads read `Gems >= PRICE` before either subtracts, because the first one yielded in between. Fixes, in order of strength:
1. **Do the state change before any yield** (spend first, refund on failure).
2. **A per-player busy flag** for that action (reject or queue while one is in flight).
3. **Idempotency keys** for anything crossing servers or DataStores ([[Trading Systems Without Duplication]]).

```lua
--!strict
local busy: { [Player]: boolean } = {}

Remote.OnServerEvent:Connect(function(player: Player, itemId: unknown)
	if typeof(itemId) ~= "string" or busy[player] then
		return
	end
	busy[player] = true
	local ok, err = pcall(function()
		local profile = getProfile(player)
		if profile and profile.Gems >= PRICE then
			profile.Gems -= PRICE -- spend before yielding
			if not grantFromExternal(player, itemId) then
				profile.Gems += PRICE -- refund
			end
		end
	end)
	busy[player] = nil -- always released, even on error
	if not ok then
		warn("purchase handler failed: " .. tostring(err))
	end
end)
```

Rate limiting is a separate defence ([[Remote Abuse Patterns and Rate Limiting in Practice]]); it does not prevent this race, because two requests within the limit are enough.

---

## 7. Module initialisation races

Two common shapes:
- **A module that yields at require time** (waits for data, `WaitForChild` on something created elsewhere). Every requirer stalls until it finishes, and if two modules wait on each other's top-level work you get a deadlock that only shows as missing behaviour plus "Infinite yield possible" warnings.
- **Init order assumptions**: system B's `init` reads something system A's `init` creates. Works while the bootstrap happens to start A first.

Fixes: keep module top levels free of yields (define functions and tables only), and use an explicit bootstrap that calls `init` then `start` on every system in a defined order ([[Project Structure and Bootstrapping]]). For cross-system readiness, publish a ready flag (an attribute such as `DataLoaded` on the Player, or a signal) and have dependents wait for that, not for a timer.

---

## 8. Tools for catching races

### 8.1 A sequence log

When order matters, timestamps alone are not enough within one frame. Add a frame number and a global sequence counter:

```lua
--!strict
-- Shared/Seq.luau: ordered debug events, Studio only.
local RunService = game:GetService("RunService")

local Seq = {}
local n = 0
local frame = 0
local enabled = RunService:IsStudio()

if enabled then
	RunService.Heartbeat:Connect(function()
		frame += 1
	end)
end

function Seq.mark(tag: string, detail: string?)
	if not enabled then
		return
	end
	n += 1
	print(("[seq %d f%d %.3f] %s %s"):format(n, frame, os.clock(), tag, detail or ""))
end

return Seq
```

Mark both sides of the suspected race (`Seq.mark("load:start")`, `Seq.mark("ui:readCoins")`). When the bug happens, the log shows the bad order. Compare it with a good run.

### 8.2 Injected jitter

Make races frequent: in Studio, add a random small wait at suspected yield points.

```lua
--!strict
local RunService = game:GetService("RunService")
local JITTER = RunService:IsStudio() and workspace:GetAttribute("DebugJitter") == true

local function jitter()
	if JITTER then
		task.wait(math.random() * 0.3)
	end
end
```

Call `jitter()` before data loads complete, before remotes fire, in character setup. If a bug's rate jumps with jitter on, you have confirmed a race and narrowed where.

### 8.3 Network latency and slow devices

Studio's network simulation adds replication lag; combined with multi-client tests it reproduces most client load-order races ([[Testing Modes - Play Run and Multi-Client]], [[Multi-Client and Device Playtesting Protocols]]). A low-end phone is the final test: it changes timing more than any setting.

### 8.4 Assertions for invariants

Some races leave a detectable fingerprint. Assert the invariant where it must hold:
- "A profile is never saved before it loaded."
- "A player never has two active character bindings."
- "An item id is never granted twice for one receipt."

Log violations with a traceback (Studio) or a counter (live). They turn silent races into visible ones ([[Crash and Error Telemetry]]).

---

## 9. A worked example

**Report:** "On mobile, sometimes the whole HUD is empty after joining. Rejoining fixes it."

1. **Reproduce.** PC Studio: 0 of 10. With 300 ms incoming lag: 3 of 10. A race.
2. **List yields** between join and HUD build: the HUD script does `player:WaitForChild("leaderstats")`, then reads `Coins`, then `WaitForChild("Data")` on a folder the data system creates after the profile loads.
3. **Sequence log.** In the failing runs, `hud:start` happens after `data:ready`... and the HUD still fails. Odd.
4. **Look closer.** The HUD reads `Data` with `FindFirstChild` in one function and `WaitForChild` in another. The `FindFirstChild` path runs first, finds nothing, and builds an empty HUD. It never rebuilds.
5. **Explain.** On fast connections `Data` happens to be there; on slow ones it is not. The UI is built once and never updates.
6. **Fix.** The data system sets a `DataLoaded` attribute on the Player when ready. The HUD waits for it (or subscribes to the attribute change) and then builds. All reads go through one accessor.
7. **Verify.** 0 of 20 with 300 ms lag; 0 of 5 on a real low-end phone.
8. **Guard.** HUD logs a warning if it builds with missing data.

---

## Common mistakes

- `task.wait(n)` as a fix for load order.
- Connecting `PlayerAdded` or `CharacterAdded` after a yield, without handling players or characters already present.
- Holding a character reference across a yield without re-checking it is still current.
- Handlers that yield between checking and spending.
- Yielding module top levels.
- Relying on the start order of scripts.
- Saving a profile that never finished loading.

## Checklist

- [ ] Every "on added" subscription uses connect, then iterate existing, with a double-init guard.
- [ ] Character bindings clean up on respawn and re-check `player.Character == character` after waits.
- [ ] Server handlers change state before yielding, or hold a per-player busy flag.
- [ ] Module top levels never yield; a bootstrap defines init order.
- [ ] Readiness is an explicit flag or signal, never a delay.
- [ ] Races are reproduced with latency, jitter and a real phone before and after the fix.
- [ ] Invariants that races break are asserted and counted.

## See also

[[Debugging Start Here]] · [[Task Library Coroutines and Yielding]] · [[Events Signals and Connections]] · [[Characters and Humanoids]] · [[Project Structure and Bootstrapping]] · [[Saving Correctly - Autosave and BindToClose]] · [[Trading Systems Without Duplication]] · [[Remote Abuse Patterns and Rate Limiting in Practice]] · [[Debugging Client-Server Desync]] · [[Reading Luau Errors and Stack Traces]]

## Connected notes
<!-- auto-links:start -->
[[Custom Schedulers and Coroutine Patterns]] · [[Building a Signal Library]] · [[Cookbook - Remotes and Networking]] · [[Cookbook - Players and Characters]] · [[Functions Closures and Upvalues]] · [[Error Handling - pcall xpcall and Promise Patterns]]
<!-- auto-links:end -->
