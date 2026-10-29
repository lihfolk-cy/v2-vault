---
tags: [atlas, concept, type/atlas, area/scripting, area/networking]
---
# Metatables

<!-- tldr:start -->
> [!tldr] TL;DR
> - Metatables let a table customize indexing, arithmetic, comparison, calling and iteration, which is how classes are built.
> - Methods missing after a save/load or remote: Metatable dropped -> Plain data at boundaries; rebuild objects.
> - No NaN, infinity, functions, metatables or Instances reach a serializer; a validation pass runs before saving.
> - Metatables are lost on `DataStore` saves and remote sends (section 7) and complicate serialization.
>
> Cost: TL;DR ~150 tok · whole note ~580 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Metatables let a table customize indexing, arithmetic, comparison, calling and iteration, which is how classes are built. (from [[Tables Metatables and OOP]])

## Key facts

- Methods missing after a save/load or remote: Metatable dropped -> Plain data at boundaries; rebuild objects. ([[Metatables and OOP - When and When Not]])
- No NaN, infinity, functions, metatables or Instances reach a serializer; a validation pass runs before saving. ([[Serialization Formats for Saves and Networking]])
- Metatables are lost on `DataStore` saves and remote sends (section 7) and complicate serialization. ([[Tables Metatables and OOP]])
- BindableEvents copy arguments. Tables passed through a `BindableEvent` arrive as copies without metatables, functions are dropped, and mixed keys can be lost. ([[Events Signals and Connections]])

## Mentioned in

26 notes in 9 sections. The 25 most relevant are linked:

### 02 Luau Scripting
[[Error Handling - pcall xpcall and Promise Patterns]] · [[Events Signals and Connections]] · [[Functions Closures and Upvalues]] · [[Luau Language Essentials]] · [[Luau Performance Patterns with Benchmarks]] · [[Luau Performance and Native Codegen]] · [[Luau Type System and Strict Mode]] · [[Metatables and OOP - When and When Not]] · [[Module Scripts and Requiring]] · [[Strings Patterns and Formatting]] · [[Tables Metatables and OOP]]

### 03 Architecture and Networking
[[Entity Component Systems]] · [[Remote Abuse Patterns and Rate Limiting in Practice]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]]

### 04 Data and Persistence
[[Data Schema Design and Migrations]]

### 22 Anti-Exploit and Security
[[How Exploits Work - The Client Boundary]]

### 29 Luau Cookbook
[[Cookbook - Tables Strings and Time]]

### 35 Advanced Luau
[[Advanced Luau Start Here]] · [[Advanced Types - Generics and Type Functions]] · [[Module Design and Dependency Injection]] · [[Serialization Formats for Saves and Networking]]

### 52 Core Concepts
[[Event Bus]] · [[Replication Boundary]]

### 56 Field Notes
[[ipairs Stops at the First nil - Cleanup Tables That Leak]]

### Root notes
[[00 Start Here]]

Also mentioned in (not linked): Luau Cookbook Start Here

<!-- atlas:generated -->
