---
tags: [atlas, api, type/atlas, area/scripting, area/networking, api/InvokeClient]
---
# InvokeClient

<!-- tldr:start -->
> [!tldr] TL;DR
> - `RemoteFunction:InvokeClient` makes the server call one client and yield until that client returns a value; the vault rules it...
> - If the client throws an error, the server throws too; if it disconnects mid-call, `InvokeClient` errors (RemoteEvents...
> - If the client never returns a value, the server yields forever, so an exploiter can leak server threads (and any lock they...
> - Avoid: `InvokeClient` for anything -> Event plus reply event with timeout.
>
> Cost: TL;DR ~160 tok · whole note ~510 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`RemoteFunction:InvokeClient` makes the server call one client and yield until that client returns a value; the vault rules it out for every use (from [[RemoteEvents RemoteFunctions and Unreliable Remotes]]; Roblox docs).

API snapshot: member of `RemoteFunction` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- If the client throws an error, the server throws too; if it disconnects mid-call, `InvokeClient` errors ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]; Roblox docs).
- If the client never returns a value, the server yields forever, so an exploiter can leak server threads (and any lock they hold) with an `OnClientInvoke` that never returns ([[RemoteEvents RemoteFunctions and Unreliable Remotes]]).
- Avoid: `InvokeClient` for anything -> Event plus reply event with timeout. ([[RemoteEvents RemoteFunctions and Unreliable Remotes]])

## Mentioned in

15 notes in 11 sections. The 15 most relevant are linked:

### 02 Luau Scripting
[[Error Handling and Retries]] · [[Task Library Coroutines and Yielding]]

### 03 Architecture and Networking
[[Remote Abuse Patterns and Rate Limiting in Practice]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]]

### 15 AI Tools
[[AI Pitfalls - Networking and Security]] · [[What AI Models Get Wrong in Roblox]]

### 22 Anti-Exploit and Security
[[Economy Exploits - Dupes Races and Purchase Abuse]]

### 23 Debugging Deep Dives
[[Debugging Race Conditions and Yield Order]]

### 24 Worked Builds
[[Saved Inventory End to End]]

### 29 Luau Cookbook
[[Cookbook - Remotes and Networking]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Engine and API Changes 2025-2026]]

### 50 Team Collaboration and Project Management
[[Code Review for Luau Teams]]

### 62 Engine Reference Cards
[[RemoteEvent - Engine Reference Card]]

### Root notes
[[Skill - Roblox Secure Remotes]]

<!-- atlas:generated -->
