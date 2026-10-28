---
tags: [ui, notifications, toasts, hud, popups, remotes, localization, accessibility, live-ops]
---
# Notification and Toast Systems

Every game ends up telling the player things: "+250 coins", "Quest complete", "Your friend joined", "Inventory full", "Double XP starts in 5 minutes", "Someone just rolled a Mythic". The first version is always a `TextLabel` that some script makes visible for three seconds. By the tenth notification type, they overlap, cover the jump button, play during cutscenes, and players start ignoring all of them, including the one that mattered.

A notification system is a small piece of architecture: a single entry point, a taxonomy of channels, rules for priority, merging and rate, and renderers that respect the HUD. [[HUD Design]] (section 3) covers the popup gate and the centre-stage queue for celebrations. This note covers the rest: choosing the right channel, the toast queue itself, merging, server design, the platform channels (CoreGui notifications, chat system messages, out-of-experience notifications), and how the whole thing fails under load.

---

## 1. Pick the channel before the look

Most notification problems are channel problems: an informational message shown as a modal, or a critical warning shown as a toast that disappears while the player is fighting.

| Channel | Blocks input? | Lifetime | Use for | Do not use for |
|---|---|---|---|---|
| **Floating number** | No | 0.6 to 1.2 s | Immediate results at the point of action (damage, "+5") | Anything the player must read |
| **Toast** | No | 2.5 to 7 s | Informational events: item obtained, quest progress, friend joined | Errors that need action; celebrations |
| **Banner (centre stage)** | No, but dominates the screen | 2 to 4 s, queued | Celebrations: level up, rare drop, zone unlocked | Routine events (they lose their weight) |
| **Inline status** | No | While the condition holds | "Inventory full" on the backpack button; "Not enough coins" on the buy button | Events unrelated to what the player is looking at |
| **Modal** | Yes | Until dismissed | Confirmations, irreversible choices, required decisions | Anything that can be a toast |
| **Inbox / log** | No | Persistent | Offline rewards, gifts, trade results, admin messages | Real-time feedback |
| **Chat system message** | No | Scrolls with chat | Social server-wide events ("X hatched a Legendary") | Private information; anything critical (many players hide chat) |
| **Out-of-experience notification** | N/A | Platform-managed | Bringing a player back (opt-in, rate-limited by Roblox) | Anything time-critical |

Two rules of thumb fall out of this:

- **The closer the message is to the cause, the less it needs to be a notification.** "Not enough coins" belongs on the buy button (shake it, tint it, show the shortfall), not in a toast in the corner. Inline feedback beats toasts for errors because the player's eyes are already there.
- **Anything that must be acted on must persist.** A toast that says "Your daily reward is ready" and disappears after 4 s is worse than a badge on the rewards button that stays until claimed.

---

## 2. Architecture: one entry point, data-driven kinds

```
server systems ──Notify(kind, params)──┐
                                       ├─> NotificationController (client) ──> queue / merge / gate ──> renderers
client systems ──Notify(kind, params)──┘                                                             (toast, banner, chat, inline)
```

- **Kinds are data.** A shared module defines every notification kind: channel, priority, merge rule, lifetime, sound, icon. Adding a kind is a data change; renderers never special-case kinds.
- **Server sends a kind and parameters, never final text.** `{kind = "ItemObtained", item = "sword_07", count = 1}`, not `"You got Flame Sword!"`. The client formats with the player's locale ([[Localization]]), picks icons, and can merge by structure (summing counts is impossible on strings).
- **One remote**, reliable, for notifications that matter. Floating numbers for cosmetic effects can go over an `UnreliableRemoteEvent` because losing one is harmless ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]).

```lua
--!strict
-- ReplicatedStorage/Shared/NotificationKinds.lua
export type Channel = "toast" | "banner" | "chat" | "inline"
export type Merge = "none" | "sum" | "replace" | "count"

export type Kind = {
	channel: Channel,
	priority: number,     -- higher wins; 1 routine, 2 notable, 3 important, 4 critical
	merge: Merge,
	mergeWindow: number?, -- seconds during which same-key notes merge
	minTime: number?,     -- minimum on-screen time
	sound: string?,       -- sound key in your audio module
	locKey: string,       -- localization key for the format string
}

local Kinds: { [string]: Kind } = {
	CurrencyGain = { channel = "toast", priority = 1, merge = "sum", mergeWindow = 1.5, locKey = "notify.currency_gain" },
	ItemObtained = { channel = "toast", priority = 2, merge = "count", mergeWindow = 3, sound = "ItemPop", locKey = "notify.item_obtained" },
	QuestProgress = { channel = "toast", priority = 1, merge = "replace", mergeWindow = 6, locKey = "notify.quest_progress" },
	FriendJoined = { channel = "toast", priority = 2, merge = "none", locKey = "notify.friend_joined" },
	InventoryFull = { channel = "toast", priority = 4, merge = "replace", mergeWindow = 30, minTime = 4, sound = "Warn", locKey = "notify.inventory_full" },
	LevelUp = { channel = "banner", priority = 3, merge = "replace", mergeWindow = 2, sound = "LevelUp", locKey = "notify.level_up" },
	RareDropServer = { channel = "chat", priority = 2, merge = "none", locKey = "notify.rare_drop_server" },
}

return Kinds
```

The priority scale is deliberately small. With 20 priority levels, everyone picks 15 and the scale means nothing.

---

## 3. The toast queue

### Capacity

| Device | Visible toasts at once (rule of thumb) |
|---|---|
| Phone | 2 to 3 |
| Tablet | 3 |
| PC / console | 4 to 5 |

More than that and the stack covers gameplay and nobody reads the bottom ones. The rest wait in a queue, which itself needs a cap (about 8 to 10) and an age limit: a "quest progress 3/10" toast that waited 15 s behind others is stale and should be dropped, not shown.

### Lifetime from reading time

Fixed 3-second toasts are too short for long text and too long for "+5". Derive lifetime from length, then clamp:

```lua
local function lifetime(text: string, minTime: number?): number
	local words = select(2, string.gsub(text, "%S+", ""))
	-- about 0.3 s per word on top of a 1.6 s base (rule of thumb, roughly 200 words per minute)
	return math.clamp(1.6 + words * 0.3, minTime or 2.5, 7)
end
```

Pause the timer while the player is hovering or touching the toast (they are reading it), and on gamepad while it is selected. Many games skip this; players notice when a toast vanishes under their finger.

### Merging

Merging is what keeps a burst of 20 events from becoming 20 toasts.

| Merge rule | Behaviour | Example |
|---|---|---|
| `sum` | Same kind and key within the window: add the amounts, restart the "bump" animation, extend lifetime a little | "+250 coins" five times becomes "+1,250 coins" |
| `count` | Same key: show a multiplier | "Iron Ore" three times becomes "Iron Ore x3" |
| `replace` | Same key: new content replaces old in place | "Quest 3/10" then "Quest 4/10" in the same toast |
| `none` | Every event is its own toast | "Alex joined" and "Sam joined" |

The merge key is usually `kind .. ":" .. subject` (for example `ItemObtained:iron_ore`). Merging must also apply to **waiting** notes, not only visible ones; otherwise a queue of 10 identical waiting toasts appears one after another after a burst.

When a merged toast updates, extend its life by a small amount (0.5 to 1 s), capped at the maximum lifetime from first appearance. Uncapped extension means a toast fed by a continuous trickle (passive income) never leaves.

The reference project merged same-kind floating numbers within 0.55 s and capped live floating numbers at 12 ([[HUD Design]]); toasts use longer windows because they are read, not glanced at.

### Preemption

When the stack is full and a higher-priority note arrives, dismiss the lowest-priority, oldest visible toast early (fast exit) and show the new one. Never preempt a note of equal or higher priority; queue instead. Critical notes (priority 4) may also bypass the popup gate, because "Inventory full, your drops are being lost" during a cutscene still matters.

---

## 4. A controller you can build on

```lua
--!strict
-- NotificationController (client). Renderer-agnostic: renderToast/updateToast/dismissToast are yours.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Kinds = require(game:GetService("ReplicatedStorage").Shared.NotificationKinds)

type Note = {
	kind: string,
	key: string,
	params: { [string]: any },
	amount: number,
	count: number,
	priority: number,
	createdAt: number,
	shownAt: number?,
	expiresAt: number,
	paused: boolean,
	handle: any?, -- renderer's object (a Frame, a component instance)
}

local MAX_VISIBLE = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then 3 else 4
local MAX_WAITING = 10
local STALE_AFTER = 12 -- seconds in queue before a routine note is dropped

local visible: { Note } = {}
local waiting: { Note } = {}
local byKey: { [string]: Note } = {}
local ticking = false

-- Supplied by your renderer module through Notifications.init.
export type Renderer = {
	render: (note: Note) -> any,              -- create the toast, return a handle
	update: (note: Note) -> (),               -- merged: refresh text and bump
	dismiss: (note: Note, fast: boolean) -> (),
	format: (note: Note) -> string,           -- localised text from kind + params
}
local renderer: Renderer

local function computeLife(note: Note): number
	local kind = Kinds[note.kind]
	local text = renderer.format(note)
	local words = select(2, string.gsub(text, "%S+", ""))
	return math.clamp(1.6 + words * 0.3, kind.minTime or 2.5, 7)
end

local tick: () -> ()

local function show(note: Note)
	local now = os.clock()
	note.shownAt = now
	note.expiresAt = now + computeLife(note)
	note.handle = renderer.render(note)
	table.insert(visible, note)
	if not ticking then
		ticking = true
		task.spawn(tick)
	end
end

local function removeFrom(list: { Note }, note: Note)
	local i = table.find(list, note)
	if i then
		table.remove(list, i)
	end
end

local function dismiss(note: Note, fast: boolean)
	removeFrom(visible, note)
	if byKey[note.key] == note then
		byKey[note.key] = nil
	end
	renderer.dismiss(note, fast)
end

local function promote()
	local now = os.clock()
	while #visible < MAX_VISIBLE and #waiting > 0 do
		local nextNote = table.remove(waiting, 1) :: Note
		if nextNote.priority <= 1 and now - nextNote.createdAt > STALE_AFTER then
			if byKey[nextNote.key] == nextNote then
				byKey[nextNote.key] = nil
			end
			continue -- stale routine note: drop it
		end
		show(nextNote)
	end
end

function tick()
	while #visible > 0 or #waiting > 0 do
		local now = os.clock()
		for i = #visible, 1, -1 do
			local note = visible[i]
			if note.paused then
				note.expiresAt += 0.1 -- hold while hovered or touched
			elseif now >= note.expiresAt then
				dismiss(note, false)
			end
		end
		promote()
		task.wait(0.1)
	end
	ticking = false
end

local function mergeInto(existing: Note, incoming: Note)
	local kind = Kinds[existing.kind]
	if kind.merge == "sum" then
		existing.amount += incoming.amount
	elseif kind.merge == "count" then
		existing.count += 1
	elseif kind.merge == "replace" then
		existing.params = incoming.params
	end
	if existing.shownAt then
		local cap = existing.shownAt + 7
		existing.expiresAt = math.min(existing.expiresAt + 0.75, cap)
		renderer.update(existing)
	end
end

local Notifications = {}

function Notifications.init(r: Renderer)
	renderer = r
end

function Notifications.push(kindName: string, key: string, params: { [string]: any }, amount: number?)
	local kind = Kinds[kindName]
	if not kind or kind.channel ~= "toast" then
		return -- banners and chat go through their own renderers
	end
	local now = os.clock()
	local fullKey = kindName .. ":" .. key
	local note: Note = {
		kind = kindName, key = fullKey, params = params, amount = amount or 0, count = 1,
		priority = kind.priority, createdAt = now, expiresAt = 0, paused = false,
	}

	local existing = byKey[fullKey]
	if existing and kind.merge ~= "none" and now - existing.createdAt <= (kind.mergeWindow or 0) + 7 then
		mergeInto(existing, note)
		return
	end
	if kind.merge ~= "none" then
		byKey[fullKey] = note
	end

	if #visible < MAX_VISIBLE then
		show(note)
		return
	end

	-- Full: preempt the lowest-priority, oldest visible note if this one outranks it.
	local victim: Note? = nil
	for _, v in visible do
		if v.priority < note.priority and (victim == nil or v.priority < victim.priority
			or (v.priority == victim.priority and (v.shownAt or 0) < (victim.shownAt or 0))) then
			victim = v
		end
	end
	if victim then
		dismiss(victim, true)
		show(note)
		return
	end

	-- Otherwise queue by priority (stable within equal priority), capped.
	local insertAt = #waiting + 1
	for i, w in waiting do
		if w.priority < note.priority then
			insertAt = i
			break
		end
	end
	table.insert(waiting, insertAt, note)
	if #waiting > MAX_WAITING then
		local dropped = table.remove(waiting) :: Note -- lowest priority, newest
		if byKey[dropped.key] == dropped then
			byKey[dropped.key] = nil
		end
	end
end

function Notifications.setPaused(note: Note, paused: boolean)
	note.paused = paused
end

return Notifications
```

Notes:

- The tick loop exists only while something is visible or waiting, then exits. Idle cost is zero ([[HUD Design]], section 7).
- `byKey` points at the latest note for a key so merges find it whether it is visible or waiting. The merge test allows the merge window plus the note's maximum life, so a toast still on screen keeps absorbing updates.
- Rendering (stacking positions, slide in from the edge, exit) is separate. Stack toasts by animating each toast's `Position` toward its slot index when the list changes; with a `UIListLayout` the remaining toasts jump when one leaves. Motion tokens: [[UI Motion Language and Timing]].
- Gate this controller with the same popup gate as banners if your game has cutscenes and death screens, except priority 4.

---

## 5. Server side

```lua
--!strict
-- Server: one function every system calls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NotifyRemote = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local lastSent: { [Player]: { [string]: number } } = {}
local MIN_GAP = 0.25 -- per player, per kind+key: coalesce bursts on the server too

local Notify = {}

function Notify.send(player: Player, kind: string, key: string, params: { [string]: any }?, amount: number?)
	local perPlayer = lastSent[player]
	if not perPlayer then
		perPlayer = {}
		lastSent[player] = perPlayer
	end
	local k = kind .. ":" .. key
	local now = os.clock()
	if amount == nil and perPlayer[k] and now - perPlayer[k] < MIN_GAP then
		return -- duplicate event in the same burst; amounts are not dropped
	end
	perPlayer[k] = now
	NotifyRemote:FireClient(player, kind, key, params or {}, amount)
end

game:GetService("Players").PlayerRemoving:Connect(function(p)
	lastSent[p] = nil
end)

return Notify
```

Things the server must own:

- **Facts, not decoration.** The server decides that an item was obtained; the client decides how to show it.
- **Bursts.** A system that grants 200 drops in one frame (an AFK collector, an area loot burst) should send one summary (`kind = "LootSummary", items = {...}`) rather than 200 remote calls. Remote traffic is per message overhead plus payload ([[Network Performance]]).
- **Offline events go to the inbox, not the remote.** A gift sent while the player was offline is stored in their profile and shown from the inbox on next join, after loading, through the popup gate.
- **Text from other players is filtered.** A toast that displays a pet name, a guild name or a trade message typed by another player must carry text that passed `TextService` filtering for that recipient. Player display names from the platform are fine to show; custom strings are not until filtered.

### Server-wide and cross-server announcements

"Someone just rolled a Mythic" in every server is a powerful social hook ([[Social Design and Multiplayer Play]]). Route it through `MessagingService` with a throttle (one announcement per kind per N seconds per server is plenty), and send parameters (rarity, item id, the player's display name), not a pre-formatted string. MessagingService has its own message size and rate limits; see [[Cross-Server Messaging]]. A global feed that fires constantly trains players to ignore it; reserve it for the top one or two rarity tiers.

---

## 6. Platform channels

### CoreGui notifications (`SetCore("SendNotification")`)

`StarterGui:SetCore("SendNotification", {...})` shows Roblox's own notification in the bottom-right corner. Fields used in practice (community sources; the official `SetCore` reference documents the general call, check it for the current field list): `Title`, `Text`, `Icon`, `Duration` (seconds), and optionally `Button1`, `Button2` with a `Callback` that must be a `BindableFunction` whose `OnInvoke` receives the pressed button's text.

Trade-offs:

- **Pro:** zero UI work; looks native; does not collide with your HUD layout.
- **Con:** you cannot style it, cannot merge, cannot prioritise, and it competes with Roblox's own notifications (friend requests, badges). It also looks the same in every game, so it carries little brand.
- **Edge case:** `SetCore` can error if called very early, before the CoreScripts have registered the callback. Wrap it in `pcall` and retry a few times with a short wait. Call it from a LocalScript only.

Use it for low-frequency, game-independent messages (a debug build banner, a "server restarting for an update" warning) or in prototypes. Use your own toasts for gameplay.

### Chat system messages

On `TextChatService`, `TextChannel:DisplaySystemMessage(text, metadata)` adds a local system line to that client's chat (Roblox docs list the method; call it on the client, for that player only). It suits social, server-wide flavour ("X hatched a Legendary!"). Caveats:

- Many players hide or minimise chat, and on phones chat is often collapsed. Never put anything required there.
- Chat may be unavailable for some accounts (age or parental settings). Treat it as a bonus channel.
- Rich text is commonly used for coloured rarity names in system messages, but verify behaviour in your chat configuration, and never insert unfiltered player-authored text.

### Out-of-experience notifications

Roblox can deliver notifications to players outside the experience, to bring them back. As of October 2026, per the Roblox docs:

- Players must **opt in**. In the experience, `ExperienceNotificationService:CanPromptOptInAsync()` tells you whether you may show the opt-in prompt, `PromptOptIn()` shows it, and `OptInPromptClosed` fires when it closes.
- Sending is done through the **Open Cloud User Notifications** API (with an API key or OAuth), from your backend, not from the game server's Luau directly.
- Delivery is limited: recipients must be opted-in users aged 13 or older, the experience needs at least 100 visits and must not be under moderation, and each user receives at most **one notification per day per experience**, with throttling feedback when the cap is hit.

Design implications: because you get one per day at most, spend it on the highest-value message (your energy refill, a limited event starting, a friend's gift waiting), not "come back and play!". Ask for opt-in at a moment of value (right after the player sets up something that will be ready later), not on first join. See [[Retention and Return Hooks]] and [[Open Cloud APIs]].

---

## 7. Placement, motion and accessibility

- **Placement:** toasts live in one zone, usually top-right on PC and top-centre or upper-right on phones, clear of the jump and action buttons and the top bar inset ([[Safe Areas and Insets]], [[HUD Design]]). Never bottom-right on phones: that is where thumbs and action buttons live.
- **Direction:** toasts slide in from the nearest screen edge and stack away from it. New toasts appear at the edge-most slot, older ones move inward, or the reverse; pick one and keep it.
- **Sound:** give priority 3 and 4 notes a sound; give routine notes none, or one shared soft sound rate-limited to once per 0.5 s. Twenty toast sounds in a second is noise ([[Game Feel and Juice]]).
- **Colour is not the message.** A red toast for errors must also have an icon and wording that says it is an error ([[Accessibility]]).
- **Reduced motion:** fade toasts in place; do not slide.
- **Gamepad:** toasts are not selectable unless they have an action. If one does ("Gift received, press Y to open"), bind the action with `ContextActionService` while the toast is visible and show the button glyph, rather than making the player navigate to it ([[Gamepad and Console UX]]).
- **Localisation:** German and Portuguese strings run 30% or more longer than English (rule of thumb); size toasts with `AutomaticSize` on the Y axis and a max width, and let lifetime follow the translated text length ([[Localization]]).

---

## 8. Failure modes and how to test for them

| Failure | Looks like | Test |
|---|---|---|
| No merging | A column of identical toasts after a loot burst | Grant 50 items in one frame |
| Unbounded queue | Toasts still appearing a minute after the burst | Same, then watch for 60 s |
| Stale messages | "Quest 2/10" shown after the quest completed | Progress quickly; check replace merging |
| Gate ignored | Level-up banner over a death screen | Level up at the moment of death |
| Critical note lost | "Inventory full" hidden behind routine toasts | Fill inventory during a loot burst |
| Notification before data | "You got X" before the inventory shows X | Throttle the network in Studio and watch order |
| Per-frame cost | Steady frame time cost with no toasts on screen | MicroProfiler while idle |
| Text overflow | Translated text clipped | Pseudo-localise to 140% length |

A cheap habit: keep a debug command that fires every notification kind 10 times in one frame. Run it after any change to the controller.

---

## Common mistakes

| Mistake | Fix |
|---|---|
| Errors shown as corner toasts | Inline feedback at the control that failed |
| Actionable info in a toast that expires | Persistent badge or inbox entry |
| Server sends formatted English strings | Send kind and parameters; format on client |
| Every system creates its own label | One controller, data-driven kinds |
| Sum-merge with uncapped lifetime extension | Cap total life from first show |
| Global announcements for every rare drop | Top tiers only, throttled per server |
| Asking for out-of-experience opt-in on first join | Ask at a moment of value |
| SendNotification for core gameplay messages | Own toasts; reserve CoreGui for system-level messages |
| Unfiltered player text in a toast or chat line | Filter with TextService for the recipient |

---

## Checklist

- [ ] Every message has a chosen channel; errors are inline where possible.
- [ ] Notification kinds defined as data with priority, merge rule and lifetime.
- [ ] Server sends kind and parameters; client localises and formats.
- [ ] Visible cap per device class; queue capped with stale-drop.
- [ ] Merging applies to visible and waiting notes; lifetime extension capped.
- [ ] Higher priority preempts lower; critical notes bypass the gate.
- [ ] Lifetime follows text length; timer pauses on hover, touch or selection.
- [ ] Loot bursts summarised server-side.
- [ ] Player-authored text filtered before display to others.
- [ ] Out-of-experience opt-in asked at a moment of value; the daily message is the best one.
- [ ] Spam test (every kind x10 in one frame) passes; idle cost is zero.

## See also

[[HUD Design]], [[UI Motion Language and Timing]], [[Game Feel and Juice]], [[Localization]], [[Accessibility]], [[Safe Areas and Insets]], [[RemoteEvents RemoteFunctions and Unreliable Remotes]], [[Cross-Server Messaging]], [[Retention and Return Hooks]], [[Open Cloud APIs]], [[Social Design and Multiplayer Play]], [[Live Ops Events and Updates]]

## Connected notes
<!-- auto-links:start -->
[[Experience Notifications and Return Prompts]] · [[Localization Pipeline]] · [[Reward Moments and Celebrations]] · [[Quest Writing and Hooks]] · [[Text Chat Customization with TextChatService]] · [[Age Checks and Safety Features]]
<!-- auto-links:end -->
