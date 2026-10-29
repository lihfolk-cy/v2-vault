---
tags: [testing, static-analysis, linting, hooks, code-review, ai-agents, luau, tooling, type/guide, area/performance, level/intermediate, api/DataStore]
---
# Automated Luau Checks - LihFolk Hook and Audit

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Adding `lihfolk-ignore` to make the feedback stop instead of fixing the line.
> - Avoid: Treating a clean hook run as a security review.
> - Avoid: Wrapping a DataStore call in `pcall` but ignoring the success flag, then saving over data that failed to load.
>
> Cost: TL;DR ~110 tok · whole note ~1.6k tok. Read more: ## 1. Where it sits in the workflow · ## 2. What it catches · ## Common mistakes
<!-- tldr:end -->

The LihFolk plugin ships a PostToolUse hook that checks Luau the moment an AI agent writes it. It targets the mistakes that cost the most on Roblox and are easy to miss in review: unprotected DataStore calls, broken `ProcessReceipt`, client-owned currency, unvalidated remotes, loops that freeze a server, and leaked connections. This note explains what it catches, how to act on a finding and where it stops. Implementation details and the full rule table live in the plugin's `hooks/README.md`.

Source labels: **Docs** (Claude Code docs, as of October 2026), **Rule of thumb**.

---

## 1. Where it sits in the workflow

| Stage | Tool | Catches |
|---|---|---|
| While writing | the LihFolk hook (this note) | Roblox-specific runtime, data, money and exploit mistakes |
| While writing | luau-lsp, Selene, StyLua ([[External Tooling - Rojo Wally Selene StyLua]]) | type errors, general lint, formatting |
| Before release | `/lihfolk:audit`, then [[QA Checklists Before Release]] | whole-system review, hard gates, ranked fixes |
| In Studio | specs and play tests ([[Testing Strategies and Frameworks]]) | behaviour the static checks cannot see |

The hook does not replace tests or a human review; it removes the cheap, repeated mistakes before they reach either.

## 2. What it catches

| Area | Rule ids | Why it matters |
|---|---|---|
| Deprecated scheduler | `deprecated-wait`, `deprecated-spawn`, `deprecated-delay` | throttled, late resumes ([[Task Library Coroutines and Yielding]]) |
| Instances | `instance-new-parent`, `findfirstchild-chain` | half-built replication, "attempt to index nil" ([[Instances Attributes and Tags]]) |
| Remotes | `remote-unvalidated-args`, `remote-invokeclient` | exploiters send anything; a client can hang the server ([[Server Authority and Validation]]) |
| Data | `datastore-no-pcall`, `datastore-setasync-player`, `datastore-no-bindtoclose` | lost saves, overwritten progress, shutdown loss ([[DataStore Fundamentals]], [[Saving Correctly - Autosave and BindToClose]]) |
| Purchases | `receipt-bad-return`, `receipt-no-idempotency`, `receipt-grant-before-save` | double grants and paid-but-not-granted ([[Developer Products and ProcessReceipt]], [[Purchase Data and Receipts]]) |
| Policy | `paid-random-no-policy` | paid random items need the PolicyService gate and odds ([[Paid Random Items and Odds Disclosure in Practice]]) |
| Runtime | `while-true-no-yield`, `connect-in-loop` | frozen servers, growing memory ([[Events Signals and Connections]], [[Memory Budgets and Leaks]]) |
| Trust boundary | `client-sets-currency` | client changes never reach the server ([[How Exploits Work - The Client Boundary]]) |

Severity drives the feedback: errors and warnings are sent to the agent as a blocking reason, info findings as extra context.

## 3. How the hook decides what to report

- Comments and string contents are stripped first, so `-- wait(5)` or `"store:GetAsync"` in text never fire.
- Blocks are tracked, so a DataStore call inside `pcall(function() ... end)` or inside a function the file passes to `pcall` by name counts as protected, and a `task.wait` inside a spawned function does not count as a yield for the loop around it.
- After an Edit, only findings on the edited lines are reported, so legacy code does not nag on every small change. After a Write, the whole file is reported.

## 4. Reading a finding

Each finding gives the line, the rule id, the reason, a fix hint and the vault note. Fix order for an agent (Rule of thumb):

1. Errors first: data, purchases, client currency, freezing loops.
2. Then warnings on server code (remotes, receipts, leaks).
3. Info last, and only if the fix is local.

If the finding is wrong, prove it (for example, the argument is validated inside the module it is forwarded to) and add `-- lihfolk-ignore: <id> - validated in ShopService.validate` on that line or the line above. `-- lihfolk-ignore-file: <id>` silences a rule for the whole file. Never ignore an error-level rule without a reason a reviewer can check.

## 5. The audit command

`/lihfolk:audit [path]` runs the checker over every Luau file (vendored Packages and _Index folders skipped), maps remotes, data, money and per-frame code, reviews them with the secure-remotes, datastore-safety, anti-exploit and performance-audit skills, marks the system rubric hard gates, and returns a ranked fix list from P0 (data, money, exploits) to P3 (hygiene). Run it before a release and after merging a large AI-written change.

## 6. Limits

- It is pattern and block based, not a type checker; it does not follow `require`, so validation or saving done in another module is invisible to it.
- Client scripts are recognised by path (`.client.luau`, StarterPlayerScripts, StarterGui, ReplicatedFirst and similar).
- Heuristic rules (remote validation, grant-before-save, paid random items) are tuned to stay quiet when unsure; a clean run is not proof of safety.

## Common mistakes

- Adding `lihfolk-ignore` to make the feedback stop instead of fixing the line.
- Treating a clean hook run as a security review.
- Wrapping a DataStore call in `pcall` but ignoring the success flag, then saving over data that failed to load.
- Fixing `wait` to `task.wait` inside a polling loop that should have been an event.

## See also

[[External Tooling - Rojo Wally Selene StyLua]] · [[Testing Strategies and Frameworks]] · [[QA Checklists Before Release]] · [[Testing Your Own Remotes - Fuzzing and Abuse Tests]] · [[Skill - Roblox Secure Remotes]] · [[Skill - Roblox DataStore Safety]] · [[Hunting Memory Leaks Step by Step]]

<!-- related:start -->
## Related
[[Code Review for Luau Teams]] · [[AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well]] · [[StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs]] · [[Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins]] · [[Automated Testing with TestEZ and Jest-Lua]] · [[Gated Tester Commands and Debug Panels]] · [[Genre QA Passes - Test Checklists per Game Type]] · [[In-Game Bug Report Button with Automatic Context]] · [[Testing Time-Based Features with a Controllable Clock]] · [[Load and Soak Testing Servers - Long Sessions and Many Clients]]
<!-- related:end -->
