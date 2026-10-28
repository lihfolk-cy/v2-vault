---
tags: [level-design, onboarding, teaching, affordances, tutorial, analytics, wayfinding]
---
# Teaching Through Level Design

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Danger cue used as decoration -> Audit script; one cue, one meaning
> - Avoid: Try space with a way around -> Close the try space so only the mechanic exits
> - Avoid: Death in the try space -> Soft floor, instant retry
> - Visual language written down: one cue per meaning; audit scripts run after art passes.
> - Each new mechanic has show, try, test and combine spaces.
> - Demonstrations framed in the direction of travel, triggered on arrival.
>
> Read more (19 KB note): ## 2. Build a visual language and never break it · ## 8. Measure what the space taught · ## 11. Common mistakes · ## 12. Checklist
<!-- tldr:end -->

[[First-Time User Experience and Onboarding]] covers the first minutes as a product problem: the funnel, starter items, tutorial gating, the HUD reveal, five versions of one real tutorial and a server-side onboarding state machine. This note covers the part that lives in the world itself: how a space teaches a mechanic without a text box, how to build a visual language players learn once and trust forever, where to let players fail safely, when geometry should gate progress instead of UI, and how to measure what a space actually taught by putting trigger volumes on the map.

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

## 1. Why the world should teach

Roblox players skip text. Many are young, many play in a second language, many are on a phone where a dialogue box covers half the view. A tutorial that says "press Q to dash" fails for the touch player who has no Q, the console player who has no keyboard, and the player who closed the box. A gap that is too wide to jump, next to a glowing pad that launches you across, teaches dashing (or launching) to all of them.

Three reasons the world teaches better than UI (rule of thumb, consistent with platformer and action design practice):

1. **Players learn by doing, and remember what they did.** A mechanic used once to get past an obstacle sticks better than one read about.
2. **The world is persistent.** A sign disappears when closed; the gap stays, so a player who missed it can look again.
3. **The world scales across devices.** Space does not care about input method. Text that names keys does.

UI still has a job: naming controls the first time (adapted to the device), confirming success and recovering stuck players. The rule is "world first, UI second, text last".

## 2. Build a visual language and never break it

A visual language is a set of consistent cues that mean the same thing everywhere in the game. Once learned, it teaches every new area for free.

A starter language (adapt the colours to your art style; the point is consistency):

| Meaning | Cue | Rule |
|---|---|---|
| Walkable, safe | Neutral floor materials | Never use the danger cue on safe floors |
| Danger, kills or hurts | One colour and material (often red neon), plus motion or particles | Same everywhere, including decoration |
| Interactable | One accent colour or outline, plus a prompt on approach | Nothing else in the game uses that accent |
| Climbable | One material or trim (trusses, vines, ladders) | Do not put the climbable trim on walls you cannot climb |
| Breakable | Cracks, a distinct material | Everything that looks cracked breaks |
| Locked or not yet | Dim, desaturated, chained or veiled | Becomes bright when unlocked |
| Collectible | Spin, bob, glow | Never on hazards |
| Objective | A beam or beacon, a distinct light colour | Only one active objective at a time |

The rule that matters most is the last column. **One broken promise costs the whole language.** A decorative red neon strip on a safe walkway makes players doubt every red surface after it. A climbable-looking vine that is not climbable makes players stop trying vines. Audit for broken promises after every art pass, because art passes are where they come from: an artist adds red lights for mood, and the danger cue is diluted.

```lua
--!strict
-- Studio audit: find parts that use the danger material/colour but are not tagged as hazards.
-- Run from the command bar after art passes.
local CollectionService = game:GetService("CollectionService")

local DANGER_COLOR = Color3.fromRGB(255, 0, 0)
local DANGER_MATERIAL = Enum.Material.Neon
local TOLERANCE = 0.08

local function close(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < TOLERANCE and math.abs(a.G - b.G) < TOLERANCE and math.abs(a.B - b.B) < TOLERANCE
end

local suspects = 0
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.Material == DANGER_MATERIAL and close(d.Color, DANGER_COLOR) then
		if not CollectionService:HasTag(d, "Hazard") then
			suspects += 1
			print("Looks dangerous but is not a hazard:", d:GetFullName())
		end
	end
end
print(suspects, "suspect parts")
```

Run the reverse check too: every part tagged `Hazard` should use the danger cue.

## 3. The four beats of a teaching space

Each new mechanic gets a sequence of spaces. The obby version is teach, test, twist (see [[Genre Playbook - Obbies and Platformers]]); the general version has one extra beat at the start:

| Beat | Space | Failure cost | Example: a dash |
|---|---|---|---|
| **Show** | The mechanic happens in front of the player, done by something else | None | An NPC or enemy dashes across a gap as the player arrives |
| **Try** | A space where only the new mechanic works, and failing costs nothing | None (soft floor, instant retry) | A gap over a shallow pit with a ramp back up |
| **Test** | The mechanic with a real cost | Small (a checkpoint back) | The same gap over a kill floor |
| **Combine** | The mechanic with one already known | Normal | Dash then jump; dash through a sweeper's window |

Details that make each beat work:

- **Show: frame it.** The demonstration must happen where the camera already points: in the direction of travel, lit, ideally at the moment the player arrives (a trigger volume starts it). A demonstration behind the player is wasted.
- **Try: make the mechanic the only way.** If the player can walk around the gap, they will, and learn nothing. The try space should be closed on both sides so that the only exit uses the mechanic.
- **Try: make failure free and fast.** Falling into a shallow pit with a ramp back is better than dying: no respawn wait, no lost context. A death in the try space teaches "this is dangerous", not "this is how it works".
- **Test: the same shape, new consequence.** Reuse the try geometry with a kill floor or an enemy so the player recognises it.
- **Combine: only with known mechanics.** Combining two new things at once is a test of reading, not of skill.

## 4. Gate with geometry, not with UI

Geometry gates (a gap you cannot cross without the mechanic, a door that opens when the enemy dies) teach and check at once. UI gates (a modal that says "talk to the guide first") only interrupt.

| Gate type | Teaches | Risk |
|---|---|---|
| Geometry that needs the mechanic | The mechanic, by doing | Players without the mechanic are stuck; needs a stuck hint |
| A door opened by the objective | That objectives matter | Players miss the cause if the door is out of view |
| A locked gate with a price | The economy | Players who cannot afford it wait; pricing becomes level design (see [[Progression and Pacing Design]]) |
| UI modal gate | Nothing about the world | Interrupts; players close it unread |

Rules of thumb:

- **The cause and the effect must be in the same view.** If killing an enemy opens a door, the door must be visible from where the enemy dies. Otherwise players do not connect them.
- **Every geometry gate needs a recovery path** for players who do not get it: a stuck hint after some time (section 6), never a soft-lock.
- **Every step with a failure state is a gate, designed or not.** Measured in the reference project's live 7-day funnel: an eleven-step tutorial lost 31 percent at its first fight step, 34 percent at a forge step whose materials only dropped in combat, and about 82 percent at its elite ("boss") step (details in [[First-Time User Experience and Onboarding]] and [[Boss Fight Design Patterns]]). Put combat and other failure-prone beats after the safe ones, and make the first one tiny.

## 5. Direction without arrows

HUD arrows and distance markers ("GATE I, 47 studs") are reliable, but they teach players to watch the HUD instead of the world, and they become a crutch every later area depends on. Measured in the reference project: a tutorial waypoint pointing to the first gate with a live distance was later disabled when the tutorial was restructured, and the world had to carry that direction instead.

World-side tools, in rough order of strength (see also [[Level Design Principles - Flow Sightlines and Landmarks]]):

1. **Light.** The goal is the brightest or warmest thing in view.
2. **Motion.** Particles rising from the goal, birds flying toward it, an NPC walking there.
3. **Openings.** The only open gate, the only lit doorway.
4. **Paths and leading lines.** A path material that leads to the goal, lamps along it.
5. **Breadcrumbs.** Coins or pickups that run out where the route ends.

Use a HUD arrow as the fallback, shown only when the world has failed: after the player has been off route or stationary for a while (section 6). That keeps the arrow for players who need it without training everyone to depend on it.

## 6. Detecting stuck players and hinting

A player who has not made progress for a while needs help, but help that arrives too soon is patronising. A simple client-side approach:

```lua
--!strict
-- Client: show a hint if the player has not reached the current objective within HINT_AFTER
-- seconds, or has stayed within a small area for STILL_AFTER seconds while an objective is active.
-- The objective position is published by the server as a player attribute "ObjectivePos".
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local HINT_AFTER = 45
local STILL_AFTER = 12
local STILL_RADIUS = 10

local objectiveSince = os.clock()
local stillAnchor: Vector3? = nil
local stillSince = os.clock()
local hintShown = false

local function showHint(on: boolean)
	-- Replace with your UI: a soft arrow, a pulsing beacon at the objective, an NPC call-out.
	player:SetAttribute("HintVisible", on)
end

player:GetAttributeChangedSignal("ObjectivePos"):Connect(function()
	objectiveSince = os.clock()
	hintShown = false
	showHint(false)
end)

RunService.Heartbeat:Connect(function()
	local objective = player:GetAttribute("ObjectivePos")
	if typeof(objective) ~= "Vector3" or hintShown then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then return end

	local now = os.clock()
	if not stillAnchor or (root.Position - stillAnchor).Magnitude > STILL_RADIUS then
		stillAnchor = root.Position
		stillSince = now
	end

	if now - objectiveSince > HINT_AFTER or now - stillSince > STILL_AFTER then
		hintShown = true
		showHint(true)
	end
end)
```

Rules of thumb for hint design:

- **Escalate.** First a world cue (the objective's beacon pulses brighter), then a soft UI cue (an arrow at the screen edge), then explicit text. Most players need only the first.
- **Do not hint during combat.** A player standing still in a fight is fighting, not lost. Suppress hints while the player is in combat.
- **Tune the timers from data.** Look at how long players who succeed take (the median and the slow end). Set the first hint after most successful players would already have finished, so it only reaches people who are actually stuck.

## 7. Device-aware teaching in the world

The world is device-neutral, but prompts and hints are not.

- **Name the action, not the key, in world text.** "Dash across" on a sign; the HUD shows the device's control. See the device-aware text section in [[First-Time User Experience and Onboarding]] and [[Input - UserInputService and ContextActionService]].
- **Touch players cannot hold a key and look around at the same time easily.** Teaching spaces that need aiming and moving together are harder on phones; give them more room.
- **Gamepad players read the screen from a sofa.** World cues must be big; small floor decals do not read at TV distance. See [[Gamepad and Console UX]].
- **Test the teaching spaces on every device class** you support with someone who has never seen the game. See [[Multi-Client and Device Playtesting Protocols]].

## 8. Measure what the space taught

Put invisible trigger volumes at the teaching beats and log when players reach them. The funnel then shows exactly which space loses people.

Roblox docs (as of October 2026) describe `AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName, customFields?)`: all funnels start at step 1, steps are limited to 1 to 100, and skipped steps are counted as completed. That last point matters for spatial funnels: if a player bypasses a beat (jumps a wall, uses a shortcut), logging a later step marks the earlier ones complete, which hides the bypass. Log a separate custom event for bypasses if you care about them.

```lua
--!strict
-- Server: spatial onboarding funnel. Trigger volumes are invisible, non-colliding,
-- CanQuery parts tagged "TeachStep" with attributes Step (number) and StepName (string).
local AnalyticsService = game:GetService("AnalyticsService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local POLL = 0.5
local reached: { [Player]: number } = {}

Players.PlayerRemoving:Connect(function(p) reached[p] = nil end)

local function charactersParams(): OverlapParams
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then table.insert(list, p.Character) end
	end
	params.FilterDescendantsInstances = list
	return params
end

task.spawn(function()
	while true do
		task.wait(POLL)
		local params = charactersParams()
		for _, volume in CollectionService:GetTagged("TeachStep") do
			if not volume:IsA("BasePart") then continue end
			local step = volume:GetAttribute("Step")
			local name = volume:GetAttribute("StepName")
			if typeof(step) ~= "number" or typeof(name) ~= "string" then continue end
			for _, part in workspace:GetPartsInPart(volume, params) do
				local model = part:FindFirstAncestorOfClass("Model")
				local player = model and Players:GetPlayerFromCharacter(model)
				if player and (reached[player] or 0) < step then
					reached[player] = step
					AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
				end
			end
		end
	end
end)
```

Two production notes. First, onboarding funnels are meant for first-time players; only run this for players who have not completed onboarding (read that flag from their saved data), or veterans will flood step 1. Second, a volume at the **exit** of each beat is more informative than one at the entrance: the entrance shows who arrived, the exit shows who learned.

Reading the result: a big drop between "entered try space" and "left try space" means the try space does not teach (players cannot work out the mechanic). A big drop between "left try space" and "passed test" means the test is too hard, or the try space was too different from the test.

## 9. Worked example: teaching a ground slam

A combat game adds a ground slam that breaks cracked floors. Teaching sequence on the route from the hub to zone 2:

1. **Show.** As the player enters a courtyard, an elite enemy on a balcony slams, and the cracked floor beneath it collapses into a pit. Triggered by a volume at the courtyard entrance; the balcony is straight ahead and lit.
2. **Try.** The courtyard's only exit is a cracked floor tile over a 6-stud drop into a short tunnel. No enemies. Slamming anywhere else does nothing visible except a dust puff. A stuck hint fires after the player has been in the courtyard for 30 seconds without slamming: the cracked tile starts glowing.
3. **Test.** In zone 2, a pack of enemies stands on cracked floor. Slamming drops them into a pit; fighting them normally is possible but slower. The reward for using the slam is obvious.
4. **Combine.** Later, a cracked floor sits under a sweeper: slam in the safe window.

Funnel volumes: courtyard entrance (step 10), tunnel below the cracked tile (step 11), zone 2 pit (counted with a custom event when enemies fall). If step 11 drops sharply, the try space is not teaching; the first thing to check is whether the cracked tile reads as cracked at the camera's distance and on a phone.

## 10. When not to teach in the world

- **Systems with no spatial component** (inventory management, trading, crafting recipes) are better taught in their UI, at the moment of first use.
- **Optional depth** (advanced combos, speedrun tech) should not have teaching spaces at all; players who want it discover it, and teaching it to everyone adds friction.
- **Very short sessions** (a round game whose round lasts 3 minutes) may not have room for a show-try-test sequence; teach the one thing that matters in the lobby instead.

## 11. Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Danger cue used as decoration | Players avoid safe areas or die on "safe" ones | Audit script; one cue, one meaning |
| Try space with a way around | Players skip learning, fail the test | Close the try space so only the mechanic exits |
| Death in the try space | Players learn fear, not the mechanic | Soft floor, instant retry |
| Cause and effect out of view | Door opens, nobody notices why | Same view for trigger and result |
| Arrows from minute one | Players never look at the world | World cues first; arrows only as a stuck fallback |
| Key names in world text | Touch and console players confused | Name the action; HUD shows the device control |
| Funnel volumes at entrances only | Cannot tell arrival from learning | Volumes at each beat's exit |
| Onboarding funnel for everyone | Step 1 swamped by veterans | Log only for first-time players |

## 12. Checklist

- [ ] Visual language written down: one cue per meaning; audit scripts run after art passes.
- [ ] Each new mechanic has show, try, test and combine spaces.
- [ ] Demonstrations framed in the direction of travel, triggered on arrival.
- [ ] Try spaces closed, failure free and fast.
- [ ] Geometry gates have stuck hints with escalation; no soft-locks.
- [ ] Direction carried by light, motion, openings and paths; arrows only as fallback.
- [ ] World text names actions, not keys; teaching spaces tested on phone, PC and gamepad.
- [ ] Funnel volumes at the exit of each beat, logged only for first-time players.

## See also

- [[Level Design Start Here]], [[First-Time User Experience and Onboarding]], [[Level Design for Roblox]].
- [[Level Design Principles - Flow Sightlines and Landmarks]], [[Obby and Platforming Level Design]], [[Combat Arena and Encounter Layout]].
- [[Analytics and Funnels]], [[Accessibility]], [[HUD Design]], [[Quests and Objectives]].
- [[Boss Fight Design Patterns]], [[Progression and Pacing Design]].

## Connected notes
<!-- auto-links:start -->
[[Onboarding Funnel]] · [[Core Loops and Session Design]] · [[Spawn Points Safe Zones and Respawn Flow]] · [[Genre Playbook - Puzzle and Escape Rooms]] · [[Pathfinding Edge Cases and Fallbacks]] · [[UI Motion Language and Timing]]
<!-- auto-links:end -->
