---
tags: [atlas, api, type/atlas, area/gameplay, area/networking, api/Teams]
---
# Teams

<!-- tldr:start -->
> [!tldr] TL;DR
> - Teams are attributes, not the `Teams` service.
> - Teams with unique colours; friendly fire in the damage core.
> - Spawning Teams and Rounds, Camera Systems, Social Design and Multiplayer Play.
> - For team modes, assign `Teams` in `Start` and return the winning team's players from `Winners` (see Spawning Teams and Rounds).
>
> Cost: TL;DR ~120 tok · whole note ~310 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Teams are attributes, not the `Teams` service. `Teams` and `Player.Team` are server-wide: a player can be on one team in the whole server. (from [[Arena Rounds with Teams and Spectating End to End]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Teams with unique colours; friendly fire in the damage core. ([[Spawning Teams and Rounds]])
- Spawning Teams and Rounds, Camera Systems, Social Design and Multiplayer Play. ([[Arena Rounds with Teams and Spectating End to End]])
- For team modes, assign `Teams` in `Start` and return the winning team's players from `Winners` (see Spawning Teams and Rounds). ([[Round-Based Minigame Loop End to End]])

## Mentioned in

5 notes in 4 sections. The 5 most relevant are linked:

### 03 Architecture and Networking
[[Client-Server Model]]

### 09 Gameplay Systems
[[Police Chases and Wanted Levels]] · [[Spawning Teams and Rounds]]

### 24 Worked Builds
[[Round-Based Minigame Loop End to End]]

### 43 Genre Systems End to End
[[Arena Rounds with Teams and Spectating End to End]]

<!-- atlas:generated -->
