---
tags: [ai-pitfalls, networking, security, remotes, validation, replication, streaming, network-ownership, server-authority, anti-exploit, type/guide, area/ai]
verified: 2026-10-28
---
# AI Pitfalls - Networking and Security

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Validating on the client "for responsiveness" and forgetting the server copy.
> - Avoid: One remote per action with no shared validation and rate-limit wrapper.
> - Avoid: Kicking on the first anomaly (false positives on lag).
> - Every `OnServerEvent` validates type, NaN, range, ownership and rate first.
> - No client-sent price, damage, reward or position used as truth.
> - No `InvokeClient`.
>
> Cost: TL;DR ~140 tok · whole note ~2.2k tok. Read more: ## 1. The server trusts numbers the client sends · ## 9. Network ownership misconceptions · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Models write Roblox networking as if the client were a trusted UI for a single program. Every item below compiles and works in Play Solo; most are exploitable or race-prone live. Hub: [[What AI Models Get Wrong in Roblox]].

## 1. The server trusts numbers the client sends

- **Wrong:** `BuyRemote.OnServerEvent:Connect(function(plr, itemId, price) plr.Coins.Value -= price ...)`, or damage, hit position, reward amount, "I own this" flags as arguments.
- **Why:** the model designs the call from the UI's point of view: the button knows the price, so it sends it.
- **Right:** the client sends **intent** (an id). The server looks up everything else and checks eligibility.

```lua
BuyRemote.OnServerEvent:Connect(function(player, itemId)
	if typeof(itemId) ~= "string" then return end
	local item = Catalog[itemId]                 -- server-side table, never client data
	if not item or not Shop.isUnlocked(player, item) then return end
	Economy.trySpend(player, item.price, "shop:" .. itemId) -- atomic check-and-spend
end)
```

- **Detect:** handler parameters named `price`, `cost`, `amount`, `damage`, `reward`, `position`, `owned`; any arithmetic on an argument before validation. See [[Server Authority and Validation]].

## 2. No type, range or NaN validation

- **Wrong:** using arguments directly. Exploiters send tables where numbers are expected, `NaN`, `math.huge`, negative counts, deep tables, or instances from elsewhere in the DataModel.
- **Right:** validate type, finiteness, range and ownership first.

```lua
local function finiteNumber(x, lo, hi)
	return typeof(x) == "number" and x == x and x > lo - 1e-9 and x < hi + 1e-9 -- x == x rejects NaN
end
local function ownedTool(player, inst)
	return typeof(inst) == "Instance" and inst:IsA("Tool") and inst:IsDescendantOf(player.Character or player.Backpack)
end
```

- **Detect:** handlers with no `typeof` check in the first lines. Fuzz them: [[Testing Your Own Remotes - Fuzzing and Abuse Tests]].

## 3. No rate limit

- **Wrong:** every remote accepts unlimited calls. A loop on the client can farm, spam DataStore writes, or flood other players.
- **Right:** per-player token bucket on every remote; drop excess silently and log. Since October 2026 Roblox also requires player-entered **non-chat text** to be limited to one submission per minute (see [[Policy and Age Rules 2026]]).
- **Detect:** remotes without a shared limiter wrapper. See [[Rate Limiting and Abuse Prevention]].

## 4. `RemoteFunction:InvokeClient`

- **Wrong:** the server asks a client for data and waits.
- **Why:** symmetric-looking API.
- **Right:** never invoke the client from the server. A client that never returns (or errors, or disconnects) can hang the server thread. Use a RemoteEvent request and a RemoteEvent reply with a timeout, or keep the data on the server.
- **Detect:** `rg -n "InvokeClient"`.

## 5. Client-side checks treated as security

- **Wrong:** anti-cheat in a LocalScript, hiding a button as access control, client-side cooldowns as the only cooldown, `WalkSpeed` checks on the client.
- **Right:** anything a LocalScript does, an exploiter can skip. Enforce on the server; use the client only for feedback. For movement exploits, **Server Authority** (released July 9, 2026) blocks speed and fly hacks at the engine level if you can adopt its constraints (see [[Server Authority and Input Migration 2026]]).
- **Detect:** words like `kick`, `ban`, `anticheat`, `exploit` inside LocalScripts.

## 6. Assuming replication order

- **Wrong:** set a property or attribute on the server, then fire a remote, and have the client read the property in the handler.
- **Why:** it usually worked under the old replicator.
- **Right:** send the value in the remote, or react to the property's own change signal. **Roblox docs:** under Next Generation Replication (forced on by Server Authority), small property updates are eventually consistent but unordered relative to remotes.
- **Detect:** `OnClientEvent` handlers that read `:GetAttribute` or properties of an instance passed in the same event.

## 7. Assuming instances exist on the client

- **Wrong:** `workspace.Map.Door.Touched` in a LocalScript, or `WaitForChild("Door")` without a timeout for something that may never stream in.
- **Why:** Studio places often have streaming off, and the model never sees streaming.
- **Right:** with StreamingEnabled (on by default for new places and forced by Server Authority), anything outside the player's radius may be absent. Use `CollectionService:GetInstanceAddedSignal(tag)` and handle removal; set `Model.ModelStreamingMode = Persistent` only for small, essential models. Passing an unstreamed instance through a remote arrives as `nil` on the client. See [[Instance Streaming]].
- **Detect:** deep `workspace.X.Y.Z` paths in LocalScripts; `WaitForChild` with one argument on workspace content.

## 8. Join and spawn races

- **Wrong:** `Players.PlayerAdded:Connect(setup)` only. In Studio and on fast servers, players can be in the game before the script connects. Same for `CharacterAdded` when the character already exists.
- **Right:**

```lua
local function onPlayer(p: Player)
	-- per-player setup
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do task.spawn(onPlayer, p) end
```

- Clean up per-player state in `PlayerRemoving`; models routinely leak tables keyed by `Player` and connections to `CharacterAdded`.

## 9. Network ownership misconceptions

- **Wrong:** calling `SetNetworkOwner` on anchored parts (it errors) or on a non-root part of an assembly; trusting the client's character position as fact; leaving NPCs on automatic ownership so they jitter when ownership hops between players.
- **Right:** ownership is per assembly (set it on the root). The owning client simulates the assembly and can move it anywhere. For NPCs, `root:SetNetworkOwner(nil)` on the server. For players, validate movement server-side or adopt Server Authority; `SetNetworkOwner(nil)` on a character is not a substitute (no latency compensation). See [[Network Ownership]].
- **Measured:** the wall-jump exploit in the reference project: jump counters refilled when `FloorMaterial ~= Air`, and the Humanoid reports a floor on steep walls, so players climbed anything (see [[Characters and Humanoids]]).

## 10. Touch-based combat trusted on the server

- **Wrong:** server `Touched` on a sword blade decides hits.
- **Why:** simplest tutorial pattern.
- **Right:** `Touched` fires from the owner's physics; for a held tool, that is the attacker's client. Use server-side spatial queries or validated client hit reports (distance, angle, cooldown, line of sight). See [[Detecting Combat Exploits - Reach Rate and Aim]].

## 11. Secrets and name collisions

- **Wrong:** API keys or webhook URLs in ModuleScripts under ReplicatedStorage, or anywhere in source; `HttpService` calls from a LocalScript (not allowed).
- **Right:** keys in the experience's **Secrets** store, read on the server with `HttpService:GetSecret(name)`.
- **Measured:** a clip named `Origin` added to a folder that also held a RemoteEvent named `Origin` broke a whole weapon's damage, because `FindFirstChild("Origin")` found the clip. Look remotes up by class or keep them in their own folder (see [[Instances Attributes and Tags]]).

## Common mistakes

- Validating on the client "for responsiveness" and forgetting the server copy.
- One remote per action with no shared validation and rate-limit wrapper.
- Kicking on the first anomaly (false positives on lag). See [[False Positives Lag and Fair Enforcement]].

## Checklist

- [ ] Every `OnServerEvent` validates type, NaN, range, ownership and rate first.
- [ ] No client-sent price, damage, reward or position used as truth.
- [ ] No `InvokeClient`.
- [ ] Client code tolerates missing (streamed-out) instances.
- [ ] Remote handlers do not rely on property-before-remote ordering.
- [ ] NPC assemblies server-owned; player movement validated or Server Authority on.
- [ ] Secrets only via `HttpService:GetSecret` on the server.

## See also

- [[What AI Models Get Wrong in Roblox]]
- [[Server Authority and Input Migration 2026]]
- [[How Exploits Work - The Client Boundary]]
- [[RemoteEvents RemoteFunctions and Unreliable Remotes]]
- [[Remote Abuse Patterns and Rate Limiting in Practice]]
- [[Exploits and Anti-Cheat]]
- [[Debugging Client-Server Desync]]

<!-- related:start -->
## Related
[[Cookbook - Remotes and Networking]] · [[Client-Server Model]] · [[Server Authority]] · [[AI Pitfalls - Physics and Animation]] · [[Replication Boundary]] · [[Rate Limiting]]
<!-- related:end -->
