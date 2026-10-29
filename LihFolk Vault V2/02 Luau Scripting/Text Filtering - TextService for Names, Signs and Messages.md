---
tags: [text-filtering, moderation, safety, textservice, signs, pet-names, type/guide, area/scripting, level/intermediate, api/TextService, api/TextFilterResult, api/TextChatService]
---
# Text Filtering - TextService for Names, Signs and Messages

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: showing the raw string when the filter call errors.
> - Avoid: filtering on the client or trusting text the client says it already filtered.
> - Avoid: using `GetNonChatStringForUserAsync` for text the whole server sees.
> - Every player-written string another player can see goes through `TextService:FilterStringAsync` on the server.
> - Public text uses `Enum.TextFilterContext.PublicChat` and `GetNonChatStringForBroadcastAsync`.
> - Single-viewer text uses `GetNonChatStringForUserAsync(viewerUserId)` and is shown only to that viewer.
>
> Cost: TL;DR ~180 tok · whole note ~3.4k tok. Read more: ## 2. The API: one filter call, then a "get" per audience · ## 4. A server handler for a sign (RemoteEvent, validation, cooldown) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Any text a player types that another player can see must go through Roblox's filter before it is shown. Chat sent through `TextChatService` is filtered for you; everything else (pet names, sign text, guild or clan names, plot titles, notes, mail, custom nametags, board posts) is your job, and Roblox can take a game down until filtering is added. This note covers the server-side `TextService` path: when it is required, which `TextFilterResult` method to call, what to store, and how to fail safely. Chat itself is covered in [[Text Chat Customization with TextChatService]] and [[TextChatService - Engine Reference Card]]; reporting and moderation flows in [[Player Reports and In-Game Moderation]]; the remote side in [[RemoteEvents RemoteFunctions and Unreliable Remotes]] and [[Server Authority and Validation]].

Source labels: **Roblox docs** (create.roblox.com and the creator-docs reference YAML, checked 2026-10-29), **DevForum** (staff or community posts, not official docs), **Rule of thumb** (experience, not a documented limit). Code is strict Luau, **compiled, not run in a live server**.

---

## 1. When filtering is required

Roblox docs: you are responsible for filtering any displayed text you do not fully control. The text filtering guide lists the cases: text typed into a `TextBox` or an on-screen or in-world keyboard, words generated from random characters, text fetched from an external web server, and text stored in data stores (such as pet names) that should be filtered when read back.

| Text | Who sees it | Filter? |
|---|---|---|
| Chat through `TextChatService` | Others | Automatic. Do not filter again |
| Pet name, plot title, house name | Others, or only the owner | Yes |
| Sign, board, mail, guild name, bounty note | Everyone on the server | Yes |
| Text the player types and only they ever see (a search box, a draft) | Only the author | Not required, but never show it to anyone else |
| Text you wrote (item names, quest text) | Everyone | No |
| Random words you generate, or text from your web API | Everyone | Yes (needs a `fromUserId` to filter as; see section 6) |

Rule of thumb: if the string started its life in a player's keyboard, or you cannot list every possible value in advance, filter it.

## 2. The API: one filter call, then a "get" per audience

`TextService:FilterStringAsync(stringToFilter, fromUserId, textContext)` (Roblox docs):

- Runs on the server. It always yields (it makes a web call) and can throw, so wrap it in `pcall`.
- Call it **once per submission**. If it fails, do not display the text to anyone. Do not retry in a loop: the docs say it already retries internally.
- It currently throws if `fromUserId` is not in the current server (confirmed as intended by Roblox staff on the DevForum, October 2026). You can only filter text for authors who are present.
- `textContext` is an `Enum.TextFilterContext` with two items: `PublicChat` (visible to everyone, strictest) and `PrivateChat` (one-to-one or small group; this is the default). The enum page says it sets strictness; the parameter page says it only helps improve the filter. Treat that as unsettled and pass `Enum.TextFilterContext.PublicChat` for anything public.

It returns a `TextFilterResult`. You then ask that object for the string in the form the audience needs:

| Method | Use for | Notes |
|---|---|---|
| `GetNonChatStringForBroadcastAsync()` | Text everyone on the server can see: signs, boards, guild names, a pet name shown over its head | Strictest. Docs: stays valid for all users "even after the author has left" |
| `GetNonChatStringForUserAsync(toUserId)` | Text one specific viewer sees: the pet name in that viewer's own inventory | Filtered for that viewer's age and settings. Show it only to `toUserId` |
| `GetChatForUserAsync(toUserId)` | Nothing | **Deprecated and returns an empty string.** Player-to-player chat must go through `TextChatService` |

All three yield and should be in `pcall` too. Filtered text comes back with blocked words replaced by `#` characters, which is why "my sign is all hashtags" is a filter result, not a bug.

Rule of thumb: if you are unsure who will see it, use `GetNonChatStringForBroadcastAsync`. Showing the stricter result to one person is safe; showing a per-user result to everyone is not.

## 3. Store raw, filter on show

The docs' data store example is the pattern to copy: save what the player typed, and filter when the text is read back for display.

- **Store the raw string** (with the author's `UserId`) in the data store. Filter rules change over time and differ per viewer, so a stored filtered string goes stale and may be wrong for the next viewer.
- **Filter when it is loaded or submitted**, while the author is in the server, and **cache the result for the session** (an attribute or a field on the server object). Re-filtering every frame or every time a player walks past the sign wastes calls and adds latency.
- **Per-viewer text** (`GetNonChatStringForUserAsync`): cache per `(author, viewer)` pair and drop the entry when either leaves.
- **Author not in the server** (a sign from yesterday, a gifted pet from an offline friend): you cannot call `FilterStringAsync` for them. Show a placeholder ("Sign", the species name, "Guild") until the author is present again. Never fall back to the raw text.
- **Edits**: a changed name is a new submission; filter it again.

## 4. A server handler for a sign (RemoteEvent, validation, cooldown)

```lua
--!strict
-- ServerScriptService/SignService.server.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local setSignText = ReplicatedStorage:WaitForChild("SetSignText") :: RemoteEvent

local MAX_CHARS = 60
local COOLDOWN = 10 -- seconds between submissions per player (rule of thumb)
local PLACEHOLDER = "..."

local lastSubmit: { [Player]: number } = {}

local function filterForEveryone(text: string, fromUserId: number): string?
	local okFilter, result = pcall(function()
		return TextService:FilterStringAsync(text, fromUserId, Enum.TextFilterContext.PublicChat)
	end)
	if not okFilter then
		warn("FilterStringAsync failed:", result)
		return nil
	end
	local okGet, filtered = pcall(function()
		return (result :: TextFilterResult):GetNonChatStringForBroadcastAsync()
	end)
	if not okGet then
		warn("GetNonChatStringForBroadcastAsync failed:", filtered)
		return nil
	end
	return filtered :: string
end

setSignText.OnServerEvent:Connect(function(player: Player, sign: unknown, text: unknown)
	-- 1. Type checks: never trust the client's arguments.
	if typeof(sign) ~= "Instance" or typeof(text) ~= "string" then
		return
	end
	local signPart = sign :: Instance
	if not signPart:IsA("BasePart") or not signPart:HasTag("Sign") then
		return
	end
	if signPart:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end

	-- 2. Length cap in characters; reject invalid UTF-8.
	local raw = text :: string
	local length = utf8.len(raw)
	if length == nil or length == 0 or length > MAX_CHARS then
		return
	end

	-- 3. Cooldown before the yielding call.
	local now = os.clock()
	local last = lastSubmit[player]
	if last and now - last < COOLDOWN then
		return
	end
	lastSubmit[player] = now

	-- 4. Filter once, show the result or the placeholder, never the raw text.
	local filtered = filterForEveryone(raw, player.UserId)
	if signPart.Parent == nil or player.Parent == nil then
		return -- sign or player gone while we yielded
	end
	signPart:SetAttribute("RawText", raw) -- server-only bookkeeping; save this, not the filtered string
	signPart:SetAttribute("DisplayText", filtered or PLACEHOLDER)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastSubmit[player] = nil
end)
```

Notes on the example:

- `RawText` as an attribute replicates to clients. In a real game keep it in a server-side table keyed by the sign instead, so exploiters cannot read unfiltered text from the attribute. It is shown inline here only to keep the example short.
- A `SurfaceGui` `TextLabel` on the sign reads `DisplayText`. Clients never set it.
- Use a `RemoteFunction` instead if the client must show "Name rejected" or "Try again later". Return a status code, never the raw text.

## 5. Per-viewer text: pet names in someone else's inventory

When a viewer opens another player's inventory or trade window, the server filters the owner's raw pet name for that viewer:

```lua
--!strict
local TextService = game:GetService("TextService")

local function petNameForViewer(rawName: string, ownerUserId: number, viewerUserId: number): string?
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(rawName, ownerUserId, Enum.TextFilterContext.PrivateChat)
	end)
	if not ok then
		return nil
	end
	local okGet, text = pcall(function()
		return (result :: TextFilterResult):GetNonChatStringForUserAsync(viewerUserId)
	end)
	return if okGet then text :: string else nil
end

return petNameForViewer
```

The owner seeing their own pet name in their own inventory is the "only the author sees it" row in section 1; once the name floats over the pet in the world, it is public and needs the broadcast form.

## 6. Limits, chat, Studio, and failure

- **Rate limits.** The docs list no number. A Roblox staff reply on the DevForum (2016) gave about 1,000 web requests per minute per server, and players report HTTP 429 and 503 errors when they exceed it or send very long strings. Unverified: a per-player limit of one non-chat submission per minute; no official source found as of 2026-10-29. A per-player cooldown and a length cap keep you well clear either way.
- **Do not filter while typing.** The docs warn against filtering per character in a `TextBox`: filter only when the player submits.
- **Chat.** `TextChatService` filters player chat automatically. Do not build chat on `RemoteEvent`s: a custom transport skips filtering, age-based chat rules, muting and reporting, and breaks the rules (see [[Text Chat Customization with TextChatService]]).
- **Generated or external text.** It needs a `fromUserId` that is in the server, so filter it as the player who will see it or caused it, and use the broadcast form if others can see it.
- **Failure.** If any call throws, show nothing or a neutral placeholder and log it. Never fall back to the raw string, and do not loop retrying.
- **Studio.** Unverified: community reports say filtering can behave differently in Studio test sessions (text passes through unchanged or is filtered more loosely). Test the real behaviour in a published private server before you trust it.

## Common mistakes

- Avoid: showing the raw string when the filter call errors. Symptom: an outage or rate limit leaks unfiltered names and signs to every player.
- Avoid: filtering on the client or trusting text the client says it already filtered. Symptom: exploiters display anything they like; `FilterStringAsync` cannot run on the client anyway.
- Avoid: using `GetNonChatStringForUserAsync` for text the whole server sees. Symptom: text approved for one viewer's age group is shown to younger players.
- Avoid: calling `GetChatForUserAsync`. Symptom: every message comes back as an empty string, because the method is deprecated.
- Avoid: storing only the filtered string in the data store. Symptom: names stay as hashtags forever, even after filter improvements, and per-viewer results are wrong for other viewers.
- Avoid: filtering on every render or every proximity check. Symptom: HTTP 429 or 503 errors and signs that flicker between text and placeholder; cache per session.
- Avoid: filtering text for an author who has left. Symptom: `FilterStringAsync` throws, because the author must be in the server; show a placeholder instead.
- Avoid: no length cap or cooldown on the submit remote. Symptom: one player spams long strings and uses up the server's filter budget for everyone.
- Avoid: building a custom chat or DM feature on remotes. Symptom: the game breaks Roblox's chat rules and can be moderated; use `TextChatService`.

## Checklist

- [ ] Every player-written string another player can see goes through `TextService:FilterStringAsync` on the server.
- [ ] Public text uses `Enum.TextFilterContext.PublicChat` and `GetNonChatStringForBroadcastAsync`.
- [ ] Single-viewer text uses `GetNonChatStringForUserAsync(viewerUserId)` and is shown only to that viewer.
- [ ] Each yielding call is in `pcall`; on error the UI shows a placeholder, never raw text.
- [ ] Remote handler type-checks arguments, checks ownership, caps length with `utf8.len`, and has a per-player cooldown.
- [ ] Raw text is saved; filtered text is cached for the session only, and raw text is not replicated to clients.
- [ ] Text from an author who is not in the server shows a placeholder.
- [ ] Chat goes through `TextChatService`, not remotes.
- [ ] Behaviour checked in a published server, not only in Studio.

<!-- related:start -->
## Related
[[Strings Patterns and Formatting]] · [[Error Handling and Retries]] · [[Error Handling - pcall xpcall and Promise Patterns]] · [[Module Scripts and Requiring]] · [[Luau Type System and Strict Mode]] · [[Tables Metatables and OOP]]
<!-- related:end -->
