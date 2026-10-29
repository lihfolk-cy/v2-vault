---
tags: [ai, agents, ai-skill, security, remotes, networking, type/guide, area/security, level/intermediate, area/networking]
---
# Skill - Roblox Secure Remotes

**Skill file:** [skills/roblox-secure-remotes/SKILL.md](../skills/roblox-secure-remotes/SKILL.md) (folder name `roblox-secure-remotes`)

## What it does

This skill makes an agent design and review RemoteEvents, UnreliableRemoteEvents and RemoteFunctions as public APIs that any modified client can call with anything. It has two modes: writing a new remote, and reviewing existing ones.

For a new remote, the agent:

- decides whether it should be a remote at all (state belongs in attributes, moments in remotes),
- picks the type (reliable for anything that must arrive, unreliable only for small replaceable data under 1,000 bytes, RemoteFunction client to server only, never `InvokeClient`),
- creates it on the server from one list,
- writes the handler in a fixed order: rate limit, shape and type, value checks (NaN, infinity, range, length, instance location and ownership), context, lock and act, then score rejections quietly,
- computes every outcome (damage, price, reward) on the server and relays only server-built payloads to other clients.

For a review, it lists every remote, checks each handler against that order, greps for the classic mistakes (`InvokeClient`, forwarded `FireAllClients` arguments, yields between check and write, client-supplied prices) and ranks findings with money and items first.

## Key numbers it uses

- About 500 client-to-server requests per second per client, shared by remotes of the same type (Roblox docs).
- Unreliable payloads over 1,000 bytes are dropped silently (Roblox docs).
- Rate limits at 1.5x to 2x the fastest legitimate use (rule of thumb).

## When to use it

Adding or changing any remote, Touched handler, ProximityPrompt or ClickDetector; reviewing networking code; or after a report of duplicated items or impossible actions.

## Notes behind it

[[RemoteEvents RemoteFunctions and Unreliable Remotes]], [[Server Authority and Validation]], [[Rate Limiting and Abuse Prevention]], [[Remote Abuse Patterns and Rate Limiting in Practice]], [[Cookbook - Remotes and Networking]], [[How Exploits Work - The Client Boundary]], [[Testing Your Own Remotes - Fuzzing and Abuse Tests]], [[Debugging Client-Server Desync]].

## Related

- [[AI Skills Start Here]]
- [[Skill - Roblox Anti-Exploit Review]] for the whole-game view
- [[Skill - Roblox System Builder]], which calls this skill for every handler

## Connected notes
<!-- auto-links:start -->
[[Skill - Roblox Debugging]] · [[Official Docs - Scripting and Luau]] · Exploits and Anti-Cheat · Rate Limiting · Anti-Exploit Start Here
<!-- auto-links:end -->
