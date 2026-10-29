---
tags: [game-design, genre, zombies, wave-survival, co-op, director, scaling, revive, barricades, npc-performance, type/guide, area/design]
---
# Genre Playbook - Zombie and Wave Survival Co-op

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Linear scaling with players. Four-player games become trivial or impossible.
> - Avoid: All enemies spawned at once. Frame spikes and unfair deaths.
> - Avoid: Instant death with long respawns. Players leave.
> - Director with credit budget, enemy table, special waves and trickle release.
> - Sublinear party scaling; global alive cap.
> - Downed, revive, bleed-out, spectate.
>
> Cost: TL;DR ~140 tok · whole note ~1.8k tok. Read more: ## 2. The wave director · ## 7. Enemy count: the technical risk · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Wave survival is a co-op loop: a group holds a space against escalating waves, spends what they earn between waves, and tries to beat their best round. On Roblox it shares DNA with tower defense (many enemies, one server) and with shooters (weapons, hit validation), and its hard problems are the same: enemy count and fair scaling to party size. This playbook covers the wave director, scaling, revives, barricades, the between-wave shop, and the technical patterns that keep 60+ zombies affordable.

Labels: **Roblox docs**, **Rule of thumb**, **Unverified**.

## 1. Loops

| Loop | Length | Content |
|---|---|---|
| Fight | 5 to 30 s | Shoot, reposition, revive |
| Wave | 45 s to 3 min | Spawn budget released and cleared |
| Intermission | 15 to 30 s | Shop, repair, regroup |
| Match | 15 to 45 min | Until wipe or a final wave |
| Meta | Weeks | Unlocks, weapon levels, cosmetics, maps |

The core tension: **spend now to survive versus save for something better later**. The intermission shop is where the strategy lives.

## 2. The wave director

Do not hand-author 50 waves. Give the director a **credit budget** per wave and let it buy enemies from a table.

```lua
--!strict
type EnemyDef = { id: string, cost: number, minWave: number, weight: number }
local ENEMIES: {EnemyDef} = {
	{ id = "Walker", cost = 1, minWave = 1, weight = 10 },
	{ id = "Runner", cost = 2, minWave = 3, weight = 5 },
	{ id = "Brute", cost = 6, minWave = 6, weight = 2 },
	{ id = "Spitter", cost = 4, minWave = 8, weight = 3 },
}

local function budgetFor(wave: number, players: number): number
	local base = 8 + wave * 4 + wave ^ 1.35
	local partyScale = 1 + 0.6 * (players - 1) -- less than linear
	return math.floor(base * partyScale)
end

local function buildWave(wave: number, players: number, rng: Random): {string}
	local budget = budgetFor(wave, players)
	local list = {}
	while budget > 0 do
		local pool, total = {}, 0
		for _, e in ENEMIES do
			if e.minWave <= wave and e.cost <= budget then
				table.insert(pool, e); total += e.weight
			end
		end
		if #pool == 0 then break end
		local pick, r = pool[1], rng:NextNumber(0, total)
		for _, e in pool do
			r -= e.weight
			if r <= 0 then pick = e; break end
		end
		table.insert(list, pick.id)
		budget -= pick.cost
	end
	return list
end
```

Coefficients are illustrative; tune them in a spreadsheet ([[Balancing with Spreadsheets and Data]]). Add **special waves** (every 5th: a boss or a single enemy type) and **release pacing**: spawn the wave in trickles from multiple spawn points, not all at once, and cap the number alive at a time.

## 3. Scaling to party size

- Scale the **budget sublinearly** with players (four players are more than four times as effective together because of revives and focus fire).
- Scale **alive cap** with players too, but keep a hard global cap for performance.
- **Health scaling** per player count is a second lever; prefer more enemies over sponges, which feel bad.
- **Late joiners** start with a catch-up loadout and some currency so they are useful immediately.
- Solo must be viable: a solo player with good play should reach mid waves.

## 4. Down, revive and wipe

- **Downed state** instead of instant death: the player crawls slowly, can be revived by a teammate holding a prompt for 3 to 5 s (rule of thumb), and bleeds out after a timer.
- **Revive is the social glue.** Make it visible: an outline through walls for teammates, a ping on the map.
- **Self-revive** item purchasable with soft currency in the shop; a Robux self-revive is common but should be capped and never prompt mid-fight ([[Ethical Design and Player Trust]]).
- Dead players **spectate** and respawn at the next intermission, not after a long wait.

## 5. Barricades and map control

- Windows and doors with barricade health that enemies attack and players repair for currency. Repairs give non-shooters something useful to do.
- **Doors that cost money** to open expand the map and create the save-or-spend decision.
- Choke points and flanking routes; enemies should not all arrive through one hole.

## 6. The between-wave shop

- Weapons by tier, ammo, armour, barricade upgrades, a random weapon box (soft currency only, or odds disclosed and `PolicyService`-gated if any Robux path reaches it; see [[Paid Random Items and Odds Disclosure in Practice]]).
- **Shared versus personal money**: personal by default, with a "give" option between teammates.
- Prices scale with wave so late-game decisions stay meaningful.

## 7. Enemy count: the technical risk

Humanoid zombies at scale cost physics, replication and pathfinding time. Patterns:

- **Server-simulated, client-rendered enemies**: the server moves lightweight records (position, health, state) and clients render models, as in TD ([[Tower Defense Waves and Placement End to End]]). The server still owns damage and hit validation.
- If you keep `Humanoid`s, disable unneeded states, avoid per-zombie `PathfindingService` every frame, and share flow fields or waypoint graphs across enemies ([[Pathfinding Edge Cases and Fallbacks]]).
- **Global alive cap** (rule of thumb: dozens, not hundreds, for Humanoid enemies) and a death pooling system.
- Measure server heartbeat and memory at the alive cap with a full server before launch ([[MicroProfiler Guide]]).

## 8. Monetisation that fits

- Cosmetics (weapon skins, character skins, kill effects).
- Starting loadout passes that help early waves but not the late game.
- Maps and modes as free updates; private servers for groups.

## Common mistakes

- **Linear scaling with players.** Four-player games become trivial or impossible.
- **All enemies spawned at once.** Frame spikes and unfair deaths.
- **Instant death with long respawns.** Players leave.
- **Unlimited Robux revives** with mid-fight prompts.
- **Per-zombie pathfinding every frame.**
- **No late-join catch-up.**

## Checklist

- [ ] Director with credit budget, enemy table, special waves and trickle release.
- [ ] Sublinear party scaling; global alive cap.
- [ ] Downed, revive, bleed-out, spectate.
- [ ] Barricades and paid doors create choices.
- [ ] Shop prices scale; random box compliant.
- [ ] Enemy simulation measured at cap with a full server.
- [ ] Solo viable; late joiners useful.

## See also

- [[Genre Playbook - Tower Defense]]
- [[Genre Playbook - Shooters FPS and TPS]]
- [[Genre Playbook - Survival and Crafting]]
- [[Tower Defense Waves and Placement End to End]]
- [[Boss Fight Design Patterns]]

## Connected notes

[[Case Study - 99 Nights in the Forest]] · Case Study - Dead Rails · Weekend Build - Arena Shooter with Server-Checked Hits · [[Social Design and Multiplayer Play]]

<!-- related:start -->
## Related
[[Spawn Director - Credit Budgets and Player-Count Scaling]] · [[Genre Playbook - Battle Royale]] · [[Genre Playbook - Horror and Story]] · [[Genre Playbook - Party and Minigame Collections]] · [[Genre Playbook - Social Deduction and Murder Mystery]] · [[Genre Playbook - Tycoons]] · [[Genre Playbook - Naval and Open-Sea Adventure]] · [[Genre Playbook - RNG and Collection Games]] · [[Simulator and RNG Genre Teardown]]
<!-- related:end -->
