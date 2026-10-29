---
tags: [qol, feedback, autosave, save-indicator, ping, latency, error-messages, toasts, trust, type/guide, area/ui, area/data, level/intermediate, api/Player, api/RemoteEvent]
---
# Feedback - Autosave Indicator Ping Display and Error Toasts

<!-- tldr:start -->
> [!tldr] TL;DR
> - "Saved" shown during outage: Client-side timer -> Server-reported status
> - Players lose purchases during save failures: Spending allowed while failing -> Freeze premium actions when failing
> - Clicks silently ignored: No error feedback -> Typed results mapped to messages
> - Save indicator driven by server results, with retrying and failing states.
> - Premium and trade actions frozen while saves fail.
> - Ping display with rolling average and Off / When high / Always setting.
>
> Cost: TL;DR ~160 tok · whole note ~2.1k tok. Read more: ## 1. Autosave indicator · ## 3. Error messages that help · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Players trust a game that tells them what is happening: "Saved", "Your connection is slow", "Not enough coins (need 120 more)". They distrust one that silently ignores a click or loses progress without a word. This note covers three feedback features: an honest autosave indicator, a ping/latency display, and clear error messages for failed actions. Saving itself is in [[Saving Correctly - Autosave and BindToClose]]; toast mechanics in [[Notification Queues and Limits]]; purchase confirmations in [[Purchase Receipts and Purchase History in UI]].

Sources: **Roblox docs** for `Player:GetNetworkPing` (https://create.roblox.com/docs/reference/engine/classes/Player) and DataStore error handling (https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits). Thresholds are **Rule of thumb**.

## 1. Autosave indicator

Show a small icon when the server saves, and a clear warning when saving fails. The indicator must reflect **server** results; a client-side timer that blinks "Saved" every two minutes is a lie that will be exposed the first time DataStores have an outage.

States:

| State | Shown | When |
|---|---|---|
| Saving | Spinner, small, corner | Server started a save for this player |
| Saved | Check mark for about 2 s | Save succeeded |
| Retrying | Amber icon, "Retrying save…" | Save failed, retry scheduled |
| Not saving | Red, sticky critical toast | Repeated failures or session lock lost |

```lua
--!strict
-- Server: wrap your profile save to report status to the player.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local statusRemote = ReplicatedStorage.Remotes.SaveStatus :: RemoteEvent

local failures: { [Player]: number } = {}

local function saveWithStatus(player: Player, doSave: () -> ())
	statusRemote:FireClient(player, "saving")
	local ok, err = pcall(doSave)
	if ok then
		failures[player] = 0
		statusRemote:FireClient(player, "saved")
	else
		local n = (failures[player] or 0) + 1
		failures[player] = n
		warn("Save failed", player.UserId, err)
		statusRemote:FireClient(player, if n >= 3 then "failing" else "retrying")
	end
end
```

If you use a profile library that saves internally, hook its save/failed signals instead. Gotchas:
- **Do not show "Saving" for every tiny change** if your system saves on an interval; show it on the interval save and after important events (purchase, trade, rebirth).
- **"Failing" should change behaviour**: disable trading and premium spending until saves recover, and tell the player why. This protects players from losing purchases ([[LihFolk Systems - Data and Purchase Guarantees]]).
- **On leave** nothing can be shown, so the indicator matters most during play. Before a teleport, wait for the save and show "Saving before travel…".
- **Platform outages**: when DataStores are degraded, a calm message ("Saving is delayed. Your progress is kept on this server and will save when the service recovers.") beats silence. Only say it if your session model actually keeps data safely in memory.

## 2. Ping display

Competitive and action players want to know whether a missed hit was them or the connection.

```lua
--!strict
-- Client: rolling ping readout.
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local samples: { number } = {}
local label: TextLabel? = nil -- assign your label

task.spawn(function()
	while true do
		local ms = player:GetNetworkPing() * 1000
		table.insert(samples, ms)
		if #samples > 5 then table.remove(samples, 1) end
		local sum = 0
		for _, v in samples do sum += v end
		local avg = sum / #samples
		if label then
			label.Text = string.format("%d ms", math.round(avg))
			label.TextColor3 = if avg < 120 then Color3.fromRGB(120, 220, 120)
				elseif avg < 250 then Color3.fromRGB(240, 200, 80)
				else Color3.fromRGB(240, 90, 90)
		end
		task.wait(1)
	end
end)
```

`GetNetworkPing` returns seconds (**Roblox docs**). Thresholds above are **Rule of thumb**. Options:
- **Setting**: Show ping: Off / When high / Always. "When high" (only above about 250 ms) is a good default; constant numbers make some players anxious.
- **Server performance** too: if the server's own frame rate drops, players experience lag even with low ping. A server-reported "Server under load" icon helps explain rubber-banding ([[Network Performance]], [[Developer Console and Stats]]).
- **Lag-tolerant design** matters more than the number: lag compensation and fair hit validation are in [[False Positives Lag and Fair Enforcement]] and [[Client Prediction and Reconciliation for Combat]].

## 3. Error messages that help

Every server-rejected action should tell the player why, in plain language, with the next step.

| Bad | Good |
|---|---|
| "Error" | "Not enough coins. You need 120 more." |
| "Request failed" | "Trade cancelled: the other player left." |
| Nothing happens | "Inventory full (200/200). Sell or lock items to make room." |
| "Cooldown" | "Dash ready in 1.4 s" (and show it on the button) |
| "DataStore error 503" | "Couldn't save right now. We'll retry automatically." |

Pattern: server request functions return a typed result the client maps to text.

```lua
--!strict
export type Result = { ok: boolean, code: string?, data: any? }

local MESSAGES: { [string]: string } = {
	NOT_ENOUGH_COINS = "Not enough coins. You need %d more.",
	INVENTORY_FULL = "Inventory full (%d/%d). Sell or lock items to make room.",
	ON_COOLDOWN = "Ready in %.1f s.",
	RATE_LIMITED = "Slow down a little.",
	UNKNOWN = "Something went wrong. Try again.",
}

local function describe(result: Result, ...: any): string?
	if result.ok then return nil end
	local template = MESSAGES[result.code or "UNKNOWN"] or MESSAGES.UNKNOWN
	local ok, text = pcall(string.format, template, ...)
	return if ok then text else MESSAGES.UNKNOWN
end
```

Rules:
- **Codes from the server, text on the client**, which keeps localisation possible ([[Localization]]; keep all strings in one table either way).
- **Never show raw errors or stack traces** to players; log them ([[Crash and Error Telemetry]]).
- **Disable buttons that cannot work** ("Buy" greyed with the price in red) instead of letting the player press and fail.
- **Error toasts go in the personal channel**, critical only for data and purchases.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| "Saved" shown during outage | Client-side timer | Server-reported status |
| Players lose purchases during save failures | Spending allowed while failing | Freeze premium actions when failing |
| Clicks silently ignored | No error feedback | Typed results mapped to messages |
| Raw error codes on screen | Error passthrough | Friendly text, log details |
| Ping number jumps wildly | Single samples | Rolling average |
| Lag blamed on players' ping | Server overload invisible | Server load indicator |

## Checklist

- [ ] Save indicator driven by server results, with retrying and failing states.
- [ ] Premium and trade actions frozen while saves fail.
- [ ] Ping display with rolling average and Off / When high / Always setting.
- [ ] Every rejection returns a code; client shows plain text with a next step.
- [ ] Buttons disabled when they cannot succeed.

## See also

- [[Saving Correctly - Autosave and BindToClose]]
- [[Debugging DataStore Problems]]
- [[Network Performance]]
- [[Error Handling and Retries]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Notification Queues and Limits]] · [[Purchase Receipts and Purchase History in UI]] · [[Server Hop Rejoin and Server Lists with Ping]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[QoL Audit Checklist]] · [[Top 25 QoL Wins by Effort]] · [[Confirmation and Undo Patterns for Destructive and Paid Actions]] · [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]] · [[Loading Screen Skip and First-Session Goals]] · [[Settings Menu Essentials and Persistence]] · [[Block and Mute Respecting Platform Rules]] · [[AFK Detection Idle Kicks and AFK Reward Rules]]
<!-- related:end -->
