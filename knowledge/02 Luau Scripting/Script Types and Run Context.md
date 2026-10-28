---
tags: [luau, scripts, runcontext, localscript, client-server, containers]
---
# Script Types and Run Context

<!-- tldr:start -->
> [!tldr] TL;DR
> - LocalScript does nothing: In Workspace or ReplicatedStorage -> Starter containers, or a Client-context Script in ReplicatedStorage
> - Client code runs twice: Client-context `Script` in a Starter container -> LocalScript there, or move to ReplicatedStorage
> - Input handlers multiply after respawns: Character/GUI scripts re-run; old connections leaked -> Disconnect on removal; `ResetOnSpawn = false` for persistent UI
> - One server entry Script, one client entry; everything else in modules.
> - No scripts inside Workspace models unless they are distributed assets with explicit `RunContext`.
> - Starter containers contain only LocalScripts.
>
> Read more (15 KB note): ## 2. RunContext (Docs) · ## 3. The recommended layout (Docs) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Whether your code runs at all, and where, depends on three things: the script's **class** (`Script`, `LocalScript`, `ModuleScript`), its **location** in the Explorer, and, for `Script`, its **`RunContext`**. Roblox's own docs call this "the fundamental challenge of adapting to Roblox scripting" (Docs: script types and locations). This note is the reference for those rules, the recommended layout, script lifecycle (enable, disable, destroy, respawn), the source and local limits that bite large scripts, and the traps: scripts that run twice, never run, or run with stale state.

---

## 1. The three script classes

| Class | Runs where | Starts when |
|---|---|---|
| `Script` | Server (Legacy/Server) or client (Client) per `RunContext` | It is enabled and in a container valid for its run context |
| `LocalScript` | Client only | It is in a client container (below), enabled |
| `ModuleScript` | Wherever it is required | When `require` is called; once per VM ([[Module Scripts and Requiring]]) |

`LocalScript` inherits from `Script` but has no run context of its own; `RunContext` is only meaningful on `Script` (Docs).

---

## 2. RunContext (Docs)

| Value | Behaviour |
|---|---|
| `Legacy` (default, 0) | Classic: a `Script` runs on the server, and only in server containers such as `Workspace` and `ServerScriptService` |
| `Server` (1) | Runs on the server regardless of legacy container rules; it can also run in `ReplicatedStorage` (not recommended: its source is replicated to clients) |
| `Client` (2) | Runs on the client; valid in `ReplicatedStorage`, `ReplicatedFirst`, and Starter containers (but see the double-run trap) |
| `Plugin` (3) | Runs as plugin code when a descendant of a `Plugin` |

Changing `RunContext` while a script runs drops its threads and starts a fresh run under the new context, if possible; an actively executing thread continues until it yields or returns (Docs).

### LocalScript containers

A `LocalScript` runs when it is a descendant of: the player's `Backpack`, `PlayerGui`, `PlayerScripts`, the player's `Character` model, or `ReplicatedFirst` (Docs: data model client table; Starter containers copy into these). A `LocalScript` in `Workspace` (outside your character) or `ReplicatedStorage` does **not** run. That is the most common "my script does nothing" cause.

### Containers at a glance

| Container | Replicated to clients | Server `Script` (Legacy) | `LocalScript` | `Script` with Client context |
|---|---|---|---|---|
| `ServerScriptService` | No | Runs | No | No |
| `ServerStorage` | No | No (storage) | No | No |
| `Workspace` | Yes | Runs | Only inside the local character | Rule of thumb: avoid |
| `ReplicatedStorage` | Yes | No | No | Runs |
| `ReplicatedFirst` | Yes, first | No | Runs | Runs |
| `StarterPlayerScripts` | Copied to `PlayerScripts` | No | Runs (copy) | Runs twice (original + copy) |
| `StarterCharacterScripts` | Copied into each character | Legacy server Scripts copied into the character also run on the server | Runs (copy, per spawn) | Runs twice |
| `StarterGui` | Copied to `PlayerGui` | No | Runs (copy) | Avoid |
| `StarterPack` | Copied to `Backpack` | Tools' server scripts run once in the character | Runs (copy) | Avoid |

The "runs twice" trap is documented: a `Script` with `RunContext = Client` placed in a Starter container runs as the original **and** as the copy (Docs). Use `LocalScript`s in Starter containers, and Client-context `Script`s only in `ReplicatedStorage`/`ReplicatedFirst`.

---

## 3. The recommended layout (Docs)

Roblox's guidance, which matches what most professional teams do:

- One `Script` with `RunContext = Server` in `ServerScriptService` as the server entry point.
- One `Script` with `RunContext = Client` in `ReplicatedStorage` as the client entry point (or a `LocalScript` in `StarterPlayerScripts`).
- Everything else in `ModuleScript`s, each exposing `start()` (and often `init()`), required by the entry scripts. Shared modules in `ReplicatedStorage`; server modules in `ServerScriptService`/`ServerStorage`.
- A minimal `ReplicatedFirst` script for the loading screen only.
- No scripts attached to Workspace instances: tag them and handle them from a module with CollectionService ([[CollectionService Patterns]]).
- Exception: models and packages distributed on the Creator Store may carry their own scripts; **set an explicit `RunContext`** on each so they behave the same wherever they are inserted.

Benefits: one place controls startup order, failing modules can be isolated, the Output window links to stable script locations (`ReplicatedStorage.Client` rather than an ephemeral copy under `Players.Name.PlayerScripts`), and nothing runs by accident because it was dragged somewhere. See [[Project Structure and Bootstrapping]].

```lua
--!strict
-- ReplicatedStorage/ClientMain (Script, RunContext = Client)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local controllers = ReplicatedStorage:WaitForChild("Controllers")
local order = { "InputController", "CameraController", "HudController" }

for _, name in order do
	local module = controllers:WaitForChild(name) :: ModuleScript
	local ok, controller = pcall(require, module)
	if ok and type(controller) == "table" and controller.start then
		task.spawn(controller.start, Players.LocalPlayer)
	else
		warn(`[ClientMain] failed to load {name}: {controller}`)
	end
end
```

---

## 4. Startup order on the client (Docs)

1. `ReplicatedFirst` contents arrive; its LocalScripts (and Client-context Scripts) run. They can access `ReplicatedFirst` safely but **not** other services' contents without `WaitForChild`.
2. The rest of the game loads; `game.Loaded` fires and `game:IsLoaded()` becomes true.
3. LocalScripts in `PlayerScripts` (from `StarterPlayerScripts`) and Client Scripts in `ReplicatedStorage` run; they can access `ReplicatedStorage` without `WaitForChild`.
4. The character spawns.
5. LocalScripts in the character (from `StarterCharacterScripts`) run.

With Instance Streaming, Workspace content may still be missing at any of these points ([[Instance Streaming]]).

The server has no such staging: server scripts start as the place loads. Do not assume any player exists when a server script starts; handle `Players:GetPlayers()` plus `PlayerAdded` ([[Events Signals and Connections]]).

---

## 5. Lifecycle

- **Enabled/Disabled.** Setting `Enabled = false` drops the script's references to its thread; a yielded thread is never resumed; an executing thread continues until it yields or returns. Setting it back to `true` starts a **fresh run** (Docs). Toggling is a crude restart, not a pause, and state in its locals is lost. Module state required by it persists (cached).
- **Destroying a script** (or an ancestor) stops its threads. A script whose `Parent` is set to `nil` **keeps running** if not destroyed (Docs).
- **Errors** at the top level stop the rest of that script; errors in handlers kill only that handler's thread ([[Error Handling and Retries]]).
- **Character scripts re-run on every spawn.** Anything they connect to outside the character (UserInputService, RunService, PlayerGui objects) must be disconnected when the character is removed, or each respawn adds another copy. Scripts inside the character are destroyed with it, and connections they made to signals of instances inside the character die with those instances, but connections to long-lived signals do not die by themselves if the thread is merely dropped (Rule of thumb: always clean up explicitly).
- **`ResetOnSpawn`** on ScreenGuis (default true) re-clones GUIs and their LocalScripts from StarterGui on each spawn. Persistent UI should set `ResetOnSpawn = false` so its scripts do not restart and duplicate state ([[ScreenGui Fundamentals]]).
- **Tools**: scripts inside a Tool run when the tool is in a Backpack or character; equipping moves the tool between them.

---

## 6. Size and complexity limits for one script

Large single scripts hit hard limits before they become unmaintainable:

| Limit | Value | Source |
|---|---|---|
| `Source` length | 200,000 characters; larger sources cannot be assigned or saved ("Unable to assign property Source") | Measured in the reference project |
| Active locals per function, including the main chunk | 200 | Luau compiler (Docs, luau-lang source) |
| Upvalues per closure | 200 | Luau bytecode format (Docs) |
| Registers per function | 255 | Luau bytecode format (Docs) |

In the reference project, a combat service at about 199,600 characters was frozen by team rule (new behaviour went into a separate API module); a config module and a theme module crossed the cap and had to be split into child modules before any edit was possible; a tutorial controller reached exactly 200 top-level locals so new features had to live inside a function (Measured). See [[Module Scripts and Requiring]] for the safe-split procedure and [[Luau Language Essentials]] for the local limit.

`Script.Source` is protected: game scripts cannot read or write it (Docs). Plugins and the Command Bar can; Studio tooling that edits scripts should use `ScriptEditorService:UpdateSourceAsync` so open editors stay consistent ([[Plugins - Using and Writing]]).

---

## 7. Server, client and "both" code

- `RunService:IsServer()`, `IsClient()`, `IsStudio()`, `IsRunMode()`, `IsEdit()` let shared modules branch. In Studio's Play Solo, the server and client run in one process but are still separate VMs.
- Never branch security on `IsClient()` inside shared code that the client can modify: exploiters control everything on their client. Authority stays on the server ([[Client-Server Model]], [[Server Authority and Validation]]).
- `Players.LocalPlayer` is `nil` on the server.
- Code in `ReplicatedStorage` and `ReplicatedFirst` is downloadable by clients; keep server-only logic out of it.

---

## 8. Parallel and plugin contexts

- Scripts under an `Actor` can run in parallel phases ([[Parallel Luau and Actors]]). Each Actor has its own VM and module copies.
- `RunContext = Plugin` scripts run as plugin code under `Plugin` instances; normal plugins are installed as plugin files and run in Studio only ([[Plugins - Using and Writing]]).
- The Command Bar runs in Studio's context with its own module cache ([[Command Bar and Studio Scripting]]).

---

## 9. Diagnosing "my script does not run"

Work through these in order; most cases stop at step 2.

1. **Is it enabled?** `Enabled` unchecked (or a disabled ancestor `Actor`/`Folder` does not matter, but a disabled script does).
2. **Is it a valid class for its location?** A `LocalScript` outside the client containers, or a Legacy `Script` in `ReplicatedStorage`, never runs. Check the containers table above.
3. **Did it run and error immediately?** Look at Output with the server/client filter correct (Studio's Play mode shows both; the Developer Console in live games has separate Server and Client tabs). A top-level error stops the script after its first lines.
4. **Is it yielding forever?** A `WaitForChild` on a misspelled name or on a streamed-out instance blocks everything after it; look for "Infinite yield possible" warnings. A `require` of a module that yields at load blocks the same way.
5. **Is it running on the side you think?** Put `print(script:GetFullName(), RunService:IsServer())` at the top. A Client-context script prints from `ReplicatedStorage`; a LocalScript copy prints from `Players.Name.PlayerScripts`.
6. **Is it running twice?** Two prints at startup means a duplicated copy (Starter container trap, or a script left inside a cloned model).
7. **Was it destroyed or disabled by other code?** Some systems disable scripts at runtime (for example a tool's script when unequipped, or a cleanup pass). Search for `.Enabled = false` and `:Destroy()` targeting scripts.

For the client-server mental model behind these rules, see [[Client-Server Model]] and [[Replication Rules]]. For testing both sides in Studio, [[Testing Modes - Play Run and Multi-Client]].

## 10. Migration from scattered scripts

Older places often have hundreds of scripts inside parts and models. A safe migration path:

1. Inventory scripts by location and purpose (a Command Bar script listing `GetDescendants()` that are `LuaSourceContainer`s, with their full names and source lengths).
2. Group identical or near-identical scripts (kill bricks, spinning coins). Replace each group with one tag plus one module binder ([[CollectionService Patterns]]); remove the copies.
3. Move unique server logic into modules required by the server entry script; unique client logic into controllers required by the client entry.
4. Set explicit `RunContext` on any script that must stay inside a model (distributed packages).
5. Ship in stages, keeping the old scripts disabled (not deleted) until each stage is verified in a live server, then delete them ([[Safe Changes in a Shared Place]]).

---

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| LocalScript does nothing | In Workspace or ReplicatedStorage | Starter containers, or a Client-context Script in ReplicatedStorage |
| Client code runs twice | Client-context `Script` in a Starter container | LocalScript there, or move to ReplicatedStorage |
| Input handlers multiply after respawns | Character/GUI scripts re-run; old connections leaked | Disconnect on removal; `ResetOnSpawn = false` for persistent UI |
| Server code visible to exploiters | Server-context Script or modules in ReplicatedStorage | ServerScriptService |
| Inserted model's scripts behave differently per location | Legacy run context | Explicit `RunContext` |
| Script cannot be saved after edits | Source over 200,000 characters | Split into modules |
| Adding one local breaks compilation | 200-local limit | Group, scope, split |
| `LocalPlayer` is nil | Shared module running on the server | Guard by `IsClient()` |

## Checklist

- [ ] One server entry Script, one client entry; everything else in modules.
- [ ] No scripts inside Workspace models unless they are distributed assets with explicit `RunContext`.
- [ ] Starter containers contain only LocalScripts.
- [ ] Persistent GUIs use `ResetOnSpawn = false`; per-character scripts clean up.
- [ ] Scripts stay far below 200,000 characters and 200 top-level locals.
- [ ] Server-only code never in replicated containers.

## See also

[[Module Scripts and Requiring]] · [[Project Structure and Bootstrapping]] · [[Client-Server Model]] · [[Replication Rules]] · [[CollectionService Patterns]] · [[Testing Modes - Play Run and Multi-Client]] · [[Plugins - Using and Writing]] · [[Luau Language Essentials]]

## Connected notes
<!-- auto-links:start -->
[[Links - Script types]] · [[External Tooling - Rojo Wally Selene StyLua]] · [[Functions Closures and Upvalues]] · [[Task Library Coroutines and Yielding]] · [[Links - Services]] · [[Debugging Race Conditions and Yield Order]]
<!-- auto-links:end -->
