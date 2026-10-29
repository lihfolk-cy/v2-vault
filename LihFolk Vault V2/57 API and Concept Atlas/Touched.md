---
tags: [atlas, api, type/atlas, area/gameplay, area/networking, api/Touched]
---
# Touched

<!-- tldr:start -->
> [!tldr] TL;DR
> - `Touched` fires per contact start and can fire many times per second for a moving part.
> - Avoid: granting rewards from a `Touched` handler with no debounce.
> - Player-chosen actions use `ProximityPrompt`; walk-into actions use `Touched`; areas use point tests or spatial queries.
> - Zone does not notice a player who stood still: `Touched` for zones -> Poll point-in-shape tests.
>
> Cost: TL;DR ~140 tok · whole note ~820 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`Touched` fires per contact start and can fire many times per second for a moving part. (from [[Physics Performance]])

`Touched` fires on contact events, which depend on physics, ownership and part movement; a player standing still inside a zone that appeared around them may never fire it. (from [[Intersection and Collision Math]])

API snapshot: member of `BasePart`, `Humanoid` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: granting rewards from a `Touched` handler with no debounce. ([[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]])
- Player-chosen actions use `ProximityPrompt`; walk-into actions use `Touched`; areas use point tests or spatial queries. ([[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]])
- Zone does not notice a player who stood still: `Touched` for zones -> Poll point-in-shape tests. ([[Intersection and Collision Math]])
- Zones are polled with containment tests, not `Touched`. ([[Intersection and Collision Math]])
- Avoid: Unanchored part plus `Touched` for bullets -> Simulated point with swept casts. ([[Projectiles and Ballistics]])

## Mentioned in

31 notes in 19 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[CollectionService Patterns]] · [[Events Signals and Connections]]

### 03 Architecture and Networking
[[Instance Streaming]]

### 06 World Building and Art
[[Collision and Physics Geometry]]

### 07 Lighting VFX and Audio
[[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop]]

### 08 Animation
[[Accessories and Armor That Follow Animation]]

### 09 Gameplay Systems
[[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]] · [[Hitboxes and Hit Detection]] · [[Physics Assemblies and Constraints]] · [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]

### 12 Performance Testing and Debugging
[[Physics Performance]]

### 15 AI Tools
[[AI Pitfalls - Networking and Security]]

### 22 Anti-Exploit and Security
[[How Exploits Work - The Client Boundary]]

### 23 Debugging Deep Dives
[[Debugging Physics and Network Ownership]]

### 24 Worked Builds
[[Round-Based Minigame Loop End to End]]

### 25 Physics and Vehicles
[[Projectiles and Ballistics]]

### 29 Luau Cookbook
[[Cookbook - Players and Characters]]

### 33 Level Design
[[Kill Planes, Map Boundaries and Out-of-Bounds Recovery]] · [[Lobby and Hub Design]]

### 37 Avatars and UGC
[[Avatar Body Types and Scale in Gameplay]]

### 40 Game Math
[[Intersection and Collision Math]]

### 43 Genre Systems End to End
[[Racing Laps and Checkpoints End to End]]

### 50 Team Collaboration and Project Management
[[Code Review for Luau Teams]]

### 51 2D Game Development
[[A 2D Engine in a ScreenGui - Game Loop Entities and Rendering]]

Also mentioned in (not linked): Game Math Start Here · Melee Combat System End to End · Obby Checkpoints and Stage Saves End to End · Remote Abuse Patterns and Rate Limiting in Practice · Replication Rules · Threat Modeling a Roblox Game

<!-- atlas:generated -->
