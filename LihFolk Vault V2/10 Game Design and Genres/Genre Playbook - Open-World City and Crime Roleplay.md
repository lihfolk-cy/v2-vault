---
tags: [game-design, genre, city, crime, cops-and-robbers, roleplay, vehicles, heists, wanted-level, streaming, type/guide, area/design]
---
# Genre Playbook - Open-World City and Crime Roleplay

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Huge empty maps at low server sizes.
> - Avoid: Client-reported robberies or arrests.
> - Avoid: Police with no information or with perfect information.
> - Server size and police cap chosen and tunable live.
> - Wanted heat and alerts server-authoritative; markers show areas, not pinpoints, by default.
> - Robberies are multi-step, timed and validated by position.
>
> Cost: TL;DR ~130 tok · whole note ~2.0k tok. Read more: ## 3. Wanted level and information · ## 5. Vehicles: the expensive system · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The city crime genre (cops versus criminals in an open map with vehicles, robberies and jail) is one of Roblox's oldest durable formats, with Jailbreak as its defining example ([[Case Study - Jailbreak]]). It differs from pure roleplay ([[Genre Playbook - Roleplay and Social Hangouts]]) because it has rules, rewards and an opponent: criminals earn by robbing, police earn by arresting, and both spend on vehicles. That makes it a systems-heavy genre with three hard technical problems: big streamed maps, many player-driven vehicles, and server-authoritative chases.

Labels: **Roblox docs**, **Rule of thumb**, **Unverified**.

## 1. The loops

| Loop | Length | Criminal | Police |
|---|---|---|---|
| Moment | 5 to 30 s | Break in, grab, escape | Spot, chase, arrest |
| Run | 2 to 10 min | Rob a location, reach a safe zone, cash out | Respond to alerts, catch, deliver to jail |
| Session | 20 to 60 min | Buy a better car, unlock a heist | Better car, gear |
| Meta | Weeks | Vehicles, cosmetics, seasons | Same |

The core tension is **asymmetric chase**: criminals pick when and where; police have information (alerts, wanted markers) and tools (cuffs, spikes, roadblocks). If police lack information, they are bored; if criminals have no escape options, they quit.

## 2. Team balance and server size

- **Server size** drives everything. A big map with too few players feels empty; too many players overwhelm robberies. Rule of thumb: start around 20 to 30 per server for a mid-size city and tune with data.
- **Team caps and ratio.** Cap police at roughly a third to two-fifths of the server (rule of thumb) and let the server rebalance on join. Too many police makes crime pointless.
- **Switching cooldowns** stop players from flipping teams to farm or grief.
- **Prisoners** need an activity (escape routes, minigames). Jail time capped and short.

## 3. Wanted level and information

A **wanted level** (server state per criminal) gates what police see and how much a bounty pays.

```lua
--!strict
-- Server: wanted heat decays unless refreshed by crimes.
local HEAT_DECAY_PER_SEC = 0.02
local heat: {[Player]: number} = {}

local function addHeat(player: Player, amount: number)
	heat[player] = math.min((heat[player] or 0) + amount, 5) -- 5 stars max
	player:SetAttribute("Wanted", math.floor(heat[player]))
end

game:GetService("RunService").Heartbeat:Connect(function(dt)
	for player, h in heat do
		local new = math.max(h - HEAT_DECAY_PER_SEC * dt, 0)
		heat[player] = if new > 0 then new else nil
		player:SetAttribute("Wanted", math.floor(new))
	end
end)
```

Only the server calls `addHeat`, from validated crime events. Police UI reads the `Wanted` attribute for map markers. Decide whether markers show exact positions or a search area; search areas create chases, exact markers end them.

## 4. Robberies and heists

- **Locations open on timers** shared server-wide, announced to everyone. Timers create gathering points and police-criminal contact ([[Retention and Return Hooks]]).
- **Steps, not a single button**: enter, break a lock (skill or hold prompt), collect (time spent exposed), escape to a drop point. Each step is a chance for police.
- **Payout scales with risk** (time inside, police count online).
- **Heists** for groups: multi-stage, longer cooldown, bigger payout. They are the content updates.
- **Server-validated progress**: collection rate checked by position inside the location volume; cash-out at a drop point checked server-side. Never let the client report "I robbed the bank".

## 5. Vehicles: the expensive system

Vehicles are the main thing players buy and the hardest system to make fair.

- **Network ownership** goes to the driver for responsiveness. That means the client controls the car's physics, so speed and teleport checks are needed on the server ([[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]]).
- **Spawn caps** per player (one active vehicle) and per server, despawn on idle.
- **Catch-up tools for police** (spike strips, EMP, roadblocks) are better than making police cars faster than every criminal car; a fast-car arms race breaks economies.
- **Handling tiers** over top speed: progression feels better when expensive cars turn and accelerate better, not only go faster.

See [[Genre Playbook - Racing and Driving]] for handling models.

## 6. The map and streaming

- A city with districts: downtown (robberies), suburbs (housing), industrial (heist), highway loop (chases), off-road shortcuts (escapes).
- **StreamingEnabled is mandatory** at this size. Mark robbery interiors and key props as atomic models, keep a persistent model for things the server must reference, and test fast driving through streaming boundaries ([[Instance Streaming]], [[Level of Detail and Model Streaming]]).
- Drive speeds outrun streaming. Tune the streaming target radius and consider `RequestStreamAroundAsync` before teleports or spawns.
- Navigation for police NPCs (if any) and minimap generation need the full layout server-side; do not depend on client streaming for server logic.

## 7. Monetisation that fits

- **Vehicles and cosmetics** are the natural store. Sell expressive cars and skins; make the best gameplay-relevant cars earnable.
- **Convenience passes**: extra garage slots, a premium team perk, a radio. Keep power passes (a car nobody can catch) out.
- **Season or battle pass** with vehicle skins ([[Battle Pass and Season Design]]).
- Private servers for friend groups.

## 8. Safety and griefing

- Spawn-kill and jail-camping protections.
- Arrest requires proximity and a short channel time; resisting has counterplay.
- Kill feeds and bounties must not encourage harassment of specific players; cap bounties per target.
- Text on custom plates or signs filtered.

## 9. Patterns that work

- Server-wide timed events that bring players together.
- Asymmetric tools, not symmetric stats.
- A first robbery in under three minutes for new criminals; a first arrest opportunity soon after joining police.
- Content updates that add one location or heist at a time, with a map change players can see.

## Common mistakes

- **Huge empty maps** at low server sizes.
- **Client-reported robberies or arrests.**
- **Police with no information** or with perfect information.
- **Unlimited vehicles** per player; physics and memory blow up.
- **Selling the fastest car.** Breaks the chase.
- **No streaming plan** for high-speed driving.

## Checklist

- [ ] Server size and police cap chosen and tunable live.
- [ ] Wanted heat and alerts server-authoritative; markers show areas, not pinpoints, by default.
- [ ] Robberies are multi-step, timed and validated by position.
- [ ] Vehicle ownership handled with server speed and teleport checks; spawn caps.
- [ ] StreamingEnabled tuned and tested at top speed.
- [ ] Store sells cosmetics and convenience, not uncatchable cars.
- [ ] Jail and spawn protections; filtered text.

## See also

- [[Case Study - Jailbreak]]
- [[Genre Playbook - Roleplay and Social Hangouts]]
- [[Genre Playbook - Racing and Driving]]
- [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]]
- [[Instance Streaming]]
- [[Detecting Movement Exploits - Speed Fly Noclip Teleport]]

## Connected notes

[[Weekend Build - Roleplay Town with Jobs and Paychecks]] · Physics and Vehicles Start Here · Spawning Teams and Rounds · [[Social Design and Multiplayer Play]]

<!-- related:start -->
## Related
[[Police Chases and Wanted Levels]] · [[Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver]] · [[Genre Playbook - Battle Royale]] · [[Vehicle Spawner and Garage - Spawn, Ownership, Despawn and Limits]] · [[Genre Playbook - Naval and Open-Sea Adventure]] · [[Case Study - Brookhaven RP]]
<!-- related:end -->
