---
tags: [atlas, api, type/atlas, area/platform, area/ai, api/OnIncomingMessage]
---
# OnIncomingMessage

<!-- tldr:start -->
> [!tldr] TL;DR
> - `OnIncomingMessage` runs twice on the sender: once locally on send, again when the filtered result returns.
> - Avoid: binding `OnIncomingMessage` in several scripts.
> - One client module owns `OnIncomingMessage`, `OnChatWindowAdded` and `OnBubbleAdded`.
> - For each recipient that passes, filtering applies and `OnIncomingMessage` runs on that client (and once on the sender), then...
>
> Cost: TL;DR ~140 tok · whole note ~400 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`OnIncomingMessage` runs twice on the sender: once locally on send, again when the filtered result returns. (from [[TextChatService - Engine Reference Card]])

API snapshot: member of `TextChannel`, `TextChatService` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Avoid: binding `OnIncomingMessage` in several scripts. ([[TextChatService - Engine Reference Card]])
- One client module owns `OnIncomingMessage`, `OnChatWindowAdded` and `OnBubbleAdded`. ([[TextChatService - Engine Reference Card]])
- For each recipient that passes, filtering applies and `OnIncomingMessage` runs on that client (and once on the sender), then the message appears. ([[Text Chat Customization with TextChatService]])
- Wrong: `game:GetService("Chat"):Chat(...)`, `ChatServiceRunner`, `SayMessageRequest`, custom chat UIs reading `TextChatMessage.Text`, moderation in `OnIncomingMessage` or `Player.Chatted`. ([[AI Pitfalls - Stale APIs and Luau]])

## Mentioned in

8 notes in 5 sections. The 8 most relevant are linked:

### 15 AI Tools
[[AI Pitfalls - Stale APIs and Luau]] · [[What AI Models Get Wrong in Roblox]]

### 26 Community and Moderation
[[Text Chat Customization with TextChatService]]

### 49 Roblox Platform Features
[[API Renames and Deprecations 2025-2026]] · [[Policy and Age Rules 2026]] · [[Roblox Changes 2025-2026]]

### 62 Engine Reference Cards
[[TextChatService - Engine Reference Card]]

### Root notes
[[Open Questions - Whole Vault]]

<!-- atlas:generated -->
