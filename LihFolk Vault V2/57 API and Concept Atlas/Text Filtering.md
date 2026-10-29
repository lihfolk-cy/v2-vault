---
tags: [atlas, concept, type/atlas, area/design, area/scripting]
---
# Text Filtering

<!-- tldr:start -->
> [!tldr] TL;DR
> - Filtered text comes back with blocked words replaced by `#` characters, which is why "my sign is all hashtags" is a filter...
> - Avoid: filtering text for an author who has left.
> - Text filtering. If report text is ever shown to other players (a public "known issues" board built from reports), filter it...
> - Jail and spawn protections; filtered text.
>
> Cost: TL;DR ~130 tok · whole note ~630 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

Filtered text comes back with blocked words replaced by `#` characters, which is why "my sign is all hashtags" is a filter result, not a bug. (from [[Text Filtering - TextService for Names, Signs and Messages]])

## Key facts

- Avoid: filtering text for an author who has left. ([[Text Filtering - TextService for Names, Signs and Messages]])
- Text filtering. If report text is ever shown to other players (a public "known issues" board built from reports), filter it with `TextService` first like any user text. ([[In-Game Bug Report Button with Automatic Context]])
- Jail and spawn protections; filtered text. ([[Genre Playbook - Open-World City and Crime Roleplay]])
- Names come from Roblox. Display names and usernames returned by `UserService` are already moderated by Roblox; do not let players set a custom "leaderboard name" without text filtering (Text Fonts and Rich Text). ([[Global Leaderboards End to End]])

## Mentioned in

22 notes in 17 sections. The 22 most relevant are linked:

### 02 Luau Scripting
[[Strings Patterns and Formatting]] · [[Text Filtering - TextService for Names, Signs and Messages]]

### 05 UI and UX
[[Text Fonts and Rich Text]]

### 10 Game Design and Genres
[[Genre Playbook - Open-World City and Crime Roleplay]] · [[Genre Playbook - Racing and Driving]] · [[Genre Playbook - Sports]]

### 11 Monetization Publishing and Live Ops
[[Age Checks and Safety Features]]

### 12 Performance Testing and Debugging
[[In-Game Bug Report Button with Automatic Context]]

### 15 AI Tools
[[In-Game AI - LLM NPCs and Text Generation]] · [[Roblox Policies on AI-Generated Content]]

### 17 Pipelines
[[Localization Pipeline]]

### 22 Anti-Exploit and Security
[[Logging Bans and Appeals]]

### 24 Worked Builds
[[Global Leaderboards End to End]]

### 26 Community and Moderation
[[Player Reports and In-Game Moderation]] · [[Text Chat Customization with TextChatService]]

### 28 Business and Careers
[[Legal Basics - IP Licenses and Assets]]

### 41 Multiplayer Services
[[Server Browsers and Server Lists]]

### 46 Resource Library
[[Official Docs - Security and Moderation]]

### 49 Roblox Platform Features
[[Experience Notifications and Return Prompts]]

### 58 Player QoL and Game Tweaks
[[Block and Mute Respecting Platform Rules]]

### 59 Viral and Trend Game Teardowns
[[Teardown - PLS DONATE]]

### 60 High-Craft Game Teardowns
[[Teardown - Piggy]]

<!-- atlas:generated -->
