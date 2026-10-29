---
tags: [atlas, api, type/atlas, area/platform, area/data, api/GetRequestBudgetForRequestType]
---
# GetRequestBudgetForRequestType

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetRequestBudgetForRequestType` is logged before bulk reads or writes.
> - Background jobs self-throttle with `GetRequestBudgetForRequestType` or HTTP-side limits.
> - Every read and write wrapped in `pcall`, retried with backoff, and checked against `GetRequestBudgetForRequestType` in hot paths.
>
> Cost: TL;DR ~120 tok · whole note ~320 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetRequestBudgetForRequestType` is logged before bulk reads or writes. (from [[Engine Limits, Quotas and Defaults - Cheat Sheet]])

API snapshot: member of `DataStoreService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Background jobs self-throttle with `GetRequestBudgetForRequestType` or HTTP-side limits. ([[Data and Cloud Changes 2025-2026]])
- Every read and write wrapped in `pcall`, retried with backoff, and checked against `GetRequestBudgetForRequestType` in hot paths. ([[DataStoreService - Engine Reference Card]])

## Mentioned in

8 notes in 6 sections. The 8 most relevant are linked:

### 04 Data and Persistence
[[DataStore Fundamentals]]

### 23 Debugging Deep Dives
[[Debugging DataStore Problems]]

### 24 Worked Builds
[[Global Leaderboards End to End]]

### 29 Luau Cookbook
[[Cookbook - Data and Saving]]

### 49 Roblox Platform Features
[[Data and Cloud Changes 2025-2026]] · [[Engine Limits, Quotas and Defaults - Cheat Sheet]] · [[Engine and API Changes 2025-2026]]

### 62 Engine Reference Cards
[[DataStoreService - Engine Reference Card]]

<!-- atlas:generated -->
