---
tags: [team, code-review, luau, quality, security, git, workflow, strict-mode, type/guide, area/production, level/intermediate, api/BindToClose]
---
# Code Review for Luau Teams

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Reviewing top to bottom -> Risk order: trust, data, yields, lifecycle, types, contracts, style
> - Avoid: Remote parameters typed as concrete types -> Type as `unknown`, narrow at runtime
> - Avoid: Huge pull requests -> Size limit, contract-first splits
> - Checks (StyLua, Selene, luau-lsp, tests) pass before anyone reviews.
> - Reviewer reads in risk order and asks "what if this runs twice?" for every grant.
> - Every remote argument typed `unknown` and validated; rate limits present.
>
> Cost: TL;DR ~160 tok · whole note ~4.7k tok. Read more: ## 2. The review order · ## 3. Luau smells with fixes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Code review on Roblox teams is usually either absent ("we all edit live, it's fine") or a rubber stamp on a pull request nobody reads. Neither catches what actually breaks Roblox games: a remote handler that trusts the client, a save that yields inside `PlayerRemoving` and is lost on shutdown, a connection that leaks once per round, a `::` cast that hides a nil. This note is a working review practice for small Luau teams: what to review in what order, the Luau-specific smells with before and after code, how to review when your code lives only in Studio, what to automate so humans do not argue about formatting, how to review AI-generated code, and how to keep review fast enough that people do not route around it.

It builds on the repository and CI setup in [[Code Pipeline - Rojo Git and CI]] and [[Git and Source Control for Roblox]] (which has a short review checklist), the tool configuration in [[External Tooling - Rojo Wally Selene StyLua]], and the rubric and independent-judge practice in [[Team Roles and Workflows]].

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. What review is for, on Roblox specifically

Tests and review catch different bugs. Automated tests ([[Automated Testing with TestEZ and Jest-Lua]]) are good at logic: does the damage formula return the right number. Review is good at things tests rarely cover in Roblox code:

| Class of bug | Why tests miss it | Why review catches it |
|---|---|---|
| Trusting client input in a remote | Tests call the handler with valid arguments | A reviewer asks "what if the client sends `-1`, `NaN`, or another player's id?" |
| Data loss on shutdown | Shutdown is hard to simulate | A reviewer sees the yield in `BindToClose` or the missing retry |
| Leaks over long sessions | Tests run for seconds | A reviewer sees a `:Connect` with no matching cleanup |
| Race conditions on join or respawn | Timing differs in Studio | A reviewer asks what happens if the character is nil here |
| Contract breaks between client and server | Each side tests alone | A reviewer sees the remote's argument order changed |
| Economy holes | Tests check the happy path | A reviewer asks "can this be called twice?" |

So the first rule: **review for consequences, not style.** Style is a tool's job (section 6).

---

## 2. The review order

Reviewers who read top to bottom spend their attention on variable names in the first file and skim the remote handler in the last. Read in risk order instead (rule of thumb):

1. **Trust boundaries.** Every `OnServerEvent`, `OnServerInvoke`, `ProcessReceipt`, and anything reading attributes or values the client can write. Is every argument type-checked, range-checked and rate limited? ([[Server Authority and Validation]], [[Remote Abuse Patterns and Rate Limiting in Practice]])
2. **Persistence.** Every DataStore call, every change to the save schema, every grant of currency or items. Retries, idempotency, session locking, migrations ([[DataStore Fundamentals]], [[Saving Correctly - Autosave and BindToClose]]).
3. **Yields and ordering.** Anything that can yield (`WaitForChild`, `:InvokeClient`, web calls, DataStore calls, `task.wait`) inside a callback where yielding causes harm. ([[Task Library Coroutines and Yielding]])
4. **Lifecycle.** Connections, threads, instances created per player or per round: who cleans them up? ([[Memory Budgets and Leaks]], [[Events Signals and Connections]])
5. **Types and nil.** Casts, optional values, `FindFirstChild` results ([[Luau Type System and Strict Mode]]).
6. **Contracts.** Remote names and argument shapes, module return shapes, attribute names. Who else depends on them?
7. **Readability.** Only now: names, structure, comments.

A pull request that touches none of 1 to 4 can be reviewed in five minutes. One that touches 1 or 2 deserves a slow, line-by-line read and possibly a second reviewer.

---

## 3. Luau smells with fixes

Each smell below is something a reviewer can spot in a diff. The code is strict Luau.

### 3.1 Unvalidated remote arguments

```lua
-- Before: trusts type, range and ownership.
BuyItem.OnServerEvent:Connect(function(player, itemId, quantity)
	Shop.buy(player, itemId, quantity)
end)
```

```lua
--!strict
-- After: validate everything the client controls; the server decides the price.
local MAX_QUANTITY = 99

BuyItem.OnServerEvent:Connect(function(player: Player, itemId: unknown, quantity: unknown)
	if typeof(itemId) ~= "string" or #itemId > 64 then
		return
	end
	if typeof(quantity) ~= "number" or quantity ~= quantity then -- NaN fails x == x
		return
	end
	local q = math.floor(quantity)
	if q < 1 or q > MAX_QUANTITY then
		return
	end
	if not RateLimit.allow(player, "BuyItem", 5, 1) then -- 5 per second
		return
	end
	Shop.buy(player, itemId, q) -- Shop looks up the price server-side
end)
```

What to look for in review: parameters typed as concrete types in a remote handler (`quantity: number`) are a smell. The type annotation does not check anything at runtime; the client can send anything. Type remote parameters as `unknown` and narrow them.

### 3.2 Yields where yields lose data

```lua
-- Before: a yield before the save inside PlayerRemoving.
Players.PlayerRemoving:Connect(function(player)
	local leaderstats = player:WaitForChild("leaderstats") -- may never resolve
	Profiles.save(player)
end)
```

The reviewer's question: what if `leaderstats` never existed (player left during load)? The handler hangs forever and never saves. Also check that `BindToClose` waits for in-flight saves ([[Saving Correctly - Autosave and BindToClose]]).

```lua
--!strict
-- After: no yields before the save; read state from the profile, not the instance tree.
Players.PlayerRemoving:Connect(function(player: Player)
	Profiles.release(player) -- saves from in-memory data and releases the session lock
end)
```

### 3.3 Leaked connections

```lua
-- Before: a new connection every round, never disconnected.
function Round.start(arena: Model)
	arena.Goal.Touched:Connect(onGoal)
end
```

```lua
--!strict
-- After: the round owns its connections and cleans them up.
local roundConnections: { RBXScriptConnection } = {}

function Round.start(arena: Model)
	local goal = arena:FindFirstChild("Goal")
	assert(goal and goal:IsA("BasePart"), "arena is missing a Goal part")
	table.insert(roundConnections, goal.Touched:Connect(onGoal))
end

function Round.stop()
	for _, c in roundConnections do
		c:Disconnect()
	end
	table.clear(roundConnections)
end
```

Review heuristic: count the `:Connect` calls in the diff and find the matching cleanup for each, or a reason none is needed (the instance is destroyed, which disconnects its own events; or the connection is meant to last for the server's life).

### 3.4 Casts that hide nil

```lua
-- Before: the cast silences the type checker, not the bug.
local hum = character:FindFirstChild("Humanoid") :: Humanoid
hum.Health -= damage
```

```lua
--!strict
-- After: narrow, and decide what to do when it is missing.
local hum = character:FindFirstChildOfClass("Humanoid")
if not hum or hum.Health <= 0 then
	return
end
hum:TakeDamage(damage)
```

Review heuristic: every `::` in a diff deserves a question. A cast is a claim the author is making to the type checker; ask what makes it true. Casts on `FindFirstChild`, `GetAttribute` and remote arguments are the usual false claims.

### 3.5 Name lookups that find the wrong child

`FindFirstChild` returns the first child with that name. **Measured in the reference project:** an animation clip named `Origin` was placed under the same parent as a RemoteEvent called `Origin`; the lookup found the clip, and damage stopped working for that whole weapon kit ([[Team Roles and Workflows]] lists the forbidden-names rule that followed). In review, flag lookups by name under folders that mix content and code, and prefer `FindFirstChildOfClass`, a typed lookup that checks `IsA`, or keeping remotes in their own folder.

### 3.6 Errors swallowed by `task.spawn` or `pcall`

```lua
-- Before: a pcall that hides every failure.
pcall(function()
	store:SetAsync(key, data)
end)
```

```lua
--!strict
-- After: check the result, log with context, retry where the operation is safe to repeat.
local ok, err = pcall(function()
	store:SetAsync(key, data)
end)
if not ok then
	warn(`save failed for {key}: {err}`)
	SaveQueue.retryLater(key) -- bounded retries with backoff
end
```

Review heuristic: a `pcall` whose first return value is ignored is almost always wrong. See [[Error Handling and Retries]] and [[Error Handling - pcall xpcall and Promise Patterns]].

### 3.7 Grants that can run twice

Any code that gives currency or items should be idempotent: running it twice with the same input must not grant twice. Look for grants keyed on nothing (a quest reward granted in a `Touched` handler with no "already claimed" flag in the save), and for `ProcessReceipt` handlers that grant before recording the purchase id ([[Developer Products and ProcessReceipt]]). This single question, "what happens if this runs twice?", finds more economy bugs than any other review question (rule of thumb).

### 3.8 Side effects at require time

A ModuleScript that connects events, starts loops or reads players when required runs that code at whatever moment the first `require` happens, which differs between Studio, live servers and tests. Prefer modules that return a table and an explicit `start()` called from the bootstrapper ([[Project Structure and Bootstrapping]]).

---

## 4. Sizing and speed

Reviews that take days are routed around. Reviews of 2,000-line diffs are rubber stamps. The two numbers that matter (rule of thumb):

- **Size:** aim for under about 400 changed lines of Luau per pull request; a reviewer can read that properly in 20 to 30 minutes. Mechanical changes (renames, formatting) go in their own pull request so they do not hide logic.
- **Turnaround:** first response within one working day. On a team of three, that means each person reviews something most days.

Ways to keep diffs small on Roblox projects:

- **Land the contract first.** A pull request that adds the remote, its validation and an empty handler, then a second that fills in the behaviour.
- **Feature flags** let unfinished code merge without being live ([[Feature Flags and Staged Rollouts]]).
- **Data changes separate from code changes.** Config tables of prices or drop rates are reviewed by the designer, not the programmer ([[Data and Config Pipeline - Spreadsheets to Game]]).

---

## 5. Comments: severity labels and tone

Label every comment so the author knows what blocks merging (rule of thumb, adapted from common practice):

| Label | Meaning | Example |
|---|---|---|
| **blocking** | Must change before merge: correctness, security, data | "blocking: `quantity` is not range checked; a client can send 1e9" |
| **should** | Strongly suggested, author may disagree with a reason | "should: move this loop to Heartbeat; RenderStepped runs on clients only" |
| **question** | Reviewer does not understand; not a request | "question: why does this wait 0.5 s before saving?" |
| **nit** | Optional polish | "nit: `t` could be `targetPlayer`" |

Tone rules: comment on the code, not the person; ask before asserting when you are not sure; suggest the fix when you can; approve with "should" comments outstanding when you trust the author to handle them. Young developers are common on Roblox teams; a review that reads as a scolding loses a teammate ([[Documentation and Onboarding New Developers]]).

---

## 6. Automate the arguments away

Humans should never comment on formatting, unused variables or obvious type errors. Run these before review, locally and in CI ([[Code Pipeline - Rojo Git and CI]] has a full workflow):

| Tool | What it removes from review | Minimal setup |
|---|---|---|
| **StyLua** | All formatting debate | `.stylua.toml` in the repo; CI runs `stylua --check src` |
| **Selene** | Unused variables, shadowing, suspicious patterns, deprecated APIs | `selene.toml` with `std = "roblox"`; CI runs `selene src` |
| **luau-lsp analyze** | Type errors across files, with a sourcemap from Rojo | `rojo sourcemap` then `luau-lsp analyze` with Roblox definitions |
| **Tests** | Logic regressions | TestEZ or Jest-Lua run headlessly ([[Automated Testing with TestEZ and Jest-Lua]]) |

A rule that makes this stick: **a pull request with failing checks is not reviewed.** It saves reviewers' time and teaches people to run checks locally. Tool flags and file names change between versions; pin tool versions in the toolchain file and check each tool's README when upgrading (rule of thumb; the vault's tooling note has tested configurations as of October 2026).

Also require `--!strict` on new files. Strict mode does not catch runtime trust problems, but it removes a whole category of nil and typo bugs before a human looks.

---

## 7. Reviewing when code lives only in Studio

Many teams have no Git. Review is still possible; it is just less convenient.

| Mechanism | How to use it for review | Limits |
|---|---|---|
| **Drafts** | Author works in a draft; before committing, a reviewer joins the session, and the author walks through **Compare With Server** | Drafts live on the author's machine; the reviewer cannot open them independently |
| **Script History** | After a commit or save, the reviewer opens View Script History and compares the version with the previous one (Roblox docs) | One script at a time; no multi-file view |
| **Pairing** | The reviewer uses **Join** in Live Collaborators to follow the author's editor | Needs both online at once |
| **Changelog line** | Author lists every script touched; reviewer checks each | Manual |

**Measured in the reference project:** the team had no pull requests for most of its life. What worked instead was a running changelog where every change recorded what, where, how to undo it and whether it was play-tested, plus independent review rounds against a written rubric for UI work ([[Team Roles and Workflows]], [[Release Process and Rollbacks]]). The changelog made "what did this change touch?" answerable, which is the precondition for any review.

If your team has more than two scripters and real money flowing, moving code to files with Script Sync or Rojo pays for itself mainly through review ([[External Tooling - Rojo Wally Selene StyLua]]).

---

## 8. Reviewing AI-generated code

AI assistants write a growing share of Luau ([[AI Code Assistants for Luau]], [[Working with AI Assistants in Studio]]). Their output fails in recognisable ways, so review it with a specific lens (rule of thumb, consistent with [[Prompting and Verifying AI Output]]):

- **Invented APIs.** A method or property that sounds right and does not exist. Strict mode and luau-lsp catch many; check anything unfamiliar against the API reference.
- **Deprecated patterns.** `wait()`, `spawn()`, `delay()` instead of the `task` library; `RenderStepped` on the server; `Instance.new(class, parent)` before setting properties.
- **Trust in the client.** Generated shop and combat code often accepts a price or damage from the client.
- **Plausible but untested edge cases.** Comments claiming "handles disconnects" over code that does not.
- **Size.** Generators produce large diffs quickly. Apply the same size limit; ask for it split.

Require the author, not the tool, to answer review questions. "The assistant wrote it" is not an answer to "what happens if this runs twice?".

---

## 9. Reviewing non-code changes

Roblox teams change a lot that is not code: UI layouts, lighting, map areas, sounds. These benefit from review too, with different tools:

- **UI:** screenshots at phone, tablet and desktop sizes against a rubric written before the work started ([[Case Study - Phone UI Overhaul]]).
- **World edits:** a before and after capture from fixed camera positions, plus counts (instances, triangles) against budgets ([[Art Budgets - Triangles Draw Calls Memory]]).
- **Sounds:** loudness measured against the reference table, not judged by ear in a noisy room.
- **Config and economy data:** a designer reviews the numbers; a programmer reviews only that the format is valid.

---

## 10. When not to require review

- **Incident hotfixes.** Ship the fix, then review it within a day. Write "post-review" in the changelog so it is not forgotten ([[Live Incident Response and Post-Mortems]]).
- **Solo projects.** Self-review still helps: read your diff the next morning in risk order.
- **Throwaway prototypes** in a separate place. Review starts when code moves toward the live game.

---

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Reviewing top to bottom | Style comments on file one, remote handler skimmed | Risk order: trust, data, yields, lifecycle, types, contracts, style |
| Remote parameters typed as concrete types | Reviewer assumes they are checked | Type as `unknown`, narrow at runtime |
| Huge pull requests | Approved in minutes | Size limit, contract-first splits |
| Formatting comments | Long threads about tabs | StyLua and Selene in CI |
| `pcall` result ignored | Silent data loss | Blocking comment; check and log |
| "The AI wrote it" | Unanswered questions | Author owns every line |
| No review for Studio-only teams | Bugs found by players | Drafts compare, Script History, changelog |

## Checklist

- [ ] Checks (StyLua, Selene, luau-lsp, tests) pass before anyone reviews.
- [ ] Reviewer reads in risk order and asks "what if this runs twice?" for every grant.
- [ ] Every remote argument typed `unknown` and validated; rate limits present.
- [ ] No yields before saves in `PlayerRemoving` or `BindToClose`.
- [ ] Every `:Connect` has a cleanup or a reason.
- [ ] Every `::` cast justified.
- [ ] Comments labelled blocking, should, question or nit.
- [ ] Pull requests under about 400 lines; first response within a working day.
- [ ] Studio-only teams: drafts compare or Script History review, plus a changelog line per change.

## Connected notes
<!-- auto-links:start -->
[[Team Collaboration Start Here]] · [[Agent Review Loops and Guardrails in Practice]] · [[Team Create Permissions and Workflows]] · Team Create and Collaboration · Links - External tooling · Testing Strategies and Frameworks
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Automated Luau Checks - LihFolk Hook and Audit]] · [[MCP Workflows for Scripting and Debugging]] · [[Team Create and Collaboration]] · [[Packages and Shared Assets Across Places]] · [[Cookbook - Remotes and Networking]] · [[Working with Contractors and Revenue Splits]]
<!-- related:end -->
