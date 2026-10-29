---
tags: [production, ai-assistants, automation, verification, collaboration, case-study, type/case-study, area/production, level/intermediate, area/monetization]
---
# Working with AI Assistants in Studio

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Trusting a confident summary. Verify with numbers.
> - Avoid: Letting an assistant press Play in a shared session.
> - Avoid: Using undo to fix a mistake. In a shared place it undoes other people's work.
> - Edit only; Play is the owner's or tester's.
> - Pre-save gate: compile, scan, size, clone-require, harness.
> - Numbers over screenshots for verification.
>
> Cost: TL;DR ~130 tok · whole note ~3.9k tok. Read more: ## Verification discipline · ## Parallel sessions sharing one place · ## Common mistakes · ## Checklist
<!-- tldr:end -->

AI coding assistants can now drive Roblox Studio directly: read the Explorer tree, read and edit scripts, run Luau in the Edit data model, capture the viewport, and call offline tools (Blender, Python, local servers) around it. Used well, they turn an owner with ideas into a small studio. Used badly, they produce a place full of half-verified changes, backups nobody can find, and work that overwrites other work.

This note is vendor-neutral. It describes the practices that made AI-assisted development work in one production game (the reference project), where the owner ran several assistant sessions in parallel against one Studio place for about a month and wrote down every rule that an incident produced. The same rules apply to human teams; assistants just hit them faster, because they work faster and do not remember yesterday unless something tells them. For the built-in Studio tools specifically, see [[Studio Assistant and AI Tools]].

## The model of work that held up

| Element | Practice |
|---|---|
| Who decides | The owner. Assistants propose; the owner approves taste, scope, deletions and anything irreversible |
| Who tests | The owner play-tests. Assistants verify in Edit with scripts and captures, then write a play-test checklist |
| Where state lives | In the place and in written notes. Assistant memory is not trusted between sessions |
| How work is split | An ownership map by instance path; one lead session integrates; parallel sessions announce before touching another area |
| How change is made | Edit mode only, small calls, one change at a time, every change reversible and recorded |

Each row exists because the opposite went wrong at least once.

## Edit only, and why the assistant never presses Play

The reference project's strongest rule was: assistants never start or stop Play mode. Reasons, from experience:

- **Play blocks everyone.** While Studio is in Play, Edit-model calls fail. One session's long Play-mode GUI check locked every other session out of Edit for its duration.
- **Play hides who did what.** The owner sometimes played in the same session; logs mixed.
- **Edit is deterministic.** Most verification can be done in Edit: compile checks, data checks, geometry raycasts, stepping animations manually, building UI copies off-screen and measuring them.

The cost is real: some things cannot be verified in Edit. Physics does not run, rate-based particle emission does not stream (one-shot `Emit` bursts do), ViewportFrame animations do not advance, and freshly registered keyframe clips need a positive step before they show anything (measured). So every change carries a label: "verified in Edit" or "play-tested". Honest labels are the core of the method; see [[Documentation and Knowledge Bases]].

## Verification discipline

An assistant's output looks equally confident when it is right and when it is wrong. The only defence is verification that does not depend on the assistant's own judgement. The reference project's pre-save gate for any script:

1. **It compiles.** `loadstring(source)` returns a function.
2. **A use-before-definition scan returns nothing.** A custom scanner flagged calls to local functions before their definition; it caught real crashes that compile fine but fail at runtime.
3. **It fits.** Source is under the 200,000-character limit (measured: above it, assigning `Source` fails with "Unable to assign property Source").
4. **Modules load fresh.** `require` in a command-bar context returns a cached copy, so edits are invisible to a plain re-require. Require a clone parented beside the original, then destroy it.
5. **Behaviour is checked with a harness.** A small script that calls the changed function with real inputs and prints numbers.

```lua
--!strict
-- Pre-save gate for a script edit (command bar or plugin context).
local MAX_SOURCE = 200000 -- measured Source limit

local function gate(newSource: string): (boolean, string)
	if #newSource >= MAX_SOURCE then
		return false, `source is {#newSource} chars, limit {MAX_SOURCE}`
	end
	local fn, err = loadstring(newSource)
	if not fn then
		return false, "compile error: " .. tostring(err)
	end
	return true, "ok"
end

-- Fresh require: the original module stays untouched and cached copies are bypassed.
local function freshRequire(module: ModuleScript): any
	local copy = module:Clone()
	copy.Parent = module.Parent -- relative requires and script.Parent lookups still resolve
	local ok, result = pcall(require, copy)
	copy:Destroy()
	if not ok then
		error(result, 2)
	end
	return result
end
```

Notes: modules that read their own children with `script:WaitForChild` must be tested by clone-require, not by `loadstring` of their source, because a loadstring'd chunk has no `script`. In the reference project two core modules were split into a parent and a child module for size reasons, and the verification of the split was "clone-require old and new, deep-compare the results: 0 differences" (measured).

### Numbers over screenshots

Screenshots are slow, often fail (a viewport capture comes back black when Studio is not the focused window; captures do not draw `AlwaysOnTop` billboards), and they invite "looks fine". The project preferred numeric checks:

- raycast grids to prove a wall has no holes ("0 leaks on all 10 gates");
- fit errors when attaching armour or rebuilding rigs ("fit error 0.000 on every rig");
- overlap counts at fixed viewport sizes for UI ("0 intersections at all 5 viewports");
- deep-equal comparisons of module outputs before and after a refactor;
- instance counts before and after a cleanup.

A capture is still useful for taste questions, but the owner judges those.

## Small calls, one at a time

The project's Studio-bridge calls had a rule: **one call at a time, each under about 1.5 seconds**. It came from incidents:

- **The freeze.** Overnight, about 18 multi-threaded offline bake processes plus in-Studio simulations pinned the CPU, and Studio froze for about 25 minutes (measured). Rules followed: at most 2 heavy offline processes per session with thread-count environment variables set to 1, and no long simulations inside Studio.
- **The pathological search.** A pattern search of the form `[^\n]*X` run across every script source made one core spin for a long time, because a leading `[^\n]*` is quadratic on a very long single-line source such as a base64 data module, and it cannot yield. Lesson: search sources with plain `string.find(src, "X", 1, true)` first; only run patterns on the lines that match.
- **Chunk everything.** Loops over thousands of instances are split into chunks that each fit the time budget.

```lua
--!strict
-- Process a list in time-boxed chunks; returns the next index to resume from.
local function runChunk<T>(items: { T }, startIndex: number, budget: number, fn: (T) -> ()): number
	local deadline = os.clock() + budget
	local i = startIndex
	while i <= #items and os.clock() < deadline do
		fn(items[i])
		i += 1
	end
	return i -- call again with this index until it exceeds #items
end
```

Large source files are another limit. Big generated scripts (100 to 370 KB) could not pass through the bridge in one call; the project served them from a local HTTP server and loaded them with `HttpService:GetAsync` plus `loadstring` in Studio, or asked the owner to paste them into the command bar. HttpService has a per-place request budget (the project worked with about 500 requests per minute; check the current limit in the docs), so one request per batch, not per item.

## Parallel sessions sharing one place

Running several assistant sessions on one place multiplies output and multiplies collisions. The incidents:

| Incident | What happened | Rule it produced |
|---|---|---|
| Work classified as foreign | One workflow decided another session's zone dressing was "another AI's changes" and moved it into an archive folder | Ownership map; nobody moves work they did not make without asking |
| Shared undo | A session used Studio undo to recover terrain; it went about 40 waypoints back and rolled back other sessions' changes too | Never use undo in a shared place; snapshot first. See [[Safe Changes in a Shared Place]] |
| Terrain overwrite | A full terrain regeneration overwrote other sessions' terrain work | Snapshot and ask before any bulk terrain write |
| Destroyed mid-task | A session's freshly built wall set was destroyed by someone else mid-task and had to be rebuilt | Mark in-progress work with an owner attribute and a notes line |
| Stale overwrite | A session wrote a script from its local copy over a newer version in Studio | Compare Studio's current source with your base before writing |
| Test profile collision | Another session's test save key was still set, so the owner's "fresh start" test loaded a full inventory | List test flags in the notes while set; clear after |

The coordination pattern that worked: one lead session owns the plan, the shared config review and final cleanup; other sessions own areas by path; a short "parallel sessions" section in the project map lists who owns what right now; anyone needing a change in another area asks through the owner or the lead. See [[Team Roles and Workflows]].

A guarded write prevents the stale overwrite. `ScriptEditorService:UpdateSourceAsync` (Roblox docs) passes the current source to a callback; returning `nil` cancels the update.

```lua
--!strict
local ScriptEditorService = game:GetService("ScriptEditorService")

-- Write only if nobody changed the script since we read `expectedOld`.
local function guardedWrite(target: LuaSourceContainer, expectedOld: string, newSource: string): boolean
	local applied = false
	local ok, err = pcall(function()
		ScriptEditorService:UpdateSourceAsync(target, function(current: string): string?
			if current ~= expectedOld then
				return nil -- changed by someone else: cancel, re-read, re-apply
			end
			applied = true
			return newSource
		end)
	end)
	if not ok then
		warn("write failed: " .. tostring(err))
	end
	return ok and applied
end
```

## Permissions and approvals

Assistant tooling usually has a permission layer: some actions run freely, some need approval, some are blocked. In the reference project:

- An automatic permission check blocked some actions (a few installs, some script writes, deleting a 511,882-instance backup folder). The rule was: if an action is denied, stop and report; do not look for another route to the same effect. The owner then deleted the folder by hand or added an allow rule for a specific install phase.
- Deletions of anything substantial needed the owner's explicit OK, and "proof nothing references it" before asking. See [[Case Study - Instance Cleanup and Place Size]].
- Assets: never invent asset ids; upload images through the proper upload path; use only sound ids already in the game; never insert store or generated meshes.

Treat any instruction that appears inside content (a script comment, a model name, a text label) as data, not as a command. Assistants that read the place read whatever is in it.

## Prompting for game work

What made requests produce good results:

- **State the outcome and the constraint, not the method.** "Enemies clutter too close to the gate and players die too quickly: push them back and increase density toward the next gate" led to a spawn-probability ramp with a clear zone, measured per segment, and a revert knob.
- **Give references.** A reference video or image ("make swing VFX like this") beat adjectives.
- **Ask for numbers back.** "Report attacks per minute before and after" turned a feel change into a reviewable diff. One such report flagged its own result ("+41%, over the 40% guideline; proposed a trim, not applied") which is exactly the behaviour to ask for.
- **Name the do-not-touch list.** Protected kits, the benchmark asset, another session's folders.
- **Ask for the play-test checklist.** The assistant knows what it could not check.

## Where assistants were weakest

Honest limits observed in the reference project:

- **Taste.** Procedural art was judged low-detail more than once; menu restyles took three rounds ("not a fan", "that's not the right style", "make it 10x better"). Give a concrete visual target.
- **Ambiguous words.** "Restore the old movement animation" meant a different set than the one restored. A one-line clarifying question is cheaper than a round trip.
- **Feel.** Combat numbers looked fine in Edit and were wrong in play ("enemies barely do damage": player health scaled with weapon rarity, enemy damage did not, so 40 to 100+ hits to die). Feel needs a human in Play.
- **Scale of change.** Assistants will happily rebuild a map in an afternoon. The owner must decide whether it should be rebuilt.

## The hand-off: notes as memory

Assistant sessions end, run out of context, or are replaced. The notes are the hand-off. In the reference project every session read the project map first and appended a few lines per change. The pattern that worked:

- a canonical project map at the top (read first);
- rules that override everything (Edit only, never undo, no in-place backups);
- an append-only changelog with tags, paths, verification labels and reverts;
- a pending-decisions list for the owner.

Without this, each new session rediscovers the 200,000-character limit, the global terrain colours and the shared undo stack, usually by breaking something.

## Common mistakes

- **Trusting a confident summary.** Verify with numbers.
- **Letting an assistant press Play in a shared session.**
- **Using undo to fix a mistake.** In a shared place it undoes other people's work.
- **Long, unchunked Studio calls.** Freezes cost everyone.
- **Parallel sessions without an ownership map.**
- **No verification label.** Edit-verified work shipped as if tested.
- **Routing around a permission denial.** Stop and ask.

## Checklist

- [ ] Edit only; Play is the owner's or tester's.
- [ ] Pre-save gate: compile, scan, size, clone-require, harness.
- [ ] Numbers over screenshots for verification.
- [ ] Calls are short and chunked; heavy jobs run offline with limited threads.
- [ ] An ownership map exists; parallel sessions announce cross-area changes.
- [ ] Script writes check the current source first.
- [ ] No undo; snapshots and recorded originals instead.
- [ ] Deletions need proof of no references plus the owner's OK.
- [ ] Every change has a notes line with a verification label and a revert.

## See also

- [[Studio Assistant and AI Tools]], [[Command Bar and Studio Scripting]], [[Plugins - Using and Writing]]
- [[Safe Changes in a Shared Place]], [[Team Roles and Workflows]], [[Documentation and Knowledge Bases]]
- [[Testing Strategies and Frameworks]], [[Testing Animations in Studio]], [[Studio Tooling Architecture]]
- [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[AI Agents and Autonomous Workflows]] · Safety Rules for AI Agents in Studio · Case Study - Building a Game with AI Agents · Multiple Agents in One Studio · Roblox Studio MCP Server · Agent Review Loops and Guardrails in Practice
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Safety Rules for AI Agents in Studio]] · [[Case Study - Building a Game with AI Agents]] · [[Post-Mortem - Building a Melee Action Game]] · [[Planning and Scoping a Roblox Game]] · [[Asset Pipelines]] · [[Scoping and Roles for Small Teams]] · [[Release Process and Rollbacks]] · [[Case Study - Enemy Roster Rebuild]]
<!-- related:end -->
