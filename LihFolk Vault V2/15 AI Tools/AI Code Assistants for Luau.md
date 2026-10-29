---
tags: [ai, luau, scripting, code-assistants, tooling, type/guide, area/ai, level/intermediate, api/LoadAnimation, area/scripting, api/Animator, api/Humanoid]
---
# AI Code Assistants for Luau

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Accepting inline completions for member names without reading them.
> - Avoid: Asking a chat model for a system without telling it where code runs and what it trusts.
> - Avoid: Letting an agent rewrite whole files that others also edit.
> - Code in files with Git, or a disciplined local-copy-and-compare habit.
> - Project memory file with hard rules and checks.
> - Docs access (llms.txt, `.md` reference pages, `http_get`) and an instruction to use it.
>
> Cost: TL;DR ~160 tok · whole note ~4.1k tok. Read more: ## 2. Set the project up for AI · ## 3. What AI gets wrong in Luau specifically · ## Common mistakes · ## Checklist
<!-- tldr:end -->

This note covers using AI to write Luau: which kinds of tools exist, how to set up a project so they work well, what they get wrong about Luau and Roblox specifically, and the checks that catch those errors. The verification method is expanded in [[Prompting and Verifying AI Output]]; agent setups in [[AI Agents and Autonomous Workflows]].

Products named here are as of October 2026. Features and plans change monthly; prices are deliberately not listed because they change too often to be useful in a shared vault. Check vendor pages.

---

## 1. Three kinds of coding AI

| Kind | Examples (October 2026) | Where it works | Best for | Main risk |
|---|---|---|---|---|
| Inline completion | Roblox Code Assist in the Script Editor, GitHub Copilot, Cursor Tab | As you type | Finishing the line or block you already started | Plausible wrong member names you accept with Tab |
| Chat | [[Roblox Assistant]], ChatGPT, Claude, Gemini, Copilot Chat | A side panel or browser | Explaining errors, drafting a module, reviewing a function | Code written without seeing your project |
| Agentic (tool-using) | Claude Code, OpenAI Codex CLI, Gemini CLI, Cursor agent, GitHub Copilot agent mode, Google Antigravity, Roblox Assistant in its agent role | Your repo and terminal, and Studio through MCP | Multi-file changes, running checks, refactors, tooling | Large changes made quickly, claimed done without proof |

Roblox's Studio MCP docs list quick-connect support for Antigravity, Codex CLI, Claude Code, Claude Desktop, Cursor, Gemini CLI and Visual Studio Code (German-language version of the page, October 2026), and any client that supports stdio transport can connect. See [[Setting Up MCP Clients]].

**Code Assist** is Roblox's inline completion inside Studio's Script Editor. Roblox's AI overview describes it as real-time code completions based on your script and comments. A common way to drive it: write a comment describing what the next block should do, pause, and accept the suggestion with Tab (third-party guide; Roblox's own page on the trigger rules was not available when checked).

---

## 2. Set the project up for AI

### Put code in files

Agentic tools are built around files, diffs and version control. Code that lives only inside a place file is hard for them to read in bulk and impossible to review as a diff. A file-based project with Rojo gives:

- Every script as a `.luau` file the agent can grep, read and edit.
- Git history, so every AI change is a reviewable diff and can be reverted.
- Linting and formatting (Selene, StyLua) and a language server (luau-lsp) the agent can run.

See [[External Tooling - Rojo Wally Selene StyLua]] and [[Git and Source Control for Roblox]].

If your project is not file-based (many are not), an MCP-connected agent can still read and edit scripts in Studio with `script_read`, `script_grep` and `multi_edit`. The reference project worked this way for most of its life, with one important habit: it kept local copies of the sources it changed, byte-identical to Studio, and compared Studio's current source against its local base before overwriting, because other sessions edited the same scripts.

### Write a project memory file

Every agentic tool reads some kind of project instructions file (for example `CLAUDE.md` for Claude Code, `AGENTS.md` for several others, rules files for Cursor). This is the highest-leverage thing you can write. What belongs in it:

- **Architecture in 20 lines.** Where server code, client code and shared modules live. How remotes are organised. Which framework, if any.
- **Hard rules.** "The server validates every remote." "Never edit `CombatService`; extend `CombatAPI`." "Never name a child `Origin`, `Attack` or `FX` in a kit folder."
- **Checks to run** before calling anything done.
- **Known traps** in this codebase (the 200,000 character `Source` limit, a module everyone requires, Studio-only APIs).
- **What not to do**, written as explicitly as possible.

The reference project's notes file grew to hundreds of lines, but the part that prevented the most damage was a short list near the top: Edit mode only, never start or stop Play, one Studio call at a time under about 1.5 seconds, never invent asset ids, never use undo in the shared place, compile and scan before saving any script.

### Give it the API reference

Models remember the Roblox API imperfectly. Give them a way to check:
- Roblox publishes a documentation index for LLMs at `create.roblox.com/docs/llms.txt`, and reference pages are available as Markdown (append `.md` to a reference URL; for example the `TextGenerator` reference is at `/docs/reference/engine/classes/TextGenerator.md`).
- The Studio MCP server includes `http_get`, which fetches allowed Roblox documentation pages.
- luau-lsp with Roblox type definitions turns invented members into type errors.

Then instruct: "Before using any API member you are not certain of, open its reference page."

---

## 3. What AI gets wrong in Luau specifically

Luau is a superset of Lua 5.1 with its own additions, and models trained on lots of plain Lua (and lots of old Roblox code) mix the dialects.

### Language confusion

| AI writes | Problem | Luau reality |
|---|---|---|
| `goto continue` / `::continue::` | Lua 5.2+ syntax | Not in Luau. Use `continue` (Luau has it) |
| `a & b`, `a << 2` | Lua 5.3 bitwise operators | Not in Luau. Use `bit32.band`, `bit32.lshift` |
| `math.pow`, `table.getn`, `unpack` (global) | Old or removed | Use `^`, `#t`, `table.unpack` |
| `local x <const> = 5` | Lua 5.4 attribute syntax | Not in Luau. Plain `local` |
| `#dict` for a dictionary's size | `#` counts the array part only | Count with a loop or keep a counter |
| `for i, v in pairs(arr)` assumed ordered | `pairs` order is undefined | Use `ipairs` or generalised `for i, v in arr` on arrays |
| String interpolation with `${x}` | JavaScript habit | Luau uses backticks: `` `HP {hp}` `` |
| `x ?? y`, `obj?.field` | Other languages | Not in Luau: `if x ~= nil then x else y` |
| Type annotations in the wrong place, `any` everywhere | Half-learned type syntax | See [[Luau Type System and Strict Mode]] |

Luau does have compound assignment (`+=`), floor division (`//`), `continue`, if-expressions, generalised iteration, string interpolation, `table.clone`, `table.freeze` and `buffer`. Models sometimes avoid these and write older code; that is legal, just dated.

### Roblox API confusion

| AI writes | Status (October 2026) | Use |
|---|---|---|
| `wait()`, `spawn()`, `delay()` | Legacy, throttled | `task.wait`, `task.spawn`, `task.delay` |
| `Humanoid:LoadAnimation` | Deprecated | `Animator:LoadAnimation` ([[Animator Deep Dive]]) |
| `BodyVelocity`, `BodyGyro`, `BodyPosition` | Deprecated body movers | `LinearVelocity`, `AlignOrientation`, `AlignPosition` ([[Mover Constraints and Physics Controllers]]) |
| `RunService.Stepped` / `RenderStepped` everywhere | Older names | `PreSimulation`, `PreRender`, `Heartbeat` as appropriate ([[Frame Order and RunService Timing]]) |
| `game.Players.LocalPlayer` in a server Script | Nil on the server | Get the player from the remote's first argument |
| `Instance.new("Part", parent)` | Works, but the docs advise setting `Parent` last for performance | Set properties, then `Parent` |
| `KeyframeSequenceProvider:RegisterKeyframeSequence` to play clips | Studio-only ids, deprecated service | Publish the clip; see [[Case Study - Abilities That Only Worked in Studio]] |
| `DataStore:SetAsync` for player data with no retries or locking | Data loss risk | [[Session Locking and Profile Libraries]] |
| Invented members like `Humanoid.IsAttacking`, `Player:GetCurrency()` | Do not exist | Your own attributes or modules |
| `HttpService` calls from a LocalScript | Not allowed on clients | Server only |

### Architecture confusion

The most expensive AI mistakes are not syntax. They are about trust and location:

- **Client authority.** The model writes `GiveCoins:FireServer(100)` and a server handler that adds whatever amount arrives. Any exploiter can send a million. The fix is a protocol where the client asks ("I opened chest 7") and the server decides ([[Server Authority and Validation]]).
- **Wrong side.** UI code in a server Script; damage applied in a LocalScript that only changes that client's view.
- **Replication assumptions.** Writing `Motor6D.Transform` on the server and expecting clients to see it; playing an NPC animation from a LocalScript and expecting other players to see it ([[Replication and Ownership]]).
- **Lifecycle.** Connections never disconnected, characters assumed to exist at `PlayerAdded`, no handling for respawn.

Ask the model to state, for each script it writes: where it runs (`RunContext`, container), what it trusts, and what happens when the player leaves or respawns.

---

## 4. The checks that catch AI code errors

In rough order of cost:

1. **It compiles.** In Studio tooling, `loadstring(source)` returns `nil, err` on a syntax error. (Server-side `loadstring` needs `ServerScriptService.LoadStringEnabled`; plugins and the command bar can use it.) In a file project, run luau-lsp or `luau-analyze`.
2. **Strict type check** on new modules (`--!strict`). Type errors catch invented members fast.
3. **Lint** (Selene) with rules for deprecated globals.
4. **Use-before-definition scan.** A local function called above its definition compiles fine and crashes at runtime. The reference project wrote a scanner for this and required it to return no issues before saving any script; it caught real crashes.
5. **Size limit.** A script's `Source` cannot exceed 200,000 characters (measured: the save fails with "Unable to assign property Source"). Generated code grows fast; the reference project had a combat service at about 199,000 characters and a rule never to edit it, only to extend it through a separate API module.
6. **Behaviour check** in Play or a live server, ideally with an observable signal (an attribute, a log line).

A small Studio-side lint for the most common AI regressions:

```lua
--!strict
-- Command bar / plugin: scan every script for patterns AI code tends to reintroduce.
local PATTERNS: { { name: string, pattern: string } } = {
	{ name = "legacy wait", pattern = "[^%.%w_]wait%s*%(" },
	{ name = "legacy spawn", pattern = "[^%.%w_]spawn%s*%(" },
	{ name = "legacy delay", pattern = "[^%.%w_]delay%s*%(" },
	{ name = "Humanoid:LoadAnimation", pattern = "[Hh]umanoid:LoadAnimation" },
	{ name = "Studio-only clip ids", pattern = "RegisterKeyframeSequence" },
	{ name = "body movers", pattern = "Body[VGP]%a+" },
}

local results = {}
for _, inst in game:GetDescendants() do
	if inst:IsA("LuaSourceContainer") then
		local ok, src = pcall(function()
			return (inst :: any).Source :: string
		end)
		if ok and src then
			for _, p in PATTERNS do
				if string.find(" " .. src, p.pattern) then
					table.insert(results, ("%s: %s"):format(p.name, inst:GetFullName()))
				end
			end
		end
	end
end
table.sort(results)
print(#results .. " findings")
for _, line in results do
	print(line)
end
```

(Reading `Source` needs plugin or command bar security; it fails in game scripts.) Expect false positives: a local function called `wait` would match. The point is a short list for a human to read.

---

## 5. How to ask

**Bad:** "Make a pet system."

**Better:**

```
Write a server-authoritative pet follow system.
Context: pets are Models in ReplicatedStorage.Pets with a PrimaryPart. Players own pets via
the attribute "EquippedPet" (string, pet name) on the Player, set by PetService (server).
Requirements:
- Server: when EquippedPet changes, clone the pet into workspace.Pets.<UserId>, set network owner
  to the player for its parts, remove it on change or PlayerRemoving.
- Client: no movement logic needed beyond what physics does; use AlignPosition/AlignOrientation
  to follow the character's HumanoidRootPart at an offset.
- Modern APIs only (task.*, AlignPosition, no BodyPosition). --!strict.
- Handle respawn (CharacterAdded) and pets that fail to load.
Then list: each script, where it runs, what it trusts from the client (should be nothing), and how to test it.
```

What makes it better: real names from your project, the trust boundary stated, the API era stated, failure cases named, and a request for a test plan.

**For bug fixes,** paste the actual error with its stack trace and the code it points to, say what you expected, and say what you already ruled out. "It doesn't work" invites the model to rewrite things that were fine.

**For reviews,** give it a role and a checklist: "Review this RemoteEvent handler as an exploiter would. List every argument that is not type-checked, range-checked or rate-limited."

---

## 6. When the AI is right and you are not sure

Models often know an obscure API correctly. Do not reject unfamiliar code on instinct; check it. A two-minute check on the reference page is cheaper than either trusting or rewriting. The reference project's animation work found several engine behaviours where the documentation itself was incomplete (easing directions, interpolation) and only a measurement settled who was right ([[How the Animator Really Behaves]]). For engine behaviour, the order of authority is: a measurement in Studio, then the reference page, then the model.

---

## 7. Reference project practices worth copying

- A notes file read at the start of every session, with rules first and history after.
- Every script save gated by: compile, use-before-definition scan, size under 200,000 characters, and for modules a fresh "clone-require" beside the original to prove it loads.
- Shared modules edited with ONE insert per change, after re-reading the current source; never a whole-file rewrite of a module someone else also edits.
- Reserved names enforced by a build tool (a clip named `Origin` once replaced a `RemoteEvent` of the same name in a kit folder and silently broke all of that kit's damage).
- Honest status in every report: "compiled and scanned, not play-tested".
- Large generated scripts (100-370 KB setup scripts) did not go through the MCP connection; the owner pasted them into the command bar, and the agent adapted what they created.

## Common mistakes

- Accepting inline completions for member names without reading them.
- Asking a chat model for a system without telling it where code runs and what it trusts.
- Letting an agent rewrite whole files that others also edit.
- No project memory file, so every session relearns (and re-breaks) the rules.
- Treating "it compiles" as "it works".

## Checklist

- [ ] Code in files with Git, or a disciplined local-copy-and-compare habit.
- [ ] Project memory file with hard rules and checks.
- [ ] Docs access (llms.txt, `.md` reference pages, `http_get`) and an instruction to use it.
- [ ] Strict typing, lint and a deprecated-pattern scan.
- [ ] Every AI change reviewed as a diff.
- [ ] Status labels say how it was verified.

## See also
[[Prompting and Verifying AI Output]] · [[Roblox Studio Assistant]] · [[AI Agents and Autonomous Workflows]] · [[MCP Workflows for Scripting and Debugging]] · [[Luau Language Essentials]] · [[Luau Type System and Strict Mode]] · [[Code Pipeline - Rojo Git and CI]] · [[Exploits and Anti-Cheat]]

## Connected notes
<!-- auto-links:start -->
[[AI in Roblox Development Overview]] · [[Studio Assistant and AI Tools]] · Roblox Studio MCP Server · Code Review for Luau Teams · Links - External tooling · Safety Rules for AI Agents in Studio
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Local vs Cloud AI - Keeping Unreleased Game Code Private]] · [[Roblox Studio MCP Server]] · [[What AI Models Get Wrong in Roblox]] · [[AI Pitfalls - Stale APIs and Luau]] · [[Roblox Built-In AI Tools Timeline 2023-2026]] · [[Evaluating AI Tools - A Practical Rubric]] · [[Windows Tooling Pitfalls for Agent Pipelines]] · [[Agent Orchestration - Sub-Agents, Hooks and Skill Costs]] · [[In-Game AI - LLM NPCs and Text Generation]]
<!-- related:end -->
