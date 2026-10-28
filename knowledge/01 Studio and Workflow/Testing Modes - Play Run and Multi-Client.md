---
tags: [studio, testing, playtest, multiplayer, emulation, workflow]
---
# Testing Modes - Play Run and Multi-Client

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Testing only in solo Test -> Server & Clients for every multiplayer feature
> - Avoid: Tuning during a test -> Copy, Stop, paste, or tune attributes in Edit
> - Avoid: Assuming Pause freezes everything -> Know which RunService events pause
> - Each new feature tested in Run, Test (both sides), and Server & Clients.
> - Network Simulator pass at 3G for anything latency-sensitive.
> - Device Simulator pass for every UI change.
>
> Read more (15 KB note): ## 1. The modes · ## 6. What Studio tests do not tell you · ## 10. Common mistakes · ## 11. Checklist
<!-- tldr:end -->

Studio can run your game in several ways: one player with a local server, a server with no player, a real server with up to eight clients, a shared test with teammates, and with emulated devices and bad networks. Each mode answers a different question, and each lies to you in specific ways. This note maps the modes to the questions, lists what behaves differently in Studio than in a live server, and adds the scripted testing services that let a plugin or pipeline drive tests. Mode names changed in recent Studio versions: the old **Play / Play Here** are now **Test / Test Here** in the mezzanine dropdown (Docs, October 2026).

Source labels: **Docs**, **Measured** (reference project), **Rule of thumb**.

---

## 1. The modes

All are in the left part of the mezzanine: choose a mode in the dropdown, then press the Play button beside it (Docs).

| Mode | Shortcut | What runs | Use it for |
|---|---|---|---|
| **Test** | `F5` | A client and a server simulation; your avatar spawns at a `SpawnLocation` or around `(0, 100, 0)` | Day-to-day gameplay checks |
| **Test Here** | | Same, avatar placed in front of the camera | Jumping straight to the area you are working on |
| **Run** | `F8` | Server simulation only, no avatar; you fly the Studio camera | Physics, NPCs, world systems, server-only logic |
| **Server & Clients** | `F7` | A server window plus 1 to 8 client windows | Replication, multiplayer interactions, ownership |
| **Team Test** | | A shared test session teammates can join | Testing with collaborators in Team Create |

During a test the mezzanine gains **Pause/Resume**, **Step**, **Stop** (`Shift F5`) and, in solo modes, the **Client/Server** toggle (Docs).

### Client/Server toggle

A solo test runs two simulations. **Client** mode: blue viewport border, your controls and camera. **Server** mode: green border, your character exists but is not controlled; you get a free camera and can select and inspect server objects (Docs). Output tags client lines blue and server lines green; a ModuleScript's lines take the colour of whoever required it (Docs).

Use the toggle to answer "does the server agree?" questions: is that part where the client thinks it is, does the server see the attribute the client set (it should not, unless replicated from the server), did the server-side NPC actually die. See [[Replication Rules]].

### Pause and Step

Pause stops physics and animations on both sides by default, or on one side via the button's arrow menu. **Step** advances one 1/60 s frame (Docs). What pauses is subtle (Docs):
- Paused: `RunService.PreAnimation`, `PreSimulation`, `PostSimulation`, `Stepped`.
- Still firing: `PreRender`, `Heartbeat`, `RenderStepped`.
- Scripts keep running.

So a gameplay loop on `Heartbeat` keeps going while physics is frozen. If you want "freeze the world and inspect", put simulation logic on `PreSimulation`/`PostSimulation` (see [[Frame Order and RunService Timing]]) or add your own debug pause flag.

## 2. Multi-client tests

**Server & Clients** opens separate Studio windows for the server and each client; usually one or two clients are enough, up to eight are supported (Docs). End with **End Session** from any window.

What only multi-client tests catch (Rule of thumb):
- Effects that play on the caster's client but never reach other players (see [[RemoteEvents RemoteFunctions and Unreliable Remotes]]).
- Network ownership handoffs: a part one client owns jitters on another (see [[Network Ownership]]).
- Join-in-progress bugs: start the test with one client, then add players later. `StudioTestService:AddPlayers` does this from code (Docs).
- UI that reacts to *other* players (leaderboards, party lists, nametags).
- Animation replication differences (see [[Replication and Ownership]] in the Animation section).

Costs: each client is a full Studio instance. Eight clients on a big place can exhaust RAM. On a laptop, two clients is the practical limit (Rule of thumb).

**Party Simulator** (Docs) assigns test players to simulated parties in Server & Clients tests, so `Player.PartyId`, `SocialService:GetPartyAsync()` and `SocialService:GetPlayersByPartyId()` return simulated data.

## 3. Team Test

With collaboration on, choose **Team Test** and press Play to start a shared session; teammates join with their Play button. Only one Team Test session runs at a time, and **End Session** kicks everyone (Docs). Team Test runs on Roblox servers, so it has real network latency, unlike local tests.

**Measured hazard.** In a shared place, someone playtesting changes what you see: server event logs fill with their actions, and a test-mode flag they set (for example a "force event" attribute) changes behaviour for everyone. In the reference project the rule became: when something odd happens, check whether someone else is playing before chasing a bug.

## 4. Device, controller and network emulation

- **Device Simulator** previews screen size, pixel density, on-screen keyboard and touch for devices you do not own; it pairs with **Controller Emulator** for gamepads, VR controllers and TV remotes (Docs). Open it from the **Test** menu. See [[Responsive UI for Phone Tablet Console and PC]].
- **Network Simulator** (beta, enabled through **File > Beta Features > New Device Simulator** as of October 2026) adds latency, jitter and packet loss per direction. Presets, as latency / jitter / loss (Docs):

| Preset | Inbound | Outbound |
|---|---|---|
| Ideal Fiber | 8 ms / 0 ms / 0.00% | 8 ms / 0 ms / 0.00% |
| Wired Broadband | 25 / 3 / 0.00% | 25 / 3 / 0.00% |
| Home Wi-Fi | 30 / 12 / 0.20% | 30 / 15 / 0.30% |
| Standard Mobile (4G/LTE) | 45 / 20 / 0.40% | 55 / 30 / 0.50% |
| Bad Connection (3G) | 150 / 70 / 0.50% | 180 / 90 / 0.50% |

Details that trip people (Docs): even Ideal Fiber adds 8 ms each way, so for a true zero baseline set every value to 0. Packet loss maxes at 0.50%, meaning half of one percent. Values add to real conditions, which matters in Team Test. Test `UnreliableRemoteEvent` traffic and any client prediction under the 3G preset before shipping (see [[Network Performance]]).

- **Player Emulator** (Test menu): **Enable Test Profile**, then emulate locale, pseudolocalization, text elongation and region (which drives `PolicyService` results) (Docs). See [[Localization]].
- **VR**: emulate headsets through Device Simulator, or test real OpenXR headsets on Windows after configuring the runtime before launching Studio (Docs).

## 5. Scripted testing services

Studio exposes services that only work in Studio and do nothing in a published game (Docs):

| Service | Purpose |
|---|---|
| `StudioTestService` | Start tests from code: `ExecutePlayModeAsync(args)`, `ExecuteRunModeAsync(args)`, `ExecuteMultiplayerTestAsync`, `AddPlayers`, `GetTestArgs`, `EndTest(value)`, `LeaveTest` |
| `StudioDeviceSimulatorService` | Switch device presets, resolution, DPI, orientation |
| `VirtualInput` | Simulated mouse, keyboard and pointer input processed like real hardware, from `UserInputService:CreateVirtualInput()` |

`ExecutePlayModeAsync` starts a solo Test and **yields until it ends**, returning the value passed to `EndTest` (or `nil`); it errors if a test is already running (Docs). That makes a plugin-driven smoke test possible:

```lua
--!strict
-- Plugin side (Edit): start a solo test, wait for its verdict.
local StudioTestService = game:GetService("StudioTestService")

local function runSmokeTest(): any
	local ok, result = pcall(function()
		return StudioTestService:ExecutePlayModeAsync({ suite = "smoke" })
	end)
	if not ok then
		warn("could not start test:", result)
		return nil
	end
	return result -- whatever the server passed to EndTest
end

print("smoke result:", runSmokeTest())
```

```lua
--!strict
-- Server Script inside the game (runs only when started by the plugin above).
local RunService = game:GetService("RunService")
local StudioTestService = game:GetService("StudioTestService")

if RunService:IsStudio() then
	local args = StudioTestService:GetTestArgs()
	if type(args) == "table" and args.suite == "smoke" then
		task.delay(5, function()
			local okCount = 0
			-- ... run checks against live server state here ...
			okCount += 1
			StudioTestService:EndTest({ passed = okCount })
		end)
	end
end
```

For tests in CI without a desktop, use Open Cloud Luau Execution instead (see [[Git and Source Control for Roblox]] and [[Testing Strategies and Frameworks]]).

## 6. What Studio tests do not tell you

The local server lives on your machine. Several systems behave differently, or not at all, compared with live servers.

| Area | In a Studio test | Live | What to do |
|---|---|---|---|
| Latency | Near zero in local tests | 50 to 300 ms typical (Rule of thumb) | Network Simulator, Team Test, private live server |
| `TeleportService` | Does not support Studio playtests (Docs) | Works | Test teleports in the published game (see [[Teleporting and Multi-Place Games]]) |
| DataStores | Need **Enable Studio Access to API Services**; otherwise calls fail | Always on | Use a separate test universe or test keys (see [[DataStore Fundamentals]]) |
| Purchases | Studio purchase prompts are test purchases | Real Robux | Never trust a Studio purchase flow as proof of receipt handling (see [[Developer Products and ProcessReceipt]]) |
| Asset loading | Usually cached and fast | First load can take seconds | Preload; test from a cold client |
| Studio-only APIs | Work | Fail or return nothing | Grep for them before release |
| Server size and memory | One player, your RAM | Full server, shared memory | Load tests with real players |
| Streaming | Optional in Studio | As configured | Test with `StreamingEnabled` on, at distance (see [[Instance Streaming]]) |

**Measured: things that only worked in Studio.** In the reference project:
- Animation ids from `KeyframeSequenceProvider:RegisterKeyframeSequence` played in every Studio test and did nothing live; dozens of weapon kits were affected before it was found. See [[Case Study - Abilities That Only Worked in Studio]].
- EditableMesh and EditableImage based effects failed in the published game by default; the rule became "never build runtime VFX on them" (check current platform rules before relying on them).
- A clip freshly registered in Studio played nothing until its track `Length > 0`, so tests that started instantly measured nothing.

Rule of thumb: any feature that touches assets, money, data, teleports or other servers is not tested until it has run in a published game with a second account.

## 7. Studio-only branches

`RunService:IsStudio()` is useful for debug UI and cheat commands, and dangerous for everything else. Every `if IsStudio()` branch is code your players never run. Keep these branches tiny, keep the real path identical, and gate cheats on the server (see [[Testing Strategies and Frameworks]] for gated cheat remotes and [[Exploits and Anti-Cheat]]).

Test flags as attributes work well when they cannot leak:

```lua
--!strict
-- ServerStorage attributes act as test switches. Read once at start.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local function testFlag(name: string): any
	if not RunService:IsStudio() then
		return nil -- flags are ignored in live servers, even if someone forgot one
	end
	return ServerStorage:GetAttribute(name)
end

local forcedWeather = testFlag("ForceWeather") -- e.g. "Rain"
```

**Measured.** The reference project used ServerStorage attributes such as an isolated test profile key, a simulated load failure and forced weather or intro. Two lessons: a flag set in Edit is saved with the place, and one (a forced intro) stayed set in the shipped place for days; and a test-profile flag must not be set before Play has actually started, or the real profile path runs. The `IsStudio` guard above makes a forgotten flag harmless live.

## 8. Edit mode is not Play mode

Tools and previews often run in Edit, where:
- Physics does not run; `Motor6D.Transform` you write does not move parts until something steps them.
- `Animator:StepAnimations(dt)` advances animation in Edit only with `dt > 0` (Measured, see [[Testing Animations in Studio]]).
- Particle emitters only step while Studio renders, so rate-based emission in an Edit preview may show nothing while `:Emit()` bursts do (Measured).
- Edit-time previews that change Lighting or Atmosphere become the place's saved state, and systems that read those as a baseline at Play start will inherit them (Measured). Switch previews off before testing.

## 9. A testing ladder

| Step | Mode | Question |
|---|---|---|
| 1 | Run | Does the world simulate without a player? Errors in Output? |
| 2 | Test, toggle to Server | Does the server state match what the client shows? |
| 3 | Test with Device Simulator | Does UI work on phone, tablet, console? |
| 4 | Server & Clients (2) | Do other players see it? Join in progress? |
| 5 | Network Simulator 3G | Is it acceptable on a bad connection? |
| 6 | Team Test | Does it work over the internet with teammates? |
| 7 | Published private server | Teleports, purchases, DataStores, assets from cold |

## 10. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Testing only in solo Test | Replication bugs ship | Server & Clients for every multiplayer feature |
| Tuning during a test | Lost on Stop | Copy, Stop, paste, or tune attributes in Edit |
| Assuming Pause freezes everything | Heartbeat logic keeps running | Know which RunService events pause |
| Leaving a test flag set | Live behaviour changes | `IsStudio` guard on all flags |
| Trusting Studio for teleports, purchases, data | Live failures | Published test with a second account |
| Ignoring "someone else is playing" | Phantom bugs in a shared place | Check the collaborators list and server logs |

## 11. Checklist

- [ ] Each new feature tested in Run, Test (both sides), and Server & Clients.
- [ ] Network Simulator pass at 3G for anything latency-sensitive.
- [ ] Device Simulator pass for every UI change.
- [ ] Studio-only API grep (for example `RegisterKeyframeSequence`) before release.
- [ ] Test flags guarded by `IsStudio` and cleared before publish.
- [ ] Teleports, purchases and data verified in a published game.

## See also

- [[Multi-Client and Live Testing]], [[Testing Strategies and Frameworks]], [[QA Checklists Before Release]]
- [[Client-Server Model]], [[Replication Rules]], [[Network Performance]]
- [[Command Bar and Studio Scripting]], [[Studio Interface Tour]]
- Animation section: [[Testing Animations in Studio]], [[Case Study - Abilities That Only Worked in Studio]]

## Connected notes
<!-- auto-links:start -->
[[Multi-Client and Device Playtesting Protocols]] · [[Mobile and Low-End Optimization]] · [[Parties and Group Teleports]] · [[Multiplayer Services Start Here]] · [[Automated Testing with TestEZ and Jest-Lua]] · [[MCP Workflows for Scripting and Debugging]]
<!-- auto-links:end -->
