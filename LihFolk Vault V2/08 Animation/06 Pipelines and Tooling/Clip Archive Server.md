---
tags: [pipeline, tooling, archive, http, rbxm, type/guide, area/animation, level/intermediate, api/HttpService, area/studio, api/KeyframeSequence]
---
# Clip Archive Server

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Deleting originals after a `saved` reply without reading back.
> - Avoid: Running the server from a terminal that gets closed.
> - Avoid: Archive folder outside the backup set. Symptom: a disk failure loses every original.
>
> Cost: TL;DR ~100 tok · whole note ~4.3k tok. Read more: ## The Studio side · ## Nuances and edge cases · ## Common mistakes
<!-- tldr:end -->

A 120-line local HTTP server that one project used to keep the **originals of baked clips out of the place**: one `.rbxm` file per KeyframeSequence on disk, written and read by Studio tools over localhost. It is what made it safe to delete hundreds of thousands of Pose instances ([[Baked Clip Stubs and Archiving]]) while keeping every original one call away. The pattern works for any "export this instance, get it back later" need.

## Why not keep originals in the place

The first version kept originals in a server-storage archive folder. It worked, and it was 291k instances that Studio and every server loaded for nothing. After Studio slowed to about 15 fps at over a million instances, the project adopted a rule: **no backup folders in the place**; back up to disk and rely on Roblox version history. Per-clip files on disk give:

- zero cost in the place;
- per-clip granularity (restore one kit, not a 100 MB backup);
- files Studio itself can open (**File > Insert from File** accepts them), so the archive is useful even without the tools;
- versioning on the file system (and in source control if you want).

## Endpoints

The server listens on `127.0.0.1` only (one port, here 8784). All bodies are plain text.

| Method and path | Result |
|---|---|
| `GET /ping` | `clipserver ok <total> (ClipSources <n>, PlayerClips <n>)`: file counts, superseded versions excluded |
| `GET /list/<Kit>` | clip names in that enemy kit folder, one per line (empty if the folder does not exist) |
| `GET /list/PlayerClips/<path...>` | clip names in a player-clip folder |
| `GET /get/<Kit>/<Clip>` | base64 of the `.rbxm`; **404 `missing`** when absent |
| `GET /get/PlayerClips/<path...>/<Clip>` | the same under player clips |
| `POST /put/<Kit>/<Clip>` | body = base64 of the `.rbxm`; reply `saved <bytes>` or `same <bytes>` |
| `POST /put/PlayerClips/<path...>/<Clip>` | the same under player clips |
| anything else | **400 `bad path`** |

## Rules the server enforces

1. **Names:** every path segment must match `[A-Za-z0-9_-]+` (no dots, no slashes, no spaces). This alone prevents path traversal: `..` cannot be expressed. Query strings are ignored.
2. **Depth:** an enemy kit path is exactly one segment (`<Kit>`). A path under a named top folder (`PlayerClips`) may have 2-6 segments, so it can mirror nested replicated-storage paths such as `<Kit>/ItemRig` or `CharacterModels/<id>/AnimSaves`.
3. **Content check:** a `put` whose decoded body does not start with the binary model signature `<roblox!` is rejected (`400 not an rbxm`). A buggy tool cannot fill the archive with garbage or JSON.
4. **Identical content:** if the file exists and is byte-identical, nothing is written (`same`). Rebakes do not churn the disk.
5. **Superseded content:** if the file exists and differs, the old one is renamed `<Clip>.<YYYYMMDD-HHMMSS>.prev.rbxm` first. Nothing is ever overwritten silently. Listings and counts ignore `.prev.` files.
6. **Atomic writes:** the new file is written to `<Clip>.rbxm.tmp` and then renamed over the target, so a crash mid-write never leaves a truncated archive file.

## Disk layout

```
archive/
  ClipSources/<Kit>/<Clip>.rbxm                       enemy kit clips (server-side clip sources)
  PlayerClips/<ReplicatedStorage path>/<Clip>.rbxm    player clips, mirroring where the stub lives
      e.g. PlayerClips/<Name>Kit/<Move>.rbxm
           PlayerClips/<Name>Kit/ItemRig/<Clip>.rbxm
           PlayerClips/<SomeFolder>/<Sub>/<Clip>.rbxm
  .../<Clip>.<stamp>.prev.rbxm                        superseded versions
```

Mirroring the in-place path means the archive key of a stub is derivable from where the stub sits; for clips whose location may change, the stub also stores an explicit key in an attribute (`KSArc = "<Kit>/<Clip>"`).

## The Studio side

Serialisation uses `SerializationService` (its methods carry the PluginOrOpenCloud capability, so they work from plugins and the command bar, not from game scripts):

```lua
local HttpService = game:GetService("HttpService")
local EncodingService = game:GetService("EncodingService")
local Ser = game:GetService("SerializationService")
local URL = "http://127.0.0.1:8784"

local function b64(buf: buffer): string return buffer.tostring(EncodingService:Base64Encode(buf)) end
local function unb64(s: string): buffer return EncodingService:Base64Decode(buffer.fromstring(s)) end

local function ping(): (boolean, string)
	local ok, r = pcall(function() return HttpService:GetAsync(URL .. "/ping", true) end)
	return ok and string.sub(r, 1, 10) == "clipserver ok", ok and r or "archive offline: start the clip archive server"
end

local function put(kit: string, ks: KeyframeSequence): string
	local rbxm = Ser:SerializeInstancesAsync({ ks })                -- a normal binary .rbxm in a buffer
	local r = HttpService:RequestAsync({
		Url = URL .. "/put/" .. kit .. "/" .. ks.Name,
		Method = "POST",
		Body = b64(rbxm),                                           -- HTTP bodies are strings: base64 keeps binary safe
		Headers = { ["Content-Type"] = "text/plain" },
	})
	if not r.Success then error(("archive put %s/%s: %d %s"):format(kit, ks.Name, r.StatusCode, r.Body)) end
	return r.Body                                                   -- "saved N" or "same N"
end

local function fetch(kit: string, clip: string): (KeyframeSequence?, string?)
	local r = HttpService:RequestAsync({ Url = URL .. "/get/" .. kit .. "/" .. clip, Method = "GET" })
	if r.StatusCode == 404 then return nil, "not in the archive" end
	if not r.Success then return nil, "archive " .. r.StatusCode end
	local list = Ser:DeserializeInstancesAsync(unb64(r.Body))
	local ks = list[1]
	if #list ~= 1 or not (ks and ks:IsA("KeyframeSequence")) then return nil, "archive file holds no KeyframeSequence" end
	return ks, nil                                                  -- unparented: the caller decides
end
```

The bake order that makes deleting safe:

```
put(original)  ->  fetch it back  ->  compare fetched vs original (or vs the stub)  ->  only then destroy the original
```

Never destroy on the strength of a `saved` reply alone: the round trip is the proof.

### Pacing

HttpService allows about **500 requests per minute for the whole place**. Archive tools wait **0.13 s** between requests (at most about 460 per minute, leaving a little headroom for other tools). A full bake of 1,000 clips is two requests per clip (put, then get back): roughly 4 to 5 minutes of paced traffic, which the tools spread over many short, resumable Studio calls ([[Studio Tooling Architecture]]). On `Number of requests exceeded limit`, wait a full minute.

### Tool behaviour when the server is down

Every operation that needs the archive (`Run`, `Verify`, `Restore`, `FetchOriginal`) pings first and errors with a clear message ("archive offline: start it with ...") instead of half-working. Read-only operations that do not need originals (`Status`, `Targets`) work without it.

## Starting and running it

- A single Python file using the standard library's threaded HTTP server; no dependencies.
- Start it detached (so closing a terminal does not stop it) and check it with `/ping` before any bake session.
- Localhost only. Never bind it to `0.0.0.0`: it accepts writes.
- The archive folder is source-code-grade data: include it in your backups.

## Security model

| Threat | Mitigation |
|---|---|
| another machine writes to your archive | bound to 127.0.0.1 |
| path traversal (`../`) | segment whitelist `[A-Za-z0-9_-]` |
| a tool writes non-model data | `<roblox!` signature check |
| a rebake silently destroys an older good version | `.prev` copies with timestamps |
| a crash leaves half a file | temp file + atomic rename |

It does not authenticate requests from local processes. On a shared machine, add a token header.

## Minimal server (sketch)

```python
import base64, http.server, os, re, time
ROOT = os.path.dirname(os.path.abspath(__file__))
NAME = re.compile(r"[A-Za-z0-9_\-]+")

def parts_of(path):
    p = [x for x in path.split("?")[0].split("/") if x]
    return p if all(NAME.fullmatch(x) for x in p) else None

class H(http.server.BaseHTTPRequestHandler):
    def reply(self, code, body):
        body = body.encode() if isinstance(body, str) else body
        self.send_response(code); self.send_header("Content-Length", str(len(body))); self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        p = parts_of(self.path)
        if not p or p[0] != "put" or len(p) < 3: return self.reply(400, "bad path")
        raw = base64.b64decode(self.rfile.read(int(self.headers.get("Content-Length", 0))))
        if not raw.startswith(b"<roblox!"): return self.reply(400, "not an rbxm")
        d = os.path.join(ROOT, *p[1:-1]); os.makedirs(d, exist_ok=True)
        f = os.path.join(d, p[-1] + ".rbxm")
        if os.path.isfile(f):
            if open(f, "rb").read() == raw: return self.reply(200, "same %d" % len(raw))
            os.replace(f, os.path.join(d, "%s.%s.prev.rbxm" % (p[-1], time.strftime("%Y%m%d-%H%M%S"))))
        with open(f + ".tmp", "wb") as h: h.write(raw)
        os.replace(f + ".tmp", f)
        self.reply(200, "saved %d" % len(raw))
    # do_GET: /ping, /list/<...>, /get/<...>/<Clip> (base64 of the file, 404 when missing)

http.server.ThreadingHTTPServer(("127.0.0.1", 8784), H).serve_forever()
```

(The production version also enforces the depth rules and the top-folder whitelist described above.)

## Failure modes seen and how they look

| Symptom | Cause | Response |
|---|---|---|
| every archive call errors "archive offline" | the server is not running (machine restarted, terminal closed) | start it detached; `/ping` before each session |
| `400 bad path` | a clip or kit name with a space, dot or other character outside the whitelist | rename the clip, or map names to safe keys and store the mapping in an attribute |
| `400 not an rbxm` | the tool sent JSON or an empty buffer (serialisation failed silently upstream) | check `buffer.len` of the serialised data before sending |
| `404 missing` on restore | the original was never archived, or archived under a different key | the stub's archive-key attribute wins over the path-derived key; never delete an original without a read-back |
| `Number of requests exceeded limit` | another tool in the same place used the HttpService budget | wait 60 s; pace at 0.13 s |
| a restore brings back an older version | someone restored from a `.prev` file by hand | `.prev` files are history, not the current version; restore by name |

## Alternatives you could choose instead

- **Roblox version history alone.** Free and automatic, but restoring one clip means opening an old place version and copying it across; fine for rare restores, painful for routine "restore, edit, rebake" loops.
- **A separate archive place.** Keeps everything in Roblox, but every restore is a cross-place copy by hand, and that place grows without bound.
- **Packages.** Good for shared models, awkward for thousands of small clips that change often.
- **A cloud bucket instead of localhost.** Works for teams, but now credentials are involved; keep tokens out of the place and out of scripts that ship.

For a single developer or small team doing frequent restore-and-rebake cycles, the local server plus files on disk (backed up with the rest of the project) was the least friction.

## Uses beyond clips

The same server archived importer save folders on models (archived, then removed), and could hold any instance you want out of the place but recoverable: retired enemy models, old map variants, design references. Anything `SerializeInstancesAsync` can write.

## See also

[[Baked Clip Stubs and Archiving]], [[Clip Buffer Format]], [[Studio Tooling Architecture]], [[Case Study - Cutting a Million Instances]], [[Performance and Memory]]

## Nuances and edge cases

1. **"Allow HTTP Requests" is a place setting, not a Studio setting.** To call localhost from the command bar or a tool, HTTP requests must be enabled for the experience. That same switch lets live game servers make outbound requests. If your game does not otherwise need HTTP, consider enabling it only in a separate tooling copy of the place, or audit every `HttpService` use before publishing so the switch does not open an unreviewed path. (Localhost requests from live Roblox servers go nowhere useful, but other outbound calls would work.)
2. **Plugins vs command bar.** Plugins prompt the user for HTTP permission per domain, and that grant is remembered; command bar code does not prompt. A team tool shipped as a plugin is easier to audit and to revoke than a pasted command bar script.
3. **Team Create and multiple machines.** The archive lives on one machine. If two developers bake clips in the same Team Create session, each writes to their own local archive and their originals diverge. Pick one: a single "bake machine", a shared network folder behind the same server (and then add the token header the security table mentions), or source control as the merge point.
4. **Scale of the archive itself.** 1,000 clips at 50 to 200 KB each is 50 to 200 MB of `.rbxm` files, and `.prev` versions grow without bound. Prune `.prev` files older than a few weeks once you trust your source control backups, or the archive ends up larger than the project.
5. **Base64 overhead.** Base64 inflates bodies by about one third. HttpService request bodies have size limits (not confirmed in docs for localhost specifically; the reference project's largest clips were well under 1 MB). If you archive large models, test the largest one first.
6. **Binary vs XML.** `SerializeInstancesAsync` produces the binary format (hence the `<roblox!` signature). Binary is compact but not diffable. If you want reviewable history in git, an XML export (`.rbxmx`) through a different tool diffs better at roughly 3 to 5 times the size (rule of thumb).
7. **Engine format changes.** Binary model files from an older Studio generally load in newer ones, but not always the reverse. Keep the archive one-way: always write from the current Studio, and avoid restoring files written by a teammate on a newer Studio build into an older one.
8. **Not for live data.** This pattern is strictly an authoring tool. Anything a live game needs at runtime must be in the place, a package, or a DataStore; a local server is never reachable from production.

The trade-off a senior developer weighs: an archive server is one more process to keep alive and back up, in exchange for a lighter place and fast single-clip restores. For a solo developer with few clips, Roblox version history is enough; the server pays off once restores are routine.

## Common mistakes

1. **Deleting originals after a `saved` reply without reading back.** Symptom: a restore later returns 404 or a truncated file. Fix: `get` and compare length or hash before deleting.
2. **Running the server from a terminal that gets closed.** Symptom: a long bake fails halfway with "archive offline". Fix: run it detached or as a background service, and ping before each batch.
3. **Archive folder outside the backup set.** Symptom: a disk failure loses every original. Fix: include it in the project backup or commit it.
4. **Binding to all interfaces "just to test from a laptop".** Symptom: anyone on the network can write files. Fix: localhost only, or a token and a firewall rule.
5. **Ignoring the HttpService budget from other tools.** Symptom: random "requests exceeded" errors mid bake. Fix: one pacing module shared by every tool in the place.

## Related decisions

- [[Plugin Security and Permissions]]: how HTTP permission grants work for tools shipped as plugins.
- [[Studio Plugins and Local HTTP Bridges]]: the general pattern of Studio talking to a local process.
- [[Version History and Backups]]: the built-in alternative and how far it gets you.
- [[Git and Source Control for Roblox]]: where the archive should ultimately be backed up.
- [[HttpService and External APIs]]: the request limits and settings this server lives within.
- [[Case Study - Instance Cleanup and Place Size]]: the place size problem the archive solves.
- [[Team Create Permissions and Workflows]]: deciding who bakes when several people edit one place.
- [[Batch Processing Tools in Studio]]: pacing and resumable batches for long archive runs.

## Connected notes
<!-- auto-links:start -->
[[Publishing Animations]] · [[Command Bar and Studio Scripting]] · Pipeline Design Principles · Asset Upload Automation with Open Cloud · Safe Changes in a Shared Place · Writing Your Own MCP Server · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Lua Keyframe Player]] · [[Weapon Rig Player]] · [[Enemy Import Axis Fix]] · [[Pipeline - Importing Animated Enemies]] · [[Pipeline - Arm IK Baking and QA]] · [[Animation Data from Blender to Roblox]] · [[Snippets - Building and Sampling Clips]] · [[Case Study - Fixing Hundreds of Attack Clips]]
<!-- related:end -->
