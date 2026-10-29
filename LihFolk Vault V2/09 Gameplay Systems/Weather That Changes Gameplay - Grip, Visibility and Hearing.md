---
tags: [weather, gameplay, vehicles, ai, perception, movement, anti-exploit, type/guide, area/gameplay, area/networking, level/intermediate, api/GetAttribute, api/CustomPhysicalProperties]
---
# Weather That Changes Gameplay - Grip, Visibility and Hearing

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Gameplay reads client-rendered fog -> Server multipliers; server-side reveal rules
> - Avoid: Grip snaps on state change -> Blend gameplay at the visual blend rate
> - Avoid: Shelter differs between server and client -> Same zone volumes for both
> - One shared module returns blended grip, sight and hearing multipliers.
> - Server decisions use server state; clients use it only for prediction and UI.
> - Shelter factor from the same zone volumes as the rain renderer.
>
> Cost: TL;DR ~160 tok · whole note ~3.1k tok. Read more: ## 1. One source of truth: multipliers · ## 2. Grip: vehicles and movement · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Cosmetic weather is easy. Weather that changes the game (cars slide in rain, guards see less in fog, footsteps are masked by a storm) is where architecture mistakes become exploits or unfair moments. The rule that drives everything here: **gameplay effects read the server's weather state and server-owned multipliers, never what the client renders.** Fog, rain particles and sound are local and can be deleted by an exploiter; a sight multiplier on the server cannot. This note shows how to expose weather as a few multipliers, then wires them into movement, vehicles, NPC perception, stealth and ranged combat, with the fairness rules that keep players from feeling cheated.

Source labels: **Roblox docs** (create.roblox.com, as of October 2026), **Rule of thumb**, **Unverified**. Code is strict Luau, reviewed, not run.

---

## 1. One source of truth: multipliers

The weather director ([[Weather System Architecture - State Machine, Transitions and Replication]]) already holds the state and blend. Expose the gameplay side as blended multipliers from the same defs table, through a tiny shared module that works on server and client:

```lua
--!strict
-- ReplicatedStorage/WeatherEffects
local Workspace = game:GetService("Workspace")
local Defs = require(script.Parent:WaitForChild("WeatherDefs"))

export type Effects = { grip: number, sight: number, hearing: number }

local WeatherEffects = {}

function WeatherEffects.current(): Effects
	local from = Defs[Workspace:GetAttribute("WeatherFrom") :: string]
	local to = Defs[Workspace:GetAttribute("WeatherState") :: string]
	if not from or not to then
		return { grip = 1, sight = 1, hearing = 1 }
	end
	local start = (Workspace:GetAttribute("WeatherStart") :: number?) or 0
	local blend = math.max((Workspace:GetAttribute("WeatherBlend") :: number?) or 1, 0.01)
	local a = math.clamp((Workspace:GetServerTimeNow() - start) / blend, 0, 1)
	local f, t = from.gameplay, to.gameplay
	return {
		grip = f.grip + (t.grip - f.grip) * a,
		sight = f.sight + (t.sight - f.sight) * a,
		hearing = f.hearing + (t.hearing - f.hearing) * a,
	}
end

return WeatherEffects
```

Why blended: if grip snaps from 1.0 to 0.7 the instant the state flips, drivers mid-corner spin out with no warning. Blending gameplay at the same rate as visuals means the road gets slippery as it visibly gets wet (Rule of thumb). Clients may call `current()` for **prediction and UI** (a "slippery" HUD icon, local vehicle handling); the server calls it for **decisions**.

**Zones override weather.** Indoors, in tunnels and under bridges there is no rain. Multiply weather effects by a per-zone shelter factor resolved on the server from the character's position ([[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]]). If the server's zone check and the client's rain shelter test disagree, the player sees dry ground but slides; use the same zone volumes for both.

## 2. Grip: vehicles and movement

### Raycast and arcade cars

If your car computes tyre forces in code ([[Choosing a Car Chassis - Raycast Suspension vs Constraint Builds vs Community Kits]], [[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]]), weather is one multiplier on the lateral grip coefficient (and a smaller one on longitudinal grip, so braking distances grow). The car is simulated by the owning client, so the client must apply the multiplier too, read from the shared module. The server's job is to validate that the result is plausible ([[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]]); an exploiter ignoring rain grip gains cornering speed, which a lap-time or lateral-acceleration sanity check catches, not the weather system.

Rules of thumb:
- Lateral grip 0.75-0.85 in rain, 0.55-0.7 on snow and ice. Below ~0.5 arcade cars become unfun for most players.
- Reduce top steering lock less than grip so the car still turns; players blame controls, not weather, when the car will not turn at all.
- Show it: wet road sheen, spray particles from tyres, and a dashboard icon.

### Constraint cars

Constraint-wheel cars get grip from physical friction. Changing wheel `CustomPhysicalProperties` (friction and friction weight) at runtime works, but property writes on the server replicate and the owning client simulates the wheels, so write the change where it takes effect for the owner. Whether a client-side friction write on an assembly it owns is honoured identically by the server for physics: **Unverified**; prefer to set it on the server once per weather change (a few parts, rare writes) and let it replicate. `CustomPhysicalProperties` docs: https://create.roblox.com/docs/reference/engine/datatypes/PhysicalProperties.

### On-foot movement

The default Humanoid walk does not model traction meaningfully for gameplay tuning, and material friction on the floor is not a dependable lever for walking characters (Rule of thumb). If on-foot slipping matters (ice levels, storms), implement it in your movement code: lower `WalkSpeed` slightly in deep snow on the server, and if you have a custom controller, reduce acceleration and deceleration so characters skid ([[Custom Character Controllers]]). The 2025-2026 server-authority and input changes ([[Server Authority and Input Migration 2026]]) make server-owned movement modifiers easier to keep honest if you adopt them.

## 3. Visibility: NPC sight and player view

### NPC perception

NPC sight range is pure server logic, so weather plugs in cleanly:

```lua
--!strict
local WeatherEffects = require(game:GetService("ReplicatedStorage"):WaitForChild("WeatherEffects"))

local BASE_SIGHT = 120 -- studs
local function canSee(npcHead: BasePart, target: BasePart, params: RaycastParams, inShelter: boolean): boolean
	local sight = BASE_SIGHT * (if inShelter then 1 else WeatherEffects.current().sight)
	local offset = target.Position - npcHead.Position
	if offset.Magnitude > sight then return false end
	if npcHead.CFrame.LookVector:Dot(offset.Unit) < 0.4 then return false end -- ~66 degree half-angle
	local hit = workspace:Raycast(npcHead.Position, offset, params)
	return hit == nil or hit.Instance:IsDescendantOf(target.Parent :: Instance)
end
```

Add a "close range always seen" floor (e.g. 15 studs) so heavy fog never lets players stand next to a guard unseen; that looks like a bug, not weather (Rule of thumb). Wire the result into your NPC brain ([[Behaviour Trees Utility AI and State Machines for NPCs]]).

### Player visibility and exploits

Fog, Atmosphere density and particles are rendered by each client. An exploiter can remove them and see across the whole map, and a low-end player on reduced weather quality also sees further than a high-end player. Consequences:

- **Never make fog the only hiding mechanic** in competitive PvP. Combine it with server-side rules: nametags and outlines hidden beyond weather sight range (server decides who is "revealed"), minimap blips limited by weather sight, and streaming or interest management for truly hidden information ([[Interest Management and Per-Player Replication]]).
- **Quality tiers must not change visibility.** Keep Atmosphere density identical on every tier and reduce only particles ([[Weather Performance Budgets and Quality Tiers]]).
- Ranged weapons: increase spread or reduce maximum effective range in heavy storms on the server, rather than hoping players cannot see.

## 4. Hearing: masking and detection

Two separate things:

1. **NPC hearing (server).** Footstep and gunshot "noise events" carry a loudness radius; NPCs within `radius * hearing` react. A storm with `hearing = 0.6` lets players sneak closer. Thunder can also briefly mask: drop hearing to ~0.3 for 1-2 s after a nearby strike, which creates a fun stealth beat ([[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]]).
2. **Player hearing (client).** Rain and wind loops raise the ambience bed and naturally mask distant footsteps. Do not lower footstep volumes for fairness-critical cues (an enemy behind you) beyond what the mix implies. Duck the weather bed slightly when combat sounds play so cues stay audible ([[Spatial Audio and Mixing]], [[Captions and Audio Accessibility]]).

Players who mute weather ambience or use captions must not gain or lose information. Directional cues should come from footsteps and indicators, not from weather masking.

## 5. Fairness and design rules

- **Telegraph before it matters.** A state that cuts grip should be preceded by visible clouds and light rain; the forecast walk in the architecture note only reaches Storm through Rain.
- **Never change weather mid-race or mid-round** if it affects the outcome, unless every participant gets the same conditions. Lock weather at round start for competitive modes, or schedule changes between rounds.
- **Show the effect in UI.** A small weather chip ("Rain: grip -20%") turns frustration into strategy.
- **Give counterplay.** Snow tyres, rain-specific perks, fog-piercing gadgets. Weather that only punishes feels like random loss.
- **Balance rewards.** If storms grant luck or currency multipliers, make the server the only authority and do not let clients claim a storm.

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Gameplay reads client-rendered fog | Exploiters delete fog and see everything | Server multipliers; server-side reveal rules |
| Grip snaps on state change | Mid-corner spin-outs | Blend gameplay at the visual blend rate |
| Shelter differs between server and client | Dry ground but sliding | Same zone volumes for both |
| Fog quality tied to graphics level | Low-end players see further | Same density on all tiers; scale particles only |
| Weather flips mid-race | Unfair results | Lock per round or apply to all equally |
| Guards blind at point-blank in fog | Looks broken | Close-range detection floor |
| Grip below ~0.5 for arcade cars | Undriveable, players quit | Floor grip, keep steering responsive |

## Checklist

- [ ] One shared module returns blended grip, sight and hearing multipliers.
- [ ] Server decisions use server state; clients use it only for prediction and UI.
- [ ] Shelter factor from the same zone volumes as the rain renderer.
- [ ] Vehicle grip applied on the owning client and sanity-checked on the server.
- [ ] NPC sight and hearing scaled, with a close-range floor.
- [ ] Visibility identical across quality tiers; no fog-only hiding in PvP.
- [ ] Competitive rounds lock weather or apply it to all equally.
- [ ] HUD shows active weather effects.

## See also

[[Weather System Architecture - State Machine, Transitions and Replication]] · [[Steering Geometry and Arcade Drifting - Ackermann, Slip and Grip Tuning]] · [[Vehicle Ownership and Anti-Exploit - Server-Checked Driving]] · [[Cars with Constraints - Suspension Steering and Drive]] · [[Behaviour Trees Utility AI and State Machines for NPCs]] · [[Interest Management and Per-Player Replication]] · [[How Exploits Work - The Client Boundary]] · [[Custom Character Controllers]] · [[Spatial Audio and Mixing]] · [[Captions and Audio Accessibility]]

## Connected notes
<!-- auto-links:start -->
[[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · Weather Performance Budgets and Quality Tiers · [[Raycasts Shapecasts and Spatial Queries]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Chase Cameras and Speed Effects for Vehicles]] · [[NPC AI and Behaviour]] · [[Police Chases and Wanted Levels]] · [[AI Difficulty Tuning - Reaction Time, Aim Error and Fair Misses]] · [[Visual AI Debugging - State Labels, Path Lines and Perception Gizmos]] · [[Ranged Enemy Tactics - Cover Points, Line of Sight and Peeking]] · [[Squad AI - Attack Tokens, Flanking and Attacker Limits]] · [[Pathfinding Edge Cases and Fallbacks]]
<!-- related:end -->
