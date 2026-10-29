---
tags: [atlas, api, type/atlas, area/scripting, area/security, api/RemoteFunction]
---
# RemoteFunction

<!-- tldr:start -->
> [!tldr] TL;DR
> - RemoteFunction callbacks that yield can return responses out of order.
> - `RemoteEvent` for state changes, `UnreliableRemoteEvent` for replaceable cosmetic or positional updates, `RemoteFunction` only...
> - RemoteFunction with no client-side timeout plan.
> - Never return error text to the client. A RemoteFunction that errors on the server propagates an error to the invoking client.
>
> Cost: TL;DR ~140 tok · whole note ~820 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

RemoteFunction callbacks that yield can return responses out of order. (from [[RemoteEvents RemoteFunctions and Unreliable Remotes]])

API snapshot: class, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `RemoteEvent` for state changes, `UnreliableRemoteEvent` for replaceable cosmetic or positional updates, `RemoteFunction` only... ([[RemoteEvent - Engine Reference Card]])
- RemoteFunction with no client-side timeout plan. Symptom: UI hangs forever when the server handler errors. ([[Cookbook - Remotes and Networking]])
- Never return error text to the client. A RemoteFunction that errors on the server propagates an error to the invoking client. ([[Error Handling - pcall xpcall and Promise Patterns]])

## Mentioned in

43 notes in 20 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Error Handling - pcall xpcall and Promise Patterns]] · [[Error Handling and Retries]]

### 03 Architecture and Networking
[[Client-Server Model]] · [[Remote Abuse Patterns and Rate Limiting in Practice]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]]

### 04 Data and Persistence
[[DataStore Fundamentals]]

### 05 UI and UX
[[Menu Archetypes - Shop Settings Codes Rewards]]

### 12 Performance Testing and Debugging
[[Developer Console and Stats]]

### 13 Production and Case Studies
[[Case Study - Fast Join and Deferred Loading]]

### 15 AI Tools
[[AI Pitfalls - Networking and Security]]

### 22 Anti-Exploit and Security
[[Admin Commands Done Safely - Permissions and Audit Logs]] · [[Testing Your Own Remotes - Fuzzing and Abuse Tests]]

### 23 Debugging Deep Dives
[[Debugging Client-Server Desync]] · [[Debugging Live Servers]] · [[Debugging Race Conditions and Yield Order]]

### 24 Worked Builds
[[Daily Rewards System End to End]] · [[Rebirth and Prestige System End to End]] · [[Saved Inventory End to End]]

### 29 Luau Cookbook
[[Cookbook - Remotes and Networking]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Commerce and Physical Goods]]

### 50 Team Collaboration and Project Management
[[Documentation and Onboarding New Developers]]

### 58 Player QoL and Game Tweaks
[[Confirmation and Undo Patterns for Destructive and Paid Actions]] · [[Settings Menu Essentials and Persistence]]

### 62 Engine Reference Cards
[[RemoteEvent - Engine Reference Card]]

Also mentioned in (not linked): Economy Exploits - Dupes Races and Purchase Abuse · Engine and API Changes 2025-2026 · Events Signals and Connections · Functions Closures and Upvalues · Gated Tester Commands and Debug Panels · Glossary · How Exploits Work - The Client Boundary · Input Responsiveness Buffering and Coyote Time · Official Docs - Scripting and Luau · Replication Rules · Serialization Formats for Saves and Networking · Server Browsers and Server Lists · Skill - Roblox Secure Remotes · Squash Stretch and Anticipation in UI and Characters · Task Library Coroutines and Yielding · Text Filtering - TextService for Names, Signs and Messages · Threat Modeling a Roblox Game · Working with Contractors and Revenue Splits

<!-- atlas:generated -->
