---
tags: [multiplayer, parties, teleport, socialservice, reserved-servers, messagingservice, luau, strict]
---
# Parties and Group Teleports

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Assuming one `TeleportAsync` moves the whole party -> It moves only players in this server; gather the rest
> - Avoid: Two servers teleporting the same party to a public place without... -> Reserve, or reunite first then teleport once
> - Avoid: Trusting teleport data for party membership -> Gather record in MemoryStore
> - `PartyId` read on the server; changes handled between rounds.
> - One reservation per gather; code stored server-side only.
> - Gather record with short TTL; message plus manual rejoin for reliability.
>
> Read more (23 KB note): ## 5. The code · ## 6. The destination: an arrival barrier · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Friends who arrive together and get split by a teleport stop playing together, and players who stop playing together stop playing. Keeping a group whole across servers and places is one of the highest-value multiplayer features you can build, and one of the easiest to get subtly wrong: one member is in another server, one is mid-teleport, one has a flaky connection, the destination fills up, the leader leaves. This note covers Roblox's own party data (`Player.PartyId` and `SocialService`), when to run your own party system instead, the exact behaviour of group teleports, gathering a party spread over several servers, the arrival barrier on the destination, and every failure path, with strict Luau.

Prerequisites: [[Teleporting and Multi-Place Games]] (TeleportAsync, TeleportOptions, `TeleportInitFailed`, arrival validation), [[Cross-Server Messaging]] (MessagingService limits). Related: [[Matchmaking Queues with MemoryStore]] (a party is one ticket), [[Session State Across Places]] (what the party carries), [[Social Design and Multiplayer Play]] (why groups matter).

## 1. Two kinds of party

| | Roblox party | Your own in-game party |
|---|---|---|
| Created by | Players, through the Roblox Party feature | Your UI: invite, accept, kick |
| Identifier | `Player.PartyId` (string, empty when not in a party) | Your own id in a MemoryStore hash map |
| Membership truth | Roblox | Your server code |
| Cross-server lookup | `SocialService:GetPartyAsync(partyId)` | Your hash map |
| Works before the player joins your game | Yes, they party up first | No |
| Rules you can enforce | None (you cannot change who is in it) | Size, level gates, leader powers |
| Persists after the session | Not your concern | Only if you save it |

From the Roblox docs (as of October 2026):

- `Player.PartyId` is a read-only string; empty when the player is not in a party. It is tagged not replicated, so read it on the server. React to changes with `player:GetPropertyChangedSignal("PartyId")`, which the official samples use.
- `SocialService:GetPlayersByPartyId(partyId)` returns the connected `Player` objects **in this server** whose `PartyId` matches. It does not yield.
- `SocialService:GetPartyAsync(partyId)` yields and returns an array of dictionaries for all members **currently in the experience, across all servers**, ordered by the time each member accepted the party invite (first element is the earliest). Each entry has `UserId`, `PlaceId`, `JobId`, `PrivateServerId` (when in a private or reserved server) and `ReservedServerAccessCode` (when in a reserved server, so you can teleport other members to them).
- Studio has a **Party Simulator** in the Server and Clients test mode: it assigns test players to simulated parties, sets their `PartyId`, and makes both `SocialService` calls return simulated data.

Use the Roblox party whenever it exists: it is the group the players themselves chose, before they even loaded in. Build your own party only for things the platform party cannot express: a party formed from strangers in your lobby, a size cap tied to a mode, a guild squad that persists across sessions, or a leader role with powers. Many games do both: on join, seed the in-game party from `PartyId`, then let players edit it.

Who can create Roblox parties, and on which platforms, is not described on the reference pages (unverified). Design so that "no party" is the normal case and a party is a bonus.

## 2. What a group teleport actually guarantees

`TeleportService:TeleportAsync(placeId, players, options)` (Roblox docs, as of October 2026):

- Server only.
- At most **50 players** per call.
- Groups can only be teleported **within one experience**.
- Players in one call go to the **same** destination server. With no options, they go to a public server of the place, matchmade using the **first player** in the list.
- Only players **in the calling server** can be in the list. A party split over three servers needs three calls from three servers.
- On arrival, `Player:GetJoinData().Members` lists the UserIds teleported alongside the player; it is only present for group teleports.

What it does not guarantee:

- That everyone arrives. A teleport can fail for one member after the call returned; `TeleportInitFailed` fires once per player (Roblox docs) with a fresh `TeleportOptions` you can retry with, including the generated access code if you used `ShouldReserveServer`.
- That a public destination has room. If you target a specific public server with `ServerInstanceId` and it is full, the result is `Enum.TeleportResult.GameFull`. Without a target, matchmaking picks a server for the group, but a party near the server's capacity can still be a problem in games with small servers (rule of thumb: keep the largest party size at most half of max players for public-server groups).
- That members who were themselves teleporting arrive anywhere sensible. `IsTeleporting` is a real result.

The `TeleportResult` values are `Success`, `Failure`, `GameNotFound`, `GameEnded`, `GameFull`, `Unauthorized`, `Flooded`, `IsTeleporting` (Roblox docs). Only `Failure`, `Flooded` and sometimes `GameFull` are worth retrying, and `GameFull` only to a different server.

## 3. Choosing the destination

| Goal | Option | Notes |
|---|---|---|
| Party into a fresh instance (dungeon, match) | `ShouldReserveServer = true`, or `ReserveServerAsync` then `ReservedServerAccessCode` | Reserve once, share the code across servers |
| Party into a busy public world | No options, all members in one call | One call per source server; members in other servers may land elsewhere |
| Member joins the party leader's public server | `ServerInstanceId = leader's JobId` | Can be `GameFull`; leader's `JobId` from `GetPartyAsync` |
| Member joins the leader's reserved server | `ReservedServerAccessCode` from `GetPartyAsync` | The platform hands you the code for party use |
| Whole party, spread over servers, into one public server | Not possible to guarantee directly | Reserve, or move everyone to the leader's server first |

The last row is the trap. Two source servers calling `TeleportAsync` to the same public place without options get two independent matchmaking decisions. If the party must be together, either make the destination a **reserved server** (both calls carry the same access code) or send the stragglers to the **leader's current server** with `ServerInstanceId` and then teleport the reunited party in one call.

`ShouldReserveServer = true` is convenient when the whole party is in one server: one call reserves and teleports. When the party is spread out, call `ReserveServerAsync(placeId)` yourself first; it returns the access code and the `PrivateServerId` (Roblox docs). Every source server then uses the same code.

## 4. Gathering a spread-out party

The flow, run on the server where the leader pressed "Start":

1. Read the party: `GetPartyAsync(partyId)`. Filter to members in places from which you allow the activity (for example, only your lobby place). Members in a match should not be yanked out.
2. Reserve one server for the destination.
3. Write a **gather record** to a MemoryStore hash map: `{ partyId, placeId, accessCode, members, expiresAt }`, short TTL (60 to 120 s). The access code lives only here and in server memory.
4. Teleport the members who are in this server.
5. Publish a small message to a gather topic with the gather id. Other servers that host members read the record, re-check each local player's `PartyId` against `partyId`, and teleport them with the same code.
6. The destination server reads the same record by the gather id in teleport data, admits listed members only, and runs an **arrival barrier**.

Why re-check `PartyId` on each source server: the member may have left the party between step 1 and step 5. Teleporting a player who is no longer in the group is a support ticket.

Why not just teleport with `GetJoinData().Members` as the truth on arrival: `Members` only lists players **from the same call**, so a party gathered from three servers arrives as three groups. The gather record is the only complete list.

MessagingService limits from [[Cross-Server Messaging]] apply: messages up to 1 kB, delivered best effort within a second or two. A gather id is a few dozen bytes. For reliability, members' servers can also poll: when a player's party has a pending gather (one key per party in the same hash map), teleport them. In practice the message alone works most of the time and a "Rejoin party" button covers the rest.

## 5. The code

```lua
--!strict
-- ServerScriptService/Party/PartyGather.luau
-- Gathers a Roblox party (Player.PartyId) from several servers into one reserved server.
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local TeleportService = game:GetService("TeleportService")

local LOBBY_PLACE_ID = 0       -- only members in the lobby are gathered
local GATHER_TTL = 120
local GATHER_TOPIC = "PartyGather"
local MAX_RETRIES_PER_PLAYER = 3

local gathers = MemoryStoreService:GetHashMap("PartyGathers")

export type GatherRecord = {
	partyId: string,
	placeId: number,
	accessCode: string,
	members: { number },
	leader: number,
	createdAt: number,
}

type PartyMember = {
	UserId: number,
	PlaceId: number,
	JobId: string,
}

local PartyGather = {}

local retries: { [number]: number } = {}
local busy: { [string]: boolean } = {} -- partyId -> a gather is running from this server

local function readParty(partyId: string): { PartyMember }?
	local ok, result = pcall(function()
		return SocialService:GetPartyAsync(partyId)
	end)
	if not ok or type(result) ~= "table" then
		warn(`[Party] GetPartyAsync failed: {result}`)
		return nil
	end
	local out: { PartyMember } = {}
	for _, entry in result do
		if type(entry) == "table" and type(entry.UserId) == "number" then
			table.insert(out, {
				UserId = entry.UserId,
				PlaceId = tonumber(entry.PlaceId) or 0,
				JobId = tostring(entry.JobId or ""),
			})
		end
	end
	return out
end

-- Teleports the local players listed in the record whose PartyId still matches.
local function teleportLocalMembers(gatherId: string, record: GatherRecord)
	local group: { Player } = {}
	for _, userId in record.members do
		local p = Players:GetPlayerByUserId(userId)
		if p and p.PartyId == record.partyId and p:GetAttribute("Teleporting") ~= true then
			p:SetAttribute("Teleporting", true)
			table.insert(group, p)
		end
	end
	if #group == 0 then
		return
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = record.accessCode
	options:SetTeleportData({ gather = gatherId }) -- a pointer; the record is the truth
	local ok, err = pcall(function()
		return TeleportService:TeleportAsync(record.placeId, group, options)
	end)
	if not ok then
		warn(`[Party] TeleportAsync failed: {err}`)
		for _, p in group do
			p:SetAttribute("Teleporting", nil)
		end
	end
end

-- Called on the leader's server after the "Start" remote has been validated.
function PartyGather.start(leader: Player, placeId: number): (boolean, string?)
	local partyId = leader.PartyId
	if partyId == "" then
		return false, "not in a party"
	end
	if busy[partyId] then
		return false, "already starting"
	end
	busy[partyId] = true

	local members = readParty(partyId)
	if not members or #members == 0 then
		busy[partyId] = nil
		return false, "party unavailable"
	end
	-- Only the earliest member (index 1) or your own chosen leader may start; here: anyone in the lobby.
	local userIds: { number } = {}
	for _, m in members do
		if m.PlaceId == LOBBY_PLACE_ID then
			table.insert(userIds, m.UserId)
		end
	end
	if not table.find(userIds, leader.UserId) then
		busy[partyId] = nil
		return false, "leader not in lobby"
	end
	if #userIds > 50 then
		busy[partyId] = nil
		return false, "party too large"
	end

	local okReserve, accessCode = pcall(function()
		local code = TeleportService:ReserveServerAsync(placeId)
		return code
	end)
	if not okReserve or type(accessCode) ~= "string" then
		busy[partyId] = nil
		return false, "could not reserve a server"
	end

	local gatherId = HttpService:GenerateGUID(false)
	local record: GatherRecord = {
		partyId = partyId,
		placeId = placeId,
		accessCode = accessCode,
		members = userIds,
		leader = leader.UserId,
		createdAt = os.time(),
	}
	local okWrite, writeErr = pcall(function()
		gathers:SetAsync(gatherId, record, GATHER_TTL)
	end)
	if not okWrite then
		busy[partyId] = nil
		warn(`[Party] gather write failed: {writeErr}`)
		return false, "service unavailable"
	end

	teleportLocalMembers(gatherId, record)
	pcall(function()
		MessagingService:PublishAsync(GATHER_TOPIC, gatherId)
	end)
	task.delay(GATHER_TTL, function()
		busy[partyId] = nil
	end)
	return true, gatherId
end

function PartyGather.init()
	-- Other servers: teleport our members of a gathering party.
	pcall(function()
		MessagingService:SubscribeAsync(GATHER_TOPIC, function(message)
			local gatherId = message.Data
			if type(gatherId) ~= "string" or #gatherId > 64 then
				return
			end
			task.spawn(function()
				local ok, record = pcall(function()
					return gathers:GetAsync(gatherId)
				end)
				if ok and type(record) == "table" then
					teleportLocalMembers(gatherId, record :: GatherRecord)
				end
			end)
		end)
	end)

	-- Per-player retry with the options Roblox hands back, capped.
	TeleportService.TeleportInitFailed:Connect(function(player, result, message, placeId, options)
		player:SetAttribute("Teleporting", nil)
		local n = (retries[player.UserId] or 0) + 1
		retries[player.UserId] = n
		local retryable = result == Enum.TeleportResult.Failure or result == Enum.TeleportResult.Flooded
		if not retryable or n > MAX_RETRIES_PER_PLAYER or player.Parent == nil then
			warn(`[Party] giving up on {player.UserId}: {result.Name} {message}`)
			player:SetAttribute("PartyTeleportFailed", true) -- client shows "Rejoin party" button
			return
		end
		task.wait(if result == Enum.TeleportResult.Flooded then 10 else 2)
		if player.Parent then
			player:SetAttribute("Teleporting", true)
			pcall(function()
				TeleportService:TeleportAsync(placeId, { player }, options)
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		retries[p.UserId] = nil
	end)
end

return PartyGather
```

The client never chooses `placeId`, never sees the access code, and never names other players. The "Start" remote carries at most a mode name, which the server maps to a place id from its own table and validates against the leader's eligibility ([[Server Authority and Validation]]).

## 6. The destination: an arrival barrier

A reserved server for a party run should not start the run when the first player loads. It should wait for the expected members with a deadline, then start with whoever made it.

```lua
--!strict
-- ServerScriptService/Party/ArrivalBarrier.luau (destination place)
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")

local LOBBY_PLACE_ID = 0
local BARRIER_TIMEOUT = 45 -- seconds after the first arrival

local gathers = MemoryStoreService:GetHashMap("PartyGathers")

local expected: { number }? = nil
local arrived: { [number]: boolean } = {}
local started = false
local onStart: ((players: { Player }) -> ())? = nil

local function startRun()
	if started then
		return
	end
	started = true
	local present: { Player } = {}
	for _, p in Players:GetPlayers() do
		if arrived[p.UserId] then
			table.insert(present, p)
		end
	end
	if onStart then
		onStart(present)
	end
end

local function allArrived(): boolean
	if not expected then
		return false
	end
	for _, userId in expected do
		if not arrived[userId] then
			return false
		end
	end
	return true
end

local function admit(player: Player)
	local join = player:GetJoinData()
	if join.SourcePlaceId ~= LOBBY_PLACE_ID then
		player:Kick("Please start from the lobby.")
		return
	end
	local data = join.TeleportData
	local gatherId = if type(data) == "table" then data.gather else nil
	if type(gatherId) ~= "string" then
		player:Kick("Missing party information.")
		return
	end
	if not expected then
		local ok, record = pcall(function()
			return gathers:GetAsync(gatherId)
		end)
		if not ok or type(record) ~= "table" or type(record.members) ~= "table" then
			player:Kick("This run has expired. Please try again.") -- default deny
			return
		end
		expected = record.members
		task.delay(BARRIER_TIMEOUT, startRun) -- deadline counts from the first valid arrival
	end
	if not table.find(expected :: { number }, player.UserId) then
		player:Kick("You are not part of this party.")
		return
	end
	if started then
		-- Late arrival after the barrier: let them spectate or join as reinforcement; your call.
		arrived[player.UserId] = true
		return
	end
	arrived[player.UserId] = true
	if allArrived() then
		startRun()
	end
end

local Barrier = {}

function Barrier.init(callback: (players: { Player }) -> ())
	onStart = callback
	Players.PlayerAdded:Connect(admit)
	for _, p in Players:GetPlayers() do
		task.spawn(admit, p)
	end
end

return Barrier
```

Points worth noticing:

- **The first arrival fetches the record once.** Later arrivals compare against the cached `expected` list. This keeps MemoryStore reads to one per run.
- **The deadline starts on the first valid arrival**, not at server start: a reserved server starts when its access code is first used (Roblox docs), which is the first arrival, so these are close, but the first arrival is the one you can measure.
- **Expiry is a feature.** If someone uses an old code after the gather record expired, the record is gone and they are refused. Since access codes stay valid indefinitely (Roblox docs), the record's TTL is your real time limit.
- Players who left the party after the gather began are still in `expected`. Decide whether to admit them (friendlier) or check their current `PartyId` against `record.partyId` (stricter). `PartyId` on the destination reflects the platform party, so the check is cheap.

## 7. Keeping the party together inside a server

Arriving together is half the job. Inside a server, put party members on the same team, spawn them together, share quest progress if your design allows. The Roblox docs include a team integration sample that listens to `PartyId` changes and rebalances teams. Rules of thumb:

- Assign teams by party first, then fill with solos.
- If a party is larger than a team, split it predictably (leader's half first) and say so.
- Recompute on `PartyId` change only between rounds, not mid-round; players hate being swapped mid-fight.
- In public servers, let a solo player "follow" a party member with `ServerInstanceId` when they rejoin, guarded by a fullness check and a friendly `GameFull` message.

## 8. Your own party system, briefly

If you need an in-game party, store it in a MemoryStore hash map: one key per party (`members`, `leader`, `mode`, `version`), plus one key per user pointing to their party id. Invitations are short-lived keys (`invite_<target>_<party>`, TTL 60 s) checked when accepted. Every mutation is an `UpdateAsync` that re-validates: leader only can kick, size cap, target not already in another party. Refresh TTLs while members are online so abandoned parties evaporate on their own. Notify members' servers with MessagingService and treat the hash map as truth when a message is missed. This is the same "state in a store, message as a hint" pattern used in [[Matchmaking Queues with MemoryStore]].

Do not persist parties in data stores unless the design needs a long-lived squad; then the squad is a [[Trading Systems Without Duplication]]-style shared record with all the same conflict rules.

## 9. Edge cases that bite

| Case | What goes wrong | Handling |
|---|---|---|
| Member mid-teleport when gather starts | `GetPartyAsync` shows a stale `JobId` (the docs warn location lookups can be wrong during teleports for `GetPlayerPlaceInstanceAsync`; assume the same here) | They are not found locally anywhere; "Rejoin party" button |
| Member in a match place | Gather would pull them out | Filter by `PlaceId` |
| Party of 6, destination max 4 | Some players get `GameFull` or are refused | Check party size against the mode before reserving |
| Leader leaves before teleport | Gather record still valid | Others continue; any member can be leader of the run |
| Two members press Start at once | Two reservations, party split | `busy[partyId]` per server plus a short `UpdateAsync` lock key per party in the hash map for cross-server races |
| Cross-play disabled console player | Can land in a different server for the same `PrivateServerId` (Roblox docs) | Show it; compare `game.MatchmakingType` if you need to explain |
| Under-13 privacy settings | Some social features restricted (platform rules) | Never assume every member can join every server type |
| Studio | Teleports do not work in Studio playtests (Roblox docs) | Test party logic with the Party Simulator, teleports in a published test experience |

## 10. When not to gather

- If the activity is a public world where joining a friend later is easy, do not force a reserved server: let members follow the leader with `ServerInstanceId` and keep the shared public space alive.
- If party members are in different places doing different things, ask before moving them. A "Your party leader started a dungeon: Join?" prompt with a 20 s timer beats an unexpected teleport.

## Common mistakes

| Mistake | Fix |
|---|---|
| Assuming one `TeleportAsync` moves the whole party | It moves only players in this server; gather the rest |
| Two servers teleporting the same party to a public place without options | Reserve, or reunite first then teleport once |
| Trusting teleport data for party membership | Gather record in MemoryStore |
| Using `GetJoinData().Members` as the full roster | It lists only the same call's group |
| Unlimited `TeleportInitFailed` retries | Cap per player, then offer a manual rejoin |
| Starting the run on the first arrival | Arrival barrier with a deadline |
| Not re-checking `PartyId` before teleporting a member | Re-check on the source server |

## Checklist

- [ ] `PartyId` read on the server; changes handled between rounds.
- [ ] One reservation per gather; code stored server-side only.
- [ ] Gather record with short TTL; message plus manual rejoin for reliability.
- [ ] Source servers re-check membership and place before teleporting.
- [ ] `TeleportInitFailed` retries capped; failure surfaces a "Rejoin party" option.
- [ ] Destination validates source place and membership, default deny.
- [ ] Arrival barrier with deadline; late arrivals handled deliberately.
- [ ] Tested with the Party Simulator and in a published test experience.

## See also
[[Multiplayer Services Start Here]] · [[Teleporting and Multi-Place Games]] · [[Cross-Server Messaging]] · [[MemoryStore Service]] · [[Matchmaking Queues with MemoryStore]] · [[Reserved and Private Servers in Practice]] · [[Session State Across Places]] · [[Social Design and Multiplayer Play]] · [[Genre Playbook - Party and Minigame Collections]] · [[Testing Modes - Play Run and Multi-Client]]

## Connected notes
<!-- auto-links:start -->
[[Server Browsers and Server Lists]] · [[Links - Teleporting]] · [[Server Shutdowns Soft Updates and Migration]] · [[Links - Reserved and private servers]] · [[Friend Invites Referrals and Experience Invites]] · [[Links - Cross-server messaging]]
<!-- auto-links:end -->
