---
tags: [testing, qa, ui, automation, studio, studiotestservice, virtualinput, mcp, type/guide, area/testing, area/ui, level/advanced]
---
# UI Automation with VirtualInput and StudioTestService

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Trying to use VirtualInputManager; it is internal.
> - Avoid: Reading `GetTestArgs` on the client and getting nothing.
> - Avoid: Fixed `task.wait(2)` instead of waiting on a condition.
> - Plugin runner runs suites sequentially and checks `EditModeActive`.
> - Server reads args, client tests click via VirtualInput, server calls `EndTest`.
> - Click helper verified once against a known button.
>
> Cost: TL;DR ~140 tok · whole note ~2.5k tok. Read more: ## 1. The pieces (Roblox docs) · ## 3. A UI test that clicks real buttons · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Clicking through the shop, the settings menu and the tutorial by hand after every change is the test everybody skips. Roblox now has the pieces to automate it inside Studio: **StudioTestService** starts Play, Run and multiplayer sessions from a plugin and gets a result back, and **VirtualInput** injects mouse, keyboard and text input into a running experience's own UI. Together they give you scripted click-through tests and multi-client integration tests without leaving Studio. AI agents add a third route through the Studio MCP input tools.

[[Testing Modes - Play Run and Multi-Client]] introduces both services with a minimal smoke test. This note is the full pattern: a plugin runner, a UI test that clicks real buttons, a multi-client test, and where each tool fits. Labels as marked.

---

## 1. The pieces (Roblox docs)

**StudioTestService** ([reference](https://create.roblox.com/docs/reference/engine/classes/StudioTestService), announced on the DevForum 4 December 2025: [Introducing StudioTestService](https://devforum.roblox.com/t/introducing-studiotestservice/4116257)):

| Member | Who calls it | Notes |
|---|---|---|
| `ExecutePlayModeAsync(args)` / `ExecuteRunModeAsync(args)` | Plugin | Starts a solo Test or Run, yields until it ends, returns the value given to `EndTest` (or `nil`). Errors if a session is already running |
| `ExecuteMultiplayerTestAsync(numPlayers, args)` | Plugin | One server plus 1 to 8 clients; one multiplayer session per Studio |
| `GetTestArgs()` | Server scripts | Returns the args; on clients it may fail (listed as a known issue) |
| `EndTest(value)` | Server only | Ends the session; value returns to the plugin |
| `AddPlayers(n)` | Server only, during a test | Adds 1 to 8 more clients, for staggered joins |
| `CanLeaveTest()` / `LeaveTest()` | Client only | Disconnect one client to test leave and reconnect logic |
| `EditModeActive` | Plugin | `true` when Studio is idle in Edit |

**VirtualInput** ([reference](https://create.roblox.com/docs/reference/engine/classes/VirtualInput)): obtained only from `UserInputService:CreateVirtualInput()`, which can return `nil` when unavailable. Methods: `SendKey`, `SendMouseButton`, `SendMousePosition`, `SendMouseDelta` (cursor must be locked), `SendPointerAction`, `SendTextInput`. Input is restricted to the experience's own UI: calls that would touch CoreGui (top bar, chat, escape menu) throw, and keys bound to core actions such as Escape throw. Use it from client code. The docs describe it as for testing.

Do not confuse it with **VirtualInputManager**, which the docs describe as an internal service that offers no functionality to developers.

---

## 2. A plugin test runner

```lua
--!strict
-- Plugin: run each UI suite in its own Play session and collect verdicts.
local StudioTestService = game:GetService("StudioTestService")

local SUITES = { "shop_buy_flow", "settings_toggle", "codes_redeem_invalid" }

local function runAll()
	local results = {}
	for _, suite in SUITES do
		if not StudioTestService.EditModeActive then
			warn("Studio not idle; aborting")
			break
		end
		local ok, verdict = pcall(StudioTestService.ExecutePlayModeAsync, StudioTestService, { suite = suite })
		results[suite] = if ok then verdict else ("runner error: " .. tostring(verdict))
	end
	for suite, verdict in results do
		print(("[UITest] %s -> %s"):format(suite, game:GetService("HttpService"):JSONEncode(verdict)))
	end
end

-- Hook runAll to a toolbar button; it yields, so run it in task.spawn.
```

Because `GetTestArgs` is reliable on the server but not yet on clients, let the **server** read the suite name and pass it to the client (an attribute on `ReplicatedStorage` works), and let the client report results back through a remote so the server can call `EndTest`.

---

## 3. A UI test that clicks real buttons

```lua
--!strict
-- StarterPlayerScripts/QA/UITestClient (Studio only)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

if not RunService:IsStudio() then return end
local suite = ReplicatedStorage:GetAttribute("QA_Suite")
if suite == nil then return end

local vi = UserInputService:CreateVirtualInput()
local Report = ReplicatedStorage.Remotes.QA_Report :: RemoteEvent
if not vi then
	Report:FireServer(suite, { passed = false, reason = "VirtualInput unavailable" })
	return
end

local player = game:GetService("Players").LocalPlayer
local gui = player:WaitForChild("PlayerGui")

local function click(button: GuiObject)
	-- AbsolutePosition excludes the top inset; add it back for screen coordinates.
	local inset = GuiService:GetGuiInset()
	local centre = button.AbsolutePosition + button.AbsoluteSize / 2 + inset
	vi:SendMousePosition(centre)
	vi:SendMouseButton(centre, Enum.UserInputType.MouseButton1, true)
	vi:SendMouseButton(centre, Enum.UserInputType.MouseButton1, false)
end

local function waitFor(pred: () -> boolean, timeout: number): boolean
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		if pred() then return true end
		task.wait(0.1)
	end
	return false
end

if suite == "shop_buy_flow" then
	local hud = gui:WaitForChild("HUD", 10) :: ScreenGui
	click(hud:FindFirstChild("ShopButton", true) :: GuiObject)
	local shop = gui:WaitForChild("Shop", 5) :: ScreenGui
	local opened = waitFor(function() return shop.Enabled end, 3)
	click(shop:FindFirstChild("Buy_Sword", true) :: GuiObject)
	local bought = waitFor(function() return player:GetAttribute("Owns_Sword") == true end, 5)
	Report:FireServer(suite, { passed = opened and bought, opened = opened, bought = bought })
end
```

**Unverified:** whether `SendMousePosition` expects coordinates with or without the GUI inset in every configuration. Test the `click` helper once against a known button and adjust. If your ScreenGuis use `IgnoreGuiInset`, the inset correction differs.

What this tests that a unit test cannot: the button is visible, on top, clickable, wired to the right handler, the remote round-trip works and the server granted the item. What it does not test: whether it looks right, or how it feels on a phone. Pair it with the Device Simulator ([[Responsive UI for Phone Tablet Console and PC]]).

Use a test universe for purchase flows; Studio purchases of developer products are test prompts, but the grant path still writes data.

---

## 4. Multi-client integration tests

`ExecuteMultiplayerTestAsync(2, { suite = "trade_basic" })` gives a server and two clients. The server script orchestrates: wait for two players, tell client A to open a trade with B (attribute or remote), have each client's test script click through its side with VirtualInput, then check both inventories on the server and call `EndTest`. Extend with:

- `AddPlayers(1)` mid-test to check late joiners see the right state.
- `LeaveTest()` from one client during a trade to check cancel and refund ([[Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins]]).

---

## 5. Agent-driven UI checks (Studio MCP)

With the Studio MCP server ([[Roblox Studio MCP Server]]) an AI agent can `start_stop_play`, send `user_mouse_input` and `user_keyboard_input`, then `inspect_instance` or `execute_luau` in the Client context to check state, and `get_console_output` for errors. That is good for exploratory checks ("open every menu and report errors"). For regression tests, prefer the scripted runner above: it is deterministic, cheap and does not depend on screenshots, which are unreliable when Studio is not in the foreground ([[Roblox Studio MCP Server]], gotchas). Never let an agent start Play in a Studio another person is testing in ([[Multiple Agents in One Studio]]).

---

## 6. Making UI testable

- Give buttons stable names (`Buy_Sword`, not `TextButton37`). Tests and agents find them by name.
- Keep business logic in modules that the UI calls; test those with unit tests, and keep UI tests for wiring.
- Expose state as attributes (`Shop.Enabled`, `Owns_Sword`) so tests wait on facts, not timers.
- One suite per flow, each short. A 5-minute mega-test that fails at minute 4 is expensive.

---

## Common mistakes

- Trying to use VirtualInputManager; it is internal.
- Reading `GetTestArgs` on the client and getting nothing.
- Fixed `task.wait(2)` instead of waiting on a condition.
- Clicking coordinates computed without the GUI inset.
- UI tests that assert on look; they belong to a human or the council.
- Agent playtests in a shared Studio.

## Checklist

- [ ] Plugin runner runs suites sequentially and checks `EditModeActive`.
- [ ] Server reads args, client tests click via VirtualInput, server calls `EndTest`.
- [ ] Click helper verified once against a known button.
- [ ] Shop, settings, codes and tutorial flows each have a suite.
- [ ] Multi-client suites for trades and joins.
- [ ] Buttons named stably; state exposed as attributes.

## See also

- [[Testing Modes - Play Run and Multi-Client]], [[Automated Testing with TestEZ and Jest-Lua]], [[Testing Strategies and Frameworks]]
- [[Roblox Studio MCP Server]], [[MCP Workflows for Scripting and Debugging]]
- [[Load and Soak Testing Servers - Long Sessions and Many Clients]]

## Connected notes

[[Debugging UI Layout and Input]] · Plugin UI with DockWidgets · [[Multi-Client and Live Testing]] · [[Genre QA Passes - Test Checklists per Game Type]]

<!-- related:start -->
## Related
[[Multi-Client and Device Playtesting Protocols]] · [[Save Migration Tests - Fixture Saves and Golden Files]] · [[Testing Time-Based Features with a Controllable Clock]] · [[QA Checklists Before Release]] · [[In-Game Bug Report Button with Automatic Context]] · [[Automated Luau Checks - LihFolk Hook and Audit]] · [[StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs]] · [[Gated Tester Commands and Debug Panels]]
<!-- related:end -->
