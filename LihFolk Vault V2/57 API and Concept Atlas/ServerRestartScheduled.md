---
tags: [atlas, api, type/atlas, area/networking, area/studio, api/ServerRestartScheduled]
---
# ServerRestartScheduled

<!-- tldr:start -->
> [!tldr] TL;DR
> - `ServerRestartScheduled` drives a drain state that other systems query.
> - `ServerRestartScheduled` warns players and triggers early saves.
> - Do the work in `ServerRestartScheduled`, not in `BindToClose`.
>
> Cost: TL;DR ~90 tok · whole note ~250 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`ServerRestartScheduled` drives a drain state that other systems query. (from [[Server Shutdowns Soft Updates and Migration]])

API snapshot: member of `DataModel` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `ServerRestartScheduled` warns players and triggers early saves. ([[Server Lifecycle and Shutdown]])
- Do the work in `ServerRestartScheduled`, not in `BindToClose`. You have minutes in the first and 30 seconds in the second. ([[Server Shutdowns Soft Updates and Migration]])

## Mentioned in

4 notes in 3 sections. The 4 most relevant are linked:

### 01 Studio and Workflow
[[Places Universes and Experience Settings]]

### 03 Architecture and Networking
[[Server Lifecycle and Shutdown]]

### 41 Multiplayer Services
[[Multiplayer Services Start Here]] · [[Server Shutdowns Soft Updates and Migration]]

<!-- atlas:generated -->
