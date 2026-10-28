---
tags: [data, httpservice, web, secrets, json, rate-limits, external-services]
---
# HttpService and External APIs

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Keys or webhook URLs in scripts (Leaked with the place file or any shared model)
> - Avoid: One request per player event (500/min limit hit at modest player counts)
> - Avoid: `GetAsync`/`PostAsync` without `pcall` (Script errors on any failure)
> - HTTP enabled only where needed; all requests server-side.
> - Secrets in the secrets store with tight domains; local secrets for Studio.
> - One helper with `pcall`, status checks, retry on 429/5xx only, backoff, `retry-after`.
>
> Read more (18 KB note): ## A reliable request helper · ## Nuances and edge cases · ## Common mistakes · ## Checklist
<!-- tldr:end -->

`HttpService` lets game servers talk to the outside world: your own backend, analytics and error trackers, Discord-style webhooks for moderation alerts, and a growing set of Roblox Open Cloud endpoints. It also hosts the JSON and GUID helpers every Roblox codebase uses. This note covers enabling it, the request API, the limits (500 requests per minute per server, a separate 2,500 per minute for Open Cloud), the secrets store, JSON edge cases, security, and patterns for reliable outbound calls. Open Cloud from outside Roblox is in [[Open Cloud APIs]].

## Enabling and where it runs

- `GetAsync`, `PostAsync` and `RequestAsync` are disabled by default. Enable **File > Experience Settings > Security > Allow HTTP Requests**. For an unpublished place, set `game:GetService("HttpService").HttpEnabled = true` in the command bar.
- Requests only work from the **server** (and from plugins). Clients cannot make HTTP requests; if a client needs external data, the server fetches, validates and forwards it.
- `JSONEncode`, `JSONDecode` and `GenerateGUID` work regardless of the HTTP setting.
- Plugins can call any URL after the user grants permission per domain, including `localhost` / `127.0.0.1`, which is how local tool bridges work ([[Plugins - Using and Writing]]).
- `HttpService:CreateWebStreamClient()` (SSE, chunked, WebSocket-style streams) is **Studio only**, maximum four clients at once (Roblox reference, October 2026). Do not ship code that depends on it.

## The request API

Use `RequestAsync`; the `GetAsync`/`PostAsync` shortcuts throw on non-2xx responses and give you less control.

Request fields: `Url` (http or https), `Method` (`GET`, `HEAD`, `POST`, `PUT`, `DELETE`, `OPTIONS`, `TRACE`, `PATCH`), `Headers` (dictionary), `Body` (string, not allowed for GET/HEAD), `Compress` (`Enum.HttpCompression.None` or `Gzip`), `Timeout` (seconds, greater than zero and no more than the default timeout).

Response fields: `Success` (true only for status 200 to 299), `StatusCode`, `StatusMessage`, `Headers`, `Body`.

Headers: `Content-Length` is computed, `User-Agent` and `Roblox-Id` are locked by Roblox, others such as `Accept` can be overridden. `RequestAsync` does not detect the body type, so set `Content-Type` yourself (`application/json` for JSON). HTTP/2 is used automatically when available; HTTP/2 header names must be lowercase.

`RequestAsync` still **throws** for transport failures (DNS, timeouts, blocked ports, rate limit exceeded), so wrap it in `pcall`; and it **returns** for HTTP errors, so check `Success`.

## Limits (Roblox docs, October 2026)

| Limit | Value |
|---|---|
| General HTTP requests per game server | 500 per minute |
| Open Cloud requests per game server | 2,500 per minute; exceeding can stall request methods for about 30 s with "Number of Open Cloud requests exceeded limit" |
| Open Cloud per-endpoint limits | Per API key owner (user or group), counted wherever the calls come from |
| Protocol to Roblox Open Cloud | HTTPS only |
| Ports | Not 1194, nothing below 1024 except 80 and 443 (`403` or `ERR_ACCESS_DENIED` otherwise) |
| Open Cloud headers from HttpService | Only `x-api-key` and `content-type`; `x-api-key` must be a `Secret` |
| `..` in Open Cloud URL path parameters | Not allowed |

> Docs contradiction: the HttpService guide says Open Cloud requests **do not** consume the 500/minute general limit; the Open Cloud rate-limits page says in-game Open Cloud calls **also** contribute to the 500/minute limit. Budget as if they do.

500 per minute sounds like a lot until each player triggers a request: 50 players each sending an analytics event every 5 seconds is 600 per minute. **Batch.**

## A reliable request helper

```lua
--!strict
-- ServerScriptService/Net/Http (ModuleScript)
local HttpService = game:GetService("HttpService")

local Http = {}

-- Simple per-server token bucket so this server never exceeds its budget.
local CAPACITY = 60            -- burst
local REFILL_PER_SEC = 6        -- 360/min sustained: leaves headroom under 500/min for other code
local tokens = CAPACITY
local lastRefill = os.clock()

local function takeToken(): boolean
	local now = os.clock()
	tokens = math.min(CAPACITY, tokens + (now - lastRefill) * REFILL_PER_SEC)
	lastRefill = now
	if tokens >= 1 then
		tokens -= 1
		return true
	end
	return false
end

export type Response = { Success: boolean, StatusCode: number, StatusMessage: string, Headers: { [string]: string }, Body: string }

local RETRYABLE: { [number]: boolean } = { [408] = true, [425] = true, [429] = true, [500] = true, [502] = true, [503] = true, [504] = true }

function Http.request(options: { [string]: any }, attempts: number?): (boolean, Response | string)
	local maxAttempts = attempts or 3
	local delay = 1
	local last: Response | string = "no attempt"
	for attempt = 1, maxAttempts do
		while not takeToken() do
			task.wait(0.2)
		end
		local ok, res = pcall(HttpService.RequestAsync, HttpService, options)
		if ok then
			local response = res :: Response
			if response.Success then
				return true, response
			end
			last = response
			if not RETRYABLE[response.StatusCode] then
				return false, response -- 4xx: our request is wrong; retrying will not help
			end
			local retryAfter = tonumber(response.Headers["retry-after"] or response.Headers["Retry-After"])
			if retryAfter then
				delay = math.clamp(retryAfter, 1, 30)
			end
		else
			last = tostring(res) -- transport error: DNS, timeout, blocked, rate limited
		end
		if attempt < maxAttempts then
			task.wait(delay * (0.5 + math.random()))
			delay = math.min(delay * 2, 30)
		end
	end
	return false, last
end

function Http.postJson(url: string | Secret, payload: any, headers: { [string]: any }?): (boolean, Response | string)
	local h = headers or {}
	h["Content-Type"] = "application/json"
	return Http.request({ Url = url, Method = "POST", Headers = h, Body = HttpService:JSONEncode(payload) })
end

return Http
```

Then batch: queue events in memory and flush every 10 to 30 seconds, or when the batch is large, and once in `BindToClose` with a short timeout (never let telemetry block data saves; [[Saving Correctly - Autosave and BindToClose]]).

## Secrets

Never put API keys, webhook URLs or passwords in scripts: anyone with edit access, any leaked place file, and any free model you copied code into exposes them. Use the **secrets store** (Roblox docs, October 2026):

- Create secrets in Creator Dashboard > your experience > Secrets (game or group owner only), or through Open Cloud. Up to **500 secrets per game**, each up to **1,024 characters**, each bound to a **domain** (exact, `*.example.com`, or `*` which is not recommended).
- Read with `HttpService:GetSecret(name)`, which returns a `Secret` object. Its content cannot be printed. Use `secret:AddPrefix(...)` and `secret:AddSuffix(...)` to build a URL or header value; `GetAsync`/`PostAsync` URLs and request headers accept `Secret` values.
- Secrets are available on live servers and in collaborative testing. For local Play, define **Local Secrets** in Studio's Experience Settings > Security, or you get a "Can't find secret" error.

```lua
--!strict
local HttpService = game:GetService("HttpService")
local Http = require(script.Parent.Http)

local function reportToModeration(text: string)
	local url = HttpService:GetSecret("ModWebhook") -- full webhook URL stored as a secret
	Http.postJson(url, { content = string.sub(text, 1, 1800) })
end
```

## JSON details that bite

From the `HttpService` reference:

- `JSONEncode`: keys must be all strings or all numbers; with both, the array part wins and string keys are **dropped**. An empty table encodes as `[]`. Avoid `nil` holes. Cycles error. It allows `inf` and `nan`, which are **not valid JSON**; most external services will reject the payload. It accepts `buffer`s up to 50 MiB, base64-encoding them.
- `JSONDecode`: per the reference, if a JSON object contains both string and number keys, the string keys are ignored. An invalid string throws, so `pcall` it. JSON `null` values become missing keys.
- Large integers above 2^53 from external APIs (ids from other systems, snowflakes) lose precision in Luau numbers: ask the API for strings.

Validate decoded data like client input: check types, ranges, lengths. External services get compromised, change formats, or return HTML error pages with a 200 status ([[Server Authority and Validation]]).

## Talking to your own backend

When a Roblox server calls your API, your API needs to know the call is really from your game:

- Send a **shared secret** (from the secrets store) in a header; rotate it.
- Better, sign requests: HMAC of timestamp + body with the secret, and reject stale timestamps. Roblox's own webhooks use exactly this scheme ([[Player Privacy and Data Deletion]]).
- Never let clients pick the URL, method or body. The server decides what to send.
- Do not send personal data you do not need. Anything you store externally is now covered by deletion requests, and Roblox's templates cannot reach it.
- Assume Roblox servers have no fixed IP range you can allowlist (unverified; Roblox's API key guidance says not to use IP restrictions for keys used from Roblox places).

## Roblox Open Cloud from inside the game

`HttpService` can call a listed subset of Open Cloud endpoints (October 2026) including: data store and ordered data store entries, memory store queues and sorted maps (and flush), configs (read, drafts, publish), user restrictions (bans), developer products and game passes management, groups, inventory items, places and universes (including `PublishUniverseMessage` and `RestartUniverseServers`), user info and thumbnails, notifications, assets, Creator Store and Luau execution sessions. Requirements: an API key in the secrets store, the `x-api-key` header as a `Secret`, and the `content-type` header; nothing else.

```lua
--!strict
local HttpService = game:GetService("HttpService")
local Http = require(script.Parent.Http)

-- Example: read another experience's (or this one's) data store entry via Open Cloud v2.
local function getEntry(universeId: number, dataStore: string, entryKey: string): any?
	local ok, res = Http.request({
		Url = `https://apis.roblox.com/cloud/v2/universes/{universeId}/data-stores/{dataStore}/entries/{entryKey}`,
		Method = "GET",
		Headers = { ["x-api-key"] = HttpService:GetSecret("OpenCloudKey") },
	})
	if not ok then
		return nil
	end
	local decoded = nil
	pcall(function()
		decoded = HttpService:JSONDecode((res :: any).Body)
	end)
	return decoded
end
```

Why call Open Cloud from a game when `DataStoreService` exists? Mostly for **cross-experience** access (a hub game reading a sequel's store), for APIs with no engine equivalent (bans by API, configs drafts, product management), or for features like `RestartUniverseServers`. Inside one experience, prefer the engine APIs: they use the server's own budgets and have no key to leak.

## Development tooling over HTTP (Studio)

One production team served large generated source files from a local static HTTP server (`127.0.0.1`) and pulled them into Studio from the command bar with `HttpService:GetAsync(url)` instead of pasting 40 KB scripts by hand. Notes if you copy that idea: it only works in Studio (command bar and plugins, with HTTP enabled), localhost ports can be taken by other tools so keep the port configurable, and executing fetched code is only acceptable for files you generated yourself. `loadstring` is disabled for game servers by default (`ServerScriptService.LoadStringEnabled`); never enable it in a live game to execute remote code ([[Command Bar and Studio Scripting]], [[External Tooling - Rojo Wally Selene StyLua]]).

## Observability

The HttpService observability dashboard (Creator Hub) shows Request Count (by method and status class: success, redirect, 400, 401, 403, 404, 429, 500, 503, external and internal errors) and Response Time. Watch 429s after adding a new integration.

## Common mistakes

| Mistake | Consequence |
|---|---|
| Keys or webhook URLs in scripts | Leaked with the place file or any shared model |
| One request per player event | 500/min limit hit at modest player counts |
| `GetAsync`/`PostAsync` without `pcall` | Script errors on any failure |
| Treating `RequestAsync` returning as success | 4xx/5xx bodies parsed as data |
| Retrying 4xx | Wasted budget; never succeeds |
| Sending `inf`/`nan` in JSON | External APIs reject the payload |
| Blocking `BindToClose` on telemetry | Player saves time out |
| Trusting external data | Injection of bad values into your economy |
| Discord webhooks as a logging pipeline | Discord rate limits and blocks abusive senders; use a proper ingest endpoint and keep Discord for human alerts |

## Checklist

- [ ] HTTP enabled only where needed; all requests server-side.
- [ ] Secrets in the secrets store with tight domains; local secrets for Studio.
- [ ] One helper with `pcall`, status checks, retry on 429/5xx only, backoff, `retry-after`.
- [ ] Per-server rate limiting and batching.
- [ ] Decoded data validated.
- [ ] Own backend authenticates requests (secret or HMAC).
- [ ] No unnecessary personal data leaves Roblox.

## See also
[[Open Cloud APIs]] · [[Player Privacy and Data Deletion]] · [[Global State and Live Config]] · [[Crash and Error Telemetry]] · [[Analytics and Funnels]] · [[Error Handling and Retries]] · [[Plugins - Using and Writing]] · [[Server Authority and Validation]]

## Nuances and edge cases

1. **The budget is per server, the load is per player.** The limit is 500 requests per minute per game server (Roblox docs, as of October 2026; going over can stall requests for about 30 seconds). One request per player action works with 5 players and fails at 50. Design every integration as "per server, batched", never "per player event".
2. **Your backend sees all servers at once.** Your own server receives the sum of every Roblox server's traffic. At launch with 1,000 servers, a once-a-minute heartbeat is 1,000 requests a minute to your backend. Size the backend for peak server count, not average, and add jitter so servers do not all call at the same second.
3. **External failures must not become game failures.** A third-party API going down should degrade a feature (no leaderboard on the website, no Discord post), never block saving, joining or purchases. Wrap calls with timeouts, retries with backoff for 5xx and network errors, and a circuit breaker that stops calling after repeated failures for a while.
4. **Latency is uneven.** Roblox servers run in many regions; your backend may be far from some of them. A call that takes 50 ms from one region can take several hundred from another. Never call external services in the path of a player action that should feel instant.
5. **Secrets belong in the secrets store.** HttpService supports secrets configured in the experience settings rather than in scripts (Roblox docs, as of October 2026: `HttpService:GetSecret(key)` returns a `Secret`, with the value set in Creator Hub). Any key in a script is visible to anyone with edit access and to anyone who obtains the place file.
6. **Studio and live behave differently.** HTTP must be enabled per experience, and Studio requests come from your machine context, not from Roblox's servers. An integration that works in Studio can fail live because of IP allow-lists on your backend or different network paths.
7. **Inbound data is untrusted.** Data from your backend should be validated as strictly as remote arguments: types, ranges, sizes. A compromised or buggy backend that returns a huge reward value should hit a server-side cap, not credit players.
8. **Third-party terms.** Services such as chat platforms rate limit and may block senders that look abusive. Using them as logging pipelines at scale breaks both your logs and possibly your account there.

The senior trade-off: an external backend adds power (web dashboards, cross-game data, moderation tools) and a second system to run, secure and pay for. Use Roblox's own services (DataStores, MemoryStore, Open Cloud) first, and add a backend only for what they cannot do.

## Common mistakes (advanced)

1. **No jitter on periodic calls.** Symptom: backend load spikes every minute on the minute. Fix: random offset per server.
2. **Synchronous external calls in purchase or save paths.** Symptom: purchases fail when a third party is down. Fix: queue outbound calls; never block core paths.
3. **No circuit breaker.** Symptom: during an outage every server wastes its whole request budget on failing calls. Fix: stop calling for a cooldown after N consecutive failures.
4. **Backend sized for average load.** Symptom: outage at launch or during a front-page feature. Fix: load-test for peak servers.
5. **Trusting backend responses.** Symptom: one bad deploy of your backend corrupts the in-game economy. Fix: validate and cap.
6. **Logging request bodies with personal data.** Symptom: privacy exposure in third-party logs. Fix: send ids, not names, and keep logs minimal.

## Related decisions

- [[Open Cloud APIs]]: Roblox's own APIs, often a better fit than a custom backend.
- [[Crash and Error Telemetry]]: batching telemetry within the request budget.
- [[Player Privacy and Data Deletion]]: what may leave Roblox and how to delete it.
- [[Discord Servers for Roblox Games]]: community integrations and their limits.
- [[Asset Upload Automation with Open Cloud]]: HTTP from the tooling side.
- [[Economy Exploits - Dupes Races and Purchase Abuse]]: why backend data must be capped.
- [[Studio Plugins and Local HTTP Bridges]]: HTTP in Studio tooling.
- [[Live Incident Response and Post-Mortems]]: handling third-party outages.

## Connected notes
<!-- auto-links:start -->
[[Links - Open Cloud and external APIs]] · [[Telemetry Events]] · [[Plugin Security and Permissions]] · [[DataStore Fundamentals]] · [[Clip Archive Server]] · [[Batch Processing Tools in Studio]]
<!-- auto-links:end -->
