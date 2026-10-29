---
tags: [atlas, api, type/atlas, area/scripting, area/networking, api/InvokeClient]
---
# InvokeClient

<!-- tldr:start -->
> [!tldr] TL;DR
> - `InvokeClient` (server asks a client) is the dangerous one.
> - No `InvokeClient`. (AI Pitfalls - Networking and Security)
> - Avoid: `InvokeClient` for anything -> Event plus reply event with timeout.
> - No `InvokeClient` anywhere. (RemoteEvents RemoteFunctions and Unreliable Remotes)
>
> Cost: TL;DR ~110 tok · whole note ~430 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`InvokeClient` (server asks a client) is the dangerous one. (from [[RemoteEvents RemoteFunctions and Unreliable Remotes]])

API snapshot: member of `RemoteFunction` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- No `InvokeClient`. ([[AI Pitfalls - Networking and Security]])
- Avoid: `InvokeClient` for anything -> Event plus reply event with timeout. ([[RemoteEvents RemoteFunctions and Unreliable Remotes]])
- No `InvokeClient` anywhere. ([[RemoteEvents RemoteFunctions and Unreliable Remotes]])
- Avoid: Using `InvokeClient` for gameplay. ([[Cookbook - Remotes and Networking]])

## Mentioned in

14 notes in 11 sections. The 14 most relevant are linked:

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

### 46 Resource Library
[[Links - Remote events and functions]]

### 49 Roblox Platform Features
[[Engine and API Changes 2025-2026]]

### 50 Team Collaboration and Project Management
[[Code Review for Luau Teams]]

### Root notes
[[Skill - Roblox Secure Remotes]]

<!-- atlas:generated -->
