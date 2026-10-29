---
tags: [reference, engine, remoteevent, api/RemoteEvent, type/reference, area/scripting, level/intermediate, area/networking, area/liveops, api/UnreliableRemoteEvent, api/RemoteFunction]
---

# RemoteEvent - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: trusting arguments from `FireServer`.
> - Avoid: `InvokeClient` for anything important.
> - Avoid: full state over an `UnreliableRemoteEvent`.
> - One server handler per remote, validating type, range and rate for each argument.
> - `RemoteEvent` for state changes, `UnreliableRemoteEvent` for replaceable cosmetic or positional updates, `RemoteFunction` only...
> - Per-player rate limiting on every client-to-server remote.
>
> Cost: TL;DR ~150 tok · whole note ~1.5k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The three remote types that carry messages across the client-server boundary: `RemoteEvent` (one-way, reliable, ordered), `RemoteFunction` (request and reply) and `UnreliableRemoteEvent` (one-way, may drop or reorder). Topic notes: [[RemoteEvents RemoteFunctions and Unreliable Remotes]], [[Remote Abuse Patterns and Rate Limiting in Practice]], [[Cookbook - Remotes and Networking]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| RemoteEvent:FireServer | method | `(...: any)` | - | Client; server receives the sending `Player` first | no |
| RemoteEvent:FireClient | method | `(player: Player, ...: any)` | - | Server; one client | no |
| RemoteEvent:FireAllClients | method | `(...: any)` | - | Server; every connected client | no |
| RemoteEvent.OnServerEvent | event | `(player: Player, ...: any)` | - | Server; `player` is trustworthy, the rest is client input | - |
| RemoteEvent.OnClientEvent | event | `(...: any)` | - | Client | - |
| RemoteFunction:InvokeServer | method | `(...: any) -> ...any` | - | Client; waits for the server's return | yes |
| RemoteFunction:InvokeClient | method | `(player: Player, ...: any) -> ...any` | - | Server; risky, see below | yes |
| RemoteFunction.OnServerInvoke | callback | `(player: Player, ...: any) -> ...any` | nil | Server; assign one function | callback may yield |
| RemoteFunction.OnClientInvoke | callback | `(...: any) -> ...any` | nil | Client | callback may yield |
| UnreliableRemoteEvent:FireServer | method | `(...: any)` | - | Client; may be dropped | no |
| UnreliableRemoteEvent:FireClient | method | `(player: Player, ...: any)` | - | Server; may be dropped | no |
| UnreliableRemoteEvent:FireAllClients | method | `(...: any)` | - | Server; may be dropped | no |
| UnreliableRemoteEvent.OnServerEvent | event | `(player: Player, ...: any)` | - | Server; no queue if nothing is connected | - |
| UnreliableRemoteEvent.OnClientEvent | event | `(...: any)` | - | Client | - |

## Limits and defaults

- Client-to-server rate: about 500 requests per second per client, shared by all remotes of the same type (all `RemoteEvent`s together, all `UnreliableRemoteEvent`s together).
- `UnreliableRemoteEvent` payload: anything larger than 1,000 bytes is dropped and not resent; some types such as buffers are compressed, so size is hard to predict; Studio Output reports how far over a dropped event was.
- `RemoteEvent` and `RemoteFunction` messages that arrive with no handler are queued until one connects; the queue is limited in count and memory, and overflow is discarded with a "Remote event invocation" error.
- Over the rate limit, a `RemoteEvent` delays and keeps order, while an `UnreliableRemoteEvent` drops the excess.
- Arguments: mixed tables lose keys, non-string keys become strings, functions and metatables do not cross, and instances the receiver cannot see arrive as `nil`.

## Replication and authority

- Place remotes where both sides can see them, usually `ReplicatedStorage` (sometimes `Workspace` or a `Tool`).
- `RemoteEvent` messages are reliable and ordered per connection and direction, including across different `RemoteEvent` instances; ordering applies to when handlers start, so a yielding handler can finish later.
- `RemoteFunction` and `RemoteEvent` traffic have no guaranteed order relative to each other; `UnreliableRemoteEvent` has no ordering with either.
- An instance created by a server invocation may not have streamed to the client yet when the call returns.
- The server owns the outcome: check types, ranges, distance and cooldowns on every `OnServerEvent` and `OnServerInvoke`.

## Common mistakes

- Avoid: trusting arguments from `FireServer`. Symptom: exploiters send any values they like; validate every one on the server.
- Avoid: `InvokeClient` for anything important. Symptom: the server errors if the client errors or leaves, and yields forever if the client never returns; prefer `FireClient`.
- Avoid: full state over an `UnreliableRemoteEvent`. Symptom: updates over 1,000 bytes silently vanish; send small, frequently replaced data with a sequence number.
- Avoid: firing a remote every frame for all players. Symptom: throttling and latency once the shared per-client rate is reached.
- Avoid: using a `RemoteFunction` when no reply is needed. Symptom: callers yield for a round trip; a `RemoteEvent` is cheaper.

## Checklist

- One server handler per remote, validating type, range and rate for each argument.
- `RemoteEvent` for state changes, `UnreliableRemoteEvent` for replaceable cosmetic or positional updates, `RemoteFunction` only for client-to-server requests that need an answer.
- Per-player rate limiting on every client-to-server remote.
- Handlers connected early so queued messages are not lost to queue overflow.

Source: https://create.roblox.com/docs/reference/engine/classes/RemoteEvent, https://create.roblox.com/docs/reference/engine/classes/RemoteFunction, https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent and https://create.roblox.com/docs/scripting/events/remote - verified 2026-10-29

<!-- related:start -->
## Related
[[AI Pitfalls - Networking and Security]] · [[Replication Boundary]] · [[MessagingService - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[MemoryStoreService - Engine Reference Card]] · [[CollectionService - Engine Reference Card]] · [[DataStoreService - Engine Reference Card]] · [[Instance - Engine Reference Card]] · [[TeleportService - Engine Reference Card]] · [[TextChatService - Engine Reference Card]]
<!-- related:end -->
