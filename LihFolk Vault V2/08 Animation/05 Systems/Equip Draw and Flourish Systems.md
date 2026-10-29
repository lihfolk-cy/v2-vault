---
tags: [systems, equip, flourish, weapons, networking, procedural, type/guide, area/animation, level/intermediate, area/networking]
---
# Equip Draw and Flourish Systems

<!-- tldr:start -->
> [!tldr] TL;DR
> - Flourish cancelled immediately on equip: A carry or other non-action layer at Action2+ -> Keep non-actions below Action2
> - Wrist snaps at the end: Flourish end pose differs from the hold -> One shared end pose (blade over shoulder)
> - Toss looks too heavy: `workspace.Gravity` used -> Gravity scaled to character height
>
> Cost: TL;DR ~120 tok · whole note ~3.5k tok. Read more: ## Choosing and starting a flourish · ## The blade: procedural maths · ## Common mistakes
<!-- tldr:end -->

An equip flourish is the short show-off a character performs when a weapon comes into the hand: a spin, a toss and catch, a salute, a katana draw. It is pure presentation, it runs constantly (every equip, every respawn), and every other player sees it, so it touches more systems than its size suggests: networking, priorities, cancel rules, procedural weapon motion, audio sync and energy-blade ignition. This note documents the system as built and iterated in one live action game (the reference project), through four versions.

## What a flourish is made of

Each flourish is about **3 seconds**: anticipation, the move, follow-through, a held hero pose. It splits into three tracks that run on one clock:

| Part | How it is produced | Who plays it |
|---|---|---|
| Body | A clip keying **only UpperTorso, Head and the right arm**, at Action2. Legs, hips and left arm unkeyed so running continues. Newer flourishes add a `<Name>Legs` layer that fades out with speed | The owner's client (it replicates like any Animator clip) |
| Blade | Procedural, through the grip joint's `C0`: spins, tosses, catches, wrist give, re-grips | **Every client**, for every holder, on the same clock |
| Sound and VFX | Cues on visible beats: the draw, each revolution, the catch | Every client |

Why the blade is procedural and not keyed: a clip can only move the weapon rigidly with the hand. A toss needs the weapon to be a free body following a parabola, spinning about its own centre of mass, then landing in a hand that moved in the meantime. That is a few lines of maths and impossible to key cleanly.

Body-angle convention used by the authoring tools (write yours down too): `rx > 0` leans back / chin up; `ry > 0` turns left.

## Choosing and starting a flourish

1. **The server picks.** On every equip the server picks one flourish from the pool (never the same twice running for that player) and stamps it on the Tool as an attribute (`Flourish = "<Name>"`).
2. **The owner's client starts it when it can be seen**: immediately, or 0.15 s after the backpack screen closes if the player equipped from it. A flourish played behind a full-screen menu is wasted.
3. **The client tells the server**: `EquipFlourish:FireServer(name)`.
4. **The server validates and relays** to every other client.
5. Other clients play **the blade half** on that player (the body clip already replicates).

```lua
-- Server relay (generic version of the reference service).
local Players = game:GetService("Players")
local relay: RemoteEvent = game:GetService("ReplicatedStorage").Remotes.EquipFlourish
local last: { [Player]: number } = {}

relay.OnServerEvent:Connect(function(player: Player, name: unknown)
	if type(name) ~= "string" then return end
	local now = os.clock()
	if last[player] and now - last[player] < 1 then return end -- at most one per second per player
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	-- only the flourish the server itself stamped on the held tool is accepted
	if not (tool and tool:GetAttribute("Flourish") == name) then return end
	last[player] = now
	for _, other in Players:GetPlayers() do
		if other ~= player then relay:FireClient(other, player, name) end
	end
end)
Players.PlayerRemoving:Connect(function(p) last[p] = nil end)
```

Why the server picks instead of the client: the validation is then trivial (match against your own stamp), exploiters cannot spam arbitrary names, and the "never twice running" rule lives in one place. Why the client decides **when**: only it knows whether the player can see their character.

### Late joiners and Lua-played bodies

When body clips moved to a Lua keyframe player (so they work without published ids; see [[Lua Keyframe Player]]), the body no longer replicated by itself. The reference fix was attributes set by the owner: `FlourishName`, `FlourishT0` (start time) and `FlourishSampled`. Every client samples the body from the same KeyframeSequence at `now - FlourishT0`, which also lets a client that streams the character in late join the flourish part-way. A published id in the flourish data table still overrides through the real Animator.

## The blade: procedural maths

### Spins

The blade rotates about the forearm axis around the grip point. Angular velocity is **cosine-ramped** in and out so the spin accelerates and settles instead of starting at full speed:

```lua
-- Angle (radians) at time t of a spin of `turns` revolutions lasting `dur` seconds,
-- with a cosine ease (0 velocity at both ends). Integral of the eased velocity.
local function spinAngle(t: number, dur: number, turns: number): number
	local u = math.clamp(t / dur, 0, 1)
	-- smooth 0..1 progress whose derivative is 0 at u = 0 and u = 1
	local eased = 0.5 - 0.5 * math.cos(math.pi * u)
	return eased * turns * 2 * math.pi
end

-- Applied to the grip joint every frame (RenderStepped on every client):
-- grip.C0 = restC0 * CFrame.new(gripPoint) * CFrame.fromAxisAngle(forearmAxis, spinAngle(t, dur, turns)) * CFrame.new(-gripPoint)
```

Spins can be **segment lists** (spin 2 turns, pause, spin 1 back), which v4 added because single spins all looked alike.

### Tosses

In the air the weapon is a free body:
- Its **centre of mass follows a parabola** under `G = 47.6 studs/s^2`, computed in the body's frame so it follows the running player.
- It **turns at a steady rate** about the body's forward axis (a free body spins at constant angular velocity).
- It lands in the closing hand, and the **wrist "gives"** with a damped rotation carrying the leftover spin.

Why 47.6 and not `workspace.Gravity` (196.2 by default): 47.6 studs/s^2 is 9.81 m/s^2 scaled to an avatar about 8.7 studs tall standing in for a human of about 1.8 m. Using workspace gravity makes a toss look like it was thrown on a heavy planet, because Roblox gravity is tuned for jump arcs, not human-scale objects. This is a good general rule for any human-scale prop motion: **scale real gravity to your character's height**, not to the physics engine.

```lua
-- Toss flight: position of the centre of mass at time t after release, in the body's frame.
local G = 47.6 -- studs/s^2: 9.81 m/s^2 at an ~8.7 stud avatar
local function tossPos(releasePos: Vector3, releaseVel: Vector3, t: number): Vector3
	return releasePos + releaseVel * t + Vector3.new(0, -0.5 * G * t * t, 0)
end
-- To land at catchPos after flight time T: releaseVel = (catchPos - releasePos) / T + Vector3.new(0, 0.5 * G * T, 0)
```

Solving for the release velocity from the catch point (last line) is how the toss lands exactly in the hand: the animator authors where the hand releases and where it catches, the code fills in the arc.

### Hand work

Later passes added:
- **HandRoll**: a procedural wrist and forearm roll that follows the spin, so the hand visibly works the hilt.
- **Regrip**: a 0.08 s re-grip on a beat, and no slides during holds (the blade must not drift in the palm while "held").
- A scabbard roll of -40 degrees for draw flourishes.
- A per-weapon grip slide for long pommels.

## The end pose rule

**Every flourish ends with the blade resting back over the right shoulder.** The v3 end pose (blade hanging back-down from a relaxed arm) required a wrist twist of about 180 degrees to get back to the normal hold, which played as a visible wrist snap on every equip. Ending all flourishes on one shared rest pose means whatever plays next (idle, carry, a swing) blends from a known pose. The same principle governs combo end poses in [[Combat Combo Systems]].

## Cancel rules

A flourish is the lowest-importance animation in the game; anything else wins. It cancels at once on:
- any other **Action2 or higher** track (the default `Animate` script's tracks are ignored),
- dashing, guarding, being downed, death,
- the tool leaving the character.

It is also skipped during the intro cutscene. Cancelling gives the blade back to the hand immediately (grip `C0` restored).

While a flourish or draw plays, **swings are blocked** (an "equip lock"). Without it, a player who clicks on equip gets a swing blended into the middle of a toss.

Consequence for every other system: **nothing that is not an action may play at Action2+.** The carry layer had to drop to Action for this reason (see [[Locomotion Systems]]). Watching for "any Action2+ track" is a cheap, robust cancel rule, but it turns priority into a global contract.

## Baking flourish body clips

The flourish bodies were baked densely with **Linear easing** rather than using Roblox easing styles:
- Keys are joined per channel (joint [[quaternions]] plus offsets) with PCHIP (monotone cubic, no overshoot); "stop" keys are dead stops.
- Baked adaptively at **0.3 degrees / 1.2 rad/s turn-rate** tolerance: about 130 to 205 keys per clip, about 6.5k instances per set (before clip stubbing removed the instance cost; see [[Baked Clip Stubs and Archiving]]).

Why avoid Roblox easing here: the legacy `Cubic` pose easing runs backwards (In eases out, measured), and Elastic and Bounce directions were contradictory across measurements (see [[Keyframes, Easing and Interpolation]] and [[Open Questions]]). Dense Linear keys remove all of that ambiguity, at the cost of key count.

QA for flourishes ran on the real dummy with the real held tool: floor clearance, blade-through-body spans (which part, how far along the blade), grip velocity and spin-rate jumps, toss release and catch velocities, and filmstrips. See [[Animation Review Checklist]].

## The pool

The reference pool grew to 12 flourishes (spins, a salute, butterfly, cyclone, comet and others), an aerial 720 (pick weight 0.6, it is the most dramatic and gets tiring), a "Manifest" (the blade materialises in the hand) and kit-specific draws. Weapon-shape rules:
- Katanas use a katana draw (the sheath materialises, an iaido draw as a rising cut, the sheath dematerialises). Earlier notes say katanas drew 35% of the time; later notes say the 11 katanas always use it. The later rule is the current one; the change is a design decision, not an error.
- Staffs always use a twirl.
- One energy weapon never gets Manifest (its ignition is the show).
- Flourishes replay on respawn.

## Energy blade ignition

Energy weapons turn on: the blade grows out of the hilt. The reference system does it procedurally on the held model:

1. **Find the blade parts**: parts running past 45% of the weapon's reach without dipping into the grip region.
2. **Hide them** with `LocalTransparencyModifier` (per-client, does not replicate, does not fight other scripts that set `Transparency`).
3. **Grow welded stand-ins** from the base along the trail axis, with a white-hot leading tip while racing out, a tip flare and sparks, a core streak, pre-on crackles, and a flash on lock-on.
4. **Swap back** to the real parts when fully grown.

Growth timing is measured from audio: for each ignition sound take, the blade reaches full length when half the energy of the first 0.7 s of the sound has been spent, which gave 0.18 to 0.40 s per take, then divided by the voice's playback pitch (a pitched-up take ignites faster). Animation timed from sound analysis is a powerful trick: the sound designer's choice drives the visual.

Variants of turn-on, chosen per model by an attribute: `ignite` (grow), `condense` (gather in from particles) and `scan` (a line sweeps along the blade).

### Waiting for the reveal

When a flourish **draws** an energy blade from somewhere (a sheath, thin air), ignition must wait for the moment the hilt is visible. The flourish data sets a reveal time on the Tool (`FlourishRevealAt`: Manifest 0.98 s, katana draw 0.93 s), and the ignition holds its pre-on sound and growth until then, with a 1.5 s fallback if no flourish reports a reveal. Without this, the blade ignited inside the sheath.

## Audio alignment

Each sound in the flourish palette was measured for **onset and peak** (for example a draw scrape peaking at 0.37 s, a quick swish at 0.13 s). Cues are started at `beat_time - peak` so the loudest moment lands on the visible beat. Starting a sound at the beat puts its peak a quarter second late, which reads as sloppy even to players who could not say why. Energy blades use their own sound font, whose hum follows the blade's angular speed by itself. See [[VFX Timing with Animation]].

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Flourish cancelled immediately on equip | A carry or other non-action layer at Action2+ | Keep non-actions below Action2 |
| Wrist snaps at the end | Flourish end pose differs from the hold | One shared end pose (blade over shoulder) |
| Toss looks too heavy | `workspace.Gravity` used | Gravity scaled to character height |
| Others see the body but not the blade spin | Only the body replicates | Relay the name; blade on every client |
| Blade ignites inside the sheath | Ignition not waiting for the reveal | Reveal timestamp with fallback |
| Swing blended into a toss | No equip lock | Block swings while flourishing |
| Flourish never seen | Played behind the backpack menu | Start when visible |

See also: [[Weapon and Combat Animation]], [[Procedural Weapon Motion]], [[Custom Rigs - Weapons and Props]], [[Replication and Ownership]], [[Tween and CFrame Animation of Objects]].

## Connected notes
<!-- auto-links:start -->
[[Weapon Swing Design]] · [[Troubleshooting Table]] · [[Playback, Priorities and Blending]] · [[Sound Design for Games]] · Modeling Weapons and Props · Tools and Inventory Systems · [[Animation Start Here]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Combat Animation Craft]] · [[Snippets - Procedural Motion]] · [[Custom Locomotion Controller Design]] · [[Ability Kits Architecture]] · [[Pipeline - New Animated Weapon]] · [[Stance and Charge Moves]] · [[Animation Editor Workflow]] · [[Spec-Driven Move Authoring]]
<!-- related:end -->
