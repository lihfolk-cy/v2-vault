---
tags: [delta, server-authority, replication, next-generation-replication, physics-replication, input-action-system, prediction, rollback, networking, migration, luau, type/guide]
verified: 2026-10-28
---
# Server Authority and Input Migration 2026

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Turning on `AuthorityMode = Server` in a non-streaming game and debugging "missing parts" for a day.
> - Avoid: Using `os.clock()`, `tick()` or `task.wait()` timing inside simulation code.
> - Avoid: Calling `:Destroy()` inside `BindToSimulation`.
> - Simulation code is in `BindToSimulation`, uses `time()`, and has no Destroy, reparent, EquipTool or UserInputService calls.
> - Predicted state lives in at most 64 attributes with short names and short strings.
> - VFX and sounds tolerate a rollback.
>
> Cost: TL;DR ~170 tok · whole note ~2.7k tok. Read more: ## 1. Server Authority (full release July 9, 2026) · ## 4. Input Action System and the converted player scripts · ## Common mistakes · ## Checklist
<!-- tldr:end -->

In 2026 Roblox shipped three linked changes: **Server Authority** (server-authoritative simulation with client prediction and rollback), a **rewrite of physics replication**, and the **Input Action System** (IAS), which now drives the default player scripts. Each one changes code that every pre-2026 model writes by reflex. Labels follow [[Roblox Changes 2025-2026]].

## 1. Server Authority (full release July 9, 2026)

**Roblox docs** (DevForum, July 9, 2026: https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993; guide https://create.roblox.com/docs/projects/server-authority).

What it is: opt-in. The server runs the simulation authoritatively and rejects invalid client movement. Clients predict their own inputs and resimulate when the server disagrees. Speed hacks and similar physics exploits are blocked without custom anti-cheat.

Turning it on: Workspace properties, Server Authority section, `AuthorityMode = Server`. That **forces five settings**:

| Property | Forced value | Why |
|---|---|---|
| `NextGenerationReplication` | Enabled | New property sync (beta on its own) |
| `PlayerScriptsUseInputActionSystem` | Enabled | Movement input must be readable on both sides |
| `SignalBehavior` | Deferred | Listeners run outside the simulation loop |
| `StreamingEnabled` | Enabled | Auto prediction uses streaming |
| `UseFixedSimulation` | Enabled | Fixed-step, replayable simulation |

So turning on Server Authority also brings every StreamingEnabled and deferred-signal bug into the game. See [[Instance Streaming]] and [[Events Signals and Connections]].

### Rules for code under Server Authority (Roblox docs, guide page)

- Simulation-affecting code goes in a function registered with `RunService:BindToSimulation(fn)`. It runs on client and server and **can be re-run** during resimulation, so it must be deterministic and side-effect-free apart from simulated state.
- Use **`time()`** for simulation timing. `tick()`, `os.time()` and `os.clock()` are local clocks that do not roll back.
- Read input from **`InputAction`** objects, not `UserInputService.InputBegan`. `InputContext`s must be descendants of the `Player`.
- Sync custom state with **attributes** on predicted instances, written only inside bound functions. Only the first **64 attributes** replicate; names and string values are limited to **50 characters**.
- `Instance:Destroy()` and reparenting **error** inside bound functions. Record intent in an attribute and destroy in `RunService.PostSimulation` on the server.
- `Humanoid:EquipTool()` and `UnequipTools()` are not allowed inside bound functions; weld a model and track "equipped" in an attribute.
- Do not cache `AnimationTrack`s across frames; look them up with `Animator:GetTrackByAnimationId()`. At release, **8 actively playing tracks per Animator** was a known limit.
- Physics assemblies are predicted as a whole: a welded sword is predicted with the character, a merely parented model is not.
- Rendering, sounds and VFX go in `RenderStepped` and must tolerate mispredictions (undo or hide effects the server never confirms).
- RemoteEvents are **not** on the shared simulation timeline. Do not use them for state that must line up with DataModel changes.
- Camera: the camera `InputAction` stops synchronising. Use **`Player:GetCameraState()`** (returns `CFrame`, `FieldOfView`, `ViewportSize`, synced client to server). `Player.InputContexts.CameraContext.CameraAction` is removed.
- `SetNetworkOwner` is **not** an equivalent: it assigns ownership without latency compensation.

Server CPU use goes up (Roblox docs: usually small).

### Sketch: a dash under Server Authority

**Unverified** sketch built from the guide's rules, not copied from Roblox; check against the current reference before shipping.

```lua
-- ReplicatedStorage/Shared/DashSim (ModuleScript), required from one server Script and one LocalScript
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local COOLDOWN, IMPULSE = 1.5, 60

RunService:BindToSimulation(function(_dt: number)
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local action = player:FindFirstChild("Gameplay") and player.Gameplay:FindFirstChild("Dash")
		if root and action and action:GetState() == true then
			local last = char:GetAttribute("LastDash") or -math.huge
			if time() - last >= COOLDOWN then -- time(), never os.clock()
				char:SetAttribute("LastDash", time())
				root.AssemblyLinearVelocity += root.CFrame.LookVector * IMPULSE
			end
		end
	end
end)
return true
```

## 2. Next Generation Replication: property ordering is gone

**Roblox docs** (staff posts in the Server Authority beta threads, e.g. https://devforum.roblox.com/t/server-authority-studio-beta-insights-from-engineers/4139321):

- Small property updates (under about 50 bytes) travel on a stream with **eventual consistency but no ordering**. Instance creation and deletion stay ordered.
- The old implicit guarantee "when a RemoteEvent arrives, every property set before it has replicated" no longer holds.
- RemoteEvent ordering among remotes is unchanged.
- NGR on its own was not generally released as of 2026-10-28; it is forced on only by `AuthorityMode = Server`.

```lua
-- WRONG: relies on the remote acting as a replication fence
door:SetAttribute("Open", true)
DoorRemote:FireAllClients(door)          -- client handler reads door:GetAttribute("Open")

-- RIGHT: send the value, or react to the change itself
DoorRemote:FireAllClients(door, true)
-- or on the client:
door:GetAttributeChangedSignal("Open"):Connect(applyDoorState)
```

This pattern is also safer without NGR. See [[Debugging Client-Server Desync]].

## 3. Physics replication rewrite (June 2026)

**Roblox docs** (DevForum, June 9, 2026, updates to July 14: https://devforum.roblox.com/t/upcoming-improvements-to-physics-replication/4675512).

- Backend rewritten for eventual consistency, so packet drops no longer lose updates. A settled part's final position always reaches clients.
- `Workspace.ImprovedPhysicsReplication`: `Default`, `Enabled`, `Disabled`. `Disabled` is a temporary escape hatch (added June 16).
- An earlier rollout was rolled back in May 2026 after games broke. Global rollout started June 15, 2026.
- Physics network stats read 0 KB/s; use the Instance State Replication (ISR) stats instead.
- **Reported** in linked bug threads: Humanoid state, `MoveDirection` and `FloorMaterial` not replicating; relative physics desync; character position errors after unanchoring.

If you see new desync from mid-June 2026, test with `Disabled` before rewriting your own code, and file a bug.

## 4. Input Action System and the converted player scripts

**Roblox docs** (DevForum, June 11, 2026: https://devforum.roblox.com/t/full-release-input-action-system-ias-newly-converted-player-scripts/4678416; guide https://create.roblox.com/docs/input/input-action-system).

Instances: `InputContext` (a group you enable, disable and prioritise), `InputAction` (`Type`: Bool, Direction1D, Direction2D, Direction3D, ViewportPosition; `GetState()`, `Pressed`, `Released`, `StateChanged`), `InputBinding` (`KeyCode`, plus `PrimaryModifier`/`SecondaryModifier` for chords, `UIModifier`, `Scale`). Give every action a keyboard/mouse, gamepad **and** touch binding. IAS instances exist on client and server; `ContextActionService` bindings are client-only.

Player script rollout:

| Phase | When | `Workspace.PlayerScriptsUseInputActionSystem` |
|---|---|---|
| 1 | June 2026 | Default Disabled, opt in |
| 2 | Early 2027 (planned) | Default Enabled; may break games that touch the old scripts or rely on old input sinking |
| 3 | Mid 2027 (planned) | Property removed; old scripts gone |

What breaks: calls into `PlayerModule` internals such as `require(PlayerModule):GetControls()`, code that depends on old input sinking, forked player scripts (these need `StarterPlayer.CreateDefaultPlayerModule = Disabled` plus the property Enabled).

```lua
-- Server: one context per player (required under Server Authority)
local Players = game:GetService("Players")
local template = Instance.new("InputContext")
template.Name = "Gameplay"
local dash = Instance.new("InputAction")
dash.Name = "Dash"
dash.Type = Enum.InputActionType.Bool
dash.Parent = template
for _, key in { Enum.KeyCode.Q, Enum.KeyCode.ButtonX } do
	local b = Instance.new("InputBinding")
	b.KeyCode = key
	b.Parent = dash
end
-- touch: bind to an on-screen button (InputBinding.UIButton; check the reference)
Players.PlayerAdded:Connect(function(p) template:Clone().Parent = p end)
```

## Common mistakes

- Turning on `AuthorityMode = Server` in a non-streaming game and debugging "missing parts" for a day. It forces StreamingEnabled.
- Using `os.clock()`, `tick()` or `task.wait()` timing inside simulation code.
- Calling `:Destroy()` inside `BindToSimulation`.
- Holding an `AnimationTrack` in an upvalue across frames.
- Treating `SetNetworkOwner(nil)` as "server authority".
- Using a RemoteEvent as a fence for property changes.
- Reaching into `PlayerModule:GetControls()` to disable movement. Disable an `InputContext` instead.
- Binding gameplay input only to keyboard keys.

## Checklist

- [ ] Simulation code is in `BindToSimulation`, uses `time()`, and has no Destroy, reparent, EquipTool or UserInputService calls.
- [ ] Predicted state lives in at most 64 attributes with short names and short strings.
- [ ] VFX and sounds tolerate a rollback.
- [ ] No remote is used as a property fence.
- [ ] Camera reads on the server use `Player:GetCameraState()`.
- [ ] Every [[InputAction]] has keyboard, gamepad and touch bindings.
- [ ] Place tested with `PlayerScriptsUseInputActionSystem = Enabled` before early 2027.

## See also

- [[Roblox Changes 2025-2026]]
- [[Engine and API Changes 2025-2026]]
- [[AI Pitfalls - Networking and Security]]
- [[Server Authority and Validation]]
- [[Network Ownership]]
- [[Client Prediction and Reconciliation for Combat]]
- [[Input - UserInputService and ContextActionService]]
- [[Debugging Physics and Network Ownership]]

<!-- related:start -->
## Related
[[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Data and Cloud Changes 2025-2026]] · [[Console and VR Release Checklists]] · [[Discovery and Monetization Changes 2025-2026]] · [[Policy and Age Rules 2026]]
<!-- related:end -->
