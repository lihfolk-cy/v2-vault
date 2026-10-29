# LihFolk Roblox check (PostToolUse hook)

Every time Claude writes or edits a `.lua` / `.luau` file, this hook scans it for well-known Roblox mistakes and hands the findings back to Claude, which then fixes them in the same turn. The same checker powers `/lihfolk:audit`, which scans a whole project and adds a prioritised review.

Files: `hooks.json` (the hook), `scripts/rules.tsv` (ids, severities, messages, fixes, vault notes), `scripts/lihfolk-check.sh` + `scripts/lihfolk-check.awk` (POSIX engine), `scripts/lihfolk-check.ps1` (PowerShell engine).

## How the feedback reaches Claude

Claude Code runs the hook after the Write, Edit or MultiEdit tool succeeds (`"matcher": "Write|Edit|MultiEdit"`) and sends it the event as JSON on stdin: `tool_name`, `tool_input.file_path`, and for edits `tool_input.new_string` (or `edits[].new_string` for MultiEdit). The checker reads the file from disk and prints one JSON object on stdout, exit code 0:

- any **error**: `{"decision": "block", "reason": "..."}`. Warnings and info come back as `additionalContext` (no forced extra turn), which keeps edits fast; Claude still sees them. For PostToolUse, `block` does not undo anything (the tool already ran); Claude Code shows the `reason` to Claude next to the tool result.
- only **info** findings: `{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "..."}}`, a softer note added to Claude's context.
- nothing found: no output.

Exit code 2 with stderr would also reach Claude, but JSON lets the hook choose between the strong and the soft channel. The hook never fails the session: if `awk` is missing, the input is unreadable or the file is not Luau, it exits 0 silently.

Each finding names the line, the rule id, the reason, a fix hint and the LihFolk note to read (`LihFolk Vault V2/...`). Up to 15 findings are listed per edit (`LIHFOLK_HOOK_MAX`), errors first.

**Edit scope.** After a Write the whole file is reported. After an Edit or MultiEdit only findings on lines the edit produced are reported (file-level findings count when one of their evidence lines was touched), so old code does not nag on every small change. `LIHFOLK_HOOK_SCOPE=file` reports the whole file every time.

## Runtime choice: no Python, no Node, one command line for every shell

Claude Code ships as a native binary; the npm package only installs that binary, which "does not itself invoke Node" (setup docs), so Node and Bun cannot be assumed. Python cannot be assumed either. What can be:

- macOS and Linux run shell-form hook commands with `sh -c`, and POSIX `sh`, `awk` and `find` are always there.
- Windows runs them in **Git Bash** when Git for Windows is installed (it brings `sh` and `awk`), otherwise in **PowerShell** (`pwsh.exe` if present, else Windows PowerShell 5.1, which every Windows has). In PowerShell, Claude Code rewrites `${CLAUDE_PLUGIN_ROOT}` to `${env:CLAUDE_PLUGIN_ROOT}`.

So the checker exists twice, an awk engine and a PowerShell engine that share `rules.tsv` and give identical reports, and `hooks.json` uses one command line that is valid in both shell families:

```
echo `# <#` >/dev/null; sh "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/lihfolk-check.sh"; exit $? #> >$null; powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/lihfolk-check.ps1"; exit $LASTEXITCODE
```

- **bash / sh / dash** read `` `# <#` `` as a command substitution holding only a comment (empty), run `lihfolk-check.sh`, then `exit`; everything after the ` #` is a comment.
- **PowerShell** reads `` `# `` as an escaped `#`, then `<# ... #>` is a block comment hiding the sh part, so it runs `lihfolk-check.ps1` through `powershell -File` (stdin is inherited, `-ExecutionPolicy Bypass` allows the local script).

Tested on Git Bash (bash, POSIX sh, dash) and Windows PowerShell 5.1 with no `sh` on PATH; the awk engine also runs under gawk `--posix` and `--traditional` (one-true-awk/mawk compatible, no gawk extensions).

## Checks

Severity: **error** = will lose data, money or freeze; **warning** = likely bug or exploit; **info** = robustness. Notes are under `LihFolk Vault V2/`.

| id | sev | flags | LihFolk note |
|---|---|---|---|
| `deprecated-wait` / `-spawn` / `-delay` | warning | global `wait(`, `spawn(`, `delay(` (and capitalised forms), unless the file defines its own | 02 Luau Scripting/Task Library Coroutines and Yielding |
| `instance-new-parent` | warning | `Instance.new(class, parent)` with a second argument | 02 Luau Scripting/Instances Attributes and Tags |
| `remote-unvalidated-args` | warning | `OnServerEvent` / `OnServerInvoke` handler (inline or named in the file) that uses a client argument directly with no `typeof`/`type`/`tonumber`/`IsA`/table lookup/validator call on it. Arguments only forwarded to another function are left to that function (heuristic) | 03 Architecture and Networking/Server Authority and Validation |
| `remote-invokeclient` | warning | any `:InvokeClient(` | 03 .../RemoteEvents RemoteFunctions and Unreliable Remotes |
| `datastore-no-pcall` | error | `:GetAsync/SetAsync/UpdateAsync/IncrementAsync/RemoveAsync(` not inside `pcall`/`xpcall`/Promise/retry wrapper, and not in a function the file passes to `pcall` by name. HttpService calls are skipped | 04 Data and Persistence/DataStore Fundamentals |
| `datastore-setasync-player` | warning | `SetAsync` on player-keyed data (line or file mentions UserId/player; OrderedDataStore files skipped) | 04 .../Session Locking and Profile Libraries |
| `datastore-no-bindtoclose` | warning | a `PlayerRemoving` handler saves (directly or through same-file functions) and the file has no `BindToClose` | 04 .../Saving Correctly - Autosave and BindToClose |
| `receipt-bad-return` | error | `ProcessReceipt` returns true/false/nil, has no `NotProcessedYet` path, or returns no decision (handlers that just `return Module.process(...)` are skipped) | 11 .../Developer Products and ProcessReceipt |
| `receipt-no-idempotency` | warning | `ProcessReceipt` in a file that never mentions `PurchaseId` | 04 .../Purchase Data and Receipts |
| `receipt-grant-before-save` | warning | a `.Value`/attribute/`+=` change in the handler before its first save call (profile-based handlers skipped; heuristic) | 04 .../Purchase Data and Receipts |
| `paid-random-no-policy` | warning | file uses `MarketplaceService` and `math.random`/`Random.new`/`NextInteger` but never `PolicyService`/`ArePaidRandomItemsRestricted` (heuristic, odds-disclosure rule) | 11 .../Paid Random Items and Odds Disclosure in Practice |
| `connect-in-loop` | warning | `:Connect(` inside a `while`/`repeat` loop or a Heartbeat/RenderStepped/Stepped handler, unless the connection is stored and the file disconnects (or uses Janitor/Maid/Trove) | 02 Luau Scripting/Events Signals and Connections |
| `while-true-no-yield` | error | `while true do` / `repeat ... until false` with no yield, `break` or `return` in the loop body (a call to a same-file function that yields counts; a yield inside a spawned function does not) | 02 .../Task Library Coroutines and Yielding |
| `client-sets-currency` | error | client script (`.client.luau`, StarterPlayerScripts, StarterGui, StarterCharacterScripts, StarterPack, ReplicatedFirst, "LocalScript" in the path) assigns `.Value` on leaderstats or a currency-named object, or `SetAttribute("Coins", ...)` | 22 Anti-Exploit and Security/How Exploits Work - The Client Boundary |
| `findfirstchild-chain` | info | `:FindFirstChild*(...)` immediately indexed (`.X`, `:M()`, `[k]`) | 02 .../Instances Attributes and Tags |

Before matching, comments and string contents are stripped (including `--[[ ]]`, `[==[ ]==]` and backtick strings), so text in comments or strings never triggers a rule. Blocks are tracked (`function`, `if`, `do`, loops, `repeat`, Luau if-expressions) so rules know whether a call sits in a loop, a `pcall` or a handler.

## Silencing a false positive

- `-- lihfolk-ignore: <id>[, <id>...]` at the end of the line, or alone on the line above (`all` silences every rule there). Add a reason after it.
- `-- lihfolk-ignore-file: <id>` anywhere in the file.
- `LIHFOLK_HOOK=off` in the environment turns the hook off.

## Running it yourself

- `sh hooks/scripts/lihfolk-check.sh --scan [path ...]`
- `powershell -NoProfile -ExecutionPolicy Bypass -File hooks/scripts/lihfolk-check.ps1 -Scan [path ...]`

Output: `file:line: severity id: message | fix | note`, then a summary; exit code 1 if any error. Folders named Packages, DevPackages, ServerPackages, _Index, node_modules and .git are skipped.

## Known limitations

- Heuristics, not a type checker: it does not resolve `require`d modules, so a remote validated inside another module, or a save done by a data module, is invisible (the rules are tuned to stay quiet rather than guess). Luau type annotations are not treated as validation, because they are not enforced at runtime.
- Client/server is decided from the path (Rojo-style names and Studio service folders); a client script in an unusual folder is not recognised.
- Multi-line constructs are approximated: a parameter list or `if` expression split over several lines may be missed.
- Edit scope matches edited lines by text, so a common one-liner elsewhere in the file can be reported too.
- Two engines must be kept in step: change both when changing a rule, and run the parity test (fixtures plus `run-tests.sh`) before releasing.

## Sources

- Hooks reference: plugin `hooks/hooks.json`, PostToolUse input, `decision`/`reason` and `additionalContext`, exit code 2 for PostToolUse, matcher syntax, `timeout`, shell selection and the PowerShell placeholder rewrite: https://code.claude.com/docs/en/hooks
- Plugin reference: `${CLAUDE_PLUGIN_ROOT}` (resolved in hook commands and in command Markdown), standard layout, quoting, `claude plugin validate`: https://code.claude.com/docs/en/plugins-reference
- Setup: native binary, npm package that "does not itself invoke Node", Git for Windows optional (PowerShell used without it): https://code.claude.com/docs/en/setup
