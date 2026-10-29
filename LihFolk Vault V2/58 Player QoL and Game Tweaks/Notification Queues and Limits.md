---
tags: [qol, notifications, toasts, queue, rate-limit, priority, dedupe, ui, type/guide, area/ui, level/intermediate, api/RemoteEvent]
---
# Notification Queues and Limits

<!-- tldr:start -->
> [!tldr] TL;DR
> - Toasts arrive long after the event: Unbounded queue -> Cap and drop stale
> - "Inventory full" missed: Same channel as spam -> Critical channel, sticky
> - Ten identical "Quest updated": No merge key -> Merge by key with a counter
> - One notifier; channels and priorities defined.
> - Visible caps per channel; queue capped around 8; stale dropped.
> - Merge by key; critical sticky and unmutable.
>
> Cost: TL;DR ~140 tok · whole note ~1.8k tok. Read more: ## 1. Classify before you show · ## 2. A queue with merge, cap and priority · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Notifications are the UI element most likely to become noise. A simulator that toasts every coin pickup, every pet hatch in the server and every quest tick trains players to ignore all of them, including the one that says "Your inventory is full". This note is about **limits**: how many, how often, which survive, and which settings players get. Toast construction and animation is in [[Notification and Toast Systems]]; centre-screen moments in [[Centre-Screen Announcements That Stay Centred]]; Roblox's out-of-game notifications in [[Experience Notifications and Return Prompts]].

Sources: **Rule of thumb** from shipped games; Roblox APIs used are standard `RemoteEvent` and GUI (https://create.roblox.com/docs/reference/engine/classes/RemoteEvent).

## 1. Classify before you show

Every message gets a **channel** and a **priority**. Systems never create GUI directly; they call one notifier.

| Channel | Examples | Max visible | Lifetime | Player can mute |
|---|---|---|---|---|
| Critical | Inventory full, purchase failed, data not saved, kicked soon | 1 (sticky until read) | Until dismissed | No |
| Personal | Quest done, level up, item received | 3 | 3-4 s | Partially |
| Social | Friend joined, party invite | 2 | 5 s | Yes |
| Server-wide | "X hatched a Mythic" | 1 | 3 s | Yes |
| Minor | +5 coins | Merged into a counter | 1.5 s | Yes |

Minor gains should not be toasts at all: animate the currency counter instead ([[Reward Moments and Celebrations]]).

## 2. A queue with merge, cap and priority

```lua
--!strict
-- StarterPlayerScripts/Notifier (ModuleScript)
export type Note = { channel: string, key: string?, text: string, priority: number, count: number, born: number }

local MAX_VISIBLE: { [string]: number } = { critical = 1, personal = 3, social = 2, server = 1 }
local MAX_QUEUED = 8

local queue: { Note } = {}
local visible: { [string]: number } = { critical = 0, personal = 0, social = 0, server = 0 }
local muted: { [string]: boolean } = {}

local M = {}
M.render = function(_note: Note, _done: () -> ()) end -- set by the UI layer

local function pump()
	table.sort(queue, function(a, b)
		if a.priority ~= b.priority then return a.priority > b.priority end
		return a.born < b.born
	end)
	local i = 1
	while i <= #queue do
		local n = queue[i]
		if visible[n.channel] < (MAX_VISIBLE[n.channel] or 1) then
			table.remove(queue, i)
			visible[n.channel] += 1
			M.render(n, function()
				visible[n.channel] -= 1
				pump()
			end)
		else
			i += 1
		end
	end
end

function M.push(channel: string, text: string, priority: number?, key: string?)
	if muted[channel] and channel ~= "critical" then return end
	-- Merge duplicates still waiting: "Quest updated x3" instead of three toasts.
	if key then
		for _, n in queue do
			if n.key == key then
				n.count += 1
				n.text = text
				return
			end
		end
	end
	table.insert(queue, { channel = channel, key = key, text = text, priority = priority or 0, count = 1, born = os.clock() })
	-- Drop the lowest-priority, oldest entries when over the cap.
	while #queue > MAX_QUEUED do
		local worst, worstIndex = math.huge, 0
		for idx, n in queue do
			if n.channel ~= "critical" and n.priority <= worst then worst, worstIndex = n.priority, idx end
		end
		if worstIndex == 0 then break end
		table.remove(queue, worstIndex)
	end
	pump()
end

function M.setMuted(channel: string, value: boolean)
	muted[channel] = value
end

return M
```

Points that matter:
- **Stale messages are worse than no message.** Dropping is correct behaviour; the cap keeps the queue under about 8 so nothing arrives 30 seconds late.
- **Merge by key** ("quest:collect_logs") so repeated progress shows a counter.
- **Critical never drops and never mutes.**
- The UI layer's `render` must call `done` exactly once, including when the toast is destroyed early (player leaves the menu, respawn with `ResetOnSpawn`).

## 3. Server-side limits too

Server-wide broadcasts ("X found a Secret pet") are the classic spam source in large servers. Rate-limit on the server: at most one broadcast per few seconds per server, drop the rest, and only broadcast rarities above a threshold. Per player, cap server-to-client notification remotes so a bug in a loop cannot flood one client. See [[Remote Abuse Patterns and Rate Limiting in Practice]] for the token bucket pattern; it applies to outgoing events as much as incoming.

## 4. Player settings

Offer (**Rule of thumb**):
- **Server announcements**: All / Rare only / Off.
- **Social notifications**: On / Off.
- **Notification position** on PC: top-right or bottom-right; on phones fixed to avoid thumbs.
- **Do Not Disturb during combat**: queue personal toasts while the player is in combat, release after.

Persist these in the settings schema ([[Settings Menu Essentials and Persistence]]).

## 5. Placement and devices

- Phones: toasts at the top centre under the top bar inset, never under thumbs or over the jump button ([[Safe Areas and Insets]]).
- Console: larger text and longer lifetime; players sit far away ([[Gamepad and Console UX]]).
- Never put actionable buttons in a toast that disappears; gamepad players cannot reach them in time. Use a persistent inbox for invites.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Toasts arrive long after the event | Unbounded queue | Cap and drop stale |
| "Inventory full" missed | Same channel as spam | Critical channel, sticky |
| Ten identical "Quest updated" | No merge key | Merge by key with a counter |
| Big servers flood with rare-drop shouts | No server rate limit | Server-wide throttle and rarity threshold |
| Slots leak, toasts stop showing | `done` never called on destroy | Call `done` in every exit path |

## Checklist

- [ ] One notifier; channels and priorities defined.
- [ ] Visible caps per channel; queue capped around 8; stale dropped.
- [ ] Merge by key; critical sticky and unmutable.
- [ ] Server-wide broadcasts throttled on the server.
- [ ] Player settings for announcements and social; combat DND.
- [ ] Placement safe on phones; no time-limited buttons.

## See also

- [[Notification and Toast Systems]]
- [[Centre-Screen Announcements That Stay Centred]]
- [[HUD Design]]
- [[Feedback - Autosave Indicator Ping Display and Error Toasts]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[UI Scale HUD Hide and Compact Mode]] · [[Experience Notifications and Return Prompts]] · Reward Moments and Celebrations
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[QoL Audit Checklist]] · [[Top 25 QoL Wins by Effort]] · [[Loading Screen Skip and First-Session Goals]] · [[Block and Mute Respecting Platform Rules]] · [[AFK Detection Idle Kicks and AFK Reward Rules]] · [[Accessibility Cross-Links for QoL Settings]] · [[Joining Friends Parties and Private Servers]] · [[Confirmation and Undo Patterns for Destructive and Paid Actions]]
<!-- related:end -->
