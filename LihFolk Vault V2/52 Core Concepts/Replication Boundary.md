---
tags: [core-concept, networking, replication, architecture, type/reference, area/networking, level/beginner]
---
# Replication Boundary

<!-- tldr:start -->
> [!tldr] TL;DR
> - Most "works in Studio, breaks live" bugs are a value on the wrong side of this line: a LocalScript sets an attribute and the...
> - (Roblox docs, "Replication" and "Network ownership", as of October 2026.)
> - Streaming changes "replicated" into "replicated if near".
> - Remote arguments are copies, not references.
>
> Cost: TL;DR ~120 tok · whole note ~1.1k tok. Read more: ## What crosses, in short · ## The nuance most people miss
<!-- tldr:end -->

The **replication boundary** is the line between what the server sends to every client automatically and what stays local to one machine. Changes the server makes to replicated instances (in Workspace, ReplicatedStorage and similar containers) flow down to clients. Changes a client makes stay on that client, with a short list of exceptions. Everything else crosses only through remotes you write.

## Why it matters on Roblox

Most "works in Studio, breaks live" bugs are a value on the wrong side of this line: a LocalScript sets an attribute and the server never sees it, a server script expects a client-made part to exist, a client edits a Value object and believes it saved. Knowing exactly what crosses, and in which direction, removes a whole debugging category.

## What crosses, in short

| Direction | Crosses automatically | Does not cross |
|---|---|---|
| Server to client | Instances, properties and attributes in replicated containers (subject to streaming) | ServerStorage, ServerScriptService contents |
| Client to server | Physics of parts the client owns (its character), animations played through its own Animator, a few character properties | Everything else: client-created parts, client-set attributes, client Value edits |

(Roblox docs, "Replication" and "Network ownership", as of October 2026.)

## The nuance most people miss

1. **Streaming changes "replicated" into "replicated if near".** With `StreamingEnabled`, a part can exist on the server and be absent on the client. Client code must wait for or tolerate missing instances; see [[Streaming Radius]].
2. **Remote arguments are copies, not references.** Tables crossing a remote lose metatables, mixed tables lose keys, and non-string dictionary keys are converted or dropped (Roblox docs, "Argument limitations for bindables and remotes"). An Instance argument arrives as `nil` if the receiver cannot see it.
3. **Ordering covers reliable remotes only.** Reliable `RemoteEvent`s arrive in order per direction, even across different RemoteEvent instances; `UnreliableRemoteEvent`s are not ordered (Roblox docs, see [[RemoteEvents RemoteFunctions and Unreliable Remotes]]). There is no guaranteed order between property replication and remotes: do not assume a property change and a remote fired in the same frame arrive in a fixed order relative to each other.
4. **Bandwidth is the hidden cost.** Every replicated property change on a replicated instance is network traffic for every client in range. Spinning a decorative part from the server costs bandwidth per player; spin it on the client instead.

## Tiny example

```lua
-- LocalScript: this never reaches the server.
workspace.Door:SetAttribute("Open", true)

-- Correct: ask the server, which owns the door.
DoorRemote:FireServer("Open")
```

## Where this shows up

- [[Replication Rules]]: the full reference on what replicates.
- [[Client-Server Model]]: the boundary's reason for existing.
- [[RemoteEvents RemoteFunctions and Unreliable Remotes]]: the only intended way across.
- [[Instance Streaming]]: when replicated content is not yet on the client.
- [[Interest Management and Per-Player Replication]]: sending different data to different players.
- [[Network Bandwidth Budgets and Measuring Them]]: the cost of every replicated change.
- [[Debugging Client-Server Desync]]: diagnosing a value on the wrong side.
- [[Replication and Ownership]]: why client-played animations replicate.
- [[Serialization Formats for Saves and Networking]]: packing data so it survives the crossing.
- [[Network Ownership]]: the physics exception to the rule.
- [[How Exploits Work - The Client Boundary]]: the same line from an attacker's view.
- [[World-Space UI - BillboardGui and SurfaceGui]]: client-only visuals that should never replicate.
- [[Cookbook - Remotes and Networking]]: short recipes for crossing safely.

Related concepts: [[Server Authority]], [[Streaming Radius]], [[Event Bus]].

## Connected notes
<!-- auto-links:start -->
[[Network Performance]] · Skill - Roblox Secure Remotes · Links - Replication · [[Core Concepts Start Here]] · Luau Cookbook Start Here · Case Study - Fast Join and Deferred Loading
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Event Bus]] · [[Deterministic Simulation]] · [[Rate Limiting]] · [[Instance Count]] · [[Feature Flags]] · [[Data Schema Versioning]] · [[Dependency Injection in Luau]] · [[Object Pooling]]
<!-- related:end -->
