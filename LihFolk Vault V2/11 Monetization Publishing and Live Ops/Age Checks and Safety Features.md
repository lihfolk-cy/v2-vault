---
tags: [safety, age-checks, chat, textchatservice, filtering, compliance, luau, type/guide, area/monetization, level/intermediate, api/TextChatService, area/scripting]
---
# Age Checks and Safety Features

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: A custom chat that sends messages through `RemoteEvent`s (bypasses filtering and age rules).
> - Avoid: Displaying unfiltered player names for pets or signs.
> - Avoid: Gameplay that requires typing to teammates.
> - All player-to-player text through `TextChatService` channels
> - Private channels only for users allowed by `CanUsersDirectChatAsync`
> - All user-authored text filtered server-side for the right audience
>
> Cost: TL;DR ~150 tok · whole note ~3.4k tok. Read more: ## 2. Age groups and chat · ## 3. Code: chat and text the compliant way · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

Between January and July 2026 Roblox moved from self-declared ages to **age checks** (facial age estimation or ID) as the basis for chat, social links, content access, publishing and collaboration. Players are split into **Roblox Kids (5 to 8)**, **Roblox Select (9 to 15)** and **Roblox (16+)** audiences. For developers this changes who can play your game, who can talk to whom inside it, what you may show, and what your own team needs to publish. This note collects what changed, what your code must do (chat through `TextChatService`, text filtering, direct-chat eligibility), and how to design for mixed-age servers. Facts verified against Creator Hub pages and official announcements **as of October 2026**; this area is still moving, so re-check dates and thresholds.

---

## 1. Timeline (Announcements and Docs)

| Date (2026) | Change |
|---|---|
| Jan 7 to mid Jan | **Age check required to chat**, rolled out globally. All text-based player-to-player communication must go through `TextChatService`. External social links can no longer be shared in-game; `PolicyService`'s external link reference is sunset (returns an empty list) |
| Feb 23 | Social media links on game pages, communities and profiles visible only to age-checked 13+ |
| March | Age checks required for Studio **Team Create** |
| April 30 | Roblox Plus launches; Robux transfers for under-18s or users without an age check need parent or caregiver approval each time |
| May 19 | Kids and Select accounts and new publishing requirements start rolling out (New Zealand, Netherlands, Australia, Indonesia) |
| June 16 | Kids and Select **global launch** |
| June 30 | Social media links visible only to age-checked **16+** |
| July 6 / 16 | Kids and Select eligibility thresholds relaxed (Announcement) |

---

## 2. Age groups and chat

### How players are grouped
Players complete an age check, typically facial age estimation; ID verification or parental controls can correct an estimate. News coverage lists chat age groups as under 9, 9 to 12, 13 to 15, 16 to 17, 18 to 20 and 21+ (secondary sources; the developer docs do not publish the bands as an API).

### Who can chat with whom (Announcement)
- Age-based chat is designed to stop **children under 16 from communicating with adults**.
- By default each group can chat with the groups **directly above and below** it (for example 9 to 12 with under 9 and 13 to 15).
- **Parental consent** is required for under-9s to access chat. Kids accounts (5 to 8) have communication disabled by default (Announcement).
- **Trusted Connections:** age-checked users 13+ can chat more freely with people they know beyond their immediate age group.

### What this means in your game
- A player's chat does **not appear** to players they are not allowed to chat with. Roblox said it is investigating in-experience indicators; today there may be no visible sign (Announcement).
- **Gameplay must not depend on chat.** Any coordination your game needs (trading, team tactics, party forming) needs non-chat UI: pings, emotes, quick-chat wheels with fixed phrases, trade windows with item slots.
- Use `TextChannel:DisplaySystemMessage` for important system messages that every player must see (Announcement).
- If chat is central to your game, increase the **Text Chat matchmaking signal** weight with Custom Matchmaking so players land in servers where they can talk (Announcement).

### No age API (as of October 2026)
There is no documented API that returns a player's age group. Developers have asked for one (DevForum feature request). Community workarounds such as inferring age from `PolicyService` ad eligibility are unofficial and unreliable. Design so you do not need to know the age: let the platform enforce chat, use `PolicyService` for the monetization rules it documents, and gate mature content by your maturity label instead of in-game checks.

---

## 3. Code: chat and text the compliant way

### All player text through `TextChatService`
Custom chat UIs are fine; custom chat *transport* is not. Send and receive through `TextChannel`s so filtering and age rules apply. Messages a recipient may not see are simply not delivered to them.

### Direct (whisper/party) channels
`TextChatService:CanUsersDirectChatAsync(requesterUserId, userIds)` returns the subset of users the requester can directly chat with (ignoring users not in the server; empty if none) (Docs). Create private channels only for allowed pairs.

```lua
--!strict
-- Server: create a party channel containing only players allowed to chat with the leader.
local TextChatService = game:GetService("TextChatService")

local function createPartyChannel(leader: Player, members: { Player }): TextChannel?
	local ids = {}
	for _, p in members do
		if p ~= leader then
			table.insert(ids, p.UserId)
		end
	end
	local ok, allowed = pcall(function()
		return TextChatService:CanUsersDirectChatAsync(leader.UserId, ids)
	end)
	if not ok or #allowed == 0 then
		return nil -- fall back to non-chat party UI (pings, quick phrases)
	end
	local channel = Instance.new("TextChannel")
	channel.Name = `Party_{leader.UserId}`
	channel.Parent = TextChatService
	channel:AddUserAsync(leader.UserId)
	local allowedSet = {}
	for _, id in allowed do
		allowedSet[id] = true
	end
	for _, p in members do
		if allowedSet[p.UserId] then
			channel:AddUserAsync(p.UserId)
		end
	end
	return channel
end
```

Destroy the channel when the party ends. Re-check when members join later.

### Filtering non-chat text
Anything a player types that other players see (pet names, sign text, guild names, trade notes) must be filtered with `TextService` on the server before display.

```lua
--!strict
-- Server: filter text one player wrote for everyone in the server to see.
local TextService = game:GetService("TextService")

local function filterForBroadcast(author: Player, text: string): string?
	if #text == 0 or #text > 50 then
		return nil
	end
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, author.UserId, Enum.TextFilterContext.PublicChat)
	end)
	if not ok then
		return nil -- never show unfiltered text on failure
	end
	local ok2, filtered = pcall(function()
		return result:GetNonChatStringForBroadcastAsync()
	end)
	return if ok2 then filtered else nil
end
```

Use `GetNonChatStringForUserAsync(userId)` when text is shown to one specific user. Store the **raw** text if you must, but always filter at display time for the viewer, because filter rules and viewers change. Never filter on the client. See [[Text Fonts and Rich Text]] for display and [[Player Privacy and Data Deletion]] for storing player-authored text.

### Voice
Voice is controlled by the platform's eligibility (age checks, settings). If your game uses spatial voice, design so non-voice players are not disadvantaged. See [[The Audio API - Players Emitters Wires and Effects]].

---

## 4. Content access by audience

The maturity label decides who can join and who sees the game in recommendations ([[Roblox Policies Ratings and Compliance]]):
- **Kids (5 to 8):** Minimal or Mild games that passed the Kids and Select evaluation.
- **Select (9 to 15):** Minimal, Mild or Moderate (9+) games that passed the evaluation.
- **Roblox (16+):** everything except Restricted; Content May Vary games reach age-checked 16+.
- **Restricted:** age-verified 18+ only; servers remove anyone else when the label applies.

Some features have age floors of their own:
- **Rewarded video:** the publishing creator must be 13+ (Docs); ads are not shown to every viewer, which is why you check availability per player.
- **Experience notifications:** recipients must be 13+; under-13s cannot be prompted to opt in (Docs).
- **Social links:** visible only to age-checked 16+ (Announcement).
- **Robux transfers:** under-18s or users without an age check need parent approval per transfer (Announcement).
- **Purchases:** parental controls can limit spending; your store must handle a prompt that closes without a purchase gracefully.

Design for the youngest audience your label allows. A Mild game reaching Kids accounts has players who read slowly or not at all: icon-first UI, voice-free communication, short sessions.

---

## 5. Your team and tools

- **Publishing** requires an age-checked creator (2+ day old account; facial estimation or ID), and for all-ages releases also 2-Step Verification and age verification (Docs). See [[Publishing an Experience]].
- **Team Create** requires age checks (Announcement, March 2026). When a game becomes Restricted, collaborators not verified 18+ are removed from active sessions (Docs).
- **Rewarded ads** need the publisher's verified ID and 2SV (Docs).
- Plan for a team member's verification lapsing or not being possible (minors on the team): who can publish, who owns the group, who can configure revenue.

---

## 6. Safety features you should build anyway

Platform rules are the floor. Good practice (rule of thumb):
- **Block and mute** respected in your own systems: if a player has blocked someone, do not pair them in trades or parties. Blocked-user information has historically been readable on the client through `StarterGui:GetCore("GetBlockedUserIds")` (unverified for 2026; check the current docs before relying on it).
- **Report flows:** link to the platform report menu; do not build your own moderation that collects personal data.
- **No private spaces without thought:** "private rooms" change your social hangout rating (16+ without private spaces, 18+ verified with them, per the questionnaire).
- **Trading safety:** confirmation screens showing both sides, a short lock delay before accept, no free-text in trades, value warnings for lopsided trades.
- **Anti-scam copy:** in trading games, tell players staff never ask for items or passwords.
- **Admin tools** restricted to server-checked group ranks or user ids, with logs ([[Exploits and Anti-Cheat]]).
- **Location of social prompts:** the reference project's community prompts never appeared during onboarding or combat and were capped per session. Prompts to join groups or like the game must not pressure young players.

---

## 7. Designing for mixed-age servers

A Moderate game can have 10-year-olds and adults in the same server who cannot see each other's chat. Rule-of-thumb design patterns:

| Need | Chat-free solution |
|---|---|
| "Follow me" / "over here" | World pings placed with a key or tap, visible to teammates |
| Greetings and thanks | Emotes and a fixed quick-phrase wheel ("Thanks!", "Nice!", "Help!") sent as system-style messages your server composes from an id, not free text |
| Trading | A trade window with item slots, both sides visible, a confirm countdown; no notes field |
| Forming a party | Invite buttons on player cards, party UI with ready checks |
| Asking for help | A help button that shows a contextual tip, not a chat request |
| Celebrating | Server feed of achievements (rare drops, boss kills) composed by the server |

Quick phrases are safe because the server builds them from a fixed table; the client sends only an index, which the server validates ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]). Localise the table ([[Localization]]).

These patterns also help players on gamepads and phones, who type slowly, and players who do not share a language. Compliance and accessibility point the same way here ([[Accessibility]], [[Gamepad and Console UX]]).

### Matchmaking considerations
If your game is cooperative and chat matters, the Text Chat matchmaking signal helps put players who can talk together in the same server (Announcement). If your game is competitive, avoid relying on chat for fairness; a team that can talk versus one that cannot is not balanced.

---

## 8. Common mistakes
- A custom chat that sends messages through `RemoteEvent`s (bypasses filtering and age rules).
- Displaying unfiltered player names for pets or signs.
- Gameplay that requires typing to teammates.
- Assuming you can read a player's age.
- External handles or links in game text.
- Building private rooms without updating the questionnaire.
- A publisher account without an age check on update day.

## 9. Checklist
- [ ] All player-to-player text through `TextChatService` channels
- [ ] Private channels only for users allowed by `CanUsersDirectChatAsync`
- [ ] All user-authored text filtered server-side for the right audience
- [ ] Core gameplay playable without chat or voice
- [ ] System messages via `DisplaySystemMessage`
- [ ] No external links or handles in-game
- [ ] Maturity label matches features (private spaces, user creation, violence)
- [ ] Publishing and Team Create accounts age-checked; 2SV on

## See also
[[Roblox Policies Ratings and Compliance]] · [[Publishing an Experience]] · [[Community Building]] · [[Accessibility]] · [[Social Design and Multiplayer Play]] · [[Player Privacy and Data Deletion]] · [[Server Authority and Validation]] · [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Text Chat Customization with TextChatService]] · Community and Moderation Start Here · Discord Servers for Roblox Games · Voice Chat and Safety Features · Links - Chat and text filtering · Roblox Policies on AI-Generated Content
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Policy and Age Rules 2026]] · [[Voice Chat and Safety Features]] · [[Paid Random Items and Odds Disclosure in Practice]] · [[Monetization Overview]] · [[Ads and Rewarded Video]] · [[Discovery and the Algorithm]] · [[Live Ops Events and Updates]]
<!-- related:end -->
