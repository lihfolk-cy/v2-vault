---
tags: [narrative, cutscenes, camera, networking, server-time, late-join, skip-vote, type/guide, area/narrative, level/advanced, api/Workspace, api/RemoteEvent]
---
# Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: One-shot remote to start the scene -> Replicated state with `StartAt`
> - Avoid: Tween chains for camera moves -> Sample a timeline by `t`
> - Avoid: Client says "done" to unfreeze the boss -> Server timeline owns gameplay
> - Server publishes id, `StartAt`, duration and participants as replicated attributes.
> - Every element of the scene can be rendered from an arbitrary `t`.
> - Gameplay freezes and unfreezes on the server timeline only.
>
> Cost: TL;DR ~150 tok · whole note ~2.5k tok. Read more: ## 2. Making the cutscene seekable · ## 4. Skipping · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A single-player cutscene is a camera script. A shared cutscene (boss intro for the whole party, a story beat in a co-op chapter, a round-start flyover) is a networking problem: every client must show the same moment at the same time, a player who joins or respawns mid-scene must land at the right frame, and one impatient player must not be able to skip for everyone or hold everyone hostage. The camera runner itself (save, hide, play, restore, watchdog) is in [[Cameras and Cutscenes]]; this note adds the timing and group rules on top.

Source labels: **Roblox docs**, **Rule of thumb**.

---

## 1. Model: the server schedules, clients render

The server never moves cameras. It publishes *what* plays and *when*, in server time:

```
Cutscene state = { id: string, startAt: number (server time), duration: number, participants: {userId} }
```

- `workspace:GetServerTimeNow()` returns a clock synchronised between server and clients (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/Workspace#GetServerTimeNow). Both sides compute `t = GetServerTimeNow() - startAt`.
- Schedule slightly in the future (`startAt = now + 0.5` to `1.0` s) so the message reaches everyone before frame zero. Clients that receive it late simply start at `t > 0`.
- Publish the state as **attributes on a replicated folder** (or a value object), not only as a one-shot `RemoteEvent`. Attributes replicate to late joiners automatically; events do not.

```lua
--!strict
-- Server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local state = ReplicatedStorage:WaitForChild("CutsceneState") :: Folder

local Cutscenes = {}

function Cutscenes.play(id: string, duration: number, participants: { Player })
	local ids = table.create(#participants)
	for i, p in participants do ids[i] = p.UserId end
	state:SetAttribute("Participants", table.concat(ids, ","))
	state:SetAttribute("Duration", duration)
	state:SetAttribute("StartAt", Workspace:GetServerTimeNow() + 0.75)
	state:SetAttribute("Id", id) -- set last: clients react to Id changing
	task.delay(duration + 0.75, function()
		if state:GetAttribute("Id") == id then
			state:SetAttribute("Id", "")
		end
	end)
end

return Cutscenes
```

Gameplay that the cutscene covers (boss invulnerable, enemies frozen, timers paused) is enforced **on the server** for exactly `[startAt, startAt + duration]`. Never trust a client "cutscene finished" message to unfreeze the boss.

## 2. Making the cutscene seekable

Late join and respawn only work if the client can render the cutscene from any `t`. Design for that from the start:

| Element | Seek method |
|---|---|
| Camera path | Keyframes or a spline sampled by `t`, not a chain of tweens started in sequence |
| Animations | `AnimationTrack.TimePosition = t - clipStart` after `Play()`; clips must be loaded on the client ([[Cameras and Cutscenes]]) |
| Dialogue and subtitles | A timeline of `{at, line}`; show the current line, not the history |
| Sounds and music | `Sound.TimePosition` / `AudioPlayer.TimePosition` set before play; skip one-shots whose time has passed |
| VFX | Fire only events whose time is in the future; permanent state (a door now open) applied directly |
| World changes | Final world state set by the server, so a late joiner sees the result even if they miss the scene |

```lua
--!strict
-- Client: render from any time t
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local state = ReplicatedStorage:WaitForChild("CutsceneState") :: Folder
type Runner = { play: (id: string, fromT: number) -> (), stop: () -> () }
local runner: Runner = require(script.Parent:WaitForChild("CutsceneRunner")) :: any

local function isParticipant(): boolean
	local list = state:GetAttribute("Participants")
	if typeof(list) ~= "string" then return false end
	return table.find(string.split(list, ","), tostring(Players.LocalPlayer.UserId)) ~= nil
end

local function sync()
	local id = state:GetAttribute("Id")
	if typeof(id) ~= "string" or id == "" or not isParticipant() then
		runner.stop()
		return
	end
	local startAt = state:GetAttribute("StartAt") :: number
	local duration = state:GetAttribute("Duration") :: number
	local t = Workspace:GetServerTimeNow() - startAt
	if t >= duration - 0.5 then return end -- nearly over: do not hijack the camera
	if t < 0 then task.wait(-t); t = 0 end
	runner.play(id, t)
end

state:GetAttributeChangedSignal("Id"):Connect(sync)
sync() -- late joiner: a scene may already be running
```

**Rule of thumb.** If less than about 1 to 2 seconds remain, or the player joined mid-scene and the scene is long, show a short "story in progress" card instead of dropping them into the middle of a camera move.

## 3. Who watches

- **Participants** are fixed when the scene starts: players in the boss arena, the party, the round's players. Spectators, lobby players and players who joined the server for a different area keep playing; their gameplay is not frozen.
- Respawning participants re-run `sync()` on `CharacterAdded`; the runner's restore step must not fire mid-scene for them.
- If the scene's focus object (boss) is streamed out for a client, the runner must wait for it or fall back to a static shot ([[Instance Streaming]], [[Streaming Joins - Frozen Players and Loading Screen Teardown]]).

## 4. Skipping

Three policies, choose per scene:

| Policy | How | Use for |
|---|---|---|
| Local skip | The client stops rendering; server timeline continues; player waits on a "waiting for others" card or regains control in a safe state | Long story scenes where gameplay is frozen anyway |
| Vote skip | Each participant sends `SkipVote`; server ends the scene early when votes reach a threshold | Co-op chapters, boss intros seen before |
| Unskippable | Short (under about 5 s) and gameplay-critical | Round-start countdown flyover |

Vote-skip rules (**Rule of thumb**):
- Threshold: all participants for 2 players, majority (`ceil(n / 2) + 1` capped at n) beyond that, or "everyone who has seen it before" if you track a `Seen_<id>` profile flag.
- Votes only accepted after a minimum time (2 to 3 s) and only from participants; rate-limit the remote ([[Rate Limiting and Abuse Prevention]]).
- Players who disconnect are removed from the denominator.
- Show the count ("2/3 want to skip") so nobody wonders what is happening.
- Early end: the server sets `Duration` to `now - startAt + 0.5` (a short fade), not an instant cut, then clears `Id`. Server-side gameplay unfreezes on the same schedule.

```lua
--!strict
-- Server: vote skip
local votes: { [number]: boolean } = {}
local function onSkipVote(player: Player, participants: { Player }, startAt: number)
	if workspace:GetServerTimeNow() - startAt < 2 then return end
	if not table.find(participants, player) then return end
	votes[player.UserId] = true
	local count = 0
	for _, p in participants do
		if votes[p.UserId] then count += 1 end
	end
	local need = if #participants <= 2 then #participants else math.min(#participants, math.ceil(#participants / 2) + 1)
	if count >= need then
		-- end the scene early: shorten Duration, unfreeze gameplay, clear votes
		table.clear(votes)
	end
end
```

## 5. Failure handling

- **Client error mid-scene**: the runner's watchdog restores the camera at `startAt + duration + 2` regardless.
- **Server shutdown or teleport**: clients clear the scene when `Id` becomes empty or the player leaves the area.
- **Clock jumps**: `GetServerTimeNow` can correct by small amounts; sample it every frame rather than accumulating `dt`, and accept a few frames of drift on animations (re-seek only if off by more than about 0.15 s).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| One-shot remote to start the scene | Late joiners and respawns see nothing or break | Replicated state with `StartAt` |
| Tween chains for camera moves | Cannot seek | Sample a timeline by `t` |
| Client says "done" to unfreeze the boss | Exploiters skip invulnerability windows | Server timeline owns gameplay |
| Any player can skip for all | Griefing, story missed | Vote threshold or local skip |
| Dropping a late joiner into the last second | Camera snap, confusion | Minimum remaining time or a card |
| Non-participants frozen | Lobby players locked out | Explicit participant list |

## Checklist
- [ ] Server publishes id, `StartAt`, duration and participants as replicated attributes.
- [ ] Every element of the scene can be rendered from an arbitrary `t`.
- [ ] Gameplay freezes and unfreezes on the server timeline only.
- [ ] Skip policy chosen per scene; votes validated, rate-limited and shown.
- [ ] Watchdog restores cameras even if the client errored.
- [ ] Tested with a client joining mid-scene and one respawning mid-scene.

## See also
[[Cameras and Cutscenes]] · [[Camera Systems]] · [[Dialogue System End to End]] · [[Boss Animation and Phases]] · [[Replication Rules]] · [[Multi-Client and Live Testing]] · [[Narrative Start Here]]

## Connected notes
<!-- auto-links:start -->
[[Lore Delivery Without Walls of Text]] · [[Boss Fight Design Patterns]] · Round-Based Minigame Loop End to End · [[Story State Flags and Chapter Saves]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Server-Authoritative Freeze and Stun Timestamps]] · [[A Stuck Player Watchdog That Logs the Cause]] · [[Puzzle Dependency Charts and Hint Systems]] · [[Writing Dialogue for Roblox Players]] · [[Quest Writing and Hooks]] · [[Naming Items Zones and Abilities]] · [[Localization-Ready Writing]]
<!-- related:end -->
