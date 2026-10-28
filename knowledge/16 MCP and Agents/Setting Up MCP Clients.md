---
tags: [mcp, setup, claude, cursor, vscode, agents]
---
# Setting Up MCP Clients

An MCP server does nothing until a client (host application) is configured to start or connect to it. Every host stores that configuration a little differently, and most "it does not work" reports come from a missing comma, the wrong key name, a path the host cannot resolve, or forgetting to restart. This note gives working configurations for the common hosts, using the [[Roblox Studio MCP Server]] and [[Blender MCP]] as examples, then covers permissions, scopes, Windows quirks, and how to debug a server that will not connect.

Everything here is **as of October 2026**. Hosts change their settings screens and file locations often; when in doubt, check the host's own MCP documentation. Source labels: **Roblox docs**, **Host docs** (the product's documentation), **Measured** (reference project), **Rule of thumb**.

---

## 1. The common shape

Nearly every host uses the same JSON idea: a map of server names to "how to start it".

```json
{
  "mcpServers": {
    "Roblox_Studio": {
      "command": "cmd.exe",
      "args": ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]
    },
    "Blender": {
      "command": "path-to-blender-mcp-launcher",
      "args": []
    }
  }
}
```

- **The key** (`Roblox_Studio`) is your name for the server. Hosts use it to prefix tool names, which is why Claude Code shows `mcp__Roblox_Studio__execute_luau`. Pick a short, stable name; renaming it breaks any allowlists that mention it.
- **`command` + `args`** start a **stdio** server: the host launches this process and talks to it over stdin and stdout ([[What Is MCP]]).
- **`env`** (optional) passes environment variables, the right place for API keys. Never put keys in `args`, which show up in process lists and logs.
- **`url`** (instead of `command`) points at a **Streamable HTTP** server that is already running. Some hosts want an explicit `"type": "http"`.

The Studio entry above is the one the Roblox docs give for Windows. On macOS the docs give `"command": "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"` with no args.

---

## 2. Roblox Quick connect (easiest)

Studio can write the client configuration for you (Roblox docs): **Assistant > ... > Manage MCP Servers**, turn on **Enable Studio as MCP server**, then in **Assistant Settings > MCP Servers > Quick connect** switch on your client. Listed clients include Antigravity, Codex CLI, Claude Code, Claude Desktop, Cursor, Gemini CLI and Visual Studio Code. If your client is not listed, install it and restart Studio. Restart the client after connecting.

Use Quick connect when you can. Use manual configuration when your client is not listed, when you need the same config on several machines, or when you want the config committed to a repository.

---

## 3. Claude Code

Claude Code is a terminal (and IDE and desktop) coding agent. It has a CLI for MCP configuration (Host docs):

```bash
# Add the Studio server for yourself across all projects (Windows)
claude mcp add --scope user Roblox_Studio -- cmd.exe /c "%LOCALAPPDATA%\Roblox\mcp.bat"

# Add an HTTP server you run yourself (bridge on localhost)
claude mcp add --transport http --scope project studio-bridge http://127.0.0.1:3920/mcp

# Inspect
claude mcp list
claude mcp get Roblox_Studio
claude mcp remove studio-bridge
```

Everything after `--` is the command and its arguments. Inside a session, the `/mcp` command shows server status and lets you reconnect or authenticate.

### Scopes

| Scope | Stored | Use for |
|---|---|---|
| `local` (default) | Your private settings for this project | Experiments, personal bridges |
| `project` | `.mcp.json` at the project root, meant to be committed | Servers the whole team uses with this repo |
| `user` | Your user settings, every project | Studio and Blender servers you use everywhere |

A project `.mcp.json` uses the same `mcpServers` shape as section 1. Claude Code asks before trusting servers from a project file, since a cloned repository could otherwise start arbitrary programs.

### Permissions

Claude Code asks before tool calls unless rules say otherwise. Rules live in settings files (`.claude/settings.json` for the project, `.claude/settings.local.json` for you) and name MCP tools as `mcp__<server>__<tool>`:

```json
{
  "permissions": {
    "allow": [
      "mcp__Roblox_Studio__list_roblox_studios",
      "mcp__Roblox_Studio__get_studio_state",
      "mcp__Roblox_Studio__script_read",
      "mcp__Roblox_Studio__script_grep",
      "mcp__Roblox_Studio__script_search",
      "mcp__Roblox_Studio__search_game_tree",
      "mcp__Roblox_Studio__inspect_instance",
      "mcp__Roblox_Studio__get_console_output"
    ],
    "deny": [
      "mcp__Roblox_Studio__start_stop_play",
      "mcp__Roblox_Studio__insert_asset",
      "mcp__Roblox_Studio__generate_mesh"
    ]
  }
}
```

The pattern: **allow read-only tools freely, ask for writers, deny what your working rules forbid.** In the reference project the human eventually allowlisted `execute_luau`, `multi_edit` and `upload_image` because asking on every call was unworkable, and relied on the working rules ([[Safety Rules for AI Agents in Studio]]) for the rest. Denying `start_stop_play` at the host level enforces "agents never start Play" mechanically instead of by instruction. Check the current Claude Code docs for exact rule syntax (wildcards, server-wide rules) before relying on it.

### Project instructions

Claude Code reads a `CLAUDE.md` file in the project (and a user-level one). This is where the reference project kept its working rules, a map of the place ("the hub is at this path", "zone n spans these coordinates"), and a list of gotchas. An agent that starts every session with the map wastes far fewer calls exploring. See [[Documentation and Knowledge Bases]] and [[Case Study - Building a Game with AI Agents]].

---

## 4. Claude Desktop

Claude Desktop reads `claude_desktop_config.json` (Host docs):

| OS | Location |
|---|---|
| Windows | `%APPDATA%\Claude\claude_desktop_config.json` |
| macOS | `~/Library/Application Support/Claude/claude_desktop_config.json` |

Open it from **Settings > Developer > Edit Config**. Add entries under `mcpServers` exactly as in section 1, save, and **fully quit and restart** the app (closing the window may leave it running in the tray). Claude Desktop also supports one-click extension bundles (`.mcpb` files), which is how servers like Blender Lab's can be installed without editing JSON.

Desktop is good for conversational work: asking questions about your place, small edits, reviewing scripts. For long build sessions with many files on disk, a coding agent with file access (Claude Code, Cursor, Codex CLI) fits better because it can keep tools and notes on disk.

---

## 5. Cursor

Cursor reads MCP configuration from `.cursor/mcp.json` in a project or `~/.cursor/mcp.json` globally, with the same `mcpServers` shape (Host docs). Servers appear in Cursor's settings under MCP, where you can toggle them and see their tools. Cursor's agent mode is where MCP tools are used.

A Rojo-based project in Cursor is a strong combination: Cursor edits `.luau` files on disk with full editor tooling, Rojo syncs them into Studio, and the Studio MCP server is used for things files cannot do (inspect the live tree, run Luau, read the Output). See [[External Tooling - Rojo Wally Selene StyLua]] and section 9.

---

## 6. Visual Studio Code

VS Code (with GitHub Copilot's agent mode) reads `.vscode/mcp.json` in a workspace, or user-level configuration. **The top-level key is `servers`, not `mcpServers`** (Host docs), and entries usually carry a `type`:

```json
{
  "servers": {
    "Roblox_Studio": {
      "type": "stdio",
      "command": "cmd.exe",
      "args": ["/c", "${env:LOCALAPPDATA}\\Roblox\\mcp.bat"]
    }
  }
}
```

Copying an `mcpServers` block from another host into VS Code is a classic silent failure. VS Code's variable syntax also differs (`${env:NAME}`); check whether your host expands `%LOCALAPPDATA%` at all, or write the full path.

---

## 7. Codex CLI, Gemini CLI and others

| Host | Config (Host docs, check current versions) |
|---|---|
| Codex CLI | `~/.codex/config.toml`, TOML tables such as `[mcp_servers.Roblox_Studio]` with `command = "..."` and `args = [...]` |
| Gemini CLI | `~/.gemini/settings.json` (or project `.gemini/settings.json`), `mcpServers` map |
| Antigravity | Supported by Roblox Quick connect; use that |
| Local model runners | Some (for example llama.cpp front ends) support MCP; Blender Lab documents a llama.cpp setup |

TOML example for Codex CLI:

```toml
[mcp_servers.Roblox_Studio]
command = "cmd.exe"
args = ["/c", "C:\\Users\\YOU\\AppData\\Local\\Roblox\\mcp.bat"]
```

---

## 8. Windows quirks

- **`npx`, `uvx` and `.bat` files** usually need to be wrapped in `cmd.exe /c` because hosts start processes directly, not through a shell. The Roblox Windows config already does this.
- **Environment variables in paths** (`%LOCALAPPDATA%`) are expanded by `cmd.exe` when it is the command, but not by every host when they appear elsewhere. If in doubt, write the absolute path.
- **Backslashes must be doubled** inside JSON strings.
- **Long paths.** Measured: Blender and some native tools failed to open paths over 260 characters, which deep temp or scratch folders easily exceed. Keep tool folders short (or use 8.3 short names).
- **Batch file echo.** A `.bat` that echoes commands writes to stdout and breaks a stdio server. Start batch files with `@echo off`.
- **Python launcher.** `py -I` (isolated mode) ignores the user site-packages, so a script that needs user-installed libraries fails under `-I` (Measured). Isolated mode is still the safer default for scripts that read untrusted files; choose deliberately.

---

## 9. Combining servers

A productive Roblox setup often has three or four servers in one host:

| Server | Role |
|---|---|
| Roblox Studio MCP | The live place: tree, scripts, Luau, Output, captures |
| Blender MCP | Modelling, renders, icons |
| File system / the host's own file tools | Your tools, notes and sources on disk |
| Your own bridge (optional) | Project-specific operations: install a weapon, run a QA suite ([[Writing Your Own MCP Server]]) |

Tool count has a cost: each server's tool list goes into the model's context, and similar-sounding tools from different servers confuse tool choice. Disable servers you are not using in a given session. Some hosts load tool schemas lazily, which helps.

---

## 10. Debugging a server that will not connect

Work down this list (the first three steps are the Roblox docs' own troubleshooting):

1. **Restart both** Studio (or Blender) and the client.
2. **Check the command path exists.** Run the exact command in a terminal. For stdio servers it should start and wait silently for input.
3. **Validate the JSON.** One missing comma disables the whole file in many hosts. Paste it into a JSON validator.
4. **Check the key name** (`mcpServers` vs `servers`) for your host.
5. **Look at the host's MCP log** (Claude Code: `/mcp`; Claude Desktop: the logs folder next to the config; VS Code: the MCP output channel). A server that "starts then disconnects" is usually printing to stdout or crashing on start.
6. **Check the target app is ready.** Studio: MCP toggle on, green indicator. Blender: add-on server started.
7. **Check for two copies.** Two hosts both trying to own one stdio server, or an old plugin-based Studio bridge still installed beside the built-in server, cause confusing behaviour. Remove the old one.

## 11. A sensible starting setup for a small Roblox team

Rule of thumb, for a team of one to five people starting with agents:

- **Studio MCP at user scope** on each developer's machine, via Quick connect. Everyone gets the same server name (`Roblox_Studio`), so shared allowlists work.
- **A project instructions file** committed with the code (or kept in a shared notes vault): working rules, a place map, owned areas.
- **A shared permissions file** in the repository that allows read-only Studio tools and denies `start_stop_play`, asset insertion and generation tools. Individuals loosen it locally if they work alone in a scratch place.
- **A scratch place** next to the real one for agent experiments. `list_roblox_studios` shows both; brief the agent which place id is which.
- **Blender MCP only on the machines of people who model**, and only in sessions that need it, to keep tool lists short.
- **Project-specific servers** (bridges, QA runners) at project scope in `.mcp.json`, with any tokens passed through `env` from each developer's own environment, never committed.

Review this setup after the first week: which prompts did people approve every time (allow them), and which tools caused trouble (deny or wrap them in a safer custom tool, see [[Writing Your Own MCP Server]]).

## 12. Common mistakes

- Editing config and not restarting the host.
- `mcpServers` in VS Code, `servers` elsewhere.
- API keys in `args`.
- Committing a `.mcp.json` that references paths only you have.
- Allowlisting every tool on day one.
- Keeping ten servers enabled "just in case".

## 13. Checklist

- [ ] Server enabled in the app (Studio toggle, Blender add-on).
- [ ] Config added via Quick connect or JSON with the right key name.
- [ ] Host fully restarted.
- [ ] Tools visible; `list_roblox_studios` returns your place.
- [ ] Read-only tools allowed, writers ask, forbidden tools denied.
- [ ] Project instructions file (working rules, place map) in place.

## See also

- [[What Is MCP]], [[Roblox Studio MCP Server]], [[Blender MCP]]
- [[Writing Your Own MCP Server]], [[Studio Plugins and Local HTTP Bridges]]
- [[Safety Rules for AI Agents in Studio]], [[AI Code Assistants for Luau]], [[Studio Assistant and AI Tools]]

## Connected notes
<!-- auto-links:start -->
[[Agent Review Loops and Guardrails in Practice]] · [[Roblox Studio Assistant]] · [[Third-Party Skill - Caveman Token Saver]] · [[AI in Roblox Development Overview]] · [[AI Agents and Autonomous Workflows]] · [[Third-Party Skill - Obsidian Skills]]
<!-- auto-links:end -->
