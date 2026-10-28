---
tags: [multiplayer, reserved-servers, private-servers, teleport, monetization, datastore, luau, strict]
---
# Reserved and Private Servers in Practice

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Treating `PrivateServerId ~= ""` as "player-owned" -> Check `PrivateServerOwnerId` too
> - Avoid: Owner check on the client -> Server check every call
> - Avoid: Keying room state by `JobId` -> Key by `PrivateServerId`
> - One `ServerKind` module; no ad-hoc checks.
> - Private server price chosen with "permanent" in mind; free option considered.
> - Owner and co-owner powers validated server-side, keyed by `PrivateServerId`.
>
> Read more (21 KB note): ## 2. Private servers as a product · ## 3. Reserved servers as a building block · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox has two kinds of server that matchmaking never fills: **private servers** that players buy or get for free from your game page, and **reserved servers** that your code creates with `TeleportService:ReserveServerAsync`. Both report a non-empty `game.PrivateServerId`, both can run many server instances over their lifetime, and both change what your game should do: who has admin powers, whether rewards should be limited, whether a match that already ended may restart, how a player-shared "room code" maps to a real server. This note is the practical layer on top of the reserved-server basics in [[Teleporting and Multi-Place Games]] and the social framing in [[Social Design and Multiplayer Play]].

Related in this section: [[Matchmaking Queues with MemoryStore]], [[Parties and Group Teleports]], [[Server Browsers and Server Lists]], [[Server Shutdowns Soft Updates and Migration]].

## 1. Three server kinds and how to tell them apart

| Kind | Created by | `PrivateServerId` | `PrivateServerOwnerId` | Matchmaking fills it |
|---|---|---|---|---|
| Public | Roblox matchmaking | `""` | `0` | Yes |
| Reserved | Your code (`ReserveServerAsync` or `ShouldReserveServer`) | non-empty | `0` | No |
| Private | A player, from the game page | non-empty | owner's UserId | No |

Facts behind the table (Roblox docs, as of October 2026):

- `DataModel.PrivateServerId` is empty for normal servers and set for both private and reserved servers.
- `DataModel.PrivateServerOwnerId` is the owner's UserId for a private server and `0` for standard and reserved servers.
- The documented reserved-server check is `game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0`.
- A private or reserved server can have many server instances over time, but **only one runs at once**; when nobody is playing, no instance is running. `PrivateServerId` stays the same across those instances; `JobId` is unique for each.
- Exception: Xbox and PlayStation players with cross-play disabled arrive in a different server than cross-play players, so several instances can share one `PrivateServerId` at the same moment. `DataModel.MatchmakingType` (`Default`, `XboxOnly`, `PlayStationOnly`) tells them apart. It is only valid on the server.
- Custom matchmaking skips full, private, reserved and shutting-down servers when placing a joining player.

Put the detection in one module so every system asks the same question the same way:

```lua
--!strict
-- ReplicatedStorage/Shared/ServerKind.luau (server and client can read it, but only the server's answer is trusted)
export type Kind = "Public" | "Reserved" | "Private"

local ServerKind = {}

function ServerKind.get(): Kind
	if game.PrivateServerId == "" then
		return "Public"
	elseif game.PrivateServerOwnerId == 0 then
		return "Reserved"
	else
		return "Private"
	end
end

-- The stable identity of "this server" across restarts of a private or reserved server.
function ServerKind.stableId(): string
	if game.PrivateServerId ~= "" then
		return game.PrivateServerId
	end
	return game.JobId
end

return ServerKind
```

On the client these properties are not replicated (they are tagged `NotReplicated` in the API reference), so do not read them there. The server should publish the kind as an attribute on a replicated object (for example `workspace:SetAttribute("ServerKind", ...)`) if the UI needs it.

## 2. Private servers as a product

### The rules (Roblox docs, as of October 2026)

- The game must be **public** before you can enable private servers. Enable them in the Creator Dashboard under **Audience > Access Settings > Allow private servers**.
- A private server is a **monthly subscription**. Toggle **Requires Robux** and set a price, or leave it off to make them free.
- **Changing the price cancels all active subscriptions**, and players are messaged about it. Treat the price as nearly permanent.
- You cannot enable **paid access** (Robux or local currency) and private servers at the same time.
- Players under 13 may not be able to join private servers, depending on their privacy and parental control settings.
- Roblox Plus subscribers get paid private servers at no cost; you still earn **up to 100 Robux per subscriber each month** based on the time they spend in your paid private servers.

Roblox's design guidance (cited in [[Social Design and Multiplayer Play]]) warns against pricing private servers so high that friend groups are discouraged. A free or cheap private server is a retention feature: groups that can play alone together come back together ([[Retention and Return Hooks]]).

### Pricing as a decision, not a guess

Because a price change cancels every subscription, pick a price you can live with for years. Rules of thumb:

- If your game's core is social (roleplay, hangout, co-op), keep it free or at the low end; the value is in sessions.
- If private servers give a real gameplay edge (farming without competition), price it like a monthly game pass and make sure the edge is bounded (next section).
- Never lower the price "for a sale". A sale cancels everyone's subscription. Run sales on other products ([[Pricing and Store Design]], [[Subscriptions and Premium Payouts]]).

### What changes inside a private server

A private server is your game with a guest list. Things to decide explicitly:

| System | Public server | Private server, common choice |
|---|---|---|
| Owner powers | None | Kick, set time of day, pick map or event, toggle PvP |
| Global leaderboards | Submit | Submit, but watch for solo-farmed records; some games flag them |
| World bosses and timed events | Shared and scarce | Same schedule, or owner-triggered on a cooldown |
| Resource spawns | Tuned for a full server | Tuned for headcount, not for "one player gets everything" |
| Trading | Open | Open; scams among friends still happen |
| Moderation | Standard | Standard; owner powers must never bypass safety |

**Owner powers must be server-checked.** A remote like `OwnerCommand` validates that `player.UserId == game.PrivateServerOwnerId` on the server, every call, and that the command is in an allow-list. Never trust a client flag that says "I am the owner". Also consider "co-owners": a list the owner sets, stored by `PrivateServerId` in a data store, so the setting survives instance restarts.

```lua
--!strict
-- ServerScriptService/PrivateServer/OwnerCommands.luau
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerKind = require(ReplicatedStorage.Shared.ServerKind)

local settingsStore = DataStoreService:GetDataStore("PrivateServerSettings_v1")
local remote = ReplicatedStorage.Remotes.OwnerCommand :: RemoteEvent

type Settings = { coOwners: { number }, pvp: boolean, timeOfDay: number }
local DEFAULTS: Settings = { coOwners = {}, pvp = false, timeOfDay = 14 }

local settings: Settings = table.clone(DEFAULTS)
local lastCall: { [number]: number } = {}

local function isOwner(player: Player): boolean
	if ServerKind.get() ~= "Private" then
		return false
	end
	return player.UserId == game.PrivateServerOwnerId or table.find(settings.coOwners, player.UserId) ~= nil
end

local function load()
	if ServerKind.get() ~= "Private" then
		return
	end
	local ok, data = pcall(function()
		return settingsStore:GetAsync(game.PrivateServerId)
	end)
	if ok and type(data) == "table" then
		settings.pvp = data.pvp == true
		settings.timeOfDay = math.clamp(tonumber(data.timeOfDay) or DEFAULTS.timeOfDay, 0, 24)
		settings.coOwners = if type(data.coOwners) == "table" then data.coOwners else {}
	elseif not ok then
		warn("[PrivateServer] settings load failed; using defaults for this instance")
	end
end

local function save()
	pcall(function()
		settingsStore:SetAsync(game.PrivateServerId, settings)
	end)
end

local handlers: { [string]: (player: Player, arg: any) -> () } = {
	SetPvP = function(_player, arg)
		if type(arg) == "boolean" then
			settings.pvp = arg
			workspace:SetAttribute("PvP", arg)
		end
	end,
	SetTime = function(_player, arg)
		if type(arg) == "number" and arg == arg then -- reject NaN
			settings.timeOfDay = math.clamp(arg, 0, 24)
			game:GetService("Lighting").ClockTime = settings.timeOfDay
		end
	end,
	Kick = function(player, arg)
		if type(arg) ~= "number" then
			return
		end
		local target = Players:GetPlayerByUserId(arg)
		-- Only the real owner may kick, and nobody may kick the owner.
		if target and player.UserId == game.PrivateServerOwnerId and target.UserId ~= game.PrivateServerOwnerId then
			target:Kick("Removed by the server owner.")
		end
	end,
}

remote.OnServerEvent:Connect(function(player: Player, command: unknown, arg: unknown)
	local now = os.clock()
	if now - (lastCall[player.UserId] or 0) < 0.5 then
		return -- rate limit
	end
	lastCall[player.UserId] = now
	if type(command) ~= "string" or not isOwner(player) then
		return
	end
	local handler = handlers[command]
	if handler then
		handler(player, arg)
		task.defer(save)
	end
end)

Players.PlayerRemoving:Connect(function(p)
	lastCall[p.UserId] = nil
end)

load()
```

Save settings sparingly in production (debounce to one write per 10 s or on `BindToClose`); the per-key write limits of data stores apply ([[DataStore Fundamentals]]).

### Bounding the farming edge

Private servers remove competition for spawns, bosses and drops. If rewards are tied to world spawns tuned for 20 players, a solo player in a private server collects 20 players' worth. Fixes (rule of thumb):

- Tie spawn rates to **headcount**: `rate = base * max(1, players) / fullServer`.
- Tie personal rewards to **personal effort** (kills, completed objectives) rather than to world availability.
- Cap per-player per-hour gains for the scarcest items, in every server kind, so private servers are not special-cased.
- Watch analytics for reward rates by server kind ([[Analytics and Funnels]]). If private-server players earn three times as much per hour, you will see it.

## 3. Reserved servers as a building block

The reserved-server guarantees that drive every pattern below (Roblox docs, as of October 2026):

- `ReserveServerAsync(placeId)` is server-only and returns an **access code** and the server's `PrivateServerId`.
- A server starts **when the code is first used**.
- **Access codes stay valid indefinitely**: if no server is running for the code, a new one starts.
- `TeleportAsync` with `ReservedServerAccessCode` enters it; `ShouldReserveServer = true` reserves and enters in one call, and `TeleportAsyncResult` then reports the new `ReservedServerAccessCode` and `PrivateServerId` so you can send more people later.
- Teleports, and so reserved servers, do not work in Studio playtests.

Four patterns come out of those guarantees.

### Pattern A: one-shot instances (matches, dungeon runs)

Reserve, teleport the group, play, send everyone back. The trap is the word "indefinitely". A player who saved the code (they cannot see it unless you leak it, but your own rejoin logic might store it) or a teleport retry that lands after the match ended will **start a fresh, empty instance** of the same reserved server with the same `PrivateServerId`. The new instance knows nothing about the old one.

Guard: write a **run record** keyed by `PrivateServerId` (or by a run id carried in teleport data and stored server-side), and on every new instance read it before admitting anyone. If the run is finished, send arrivals back to the lobby.

```lua
--!strict
-- ServerScriptService/Run/RunGuard.luau (match or dungeon place)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local LOBBY_PLACE_ID = 0
local runs = DataStoreService:GetDataStore("Runs_v1") -- durable; MemoryStore works if runs are short

type RunState = "Open" | "Running" | "Finished"

local RunGuard = {}
local state: RunState = "Open"

local function sendToLobby(players: { Player })
	if #players == 0 then
		return
	end
	local ok = pcall(function()
		return TeleportService:TeleportAsync(LOBBY_PLACE_ID, players)
	end)
	if not ok then
		for _, p in players do
			p:Kick("This session has ended. Please rejoin from the lobby.")
		end
	end
end

function RunGuard.init(): RunState
	local id = game.PrivateServerId
	if id == "" then
		-- Someone reached the match place through a public server: access settings are wrong.
		state = "Finished"
	else
		local ok, stored = pcall(function()
			return runs:GetAsync(id)
		end)
		if ok and type(stored) == "table" and stored.state == "Finished" then
			state = "Finished"
		elseif not ok then
			-- Data store down: the safe default for a one-shot run is to refuse rather than replay rewards.
			state = "Finished"
		end
	end
	if state == "Finished" then
		Players.PlayerAdded:Connect(function(p)
			sendToLobby({ p })
		end)
		sendToLobby(Players:GetPlayers())
	end
	return state
end

function RunGuard.markRunning()
	state = "Running"
end

function RunGuard.markFinished()
	state = "Finished"
	local id = game.PrivateServerId
	pcall(function()
		runs:SetAsync(id, { state = "Finished", at = os.time() })
	end)
end

return RunGuard
```

The "data store down means refuse" choice is deliberate: for a run that grants rewards, replaying is worse than an annoyed player. For a casual minigame the opposite default may be right. Write down which you chose.

### Pattern B: persistent rooms (houses, guild halls, player-made worlds)

A player's house, a guild hall, a custom map: one reserved server per room, entered any time. Store the access code durably, keyed by the room id, and reserve lazily the first time anyone enters.

```lua
--!strict
-- ServerScriptService/Rooms/RoomDirectory.luau
local DataStoreService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")

local ROOM_PLACE_ID = 0
local directory = DataStoreService:GetDataStore("RoomDirectory_v1")

type RoomEntry = { accessCode: string, privateServerId: string, owner: number, createdAt: number }

local RoomDirectory = {}
local cache: { [string]: RoomEntry } = {}

-- Returns the room's access code, reserving a server the first time. Server only.
function RoomDirectory.resolve(roomId: string, owner: number): RoomEntry?
	local hit = cache[roomId]
	if hit then
		return hit
	end
	-- Reserve first (cheap and harmless if unused), then commit atomically.
	local okReserve, code, psid = pcall(function()
		return TeleportService:ReserveServerAsync(ROOM_PLACE_ID)
	end)
	if not okReserve or type(code) ~= "string" then
		return nil
	end
	local now = os.time()
	local ok, entry = pcall(function()
		return directory:UpdateAsync(roomId, function(old: any)
			if type(old) == "table" and type(old.accessCode) == "string" then
				return nil -- someone else created it first; keep theirs
			end
			return { accessCode = code, privateServerId = psid, owner = owner, createdAt = now }
		end)
	end)
	if not ok then
		return nil
	end
	if entry == nil then
		-- Our write was cancelled because the room exists; read the winner.
		local okGet, existing = pcall(function()
			return directory:GetAsync(roomId)
		end)
		if not okGet or type(existing) ~= "table" then
			return nil
		end
		entry = existing
	end
	cache[roomId] = entry :: RoomEntry
	return entry :: RoomEntry
end

return RoomDirectory
```

`DataStore:UpdateAsync` returning `nil` from the transform cancels the write and the call returns `nil`, which is why the code reads the winner afterwards. The unused reservation from a lost race costs nothing measurable (rule of thumb: an unused access code never starts a server).

Inside the room server, key room state (furniture, permissions, visit count) by `game.PrivateServerId`, which is stable across instances. Load on start, save on change and at `BindToClose` ([[Saving Correctly - Autosave and BindToClose]]). Two instances can exist at once only in the cross-play case above; if room edits matter, use `UpdateAsync` with a version number so two instances cannot overwrite each other blindly.

### Pattern C: shareable room codes

Players love "join code: K7QF2M". Never make the access code the shareable code. Generate a short human code, store `code -> roomId` in a data store, and resolve it on the server.

- Alphabet without lookalikes (no 0/O, 1/I/L): 30 symbols, 6 characters is 30^6, about 729 million codes. Rate-limit lookups per player (for example 5 per minute) so nobody brute-forces private rooms.
- Let owners rotate the code (new code, old mapping deleted) and set the room to friends-only, checking friendship on arrival with `Player:IsFriendsWith` on the server.
- Filter any room **name** with `TextService` before showing it to others; room names are user-generated text ([[Server Browsers and Server Lists]] covers filtering for listings).

### Pattern D: holding and utility servers

A reserved server is the standard "holding pen" for the soft-shutdown pattern in [[Server Lifecycle and Shutdown]], a waiting room while a party gathers ([[Parties and Group Teleports]]), or a one-player tutorial instance that cannot be griefed. Utility servers should be **stateless**: they read what they need from teleport data hints plus server-side stores and send players on.

## 4. Capacity, cost and access

- A reserved server has the same max players as its place. A party of 10 into a place with max 8 fails for two members. Check sizes before reserving.
- Every reserved instance is a full server. A design that reserves a server per player (solo instancing) can multiply server count by your CCU. Roblox does not publish a charge for this (not documented on the pages checked), but each server has its own memory budget and start-up cost, and players wait for a cold start. Batch where the design allows.
- Access: reserved servers usually live in **non-start places**. Set **Access Control for Places** to **Secure within universe only** so those places can only be entered through server-initiated teleports (Roblox docs, see [[Teleporting and Multi-Place Games]]). Otherwise a client can try to enter a match place directly and land in a public server of it, which `RunGuard` above treats as finished.

## 5. Testing

- `ServerKind` logic can be unit-tested by injecting the three property values ([[Testing Strategies and Frameworks]]).
- Private-server behaviour needs a published experience with private servers enabled (free is fine for a test universe). Buy one with a test account and verify owner commands, co-owner persistence and spawn scaling.
- Reserved-server patterns need live teleports. Keep a separate private test universe so test rooms and runs never share stores with production ([[Places Universes and Experience Settings]]).

## Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Treating `PrivateServerId ~= ""` as "player-owned" | Reserved servers get owner logic with owner 0 | Check `PrivateServerOwnerId` too |
| Owner check on the client | Anyone runs owner commands | Server check every call |
| Keying room state by `JobId` | Room resets every time it empties | Key by `PrivateServerId` |
| Changing private server price for a promotion | All subscriptions cancelled | Treat price as permanent |
| Reused match codes replaying rewards | Free loot from finished runs | Run record checked on every instance start |
| Access code as the shareable room code | Codes leak; anyone can enter forever | Short human code mapped server-side |
| Spawns tuned only for full public servers | Private-server farming | Scale by headcount, cap scarce rewards |
| Match places open to direct joins | Public servers of a match place | Secure within universe only |

## Checklist

- [ ] One `ServerKind` module; no ad-hoc checks.
- [ ] Private server price chosen with "permanent" in mind; free option considered.
- [ ] Owner and co-owner powers validated server-side, keyed by `PrivateServerId`.
- [ ] Reward and spawn rates hold up in a one-player private server.
- [ ] One-shot reserved servers check a run record before admitting anyone.
- [ ] Persistent rooms store codes durably with an atomic create.
- [ ] Shareable codes are separate from access codes and rate-limited.
- [ ] Access Control for Places set to Secure within universe only for instance places.

## See also
[[Multiplayer Services Start Here]] · [[Teleporting and Multi-Place Games]] · [[Social Design and Multiplayer Play]] · [[Parties and Group Teleports]] · [[Matchmaking Queues with MemoryStore]] · [[Server Browsers and Server Lists]] · [[Server Lifecycle and Shutdown]] · [[Pricing and Store Design]] · [[Places Universes and Experience Settings]] · [[DataStore Fundamentals]]

## Connected notes
<!-- auto-links:start -->
[[Links - Reserved and private servers]] · [[Session State Across Places]] · [[Links - Teleporting]] · [[Resource Library - Networking and Multiplayer]] · [[Cross-Server Messaging]] · [[Monetization Overview]]
<!-- auto-links:end -->
