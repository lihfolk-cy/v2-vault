---
tags: [case-study, performance, join-time, loading, replication, streaming, production]
---
# Case Study: Fast Join and Deferred Loading

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Putting every model the client might ever need in ReplicatedStorage.
> - Avoid: Building a fancy loading screen and calling the join fixed.
> - Avoid: Waiting for `WaitForChild` on a large deferred folder and assuming its contents are complete.
> - Join telemetry: loaded, ready, play, by device.
> - ReplicatedStorage instance count tracked; top folders known.
> - Dense data baked to compact forms.
>
> Cost: TL;DR ~140 tok · whole note ~3.9k tok. Read more: ## Step 0: measure join time from the client · ## Step 3: defer what is not needed at join · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Players decide in seconds. A long join (black screen, then a loading bar, then a menu, then the world popping in) loses players before they see your game. This case study follows one live action game (the reference project) as it discovered why its joins were slow, measured them, and moved non-essential content out of the join path: baking heavy data, tightening streaming, moving a main-menu kit out of ReplicatedStorage, and loading armour, pets and loot models only when needed.

General background: [[Instance Streaming]], [[Replication Rules]], [[Mobile and Low-End Optimization]], [[Network Performance]].

## What a join actually waits for

Simplified order of a join (Roblox docs, plus measurement in the reference project):

1. The client connects and receives **ReplicatedFirst**; its LocalScripts run early, which is why custom loading screens live there.
2. The client receives **ReplicatedStorage** and the non-streamed parts of **Workspace**. Everything in ReplicatedStorage replicates in full; there is no streaming for it.
3. `game.Loaded` fires (`game:IsLoaded()` becomes true).
4. Player scripts run, the character spawns, UI builds.
5. With streaming enabled, Workspace content around the player keeps arriving.

The key fact: **everything in ReplicatedStorage is downloaded and deserialised by every client before the game is loaded.** Content placed there "so the client can reach it" is content every player waits for, whether they will use it or not.

The reference project's measurement about a month in: ReplicatedStorage held over 100k instances, all replicated before `game.Loaded`, of which character models were about a third and well over a hundred ability-kit folders about 40% (measured). The team's own conclusion is the most important line in this note: "That, not the menu, is what makes joins slow; the menu only hides the wait."

## Step 0: measure join time from the client

You cannot improve what you do not measure, and Studio does not reproduce a phone on a slow network. The reference project added join telemetry the same day as its new main menu. The menu script (in ReplicatedFirst, so it starts early) recorded three times relative to its own start: content loaded, menu ready (PLAY enabled), PLAY pressed. It sent them once to the server, which validated them and logged analytics custom events with the device type and the chosen graphics preset as fields.

```lua
--!strict
-- ReplicatedFirst LocalScript (excerpt): time the join from this script's first line.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local t0 = os.clock()

if not game:IsLoaded() then
	game.Loaded:Wait()
end
local loadedAt = os.clock() - t0

-- ... build the menu, wait for character and essential UI ...
local readyAt = os.clock() - t0

local function onPlayPressed()
	local playAt = os.clock() - t0
	local remote = ReplicatedStorage:WaitForChild("JoinTiming") :: RemoteEvent
	remote:FireServer(loadedAt, readyAt, playAt)
end
```

```lua
--!strict
-- Server: validate and log once per player.
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = Instance.new("RemoteEvent")
remote.Name = "JoinTiming"
remote.Parent = ReplicatedStorage

local seen: { [Player]: boolean } = {}

local function valid(x: unknown): boolean
	return typeof(x) == "number" and x == x and x >= 0 and x < 600 -- reject NaN and junk
end

remote.OnServerEvent:Connect(function(player: Player, loaded: unknown, ready: unknown, play: unknown)
	if seen[player] or not (valid(loaded) and valid(ready) and valid(play)) then
		return
	end
	seen[player] = true
	AnalyticsService:LogCustomEvent(player, "JoinLoaded", loaded :: number)
	AnalyticsService:LogCustomEvent(player, "JoinReady", ready :: number)
	AnalyticsService:LogCustomEvent(player, "JoinPlay", play :: number)
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	seen[player] = nil
end)
```

`LogCustomEvent(player, eventName, value, customFields)` is the documented signature (Roblox docs, October 2026); the reference project passed device type and graphics preset in the custom fields so it could split results by device. Results show up under the experience's analytics custom events in Creator Hub. See [[Analytics and Funnels]].

Caveats:

- The clock starts when the first ReplicatedFirst script runs, not when the player clicked Play on the website. The time before that (server match, connect) is invisible to you; it still counts for the player.
- Telemetry is client-reported; validate and treat it as statistics, never as gameplay input. See [[Server Authority and Validation]].
- "Time to PLAY pressed" includes how long the player looked at the menu. Use "loaded" and "ready" for performance.

## Step 1: make what must replicate smaller

Before moving anything, shrink what stays. The reference project's biggest win here was representation: animation keyframe data stored as instances was converted to compact binary buffers in attributes, with originals archived to disk. ReplicatedStorage went from 392k to 107k instances on every client from player clips alone, and later from over 100k to about 70k when weapon rig clips were baked and unused importer animation saves removed (measured). Details: [[Baked Clip Stubs and Archiving]] and [[Case Study - Cutting a Million Instances]].

Rule of thumb: count instances, not bytes. A folder of thousands of tiny instances costs more than one mesh of the same total size, because each instance is created, parented and tracked individually.

## Step 2: streaming that actually streams

The owner noticed from the lobby that a distant play area was visible from afar, when players should only see what is around them. That area was many thousands of studs from the lobby, so seeing it meant the streaming radii were far too large or models were not streaming out.

Facts that shaped the fix:

- Workspace streaming properties (`StreamingEnabled`, `StreamingMinRadius`, `StreamingTargetRadius`, `StreamOutBehavior`, `ModelStreamingBehavior`, `StreamingIntegrityMode`) **cannot be set from scripts**; they are set on Workspace in Studio (Roblox docs). Tools and command-bar scripts cannot change them; a person sets them in the Properties panel.
- Defaults are `StreamingMinRadius` 64 and `StreamingTargetRadius` 1024 (Roblox docs, October 2026).
- `StreamOutBehavior` can be `LowMemory` (default) or `Opportunistic`; `ModelStreamingBehavior` can be `Legacy` (default) or `Improved` (Roblox docs).

The settings the reference project asked for: min radius 256, target 1024, stream-out Opportunistic, model streaming Improved, integrity mode set to pause when the minimum radius is not loaded. It also disabled automatic level of detail on several thousand map models so distant stand-in meshes would not render, storing the old value as an attribute for revert (measured). Whether that LOD change helps depends on the game; it removed far imposters the owner did not want, at the cost of no far silhouettes.

Code must tolerate streaming. The project checked every server move: each teleport-like move requested streaming around the destination first (`Player:RequestStreamAroundAsync`), and client code only waited on Workspace paths that cross folders or modules that are always present. See [[Instance Streaming]].

## Step 3: defer what is not needed at join

What does a player need in the first minute? The character, the HUD, the hub and the tutorial. What did the reference project replicate at join? Every weapon model, every ability kit, every armour piece, every pet, every loot model, and a main-menu kit. The fix is **deferred loading**: keep non-essential assets in ServerStorage (which clients never receive) and move them to a replicated location only when a player first needs them.

The reference project applied this to:

- **The main-menu kit.** The new main menu's art and showcase assets lived in ReplicatedStorage, so they replicated to every client and stayed there after the menu closed. They were moved out of ReplicatedStorage. A related constraint: the menu runs from ReplicatedFirst before ReplicatedStorage is available, so it cannot `require` shared theme modules; it carried a local copy of the colour tokens and a hard-coded showcase list ("hard-coded because the config arrives with ReplicatedStorage much later"). Anything the menu needs early must be small and live with it.
- **Armour kits.** Hundreds of armour MeshParts are needed only when a player opens the armour tab or wears armour.
- **Pets.** Pet models are needed only for players who own pets (pets were also shelved behind a flag for a while).
- **Drop models.** Loot and material pickup models are needed only once combat starts.

A minimal deferred-asset service:

```lua
--!strict
-- ServerScriptService.DeferredAssets
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local source = ServerStorage:WaitForChild("Deferred") :: Folder -- kits live here, never replicated

local shelf = Instance.new("Folder")
shelf.Name = "DeferredShelf" -- replicated destination
shelf.Parent = ReplicatedStorage

local request = Instance.new("RemoteFunction")
request.Name = "RequestKit"
request.Parent = ReplicatedStorage

local ALLOWED: { [string]: boolean } = { ArmorKit = true, PetKit = true, DropModels = true }

local function publish(name: string): boolean
	if shelf:FindFirstChild(name) then
		return true
	end
	local kit = source:FindFirstChild(name)
	if not kit then
		return false
	end
	-- Tell clients how much to wait for: big subtrees can arrive over several frames.
	kit:SetAttribute("DescendantCount", #kit:GetDescendants())
	kit.Parent = shelf -- move, don't clone: no second copy in server memory
	return true
end

request.OnServerInvoke = function(_player: Player, name: unknown): boolean
	if typeof(name) ~= "string" or not ALLOWED[name] then
		return false
	end
	return publish(name)
end

-- Server-side triggers can publish too, e.g. when the first enemy dies:
-- publish("DropModels")
```

```lua
--!strict
-- Client helper: get a deferred kit, waiting until it has fully arrived.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getKit(name: string, timeout: number?): Instance?
	local shelf = ReplicatedStorage:WaitForChild("DeferredShelf")
	local kit = shelf:FindFirstChild(name)
	if not kit then
		local request = ReplicatedStorage:WaitForChild("RequestKit") :: RemoteFunction
		if not request:InvokeServer(name) then
			return nil
		end
		kit = shelf:WaitForChild(name, timeout or 30)
		if not kit then
			return nil
		end
	end
	local expected = kit:GetAttribute("DescendantCount")
	local deadline = os.clock() + (timeout or 30)
	while typeof(expected) == "number" and #kit:GetDescendants() < expected and os.clock() < deadline do
		task.wait(0.1)
	end
	return kit
end
```

Design notes and trade-offs:

- **Once published, a kit replicates to everyone.** ReplicatedStorage has no per-player replication. That is acceptable for kits most players eventually need (drops); for rare content, publishing on first use still saves every player who never uses it.
- **Move, do not clone.** Cloning doubles server memory for the kit.
- **Wait for the whole subtree.** `WaitForChild` returns when the root arrives; descendants of a large folder can still be arriving. The descendant-count attribute is a simple completeness check. (Rule of thumb, not a documented guarantee about arrival order.)
- **Trigger early, not at the click.** Request the armour kit when the player opens the backpack, not when they click the armour tab; request drops when the player crosses into a combat zone. Prefetch hides latency.
- **Preload assets, not just instances.** Instances arriving is not the same as meshes and textures being downloaded; use `ContentProvider:PreloadAsync` on the kit after it arrives if first use must look complete (Roblox docs).
- **Lazy require kit code.** The same idea applies to code: the reference project's client required well over a hundred ability-kit modules (tens of megabytes of source) at start through over a hundred small client scripts (measured). Requiring a kit's module when its weapon is equipped removes that cost from the join.

## Step 4: present the wait well

Even a fast join has a wait. The reference project's main menu: a hub flyover behind a logo, PLAY showing "Loading n%" until the character, the main UI and the hub are present (or 25 seconds pass), a graphics-preset prompt on first launch with a per-device recommendation (phones: performance; tablets and consoles: balanced; PC by the Roblox quality slider), and an updates panel. The HUD stays hidden until PLAY. Good presentation reduces perceived wait, but the team's own measurement is the warning: it does not make the join shorter.

Choosing graphics defaults per device on first launch matters for join and first-minute frame rate on phones. Save the choice so returning players are not asked again.

## Results and open items

Measured in the reference project:

- ReplicatedStorage from a peak near 600k instances (early in development) to over 100k (about a month in) to about 70k (same day, after rig baking).
- Several thousand models with automatic LOD disabled.
- Join telemetry in place, by device and preset.
- Main-menu kit, armour, pets and drops moved off the join path.

Not measured in the notes at the time of writing: before-and-after join seconds by device. That is the number that matters; collect it for at least a week before and after such a change.

## Lessons

1. **ReplicatedStorage is the join cost.** Audit it by folder, every week.
2. **A loading screen is presentation, not optimisation.**
3. **Measure join time on real devices from the first publish.**
4. **Shrink representation first**, then defer, then stream.
5. **Streaming settings are Studio-only properties**; put them on the release checklist.
6. **ReplicatedFirst code cannot rely on ReplicatedStorage**; keep the early path self-contained and small.
7. **Defer by trigger and prefetch**, so deferred content is ready before the click.

## Common mistakes

- Putting every model the client might ever need in ReplicatedStorage.
- Building a fancy loading screen and calling the join fixed.
- Waiting for `WaitForChild` on a large deferred folder and assuming its contents are complete.
- Cloning deferred kits instead of moving them.
- Forgetting that streaming properties cannot be scripted.

## Checklist

- [ ] Join telemetry: loaded, ready, play, by device.
- [ ] ReplicatedStorage instance count tracked; top folders known.
- [ ] Dense data baked to compact forms.
- [ ] Streaming radii and modes set deliberately in Studio; code tolerates streaming.
- [ ] Non-essential kits in ServerStorage, published on trigger, with a completeness check.
- [ ] Kit code required lazily.
- [ ] ReplicatedFirst path small and self-contained.

## See also

- [[Instance Streaming]], [[Replication Rules]], [[Network Performance]], [[Mobile and Low-End Optimization]]
- [[Case Study - Instance Cleanup and Place Size]], [[Case Study - Cutting a Million Instances]], [[Animation LOD]]
- [[ScreenGui Fundamentals]], [[First-Time User Experience and Onboarding]]
- [[Post-Mortem - Building a Melee Action Game]], [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[Level of Detail and Model Streaming]] · [[Streaming Radius]] · [[Links - StreamingEnabled]] · [[Performance and Memory]] · [[Client-Server Model]] · [[Instance Count]]
<!-- auto-links:end -->
