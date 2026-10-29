---
tags: [game-design, genre, battle-royale, zone, loot, squads, matchmaking, streaming, server-size, teleport, type/guide, area/design]
---
# Genre Playbook - Battle Royale

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Large lobby requirement at launch CCU.
> - Avoid: Client-side zone damage.
> - Avoid: Final circles in unreachable places.
> - Lobby size and match length chosen for your real CCU.
> - Lobby and match places; reserved servers; teleport failure handling.
> - Server-owned zone with validated end points and timed damage checks.
>
> Cost: TL;DR ~120 tok · whole note ~1.7k tok. Read more: ## 3. Places and teleports · ## 4. The zone · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Battle royale (BR) drops a large group onto a big map, makes them scavenge for gear, and shrinks the playable area until one player or squad remains. It is one of the most expensive genres to build on Roblox: large streamed maps, a loot economy, a zone, squads and matchmaking, plus all the shooter netcode in [[Genre Playbook - Shooters FPS and TPS]]. It is also a genre where Roblox's platform limits (server size, physics, phone performance) shape design more than taste does. Read this before committing.

Labels: **Roblox docs**, **Rule of thumb**, **Unverified**.

## 1. Is BR right for you?

BR needs a full lobby to be fun. With low concurrency, matches start half-empty and feel dead ([[Rescuing a Weak Launch - Empty Servers, Low CCU and Relaunch Tactics]]). Before building BR, ask:

- Can matches be fun with 12 to 20 players instead of 50+?
- Can you fill matches with bots early on without hiding it dishonestly?
- Do you have a smaller hook (a mode, a movement mechanic, a theme) that sets you apart?

Many successful Roblox "BR-likes" are small-lobby, fast variants: 10 to 30 players, 5 to 10 minute matches.

## 2. Match structure

| Phase | Length (rule of thumb) | Design goal |
|---|---|---|
| Lobby | until full or timer | Cosmetics, warm-up, squad forming |
| Drop | 30 to 60 s | Choose a landing spot: risk vs loot |
| Early loot | 1 to 3 min | Gear up; first fights at hot drops |
| Mid zones | 3 to 6 min | Rotations, third parties |
| End zones | 1 to 3 min | Forced final fights |
| Results | 10 to 20 s | Placement, kills, rewards, re-queue |

Total 6 to 15 minutes. Shorter is better for phones and younger audiences.

## 3. Places and teleports

Use a **lobby place** and a **match place**. The lobby groups players into squads and queues; a matchmaker reserves a match server and teleports the group ([[Matchmaking Queues with MemoryStore]], [[Reserved and Private Servers in Practice]], [[Parties and Group Teleports]]).

- Pass squad and loadout data through teleport data **only for display**; re-verify everything from DataStores in the match place ([[Session State Across Places]]).
- Handle teleport failures: retry, then return players to the lobby with an explanation.
- Start the match on a timer even if not full; fill with bots or shrink the zone faster.

## 4. The zone

Server-owned state: current circle centre and radius, next circle, phase timers, damage per tick. Clients render the wall and the minimap.

```lua
--!strict
-- Server: next zone centre inside the current zone so the final area is always reachable.
local function nextCircle(center: Vector2, radius: number, shrink: number, rng: Random): (Vector2, number)
	local newRadius = radius * shrink
	local maxOffset = radius - newRadius
	local angle = rng:NextNumber(0, 2 * math.pi)
	local dist = maxOffset * math.sqrt(rng:NextNumber()) -- uniform over the disc
	return center + Vector2.new(math.cos(angle), math.sin(angle)) * dist, newRadius
end
```

Validate zone positions against the map: a final circle over the ocean or inside a mountain ruins a match. Pre-bake a set of valid end points and bias toward them. Apply zone damage on the server by checking each character's horizontal distance on a timer (every 0.5 to 1 s), not with touch events.

## 5. Loot

- Spawn tables per location tier (hot drops richer), generated at match start on the server ([[Procedural Loot and Item Generation]]).
- Items in the world are lightweight: one model per pickup, not a full tool, until picked up.
- Pickup validated by distance and line of sight on the server.
- Inventory small (5 slots is a common pattern) to force decisions.
- Rarity colours consistent across the game.

## 6. Squads

- Solo, duo, trio or squad queues; at low CCU offer one mode only.
- Downed state and revives for squads; knock-out instead of instant elimination.
- Pings and markers for players without chat.
- Spectate teammates after elimination; leave and re-queue without penalty once your squad is out.

## 7. The map and streaming

- A BR map is mostly empty space between points of interest. Use StreamingEnabled, atomic models for buildings, and low-detail terrain far away ([[Instance Streaming]], [[Infinite and Streamed Worlds]]).
- Drop from height means the client must stream the landing area quickly; consider `Player:RequestStreamAroundAsync` toward the chosen landing spot.
- Long sightlines over streamed terrain need low-detail impostors so snipers see buildings that have not streamed in.
- Test with the full player count on low-end phones; memory is the usual killer.

## 8. Shooter netcode at BR scale

Everything in the shooter playbook applies, with more players and longer ranges: server-validated hits with capped rewind, rate limits, projectile drop for long-range weapons ([[Projectiles and Ballistics]]). With 50 players, budget the server's per-shot validation cost.

## 9. Monetisation

- Cosmetics: skins, weapon wraps, emotes, drop trails.
- Battle pass with cosmetic rewards ([[Battle Pass and Season Design]]).
- No paid weapons or armour; BR players are sensitive to pay-to-win.

## Common mistakes

- **Large lobby requirement at launch CCU.**
- **Client-side zone damage.**
- **Final circles in unreachable places.**
- **Loot as full tools** lying everywhere (memory and replication).
- **Trusting teleport data** for unlocks.
- **No bots or timers**; matches never start.

## Checklist

- [ ] Lobby size and match length chosen for your real CCU.
- [ ] Lobby and match places; reserved servers; teleport failure handling.
- [ ] Server-owned zone with validated end points and timed damage checks.
- [ ] Loot tables per tier; lightweight world pickups; server pickup validation.
- [ ] Squad revive, pings, spectate.
- [ ] Streaming tuned for drops and long sightlines; tested on phones at full count.
- [ ] Cosmetic-only store.

## See also

- [[Genre Playbook - Shooters FPS and TPS]]
- [[Matchmaking Queues with MemoryStore]]
- [[Teleporting and Multi-Place Games]]
- [[Instance Streaming]]
- [[Procedural Loot and Item Generation]]

## Connected notes

[[Case Study - Rivals]] · Weekend Build - Arena Shooter with Server-Checked Hits · Server Browsers and Server Lists · Parties and Group Teleports

<!-- related:start -->
## Related
[[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Genre Playbook - Party and Minigame Collections]] · [[Genre Playbook - Battlegrounds and Arena Fighters]] · [[Genre Playbook - Tower Defense]] · [[Genre Playbook - Naval and Open-Sea Adventure]] · [[Genre Playbook - Open-World City and Crime Roleplay]] · [[Genre Playbook - Sports]] · [[Genre Playbook - Social Deduction and Murder Mystery]]
<!-- related:end -->
