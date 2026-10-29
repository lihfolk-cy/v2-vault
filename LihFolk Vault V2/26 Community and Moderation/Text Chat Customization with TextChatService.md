---
tags: [community, moderation, chat, textchatservice, safety, luau, ui, type/guide, area/community, level/intermediate, api/TextChatService, area/ui]
---
# Text Chat Customization with TextChatService

<!-- tldr:start -->
> [!tldr] TL;DR
> - Tags or colours vanish after adding a module: Two scripts assigned the same callback slot
> - Some players "never answer": They cannot see each other's chat because of age groups; design for it
> - Admin command works in Studio, fails live: Rank check against the wrong group id, or the group lookup...
> - No player text travels through remotes; all chat via `TextChatService`
> - No code reads, logs or reacts to message text (except `TextChatCommand`)
> - Each callback owned by exactly one module; no yields inside
>
> Cost: TL;DR ~170 tok · whole note ~5.4k tok. Read more: ## 2. Platform-integrated chat (Announcement and Roblox docs, October 2026) · ## 3. The object model · ## 11. Common mistakes and how to spot them · ## 12. Checklist
<!-- tldr:end -->

Text chat is where players talk to each other, which makes it the single most safety-sensitive feature in most games. This note goes past the basics in [[Age Checks and Safety Features]] (all player text through `TextChatService`, filtering, direct-chat eligibility) and covers what you can actually customize: channels, delivery rules, chat tags, commands, bubbles, system messages, and the October 2026 change called **platform-integrated chat**, which removes your code's access to message text and will be required for every game in 2027. If you are designing a chat feature today, read section 2 before you write a line, because some popular customizations are on a deprecation clock.

Facts are labelled "Roblox docs (as of October 2026)", "Announcement (October 2026)", "measured in the reference project" or "rule of thumb". This area is moving monthly; re-check the dates.

---

## 1. Safety first: what chat customization may never do

Roblox's Community Standards and the Chat System Guidelines apply to every message, whether it shows in the default window or yours. Before any styling question:

- **All player-to-player text goes through `TextChatService`.** A `RemoteEvent` that carries text from one player to others is a custom chat transport and breaks the rules, because it skips filtering, age-based chat groups, muting, blocking and abuse reporting (Announcement, January and October 2026).
- **You never decide who may talk to whom based on age.** Roblox does that through age checks and chat groups ([[Age Checks and Safety Features]]). Your code can only *narrow* delivery (proximity, team, party), never widen it.
- **Do not build a feature whose purpose is to move a conversation somewhere less moderated**: no "type your Discord" prompts, no free-text notes in trades, no private-message system outside `TextChatService`. Moving children off-platform is the most common grooming pattern, and the platform rules on external links exist for that reason ([[Community Building]]).
- **Never log raw chat to your own data stores or external servers.** Chat is personal data ([[Player Privacy and Data Deletion]]). Under platform-integrated chat this becomes impossible anyway, but even today it is a liability with no upside: Roblox already has the reports and the moderators.
- **Gameplay must work without chat**, because many players in any server cannot see each other's messages. Use pings, emotes and quick-phrase wheels ([[Social Design and Multiplayer Play]]).

If a customization idea conflicts with any of the above, drop it. No amount of polish is worth a moderation strike on the game.

---

## 2. Platform-integrated chat (Announcement and Roblox docs, October 2026)

In October 2026 Roblox announced a foundational change to `TextChatService` called platform-integrated chat. Summary:

| Phase | Date (as announced) | What happens |
|---|---|---|
| Opt-in testing | Now until February 2027 | Set `TextChatService.PlatformIntegratedChat` to `Enabled` in Studio |
| Default on | February 2027 | All new and existing games opted in, with an opt-out |
| Required | May 2027 | The updated service is the only way to have custom chat |

The announcement's API table also mentions an opt-out "before March 2027", which conflicts with the May date elsewhere in the same post. Treat May 2027 as the hard line and March as possible.

**What changes when it is enabled (Roblox docs):**
- Roblox renders all chat, either in the default window or in a new `TextChannelWindow` you place in your own `ScreenGui` (one window per channel; set `Target` to a `TextChannel`). Custom UIs can no longer draw messages themselves.
- `TextChatMessage.Text` and `.Translation` return `""` (not `nil`) with a warning. `PrefixText` is not supported. Scripts keep running but see no content.
- `TextChannel:SendAsync` for custom presets and chat wheels is replaced by a creator customization called Quick Words.
- `TextChatService.OnIncomingMessage` and `Player.Chatted` no longer give you text for moderation or admin commands; commands must use `TextChatCommand`.
- No API returns message content on client or server. Moderators with the right group permission can view chat read-only ([[Groups Roles and Permissions for Studios]]).
- The property can only be changed in Studio, not by script.
- Signs, boards, mail and comment systems are not affected; their filtering rules still apply ([[Player Reports and In-Game Moderation]]).

**Not yet available (Announcement, October 2026, planned dates):** native prefixes or role badges (early February 2027), keyword detection anywhere in a message (by February), message history (end of 2026), creator blocked words (by May 2027), display name colours (November 2026), bubbles inside `TextChannelWindow` (later in 2026). The docs say plainly: if your game depends on prefixes, do not enable the setting yet.

**What this means for design decisions today (rule of thumb):**
- Do not build anything new that reads message text: chat logs, keyword triggers ("say 'open sesame'"), chat-based minigames, profanity counters, "first to type the word" events. They will stop working within months.
- Admin commands: build them as `TextChatCommand` now (section 6). That path survives.
- Chat tags (VIP, Developer, rank): build them so they are easy to switch to the native role badges. Keep the data (who has which tag) in attributes, and keep the rendering in one small client module you can delete.
- Custom chat windows: prototype with `TextChannelWindow` and accept limited styling (transparency, fonts, size) rather than investing in a bespoke renderer.

The rest of this note describes the current API with that clock in mind. Every section marks what survives.

---

## 3. The object model

`TextChatService` is the root. Under it (Roblox docs):

| Object | Role | Notes |
|---|---|---|
| `TextChannel` | A conversation. Messages go client to server to recipients | Must be parented to `TextChatService` |
| `TextSource` | One user inside a channel | Created by `AddUserAsync`; has `CanSend` and `UserId` |
| `TextChatMessage` | One message: sender, text, filtered text, timestamp, `Status`, `Metadata` | `Text` empties under platform-integrated chat |
| `TextChatCommand` | Fires `Triggered` when a message starts with `PrimaryAlias` or `SecondaryAlias` | Survives platform-integrated chat |
| `ChatWindowConfiguration` | Default window settings | `TextChannelDisplayMode` new in 2026 |
| `ChatInputBarConfiguration` | Input bar settings, including which channel is targeted | |
| `BubbleChatConfiguration` | Bubble settings: `BubbleDuration`, `MaxBubbles`, `MaxDistance`, `MinimizeDistance`, `TailVisible`, `VerticalStudsOffset`, `LocalPlayerStudsOffset`, `AdorneeName`, colours, `FontFace`, `TextSize` | Still supported |
| `ChannelTabsConfiguration` | Channel tabs in the default window | |

`CreateDefaultTextChannels` creates `RBXGeneral` and `RBXSystem` (and team and whisper channels as needed). `CreateDefaultCommands` creates the built-in slash commands. Avoid creating your own channel with a default channel's name; the docs warn that duplicates confuse the default window.

### Message flow (Roblox docs)
1. Client calls `TextChannel:SendAsync`. If the message matches a command alias, `TextChatCommand.Triggered` fires instead and the message is not sent as chat.
2. Otherwise `TextChatService.SendingMessage` fires locally (status `Sending`) and the message goes to the server.
3. The server runs the channel's `ShouldDeliverCallback` once per `TextSource`.
4. For each recipient that passes, filtering applies and `OnIncomingMessage` runs on that client (and once on the sender), then the message appears.

### Callbacks and where they run (Roblox docs)
| Callback | Runs on | Returns |
|---|---|---|
| `TextChannel.ShouldDeliverCallback` | Server | `boolean` |
| `TextChatService.OnIncomingMessage` / `TextChannel.OnIncomingMessage` | Client | `TextChatMessageProperties` |
| `TextChatService.OnBubbleAdded` | Client | `BubbleChatMessageProperties` |
| `TextChatService.OnChatWindowAdded` | Client | `ChatWindowMessageProperties` |

All callbacks must be non-yielding. A callback is a single slot: assigning a second function replaces the first. That is the most common source of "my chat tags vanished after I added a plugin" bugs (rule of thumb): two scripts both assign `OnIncomingMessage` and the last one wins. Own each callback in exactly one module.

---

## 4. Delivery rules with `ShouldDeliverCallback`

This server callback is the right tool for proximity chat, team-only chat in a channel, spectator rules and "dead players cannot talk to the living". It only narrows delivery; Roblox's own rules apply first.

```lua
--!strict
-- Server Script: proximity delivery on the general channel.
-- Reviewed, not run.
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local RANGE = 80 -- studs; rule of thumb, tune by map scale

local general = TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXGeneral") :: TextChannel

local function rootOf(userId: number): BasePart?
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

general.ShouldDeliverCallback = function(message: TextChatMessage, target: TextSource): boolean
	local source = message.TextSource
	if source == nil then
		return true -- system messages
	end
	if source.UserId == target.UserId then
		return true -- the sender always sees their own message
	end
	local a, b = rootOf(source.UserId), rootOf(target.UserId)
	if a == nil or b == nil then
		return false -- dead or loading players do not receive proximity chat
	end
	return (a.Position - b.Position).Magnitude <= RANGE
end
```

Edge cases worth deciding on purpose:
- **Sender feedback.** If nobody is in range, the sender sees their message and assumes it was read. Show a subtle "nobody nearby heard you" hint from your own UI, computed on the client from positions, not from message text.
- **Respawn gaps.** During respawn the root is missing, so messages vanish. Decide whether that is a feature.
- **Cost.** The callback runs per recipient per message. With 50 players and a chat burst of 10 messages a second that is 500 calls a second. Keep it to a distance check; never yield, never call a data store.
- **Compatibility.** `ShouldDeliverCallback` is not listed among the APIs that lose access under platform-integrated chat, but the announcement does not discuss it either. Unverified for 2027; test it with the setting enabled.

---

## 5. Muting and chat permissions with `TextSource.CanSend`

Each `TextSource` has a `CanSend` boolean. Setting it to false on the server stops that user sending in that channel. It is the clean way to implement a game-level mute that respects your own rules (a moderator mute, a "no chat during the quiz" rule, a new-account cool-down).

```lua
--!strict
-- Server: mute a user in every channel they belong to, for a duration.
-- Reviewed, not run.
local TextChatService = game:GetService("TextChatService")

local mutedUntil: { [number]: number } = {}

local function applyMute(userId: number, muted: boolean)
	for _, channel in TextChatService:GetDescendants() do
		if channel:IsA("TextChannel") then
			local source = channel:FindFirstChild(tostring(userId))
			if source and source:IsA("TextSource") then
				source.CanSend = not muted
			end
		end
	end
end

local function muteFor(userId: number, seconds: number)
	mutedUntil[userId] = os.clock() + seconds
	applyMute(userId, true)
	task.delay(seconds, function()
		if (mutedUntil[userId] or 0) <= os.clock() then
			mutedUntil[userId] = nil
			applyMute(userId, false)
		end
	end)
end

-- New channels or rejoins: re-apply when a TextSource appears.
TextChatService.DescendantAdded:Connect(function(inst)
	if inst:IsA("TextSource") and mutedUntil[inst.UserId] then
		inst.CanSend = false
	end
end)
```

Two caveats. First, finding the source by name assumes `TextSource.Name` is the user id; that is the observed default, not a documented contract, so prefer iterating `channel:GetChildren()` and comparing `UserId` in production. Second, a game mute is not a Roblox moderation action. Muting someone for a rule *you* set is fine; for anything that breaks the Community Standards, the right action is the player's own report plus your kick or ban ([[Player Reports and In-Game Moderation]]).

---

## 6. Admin and gameplay commands with `TextChatCommand`

Commands are the one chat-reading feature that survives platform-integrated chat. A `TextChatCommand` parented to `TextChatService` fires `Triggered(originTextSource, unfilteredText)` when a message begins with its alias.

```lua
--!strict
-- Server Script: a /kick command for group moderators.
-- Reviewed, not run. Connect on the server; never trust a client-side rank check.
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local GroupService = game:GetService("GroupService")

local GROUP_ID = 0 -- your group
local MIN_RANK = 200 -- your moderator rank

local command = Instance.new("TextChatCommand")
command.Name = "ModKick"
command.PrimaryAlias = "/modkick"
command.AutocompleteVisible = false -- do not advertise moderator commands
command.Parent = TextChatService

local function isModerator(player: Player): boolean
	local ok, rank = pcall(function()
		-- highest role's Rank; Player:GetRankInGroup(Async) is deprecated
		local info = GroupService:GetRolesInGroupAsync(player.UserId, GROUP_ID)
		return if info.IsMember and info.Roles[1] then info.Roles[1].Rank else 0
	end)
	return ok and rank >= MIN_RANK
end

command.Triggered:Connect(function(source: TextSource, text: string)
	local caller = Players:GetPlayerByUserId(source.UserId)
	if not caller or not isModerator(caller) then
		return
	end
	-- "/modkick name": take the first argument only, never echo the raw text.
	local targetName = string.match(text, "^%S+%s+(%S+)")
	if not targetName then
		return
	end
	for _, p in Players:GetPlayers() do
		if string.lower(p.Name) == string.lower(targetName) and p ~= caller then
			p:Kick("Removed by a moderator.")
			-- log who, whom, when (see Player Reports and In-Game Moderation)
			break
		end
	end
end)
```

Rules for commands (rule of thumb):
- `unfilteredText` is exactly that. Parse ids and names out of it; never broadcast it, store it or show it to other players.
- `AutocompleteVisible = false` for staff commands. Players will still find them; the rank check is the security, not the secrecy.
- Prefer a moderation **panel** over typed commands for anything with consequences. Typing a username wrong kicks the wrong player; a panel lists the players in the server.
- Gameplay commands (`/dance2`, `/afk`) are fine and survive the change.
- Do not shadow default commands (`/mute`, `/whisper`, `/team`) with your own aliases.

---

## 7. Chat tags and name colours

The common pattern today: read an attribute on the sender's `Player` in `OnIncomingMessage` (or `OnChatWindowAdded`) and set `PrefixText`. The docs suggest attributes as the replacement for the legacy `SetExtraData`.

```lua
--!strict
-- LocalScript: chat tags from a server-set attribute.
-- Reviewed, not run. PrefixText is NOT supported under platform-integrated chat.
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local TAGS: { [string]: string } = {
	Dev = "<font color='#ffb84d'>[DEV]</font>",
	VIP = "<font color='#7fd1ff'>[VIP]</font>",
}

TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local props = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	if source then
		local player = Players:GetPlayerByUserId(source.UserId)
		local tag = player and player:GetAttribute("ChatTag")
		if typeof(tag) == "string" and TAGS[tag] then
			props.PrefixText = `{TAGS[tag]} {message.PrefixText}`
		end
	end
	return props
end
```

Nuances:
- The attribute is set by the server (from a pass, rank or role), never by the client. A client can set attributes on its own `Player` locally, but only it will see them.
- Keep `message.PrefixText` in the new prefix, or you erase the display name.
- Paid chat tags are a common monetization item. Under platform-integrated chat they disappear until native role badges arrive (planned early February 2027). If you sell one, write the benefit as "a VIP badge in chat where supported" and keep a visible non-chat VIP perk too, so nobody has paid for something that silently stops working ([[Game Passes]], [[Ethical Design and Player Trust]]).

---

## 8. System messages, announcements and NPC bubbles

- `TextChannel:DisplaySystemMessage(text, metadata?)` runs on the **client**. To announce something server-wide, send a short remote with an id and parameters, and let each client compose and display the localized line. The announcement confirms this works in `TextChannelWindow` and supports rich text.
- Never put player-authored text into a system message. A "Player X named their pet Y" announcement must filter Y with `TextService` for broadcast first ([[Age Checks and Safety Features]]).
- `TextChatService:DisplayBubble(partOrCharacter, message)` shows a bubble over an NPC or part. It is local; call it on each client that should see it. Good for NPC dialogue that does not need a dialogue UI.
- Rate-limit announcements. A rare-drop feed that posts every pull in a busy server drowns real conversation. The reference project announced only high rarity pulls and server-wide purchases (measured in the reference project).

---

## 9. Custom channels: party, team, guild

Party and guild channels need a server-created `TextChannel`, members added with `AddUserAsync`, and an eligibility check through `CanUsersDirectChatAsync` before adding anyone ([[Age Checks and Safety Features]] has a full example). Decisions to make:

| Decision | Recommendation (rule of thumb) |
|---|---|
| Cross-server guild chat | Do not build it. It needs your own transport, which is a custom chat system |
| Persisted history | Not yours to keep; Roblox plans native history |
| Channel visibility | Under platform-integrated chat, set `ChatWindowConfiguration.TextChannelDisplayMode` to `DefaultTextChannels` and give custom channels their own `TextChannelWindow` |
| Cleanup | Destroy the channel when the party ends; stale channels leak `TextSource`s |
| Many channels | One window per channel today; multi-channel windows are only "under consideration" |

---

## 10. When not to customize

- **Small games**: default chat with bubbles on is the right answer. Every custom piece is a future migration.
- **Kids and Select audiences**: many players cannot chat at all. Invest in quick phrases and pings instead ([[Social Design and Multiplayer Play]]).
- **Competitive games**: proximity chat can leak positions; team-only delivery is fairer.
- **Anything reading text**: see section 2.

---

## 11. Common mistakes and how to spot them

| Symptom | Likely cause |
|---|---|
| Tags or colours vanish after adding a module | Two scripts assigned the same callback slot |
| Some players "never answer" | They cannot see each other's chat because of age groups; design for it |
| Admin command works in Studio, fails live | Rank check against the wrong group id, or the group lookup (`GroupService:GetRolesInGroupAsync`) failing without `pcall` |
| Chat freezes for everyone | A yielding call inside a callback |
| Warning spam about empty `Text` | Platform-integrated chat enabled while code still reads `Text` |
| Quick-chat wheel stopped sending | `SendAsync` used for presets; move to Quick Words |

---

## 12. Checklist

- [ ] No player text travels through remotes; all chat via `TextChatService`
- [ ] No code reads, logs or reacts to message text (except `TextChatCommand`)
- [ ] Each callback owned by exactly one module; no yields inside
- [ ] Delivery rules only narrow, never widen
- [ ] Staff commands are server-checked, hidden from autocomplete and logged
- [ ] Paid chat cosmetics have a non-chat equivalent
- [ ] Game tested with `PlatformIntegratedChat` set to `Enabled`
- [ ] Gameplay playable with chat off

## See also
[[Community and Moderation Start Here]] · [[Voice Chat and Safety Features]] · [[Player Reports and In-Game Moderation]] · [[Age Checks and Safety Features]] · [[Community Building]] · [[Social Design and Multiplayer Play]] · [[Text Fonts and Rich Text]] · [[Localization]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]]

## Connected notes
<!-- auto-links:start -->
[[Links - Chat and text filtering]] · [[Discord Servers for Roblox Games]] · Links - Teams and permissions · Notification and Toast Systems · Cross-Server Messaging · Writing Dialogue for Roblox Players
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Block and Mute Respecting Platform Rules]] · [[Policy and Age Rules 2026]] · [[Admin Commands Done Safely - Permissions and Audit Logs]] · [[AI Pitfalls - Stale APIs and Luau]] · [[Roblox Changes 2025-2026]] · [[Working with Content Creators]]
<!-- related:end -->
