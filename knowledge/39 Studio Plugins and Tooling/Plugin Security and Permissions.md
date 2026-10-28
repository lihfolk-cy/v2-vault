---
tags: [studio, plugins, security, permissions, supply-chain, tooling]
---
# Plugin Security and Permissions

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Treating permission prompts as a sandbox -> Choose plugins carefully; audit
> - Avoid: Approving a domain without asking why -> Approve only documented domains
> - Avoid: Granting script injection to building plugins -> Code tools only
> - Every installed plugin is on the approved list with permissions noted.
> - New plugins are audited in an empty place before installation.
> - Script injection only for code tools; HTTP domains documented.
>
> Read more (17 KB note): ## 4. Auditing a plugin before you trust it · ## 7. Writing a plugin that deserves trust · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

A plugin runs inside Studio with access no game script ever gets: it can read and rewrite every script in every place you open, make web requests, prompt you to open files, and do all of it every time Studio starts, in every project, updated silently by its author. That makes plugins the largest supply-chain risk in Roblox development, larger than free models, because a model only runs inside the game it was inserted into while a plugin touches everything you work on.

[[Creator Store and Toolbox Safety]] covers backdoors in models and gives a place audit script. This note is about plugins specifically, from both sides: as a **user** (what the permission model actually protects, how to audit a plugin, how to run a team policy) and as an **author** (least privilege, secrets, local bridges, and not becoming the vector yourself).

Labels: **Roblox docs (as of October 2026)**, **DevForum announcement**, **measured in the reference project**, **rule of thumb**, **unverified**.

---

## 1. What a plugin can do

Plugin-level APIs that matter for security (Roblox docs, plugin security members):

| Capability | APIs |
|---|---|
| Read every script's source in the open place | `Source`, `ScriptEditorService:GetEditorSource` |
| Rewrite scripts | `Source` assignment, `ScriptEditorService:UpdateSourceAsync` (gated by the script injection permission, see below) |
| Create, move, delete any instance | Normal instance APIs at plugin security |
| Web requests | `HttpService` (gated per domain, see below) |
| Talk to programs on your machine | `HttpService` to `localhost` / `127.0.0.1` (Roblox docs: such software "can pose security risks") |
| Read files the user picks | `StudioService:PromptImportFileAsync` / `PromptImportFilesAsync` returning `File` objects with `GetBinaryContents` |
| Persist data on your disk | `plugin:SetSetting` (JSON per plugin) |
| Know who you are | `StudioService:GetUserId()` |
| Upload the selection | `plugin:SaveSelectedToRoblox()` opens the upload window |
| Run code from strings | `loadstring` is available to plugins (Rule of thumb; it is how loader tools work, see [[Studio Plugins and Local HTTP Bridges]]) |

Plugins also load in every place you open, including group places you have edit access to. A plugin that misbehaves in one personal test place can do the same in your studio's main game.

## 2. The permission model, and its limits

Two user-facing gates exist.

**HTTP permissions.** The first time a plugin requests a domain, Studio may prompt you to allow or deny it, and you can "accept, deny, and revoke these permissions at any time through the Plugin Management window" (Roblox docs, HttpService guide). The original 2020 DevForum announcement adds: every subdomain needs its own approval, the game's **Allow HTTP Requests** setting no longer governs plugin requests, and **local plugins bypass the prompts** (DevForum announcement; whether the last point still holds as of October 2026 is **unverified**).

**Script injection.** Studio asks before a plugin is allowed to modify scripts, and the choice can be changed later in **Manage Plugins** (community reports describe the entry as "Script Injection" under each plugin; exact wording varies between Studio versions). Community reports also say that cloning or inserting an instance that contains a script trips the same permission, not just editing `Source` (**unverified** beyond DevForum threads).

What these gates do **not** protect:

- **Reading.** No permission is needed to read scripts. A plugin that reads your entire codebase and posts it to a domain you approved for "update checks" passes both gates.
- **Approved domains are approved for everything.** You allowed `example.com` for one feature; the plugin can send anything there forever, including after an update.
- **Instance edits.** A plugin with no script permission can still delete, move or reparent anything, change `RemoteEvent` names, set `LoadStringEnabled`-style properties, or insert models.
- **Updates.** Cloud plugins update in place. A permission you granted to version 1 stays granted to version 9. Studio has an internal per-plugin auto-update setting (the engine's `PluginManagementService` exposes it to Studio's own UI; the docs say the service is not intended for creator scripts).
- **Social engineering.** A plugin can show a panel saying "Click Allow to enable cloud sync". The prompt is Studio's, but the reason text is the author's.

Practical conclusion (rule of thumb): treat permissions as **speed bumps that tell you what a plugin intends**, not as a sandbox. The real control is choosing what you install.

## 3. Threat catalogue

| Threat | How it looks | Where it hurts |
|---|---|---|
| Backdoor injection | Plugin inserts a script (often disguised as a common module name) that `require`s a remote asset or opens an admin remote | Live game; persists after the plugin is removed |
| Source exfiltration | Plugin posts script sources or the place file to a web endpoint | Your code and unreleased content leak |
| Destructive payload | Deletes or scrambles instances, sometimes delayed or random | Lost work; may be saved and published before noticed |
| Compromised update | A trusted plugin's author account is taken over or sold; a new version adds malicious code | Every user, at once |
| Typosquat or clone | A copy of a popular plugin, re-uploaded with a payload, with fake reviews | New users searching the store |
| Overreaching telemetry | Legitimate plugin sends usage data, place names, user ids without disclosure | Privacy; group policies |
| Local bridge abuse | A plugin that executes commands from a localhost server, reachable by any local process or a malicious web page | Arbitrary code in your places |

The backdoor case is the most common and the most expensive: the injected script survives uninstalling the plugin, and it ships with your next publish. That is why the place audit in [[Creator Store and Toolbox Safety]] belongs in every release checklist, and why [[Exploits and Anti-Cheat]] treats injected server code as game over.

## 4. Auditing a plugin before you trust it

You can read a plugin's code before running it (rule of thumb procedure):

1. **Do not install it first.** Find the plugin's asset and insert it into an **empty, unpublished place** as a model from the Toolbox (plugins can be inserted as their script hierarchy in most cases; if that fails, install it into a throwaway Studio profile or machine). Turn HTTP off in that place.
2. **Inventory the scripts.** Count scripts and total source size. A "part aligner" with 40,000 lines is a red flag. The Creator Store itself restricts "extremely large scripts" (Roblox docs).
3. **Search for the restricted patterns.** The Creator Store restricts obscuring engine features (custom Lua VMs, `getfenv`, `setfenv`), requiring remote assets (`require(assetId)`, `loadstring`, `InsertService:LoadAsset`, `AssetService:LoadAssetAsync`, `ModuleScript.LinkedSource`), and obfuscated code (Roblox docs). Any of these in a plugin needs an explanation.
4. **Look for writes to scripts and for HTTP.** Every `Source =`, `UpdateSourceAsync`, `Instance.new("Script")`, `Clone()` of a script, and every `HttpService` call. Read each call site: what is sent, to where.
5. **Check strings.** Long strings of numbers or escapes (`\104\116\116\112`), `string.char` sequences, and `string.reverse` on URLs are classic obfuscation.
6. **Check the author and history.** Account age, other assets, a public repository whose code matches the uploaded code, a changelog.

A short Command Bar scanner for step 3 to 5, run against the inserted plugin folder:

```lua
--!strict
-- Scan a folder of scripts for patterns that need a human explanation.
local PATTERNS: { { name: string, pat: string } } = {
	{ name = "require(number)", pat = "require%s*%(%s*%d" },
	{ name = "loadstring", pat = "loadstring" },
	{ name = "getfenv/setfenv", pat = "[gs]etfenv" },
	{ name = "LoadAsset", pat = "LoadAsset" },
	{ name = "LinkedSource", pat = "LinkedSource" },
	{ name = "HTTP call", pat = "HttpService" },
	{ name = "Source write", pat = "%.Source%s*=" },
	{ name = "UpdateSourceAsync", pat = "UpdateSourceAsync" },
	{ name = "escaped bytes", pat = "\\%d%d%d\\%d%d%d\\%d%d%d" },
	{ name = "string.char", pat = "string%.char" },
}

local root = game:GetService("ServerStorage"):FindFirstChild("PluginUnderReview")
assert(root, "put the plugin under ServerStorage.PluginUnderReview first")

local totalChars, scripts = 0, 0
for _, inst in root:GetDescendants() do
	if inst:IsA("LuaSourceContainer") then
		scripts += 1
		local ok, src = pcall(function()
			return (inst :: any).Source :: string
		end)
		if ok and src then
			totalChars += #src
			for _, p in PATTERNS do
				local count = 0
				for _ in string.gmatch(src, p.pat) do
					count += 1
				end
				if count > 0 then
					print(("%s  %s x%d"):format(inst:GetFullName(), p.name, count))
				end
			end
		end
	end
end
print(("%d scripts, %d characters"):format(scripts, totalChars))
```

Matches are questions, not verdicts. An HTTP call that checks a version on the author's site is fine; one that posts `game:GetDescendants()` names is not. Obfuscation in a plugin has no legitimate reason that outweighs the risk; skip those plugins.

## 5. A team plugin policy

For a studio, rules of thumb that cost little:

- **An approved plugin list** with name, author, version checked, permissions granted and why, and an owner who re-reviews on updates. See [[Groups Roles and Permissions for Studios]] for the account side.
- **Script injection only for code tools** (formatters, linters, Rojo). A building or animation plugin asking for it gets questioned.
- **Prefer local, pinned builds of critical plugins** (built from source or saved as a local `.rbxm`) for anyone with edit access to the live game. Local plugins do not auto-update; you upgrade deliberately after reading the diff.
- **Separate profiles** for experimenting with new plugins (a second Studio account or machine) and for working on the production place.
- **A release gate**: run the place audit before every publish, and diff scripts against your repository if you use Rojo ([[Git and Source Control for Roblox]]). An injected script shows up as a file nobody committed.
- **Version history as the backstop.** If an injection is found, [[Version History and Backups]] tells you which publish first contained it, which tells you roughly when the plugin went bad.

If you find a malicious plugin: uninstall it, revoke its permissions, audit every place you opened since it was installed (not just the current one), rotate any secrets that were present in those places' scripts (they should not have been there), and report the asset on its store page.

## 6. Secrets and plugins

Rules for anyone handling API keys around Studio:

- **Never put keys in `SetSetting`.** It is a plain JSON file on disk, readable by anything running as your user.
- **Never put keys in scripts in the place.** Every plugin you run can read them, and so can every collaborator and every future copy of the place.
- **Use the Secrets Store for game-side secrets.** `HttpService:GetSecret` reads secrets configured for the experience (see [[HttpService and External APIs]] and [[Open Cloud APIs]]). Studio supports local secrets for testing through `StudioService.Secrets`, described in the docs as "a JSON string storing the local secrets for the current experience". Whether third-party plugins can read that property is **unverified**; assume a malicious plugin can see what Studio can, and use low-privilege, narrowly scoped keys for local testing.
- **Scope Open Cloud keys** to the minimum operations and resources, with IP restrictions where possible, and expiry dates. A key used by a plugin for asset uploads should not be able to publish places.

## 7. Writing a plugin that deserves trust

If you author plugins, especially public ones, the same threats apply in reverse: you are a target for account takeover, and your plugin's design decides how bad a compromise would be.

**Least privilege by design.**

- If your plugin does not need to edit scripts, never touch `Source` and never clone instances that contain scripts. Users will not be prompted, and you will not be blamed.
- Make every HTTP domain obvious and documented: one domain, stated in the description, with what is sent. Users and reviewers can then see when a request does not match.
- No `loadstring` of remote code, no `require(assetId)`. Beyond the risk, the Creator Store restricts requiring remote assets and `loadstring` in distributed assets (Roblox docs), so a self-updating loader design is both dangerous and against store rules. Ship code inside the plugin; update by publishing a new version ([[Publishing Selling and Updating Plugins]]).
- No obfuscation, even for paid plugins. The store restricts it and users cannot trust it.

**Telemetry.** If you collect anything (usage counts, errors), make it opt-in, show exactly what is sent, never send place names, script contents or user ids without explicit consent, and give a switch to turn it off. Many studios forbid plugins that phone home; a silent telemetry call can get your plugin banned from their approved lists.

**Account security.** Your Roblox account is your plugin's update channel. Two-step verification is required for sellers anyway (Roblox docs); use an authenticator app, a unique password, and do not share the account with collaborators. Rule of thumb: publish from an account used for nothing else risky.

**Local bridges.** Plugins that talk to a companion program on `localhost` are powerful and are the easiest to get wrong ([[Studio Plugins and Local HTTP Bridges]], [[Writing Your Own MCP Server]]):

- Bind the companion to `127.0.0.1`, never `0.0.0.0`.
- Whitelist job kinds; never execute arbitrary code strings received from the bridge.
- Require a per-session token: the companion prints a random token at start, the user pastes it into the plugin once, and every request carries it. This blocks other local processes and web pages using DNS rebinding from driving your plugin.
- Run only in Edit (`RunService:IsEdit()`), one job at a time, each wrapped in a recording.
- Validate every path and size on the companion side if it writes files.

Measured in the reference project: the local receiver that accepted dumps from Studio restricted writes to four fixed subfolders and to names matching `[A-Za-z0-9_.-]`, precisely because anything that can reach the port can write files.

## 8. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Treating permission prompts as a sandbox | Reading and instance edits are ungated | Choose plugins carefully; audit |
| Approving a domain without asking why | Silent exfiltration path for every future version | Approve only documented domains |
| Granting script injection to building plugins | Persistent backdoor risk | Code tools only |
| Auto-updating plugins on the production account | A compromised update hits the live game | Pinned local builds for production editors |
| Keys in scripts or plugin settings | Any plugin or collaborator can read them | Secrets Store, scoped keys |
| Plugin bridge without a token | Any local process can drive Studio | Token, whitelist, localhost bind |
| Shipping obfuscated or self-loading code | Store restriction; lost trust | Plain code, versioned releases |

## 9. Checklist

- [ ] Every installed plugin is on the approved list with permissions noted.
- [ ] New plugins are audited in an empty place before installation.
- [ ] Script injection only for code tools; HTTP domains documented.
- [ ] Production editors use pinned local builds of critical plugins.
- [ ] Place audit and script diff before every publish.
- [ ] No secrets in scripts or plugin settings; keys scoped.
- [ ] As an author: no remote code, no obfuscation, opt-in telemetry, one documented domain.
- [ ] Local bridges: localhost bind, session token, whitelisted jobs, Edit only.
- [ ] Incident plan: uninstall, revoke, audit all recent places, rotate, report.

## See also

- [[Plugin Development Start Here]], [[Publishing Selling and Updating Plugins]], [[Building a Studio Plugin End to End]]
- [[Creator Store and Toolbox Safety]], [[Plugins - Using and Writing]], [[Studio Plugins and Local HTTP Bridges]]
- [[Threat Modeling a Roblox Game]], [[Exploits and Anti-Cheat]], [[HttpService and External APIs]], [[Safety Rules for AI Agents in Studio]]

## Connected notes
<!-- auto-links:start -->
[[Links - Backdoors and malicious assets]] · [[Resource Library - Safety (free models and plugins)]] · [[Command Bar and Studio Scripting]] · [[Clip Archive Server]] · [[Roblox Studio MCP Server]] · [[Animation Asset Permissions and Groups]]
<!-- auto-links:end -->
