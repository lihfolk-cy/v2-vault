---
tags: [game-design, genre, obby, platformer, checkpoints, difficulty, type/guide, area/design, level/intermediate, api/AnalyticsService, api/CollectionService, api/Player]
---
# Genre Playbook - Obbies and Platformers

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Hard jumps in the first 10 stages -> Comfortable band early; spikes later
> - Avoid: Long stages without internal checkpoints -> Checkpoint before replaying more than about a minute
> - Avoid: Kill bricks that look like platforms -> One consistent kill style
> - Calibration course built; gaps designed in bands.
> - Teach, test, twist for every new obstacle type.
> - Sawtooth difficulty with breather stages.
>
> Cost: TL;DR ~140 tok · whole note ~3.9k tok. Read more: ## 4. Stage design · ## 5. Checkpoints and saving · ## 11. Common mistakes · ## 12. Checklist
<!-- tldr:end -->

The **obby** (obstacle course) is Roblox's oldest native genre and still one of its biggest: jump across platforms, avoid kill bricks, reach the next checkpoint. It needs no text, no tutorial and no economy, which makes it perfect for a young, mobile, international audience, and brutally competitive because thousands exist. The docs list Obby among the platform's common genres (Docs, "Design for Roblox"). This playbook covers the variants, stage and difficulty design, the movement numbers you design against, checkpoints and saving, mobile fairness, moving platforms (a classic engine trap), anti-cheat for timed runs, and monetisation that does not ruin the challenge.

Labels: **Docs** (create.roblox.com, checked October 2026), **Reference project** (one production combat game; used for funnel and pacing lessons), **Rule of thumb**.

---

## 1. Variants

| Variant | Structure | What players come for |
|---|---|---|
| Stage obby | Numbered stages, checkpoint each, linear | Steady progress, "stage 87!" |
| Difficulty-chart obby | Stages grouped by named difficulty, each harder | Mastery, bragging |
| Tower (round-based) | Randomly assembled sections, time limit, everyone races up | Short rounds, competition, replay |
| Story / escape obby | A theme or chase ("escape the X") with set pieces | Spectacle, humour, characters |
| Parkour / movement | Wall runs, slides, momentum, skill moves | Expression, speedruns |
| Co-op obby | Two players needed (buttons, carrying) | Friends |
| Troll obby | Fake platforms, jokes | Laughs, clips |

All share the same spine: **a stage is a short, readable challenge with a guaranteed restart point**.

---

## 2. Why obbies work on Roblox

- **No text.** A platform and a red brick explain themselves in any language.
- **Built on the default character.** Everyone already knows how to walk and jump.
- **Short attempts.** Each try is seconds long; death is cheap.
- **Visible progress.** Stage number on the HUD and over the head.
- **Social.** Watching a friend fail the jump you just made is the original Roblox comedy.
- **Clip-friendly.** Near-misses and rage moments make videos.

The weakness: the challenge is the only content. Every stage costs design time and is consumed in seconds. Variants exist mainly to multiply replay value per stage (towers randomise, charts add mastery, story obbies add spectacle).

---

## 3. Movement numbers to design against

Design gaps and heights around the default character, then **measure in Studio**, because settings, character scale and animations all change the result.

| Setting | Default | Where |
|---|---|---|
| Walk speed | 16 studs/s | `Humanoid.WalkSpeed` / `StarterPlayer.CharacterWalkSpeed` |
| Jump | JumpHeight 7.2 studs (newer places) or JumpPower 50 (when `UseJumpPower` is on) | `StarterPlayer.CharacterUseJumpPower`, `CharacterJumpHeight`, `CharacterJumpPower` |
| Gravity | 196.2 studs/s^2 | `Workspace.Gravity` |

Build a **calibration course** once per project: a row of gaps (6, 8, 10, 12 studs...) and ledges (3, 5, 7 studs...) and record which ones a normal player clears reliably, which need a running start, and which are impossible. Then design in bands:

| Band | Use for |
|---|---|
| Comfortably inside the max | Early stages, mobile-friendly sections |
| Close to the max, needs a clean run-up | Mid-difficulty "test" jumps |
| At the edge, needs precise timing | Hard stages only, never in the first 20 |

If you change walk speed, jump or gravity (some games give speed boosts as upgrades), **every gap changes meaning**. A speed pass can make early stages trivial, which is fine if intended, and a disaster for a leaderboard.

---

## 4. Stage design

### Teach, test, twist
Each new obstacle type follows three beats (rule of thumb from platformer design generally):
1. **Teach**: the mechanic appears in a safe form (a moving platform over solid ground).
2. **Test**: the same mechanic with a cost of failure (over a kill floor).
3. **Twist**: combined with another mechanic, or under time pressure.

### Readability
- Kill surfaces have **one colour and material** across the whole game (classic red neon). Never make a kill brick look like a safe one, except in a troll obby that announces itself.
- Safe platforms contrast with the background; check on a phone at low graphics quality, where fog and shadows differ. See [[Mobile and Low-End Optimization]].
- Show the next checkpoint from the current one when possible: a visible goal makes a hard jump worth trying.

### Length and pacing
| Stage type | Typical attempt length (rule of thumb) |
|---|---|
| Early | 5 to 15 s |
| Mid | 15 to 40 s |
| Late / hard | 30 to 90 s |
| Boss / set piece | 1 to 3 min, with an internal checkpoint |

Put a checkpoint wherever a failure would replay more than about a minute of already-mastered content. Replaying solved content is what makes players quit, not the hard jump itself.

### Difficulty curve
Use a **sawtooth**: a run of stages ramps up, then a breather stage (wide platforms, a reward, a view), then the next ramp starts slightly above the previous breather. Name difficulty bands visibly (Easy, Medium, Hard, ...) if your game is chart-style; players love knowing they have reached "Insane".

### Measure every stage
Log progression per stage and look for cliffs:

```lua
--!strict
-- Server: log stage starts and completions for a per-stage funnel.
local AnalyticsService = game:GetService("AnalyticsService")

local PATH = "Stages"

local function stageReached(player: Player, stage: number)
	AnalyticsService:LogProgressionCompleteEvent(player, PATH, stage - 1, ("Stage %d"):format(stage - 1))
	AnalyticsService:LogProgressionStartEvent(player, PATH, stage, ("Stage %d"):format(stage))
end
```

Also count deaths per stage on the server (a simple counter per stage per session, sent as a custom event when the player leaves the stage). A stage where the median player dies 30 times while its neighbours take 3 is a difficulty spike; redesign it or move it later. The reference project's onboarding funnel showed how unforgiving cliffs are: 82% of players were lost at a single boss step. Obby stages behave the same way.

---

## 5. Checkpoints and saving

### Checkpoints
Two approaches:

| Approach | How | Notes |
|---|---|---|
| SpawnLocations | One `SpawnLocation` per stage; set `Player.RespawnLocation` when touched | Simple; respawn handled by the engine |
| Custom | Store the stage number; on `CharacterAdded`, move the character to that stage's pad | Full control (spawn facing, effects, skip stages) |

A custom checkpoint system with server validation:

```lua
--!strict
-- Server: stage checkpoints. Pads are parts tagged "Checkpoint" with attribute Stage (number).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local pads: { [number]: BasePart } = {}
for _, pad in CollectionService:GetTagged("Checkpoint") do
	local stage = pad:GetAttribute("Stage")
	if pad:IsA("BasePart") and typeof(stage) == "number" then
		pads[stage] = pad
	end
end

local function getStage(player: Player): number
	return (player:GetAttribute("Stage") :: number?) or 1
end

local function onPadTouched(pad: BasePart, hit: BasePart)
	local character = hit.Parent
	if not character then return end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local stage = pad:GetAttribute("Stage") :: number
	local current = getStage(player)
	-- Only allow the next stage (no skipping by teleport exploits) or any earlier one (no effect).
	if stage == current + 1 then
		player:SetAttribute("Stage", stage) -- save this in the profile
	end
end

for _, pad in pads do
	pad.Touched:Connect(function(hit) onPadTouched(pad, hit) end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local pad = pads[getStage(player)]
		if not pad then return end
		-- Wait for the character to be assembled before moving it.
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root then
			task.defer(function()
				character:PivotTo(pad.CFrame + Vector3.new(0, 4, 0))
			end)
		end
	end)
end)
```

The "only the next stage" rule blocks the most common exploit (teleporting to the last checkpoint). Add plausibility checks for leaderboards (section 7).

### Saving
Save the furthest stage (and best times) in the profile. Offer **"Return to stage N"** and a way to replay earlier stages without losing the furthest one. See [[DataStore Fundamentals]].

---

## 6. Mobile fairness

Most players are on phones (Docs). Touch jumping is less precise than a keyboard, and the thumbstick hides part of the screen.

- Keep early and mid stages inside the comfortable band.
- Avoid jumps that require **camera control and movement at the same time** (turning mid-air around a pillar) in early stages; on touch that needs two thumbs plus a jump button.
- Avoid obstacles that appear in the lower-left of the screen (under the thumbstick) or near the jump button.
- Test every stage with the touch controls in the device emulator and on a real phone. See [[Responsive UI for Phone Tablet Console and PC]] and [[Testing Modes - Play Run and Multi-Client]].
- Consider a shift-lock-style camera option for PC but never require it.

---

## 7. Moving platforms, physics and timing

### Moving platforms that carry players
A platform moved by **setting its CFrame each frame** (or with a `TweenService` tween on an anchored part) does not carry a standing character reliably: the platform teleports under the feet, and the character slides off or jitters. Platforms driven by **physics** (an unanchored part with `PrismaticConstraint`, `AlignPosition` or another mover) have a real velocity, and characters standing on them move with them.

| Method | Carries players | Notes |
|---|---|---|
| Anchored + CFrame/tween on the server | Poorly | Fine for obstacles you must avoid (sweepers), bad for rides |
| Physics mover (constraint) | Yes | Set network ownership to the server for consistency (`SetNetworkOwner(nil)`) |
| Client-side animated platform | Smooth for that client | Positions differ between players; use only for single-player-visible elements |

See [[Physics Assemblies and Constraints]], [[Mover Constraints and Physics Controllers]] and [[Network Ownership]].

### Kill bricks and lag
Touch detection for the local character runs on the client that owns it. A kill brick handled only on the server can kill a player a moment after they visibly cleared it on their screen (or miss a touch). Common pattern: detect touches on the client for instant feedback (reset the character), and treat the server as the authority only for **progress** (stages), never for "you died on my screen".

### Timed runs and anti-cheat
Speedrun leaderboards attract speed and fly exploits.
- Time runs on the **server** (start and finish timestamps from `os.clock()` on the server), not from a client timer.
- Reject impossible times: keep a per-stage minimum (from your own best runs, minus a margin) and flag runs that beat the sum of minimums.
- Check position plausibility at checkpoints (distance from the previous checkpoint divided by time must be below the maximum speed).
- See [[Exploits and Anti-Cheat]].

---

## 8. Towers and round-based obbies

Round-based towers solve the content problem: the server assembles a tower from a pool of sections (each 20 to 60 s to climb), sets a timer, and everyone races. Players replay because the order changes.

Design notes:
- Tag sections by difficulty and assemble with a difficulty ramp (easy sections at the bottom).
- Keep each section's entry and exit at the same position and size, so any two can connect.
- Reward per section reached and a bonus for the top, so a player who reaches only halfway still earns.
- Timer length: long enough that average players reach the middle; the top is for good players.
- Spectating for players who finish or fall out keeps them in the server. See [[Spawning Teams and Rounds]].

---

## 9. Monetisation

| Product | Notes |
|---|---|
| Skip stage | Very common developer product; fine if stages are fair without it |
| Speed / jump coils | Changes difficulty; disable on leaderboards or keep separate boards |
| Cosmetics (trails, hats) | Safe and popular; obbies are watched by others |
| Checkpoint saves / revives | Acceptable in long stages |
| Gravity coil, fly | Turns the obby into a walk; ok as a novelty, not on leaderboards |

The ethical line: **do not tune stages to be unfair so that skips sell**. Players notice a stage that is suddenly much harder than its neighbours with a skip button glowing beside it. See [[Ethical Design and Player Trust]].

---

## 10. Adding depth without losing the genre

| Addition | Effect |
|---|---|
| Collectibles hidden off the main path | Exploration and replay |
| Badges per difficulty band | Long-term goals; see [[Quests and Objectives]] |
| Daily challenge stage | A return hook |
| Co-op stages | Social value |
| A light story with characters | Memorable set pieces; see [[Genre Playbook - Horror and Story]] |
| Movement abilities unlocked by progress | Metroidvania-style backtracking |

## 11. Common mistakes

| Mistake | Better |
|---|---|
| Hard jumps in the first 10 stages | Comfortable band early; spikes later |
| Long stages without internal checkpoints | Checkpoint before replaying more than about a minute |
| Kill bricks that look like platforms | One consistent kill style |
| Tween-driven rides | Physics movers for anything players stand on |
| Client-timed leaderboards | Server timing plus plausibility checks |
| Speed passes on the main leaderboard | Separate boards or disable boosts |
| Stages tuned to sell skips | Fair stages; skips for convenience |
| Never testing on touch | Every stage on a phone |

## 12. Checklist

- [ ] Calibration course built; gaps designed in bands.
- [ ] Teach, test, twist for every new obstacle type.
- [ ] Sawtooth difficulty with breather stages.
- [ ] Per-stage funnel and death counts logged.
- [ ] Checkpoints only advance one stage at a time; saved.
- [ ] Moving rides use physics movers with server ownership.
- [ ] Mobile pass on every stage.
- [ ] Timed runs measured on the server with minimum-time checks.

## See also
- [[Level Design for Roblox]], [[Characters and Humanoids]], [[Custom Character Controllers]]
- [[Physics Assemblies and Constraints]], [[Mover Constraints and Physics Controllers]], [[Network Ownership]]
- [[Exploits and Anti-Cheat]], [[OrderedDataStores and Leaderboards]], [[Spawning Teams and Rounds]]
- [[Core Loops and Session Design]], [[First-Time User Experience and Onboarding]], [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[Obby and Platforming Level Design]] · Obby Checkpoints and Stage Saves End to End · Genre Systems Start Here · Links - Checkpoints and spawning · Level Design Start Here · Difficulty Options and Cognitive Load
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Obby Checkpoints and Stage Saves End to End]] · [[Genre Playbook - Puzzle and Escape Rooms]] · [[Genre Playbook - Party and Minigame Collections]] · [[Genre Playbook - Racing and Driving]] · [[Genre Playbook - Tycoons]] · [[Progression and Pacing Design]] · [[Genre Playbook - Tower Defense]] · [[Genre Playbook - Combat and RPG]] · [[Genre Playbook - Simulators]]
<!-- related:end -->
