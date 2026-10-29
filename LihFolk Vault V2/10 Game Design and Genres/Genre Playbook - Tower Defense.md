---
tags: [game-design, genre, tower-defense, waves, co-op, units, economy, performance, type/guide, area/design, level/intermediate, api/Humanoid]
---
# Genre Playbook - Tower Defense

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Humanoid NPC enemies -> Data-driven enemies, client-rendered
> - Avoid: One remote per enemy per frame -> Batched spawn/death events plus unreliable corrections
> - Avoid: Scaling enemy *count* with players -> Scale *health*; keep count flat
> - Match loop playable start to finish on a phone, with touch placement that is precise (snap, preview, confirm).
> - Worst wave of the hardest mode measured: server frame time, bandwidth per player, client memory on a low-end device.
> - Placement remote validates loadout, cash, caps, bounds, footprint and surface; fuzzed with bad inputs.
>
> Cost: TL;DR ~190 tok · whole note ~4.9k tok. Read more: ## 3. Systems you must build · ## 5. The technical risk: enemy count · ## 8. Common mistakes · ## 9. Launch checklist
<!-- tldr:end -->

Tower defense (TD) on Roblox means a team of one to four players placing units ("towers") beside a fixed path while waves of enemies walk it toward a base. It sits between a strategy game and a collection game: the match is a puzzle about placement and money, and the meta-game around it is usually a unit roster you pull, upgrade and evolve. That combination gives TD some of the longest sessions on the platform and some of the hardest technical problems, because a late wave can put hundreds of moving enemies and dozens of firing towers into one server at once.

This playbook covers the two loops, match and session length, monetisation that fits, the systems you must build, the Roblox-specific technical risks (above all, enemy count), the patterns successful TD games share, and a launch checklist. It goes deeper than the general notes on [[Core Loops and Session Design]] and [[Genre Playbook - RNG and Collection Games]].

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production combat RNG game; used only where its lessons transfer), **Rule of thumb** (common practice, not measured here).

---

## 1. The two loops

| Loop | Length | Verb | What changes |
|---|---|---|---|
| Match loop | 15 to 40 min | Place, upgrade, sell, use abilities | Money in the match, wave number, base health |
| Meta loop | Days to months | Summon, upgrade, evolve, equip a loadout | Permanent roster, account level, currencies |

**Match loop, second by second:** a wave spawns, enemies walk, towers fire, kills pay cash, the player spends cash on new towers or upgrades, the next wave arrives. The decisions are *where* (coverage of the path, choke points, range overlap), *what* (damage type against the enemy mix) and *when* (save for a big upgrade or spend now).

**Meta loop:** match rewards (gems, unit shards, XP) feed a summon banner and upgrades. Better units let the player beat harder maps and modes, which pay more. This is the same engine described in [[Genre Playbook - RNG and Collection Games]], with one important difference: the match is a real skill test, so a weak roster can be compensated by good placement, and a strong roster can still lose to bad placement. That is why TD retains strategy players that pure RNG games lose.

### The core tension
Every TD match is a running answer to one question: **does my damage per second along the path keep up with the incoming health per second?** Write it as

```
required path DPS = (sum of enemy health in the wave) / (time the wave spends inside your coverage)
```

Everything you design (enemy speed, health, shields, tower range, upgrade cost) moves one side of that equation. If you keep a sheet of "incoming health per second" by wave and "achievable DPS per cash spent" by tower, you can predict which wave a given loadout fails on before any playtest. See [[Balancing with Spreadsheets and Data]].

---

## 2. Session and match length

| Mode | Target length (rule of thumb) | Why |
|---|---|---|
| Story / campaign map | 10 to 20 min | Fits a phone session; a clear win or loss |
| Endless / infinite | 30 to 90 min | Tryhard mode; leaderboard fodder |
| Challenge (daily rotating rules) | 8 to 15 min | Daily return hook |
| Raid / boss mode | 15 to 25 min | Social, high reward |

Rules that follow from these numbers:
- **Speed-up is not optional.** A 2x (and often 3x) speed toggle lets veterans finish early waves in a fraction of the time. Players resent sitting through wave 1 on their fiftieth replay of a map. Implement speed as a simulation time scale on the server, never by speeding up animations only.
- **Mid-match leaving must be safe.** Phones get interrupted. Pay partial rewards per wave cleared, so a player who leaves at wave 18 of 25 is not punished with nothing. A player who gets nothing after 15 minutes does not come back.
- **The lobby is part of the session.** Queuing, loadout edits, summoning and trading happen in the lobby place. Budget about a third of session time there and make it a social hub, not a menu screen. See [[Social Design and Multiplayer Play]].

---

## 3. Systems you must build

| System | Server or client | Notes |
|---|---|---|
| Lobby and matchmaking | Server, multi-place | Party queue pads, then `TeleportService` to a reserved match server |
| Map and path data | Shared data | Path as a list of waypoints plus cumulative distances |
| Wave director | Server | Spawn tables per wave, scaling by difficulty and player count |
| Enemy simulation | Server (data), client (visuals) | The hard part; see section 5 |
| Placement | Client preview, server validation | Grid or free placement, footprint checks, path exclusion |
| Targeting | Server | First, last, strongest, closest; per tower |
| Upgrades and selling | Server | Upgrade paths, sell refund (often 50 to 80% of spent) |
| Match economy | Server | Cash per kill, per wave, shared or per player |
| Abilities | Server, cooldown | Active tower skills, global player skills |
| Roster (meta) | Server + DataStore | Units owned, levels, equipped loadout |
| Summon banner | Server | Odds, pity, disclosure; see [[Paid Random Items and Odds Disclosure in Practice]] |
| Trading | Server | Optional but common; see [[Trading Systems Without Duplication]] |
| Results and rewards | Server | Per wave cleared, first-clear bonus |

Two architecture rules save weeks:
1. **Lobby and match are different places in one universe.** The lobby holds 20 to 50 players for social pressure; matches are small reserved servers with only the party. See [[Teleporting and Multi-Place Games]].
2. **Unit definitions live in one data module** read by the lobby UI, the match server and the balance sheet. A unit that shows 120 damage in the inventory and does 100 in the match destroys trust. See [[Data and Config Pipeline - Spreadsheets to Game]].

### Placement validation
Placement is the most-hit remote in a TD game and a common exploit target (placing towers on the path, inside walls, off the map, or for free). The server must check, in this order: the player is in a match and alive; the unit is in their equipped loadout; they have the cash; the per-player and per-unit placement caps are not exceeded; the position is inside the map bounds; the footprint does not overlap the path or another tower; the ground under it is a "placeable" surface (tag it). Only then deduct cash and spawn. Never accept a tower id or a cost from the client. See [[Server Authority and Validation]] and [[Grid Placement and Player Building Systems]].

---

## 4. Wave and enemy design

### Wave composition
| Enemy archetype | Tests |
|---|---|
| Normal | Baseline DPS |
| Fast, low health | Coverage near the start of the path, reaction |
| Tank, high health | Concentrated DPS, single-target towers |
| Swarm (many weak) | Splash damage |
| Shielded / armoured | Damage types, armour-piercing towers |
| Hidden / stealth | Detection towers (a classic TD check) |
| Flying (if the game has it) | Anti-air units |
| Boss | Everything at once, plus abilities that stun or disable towers |

Introduce each archetype alone before combining it, the same "teach, test, twist" rhythm used in [[Genre Playbook - Obbies and Platformers]]. A stealth enemy that first appears on wave 12 mixed with a tank and a swarm kills new players for reasons they cannot see.

### Scaling
- Health grows faster than linear across waves (for example 8 to 15% per wave in a campaign), while cash per wave grows slower. That squeeze is what forces good placement and upgrades. Rule of thumb, tune in your sheet.
- **Scale with player count.** Four players with four loadouts have four times the placement cap. Increase enemy health (not count) by roughly 60 to 80% per extra player, so the server load stays flat while the challenge holds. Scaling count instead multiplies the performance problem in section 5.
- **Boss waves telegraph.** A banner, a sound and a health bar at the top of the screen. Bosses that stun towers should show which towers are stunned and for how long.

### Readability
Enemy type must read at a glance on a phone at a distance: distinct silhouettes and colours per archetype, a small health bar only on damaged enemies, and an icon for stealth or shield. Damage numbers above hundreds of enemies are noise; aggregate them or show them only for the selected tower.

---

## 5. The technical risk: enemy count

This is where TD games live or die on Roblox. A late wave may have 150 to 400 enemies alive. If each enemy is a Humanoid character model moved by `Humanoid:MoveTo`, the server pays for physics, humanoid state machines and replication of every part's position, and players on phones see enemies stutter and teleport.

### What goes wrong with "real" NPCs
| Approach | Cost | Failure mode |
|---|---|---|
| Humanoid NPCs with `MoveTo` | Humanoid simulation plus physics per enemy | Server frame time climbs past budget around 100 to 200 enemies (rule of thumb; measure yours); enemies bunch up and collide |
| Anchored models moved by `PivotTo` each frame on the server | Replication of every CFrame change | Bandwidth spikes; client sees choppy 20-ish updates per second |
| Unanchored parts with physics movers | Physics plus ownership questions | Enemies get pushed, fall off, or are owned by a client |

### The data-driven pattern
Treat enemies as **numbers, not instances**, on the server:
- The path is a polyline of waypoints with precomputed cumulative distance.
- Each enemy is a small record: id, type, spawn time, speed, health, status effects.
- Its position is a pure function: distance travelled = speed x (now - spawn time, adjusted for slows and stuns), then a lookup along the path.
- The server uses those computed positions for targeting and range checks. No physics, no parts.
- Clients receive only events: "enemy 412 of type Brute spawned at server time T", "enemy 412 slowed 30% from T1 to T2", "enemy 412 died". Each client computes the same positions locally from the shared path and `workspace:GetServerTimeNow()`, and renders a model (pooled) at that position.

Bandwidth becomes proportional to *events*, not to *enemies x frames*. Visual models exist only on clients, so you can use cheaper models on phones.

```lua
--!strict
-- ReplicatedStorage/PathMath (ModuleScript). Shared by server (targeting) and client (rendering).
local PathMath = {}

export type Path = {
	points: { Vector3 },
	cumulative: { number }, -- cumulative[i] = distance from start to points[i]
	length: number,
}

function PathMath.build(points: { Vector3 }): Path
	local cumulative = { 0 }
	for i = 2, #points do
		cumulative[i] = cumulative[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	return { points = points, cumulative = cumulative, length = cumulative[#points] }
end

-- Position at a distance along the path. Binary search keeps it cheap for long paths.
function PathMath.positionAt(path: Path, distance: number): Vector3
	local pts, cum = path.points, path.cumulative
	if distance <= 0 then return pts[1] end
	if distance >= path.length then return pts[#pts] end
	local lo, hi = 1, #pts
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if cum[mid] <= distance then lo = mid else hi = mid end
	end
	local segLen = cum[hi] - cum[lo]
	local alpha = if segLen > 0 then (distance - cum[lo]) / segLen else 0
	return pts[lo]:Lerp(pts[hi], alpha)
end

return PathMath
```

On the server, an enemy's distance is advanced in one `Heartbeat` loop over a plain array, multiplied by the match's time scale (the 2x speed toggle) and by any slow. Each tower checks range against those positions a few times per second, not every frame: towers with a fire rate of 1 per second do not need 60 targeting passes per second. That single change often halves server cost.

### Nuances of the pattern
- **Slows and stuns break the pure formula.** Store `distance` and advance it per tick on the server, and send the client a correction (`id, distance, serverTime`) whenever speed changes. The client then extrapolates from the last correction. Sending a correction every second or two for every enemy is still far cheaper than CFrame replication.
- **Clients will drift slightly.** A client that renders an enemy 0.3 studs from where the server thinks it is never matters, because the server decides hits. Projectile visuals should home onto the client's rendered enemy, not fly to the server's coordinates.
- **Use `UnreliableRemoteEvent` for corrections** and reliable remotes for spawn and death. A lost correction is replaced by the next one; a lost death leaves a ghost enemy walking forever. See [[RemoteEvents RemoteFunctions and Unreliable Remotes]].
- **Batch.** Send one remote per tick with all spawns and deaths in it (a buffer if the volume is high; see [[Buffers and Binary Data]]), not one remote per enemy.
- **Pool client models.** Creating and destroying hundreds of models per wave causes memory churn and hitches. Keep a pool per enemy type. See [[Hunting Memory Leaks Step by Step]].
- **Animate cheaply.** A walk cycle per enemy through `Animator` is fine for dozens; for hundreds, consider fewer bones, simpler rigs, or animation LOD that stops far enemies. See [[Animation LOD]].

Measure with the MicroProfiler and network stats before launch. A good target (rule of thumb): server `Heartbeat` work under 4 ms at the worst wave of your hardest mode, and under 50 KB/s per player of incoming network data. See [[Network Bandwidth Budgets and Measuring Them]] and [[MicroProfiler Guide]].

### Towers have the same problem, smaller
Twenty towers per player x 4 players = 80 towers firing. Keep tower visuals client-side too: the server sends "tower 9 hit enemy 412 for 340"; clients play the muzzle flash, projectile and hit effect. Respect a VFX budget per client and cull effects off-screen. See [[VFX Performance Budgets and Culling]].

---

## 6. Monetisation that fits

| Product | Fit | Notes |
|---|---|---|
| Summon banner currency (developer products) | Core | Odds disclosure and `PolicyService` checks are required for paid random items (Docs; see [[Paid Random Items and Odds Disclosure in Practice]]) |
| Premium battle pass / season pass | Strong | Ties spending to playing; rewards daily play |
| Extra loadout slot, extra equip slots | Strong | Clear value; keep the base game fair without it |
| 2x / 3x speed pass | Common | Consider giving 2x free and selling 3x; time-saving purchases are well tolerated |
| VIP (extra rewards, private lobby perks) | Common | Game pass; see [[Game Passes]] |
| Cosmetic unit skins | Good | No balance impact; shines in a co-op genre where friends see your units |
| Direct-buy limited units | Risky | Pay-to-win perception if they are the best units in the game |

Ethics specific to TD:
- **A purchasable unit should never be required to clear story content.** If the paid unit is the only way past a map, players notice and leave reviews. Use paid units as convenience and expression, and test that every story map is beatable with free units. See [[Ethical Design and Player Trust]].
- **Pity on banners.** Long dry streaks on a premium banner hurt younger players the most. A visible pity counter is both kinder and better for retention. See [[Rarity Ladders and Drop Pacing Math]].
- **Trading and real-money markets.** If units can be traded, they acquire off-platform value, and you will see scams. Roblox's rules apply; build trade confirmations, value warnings and trade logs. See [[Economy Exploits - Dupes Races and Purchase Abuse]].

---

## 7. Patterns successful TD games share

Descriptions of common patterns, not copies of any one game:
- **A licensed-feeling or themed roster** is the main hook: units that look like a recognisable archetype ("the sniper", "the farm", "the support") with strong personality. Never use other people's IP; Roblox removes infringing games. See [[Roblox Policies Ratings and Compliance]].
- **A farm/economy unit** that generates match cash creates the classic early-game choice: invest in economy now or defend now.
- **Unit evolution** (a high-level unit plus materials becomes a stronger form) gives long goals to players who already own everything.
- **Traits or modifiers** rolled on units (a random +damage or +range trait, rerollable for a currency) create an endless sink. Watch the economics: see [[Economy Inflation Sinks and Faucets Math]].
- **Weekly content cadence**: a new map or mode, a banner rotation, a limited unit. TD players consume maps fast.
- **Leaderboards for endless mode**: highest wave reached, with the loadout visible. This doubles as a "how to play" guide for others.
- **Spectator-friendly lobbies**: showing off a rare unit in the lobby is a large part of why players chase them.

---

## 8. Common mistakes

| Mistake | Better |
|---|---|
| Humanoid NPC enemies | Data-driven enemies, client-rendered |
| One remote per enemy per frame | Batched spawn/death events plus unreliable corrections |
| Scaling enemy *count* with players | Scale *health*; keep count flat |
| Targeting every frame for every tower | Target at the tower's fire rate |
| Paid units required for story clears | Story beatable free; test it |
| No speed-up | 2x free, server-side time scale |
| No partial rewards | Pay per wave cleared |
| Tower stats in three places | One unit data module |
| Stealth enemies with no tutorial | Introduce each archetype alone |

## 9. Launch checklist

- [ ] Match loop playable start to finish on a phone, with touch placement that is precise (snap, preview, confirm).
- [ ] Worst wave of the hardest mode measured: server frame time, bandwidth per player, client memory on a low-end device.
- [ ] Placement remote validates loadout, cash, caps, bounds, footprint and surface; fuzzed with bad inputs. See [[Testing Your Own Remotes - Fuzzing and Abuse Tests]].
- [ ] Lobby to match teleport handles failures (retry, return to lobby) and parties stay together. See [[Teleporting and Multi-Place Games]].
- [ ] Every story map cleared with free units only.
- [ ] Banner odds disclosed; `PolicyService` gating in place; pity defined.
- [ ] Partial rewards on leave; results screen shows what was earned and why.
- [ ] Roster saved with session locking; trades atomic if enabled. See [[Session Locking and Profile Libraries]].
- [ ] Analytics: per-map win rate, wave-of-loss histogram, banner pulls per session. See [[Analytics and Funnels]].
- [ ] A content plan for the first four weeks (maps, units, banners).

## See also
- [[Core Loops and Session Design]], [[Progression and Pacing Design]], [[Retention and Return Hooks]]
- [[Genre Playbook - RNG and Collection Games]], [[Simulator and RNG Genre Teardown]], [[Rarity Ladders and Drop Pacing Math]]
- [[Interest Management and Per-Player Replication]], [[Network Performance]], [[Performance Fundamentals]]
- [[Round-Based Minigame Loop End to End]], [[Projectiles and Ballistics]]

## Connected notes
<!-- auto-links:start -->
[[Tower Defense Waves and Placement End to End]] · Genre Systems Start Here · [[Genre Playbook - Combat and RPG]] · [[Genre Playbook - Shooters FPS and TPS]] · Power Curve · Pity Timer
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Genre Playbook - Simulators]] · [[Genre Playbook - Party and Minigame Collections]] · [[Genre Playbook - Puzzle and Escape Rooms]] · [[Genre Playbook - Battle Royale]] · [[Genre Playbook - Tycoons]] · [[Genre Playbook - Survival and Crafting]] · [[Genre Playbook - Battlegrounds and Arena Fighters]]
<!-- related:end -->
