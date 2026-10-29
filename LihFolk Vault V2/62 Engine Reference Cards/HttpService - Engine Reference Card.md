---
tags: [reference, engine, httpservice, api/HttpService, type/reference, area/scripting, level/intermediate, api/RequestAsync]
---

# HttpService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: putting API keys in script source.
> - Avoid: one request per player per event.
> - Avoid: `GetAsync` when you need status codes.
> - Every request in `pcall` with backoff, using `RequestAsync` and checking `StatusCode`.
> - Credentials kept in the secrets store; nothing secret printed or sent to clients.
> - External and Open Cloud request rates budgeted separately per server.
>
> Cost: TL;DR ~140 tok · whole note ~1.3k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Outbound web requests, selected Open Cloud endpoints, secrets, plus the JSON, GUID and URL helpers every project uses. Topic notes: [[HttpService and External APIs]], [[Open Cloud APIs]], [[Studio Plugins and Local HTTP Bridges]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| HttpEnabled | prop | boolean | off until "Allow HTTP Requests" is enabled | Gates `GetAsync`, `PostAsync` and `RequestAsync` only | - |
| [[RequestAsync]] | method | `(requestOptions: {Url, Method?, Headers?, Body?, Compress?, Timeout?}) -> {Success, StatusCode, StatusMessage, Headers, Body}` | Method optional | Preferred call; any verb, full response | yes |
| GetAsync | method | `(url: string \| Secret, nocache: bool = false, headers: Dictionary?) -> string` | nocache false | Shorthand; body only | yes |
| PostAsync | method | `(url: string \| Secret, data: string, content_type: Enum.HttpContentType = ApplicationJson, compress: bool = false, headers: Dictionary?) -> string` | ApplicationJson | Shorthand; body only | yes |
| GetSecret | method | `(key: string) -> Secret` | - | Reads the experience secrets store; value is never printable | no |
| JSONEncode | method | `(input: Variant) -> string` | - | Works without HTTP enabled; errors on cyclic tables | no |
| JSONDecode | method | `(input: string) -> Variant` | - | Works without HTTP enabled; errors on invalid JSON | no |
| GenerateGUID | method | `(wrapInCurlyBraces: bool = true) -> string` | braces on | Random 128-bit id; works without HTTP enabled | no |
| UrlEncode | method | `(input: string) -> string` | - | Percent-encodes query values | no |
| CreateWebStreamClient | method | `(streamClientType: Enum.WebStreamClientType, requestOptions: Dictionary) -> WebStreamClient` | - | Studio only; SSE, RawStream or WebSocket | no |
| WebStreamClient:Close | method | `() -> ()` | - | Frees one of the 4 stream slots | no |
| RequestAsync `Compress` | field | `Enum.HttpCompression` | None | `Enum.HttpCompression.Gzip` compresses the body | - |
| RequestAsync `Timeout` | field | integer (s) | platform default | Must be above zero and no larger than the default | - |
| Response `Success` | field | boolean | - | True only for status 200-299 | - |

## Limits and defaults

- External requests: 500 per minute per game server; requests over it fail.
- Open Cloud requests through `HttpService`: a separate 2,500 per minute per game server; over it, calls can stall about 30 s and `pcall` may report "Number of Open Cloud requests exceeded limit".
- Open Cloud calls: only `x-api-key` (as a `Secret`) and `content-type` headers, and no `..` in URL path parameters.
- HTTPS only; port 1194 and ports below 1024 except 80 and 443 are blocked (403 Forbidden or ERR_ACCESS_DENIED).
- Web stream clients: 4 open at a time, Studio only.
- `GenerateGUID`: 36 characters in `8-4-4-4-12` form, 38 with braces.
- `JSONEncode`: an empty table becomes `[]`; mixed keys keep only the array part; `inf` and `nan` are emitted even though they are not valid JSON.

## Replication and authority

- Make web requests from server Scripts; the request quotas are counted per game server, and secrets stay on the server.
- "Allow HTTP Requests" lives in File > Experience Settings > Security; for an unpublished place set `HttpEnabled = true` from the Command Bar.
- Plugins may call `localhost` and `127.0.0.1` to talk to local tools; the user can be asked to grant a plugin HTTP permission.
- Your web server should authenticate callers, for example with a pre-shared secret, because anyone can send it requests.

## Common mistakes

- Avoid: putting API keys in script source. Symptom: the key leaks with any copy of the place; store it as a secret and read it with `GetSecret`.
- Avoid: one request per player per event. Symptom: the 500-per-minute budget runs out; batch into a single request.
- Avoid: `GetAsync` when you need status codes. Symptom: error pages arrive as plain strings or errors; use `RequestAsync` and check `Success`.
- Avoid: shipping `CreateWebStreamClient` in game scripts. Symptom: it works only in Studio; keep streaming in plugins.
- Avoid: requests without `pcall`. Symptom: a timeout or blocked host stops the calling thread with an error.

## Checklist

- Every request in `pcall` with backoff, using `RequestAsync` and checking `StatusCode`.
- Credentials kept in the secrets store; nothing secret printed or sent to clients.
- External and Open Cloud request rates budgeted separately per server.
- JSON payloads free of `nil` gaps, cycles, `inf` and `nan`.

Source: https://create.roblox.com/docs/reference/engine/classes/HttpService and https://create.roblox.com/docs/cloud-services/http-service - verified 2026-10-29

<!-- related:start -->
## Related
[[MessagingService - Engine Reference Card]] · [[DataStoreService - Engine Reference Card]] · [[MemoryStoreService - Engine Reference Card]] · [[TeleportService - Engine Reference Card]] · [[Players - Engine Reference Card]] · [[PathfindingService - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[BadgeService - Engine Reference Card]]
<!-- related:end -->
