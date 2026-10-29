---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/CharacterAdded]
---
# CharacterAdded

<!-- tldr:start -->
> [!tldr] TL;DR
> - `CharacterAdded` fires before appearance loads.
> - Avoid: Connecting `PlayerAdded` or `CharacterAdded` after a yield, without handling players or characters already present.
> - Every `CharacterAdded` handler also handles an existing character.
> - Connect CharacterAdded first, then handle a character that already exists.
>
> Cost: TL;DR ~120 tok · whole note ~820 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`CharacterAdded` fires before appearance loads. Use `Player.CharacterAppearanceLoaded` to know when the platform avatar has finished; applying before that can be overwritten by the engine's own appearance load. (from [[HumanoidDescription and Outfit Systems]])

API snapshot: member of `Player` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: Connecting `PlayerAdded` or `CharacterAdded` after a yield, without handling players or characters already present. ([[Debugging Race Conditions and Yield Order]])
- Every `CharacterAdded` handler also handles an existing character. ([[Cookbook - Players and Characters]])
- Connect CharacterAdded first, then handle a character that already exists. ([[Player - Engine Reference Card]])
- Avoid: Relying on random SpawnLocation choice -> Place in `CharacterAdded` ([[Spawning Teams and Rounds]])

## Mentioned in

39 notes in 20 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Events Signals and Connections]] · [[Functions Closures and Upvalues]]

### 05 UI and UX
[[Nametags and Overhead Bars - Cost and Visibility Rules]]

### 06 World Building and Art
[[Collision and Physics Geometry]]

### 07 Lighting VFX and Audio
[[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]]

### 08 Animation
[[AnimationTrack Reference]] · [[Custom Characters and StarterCharacter]] · [[Custom Locomotion Controller Design]] · [[Snippets - Playing Animations]]

### 09 Gameplay Systems
[[Character Select and Class Systems with Different Rigs]] · [[Characters and Humanoids]] · [[Spawning Teams and Rounds]] · [[Tools and Inventory Systems]] · [[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]

### 10 Game Design and Genres
[[Genre Playbook - Obbies and Platformers]]

### 11 Monetization Publishing and Live Ops
[[Game Passes]]

### 15 AI Tools
[[AI Code Assistants for Luau]] · [[AI Pitfalls - Networking and Security]]

### 22 Anti-Exploit and Security
[[Detecting Movement Exploits - Speed Fly Noclip Teleport]]

### 23 Debugging Deep Dives
[[Debugging Race Conditions and Yield Order]]

### 29 Luau Cookbook
[[Cookbook - Players and Characters]]

### 33 Level Design
[[Spawn Points Safe Zones and Respawn Flow]]

### 37 Avatars and UGC
[[AvatarEditorService and In-Game Avatar Editors]] · [[HumanoidDescription and Outfit Systems]]

### 62 Engine Reference Cards
[[Player - Engine Reference Card]]

Also mentioned in (not linked): Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots · Horror Monster Chase AI End to End · Kill Planes, Map Boundaries and Out-of-Bounds Recovery · Locomotion Systems · Making Numbers Feel Good - Cooldowns Buffering and Coyote Time · Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes · Obby Checkpoints and Stage Saves End to End · Quest Chain System End to End · ScreenGui Fundamentals · Shop with Game Passes and Developer Products End to End · Side-Scroller in 3D - Locking Camera and Movement to a Plane · Snippets - Animation Controller Module · Tutorial Step Design Patterns - Teach by Doing · Tycoon Plots and Droppers End to End

<!-- atlas:generated -->
