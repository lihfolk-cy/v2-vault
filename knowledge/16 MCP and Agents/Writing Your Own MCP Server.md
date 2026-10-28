---
tags: [mcp, python, typescript, plugins, tooling, agents]
---
# Writing Your Own MCP Server

The official [[Roblox Studio MCP Server]] gives agents general tools: run Luau, read scripts, capture the screen. Your project has operations that deserve their own tools: "install this weapon", "run the QA suite on zone 4", "bake these clips", "report instance counts per folder". Wrapping those in a small MCP server makes them one well-described call instead of a fragile paragraph of instructions, and lets any MCP host use them.

This note builds a complete small server in Python that talks to a Studio plugin over local HTTP (the same architecture as Roblox's original open-source reference server), shows the equivalent TypeScript skeleton, and covers tool design, testing and security. Read [[What Is MCP]] first for the protocol and [[Studio Plugins and Local HTTP Bridges]] for the plugin side in depth.

SDK APIs move quickly; the code below matches the official Python SDK (`mcp` package, `FastMCP`) and TypeScript SDK (`@modelcontextprotocol/sdk`) as commonly used in 2025-2026. **Check each SDK's README for the current version before copying** (as of October 2026). **Rule of thumb** marks design advice from experience; **Measured** marks the reference project.

---

## 1. Do you need one?

| Situation | Answer |
|---|---|
| You want an agent to run Luau and read scripts in Studio | No. Use the built-in server |
| You repeat the same multi-step Studio procedure often | Maybe. First try a ModuleScript in ServerStorage with one entry point, called through `execute_luau`. If that works, a custom MCP tool only adds a nicer description |
| The work needs your disk, a database, Python libraries, Blender, or Open Cloud | Yes. Studio cannot reach those; a local server can |
| Several hosts or agents need the same project-specific tools | Yes, and consider Streamable HTTP so one server serves all |
| You need tools in a live game server | No. MCP is a development-time protocol; live servers should not accept agent commands |

The reference project mostly used option two: installer modules in a ServerStorage "DevTools" folder (`Status`, `Install`, `Verify`, `Remove`), plus Python tools on disk run by the agent's own shell, plus small local HTTP servers to move files. That gets you 80 percent of a custom server's value with no new protocol code. Write a server when the glue starts being repeated in every prompt.

---

## 2. Architecture: three processes, two protocols

```
 MCP host (Claude Code, Cursor ...)
    |  MCP over stdio (JSON-RPC lines)
 your_server.py   <-- one process: MCP on stdio + a tiny HTTP server on 127.0.0.1
    |  your own HTTP protocol (long-poll GET for jobs, POST for results)
 Studio plugin (polls, runs the job inside Studio, posts the result)
```

Why a plugin polls instead of the server pushing: **Studio cannot listen for incoming connections.** Luau has no socket server. A plugin can only make outgoing HTTP requests. So the plugin asks "any work?" in a loop, holding each request open for a while (long polling) so jobs start quickly without hammering the server. Roblox's archived reference server worked exactly this way: an `axum` web server that the plugin long-polled, plus an `rmcp` stdio server for the client.

Rules for the HTTP side (from the MCP spec's local-server advice, which applies just as much to your private hop):
- Bind to `127.0.0.1`, never `0.0.0.0`.
- Require a shared secret header so random local processes and web pages cannot submit jobs.
- Never echo the secret in tool output.

---

## 3. The Python server

Dependencies: Python 3.10+, `pip install mcp` (the official SDK). Everything else is standard library.

```python
# studio_bridge.py : MCP server (stdio) + local HTTP job queue for a Studio plugin.
import asyncio
import json
import logging
import os
import queue
import secrets
import sys
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from mcp.server.fastmcp import FastMCP

# stdout belongs to the MCP protocol. ALL logging goes to stderr.
logging.basicConfig(stream=sys.stderr, level=logging.INFO, format="[bridge] %(message)s")
log = logging.getLogger("bridge")

HOST = "127.0.0.1"
PORT = int(os.environ.get("STUDIO_BRIDGE_PORT", "38741"))
TOKEN = os.environ.get("STUDIO_BRIDGE_TOKEN") or secrets.token_hex(16)
POLL_HOLD_S = 20          # how long a poll waits for a job before returning 204
JOB_TIMEOUT_S = 30        # how long a tool waits for Studio to answer

jobs: "queue.Queue[dict]" = queue.Queue()
results: dict[str, dict] = {}
done_events: dict[str, threading.Event] = {}
last_poll = {"t": 0.0}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # keep http.server quiet on stderr
        pass

    def _authorised(self) -> bool:
        return self.headers.get("X-Bridge-Token") == TOKEN

    def _send(self, code: int, body: dict | None = None):
        data = json.dumps(body).encode() if body is not None else b""
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path != "/poll" or not self._authorised():
            return self._send(404)
        import time
        last_poll["t"] = time.time()
        try:
            job = jobs.get(timeout=POLL_HOLD_S)
        except queue.Empty:
            return self._send(204)
        self._send(200, job)

    def do_POST(self):
        if self.path != "/result" or not self._authorised():
            return self._send(404)
        length = int(self.headers.get("Content-Length", "0"))
        if length > 5_000_000:
            return self._send(413)
        payload = json.loads(self.rfile.read(length) or b"{}")
        job_id = payload.get("id")
        if job_id in done_events:
            results[job_id] = payload
            done_events[job_id].set()
        self._send(200, {"ok": True})


def start_http():
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    log.info("listening on http://%s:%d (token in STUDIO_BRIDGE_TOKEN)", HOST, PORT)


def submit(kind: str, args: dict) -> dict:
    """Queue a job for the plugin and block until it answers or times out."""
    job_id = uuid.uuid4().hex
    done_events[job_id] = threading.Event()
    jobs.put({"id": job_id, "kind": kind, "args": args})
    ok = done_events[job_id].wait(JOB_TIMEOUT_S)
    done_events.pop(job_id, None)
    if not ok:
        return {"ok": False, "error": f"Studio did not answer in {JOB_TIMEOUT_S}s (plugin running? Studio in Edit?)"}
    return results.pop(job_id)


mcp = FastMCP("studio-bridge")


@mcp.tool()
async def bridge_status() -> str:
    """Report whether the Studio plugin is polling. Call this first if other bridge tools time out."""
    import time
    age = time.time() - last_poll["t"]
    return "plugin connected" if age < POLL_HOLD_S + 5 else f"no poll for {age:.0f}s: plugin not running"


@mcp.tool()
async def instance_counts(root_path: str, depth: int = 1) -> str:
    """Count descendants under each child of an instance (e.g. 'Workspace.Map', depth 1).
    Read-only. Use to find what is bloating a place."""
    r = await asyncio.to_thread(submit, "counts", {"root": root_path, "depth": depth})
    return json.dumps(r)


@mcp.tool()
async def run_installer(module_path: str, entry: str, args_json: str = "{}") -> str:
    """Call Entry(args) on a DevTools installer ModuleScript in Edit mode, e.g.
    module_path='ServerStorage.DevTools.ZoneInstall', entry='Status'.
    Installers must be idempotent and finish in under 1.5 s per call; long ones return a resume index."""
    r = await asyncio.to_thread(submit, "installer", {"module": module_path, "entry": entry, "args": args_json})
    return json.dumps(r)


if __name__ == "__main__":
    start_http()
    mcp.run()  # stdio transport by default
```

Points that matter:
- **`logging` to stderr**, `log_message` silenced: nothing but MCP JSON may reach stdout ([[What Is MCP]] 5.1).
- **Async tools hand blocking waits to a thread** (`asyncio.to_thread`) so one slow Studio job does not stall the whole server.
- **Timeouts produce readable errors** the model can act on ("plugin running? Studio in Edit?") rather than hanging the host.
- **Narrow, named job kinds** (`counts`, `installer`) rather than "run arbitrary Luau". The built-in server already offers arbitrary Luau; your server's value is curated, safe operations.
- **The token** comes from the environment so the host config can pass it via `env`, and the plugin reads the same value from a plugin setting.

Register it in a host (Claude Code example):

```bash
claude mcp add --scope project studio-bridge --env STUDIO_BRIDGE_TOKEN=change-me -- python studio_bridge.py
```

---

## 4. The plugin side

The plugin runs inside Studio, polls, executes the job, posts the result. A compact version (full discussion in [[Studio Plugins and Local HTTP Bridges]]):

```lua
--!strict
-- Plugin script (saved as a local plugin). Polls the bridge and runs whitelisted job kinds.
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local BASE = "http://127.0.0.1:38741"
local TOKEN = plugin:GetSetting("BridgeToken") or "change-me" -- set once from the command bar
local running = true

local handlers: {[string]: (args: any) -> any} = {}

-- "ServerStorage.DevTools.ZoneInstall" -> Instance (first segment may be a service name).
local function resolve(path: string): Instance?
	local parts = string.split(path, ".")
	local i = if parts[1] == "game" then 2 else 1
	local ok, svc = pcall(game.GetService, game, parts[i]) -- errors for non-service names
	local node: Instance? = if ok then svc else game:FindFirstChild(parts[i])
	for j = i + 1, #parts do
		if not node then
			return nil
		end
		node = node:FindFirstChild(parts[j])
	end
	return node
end

handlers.counts = function(args)
	local root = resolve(args.root)
	assert(root, "not found: " .. tostring(args.root))
	local out = {}
	for _, child in root:GetChildren() do
		out[child.Name] = #child:GetDescendants()
	end
	return out
end

handlers.installer = function(args)
	local module = resolve(args.module)
	assert(module and module:IsA("ModuleScript"), "not a ModuleScript: " .. tostring(args.module))
	-- Fresh copy: the require cache would return a stale version after edits.
	local clone = module:Clone()
	clone.Parent = module.Parent
	local ok, lib = pcall(require, clone)
	clone:Destroy()
	assert(ok, lib)
	local fn = (lib :: any)[args.entry]
	assert(type(fn) == "function", "no entry " .. tostring(args.entry))
	return fn(HttpService:JSONDecode(args.args))
end

local function request(method: "GET" | "POST", path: string, body: string?)
	return HttpService:RequestAsync({
		Url = BASE .. path,
		Method = method,
		Headers = { ["X-Bridge-Token"] = TOKEN, ["Content-Type"] = "application/json" },
		Body = body,
	})
end

local function loop()
	while running do
		local ok, res = pcall(request, "GET", "/poll")
		if not ok then
			task.wait(5) -- server not up; back off
		elseif res.StatusCode == 200 then
			local job = HttpService:JSONDecode(res.Body)
			local handler = handlers[job.kind]
			local okRun: boolean, value: any = false, "unknown kind " .. tostring(job.kind)
			if handler then
				okRun, value = pcall(handler, job.args)
			end
			local reply = { id = job.id, ok = okRun, value = if okRun then value else nil, error = if okRun then nil else tostring(value) }
			pcall(request, "POST", "/result", HttpService:JSONEncode(reply))
		end
		-- 204 = no job within the hold time: poll again immediately
	end
end

if RunService:IsEdit() then
	task.spawn(loop)
end
plugin.Unloading:Connect(function()
	running = false
end)
```

Notes:
- Long polling means each idle cycle is one request every 20 s, about 3 per minute, well under HttpService's 500-per-minute budget (Roblox docs for game servers; Measured as a real limit in Studio too).
- Studio asks you to allow a plugin's HTTP access to a host the first time; grant it for `127.0.0.1` only. Scripts and the command bar instead depend on the place's HTTP setting ([[HttpService and External APIs]]).
- **Only run in Edit** (`RunService:IsEdit()`); a plugin instance also loads in play-test datamodels.
- Handlers are a whitelist. Adding a `luau` handler that runs `loadstring(args.code)` is possible but duplicates the built-in server and widens your attack surface.
- Keep each handler under the call budget (about 1.5 s, Measured); the polling loop runs on Studio's main thread between yields.

---

## 5. The TypeScript equivalent

The official TypeScript SDK has the same shape. A skeleton (check the SDK README for the current registration API):

```typescript
// server.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "studio-bridge", version: "0.1.0" });

server.registerTool(
  "instance_counts",
  {
    title: "Instance counts",
    description: "Count descendants under each child of an instance path. Read-only.",
    inputSchema: { rootPath: z.string(), depth: z.number().int().min(1).max(3).default(1) },
  },
  async ({ rootPath, depth }) => {
    const result = await submitJob("counts", { root: rootPath, depth }); // your HTTP queue, as in Python
    return { content: [{ type: "text", text: JSON.stringify(result) }] };
  }
);

await server.connect(new StdioServerTransport());
console.error("studio-bridge ready"); // stderr, never stdout
```

Choose the language your team already runs. Python is convenient when the same process also needs numpy or Blender scripting; TypeScript when your tooling is Node-based.

---

## 6. Designing good tools

The model chooses and uses tools from their names, descriptions and schemas. Design for that reader.

| Principle | Example |
|---|---|
| One job per tool | `zone_status`, `zone_install`, `zone_verify` rather than `zone(action=...)` |
| Description states limits and side effects | "Writes to Workspace.Map. Idempotent. Under 1.5 s; returns `resume=i` if it stopped early" |
| Read-only tools say so | So hosts and humans can allowlist them |
| Small, structured results | Counts and short lists; offer a `detail` flag rather than dumping everything |
| Errors are actionable | "Kit folder would exceed 2,500 instances (now 2,612): remove clips or split the kit" |
| Dry-run by default for destructive work | `cleanup(dry_run=true)` lists what it would delete |
| Idempotent installs | Running twice gives the same result, not duplicates |
| Fingerprint checks | Refuse to write over data that changed since it was read (Measured: the reference project's clip installer compared instance counts and a checksum and refused with "changed since it was dumped") |

That last pattern is worth copying everywhere agents share a place: a tool that reads, computes offline, then writes must verify the target did not change in between ([[Multiple Agents in One Studio]]).

---

## 7. Testing a server

- **MCP Inspector.** The official interactive debugger: `npx @modelcontextprotocol/inspector python studio_bridge.py` opens a UI that lists your tools and lets you call them by hand. Use it before connecting a host.
- **Unit-test the pure parts** (job queue, argument validation) with normal Python or TypeScript tests.
- **Smoke test in a scratch place**, never the production place first.
- **Watch stderr.** Hosts usually expose server stderr in their MCP logs.

## 8. Security checklist

- [ ] HTTP bound to 127.0.0.1; token required; token from environment, never printed.
- [ ] Whitelisted job kinds; no generic eval unless you truly need it.
- [ ] Size limits on request bodies; timeouts on every wait.
- [ ] Destructive tools default to dry run and say so in the description.
- [ ] No Open Cloud keys or upload tokens in tool results or logs.
- [ ] The plugin only runs in Edit and stops on unload.
- [ ] Source code readable by the team; no binaries from unknown origins.

## 9. Common mistakes

- `print()` in a stdio server.
- A tool that blocks the event loop while waiting for Studio.
- A plugin loop with no back-off when the server is down (it spins errors into the Output).
- Returning a 40,000-line JSON blob.
- One "do anything" tool with a mode string.
- Binding the bridge to all interfaces "so my laptop can use it too".

## See also

- [[What Is MCP]], [[Studio Plugins and Local HTTP Bridges]], [[Plugins - Using and Writing]]
- [[Roblox Studio MCP Server]], [[Setting Up MCP Clients]], [[Safety Rules for AI Agents in Studio]]
- [[HttpService and External APIs]], [[Batch Processing Tools in Studio]], [[Asset Upload Automation with Open Cloud]]

## Nuances and edge cases

1. **One Studio, several polling plugins.** If two Studio windows are open with the plugin installed (two places, or the same place twice), both poll the same queue and whichever polls first takes the job. The agent may then run an installer in the wrong place. Give each plugin an identity (place id plus a session id) in the poll request, and let tools target a specific place. `bridge_status` should list every connected Studio, not just "connected".
2. **Play mode creates extra data models.** The `IsEdit()` guard matters: starting a play test creates client and server data models where plugins can load again. Without the guard you get three pollers racing for jobs, two of which see a game that disappears when the test stops. Keep the guard, and make tools refuse with a clear error while a play test is running if they need Edit.
3. **Long jobs versus the call budget.** The plugin runs handlers on Studio's main thread; a 20-second handler freezes Studio for 20 seconds and may exceed the host's own tool timeout. Split heavy work into resumable chunks that return a resume index, and let the agent call again. The server's 30-second timeout should be longer than any single chunk, with headroom.
4. **Lost results after a timeout.** If a job times out on the server, the plugin may still finish it later and post a result for an id nobody waits for. The code above drops it, which is correct, but the side effect (an installer that ran) still happened. Tools whose jobs can time out must be idempotent, so the agent's retry does not double-apply.
5. **Undo history.** Changes made by a plugin go into Studio's undo stack only if the plugin records them with ChangeHistoryService. Without that, a bad agent edit cannot be undone with Ctrl+Z and the only way back is version history. Wrap each write handler in a recording so one tool call is one undo step.
6. **Host differences.** Hosts differ in how they show tool output, how long they wait for a tool, whether they pass environment variables, and whether they support newer protocol features (structured output, tool annotations such as read-only and destructive hints, progress notifications). Write tools that work with plain text results and no optional features, then use extras where a host supports them (MCP spec features; check your host's docs, not verified per host here).
7. **Scale of a team.** For one developer, stdio is simplest: the host starts the server and it dies with the host. For a team sharing one build machine, a long-running Streamable HTTP server is easier to keep updated, but it now needs real authentication, logging of who called what, and care with concurrent jobs. Do not move to HTTP until more than one host really needs the same server.
8. **Port collisions.** A fixed port fails if another tool or a second copy already uses it. Fail loudly with "port in use" on startup, and make the port configurable on both the server and the plugin side.

## Common mistakes in practice

1. **Token left at the default.** Symptom: any local process that guesses "change-me" can submit installer jobs. Fix: generate a random token per machine and store it in a plugin setting and the host's environment.
2. **Stale require cache in handlers.** Symptom: an agent edits an installer module, calls it, and the old code runs. Fix: clone and require a fresh copy each call, as above.
3. **Results that include whole instance trees.** Symptom: the host truncates the output and the model guesses at the rest. Fix: return counts, ids and short summaries; add a paging argument for detail.
4. **Ambiguous instance paths.** Symptom: a tool finds the wrong "Map" because two siblings share a name. Fix: report ambiguity as an error instead of taking the first match.
5. **Swallowed handler errors.** Symptom: tools return "ok" with nothing changed. Fix: always return `ok=false` with the error text and the handler name.
6. **No version handshake.** Symptom: an updated server sends a job kind an old plugin does not know, and the agent gets "unknown kind". Fix: have the plugin report its version on poll and the server reject jobs the plugin cannot run.

## Related decisions

- [[Plugin Security and Permissions]]: what HTTP and script-injection permissions the bridge plugin asks for.
- [[Undo and ChangeHistoryService Done Right]]: making each tool call a single undo step.
- [[Building a Studio Plugin End to End]]: packaging and updating the plugin half of the bridge.
- [[Agent Review Loops and Guardrails in Practice]]: review steps around tools that write to the place.
- [[Version History and Backups]]: the fallback when an agent edit cannot be undone.
- [[Open Cloud APIs]]: the alternative when the work does not need a running Studio at all.
- [[Code Review for Luau Teams]]: reviewing installer modules before agents can call them.
- [[Error Handling - pcall xpcall and Promise Patterns]]: the pcall patterns the handlers rely on.

## Connected notes
<!-- auto-links:start -->
[[AI Agents and Autonomous Workflows]] · [[Pipeline Design Principles]] · [[Blender MCP]] · [[MCP Workflows for Building Worlds]] · [[Plugin Development Start Here]] · [[Third-Party Skill - Caveman Token Saver]]
<!-- auto-links:end -->
