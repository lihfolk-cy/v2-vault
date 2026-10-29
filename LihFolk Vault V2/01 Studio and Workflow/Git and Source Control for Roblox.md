---
tags: [git, source-control, ci, github-actions, open-cloud, workflow, type/guide, area/studio, level/intermediate]
---
# Git and Source Control for Roblox

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Committing `.rbxl` place files as the source -> Code as text; place versions in the cloud
> - Avoid: Rojo live-sync from a feature branch into the shared place -> Personal dev places per branch
> - Avoid: Code change that renames something the world uses, with no place... -> PR "requires" section, done at merge
> - Model (A, B or C) chosen and documented, with container ownership.
> - `.gitignore` and `.gitattributes` in place; LF everywhere.
> - Tool versions pinned; `wally.lock` committed.
>
> Cost: TL;DR ~170 tok · whole note ~3.9k tok. Read more: ## 2. Repository layout (model B) · ## 6. CD: publishing and testing with Open Cloud · ## 8. Common mistakes · ## 9. Checklist
<!-- tldr:end -->

Git assumes your project is a folder of text files. A Roblox game is a cloud data model edited live by several people, with binary place files, assets referenced by id and no local build step. Source control for Roblox is therefore a choice about **which part of the game lives in Git** and how it gets back into the place. Done well, it gives you code review, history that survives place restores, CI that blocks broken code, and reproducible releases. Done badly, it gives you a repo that disagrees with the live place and a team that stops trusting either. This note covers the three workable models, repo layout, `.gitignore` and `.gitattributes`, branching that fits a single cloud place, and a full CI pipeline including Open Cloud place publishing and Luau Execution tests (APIs as of October 2026).

Labels: **Docs**, **Measured**, **Rule of thumb**.

---

## 1. Three models

| Model | Git holds | Place holds | Sync | Fits |
|---|---|---|---|---|
| **A. Studio-first, code mirrored** | Scripts only | Everything; scripts edited in Studio or an editor | Script Sync (built in) | Small teams, existing games, heavy Team Create users |
| **B. Hybrid** (most common) | Code, configs, tooling, selected models | World, UI built visually, terrain, lighting | Rojo (code containers only) | Most production teams |
| **C. Fully managed** | Everything, including models as `.rbxm`/`.rbxmx` | A build artifact | `rojo build` then publish from CI | Code-heavy games, libraries, plugins, small worlds |

Rules of thumb:
- In model A, Git is a history and review tool; the place is the truth. Make sure everyone's edits go through the synced folder, or Git misses them.
- In model B, decide container by container who owns what, and write it down (see [[External Tooling - Rojo Wally Selene StyLua]]). Never let both Studio and Rojo own the same container.
- Model C is the only one where CI can publish the whole game from Git, but binary assets in Git do not diff or merge, and some instance types do not round-trip through the place publishing API (section 6).

## 2. Repository layout (model B)

```text
my-game/
  default.project.json
  rokit.toml  wally.toml  wally.lock
  selene.toml  stylua.toml  .luaurc
  src/
    shared/        -> ReplicatedStorage.Shared
    server/        -> ServerScriptService.Server
    client/        -> StarterPlayer.StarterPlayerScripts.Client
  assets/          # source art: .blend, .png, .fbx (or Git LFS / separate storage)
  models/          # small .rbxmx instance trees that code depends on (RemoteEvents, templates)
  tools/
    studio/        # command-bar tools loaded over localhost (see Command Bar and Studio Scripting)
    lune/          # build and report scripts
    studio-setup/  # team custom tabs, DefaultInstances.rbxm, settings list
  tests/
  docs/
    CHANGELOG.md  OWNERSHIP.md  RELEASE.md
  .github/workflows/ci.yml
```

### .gitignore

```gitignore
# Place files are build outputs or local backups, not sources
*.rbxl
*.rbxlx
*.rbxl.lock
*.rbxlx.lock
# Wally installs
Packages/
ServerPackages/
DevPackages/
# Generated
sourcemap.json
globalTypes.d.luau
out/
# OS
.DS_Store
Thumbs.db
```

Commit `wally.lock` for games (reproducible dependencies). Some templates ignore it; for a library that is fine, for a game it is a mistake.

### .gitattributes

```gitattributes
* text=auto eol=lf
*.luau text eol=lf
*.lua text eol=lf
*.json text eol=lf
*.rbxm binary
*.rbxl binary
*.png binary
*.blend binary
*.fbx binary
```

Rojo already converts synced Lua line endings to LF (Rojo 7.4.1 changelog), and StyLua defaults to Unix endings. Mixed endings produce whole-file diffs on Windows; settle it once here.

### Models in Git

- `.rbxmx` (XML) diffs, but noisily: referent ids and property order change between saves. Fine for small hand-made trees.
- `.model.json` is the cleanest for small instance trees (remotes, folders, simple templates).
- `.rbxm` (binary) is compact and unmergeable. Treat it like an image: one owner at a time.
- Large art sources (`.blend`, textures) belong in Git LFS or separate storage; never in plain Git history.

## 3. Branching when there is one cloud place

A branch in Git does not create a branch of the Roblox place. With Rojo live sync, whatever branch you have checked out is what you push into the place you are connected to. Practical patterns:

| Situation | Approach |
|---|---|
| Solo or two developers | Trunk-based: short feature branches, merge daily, live-sync only from `main` into the shared dev place |
| Several developers on code | Each developer has a **personal dev place** (Save to Roblox As a copy of dev) and syncs their branch there; `main` syncs to the shared dev place |
| World builders plus coders | Coders follow the above; builders work in the shared dev place; the world is versioned by Version History |
| Releases | Tag the commit that was published (`v1.42.0`), and put the tag in the place's publish notes |

**Rule of thumb:** a commit that changes the shape of something the world depends on (a remote name, a tag, an attribute schema, a folder path) needs a matching change in the place. Write it in the PR description ("requires: rename Workspace.Map.Shops to Stores") and do the place change at merge time.

Script Sync users get a simpler picture: the folder on disk mirrors one place. Branch switching rewrites those files and therefore the place's scripts; if Studio is open, Script Sync shows a conflict dialog listing what changes on each side (Docs). Do not switch branches with Studio syncing unless you mean it.

## 4. Commits and reviews

- Small commits with a subject saying what changed and why ("Shop: clamp quantity server-side to 1..99").
- One logical change per PR. Reviewers should be able to read it in fifteen minutes.
- Review checklist for Roblox code: server validates every remote argument ([[Server Authority and Validation]]); no client-trusted currency; DataStore calls wrapped and retried ([[DataStore Fundamentals]]); connections cleaned up ([[Memory Budgets and Leaks]]); no Studio-only APIs on runtime paths.
- Keep `docs/CHANGELOG.md` with player-facing and internal notes; reuse it for publish notes.

**Measured.** The reference project kept a running change log where every change recorded what changed, where, how to undo it, and whether it had been play-tested. That log answered most "what happened to X" questions faster than Version History, and the "not play-tested" flag kept QA honest.

## 5. CI: checks on every push

GitHub Actions example using Rokit to install pinned tools:

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: [main]
  pull_request:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install toolchain (rokit.toml)
        uses: CompeyDev/setup-rokit@v0.2.1

      - name: Install packages
        run: wally install

      - name: Format
        run: stylua --check src

      - name: Lint
        run: selene src

      - name: Type check
        run: |
          rojo sourcemap default.project.json -o sourcemap.json
          curl -sSLo globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
          luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json \
            --definitions=@roblox=globalTypes.d.luau --ignore="Packages/**" src

      - name: Build place
        run: rojo build default.project.json -o build.rbxl

      - uses: actions/upload-artifact@v4
        with:
          name: place
          path: build.rbxl
```

Notes:
- `setup-rokit` reads `rokit.toml` (or `aftman.toml`/`foreman.toml`) from the working directory and uses the repo's GitHub token by default for rate limits (its README).
- Fetching type definitions from `main` makes builds non-reproducible; pin a commit or vendor the file once stable.
- Selene's Roblox std is generated online; for offline CI, pin it (`roblox-std-source = "pinned"`, see [[External Tooling - Rojo Wally Selene StyLua]]).

## 6. CD: publishing and testing with Open Cloud

### Publish a place file

The place publishing API uploads a place file as a new version (Docs):

```bash
curl --fail --location -X POST \
  "https://apis.roblox.com/universes/v1/${UNIVERSE_ID}/places/${PLACE_ID}/versions?versionType=Saved" \
  -H "x-api-key: ${ROBLOX_API_KEY}" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @build.rbxl
# -> {"versionNumber": 57}
```

- API key from the Creator Dashboard with **universe-places** access and **Write** on the game (Docs). Store it as a CI secret; scope it to the dev universe for automatic deploys.
- `versionType=Saved` creates a saved version; `Published` makes it live (Docs examples use Published). Auto-publish to a **dev** universe; publish live by a manual, approved job.
- **Limitation (Docs):** the API does not update `EditableImage`, `EditableMesh`, `PartOperation`, `SurfaceAppearance` or `BaseWrap` instances; publish from Studio after changing those. In model C, unions and SurfaceAppearances in your `.rbxm` files will not update through CI.

In model B the place's world is not in Git, so CI cannot rebuild the whole place. Options: publish code only through Studio (a human connects Rojo to the live-candidate place and publishes), or have CI download nothing and only gate merges. Most hybrid teams do the latter and publish from Studio with release notes (see [[Release Process and Rollbacks]]).

### Run tests headlessly: Luau Execution

Open Cloud **Luau Execution** runs a Luau script on a real server that loads your place, with full engine API access (Docs, as of October 2026):
- `POST /cloud/v2/universes/{universe}/places/{place}/luau-execution-session-tasks` (or `.../versions/{version}/...` to target a specific version) with a JSON body containing `script`.
- The response includes a `path`; poll `GET https://apis.roblox.com/cloud/v2/{path}` until `state` is `COMPLETE` or `FAILED`; `.../logs` returns printed output.
- Scripts up to 4 MB, run up to 5 minutes (configurable `timeout`), 10 concurrent tasks per place; task creation is rate limited (5 per minute per API key owner) (Docs).
- Scope: `universe.place.luau-execution-session:write`.
- Roblox publishes a reference pipeline, `Roblox/place-ci-cd-demo` on GitHub (Docs).

```bash
#!/usr/bin/env bash
# run-tests.sh: execute tests/run.luau against the version CI just saved; fail CI on failure.
set -euo pipefail
API="https://apis.roblox.com/cloud/v2"
BODY=$(jq -n --rawfile s tests/run.luau '{script: $s}')
TASK=$(curl -sf -X POST "$API/universes/$UNIVERSE_ID/places/$PLACE_ID/versions/$VERSION/luau-execution-session-tasks" \
  -H "x-api-key: $ROBLOX_API_KEY" -H "Content-Type: application/json" -d "$BODY")
TASK_PATH=$(echo "$TASK" | jq -r .path)
for _ in $(seq 1 60); do
  sleep 5
  STATE_JSON=$(curl -sf "$API/$TASK_PATH" -H "x-api-key: $ROBLOX_API_KEY")
  STATE=$(echo "$STATE_JSON" | jq -r .state)
  if [ "$STATE" = "COMPLETE" ] || [ "$STATE" = "FAILED" ]; then break; fi
done
curl -sf "$API/$TASK_PATH/logs" -H "x-api-key: $ROBLOX_API_KEY" | jq -r '.. | .messages? // empty | .[]' || true
echo "$STATE_JSON" | jq .
[ "$STATE" = "COMPLETE" ] && [ "$(echo "$STATE_JSON" | jq -r '.output.results[0]')" = "true" ]
```

```lua
--!strict
-- tests/run.luau: runs on a server with the saved place loaded. Return true only if every test passes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelCurve = require(ReplicatedStorage.Shared.LevelCurve)

local failures = 0
local function check(name: string, cond: boolean)
	if not cond then
		failures += 1
		print("FAIL", name)
	end
end

check("level 1 at 0 xp", LevelCurve.levelFromTotalXp(0) == 1)
check("monotonic", LevelCurve.xpForLevel(10) > LevelCurve.xpForLevel(9))

print(("tests done, %d failures"):format(failures))
return failures == 0
```

The exact JSON shape of `output` and logs should be checked against the current reference before you rely on the `jq` paths above (field names from the docs: `state`, `output`, `path`; the nested `results` array is how return values are reported in the reference, verify on first run). Tests that touch DataStores in a dev universe work; keep them away from live data.

Alternative without Open Cloud: the Studio CLI runs a script after a place loads and can quit afterwards (`--task RunScript --runScriptFile ... --outputFile ... --quitAfterExecution`, Docs). It needs a machine with Studio and a signed-in user, so it suits a self-hosted runner, not hosted CI.

## 7. Studio-only teams: minimum viable source control

No Rojo, no CI, still worth doing:
1. **Script Sync** your code folders to a directory that is a Git repo.
2. Commit at the end of each session with a message; push to a private remote.
3. Write the commit hash in **Save to Roblox with Notes** for releases.
4. Before a risky change, commit; after, review the diff of scripts. Unexpected diffs in files you did not touch mean a plugin or another person changed them (see [[Creator Store and Toolbox Safety]]).

## 8. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| Committing `.rbxl` place files as the source | Huge repo, no diffs, merge impossible | Code as text; place versions in the cloud |
| Rojo live-sync from a feature branch into the shared place | Teammates test half-finished code | Personal dev places per branch |
| Code change that renames something the world uses, with no place change | Runtime errors after merge | PR "requires" section, done at merge |
| Ignoring `wally.lock` in a game | Different library versions per developer | Commit it |
| CI publishes live automatically | Every merge ships, including mistakes | Auto-publish to dev; manual live publish |
| Relying on CI publish with unions or SurfaceAppearances | Stale geometry live | Publish those from Studio |
| API key with broad scope in CI | Compromise affects everything | Minimal scopes, dev universe, rotate |
| No tag for what was published | Cannot reproduce or roll back code | Tag and note every release |

## 9. Checklist

- [ ] Model (A, B or C) chosen and documented, with container ownership.
- [ ] `.gitignore` and `.gitattributes` in place; LF everywhere.
- [ ] Tool versions pinned; `wally.lock` committed.
- [ ] CI: format, lint, type check, build on every PR.
- [ ] Personal dev places for branch work; shared dev place follows `main`.
- [ ] Releases tagged; tag in publish notes.
- [ ] Open Cloud keys scoped and stored as secrets.
- [ ] Headless tests via Luau Execution or a self-hosted Studio runner.

## See also

- [[External Tooling - Rojo Wally Selene StyLua]], [[Version History and Backups]], [[Team Create and Collaboration]]
- [[Release Process and Rollbacks]], [[Testing Strategies and Frameworks]], [[Open Cloud APIs]]
- [[Places Universes and Experience Settings]], [[Documentation and Knowledge Bases]]

## Connected notes
<!-- auto-links:start -->
[[Code Pipeline - Rojo Git and CI]] · Build Test and Release Pipeline · Code Review for Luau Teams · [[Packages and Asset Reuse]] · Links - Version control · Documentation and Onboarding New Developers
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Studio Settings and Shortcuts]] · [[Studio Interface Tour]] · [[Plugins - Using and Writing]] · [[Command Bar and Studio Scripting]] · [[Studio Assistant and AI Tools]] · [[Testing Modes - Play Run and Multi-Client]] · [[Explorer Properties and Selection]]
<!-- related:end -->
