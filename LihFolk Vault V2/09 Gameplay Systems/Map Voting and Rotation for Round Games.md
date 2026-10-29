---
tags: [rounds, map-voting, map-rotation, round-games, streaming, type/guide, area/gameplay, level/intermediate, api/RequestStreamAroundAsync, api/RemoteEvent, api/ServerStorage, area/world]
---
# Map Voting and Rotation for Round Games

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Ballot shows every map -> Ballot of 3 from a weighted pool
> - Avoid: No recent-map exclusion -> Exclude last 2 to 3
> - Avoid: Tie goes to the first option -> Weighted random among ties
> - Maps tagged with player-count range and mode; ballot filters on both.
> - Recent maps excluded; staleness weights; seasonal boost option.
> - Votes validated against current ballot and phase; rate limited; leavers removed.
>
> Cost: TL;DR ~150 tok · whole note ~2.5k tok. Read more: ## 1. Ballot design: offer 3, not 20 · ## 3. Loading maps · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Round-Based Minigame Loop End to End]] already builds a working lobby, a 10-second vote and a cloned map. This note covers what that build leaves simple and what breaks once a game has twenty maps and full servers: how to pick which maps appear on the ballot, how to stop the same favourite winning every round, fair tie-breaks, vote validation, and how to load and unload large maps without a hitch or players falling through an unstreamed floor.

Source labels: **Roblox docs** (create.roblox.com, as of October 2026), **Rule of thumb**. Code is strict Luau, **reviewed, not run**.

---

## 1. Ballot design: offer 3, not 20

Showing every map produces the same two winners forever and leaves the rest unplayed. A ballot of three (sometimes four) drawn from a **rotation pool** keeps variety and makes the choice quick on phones.

Build the ballot like this:

1. Start from the pool of maps valid for the current player count and mode (a 24-player map with 4 players is empty and boring; tag each map with `MinPlayers`/`MaxPlayers`).
2. Remove the last N played maps (N = 2 or 3, rule of thumb) so no map can repeat back to back.
3. Draw 3 by **weighted** random, where a map's weight grows the longer it has gone unplayed. New or seasonal maps can get a fixed boost.
4. Optionally reserve one slot for "Random" (resolve at the end to an unplayed map from the pool); it gives players a way to say "anything but these".

```lua
--!strict
-- ServerScriptService/MapRotation
export type MapInfo = { id: string, minPlayers: number, maxPlayers: number, boost: number }

local MapRotation = {}

local recent: { string } = {}       -- most recent first
local lastPlayed: { [string]: number } = {} -- round index
local roundIndex = 0
local rng = Random.new()

local function isRecent(id: string, n: number): boolean
	for i = 1, math.min(n, #recent) do
		if recent[i] == id then return true end
	end
	return false
end

function MapRotation.ballot(pool: { MapInfo }, playerCount: number, size: number): { MapInfo }
	local candidates: { MapInfo } = {}
	local weights: { number } = {}
	for _, map in pool do
		if playerCount >= map.minPlayers and playerCount <= map.maxPlayers and not isRecent(map.id, 2) then
			local age = roundIndex - (lastPlayed[map.id] or -10)
			table.insert(candidates, map)
			table.insert(weights, math.min(age, 10) + map.boost)
		end
	end
	local picked: { MapInfo } = {}
	while #picked < size and #candidates > 0 do
		local total = 0
		for _, w in weights do total += w end
		local roll = rng:NextNumber() * total
		for i, w in weights do
			roll -= w
			if roll <= 0 or i == #weights then
				table.insert(picked, table.remove(candidates, i) :: MapInfo)
				table.remove(weights, i)
				break
			end
		end
	end
	return picked
end

function MapRotation.markPlayed(id: string)
	roundIndex += 1
	lastPlayed[id] = roundIndex
	table.insert(recent, 1, id)
	if #recent > 5 then table.remove(recent) end
end

return MapRotation
```

If the filtered pool is smaller than the ballot size (few maps fit tiny servers), relax the recent rule before you relax the player-count rule.

## 2. Counting votes fairly

- **One vote per player, changeable.** Store `votes[player] = mapId`; a new vote overwrites. Count from that table at the end, so leaving players drop out automatically (clear their entry in `PlayerRemoving`).
- **Validate**: the vote must be one of the current ballot ids, the vote phase must be open, and the remote must be rate limited ([[Rate Limiting and Abuse Prevention]]). Ignore everything else silently.
- **Broadcast counts at a fixed rate** (2 to 4 Hz) rather than on every vote; 30 players clicking at once otherwise sends 30 updates to 30 clients.
- **Tie-break**: random among tied maps, weighted by the same staleness weight, so a tie leans towards the less-played map. "First in the list wins" biases towards whatever the ballot put first.
- **Nobody voted**: pick by staleness weight, not uniformly, so idle servers still rotate.
- **Paid vote boosts** (a game pass that counts double): legal, but disclose it on the ballot and cap it; a single whale deciding every map drives other players off. Check current monetization rules in [[Roblox Policies Ratings and Compliance]] before shipping anything paid that affects shared outcomes.

## 3. Loading maps

Small maps: `ServerStorage.Maps[id]:Clone()` and parent to `workspace.ActiveMap`, as in the worked build. Larger maps need more care.

**Parent in one go, but prepare first.** Cloning is cheap; the hitch comes from replication and from physics waking up thousands of parts. Rules of thumb:

- Anchor everything that does not move, before parenting. Unanchored props settling at round start cost physics time and produce visible jiggle.
- Parent the map during intermission, while players are still in the lobby, not when the round starts. The vote ends, the map loads during a 3 to 5 s "Loading map..." card, then players move.
- Keep scripts inside maps to a minimum; map behaviour should be a module the round system starts, so it can also stop it.

**Streaming and moving players.** Under StreamingEnabled the client does not yet have the new map's floor when you teleport them onto it. Roblox docs: `Player:RequestStreamAroundAsync(position, timeOut)` asks the server to stream the region around a position to that player before you move them. Call it per player (in parallel tasks) on their spawn point, then `PivotTo` the character. See [[Instance Streaming]].

```lua
--!strict
local function moveToMap(player: Player, spawnCFrame: CFrame)
	task.spawn(function()
		local ok = pcall(function()
			player:RequestStreamAroundAsync(spawnCFrame.Position, 5)
		end)
		local character = player.Character
		if character and character.Parent then
			character:PivotTo(spawnCFrame + Vector3.new(0, 3, 0))
		end
		if not ok then
			warn("Stream request failed for", player.Name)
		end
	end)
end
```

For maps that must be in full view at round start (a sniper map), set the map model's `ModelStreamingMode` to `Persistent` sparingly, or accept that distant parts stream in; never make every map persistent, that defeats streaming.

**Very large maps**: if one map alone is a big share of your memory budget, consider a separate place per map and `TeleportService` with a reserved server per match instead of cloning ([[Teleporting and Multi-Place Games]]). That trades load hitches for teleport time and is common for competitive shooters.

## 4. Unloading maps

- Move all players back to the lobby first (same stream-then-pivot pattern), then destroy the map. Destroying a floor under live characters drops them into the void.
- Stop map modules (disconnect events, cancel `task.delay` threads) before `Destroy()`. A map script still running after its map is destroyed is the most common round-game memory leak ([[Memory Budgets and Leaks]]).
- Clean up anything the round created outside the map folder: projectiles, dropped tools, debris, temporary sounds. Parent round-created instances under the map or a `RoundDebris` folder so one destroy clears them.
- Check `Stats` / the Developer Console memory graph across 20 rounds in a test server; flat is correct, a staircase is a leak.

---

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Ballot shows every map | Two maps played forever | Ballot of 3 from a weighted pool |
| No recent-map exclusion | Same map back to back | Exclude last 2 to 3 |
| Tie goes to the first option | Ballot order decides outcomes | Weighted random among ties |
| Votes counted from a running total | Leavers' votes still count; double votes | `votes[player]` table, clear on leave |
| Teleport before streaming | Players fall through the new map | `RequestStreamAroundAsync`, then `PivotTo` |
| Map destroyed with players on it | Mass deaths at round end | Move to lobby first |
| Map scripts outlive the map | Memory climbs every round | Stop modules, then destroy |
| Every map `Persistent` | Join time and memory grow with map count | Default streaming; persistent only where needed |

## Checklist

- [ ] Maps tagged with player-count range and mode; ballot filters on both.
- [ ] Recent maps excluded; staleness weights; seasonal boost option.
- [ ] Votes validated against current ballot and phase; rate limited; leavers removed.
- [ ] Count broadcasts throttled; tie-break and no-vote cases weighted.
- [ ] Map loads during an intermission card; players streamed then moved.
- [ ] Unload moves players first, stops modules, clears round debris.
- [ ] Memory flat across 20 consecutive rounds in a live test server.

## See also

[[Round-Based Minigame Loop End to End]] · [[Spawning Teams and Rounds]] · [[Instance Streaming]] · [[Teleporting and Multi-Place Games]] · [[Rate Limiting and Abuse Prevention]] · [[Memory Budgets and Leaks]] · [[Genre Playbook - Party and Minigame Collections]] · [[Lobby and Hub Design]]

## Connected notes
<!-- auto-links:start -->
[[Arena Rounds with Teams and Spectating End to End]] · Links - Rounds and matchmaking · Matchmaking Queues with MemoryStore
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Spawn Director - Credit Budgets and Player-Count Scaling]] · [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] · [[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Kill Credit, Assists, Kill Feed and Death Recaps]] · [[Pathfinding Edge Cases and Fallbacks]] · [[Camera Obstruction Handling - Occlusion Modes, Fades and Collision]] · [[Behaviour Trees Utility AI and State Machines for NPCs]]
<!-- related:end -->
