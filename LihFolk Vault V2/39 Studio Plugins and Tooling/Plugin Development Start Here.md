---
cssclasses: [vault-hub]
tags: [studio, plugins, tooling, hub]
---
# Plugin Development Start Here

This section is about building Roblox Studio plugins that other people can rely on: panels that behave, undo that reverts exactly one action, bulk edits that do not wreck a map, a security posture you can defend, and releases that do not break users' places. It goes deeper than the older overview notes and assumes you have read [[Plugins - Using and Writing]].

Labels: "Roblox docs (as of October 2026)", "measured in the reference project", "rule of thumb". Code is reviewed, not run: test every snippet in a scratch place first.

## What the older notes already cover

| Older note | Gives you | This section adds |
|---|---|---|
| [[Plugins - Using and Writing]] | Installing safely, the dev loop, the API map, a bulk anchor example | Lifecycle, structure, undo internals, UI, selling |
| [[Command Bar and Studio Scripting]] | Snippet versus plugin, clone-require, budgets, never undo in a shared place | The same rules applied through recordings and a UI |
| [[Studio Plugins and Local HTTP Bridges]] | Loader, receiver and polling plugin patterns | Securing a bridge with tokens and whitelists |
| [[Explorer Properties and Selection]] | The Selection API, the selection trap, Pre-attributes | Normalisation, mouse tools, handles, bulk operations |
| [[Batch Processing Tools in Studio]], [[Studio Tooling Architecture]] | Sliced, resumable tools | When a job is too big for a button |
| [[Creator Store and Toolbox Safety]] | Store rules, model backdoors, a place audit | Plugin threats, auditing a plugin, author duties |

## The six deep notes

| Note | Read it when |
|---|---|
| [[Building a Studio Plugin End to End]] | Starting a plugin, or yours became one giant script. Lifecycle, layout, cleanup, versioned settings, actions, a complete Duplicate Name Linter |
| [[Plugin UI with DockWidgets]] | You need a panel. Dock persistence, button sync, role-based theming, virtual lists, throttled refresh, input, menus, drag and drop |
| [[Undo and ChangeHistoryService Done Right]] | Your plugin changes anything. Every member, a crash-safe recording helper, no yields, drags with Commit and Append, undo resync |
| [[Selection Editing and Bulk Tools]] | You act on the selection. Root normalisation, locked parts, packages, grid settings, pick tools, handles, replace and distribute |
| [[Plugin Security and Permissions]] | Before installing or publishing. What permissions really gate, threats, an audit scanner, team policy, secrets |
| [[Publishing Selling and Updating Plugins]] | Before shipping. Limits, Stripe seller rules, prices, escrow, refunds, versioning, compatibility, rollback |

Suggested order: Building, then Undo, then Selection or UI as your tool needs, then Security, then Publishing.

## Five rules that run through every note

1. **Every write goes through one recording helper** that commits on success, cancels on failure, and never yields.
2. **Never call `Undo()`, `ResetWaypoints()` or `SetEnabled(false)` from a plugin.** Measured in the reference project: one undo in a shared session walked about 40 waypoints back and rolled back other people's work.
3. **Selection is for humans; names and tags are for automation.**
4. **A plugin is a long-lived guest in other people's places.** Prefix what you write, version its format, read old formats forever, clean up on `Unloading`.
5. **Least privilege, no remote code.** Edit scripts only if that is your job, use one documented HTTP domain, never obfuscate.

## Related notes elsewhere

- Workflow: [[Studio Settings and Shortcuts]], [[External Tooling - Rojo Wally Selene StyLua]], [[Git and Source Control for Roblox]], [[Version History and Backups]], [[Team Create and Collaboration]], [[Safe Changes in a Shared Place]]
- Agents: [[Writing Your Own MCP Server]], [[Safety Rules for AI Agents in Studio]], [[Multiple Agents in One Studio]]
- Code and UI: [[Luau Type System and Strict Mode]], [[Error Handling - pcall xpcall and Promise Patterns]], [[Automated Testing with TestEZ and Jest-Lua]], [[Declarative UI - React-Lua and Fusion]], [[Virtualized Lists and Large Inventories]]
- Business: [[Running a Small Studio as a Business]], [[Building a Portfolio as a Roblox Developer]]

## Connected notes
<!-- auto-links:start -->
[[Links - Plugins and custom tools]] · [[Team Collaboration Start Here]] · [[Resource Library - Safety (free models and plugins)]] · [[Packages and Asset Reuse]] · [[Roblox Studio MCP Server]] · [[Code Pipeline - Rojo Git and CI]]
<!-- auto-links:end -->
