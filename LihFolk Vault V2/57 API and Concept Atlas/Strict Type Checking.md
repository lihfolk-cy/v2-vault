---
tags: [atlas, concept, type/atlas, area/scripting, area/ai]
---
# Strict Type Checking

<!-- tldr:start -->
> [!tldr] TL;DR
> - Strict mode makes you prove a value is not `nil` before you use it.
> - Add CI type checking so errors cannot accumulate silently.
> - Types and nil. Casts, optional values, `FindFirstChild` results (Luau Type System and Strict Mode).
> - Projects that used the new solver in strict mode during the beta were told to set `UseNewLuauTypeSolver` from `Default` to...
>
> Cost: TL;DR ~130 tok · whole note ~680 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Strict mode makes you prove a value is not `nil` before you use it. (from [[Luau Type System and Strict Mode]])

Strict mode does not catch runtime trust problems, but it removes a whole category of nil and typo bugs before a human looks. (from [[Code Review for Luau Teams]])

## Key facts

- Add CI type checking so errors cannot accumulate silently. ([[Luau Type System and Strict Mode]])
- Types and nil. Casts, optional values, `FindFirstChild` results (Luau Type System and Strict Mode). ([[Code Review for Luau Teams]])
- Projects that used the new solver in strict mode during the beta were told to set `UseNewLuauTypeSolver` from `Default` to `Enabled`. ([[Engine and API Changes 2025-2026]])
- Project Structure and Bootstrapping, Module Scripts and Requiring, Luau Type System and Strict Mode. ([[External Tooling - Rojo Wally Selene StyLua]])

## Mentioned in

33 notes in 18 sections. The 25 most relevant are linked:

### 01 Studio and Workflow
[[External Tooling - Rojo Wally Selene StyLua]] · [[Studio Interface Tour]]

### 02 Luau Scripting
[[Error Handling and Retries]] · [[Functions Closures and Upvalues]] · [[Luau Language Essentials]] · [[Luau Type System and Strict Mode]] · [[Metatables and OOP - When and When Not]] · [[Tables Metatables and OOP]]

### 05 UI and UX
[[Declarative UI - React-Lua and Fusion]]

### 12 Performance Testing and Debugging
[[Testing Strategies and Frameworks]]

### 15 AI Tools
[[AI Code Assistants for Luau]] · [[AI Pitfalls - Stale APIs and Luau]] · [[Evaluating AI Tools - A Practical Rubric]]

### 17 Pipelines
[[Code Pipeline - Rojo Git and CI]]

### 23 Debugging Deep Dives
[[Reading Luau Errors and Stack Traces]]

### 28 Business and Careers
[[Building a Portfolio as a Roblox Developer]]

### 29 Luau Cookbook
[[Cookbook - Players and Characters]] · [[Cookbook - Remotes and Networking]]

### 35 Advanced Luau
[[Advanced Luau Start Here]] · [[Advanced Types - Generics and Type Functions]]

### 36 Narrative and Worldbuilding
[[Dialogue System End to End]]

### 39 Studio Plugins and Tooling
[[Building a Studio Plugin End to End]]

### 49 Roblox Platform Features
[[Engine and API Changes 2025-2026]]

### 50 Team Collaboration and Project Management
[[Code Review for Luau Teams]]

### 52 Core Concepts
[[Dependency Injection in Luau]]

Also mentioned in (not linked): 00 Start Here · Frameworks - Knit Matter and Others · Game Feel Start Here · Luau Cookbook Start Here · Module Scripts and Requiring · Open Questions - Whole Vault · Plugin Development Start Here · Skill - Roblox System Builder

<!-- atlas:generated -->
