---
tags: [atlas, concept, type/atlas, area/performance, area/scripting]
---
# TestEZ

<!-- tldr:start -->
> [!tldr] TL;DR
> - TestEZ is Roblox's original BDD-style test framework (`describe`/`it`/`expect`), used for years for Roblox's own libraries.
> - On Open Cloud you cannot set fast flags, so whether Jest-Lua runs there is unverified; TestEZ, which needs no flag, or a small...
> - Use plain assertions or a small TestEZ-compatible shim.
> - Add the arguments to a per-remote "known bad inputs" list that a unit test runs on every build (Automated Testing with TestEZ...
>
> Cost: TL;DR ~150 tok · whole note ~870 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

TestEZ is Roblox's original BDD-style test framework (`describe`/`it`/`expect`), used for years for Roblox's own libraries. (from [[Testing Strategies and Frameworks]])

TestEZ needs no flags and no Wally (a copy of the module works). (from [[Automated Testing with TestEZ and Jest-Lua]])

## Key facts

- On Open Cloud you cannot set fast flags, so whether Jest-Lua runs there is unverified; TestEZ, which needs no flag, or a small runner of your own, is the safer choice for Open Cloud jobs. ([[Automated Testing with TestEZ and Jest-Lua]])
- Use plain assertions or a small TestEZ-compatible shim. ([[Testing Strategies and Frameworks]])
- Add the arguments to a per-remote "known bad inputs" list that a unit test runs on every build (Automated Testing with TestEZ and Jest-Lua). ([[Testing Your Own Remotes - Fuzzing and Abuse Tests]])
- Turn every failure into a regression check. If a bug can be expressed as a pure function test (odds, prices, rewards), add it to the suite (Automated Testing with TestEZ and Jest-Lua). ([[Genre QA Passes - Test Checklists per Game Type]])

## Mentioned in

42 notes in 21 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[External Tooling - Rojo Wally Selene StyLua]]

### 02 Luau Scripting
[[Buffers and Binary Data]]

### 03 Architecture and Networking
[[Frameworks - Knit Matter and Others]]

### 12 Performance Testing and Debugging
[[Automated Testing with TestEZ and Jest-Lua]] · [[Dupe Hunting Test Script - Trades, Gifts, Drops and Rejoins]] · [[Genre QA Passes - Test Checklists per Game Type]] · [[Testing Strategies and Frameworks]] · [[Testing Time-Based Features with a Controllable Clock]]

### 22 Anti-Exploit and Security
[[Testing Your Own Remotes - Fuzzing and Abuse Tests]]

### 23 Debugging Deep Dives
[[Debugging Live Servers]]

### 24 Worked Builds
[[Daily Rewards System End to End]] · [[LihFolk Systems Library]]

### 28 Business and Careers
[[Building a Portfolio as a Roblox Developer]] · [[Open-Source Licenses for Roblox Libraries - Quick Reference]]

### 35 Advanced Luau
[[Building a Signal Library]] · [[Custom Schedulers and Coroutine Patterns]] · [[Module Design and Dependency Injection]]

### 38 Live Ops Deep Dive
[[Feature Flags and Staged Rollouts]]

### 39 Studio Plugins and Tooling
[[Building a Studio Plugin End to End]]

### 42 Accessibility and Inclusive Design
[[Colour-Blind Safe Design]]

### 48 Economy Design Deep Dive
[[Drop Tables Rarity and Pity Systems]]

### 50 Team Collaboration and Project Management
[[Code Review for Luau Teams]]

### 52 Core Concepts
[[Data Schema Versioning]] · [[Dependency Injection in Luau]] · [[Deterministic Simulation]]

Also mentioned in (not linked): 00 Start Here · Advanced Luau Start Here · Anti-Exploit Start Here · Debugging Start Here · Live Incident Response and Post-Mortems · MCP Workflows for Scripting and Debugging · Multi-Client and Device Playtesting Protocols · Plugin Development Start Here · Probability and Statistics for Designers · Save Migration Tests - Fixture Saves and Golden Files · Seeds Determinism and Reproducible Worlds · Skill - Roblox System Builder · Snippets - Lua Keyframe Player Core · Studio Assistant and AI Tools · Team Collaboration Start Here · The Debugging Method - Reproduce Isolate Bisect · UI Automation with VirtualInput and StudioTestService

<!-- atlas:generated -->
