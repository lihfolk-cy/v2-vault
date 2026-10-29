---
tags: [game-design, genre, battlegrounds, fighting, pvp, combos, netcode, arena, type/guide, area/design, level/intermediate]
---
# Genre Playbook - Battlegrounds and Arena Fighters

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Server-only hit decision with no rewind -> Lag-compensated server checks, capped
> - Avoid: Client-trusted hits -> Validate range, cooldown, state and target count
> - Avoid: Infinite combos -> Hitstun decay, combo time cap, get-up invulnerability, breaker
> - Every move defined in data with frame data, hitbox and damage.
> - Two-client test with simulated latency (100 and 250 ms) for every character's combos.
> - Hit validation and rate limits on every combat remote; fuzzed.
>
> Cost: TL;DR ~160 tok · whole note ~4.1k tok. Read more: ## 1. Core loop · ## 3. Fairness under latency · ## 8. Common mistakes · ## 9. Launch checklist
<!-- tldr:end -->

A "battlegrounds" game drops a server of players into one open arena, each picking a character with a fixed move set (usually four abilities plus a basic attack chain and an ultimate that charges in combat), and lets them fight freely. Arena fighters are the tighter cousin: one-on-one or small-team rounds, often ranked. Both are pure PvP skill games built on the moment-to-moment feel of hits, which makes them the most netcode-sensitive genre on Roblox and the one where exploiters do the most visible damage.

This note goes beyond [[Genre Playbook - Combat and RPG]] (which focuses on PvE: enemies, bosses, gear) into what a PvP move-set fighter needs: the combat grammar, fairness under latency, counterplay, servers full of strangers, monetisation that does not sell power, and the patterns successful fighters share.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production combat game with a PvP arena), **Rule of thumb**.

---

## 1. Core loop

| Loop | Length | Content |
|---|---|---|
| Exchange | 1 to 5 s | Approach, basic attack chain or ability, block or dodge, punish |
| Fight | 10 to 60 s | One duel or a scramble of three or four players |
| Session | 20 to 60 min | Many fights, character swaps, chasing kill streaks |
| Meta | Weeks | Unlocking characters, emotes, cosmetics, ranked rating, mastery |

The fight is the product. Unlike most Roblox genres, there is little meta progression of *power*; progression is in **knowledge and execution**: learning combos, learning each character's counters, reading opponents. That is the genre's strength (endless replay from player-made depth) and its acquisition problem (new players get beaten by veterans immediately).

### The combat grammar
Most fighters on Roblox share a small grammar, and players arrive already knowing it. Deviate deliberately, not by accident.

| Element | Typical shape (rule of thumb) |
|---|---|
| Basic attack chain ("M1s") | 4 hits, the last one knocks back or ragdolls; a short end lag after the chain |
| Block | Hold to reduce damage heavily; breaks after N hits or a heavy attack (guard break) |
| Dash / dodge | Short burst with a cooldown (1.5 to 3 s); side dashes and forward dashes distinct |
| Abilities | 4 per character, cooldowns 5 to 25 s, mixing a combo starter, a mobility move, a counter and a finisher |
| Ultimate / awakening | Charges by dealing and taking damage; transforms the move set for 30 to 60 s |
| Counter | A timed move that punishes an attack inside a short window |
| Ragdoll / knockdown | The end of a combo; the victim cannot act until they get up |

### Combo design and escape
A combo is a sequence where the victim cannot act between hits (they are in hitstun). Combos are the skill ceiling, and **infinite combos are the genre's most common design bug**. Rules that prevent them:
- **Hitstun decays.** Each hit in a combo applies slightly less stun than the previous one, or a cap on total combo time (for example 3 to 4 s) forces a release.
- **Ragdoll ends the combo.** After a knockdown, give the victim a short invulnerability on getting up (0.5 to 1 s) so they are not re-caught instantly.
- **A combo breaker.** Many fighters give an escape on a long cooldown (or costing part of a meter) that works while in hitstun. It turns "I lost to a combo" into "I spent my escape too early".
- **Wall and ground bounces have limits.** One of each per combo.

Write combos as data, then test them with two clients and real latency. See [[Combat Combo Systems]] and [[Hit Reactions Stagger and Hit-Stop]].

---

## 2. Session length and server shape

- **Server size:** battlegrounds typically run 10 to 20 players per server in one arena (rule of thumb). Fewer than 8 and fights are hard to find; more than about 25 and third-party chaos ruins duels, and the server performance cost of ragdolls and VFX climbs.
- **No rounds** in open battlegrounds: players drop in, fight, die, respawn in seconds. Respawn time is the main pacing knob (2 to 5 s).
- **Arena fighters use rounds:** best of three or five, 60 to 99 s round timers. Queue time must be short; with few players online, fall back to bots or open sparring.
- **Session hooks:** kill streaks, a "hunted" bounty on high-streak players, daily challenges per character, and mastery tracks per character.

### The newcomer problem
In an open server, a player with 10 minutes of experience meets one with 300 hours. Ways to soften it without splitting the player base:
- A **training dummy area** in the lobby, with combo practice and an input display.
- **Custom matchmaking** to put similar-skill players together. Roblox lets creators weight matchmaking signals and define custom signals from their own data (Docs, "Customize your matchmaking configuration"; rolled out to all creators in 2025). A custom signal such as "average kills per death" or "hours played" can bias server joins toward similar players. Test carefully: too strong a bias can split a small player base into empty servers.
- **Bounties on dominant players** give everyone a reason to gang up on the top player instead of on the newcomer.
- **Damage scaling on low-health victims is a trap**; it makes good players feel cheated. Prefer protecting newcomers through matchmaking and spawn protection.

---

## 3. Fairness under latency

PvP on Roblox is a negotiation between players with 30 ms and players with 250 ms. There is no perfect answer; choose consciously.

### Where the hit is decided
| Model | Feels like | Risk |
|---|---|---|
| Server-side hitbox at the server's view of positions | Fair to the defender; attackers on high ping "whiff" visible hits | Frustration for attackers |
| Client reports hit, server validates (distance, angle, cooldown, recent positions) | Great for the attacker; defenders sometimes get hit "around corners" | Needs strict validation or it becomes an exploit |
| Server-side hitbox with lag compensation (rewind positions by the attacker's ping) | Best compromise | Needs a position history buffer; more server work |

Most successful fighters use one of the last two. Whatever you choose:
- **Play the attack animation and effects on the attacker's client at once** (under 100 ms to visible response) and let the server decide damage. See [[Client Prediction and Reconciliation for Combat]].
- **Validate every hit on the server:** the attacker is alive and not stunned, the move is off cooldown (using the server's clock), the target is within the move's range plus a latency margin, and the attacker has not hit more targets than the move allows. See [[Detecting Combat Exploits - Reach Rate and Aim]].
- **Keep a short position history** (the last 1 s of root positions per player, sampled at 20 to 30 Hz) on the server. It powers lag compensation and reach checks.

```lua
--!strict
-- Server: a ring buffer of recent root positions per player, for rewind checks.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HISTORY_SECONDS = 1.0
local SAMPLE_INTERVAL = 1 / 30

type Sample = { t: number, pos: Vector3 }
local history: { [Player]: { Sample } } = {}

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < SAMPLE_INTERVAL then return end
	accumulator = 0
	local now = workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local buf = history[player] or {}
			history[player] = buf
			table.insert(buf, { t = now, pos = root.Position })
			while #buf > 0 and now - buf[1].t > HISTORY_SECONDS do
				table.remove(buf, 1) -- small buffers (about 30 entries), so this is cheap
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	history[player] = nil
end)

-- Position of a player at a past server time (nearest sample; interpolate if you need more precision).
local function positionAt(player: Player, t: number): Vector3?
	local buf = history[player]
	if not buf or #buf == 0 then return nil end
	local best = buf[#buf]
	for i = #buf, 1, -1 do
		if buf[i].t <= t then best = buf[i]; break end
	end
	return best.pos
end

return positionAt
```

Cap the rewind (for example at 250 ms). Players above that ping get no extra compensation, because rewinding further makes defenders get hit long after they dodged, which feels worse than an occasional whiff.

### Network ownership and knockback
Characters are owned by their own client, so the server cannot simply set a victim's velocity and expect it to stick. Common approach: apply knockback on the victim's client (the server sends "knockback, direction, strength") and also apply it on the server; or briefly take ownership for ragdolls. Each has artefacts; test with two clients and simulated latency. See [[Network Ownership]] and [[Debugging Physics and Network Ownership]].

### Ragdolls cost
Ragdolls look great in clips and cost physics on every client. Ten simultaneous ragdolls in a 20-player server is normal for the genre. Keep ragdolls short (1 to 2 s), simplify the ragdoll constraints, and stop them early on low-end devices. See [[Ragdolls and Physics-Based Animation]] and [[Snippets - Ragdoll]].

---

## 4. Systems you must build

| System | Notes |
|---|---|
| Character / move-set registry | One data module per character: moves, cooldowns, damage, hitboxes, animations, VFX ids |
| Input layer | Keyboard, touch buttons, gamepad; buffered inputs (a 100 to 200 ms buffer makes combos feel responsive) |
| State machine per fighter | Idle, attacking, blocking, stunned, ragdolled, dashing; illegal transitions rejected on the server |
| Hitbox service | Spatial queries per move frame; see [[Raycasts Shapecasts and Spatial Queries]] |
| Damage, stun and status | One module; see [[Status Effects Buffs and Stacking Rules]] |
| Ultimate meter | Server-side; charged by damage dealt and taken |
| Respawn and spawn protection | 2 to 5 s respawn, 2 s shield, multiple spawns |
| Kill feed, streaks, bounties | Cheap and very effective |
| Anti-exploit | Speed, fly, reach, cooldown, autoclick checks; see [[Anti-Exploit Start Here]] |
| Moderation | Report flow, mute, block; voice-chat-aware if enabled; see [[Player Reports and In-Game Moderation]] |
| Training area | Dummies, input display, combo counter |

### Mobile is half the battle
Most players are on phones (Docs). A fighter with four abilities, an ultimate, block, dash and attack has eight buttons. Make them big, put the basic attack where the right thumb rests, and give abilities automatic soft targeting toward the nearest enemy in front. Shift-lock style camera should be the default on touch. Test every combo with touch input: combos that need two simultaneous presses are often impossible on a phone. See [[Input - UserInputService and ContextActionService]] and [[Gamepad and Console UX]].

---

## 5. Monetisation that fits

| Product | Fit | Notes |
|---|---|---|
| Characters / move sets sold for Robux | Common | Balance them against free characters; a new paid character that is clearly strongest invites backlash |
| Character unlocks by playtime or kills, with a Robux shortcut | Strong | Players who do not pay still get there |
| Cosmetic skins for moves (colour, VFX) | Excellent | Pure expression; very visible in PvP |
| Emotes and kill effects | Excellent | Fighting genres thrive on taunts; see [[Emotes and Social Animation]] |
| Private servers | Good | Friends practise and run tournaments; enable and price them sensibly |
| Battle pass | Good | Cosmetic tracks; daily character challenges |
| Stat boosts, damage passes | Avoid | Pay-to-win in a pure skill game is the fastest way to lose the core audience |

Taunts and kill effects need a moderation thought: some players will use them to harass. Let players mute other players' emotes and effects, and never allow free-text in a kill effect.

---

## 6. Balance in a live fighter

- **Track per-character data:** pick rate, win rate in duels, average damage per minute, kill share, and the most common killer of each character. A character above about 55% duel win rate with a high pick rate needs attention (rule of thumb).
- **Small, frequent patches** beat big reworks. Change one number per move per patch, note it in patch notes, and give players a week.
- **Nerf the outlier move, not the character.** One unpunishable move usually explains a dominant character.
- **Frame data in the data module**: startup, active, recovery per move. Even if players never see it, you need it to reason about what is punishable.
- See [[Balancing with Spreadsheets and Data]] and [[Analytics and Funnels]].

---

## 7. Patterns successful fighters share

Patterns, not copies:
- **Characters inspired by recognisable archetypes** (the speedster, the heavy hitter, the trickster), each with a strong visual identity and signature ultimate. Do not use other people's characters or names without a licence.
- **Spectacle at the top of the skill curve:** ultimates and finishers with camera work and VFX that make clips. See [[Cinematic Ultimates]] and [[VFX Design Playbook]].
- **Sound design that sells impact.** A hit with no sound feels like a miss. See [[Combat Sound Design and Feedback]].
- **A visible skill ladder** through kill streak counters, rank badges and leaderboards.
- **Regular new characters** (every two to four weeks in a healthy live game) with a free path to unlock.
- **Community tech.** Players discover combos the designers did not plan. Keep the good ones; fix only the infinites.

---

## 8. Common mistakes

| Mistake | Better |
|---|---|
| Server-only hit decision with no rewind | Lag-compensated server checks, capped |
| Client-trusted hits | Validate range, cooldown, state and target count |
| Infinite combos | Hitstun decay, combo time cap, get-up invulnerability, breaker |
| Eight tiny touch buttons | Big buttons, soft targeting, tested on phones |
| Selling damage | Sell characters, cosmetics and emotes |
| Long ragdolls on every hit | 1 to 2 s, simplified on low-end |
| No newcomer space | Training area, matchmaking signals, bounties on top players |
| Balancing by feel only | Per-character win and pick rates |

## 9. Launch checklist

- [ ] Every move defined in data with frame data, hitbox and damage.
- [ ] Two-client test with simulated latency (100 and 250 ms) for every character's combos.
- [ ] Hit validation and rate limits on every combat remote; fuzzed. See [[Remote Abuse Patterns and Rate Limiting in Practice]].
- [ ] Movement exploit detection with fair handling of lag. See [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] and [[False Positives Lag and Fair Enforcement]].
- [ ] Full touch pass; buttons reachable; soft targeting.
- [ ] Ragdoll and VFX budget measured on a low-end phone in a full server.
- [ ] Spawn protection and respawn tuned; no spawn camping.
- [ ] Report, mute and block flows working. See [[Community and Moderation Start Here]].
- [ ] Per-character analytics events in place.
- [ ] At least one free character that is fully competitive.

## See also
- [[Combat Systems Architecture]], [[Hitboxes and Hit Detection]], [[Melee Combat System End to End]]
- [[Weapon and Combat Animation]], [[Combat Animation Craft]], [[Game Feel and Juice]]
- [[Spawning Teams and Rounds]], [[Social Design and Multiplayer Play]], [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Genre Playbook - Shooters FPS and TPS]] · [[Hit-Stop]] · [[Genre Playbook - Sports]] · Links - Combat · Input Responsiveness Buffering and Coyote Time · Level Design Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Case Study - The Strongest Battlegrounds]] · [[Genre Playbook - Battle Royale]] · [[Genre Playbook - Tower Defense]] · [[Genre Playbook - Open-World City and Crime Roleplay]] · [[Boss Fight Design Patterns]] · [[Genre Playbook - Puzzle and Escape Rooms]] · [[Time-to-Kill Math and a Weapon Balance Sheet]] · [[Genre Playbook - Party and Minigame Collections]] · [[Genre Playbook - Obbies and Platformers]]
<!-- related:end -->
