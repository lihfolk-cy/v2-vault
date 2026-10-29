---
tags: [architecture, networking, streaming, performance, memory, type/guide, area/networking, level/intermediate, api/CollectionService, area/performance, api/ProximityPrompt, api/Player]
---
# Instance Streaming

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Turning streaming off "to fix bugs" -> Fix the client code; non-streamed big worlds crash phones
> - Avoid: Persistent on many models -> Atomic for most; Persistent only for tiny essentials
> - Avoid: Expecting Atomic in ReplicatedStorage -> Streaming settings apply to Workspace only
> - Streaming on; properties chosen deliberately (radius, StreamOutBehavior, integrity mode, Improved behaviour).
> - Interactable models set to Atomic; Persistent only where justified.
> - No LocalScript indexes Workspace parts directly without a wait or a tag.
>
> Cost: TL;DR ~180 tok · whole note ~4.6k tok. Read more: ## Per-model streaming: `ModelStreamingMode` · ## Writing streaming-safe client code · ## Common mistakes · ## Checklist
<!-- tldr:end -->

With **instance streaming** (`Workspace.StreamingEnabled`), the server sends each client only the part of the Workspace near that player, and the client drops distant parts again when it needs memory. It is enabled by default for new places (Roblox docs, "Instance streaming"), and for any world bigger than a single arena it is the difference between a 10 second join and a 60 second join, and between a phone that runs the game and one that crashes. The cost is that **client code can no longer assume any Workspace instance exists**. This note covers the exact streaming rules, every property and per-model mode, how to write client code that survives streaming, how to move players safely with `RequestStreamAroundAsync`, and a production example of tuning a big world.

Related: [[Level of Detail and Model Streaming]] (visual LOD and SLIM), [[Case Study - Fast Join and Deferred Loading]], [[Memory Budgets and Leaks]].

## What streams and what does not

From the Roblox docs:

- **Scope:** only descendants of `Workspace` stream. `ReplicatedStorage` and `ReplicatedFirst` are sent in full at join and never stream. An Atomic model placed in ReplicatedStorage is not atomic; the setting has no meaning there.
- **On join**, the client receives the Workspace **except**: BaseParts; models set to Atomic, Persistent or PersistentPerPlayer; Nonatomic models when `ModelStreamingBehavior` is Improved; and the descendants of all of those. Those deferred instances stream in later based on distance, device and conditions.
- **Stream out:** a client may remove regions of BaseParts, starting furthest from its replication focus. Regions inside `StreamingMinRadius` **never** stream out.
- A **Model with no BasePart descendants** (a container for scripts or values) is exempt from streaming out unless it is under a BasePart.
- Instances **created or cloned by client scripts** are exempt from streaming out unless parented under a server-created instance.
- When an instance streams out it is **parented to `nil`, not destroyed**; removal signals fire on its parent and ancestors; if it streams back in, existing Luau references reconnect. Local-only property changes on it can be lost.
- **Assemblies** stream in as complete units with their constraints and attachments, except anchored assemblies, where only the BaseParts inside the radius come in. Assemblies stream out only when all their parts are eligible. Avoid huge moving assemblies: they stream in all at once and spike.
- **The server always has everything.** Streaming only changes what clients hold.

## Workspace properties

All streaming properties are **non-scriptable**: you set them on Workspace in Studio's Properties panel; scripts cannot read or set them (Roblox docs). `StreamingEnabled` itself cannot be set by script.

| Property | Default | Docs recommendation | Meaning |
|---|---|---|---|
| `StreamingMinRadius` | 64 | Keep 64 | Radius streamed at highest priority and never streamed out. Larger costs memory and server bandwidth |
| `StreamingTargetRadius` | 1024 | Keep 1024 | Maximum distance the server streams to; also the distance players see full detail |
| `StreamOutBehavior` | `LowMemory` | `Opportunistic` | LowMemory streams out beyond the min radius only under memory pressure. Opportunistic may remove regions beyond the target radius any time |
| `StreamingIntegrityMode` | `Default` | `PauseOutsideLoadedArea` | What happens when a player moves into an area not yet streamed. Enum values: `Default`, `Disabled`, `MinimumRadiusPause`, `PauseOutsideLoadedArea` |
| `ModelStreamingBehavior` | `Legacy` | `Improved` | How Nonatomic models stream (see below) |
| `PredictiveStreamingMode` | off | Opt in with `Enabled` | Engine pre-fetches likely respawn points and recently left areas |
| `EnableSLIMAvatars` | off | Per game | SLIM level of detail for avatars |

The target radius must be larger than the min radius: the ring between them is the buffer that absorbs moments when the client stops receiving (Roblox docs). Equal values mean more streaming pauses.

When integrity pausing triggers, `Player.GameplayPaused` becomes true; you can replace the default notification with `GuiService:SetGameplayPausedNotificationEnabled(false)` and your own UI.

## Per-model streaming: `ModelStreamingMode`

Enum values: `Default`, `Atomic`, `Persistent`, `PersistentPerPlayer`, `Nonatomic` (Roblox API reference). The docs describe the behaviours as:

| Mode | Streams in | Streams out | Use |
|---|---|---|---|
| Nonatomic (default behaviour) | Legacy: the model container and its non-BasePart children (scripts) replicate at join; parts stream individually. Improved: the model streams in when one of its parts is eligible, with that part and all non-part children; it streams out with its last part | Part by part | Scenery, terrain dressing, anything client code does not walk into |
| Atomic | Everything in the model (initial descendants) arrives together when any part is eligible | Only when all parts are eligible, all together | Interactables and machines client code reads as a whole (a door with its hinge and prompt, a shop stand) |
| Persistent | Sent as a complete unit soon after join, before `Workspace.PersistentLoaded` fires | Never | Very rare: a small set of parts client code must always reach. Not a way to bypass streaming |
| PersistentPerPlayer | Persistent for players added with `Model:AddPersistentPlayer()`, Atomic for others | Per player | A player's own base or plot that must stay loaded for its owner |

The docs warn that overusing Persistent hurts performance. Each Persistent model is memory every player always pays.

### Why Atomic simplifies code

With Atomic, a client that has the model has all of it, so you `WaitForChild` the model only, never each descendant:

```lua
--!strict
-- Client: one wait for an Atomic model, then direct indexing is safe.
local Workspace = game:GetService("Workspace")

local shop = Workspace:WaitForChild("ShopStand", 30)
if shop then
	-- Safe: an Atomic model's initial descendants arrive together with it.
	local counter = shop:FindFirstChild("Counter") :: BasePart
	local prompt = counter:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	prompt.Triggered:Connect(function()
		-- Local feedback only (open the shop UI). Purchases are decided on the server.
	end)
end
```

With Nonatomic, `shop.Counter` may arrive before or after `shop.Counter.Prompt`, and the model may exist while its parts do not.

## Replication focus

Streaming happens around the character's `PrimaryPart` by default. You can change it with `Player.ReplicationFocus`, or add extra foci with `Player:AddReplicationFocus(part)` and `RemoveReplicationFocus`. Each extra focus costs about as much server work as another player: the docs give the example that one player with nine moving foci costs roughly as much as ten players. Client physics, including for Persistent models, only simulates in streamed areas, so add a focus near any far object that must keep simulating (Roblox docs).

Good uses: a spectator camera that flies away from the character; a cutscene camera; a scope or remote viewer looking at a distant base; a "home base" that players return to often.

## Moving players: `RequestStreamAroundAsync`

When the **server** moves a character far away (a teleport pad, respawn in another world, an admin "bring", a cutscene ending), the destination is usually not streamed in on that client. The player lands in emptiness: they fall through missing floors, hit an integrity pause, or see the world pop in.

`Player:RequestStreamAroundAsync(position, timeOut)` asks the server to stream regions (parts and terrain) around a position to that player before you move them (Roblox docs):

- It **yields** and is server-callable for the target player.
- `timeOut` defaults to 0, which means effectively infinite; under low client memory the engine abandons requests regardless.
- The effect is **temporary** and there is **no guarantee** about what will be streamed.

```lua
--!strict
-- Server: move a player to a far destination with the destination streamed first.
local MAX_WAIT = 5 -- seconds; never let a slow client block the move forever

local function moveFar(player: Player, destination: CFrame)
	local character = player.Character
	if not character then return end

	-- Pre-fetch around the destination. pcall: the call can fail for players leaving.
	local ok, err = pcall(function()
		player:RequestStreamAroundAsync(destination.Position, MAX_WAIT)
	end)
	if not ok then
		warn("RequestStreamAroundAsync failed: " .. tostring(err))
	end

	-- The player may have left or respawned while we yielded.
	if player.Parent == nil or player.Character ~= character then return end
	character:PivotTo(destination)
end

return moveFar
```

Two practical details:

- Run it in its own thread if the caller should not yield (a ProximityPrompt handler can spawn it).
- Tell your movement validator that this move was server-initiated so it does not flag a "teleport" ([[Exploits and Anti-Cheat]]).

With `PredictiveStreamingMode = Enabled`, the engine also pre-fetches likely respawn points on death and keeps the area a player just left briefly streamed; it does not add a focus where you already requested one (Roblox docs).

## Writing streaming-safe client code

The rule: **a client script must handle every Workspace instance it uses appearing late, disappearing, and reappearing.**

| Pattern | Streaming-safe? | Better |
|---|---|---|
| `workspace.Map.Shop.Door.Prompt` at the top of a LocalScript | No: errors if any link is missing | `WaitForChild` on the Atomic model, or tag-based setup |
| `WaitForChild` chain with no timeout | Hangs forever if the player never goes near | Timeout, or event-driven setup |
| Looping over `workspace.Chests:GetChildren()` once at start | Misses chests that stream in later | `CollectionService` added and removed signals |
| Caching part references forever | Holds parts parented to nil; connections may die | Re-resolve on `GetInstanceAddedSignal`, clean up on removed |
| Client-side `Touched` on distant parts | Never fires; parts are not there | Server-side logic, or client logic only near the player |
| Reading attributes of an object to show UI | Fine if the object is streamed in | Keep UI-relevant state on `Player` or in ReplicatedStorage, which never stream |

The tag pattern handles all three cases in one place:

```lua
--!strict
-- Client: attach behaviour to every tagged instance as it streams in, clean up as it streams out.
local CollectionService = game:GetService("CollectionService")

local TAG = "Chest"
local cleanups: { [Instance]: () -> () } = {}

local function attach(inst: Instance)
	if cleanups[inst] then return end
	local conns: { RBXScriptConnection } = {}
	table.insert(conns, inst:GetAttributeChangedSignal("Opened"):Connect(function()
		-- play the open animation and VFX locally
	end))
	cleanups[inst] = function()
		for _, c in conns do c:Disconnect() end
	end
end

local function detach(inst: Instance)
	local cleanup = cleanups[inst]
	if cleanup then
		cleanup()
		cleanups[inst] = nil
	end
end

for _, inst in CollectionService:GetTagged(TAG) do attach(inst) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(attach)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(detach)
```

Tags travel with the instance, so tagged objects fire "added" when they stream in and "removed" when they stream out. See [[CollectionService Patterns]].

### Keep UI state off the map

A HUD that reads "quest progress" from an attribute on a quest board in Workspace breaks when the player walks away from the board. Put anything the UI needs on the `Player`, in `ReplicatedStorage`, or send it by remote. One production game mirrored quest and inventory state as JSON attributes on the Player for exactly this reason.

### Server code is unaffected, mostly

The server sees everything, so server logic does not change. Two exceptions: server code that **asks the client** about Workspace objects (client remotes that send an Instance only work if the client has it) and server moves of players (use `RequestStreamAroundAsync`).

## Production example: a world too big to see

One production game had a hub and several themed realms, the nearest realm more than 11,000 studs from the hub. Players in the hub could see realm models on the horizon, which meant the streaming radius was far too large: every client held geometry it would not reach for minutes. The team's changes:

| Setting | Chosen value | Reason |
|---|---|---|
| `StreamingMinRadius` | 256 | Combat arenas needed close geometry guaranteed (the docs default is 64; the team accepted the memory cost for its arenas) |
| `StreamingTargetRadius` | 1024 | The docs default; enough for every in-zone view |
| `StreamOutBehavior` | Opportunistic | Reclaim memory on phones without waiting for pressure |
| `ModelStreamingBehavior` | Improved | Models without parts stop arriving at join; faster join |
| `StreamingIntegrityMode` | MinimumRadiusPause | Pause only if the guaranteed radius is missing (the docs recommend PauseOutsideLoadedArea; the team picked the narrower mode to pause less often) |

Before flipping the switch, the code was audited for streaming readiness:

- **Every server-initiated move streamed the destination first**: hub travel, zone travel, world travel, death respawns, boss events, admin teleports.
- Client `WaitForChild` chains into Workspace only crossed Folders and a config ModuleScript (containers that do not stream out), never parts.
- Portal and gate lookups re-scanned instead of caching once.
- Automatic model LOD was turned off on 7,861 decorative models so distant stand-in meshes did not keep far realms visible (an attribute recorded the previous value on each model so it could be reverted).

The settings had to be applied by hand in Studio's Properties panel, because they are not scriptable: tooling that edits places by script could not set them.

A related lesson from the same game: a 5,000 by 1,900 stud sea of terrain water stalled joining. Large terrain and water areas are expensive to stream and render; the team replaced it with a flat part. See [[Terrain Tools and Terrain API]] and [[Water Sky and Atmosphere Art]].

## Streaming is not a security boundary

The security docs suggest streaming as defence in depth ("if feasible, use streaming to limit how much of the world replicates to a new player"), but do not rely on it for secrecy. Anything a player can get near streams to them, and exploit clients can move their character anywhere to pull content. Unreleased content belongs in a separate private universe, not in a far corner of the live map (Roblox docs, "Access control and confidentiality").

## Debugging streaming

- In a live game press **Shift+F3** (in Studio playtest **Shift+Ctrl+F3**, Mac **Shift+Cmd+F3**) for Network Stats, then **Shift+1** repeatedly; the fourth panel is the Streaming view, with regions coloured: red inside the min radius, yellow between min and target, blue at the target radius, green beyond (Roblox docs).
- Temporarily raise `CameraMaxZoomDistance` (for example to 1000) to see the streamed region around you.
- Studio playtests stream like live games, but with local server speed; also test on a real phone.

| Symptom | Cause | Fix |
|---|---|---|
| `attempt to index nil` in a LocalScript on join | Direct indexing into Workspace | `WaitForChild` with timeout, Atomic models, tags |
| Player falls through the floor after a teleport | Destination not streamed | `RequestStreamAroundAsync` before moving; integrity mode |
| Interactable works only after walking near it twice | Setup ran once at start and missed late arrivals | Tag added signal |
| Effects keep playing on objects far away | References to streamed-out parts never cleaned | Tag removed signal, `AncestryChanged` |
| Memory keeps growing on phones | `LowMemory` never streams out until pressure | `Opportunistic` |
| World pops in when turning around | Target radius too small for the view | Raise target radius, or fog and LOD to hide edges |
| Everything far away is visible | Target radius huge, or LOD stand-ins | Default radius; review Model LOD |
| Physics object far away stops moving | Client physics only runs in streamed areas | Server ownership, or an extra replication focus |

## Common mistakes

| Mistake | Fix |
|---|---|
| Turning streaming off "to fix bugs" | Fix the client code; non-streamed big worlds crash phones |
| Persistent on many models | Atomic for most; Persistent only for tiny essentials |
| Expecting Atomic in ReplicatedStorage | Streaming settings apply to Workspace only |
| Server teleports without pre-fetch | `RequestStreamAroundAsync` with a timeout |
| UI reading Workspace attributes | Move UI state to Player or ReplicatedStorage |
| Many replication foci per player | Each costs like a player; use sparingly |

## Checklist

- [ ] Streaming on; properties chosen deliberately (radius, StreamOutBehavior, integrity mode, Improved behaviour).
- [ ] Interactable models set to Atomic; Persistent only where justified.
- [ ] No LocalScript indexes Workspace parts directly without a wait or a tag.
- [ ] Every server move of a character pre-fetches the destination.
- [ ] Tested on a low-memory phone by walking far and back.

## See also
[[Level of Detail and Model Streaming]] · [[Client-Server Model]] · [[Replication Rules]] · [[CollectionService Patterns]] · [[Case Study - Fast Join and Deferred Loading]] · [[Memory Budgets and Leaks]] · [[Mobile and Low-End Optimization]] · [[Teleporting and Multi-Place Games]] · [[Network Ownership]]

## Connected notes
<!-- auto-links:start -->
[[Streaming Radius]] · Official Docs - Building and World · [[Interest Management and Per-Player Replication]] · Infinite and Streamed Worlds · Network Performance · Performance and Memory
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs]] · [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]] · [[Network Performance]] · [[Infinite and Streamed Worlds]] · [[Replication Boundary]] · [[Performance and Memory]]
<!-- related:end -->
