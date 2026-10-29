---
tags: [atlas, api, type/atlas, area/liveops, area/economy, api/ConfigService]
---
# ConfigService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ConfigService` is server-only. Calling it from a client script errors.
> - `ConfigService:GetConfigAsync()` returns a `ConfigSnapshot` of global values (no targeting).
> - History and Restore for every change, and `ConfigService:SetTestingValue` to override a value on one server (or one Studio...
> - Configs: live key/value config with staging and targeting, read through `ConfigService` (see Global State and Live Config).
>
> Cost: TL;DR ~150 tok · whole note ~360 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ConfigService` is server-only. Calling it from a client script errors. (from [[A-B Testing and Experiments on Roblox]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `ConfigService:GetConfigAsync()` returns a `ConfigSnapshot` of global values (no targeting). ([[Global State and Live Config]])
- History and Restore for every change, and `ConfigService:SetTestingValue` to override a value on one server (or one Studio session). ([[Feature Flags and Staged Rollouts]])
- Configs: live key/value config with staging and targeting, read through `ConfigService` (see Global State and Live Config). ([[Places Universes and Experience Settings]])

## Mentioned in

9 notes in 5 sections. The 9 most relevant are linked:

### 01 Studio and Workflow
[[Places Universes and Experience Settings]]

### 04 Data and Persistence
[[Global State and Live Config]]

### 27 Marketing and Growth
[[A-B Testing and Experiments on Roblox]]

### 38 Live Ops Deep Dive
[[Event Calendars and Content Planning]] · [[Feature Flags and Staged Rollouts]] · [[Live Ops Deep Dive Start Here]] · [[Patch Notes and Player Communication]]

### 48 Economy Design Deep Dive
[[Economy Design Start Here]] · [[Economy Telemetry and Balancing Live]]

<!-- atlas:generated -->
