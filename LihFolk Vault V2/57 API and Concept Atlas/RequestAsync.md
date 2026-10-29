---
tags: [atlas, api, type/atlas, area/scripting, area/data, api/RequestAsync]
---
# RequestAsync

<!-- tldr:start -->
> [!tldr] TL;DR
> - `RequestAsync` does not detect the body type, so set `Content-Type` yourself (`application/json` for JSON).
> - Every request in `pcall` with backoff, using `RequestAsync` and checking `StatusCode`.
> - `GetAsync`, `PostAsync` and `RequestAsync` are disabled by default.
>
> Cost: TL;DR ~110 tok · whole note ~280 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`RequestAsync` does not detect the body type, so set `Content-Type` yourself (`application/json` for JSON). (from [[HttpService and External APIs]])

API snapshot: member of `HttpRbxApiService`, `HttpService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Every request in `pcall` with backoff, using `RequestAsync` and checking `StatusCode`. ([[HttpService - Engine Reference Card]])
- `GetAsync`, `PostAsync` and `RequestAsync` are disabled by default. ([[HttpService and External APIs]])

## Mentioned in

7 notes in 6 sections. The 7 most relevant are linked:

### 02 Luau Scripting
[[Error Handling and Retries]] · [[Task Library Coroutines and Yielding]]

### 04 Data and Persistence
[[HttpService and External APIs]]

### 08 Animation
[[Clip Archive Server]]

### 15 AI Tools
[[In-Game AI - LLM NPCs and Text Generation]]

### 16 MCP and Agents
[[Writing Your Own MCP Server]]

### 62 Engine Reference Cards
[[HttpService - Engine Reference Card]]

<!-- atlas:generated -->
