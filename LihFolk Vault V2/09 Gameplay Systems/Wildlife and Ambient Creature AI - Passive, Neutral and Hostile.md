---
tags: [gameplay, ai, wildlife, creatures, herds, flocking, survival, open-world, performance, type/guide, area/gameplay, level/intermediate]
---
# Wildlife and Ambient Creature AI - Passive, Neutral and Hostile

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Server-owned birds and butterflies -> Client-only ambient tier
> - Avoid: Humanoid per small animal -> CFrame movers and AnimationController
> - Avoid: Whole map populated at all times -> Spawn by player proximity with caps
> - Every creature assigned a tier; only gameplay-relevant ones are server-owned.
> - Temperament data with alert tells and perception per species.
> - Herd leader, contagious fear, pack tokens and territory leash.
>
> Cost: TL;DR ~150 tok · whole note ~2.3k tok. Read more: ## 3. Herds, packs and flocks · ## 4. Performance architecture · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Survival and open-world games need animals: deer that bolt, wolves that hunt in packs, boars that charge only when provoked, birds that scatter when you walk past. Wildlife AI differs from enemy AI in three ways: most of it is **not combat**, there is **a lot of it**, and much of it can be **client-side and cosmetic**. This note splits creatures into tiers by gameplay importance, gives temperament rules (passive, neutral, hostile), herd and flock behaviours, and the performance architecture that lets a map feel alive without spending the server budget on rabbits. Enemy brains and scheduling are in [[NPC AI and Behaviour]]; rigs in [[Creature Rig Conventions]].

Source labels: **Rule of thumb**, **Roblox docs** where engine calls are used.

---

## 1. Three tiers by authority

| Tier | Examples | Authority | Replication |
|---|---|---|---|
| **Ambient** | Birds, butterflies, fish schools, rabbits that cannot be hunted | Client only | None; each client spawns its own around the camera |
| **Huntable** | Deer, rabbits that drop meat, chickens | Server-owned state (health, alive, loot); simple brain | Position and state replicate; animations local |
| **Dangerous** | Wolves, bears, boars | Server brain with perception and combat | Same as enemies |

**Rule of thumb.** If killing or touching it changes inventory, health or progress, the server owns it. Everything else is client-side decoration that each player may see differently, which is fine: nobody can prove the bird they saw was the same bird.

## 2. Temperaments

| Temperament | Default | Trigger | Response |
|---|---|---|---|
| **Passive** | Graze, wander | Player within flee radius, noise, a herd member fleeing | Flee away from the threat, then calm down |
| **Neutral** | Graze, wander | Being attacked; player very close for long; young threatened | Aggro on the attacker only, then de-aggro after leash or time |
| **Hostile** | Patrol or ambush | Perceives player in range | Hunt and attack; may flee at low health |

Model it as a small state machine per creature: `Idle -> Wander -> Graze -> Alert -> Flee | Attack -> Calm`. **Alert** is the important one: a head-up pause with a sound before fleeing or attacking gives players a moment to react and makes hunting a skill ([[Anticipation]]).

Use **perception** that matches the animal: deer hear well and see motion (crouching players get closer); wolves smell (wind direction is a fun optional modifier). Sneak values belong in data, not code.

## 3. Herds, packs and flocks

### Herds (passive grazers)
- One **leader** wanders on a slow random walk inside its home area; members keep a loose offset from the leader with separation (do not overlap) and a little noise.
- **Contagious fear**: when one member flees, members within a radius flee after a short random delay (0.1 to 0.4 s). The ripple looks natural and warns players they were spotted.
- Flee direction: away from the threat, biased toward the herd's home area and away from map edges and water; re-evaluate every 0.5 s.

### Packs (hostile hunters)
- Pack members circle at mid range and take turns attacking, using the same token idea as enemies ([[Squad AI - Attack Tokens, Flanking and Attacker Limits]]).
- An alpha starts and ends the hunt; if the alpha dies or flees, the pack may scatter. This gives players a priority target.
- Packs give up (leash) at the edge of their territory, so hunts end and players are not chased across the world.

### Flocks (ambient, client)
- Boids with three rules (separation, alignment, cohesion) plus "avoid the player". Run in a single loop per flock on the client; update 10 to 20 Hz and interpolate rendering.
- Scatter on player approach, land again elsewhere after a delay.
- Use `CFrame` updates on anchored, non-colliding, non-queryable parts or simple meshes; for large numbers use `Workspace:BulkMoveTo` (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/WorldRoot#BulkMoveTo).

```lua
--!strict
-- Client-side boid step for one flock (anchored, CanCollide/CanQuery/CanTouch false parts).
type Bird = { part: BasePart, vel: Vector3 }

local function stepFlock(birds: { Bird }, dt: number, threat: Vector3?, home: Vector3)
	for i, b in birds do
		local pos = b.part.Position
		local sep, ali, coh, n = Vector3.zero, Vector3.zero, Vector3.zero, 0
		for j, o in birds do
			if i ~= j then
				local d = o.part.Position - pos
				local dist = d.Magnitude
				if dist < 12 then
					n += 1
					ali += o.vel
					coh += o.part.Position
					if dist < 3 and dist > 1e-3 then sep -= d.Unit / dist end
				end
			end
		end
		local steer = (home - pos) * 0.01
		if n > 0 then
			steer += sep * 2 + (ali / n - b.vel) * 0.05 + ((coh / n) - pos) * 0.02
		end
		if threat and (pos - threat).Magnitude < 25 then
			steer += (pos - threat).Unit * 3
		end
		local v = b.vel + steer * dt * 10
		if v.Magnitude > 20 then v = v.Unit * 20 end
		b.vel = v
	end
	local parts, cframes = table.create(#birds), table.create(#birds)
	for i, b in birds do
		local p = b.part.Position + b.vel * dt
		parts[i] = b.part
		cframes[i] = if b.vel.Magnitude > 1e-3 then CFrame.lookAt(p, p + b.vel) else CFrame.new(p)
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end
```

The O(n squared) neighbour loop is fine for flocks of 10 to 30; larger flocks need a spatial grid.

## 4. Performance architecture

- **Population by proximity.** Servers spawn huntable and dangerous animals only in regions with players nearby, from spawn regions with caps, and despawn them when no player is within a larger radius for a while (with hysteresis). The world is not "full of deer"; the area around players is.
- **Brain LOD**: animals far from all players tick at 1 to 2 Hz with no pathfinding (straight-line wander within home bounds); near players 5 to 10 Hz ([[NPC AI and Behaviour]] section 7).
- **No Humanoid for small animals.** A Humanoid per rabbit is expensive; use an anchored model moved by CFrame along the ground (raycast for height) or a mover-constraint controller, and play animations through an `AnimationController` with an `Animator` (**Roblox docs**: https://create.roblox.com/docs/reference/engine/classes/AnimationController).
- **Ambient spawns per client** around the camera, capped (for example 20 birds, 10 butterflies), despawned beyond a radius. Respect lower graphics quality levels by spawning fewer ([[Juice on a Budget - Mobile and Low-End]]).
- **Streaming**: server animals in non-streamed regions are not on the client, which is fine; avoid client scripts that assume a specific animal exists ([[Instance Streaming]]).

## 5. Hunting and loot (huntable tier)

- Damage, death and loot are server-validated like enemy kills ([[Combat Systems Architecture]]); the kill payload carries the animal type for quests and journals.
- Flee speed must allow ranged hunting and occasional melee catch-ups; a deer faster than any player at all times is not huntable without a bow.
- Respawn by region timers, not at the death spot, so camping a spot is not optimal.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Server-owned birds and butterflies | Bandwidth and server cost for decoration | Client-only ambient tier |
| Humanoid per small animal | Server frame cost explodes | CFrame movers and AnimationController |
| Whole map populated at all times | Wasted brains | Spawn by player proximity with caps |
| Instant flee or attack | No counterplay, feels random | Alert state with a tell |
| Packs chase forever | Players dragged across the world | Territory leash |
| Each herd member flees independently | Robotic herds | Contagious fear with random delays |

## Checklist
- [ ] Every creature assigned a tier; only gameplay-relevant ones are server-owned.
- [ ] Temperament data with alert tells and perception per species.
- [ ] Herd leader, contagious fear, pack tokens and territory leash.
- [ ] Ambient flocks client-side with BulkMoveTo and caps per quality level.
- [ ] Proximity spawning, brain LOD and no Humanoids for small animals.

## See also
[[NPC AI and Behaviour]] · [[Creature Rig Conventions]] · [[Genre Playbook - Survival and Crafting]] · [[Flight Flocks and Path Animation]] · [[Enemy and NPC Animation]] · [[Mover Constraints and Physics Controllers]]

## Connected notes
<!-- auto-links:start -->
[[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]] · [[Spawn Director - Credit Budgets and Player-Count Scaling]] · [[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Visual AI Debugging - State Labels, Path Lines and Perception Gizmos]] · [[Pathfinding Edge Cases and Fallbacks]] · [[AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses]] · [[Pathfinding]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]] · [[Spawning Teams and Rounds]]
<!-- related:end -->
