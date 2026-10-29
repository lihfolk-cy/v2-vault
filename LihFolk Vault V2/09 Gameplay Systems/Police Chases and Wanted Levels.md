---
tags: [gameplay, roleplay, police, wanted-level, pursuit, ai, teams, anti-abuse, type/guide, area/gameplay, level/intermediate, api/Teams, api/Raycast]
---
# Police Chases and Wanted Levels

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Heat decays on a plain timer -> Decay only when unseen past a grace period
> - Avoid: Client sends "arrest player X" -> Server checks team, heat, range, speed, hold time
> - Avoid: Arrest at any heat -> Heat >= 1 required
> - Heat, LastSeenAt and JailUntil are server-written attributes with a reason log.
> - Heat only from server-detected events.
> - Decay requires being unseen for a grace period; LOS budgeted.
>
> Cost: TL;DR ~150 tok · whole note ~2.4k tok. Read more: ## 2. Decay only out of sight · ## 3. Arrest rules · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Cops-and-robbers is the oldest loop in Roblox city games: commit a crime, gain heat, get chased, escape or get arrested. The loop is simple; the failure modes are not. Heat that decays on a timer makes chases meaningless, arrests decided by a client let anyone jail anyone, and bounty payouts without anti-collusion turn your police team into a farm. This note gives a server-owned heat model that decays only when the suspect is unseen, line-of-sight checks that scale, arrest and escape rules, hooks for NPC pursuit, and the abuse cases to close before launch. Genre context: [[Genre Playbook - Roleplay and Social Hangouts]] and [[Case Study - Brookhaven RP]].

Source labels: **Roblox docs** (create.roblox.com, checked October 2026), **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

---

## 1. Heat is server state with a reason log

Each player has `Heat` (0 to 5 stars, stored as a float so partial heat accumulates) and `LastSeenAt` (server time). Both are attributes written only by the server; clients render stars and the minimap search circle from them.

Heat comes only from server-detected events, never from a remote that says "I committed a crime":

| Event (server detects) | Heat | Notes |
|---|---|---|
| Robbery completed (server-side interaction finished) | +2 | The robbery system calls `addHeat` |
| Damaging a police player or unit | +1 per hit, capped | From your server damage function |
| Ramming a police car (server delta-v + contact) | +0.5 | Rate limited |
| Escaping arrest or jail | +1 | |
| Trespass in a restricted zone | +0.5 once | Zone system |

Keep a short ring buffer of reasons per player for moderation and debugging. When a player reports "I got 5 stars for nothing", you will want it.

## 2. Decay only out of sight

The core rule that makes chases work: **heat does not fall while any cop can see you**. It falls after you have been unseen for a grace period, and faster at low heat.

```lua
--!strict
-- Server. Called at ~4 Hz. Assumes Teams has a "Criminals" Team.
local Teams = game:GetService("Teams")

local GRACE = 8          -- seconds unseen before decay starts
local DECAY_PER_SEC = 0.25
local SIGHT_RANGE = 180

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function canSee(copRoot: BasePart, suspectRoot: BasePart): boolean
	local delta = suspectRoot.Position - copRoot.Position
	if delta.Magnitude > SIGHT_RANGE then return false end
	params.FilterDescendantsInstances = { copRoot.Parent :: Instance, suspectRoot.Parent :: Instance }
	return workspace:Raycast(copRoot.Position + Vector3.new(0, 2, 0), delta, params) == nil
end

local function tick(dt: number, policeRoots: { BasePart })
	local now = workspace:GetServerTimeNow()
	for _, player in Teams.Criminals:GetPlayers() do
		local heat = (player:GetAttribute("Heat") :: number?) or 0
		if heat <= 0 then continue end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then continue end
		local seen = false
		for _, cop in policeRoots do
			if canSee(cop, root) then seen = true break end
		end
		if seen then
			player:SetAttribute("LastSeenAt", now)
			player:SetAttribute("LastSeenPos", root.Position)
		elseif now - ((player:GetAttribute("LastSeenAt") :: number?) or 0) > GRACE then
			player:SetAttribute("Heat", math.max(0, heat - DECAY_PER_SEC * dt))
		end
	end
end
```

Scaling notes (Rule of thumb):
- Cost is suspects x cops raycasts per tick. At 4 Hz with 10 suspects and 15 cops that is 600 rays/s, fine. With many NPC units, check only the 3 to 5 nearest cops per suspect, and stop at the first hit.
- Use the suspect's vehicle root when they are seated ([[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]]); raycasts from a car's interior hit its own body otherwise, so exclude the vehicle model too.
- `LastSeenPos` is what NPC units search when they lose you, and what the minimap circle centres on (offset randomly so it is not a perfect tracker).

## 3. Arrest rules

Arrest is the high-stakes action, so the server decides everything:

- The officer is on the Police team and holds the cuff tool; the suspect has `Heat >= 1`. **No heat, no arrest.** This single rule kills most griefing.
- Distance between roots under ~8 studs, checked on the server at the moment of the request and again after a short hold (0.75 to 1.5 s channel). Moving out of range cancels.
- Suspect must be slow (under ~6 studs/s) or "downed" (stunned by a taser hit validated on the server, or vehicle disabled). Arresting someone driving at full speed by touching their car is the classic exploit target.
- On success: remove from vehicle (`Humanoid.Sit = false`), teleport to jail, set `JailUntil` server time scaled by heat (e.g. 30 s + 20 s per star), reset heat to 0, pay the officer.

Escapes: breaking out of jail sets heat to at least 2. Leaving the server while wanted is common; decide a policy (heat persists for N minutes via a short session record, or jail on next join). Rule of thumb: persist for 10 minutes so "rage quit to escape" stops working, and tell players.

## 4. Pursuit hooks for NPC police

NPC units are optional but help servers with few police players. Keep them simple and budgeted:

- **Spawn budget** per heat level, e.g. 0 units at 1 star, 1 at 2, 2 at 3, 4 at 5, capped server-wide. Spawn out of the suspect's view, ahead on their road graph, not behind them in plain sight.
- **States**: Patrol -> Pursue (has line of sight) -> Search (go to `LastSeenPos`, then random nearby road nodes for 20 s) -> Return. A small state machine is enough ([[Behaviour Trees Utility AI and State Machines for NPCs]]).
- **Driving**: follow road waypoints, not raw pathfinding over terrain; NPC cars are server-owned and expensive, so cap them and despawn when far from all players ([[Physics Performance]]).
- NPC units count as "cops" for line of sight, so they extend chases without being able to arrest unless you choose to allow it.

## 5. Bounties and anti-collusion

The farm: a friend gets heat, the other arrests them, repeat. Close it on the server:

- Bounty scales with heat **earned over time** (heat-minutes), not with heat level alone, so instant crime-then-surrender pays little.
- Diminishing returns per officer-suspect pair: full pay for the first arrest of a given suspect per 15 minutes, then 25%, then 0.
- No payout if the suspect's heat came only from attacking that same officer.
- Log pairs with high arrest counts for review ([[Economy Exploits - Dupes Races and Purchase Abuse]]).

## 6. Team balance and server sizing

Chases need a ratio. Rule of thumb: about one police player per three to four criminals; cap the Police team and show a queue. With very small servers, lean on NPC units. Give police a non-chase loop (patrol pay, traffic stops) so the team is not dead when nobody is wanted.

Content: crime and police themes are normal on Roblox but answer your experience's maturity questionnaire honestly for violence and crime content (Roblox docs: https://create.roblox.com/docs/production/promotion/content-maturity). Keep arrests non-graphic.

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Heat decays on a plain timer | Suspects hide in a corner, chases fizzle | Decay only when unseen past a grace period |
| Client sends "arrest player X" | Anyone jailed from across the map | Server checks team, heat, range, speed, hold time |
| Arrest at any heat | Police grief random players | Heat >= 1 required |
| Bounty on heat level only | Friends farm arrests | Heat-minutes plus pair diminishing returns |
| Raycasts ignore the suspect's car | Suspect "never seen" in a vehicle | Exclude the vehicle model, cast to its root |
| Unbounded NPC units | Server physics collapses at 5 stars | Per-heat and global budgets |
| Leaving the server clears heat | Rage-quit escapes | Short persistence window |

## Checklist

- [ ] Heat, LastSeenAt and JailUntil are server-written attributes with a reason log.
- [ ] Heat only from server-detected events.
- [ ] Decay requires being unseen for a grace period; LOS budgeted.
- [ ] Arrest validated: team, heat, distance, speed or downed, hold time.
- [ ] Bounties use heat-minutes and pair diminishing returns.
- [ ] NPC units budgeted per heat and server-wide.
- [ ] Team caps and a non-chase police loop.

## See also

[[Genre Playbook - Roleplay and Social Hangouts]] · [[Case Study - Brookhaven RP]] · [[NPC AI and Behaviour]] · [[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Raycasts Shapecasts and Spatial Queries]] · [[Spawning Teams and Rounds]] · [[Economy Exploits - Dupes Races and Purchase Abuse]] · [[Horror Monster Chase AI End to End]]

## Connected notes
<!-- auto-links:start -->
[[Multi-Seat Vehicles - Driver, Passenger and Gunner Roles]] · Vehicle Damage, Repair and Wreck States · [[Pathfinding]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Genre Playbook - Open-World City and Crime Roleplay]] · [[Weekend Build - Roleplay Town with Jobs and Paychecks]] · [[Case Study - Jailbreak]] · [[Pathfinding Edge Cases and Fallbacks]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]] · [[Visual AI Debugging - State Labels, Path Lines and Perception Gizmos]]
<!-- related:end -->
