---
tags: [reference, engine, textchatservice, api/TextChatService, type/reference, area/scripting, level/intermediate, api/OnIncomingMessage, api/GetChatGroupsAsync]
---

# TextChatService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: binding `OnIncomingMessage` in several scripts.
> - Avoid: sending server announcements with `SendAsync`.
> - Avoid: metadata strings over 200 characters.
> - One client module owns `OnIncomingMessage`, `OnChatWindowAdded` and `OnBubbleAdded`.
> - Team or proximity filtering done server-side with `ShouldDeliverCallback`.
> - Custom channels populated with `AddUserAsync` after an eligibility check.
>
> Cost: TL;DR ~140 tok · whole note ~1.5k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The one chat system for experiences: channels, filtering, commands, bubbles and message decoration. Topic notes: [[Text Chat Customization with TextChatService]], [[TextChatService]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| CreateDefaultTextChannels | prop | boolean | set in Studio | Plugin security (Studio Properties); creates a TextChannels folder at runtime | - |
| CreateDefaultCommands | prop | boolean | set in Studio | Plugin security; creates a TextChatCommands folder | - |
| ChatTranslationEnabled | prop | boolean | user preference | Client-side, read-only for scripts; reflects the user's toggle | - |
| ChatVersion | prop | Enum.ChatVersion | - | Deprecated for new experiences: TextChatService is the only chat system | - |
| CanUserChatAsync | method | `(userId: number) -> boolean` | - | Server for any player; LocalScript only for the local user | yes |
| CanUsersChatAsync | method | `(userIdFrom: number, userIdTo: number) -> boolean` | - | Server/Legacy RunContext only; both users in server | yes |
| CanUsersDirectChatAsync | method | `(requesterUserId: number, userIds: {number}) -> {number}` | - | Gate user-initiated private channels | yes |
| [[GetChatGroupsAsync]] | method | `(players: {Player}) -> {{string}}` | - | Server only; group IDs for matchmaking/teleport | yes |
| DisplayBubble | method | `(partOrCharacter: Instance, message: string)` | - | Client only; works for NPC heads | no |
| MessageReceived | event | `(textChatMessage: TextChatMessage)` | - | Client only | - |
| SendingMessage | event | `(textChatMessage: TextChatMessage)` | - | Sending client; show placeholders | - |
| BubbleDisplayed | event | `(partOrCharacter: Instance, textChatMessage: TextChatMessage)` | - | Fires from DisplayBubble | - |
| [[OnIncomingMessage]] | callback | `(message: TextChatMessage) -> TextChatMessageProperties?` | nil | Client only; runs before TextChannel.OnIncomingMessage | - |
| OnChatWindowAdded | callback | `(message: TextChatMessage) -> ChatWindowMessageProperties?` | nil | Client only; per-message window styling | - |
| OnBubbleAdded | callback | `(message: TextChatMessage, adornee: Instance) -> BubbleChatMessageProperties?` | nil | Client only; per-bubble styling | - |
| TextChannel:SendAsync | method | `(message: string, metadata: string?) -> TextChatMessage` | - | Client only; only user-typed messages deliver | yes |
| TextChannel:DisplaySystemMessage | method | `(systemMessage: string, metadata: string?) -> TextChatMessage` | - | Client only; local, unfiltered, unlocalized | no |
| TextChannel:AddUserAsync | method | `(userId: number) -> tuple (TextSource)` | - | Server Script only | yes |
| TextChannel.ShouldDeliverCallback | callback | `(message: TextChatMessage, textSource: TextSource) -> truthy` | nil | Server only; per receiver | - |

## Limits and defaults

- `SendAsync` metadata: 200 characters maximum. Longer metadata blocks delivery and returns a message with empty Text and Metadata to the sender.
- `OnIncomingMessage` runs twice on the sender: once locally on send, again when the filtered result returns.
- `ShouldDeliverCallback` must return a truthy value to deliver; `nil` or `false` hides the message from that receiver, while the sender still sees it.
- `GetChatGroupsAsync` replaces N^2 pairwise `CanUsersChatAsync` checks; chat group IDs are per universe, can change, and must not be stored after the user leaves.
- When `PlatformIntegratedChat` is Enabled, developer `OnIncomingMessage` callbacks are not invoked.

## Replication and authority

- Server: `ShouldDeliverCallback`, `AddUserAsync`, `GetChatGroupsAsync`, `CanUsersChatAsync`, `TextChannel:SetDirectChatRequester`.
- Client: `SendAsync`, `DisplaySystemMessage`, `DisplayBubble`, all decoration callbacks, `MessageReceived`.
- Decoration callbacks change how a message looks on one client; access control belongs on the server through channels and `ShouldDeliverCallback`.

## Common mistakes

- Avoid: binding `OnIncomingMessage` in several scripts. Symptom: bindings override each other in a non-deterministic order and tags flicker.
- Avoid: sending server announcements with `SendAsync`. Symptom: nothing arrives, because only user-typed messages deliver; use `DisplaySystemMessage` on each client instead.
- Avoid: metadata strings over 200 characters. Symptom: the message silently fails to reach others.
- Avoid: defining `ShouldDeliverCallback` without an explicit `return true`. Symptom: every message vanishes for receivers.
- Avoid: creating private channels without `CanUsersDirectChatAsync`. Symptom: users with parental limits end up in channels they are not eligible for.

## Checklist

- One client module owns `OnIncomingMessage`, `OnChatWindowAdded` and `OnBubbleAdded`.
- Team or proximity filtering done server-side with `ShouldDeliverCallback`.
- Custom channels populated with `AddUserAsync` after an eligibility check.
- Metadata kept short (under 200 characters) and treated as display hints.

Source: https://create.roblox.com/docs/reference/engine/classes/TextChatService and https://create.roblox.com/docs/reference/engine/classes/TextChannel - verified 2026-10-29

<!-- related:start -->
## Related
[[Age Checks and Safety Features]] · [[MessagingService - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[DataStoreService - Engine Reference Card]] · [[Players - Engine Reference Card]] · [[RemoteEvent - Engine Reference Card]] · [[BadgeService - Engine Reference Card]] · [[MarketplaceService - Engine Reference Card]] · [[Instance - Engine Reference Card]]
<!-- related:end -->
