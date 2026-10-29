---
tags: [atlas, concept, type/atlas, area/pipelines, area/studio]
---
# Continuous Integration

<!-- tldr:start -->
> [!tldr] TL;DR
> - CI runs `stylua --check`, `selene`, `luau-lsp analyze`, `rojo build`.
> - CI green, game broken: tests did not touch engine behaviour -> cloud tests for engine logic, play test for feel.
> - StyLua, Selene, luau-lsp, Rojo build in CI on every PR.
> - Schema validation plus cross-table references in CI.
>
> Cost: TL;DR ~120 tok · whole note ~1000 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

CI runs `stylua --check`, `selene`, `luau-lsp analyze`, `rojo build`. (from [[External Tooling - Rojo Wally Selene StyLua]])

## Key facts

- CI green, game broken: tests did not touch engine behaviour -> cloud tests for engine logic, play test for feel. ([[Code Pipeline - Rojo Git and CI]])
- StyLua, Selene, luau-lsp, Rojo build in CI on every PR. ([[Code Pipeline - Rojo Git and CI]])
- Schema validation plus cross-table references in CI. ([[Data and Config Pipeline - Spreadsheets to Game]])
- Validator checks reachability, cycles, consumables, areas and hint completeness in CI. ([[Puzzle Dependency Charts and Hint Systems]])

## Mentioned in

65 notes in 26 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[External Tooling - Rojo Wally Selene StyLua]] · [[Git and Source Control for Roblox]] · [[Places Universes and Experience Settings]]

### 02 Luau Scripting
[[Luau Type System and Strict Mode]]

### 04 Data and Persistence
[[Open Cloud APIs]]

### 11 Monetization Publishing and Live Ops
[[Economy Inflation Sinks and Faucets Math]]

### 12 Performance Testing and Debugging
[[Automated Testing with TestEZ and Jest-Lua]] · [[Save Migration Tests - Fixture Saves and Golden Files]] · [[Testing Strategies and Frameworks]]

### 15 AI Tools
[[Local vs Cloud AI - Keeping Unreleased Game Code Private]] · [[Obsidian Vaults for AI Agents - Structure, Graph and Theming]]

### 16 MCP and Agents
[[AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well]]

### 17 Pipelines
[[Asset Upload Automation with Open Cloud]] · [[Blender Automation with Python]] · [[Build Test and Release Pipeline]] · [[Code Pipeline - Rojo Git and CI]] · [[Data and Config Pipeline - Spreadsheets to Game]] · [[Live Content Pipeline]] · [[Pipeline Design Principles]]

### 28 Business and Careers
[[Open-Source Licenses for Roblox Libraries - Quick Reference]]

### 45 Procedural Blender Assets
[[Blender 5 Python Gotchas for Headless Builds]]

### 48 Economy Design Deep Dive
[[Simulating an Economy Before Launch]]

### 50 Team Collaboration and Project Management
[[Code Review for Luau Teams]] · [[Documentation and Onboarding New Developers]]

### 52 Core Concepts
[[Dependency Injection in Luau]]

Also mentioned in (not linked): 00 Start Here · 2D Collision Physics and Platformer Movement · AI Code Assistants for Luau · Agent Review Loops and Guardrails in Practice · Art Pipeline - Concept to In-Game Asset · Building a Studio Plugin End to End · Colour-Blind Safe Design · Creator Account Security and Takeover Recovery · Data Schema Design and Migrations · Data and Cloud Changes 2025-2026 · Debugging Client-Server Desync · Debugging DataStore Problems · Debugging Live Servers · Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts · Economy Design Start Here · Error Handling and Retries · Gated Tester Commands and Debug Panels · Global State and Live Config · Icon and Thumbnail Rendering Pipeline · MCP Workflows for Scripting and Debugging · Multiple Agents in One Studio · Packages and Shared Assets Across Places · Paid Random Items and Odds Disclosure in Practice · Plugins - Using and Writing · Probability and Statistics for Designers · Project Structure and Bootstrapping · Publishing Animations · Publishing Selling and Updating Plugins · Puzzle Dependency Charts and Hint Systems · Running a Small Studio as a Business · Schema Migrations - Worked Case Studies · Seeds Determinism and Reproducible Worlds · Skill - Roblox Monetization Compliance · Snippets - Building and Sampling Clips · Story State Flags and Chapter Saves · Studio Assistant and AI Tools · Studio Plugins and Local HTTP Bridges · Team Collaboration Start Here · Testing Modes - Play Run and Multi-Client · Windows Tooling Pitfalls for Agent Pipelines

<!-- atlas:generated -->
