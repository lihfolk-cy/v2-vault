---
tags: [testing, qa, debug, admin, security, remotes, type/guide, area/testing, area/security, level/intermediate, area/performance, api/Player]
---
# Gated Tester Commands and Debug Panels

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Checking permission only on the client (hiding the button).
> - Avoid: Allowlisting by username or a client-sent flag.
> - Avoid: One "admin" boolean for everything, so a viewer can mint currency.
> - Server-side role check on every call, by UserId or group rank.
> - Per-command minimum role and test-only flag.
> - Strict argument validation in each command.
>
> Cost: TL;DR ~130 tok · whole note ~2.3k tok. Read more: ## 1. The rules · ## 2. Server command registry · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Testers need powers players must never have: grant currency, teleport to stage 40, spawn a boss, skip a day, force an egg result, show hitboxes. Without them, QA either wastes hours grinding or someone edits live code "just for a test". With them done badly, an exploiter finds the remote and gives themselves a billion coins. This note is how to build a tester command layer and debug panel whose security does not depend on nobody finding it.

Labels as marked. Security reasoning follows [[Server Authority and Validation]] and [[How Exploits Work - The Client Boundary]].

---

## 1. The rules

1. **The server decides who is a tester, every call.** The client may hide or show a panel, but hiding is cosmetic. Exploiters can fire any remote with any arguments.
2. **Allowlist by stable identity.** `UserId` or group rank (`GroupService:GetRolesInGroupAsync(userId, groupId)`; the older `Player:GetRankInGroup` is deprecated). Never by display name or username (both can change) and never by a value the client sends.
3. **Default deny, per command.** Each command names the minimum role. A "viewer" tester can show hitboxes but not grant currency.
4. **Environment gating on top of identity.** Economy-changing commands only work in test places or Studio. In the live game, even a developer should not casually mint currency; if live ops needs grants, they go through an audited tool.
5. **Log every call.** Who, what, arguments, place, time. A tester command that leaves no trace is an exploit waiting for a motive.
6. **Ship the code, not the risk.** It is fine for command code to exist in the live build if rules 1 to 5 hold. It is safer still to keep the dangerous commands in a module that is only inserted into test places.

---

## 2. Server command registry

```lua
--!strict
-- ServerScriptService/QA/TesterCommands
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(game.ServerScriptService.Services.Economy) -- your economy module

local GROUP_ID = 0 -- your group id
local ROLE_BY_RANK = { { rank = 254, role = 3 }, { rank = 200, role = 2 }, { rank = 100, role = 1 } }
local USER_ALLOW: { [number]: number } = {} -- [userId] = role, for testers outside the group
local TEST_PLACES: { [number]: boolean } = {} -- [placeId] = true

-- role 1 = viewer, 2 = tester, 3 = lead
local function roleOf(player: Player): number
	local explicit = USER_ALLOW[player.UserId]
	if explicit then return explicit end
	local ok, rank = pcall(function() -- GetRankInGroup(Async) is deprecated
		local info = GroupService:GetRolesInGroupAsync(player.UserId, GROUP_ID)
		return if info.IsMember and info.Roles[1] then info.Roles[1].Rank else 0
	end)
	if not ok then return 0 end
	for _, r in ROLE_BY_RANK do
		if rank >= r.rank then return r.role end
	end
	return 0
end

local function isTestEnvironment(): boolean
	return RunService:IsStudio() or TEST_PLACES[game.PlaceId] == true
end

type Command = { role: number, testOnly: boolean, run: (Player, { any }) -> string }
local commands: { [string]: Command } = {}

commands.give = {
	role = 2, testOnly = true,
	run = function(player, args)
		local amount = tonumber(args[1])
		if not amount or amount ~= amount or amount <= 0 or amount > 1e9 then return "bad amount" end
		Economy.grant(player, math.floor(amount), "qa_give") -- your economy module; logs the source
		return "ok"
	end,
}

commands.hitboxes = {
	role = 1, testOnly = false,
	run = function(player, args)
		player:SetAttribute("QA_Hitboxes", args[1] == "on")
		return "ok"
	end,
}

local Remote = ReplicatedStorage.Remotes.TesterCommand :: RemoteFunction
local roleCache: { [Player]: number } = {}

Remote.OnServerInvoke = function(player: Player, name: any, args: any): string
	if type(name) ~= "string" or type(args) ~= "table" or #args > 8 then return "denied" end
	local cmd = commands[name]
	if not cmd then return "denied" end
	local role = roleCache[player] or roleOf(player)
	roleCache[player] = role
	if role < cmd.role or (cmd.testOnly and not isTestEnvironment()) then
		warn(("[QA] denied %s %d %s"):format(player.Name, player.UserId, name))
		return "denied"
	end
	local ok, result = pcall(cmd.run, player, args)
	print(("[QA] %d ran %s (%s) -> %s"):format(player.UserId, name, table.concat(args, " "), tostring(result)))
	return if ok then result else "error"
end

Players.PlayerRemoving:Connect(function(p) roleCache[p] = nil end)
```

Notes:

- The same reply ("denied") for unknown commands and missing permission, so probing reveals nothing.
- `GetRolesInGroupAsync` is a web call; wrap it in `pcall` and cache per session.
- Arguments are validated inside each command as strictly as any player remote. A tester account can be compromised.
- `Economy.grant` records a source tag, so QA-minted currency is visible in audits ([[Economy Exploits - Dupes Races and Purchase Abuse]]).
- `table.concat` on args assumes strings and numbers; coerce with `tostring` in real code.

---

## 3. Chat commands

You can drive the same registry from chat with `TextChatCommand` instances (Roblox docs: [TextChatCommand](https://create.roblox.com/docs/reference/engine/classes/TextChatCommand)), handling `Triggered` on the server and calling the same permission check. Keep the registry as the single entry point: chat, panel and console all end in `commands[name]` behind `roleOf`.

---

## 4. The debug panel

A client ScreenGui that only builds itself after the server confirms a role:

- The server sets an attribute such as `QA_Role` on the player after checking. The client reads it to decide whether to create the panel. An exploiter who sets it locally gets a panel whose buttons all return "denied".
- Panel sections: **Teleport** (stage list), **Economy** (give, reset), **Time** ([[Testing Time-Based Features with a Controllable Clock]]), **Spawns** (boss, wave), **Visuals** (hitboxes, pathfinding lines, server position ghosts), **Data** (print my profile, wipe my test profile), **Info** (PlaceVersion, JobId, ping, FPS).
- Visual debug toggles are read-only and safe to allow more widely; data and economy toggles are not.
- Make it obvious: a bright border and "QA" label, so screenshots from testers are never mistaken for player footage, and a forgotten panel in a trailer is noticed.

---

## 5. Keeping commands out of the wrong place

- **Test-only modules.** Put economy and data commands in a module that your build inserts only for test places (Rojo project file per environment, see [[Code Pipeline - Rojo Git and CI]]). The live build then does not contain them at all.
- **Release check.** Add a grep to your release checklist: no `USER_ALLOW` entries for people who left, no test place ids pointing at the live place, no commands with `testOnly = false` that change data.
- **Review allowlists** when team members leave ([[Groups Roles and Permissions for Studios]]).
- **Kill switch.** A live config flag that disables all tester commands instantly ([[Feature Flags and Staged Rollouts]]).

---

## Common mistakes

- Checking permission only on the client (hiding the button).
- Allowlisting by username or a client-sent flag.
- One "admin" boolean for everything, so a viewer can mint currency.
- Economy commands that work in the live place.
- No log of who ran what.
- Commands that skip the validation player remotes get.

## Checklist

- [ ] Server-side role check on every call, by UserId or group rank.
- [ ] Per-command minimum role and test-only flag.
- [ ] Strict argument validation in each command.
- [ ] Every call logged; QA currency tagged with a source.
- [ ] Dangerous commands absent from the live build or hard-gated by place id.
- [ ] Allowlist reviewed at each release; kill switch exists.

## See also

- [[Server Authority and Validation]], [[How Exploits Work - The Client Boundary]], [[Logging Bans and Appeals]]
- [[Testing Time-Based Features with a Controllable Clock]], [[In-Game Bug Report Button with Automatic Context]]
- [[Debugging Live Servers]], [[Developer Console and Stats]]

## Connected notes

[[Groups Roles and Permissions for Studios]] · Feature Flags and Staged Rollouts · [[Genre QA Passes - Test Checklists per Game Type]] · [[Multi-Client and Device Playtesting Protocols]]

<!-- related:start -->
## Related
[[Admin Commands Done Safely - Permissions and Audit Logs]] · [[Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins]] · [[Automated Luau Checks - LihFolk Hook and Audit]] · [[Multi-Client and Live Testing]] · [[QA Checklists Before Release]] · [[Save Migration Tests - Fixture Saves and Golden Files]] · [[Load and Soak Testing Servers - Long Sessions and Many Clients]] · [[StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs]]
<!-- related:end -->
