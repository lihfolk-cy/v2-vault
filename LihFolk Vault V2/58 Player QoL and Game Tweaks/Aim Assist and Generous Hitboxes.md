---
tags: [qol, game-tweaks, aim-assist, hitboxes, mobile, controller, fairness, combat, server-authority, type/guide, area/gameplay, area/game-feel, level/advanced, api/Camera, api/WorldRoot]
---
# Aim Assist and Generous Hitboxes

<!-- tldr:start -->
> [!tldr] TL;DR
> - Touch players cannot hit anything: No assist or tolerance -> Friction, small bend cone, generous server checks
> - Mouse players dominate or complain: Assist for all inputs -> Scale by active input
> - Assist locks through walls: No line-of-sight check -> Raycast before assisting
> - Assist scaled by active input; Off/Low/Standard setting.
> - Friction first; magnetism and bend only where needed.
> - Line of sight required; teammates excluded; search throttled.
>
> Cost: TL;DR ~160 tok · whole note ~2.1k tok. Read more: ## 3. Friction and target selection (client) · ## 4. Generous hitboxes on the server · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Precise aiming is hard on a phone touchscreen and on a thumbstick, and Roblox games mix all three input types in the same server. Aim assist and slightly generous hitboxes make combat feel fair to touch and controller players without handing mouse players an advantage or opening an exploit. This note covers the forms of assist that work, how to scale them per input type, generous hit validation on the server, and where the line with cheating sits. Hit detection architecture is in [[Hitboxes and Hit Detection]]; exploit checks in [[Detecting Combat Exploits - Reach Rate and Aim]].

Sources: **Roblox docs** for `Camera:ViewportPointToRay` (https://create.roblox.com/docs/reference/engine/classes/Camera), `WorldRoot:Spherecast` / `Raycast` (https://create.roblox.com/docs/reference/engine/classes/WorldRoot) and `UserInputService.PreferredInput` (https://create.roblox.com/docs/reference/engine/classes/UserInputService). Strength values are **Rule of thumb**. Whether Roblox currently ships a first-party aim-assist module is **Unverified**; check the Creator Hub before building your own.

## 1. Forms of assist (weakest to strongest)

| Form | What it does | Typical use |
|---|---|---|
| Generous hit volume | Projectiles or melee sweeps slightly larger than visuals | All inputs, all games |
| Friction (slowdown) | Camera sensitivity drops while the reticle is over a target | Controller, touch |
| Magnetism (pull) | Reticle drifts toward a target while the player is already turning toward it | Controller, touch |
| Bullet bending | Shot direction nudged toward a target within a small cone | Touch-first casual games |
| Lock-on | Camera follows a chosen target | Melee/action, opt-in |

Start with the weakest forms. Friction is the least noticeable and most accepted; strong magnetism feels like the game is playing itself.

## 2. Scale by input, not by device

Use the **active** input, since players switch mid-session (`UserInputService.PreferredInput`, **Roblox docs**):

| Input | Friction | Magnetism | Bend cone |
|---|---|---|---|
| Keyboard and mouse | Off | Off | Off |
| Gamepad | Medium | Low | Off or tiny |
| Touch | Medium | Medium | Small (a few degrees) |

Expose **Aim assist: Off / Low / Standard** in settings for controller and touch players. In ranked or competitive modes, consider limiting assist or showing input type in the scoreboard so players understand matchups.

## 3. Friction and target selection (client)

```lua
--!strict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local camera = workspace.CurrentCamera
local MAX_RANGE = 150
local CONE_DEG = 6

-- Returns the best target part near the screen centre, or nil.
local function findAssistTarget(): BasePart?
	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local best: BasePart? = nil
	local bestScore = math.huge
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Players.LocalPlayer.Character :: Instance }
	for _, model in CollectionService:GetTagged("Targetable") do
		local part = (model :: Model).PrimaryPart
		if part == nil then continue end
		local offset = part.Position - origin
		local dist = offset.Magnitude
		if dist > MAX_RANGE or dist < 1 then continue end
		local angle = math.deg(math.acos(math.clamp(look:Dot(offset.Unit), -1, 1)))
		if angle > CONE_DEG then continue end
		local hit = workspace:Raycast(origin, offset, params) -- line of sight
		if hit and not hit.Instance:IsDescendantOf(model) then continue end
		local score = angle + dist * 0.02
		if score < bestScore then best, bestScore = part, score end
	end
	return best
end

-- Multiply camera input by this each frame.
local function frictionScale(strength: number): number
	return if findAssistTarget() then 1 - 0.4 * strength else 1
end
```

Points:
- **Line of sight** is mandatory; never assist through walls.
- **Run selection at a modest rate** (every other frame, or 20 Hz) and only for tagged targets near the screen centre, not for every model in the world.
- **Teammates and friendly NPCs** are excluded by tag.
- Apply friction inside your camera input path, after Roblox sensitivity ([[Camera Settings - FOV Shake Sensitivity and Shift-Lock]]).

## 4. Generous hitboxes on the server

Generosity belongs in **server validation**, because that is where hits are accepted:

- **Slightly larger target volume** than the visual (for example a sphere cast with a radius a little bigger than the projectile, or melee sweeps with a few studs of tolerance).
- **Latency tolerance**: validate against where the target was recently, not only where it is now, within a bounded window ([[Client Prediction and Reconciliation for Combat]]).
- **Bounded**: tolerances are constants you can reason about. A reach check still rejects hits far outside them ([[Detecting Combat Exploits - Reach Rate and Aim]]).

```lua
--!strict
-- Server: accept a melee hit if the target was within reach plus tolerance.
local BASE_REACH = 7
local TOLERANCE = 2.5 -- generosity + latency, studs

local function validateMelee(attacker: Model, target: Model): boolean
	local a = attacker.PrimaryPart
	local t = target.PrimaryPart
	if a == nil or t == nil then return false end
	return (a.Position - t.Position).Magnitude <= BASE_REACH + TOLERANCE
end
```

Asymmetry rule (**Rule of thumb**): being hit should feel fair too. Make hurtboxes for **incoming** hits on players no larger than visuals, while outgoing hit checks are generous. Players forgive "I hit them" far more easily than "that missed me by a mile".

## 5. Where assist becomes a problem

- **Assist must not be client-authoritative for hits.** The client can bend its aim request; the server still validates range, line of sight and rate.
- **Exploit overlap**: aimbots look like extreme magnetism. Server-side aim statistics should account for legitimate assist levels, which is another reason to keep assist modest.
- **PvE vs PvP**: be more generous in PvE; nobody complains that the dragon was too easy to hit.
- **Disclose**: list assist in settings with a description; hidden assist erodes trust when players notice.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Touch players cannot hit anything | No assist or tolerance | Friction, small bend cone, generous server checks |
| Mouse players dominate or complain | Assist for all inputs | Scale by active input |
| Assist locks through walls | No line-of-sight check | Raycast before assisting |
| Being hit feels unfair | Generous incoming hurtboxes | Generous outgoing, accurate incoming |
| Frame drops in big fights | Target search every frame over everything | Tagged targets, throttled |
| Exploiters hide behind "assist" | Client-trusted hits | Server validation with bounded tolerance |

## Checklist

- [ ] Assist scaled by active input; Off/Low/Standard setting.
- [ ] Friction first; magnetism and bend only where needed.
- [ ] Line of sight required; teammates excluded; search throttled.
- [ ] Server validation generous but bounded; incoming hurtboxes accurate.
- [ ] Assist disclosed; competitive modes considered.

## See also

- [[Hitboxes and Hit Detection]]
- [[Genre Playbook - Shooters FPS and TPS]]
- [[Dot and Cross Products in Gameplay]]
- [[Making Numbers Feel Good - Cooldowns Buffering and Coyote Time]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Detecting Combat Exploits - Reach Rate and Aim]] · [[Controller Support QoL]] · Difficulty Options and Cognitive Load
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[QoL Audit Checklist]] · [[Top 25 QoL Wins by Effort]] · [[Accessibility Cross-Links for QoL Settings]] · [[Settings Menu Essentials and Persistence]] · [[Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots]] · [[Mobile Button Layout Editor]] · [[Confirmation and Undo Patterns for Destructive and Paid Actions]] · [[Colourblind Palettes Text Size and Tooltips]]
<!-- related:end -->
