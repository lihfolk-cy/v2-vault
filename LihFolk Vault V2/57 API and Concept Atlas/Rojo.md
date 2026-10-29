---
tags: [atlas, concept, type/atlas, area/studio, area/performance]
---
# Rojo

<!-- tldr:start -->
> [!tldr] TL;DR
> - Rojo is the most mature example of this pattern: `rojo serve` runs a local server, the Rojo plugin connects to it and syncs...
> - Avoid: Mixing Script Sync and Rojo naming -> One convention per repo.
> - Decision written down: Script Sync or Rojo, and which naming convention.
> - Changes in Studio vanish: Rojo synced files over Studio edits -> edit code only in files; keep mapped folders code-only.
>
> Cost: TL;DR ~140 tok · whole note ~1.0k tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Rojo is the most mature example of this pattern: `rojo serve` runs a local server, the Rojo plugin connects to it and syncs file changes into the place. (from [[Studio Plugins and Local HTTP Bridges]])

Rojo: Tool that syncs files on disk with Studio, enabling Git. (from [[Glossary]])

## Key facts

- Avoid: Mixing Script Sync and Rojo naming -> One convention per repo. ([[External Tooling - Rojo Wally Selene StyLua]])
- Decision written down: Script Sync or Rojo, and which naming convention. ([[External Tooling - Rojo Wally Selene StyLua]])
- Changes in Studio vanish: Rojo synced files over Studio edits -> edit code only in files; keep mapped folders code-only. ([[Code Pipeline - Rojo Git and CI]])
- Code in files, Rojo-mapped folders code-only. ([[Code Pipeline - Rojo Git and CI]])
- Avoid: Rojo live-sync from a feature branch into the shared place -> Personal dev places per branch. ([[Git and Source Control for Roblox]])

## Mentioned in

64 notes in 24 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[External Tooling - Rojo Wally Selene StyLua]] · [[Git and Source Control for Roblox]] · [[Packages and Asset Reuse]] · [[Plugins - Using and Writing]] · [[Team Create and Collaboration]]

### 02 Luau Scripting
[[Luau Type System and Strict Mode]]

### 03 Architecture and Networking
[[Project Structure and Bootstrapping]]

### 12 Performance Testing and Debugging
[[Automated Testing with TestEZ and Jest-Lua]]

### 13 Production and Case Studies
[[Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts]]

### 15 AI Tools
[[AI Code Assistants for Luau]]

### 16 MCP and Agents
[[AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well]] · [[Agent Review Loops and Guardrails in Practice]] · [[MCP Workflows for Scripting and Debugging]] · [[Setting Up MCP Clients]] · [[Studio Plugins and Local HTTP Bridges]]

### 17 Pipelines
[[Build Test and Release Pipeline]] · [[Code Pipeline - Rojo Git and CI]] · [[Data and Config Pipeline - Spreadsheets to Game]] · [[Pipeline Design Principles]]

### 28 Business and Careers
[[Open-Source Licenses for Roblox Libraries - Quick Reference]]

### 39 Studio Plugins and Tooling
[[Building a Studio Plugin End to End]]

### 50 Team Collaboration and Project Management
[[Code Review for Luau Teams]] · [[Documentation and Onboarding New Developers]] · [[Packages and Shared Assets Across Places]] · [[Team Create Permissions and Workflows]]

Also mentioned in (not linked): 00 Start Here · AI in Roblox Development Overview · Asset Upload Automation with Open Cloud · Automated Luau Checks - LihFolk Hook and Audit · Blender 5 Python Gotchas for Headless Builds · Commissions Pricing and Contracts · Debugging Client-Server Desync · Declarative UI - React-Lua and Fusion · Dependency Injection in Luau · Error Handling and Retries · Frameworks - Knit Matter and Others · Gated Tester Commands and Debug Panels · Glossary · HttpService and External APIs · Legal Basics - IP Licenses and Assets · LihFolk Systems Library · LihFolk UI Design System · Local vs Cloud AI - Keeping Unreleased Game Code Private · Luau Language Essentials · Module Scripts and Requiring · Multiple Agents in One Studio · Open Cloud APIs · Plugin Development Start Here · Plugin Security and Permissions · Publishing Selling and Updating Plugins · Running a Small Studio as a Business · Save Migration Tests - Fixture Saves and Golden Files · Saved Inventory End to End · Seeds Determinism and Reproducible Worlds · Simulating an Economy Before Launch · Snippets - Building and Sampling Clips · StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs · Studio Interface Tour · Studio Settings and Shortcuts · Team Collaboration Start Here · Testing Strategies and Frameworks · Testing Your Own Remotes - Fuzzing and Abuse Tests · The Debugging Method - Reproduce Isolate Bisect · Tilemaps Cameras and Parallax for 2D Levels

<!-- atlas:generated -->
