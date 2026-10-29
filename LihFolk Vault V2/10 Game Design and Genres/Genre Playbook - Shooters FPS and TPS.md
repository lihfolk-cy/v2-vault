---
tags: [game-design, genre, shooter, fps, tps, hitscan, netcode, matchmaking, anti-cheat, type/guide, area/design, level/intermediate]
---
# Genre Playbook - Shooters FPS and TPS

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Trusting the client's "I hit X" -> Server validation with capped rewind
> - Avoid: Server-only raycasts at current positions -> Rewind by ping, capped
> - Avoid: Damage computed on the client -> Server computes from weapon data
> - TTK-by-range chart for every weapon; each class owns a range band.
> - Hit validation with rewind, line of sight, fire rate and ammo on the server; abuse-tested.
> - Two-client tests at 50, 150 and 250 ms simulated latency.
>
> Cost: TL;DR ~160 tok · whole note ~4.4k tok. Read more: ## 3. Weapons · ## 4. Hit registration: the core technical decision · ## 10. Common mistakes · ## 11. Launch checklist
<!-- tldr:end -->

Shooters on Roblox range from casual team deathmatch with blocky guns to tactical round-based games with recoil patterns, attachments and ranked play, and from first-person (FPS) to over-the-shoulder third-person (TPS). The genre has a large, loyal, older-skewing audience on Roblox, unusually high expectations (players compare you with console shooters), and the hardest anti-cheat problem on the platform: aimbots and wallhacks run entirely on the client, where you cannot see them.

This playbook covers the loops and modes, session pacing, monetisation that keeps the game fair, the systems you must build (weapons, hit registration, cameras, matchmaking), the Roblox-specific technical risks, the patterns successful shooters share, and a launch checklist.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production combat game; limited relevance to shooters), **Rule of thumb**.

---

## 1. Core loop and modes

| Loop | Length | Content |
|---|---|---|
| Engagement | 1 to 5 s | Spot, aim, shoot, take cover, reload |
| Life | 20 s to 2 min | Move to a position, a few engagements, die or win |
| Match | 5 to 15 min | A mode's objective: score limit, rounds, capture |
| Meta | Weeks | Weapon levels, unlocks, attachments, camos, rank |

### Modes and what they demand
| Mode | Pacing | Map need | Notes |
|---|---|---|---|
| Team deathmatch | Fast, constant respawn | Mid-size, three lanes | Best default mode; easy to understand |
| Free-for-all | Fast | Small to mid | Popular with solo players; harder for newcomers |
| Domination / capture points | Medium | Points with clear sightlines | Rewards teamwork without voice |
| Search and destroy / round-based | Slow, one life per round | Tight, deliberate | Tactical audience; needs good spectate |
| Battle royale | Slow then intense | Very large | Streaming, loot and zone systems; high cost |
| Gun game / arms race | Fast | Small | Weapon-rotation novelty; great for clips |
| Zombies / PvE waves | Medium | Arena | Co-op shooter; shares the enemy-count problem described in [[Genre Playbook - Tower Defense]] |

Start with one mode done extremely well. A tight team deathmatch with three good maps outperforms five half-built modes.

---

## 2. Session and match pacing

- **Time to first shot under 30 seconds from joining** (rule of thumb). Shooter players want action; a long loadout screen before the first spawn bleeds them. Spawn first with a default loadout, customise between lives.
- **Time to kill (TTK) defines the game's identity.** Fast TTK (0.2 to 0.4 s for a rifle at close range) rewards first-shot aim and positioning; slow TTK (0.8 to 1.5 s) rewards tracking and makes fights reversible. Fast TTK hides latency for the shooter and punishes it for the target ("I died before I saw him"). Decide this first; every weapon number follows.
- **Match length 8 to 12 min** for objective modes; between matches, a 15 to 30 s scoreboard and map vote. Keep players in the same server between matches, with teams rebalanced.
- **Join in progress** for casual modes; players who join mid-match land on the team with fewer players.

---

## 3. Weapons

### Weapon data
Every weapon is a row: damage (head, body, limb multipliers), fire rate, magazine, reload time, range falloff (start and end distance, minimum damage), spread (hip and aim), recoil pattern, movement speed while equipped, aim-down-sights time. Keep it in one data module shared by the client (for prediction and UI) and the server (authority). See [[Data and Config Pipeline - Spreadsheets to Game]].

```
TTK (s)       = (shots to kill - 1) / (fire rate in shots per second)
shots to kill = ceil(target health / damage at that range)
```

Plot TTK against range for every weapon in your sheet. A weapon that wins at every range is broken; each class should own a range band (SMG close, rifle mid, sniper long). See [[Balancing with Spreadsheets and Data]].

### Hitscan versus projectile
| Model | Use for | Cost |
|---|---|---|
| Hitscan (instant ray) | Most rifles, pistols, SMGs | One raycast per shot; simplest netcode |
| Projectile (simulated bullet with drop and travel time) | Snipers, launchers, bows | Simulate on server and client; see [[Projectiles and Ballistics]] |
| Hybrid (hitscan up to a range, projectile beyond) | Realistic long-range weapons | More complex, cheap overall |

Hitscan is easier to validate; projectiles reward skill at range but make lag more visible.

### Recoil and spread
- **Recoil** (where the view kicks) should be learnable: a fixed or semi-fixed pattern rewards practice. Pure random recoil feels unfair.
- **Spread** (random cone around the aim) should be small when aiming and grow with movement and sustained fire. Either derive spread from a seed the server can reproduce, or have the server accept the client's ray direction only within the weapon's maximum spread cone.

---

## 4. Hit registration: the core technical decision

Players judge a shooter by whether shots that look like hits count. On Roblox, a client sees other players slightly in the past (their positions arrive after network delay and are interpolated), so a crosshair on an enemy is on where that enemy *was*.

| Approach | Shooter's experience | Target's experience | Exploit risk |
|---|---|---|---|
| Server raycast at current server positions | Misses moving targets on high ping | Fair | Low |
| Client-authoritative hits ("I hit X in the head") | Perfect | Gets hit behind cover | Very high: silent aim fakes hits trivially |
| Client-reported hits, server validated with rewind | Very good | Occasionally hit "around corners" | Moderate, controlled |

The common professional choice is the third: the client sends the shot origin, direction, the claimed target and its timestamp; the server rewinds the target to that time (using a position history buffer like the one in [[Genre Playbook - Battlegrounds and Arena Fighters]]) and checks.

```lua
--!strict
-- Server: validate a reported hitscan hit. positionAt(player, t) comes from a rewind buffer.
local MAX_REWIND = 0.25   -- seconds; beyond this, no extra compensation
local HIT_TOLERANCE = 4   -- studs around the rewound root (character size plus slack)
local ORIGIN_SLACK = 8    -- studs between reported muzzle and real root

export type Shot = { origin: Vector3, direction: Vector3, target: Player, clientTime: number }

local function isFiniteVector(v: Vector3): boolean
	return v == v and v.Magnitude < math.huge and v.Magnitude > 0 -- v ~= v catches NaN
end

local function validateShot(
	shooter: Player,
	shot: Shot,
	weaponRange: number,
	positionAt: (Player, number) -> Vector3?
): boolean
	if not isFiniteVector(shot.direction) or shot.origin ~= shot.origin then return false end
	local character = shooter.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then return false end

	-- 1. Origin must be near the shooter's real position (no shooting from elsewhere).
	if (shot.origin - root.Position).Magnitude > ORIGIN_SLACK then return false end

	-- 2. Clamp the rewind time to a window the server accepts.
	local now = workspace:GetServerTimeNow()
	local t = math.clamp(shot.clientTime, now - MAX_REWIND, now)
	local targetPos = positionAt(shot.target, t)
	if not targetPos then return false end

	-- 3. Range and direction: the ray must pass close to the rewound target.
	local toTarget = targetPos - shot.origin
	if toTarget.Magnitude > weaponRange then return false end
	local dir = shot.direction.Unit
	local along = toTarget:Dot(dir)
	if along <= 0 then return false end
	local closest = shot.origin + dir * along
	if (closest - targetPos).Magnitude > HIT_TOLERANCE then return false end

	-- 4. Line of sight against the current world (walls do not move, so no rewind needed).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { character }
	if shot.target.Character then table.insert(ignore, shot.target.Character) end
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(shot.origin, dir * along, params) == nil
end

return validateShot
```

Combine with cadence checks: shots per second must not exceed the weapon's fire rate (with a small tolerance), ammo is tracked on the server, and reloads take server time. A client that reports 40 shots per second from a weapon that fires 10 is lying. Never let the client name the damage; the server computes it from the weapon row, the hit part and the range.

Nuances:
- **Headshots** need their own check: rewind the head position, or accept a body hit and decide the multiplier with a tighter tolerance. Generous headshot tolerance is the easiest thing for silent-aim cheats to exploit.
- **Moving platforms and vehicles** break simple rewind (the target moved with the platform). Store positions relative to the platform, or accept looser checks there.
- **Shotguns** send many pellets; validate one packet per trigger pull with pellet count capped, not one remote per pellet.
- See [[Raycasts Shapecasts and Spatial Queries]], [[Detecting Combat Exploits - Reach Rate and Aim]] and [[Server Authority and Validation]].

### Aimbots and wallhacks
You cannot see the client's memory. What you can do:
- **Limit what wallhacks reveal** with interest management: do not replicate enemy positions a player cannot plausibly see or hear. Characters replicate by default, so this is expensive, but streaming and custom character replication help in large maps. See [[Interest Management and Per-Player Replication]].
- **Statistical detection** of aimbots: headshot ratio, time from target visible to first hit, angular snap speed of the reported aim. Flag outliers for review; never auto-ban on one stat. See [[False Positives Lag and Fair Enforcement]] and [[Logging Bans and Appeals]].
- **Server-checked line of sight** stops "shoot through walls" cheats.
- Accept that some cheating will happen; invest in reports and fast review. See [[How Exploits Work - The Client Boundary]].

---

## 5. Cameras, movement and feel

- **First person:** a viewmodel (arms and gun rendered close to the camera) with sway, bob and aim-down-sights zoom through a field-of-view change. The viewmodel exists only on the local client; others see the third-person character, whose aim should be driven by a replicated look direction. See [[Camera Systems]], [[Look-At Aim and Head Tracking]] and [[Procedural Weapon Motion]].
- **Third person:** over-the-shoulder camera with a shoulder swap. Raycast from the camera to find the aim point, then fire from the muzzle to that point, so players hit what the crosshair shows. Without this, players behind cover shoot the wall in front of the muzzle while the crosshair shows a clear shot.
- **Movement:** sprint, crouch, slide, and sometimes lean or vault. Each changes the hitbox and spread. Keep the count small on mobile.
- **Feedback:** hitmarkers (distinct for headshots and kills), damage direction indicators, kill sounds, recoil kick, muzzle flash. See [[Game Feel and Juice]] and [[Combat Sound Design and Feedback]].
- **Mobile:** a fire button, an aim button, optional auto-fire (fires when the crosshair rests on an enemy), and aim assist (slow-down near targets). Touch players against mouse players is the genre's hardest fairness problem; custom matchmaking signals by input type are one answer. See [[Input - UserInputService and ContextActionService]].

---

## 6. Systems you must build

| System | Notes |
|---|---|
| Weapon framework | Data rows, client prediction, server authority, ammo |
| Hit registration | Section 4 |
| Camera and viewmodel | First or third person, ADS |
| Teams and spawns | Spawn away from enemies; see [[Spawning Teams and Rounds]] |
| Match flow | Lobby, match, scoreboard, map vote; see [[Round-Based Minigame Loop End to End]] |
| Loadouts and unlocks | Weapon levels, attachments, perks |
| Matchmaking | Roblox lets creators weight built-in matchmaking signals and add custom ones (Docs, "Customize your matchmaking configuration") |
| Kill feed, scoreboard, killcam (optional) | Killcams need recorded positions of every player for the last few seconds |
| Anti-cheat and reports | Section 4 and [[Anti-Exploit Start Here]] |
| Text and voice moderation | Shooters attract toxicity; see [[Voice Chat and Safety Features]] |

### Maps
- Three-lane layouts are the reliable default for team modes.
- Sightline length should match the roster: no 400-stud sightlines if there are no long-range weapons.
- Spawn areas need protection from direct sightlines.
- **Streaming caution:** a player must never be shot by an enemy whose model has not streamed in for them. For mid-size maps, disable streaming or keep a large minimum radius around combat areas. See [[Instance Streaming]].

---

## 7. Monetisation that keeps it fair

| Product | Fit | Notes |
|---|---|---|
| Weapon skins and camos | Excellent | The core shooter cosmetic |
| Battle pass with cosmetic tracks | Strong | Rewards play |
| Early unlock of a weapon that is also earnable | Acceptable | Equal or sidegrade only |
| Kill effects, emotes, charms | Good | Visible social signal |
| Private servers | Good | Clans, scrims, tournaments |
| XP boosts | Acceptable | Speeds unlocking, not power |
| Exclusive stronger weapons | Avoid | Kills trust in a competitive genre |

Paid random crates fall under Roblox's paid random item rules: odds disclosure and `PolicyService` restrictions for some players (Docs; see [[Paid Random Items and Odds Disclosure in Practice]]). Direct purchase of a specific skin avoids most of that complexity.

---

## 8. Patterns successful shooters share

- **Consistent hit registration first, content second.** Players forgive few maps; they do not forgive shots that do not count.
- **Progression per gun** (level a gun to unlock its attachments and camos) gives a long tail of goals inside one mode.
- **Readable art:** clean silhouettes, team-coloured outlines or tints, low visual noise behind enemies. Realism that hides players in clutter hurts gameplay.
- **Ranked only after the casual base is healthy.** Ranked splits the player base; launch it when servers are full.
- **Frequent balance patches with notes**, informed by per-weapon pick and kill rates.
- **Clan support** through private servers and group events. See [[Community Building]].

---

## 9. When not to make a shooter

- If you cannot spend weeks on hit registration and anti-cheat before content, the game will be judged on its worst moments.
- If your audience is mostly young and casual, a shooter's competitive pressure and toxicity risk may not fit; a co-op PvE shooter is gentler.
- If you plan a battle royale as a first project, scope down. Huge maps, streaming, looting and 50-plus player servers are several projects at once. See [[Planning and Scoping a Roblox Game]].

## 10. Common mistakes

| Mistake | Better |
|---|---|
| Trusting the client's "I hit X" | Server validation with capped rewind |
| Server-only raycasts at current positions | Rewind by ping, capped |
| Damage computed on the client | Server computes from weapon data |
| No fire-rate or ammo tracking on the server | Server tracks ammo and cadence |
| Streaming hides enemies who can shoot you | Large radius or no streaming in combat areas |
| Long menus before the first spawn | Spawn first, customise later |
| Selling stronger guns | Sell skins and sidegrades |
| Auto-banning on a single stat | Flag, review, appeal |

## 11. Launch checklist

- [ ] TTK-by-range chart for every weapon; each class owns a range band.
- [ ] Hit validation with rewind, line of sight, fire rate and ammo on the server; abuse-tested. See [[Testing Your Own Remotes - Fuzzing and Abuse Tests]].
- [ ] Two-client tests at 50, 150 and 250 ms simulated latency.
- [ ] First- and third-person aim match the crosshair; tested on touch and gamepad.
- [ ] Spawns safe from direct sightlines on every map.
- [ ] Streaming settings verified with players at opposite ends of each map.
- [ ] Reporting, mute and block flows; text and voice safety settings checked.
- [ ] Per-weapon analytics: pick rate, kills per minute, headshot share.
- [ ] Monetisation is cosmetic or sidegrade only; paid random items follow the rules.

## See also
- [[Combat Systems Architecture]], [[Hitboxes and Hit Detection]], [[Client Prediction and Reconciliation for Combat]]
- [[Exploits and Anti-Cheat]], [[Threat Modeling a Roblox Game]], [[Network Performance]]
- [[Genre Playbook - Battlegrounds and Arena Fighters]], [[Genre Playbook - Combat and RPG]], [[Level Design for Roblox]]

## Connected notes
<!-- auto-links:start -->
[[Genre Playbook - Sports]] · [[Physics and Vehicles Start Here]] · Links - Cameras · Melee Combat System End to End · Tower Defense Waves and Placement End to End · Combat Arena and Encounter Layout
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Gun Feel - Recoil, Spread, Bloom and Headshot Multipliers]] · [[Time-to-Kill Math and a Weapon Balance Sheet]] · [[Genre Playbook - Battle Royale]] · [[Weekend Build - Arena Shooter with Server-Checked Hits]] · [[Genre Playbook - Zombie and Wave Survival Co-op]] · [[Genre Playbook - Social Deduction and Murder Mystery]]
<!-- related:end -->
