---
tags: [reference, engine, messagingservice, api/MessagingService, type/reference, area/scripting, level/intermediate]
---

# MessagingService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: one global topic that every server publishes to.
> - Avoid: sending whole tables of player data.
> - Avoid: features that break when a message never arrives.
> - Every publish and subscribe in `pcall`, with retry for subscriptions at server start.
> - Payloads encoded and measured; under 1 kB, with an id or `Sent` check to drop duplicates and stale messages.
> - Per-minute send and receive budget estimated at peak server count.
>
> Cost: TL;DR ~150 tok · whole note ~1.2k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Publish and subscribe between live servers of one experience, usually delivered within 1-2 seconds on a best-effort basis. Topic notes: [[Cross-Server Messaging]], [[MemoryStore Service]], [[Global Leaderboards End to End]].

## Members that matter

The service has two methods; the remaining rows are the pieces you combine with them in nearly every cross-server feature.

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| PublishAsync | method | `(topic: string, message: Variant)` | - | Server; yields until the backend accepts the message | yes |
| SubscribeAsync | method | `(topic: string, callback: (message: {Data: Variant, Sent: number}) -> ()) -> RBXScriptConnection` | - | Server; yields until the subscription is registered; may be called more than once per topic | yes |
| callback `message.Data` | field | Variant | - | The payload passed to `PublishAsync` | - |
| callback `message.Sent` | field | number | - | Unix time in seconds when it was sent; use it to drop stale messages | - |
| connection `:Disconnect()` | method | `() -> ()` | - | Unsubscribes; stopping the owning script also unsubscribes | no |
| `game.JobId` | prop | string | - | Put it in the payload so a server can skip its own messages | - |
| `HttpService:JSONEncode` | method | `(input: Variant) -> string` | - | Measure the payload against the 1 kB limit before publishing | no |
| `HttpService:GenerateGUID` | method | `(wrapInCurlyBraces: bool = true) -> string` | braces on | Message id for de-duplication | no |
| `Players:GetPlayerByUserId` | method | `(userId: number) -> Player?` | - | Route a message to a player only if they are on this server | no |
| `MemoryStoreHashMap:SetAsync` | method | `(key: string, value: Variant, expiration: int64) -> bool` | - | Store a large payload; publish only its key | yes |
| `GlobalDataStore:GetAsync` | method | `(key: string, options: DataStoreGetOptions?)` | cached | After a "data changed" message, re-read with `UseCache = false` | yes |
| `game:BindToClose` | method | `(function: () -> ())` | - | Publish a final "server closing" message if other servers track this one | no |

## Limits and defaults

- Message size: 1 kB.
- Topic name: 1 to 80 characters.
- Messages sent per server: 600 + 240 x players per minute.
- Messages received per topic: 40 + 80 x servers per minute.
- Messages received for the whole experience: 400 + 200 x servers per minute.
- Subscriptions per server: 20 + 8 x players.
- Subscribe requests per server: 240 per minute.
- Delivery: best effort, typically within 1-2 seconds; Roblox notes these limits are subject to change.

## Replication and authority

- The service is `NotReplicated` and server-to-server only; clients learn about messages through remotes the server fires.
- Messages stay inside one experience. Publishing to live servers from outside, or across experiences, goes through the Open Cloud messaging API.
- Any server in the experience can publish to any topic, so treat incoming data as hints and keep the authoritative copy in a data store or memory store.

## Common mistakes

- Avoid: one global topic that every server publishes to. Symptom: received traffic passes 40 + 80 x servers per minute and messages are lost; shard topics or batch updates.
- Avoid: sending whole tables of player data. Symptom: publishing fails over 1 kB; send an id and look the payload up.
- Avoid: features that break when a message never arrives. Symptom: rare desyncs, because delivery is not guaranteed; re-read the source of truth on a timer as a fallback.
- Avoid: calling `PublishAsync` or `SubscribeAsync` without `pcall`. Symptom: a throttled or failed call errors and stops the script.
- Avoid: reacting to your own broadcast. Symptom: duplicate effects on the sending server; compare the payload's `JobId` with `game.JobId`.

## Checklist

- Every publish and subscribe in `pcall`, with retry for subscriptions at server start.
- Payloads encoded and measured; under 1 kB, with an id or `Sent` check to drop duplicates and stale messages.
- Per-minute send and receive budget estimated at peak server count.
- Connections disconnected when a feature shuts down.

Source: https://create.roblox.com/docs/reference/engine/classes/MessagingService and https://create.roblox.com/docs/cloud-services/cross-server-messaging - verified 2026-10-29

<!-- related:start -->
## Related
[[MemoryStoreService - Engine Reference Card]] · [[DataStoreService - Engine Reference Card]] · [[HttpService - Engine Reference Card]] · [[TeleportService - Engine Reference Card]] · [[RemoteEvent - Engine Reference Card]] · [[BadgeService - Engine Reference Card]] · [[MarketplaceService - Engine Reference Card]] · [[Players - Engine Reference Card]]
<!-- related:end -->
