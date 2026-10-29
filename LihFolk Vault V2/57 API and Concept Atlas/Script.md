---
tags: [atlas, api, type/atlas, area/gameplay, area/studio, api/Script]
---
# Script

<!-- tldr:start -->
> [!tldr] TL;DR
> - `Script.Source` is protected: game scripts cannot read or write it (Docs).
> - LocalScript does nothing: In Workspace or ReplicatedStorage -> Starter containers, or a Client-context Script in...
> - Client code runs twice: Client-context `Script` in a Starter container -> LocalScript there, or move to ReplicatedStorage.
> - One entry Script per side; modules with `init`/`start`.
>
> Cost: TL;DR ~140 tok · whole note ~970 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`Script.Source` is protected: game scripts cannot read or write it (Docs). (from [[Script Types and Run Context]])

API snapshot: class, inherits `BaseScript` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- LocalScript does nothing: In Workspace or ReplicatedStorage -> Starter containers, or a Client-context Script in ReplicatedStorage. ([[Script Types and Run Context]])
- Client code runs twice: Client-context `Script` in a Starter container -> LocalScript there, or move to ReplicatedStorage. ([[Script Types and Run Context]])
- One entry Script per side; modules with `init`/`start`. ([[Module Scripts and Requiring]])
- Avoid: Mixing Script Sync and Rojo naming -> One convention per repo. ([[External Tooling - Rojo Wally Selene StyLua]])
- Decision written down: Script Sync or Rojo, and which naming convention. ([[External Tooling - Rojo Wally Selene StyLua]])

## Mentioned in

59 notes in 22 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[Creator Store and Toolbox Safety]] · [[External Tooling - Rojo Wally Selene StyLua]] · [[Testing Modes - Play Run and Multi-Client]] · [[Version History and Backups]]

### 02 Luau Scripting
[[Error Handling - pcall xpcall and Promise Patterns]] · [[Module Scripts and Requiring]] · [[Parallel Luau and Actors]] · [[Script Types and Run Context]]

### 03 Architecture and Networking
[[Client-Server Model]]

### 04 Data and Persistence
[[Purchase Data and Receipts]]

### 06 World Building and Art
[[Materials MaterialVariants and SurfaceAppearance]]

### 08 Animation
[[The Default Animate Script]]

### 12 Performance Testing and Debugging
[[Developer Console and Stats]]

### 16 MCP and Agents
[[MCP Workflows for Scripting and Debugging]]

### 23 Debugging Deep Dives
[[Reading Luau Errors and Stack Traces]] · [[The Debugging Method - Reproduce Isolate Bisect]]

### 24 Worked Builds
[[Melee Combat System End to End]] · [[Pet Hatching and Following End to End]] · [[Quest Chain System End to End]] · [[Rebirth and Prestige System End to End]] · [[Round-Based Minigame Loop End to End]] · [[Saved Inventory End to End]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 49 Roblox Platform Features
[[Server Authority and Input Migration 2026]]

### 51 2D Game Development
[[Side-Scroller in 3D - Locking Camera and Movement to a Plane]]

Also mentioned in (not linked): Ability Kits Architecture · Agent Review Loops and Guardrails in Practice · Animation Asset Permissions and Groups · Arena Rounds with Teams and Spectating End to End · Audio Pipeline · Avatar Context Menus Profiles and Social Surfaces · Building a Studio Plugin End to End · Cars with Constraints - Suspension Steering and Drive · Commerce and Physical Goods · Data and Config Pipeline - Spreadsheets to Game · DataStore Fundamentals · Developer Products and ProcessReceipt · Error Handling and Retries · Explorer Properties and Selection · Horror Monster Chase AI End to End · Hunting Memory Leaks Step by Step · Infinite and Streamed Worlds · LihFolk Systems Library · Luau Performance Patterns with Benchmarks · Moving Data Out of a Play Session · Network Ownership · Obby Checkpoints and Stage Saves End to End · Packages and Asset Reuse · Plugin Security and Permissions · Plugins - Using and Writing · Prompting and Verifying AI Output · Racing Laps and Checkpoints End to End · Saving Correctly - Autosave and BindToClose · Session Locking and Profile Libraries · Text Chat Customization with TextChatService · Tower Defense Waves and Placement End to End · Tycoon Plots and Droppers End to End · Voice Chat and Safety Features · Weekend Build - Arena Shooter with Server-Checked Hits

<!-- atlas:generated -->
