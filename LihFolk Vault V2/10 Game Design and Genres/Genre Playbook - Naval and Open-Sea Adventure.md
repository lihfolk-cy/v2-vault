---
tags: [game-design, genre, naval, ships, ocean, sea-events, islands, crew, streaming, buoyancy, type/guide, area/design]
---
# Genre Playbook - Naval and Open-Sea Adventure

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Empty ocean. Long sails with nothing happening.
> - Avoid: Physics waves that throw crew off decks.
> - Avoid: Full buoyancy simulation for player ships.
> - Something to stop for every 30 to 90 s of sailing.
> - Arcade controller on a flat physics plane; visual waves on the client.
> - Driver ownership with server speed and teleport checks.
>
> Cost: TL;DR ~130 tok · whole note ~1.7k tok. Read more: ## 2. Ships: arcade over simulation · ## 5. Islands and the map · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Open-sea games put players on ships crossing an ocean between islands: sailing, fishing, trading, fighting sea monsters or other crews. On Roblox, sea travel features heavily in games like Blox Fruits and Fisch ([[Case Study - Blox Fruits]], [[Case Study - Fisch]]) and is the whole game in dedicated pirate and naval titles. The genre's appeal is freedom and crew play; its technical risks are ship physics on moving platforms, huge streamed maps that are mostly water, and keeping a crew on the same deck when everyone's client owns different physics.

Labels: **Roblox docs**, **Rule of thumb**, **Unverified**.

## 1. Loops

| Loop | Length | Content |
|---|---|---|
| Moment | seconds | Steer, fire a cannon, repair a leak, reel a fish |
| Voyage | 3 to 10 min | Sail to an island or event, act, return or move on |
| Session | 30 to 90 min | Upgrade the ship, complete a quest chain, beat a boss |
| Meta | weeks | Ship collection, cosmetics, reputation, rare catches |

The ocean must be **dense with reasons to stop**. Empty sailing is the genre's failure mode. Rule of thumb: something interesting (event, island, wreck, floating loot) every 30 to 90 seconds of travel.

## 2. Ships: arcade over simulation

- **Arcade ship controller**: server-authoritative or driver-owned constraints (`VectorForce`, `AlignOrientation`, `LinearVelocity`) with designer-tuned acceleration, turn rate and top speed per ship class. Full buoyancy simulation is fragile and expensive; use it for floating debris, not player ships ([[Boats Buoyancy and Water]]).
- **Waves are visual.** Bob the hull's visual model on the client from a shared wave function; keep the physics root on a flat plane. Players then never fall off a deck because a server wave did not match their screen.
- **Ownership**: the helmsman's client owns the ship for responsive steering; the server checks speed and position jumps ([[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]]).
- **Standing on moving decks**: Roblox characters ride moving assemblies, but fast turns and ownership changes cause slipping and rubber-banding. Keep turn rates moderate, test with several crew members at once, and consider welding seated crew roles.

## 3. Crew roles

Give each crew member something to do so friends want to sail together:

| Role | Job | Interaction |
|---|---|---|
| Helm | Steer, choose route | Seat with steering input |
| Gunner | Aim and fire cannons | Seat per cannon, server-validated shots |
| Repair | Patch hull holes, pump water | ProximityPrompt tasks on damage points |
| Lookout | Spot events, mark targets | Spyglass with marker pings |
| Angler / salvager | Fish, collect floating loot | Minigame |

A solo player should be able to run a small ship with automation (auto-repair upgrade, single-seat cannon). Large ships should need two or more players.

## 4. Sea events

A server-wide event scheduler spawns events at sea locations near players:

- Monster attacks (boss fights on the water; see [[Boss Fight Design Patterns]]).
- Storms (visibility, waves, lightning hazards) driven by a server weather state.
- Shipwrecks and treasure with a timer, announced to nearby ships, creating contests.
- Merchant ships, bounties on other crews (PvP opt-in).

Announce events with direction and distance so crews make route decisions. Events spawn relative to where players are, not uniformly over the ocean.

## 5. Islands and the map

- Islands are hubs: shop, quests, docks, a landmark visible from far away (lighthouse, volcano) for navigation.
- **StreamingEnabled** with islands as atomic or persistent models as needed; the ocean surface can be Terrain water or a large mesh plane. Terrain water at huge scale has memory and performance cost on phones; test both ([[Terrain Deep Dive - Materials Water and Performance]], [[Water Sky and Atmosphere Art]]).
- **Distant islands as low-detail impostors** so the horizon is not empty when streaming has not loaded them ([[Level of Detail and Model Streaming]]).
- **Fast travel** after first discovery keeps sessions moving; sailing should be a choice, not a toll.

## 6. Combat at sea

- Cannon projectiles with visible arcs and generous hit areas; ships are big targets ([[Projectiles and Ballistics]]).
- Hull damage as zones (holes at hit points) that crew repair, rather than one health bar. It creates crew work.
- Sinking is a sequence: warning, slowing, tilting, then respawn at the last dock with partial loss, not wipe of all cargo (rule of thumb).
- PvP: opt-in flags or PvP zones. Forced PvP at sea drives away solo and younger players.

## 7. Saving

Ships, upgrades and cosmetics are saved per player. Cargo in flight can be session-only with a clear rule ("cargo is lost if your ship sinks"). Spawning a saved ship at a dock is a server action with a per-player cap ([[Saved Inventory End to End]]).

## 8. Monetisation

- Ship skins, sails, flags (filtered if custom), figureheads, cannon effects.
- Larger ship classes earnable in play; paid shortcuts acceptable if they do not make ships unsinkable.
- Convenience: extra ship slots, dock anywhere (time-gated), fishing perks.

## Common mistakes

- **Empty ocean.** Long sails with nothing happening.
- **Physics waves** that throw crew off decks.
- **Full buoyancy simulation** for player ships.
- **Forced PvP** at sea.
- **Ocean terrain at full scale untested on phones.**
- **Crew roles that only the helm enjoys.**

## Checklist

- [ ] Something to stop for every 30 to 90 s of sailing.
- [ ] Arcade controller on a flat physics plane; visual waves on the client.
- [ ] Driver ownership with server speed and teleport checks.
- [ ] Four or more crew roles; solo-viable small ship.
- [ ] Event scheduler near players with announced direction and distance.
- [ ] Islands streamed with landmarks and horizon impostors; fast travel.
- [ ] Hull-zone damage with repair; opt-in PvP.

## See also

- [[Boats Buoyancy and Water]]
- [[Case Study - Fisch]]
- [[Case Study - Blox Fruits]]
- [[Instance Streaming]]
- [[Genre Playbook - Combat and RPG]]

## Connected notes

[[Physics and Vehicles Start Here]] · Water Sky and Atmosphere Art · [[Social Design and Multiplayer Play]] · Zone and Biome Art Direction

<!-- related:start -->
## Related
[[Genre Playbook - Racing and Driving]] · [[Genre Playbook - Battle Royale]] · [[Genre Playbook - Open-World City and Crime Roleplay]] · [[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Genre Playbook - Survival and Crafting]] · [[Genre Playbook - Social Deduction and Murder Mystery]] · [[Genre Playbook - Tower Defense]] · [[Genre Playbook - Sports]]
<!-- related:end -->
