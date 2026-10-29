---
tags: [testing, qa, bug-reports, telemetry, live-ops, ui, type/guide, area/testing, level/intermediate, area/performance, api/UserInputService, area/ui]
---
# In-Game Bug Report Button with Automatic Context

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Trusting the `userId` in the client payload.
> - Avoid: No size limits; one exploiter fills your store.
> - Avoid: One HTTP request per click with no batching or fallback.
> - Build, JobId, time, position, device and recent client errors captured.
> - Server validates types and sizes; identity from the server.
> - Cooldown per player and cap per server.
>
> Cost: TL;DR ~130 tok · whole note ~2.3k tok. Read more: ## 2. Client: gather and send · ## 3. Server: validate, enrich, store · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Players report bugs in Discord, comments and reviews as "it doesn't work". The information you need (which build, which server, which device, where they were, what errored) is gone by the time you read it. An in-game report button captures that context automatically at the moment the player is annoyed, and attaches whatever they type. Done right it is the cheapest QA team you will ever have.

This note covers what to capture, the client and server code, where to store reports, and the policy points (text filtering, personal data, abuse). Labels as marked.

---

## 1. What to capture automatically

| Field | Source | Why |
|---|---|---|
| Build | `game.PlaceVersion` plus your own build string in a config module | Match the report to code |
| Server | `game.JobId` | Find that server's logs and telemetry |
| Player | `player.UserId` (server-side, never from the client payload) | Look up their data; spot repeat reporters |
| Time | `os.time()` on the server | Correlate with deploys and incidents |
| Position and area | Character root position, your zone or stage name | Reproduce |
| Device class | `UserInputService.TouchEnabled`, `.GamepadEnabled`, `.KeyboardEnabled`, `GuiService:IsTenFootInterface()`, camera `ViewportSize` | Phone vs console vs PC bugs |
| Client errors | Recent `LogService` entries of type Error and Warning on the client | The actual stack trace |
| Game state | Current round, quest step, open menu, equipped item | Most bugs depend on state |
| Ping | `player:GetNetworkPing()` (Roblox docs: [Player](https://create.roblox.com/docs/reference/engine/classes/Player)) | Latency bugs |

Device and log data come from the client and can be faked; that is fine for a bug report, but never use them for anything that grants or punishes.

---

## 2. Client: gather and send

```lua
--!strict
-- StarterPlayerScripts/BugReportClient (wire Submit to your report UI)
local LogService = game:GetService("LogService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remote = ReplicatedStorage.Remotes.SubmitBugReport :: RemoteEvent
local MAX_LOG_LINES = 20
local MAX_TEXT = 500

local function recentErrors(): { string }
	local out = {}
	local history = LogService:GetLogHistory()
	for i = #history, 1, -1 do
		local entry = history[i]
		if entry.messageType == Enum.MessageType.MessageError or entry.messageType == Enum.MessageType.MessageWarning then
			table.insert(out, string.sub(entry.message, 1, 300))
			if #out >= MAX_LOG_LINES then break end
		end
	end
	return out
end

local function submit(category: string, text: string)
	local cam = workspace.CurrentCamera
	Remote:FireServer({
		category = category,
		text = string.sub(text, 1, MAX_TEXT),
		device = {
			touch = UserInputService.TouchEnabled,
			gamepad = UserInputService.GamepadEnabled,
			keyboard = UserInputService.KeyboardEnabled,
			tenFoot = GuiService:IsTenFootInterface(),
			viewport = cam and { math.floor(cam.ViewportSize.X), math.floor(cam.ViewportSize.Y) } or nil,
		},
		errors = recentErrors(),
		menu = "TODO: your UI state",
	})
end

return submit
```

Offer categories (Gameplay, Purchase, UI, Performance, Other) so you can sort without reading every report. Pre-select "Purchase" if the button is pressed from a shop screen.

---

## 3. Server: validate, enrich, store

```lua
--!strict
-- ServerScriptService/BugReportServer
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Remote = ReplicatedStorage.Remotes.SubmitBugReport :: RemoteEvent
local ReportSink = require(script.ReportSink) -- your batching sink module (section 4)
local COOLDOWN = 60
local lastReport: { [Player]: number } = {}
local CATEGORIES = { Gameplay = true, Purchase = true, UI = true, Performance = true, Other = true }

Remote.OnServerEvent:Connect(function(player: Player, payload: any)
	local now = os.clock()
	if lastReport[player] and now - lastReport[player] < COOLDOWN then return end
	if type(payload) ~= "table" or not CATEGORIES[payload.category] then return end
	if type(payload.text) ~= "string" then return end
	lastReport[player] = now

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local report = {
		id = HttpService:GenerateGUID(false),
		userId = player.UserId,           -- from the server, not the payload
		placeVersion = game.PlaceVersion,
		jobId = game.JobId,
		time = os.time(),
		ping = player:GetNetworkPing(),
		pos = root and { math.floor(root.Position.X), math.floor(root.Position.Y), math.floor(root.Position.Z) } or nil,
		category = payload.category,
		text = string.sub(payload.text, 1, 500),
		device = type(payload.device) == "table" and payload.device or nil,
		errors = type(payload.errors) == "table" and payload.errors or nil,
		-- add server-side state here: round, quest step, data schema version
	}
	ReportSink.push(report) -- see section 4
end)

Players.PlayerRemoving:Connect(function(p) lastReport[p] = nil end)
```

Validate sizes and types on everything the client sends ([[Server Authority and Validation]]). Truncate log lines; a malicious client can send megabytes. Note the cleanup on `PlayerRemoving`, or the cooldown table itself leaks.

---

## 4. Where reports go

| Sink | Pros | Cons |
|---|---|---|
| Your own HTTPS endpoint via `HttpService` | Searchable, alerts, dashboards | You run a server; keep the URL and any key in Secrets ([[HttpService and External APIs]]) |
| MemoryStore queue, drained by a job | No external server needed in game | Items expire; you need something to drain it (Open Cloud) |
| DataStore, one key per day or per report | Durable, readable via Open Cloud | Request budgets; awkward to search |
| Analytics custom events | Built-in dashboards for counts | Not meant for free text and logs |

**Rule of thumb:** an HTTPS endpoint you own, with a DataStore fallback when the request fails. Batch: queue reports in memory and flush every minute or at `BindToClose`, not one request per click. Avoid posting directly to chat-app webhooks from game servers; those endpoints have their own terms and rate limits, and a webhook URL in a game server is a secret you can leak.

---

## 5. Policy and abuse

- **Personal information.** Do not ask for email, Discord handle or other off-platform contact details in the form; Roblox's Community Standards restrict soliciting personal information (see [[Roblox Policies Ratings and Compliance]]). The UserId is enough to contact them in-game or see their data.
- **Text filtering.** If report text is ever shown to other players (a public "known issues" board built from reports), filter it with `TextService` first like any user text. Text only your team reads in your own tools is a different case; check the current Roblox text filtering rules in [[Links - Chat and text filtering]] before deciding.
- **Spam.** Cooldown per player, cap per server per minute, drop identical text.
- **Feedback loop.** Show "Thanks, report sent". If you fix a widely reported bug, say so in update notes. Players who see reports lead to fixes send better reports.

---

## 6. Triage

Group by `placeVersion` and the first error line. A new version whose reports cluster on one error is a regression; roll back or hotfix ([[Debugging Live Servers]]). A "Purchase" report always gets a human look and a data check ([[Purchase Data and Receipts]]).

---

## Common mistakes

- Trusting the `userId` in the client payload.
- No size limits; one exploiter fills your store.
- One HTTP request per click with no batching or fallback.
- Asking players for contact details.
- Reports with no build or server id, so nothing can be matched.
- Cooldown tables keyed by `Player` that are never cleaned.

## Checklist

- [ ] Build, JobId, time, position, device and recent client errors captured.
- [ ] Server validates types and sizes; identity from the server.
- [ ] Cooldown per player and cap per server.
- [ ] Batched sink with a fallback; secrets not in code.
- [ ] No personal contact fields; filtering rule decided for any public display.
- [ ] Triage view grouped by version and first error.

## See also

- [[Crash and Error Telemetry]], [[Debugging Live Servers]], [[Analytics and Funnels]]
- [[HttpService and External APIs]], [[Server Authority and Validation]]
- [[Gated Tester Commands and Debug Panels]]

## Connected notes

[[Developer Console and Stats]] · [[Community Building]] · Live Ops Events and Updates · [[QA Checklists Before Release]]

<!-- related:start -->
## Related
[[Multi-Client and Device Playtesting Protocols]] · [[Debugger Breakpoints and Logging]] · [[Load and Soak Testing Servers - Long Sessions and Many Clients]] · [[Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins]] · [[Automated Luau Checks - LihFolk Hook and Audit]] · [[Genre QA Passes - Test Checklists per Game Type]] · [[Testing Time-Based Features with a Controllable Clock]] · [[Multi-Client and Live Testing]]
<!-- related:end -->
