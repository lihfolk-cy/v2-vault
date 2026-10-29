---
tags: [architecture, server, lifecycle, shutdown, bindtoclose, live-ops, type/guide, area/networking, level/intermediate, api/BindToClose, area/liveops, api/ServerRestartScheduled]
---
# Server Lifecycle and Shutdown

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: One sequential save loop in `BindToClose` -> Parallel saves with a deadline
> - Avoid: `BindToClose` and `PlayerRemoving` saving the same profile... -> Per-player save serialisation; idempotent saves
> - Avoid: Relying on soft-shutdown teleports to protect data -> Save first; teleports can be disabled
> - One `BindToClose` handler saves everyone in parallel and waits for in-flight saves, with a deadline under 30 s.
> - Per-player saves are serialised and idempotent; profiles are session-locked.
> - `ServerRestartScheduled` warns players and triggers early saves.
>
> Cost: TL;DR ~180 tok · whole note ~3.9k tok. Read more: ## BindToClose: the rules · ## The soft-shutdown pattern (and when you still need it) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A Roblox game server is born when matchmaking needs one, lives while players are in it, and dies when it empties, when you restart servers for an update, when Roblox does maintenance, when it runs out of memory, or when the experience is moderated. Most data loss and most "the update kicked everyone and lost their last ten minutes" incidents happen at the end of that life. This note covers the stages of a server's life, the exact shutdown rules (`BindToClose`, `CloseReason`, the 30 second window), restarting servers for updates (`ServerRestartScheduled`, bleed-off, Roblox's automatic migration), the soft-shutdown pattern, and long-running server health.

Data-specific saving is covered in depth in [[Saving Correctly - Autosave and BindToClose]]; this note is the server-side frame around it.

## Stages of a server's life

| Stage | What happens | Your code |
|---|---|---|
| Start | The place version is loaded; server Scripts run; no players yet (usually) | Bootstrap: init then start ([[Project Structure and Bootstrapping]]) |
| First player | `PlayerAdded`; in Studio the first player may already exist before your scripts connect | Handle existing players as well as new ones |
| Running | Players join and leave; autosaves; live config polls | Periodic saves, health metrics |
| Restart scheduled | `DataModel.ServerRestartScheduled(restartTime, source, attributes)` fires (for developer restarts and Roblox maintenance) | Warn players, save, optionally move them yourself |
| Closing | Players are removed; `BindToClose` callbacks run (in parallel); server waits up to 30 s | Final saves, release locks, flush logs |
| Gone | Process ends | Nothing runs; unsaved state is lost |

Useful identity facts (Roblox docs): `game.JobId` is a UUID unique to this server instance (empty in Studio); `game.PlaceVersion` is the version the server runs; `game.PrivateServerId` identifies reserved and private servers.

## BindToClose: the rules

From the Roblox docs for `DataModel:BindToClose`:

- It binds a function to be called **before the server shuts down**. If the function accepts a parameter, it receives an `Enum.CloseReason`.
- You can bind **multiple functions**; they are called **in parallel**.
- The server waits **30 seconds** for all bound functions to finish, then shuts down even if they are still running.
- **Teleports are disabled during moderation shutdowns.**
- Use `RunService:IsStudio()` to avoid long waits when stopping a Studio playtest.
- If you use DataStores, use `BindToClose` to save all unsaved data.

`Enum.CloseReason` values: `Unknown`, `RobloxMaintenance`, `DeveloperShutdown`, `DeveloperUpdate` (migrated to a new place version), `ServerEmpty` (the last player left), `OutOfMemory`, `Moderation`.

### What the 30 seconds really buys

- DataStore writes take from tens of milliseconds to seconds each, and the per-server write budget still applies. Saving 50 players **sequentially** with retries can exceed 30 s. Save **in parallel**, one thread per player, and wait for all of them with a deadline (rule of thumb: stop waiting around 25 s so logging can finish).
- `PlayerRemoving` also fires for players removed at shutdown, so the same player may be saved by your leave handler and by `BindToClose` at the same time. Make saves **idempotent and serialised per player** (one save in flight per profile; a second request waits for or joins the first).
- `ServerEmpty` shutdowns happen after the last player left. Their saves already started in `PlayerRemoving`; `BindToClose` must **wait for in-flight saves** rather than return immediately, or the server can close mid-save.
- `OutOfMemory` closes are the worst time to need memory; keep save paths lean.

```lua
--!strict
-- ServerScriptService/Systems/Lifecycle.luau
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerData = require(script.Parent.PlayerData) -- exposes saveAndRelease(player): boolean, and inFlight(): number

local Lifecycle = {}
Lifecycle.closing = false
Lifecycle.closeReason = nil :: Enum.CloseReason?

local DEADLINE = 25 -- seconds; leave headroom inside the 30 s window

function Lifecycle.init()
	game:BindToClose(function(reason: Enum.CloseReason)
		Lifecycle.closing = true
		Lifecycle.closeReason = reason
		print(("[Lifecycle] closing: %s, %d players"):format(reason.Name, #Players:GetPlayers()))

		if RunService:IsStudio() then
			-- Still save in Studio if you test saving; just do not wait the full deadline.
			for _, player in Players:GetPlayers() do
				task.spawn(PlayerData.saveAndRelease, player)
			end
			task.wait(2)
			return
		end

		-- Save everyone still here, in parallel.
		local remaining = 0
		for _, player in Players:GetPlayers() do
			remaining += 1
			task.spawn(function()
				local ok, err = pcall(PlayerData.saveAndRelease, player)
				if not ok then warn("[Lifecycle] save failed: " .. tostring(err)) end
				remaining -= 1
			end)
		end

		-- Wait for these AND for saves already started by PlayerRemoving.
		local start = os.clock()
		while (remaining > 0 or PlayerData.inFlight() > 0) and os.clock() - start < DEADLINE do
			task.wait(0.1)
		end
		if remaining > 0 or PlayerData.inFlight() > 0 then
			warn(("[Lifecycle] deadline hit with %d pending saves"):format(remaining + PlayerData.inFlight()))
		end
	end)
end

return Lifecycle
```

Other systems can read `Lifecycle.closing` to stop starting new work (no new matches, no new trades, no new purchases prompts) once the server is going down.

## Restarting servers for an update

When you publish a new place version, existing servers keep running the old version. From the Roblox docs ("Release game updates", as of October 2026):

- If you do nothing, players move to the new version as old servers **eventually empty and shut down**.
- In the Creator Dashboard (**Configurations > Server management**) you can **Restart servers**; the recommended option is **Restart only servers with outdated versions**, which leaves servers already on the latest version alone.
- A **delay** (server bleed-off) of **1 to 60 minutes** lets players leave on their own first.
- On restart Roblox **stops matchmaking** into affected servers (invites, teleports and joins via friends still work), waits out the delay, then **automatically moves players to the updated version**; players from the same old server go to the same replacement server.
- Affected servers receive `DataModel.ServerRestartScheduled(restartTime, source, attributes)`. `restartTime` is a `DateTime` (the restart may be slightly later, never earlier); `source` is `DeveloperUpdate` for your updates and `RobloxMaintenance` for maintenance; `attributes` carries developer-supplied metadata (restarts can also be launched through Open Cloud).
- To fully shut the game down and prevent reconnection, revoke public access.

Older guides call this "Shut down all servers" or "Migrate to latest update". Community posts report that Roblox is consolidating those options (unverified; check the dashboard you have).

### Using `ServerRestartScheduled`

```lua
--!strict
-- Server: tell players about a scheduled restart and save early.
local Players = game:GetService("Players")

local Toasts = require(script.Parent.Toasts)
local PlayerData = require(script.Parent.PlayerData)

game.ServerRestartScheduled:Connect(function(restartTime: DateTime, source: Enum.CloseReason, attributes)
	local secondsLeft = math.max(0, restartTime.UnixTimestamp - DateTime.now().UnixTimestamp)
	local why = if source == Enum.CloseReason.DeveloperUpdate then "an update" else "maintenance"
	Toasts.all(("Server restarting for %s in %d minutes. Your progress is saved."):format(why, math.ceil(secondsLeft / 60)))

	-- Save now, while there is plenty of time, then again at close.
	for _, player in Players:GetPlayers() do
		task.spawn(PlayerData.saveSoon, player)
	end

	-- Optional: stop starting long activities that would be cut off.
	-- e.g. MatchSystem.acceptNewMatches = false when secondsLeft < 300
end)
```

## The soft-shutdown pattern (and when you still need it)

Before Roblox moved players automatically, games used a **soft shutdown**: in `BindToClose`, teleport every player to a reserved holding server, then teleport them back to a fresh server of the updated place. The aim was that players never see a disconnect.

Today, restarting through Server management already moves players to an updated server automatically, so many games no longer need a custom soft shutdown. Cases where a custom flow is still useful:

- You want players placed somewhere specific (back into their party's dungeon, or to the lobby rather than a random server).
- You need to run game logic first (end a match and pay out, close trades).
- You restart through other means and want to control timing.

Caveats:

- Teleports are **disabled during moderation shutdowns** (Roblox docs). A soft shutdown must not be the only thing protecting saves; save first, teleport second.
- `TeleportService` does not work in Studio, so test on a live private experience.
- A DevForum report says teleports from `BindToClose` misbehave during dashboard restarts; a Roblox staff reply says they work when you trigger the shutdown yourself (unverified; test it).
- Keep it short: everything must finish inside the 30 seconds, including your final saves.

A sketch:

```lua
--!strict
-- Server: soft shutdown on developer updates only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local isReservedServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0

game:BindToClose(function(reason: Enum.CloseReason)
	if RunService:IsStudio() or reason ~= Enum.CloseReason.DeveloperUpdate then return end
	local players = Players:GetPlayers()
	if #players == 0 then return end

	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	options:SetTeleportData({ softShutdown = true })
	-- Saves are handled by Lifecycle in parallel; this only moves people.
	pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players, options)
	end)
	task.wait(5)
end)

-- In the holding server: wait a few seconds, then send everyone to a public server of the new version.
local function onHoldingArrival(player: Player)
	if not isReservedServer then return end
	local data = player:GetJoinData().TeleportData
	if type(data) == "table" and data.softShutdown then
		task.wait(8)
		pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player })
		end)
	end
end
Players.PlayerAdded:Connect(onHoldingArrival)
```

The `softShutdown` flag in teleport data is only a hint; the worst an exploiter can do with it is send themselves to a public server.

## Long-running server health

Servers in popular games can run for many hours. Problems that only appear with uptime:

| Problem | Symptom | Defence |
|---|---|---|
| Memory leaks (connections, tables keyed by Player, debris) | Server memory climbs; eventually `OutOfMemory` close | Clean per-player tables on `PlayerRemoving`; Trove/Janitor; watch memory by uptime ([[Memory Budgets and Leaks]]) |
| Instance accumulation | Dropped items, projectiles, effects never destroyed | Lifetimes on everything spawned; `Debris` or explicit cleanup |
| Unbounded caches | Rate-limit tables, dedupe sets, seen-ids grow | TTLs and periodic sweeps |
| Drifting timers | Loops using accumulated waits drift | Schedule by absolute server time |
| Stale config | Live config changed hours ago, server never re-read | Poll and subscribe ([[Global State and Live Config]]) |

Log a heartbeat every few minutes with uptime, player count, memory and key counters (`Stats` service, [[Developer Console and Stats]]) so you can see degradation by server age. One production place grew to over a million instances in Studio (mostly backups and imported sources) and ran at 15 fps in Studio until cleaned; live servers pay for every instance in the place too ([[Case Study - Instance Cleanup and Place Size]]).

## Shutdown in Studio

- Stopping a playtest triggers `BindToClose` and `PlayerRemoving`. If your close handler waits 25 seconds, every stop takes 25 seconds; skip or shorten waits under `IsStudio()` (the docs recommend checking it).
- DataStores in Studio write to real stores only if API access is enabled for the experience. One production team routed Studio tests to isolated test keys (a `TestProfileKey` attribute on ServerStorage) so stopping a playtest could never overwrite a real profile.

## Diagnosing shutdown data loss

| Symptom | Cause |
|---|---|
| Last minutes of progress lost after updates | No `BindToClose`, or it returns before saves finish |
| Some players lost data, others fine | Sequential saves hitting the 30 s limit; save in parallel |
| Items duplicated after an update | Old server and new server both saved; no session lock |
| Data lost only when servers empty | `BindToClose` does not wait for saves started by `PlayerRemoving` |
| Stopping Studio takes forever | Waiting the full deadline in Studio |
| Players kicked with no warning on updates | Restart without bleed-off; no `ServerRestartScheduled` messaging |

## Common mistakes

| Mistake | Fix |
|---|---|
| One sequential save loop in `BindToClose` | Parallel saves with a deadline |
| `BindToClose` and `PlayerRemoving` saving the same profile concurrently | Per-player save serialisation; idempotent saves |
| Relying on soft-shutdown teleports to protect data | Save first; teleports can be disabled |
| Restarting all servers including up-to-date ones | "Restart only servers with outdated versions" |
| Ignoring `ServerRestartScheduled` | Warn players, save early, stop long activities |
| No uptime monitoring | Periodic health logs by server age |

## Checklist

- [ ] One `BindToClose` handler saves everyone in parallel and waits for in-flight saves, with a deadline under 30 s.
- [ ] Per-player saves are serialised and idempotent; profiles are session-locked.
- [ ] `ServerRestartScheduled` warns players and triggers early saves.
- [ ] Updates use outdated-only restarts with a bleed-off delay where appropriate.
- [ ] Systems check a `closing` flag before starting new long work.
- [ ] Long-running servers log uptime, memory and player counts.

## See also
[[Saving Correctly - Autosave and BindToClose]] · [[Session Locking and Profile Libraries]] · [[Data Loss Prevention and Recovery]] · [[Teleporting and Multi-Place Games]] · [[Release Process and Rollbacks]] · [[Live Ops Events and Updates]] · [[Memory Budgets and Leaks]] · [[Project Structure and Bootstrapping]]

## Connected notes
<!-- auto-links:start -->
[[Server Shutdowns Soft Updates and Migration]] · Places Universes and Experience Settings · Cookbook - Data and Saving · Live Incident Response and Post-Mortems · Reserved and Private Servers in Practice · Multiplayer Services Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Places Universes and Experience Settings]] · [[Cross-Server Messaging]] · [[Cookbook - Data and Saving]] · [[Client-Server Model]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Frameworks - Knit Matter and Others]]
<!-- related:end -->
