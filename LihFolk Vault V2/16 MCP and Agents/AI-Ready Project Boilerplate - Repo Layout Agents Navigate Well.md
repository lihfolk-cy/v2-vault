---
tags: [agents, ai, workflow, rojo, repo-layout, documentation, claude-code, type/template, area/ai, area/pipelines, level/intermediate, area/ui]
---
# AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: One giant server script; every task starts with reading all of it.
> - Avoid: CLAUDE.md as a 600-line manual that dilutes the rules that matter.
> - Avoid: No single check command, so agents skip verification or guess commands.
> - Service-per-feature layout; thin remote handlers; data-only config.
> - CLAUDE.md or AGENTS.md under ~200 lines with commands, layout, rules.
> - PROJECT_STATE.md and handoffs/ in place.
>
> Cost: TL;DR ~150 tok · whole note ~2.3k tok. Read more: ## 1. The layout · ## 2. CLAUDE.md or AGENTS.md: what goes in · ## Common mistakes · ## Checklist
<!-- tldr:end -->

An agent's speed and accuracy on a Roblox project depend less on the model than on the repo. In a well-laid-out project the agent finds the shop service in one search, runs one command to check its work, and knows which folders it must not touch. In a messy one it reads 40 files, guesses at conventions and edits the wrong copy of a module. This note is a boilerplate layout, the docs and scripts that make agents productive, and the reasons behind each choice.

It assumes the Rojo code pipeline from [[Code Pipeline - Rojo Git and CI]]. Labels: **Rule of thumb** unless stated; Claude Code facts from [code.claude.com/docs](https://code.claude.com/docs/en/memory).

---

## 1. The layout

```
my-game/
  CLAUDE.md                 -- or AGENTS.md: stable rules, under ~200 lines
  PROJECT_STATE.md          -- current truth (see Agent Handoff Notes)
  handoffs/                 -- one file per session
  docs/
    ARCHITECTURE.md         -- services, data flow, remotes list
    DECISIONS.md            -- dated decisions with reasons
    TOOL_NAMES.md           -- MCP tool names in use and their mapping
  default.project.json      -- Rojo: live build
  test.project.json         -- Rojo: test build (adds QA modules)
  rokit.toml  wally.toml  selene.toml  stylua.toml
  src/
    server/
      Services/             -- one ModuleScript per service: ShopService.luau ...
      Remotes/              -- remote handlers, thin, delegate to services
    client/
      Controllers/          -- one per feature: ShopController.luau ...
      UI/
    shared/
      Config/               -- data-only modules: Prices.luau, Odds.luau
      Types.luau
  tests/
    unit/                   -- pure logic specs
    migrations/fixtures/ golden/
  qa/                       -- test-only modules (tester commands, chaos, samplers)
  tools/
    check.sh                -- one command: format, lint, types, tests
    run_cloud_tests.py
  .claude/
    settings.json           -- shared permissions and hooks
    rules/                  -- path-scoped rules
  .mcp.json                 -- project MCP servers (if any)
```

Why each part helps an agent:

| Choice | Effect |
|---|---|
| **One service per file, named after the feature** | `ShopService` is found by filename search; no grep through a 5,000-line `Main.server.luau` |
| **Thin remote handlers** that delegate | The agent knows where validation lives and where logic lives ([[Server Authority and Validation]]) |
| **Config as data-only modules** | Balance changes are small, safe diffs; tests read the same tables the game does |
| **`qa/` separate, only in `test.project.json`** | Agents can build test tooling freely without it shipping ([[Gated Tester Commands and Debug Panels]]) |
| **One `tools/check.sh`** | "Run the check" is one instruction; the agent verifies itself every change |
| **Code in files, not the place** | Agents edit files with normal tools and Git shows every change ([[Code Pipeline - Rojo Git and CI]]) |

---

## 2. CLAUDE.md or AGENTS.md: what goes in

Claude Code loads `CLAUDE.md` from the working directory and parents at start, can read `AGENTS.md` in its place, loads subdirectory files on demand, and recommends under about 200 lines per file (Claude Code docs). Keep it to facts needed every session:

```markdown
# my-game

## Commands
- Check everything: `sh tools/check.sh` (StyLua, Selene, luau-lsp, unit tests). Run after every change.
- Build test place: `rojo build test.project.json -o build/test.rbxl`

## Layout
- Server services: src/server/Services/<Feature>Service.luau
- Client controllers: src/client/Controllers/<Feature>Controller.luau
- Balance numbers: src/shared/Config/*.luau (data only, no logic)

## Rules
- All remotes validated on the server; handlers in src/server/Remotes delegate to services.
- DataStore calls only in src/server/Services/DataService.luau.
- Never edit default.project.json mappings without asking.
- Studio: call list_roblox_studios first; pick the TEST place by id; never start Play without asking.

## Roblox knowledge
- Before Roblox work: `py "<path>/LihFolk Vault V2/_tools/vault.py" "<task>"`.

## Sessions
- Read PROJECT_STATE.md and the newest handoffs/ file first. Write a handoff before ending.
```

Move procedures (how to add a new item, how to release) into skills or path-scoped rules rather than CLAUDE.md. `.claude/rules/*.md` files can be scoped to paths so they load only when the agent works on matching files (Claude Code docs). For example `rules/data.md` scoped to `src/server/Services/DataService.luau` can hold the data rules from [[Session Locking and Profile Libraries]].

---

## 3. Docs that pay for themselves

- **ARCHITECTURE.md**: a list of services with one line each, the remote list (name, direction, payload, rate limit), and the data schema version. The remote list alone saves agents from inventing duplicate remotes.
- **DECISIONS.md**: dated, one reason each. Stops reopened debates.
- **TOOL_NAMES.md**: the MCP tools in use, so prompts and permission rules stay correct after updates ([[Built-In Studio MCP vs Community MCP Servers - Migration Guide]]).
- **Module headers**: three lines at the top of each service: purpose, public functions, who calls it. Agents read the top of a file first.

---

## 4. Guardrails built into the repo

- **Permissions in `.claude/settings.json`:** allow read-only Studio tools, require approval for `multi_edit`, `execute_luau`, `insert_asset` and `start_stop_play`, deny reads of secret files ([[Safety Rules for AI Agents in Studio]], [[Local vs Cloud AI - Keeping Unreleased Game Code Private]]).
- **Hooks:** the LihFolk plugin's PostToolUse hook checks every written `.lua`/`.luau` file for known Roblox mistakes (unprotected DataStore calls, bad ProcessReceipt returns, unvalidated remote args and more) and feeds findings back in the same turn ([[Automated Luau Checks - LihFolk Hook and Audit]]). Add `tools/check.sh` as your own gate.
- **CI** runs the same `check.sh` plus cloud tests, so an agent's "done" is checked by something other than the agent ([[Agent Review Loops and Guardrails in Practice]]).
- **Quality bar:** for generated systems and assets, LihFolk's `quality-score` rubrics (minimum 8.5, blind reviewers, ledger in `.lihfolk/ledger.jsonl`); for big decisions, `/lihfolk:council`.

---

## 5. Naming conventions agents follow

- Feature names identical across layers: `ShopService`, `ShopController`, `Remotes/Shop`, `Config/ShopItems`, `tests/unit/Shop.spec.luau`. One search term finds the whole feature.
- Instance names in the place that match code names (`Shop` ScreenGui, `Buy_<ItemId>` buttons), so MCP `search_game_tree` and UI tests find them ([[UI Automation with VirtualInput and StudioTestService]]).
- No duplicated modules ("ShopService_old", "ShopService2"). Delete or move to an `archive/` folder outside the Rojo mapping.

---

## 6. Starting from an existing Studio-only game

1. Export scripts to files with a sync tool and set up Rojo for code only ([[Code Pipeline - Rojo Git and CI]], section on Studio-first pipelines).
2. Write ARCHITECTURE.md by having an agent survey the code read-only (`script_grep`, `search_game_tree`) and then correcting it yourself.
3. Split giant scripts by feature before asking agents for features. The reference project hit the 200,000-character Source limit in one service ([[Roblox Studio MCP Server]], section 5.6).

---

## Common mistakes

- One giant server script; every task starts with reading all of it.
- CLAUDE.md as a 600-line manual that dilutes the rules that matter.
- No single check command, so agents skip verification or guess commands.
- QA tooling mixed into the live build.
- Inconsistent feature names across layers.
- Duplicate "old" modules that agents edit by mistake.

## Checklist

- [ ] Service-per-feature layout; thin remote handlers; data-only config.
- [ ] CLAUDE.md or AGENTS.md under ~200 lines with commands, layout, rules.
- [ ] PROJECT_STATE.md and handoffs/ in place.
- [ ] ARCHITECTURE.md with remote list; DECISIONS.md; TOOL_NAMES.md.
- [ ] `tools/check.sh` runs format, lint, types and tests.
- [ ] Permissions, hooks and CI gate agent work; QA code only in the test build.

## See also

- [[Agent Handoff Notes - Project State and Resume Templates]], [[Code Pipeline - Rojo Git and CI]]
- [[External Tooling - Rojo Wally Selene StyLua]], [[Pipeline Design Principles]]
- [[Case Study - Building a Game with AI Agents]], [[Agent Review Loops and Guardrails in Practice]]

## Connected notes

[[Setting Up MCP Clients]] · [[Roblox Studio MCP Server]] · [[Git and Source Control for Roblox]] · Automated Luau Checks - LihFolk Hook and Audit

<!-- related:start -->
## Related
[[MCP Workflows for Scripting and Debugging]] · [[Agent Orchestration - Sub-Agents, Hooks and Skill Costs]] · [[Multiple Agents in One Studio]] · [[What Is MCP]] · [[Writing Your Own MCP Server]] · [[Studio Plugins and Local HTTP Bridges]] · [[Blender MCP]] · [[MCP Workflows for Building Worlds]]
<!-- related:end -->
