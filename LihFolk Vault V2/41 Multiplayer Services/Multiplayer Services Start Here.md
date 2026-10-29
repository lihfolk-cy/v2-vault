---
cssclasses: [vault-hub]
tags: [multiplayer, hub, matchmaking, parties, teleport, reserved-servers, memorystore, live-ops, type/hub, area/networking, level/beginner, area/performance]
---
# Multiplayer Services Start Here

This section is about everything that happens **between** servers: matching players, keeping friends together, giving groups their own server, letting players pick a server, updating a live game safely, and carrying state from one place to the next. Here the unit of design is the whole fleet of servers and places that make up one experience.

It builds on four older notes. Read them first if the services are new to you; the notes here go deeper and do not repeat them:

- [[MemoryStore Service]]: queues, sorted maps, hash maps, quotas, error codes.
- [[Cross-Server Messaging]]: MessagingService limits, payload design, best-effort delivery.
- [[Teleporting and Multi-Place Games]]: `TeleportAsync`, reserved server basics, teleport data trust, `TeleportInitFailed`, access settings.
- [[Social Design and Multiplayer Play]]: why groups, friends and private servers matter to retention.

## The six notes

| Note | Problem it solves | Key ideas |
|---|---|---|
| [[Matchmaking Queues with MemoryStore]] | Fixed-size matches that start together, with fair skill spread | Built-in custom matchmaking vs your own queue, tickets, leader lease, compare-and-set claims, widening windows, budget maths |
| [[Parties and Group Teleports]] | Friends split by teleports | `Player.PartyId`, `SocialService:GetPartyAsync`, 50-player group teleports, gathering a party from several servers, arrival barrier |
| [[Reserved and Private Servers in Practice]] | Instances, rooms and player-owned servers | Telling server kinds apart, private server pricing rules, owner powers, run records, persistent rooms, shareable codes |
| [[Server Browsers and Server Lists]] | Letting players pick a server without wrecking population | Registry, snapshot builder, the 32 KB limit, hot keys, joining by `ServerInstanceId`, friend presence, filtered names |
| [[Server Shutdowns Soft Updates and Migration]] | Updating a live, multi-place game safely | Version skew, schema guard, expand then contract, drain on `ServerRestartScheduled`, release order, kill switches |
| [[Session State Across Places]] | Carrying "what the player was doing" across a teleport | Durable, transit and hint tiers, envelope with nonce, save and release, atomic consume, reclaim on failure |

## Suggested reading paths

- **Competitive or co-op match game:** Matchmaking, then Parties, then Session State, then Reserved Servers (run records). Pair with [[Spawning Teams and Rounds]] and [[Genre Playbook - Party and Minigame Collections]].
- **Roleplay or hangout:** Reserved and Private Servers, then Server Browsers, then Parties. Pair with [[Lobby and Hub Design]] and [[Genre Playbook - Roleplay and Social Hangouts]].
- **Live ops and release owner:** Server Shutdowns first, then Session State. Pair with [[Server Lifecycle and Shutdown]], [[Release Process and Rollbacks]] and [[Global State and Live Config]].
- **Data and backend engineer:** Session State, then Matchmaking (for the claim pattern), then Server Browsers (for budgets). Pair with [[Session Locking and Profile Libraries]] and [[Saving Correctly - Autosave and BindToClose]].

## Patterns that repeat across the section

1. **State in a store, message as a hint.** MessagingService is best effort; the truth lives in a store record a poll can always find.
2. **Compare-and-set with `UpdateAsync`.** Leases, claims, envelope consumption and room creation all refuse by returning `nil` from a pure transform.
3. **The client carries pointers, never value.** Access codes and rewards stay server-side.
4. **Every failure ends in a known state:** the player is at the source or the destination with a loaded profile, never in between.
5. **Version everything that crosses a boundary**, so old and new servers can coexist during an update.

## Related notes elsewhere

- Security of the remotes that start all of this: [[Server Authority and Validation]], [[Remote Abuse Patterns and Rate Limiting in Practice]].
- Data foundations: [[DataStore Fundamentals]], [[Data Schema Design and Migrations]], [[Schema Migrations - Worked Case Studies]], [[Data Loss Prevention and Recovery]].
- Places and access settings: [[Places Universes and Experience Settings]].
- Testing multi-server behaviour: [[Multi-Client and Live Testing]], [[Testing Modes - Play Run and Multi-Client]].

## Conventions used in this section

- Facts are labelled "Roblox docs (as of October 2026)" or "rule of thumb".
- Code is `--!strict`, server-authoritative Luau with failure paths written out, reviewed but not run in every engine build. Teleports do not work in Studio playtests: test in a published private test universe.

## Connected notes
<!-- auto-links:start -->
[[Session Lock]] · Links - Reserved and private servers · Links - MemoryStore · Skill - Roblox DataStore Safety · Debugging DataStore Problems · Cookbook - Data and Saving
<!-- auto-links:end -->
