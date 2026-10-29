---
tags: [gameplay, ai, squad, attack-tokens, flanking, coordination, npc, type/guide, area/gameplay, level/advanced, server-authority, api/Model]
---
# Squad AI - Attack Tokens, Flanking and Attacker Limits

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Flat token count -> Weighted costs and priority
> - Avoid: Stealing after the telegraph -> Steal only uncommitted holders
> - Avoid: Leaked tokens -> Release on every exit path, plus sweep
> - Token budget per target with costs per attack type and context modifiers.
> - Priority includes wait time; stealing limited to uncommitted holders.
> - Coordinator assigns pinner, flanker, suppressor and waiter roles with hysteresis.
>
> Cost: TL;DR ~150 tok · whole note ~2.2k tok. Read more: ## 1. Tokens with weight, priority and stealing · ## 2. Roles · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[NPC AI and Behaviour]] introduces attack tokens (two attackers per target) and ring slots. That is enough for melee mobs. Once enemies have roles (a shooter, a flanker, a shield) and fight in groups against several players, a flat token count produces new problems: the far-away archer hogs a token while the brute next to the player waits; every flanker picks the same side; a squad of five behaves like five individuals. This note adds a **squad coordinator**: weighted tokens with priority and stealing, role assignment, flank side selection and attacker limits that scale with the target. All of it runs on the server at brain tick rate.

Source labels: **Rule of thumb** (game AI practice; there is no Roblox API for this), **Roblox docs** where engine calls are used.

---

## 1. Tokens with weight, priority and stealing

Each target (player) has a token **budget**, not a count. Each attack type has a **cost**:

| Attack | Cost | Notes |
|---|---|---|
| Light melee | 1 | |
| Heavy melee / grab | 2 | Grabs should usually be exclusive: 1 per target ([[Grabs, Carries and Throws - Moving Players Safely]]) |
| Ranged shot | 0.5 | Cheap, but cap shooters separately |
| Special / AoE | 2 to 3 | Telegraphed |

Budget per target: base 2 to 3, plus modifiers. Lower it when the target is low health, downed, new (onboarding), or already under several status effects; raise it slightly for players far above the zone's level. This is how you make a fight harder without making it unfair.

**Priority** decides who gets a token when several want one:
`priority = proximity + visibility + roleBonus + waitTime`. Wait time matters: an enemy that has been denied for 4 s should eventually win, or it looks broken.

**Stealing**: a higher-priority requester can revoke a token from a holder that has **not yet committed** (still winding up before the telegraph). Never steal after the telegraph has started; cancelling an attack the player is already reacting to feels like a bug.

```lua
--!strict
type Holder = { npc: Model, cost: number, priority: number, committed: boolean }
type Pool = { budget: number, holders: { Holder } }

local Squad = {}
local pools: { [Player]: Pool } = {}

local function used(pool: Pool): number
	local n = 0
	for _, h in pool.holders do n += h.cost end
	return n
end

function Squad.request(target: Player, npc: Model, cost: number, priority: number, budget: number): boolean
	local pool = pools[target]
	if not pool then
		pool = { budget = budget, holders = {} }
		pools[target] = pool
	end
	pool.budget = budget
	if used(pool) + cost <= pool.budget then
		table.insert(pool.holders, { npc = npc, cost = cost, priority = priority, committed = false })
		return true
	end
	-- try to steal from the lowest-priority uncommitted holder
	local victimIndex, victimPriority = nil :: number?, priority
	for i, h in pool.holders do
		if not h.committed and h.priority < victimPriority and used(pool) - h.cost + cost <= pool.budget then
			victimIndex, victimPriority = i, h.priority
		end
	end
	if victimIndex then
		local victim = table.remove(pool.holders, victimIndex) :: Holder
		victim.npc:SetAttribute("TokenRevoked", true) -- its brain backs off next tick
		table.insert(pool.holders, { npc = npc, cost = cost, priority = priority, committed = false })
		return true
	end
	return false
end

function Squad.commit(target: Player, npc: Model)
	local pool = pools[target]
	if not pool then return end
	for _, h in pool.holders do
		if h.npc == npc then h.committed = true end
	end
end

function Squad.release(target: Player, npc: Model)
	local pool = pools[target]
	if not pool then return end
	for i = #pool.holders, 1, -1 do
		if pool.holders[i].npc == npc then table.remove(pool.holders, i) end
	end
end

return Squad
```

Release on every exit path: attack ended, interrupted, NPC died or despawned (hook `Destroying`), target died or left (clear the pool on `PlayerRemoving`). A periodic sweep that drops holders whose NPC is no longer in the workspace catches the rest.

## 2. Roles

A squad coordinator (one per encounter or group, server-side) assigns roles every 1 to 2 s, not every tick:

| Role | Behaviour | Count |
|---|---|---|
| **Pinner** | Engages from the front, holds the target's attention | 1 to 2 |
| **Flanker** | Moves to the target's side or rear, attacks when the pinner has engaged | 1 |
| **Suppressor** | Ranged; fires to restrict movement more than to hit (wider spread, cheaper token) | 1 to 2 |
| **Waiter** | No token; circles at mid range, taunts, repositions | The rest |

Assign by suitability score (archetype, distance, health) with **hysteresis**: keep the current role unless another candidate is clearly better (for example 25% higher score). Role churn every tick looks like indecision.

Waiters are the secret of readable group fights: visibly present and threatening, not attacking. Give them animation (shield bash taunts, pacing) so the player reads "they are queueing".

## 3. Flanking without dog-piling

- Compute the target's facing (character look vector, flattened). For each candidate flank point, score by angle from the facing (sides and rear score higher), distance to reach, line of sight from the point, and **occupancy** (penalty if another squad member is already within some degrees of that bearing).
- Prefer the side the target is not moving toward; flanking into the player's path is just a frontal attack.
- **Telegraph from the flank.** An attack from outside the camera must be audible or visible: a bark, a footstep cue, an indicator. Unseen hits from behind are the top complaint in group combat ([[Combat Sound Design and Feedback]]).
- Re-evaluate flank points slowly (every 1 to 2 s) and only switch when the old point becomes invalid.

## 4. Limits that scale with the fight

- **Per-target attacker cap** is the token budget; **per-encounter cap** limits total attacking NPCs (for example 4 to 6) so eight-player lobbies do not get 24 simultaneous attacks.
- **Ranged cap per target** (2 is a good start) independent of the token budget, or chip damage from cheap shots stacks unseen.
- **Focus fairness**: when several players are present, spread pinners across players by threat (damage dealt recently) with a decay, not purely by distance, so the closest player is not always the only one fought.

## 5. Communication and barks

Squads feel smart when they *say* what they do: "flanking", "reloading", "cover me". Barks are cosmetic: server picks a bark id when a role or state changes, sends it unreliably to nearby clients, with a global cooldown (one bark per squad per 2 to 3 s) ([[Captions and Audio Accessibility]] for captions).

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Flat token count | Far archer blocks the adjacent brute | Weighted costs and priority |
| Stealing after the telegraph | Attacks vanish mid-swing | Steal only uncommitted holders |
| Leaked tokens | Squad goes passive | Release on every exit path, plus sweep |
| Roles recomputed every tick | Jittery, indecisive squads | 1 to 2 s cadence with hysteresis |
| All flankers pick the same side | Accidental dog-pile | Occupancy penalty per bearing |
| Unsignalled rear attacks | "Cheap" deaths | Barks and audio tells from flankers |

## Checklist
- [ ] Token budget per target with costs per attack type and context modifiers.
- [ ] Priority includes wait time; stealing limited to uncommitted holders.
- [ ] Coordinator assigns pinner, flanker, suppressor and waiter roles with hysteresis.
- [ ] Flank points scored by angle, reachability, LOS and occupancy.
- [ ] Per-encounter and ranged caps in live config.
- [ ] Token state visible in the debug overlay ([[Visual AI Debugging - State Labels, Path Lines and Perception Gizmos]]).

## See also
[[NPC AI and Behaviour]] · [[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[Enemy Archetype Kit - Fodder, Tank, Ranged, Support and Exploder]] · [[Combat Arena and Encounter Layout]] · [[Dot and Cross Products in Gameplay]]

## Connected notes
<!-- auto-links:start -->
[[Spawn Director - Credit Budgets and Player-Count Scaling]] · [[Melee Combat System End to End]] · [[Combat Systems Architecture]] · [[AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Wildlife and Ambient Creature AI - Passive, Neutral and Hostile]] · [[Hitboxes and Hit Detection]] · [[Pathfinding Edge Cases and Fallbacks]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]] · [[Pathfinding]] · [[Explosions - Radius Damage, Falloff and Cover Checks]] · [[Police Chases and Wanted Levels]] · [[Status Effects Buffs and Stacking Rules]]
<!-- related:end -->
