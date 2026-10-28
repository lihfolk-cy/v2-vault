---
tags: [multiplayer, matchmaking, memorystore, queues, lobby, reserved-servers, teleport, luau, strict]
---
# Matchmaking Queues with MemoryStore

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Every lobby runs the matcher -> Lease election
> - Avoid: Cancel by trying to delete from the queue -> State in a hash map, validate on read
> - Avoid: Remove batch before re-adding leftovers -> Re-add first, remove last
> - Decided between built-in custom matchmaking and a queue, and wrote down why.
> - Party is one ticket; party rating rule chosen.
> - One leader per queue via a lease; ownership re-checked before reserving.
>
> Read more (30 KB note): ## 1. First question: do you need a queue at all? · ## 6. The code · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A "Play Ranked" button looks like one feature. Behind it sit five problems that each fail in their own way: deciding whether you need your own queue at all, describing a player (or a party) as a ticket, letting exactly one server do the matching, handing the result back to the right lobby servers, and surviving every crash in between without matching a player twice or losing them forever. This note goes past the starter queue in [[MemoryStore Service]] and the four-step sketch in [[Teleporting and Multi-Place Games]]. It covers the built-in custom matchmaking option first (because it removes the need for a queue in many games), then a full queue-based matchmaker in strict Luau with leader election, ticket cancellation, widening skill windows, budget maths and failure paths.

Prerequisites: [[MemoryStore Service]] (structures, quotas, error codes), [[Cross-Server Messaging]] (MessagingService limits), [[Teleporting and Multi-Place Games]] (reserved servers, arrival validation). Related in this section: [[Parties and Group Teleports]], [[Reserved and Private Servers in Practice]], [[Session State Across Places]].

## 1. First question: do you need a queue at all?

Roblox now offers **custom matchmaking** for the normal Play button. When a player joins a place, the matchmaking service filters out servers that are full, private, reserved or about to shut down, scores every remaining server with a weighted sum of signals, and sends the player to the highest score (Roblox docs, as of October 2026). You configure it in the Creator Dashboard under **Configurations > Custom matchmaking**.

What it gives you (Roblox docs, as of October 2026):

| Piece | What it is | Limits |
|---|---|---|
| Roblox signals | Built-in signals such as Age, Device Type, Friends, Language, Latency, Occupancy, Play History, Voice Chat; you change their weights | Formulas are fixed; you only weight them |
| Player attributes | A value read from one of your data stores via a key template containing `{UserId}` and a JSON value path | 5 player attributes per game |
| Server attributes | Non-persistent values a server sets on itself with `MatchmakingService:SetServerAttribute(name, value)` | 5 server attributes per game |
| Custom signals | Numerical (average, median or sum against the joiner) or categorical (cluster or diversify) scoring built on your attributes | 2 custom signals per game |

The latency signal, for instance, scores `1 - min(100, deltaPingMs) / 100`, where delta ping is the ping above the best datacenter the player could reach (Roblox docs). A custom numerical player signal on an `Elo` attribute with "average" aggregation prefers servers whose average rating is close to the joiner's.

**Use built-in matchmaking when** players drop into long-running servers (a hangout, an open-world RPG, a survival server), you want "similar players together" rather than "exactly eight players start at once", and the attribute you care about is already in a data store. It costs no MemoryStore budget, works with the Play button, friends joins and invites, and needs no lobby place.

**Build a queue when** a match has a fixed size and a start moment (4v4, battle royale of 50, a co-op raid of 6), teams must be balanced before anyone enters, players must agree to a mode first, or a party must be kept together and placed against a party of similar size. Built-in matchmaking scores servers for one joining player; it does not hold players until a full roster exists.

A common hybrid: custom matchmaking places players into the **right lobby** (same language, low latency, similar rating), and the lobby runs a queue for timed matches.

## 2. Architecture in one picture

```
Lobby server A ──┐                         ┌── Match record (hash map, TTL)
Lobby server B ──┼─ tickets ─▶ Queue ─▶ Matchmaker (one leader) ─┤
Lobby server C ──┘    ▲                         │                 └── MessagingService "assign"
                      │                         ▼
              Ticket state (hash map, per user)  ReserveServerAsync once per match
                      ▲
Lobby servers read their own players' assignments ─▶ TeleportAsync with the access code
```

Three structures:

1. **Queue** `MM_Q_<mode>`: ticket payloads in order of priority then arrival. `MemoryStoreQueue` retrieves higher priority first and equal priority in order of addition (Roblox docs, as of October 2026).
2. **Hash map** `MM_Tickets`: one key per user, `{ ticketId, state, mode, at, matchId? }`. This is the source of truth for "is this player still searching". The queue item is only a pointer.
3. **Hash map** `MM_Matches`: one key per match id, `{ placeId, accessCode, members, createdAt }`, written by the leader, read by lobbies.

Why the split: you **cannot remove one arbitrary item from a queue**. `RemoveAsync` takes the id returned by a `ReadAsync` batch and removes that whole batch (Roblox docs). So cancellation has to be a state change somewhere else, checked when the ticket is read. Treat every queue item as possibly stale.

## 3. Ticket design

A ticket is the smallest thing that can be matched. Make a **party one ticket**, never several, so a matcher can never split it. Keep it small: the leader reads up to 100 per call and pays one request unit per item returned.

```lua
type Ticket = {
	id: string,          -- GUID, also stored in MM_Tickets for every member
	members: { number }, -- UserIds, leader first
	rating: number,      -- party rating (see below)
	mode: string,
	at: number,          -- os.time() when first enqueued
	region: string?,     -- optional bucket hint
}
```

**Party rating** is a design choice with consequences. Averaging lets a high player carry a low friend into a low lobby (smurfing). Common fixes (rule of thumb): use the maximum, or a weighted value like `0.7 * max + 0.3 * mean`, and only match parties against parties of similar size.

**Bucketing**: one queue per mode, and for big games one queue per mode and coarse rating band (`MM_Q_ranked_0` for 0 to 1199, `_1` for 1200 to 1599...). A queue is a single partition with an estimated ceiling of about 30,000 request units per minute (Roblox docs, an estimate that "can change"). Bands spread load and also make matching cheaper because candidates are already close. The cost: a player near a band edge waits longer. Allow the leader to pull from the neighbouring band after a wait threshold.

## 4. One leader, elected with a lease

If every lobby server reads the queue, two of them can each read half of a viable match and neither finds enough players. One matcher per queue is simpler and fairer. Elect it with a **lease** in a hash map: a key holding the owner's `JobId`, written with a short expiration and renewed while the leader lives. If the leader crashes, the key expires and another server takes over.

`MemoryStoreHashMap:UpdateAsync(key, transform, expiration)` runs the transform atomically and returning `nil` cancels the write (Roblox docs), which is exactly a compare-and-set. The transform can run several times under contention, so it must be pure: compute `now` outside it.

Lease timing rule of thumb: renew every 5 s, TTL 15 s. A crashed leader is replaced within 15 to 20 s; tickets it had read reappear after the queue's invisibility timeout (30 s by default, Roblox docs). Set the queue invisibility timeout comfortably longer than one matching cycle, but short enough that recovery after a crash is tolerable. 20 s works for a cycle that takes under 5 s.

**Split brain**: a leader that stalls (a long yield, a throttled call) may still believe it is leader after its lease expired and someone else took over. Guard it: re-check ownership before each write that matters (reserving a server, writing a match). Claims on tickets (below) are the final safety net: two leaders can never both claim the same ticket.

## 5. The matching cycle

Each cycle the leader:

1. `ReadAsync(100, false, 0)` from the queue: up to 100 items, no waiting. Waiting reads poll every two seconds and each poll costs a unit (Roblox docs), so a busy loop with `waitTimeout = 0` and your own `task.wait` is easier to budget.
2. Decodes tickets, drops malformed ones.
3. Sorts by rating, then walks the list forming groups whose rating spread is under the **window** of the oldest ticket in the group. Window widens with wait time, for example `100 + 15 * secondsWaited`, capped at 600 (rule of thumb; tune from analytics).
4. For each candidate group, **claims** every member ticket in `MM_Tickets` with `UpdateAsync` that succeeds only if the stored state is still `searching` with the same ticket id. If any claim fails (cancelled, left, already matched elsewhere), it **rolls back** the claims it made and drops the bad ticket.
5. Reserves a server, writes the match record, publishes an assign message.
6. Re-adds every unmatched, still-valid ticket to the queue with its original `at` preserved and a priority that favours old tickets.
7. Removes the read batch with `RemoveAsync(readId)`.

Order matters for crash safety. Re-adding leftovers **before** removing the batch means a crash in between causes duplicates, not losses, and duplicates are harmless because the claim step refuses a ticket whose state is no longer `searching`. A crash before step 6 simply lets the whole batch reappear after the invisibility timeout. This is the at-least-once model the queue was designed for.

Priority for re-added items: `AddAsync(value, expiration, priority)` with higher priority read first (Roblox docs). Using `priority = os.time() - ticket.at` (seconds waited) keeps old tickets at the front. New tickets enter at priority 0.

## 6. The code

The module below runs on lobby servers. Every server can enqueue and cancel for its own players; only the lease holder runs the cycle. It is strict Luau, server-only, with every MemoryStore call wrapped and every failure path decided explicitly.

```lua
--!strict
-- ServerScriptService/Matchmaking/Matchmaker.luau
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local MODE = "ranked4v4"
local MATCH_PLACE_ID = 0          -- your match place
local MATCH_SIZE = 8
local TICKET_TTL = 180            -- seconds a ticket state lives without refresh
local QUEUE_ITEM_TTL = 150
local MATCH_TTL = 600
local LEASE_TTL = 15
local LEASE_RENEW = 5
local CYCLE = 2                   -- seconds between matching cycles
local ASSIGN_TOPIC = "MM_Assign"

local queue = MemoryStoreService:GetQueue("MM_Q_" .. MODE, 20) -- 20 s invisibility
local ticketStates = MemoryStoreService:GetHashMap("MM_Tickets")
local matches = MemoryStoreService:GetHashMap("MM_Matches")
local leases = MemoryStoreService:GetHashMap("MM_Leases")

export type Ticket = {
	id: string,
	members: { number },
	rating: number,
	mode: string,
	at: number,
}

type TicketState = {
	ticketId: string,
	state: string, -- "searching" | "claimed" | "matched" | "cancelled"
	at: number,
	matchId: string?,
}

type MatchRecord = {
	placeId: number,
	accessCode: string,
	members: { number },
	createdAt: number,
}

local Matchmaker = {}

-- Small helper: pcall with up to three attempts and jittered backoff.
local function try<T>(label: string, fn: () -> T): (boolean, T?)
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[MM] {label} failed (attempt {attempt}): {result}`)
		task.wait(attempt + math.random())
	end
	return false, nil
end

------------------------------------------------------------------ enqueue / cancel

function Matchmaker.enqueue(members: { Player }, rating: number): (boolean, string?)
	if #members == 0 or #members > 4 then
		return false, "bad party size"
	end
	local now = os.time()
	local ticket: Ticket = {
		id = HttpService:GenerateGUID(false),
		members = {},
		rating = rating,
		mode = MODE,
		at = now,
	}
	for _, p in members do
		table.insert(ticket.members, p.UserId)
	end

	-- 1. Mark every member as searching. Refuse if anyone is already searching or matched.
	local written: { number } = {}
	for _, userId in ticket.members do
		local ok, result = pcall(function()
			return ticketStates:UpdateAsync(tostring(userId), function(old: any)
				if type(old) == "table" and (old.state == "searching" or old.state == "claimed" or old.state == "matched") then
					return nil -- abort: already busy
				end
				return { ticketId = ticket.id, state = "searching", at = now }
			end, TICKET_TTL)
		end)
		if not ok or result == nil then
			-- Roll back the members we already marked, then fail the whole party.
			for _, done in written do
				pcall(function()
					ticketStates:RemoveAsync(tostring(done))
				end)
			end
			return false, if ok then "already in a queue or match" else "service unavailable"
		end
		table.insert(written, userId)
	end

	-- 2. Push the pointer into the queue.
	local ok = try("AddAsync", function()
		queue:AddAsync(HttpService:JSONEncode(ticket), QUEUE_ITEM_TTL, 0)
		return true
	end)
	if not ok then
		for _, userId in written do
			pcall(function()
				ticketStates:RemoveAsync(tostring(userId))
			end)
		end
		return false, "service unavailable"
	end
	return true, ticket.id
end

-- Cancelling never touches the queue; the leader discards the stale item when it reads it.
function Matchmaker.cancel(userId: number): boolean
	local ok, result = pcall(function()
		return ticketStates:UpdateAsync(tostring(userId), function(old: any)
			if type(old) == "table" and old.state == "searching" then
				return { ticketId = old.ticketId, state = "cancelled", at = old.at }
			end
			return nil -- claimed or matched: too late to cancel
		end, 60)
	end)
	return ok and result ~= nil
end

------------------------------------------------------------------ leader lease

local function tryHoldLease(): boolean
	local me = game.JobId
	local now = os.time()
	local ok, result = pcall(function()
		return leases:UpdateAsync("leader_" .. MODE, function(old: any)
			if old == nil or (type(old) == "table" and old.owner == me) then
				return { owner = me, at = now }
			end
			return nil
		end, LEASE_TTL)
	end)
	return ok and type(result) == "table" and result.owner == me
end

------------------------------------------------------------------ claims

local function claim(ticket: Ticket, matchId: string): boolean
	local claimed: { number } = {}
	for _, userId in ticket.members do
		local ok, result = pcall(function()
			return ticketStates:UpdateAsync(tostring(userId), function(old: any)
				if type(old) == "table" and old.state == "searching" and old.ticketId == ticket.id then
					return { ticketId = ticket.id, state = "claimed", at = old.at, matchId = matchId }
				end
				return nil
			end, TICKET_TTL)
		end)
		if not ok or result == nil then
			-- Undo partial claims so those members return to searching.
			for _, done in claimed do
				pcall(function()
					ticketStates:UpdateAsync(tostring(done), function(old: any)
						if type(old) == "table" and old.matchId == matchId then
							return { ticketId = ticket.id, state = "searching", at = old.at }
						end
						return nil
					end, TICKET_TTL)
				end)
			end
			return false
		end
		table.insert(claimed, userId)
	end
	return true
end

local function release(tickets: { Ticket }, matchId: string)
	for _, t in tickets do
		for _, userId in t.members do
			pcall(function()
				ticketStates:UpdateAsync(tostring(userId), function(old: any)
					if type(old) == "table" and old.matchId == matchId then
						return { ticketId = t.id, state = "searching", at = old.at }
					end
					return nil
				end, TICKET_TTL)
			end)
		end
	end
end

------------------------------------------------------------------ forming groups

local function windowFor(t: Ticket, now: number): number
	return math.min(600, 100 + 15 * (now - t.at))
end

-- Greedy: walk tickets sorted by rating; fill a group of exactly MATCH_SIZE players.
local function formGroups(tickets: { Ticket }, now: number): ({ { Ticket } }, { Ticket })
	table.sort(tickets, function(a, b)
		return a.rating < b.rating
	end)
	local groups: { { Ticket } } = {}
	local leftovers: { Ticket } = {}
	local current: { Ticket } = {}
	local count = 0
	for _, t in tickets do
		local anchor = current[1]
		local fits = anchor == nil
			or (t.rating - anchor.rating) <= math.max(windowFor(anchor, now), windowFor(t, now))
		if not fits or count + #t.members > MATCH_SIZE then
			for _, x in current do
				table.insert(leftovers, x)
			end
			current, count = {}, 0
		end
		table.insert(current, t)
		count += #t.members
		if count == MATCH_SIZE then
			table.insert(groups, current)
			current, count = {}, 0
		end
	end
	for _, x in current do
		table.insert(leftovers, x)
	end
	return groups, leftovers
end

------------------------------------------------------------------ one cycle

local function runCycle()
	local ok, items, readId = pcall(function()
		return queue:ReadAsync(100, false, 0)
	end)
	if not ok then
		warn(`[MM] ReadAsync failed: {items}`)
		task.wait(3 + math.random() * 2) -- back off on throttling
		return
	end
	if type(items) ~= "table" or #items == 0 or type(readId) ~= "string" then
		return
	end

	local tickets: { Ticket } = {}
	for _, raw in items do
		local decoded, value = pcall(HttpService.JSONDecode, HttpService, raw)
		if decoded and type(value) == "table" and type(value.id) == "string" then
			table.insert(tickets, value :: Ticket)
		end
	end

	local now = os.time()
	local groups, leftovers = formGroups(tickets, now)

	for _, group in groups do
		if not tryHoldLease() then
			-- Lost leadership mid-cycle: put everything back and stop.
			for _, t in group do
				table.insert(leftovers, t)
			end
			continue
		end
		local matchId = HttpService:GenerateGUID(false)
		local claimedTickets: { Ticket } = {}
		local allClaimed = true
		for _, t in group do
			if claim(t, matchId) then
				table.insert(claimedTickets, t)
			else
				allClaimed = false -- stale or cancelled ticket: drop it
			end
		end
		if not allClaimed then
			release(claimedTickets, matchId)
			for _, t in claimedTickets do
				table.insert(leftovers, t)
			end
			continue
		end

		local reserved, accessCode = try("ReserveServerAsync", function()
			local code = TeleportService:ReserveServerAsync(MATCH_PLACE_ID)
			return code
		end)
		if not reserved or type(accessCode) ~= "string" then
			release(claimedTickets, matchId)
			for _, t in claimedTickets do
				table.insert(leftovers, t)
			end
			continue
		end

		local members: { number } = {}
		for _, t in group do
			for _, userId in t.members do
				table.insert(members, userId)
			end
		end
		local record: MatchRecord = {
			placeId = MATCH_PLACE_ID,
			accessCode = accessCode,
			members = members,
			createdAt = now,
		}
		local wrote = try("write match", function()
			matches:SetAsync(matchId, record, MATCH_TTL)
			return true
		end)
		if not wrote then
			release(claimedTickets, matchId)
			for _, t in claimedTickets do
				table.insert(leftovers, t)
			end
			continue
		end
		for _, userId in members do
			pcall(function()
				ticketStates:UpdateAsync(tostring(userId), function(old: any)
					if type(old) == "table" and old.matchId == matchId then
						return { ticketId = old.ticketId, state = "matched", at = old.at, matchId = matchId }
					end
					return nil
				end, MATCH_TTL)
			end)
		end
		-- Fast path to lobbies; the poll in Lobby code is the reliable path.
		pcall(function()
			MessagingService:PublishAsync(ASSIGN_TOPIC, matchId)
		end)
	end

	-- Re-add leftovers BEFORE removing the batch: a crash here duplicates, never loses.
	for _, t in leftovers do
		pcall(function()
			queue:AddAsync(HttpService:JSONEncode(t), QUEUE_ITEM_TTL, now - t.at)
		end)
	end
	pcall(function()
		queue:RemoveAsync(readId)
	end)
end

function Matchmaker.startLeaderLoop()
	task.spawn(function()
		task.wait(math.random() * LEASE_RENEW) -- stagger servers
		while true do
			if tryHoldLease() then
				local deadline = os.clock() + LEASE_RENEW
				while os.clock() < deadline do
					runCycle()
					task.wait(CYCLE)
				end
			else
				task.wait(LEASE_RENEW)
			end
		end
	end)
end

------------------------------------------------------------------ lobby side delivery

local teleporting: { [number]: boolean } = {}

local function deliver(matchId: string)
	local ok, record = pcall(function()
		return matches:GetAsync(matchId)
	end)
	if not ok or type(record) ~= "table" then
		return
	end
	local rec = record :: MatchRecord
	local here: { Player } = {}
	for _, userId in rec.members do
		local p = Players:GetPlayerByUserId(userId)
		if p and not teleporting[userId] then
			teleporting[userId] = true
			table.insert(here, p)
		end
	end
	if #here == 0 then
		return
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = rec.accessCode
	options:SetTeleportData({ matchId = matchId }) -- a hint; the match server re-reads MM_Matches
	local sent = try("TeleportAsync", function()
		return TeleportService:TeleportAsync(rec.placeId, here, options)
	end)
	if not sent then
		for _, p in here do
			teleporting[p.UserId] = nil
		end
	end
end

function Matchmaker.startLobbyDelivery()
	pcall(function()
		MessagingService:SubscribeAsync(ASSIGN_TOPIC, function(message)
			if type(message.Data) == "string" then
				task.spawn(deliver, message.Data)
			end
		end)
	end)
	-- Reliable path: poll only players who are searching, every 5 s.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, p in Players:GetPlayers() do
				if p:GetAttribute("Searching") == true and not teleporting[p.UserId] then
					local ok, state = pcall(function()
						return ticketStates:GetAsync(tostring(p.UserId))
					end)
					if ok and type(state) == "table" and state.state == "matched" and type(state.matchId) == "string" then
						task.spawn(deliver, state.matchId)
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		teleporting[p.UserId] = nil
		Matchmaker.cancel(p.UserId)
	end)
end

return Matchmaker
```

What the code deliberately does not do: trust anything from the client. The remote that starts searching (not shown) checks that the caller is the party leader, that the mode exists, that the player is not already searching, and rate limits requests ([[Remote Abuse Patterns and Rate Limiting in Practice]]). The rating comes from the server's own profile, never from the remote arguments. The `Searching` attribute is set by the server after `enqueue` succeeds.

The match server validates arrivals against `MM_Matches` exactly as the ticket pattern in [[Teleporting and Multi-Place Games]] does: read the record using the `matchId` hint, check membership, default deny, and start when all members arrived or after a timeout (rule of thumb: 30 to 45 s), filling empty slots with bots or ending the match as void.

## 7. Budget maths

The request quota is `1,000 + 120 x CCU` units per minute for the whole experience (Roblox docs, as of October 2026). At 2,000 CCU that is 241,000 units per minute.

Rough cost per minute with the code above, 2,000 CCU, 300 searching players, cycle every 2 s:

| Operation | Frequency | Units per minute |
|---|---|---|
| Leader `ReadAsync` | 30 cycles, about 40 items each | 1,200 |
| Re-adding leftovers | about 35 per cycle | 1,050 |
| Lease renewals (all lobby servers try) | 60 servers x 12 | about 1,440 (hash map `UpdateAsync` costs at least 2) |
| Claims and state writes for 30 matches | 8 members x 2 writes x 2 units | about 960 |
| Lobby polls of searching players | 300 players x 12 | 3,600 |
| Enqueue and cancel | 60 per minute x 2 to 3 calls | about 300 |

Total is under 10,000 units per minute: comfortable. The danger rows are the ones that scale with CCU rather than with searching players. If you poll **every** player rather than searching players, the poll row becomes 24,000. If non-leaders hammer the lease every second, 60 servers cost 7,200. Keep leader attempts slow and polls scoped.

Single-partition ceiling: everything on one queue lives on one partition (estimated 30,000 units per minute, Roblox docs). The leader alone is fine; trouble starts when every lobby polls `GetSizeAsync` on the queue to show "312 players searching". Publish that number from the leader once per cycle instead (MessagingService, one message per cycle, well under the per-topic receive limit in [[Cross-Server Messaging]]).

Memory: tickets near 200 bytes, states near 100 bytes. 300 searching players use under 100 KB, far inside `64 KB + 1.2 KB x users` (Roblox docs). Short TTLs keep it that way.

## 8. Failure paths and what players see

| Failure | What happens | What the player sees |
|---|---|---|
| Enqueue `UpdateAsync` throttled | Party rolled back | "Matchmaking is busy, try again" |
| Leader crashes mid-cycle | Lease expires in at most 15 s; batch reappears after 20 s | Longer wait, no loss |
| Two leaders briefly | Claims are compare-and-set; only one wins each ticket | Nothing |
| Member left lobby before claim | Their `PlayerRemoving` cancelled the state; claim fails; group released | Others keep searching |
| Member leaves after `matched` | Match server times them out | Match starts short or with a bot |
| `ReserveServerAsync` fails 3 times | Claims released, tickets re-added | Slightly longer wait |
| Assign message lost | Lobby poll finds `matched` within 5 s | A few seconds slower |
| `TeleportAsync` throws | `teleporting` flag cleared; next poll retries | Retry, then a message after the poll keeps failing |
| Teleport fails after the call | `TeleportInitFailed` retry logic from the teleport note | Retry or "could not join match" |
| Match record expired before delivery | `GetAsync` returns nil; player stays in lobby with state `matched` | Add a sweeper: states `matched` older than 60 s with no record become `cancelled`, UI resets |
| Memory quota full | Writes fail with `TotalMemoryOverLimit` | Matchmaking unavailable; shorten TTLs, check for leaks |

Always give the player a **cancel button that works locally** (stop showing "searching", call `cancel`) even if the remote write fails: the TTL on the ticket state is the backstop.

## 9. Fairness and tuning

- **Measure queue time by percentile**, not average: log enqueue to teleport time per mode and report p50 and p90 ([[Analytics and Funnels]], [[Probability and Statistics for Designers]]). p90 is what quitters experience.
- **Widening windows trade quality for time.** Log the rating spread of each formed match next to its wait. If p90 wait is fine but spreads are huge, the window grows too fast.
- **Low population collapse**: at night or in small regions a mode may never fill. After a threshold (for example 90 s), offer the player a smaller mode or fill with bots, and show an honest estimate. A queue that silently never pops is the fastest way to lose players.
- **Party versus solo**: weight parties a little higher than their rating so a coordinated party does not crush four strangers, or prefer matching parties against parties of the same size.
- **Backfill**: if a match loses a player in its first minute, the match server can enqueue a "slot" ticket on a separate backfill queue so new players join a running match. Make backfill optional for the joining player; joining a losing game is a bad first experience.

## 10. When not to do this

- Games under a few hundred CCU in a mode: queues rarely fill. Use built-in matchmaking with a server attribute for the mode, or a lobby with a visible "join next round" pad ([[Spawning Teams and Rounds]], [[Lobby and Hub Design]]).
- Casual drop-in play: reserved servers per match throw away the social glue of public servers.
- When friends must be together but skill does not matter: use [[Parties and Group Teleports]] and public servers.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Every lobby runs the matcher | Half-matches, players matched twice | Lease election |
| Cancel by trying to delete from the queue | Impossible; cancelled players still matched | State in a hash map, validate on read |
| Remove batch before re-adding leftovers | Tickets lost on crash | Re-add first, remove last |
| Ticket per party member | Parties split across matches | One ticket per party |
| Client sends its own rating | Smurfs and boosted lobbies | Read rating from the server profile |
| Polling every player's state | Budget gone at peak | Poll only searching players |
| Waiting reads with long timeouts | A unit every 2 s spent waiting | `waitTimeout = 0` plus your own wait |
| No sweeper for orphaned states | Players stuck in "matched" forever | TTL plus sweeper |
| Access code sent to clients | Players rejoin finished matches | Keep codes in the match record only |

## Checklist

- [ ] Decided between built-in custom matchmaking and a queue, and wrote down why.
- [ ] Party is one ticket; party rating rule chosen.
- [ ] One leader per queue via a lease; ownership re-checked before reserving.
- [ ] Ticket state is the truth; queue items validated by compare-and-set claims.
- [ ] Leftovers re-added before the batch is removed.
- [ ] Assignments delivered by message and by a scoped poll.
- [ ] Match server validates arrivals and starts on all-arrived or timeout.
- [ ] Budget estimated at peak CCU; queue size broadcast instead of polled.
- [ ] Queue time p50 and p90 logged per mode.

## See also
[[Multiplayer Services Start Here]] · [[MemoryStore Service]] · [[Cross-Server Messaging]] · [[Teleporting and Multi-Place Games]] · [[Parties and Group Teleports]] · [[Reserved and Private Servers in Practice]] · [[Session State Across Places]] · [[Social Design and Multiplayer Play]] · [[Spawning Teams and Rounds]] · [[Lobby and Hub Design]]

## Connected notes
<!-- auto-links:start -->
[[Server Browsers and Server Lists]] · [[Session Locking and Profile Libraries]] · [[Links - MemoryStore]] · [[Server Shutdowns Soft Updates and Migration]] · [[Saving Correctly - Autosave and BindToClose]] · [[Arena Rounds with Teams and Spectating End to End]]
<!-- auto-links:end -->
