---
tags: [atlas, concept, type/atlas, area/monetization, area/math]
---
# Drop Rates

<!-- tldr:start -->
> [!tldr] TL;DR
> - A drop rate lowered silently is the change most likely to be discovered by dataminers and framed as deception.
> - Reward diminishing for long sessions without input variety: lower drop rates or XP after N minutes of identical actions.
> - Data changes separate from code changes.
> - A fast drop rate and a slower recovery (the code above uses 12 and 5 per second, rule of thumb) hides it; a spring on the...
>
> Cost: TL;DR ~140 tok · whole note ~500 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

A drop rate lowered silently is the change most likely to be discovered by dataminers and framed as deception. (from [[Patch Notes and Player Communication]])

## Key facts

- Reward diminishing for long sessions without input variety: lower drop rates or XP after N minutes of identical actions. ([[Autoclicker and Macro Detection for Combat Remotes]])
- Data changes separate from code changes. Config tables of prices or drop rates are reviewed by the designer, not the programmer (Data and Config Pipeline - Spreadsheets to Game). ([[Code Review for Luau Teams]])
- A fast drop rate and a slower recovery (the code above uses 12 and 5 per second, rule of thumb) hides it; a spring on the pelvis offset is better still. ([[Foot Placement and Ground IK]])
- Unvalidated config. Symptom: a typo (a price of 0, a drop rate of 50 instead of 0.5) ships instantly to every server. ([[Global State and Live Config]])

## Mentioned in

13 notes in 11 sections. The 13 most relevant are linked:

### 04 Data and Persistence
[[Global State and Live Config]]

### 08 Animation
[[Foot Placement and Ground IK]]

### 11 Monetization Publishing and Live Ops
[[Paid Random Items and Odds Disclosure in Practice]] · [[Roblox Policies Ratings and Compliance]]

### 22 Anti-Exploit and Security
[[Autoclicker and Macro Detection for Combat Remotes]]

### 27 Marketing and Growth
[[Launch Strategy - The First Two Weeks]]

### 34 Procedural Generation
[[Procedural Loot and Item Generation]]

### 35 Advanced Luau
[[Module Design and Dependency Injection]]

### 38 Live Ops Deep Dive
[[Patch Notes and Player Communication]]

### 40 Game Math
[[Game Math Start Here]] · [[Probability and Statistics for Designers]]

### 49 Roblox Platform Features
[[Subscriptions and Recurring Revenue]]

### 50 Team Collaboration and Project Management
[[Code Review for Luau Teams]]

<!-- atlas:generated -->
