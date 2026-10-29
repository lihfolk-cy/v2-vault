---
tags: [level-design, lobby, hub, social, teleport, proximity-prompt, performance, layout, type/hub, area/world, level/intermediate, api/TeleportService]
---
# Lobby and Hub Design

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Built for the impressive jobs first -> Rank the jobs; build spawn and exits first
> - Avoid: Loiter node on the spawn line -> Move boards and benches off the spawn axis
> - Avoid: Shop off the return flow -> Put the core spend station on the way out
> - Hub jobs ranked; spawn and exits designed first.
> - First-time, return and loiter flows drawn; no crossings at chokes.
> - Time budgets met: first station under 15 s, exit under 20 s for veterans.
>
> Cost: TL;DR ~160 tok · whole note ~4.7k tok. Read more: ## 3. Stations and prompts: the hidden collision problem · ## 4. Queue pads, portals and teleports · ## 10. Common mistakes · ## 11. Checklist
<!-- tldr:end -->

The hub (or lobby) is the space every player sees first and returns to most. [[Level Design for Roblox]] gives the layout patterns (radial plaza, street, courtyard with gates, vertical) and the hub rules that held up in one production game; [[Lobby and Hub Design]] covers how to swap a hub safely with a hook contract and staging copies. This note does neither again. It covers the design questions in between: what a hub is for and in what order, how long each job may take, how many players it must hold, how stations, prompts and queue pads interact, how returning players should flow, and what a hub may cost in performance.

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

## 1. A hub has jobs, in priority order

Before choosing a layout, list what the hub must do, and rank it. A typical ranking for an action or progression game:

| Rank | Job | Measured by |
|---|---|---|
| 1 | Get a new player to their first fun action | Seconds from spawn to first action |
| 2 | Get a returning player back into play | Seconds from spawn to leaving the hub |
| 3 | Offer the core spend (roll, shop, upgrade) | Station visit rate per session |
| 4 | Show progress and status (leaderboards, titles, cosmetics) | Dwell near boards, cosmetic views |
| 5 | Let players meet (social nodes, parties, trading) | Party formation, chat near nodes |
| 6 | Announce live content (events, updates) | Event joins from the hub |

The ranking decides the geometry. Rank 1 and 2 decide the spawn and the exits; ranks 3 to 6 decide the ring around them. Games differ: a social hangout ranks 5 first; a round-based game ranks the queue pad first. The mistake is building for rank 3 to 6 (the impressive part) and leaving rank 1 and 2 as whatever falls out.

### Time budgets

Rule of thumb budgets for a hub in an action or progression game:

| Moment | Budget |
|---|---|
| First frame after spawn shows the main action or its entrance | 0 s (spawn facing) |
| New player reaches the first interactive station or exit | under 15 s of walking |
| Returning player leaves the hub for play | under 20 s, ideally one prompt or pad from spawn |
| Any station from any other station | under 10 s |

At the default 16 studs/s (Roblox docs), 15 seconds is 240 studs. Measured in the reference project, the walk from the hub portal to the first gate was cut from about 460 to about 227 studs because new players were bored before their first fight. That is the same budget seen from the other side: a hub that is lovely but 30 seconds wide fails job 1.

## 2. Layout follows the flows, not the other way round

Draw three flows on the plan before placing a single station:

1. **First-time flow.** Spawn, then the one thing you want a new player to do first (often the tutorial start or the first station), then the exit to play.
2. **Return flow.** Spawn (or arrival from a realm), then straight to the exit, with the core spend station on the way, not off to the side.
3. **Loiter flow.** Where players stand when they have nothing to do: around boards, the centrepiece, social benches.

Then check for conflicts:

- **The first-time flow and the loiter flow must not cross at a choke.** If 20 players stand around the leaderboards on the spawn avenue, new players spawn into a crowd and cannot see the stations. Put loiter nodes off to the side of the spawn line, visible but not in it.
- **The return flow should pass the core spend station** in front, within prompt range. A shop that the return flow walks past gets visits; a shop behind the spawn gets visits only from players who look for it.
- **Exits must not be behind the centrepiece from the spawn.** The centrepiece pulls players toward it, and anything directly behind it is hidden. See the worked example in [[Level Design Principles - Flow Sightlines and Landmarks]].

### Hub size versus server size

A hub sized for 4 players feels dead with 4 and a hub sized for 40 feels empty with 4. Size the walkable core for the **typical** concurrent count in a server, not the maximum. If a server holds up to 30 players but players spend 80 percent of their session out in zones, the hub typically holds 3 to 8 people at a time. Rule of thumb: the central plaza should feel occupied with about 5 players in it, which for default-sized characters means a core radius around 40 to 70 studs, with the ring of stations further out.

If your game spends most of its time in the hub (simulators, trading games, social hangouts), the opposite applies: size for the busy case and add more nodes, not more width.

## 3. Stations and prompts: the hidden collision problem

Most hubs open their stations with a `ProximityPrompt`. Prompts have behaviours that interact with layout:

| Property | Behaviour | Source |
|---|---|---|
| `RequiresLineOfSight` | When true (the default), the prompt hides if something blocks the line between camera and prompt | Roblox docs (as of October 2026) |
| `Exclusivity` | `OnePerButton` shows only one prompt per input key; `OneGlobally` and `AlwaysShow` are the other options | Roblox docs |
| `MaxActivationDistance` | Range at which the prompt becomes active | Roblox docs; the Studio default is 10 studs (unconfirmed in the reference page) |
| `HoldDuration` | 0 triggers immediately | Roblox docs |
| `KeyboardKeyCode` / `GamepadKeyCode` | Default E / ButtonX | Roblox docs |

Level design consequences:

- **Decorative parts block prompts.** With line of sight required, a sign, a railing or a transparent glass panel in front of the prompt's part can hide it from some camera angles. Players report "the shop does not work sometimes". Fix by parenting the prompt to an attachment in front of the decoration, setting the decoration's `CanQuery` off if it does not need it, or turning off `RequiresLineOfSight` for that prompt.
- **Two stations within range at once.** With `OnePerButton`, only the closest-feeling prompt shows; players standing between two stations flip between them. Keep station prompt points at least twice the activation distance apart (rule of thumb: 20+ studs with a 10-stud range), or give them different keys.
- **No pads, no circles.** The reference project removed glowing "stand here" circles under prompts: players read the object, not the floor. Put the prompt on the object at chest height.
- **Gamepad and touch.** On touch the prompt is tapped, so it must not overlap the jump button's screen area when the player stands at the station. Check standing positions on a phone, not just in Studio.

### Station spacing and the ring

A radial ring of stations works when each station's front faces the centre and its approach is clear. Measured in the reference project: stations sat on a 170 to 220 stud ring facing the centre, and a 46-stud keep-clear radius around each station stopped foliage from blocking signs and prompts. Treat the approach cone in front of each station (rule of thumb: 30 degrees either side, out to 30 studs) as reserved: no trees, lamp posts or benches there.

## 4. Queue pads, portals and teleports

Round-based and multi-place games use the hub to send groups somewhere else. A queue pad is level design and networking at once.

Design rules (rule of thumb):

- **Pads are visible from the spawn** and labelled with what they start, the player count and a countdown.
- **Pads are big enough for a party standing together**: about 4 studs of diameter per expected player, so a 4-player pad is about 16 studs across.
- **A clear walk-off edge.** Players who change their mind must be able to step off without walking through others.
- **Pads must not sit on the return flow,** or players walking past get pulled into a match.

Detecting who stands on a pad with `Touched` and `TouchEnded` is unreliable for standing characters (touch events fire on contact changes, and animations jitter contacts). Poll a box instead:

```lua
--!strict
-- Server: a queue pad that teleports everyone standing on it after a countdown.
-- Pad = an anchored Part; the query box extends 8 studs above it.
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local PAD_HEIGHT = 8
local COUNTDOWN = 10
local MAX_PLAYERS = 8 -- TeleportAsync accepts at most 50 per call (Roblox docs)

local function playersOnPad(pad: BasePart): { Player }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local characters = {}
	for _, p in Players:GetPlayers() do
		if p.Character then table.insert(characters, p.Character) end
	end
	params.FilterDescendantsInstances = characters

	local boxCFrame = pad.CFrame * CFrame.new(0, pad.Size.Y / 2 + PAD_HEIGHT / 2, 0)
	local boxSize = Vector3.new(pad.Size.X, PAD_HEIGHT, pad.Size.Z)
	local seen: { [Player]: boolean } = {}
	local list = {}
	for _, part in workspace:GetPartBoundsInBox(boxCFrame, boxSize, params) do
		-- Accessory handles sit one level deeper, so look for the character model.
		local model = part:FindFirstAncestorOfClass("Model")
		local player = model and Players:GetPlayerFromCharacter(model)
		if model and player and not seen[player] then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				seen[player] = true
				table.insert(list, player)
			end
		end
	end
	return list
end

local function runPad(pad: BasePart, placeId: number)
	while true do
		local waiting = playersOnPad(pad)
		if #waiting == 0 then
			pad:SetAttribute("Countdown", nil)
			task.wait(0.5)
			continue
		end
		local remaining = COUNTDOWN
		while remaining > 0 do
			pad:SetAttribute("Countdown", remaining) -- a SurfaceGui reads this
			task.wait(1)
			remaining -= 1
			if #playersOnPad(pad) == 0 then break end
		end
		local group = playersOnPad(pad)
		if remaining <= 0 and #group > 0 then
			while #group > MAX_PLAYERS do table.remove(group) end
			local options = Instance.new("TeleportOptions")
			options.ShouldReserveServer = true -- a private server just for this group
			local ok, err = pcall(function()
				TeleportService:TeleportAsync(placeId, group, options)
			end)
			if not ok then warn("Queue pad teleport failed:", err) end
			task.wait(3) -- let the teleport take the players before polling again
		end
	end
end

return runPad
```

Notes on the code: the countdown resets if the pad empties; the group is re-read at the end so latecomers are included and leavers are not; the filter includes only characters so props on the pad do not matter. Teleports fail sometimes; the docs describe `TeleportInitFailed`, which hands back options you can retry with. See [[Teleporting and Multi-Place Games]] for retries and data hand-off, and [[Round-Based Minigame Loop End to End]] for the in-place alternative to teleporting.

### Portals inside one place

When "portals" lead to zones in the same place, the destination must be streamed before the character arrives, or the player lands in a void and falls. Call `Player:RequestStreamAroundAsync(position)` before moving the character (Roblox docs: it asks the server to stream around a location you are about to move to, with no guarantee of what loads). Measured in the reference project, the death flow requested streaming around the respawn spot before pivoting the player there. Keep the portal effect playing for the duration of that request so the wait reads as travel, not lag.

## 5. Returning players and the hub skip

Veterans do not need the hub every time. Options:

| Option | For | Against |
|---|---|---|
| Always spawn in the hub | Simple; everyone sees new content and the shop | Veterans walk the same 20 s every session |
| Spawn at the last realm or zone | Fast return to play | They may never see new hub content or events |
| Hub spawn with a "continue" portal right at the spawn | Both: one step back into play, hub still visible | One more portal to design |
| Short arrival in the hub, then a prompt to continue | Shows event banners once | Easy to make annoying |

The third option is usually best for progression games: the spawn pad has a "return to Zone N" portal within a few studs, framed so that the hub's live content (an event rift, a new station) is visible behind it. Measured in the reference project: deaths in a realm respawned the player in front of a hub return portal, and players who stood in a zone they had not unlocked were sent to the lobby by a gate guard. Make each context's arrival point explicit, as shown in [[Spawn Points Safe Zones and Respawn Flow]].

## 6. The hub's performance budget

The hub is the most visited space and the place new players load first, often on the weakest devices. Its budget should be the tightest in the game, not the loosest.

- **Instance count.** Measured in the reference project: hub designs ranged from about 913 to about 4,531 instances. Neither number is a limit; what matters is the frame time and memory on a low-end phone while 10 players and their effects are in view. Profile in the hub specifically. See [[Mobile and Low-End Optimization]] and [[Art Budgets - Triangles Draw Calls Memory]].
- **Animated decoration.** Measured in the reference project: hub effects only animated within a range (280 to 650 studs depending on the effect) and gate frames within 900 studs, so nothing animates for players far away. Apply the same rule on the client: pause loops for decorations the camera cannot see.
- **Leaderboards and SurfaceGuis.** Each board is UI the client renders. Several large scrolling boards on the spawn avenue cost more than they look. Fewer rows, slower refresh.
- **Fast join.** The hub is what must be ready for the first frame. Defer distant decoration, and do not block the spawn on the whole hub streaming in. See [[Case Study - Fast Join and Deferred Loading]].

## 7. Seasonal and event dressing

Live games redecorate the hub for events. Treat event dressing as its own layer:

- One folder per event, added and removed as a unit.
- Event dressing must not move stations, prompts, spawns or bounds. If it needs to, it is a hub change and goes through the hook contract described in [[Lobby and Hub Design]].
- Recheck prompt line of sight and the spawn's first frame after adding dressing. Festive arches are a classic prompt blocker.
- Schedule removal. Stale event dressing is a common "is this game dead?" signal. See [[Live Ops Events and Updates]].

## 8. Social nodes

Players hang out where three things meet: somewhere to stand still, something to look at, and other people passing by. Good social nodes in a hub:

- A centrepiece with a ledge or steps to stand on.
- Leaderboards with standing room in front, off the main flow.
- Emote or photo spots with a good camera background (the centrepiece behind them).
- Trading or showcase plazas, if your game has trading, close to but not on the return flow.

Avoid hiding social nodes in corners: people stand where they can be seen. See [[Social Design and Multiplayer Play]].

## 9. When not to build a hub

- **Single-loop games** (pure obbies, short round games) may be better with no hub: spawn into play, put the shop in the UI.
- **Very small player counts per server** make a large hub feel abandoned. A compact menu room or a UI-only lobby may serve better.
- **A hub as a separate place** costs a teleport each way. Only split it out when its content or performance needs justify the extra load time; see [[Teleporting and Multi-Place Games]].

## 10. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Built for the impressive jobs first | New players wander; low first-action rate | Rank the jobs; build spawn and exits first |
| Loiter node on the spawn line | New players spawn into a crowd | Move boards and benches off the spawn axis |
| Shop off the return flow | Low station visits from veterans | Put the core spend station on the way out |
| Prompts blocked by decoration | "Station sometimes does not work" | Move the prompt, disable `CanQuery` on decor, or drop line of sight |
| Stations too close | Prompts flicker between two stations | Space prompt points about twice the range |
| Pad detection with `Touched` | Players on the pad not counted | Poll a box with `GetPartBoundsInBox` |
| Portal without streaming | Players arrive in a void and fall | `RequestStreamAroundAsync` before the move |
| Hub heavier than any zone | Low-end phones stutter on join | Hub gets the tightest budget |
| Event dressing never removed | Hub looks stale | Folder per event with a removal date |

## 11. Checklist

- [ ] Hub jobs ranked; spawn and exits designed first.
- [ ] First-time, return and loiter flows drawn; no crossings at chokes.
- [ ] Time budgets met: first station under 15 s, exit under 20 s for veterans.
- [ ] Core size feels occupied with the typical player count.
- [ ] Every prompt visible from its standing spots; no decoration blocking line of sight.
- [ ] Prompt points at least about twice the activation distance apart.
- [ ] Queue pads polled with spatial queries, with countdown and safe walk-off.
- [ ] In-place portals request streaming before moving the player.
- [ ] Hub profiled on a low-end phone with several players present.
- [ ] Event dressing in its own folder with a removal date.

## See also

- [[Level Design Start Here]], [[Level Design for Roblox]], [[Lobby and Hub Design]].
- [[Level Design Principles - Flow Sightlines and Landmarks]], [[Spawn Points Safe Zones and Respawn Flow]], [[Teaching Through Level Design]].
- [[Teleporting and Multi-Place Games]], [[Round-Based Minigame Loop End to End]], [[Instance Streaming]].
- [[First-Time User Experience and Onboarding]], [[Social Design and Multiplayer Play]], [[Menu Archetypes - Shop Settings Codes Rewards]].

## Connected notes
<!-- auto-links:start -->
[[Arena Rounds with Teams and Spectating End to End]] · Spawning Teams and Rounds · [[Combat Arena and Encounter Layout]] · Multiplayer Services Start Here · Streaming Radius · Environment and Level Pipeline
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Playtest Heatmaps - Position and Death Maps]] · [[Instanced Interiors - Pooled House and Room Copies for Many Players]] · [[Objective Mode Maps - Capture the Flag, King of the Hill and Control Points]] · [[Kill Planes, Map Boundaries and Out-of-Bounds Recovery]] · [[ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab]] · [[Level of Detail and Model Streaming]] · [[Obby and Platforming Level Design]]
<!-- related:end -->
