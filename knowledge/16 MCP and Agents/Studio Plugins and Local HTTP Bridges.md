---
tags: [plugins, http, tooling, studio, bridges, mcp]
---
# Studio Plugins and Local HTTP Bridges

Long before MCP, developers connected Roblox Studio to the outside world with a simple trick: Studio can make HTTP requests to a server on your own machine. A plugin or the command bar fetches code and data from `http://127.0.0.1`, and posts results back. Rojo works this way. Roblox's original MCP reference server worked this way. And even with the built-in [[Roblox Studio MCP Server]], the reference project relied on local HTTP every day, because MCP tool calls are the wrong pipe for megabytes of source, images and baked data.

This note covers the four bridge patterns (loader, receiver, polling plugin, file server for uploads), their limits, and working code for each. **Measured** marks the reference project; **Roblox docs** marks the official reference; **Rule of thumb** marks experience.

---

## 1. What Studio can and cannot do over HTTP

| Fact | Source |
|---|---|
| `HttpService` can request `127.0.0.1` / `localhost` from Studio (command bar, plugins, Edit-mode tool code) | Measured; Rojo depends on it |
| Live game servers cannot reach your machine's localhost; they run in Roblox's data centres | Roblox docs (HttpService guidance) |
| Scripts and the command bar need **Allow HTTP Requests** enabled for the place (Game Settings > Security), which sets `HttpService.HttpEnabled` | Roblox docs |
| Plugins ask the user for permission per domain the first time they make a request | Roblox docs (plugin HTTP permissions) |
| Requests are rate-limited: Roblox docs give 500 requests per minute per game server; Measured: the same budget applied in Studio, errors read "Number of requests exceeded limit" | Roblox docs, Measured |
| `loadstring` works in the command bar and plugins; in game scripts it requires `ServerScriptService.LoadStringEnabled` and never works on the client | Roblox docs |
| Studio cannot listen for incoming connections | Engine design: there is no server socket API in Luau |

The last point shapes everything: **Studio always initiates.** If an outside program wants Studio to do something, Studio must poll for it.

---

## 2. Pattern A: the loader (fetch code, run it)

Keep tools as `.lua` files on disk, edited with a real editor or by an agent's file tools. Serve the folder with a static file server bound to localhost:

```bash
# Serve the tools folder on localhost only.
python -m http.server 8765 --bind 127.0.0.1
```

Run a tool from the command bar or `execute_luau`:

```lua
local HttpService = game:GetService("HttpService")
local function runTool(name: string, args: {[string]: any}?): any
	-- "?x=" .. os.clock() makes every URL unique so no cache returns yesterday's file.
	local url = ("http://127.0.0.1:8765/%s?x=%s"):format(name, tostring(os.clock()))
	local src = HttpService:GetAsync(url, true) -- second argument = nocache
	local chunk, err = loadstring(src, "=" .. name) -- chunk name makes error messages readable
	assert(chunk, "compile failed: " .. tostring(err))
	return chunk()(args or {})
end

return runTool("tools/zone_audit.lua", { zone = 4, budget = 1.2 })
```

Conventions that made this robust (Measured):
- **Every tool file returns one function taking one table of arguments** and returns a short string report.
- **Budget argument.** The tool checks `os.clock() - t0 > budget` in its loops and returns `"stopped early i0=<n>"` so the caller resumes. Studio calls stay under about 1.5 s.
- **Modes.** Installers take `mode = "test" | "install" | "rollback" | "status"`; `test` writes into a separate test folder and never touches live content.
- **Fresh modules.** Tools that read shared ModuleScripts clone-require them ([[Roblox Studio MCP Server]], 5.2).

Why this beats pasting code into a tool call: the source never enters the model's context (a 300 KB setup script would eat a large share of it), the file is versioned on disk, and re-running after a fix is one line.

When the place's HTTP setting is off and you cannot turn it on, the fallback the reference project used for 100 to 370 KB setup scripts was simply asking the human to paste them into the command bar.

---

## 3. Pattern B: the receiver (post results out)

Studio is the only place that knows some truths: what an Animator actually does, where terrain actually renders, what every clip contains. To analyse that offline you need to get data out. A tiny receiver writes POST bodies to files:

```python
# recv.py : write POSTed bodies to ./inbox/<sub>/<name>. Localhost only, names validated.
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "inbox"
ALLOWED_SUBS = {"data", "clips", "out", "truth"}
NAME_OK = re.compile(r"^[A-Za-z0-9_.-]{1,120}$")
MAX_BYTES = 50_000_000

class Recv(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_POST(self):
        parts = self.path.strip("/").split("/")
        if len(parts) != 2 or parts[0] not in ALLOWED_SUBS or not NAME_OK.match(parts[1]) or ".." in parts[1]:
            self.send_response(400); self.end_headers(); return
        n = int(self.headers.get("Content-Length", "0"))
        if n > MAX_BYTES:
            self.send_response(413); self.end_headers(); return
        target = ROOT / parts[0] / parts[1]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(self.rfile.read(n))
        self.send_response(200); self.end_headers()
        self.wfile.write(b"ok")

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8833
    ThreadingHTTPServer(("127.0.0.1", port), Recv).serve_forever()
```

Studio side:

```lua
local HttpService = game:GetService("HttpService")
local function postJson(sub: string, name: string, data: any): string
	local body = HttpService:JSONEncode(data)
	return HttpService:PostAsync(
		("http://127.0.0.1:8833/%s/%s"):format(sub, name),
		body,
		Enum.HttpContentType.ApplicationJson
	)
end

-- One POST per batch, not per item: the request budget is per minute for the whole place.
local dump = {}
for _, clip in game.ServerStorage.Clips.KitA:GetChildren() do
	if clip:IsA("KeyframeSequence") then
		table.insert(dump, { name = clip.Name, keyframes = #clip:GetChildren() })
	end
end
return postJson("data", "kitA_clips.json", dump)
```

Why the name validation and the fixed subfolders matter: anything that can reach the port can write files. A receiver that accepted `../../` paths would let any local process (or a page exploiting DNS rebinding) overwrite your files. Bind to 127.0.0.1, validate names, cap sizes.

**Batching rule (Measured):** with about 500 requests per minute for the whole place, a dump that posted one request per clip across hundreds of clips hit the limit. Post one JSON per kit. On a limit error, wait 60 s and resume.

`JSONEncode` cannot encode CFrames, Vector3s or Instances directly. Convert to plain arrays (`{cf:GetComponents()}` gives 12 numbers) before posting.

---

## 4. Pattern C: the polling plugin (a command channel)

When an outside program needs to start work in Studio on its own schedule (an MCP server, a build script, a file watcher), a plugin polls for commands:

1. Plugin sends `GET /poll`. The server holds the request open until a job arrives or about 20 s pass.
2. On a job, the plugin runs it and sends `POST /result`.
3. Repeat.

Long polling keeps latency low (a job starts the moment it is queued) while making only about 3 requests per minute when idle. A complete server and plugin pair is in [[Writing Your Own MCP Server]]. Design rules:

- **Whitelist job kinds.** A plugin that runs arbitrary code from any local process is a backdoor into every place you open.
- **Run only in Edit.** Check `RunService:IsEdit()`; a plugin also loads in play-test sessions.
- **Back off when the server is down** (wait a few seconds after a failed request), or the Output fills with errors.
- **Stop on `plugin.Unloading`.**
- **One job at a time**, each within the call budget.
- **Record undo waypoints sensibly.** If your plugin writes to the place, wrap each job with `ChangeHistoryService:TryBeginRecording` and `FinishRecording` so a human undo reverts one job cleanly. (Agents themselves should still never call undo in a shared place: see [[Safety Rules for AI Agents in Studio]].)

Rojo is the most mature example of this pattern: `rojo serve` runs a local server, the Rojo plugin connects to it and syncs file changes into the place. See [[External Tooling - Rojo Wally Selene StyLua]].

---

## 5. Pattern D: a file server for uploads and archives

### 5.1 Images
The Studio MCP `upload_image` tool takes **HTTP URLs**, not file paths. To upload locally rendered icons, serve the render folder on localhost and pass `http://127.0.0.1:8766/icons/sword_01.png` (Measured). The tool returns a map of path to asset id; record it to a JSON file immediately, because the ids are the only link between your files and the game.

Measured: a freshly uploaded image can fail `ContentProvider:PreloadAsync` for about 20 to 60 seconds after upload. Do not conclude the upload failed; wait and retry.

### 5.2 Archives
The reference project moved about 291,000 instances of original animation data out of the place into `.rbxm` files on disk, served by a small archive server, so tools could fetch an original when they needed to edit it. The place shrank, Studio sped up, and nothing was lost. See [[Clip Archive Server]] and [[Baked Clip Stubs and Archiving]].

---

## 6. Process hygiene on Windows

Measured in the reference project:

- **Start servers hidden and detached** so they survive the agent's shell and do not pop windows: in PowerShell, `Start-Process python -ArgumentList "recv.py 8833" -WindowStyle Hidden`.
- **Long paths break native tools.** Python and Blender failed on paths over 260 characters (deep temp folders exceed this). Use short working folders or 8.3 short names.
- **One port per purpose**, written down in project notes (loader 8765, receiver 8833, icons 8766, archive 8784 in the reference project). Port collisions between agents produce baffling errors (a tool fetches another agent's file).
- **Limit offline CPU.** When offline numeric solvers ran beside Studio, the rule became at most 2 processes per agent with `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS` and `MKL_NUM_THREADS` set to 1, after many parallel processes starved Studio (part of the 25-minute freeze described in [[Safety Rules for AI Agents in Studio]]).
- **Check the server is running** before blaming the tool: a `GetAsync` error "connection refused" means nothing is listening.

---

## 7. Choosing a pattern

| Need | Pattern |
|---|---|
| Run a large tool or setup script | A: loader |
| Get Studio data into offline tools | B: receiver |
| Let an outside program trigger Studio work | C: polling plugin (or an MCP server, [[Writing Your Own MCP Server]]) |
| Upload local images | D: file server + `upload_image` |
| Keep big rarely-used data out of the place | D: archive server |
| Keep code in files with Git | Rojo ([[Git and Source Control for Roblox]]) |

MCP did not make these patterns obsolete. MCP is the right pipe for **decisions and small results** (the agent asks, Studio answers in a few lines). Local HTTP is the right pipe for **bulk**: tool sources, placement tables, clip dumps, images, archives. A mature setup uses both: the agent calls `execute_luau` with a one-line loader that pulls a 50 KB tool from localhost, and the tool posts a 5 MB dump to the receiver, while the only text that enters the model's context is a two-line report.

## 8. Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| "Http requests are not enabled" | Place HTTP setting off | Enable Allow HTTP Requests for the place (dev places only if policy requires) |
| "connection refused" | Server not running, wrong port | Start it; check the port in notes |
| Old code runs after editing | Cache | Query-string cache buster plus `nocache = true` |
| "Number of requests exceeded limit" | Too many small requests | Batch; wait 60 s |
| `loadstring` is nil | Running in a game script without LoadStringEnabled | Run from command bar, plugin or tool context |
| Receiver writes nothing | Name failed validation, size cap | Check the 400/413 response |
| Studio freezes | Tool did all work in one call | Budget and resume |

## 9. Checklist

- [ ] Servers bound to 127.0.0.1; ports recorded.
- [ ] Receiver validates paths and sizes.
- [ ] Loader uses cache busting and readable chunk names.
- [ ] Tools take one args table, have a budget, return a short report.
- [ ] Batches sized for the request budget.
- [ ] Polling plugins whitelist job kinds and run only in Edit.
- [ ] Upload ids recorded immediately.

## See also

- [[Writing Your Own MCP Server]], [[Roblox Studio MCP Server]], [[Plugins - Using and Writing]]
- [[HttpService and External APIs]], [[Command Bar and Studio Scripting]], [[Batch Processing Tools in Studio]]
- [[Studio Tooling Architecture]], [[Clip Archive Server]], [[Asset Upload Automation with Open Cloud]]

## Nuances and edge cases

1. **The loader pattern runs whatever the server sends.** Fetching code and calling `loadstring` on it in a plugin or the command bar means anyone who can answer on that port can run code in your Studio, with your account's access to the place. On a single-user machine the risk is small; on a shared machine, or with a server bound to all interfaces, it is not. Bind to 127.0.0.1, require a token, and prefer whitelisted job kinds over raw code where practical.
2. **Browsers can reach localhost too.** A web page open in your browser can send requests to `http://127.0.0.1:port`. Simple GET endpoints that change state can be triggered from a page you visit. Make every state-changing endpoint a POST that requires a custom header token; browsers will not add that header to a cross-site request without a preflight your server can refuse.
3. **Request budgets and batching.** The 500-requests-per-minute budget is plenty for long polling but easy to hit if a tool sends one request per instance or per file (Roblox docs for game servers; observed in Studio too). Batch payloads: one request with a hundred items, not a hundred requests. When the budget is hit, wait out the minute rather than retrying in a loop, which only extends the lockout.
4. **Payload sizes.** Large bodies (megabytes of baked data, base64 images) are slow to encode and decode in Luau and can freeze Studio during JSON work. Split into chunks of a size that encodes in well under a second, and stream them across several calls with a resume index.
5. **HttpEnabled on live places.** Turning on Allow HTTP Requests for convenience in a development place is fine. Turning it on in the live place because a tool needed it also lets live game scripts (including any malicious script hidden in a free model) call out to the internet. Keep tooling in development places, or turn the setting back off.
6. **Windows process hygiene.** Background Python servers outlive terminals, keep ports busy and can serve stale code after edits. Record the process id when starting, kill by id when done, and print the port and version on startup so a stale server is obvious.
7. **Multiple Studios and multiple tools.** Rojo, an MCP bridge and a custom file server can all run at once on different ports. Keep a small table of ports per tool in the project notes, and make each server refuse to start if its port is taken instead of quietly picking another.
8. **When MCP is the better pipe.** For small, frequent, model-driven actions (read a script, run a check), MCP tool calls are simpler and safer. Local HTTP shines for bulk transfer and for tools that are not AI-driven. Using both is normal: MCP for control, HTTP for data.

## More common mistakes

1. **No token on a state-changing endpoint.** Symptom: unexpected jobs or edits, possibly triggered from a browser tab. Fix: custom header token, POST only.
2. **Polling without back-off when the server is down.** Symptom: Output fills with connection errors and Studio slows. Fix: wait several seconds after a failure, longer after repeated failures.
3. **Leaving HTTP enabled in the live place.** Symptom: an audit finds outbound requests from game scripts you did not write. Fix: tooling only in development places.
4. **JSON with non-UTF-8 text.** Symptom: decode errors on files with special characters. Fix: write UTF-8 on the server side and validate before sending.
5. **Huge single responses.** Symptom: Studio freezes for seconds during decode. Fix: chunk and resume.
6. **Stale server code.** Symptom: fixes to the Python server seem to have no effect. Fix: restart by process id and print a version on each response.

## Related decisions

- [[Plugin Security and Permissions]]: what permissions a bridge plugin should and should not ask for.
- [[Links - Backdoors and malicious assets]]: why live places should not allow arbitrary HTTP.
- [[Building a Studio Plugin End to End]]: turning a bridge script into a maintained plugin.
- [[Code Pipeline - Rojo Git and CI]]: Rojo as the most common bridge of this kind.
- [[Threat Modeling a Roblox Game]]: tooling as part of the attack surface.
- [[Serialization Formats for Saves and Networking]]: compact formats for bulk payloads.
- [[Debugging Live Servers]]: why none of these bridges reach live servers.
- [[Documentation and Onboarding New Developers]]: documenting ports, tokens and startup steps so the team can run the tools.

## Connected notes
<!-- auto-links:start -->
[[Plugin Development Start Here]] · [[What Is MCP]] · [[AI Agents and Autonomous Workflows]] · [[MCP Workflows for Building Worlds]] · [[Pipeline Design Principles]] · [[Version History and Backups]]
<!-- auto-links:end -->
