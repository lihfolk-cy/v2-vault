---
tags: [core-concept, architecture, security, networking, server-authority, type/reference, area/security, level/beginner, area/networking]
---
# Server Authority

<!-- tldr:start -->
> [!tldr] TL;DR
> - Every client runs code the player controls.
> - Authority is per piece of state, not per game.
> - Authority does not mean the client waits.
> - Display copies are not inputs. The client may hold a copy of prices or odds for the UI, but the server must never read those...
>
> Cost: TL;DR ~110 tok · whole note ~1.1k tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

**Server authority** is the rule that the server owns every piece of state that matters (currency, inventory, damage, cooldowns that gate power, round results) and decides every outcome. Clients render, predict and *ask*; the server checks the request and either applies it or ignores it.

## Why it matters on Roblox

Every client runs code the player controls. An exploiter can delete your LocalScripts, call any RemoteEvent with any arguments, and read every value replicated to them (Roblox docs, "Security and cheat mitigation tactics", as of October 2026). That means a check that runs only on the client is not a check. Server authority is the only security model that survives this, and it also fixes a whole class of honest bugs: two clients can never disagree about who won if only the server decides.

## The nuance most people miss

1. **Authority is per piece of state, not per game.** In the classic model the client owns its own character's physics (see [[Network Ownership]]), so the server cannot simply "own" movement; it validates movement after the fact. Being authoritative over gold and advisory over position is normal and correct.
2. **Authority does not mean the client waits.** Good games predict on the client (play the swing, show the number) and let the server confirm or correct. Server authority plus client prediction is the senior pattern; server authority plus input delay feels bad on phones with 150 ms ping.
3. **Display copies are not inputs.** The client may hold a copy of prices or odds for the UI, but the server must never read those values back from a remote. If a remote argument says `price = 0`, the bug is that price was an argument at all.
4. **Roblox has been rolling out a server-authoritative character and physics model** (a beta in 2025). It changes who simulates movement, not the rule that the server decides outcomes. Check its current status before relying on it; this vault has not verified its final shape.

## Tiny example

```lua
-- Server: the client asks to buy; the server decides everything else.
BuyRemote.OnServerEvent:Connect(function(player: Player, itemId: unknown)
	if typeof(itemId) ~= "string" then return end
	local item = ShopConfig[itemId]          -- server-side price, never the client's
	if not item then return end
	local profile = Profiles[player]
	if not profile or profile.Coins < item.Price then return end
	profile.Coins -= item.Price
	table.insert(profile.Items, itemId)
end)
```

The client sends only *intent* (`itemId`). Price, balance and result live on the server.

## Where this shows up

- [[Server Authority and Validation]]: the full layered validation model and reusable validator.
- [[Client-Server Model]]: what runs where and why the boundary exists.
- [[How Exploits Work - The Client Boundary]]: what an exploiter can actually touch.
- [[Threat Modeling a Roblox Game]]: deciding which state needs authority first.
- [[Client Prediction and Reconciliation for Combat]]: keeping authority without input lag.
- [[Combat Systems Architecture]]: hit decisions on the server, effects on the client.
- [[Economy Exploits - Dupes Races and Purchase Abuse]]: what happens when currency is not authoritative.
- [[Shop with Game Passes and Developer Products End to End]]: a worked shop that sends intent only.
- [[Debugging Client-Server Desync]]: symptoms when two sides both think they own a value.
- [[Detecting Movement Exploits - Speed Fly Noclip Teleport]]: validating state the client owns.
- [[Replication and Ownership]]: animation is one of the few things a client legitimately authors.
- [[Melee Combat System End to End]]: authority applied to a full combat loop.

Related concepts: [[Replication Boundary]], [[Rate Limiting]], [[Idempotency]], [[Input Buffering]].

## Connected notes
<!-- auto-links:start -->
[[Anti-Exploit Start Here]] · Skill - Roblox Anti-Exploit Review · Official Docs - Networking and Multiplayer · Cookbook - Remotes and Networking · Official Docs - Scripting and Luau · [[Core Concepts Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[AI Pitfalls - Networking and Security]] · [[Deterministic Simulation]] · [[Streaming Radius]] · [[Input Buffering]] · [[Session Lock]] · [[Anticipation]] · [[Event Bus]] · [[Hit-Stop]] · [[Data Schema Versioning]]
<!-- related:end -->
