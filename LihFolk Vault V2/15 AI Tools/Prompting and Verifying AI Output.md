---
tags: [ai, verification, prompting, testing, qa, type/guide, area/ai, level/intermediate]
---
# Prompting and Verifying AI Output

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Asking "does it work?" and accepting "yes".
> - Avoid: Verifying in Studio and shipping features that depend on live-only behaviour.
> - Avoid: Relying on screenshots an agent says it took, when the capture may have been black.
> - Prompt states context, rules, API era and what done means.
> - Each change verified to a named rung; the rung is reported.
> - Live-only dependencies tested in a live or team-test server.
>
> Cost: TL;DR ~150 tok · whole note ~3.5k tok. Read more: ## 1. How AI-written Roblox code fails · ## 3. Verifying: the ladder · ## Common mistakes · ## Checklist
<!-- tldr:end -->

AI output fails in a specific way: it looks finished. Wrong code compiles, a wrong mesh renders, a wrong explanation reads fluently, and an agent's report says "done". This note is about the two halves of working with that: asking in a way that makes errors less likely and easier to see, and verifying in a way that catches the errors that remain.

It draws heavily on the reference project, which was built largely by AI coding agents and learned its verification rules from real regressions. The Luau-specific error catalogue is in [[AI Code Assistants for Luau]]; testing in general is in [[Testing Strategies and Frameworks]].

---

## 1. How AI-written Roblox code fails

| Failure | Example | How it shows up | Catch it with |
|---|---|---|---|
| Invented API | `Humanoid.IsAttacking`, `TweenService:TweenModel()` | Runtime error "is not a valid member", or silently nil | Strict types, luau-lsp, opening the reference page |
| Deprecated API | `wait()`, `Humanoid:LoadAnimation`, `BodyVelocity` | Works, but throttled, warned or removed later | A deprecated-pattern scan |
| Wrong dialect | `goto`, `&`, `<const>` | Syntax error | Compile check |
| Client/server confusion | Currency changed in a LocalScript | Works for the tester, nothing saves, or exploitable | Ask "where does this run, what does it trust", review remotes |
| Studio-only behaviour | Temporary clip ids, Studio timing, local secrets | Works in Studio, nothing happens live | Test in a live or team-test server |
| Use before definition | A local function called above its definition | Compiles, crashes at that line at runtime | A use-before-definition scan |
| Name collisions | A new child named like an existing remote | `FindFirstChild` returns the wrong object; a system silently stops | Reserved-name checks, `IsA` on lookups |
| Partial change | 3 of 5 call sites updated | Some paths still use the old behaviour | Grep for the old name after the change |
| Stale read | Edited code based on a version from earlier in the session | Someone else's change disappears | Re-read right before editing; compare with your base |
| Untested claim | "Fixed the dash cooldown" | Nobody pressed the key | Require evidence with every claim |
| Wrong numbers | Invented limits, prices, payout rates | Bad design decisions | Source every number |

### The one that cost the reference project most: works in Studio only

Agents authored hundreds of animation clips and played weapon-part clips through `KeyframeSequenceProvider:RegisterKeyframeSequence`, which returns a temporary id that only loads inside Studio. Every Studio test passed. In live servers, dozens of weapon kits had blades that never moved, marker-driven specials that never fired, and ability clips that did nothing, with no error. Later, templated code reintroduced the same call in a new weapon. The fix needed a real asset or a Lua playback path, plus a lint rule run before every release. Full story: [[Case Study - Abilities That Only Worked in Studio]].

The general lesson: an AI that tested in Studio has proven that it works in Studio. Whenever a feature depends on assets, replication, data stores, secrets, timing or other players, Studio passes are weak evidence.

---

## 2. Prompting to reduce errors

### Give the context it cannot guess

- **Where code runs** and what it trusts.
- **Real names** from your project: modules, remotes, attributes, folders.
- **The API era**: "modern APIs only: `task.*`, `Animator`, `LinearVelocity`, `PreSimulation`".
- **The rules** it must not break, written as a list.
- **What done means**: the checks it must run and report.

### Ask for evidence, not reassurance

Replace "make sure it works" (which produces the sentence "I made sure it works") with requests for artefacts:

- "After editing, print the first 30 lines of the changed function as it now stands in Studio."
- "Grep for every call of `applyDamage` and list file and line."
- "Run the compile check and paste its output."
- "Report the instance count before and after."

### Make it state uncertainty

"For each API member you used, mark whether you checked it against the reference page." Models are better at admitting uncertainty when asked for it in a structured way.

### Small steps with checks between them

A 600-line change verified once is worse than six 100-line changes each verified. Agents can work in long loops; that makes step size more important, not less.

### Name the thing it must not do

The reference project's most effective prompt lines were prohibitions: never start or stop Play; never use undo in the shared place; never invent asset ids (use placeholders like `rbxassetid://0000000000` and ask); never delete without proving nothing references it; never edit a named near-limit script. Each was added after a real incident.

### For creative output, ask for options, not one answer

For art direction, names, item lore and move design, ask for three to five options with trade-offs, then pick. The reference project's owner rejected a batch of twenty agent-designed weapons after the work was done; an early option round would have saved most of that effort.

---

## 3. Verifying: the ladder

Climb as high as the risk needs. Write down which rung you reached.

| Rung | Check | Proves | Does not prove |
|---|---|---|---|
| 0 | Read the code | It says what you wanted | That it runs |
| 1 | Compiles | Syntax | Anything about behaviour |
| 2 | Types, lint, scans | No invented members, no deprecated calls, no use-before-definition | Logic |
| 3 | Loads | Modules `require` without error | That functions work |
| 4 | Unit or probe test | A function returns the right numbers for chosen inputs | Integration |
| 5 | Edit-mode integration probe | Objects exist, counts match, rigs move when stepped | Play behaviour |
| 6 | Play test in Studio | One client and server behave | Live assets, multiple players, real latency |
| 7 | Team Test or a private live server | Live asset loading, secrets, multiple players | Scale |
| 8 | Live with telemetry | Real-world behaviour | Nothing more to prove |

The reference project's agents worked in Edit only (the owner did all play-testing), so their honest ceiling was rung 5, and every report said so: "compiled, scanned, probed in Edit; not play-tested; check in Play: ...". That phrase is a feature. A false "verified" is worse than an honest "not tested", because it removes the human check.

### Rung 1-3 in Studio

```lua
--!strict
-- Gate for saving a generated script: compile, size, optional fresh require.
local MAX_SOURCE = 200000 -- characters; measured hard limit on Script.Source

local function checkSource(src: string): (boolean, string?)
	if #src >= MAX_SOURCE then
		return false, ("source is %d chars (limit %d)"):format(#src, MAX_SOURCE)
	end
	local fn, err = loadstring(src) -- command bar / plugin context
	if not fn then
		return false, "compile: " .. tostring(err)
	end
	return true, nil
end

local function checkModuleLoads(module: ModuleScript): (boolean, string?)
	-- require caches in Edit: clone beside the original so relative requires still resolve
	local clone = module:Clone()
	clone.Parent = module.Parent
	local ok, res = pcall(require, clone)
	clone:Destroy()
	if not ok then
		return false, "require: " .. tostring(res)
	end
	return true, nil
end
```

### Rung 4-5: numeric probes

When screenshots are unavailable or ambiguous, measure. The reference project often could not capture the viewport (captures came back black when Studio was not the focused window), so it verified numerically: positions, distances, bounding boxes, instance counts, joint angles.

```lua
-- Probe: is every spawned prop on the ground (within tolerance) and not inside another prop?
local TOL = 0.25
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local bad = {}
for _, model in workspace.Props:GetChildren() do
	if model:IsA("Model") then
		local cf, size = model:GetBoundingBox()
		local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
		params.FilterDescendantsInstances = { model }
		local hit = workspace:Raycast(bottom + Vector3.new(0, 1, 0), Vector3.new(0, -50, 0), params)
		if not hit then
			table.insert(bad, model.Name .. ": no ground below")
		elseif math.abs(hit.Position.Y - bottom.Y) > TOL then
			table.insert(bad, ("%s: floats %.2f studs"):format(model.Name, bottom.Y - hit.Position.Y))
		end
	end
end
print(#bad == 0 and "all grounded" or table.concat(bad, "\n"))
```

Other probe patterns from the reference project:
- **Predicted versus actual counts.** An offline tool predicted how many instances an install would create; the Studio side reported the real count; a mismatch meant something else had changed.
- **Fingerprints before writes.** Before installing a re-baked animation clip, the installer compared the live clip's instance count, keyframe count, weighted pose count and a checksum against the values recorded when the clip was dumped. On mismatch it refused: "changed since it was dumped". This catches the case where another person or agent edited the target after you read it.
- **Model versus engine.** Offline animation maths was checked against the real `Animator` stepping the clip in Edit; a difference over 3 degrees blocked installation.
- **Thresholds that block.** "Do not install if a new critical appears or the score went down." Verification that never says no is decoration.

### Rung 6-8

- Write the play-test request as steps with observable outcomes, so the human tester (or the beta playtest subagent, see [[Roblox Studio Assistant]]) can pass or fail it quickly.
- Anything involving uploaded assets, animation ids, `HttpService` secrets, data stores or multiple players needs at least rung 7.

---

## 4. Verifying non-code output

| Output | Fast check | Deeper check |
|---|---|---|
| Explanation of an engine behaviour | Find the sentence in the reference page | Measure it in Studio |
| A number (limit, price, rate) | Find it on an official page with a date | Note "as of" and re-check before release |
| Mesh | Bounds, triangle count, pivot, facing | Next to a reference model at gameplay distance ([[Exporting and Validating Models for Roblox]]) |
| Texture or material | Tiling offset test, three distances | On target devices ([[Mobile and Low-End Optimization]]) |
| Image (icon, thumbnail) | Side by side with the real item | At display size on a phone |
| Audio | Licence terms, peak and loudness | In the mix with music and other SFX |
| Animation | On the real rig, markers fire | In a live server with the real character scale |
| Translations | Back-translate a sample | A native speaker ([[Localization]]) |

---

## 5. Verifying claims from agents

Agents summarise their own work, and summaries drift towards success. Ask for:

1. **A list of every change**: object paths, files, attributes. Then spot-check two.
2. **What was not done**: the honest remainder. The reference project's reports always ended with "Manual left: ..." (for example: publish the clips, play-test, import the model).
3. **The verification rung** reached for each change.
4. **Backups**: where the safety copy is and how to roll back.

If an agent cannot say how it verified something, it did not verify it.

---

## 6. Calibrating trust

Trust is per task type, not per tool. Keep a rough log: which kinds of output from which tool needed fixing? After a few weeks you will know, for example, that your agent's data plumbing is nearly always right, its UI layout is often off by a few pixels, and its explanations of physics ownership need checking every time. Spend verification effort where the log says errors live.

Rules of thumb from the reference project:
- **High trust after checks:** offline maths with numeric tests, bulk renames with a grep afterwards, generators that are deterministic.
- **Medium:** gameplay code (needs a play test), UI (needs eyes on several screen sizes).
- **Low:** anything visual judged only by the agent, anything claimed about live servers from Studio tests, generated art.

## Common mistakes

- Asking "does it work?" and accepting "yes".
- Verifying in Studio and shipping features that depend on live-only behaviour.
- Relying on screenshots an agent says it took, when the capture may have been black.
- Thresholds that report but never block.
- Removing the human play-test because the AI "tested it".
- Reports without a "not done" section.

## Checklist

- [ ] Prompt states context, rules, API era and what done means.
- [ ] Each change verified to a named rung; the rung is reported.
- [ ] Live-only dependencies tested in a live or team-test server.
- [ ] Numbers carry a source and a date.
- [ ] Writes guarded by fingerprints where others may edit the same targets.
- [ ] Reports list changes, backups, what was not done, and "not play-tested" where true.

## See also
[[AI Code Assistants for Luau]] · [[AI Agents and Autonomous Workflows]] · [[Safety Rules for AI Agents in Studio]] · [[Testing Strategies and Frameworks]] · [[QA Checklists Before Release]] · [[Debugger Breakpoints and Logging]] · [[Engine Gotchas]] · [[Lessons Learned Index]]

## Connected notes
<!-- auto-links:start -->
[[MCP Workflows for Scripting and Debugging]] · [[AI in Roblox Development Overview]] · Working with AI Assistants in Studio · Case Study - Building a Game with AI Agents · Agent Review Loops and Guardrails in Practice · Roblox Studio MCP Server
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Evaluating AI Tools - A Practical Rubric]] · [[What AI Models Get Wrong in Roblox]] · [[Local vs Cloud AI - Keeping Unreleased Game Code Private]] · [[AI Animation and Motion from Video]] · [[AI Asset Pipelines - Scoring, Reviewers and Spot Checks]] · [[Agent Orchestration - Sub-Agents, Hooks and Skill Costs]] · [[AI Audio - Voice Music and SFX]] · [[Token Cost Benchmarks]]
<!-- related:end -->
