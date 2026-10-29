---
description: 'Audit a Roblox project''s Luau: checker on every file, then a ranked security, data, exploit and performance fix list'
argument-hint: [path to scan, default: project root]
---

Audit the Roblox code under: $ARGUMENTS (if empty, use the project root). This is a review: do not change code unless the user asks; offer to fix the top items at the end.

## 1. Run the checker (automated pass)

Run the LihFolk checker over the path with whichever shell tool you have. Exit code 1 only means it found an error-level issue; read the output either way.

- Bash tool (macOS, Linux, Windows with Git Bash):
  `sh "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/lihfolk-check.sh" --scan "<path>"`
- PowerShell tool (Windows without Git Bash):
  `powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/lihfolk-check.ps1" -Scan "<path>"`

Each line is `file:line: severity id: message | fix | note`. Vendored folders (Packages, _Index, node_modules) are skipped. The rules, their heuristics and the ignore comment are described in `${CLAUDE_PLUGIN_ROOT}/hooks/README.md`.

The checker is regex and block-structure based, not a type checker. Treat every finding as a lead: open the line, confirm or dismiss it, and say why when you dismiss one. Existing `-- lihfolk-ignore: <id>` comments are the project's earlier decisions; mention them only if the reason no longer holds.

## 2. Map the project (what the checker cannot see)

Grep the path before reviewing, so the review covers whole systems rather than single lines:
- entry points: `OnServerEvent`, `OnServerInvoke`, `InvokeClient`, `Touched`, `ProximityPrompt`, `ClickDetector`;
- data: `GetDataStore`, `GetOrderedDataStore`, `UpdateAsync`, `SetAsync`, `ProfileStore`/`ProfileService`, `BindToClose`, `PlayerRemoving`;
- money: `ProcessReceipt`, `PromptProductPurchase`, `UserOwnsGamePassAsync`, `MarketplaceService`, `PolicyService`, `math.random`/`Random.new` near anything bought with Robux;
- runtime cost: `while true`, `Heartbeat`/`RenderStepped`, `:Connect(` inside loops or per-frame handlers, `Instance.new` in hot paths.

Note which files are server, client (`.client.luau`, StarterPlayerScripts, StarterGui, ReplicatedFirst) and shared.

## 3. Review with the LihFolk skills, in this order

Use each skill's review procedure and hard rules, and read the vault notes it lists when a finding needs evidence:
1. `roblox-secure-remotes` ("Procedure for a review"): every remote handler, its validation (type, range, ownership, rate) and anything the client is trusted with.
2. `roblox-datastore-safety`: load and save paths, pcall and retries, session locking, UpdateAsync vs SetAsync, autosave, BindToClose, receipts and idempotency.
3. `roblox-anti-exploit-review`: threat model of the economy and combat, duplication races, purchase abuse, fair enforcement.
4. `roblox-performance-audit`: leaks, unyielding loops, per-frame work and allocations, instance churn. Without Studio measurements, label performance findings "static, not measured".
5. If paid random items exist, also apply `roblox-monetization-compliance` (odds shown before purchase, `PolicyService` gate that fails closed).

## 4. Check the system rubric hard gates

Open `${CLAUDE_PLUGIN_ROOT}/skills/quality-score/rubrics/system.md` and mark each hard gate PASS, FAIL or UNKNOWN (with the file and line that decides it). Any FAIL caps a system score at 5.0. Give a provisional rubric estimate only if the evidence supports one, and say it is a reviewer's estimate; suggest `/lihfolk:council` for an independent score.

## 5. Report: ranked fix list

Rank by impact, then likelihood, then effort:
- **P0 (fix before publishing):** lost or duplicated player data or purchases, client-controlled currency, items or damage, exploitable remotes, ProcessReceipt errors, paid random items without the policy gate or odds.
- **P1:** server or client freezes and crashes (unyielding loops, InvokeClient hangs), unprotected DataStore calls, missing BindToClose.
- **P2:** memory leaks, per-frame waste, connection buildup, replication churn.
- **P3:** deprecated APIs, `Instance.new` parent argument, unchecked `FindFirstChild` chains, style.

Output, in this order:
1. One line: files scanned, checker counts (error, warning, info), confirmed vs dismissed findings.
2. **Ranked fix list** table: `# | P | Area | File:line | Problem | Why it matters (LihFolk note) | Fix | Effort (S/M/L) | Source (checker id or skill)`. Group repeats of the same pattern into one row with a count and the first few locations.
3. **Hard gates** table from step 4.
4. **Dismissed findings**: id, location, one-line reason (these are candidates for a `-- lihfolk-ignore: <id>` comment).
5. **Next steps**: the top 3 fixes you would do first, and an offer to apply them.
