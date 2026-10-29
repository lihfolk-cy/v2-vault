---
tags: [field-notes, studio, playtest, httpservice, mcp, tooling, ui, datamodel, type/guide, area/data, level/intermediate, api/HttpService]
---
# Moving Data Out of a Play Session

<!-- tldr:start -->
> [!tldr] TL;DR
> - Runtime GUI "saved" but gone after Stop: Edited inside the Client model -> Export through a bridge, rebuild in Edit
> - `HttpService` errors on the client: Requests are server-only -> Remote to the server, server posts
> - Export silently truncated: Large single payload -> Chunk and reassemble
> - Know which data model each tool call runs in.
> - Studio-only export remote with an `IsStudio` guard.
> - Payloads chunked; receiver reassembles and validates labels.
>
> Cost: TL;DR ~160 tok · whole note ~1.9k tok. Read more: ## 2. Bridge A: client to server to localhost · ## 4. Baking runtime-built GUIs into StarterGui · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Some of the most useful data only exists while the game runs: a GUI that code builds at runtime, tuned values from a live session, a dump of what the client actually sees. When you stop the session, it is gone, and the Edit view never had it. This note covers why, two reliable ways to get data out (a localhost bridge and chunked returns), and how to turn runtime-built GUIs into editable copies without losing the code that builds them. Tooling foundations are in [[Studio Plugins and Local HTTP Bridges]] and [[HttpService and External APIs]].

Source labels: **Roblox docs (as of October 2026)**, **Measured** (field-tested in a shipped Roblox game), **Rule of thumb**.

---

## 1. Three data models, not one

During a Play session Studio runs separate data models: the **Edit** model (your place file), a **Server** model and a **Client** model (Roblox docs, [[Testing Modes - Play Run and Multi-Client]]). Each has its own instances and its own memory. A command-bar call, plugin or MCP tool runs against one of them. Things that follow from that:

- A GUI built by a `LocalScript` exists only in the Client model's `PlayerGui`. Copying it in the Edit model's command bar finds nothing.
- `_G` and module state are per data model. Setting a value in the client does not make it visible to Edit.
- Stopping Play discards Server and Client entirely. Anything not written out is lost.

**Measured.** The reference project needed runtime-built GUIs and live values in Edit many times; what worked every time was routing the data out through one of the two bridges below.

## 2. Bridge A: client to server to localhost

The client cannot use `HttpService`; the server can, when **Allow HTTP Requests** (`HttpService.HttpEnabled`) is on in Game Settings (Roblox docs). So the client sends data to the server through a remote, and the server posts it to a small receiver on your machine.

```lua
-- Server Script, Studio only.
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
	return -- never ship this to live servers
end

local exportEvent = Instance.new("RemoteEvent")
exportEvent.Name = "DevExport"
exportEvent.Parent = ReplicatedStorage

exportEvent.OnServerEvent:Connect(function(_player, label: string, part: number, total: number, chunk: string)
	local body = HttpService:JSONEncode({ label = label, part = part, total = total, data = chunk })
	local ok, err = pcall(HttpService.PostAsync, HttpService, "http://localhost:8765/dump", body,
		Enum.HttpContentType.ApplicationJson)
	if not ok then
		warn("DevExport failed:", err)
	end
end)
```

The client serialises what it needs to a JSON string with `HttpService:JSONEncode` (that works on the client; only requests are server-only) and sends it in chunks of a few tens of kilobytes, because remotes and HTTP bodies both have size limits.

A receiver needs only a few lines of Python:

```python
# dump_receiver.py - run locally, writes each export to ./exports/<label>.json
import json, os
from http.server import BaseHTTPRequestHandler, HTTPServer

parts = {}
os.makedirs("exports", exist_ok=True)

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        key = body["label"]
        parts.setdefault(key, {})[body["part"]] = body["data"]
        if len(parts[key]) == body["total"]:
            data = "".join(parts[key][i] for i in sorted(parts[key]))
            with open(os.path.join("exports", key + ".json"), "w", encoding="utf-8") as f:
                f.write(data)
            del parts[key]
        self.send_response(200)
        self.end_headers()

HTTPServer(("127.0.0.1", 8765), Handler).serve_forever()
```

Field-tested in Studio Play sessions. Live game servers cannot reach your localhost, which is one more reason for the `IsStudio` guard. Validate the `label` on the receiver before using it in a file name.

## 3. Bridge B: chunked returns

If your tool can run code in the Client or Server model directly (some MCP tools can choose the data model), return the data as the call's result. Results are usually truncated past some size, so store the serialised string in that model once (for example in `_G.__export`) and read it back in slices across several calls: `string.sub(_G.__export, i, i + 49999)`. Count the total length first so you know when you are done.

## 4. Baking runtime-built GUIs into StarterGui

Code-built GUIs are hard for designers to adjust. Bridge A lets you export a full description (class, name, parent path, key properties) and rebuild it in Edit as a **baked copy** in `StarterGui`, which designers can edit visually. Do not delete the code that builds the GUI; it still holds logic, data binding and dynamic sizing.

Instead, add a **mirror script** that applies designer edits on top of the runtime build:

1. When baking, record each element's baked property values as a snapshot (attributes on the baked element, or a generated table).
2. At runtime, after code builds the GUI, the mirror walks the baked copy. For each property whose current baked value differs from its snapshot, a designer changed it, so the mirror applies that value to the matching runtime element.
3. Properties nobody changed are left alone, so code-driven values (text, counts, dynamic sizes) keep working.

**Rule of thumb:** match elements by path, not by order, and log any baked element with no runtime match so renamed elements are noticed.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Runtime GUI "saved" but gone after Stop | Edited inside the Client model | Export through a bridge, rebuild in Edit |
| `HttpService` errors on the client | Requests are server-only | Remote to the server, server posts |
| Export silently truncated | Large single payload | Chunk and reassemble |
| Designer edits overwritten by code | Baked copy not mirrored | Mirror only changed properties onto the runtime GUI |
| Debug exporter running in production | No Studio guard | `RunService:IsStudio()` check |

## Checklist

- [ ] Know which data model each tool call runs in.
- [ ] Studio-only export remote with an `IsStudio` guard.
- [ ] Payloads chunked; receiver reassembles and validates labels.
- [ ] Large tool results read in slices.
- [ ] Baked GUIs keep their builder code; a mirror applies only changed properties.

## Connected notes
<!-- auto-links:start -->
[[Studio Plugins and Local HTTP Bridges]] · HttpService and External APIs · Testing Modes - Play Run and Multi-Client · Roblox Studio MCP Server · UI Asset Pipeline · [[Field Notes Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Studio Automation Without Freezing Studio]] · [[Running Many AI Agents on One Roblox Place]] · [[Centre-Screen Announcements That Stay Centred]] · [[Springs That Survive Long Frames - dt Clamps and NaN Guards]] · [[ipairs Stops at the First nil - Cleanup Tables That Leak]] · [[UIStroke on Text - Glyph Counters and the Stroke Ratio]] · [[Resetting One Player's Data Safely]] · [[Shift-Lock Sprint and Gamepad B for Menus]]
<!-- related:end -->
