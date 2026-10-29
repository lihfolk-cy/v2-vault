---
tags: [mcp, studio, agents, migration, tooling, type/guide, area/ai, area/studio, level/intermediate, area/ui]
---
# Built-In Studio MCP vs Community MCP Servers - Migration Guide

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Leaving the old server configured next to the new one.
> - Avoid: Old plugin still installed and enabled.
> - Avoid: Permission rules and hook matchers still naming old tools, so approvals and checks quietly vanish.
> - Old server entries removed from every client.
> - Old Studio plugin disabled or uninstalled.
> - Built-in server enabled and verified with `list_roblox_studios`.
>
> Cost: TL;DR ~140 tok · whole note ~2.1k tok. Read more: ## 1. What changed and when · ## 3. Tool mapping · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Between 2025 and 2026 most Roblox AI setups ran on one of two kinds of bridge: Roblox's open-source reference server (`Roblox/studio-rust-mcp-server`) or a community server with its own Studio plugin. Roblox then built an MCP server into Studio itself, and archived the reference repository. If your prompts, permission rules, hooks or skills still name the old tools, they silently stop matching. This note is the migration: what differs, how old tool calls map to new ones, how to switch configs, and how to retire the old plugin safely.

What the built-in server does and its gotchas are in [[Roblox Studio MCP Server]]; client setup is in [[Setting Up MCP Clients]]. Labels as marked.

---

## 1. What changed and when

| Date | Event | Source |
|---|---|---|
| 9 May 2025 | `Roblox/studio-rust-mcp-server` repository created (MIT) | Measured: GitHub API, October 2026 |
| 5 Sep 2025 | Assistant update: Studio natively acts as an MCP server and Assistant as an MCP client | DevForum: [Assistant Update](https://devforum.roblox.com/t/assistant-update-boost-your-productivity-by-executing-complex-tasks/3920088) |
| 21 Feb 2026 | Open-source server gains `get_console_output`, `start_stop_play`, `run_script_in_play_mode`, `get_studio_mode`; Assistant accepts external LLM API keys | DevForum: [Studio MCP Server Updates](https://devforum.roblox.com/t/studio-mcp-server-updates-and-external-llm-support-for-assistant/4415631) |
| 3 Apr 2026 | Reference repository archived; Roblox points to the built-in server | [[Roblox Studio MCP Server]] (Roblox docs and repo notice) |

Community servers vary. One popular one (`boshyxd/robloxstudio-mcp`) was also archived when checked in October 2026 (Measured: GitHub API). Check the status of whatever you use.

---

## 2. Differences that matter

| | Reference or community server | Built-in server |
|---|---|---|
| Process | A separate binary or Node/Python process plus a Studio plugin that polls localhost | Inside Studio; the client launches a small Roblox-supplied launcher |
| Install | Download, run installer or `npx`, install plugin | Toggle "Enable Studio as MCP server" in Assistant's Manage MCP Servers |
| Updates | When you update it | With Studio |
| Tool count | 6 in the reference server; community servers vary (often property and tree tools) | About 25 (data model, scripts, Luau, playtest, input, assets, generation, docs) |
| Studio selection | Usually "the open Studio" | Explicit `studio_id` per call from `list_roblox_studios`; several windows at once |
| Security surface | Third-party code with plugin permissions and a local port | First-party; no extra plugin |

The practical win is fewer moving parts. The practical cost: every call now needs a `studio_id`, and that id changes when Studio restarts.

---

## 3. Tool mapping

Reference-server tools (names from the archived README, summarised in [[Roblox Studio MCP Server]]) to built-in equivalents:

| Old tool | Built-in replacement | Notes |
|---|---|---|
| `run_code` | `execute_luau` | Choose the datamodel (Edit, Server or Client). Old calls implicitly ran in Edit |
| `insert_model` | `search_asset` then `insert_asset` | Insert by numeric id; inspect scripts before trusting ([[Creator Store and Toolbox Safety]]) |
| `get_console_output` | `get_console_output` | Same name; now also needs `studio_id` |
| `start_stop_play` | `start_stop_play` | Same name. Still ends everyone's test in a shared Studio |
| `run_script_in_play_mode` | `start_stop_play` + `execute_luau` (Server or Client) + `get_console_output`, or the `subagent` tool's playtest mode | No single auto-stopping equivalent; stop the test yourself |
| `get_studio_mode` | `get_studio_state` | Returns play state and available datamodels |
| (none) | `script_read`, `script_grep`, `script_search`, `multi_edit` | Prefer these over `execute_luau` that reads `.Source` |
| (none) | `search_game_tree`, `inspect_instance` | Replace community "get children / get properties" tools |
| (none) | `user_mouse_input`, `user_keyboard_input`, `character_navigation`, `screen_capture` | Playtest driving |

**Community tool names** (`get_instance_properties`, `set_property`, `get_file_tree` and similar): map by intent. Reads become `inspect_instance` or `search_game_tree`; writes become `execute_luau` (Edit) or `multi_edit` for scripts. Do this mapping once in a table in your project docs so agents do not guess.

---

## 4. Config migration

1. **Remove the old server entry** from every client config (`claude mcp remove <old-name>`, Cursor `mcp.json`, Claude Desktop config, VS Code). Two servers that both drive Studio confuse agents and humans.
2. **Add the built-in server** with Quick connect in Studio or the JSON entry from the Roblox docs. Keep the server name `Roblox_Studio` unless you have a reason; tool names in hosts become `mcp__Roblox_Studio__<tool>`.
3. **Restart the client fully.**
4. **Disable or uninstall the old Studio plugin.** An old bridge plugin left enabled keeps polling a port and can still execute code if its server is started again. Remove it from Plugins > Manage Plugins.
5. **Verify:** green indicator in Manage MCP Servers; `list_roblox_studios` returns your place.

---

## 5. Update everything that names tools

This is the step people skip.

- **Permission rules.** Claude Code `permissions.allow` / `deny` entries such as `mcp__robloxstudio__run_code` match nothing now. Rewrite them for the new names, keeping write tools (`multi_edit`, `execute_luau`, `insert_asset`, `start_stop_play`) behind approval ([[Safety Rules for AI Agents in Studio]]).
- **Hooks.** Any `PreToolUse` or `PostToolUse` matcher on old tool names stops firing. Search hook configs for the old server name.
- **Skills, prompts and CLAUDE.md or AGENTS.md.** Replace old tool names and add the session start rule: call `list_roblox_studios`, pick by place id, check `get_studio_state`.
- **Scripts that parsed old outputs.** Output formats differ; re-check anything that reads tool results programmatically.

A quick audit: grep your repo and home config for the old names.

```bash
rg -n "run_code|insert_model|get_studio_mode|run_script_in_play_mode|robloxstudio" \
  .claude .mcp.json CLAUDE.md AGENTS.md skills docs 2>/dev/null
```

---

## 6. When to keep a custom bridge

The built-in server cannot read your disk or import local files ([[Roblox Studio MCP Server]], gotcha 5.5). If your pipeline needs to push large generated files or GLBs into Studio, a small local HTTP bridge is still useful alongside the built-in server ([[Studio Plugins and Local HTTP Bridges]], [[Writing Your Own MCP Server]]). Give it a distinct name and narrow tools so it does not overlap.

---

## Common mistakes

- Leaving the old server configured next to the new one.
- Old plugin still installed and enabled.
- Permission rules and hook matchers still naming old tools, so approvals and checks quietly vanish.
- Caching a `studio_id` across Studio restarts.
- Assuming `run_script_in_play_mode` exists and auto-stops.
- Trusting an archived community server for new work.

## Checklist

- [ ] Old server entries removed from every client.
- [ ] Old Studio plugin disabled or uninstalled.
- [ ] Built-in server enabled and verified with `list_roblox_studios`.
- [ ] Permission rules, hooks, skills and agent docs updated to new names.
- [ ] Tool mapping table written into project docs.
- [ ] Custom bridge kept only for disk-bound jobs, with distinct name.

## See also

- [[Roblox Studio MCP Server]], [[Setting Up MCP Clients]], [[What Is MCP]]
- [[Safety Rules for AI Agents in Studio]], [[Studio Plugins and Local HTTP Bridges]]
- [[Roblox Built-In AI Tools Timeline 2023-2026]]

## Connected notes

[[Writing Your Own MCP Server]] · [[Multiple Agents in One Studio]] · [[MCP Workflows for Scripting and Debugging]] · [[Roblox Studio Assistant]]

<!-- related:start -->
## Related
[[AI Agents and Autonomous Workflows]] · [[AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well]] · [[Agent Review Loops and Guardrails in Practice]] · [[Blender MCP]] · [[MCP Workflows for Building Worlds]] · [[Plugin Security and Permissions]] · [[Case Study - Building a Game with AI Agents]] · [[Agent Handoff Notes - Project State and Resume Templates]]
<!-- related:end -->
