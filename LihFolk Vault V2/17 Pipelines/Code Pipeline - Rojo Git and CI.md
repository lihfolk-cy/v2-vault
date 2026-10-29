---
tags: [pipelines, code, rojo, git, ci, github-actions, open-cloud, testing, type/guide, area/pipelines, level/intermediate, api/SurfaceAppearance]
---
# Code Pipeline - Rojo Git and CI

<!-- tldr:start -->
> [!tldr] TL;DR
> - Changes in Studio vanish: Rojo synced files over Studio edits -> edit code only in files; keep mapped folders code-only
> - "Works on my machine" formatting or lint: unpinned tools -> Rokit-pinned versions
> - CI green, game broken: tests did not touch engine behaviour -> cloud tests for engine logic, play test for feel
> - Code in files, Rojo-mapped folders code-only
> - Tools pinned with Rokit; Wally for packages
> - StyLua, Selene, luau-lsp, Rojo build in CI on every PR
>
> Cost: TL;DR ~160 tok · whole note ~4.7k tok. Read more: ## Stage 4: local checks before commit · ## Stage 5: tests in CI with Open Cloud Luau execution · ## Failure modes · ## Checklist
<!-- tldr:end -->

Code is the content type with the best tooling outside Roblox and the worst inside it. Studio's script editor has no branches, no review and no diff between yesterday and today, and in Team Create two people can overwrite each other's script without a warning. The fix the community settled on is to keep code in files and sync it into Studio with **Rojo**, version it with **Git**, and check it with **CI**. This note is the full recipe, from repo layout to an automated publish, plus what to do when you cannot (yet) move to files. Tool introductions are in [[External Tooling - Rojo Wally Selene StyLua]] and [[Git and Source Control for Roblox]]; project structure in [[Project Structure and Bootstrapping]] and [[Module Scripts and Requiring]].

## The target pipeline

```text
edit .luau in VS Code (luau-lsp)          rojo serve  -> Studio plugin syncs files live
        |                                                 |
   git commit on a branch                         play-test in Studio
        |
   push -> CI: format check, lint, type check, build, tests (Open Cloud Luau execution)
        |
   review + merge to main
        |
   tag release -> CI: rojo build -> publish to test place -> smoke tests -> publish to live
```

Every arrow is automated except the edit, the play test and the review.

## Stage 1: repo layout and toolchain

A typical layout:

```text
my-game/
  rokit.toml              # pinned tool versions (rojo, wally, selene, stylua, luau-lsp)
  default.project.json    # Rojo: which folder maps to which service
  wally.toml              # package dependencies
  selene.toml             # lint config (std = "roblox")
  stylua.toml             # formatter config
  src/
    server/               # -> ServerScriptService
    client/               # -> StarterPlayer.StarterPlayerScripts
    shared/               # -> ReplicatedStorage.Shared
    serverstorage/        # -> ServerStorage
  tests/                  # test modules (TestEZ, Jest-Lua style or your own)
  tools/                  # Python/Node scripts: publish, run tests, generate config
  .github/workflows/ci.yml
```

Pin tool versions with a toolchain manager. Rojo's own docs recommend **Rokit** (`rokit add rojo-rbx/rojo`, then `rokit install`); it also reads older `aftman.toml` and `foreman.toml` files. Pinning means CI and every developer run the same Rojo, the same formatter and the same linter, so "it formats differently on my machine" disappears.

`default.project.json` (minimal):

```json
{
  "name": "my-game",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Shared": { "$path": "src/shared" },
      "Packages": { "$path": "Packages" }
    },
    "ServerScriptService": { "Server": { "$path": "src/server" } },
    "ServerStorage": { "$path": "src/serverstorage" },
    "StarterPlayer": {
      "StarterPlayerScripts": { "Client": { "$path": "src/client" } }
    }
  }
}
```

File naming conventions Rojo understands: `Foo.luau` is a ModuleScript, `Foo.server.luau` a Script, `Foo.client.luau` a LocalScript, and a folder with `init.luau` becomes a module whose children are the folder's other files.

## Stage 2: what stays in the place

Rojo manages the parts of the tree you map; everything else stays in the place file. Decide explicitly:

| In files (Rojo) | In the place |
|---|---|
| all scripts | maps, terrain, models, UI layouts if hand-built |
| config modules generated from data | lighting, sounds placed in the world |
| UI built by code | baked UI copies if your builders run in Studio ([[UI Asset Pipeline]]) |
| type definitions, tests | anything artists edit by eye |

**Partial management is fine and common.** Rojo leaves unmapped instances alone. The risk is mapping a folder that also holds hand-made instances: Rojo's sync will treat them as not in the source. Keep mapped folders code-only.

For fully managed places (everything built from files, including models as `.rbxm`/`.rbxmx`), `rojo build -o game.rbxl` produces a complete place file in CI. Most games are hybrid: code from files, world from the place.

## Stage 3: Git habits that matter for Roblox

- **Branch per change**, small PRs. A PR that touches 40 scripts cannot be reviewed.
- **Commit generated files deliberately.** Generated config modules (from spreadsheets) can be committed so the game builds without the generator, but mark them `-- GENERATED, do not edit` and regenerate in CI to check they are in sync ([[Data and Config Pipeline - Spreadsheets to Game]]).
- **Do not commit place files to Git as the main record.** Binary `.rbxl` does not diff. Use Studio version history or a separate artifact store for places; Git is for sources.
- **Ignore** `Packages/` (Wally installs it), `sourcemap.json`, build outputs.
- **Commit message tags** that match your changelog tags (`[LEVELS-2] re-measure kit sounds`) so `git log --grep` finds a pass.

## Stage 4: local checks before commit

Four tools, each fast:

| Tool | Command | Catches |
|---|---|---|
| StyLua | `stylua --check src` | formatting drift |
| Selene | `selene src` | lint: unused variables, shadowing, deprecated APIs, suspicious patterns |
| luau-lsp | `rojo sourcemap -o sourcemap.json` then `luau-lsp analyze --sourcemap=sourcemap.json --defs=globalTypes.d.luau src` | type errors, wrong property names, bad requires ([[Luau Type System and Strict Mode]]) |
| Rojo | `rojo build -o build.rbxl` | project file errors, missing paths |

The Roblox type definitions file (`globalTypes.d.luau`) comes from the luau-lsp project; download a pinned version in CI. Flags change between luau-lsp versions, so check `luau-lsp analyze --help` for yours.

Add project-specific gates as small scripts. Two that one production game found essential (measured in one production game):

- **Source size**: fail if any script's source is over about 195,000 characters; Studio refused sources over 200,000 characters in that project, and two core modules sat within 1,000 characters of it. Split before you hit it.
- **Use before definition**: fail if a `local function` is called on a line before it is defined at the same scope. Luau compiles that fine and crashes at runtime with "attempt to call a nil value".

```python
# tools/check_sources.py : size cap + a cheap use-before-definition heuristic
import pathlib, re, sys

CAP = 195_000
bad = 0
for p in pathlib.Path("src").rglob("*.luau"):
    text = p.read_text(encoding="utf-8")
    if len(text) > CAP:
        print(f"{p}: {len(text)} chars (cap {CAP})"); bad += 1
    defined_at = {m.group(1): text[: m.start()].count("\n") + 1
                  for m in re.finditer(r"^local function ([A-Za-z_]\w*)", text, re.M)}
    for name, line_def in defined_at.items():
        for m in re.finditer(r"(?<![\w.:])" + re.escape(name) + r"\s*\(", text):
            line = text[: m.start()].count("\n") + 1
            # only flag top-level calls (column 0 statements) before the definition
            line_text = text.splitlines()[line - 1]
            if line < line_def and not line_text.startswith(("\t", " ", "--")):
                print(f"{p}:{line}: {name}() called before its definition on line {line_def}"); bad += 1
sys.exit(1 if bad else 0)
```

The heuristic only flags top-level statements, which is where the real crashes happen (calls inside other functions usually run later, after the definition line has executed). A proper check walks the AST; the cheap one catches most cases.

## Stage 5: tests in CI with Open Cloud Luau execution

Unit tests for pure logic can run outside Roblox with **[[Lune]]** (a standalone Luau runtime) if your modules avoid engine APIs. Anything that touches the engine needs a real place. As of October 2026, Open Cloud offers **Luau Execution**: you POST a script to run against a place version on Roblox servers and poll for the result. Facts from the Roblox docs:

| Item | Value |
|---|---|
| Create task | `POST https://apis.roblox.com/cloud/v2/universes/{universeId}/places/{placeId}/luau-execution-session-tasks` (or `.../places/{placeId}/versions/{versionId}/luau-execution-session-tasks` for a specific version) |
| Poll | GET the task's `path` returned by create; `state` is `QUEUED`, `PROCESSING`, `COMPLETE`, `FAILED` or `CANCELLED` |
| Logs | GET `<task path>/logs` |
| Scopes | `universe.place.luau-execution-session:write` to create; read or write to get tasks and logs |
| Limits | script up to 4 MB; runs up to 5 minutes; return values up to 4 MB as JSON; logs keep up to 450 KB; at most 10 incomplete tasks per place (HTTP 429 beyond); task info kept 24 hours |
| Rate limits | create task 5 per minute per API key owner; get task 200 per minute; list logs 45 per minute |
| Sandbox | physics does not run; data model changes are local to the task and are not saved |

The flow in CI: build the place with Rojo, publish it as a **Saved** version to a dedicated **test place** (never the live place), run a test runner script there through Luau Execution, read the returned JSON, fail the job on any failure.

```python
# tools/run_cloud_tests.py : run the test runner in a test place via Open Cloud Luau Execution.
# env: RBX_API_KEY, TEST_UNIVERSE_ID, TEST_PLACE_ID
import json, os, sys, time, requests

KEY = os.environ["RBX_API_KEY"]
U, P = os.environ["TEST_UNIVERSE_ID"], os.environ["TEST_PLACE_ID"]
BASE = "https://apis.roblox.com/cloud/v2"
H = {"x-api-key": KEY, "Content-Type": "application/json"}

runner = """
local ok, result = pcall(function()
    local Runner = require(game:GetService("ServerStorage").Tests.Runner)
    return Runner.runAll()   -- returns { passed = n, failed = n, failures = { ... } }
end)
if not ok then return { passed = 0, failed = 1, failures = { tostring(result) } } end
return result
"""

r = requests.post(f"{BASE}/universes/{U}/places/{P}/luau-execution-session-tasks",
                  headers=H, json={"script": runner}, timeout=30)
r.raise_for_status()
task_path = r.json()["path"]

deadline = time.time() + 6 * 60
while True:
    t = requests.get(f"{BASE}/{task_path}", headers=H, timeout=30)
    t.raise_for_status()
    task = t.json()
    if task["state"] in ("COMPLETE", "FAILED", "CANCELLED"):
        break
    if time.time() > deadline:
        sys.exit("timed out waiting for the task")
    time.sleep(3)   # get-task limit is 200/min, so 3 s polling is safe

logs = requests.get(f"{BASE}/{task_path}/logs", headers=H, timeout=30)
if logs.ok:
    print(json.dumps(logs.json(), indent=1)[:20000])

if task["state"] != "COMPLETE":
    sys.exit(f"task {task['state']}: {json.dumps(task.get('error'))}")
# The docs say output holds the script's return values serialised to JSON; check the exact
# shape against the current reference (this assumes output.results is a list of returns).
result = (task.get("output") or {}).get("results", [{}])[0]
print(f"passed {result.get('passed')} failed {result.get('failed')}")
for f in result.get("failures", []):
    print("FAIL:", f)
sys.exit(1 if result.get("failed") else 0)
```

Things the sandbox cannot test: physics, real players, multi-client replication, and anything that needs Play. Those remain manual or need a separate harness ([[Multi-Client and Live Testing]]). Unit-test the logic; play-test the feel ([[Testing Strategies and Frameworks]]).

## Stage 6: publishing from CI

The Open Cloud **Place Publishing** API uploads a place file as a new version (Roblox docs):

- `POST https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Published` (use `versionType=Saved` to save without publishing)
- header `x-api-key`, body the place file, `Content-Type: application/octet-stream` for `.rbxl` or `application/xml` for `.rbxlx`
- API key permission: `universe-places` with Write for that experience
- response `{ "versionNumber": N }`
- **limitation**: the API does not update instances of type EditableImage, EditableMesh, PartOperation, SurfaceAppearance or BaseWrap; for places with those, the docs say to publish from Studio after modifying them.

That limitation matters for hybrid places: if your world uses unions (PartOperation) or SurfaceAppearance and you publish a Rojo-built file that contains them, check the result carefully, or restrict CI publishing to fully code-built places and publish hybrid places from Studio. Full details and scripts are in [[Asset Upload Automation with Open Cloud]] and [[Build Test and Release Pipeline]].

## Stage 7: the CI workflow

```yaml
# .github/workflows/ci.yml
name: ci
on:
  pull_request:
  push:
    branches: [main]
    tags: ["v*"]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Rokit and pinned tools
        run: |
          curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
          echo "$HOME/.rokit/bin" >> "$GITHUB_PATH"
      - run: rokit install --no-trust-check   # check flags for your Rokit version
      - run: wally install
      - run: stylua --check src
      - run: selene src
      - run: rojo sourcemap default.project.json -o sourcemap.json
      - run: luau-lsp analyze --sourcemap=sourcemap.json --defs=tools/globalTypes.d.luau src
      - run: python3 tools/check_sources.py
      - run: rojo build default.project.json -o build.rbxl
      - uses: actions/upload-artifact@v4
        with: { name: place, path: build.rbxl }

  cloud-tests:
    needs: check
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with: { name: place }
      - run: pip install requests
      - name: Save build to the TEST place
        env: { RBX_API_KEY: "${{ secrets.RBX_TEST_KEY }}" }
        run: |
          curl -sf -X POST \
            "https://apis.roblox.com/universes/v1/${{ vars.TEST_UNIVERSE_ID }}/places/${{ vars.TEST_PLACE_ID }}/versions?versionType=Saved" \
            -H "x-api-key: $RBX_API_KEY" -H "Content-Type: application/octet-stream" \
            --data-binary @build.rbxl
      - name: Run tests in the cloud
        env:
          RBX_API_KEY: ${{ secrets.RBX_TEST_KEY }}
          TEST_UNIVERSE_ID: ${{ vars.TEST_UNIVERSE_ID }}
          TEST_PLACE_ID: ${{ vars.TEST_PLACE_ID }}
        run: python3 tools/run_cloud_tests.py
```

The live publish job runs only on tags, needs the cloud tests to pass, uses a **separate** API key scoped to the live experience, and is usually gated by a GitHub environment with required reviewers. See [[Build Test and Release Pipeline]].

API key hygiene: one key per purpose (test place vs live), the minimum scopes, IP restrictions where possible, stored as CI secrets, never printed in logs and never committed. Rotate keys when people leave.

## When you cannot use Rojo yet: the Studio-first code pipeline

Many teams (and the reference project for most of its life) edit scripts directly in a shared place, often through AI agents with Studio access. You can still get most of the safety:

1. **Keep a local base copy of each script you edit** (pull the source, edit locally, push back).
2. **Before every write, compare Studio's current source with your base.** If they differ, someone else changed it: merge, do not overwrite. The reference project had several agents and a human editing the same place; this check prevented silent losses.
3. **Gate every write**: compile (`loadstring(src)` returns a function), use-before-definition scan returns empty, size under the cap, clone-require for modules.
4. **One small change per write** for shared modules ("one insert"), with a backup of the previous source.
5. **Load big tools over HTTP instead of pasting them**: the project served its scratch folder on a local HTTP server and loaded tools with `loadstring(HttpService:GetAsync("http://127.0.0.1:<port>/<path>?x=" .. os.clock(), true))(args)`; the `?x=` defeats caching and `true` sets `nocache`. This needs HttpService enabled and only works in Studio. See [[Studio Plugins and Local HTTP Bridges]].
6. **Dump sources to disk regularly** (a plugin or a script that posts every script's source to a local receiver), and commit those dumps to Git. Even a read-only mirror gives you diff and blame.

This is a stepping stone. The moment more than one person edits code daily, move code to files.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Changes in Studio vanish | Rojo synced files over Studio edits | edit code only in files; keep mapped folders code-only |
| "Works on my machine" formatting or lint | unpinned tools | Rokit-pinned versions |
| CI green, game broken | tests did not touch engine behaviour | cloud tests for engine logic, play test for feel |
| Publish removed SurfaceAppearance / unions | Place Publishing API limitation | publish hybrid places from Studio |
| 429 from Luau Execution | more than 10 incomplete tasks, or create rate | queue tasks; 5 creates per minute |
| Key leaked in logs | `echo` of secrets, verbose curl | mask secrets; never `-v` with keys |
| Script rejected on save | source over the size cap | split into child modules before 195k |
| Overwrote a teammate's edit | no compare before write | base-copy compare, or move to Rojo |

## Checklist

- [ ] Code in files, Rojo-mapped folders code-only
- [ ] Tools pinned with Rokit; Wally for packages
- [ ] StyLua, Selene, luau-lsp, Rojo build in CI on every PR
- [ ] Project gates: source size, use-before-definition
- [ ] Engine tests through Open Cloud Luau Execution on a test place
- [ ] Separate API keys for test and live, minimum scopes, secrets only
- [ ] Live publish on tags only, after tests, with a reviewer gate
- [ ] Studio-first fallback: base compare, gated writes, HTTP loader, source dumps

## See also

[[External Tooling - Rojo Wally Selene StyLua]] · [[Git and Source Control for Roblox]] · [[Open Cloud APIs]] · [[Build Test and Release Pipeline]] · [[Testing Strategies and Frameworks]] · [[Luau Type System and Strict Mode]] · [[MCP Workflows for Scripting and Debugging]] · [[Safe Changes in a Shared Place]] · [[Pipeline Design Principles]]

## Connected notes
<!-- auto-links:start -->
[[Code Review for Luau Teams]] · Places Universes and Experience Settings · Official Docs - Studio and Tooling · Documentation and Onboarding New Developers · Packages and Asset Reuse · AI Code Assistants for Luau
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Batch Processing Tools in Studio]] · [[Live Content Pipeline]] · [[Icon and Thumbnail Rendering Pipeline]] · [[Blender Automation with Python]] · [[Art Pipeline - Concept to In-Game Asset]] · [[Localization Pipeline]] · [[Environment and Level Pipeline]] · [[Audio Pipeline]]
<!-- related:end -->
