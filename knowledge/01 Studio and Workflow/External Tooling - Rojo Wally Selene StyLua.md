---
tags: [tooling, rojo, wally, selene, stylua, luau-lsp, darklua, script-sync]
---
# External Tooling - Rojo Wally Selene StyLua

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: `$path` on `Workspace` without ignoring unknowns -> Map code containers only, or `$ignoreUnknownInstances: true`
> - Avoid: Syncing into the live place -> `servePlaceIds` set to the dev place
> - Avoid: Mixing Script Sync and Rojo naming -> One convention per repo
> - Decision written down: Script Sync or Rojo, and which naming convention.
> - `rokit.toml`, `wally.toml`, `wally.lock`, `selene.toml`, `stylua.toml`, `.luaurc` committed.
> - Rojo maps code only; world protected; `servePlaceIds` set.
>
> Read more (16 KB note): ## 1. Script Sync or Rojo? · ## 3. Rojo · ## 11. Common mistakes · ## 12. Checklist
<!-- tldr:end -->

Studio stores your project in the cloud. External tools put it, or part of it, on disk, so you can use a real editor, Git, code review, linters, formatters, type checking in CI and package managers. Roblox's docs describe this as a syncing problem: files on disk, instances in Studio, and conflicts when both change (Docs). This note explains the options (Studio's built-in **Script Sync** versus **Rojo**), then each tool in the standard community toolchain with working config: Rokit, Rojo, Wally, Selene, StyLua, Luau Language Server and darklua. Versions are current as of October 2026; pin what you have tested.

Labels: **Docs** (Roblox docs or the tool's own docs/changelog), **Measured**, **Rule of thumb**.

---

## 1. Script Sync or Rojo?

| | **Script Sync** (built into Studio) | **Rojo** (community, rojo.space) |
|---|---|---|
| What syncs | Only `Script`, `LocalScript`, `ModuleScript`, `Folder` (Docs) | Scripts, folders, models (`.rbxm`/`.rbxmx`), JSON/TOML/YAML/CSV/TXT, `.model.json`, properties and attributes from project files |
| Source of truth | Studio, with files mirrored | The filesystem (or hybrid with `$ignoreUnknownInstances`) |
| Team Create | Supported; collaborator sync icons, numeric suffixes to avoid name clashes (Docs) | Supported with a sync lock (Rojo 7.3+) |
| Setup | Right-click a folder, **Sync to...** (Docs) | `rojo serve` plus the Studio plugin |
| Limits | 10,000 scripts per synced root, 128 roots (Docs) | Some properties cannot live-sync (binary data, `MeshPart.MeshId`, `HttpService.HttpEnabled`); build a place file instead (Rojo docs). Rojo 7.6 added a delete-and-recreate fallback for MeshParts and unions |
| Packages | Can sync scripts inside; `PackageLink` not written (Docs) | Not package-aware |
| Attributes/tags on scripts | Ignored; can lose data (Docs: do not sync scripts with attributes or tags) | Synced (`$attributes`, meta files) |
| Best for | Studio-first teams wanting an external editor and Git for code | Code-first teams, CI builds, Wally |

Docs guidance: Script Sync if you want your editor and version control but Studio for everything else; Rojo if you want the whole project on disk or the filesystem as the source of truth.

### File naming is not compatible

| On disk | Script Sync (Docs) | Rojo default (`emitLegacyScripts = true`) | Rojo with `emitLegacyScripts = false` |
|---|---|---|---|
| `x.luau` | ModuleScript | ModuleScript | ModuleScript |
| `x.server.luau` | Script, RunContext Server | Script, RunContext Legacy | Script, RunContext Server |
| `x.client.luau` | **Script, RunContext Client** | **LocalScript** | Script, RunContext Client |
| `x.local.luau` | LocalScript | (not a Rojo convention) | |
| `x.legacy.luau` | Script, RunContext Legacy | (not a Rojo convention) | |
| `x.plugin.luau` | Script, RunContext Plugin | Script, RunContext Plugin (7.5+) | same |
| `dir/init.*.luau` | The folder becomes that script | Same (`init.luau`, `init.server.luau`, `init.client.luau`) | same |

Moving a project between the two silently changes `.client.luau` files from LocalScripts to client-context Scripts or back. That matters: a LocalScript runs only in client containers such as `StarterPlayerScripts`, while a `RunContext = Client` Script runs wherever it is placed, including `Workspace` and `ReplicatedStorage` (see [[Script Types and Run Context]]). Pick one convention per repo and write it in the README.

## 2. Rokit: pin the toolchain

Rokit installs tools per project from a `rokit.toml` so every developer and CI runner uses the same versions (Docs, Roblox external tools page). It also reads `aftman.toml` and `foreman.toml` (Rokit README).

```toml
# rokit.toml (commit it). Versions current as of October 2026.
[tools]
rojo = "rojo-rbx/rojo@7.7.1"
wally = "UpliftGames/wally@0.3.2"
selene = "Kampfkarren/selene@0.32.0"
stylua = "JohnnyMorganz/StyLua@2.6.0"
luau-lsp = "JohnnyMorganz/luau-lsp@1.70.1"
darklua = "seaofvoices/darklua@0.19.0"
lune = "lune-org/lune@0.11.1"
```

Commands: `rokit self-install`, `rokit init`, `rokit add <owner/repo>`, `rokit install`, `rokit update`, `rokit list` (Rokit README). Upgrade deliberately: bump a version, run the full check suite, commit.

## 3. Rojo

### Project file

A `*.project.json` has `name` and `tree`, plus optional `servePort` (default 34872), `servePlaceIds`/`blockedPlaceIds` (guard against syncing into the wrong game), `placeId`, `gameId`, `serveAddress`, `globIgnorePaths`, `emitLegacyScripts`, `syncRules` and (7.7) `syncbackRules` (Rojo docs and changelog). Instance descriptions use `$className`, `$path`, `$properties`, `$attributes` (7.3+) and `$ignoreUnknownInstances`.

```json
{
  "name": "MyGame",
  "emitLegacyScripts": false,
  "servePlaceIds": [0],
  "globIgnorePaths": ["**/*.spec.luau", "**/.DS_Store"],
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Shared": { "$path": "src/shared" },
      "Packages": { "$path": "Packages" }
    },
    "ServerScriptService": {
      "Server": { "$path": "src/server" }
    },
    "ServerStorage": {
      "ServerPackages": { "$path": "ServerPackages" }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Client": { "$path": "src/client" }
      }
    },
    "Workspace": {
      "$properties": { "StreamingEnabled": true },
      "$ignoreUnknownInstances": true
    },
    "HttpService": {
      "$properties": { "HttpEnabled": true }
    }
  }
}
```

Replace `servePlaceIds` with your dev place id (placeholder 0 here). Note that `HttpEnabled` cannot live-sync; it applies when you **build** a place (Rojo docs).

### Hybrid versus full management

`$ignoreUnknownInstances` defaults to **false when `$path` is set** and true otherwise (Rojo docs). With a `$path`, Rojo deletes instances in that container that are not on disk. That is right for code folders and catastrophic for a `Workspace` full of hand-built map. The common, safe setup (Rule of thumb):
- Rojo owns **code containers** (`src/*` mapped into dedicated folders like `ReplicatedStorage.Shared`).
- Studio owns the **world** (Workspace, Lighting, terrain, UI built visually), protected by `$ignoreUnknownInstances: true` or simply not mapped.
- The cloud place is the source of truth for the world, with Version History; Git is the source of truth for code.

### Other file types (Rojo docs)
- `.meta.json` next to a file sets properties or `ignoreUnknownInstances`; `init.meta.json` can change a folder's class (for example to `Tool`).
- `.model.json` describes small hand-written instances such as `RemoteEvent`s.
- `.json`, `.toml` (and `.yaml` since 7.6) become ModuleScripts returning the data; `.txt` becomes a StringValue; `.csv` a LocalizationTable.
- `syncRules` map custom extensions to types, including `runContextClientScript`, `legacyClientScript` and `pluginScript` (7.5).
- Ref properties can be linked with `Rojo_Target_<Prop>` attributes (7.5, described by the changelog as rough).

### Commands
```text
rojo init my-game          # new project
rojo serve                 # live sync to the Studio plugin
rojo build -o game.rbxl    # build a place file (CI, first open)
rojo sourcemap default.project.json -o sourcemap.json --watch   # for luau-lsp
rojo plugin install        # install the Studio plugin locally (Docs)
rojo syncback default.project.json --input game.rbxl            # 7.7: pull instances from a place file into the project
```

`rojo syncback` (7.7, released July 2026) pulls instances referenced by the project out of a Roblox file into files, controlled by `syncbackRules` (`ignoreTrees`, `ignorePaths`, `ignoreProperties`, `syncCurrentCamera`, `syncUnscriptable`) (changelog). It is the official path for porting an existing Studio game into Rojo. New and still settling: review the diff it produces.

Rojo 7.7 also validates `Host`/`Origin` headers on `rojo serve` against DNS rebinding and warns when bound to a network-reachable address (changelog). Keep the server on localhost.

## 4. Wally

Wally is a package manager for Luau with a registry index on GitHub (Wally README).

```toml
# wally.toml
[package]
name = "mystudio/my-game"
version = "0.1.0"
registry = "https://github.com/UpliftGames/wally-index"
realm = "shared"
private = true

[dependencies]
# React = "jsdotlua/react@17.2.1"

[server-dependencies]
# Server-only packages: never replicated to clients.

[dev-dependencies]
# TestEZ = "roblox/testez@0.4.1"
```

- `wally install` downloads into `Packages/` (shared), `ServerPackages/` and `DevPackages/`; map them in the Rojo project (the docs example maps `Packages` into ReplicatedStorage). Put `ServerPackages` in `ServerStorage` or `ServerScriptService`, never in a replicated container.
- `wally.lock` pins exact versions. **Commit it** for games so everyone gets identical code (the lockfile exists for exactly that, per the Wally README); ignore `Packages/` folders.
- Realms: `shared` or `server`; a server-realm package cannot be required from shared code by design.
- Version requirements are semver with caret behaviour by default.
- Wally packages ship as thin linker modules; luau-lsp needs types from them. The community tool `wally-package-types` regenerates type exports after `wally install` (Rule of thumb; check its README).

## 5. Selene (linter)

```toml
# selene.toml
std = "roblox"

[lints]
global_usage = "deny"
unused_variable = "warn"
shadowing = "warn"
```

- With `std = "roblox"`, selene generates and caches a Roblox standard library automatically and refreshes it every 6 hours; force it with `selene update-roblox-std` (selene docs). Set `roblox-std-source = "pinned"` to write it to `roblox.yml` in the repo for offline, reproducible CI.
- Severity per lint: `allow`, `warn`, `deny`; per-lint options under `[config]` (selene docs).
- Inline: `-- selene: allow(unused_variable)` above a statement or block; `--# selene: allow(lint)` at the very top for the whole file (selene docs).
- `std = "roblox+testez"` with a `testez.yml` for TestEZ globals.
- Run: `selene src`.

## 6. StyLua (formatter)

```toml
# stylua.toml
syntax = "Luau"
column_width = 120
line_endings = "Unix"
indent_type = "Tabs"
indent_width = 4
quote_style = "AutoPreferDouble"
call_parentheses = "Always"

[sort_requires]
enabled = true
```

- Defaults shown are StyLua's own (column 120, Unix endings, tabs, width 4, AutoPreferDouble, Always) (StyLua README). Set `syntax = "Luau"` explicitly: the default `All` union can misparse, for example Lua 5.2 labels versus Luau `::` casts (README).
- `[sort_requires]` sorts consecutive `local X = require(...)` and `game:GetService` lines within a block (README).
- `stylua src` formats; `stylua --check src` fails CI on unformatted files; `--verify` re-parses output as a safety net. `.styluaignore` excludes paths; `-- stylua: ignore` or `ignore start`/`ignore end` protect hand-aligned tables.
- Turn off Studio's **Format On Type/Paste** if StyLua owns formatting, or the two will fight.

## 7. Luau Language Server (luau-lsp)

The VS Code extension gives autocomplete, hover, go to definition, rename, type errors and more; the companion Studio plugin feeds it DataModel information for instances not on disk (Docs, Script Sync page; luau-lsp README).

- **Rojo users**: luau-lsp runs `rojo sourcemap --watch` to understand where files live in the DataModel; ignore `sourcemap.json` in Git (README).
- **Script Sync users**: install the extension and the **Luau Language Server Companion** plugin (Docs strongly recommend both).
- `.luaurc` configures strictness, lints and require aliases (Luau RFC):

```json
{
  "languageMode": "strict",
  "lint": { "*": true, "LocalUnused": false },
  "aliases": {
    "Shared": "src/shared",
    "Packages": "Packages"
  }
}
```

- **CI**: `luau-lsp analyze` runs the same checker headless. Flags from the tool's source: `--sourcemap=PATH`, `--definitions=@roblox=PATH` (repeatable), `--base-luaurc=PATH`, `--platform=roblox`, `--settings=PATH`, `--ignore=GLOB`, `--formatter=plain|gnu`, `--no-strict-dm-types`. Roblox type definitions are published in the luau-lsp repo (`scripts/globalTypes.d.luau`).

```text
rojo sourcemap default.project.json -o sourcemap.json
curl -sSLo globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=@roblox=globalTypes.d.luau --ignore="Packages/**" src
```

See [[Luau Type System and Strict Mode]].

## 8. darklua (code transforms)

darklua rewrites Lua/Luau with configurable rules (`.darklua.json` or `.darklua.json5`, run with `darklua process`) (darklua docs). The main Roblox use: write requires as **paths** (`require("./util")`, `require("@pkg/react")`) for tooling such as Lune and luau-lsp, and convert them to Roblox instance requires at build time with the `convert_require` rule and the Rojo sourcemap:

```json5
{
  rules: [
    {
      rule: "convert_require",
      current: { name: "path", sources: { "@pkg": "./Packages" } },
      target: { name: "roblox", rojo_sourcemap: "./sourcemap.json", indexing_style: "find_first_child" },
    },
  ],
}
```

Pipeline: `darklua process src out/src`, then point the Rojo project at `out/`. Roblox now supports require-by-string natively in many cases (see [[Module Scripts and Requiring]]), so check whether you still need the conversion before adding a build step.

## 9. Lune (scripts outside Roblox)

Lune runs Luau outside Roblox with filesystem, process, network and a `roblox` library that can read and write place and model files. Teams use it for build scripts, asset reports, data migrations and test runners in CI, so the whole toolchain stays in one language (Rule of thumb).

## 10. A day with this toolchain

1. `rokit install`, `wally install`.
2. `rojo serve`; in Studio, connect the Rojo plugin to the dev place (guarded by `servePlaceIds`).
3. Edit in VS Code with luau-lsp; StyLua formats on save; selene flags issues inline.
4. Build the world in Studio as usual; Rojo ignores it.
5. Commit; CI runs format check, lint, type check and build (see [[Git and Source Control for Roblox]]).

## 11. Common mistakes

| Mistake | Consequence | Fix |
|---|---|---|
| `$path` on `Workspace` without ignoring unknowns | Rojo deletes the hand-built map on connect | Map code containers only, or `$ignoreUnknownInstances: true` |
| Syncing into the live place | Unreviewed code live on next publish, or wrong place overwritten | `servePlaceIds` set to the dev place |
| Mixing Script Sync and Rojo naming | `.client.luau` changes class | One convention per repo |
| Script Sync on scripts with attributes or tags | Attribute data lost | Move data off scripts or use Rojo |
| `ServerPackages` in ReplicatedStorage | Server code downloaded by clients | ServerStorage |
| Unpinned tools | "Works on my machine" formatting and lint differences | `rokit.toml` |
| StyLua and Studio both formatting | Endless whitespace diffs | One formatter |
| luau-lsp without sourcemap | Everything typed `any`, false confidence | Sourcemap watch running |
| Wally lockfile ignored | Different dependency versions per developer | Commit `wally.lock` |

## 12. Checklist

- [ ] Decision written down: Script Sync or Rojo, and which naming convention.
- [ ] `rokit.toml`, `wally.toml`, `wally.lock`, `selene.toml`, `stylua.toml`, `.luaurc` committed.
- [ ] Rojo maps code only; world protected; `servePlaceIds` set.
- [ ] Editor extensions: luau-lsp (+ companion plugin), selene, StyLua.
- [ ] CI runs `stylua --check`, `selene`, `luau-lsp analyze`, `rojo build`.

## See also

- [[Git and Source Control for Roblox]], [[Plugins - Using and Writing]], [[Studio Settings and Shortcuts]]
- [[Project Structure and Bootstrapping]], [[Module Scripts and Requiring]], [[Luau Type System and Strict Mode]]
- [[Frameworks - Knit Matter and Others]], [[Declarative UI - React-Lua and Fusion]], [[Testing Strategies and Frameworks]]

## Connected notes
<!-- auto-links:start -->
[[Code Pipeline - Rojo Git and CI]] · [[Links - External tooling]] · [[Code Review for Luau Teams]] · [[Packages and Asset Reuse]] · [[Documentation and Onboarding New Developers]] · [[AI Code Assistants for Luau]]
<!-- auto-links:end -->
