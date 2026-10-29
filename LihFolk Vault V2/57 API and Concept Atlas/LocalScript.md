---
tags: [atlas, api, type/atlas, area/animation, area/gameplay, api/LocalScript]
---
# LocalScript

<!-- tldr:start -->
> [!tldr] TL;DR
> - Animate script: The default LocalScript that plays idle, walk, run, jump and so on for player characters.
> - LocalScript does nothing: In Workspace or ReplicatedStorage -> Starter containers, or a Client-context Script in...
> - Client code runs twice: Client-context `Script` in a Starter container -> LocalScript there, or move to ReplicatedStorage.
> - One `LocalScript` boots the UI from `StarterPlayerScripts`.
>
> Cost: TL;DR ~140 tok · whole note ~1.7k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Animate script: The default LocalScript that plays idle, walk, run, jump and so on for player characters. (from [[Animation Glossary]])

API snapshot: class, inherits `Script` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- LocalScript does nothing: In Workspace or ReplicatedStorage -> Starter containers, or a Client-context Script in ReplicatedStorage. ([[Script Types and Run Context]])
- Client code runs twice: Client-context `Script` in a Starter container -> LocalScript there, or move to ReplicatedStorage. ([[Script Types and Run Context]])
- One `LocalScript` boots the UI from `StarterPlayerScripts`. ([[Cookbook - UI]])
- No LocalScript indexes Workspace parts directly without a wait or a tag. ([[Instance Streaming]])
- Avoid: awarding from a LocalScript. Symptom: the award fails; fire a validated remote and award on the server. ([[BadgeService - Engine Reference Card]])

## Mentioned in

130 notes in 36 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[External Tooling - Rojo Wally Selene StyLua]]

### 02 Luau Scripting
[[Script Types and Run Context]]

### 03 Architecture and Networking
[[Client-Server Model]] · [[Instance Streaming]]

### 05 UI and UX
[[ScreenGui Fundamentals]]

### 07 Lighting VFX and Audio
[[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]]

### 08 Animation
[[Ability Kits Architecture]] · [[Custom Characters and StarterCharacter]] · [[Snippets - Playing Animations]]

### 09 Gameplay Systems
[[Characters and Humanoids]] · [[Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched]]

### 15 AI Tools
[[AI Code Assistants for Luau]] · [[AI Pitfalls - Networking and Security]]

### 22 Anti-Exploit and Security
[[How Exploits Work - The Client Boundary]]

### 24 Worked Builds
[[Codes Redemption System End to End]] · [[Melee Combat System End to End]] · [[Pet Hatching and Following End to End]] · [[Round-Based Minigame Loop End to End]] · [[Saved Inventory End to End]] · [[Shop with Game Passes and Developer Products End to End]]

### 29 Luau Cookbook
[[Cookbook - Players and Characters]] · [[Cookbook - UI]]

### 43 Genre Systems End to End
[[Arena Rounds with Teams and Spectating End to End]]

### 46 Resource Library
[[Official Docs - Scripting and Luau]]

### 62 Engine Reference Cards
[[BadgeService - Engine Reference Card]]

Also mentioned in (not linked): 2D Multiplayer - Server Authority and Replicating GUI Worlds · AI Pitfalls - Physics and Animation · AI Pitfalls - UI and Input · Ads and Rewarded Video · Animation Glossary · Animation Objects · Avatar Context Menus Profiles and Social Surfaces · Badges and Achievement Design · BasePart - Engine Reference Card · Boats Buoyancy and Water · Bundles Animation Packs and Emotes for Sale · Cars with Constraints - Suspension Steering and Drive · Case Study - Fast Join and Deferred Loading · Choosing GUI 2D or Locked-Camera 2.5D · Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits · Code Pipeline - Rojo Git and CI · Commerce and Physical Goods · Community Building · Creator Store and Toolbox Safety · Custom Character Controllers · Daily Rewards System End to End · DataStore Fundamentals · DataStoreService - Engine Reference Card · Debugging Animation Problems · Debugging Client-Server Desync · Destruction and Fracture · Dialogue System End to End · Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins · EditableImage for Pixel Buffers and Procedural 2D · Emotes and Social Animation · Engine Gotchas · Experience Notifications and Return Prompts · Exploits and Anti-Cheat · Figma to Roblox UI - Pipeline and Handoff · First-Person Viewmodels - Arms Rig, Sway and Camera Binding · Foliage Props and Scatter · Functions Closures and Upvalues · Game Icon Design - Readable at Small Sizes · Game Passes · Global Leaderboards End to End · Graphics and Performance Toggles for Low-End Devices · Horror Monster Chase AI End to End · Humanoid - Engine Reference Card · Humanoid States and Animation · Hunting Memory Leaks Step by Step · Input Remapping and One-Handed Play · Input Responsiveness Buffering and Coyote Time · Lighting Technologies and Settings · LihFolk UI Design System · Live Ops Events and Updates · Loading Screen Skip and First-Session Goals · Locomotion Systems · MaterialService and Custom Materials · MicroProfiler Guide · Modelling to the Roblox Camera and Player Scale · Mover Constraints and Physics Controllers · Moving Data Out of a Play Session · Multi-Seat Vehicles - Driver, Passenger and Gunner Roles · Notification and Toast Systems · Obby Checkpoints and Stage Saves End to End · Pipeline - New Animated Weapon · Player - Engine Reference Card · Players - Engine Reference Card · Project Structure and Bootstrapping · Prompting and Verifying AI Output · ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab · Quest Chain System End to End · Racing Laps and Checkpoints End to End · Ragdolls and Physics-Based Animation · Rain - Camera-Local Particles, Splashes and Wet Surfaces · Rebirth and Prestige System End to End · RemoteEvents RemoteFunctions and Unreliable Remotes · Replication Boundary · Replication Rules · Replication and Ownership · Rigs and Joints · RunService - Engine Reference Card · Server Authority and Input Migration 2026 · Short-Form Video Marketing · Side-Scroller in 3D - Locking Camera and Movement to a Plane · Snippets - Animation Controller Module · Snippets - Ragdoll · SoundService - Engine Reference Card · Streaming Joins - Frozen Players and Loading Screen Teardown · StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs · TeleportService - Engine Reference Card · Terrain - Engine Reference Card · Terrain Materials and Painting · Testing Your Own Remotes - Fuzzing and Abuse Tests · Text Chat Customization with TextChatService · TextChatService - Engine Reference Card · Textures Decals and Texture Memory · The Debugging Method - Reproduce Isolate Bisect · The Default Animate Script · Tools and Inventory Systems · Tower Defense Waves and Placement End to End · Troubleshooting Table · Tycoon Plots and Droppers End to End · UI Asset Pipeline · UserInputService - Engine Reference Card · Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer · Voice Chat and Safety Features · Weekend Build - Arena Shooter with Server-Checked Hits · Working with Content Creators · World-Space UI - BillboardGui and SurfaceGui

<!-- atlas:generated -->
