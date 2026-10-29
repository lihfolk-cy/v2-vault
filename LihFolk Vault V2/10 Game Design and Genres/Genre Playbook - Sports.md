---
tags: [game-design, genre, sports, ball-physics, teams, network-ownership, competitive, type/guide, area/design, level/intermediate, area/physics]
---
# Genre Playbook - Sports

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: A plain unanchored ball, owned by whoever touched it last -> Possession model with server-decided flight
> - Avoid: Replicating the ball's CFrame every frame -> One launch message per flight segment
> - Avoid: 11v11 and 90-minute matches -> 3v3 to 6v6, 3 to 8 minutes
> - Ball model chosen; contested touches decided on the server with fair grace windows.
> - Two-client tests at 50, 150 and 250 ms for passing, shooting and stealing.
> - Goal and out-of-bounds decisions server-side; no premature "GOAL" banners.
>
> Cost: TL;DR ~170 tok · whole note ~4.0k tok. Read more: ## 3. The ball problem · ## 5. Systems you must build · ## 9. Common mistakes · ## 10. Launch checklist
<!-- tldr:end -->

Sports games on Roblox cover team ball sports (soccer, basketball, volleyball, hockey, American football, dodgeball), individual sports (golf, tennis, bowling, skating), extreme sports (skate parks, parkour), and arcade sports with powers and abilities. They range from casual "kick the ball around" hangouts to competitive leagues with ranked play and community tournaments. The audience is large and social, and the best sports games become places where friends meet to play a game they already know.

The genre has one defining technical problem: **a shared physics object (the ball) that every player wants to control instantly, over a network where every player sees it at a different time.** Get the ball right and almost everything else is design; get it wrong and no amount of content saves the game.

This playbook covers the loops, session and match length, monetisation, the systems you must build, the ball problem in depth, the patterns successful sports games share, and a launch checklist.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production combat game; cited only for general lessons), **Rule of thumb**.

---

## 1. Core loop

| Loop | Length | Content |
|---|---|---|
| Play | 1 to 10 s | Receive, move, pass, shoot, tackle |
| Possession | 10 to 60 s | A team's attack |
| Match | 3 to 10 min | Score, win |
| Session | 20 to 60 min | Several matches, casual or ranked |
| Meta | Weeks | Rank, skills, cosmetics, team or club membership |

### Realistic, arcade or ability sports
| Style | Feel | Audience |
|---|---|---|
| Realistic (close to the real rules) | Skill, teamwork, positioning | Fans of the sport, older players, leagues |
| Arcade (simplified rules, exaggerated physics) | Fast, accessible | Broad, young |
| Ability sports (powers, special shots, character kits) | Spectacle, clips | Anime and battlegrounds audience; see [[Genre Playbook - Battlegrounds and Arena Fighters]] |

Arcade and ability styles fit Roblox's audience and phones better. Realistic simulations need precise input and good networking to feel right.

### Real rules are a starting point
Real sports rules assume 11 players, 90 minutes and referees. On Roblox, adapt:
- **Small teams:** 3v3 to 6v6 is typical (rule of thumb). Fewer players means more ball touches each.
- **Short matches:** 3 to 8 minutes. Long matches lose players to interruptions.
- **Simplified fouls:** offside rules and complex foul systems confuse new players; remove or automate them.
- **No goalkeeper requirement** in casual modes, or an AI keeper when nobody wants the role.

---

## 2. Session design

- **Join and play in seconds.** Joining a server should put a player on a team or in a queue for the next match immediately, with a practice area while waiting.
- **Fill empty slots with bots** in casual modes when player counts are low, and let joining players take over bot slots mid-match.
- **Team balancing** at match start and after leaves, by skill if possible.
- **Spectating and substitution:** players waiting for a match watch the current one and can sub in.
- **Practice areas** for shooting, dribbling or skills, with targets and timers. These double as the tutorial.
- **Leagues and ranked**: only when servers are full enough to match quickly. See [[Spawning Teams and Rounds]].

---

## 3. The ball problem

### Why it is hard
Each client sees other players slightly in the past. If the server owns the ball, every kick is delayed by the kicker's round trip: the player presses kick, and the ball reacts 100 to 300 ms later. If the kicker's client owns the ball, the kick is instant for them, but everyone else sees the ball late, and ownership must hand over every time someone else touches it, which itself takes time.

| Approach | Kicker feels | Others feel | Risks |
|---|---|---|---|
| Server owns, server simulates | Delayed kicks | Consistent | Feels sluggish on high ping |
| Ownership moves to the possessing player | Instant | Ball jumps on handover | Exploitable (owner can move the ball freely); handover flicker |
| Server-authoritative ball with client prediction (custom simulation) | Instant, then corrected | Smooth | Most code; best result |
| Possession model (ball attached to the carrier; physics only in flight) | Instant dribble | Clean | Less "physical" feel; flight still needs a decision |

Successful sports games commonly use a **possession model with server-simulated flight**: while a player "has" the ball, it is welded or positioned at their feet or hand (driven by their client for smoothness, with the server tracking the carrier). When they pass or shoot, the client sends the intent (direction, power, timestamp), the server validates and launches the ball on a deterministic trajectory, and every client simulates the same trajectory from the same start time. Catching or intercepting is decided by the server.

### Deterministic flight
If the ball's flight is a simple function of time (projectile motion with drag, without collisions until it lands), every client can draw it from one message: start position, start velocity, server start time. No per-frame replication.

```lua
--!strict
-- ReplicatedStorage/BallFlight (ModuleScript). Shared trajectory so clients and server agree.
local BallFlight = {}

local GRAVITY = Vector3.new(0, -workspace.Gravity, 0)
local DRAG = 0.15 -- simple linear drag factor per second; tune per sport

export type Launch = { origin: Vector3, velocity: Vector3, t0: number }

-- Position at time t (server time), linear drag closed form.
function BallFlight.positionAt(l: Launch, t: number): Vector3
	local dt = math.max(t - l.t0, 0)
	if DRAG <= 0 then
		return l.origin + l.velocity * dt + 0.5 * GRAVITY * dt * dt
	end
	local k = DRAG
	local e = math.exp(-k * dt)
	-- x(t) = x0 + (v0 - g/k)(1 - e^{-kt})/k + (g/k) t
	return l.origin + (l.velocity - GRAVITY / k) * ((1 - e) / k) + (GRAVITY / k) * dt
end

-- Time when the ball reaches ground height y (first crossing after launch), by stepping.
function BallFlight.landingTime(l: Launch, groundY: number, maxTime: number?): number?
	local limit = maxTime or 6
	local step = 1 / 60
	local t = 0
	while t < limit do
		t += step
		if BallFlight.positionAt(l, l.t0 + t).Y <= groundY then
			return l.t0 + t
		end
	end
	return nil
end

return BallFlight
```

Clients render the ball at `positionAt(launch, workspace:GetServerTimeNow())`. A late-arriving client simply starts drawing partway through the flight. The server uses the same function to decide who can reach the ball, where it lands and whether it crossed the goal line. Bounces and collisions with players can be handled as new launches (the server issues a new launch from the contact point), which keeps every segment deterministic.

Nuances:
- `workspace.Gravity` read at module load; if your game changes gravity at runtime, pass it in instead.
- Spin and curve shots need a sideways term; add it to the formula rather than simulating in physics.
- Goal-line decisions belong to the server. Show a short replay or a "GOAL" banner only after the server confirms, or players see goals that are later taken back.
- Walls and posts make pure closed-form flight insufficient; raycast along the predicted path each segment on the server to find the first collision, then issue the bounce as a new launch.

### Tackles, steals and contested balls
Two players reach the ball at nearly the same time; each sees themselves first. The server decides, and the decision must feel fair:
- Use the **server's timeline**, with a small grace window favouring the player whose request arrived first.
- Give **visible feedback** for lost contests (a stumble animation) so the loss reads as gameplay, not lag.
- Steals need cooldowns and range checks on the server; a client that sends steal requests every frame from 30 studs away is cheating. See [[Remote Abuse Patterns and Rate Limiting in Practice]].

### When to use real physics
Fully physical balls (unanchored parts with real collisions) suit casual hangouts, physics-chaos arcade games and individual sports where one player owns the ball (golf, bowling: the shooter owns their ball, nobody else touches it). For competitive team play, the possession-plus-deterministic-flight model is more reliable. See [[Physics Assemblies and Constraints]], [[Network Ownership]] and [[Projectiles and Ballistics]].

---

## 4. Movement, input and camera

- **Movement speed and acceleration** define the sport. Sprint with a stamina bar adds decisions. Keep base speed consistent across characters in competitive modes.
- **Input:** pass, shoot (with charge for power), sprint, tackle or block, and one or two skills. On phones that is already five buttons; context-sensitive buttons (one action button that shoots when near the goal and passes elsewhere) reduce clutter. See [[Input - UserInputService and ContextActionService]].
- **Aim assistance:** passes that snap toward a teammate in the aimed direction make team play possible on phones.
- **Camera:** a broadcast-style camera (side-on or behind the team) for team sports; a following camera for individual sports. Keep the ball and the goal in view. See [[Camera Systems]].
- **Animation:** kicks, throws, dives and celebrations. Celebrations are a big part of the genre's social life and a natural cosmetic. See [[Emotes and Social Animation]] and [[Weapon and Combat Animation]].

---

## 5. Systems you must build

| System | Notes |
|---|---|
| Ball system | Possession, deterministic flight, server decisions |
| Teams and positions | Balancing, substitutions, bots |
| Match flow | Kickoff, score, timer, half time, results; see [[Round-Based Minigame Loop End to End]] |
| Rules engine | Out of bounds, goals, simple fouls, restarts |
| Stats | Goals, assists, passes, saves per player; saved |
| Ranking | Elo-style rating for ranked; see section 7 |
| Practice and tutorial | Drills that teach each action |
| Customisation | Kits, boots, balls, celebrations, team colours |
| Clubs / teams | Player-made teams (group-based or in-game); moderation of names |
| Spectating | Free camera and player follow |
| Anti-exploit | Speed, teleport, ball manipulation, request spam |

### Ranked ratings
An Elo-style rating is the standard. For a team match, compute expected score from the average rating of each team, and update each player's rating by the team result. Weight new players' updates higher (a larger K factor for the first 20 to 30 matches) so they reach their level quickly. Hide ratings for the first few matches to reduce pressure. Store ratings with the player's profile and, for leaderboards, in an ordered data store. See [[OrderedDataStores and Leaderboards]] and [[Global Leaderboards End to End]].

### Clubs and custom team names
Any text players create (club names, kit names, numbers with names) is user-generated text shown to others and must be filtered with `TextService` for every viewer (Docs, "Text filtering"). Club logos should be chosen from a preset library, not uploaded. See [[Community and Moderation Start Here]] and [[Groups Roles and Permissions for Studios]].

---

## 6. Monetisation that fits

| Product | Fit | Notes |
|---|---|---|
| Cosmetics: kits, boots, balls, trails, celebrations | Core | Highly visible in every match |
| Battle pass with cosmetic tracks | Strong | Weekly challenges per position or skill |
| Ability characters or special shots (ability sports) | Common | Balance against free options |
| Private servers | Strong | Leagues, clubs, tournaments run on them |
| Stat boosts (speed, shot power) | Avoid | Destroys competitive trust |
| Club creation fee | Acceptable | Small; also a spam filter |

Leagues run by the community are a major growth source. Supporting them (private servers, referee tools, match recording) costs little and builds loyalty. See [[Community Building]].

---

## 7. Technical risks on Roblox

| Risk | Symptom | Mitigation |
|---|---|---|
| Client-owned ball | Exploiters teleport the ball into the goal | Server-authoritative ball state |
| High-ping players | Kicks delayed, lost contests | Possession model, deterministic flight, capped grace windows |
| Character collisions | Players pushing and flinging each other | Collision groups between characters; custom tackle logic |
| Speed exploits | One player outruns everyone | Server speed checks with fair thresholds; see [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] |
| Spam requests | Steal or shoot requests every frame | Per-action cooldowns and rate limits on the server |
| Match leavers | Uneven teams | Bots fill slots; rating penalties for leaving ranked |
| Field size versus streaming | Ball or players outside streamed area | Small fields need no streaming; large ones need a radius covering the whole pitch |

---

## 8. Patterns successful sports games share

Patterns, not copies:
- **Instant fun with no explanation**: everyone knows "kick the ball into the goal".
- **Skill expression** in a few deep moves (curved shots, timed tackles, trick moves) that players practise.
- **Celebrations and cosmetics** as the main spending.
- **Community leagues and tournaments** supported by private servers and tools.
- **Short matches and quick rematches**.
- **Original branding.** Real leagues, clubs, players and logos are protected; use original teams and kits. See [[Legal Basics - IP Licenses and Assets]].

---

## 9. Common mistakes

| Mistake | Better |
|---|---|
| A plain unanchored ball, owned by whoever touched it last | Possession model with server-decided flight |
| Replicating the ball's CFrame every frame | One launch message per flight segment |
| 11v11 and 90-minute matches | 3v3 to 6v6, 3 to 8 minutes |
| Complex foul rules | Simplified, automated rules |
| Empty teams waiting for players | Bots that players can replace |
| Selling stat boosts | Cosmetics and celebrations |
| Unfiltered club names | `TextService` filtering per viewer |
| Ranked before the casual base is healthy | Casual first, ranked when queues are short |

## 10. Launch checklist

- [ ] Ball model chosen; contested touches decided on the server with fair grace windows.
- [ ] Two-client tests at 50, 150 and 250 ms for passing, shooting and stealing.
- [ ] Goal and out-of-bounds decisions server-side; no premature "GOAL" banners.
- [ ] Phone controls tested: context buttons, pass assist.
- [ ] Bots fill empty slots; team balancing on join and leave.
- [ ] Rate limits and range checks on every action remote.
- [ ] Ratings and stats saved safely; leaderboards via ordered data stores.
- [ ] User-created text filtered; logos from a preset library.
- [ ] Original teams, kits and branding.

## See also
- [[Spawning Teams and Rounds]], [[Social Design and Multiplayer Play]], [[Core Loops and Session Design]]
- [[Network Ownership]], [[Client-Server Model]], [[Physics and Vehicles Start Here]]
- [[Genre Playbook - Party and Minigame Collections]], [[Genre Playbook - Racing and Driving]], [[Retention and Return Hooks]]

## Connected notes
<!-- auto-links:start -->
[[Genre Playbook - Shooters FPS and TPS]] · [[Arena Rounds with Teams and Spectating End to End]] · Genre Systems Start Here · Skill - Roblox Anti-Exploit Review · Core Loop · Matchmaking Queues with MemoryStore
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Genre Playbook - Battle Royale]] · [[Genre Playbook - Social Deduction and Murder Mystery]] · [[Genre Playbook - Obbies and Platformers]] · [[Genre Playbook - Tower Defense]] · [[Genre Playbook - Roleplay and Social Hangouts]] · [[Genre Playbook - Naval and Open-Sea Adventure]] · [[Genre Playbook - Open-World City and Crime Roleplay]] · [[Genre Playbook - Tycoons]]
<!-- related:end -->
