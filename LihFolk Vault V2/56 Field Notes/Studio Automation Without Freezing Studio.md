---
tags: [field-notes, studio, command-bar, mcp, automation, patterns, scripts, performance, type/guide, area/performance, level/intermediate, area/ai]
---
# Studio Automation Without Freezing Studio

<!-- tldr:start -->
> [!tldr] TL;DR
> - Studio frozen for many minutes on a search: Leading `[^\n]*` or `.-` in `gmatch` over big sources -> Plain `find` first, or split lines
> - Studio unresponsive during bulk edits: No yielding -> `task.wait()` every ~50 ms, paged jobs
> - Write of a generated module fails: ~200k character source cap -> Split data modules
> - No pattern starts with `[^...]*`, `.*` or `.-`; literals found with plain `find`.
> - Long jobs yield and are paged across calls.
> - Source length checked against the cap before writing.
>
> Cost: TL;DR ~170 tok · whole note ~1.9k tok. Read more: ## 1. Patterns that backtrack catastrophically · ## 4. Compile-check before saving · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Bulk work through the command bar or an MCP `execute_luau` call (search every script, patch a pattern, rebuild a folder) runs on Studio's main thread. A slow call does not just take a while; it freezes the editor for everyone connected, and a pathological one can freeze it for most of an hour. This note collects the rules that came out of running large automated edits on a big place: pattern traps, chunking, the script size cap, compile checks, and the AutoRecovery trap. Basics are in [[Command Bar and Studio Scripting]] and [[Batch Processing Tools in Studio]]; agent rules in [[Safety Rules for AI Agents in Studio]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. Patterns that backtrack catastrophically

**Measured.** A search over every script used `string.gmatch(source, "[^\n]*FireServer[^\n]*")` to pull out matching lines (the leading `[^\n]*` is the culprit). Studio froze for over 40 minutes.

Why: Luau patterns are matched by backtracking. An unanchored pattern is tried at *every* position in the string. At each position, `[^\n]*` greedily eats to the end of the line and then gives characters back one at a time looking for `FireServer`. For a line of length L that is about L steps from each of L starting positions, so O(L squared) per line, and minified or generated scripts can have lines tens of thousands of characters long. `.-` spanning newlines is worse: it can scan to the end of the *file* from every starting position, O(N squared) on a 200,000-character script, around 4 x 10^10 steps.

Safe shapes:

- **Find the literal first, then expand.** `string.find(source, "FireServer", init, true)` (the fourth argument `true` means a plain find with no pattern) is linear. Then walk back and forward to the newlines to extract the line.
- **Split, then match per line.** `string.split(source, "\n")` is linear; run simple patterns per line.
- **Start patterns with a literal or an anchor.** `"rbxassetid://(%d+)"` is cheap; `"^%s*local"` per line is cheap. Leading `[^x]*`, `.*` or `.-` is the trap.

```lua
-- Find lines containing a literal, linear time.
local function linesContaining(source: string, needle: string): { { line: number, text: string } }
	local out = {}
	for i, text in string.split(source, "\n") do
		if string.find(text, needle, 1, true) then
			table.insert(out, { line = i, text = text })
		end
	end
	return out
end
```

## 2. Chunk work and yield

Even linear work over thousands of scripts can take seconds. Yield every so often with `task.wait()` so Studio repaints and other MCP calls get a turn. **Rule of thumb:** keep any single uninterrupted stretch under about 100 ms, and any single tool call short (the multi-agent rule of thumb of about 1.5 s in [[Multiple Agents in One Studio]]). For longer jobs, run them in pages: process scripts 1 to 200, return, then 201 to 400 in the next call, storing progress in an attribute or a module-level table.

```lua
local scripts = {}
for _, root in { game.ServerScriptService, game.ReplicatedStorage, game.StarterPlayer, game.StarterGui, game.ReplicatedFirst } do
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			table.insert(scripts, d)
		end
	end
end

local hits = {}
local started = os.clock()
for i, s in scripts do
	for _, h in linesContaining(s.Source, "FireServer") do
		table.insert(hits, s:GetFullName() .. ":" .. h.line)
	end
	if os.clock() - started > 0.05 then
		task.wait()
		started = os.clock()
	end
end
print(#hits, "hits")
```

## 3. The script size cap

**Measured.** Writes of very large sources failed at around 200,000 characters per script. Generated modules (baked animation data, big lookup tables) hit it first. Split data across several modules and have a small index module `require` them. Check `#newSource` before writing and refuse to write anything near the cap.

## 4. Compile-check before saving

A patch that breaks syntax silently disables a script, and you find out in a playtest. Compile the new source first; `loadstring` returns `nil` plus an error message on a syntax error and does not run the code (field-tested in the command bar and plugin context):

```lua
local ScriptEditorService = game:GetService("ScriptEditorService")

local function safeWrite(target: LuaSourceContainer, newSource: string): (boolean, string?)
	if #newSource > 190000 then
		return false, "too large; split the module"
	end
	local fn, err = loadstring(newSource)
	if not fn then
		return false, "compile error: " .. tostring(err)
	end
	ScriptEditorService:UpdateSourceAsync(target, function(_old)
		return newSource
	end)
	return true
end
```

`ScriptEditorService:UpdateSourceAsync` (Roblox docs) is the supported way to change a script's source from tooling, and plays well with open script editor tabs and collaborative editing. Compare the old source in the callback with what you read earlier; if it changed, someone else edited the script, so abort ([[Running Many AI Agents on One Roblox Place]]).

## 5. Never work in an AutoRecovery copy

After a crash, Studio offers to open an auto-recovered copy. It is a local file, not your published place. **Measured:** edits made there are not in the cloud place and are lost unless copied back by hand. Open the published place, then copy only what you need out of the recovery file. Before any bulk edit, check you are in the right place (rule of thumb: `game.PlaceId` is non-zero when the published place is open, and a local file opened from disk shows 0).

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Studio frozen for many minutes on a search | Leading `[^\n]*` or `.-` in `gmatch` over big sources | Plain `find` first, or split lines |
| Studio unresponsive during bulk edits | No yielding | `task.wait()` every ~50 ms, paged jobs |
| Write of a generated module fails | ~200k character source cap | Split data modules |
| Script silently stopped working after a patch | Syntax error saved | `loadstring` compile check first |
| Hours of edits vanished | Worked in an AutoRecovery copy | Check `game.PlaceId` before working |

## Checklist

- [ ] No pattern starts with `[^...]*`, `.*` or `.-`; literals found with plain `find`.
- [ ] Long jobs yield and are paged across calls.
- [ ] Source length checked against the cap before writing.
- [ ] Every generated source compile-checked with `loadstring`.
- [ ] Writes go through `UpdateSourceAsync` with a changed-since-read check.
- [ ] Working in the published place, not a recovery file.

## Connected notes
<!-- auto-links:start -->
[[Command Bar and Studio Scripting]] · Batch Processing Tools in Studio · MCP Workflows for Scripting and Debugging · Safety Rules for AI Agents in Studio · [[Running Many AI Agents on One Roblox Place]] · [[Field Notes Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Moving Data Out of a Play Session]] · [[Server-Authoritative Freeze and Stun Timestamps]] · [[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]] · [[Resetting One Player's Data Safely]] · [[Streaming Joins - Frozen Players and Loading Screen Teardown]] · [[ipairs Stops at the First nil - Cleanup Tables That Leak]] · [[Blind Review Scores - Noise, Panels and Shipping the Best Version]] · [[Held Weapons on Motor6D - Locking the Grip During Attacks]]
<!-- related:end -->
