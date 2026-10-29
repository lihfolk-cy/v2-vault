---
tags: [level-design, obby, platforming, jump-math, difficulty, stage-design, validation, type/guide, area/world, level/intermediate, api/CollectionService, area/design]
---
# Obby and Platforming Level Design

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Designed for JumpHeight, place uses JumpPower (or the reverse) -> Check `CharacterUseJumpPower`; redo the reach table
> - Avoid: Raised a platform for looks -> Lower it or shorten the gap
> - Avoid: Long chains with no rest -> Mid-stage checkpoint or split the chain
> - Jump mode (height or power) written down; reach table computed and calibrated.
> - Every stage raises one dial; difficulty attribute set.
> - Chains longer than 5 or 6 jumps split by a checkpoint.
>
> Cost: TL;DR ~160 tok · whole note ~5.2k tok. Read more: ## 1. The jump arc, worked out · ## 3. The obstacle vocabulary · ## 9. Common mistakes · ## 10. Checklist
<!-- tldr:end -->

[[Genre Playbook - Obbies and Platformers]] covers the genre: variants, why obbies work on Roblox, the default movement numbers, teach-test-twist, checkpoint code, mobile fairness, moving platforms, towers and monetisation. This note is the level designer's companion to it. It works out the jump arc from first principles so you can design gaps on paper, builds an obstacle vocabulary with the variables that make each one hard, treats difficulty as a set of dials instead of a feeling, covers the camera and depth-perception problems peculiar to a third-person platformer, and ends with a validator script that catches impossible and trivial jumps before a playtester does.

Labels: **Roblox docs (as of October 2026)**, **computed** (worked from the documented defaults; confirm in your place), **rule of thumb**.

## 1. The jump arc, worked out

Documented defaults (Roblox docs, as of October 2026): `StarterPlayer.CharacterJumpHeight` 7.2 studs, `CharacterJumpPower` 50 (used when `CharacterUseJumpPower` is on), `CharacterWalkSpeed` 16 studs/s, and the gravity value used across Roblox samples, 196.2 studs/s².

From those, using plain projectile motion (computed; the Humanoid controller is close to this but not exact, so calibrate):

| Quantity | Formula | JumpHeight 7.2 | JumpPower 50 |
|---|---|---|---|
| Launch speed up | `v = sqrt(2 g h)` or `v = JumpPower` | about 53.2 studs/s | 50 studs/s |
| Peak height | `h` or `v² / 2g` | 7.2 studs | about 6.4 studs |
| Time to peak | `v / g` | about 0.27 s | about 0.25 s |
| Airtime, flat landing | `2v / g` | about 0.54 s | about 0.51 s |
| Horizontal travel, flat, at 16 studs/s | `speed * airtime` | about 8.7 studs | about 8.2 studs |

**Nuance 1: two jump modes give different games.** Older places and many templates use JumpPower 50, which peaks around 6.4 studs, not 7.2. A ledge of 7 studs is easy in one mode and impossible in the other. Write down which mode your place uses before designing a single stage.

**Nuance 2: travel is centre to centre.** The 8.7 studs is how far the character's root moves. The character has width: you can take off with your root slightly behind the edge and land with your feet just over the far edge. In practice the clearable edge-to-edge gap is the root travel plus about 1 to 2 studs (rule of thumb; measure it on your calibration course, because character scale and animation change it).

### Jumping up and down changes the distance

Time in the air until the character comes back down to a height `dh` above (positive) or below (negative) the take-off height:

`t = (v + sqrt(v² - 2 g dh)) / g`

| Landing height vs take-off | Airtime (JumpHeight 7.2) | Root travel at 16 studs/s |
|---|---|---|
| +7 studs (near the limit) | about 0.32 s | about 5.1 studs |
| +5 studs | about 0.42 s | about 6.7 studs |
| 0 (flat) | about 0.54 s | about 8.7 studs |
| -5 studs | about 0.62 s | about 9.9 studs |
| -10 studs | about 0.69 s | about 11.0 studs |

Two design facts follow:

- **Upward jumps are much shorter.** A gap that is easy on the flat becomes hard if the far platform is 5 studs higher. Many accidental difficulty spikes are exactly this: a builder raised a platform for visual variety.
- **Downward jumps forgive.** Descending stages feel generous. Use them for breathers and for the first stage after a hard one.

```lua
--!strict
-- Computed jump reach for design work. Calibrate EXTRA_REACH on your own course.
local GRAVITY = workspace.Gravity
local EXTRA_REACH = 1.5 -- studs of edge-to-edge bonus from character width (measure this)

local function launchSpeed(): number
	local sp = game:GetService("StarterPlayer")
	if sp.CharacterUseJumpPower then
		return sp.CharacterJumpPower
	end
	return math.sqrt(2 * GRAVITY * sp.CharacterJumpHeight)
end

-- Max edge-to-edge horizontal gap for a landing dh studs above (+) or below (-) take-off.
-- Returns nil if the height cannot be reached at all.
local function maxGap(dh: number, runSpeed: number): number?
	local v = launchSpeed()
	local disc = v * v - 2 * GRAVITY * dh
	if disc < 0 then
		return nil
	end
	local t = (v + math.sqrt(disc)) / GRAVITY
	return runSpeed * t + EXTRA_REACH
end

return { maxGap = maxGap, launchSpeed = launchSpeed }
```

### Air control

Default Roblox characters can change direction in the air at close to full walk speed (observed behaviour; not a documented number). That has two effects: jumps can curve (around a pole, onto a platform to the side), and a player who overshoots can pull back. It also means an obby built for another engine's committed jumps plays easier on Roblox. If you write a custom controller that reduces air control, every gap in your game changes meaning; see [[Custom Character Controllers]].

## 2. Difficulty is a set of dials

"This stage is too hard" is useless feedback for a designer. Break difficulty into dials you can turn one at a time:

| Dial | Easy end | Hard end |
|---|---|---|
| Gap margin (gap vs max reach) | 50 percent of max | 90 to 100 percent of max |
| Landing size | 8+ studs square | 1 to 2 stud pole tops, truss ends |
| Height change | Down or flat | Up near the limit |
| Timing window | Static | Under 0.5 s windows on moving hazards |
| Run-up required | None | Must sprint from a fixed spot |
| Camera difficulty | Jump across the screen (sideways) | Jump toward or away from the camera |
| Chain length | 1 to 2 jumps between safe spots | 6+ jumps with no rest |
| Penalty | Respawn 5 s back | Lose a minute of progress |
| Visual noise | Plain platforms on a plain sky | Busy textures, particles, other players |

Rules of thumb for using them:

- **Turn one dial per new stage.** A stage that raises margin, shrinks landings and adds timing at once is a cliff, not a step.
- **Penalty multiplies everything.** The same jump feels twice as hard when a miss costs a minute instead of five seconds. Checkpoint placement is a difficulty dial, not a convenience. The playbook's rule (a checkpoint wherever a failure would replay more than about a minute of mastered content) is the ceiling, not the target.
- **Chain length is the sneakiest dial.** Each jump at a 90 percent success rate is fine alone; six in a row succeed only about 53 percent of the time (0.9 to the 6th power). Players feel the chain, not the individual jump.

### Success-rate maths for a stage

If a stage has jumps with success rates `p1, p2, ...`, a full clean run succeeds with probability `p1 * p2 * ...`, and the expected number of attempts is `1 / (that product)`. Two worked cases:

| Stage | Per-jump success | Jumps | Clean-run chance | Expected attempts |
|---|---|---|---|---|
| Early | 0.97 | 5 | about 86 percent | about 1.2 |
| Mid | 0.9 | 6 | about 53 percent | about 1.9 |
| Hard | 0.8 | 8 | about 17 percent | about 6 |
| Spike | 0.7 | 10 | about 3 percent | about 35 |

This is why deaths-per-stage logging (see the playbook) reveals spikes so clearly: a few hard jumps added to a long chain move the expected attempts by an order of magnitude. Split long chains with a mid-stage checkpoint before you make any single jump easier.

## 3. The obstacle vocabulary

Name your obstacle types and keep their parameters consistent across the game, so that players learn a language. A starter vocabulary:

| Obstacle | Key parameters | What it tests | Notes |
|---|---|---|---|
| Gap jump | Gap, height change, landing size | Distance judgement | The atom of every obby |
| Pole / pillar hop | Top size, spacing | Precision | 2-stud tops are hard on touch screens |
| Truss climb | Height, overhangs | Route reading | `TrussPart` is always climbable; other geometry only when it forms rung-like steps (observed behaviour) |
| Wraparound | Wall width, ledge width | Camera and air control | Hard for new players; teach on a wide ledge first |
| Kill floor with safe tiles | Tile pattern, tile size | Reading and memory | Keep the kill colour identical game-wide |
| Moving platform | Path, speed, pause at ends | Timing, riding | Riding behaviour is the classic engine trap |
| Rotating bar or sweeper | Angular speed, height | Timing | Give a visible rhythm and a safe zone |
| Disappearing tiles | On and off time, warning time | Timing, commitment | Always flash before vanishing |
| Conveyor | Speed vs walk speed | Fighting drift | Use `AssemblyLinearVelocity` on an anchored part |
| Bounce pad | Launch speed and angle | Committing to a launch | Show the landing from the pad |
| Ice or low friction | Friction values | Momentum control | Use sparingly; frustrating on touch |
| Wall jump or custom move | Your mechanic | Mastery | Needs its own teach-test-twist |

Timing obstacles need explicit numbers. For a rotating sweeper with period `T` and a safe window `w` at the player's position, the safe fraction is `w / T`. Rule of thumb: start at a window of 1 second or more, never go below about 0.4 s for anything required, and keep periods constant within a stage so players can count the rhythm. Every moving hazard should move on a clock players can read: same speed, same pauses, ideally with a sound or light cue on each cycle.

### Server time versus client time for hazards

Characters are simulated on their owner's client, so the player's own movement is instant on their screen. Hazards moved by the server arrive slightly late on every client. If the server also decides kills, a player can dodge a sweeper on their screen and still die. Two safer patterns (rule of thumb):

1. **Drive hazards from a shared clock on each client** (for example, angle = speed * `workspace:GetServerTimeNow()`), so every client sees the same position for the same moment without replicating movement.
2. **Detect hazard hits on the client** that owns the character, and have the server only sanity-check (the player was near the hazard). Cheaters can skip a kill this way, which matters for leaderboard runs; for those, validate stage times on the server instead. See the "Timed runs and anti-cheat" section of [[Genre Playbook - Obbies and Platformers]] and [[Detecting Movement Exploits - Speed Fly Noclip Teleport]].

```lua
--!strict
-- Client: a sweeper that every client animates from server time, so all players
-- see the same bar position at the same moment with no per-frame replication.
local RunService = game:GetService("RunService")

local sweeper = workspace:WaitForChild("Stage12"):WaitForChild("Sweeper") :: BasePart
local pivot = sweeper.CFrame
local PERIOD = 4 -- seconds per full turn; keep constant within the stage

RunService.PreRender:Connect(function()
	local t = workspace:GetServerTimeNow()
	local angle = (t % PERIOD) / PERIOD * math.pi * 2
	sweeper.CFrame = pivot * CFrame.Angles(0, angle, 0)
end)
```

The part here is anchored and moved only on the client (the server leaves it alone), so it does not replicate. Its collisions and touch detection then happen on each client, which is what you want for player-owned characters.

## 4. The camera is part of the obstacle

The default camera sits behind and above the character. That makes some jumps much harder than their numbers suggest.

- **Depth is the hardest axis to judge.** A jump straight away from the camera hides the gap behind the character. A jump straight toward the camera hides the landing entirely unless the player rotates. Sideways jumps (across the screen) are the easiest to judge. Use direction as a difficulty dial on purpose.
- **There is no drop shadow by default.** Many platformers project a blob shadow straight down under the character so players can see where they will land. On Roblox, sunlight shadows fall at the sun's angle, not straight down, and may be off on low graphics. A simple client-side shadow (a dark circular decal on a thin part placed by a downward raycast each frame) makes precise landings far easier. Rule of thumb: add one to any game with small landings.
- **Walls behind the player.** In tight spaces the default camera zooms in to avoid walls, which removes the view of the next platform. Leave open space behind the take-off spot of every hard jump.
- **Shift lock and first person.** Some players use shift lock or first person for precision. Do not design jumps that are only possible in one camera mode unless you force that mode for the stage.

## 5. Stage templates and modular assembly

Long obbies and tower games need many stages. Building them as modules with a standard interface pays off quickly:

- **Every stage is a Model with two attachments,** `Entry` and `Exit`, on the floor, facing along the direction of travel. Assembly snaps each stage's `Entry` onto the previous stage's `Exit` with `PivotTo`.
- **Every stage carries attributes**: `Difficulty` (1 to 10), `Dials` (the dial it raises), `Length` (seconds for a typical clear), `Theme`.
- **Every stage starts and ends on a safe landing** at least 8 by 8 studs. That is what makes random assembly safe: no stage can end with a jump that depends on the next stage's first platform.

```lua
--!strict
-- Assemble stage modules end to end: each stage's Entry attachment snaps to the previous Exit.
local function assemble(stages: { Model }, startCFrame: CFrame, parent: Instance)
	local cursor = startCFrame
	for i, template in stages do
		local stage = template:Clone()
		local entry = stage:FindFirstChild("Entry", true) :: Attachment?
		local exit = stage:FindFirstChild("Exit", true) :: Attachment?
		assert(entry and exit, `Stage {template.Name} needs Entry and Exit attachments`)
		-- Offset from the model pivot to the entry, so we can place the entry at the cursor.
		local pivotToEntry = stage:GetPivot():ToObjectSpace(entry.WorldCFrame)
		stage:PivotTo(cursor * pivotToEntry:Inverse())
		stage.Name = `Stage{i}`
		stage.Parent = parent
		cursor = exit.WorldCFrame
	end
end
```

Tower games pick stages at random within a difficulty band per floor. Pick by band, not by random index across all stages, or a hard stage can appear first. See [[Procedural World Generation]] for seeded selection.

## 6. A stage validator

Most broken jumps are found by players. A script can find the worst of them first: list the platforms of a stage in order, compute each gap and height change, and compare with `maxGap`.

```lua
--!strict
-- Validate a stage: platforms are BaseParts tagged "Platform" inside the stage, with an
-- integer attribute "Order". Flags jumps that are impossible or nearly so, and trivial ones.
local CollectionService = game:GetService("CollectionService")
local Jump = require(script.Parent.JumpReach) -- the module from section 1

local RUN_SPEED = 16

local function edgeGap(a: BasePart, b: BasePart): number
	-- Horizontal gap between the two top faces' bounding boxes (ignores rotation; fine for most stages).
	local function axisGap(ca: number, ha: number, cb: number, hb: number): number
		-- Gap between intervals [ca - ha, ca + ha] and [cb - hb, cb + hb]; 0 if they overlap.
		return math.max(0, math.abs(ca - cb) - ha - hb)
	end
	local dx = axisGap(a.Position.X, a.Size.X / 2, b.Position.X, b.Size.X / 2)
	local dz = axisGap(a.Position.Z, a.Size.Z / 2, b.Position.Z, b.Size.Z / 2)
	return math.sqrt(dx * dx + dz * dz)
end

local function validate(stage: Model)
	local platforms = {}
	for _, d in stage:GetDescendants() do
		if d:IsA("BasePart") and CollectionService:HasTag(d, "Platform") then
			table.insert(platforms, d)
		end
	end
	table.sort(platforms, function(a, b)
		return (a:GetAttribute("Order") :: number) < (b:GetAttribute("Order") :: number)
	end)

	for i = 1, #platforms - 1 do
		local a, b = platforms[i], platforms[i + 1]
		local topA = a.Position.Y + a.Size.Y / 2
		local topB = b.Position.Y + b.Size.Y / 2
		local dh = topB - topA
		local gap = edgeGap(a, b)
		local reach = Jump.maxGap(dh, RUN_SPEED)
		local label = `{stage.Name}: {a.Name} -> {b.Name} gap {string.format("%.1f", gap)}, dh {string.format("%.1f", dh)}`
		if not reach then
			warn(label, "IMPOSSIBLE (too high)")
		elseif gap > reach then
			warn(label, `IMPOSSIBLE (reach {string.format("%.1f", reach)})`)
		elseif gap > reach * 0.9 then
			warn(label, "near the limit: hard, needs a clean run-up")
		elseif gap < 2 and dh <= 0 then
			print(label, "trivial: is this meant to be a breather?")
		end
	end
end

return validate
```

Limits of the check: it ignores rotation, moving parts, bounce pads and ceilings that cut the arc. It still catches the common bugs (a platform nudged one stud too far, a raised platform that made a jump impossible) and gives a reviewer a list of the hardest jumps to playtest first.

## 7. Rhythm across a run

Above the stage, a run of stages has rhythm. The playbook gives the sawtooth (ramp, breather, slightly higher ramp). Three level-design details make breathers work:

- **A breather is a place, not just an easy stage.** A wide platform with a view back over the stages just cleared (progress made visible), a view forward to the next landmark, and the checkpoint.
- **Change theme at breathers,** not mid-ramp. The visual change marks the new difficulty band and resets attention.
- **Put shops, skips and social features at breathers.** A purchase prompt in the middle of a hard chain is resented; one on a calm platform after a hard chain is welcome. See [[Ethical Design and Player Trust]].

## 8. When not to apply this

- **Troll obbies** break the vocabulary on purpose (fake platforms, kill bricks that look safe). Do it inside a game that announces itself as a troll obby, never in a normal one.
- **Movement and parkour games** with custom moves (wall runs, slides, dashes) need their own reach tables. The maths in section 1 applies only to the default jump.
- **Physics-heavy obstacles** (swinging ropes, ragdoll launchers) are hard to keep fair across latency and devices. Test them on a phone with a weak connection before keeping them.

## 9. Common mistakes

| Mistake | How to spot it | Fix |
|---|---|---|
| Designed for JumpHeight, place uses JumpPower (or the reverse) | Ledges near 7 studs fail for everyone | Check `CharacterUseJumpPower`; redo the reach table |
| Raised a platform for looks | Validator flags a near-limit upward jump | Lower it or shorten the gap |
| Long chains with no rest | Deaths per stage spike at the end of the stage | Mid-stage checkpoint or split the chain |
| Server-moved hazards with server kills | "I dodged it and died" | Client clock animation and client-side hits |
| Depth jumps early | New players miss jumps toward the camera | Sideways jumps first; depth later |
| No landing shadow on tiny platforms | Players overshoot pole tops | Client blob shadow by raycast |
| Stage ends on a jump | Random assembly makes impossible joins | Every stage starts and ends on a safe landing |
| Inconsistent kill colour | Deaths on "safe-looking" parts | One kill material game-wide |

## 10. Checklist

- [ ] Jump mode (height or power) written down; reach table computed and calibrated.
- [ ] Every stage raises one dial; difficulty attribute set.
- [ ] Chains longer than 5 or 6 jumps split by a checkpoint.
- [ ] Timing windows at least about 0.4 s for required obstacles; constant periods per stage.
- [ ] Hazards animated from a shared clock; hit detection on the owning client with server sanity checks.
- [ ] Hard jumps have open space behind the take-off for the camera.
- [ ] Landing shadow for small landings.
- [ ] Stage modules have `Entry` and `Exit` and start and end on safe landings.
- [ ] Validator run on every stage after edits; near-limit jumps playtested on a phone.
- [ ] Breathers are places with a view, a checkpoint and any shop prompts.

## See also

- [[Level Design Start Here]], [[Genre Playbook - Obbies and Platformers]], [[Level Design for Roblox]].
- [[Teaching Through Level Design]] for teaching new obstacle types.
- [[Spawn Points Safe Zones and Respawn Flow]] for checkpoint respawns and fall recovery.
- [[Characters and Humanoids]], [[Custom Character Controllers]], [[Camera Systems]].
- [[Raycasts Shapecasts and Spatial Queries]], [[Procedural World Generation]], [[Detecting Movement Exploits - Speed Fly Noclip Teleport]].

## Connected notes
<!-- auto-links:start -->
[[Obby Checkpoints and Stage Saves End to End]] · 2D Collision Physics and Platformer Movement · Input Buffering · Genre Systems Start Here · Avatar Body Types and Scale in Gameplay · Official Docs - Game Systems
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Kill Planes, Map Boundaries and Out-of-Bounds Recovery]] · [[Combat Arena and Encounter Layout]] · [[Playtest Heatmaps - Position and Death Maps]] · [[Level Design Principles - Flow Sightlines and Landmarks]] · [[Objective Mode Maps - Capture the Flag, King of the Hill and Control Points]] · [[Lobby and Hub Design]]
<!-- related:end -->
