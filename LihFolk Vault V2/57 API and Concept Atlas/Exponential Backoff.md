---
tags: [atlas, concept, type/atlas, area/data, area/scripting]
---
# Exponential Backoff

<!-- tldr:start -->
> [!tldr] TL;DR
> - Exponential backoff gives the service time to recover instead of hammering it inside the same throttle window.
> - DataStore throttling cascades: Immediate retries in a loop -> Backoff with jitter; attempt cap.
> - Uploader: content types, polling, backoff on 429/5xx, hash skip.
> - DataStore calls in `pcall` with backoff and jitter; throttle codes logged; per-server limits raised with...
>
> Cost: TL;DR ~140 tok · whole note ~570 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Exponential backoff gives the service time to recover instead of hammering it inside the same throttle window. (from [[Cookbook - Data and Saving]])

## Key facts

- DataStore throttling cascades: Immediate retries in a loop -> Backoff with jitter; attempt cap. ([[Error Handling and Retries]])
- Uploader: content types, polling, backoff on 429/5xx, hash skip. ([[Asset Upload Automation with Open Cloud]])
- DataStore calls in `pcall` with backoff and jitter; throttle codes logged; per-server limits raised with... ([[Data and Cloud Changes 2025-2026]])
- Every data store call is in `pcall`, with transient-error retry and backoff. ([[DataStore Fundamentals]])
- Block list empty at start: `GetCore` not ready -> Retry with backoff. ([[Block and Mute Respecting Platform Rules]])

## Mentioned in

24 notes in 14 sections. The 24 most relevant are linked:

### 02 Luau Scripting
[[Error Handling - pcall xpcall and Promise Patterns]] · [[Error Handling and Retries]]

### 03 Architecture and Networking
[[Cross-Server Messaging]]

### 04 Data and Persistence
[[DataStore Fundamentals]] · [[HttpService and External APIs]] · [[MemoryStore Service]] · [[Saving Correctly - Autosave and BindToClose]]

### 11 Monetization Publishing and Live Ops
[[Game Passes]]

### 13 Production and Case Studies
[[Asset Pipelines]]

### 15 AI Tools
[[AI Pitfalls - Assets and Import]] · [[AI Pitfalls - Data and Monetization]]

### 17 Pipelines
[[Asset Upload Automation with Open Cloud]]

### 23 Debugging Deep Dives
[[Debugging DataStore Problems]]

### 24 Worked Builds
[[LihFolk Systems - Data and Purchase Guarantees]]

### 29 Luau Cookbook
[[Cookbook - Data and Saving]] · [[Luau Cookbook Start Here]]

### 49 Roblox Platform Features
[[Badges and Achievement Design]] · [[Data and Cloud Changes 2025-2026]]

### 58 Player QoL and Game Tweaks
[[Block and Mute Respecting Platform Rules]]

### 62 Engine Reference Cards
[[DataStoreService - Engine Reference Card]] · [[HttpService - Engine Reference Card]] · [[MemoryStoreService - Engine Reference Card]] · [[TeleportService - Engine Reference Card]]

### Root notes
[[Skill - Roblox DataStore Safety]]

<!-- atlas:generated -->
