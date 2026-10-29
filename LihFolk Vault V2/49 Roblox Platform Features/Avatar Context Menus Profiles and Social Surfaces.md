---
tags: [platform-features, social, avatar-context-menu, inspect-menu, profiles, friends, blocking, startergui, luau, strict, type/guide, area/platform]
---
# Avatar Context Menus Profiles and Social Surfaces

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: ACM enabled in a combat game -> Enable only in social zones
> - Avoid: Trusting the client that the target is nearby or in the zone -> Server re-checks zone, distance, cooldown
> - Avoid: Ignoring blocks in custom systems -> Sync block list, filter both directions
> - ACM enabled only where clicking players has no other meaning; custom options validated on the server
> - ACM closed and options removed when leaving the zone
> - Inspect menu mode chosen deliberately (profile, current outfit or disabled)
>
> Cost: TL;DR ~170 tok · whole note ~5.5k tok. Read more: ## 1. The Avatar Context Menu · ## 5. Building your own interaction surface · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

"Social surfaces" are the places where one player learns about, and acts on, another: clicking someone's avatar, opening their profile card, seeing that a friend is here, sending a friend request, blocking a nuisance, trying on the outfit someone is wearing. Roblox supplies several of these as built-in menus you can switch on, restyle or replace: the **Avatar Context Menu** (ACM), the **Avatar Inspect Menu**, and a family of `StarterGui:SetCore` prompts. This note covers what each one does, when to use the built-in version and when to build your own, the friends and profile APIs behind custom cards, and the rules that keep these surfaces safe: respect blocks, validate every action on the server, and never show more about a player than they chose to share. [[Social Design and Multiplayer Play]] explains why visible social signals matter; this note is the toolkit.

Platform facts are labelled **Roblox docs (as of October 2026)** and were checked against the Avatar Context Menu and Avatar Inspect Menu guides and the StarterGui, GuiService, Players, Player, [[SocialService]] and AvatarContextMenuOption references on create.roblox.com. Design advice is rule of thumb.

## 1. The Avatar Context Menu

### What it is (Roblox docs, as of October 2026)
When enabled, a player can click or tap another player's character to open a small menu. Default options: **Friend** (send a friend request), **Chat** (private conversation in in-game chat), **View** (inspect appearance) and **Wave** (a wave animation toward them). In the `Enum.AvatarContextMenuOption` enum these are `Friend`, `Chat`, `InspectMenu` and `Emote`. Once open, a carousel lets the player scroll to other nearby characters, sorted by distance; the list updates only when the menu opens and repeats when scrolling.

It is **off by default** and enabled per client:

```lua
StarterGui:SetCore("AvatarContextMenuEnabled", true)
```

Other `SetCore` options (Roblox docs):
- `"AvatarContextMenuTarget"`, with a `Player` to open it on that player, or `nil` to close it.
- `"AddAvatarContextMenuOption"`, with either an `Enum.AvatarContextMenuOption` or a two-element table `{ "Action name", bindableEvent }`. The BindableEvent fires with the selected player when the option is used.
- `"RemoveAvatarContextMenuOption"`, with the same value you added, or a default enum value to remove a built-in option.
- `"AvatarContextMenuTheme"`, with a table of appearance parameters: background colour, transparency and images (with nine-slice support), name tag and underline colours, button frame and button colours, hover states, button images, `Font`, `TextColor`, `TextScale`, the close and scroll button images, a `SelectedCharacterIndicator` MeshPart, and `Size`, `MinSize`, `MaxSize`, `AspectRatio`, `AnchorPoint`, `OnScreenPosition` and `OffScreenPosition`.
- `GetCore("AvatarContextMenuEnabled")` returns whether it is on.

Two constraints from the guide:
- **You cannot edit the ACM while it is open.** Your code must check that an action still makes sense when it fires; the guide's example is a trade option added in a marketplace area, which must verify both players are still in the marketplace.
- The ACM is "best used in games where there is no predefined behavior for clicking on other users." In a combat game, clicking a player is an attack; a menu popping up mid-swing is a bug.

### When to use it (rule of thumb)

| Game type | ACM? | Why |
|---|---|---|
| Hangout, roleplay, social hub | Yes, with custom options | Clicking people is the main social verb |
| Trading game | Yes, in the trading area only | Add "Trade", remove "Wave" if it clutters |
| Simulator with a shared hub | Hub only | Toggle on entering and leaving the hub |
| Combat, shooter, obby | No | Clicks mean something else; use a profile button in the player list instead |
| Console-heavy audience | Test carefully | Character targeting with a gamepad is clumsy; offer a list-based alternative ([[Gamepad and Console UX]]) |

Because enabling is a client call, you can switch the ACM on and off by zone: on when the player enters the hub, off when they enter the arena. Remember to close an open menu (`AvatarContextMenuTarget` set to `nil`) when leaving the zone.

### SetCore timing
`SetCore` calls can fail if the core scripts that register an option have not loaded yet, which is most likely in the first moments of a session (rule of thumb from common experience; the reference does not document a registration event for these options). Wrap calls in `pcall` and retry briefly, as in the sample below.

## 2. The Avatar Inspect Menu

Facts (Roblox docs, as of October 2026):
- **On by default.** Players reach it from the main menu's Players tab (View), by clicking a name in the player list, or from the ACM's inspect option.
- By default it shows the player's **Roblox profile avatar**, which may differ from what they wear in your game.
- To inspect the **current in-game outfit**: `GuiService:SetInspectMenuEnabled(false)` to disable the profile-based menu, then `GuiService:InspectPlayerFromHumanoidDescription(humanoid:GetAppliedDescription(), name)`.
- `GuiService:InspectPlayerFromUserId(userId)` inspects any user, even one not in the game. `GuiService:CloseInspectMenu()` closes it.
- Items bought through the inspect menu earn the game owner a commission (40% for avatar items sold in game; see [[Commerce and Physical Goods]]).

Design consequences:
- **Games with custom avatars or uniforms** (a team game where everyone wears a jersey, a roleplay game with job outfits) should use `InspectPlayerFromHumanoidDescription`, or players will try on items the target is not visibly wearing. Note the trade-off: the inspect menu then shows what the player wears in your game, which can include your game's own items.
- **Games with fixed custom characters** (a creature you play as) might disable the inspect menu entirely: there is no Roblox outfit to show.
- In avatar-focused hangouts the inspect menu is a revenue surface. Make it easy to reach (a "View outfit" button on your profile card).

For outfit systems and in-game editors, see [[HumanoidDescription and Outfit Systems]] and [[AvatarEditorService and In-Game Avatar Editors]].

## 3. Friend, unfriend, block: the SetCore prompts

`StarterGui:SetCore` also exposes platform prompts you can attach to your own UI (Roblox docs, as of October 2026):

| [[SetCore]] option | Argument | Effect |
|---|---|---|
| `PromptSendFriendRequest` | `Player` | Prompts the local player to send a friend request |
| `PromptUnfriend` | `Player` | Prompts to remove a friend |
| `PromptBlockPlayer` | `Player` | Prompts to block |
| `PromptUnblockPlayer` | `Player` | Prompts to unblock |

And `GetCore` values (Roblox docs):
- `"GetBlockedUserIds"`: user ids the local player has blocked.
- `"PlayerBlockedEvent"`, `"PlayerUnblockedEvent"`, `"PlayerMutedEvent"`, `"PlayerUnmutedEvent"`, `"PlayerFriendedEvent"`, `"PlayerUnfriendedEvent"`: each returns a BindableEvent that fires on that change.

The reference text for these now says "connected" and "unconnected" in places where it used to say "friended" and "unfriended", reflecting Roblox's newer wording for friends. The API names still say Friend.

### Respecting blocks in your own systems
Roblox applies blocks to its own surfaces (chat, for example; see [[Text Chat Customization with TextChatService]]). **Your** systems do not know about blocks unless you tell them: a blocked player can still send your custom trade requests, party invites or duel challenges, appear on your custom "nearby players" list, and spam your emote-at-player feature. That is a safety failure, not a polish issue ([[Player Reports and In-Game Moderation]]).

The block list is only available on the **client**. The pattern:
1. The client reads `GetBlockedUserIds` on start and listens to the blocked and unblocked events.
2. It sends the list to the server through a remote.
3. The server stores it as a **preference** for that player and filters every player-to-player action against it, in both directions: if A blocked B, B's requests to A are dropped silently, and A's UI hides B.

Is it a problem that the client could lie? No: a client can only lie about *its own* preferences. Claiming to block someone just hides them from yourself. The server must still bound the list size and validate types ([[Server Authority and Validation]]).

## 4. Friends and profile data for custom cards

When the built-in menus are not enough, you build a **profile card**: name, avatar headshot, level, title, badges earned in your game, "friend" marker, action buttons. Data sources (Roblox docs, as of October 2026):

| API | Side | Notes |
|---|---|---|
| `Players:GetUserThumbnailAsync(userId, thumbnailType, thumbnailSize)` | Either | Returns a content URL and an `isReady` boolean; check readiness or retry |
| `Player:IsFriendsWithAsync(userId)` | Either | Results are **cached**; may be stale after a friendship changes. `IsFriendsWith` is superseded; `IsBestFriendsWith` is obsolete |
| `Player:GetFriendsOnlineAsync()` | Either | Online friends with location fields; a **30-second cache** |
| `Player:GetFriendsWhoPlayedAsync()` | Either | User ids of friends who have played this game; the docs suggest it for friend leaderboards to cut DataStore lookups |
| `Players:GetFriendsAsync(userId)` | Either | A `FriendPages` object (`Id`, `Username`, `DisplayName`) |
| `Players:GetProfileConfigurationFromUserIdAsync(userId)` | **Server only** | Can include `BackgroundAssetId` and `FrameAssetId` from the user's profile; **throttled** to a limited number of requests per minute |
| `BadgeService:GetUserBadgesAsync(userId, badgeIds)` | Server (any user recently in the server) | Up to 100 ids per call; shows "badges earned here" ([[Badges and Achievement Design]]) |
| `Player.PartyId`, `SocialService:GetPartyAsync(partyId)` | Server | Party membership across servers ([[Parties and Group Teleports]]) |

The "Either" entries mean the reference does not restrict them; check each against your own use. Rules of thumb for cards:
- **Show `DisplayName` with the username** in smaller text, as Roblox surfaces do. Display names are not unique; the username disambiguates impersonators.
- **Cache per session.** Profile cards are opened often; fetch thumbnails and profile configuration once per user per server, not on every open. The profile configuration call is explicitly throttled.
- **Player-written text** (bios, guild names, titles they type) must be filtered with `TextService` before others see it ([[Text Chat Customization with TextChatService]]). Titles you award from a fixed list need no filtering.
- **Never show what the player did not choose to share.** Do not show other games they play, their country, their account age, or "last online" for non-friends. Profile frame and background from `GetProfileConfigurationFromUserIdAsync` are things the player set on their profile, which makes them fair to show.
- Roblox ships a **Profile Card** developer module (shows information about other players, including badges and favourite games) and a **Friends Locator** module (find and teleport to friends in a place) (Roblox docs). They are good references even if you build your own.

## 5. Building your own interaction surface

Many games replace click-to-open with something more deliberate:

| Method | Good for | Watch out for |
|---|---|---|
| ACM with custom options | Hangouts; fast to ship | Limited layout; global per client |
| `ProximityPrompt` on other characters (created on the client, local only) | Trading, dueling, "inspect" in hubs; works with touch, mouse and gamepad | Prompt clutter in crowds; limit to the nearest few |
| Player list button | Combat games where clicks are taken | Less discoverable |
| Raycast from tap or click to a character | Custom feel | You handle gamepad and accessibility yourself |

Whatever the trigger, the **action** always goes to the server, and the server re-checks everything the client claimed: both players exist, are close enough or in the right zone, have not blocked each other, and are not rate limited ([[Remote Abuse Patterns and Rate Limiting in Practice]]).

### Code: hub interactions with blocks respected

```lua
--!strict
-- StarterPlayerScripts/SocialSurfaces (LocalScript)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local remotes = ReplicatedStorage:WaitForChild("SocialRemotes")
local requestTrade = remotes:WaitForChild("RequestTrade") :: RemoteEvent
local syncBlocks = remotes:WaitForChild("SyncBlocks") :: RemoteEvent

local function setCore(name: string, value: any): boolean
	for _ = 1, 20 do
		local ok = pcall(StarterGui.SetCore, StarterGui, name, value)
		if ok then
			return true
		end
		task.wait(0.5)
	end
	warn("[Social] SetCore failed:", name)
	return false
end

local function getCore(name: string): any
	for _ = 1, 20 do
		local ok, value = pcall(StarterGui.GetCore, StarterGui, name)
		if ok then
			return value
		end
		task.wait(0.5)
	end
	return nil
end

-- 1. Blocks: send the list once, then every change.
local blocked: { number } = {}
local initial = getCore("GetBlockedUserIds")
if type(initial) == "table" then
	for _, id in initial do
		if typeof(id) == "number" then
			table.insert(blocked, id)
		end
	end
end
syncBlocks:FireServer(blocked)

local function hookBlockEvent(name: string)
	local event = getCore(name)
	if typeof(event) == "Instance" and event:IsA("BindableEvent") then
		event.Event:Connect(function()
			local current = getCore("GetBlockedUserIds")
			if type(current) == "table" then
				syncBlocks:FireServer(current)
			end
		end)
	end
end
hookBlockEvent("PlayerBlockedEvent")
hookBlockEvent("PlayerUnblockedEvent")

-- 2. Avatar Context Menu with a "Trade" option, only while in the hub.
local tradeEvent = Instance.new("BindableEvent")
tradeEvent.Event:Connect(function(target: Player)
	requestTrade:FireServer(target) -- the server re-validates everything
end)

local TRADE_OPTION = { "Trade", tradeEvent }
local inHub = false

local function setHub(on: boolean)
	if on == inHub then
		return
	end
	inHub = on
	if on then
		setCore("AvatarContextMenuEnabled", true)
		setCore("AddAvatarContextMenuOption", TRADE_OPTION)
		setCore("RemoveAvatarContextMenuOption", Enum.AvatarContextMenuOption.Emote)
	else
		setCore("AvatarContextMenuTarget", nil) -- close it if open
		setCore("RemoveAvatarContextMenuOption", TRADE_OPTION)
		setCore("AddAvatarContextMenuOption", Enum.AvatarContextMenuOption.Emote) -- restore, so the next removal is valid
		setCore("AvatarContextMenuEnabled", false)
	end
end

-- Drive setHub from your zone system, for example an attribute the server sets.
local player = Players.LocalPlayer
player:GetAttributeChangedSignal("Zone"):Connect(function()
	setHub(player:GetAttribute("Zone") == "Hub")
end)
setHub(player:GetAttribute("Zone") == "Hub")
```

```lua
--!strict
-- ServerScriptService/SocialServer (Script)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "SocialRemotes"
local requestTrade = Instance.new("RemoteEvent")
requestTrade.Name = "RequestTrade"
requestTrade.Parent = folder
local syncBlocks = Instance.new("RemoteEvent")
syncBlocks.Name = "SyncBlocks"
syncBlocks.Parent = folder
folder.Parent = ReplicatedStorage

local MAX_BLOCKS = 500
local TRADE_COOLDOWN = 5
local MAX_DISTANCE = 20

local blocks: { [Player]: { [number]: boolean } } = {}
local lastRequest: { [Player]: number } = {}

syncBlocks.OnServerEvent:Connect(function(player: Player, list: any)
	if type(list) ~= "table" then
		return
	end
	local set: { [number]: boolean } = {}
	local count = 0
	for _, id in list do
		if typeof(id) == "number" and id > 0 and id % 1 == 0 then
			set[id] = true
			count += 1
			if count >= MAX_BLOCKS then
				break
			end
		end
	end
	blocks[player] = set
end)

local function eitherBlocked(a: Player, b: Player): boolean
	local aSet = blocks[a]
	local bSet = blocks[b]
	return (aSet ~= nil and aSet[b.UserId] == true) or (bSet ~= nil and bSet[a.UserId] == true)
end

local function rootOf(p: Player): BasePart?
	local character = p.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

requestTrade.OnServerEvent:Connect(function(sender: Player, target: any)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target == sender or target.Parent ~= Players then
		return
	end
	local now = os.clock()
	if now - (lastRequest[sender] or 0) < TRADE_COOLDOWN then
		return
	end
	lastRequest[sender] = now
	if sender:GetAttribute("Zone") ~= "Hub" or target:GetAttribute("Zone") ~= "Hub" then
		return -- the menu may have been open when they left the hub
	end
	if eitherBlocked(sender, target) then
		return -- drop silently; do not reveal the block to the sender
	end
	local a, b = rootOf(sender), rootOf(target)
	if not a or not b or (a.Position - b.Position).Magnitude > MAX_DISTANCE then
		return
	end
	-- Hand off to your trade system, which shows the target an accept/decline prompt.
end)

Players.PlayerRemoving:Connect(function(p)
	blocks[p] = nil
	lastRequest[p] = nil
end)
```

Notes:
- The zone is a server-set attribute, so the client cannot fake being in the hub; the server checks it again on every request.
- The block check drops requests **silently**. Telling the sender "you are blocked" leaks information and invites harassment from alternate accounts.
- The retry wrapper retries on any error, including a genuinely invalid call (removing an option that is not there). Keep every add and remove paired, as `setHub` does, so a retry loop only ever covers the startup race.
- Removing `Emote` (Wave) in a trading hub is a judgment call: it reduces clutter but also removes a friendly, harmless interaction.

## 6. Friend presence as a social signal

Visible friends are among the strongest retention signals in social games (rule of thumb, see [[Social Design and Multiplayer Play]]). Cheap ways to show them:
- A small friend icon next to names in your custom player list and above heads for friends in the server (check with `IsFriendsWithAsync` once per pair; remember the cache can be stale after a new friendship, so also listen to `PlayerFriendedEvent` on the client).
- "3 friends online" on the main menu from `GetFriendsOnlineAsync`, with a join or invite button ([[Friend Invites Referrals and Experience Invites]]).
- Friend-only leaderboards from `GetFriendsWhoPlayedAsync`, which avoids looking up hundreds of friends who never played ([[OrderedDataStores and Leaderboards]]).

Never turn friend presence into pressure ("Your friend is waiting for you!" when they are not), and never show friend data to anyone except the player whose friends they are.

## 7. Accessibility and platforms
- Click-on-character targets are small on phones. The ACM carousel helps; a custom `ProximityPrompt` with a clear key and tap target helps more ([[Accessibility]], [[Responsive UI for Phone Tablet Console and PC]]).
- Gamepad players need a list-based way to reach every player action, not just character targeting.
- Theme the ACM to match your UI, but keep text readable: `TextScale` and contrast matter more than a matching font.

## 8. Common mistakes

| Mistake | Effect | Fix |
|---|---|---|
| ACM enabled in a combat game | Menus open mid-fight | Enable only in social zones |
| Trusting the client that the target is nearby or in the zone | Remote trade spam across the map | Server re-checks zone, distance, cooldown |
| Ignoring blocks in custom systems | Harassment through your features | Sync block list, filter both directions |
| Default inspect menu in a uniform-based game | Shows outfits players are not wearing | `InspectPlayerFromHumanoidDescription` |
| Profile configuration fetched on every card open | Throttled, cards fail | Cache per user per server |
| Showing account age, region or other games on cards | Privacy problem | Show only game-earned and player-chosen data |
| Assuming `IsFriendsWithAsync` is live | Stale friend markers | Listen to friended events and refresh |
| `SetCore` without `pcall` at startup | Errors before core scripts register | Retry wrapper |

## 9. Checklist
- [ ] ACM enabled only where clicking players has no other meaning; custom options validated on the server
- [ ] ACM closed and options removed when leaving the zone
- [ ] Inspect menu mode chosen deliberately (profile, current outfit or disabled)
- [ ] Block list synced and applied to every player-to-player feature, silently
- [ ] Profile cards cache thumbnails and profile configuration; player-written text filtered
- [ ] Friend markers refreshed on friendship changes
- [ ] Every player action reachable by touch, mouse and gamepad
- [ ] `SetCore` and `GetCore` calls wrapped with retries

## See also
[[Platform Features Start Here]] · [[Social Design and Multiplayer Play]] · [[Genre Playbook - Roleplay and Social Hangouts]] · [[Emotes and Social Animation]] · [[HumanoidDescription and Outfit Systems]] · [[Player Reports and In-Game Moderation]] · [[Voice Chat and Safety Features]] · [[Trading Systems Without Duplication]] · [[Official Docs - Publishing and Live Ops]]

## Connected notes
<!-- auto-links:start -->
[[Avatars and UGC Start Here]] · Multiplayer Services Start Here · Community Building · [[Experience Notifications and Return Prompts]] · Server Browsers and Server Lists · Age Checks and Safety Features
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Block and Mute Respecting Platform Rules]] · [[Joining Friends Parties and Private Servers]] · [[API Renames and Deprecations 2025-2026]] · [[Community Building]] · [[BadgeService - Engine Reference Card]] · [[Age Checks and Safety Features]]
<!-- related:end -->
