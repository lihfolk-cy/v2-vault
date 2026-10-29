---
tags: [resources, links, official-docs, type/reference, area/data, level/beginner, api/DataStoreService, api/PlayerRemoving, api/BindToClose]
---
# Official Docs - Data and Persistence

Official references for saving and sharing data: DataStoreService, MemoryStoreService, leaderboards and data-safety guidance. Part of the [[Resource Library Start Here]].

Every link below goes to a first-party source: the Roblox Creator Hub, official Roblox announcements, the Luau project or the Blender manual. 32 links.

## DataStoreService

### Core docs
- https://create.roblox.com/docs/cloud-services/data-stores
- https://create.roblox.com/docs/reference/engine/classes/DataStoreService
- https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore
- https://create.roblox.com/docs/cloud-services/data-stores/best-practices
- https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits
- https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching
- https://create.roblox.com/docs/cloud-services/data-stores/data-stores-manager
- https://create.roblox.com/docs/tutorials/core/scripting/record-and-display-player-data

### Saving on PlayerRemoving & BindToClose
- https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing

### Autosaving
- https://create.roblox.com/docs/tutorials/use-case-tutorials/data-storage/save-player-data

### Testing DataStores in Studio
- https://github.com/Roblox/creator-docs/blob/main/content/en-us/cloud-services/data-stores/index.md

## Leaderboards

### Leaderstats
- https://create.roblox.com/docs/players/leaderboards
- https://create.roblox.com/docs/tutorials/use-case-tutorials/scripting/basic-scripting/score-points
- https://create.roblox.com/docs/education/adventure-game-series/code-the-leaderboard

### Global leaderboards (OrderedDataStore)
- https://create.roblox.com/docs/reference/engine/classes/OrderedDataStore
- https://create.roblox.com/docs/tutorials/use-case-tutorials/data-storage/create-leaderboard

## MemoryStore

### Docs
- https://create.roblox.com/docs/cloud-services/memory-stores
- https://create.roblox.com/docs/reference/engine/classes/MemoryStoreService
- https://create.roblox.com/docs/cloud-services/memory-stores/best-practices
- https://create.roblox.com/docs/cloud-services/memory-stores/sorted-map
- https://create.roblox.com/docs/cloud-services/memory-stores/queue
- https://create.roblox.com/docs/cloud-services/memory-stores/hash-map
- https://create.roblox.com/docs/cloud-services/memory-stores/observability

### Sorted maps for live leaderboards
- https://create.roblox.com/docs/reference/engine/classes/MemoryStoreSortedMap
- https://devforum.roblox.com/t/memorystore-sortedmap-sortkey-full-release/2872814

### Queues for matchmaking
- https://create.roblox.com/docs/reference/engine/classes/MemoryStoreQueue
- https://create.roblox.com/docs/scripting/data/memory-stores

### Server lists
- https://create.roblox.com/docs/cloud-services/data-stores-vs-memory-stores

## Session locking and data safety

### How session locking works
- https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing

### Handling DataStore outages
- https://create.roblox.com/docs/cloud-services/data-stores/best-practices
- https://create.roblox.com/docs/cloud/guides/data-store-api-handling

### GDPR & right-to-erasure requests
- https://create.roblox.com/docs/cloud/webhooks/automate-right-to-erasure
