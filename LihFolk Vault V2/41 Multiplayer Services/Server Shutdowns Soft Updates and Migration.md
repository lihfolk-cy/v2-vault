---
tags: [multiplayer, updates, shutdown, migration, versioning, live-ops, configs, luau, strict, type/guide, area/networking, level/intermediate]
---
# Server Shutdowns Soft Updates and Migration

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No schema number in profiles -> Schema number plus guard
> - Avoid: Rename a field in one release -> Expand then contract
> - Avoid: Restarting the lobby before the match place -> Receiving side first; versioned contracts
> - Every persisted record and cross-place payload has a version.
> - Profile loader runs the schema guard; old builds never save newer data.
> - Schema changes ship as expand, then contract.
>
> Cost: TL;DR ~150 tok · whole note ~5.3k tok. Read more: ## 1. What Roblox does for you (and what it does not) · ## 5. The code · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Publishing a new version is the easy part. The hard part is the hour after: old and new servers running side by side, players hopping between them through invites and teleports, a lobby on version 41 sending players to a match place on version 17, a profile saved by new code being loaded and overwritten by old code, a match server cut off mid-round with rewards half granted. [[Server Lifecycle and Shutdown]] covers the mechanics (`BindToClose`, the 30 second window, `ServerRestartScheduled`, a basic soft shutdown). This note covers **migration**: how to move a live multi-server, multi-place game from one version to the next without data damage, without stranding parties, and with the fewest visible disconnects.

Related: [[Release Process and Rollbacks]], [[Data Schema Design and Migrations]], [[Schema Migrations - Worked Case Studies]], [[Global State and Live Config]], [[Session State Across Places]], [[Live Incident Response and Post-Mortems]].

## 1. What Roblox does for you (and what it does not)

From "Release game updates" (Roblox docs, as of October 2026):

- Publishing does **not** remove players from old versions. Without a restart, players move to the new version only as old servers empty and close. This is non-disruptive, but "your player base might be playing different versions of the game for a prolonged period of time"; the docs advise restarting if your player data format changes.
- **Configurations > Server management > Restart Servers**, with two options: **Restart only servers with outdated versions** (recommended unless your update flow is independent of place version) and **Delay server restart** of 1 to 60 minutes (server bleed-off).
- After a restart is launched, Roblox stops matchmaking into the affected servers (but invites, teleports and joining a user from their profile still reach them), waits for the delay, then **automatically teleports players to the updated version**, keeping players from one old server together on one replacement server.
- Affected servers receive `DataModel.ServerRestartScheduled(restartTime, source, attributes)`. `restartTime` is the earliest shutdown time (it may be later, never earlier). `source` is `DeveloperUpdate` for your restarts and `RobloxMaintenance` for infrastructure maintenance, which also fires the event (with empty attributes). `attributes` is optional developer metadata, and restarts can be launched through Open Cloud too.
- The docs also suggest a third route for time-sensitive releases: deploy early, hide content behind a **config**, then flip the config.
- `DataModel.PlaceVersion`: a new server uses the place's current version; a running server keeps its version when the place is updated.

What it does not do:

- It does not make your **data** compatible across versions.
- It does not coordinate **places**. Each place is restarted as you select it; a lobby and a match place can be on different versions for the whole bleed-off.
- It does not finish your **matches, trades or auctions**. Those end when the server ends unless your code finishes them.
- Whether the automatic move keeps players in their reserved or private server context is not stated on the page (unverified). Assume reserved-server match state is lost unless you persist it, and test with a live restart.

## 2. Version skew is the real problem

During any update window, assume all of these happen:

| Skew | How it happens | What breaks |
|---|---|---|
| Old server loads data saved by a new server | Player plays on new, rejoins a friend on old (invites still reach old servers) | Old code drops unknown fields on save; new items vanish |
| New server loads data saved by old server | Normal | Fine if new code migrates on load |
| Lobby new, match place old (or reverse) | Places restarted separately, or not at all | Teleport data or tickets in a shape the other side does not expect |
| Two servers, two versions, one MemoryStore structure | Always, during bleed-off | Old matchmaker forms matches with new rules |
| Client older than server | Not normally: clients load the server's version on join | Client code always matches its server; this one is safe |

The most damaging row is the first: **old code overwriting new data**. Roblox explicitly keeps old servers reachable through invites and teleports during bleed-off, so it will happen to some players on every update that changes the schema.

## 3. Rules that make updates safe

### Rule 1: every persisted record carries a schema version

A number in the profile root (`schema = 7`), incremented whenever the shape changes. Every server knows the highest schema it understands (`KNOWN_SCHEMA`).

### Rule 2: old code never writes newer data

When a server loads a profile whose `schema > KNOWN_SCHEMA`, it must not save that profile. Two acceptable responses:

- **Send the player to the new version.** Teleport them to a fresh public server of the same place (new servers start on the current version, Roblox docs). Best for most games.
- **Read-only session.** Let them play with saving disabled and a visible banner. Only acceptable when the session cannot earn anything important.

Kicking is the last resort; it reads as a crash.

### Rule 3: expand, then contract

Change schemas in two releases:

1. **Expand**: new code reads both old and new shapes, writes the new shape, but keeps writing old fields that old servers need. `schema` increments. Old servers that see the new schema refuse to write (rule 2), so nothing is lost.
2. **Contract**: once no server runs the old version (after a full restart), remove the old fields in a later release.

Never rename a field in one step. Renames are "add new, copy, stop reading old, later delete old". The worked cases in [[Schema Migrations - Worked Case Studies]] follow the same shape.

### Rule 4: cross-place messages are versioned contracts

Teleport data hints, MemoryStore tickets, match records and MessagingService payloads all get a `v` field. Receivers accept the current and the previous version and refuse anything newer than they know (with a clear path for the player, usually "return to lobby"). This lets the lobby and match places update in either order.

### Rule 5: features ship dark

Content and rule changes ship behind a config value that defaults to off ([[Global State and Live Config]]). Publish, restart outdated servers with a bleed-off, wait until the old version is gone, then flip the config. Everyone sees the feature at the same moment, regardless of which server they are on, and turning it off again is a config edit, not a rollback.

## 4. Draining a server on `ServerRestartScheduled`

When the event fires, the server has between 1 and 60 minutes (whatever delay you picked) and then a hard stop. Use the time to **drain**: stop starting long things, finish short things, save.

| System | Drain behaviour |
|---|---|
| Matchmaking | This server stops enqueuing new tickets; lobby UI says "Updating soon" |
| Rounds | Current round finishes; no new round starts if it cannot finish before `restartTime` |
| Trades and auctions | New trades refused; open trades completed or cancelled atomically |
| Server browser | Registry entry marked draining or removed so nobody picks it |
| Parties | Gathering into this server blocked |
| Saves | One early save for everyone; normal autosave continues |

The `attributes` argument lets one restart carry instructions. When you launch restarts through Open Cloud, put a small JSON object in it, for example `{ "reason": "hotfix", "urgent": true }`, and let the server choose its drain policy from it. Maintenance restarts arrive with empty attributes, so code must have a default.

## 5. The code

The module below is the coordinator a server runs at boot. It owns the drain state, the schema guard and the move-to-new-version path. Other systems ask it questions (`canStartRound`, `canSave`) rather than listening to the restart event themselves.

```lua
--!strict
-- ServerScriptService/Live/UpdateCoordinator.luau
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local KNOWN_SCHEMA = 7          -- highest profile schema this build understands
local CONTRACT_VERSION = 3      -- version of teleport/ticket payloads this build writes
local OLDEST_CONTRACT = 2       -- oldest payload version this build still accepts

export type DrainReason = "None" | "DeveloperUpdate" | "Maintenance"

local UpdateCoordinator = {}

local draining = false
local drainReason: DrainReason = "None"
local restartAt = math.huge
local urgent = false
local readOnly: { [number]: boolean } = {} -- userId -> loaded a profile newer than this build

local drainChanged = Instance.new("BindableEvent")
UpdateCoordinator.DrainChanged = drainChanged.Event

------------------------------------------------------------------ queries

function UpdateCoordinator.isDraining(): boolean
	return draining
end

function UpdateCoordinator.secondsLeft(): number
	return math.max(0, restartAt - DateTime.now().UnixTimestamp)
end

-- Rounds, raids, trades: may this activity of `duration` seconds start now?
function UpdateCoordinator.canStart(duration: number): boolean
	if not draining then
		return true
	end
	-- Leave 30 s of slack for payout and saves.
	return UpdateCoordinator.secondsLeft() > duration + 30
end

function UpdateCoordinator.canSave(userId: number): boolean
	return not readOnly[userId]
end

------------------------------------------------------------------ versioned payloads

function UpdateCoordinator.stamp(payload: { [string]: any }): { [string]: any }
	payload.v = CONTRACT_VERSION
	return payload
end

function UpdateCoordinator.acceptPayload(payload: any): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "malformed"
	end
	local v = tonumber(payload.v)
	if not v then
		return false, "unversioned"
	elseif v > CONTRACT_VERSION then
		return false, "newer" -- the sender runs a newer build; route the player to a fresh server
	elseif v < OLDEST_CONTRACT then
		return false, "too old"
	end
	return true, nil
end

------------------------------------------------------------------ schema guard

-- Call right after a profile loads. Returns false if the player was moved away.
function UpdateCoordinator.checkProfileSchema(player: Player, schema: number): boolean
	if schema <= KNOWN_SCHEMA then
		return true
	end
	readOnly[player.UserId] = true
	player:SetAttribute("UpdateBanner", "A newer version of the game is available. Moving you there...")
	if RunService:IsStudio() then
		return true -- teleports do not work in Studio; stay read-only
	end
	-- A fresh public server of this place runs the current published version.
	local ok, err = pcall(function()
		return TeleportService:TeleportAsync(game.PlaceId, { player })
	end)
	if not ok then
		warn(`[Update] could not move {player.UserId} to new version: {err}`)
		player:SetAttribute("UpdateBanner", "Progress is not being saved on this server. Please rejoin.")
	end
	return false
end

------------------------------------------------------------------ drain

local function parseAttributes(attributes: any)
	if type(attributes) == "table" and attributes.urgent == true then
		urgent = true
	end
end

local function beginDrain(restartTime: DateTime, source: Enum.CloseReason, attributes: any)
	draining = true
	drainReason = if source == Enum.CloseReason.DeveloperUpdate then "DeveloperUpdate" else "Maintenance"
	restartAt = restartTime.UnixTimestamp
	parseAttributes(attributes)
	workspace:SetAttribute("Draining", true)
	workspace:SetAttribute("RestartAt", restartAt)
	drainChanged:Fire(drainReason, restartAt)
end

function UpdateCoordinator.init(saveAllNow: () -> ())
	game.ServerRestartScheduled:Connect(function(restartTime: DateTime, source: Enum.CloseReason, attributes: any)
		beginDrain(restartTime, source, attributes)
		-- Save early while there is plenty of time; BindToClose saves again at the end.
		task.spawn(saveAllNow)
		if urgent then
			-- An urgent hotfix: end activities now rather than letting them run to the deadline.
			drainChanged:Fire("Urgent", restartAt)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		readOnly[p.UserId] = nil
	end)
end

return UpdateCoordinator
```

How other systems use it:

```lua
--!strict
-- Inside a round system
local UpdateCoordinator = require(script.Parent.Parent.Live.UpdateCoordinator)

local ROUND_LENGTH = 300

local function tryStartRound(): boolean
	if not UpdateCoordinator.canStart(ROUND_LENGTH) then
		-- Show "Server updating in N min: final round complete" and send players to the lobby
		-- or let them idle until the automatic move.
		return false
	end
	-- start the round...
	return true
end

-- Inside the profile save path
local function save(player: Player, profile: { schema: number })
	if not UpdateCoordinator.canSave(player.UserId) then
		return -- never let this build write data from a newer build
	end
	-- normal session-locked save...
end
```

The schema guard belongs in the profile loader, before any gameplay touches the data. With a session-locking library ([[Session Locking and Profile Libraries]]), release the lock without saving when the guard fails, so the newer server the player is moving to can claim it immediately.

## 6. Multi-place releases

A lobby plus match place plus event place is three independent version streams. A safe order (rule of thumb):

1. **Publish the receiving side first.** If the lobby will start sending `v = 3` tickets, publish the match place that accepts `v = 3` (and still accepts `v = 2`) first.
2. Restart outdated servers of the receiving place with a short delay (match places usually have short sessions; 5 to 10 minutes).
3. Publish the sending side (lobby). Restart outdated lobby servers with a longer bleed-off (15 to 30 minutes).
4. Flip the config that enables the new behaviour.
5. Next release: drop acceptance of `v = 2`.

If you cannot order them (a hotfix touching both), the contract rule still protects you: a match server that receives a newer payload than it understands sends the player back to the lobby with a message instead of misreading the data.

## 7. Custom soft shutdowns, when they still earn their keep

The automatic move covers ordinary public servers. A custom flow is still worth it when the destination matters:

- **Match and dungeon servers**: the automatic move does not know that eight players were mid-run. On drain, finish the run early with prorated rewards written on this server, then teleport the group back to the lobby (or to a new reserved server of the updated match place with a resume record in a store; see [[Session State Across Places]]).
- **Persistent rooms** (houses, guild halls, private-server style rooms): save room state keyed by `PrivateServerId`, then let the move happen or teleport the room's players back to the same room code, which starts a new instance on the new version.
- **Parties across servers**: if an update splits a gathering party, the gather record from [[Parties and Group Teleports]] lets the lobby re-gather them.

Hard rules for any custom flow:

- **Save first, teleport second.** Teleports are disabled during moderation shutdowns (Roblox docs, see [[Server Lifecycle and Shutdown]]), and a teleport can fail. Data must be safe even if nobody moves.
- **Do the work in `ServerRestartScheduled`, not in `BindToClose`.** You have minutes in the first and 30 seconds in the second. A soft shutdown that starts in `BindToClose` competes with your final saves for the same 30 seconds.
- **Use a reserved server as the next destination only if it will run the new version.** A new server instance takes the place's current version (Roblox docs), so a server reserved and started after publishing is on the new version. Teleporting to a public server of the same place without options can land in another **old** server that is still bleeding off; reserving avoids that.
- **Keep one owner of the move.** If both your code and Roblox's automatic move act, players get two teleports. Either finish your flow before `restartTime`, or do nothing and let Roblox move them.

## 8. Emergencies

| Situation | First move | Then |
|---|---|---|
| Bad update, no data impact | Revert in Version History, publish, restart outdated with 1 to 5 min delay | Post-mortem ([[Live Incident Response and Post-Mortems]]) |
| Bug that corrupts saves | Config kill switch `savesFrozen = true` so servers stop writing (code must honour it) | Fix, migrate, unfreeze; restore from versions ([[Data Loss Prevention and Recovery]]) |
| Exploit in an economy feature | Config flag disabling the feature | Patch, restart, re-enable |
| Need everyone out now | Restart all servers with no delay | To keep them out, revoke public access (Roblox docs) |

A `savesFrozen` switch is only useful if it already exists in the code that is running. Add it before you need it, test it on one server with a testing value (the configs testing override is described in [[Global State and Live Config]]), and make the frozen state visible to players ("saving paused for maintenance") so they do not grind progress that will not stick.

Rolling back code does not roll back data. If new code wrote `schema = 8` profiles and you revert to a build that knows 7, the schema guard makes the old build refuse to save those profiles, which is correct but painful. Prefer a forward fix. If you must roll back, ship the rollback with `KNOWN_SCHEMA = 8` and a reader that tolerates the new fields.

## 9. Measuring an update

- Before: note CCU and servers per version (log `PlaceVersion` in your analytics events, [[Analytics and Funnels]]).
- During: watch how many servers remain on the old version and how many players hit the schema guard (log it). A high guard count means many old-version joins through invites; consider a shorter delay next time.
- After: compare session length and day-1 return for players moved during the update to normal days. Disconnect-heavy updates show up as a dip.

## 10. When a simple approach is enough

A single-place game with no persistent schema change and no long activities can publish and either do nothing (eventual migration) or restart outdated servers with a 10 to 15 minute delay. Everything above is for games where data shape changes, places talk to each other, or a cut-off activity costs players something.

## Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| No schema number in profiles | Old servers silently drop new fields | Schema number plus guard |
| Rename a field in one release | Half the population loses the field | Expand then contract |
| Restarting the lobby before the match place | Lobby sends payloads the match place cannot read | Receiving side first; versioned contracts |
| Starting a 10 minute round with 3 minutes left | Rewards cut off, angry players | `canStart(duration)` |
| Soft shutdown inside `BindToClose` only | Races final saves in 30 s | Act on `ServerRestartScheduled` |
| Teleporting to a public server of the same place to "update" players | Lands on another old server | Reserve, or let Roblox move them |
| Kill switch added during the incident | Too late; the running build lacks it | Ship switches ahead of time |
| Rolling back code over migrated data | Old build mangles new profiles | Forward fix, or a rollback that knows the new schema |

## Checklist

- [ ] Every persisted record and cross-place payload has a version.
- [ ] Profile loader runs the schema guard; old builds never save newer data.
- [ ] Schema changes ship as expand, then contract.
- [ ] `ServerRestartScheduled` drives a drain state that other systems query.
- [ ] Multi-place release order written down: receiving side first.
- [ ] Features ship dark behind configs; flipped after bleed-off.
- [ ] `savesFrozen` and feature kill switches exist and are tested.
- [ ] Update metrics logged per `PlaceVersion`.

## See also
[[Multiplayer Services Start Here]] · [[Server Lifecycle and Shutdown]] · [[Release Process and Rollbacks]] · [[Data Schema Design and Migrations]] · [[Schema Migrations - Worked Case Studies]] · [[Global State and Live Config]] · [[Session Locking and Profile Libraries]] · [[Session State Across Places]] · [[Parties and Group Teleports]] · [[Live Ops Events and Updates]]

## Connected notes
<!-- auto-links:start -->
[[Places Universes and Experience Settings]] · Data Schema Versioning · [[Reserved and Private Servers in Practice]] · Teleporting and Multi-Place Games · Publishing an Experience · Build Test and Release Pipeline
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Server Browsers and Server Lists]] · [[Server Hop Rejoin and Server Lists with Ping]] · [[Publishing an Experience]] · [[Matchmaking Queues with MemoryStore]] · [[Patch Notes and Player Communication]] · [[Build Test and Release Pipeline]]
<!-- related:end -->
