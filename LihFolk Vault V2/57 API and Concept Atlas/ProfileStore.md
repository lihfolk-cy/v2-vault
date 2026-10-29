---
tags: [atlas, concept, type/atlas, area/networking, area/data]
---
# ProfileStore

<!-- tldr:start -->
> [!tldr] TL;DR
> - ProfileStore / profile library: A wrapper that adds session locking and safe saving on DataStores.
> - For whole player profiles, use a session lock (ProfileStore-style) so only one server owns the profile at a time.
> - Session locking (profile libraries such as ProfileStore): the destination waits until the source releases the lock.
>
> Cost: TL;DR ~120 tok · whole note ~270 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

ProfileStore / profile library: A wrapper that adds session locking and safe saving on DataStores. (from [[Glossary]])

## Key facts

- For whole player profiles, use a session lock (ProfileStore-style) so only one server owns the profile at a time. ([[AI Pitfalls - Data and Monetization]])
- Session locking (profile libraries such as ProfileStore): the destination waits until the source releases the lock. ([[Teleporting and Multi-Place Games]])

## Mentioned in

7 notes in 6 sections. The 7 most relevant are linked:

### 03 Architecture and Networking
[[Frameworks - Knit Matter and Others]] · [[Teleporting and Multi-Place Games]]

### 04 Data and Persistence
[[Session Locking and Profile Libraries]]

### 15 AI Tools
[[AI Pitfalls - Data and Monetization]]

### 28 Business and Careers
[[Open-Source Licenses for Roblox Libraries - Quick Reference]]

### 41 Multiplayer Services
[[Session State Across Places]]

### Root notes
[[Glossary]]

<!-- atlas:generated -->
