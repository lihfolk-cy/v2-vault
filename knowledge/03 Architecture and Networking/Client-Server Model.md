---
tags: [architecture, networking, client-server, fundamentals, security]
---
# Client-Server Model

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Client changes `leaderstats` or an attribute and expects the... -> Send a request; the server changes it
> - Avoid: Server reads a value the client wrote locally -> Keep authoritative values on the server only
> - Avoid: Client computes damage and sends it -> Server computes damage from server-side stats
> - Every value that grants power or currency is computed and stored on the server.
> - No secrets in ReplicatedStorage, ReplicatedFirst, Workspace, StarterGui or StarterPlayer.
> - Every remote handler validates type, value, context and rate before acting.
>
> Read more (19 KB note): ## Latency: the other half of the model · ## A minimal correct round trip · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Every Roblox experience is a distributed program. One **server** runs the authoritative copy of the game; every player runs a **client** with a partial, delayed copy. Almost every hard bug in a multiplayer Roblox game (duplicated items, enemies that "teleport", effects only one player sees, a shop that gives free items) comes from code that forgot which side it was on, or trusted the wrong side. This note is the map: what runs where, what each side can see and change, what the latency looks like, and how to decide where a piece of logic belongs.

The rest of this section builds on it: [[Replication Rules]] (what crosses the boundary on its own), [[RemoteEvents RemoteFunctions and Unreliable Remotes]] (what you send across it), [[Network Ownership]] (who simulates physics), [[Server Authority and Validation]] and [[Exploits and Anti-Cheat]] (what to do about the fact that clients lie).

## The two DataModels

When a game starts, Roblox takes the published place (the "edit" DataModel you built in Studio) and runs a copy of it on a Roblox server as the **runtime DataModel** (Roblox docs, "Client-server runtime"). Each player who joins receives their own copy of that runtime DataModel, minus the containers the server never sends, and with Workspace content arriving gradually if [[Instance Streaming]] is on.

From that point there are N+1 DataModels: the server's, and one per client. They start identical (apart from server-only containers) and then drift. **Replication** is the engine process that pushes server changes out to clients so they stay roughly in sync. It is mostly one-way. A client can change anything in its own copy, and in almost all cases that change stays on that client.

```text
                    +-----------------------------+
                    |           SERVER            |
                    |  ServerScriptService        |
                    |  ServerStorage              |
                    |  Workspace (everything)     |
                    |  ReplicatedStorage          |
                    +------+-------------+--------+
              replication  |             |  replication
              (automatic)  |             |  (automatic)
                    +------v----+   +----v------+
                    | CLIENT A  |   | CLIENT B  |
                    | Workspace |   | Workspace |
                    | (partial) |   | (partial) |
                    | PlayerGui |   | PlayerGui |
                    +-----------+   +-----------+
        remotes, owned physics, a few engine-defined exceptions go back up
```

## Who runs what

| Side | Runs | Can see | Can change for everyone |
|---|---|---|---|
| Server | `Script` (RunContext Legacy in server containers, or `Server`) | Everything, including ServerStorage and ServerScriptService | Yes: any instance or property it changes replicates (subject to streaming on the receiving side) |
| Client | `LocalScript`, `Script` with RunContext `Client`, ModuleScripts they require | Everything replicated to it, plus anything it creates locally | Only through the narrow exceptions in [[Replication Rules]]: remotes, physics of parts it owns, its own character's animations, and a handful of engine events |

ModuleScripts run on whichever side requires them, and a module required on both sides is two independent copies with separate state. A module in ReplicatedStorage that holds a `coins` table on the server and a different `coins` table on each client is a classic source of "the UI shows 500 but the server says 20". See [[Module Scripts and Requiring]] and [[Script Types and Run Context]].

## Containers and visibility

Where an instance lives decides who receives it. This is the most important table in the section.

| Container | Sent to clients? | Notes |
|---|---|---|
| `Workspace` | Yes | With streaming on, BaseParts and most models arrive by distance; the server always has all of it |
| `ReplicatedFirst` | Yes, first | Loaded before anything else on join; use for loading screens and the client bootstrap |
| `ReplicatedStorage` | Yes, all at join | Not streamed. Shared modules, remotes, assets the client clones |
| `Lighting`, `SoundService`, `Teams`, `StarterGui`, `StarterPack`, `StarterPlayer` | Yes | Starter containers are templates copied into each player |
| `Players.<Player>.PlayerGui`, `.Backpack` | Only to that player | Server-created UI placed here is only visible to its owner |
| `ServerScriptService` | **Never** | Server scripts and server-only modules |
| `ServerStorage` | **Never** | Server-only assets, templates, test flags, secret config |

Two consequences that matter for security:

1. **Anything in a replicated container is public.** Exploiters can read every replicated instance and decompile every replicated `LocalScript`, client `Script` and `ModuleScript`, even ones that are disabled or never required (Roblox docs, "Access control and confidentiality"). Prices in a ReplicatedStorage config module, an admin list in a client script, a "secret" code list in a ModuleScript: all of it can be read.
2. **ServerStorage and ServerScriptService are your only private storage.** One production game kept its admin panel's client UI in ServerStorage and cloned it into an admin's `PlayerGui` on join. Non-admins never receive the code at all, and the server re-checks the caller on every admin request regardless, because the client UI is a convenience, not a gate.

## What a client can do (assume all of it)

The Roblox security docs list what a determined exploiter controls. Paraphrased:

- Decompile any replicated LocalScript or ModuleScript.
- Take network ownership of their character and any unanchored parts the engine hands them, and set their position, rotation and velocity to anything, including `inf` and `NaN`.
- Trigger client-initiated events (Touched, ProximityPrompt, ClickDetector) at any range and any frequency.
- Fire or invoke any RemoteEvent or RemoteFunction with arbitrary arguments, at any rate. The only argument they cannot forge is the first `player` parameter the server receives.
- Change anything in their local DataModel without firing the usual events.
- Alter the behaviour of any code running on their machine.

So the working model is: **the client is a rendering terminal and an input device that sometimes lies.** It is extremely good at the first job and should never be trusted for anything that matters. The server's job, per the docs, is to receive input, validate that the requested action is possible and permitted, execute it, update authoritative state, and replicate results.

## Latency: the other half of the model

Even honest clients disagree with the server, because everything takes time to travel.

| Path | Typical delay |
|---|---|
| Client input to server | One-way latency, roughly half the round trip (rule of thumb: 30 to 150 ms for most players, much worse on mobile data) |
| Server change to a client | Same one-way latency, plus replication batching |
| Client A's action seen by client B | A to server, then server to B: about a full round trip |
| `Player:GetNetworkPing()` | Round-trip network latency in seconds, measured without processing time (Roblox docs) |

This creates three different "nows":

- **The owner's now.** The player sees their own character and their own predicted effects with zero delay.
- **The server's now.** The server sees the player's character where the client was about half a round trip ago.
- **Everyone else's now.** Other players see that character where it was about a full round trip ago, smoothed by interpolation.

Gameplay decisions must be made in the server's now, while presentation should happen in the viewer's now. That split is the root of most architecture choices in combat games: the attacker's client plays the swing instantly, the server decides the hit using its own state plus a latency tolerance, and the victim's client shows the result when it arrives. See [[Hitboxes and Hit Detection]] and [[Combat Systems Architecture]].

### A shared clock

`os.clock()` and `tick()` are local to each machine. For anything both sides must agree on (an ability's start time, a round timer, an animation that every client joins part-way through), use `workspace:GetServerTimeNow()`, which returns an estimate of the server's time on any machine.

```lua
--!strict
-- Shared helper: how far into a server-started action are we, on any machine?
local Workspace = game:GetService("Workspace")

local function elapsedSince(serverStartTime: number): number
	return math.max(0, Workspace:GetServerTimeNow() - serverStartTime)
end

return elapsedSince
```

The server writes the start time once (an attribute or a remote argument), and every client computes its own offset. One production game drove all enemy animation this way: the server wrote `AnimT = GetServerTimeNow()` with the clip name, and each client started the clip at `(now - AnimT) * speed` so late joiners and laggy clients were still in sync (see [[Enemy Animation State Protocol]]).

## The simulation is split three ways

Physics is not simply "on the server". Roblox uses **distributed physics**: each unanchored assembly is simulated by exactly one machine, its network owner (Roblox docs, "Network ownership").

| Thing | Simulated by | Consequence |
|---|---|---|
| Anchored parts | Server (always; cannot be changed) | Clients cannot move them for others |
| A player's own character | That player's client | The client decides where it is. Speed, fly and teleport hacks start here |
| Unanchored parts near a player | Often that player's client (automatic ownership) | That client can move them, fling them, fake their Touched events |
| NPCs and props you lock with `SetNetworkOwner(nil)` | Server | Authoritative, but clients see them with latency and possible jitter |

This is why "validate everything" is not only about remotes. Character position, owned parts and Touched events are all client-authored data that arrive through the engine, not through your code. See [[Network Ownership]].

A newer option, the **server authority model** (`Workspace.AuthorityMode = Server`, with client prediction and rollback), moves character and physics simulation to the server while clients predict. The Roblox docs describe it as in beta and "will be released soon" (as of October 2026); check its status before relying on it. Everything in this section assumes the classic model unless it says otherwise.

## Where should this code live? (decision table)

| Logic | Side | Why |
|---|---|---|
| Currency, inventory, progression, cooldowns that gate power | Server | Any client copy can be edited |
| Damage numbers, hit decisions, kill credit | Server | Clients would choose their own damage |
| Prices, drop tables, odds | Server (a client copy for display only) | Display copies are readable but harmless if the server never reads them back |
| Input reading, camera, UI, sounds, VFX | Client | Only the local player needs them; zero latency |
| Your own character's animation | Client (owner) | Replicates through the Animator; see [[Replication and Ownership]] |
| Enemy AI decisions | Server | Shared world state |
| Enemy animation and effects for many NPCs | Every client, driven by small server state | Server CPU and bandwidth stay flat; see [[Entity Component Systems]] |
| Pure maths both sides need (level curve, damage formula preview) | Shared module | The server result is authoritative; the client copy is prediction or display |
| Secrets (API keys, admin lists, codes) | ServerStorage or server modules, or HttpService secrets | Replicated means public |

## Responsiveness without trust

The tension is permanent: authority wants everything on the server, feel wants everything on the client. The patterns that resolve it:

1. **Predict, then confirm.** The client shows the result immediately (button press animates, swing plays, coin counter ticks), sends the request, and reconciles when the server answers. If the server rejects, roll the presentation back quietly.
2. **Request intent, not outcome.** "I swung at time T facing direction D" instead of "I hit enemy 12 for 400". The server derives the outcome. See [[Server Authority and Validation]].
3. **Replicate state, derive presentation.** The server writes small facts (attributes like `State = "Stunned"`, `AnimT`); every client turns them into animation, VFX and UI. Presentation can be rich without the server sending rich data. See [[Replication Rules]].
4. **Data-driven timing.** When the server must know when a hit lands, it reads the time from data (marker times exported from the clip, a table of hit frames) instead of waiting for the client to say so. One production combat game computed ability hits per segment on the server from shared timing data, so the caster's client could animate freely while the server applied damage on schedule. See [[Markers and Events]].

## A minimal correct round trip

The smallest example that shows every rule: a "claim daily reward" button.

```lua
--!strict
-- ServerScriptService/DailyReward.server.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local claimRemote = remotes:WaitForChild("ClaimDaily") :: RemoteEvent
local resultRemote = remotes:WaitForChild("DailyResult") :: RemoteEvent

local COOLDOWN = 20 * 60 * 60 -- seconds between claims (server-side truth)
local REWARD = 250

-- Server-owned state. In a real game this lives in the player's profile.
local lastClaim: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}

claimRemote.OnServerEvent:Connect(function(player: Player)
	-- No arguments are trusted because none are accepted.
	if busy[player] then return end -- ignore re-entry while one claim is in flight
	busy[player] = true

	local now = os.time()
	local last = lastClaim[player] or 0
	if now - last >= COOLDOWN then
		lastClaim[player] = now -- mark BEFORE paying, so a re-entrant request cannot pay twice
		local coins = (player:GetAttribute("Coins") :: number?) or 0
		player:SetAttribute("Coins", coins + REWARD) -- server write: replicates to the owner's UI
		resultRemote:FireClient(player, true, REWARD)
	else
		resultRemote:FireClient(player, false, COOLDOWN - (now - last))
	end

	busy[player] = nil
end)

Players.PlayerRemoving:Connect(function(player)
	lastClaim[player] = nil
	busy[player] = nil
end)
```

```lua
--!strict
-- StarterPlayerScripts/DailyRewardClient.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local claimRemote = remotes:WaitForChild("ClaimDaily") :: RemoteEvent
local resultRemote = remotes:WaitForChild("DailyResult") :: RemoteEvent

local function onClaimPressed()
	-- Optimistic UI could start a spinner here; the server decides the outcome.
	claimRemote:FireServer()
end

resultRemote.OnClientEvent:Connect(function(ok: boolean, value: number)
	if ok then
		print(("Claimed %d coins"):format(value))
	else
		print(("Come back in %d seconds"):format(value))
	end
end)

-- Wire onClaimPressed to a button in your UI code.
```

What makes it correct: the client sends no data the server uses, the cooldown and reward live on the server, the claim is marked before the reward is granted, the result travels back as a separate message, and per-player state is cleaned up on leave. A real version also rate-limits the remote ([[Rate Limiting and Abuse Prevention]]) and saves the claim time with the profile ([[Saving Correctly - Autosave and BindToClose]]).

## Nuances where the obvious answer is wrong

- **"The server sees what the client sees."** No. The server sees every player's character late, and with streaming the client does not have most of the world. Code that runs fine in Play Solo (zero latency, everything loaded) fails live. Test with network simulation and multiple clients ([[Testing Modes - Play Run and Multi-Client]]).
- **"LocalScripts can't hurt the server."** A LocalScript can do anything to the server that the server lets a remote, an owned part, a prompt or a Touched event do. The risk is in the server's handlers, not in the LocalScript.
- **"Put it in ReplicatedStorage so both sides can use it."** Fine for code that must exist on both sides. Wrong for server logic: decompilation exposes your rules and makes exploits easier to find (Roblox docs warn against mixed server/client modules).
- **"The server is fast, so do everything there."** Server CPU is shared by every player in the instance. Animation for 200 NPCs, per-frame raycasts for every projectile, or per-frame UI state on the server will drop the server's frame rate for everyone, and every server-side visual change costs bandwidth. Do decisions on the server and presentation on clients.
- **"Studio Play Solo proves it works."** Play Solo runs client and server in one process with no latency and a tiny world. Teleports do not work in Studio at all ([[Teleporting and Multi-Place Games]]), and some behaviours (like ids registered for Studio only) look like replication bugs only in live servers ([[Case Study - Abilities That Only Worked in Studio]]).

## Common mistakes

| Mistake | What it looks like | Fix |
|---|---|---|
| Client changes `leaderstats` or an attribute and expects the server to see it | Works for the player, reverts on rejoin, other players see old values | Send a request; the server changes it |
| Server reads a value the client wrote locally | The server sees the old value (the change never replicated) | Keep authoritative values on the server only |
| Client computes damage and sends it | Exploiters one-shot bosses | Server computes damage from server-side stats |
| One ModuleScript with server and client branches in ReplicatedStorage | Server logic visible to exploiters | Split into a server module (ServerScriptService) and a client module |
| Timers with `os.clock()` across the boundary | Effects out of sync by seconds | `workspace:GetServerTimeNow()` |
| Assuming a Workspace object exists on the client | `attempt to index nil` on join or after walking away | `WaitForChild` with timeout, tags, streaming-aware code; see [[Instance Streaming]] |

## Checklist

- [ ] Every value that grants power or currency is computed and stored on the server.
- [ ] No secrets in ReplicatedStorage, ReplicatedFirst, Workspace, StarterGui or StarterPlayer.
- [ ] Every remote handler validates type, value, context and rate before acting.
- [ ] Shared timing uses `GetServerTimeNow()`.
- [ ] Presentation (VFX, sound, camera, UI) runs on clients, driven by small replicated state.
- [ ] Tested with two or more clients and simulated latency, not only Play Solo.

## See also
[[Replication Rules]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Network Ownership]] · [[Server Authority and Validation]] · [[Exploits and Anti-Cheat]] · [[Project Structure and Bootstrapping]] · [[Script Types and Run Context]] · [[Replication and Ownership]] · [[Network Performance]]

## Connected notes
<!-- auto-links:start -->
[[How Exploits Work - The Client Boundary]] · [[Replication Boundary]] · [[Server Authority]] · [[Client Prediction and Reconciliation for Combat]] · [[Debugging Client-Server Desync]] · [[Skill - Roblox Secure Remotes]]
<!-- auto-links:end -->
