---
tags: [studio, toolbox, creator-store, security, backdoors, assets]
---
# Creator Store and Toolbox Safety

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Inserting directly into the live place -> Scratch place first
> - Avoid: Trusting a model because it has many likes -> Read the scripts
> - Avoid: Deleting the model and assuming it is gone -> Audit the whole place
> - Insert unknown assets only into a scratch place with scripts disabled.
> - Read every script in an inserted asset.
> - Run the audit script before every release and after installing a new plugin.
>
> Read more (13 KB note): ## 6. An audit script · ## 7. Licensing, ownership and permissions · ## 9. Common mistakes · ## 10. Checklist
<!-- tldr:end -->

The Creator Store holds millions of free and paid models, meshes, images, audio, plugins, fonts and videos, browsable on the web and inside Studio's Toolbox. Used carefully it saves weeks. Used carelessly it is the main way malicious code enters Roblox games: a free model with a hidden script that `require`s a remote module, grants an attacker admin, or injects obfuscated code into your other scripts. This note covers how the store works (as of October 2026), the store's own rules about unsafe code, how to inspect and quarantine assets, how backdoors look in practice, and licensing and permission traps. It ends with a command-bar audit script you can run on any place.

Labels: **Docs**, **Measured**, **Rule of thumb**.

---

## 1. The store and the Toolbox

The Toolbox (Window menu or Home tab) has four sections (Docs):

| Section | Contents |
|---|---|
| **Creator Store** | Public assets by Roblox and the community |
| **Inventory** | Assets you or your groups published, or took from the store; includes packages, animations |
| **Recent** | Recently used assets |
| **Creations** | Assets you or your groups published; configurable from Studio via **Edit Asset** |

Search with the category selector and **advanced filter** (verified creators, a specific creator, plugin price, audio length). Hover a result and click the magnifying glass for the details page: creator, type, created and updated dates, description, **triangle, vertex and script counts**, ratings and reviews, and a **Try in Roblox** demo when available (Docs).

Clicking a model, mesh, decal, video or audio asset inserts it. Plugins and fonts use **Install** (Docs).

The Toolbox runs in a web view; if it misbehaves on Windows, reinstall WebView2 or delete `%LOCALAPPDATA%\Roblox\RobloxStudio\WebView2` with Studio closed (Docs).

## 2. What the store forbids

The Creator Store restricts these practices in distributed assets (Docs):
- **Obscuring engine features in scripts**: Lua VMs, `getfenv()`, `setfenv()`.
- **Requiring remote assets**: `require(assetId)`, `loadstring()`, `InsertService:LoadAsset()`, `AssetService:LoadAssetAsync()`, `ModuleScript.LinkedSource`. The docs explain why: a useful-looking asset can load "another virus asset at runtime".
- **Obfuscated code**.
- **Extremely large scripts** with repeated lines or unused strings.

Those rules are enforced by moderation after the fact, not by a compiler. Assume any asset may still contain them, and treat the list as your scan list.

## 3. How backdoors look

Common patterns in malicious free models (Rule of thumb, widely reported in the community):

| Pattern | Example shape | Why it works |
|---|---|---|
| Remote require | `require(1234567890)` or an id built from arithmetic or string reversal | Loads code the author can change at any time |
| Hidden script | A `Script` named `Weld`, `Light`, `ThumbnailCamera` deep in a mesh model | Nobody opens a "Weld" |
| Whitespace push | Hundreds of spaces before the payload on one line | Code is off-screen in the editor |
| Environment tricks | `getfenv`, `setfenv`, `string.char` sequences, `\x` escapes | Hides names from search |
| Late activation | `task.wait(math.random(300, 900))` before acting | Evades quick tests |
| Script injection via plugins | A plugin that edits your scripts on load | Persists after the model is deleted |
| Admin grants | Gives a specific user id commands or a GUI | Takeover of live servers |

Server scripts are the dangerous ones: they run with full server authority. A LocalScript in a model can still spam or leak, but cannot touch other players' data directly (see [[Client-Server Model]] and [[Exploits and Anti-Cheat]]).

The place-size docs add a real-world tell: obfuscated or unclear text in model scripts "does not compress well and might even be a malicious backdoor"; delete the model and report it (Docs).

## 4. Safe insertion procedure

1. **Save first** (named version), so you can revert (Docs advice for packages from others applies to any asset).
2. **Insert into a scratch place**, not your game. A baseplate is enough.
3. Before anything runs, right-click the inserted object, **Disable Scripts** (Docs).
4. Search the subtree: `ModelName.** is:LuaSourceContainer` in the Explorer. Read every script. Expect zero scripts in pure art.
5. Run the audit script (section 6) on the subtree.
6. Check `Workspace` and services for anything the model added outside itself.
7. If it is clean and you want it, strip scripts you do not need, then copy only the parts you need into your game.
8. Better: re-export the meshes and rebuild the asset under your own ownership.

**Measured.** The reference project banned foreign assets outright: no Toolbox inserts and no third-party asset ids. Everything was built in Blender by the team, uploaded under the game's own account, and only those ids were inserted. The cost was more art time; the benefits were a consistent art style, no licensing questions, no surprise scripts and full control over triangle and texture budgets (see [[Modeling in Blender for Roblox]] and [[Asset Pipelines]]).

## 5. Plugins are the bigger risk

A model runs only when your game runs. A plugin runs in Studio every time you open any place, with the power to read and rewrite all scripts. A malicious or compromised plugin can insert a backdoor into a hundred places before anyone notices (Rule of thumb). Mitigations (see [[Plugins - Using and Writing]]):
- Approved plugin list per team, with creators and purposes.
- Script injection granted only to plugins whose job is editing code.
- HTTP sandboxing on; review domain prompts.
- Periodic audit of all scripts in the place for remote requires (section 6), not only new models.
- Source control: a diff of scripts you did not change is the clearest sign of injection (see [[Git and Source Control for Roblox]]).

## 6. An audit script

Run in the Command Bar on a scratch place or your game. It only reads.

```lua
--!strict
-- Read-only scan for patterns the Creator Store forbids and common backdoor tells.
local ROOTS: { Instance } = {
	workspace,
	game:GetService("ServerScriptService"),
	game:GetService("ServerStorage"),
	game:GetService("ReplicatedStorage"),
	game:GetService("ReplicatedFirst"),
	game:GetService("StarterGui"),
	game:GetService("StarterPack"),
	game:GetService("StarterPlayer"),
	game:GetService("Lighting"),
}

local PATTERNS: { { name: string, pattern: string } } = {
	{ name = "numeric require", pattern = "require%s*%(%s*[%d%(]" },
	{ name = "getfenv/setfenv", pattern = "[gs]etfenv" },
	{ name = "loadstring", pattern = "loadstring" },
	{ name = "LoadAsset", pattern = "LoadAsset" },
	{ name = "string.char chain", pattern = "string%.char%s*%(%s*%d+%s*,%s*%d+%s*,%s*%d+" },
	{ name = "hex escapes", pattern = "\\x%x%x\\x%x%x\\x%x%x" },
	{ name = "long whitespace run", pattern = string.rep("[ \t]", 40) .. "%S" }, -- 40+ spaces then code
}

local SUSPICIOUS_NAMES = { Weld = true, ThumbnailCamera = true, Light = true, Fire = true, Smoke = true, Sparkles = true }

local hits = 0
for _, root in ROOTS do
	for _, inst in root:GetDescendants() do
		if inst:IsA("LuaSourceContainer") then
			local ok, src = pcall(function()
				return (inst :: any).Source :: string
			end)
			if ok then
				local found: { string } = {}
				for _, p in PATTERNS do
					if string.find(src, p.pattern) then
						table.insert(found, p.name)
					end
				end
				if SUSPICIOUS_NAMES[inst.Name] then
					table.insert(found, "script named like a non-script")
				end
				if #src > 100_000 then
					table.insert(found, ("very large (%d chars)"):format(#src))
				end
				if #found > 0 then
					hits += 1
					warn(inst:GetFullName(), "->", table.concat(found, ", "))
				end
			end
		end
	end
end
print(("audit done: %d scripts flagged"):format(hits))
```

Hits are leads, not verdicts. Your own tools may legitimately use `loadstring` in edit-only code, and a `require` of a numeric id is legitimate for a few official modules. Every hit should have an owner who can explain it. Add the audit to release QA (see [[QA Checklists Before Release]]).

## 7. Licensing, ownership and permissions

- **IP.** Assets must follow the Community Rules, Terms of Use and IP guidelines (Docs). "Free model" means free to insert, not cleared of copyright. A ripped game model or a brand logo can get your game moderated.
- **Asset privacy.** Images, decals and meshes are Open Use by default; with **Asset Privacy** enabled (Creator Dashboard, Settings, Advanced) new ones are Restricted. Restricted assets only load for creators and games granted permission; Open Use is irreversible; game grants are permanent (Docs). Restricted dependencies inside a store model you insert will not render in your game without permission.
- **Audio and animations** have their own permission rules: an animation only plays in games owned by the same user or group as the animation (see [[Animation Asset Permissions and Groups]]).
- **Distributing** your own assets: account must be at least 2 days old, not recently banned, and age-checked or ID verified (not phone). Distribution limits per 30 days (Docs, October 2026):

| | Mesh | Image | Model | Audio | Plugins |
|---|---|---|---|---|---|
| Verified | 200 | 200 | 200 | 100 | 10 |
| Unverified | 10 | 10 | 10 | 10 | 2 |

- **Selling** models and plugins for USD needs a Stripe seller account; 18+ or 13-17 with parental consent, 2-step verification, supported country; only individually owned assets can be sold, not group-owned; only individuals can buy (Docs). Sellers keep 100% of net proceeds after taxes and payment processing (Docs).

## 8. Using store assets well

When you do use store content (prototypes, jams, solo projects):
- Prefer **verified creators** and assets with high script count transparency (zero scripts for art).
- Check **triangle and vertex counts** on the details page before inserting; a 200k triangle "low poly" tree is common (see [[Art Budgets - Triangles Draw Calls Memory]]).
- Normalise imported art: scale, pivot, collision fidelity, `CastShadow`, materials, anchoring.
- Keep a list of every third-party asset id with source and licence notes in the repo, so you can replace them before launch.
- Replace prototype assets before release; a recognisable free model reads as low effort to players.

### If you find a backdoor in a live game

1. Remove the payload and every script it created; run the audit on the whole place, not only the model.
2. Check `ServerScriptService`, `ServerStorage` and `StarterPlayer` for scripts added near the same date (Script History and Version History show when).
3. Review plugins installed around that time and remove any you cannot vouch for.
4. Publish the cleaned place and restart all servers (see [[Release Process and Rollbacks]]); a backdoor keeps running in old servers until they close.
5. Check DataStores for tampering if the payload had server access (see [[Data Loss Prevention and Recovery]]).
6. Report the asset on its details page (**Report Item**, Docs).
7. Write down how it got in and add the check that would have caught it.

## 9. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Inserting directly into the live place | Backdoor saved and possibly published | Scratch place first |
| Trusting a model because it has many likes | Bots inflate ratings | Read the scripts |
| Deleting the model and assuming it is gone | Injected scripts elsewhere remain | Audit the whole place |
| Ignoring LocalScripts | UI spam, data leaks | Read everything |
| Approving every plugin permission | Persistent injection | Approved list, minimal permissions |
| Assuming free means licensed | Moderation, takedowns | Track sources; replace |
| Store assets with Restricted dependencies | Invisible meshes in your game | Check Output for permission errors |

## 10. Checklist

- [ ] Insert unknown assets only into a scratch place with scripts disabled.
- [ ] Read every script in an inserted asset.
- [ ] Run the audit script before every release and after installing a new plugin.
- [ ] Approved plugin list maintained.
- [ ] Third-party asset register with licence notes.
- [ ] Asset Privacy enabled for the group if you sell or share kits.

## See also

- [[Plugins - Using and Writing]], [[Packages and Asset Reuse]], [[Asset Pipelines]]
- [[Exploits and Anti-Cheat]], [[Server Authority and Validation]], [[Roblox Policies Ratings and Compliance]]
- [[Places Universes and Experience Settings]], [[Command Bar and Studio Scripting]]

## Connected notes
<!-- auto-links:start -->
[[Plugin Security and Permissions]] · [[Links - Backdoors and malicious assets]] · [[Publishing Selling and Updating Plugins]] · [[Legal Basics - IP Licenses and Assets]] · [[Resource Library - Safety (free models and plugins)]] · [[Links - Models, Toolbox and Creator Store]]
<!-- auto-links:end -->
