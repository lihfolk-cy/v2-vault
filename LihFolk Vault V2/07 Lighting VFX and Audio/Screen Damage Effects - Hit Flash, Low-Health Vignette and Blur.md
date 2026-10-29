---
tags: [vfx, post-processing, damage, vignette, hit-flash, blur, colorcorrection, accessibility, ui, type/guide, area/vfx, level/intermediate]
---
# Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Several scripts tweening the same `ColorCorrectionEffect`.
> - Avoid: Effects parented to `Lighting` in a game that also uses lighting zones.
> - Avoid: Uncapped stacking. Shotguns and DoT ticks white out the screen.
> - One client module owns every screen effect instance.
> - Hits are pulses; low health is a level; both capped.
> - Damage effects driven by server-confirmed events, with source position for a directional indicator.
>
> Cost: TL;DR ~150 tok · whole note ~2.1k tok. Read more: ## Architecture: one owner, many requests · ## Accessibility and comfort · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Screen-space damage feedback tells the player "you were hit" and "you are in danger" without them reading a health bar. Done badly it blinds phones, stacks into a white screen in multi-hit fights, and triggers motion or photosensitivity problems. This note is the client-side pattern: one owner for every screen effect, additive "requests" from gameplay, and accessibility toggles that scale everything to zero.

Source labels: **Roblox docs** (create.roblox.com), **Rule of thumb** (LihFolk practice), **Unverified**.

## What you have to work with

- `ColorCorrectionEffect` (`Brightness`, `Contrast`, `Saturation`, `TintColor`) and `BlurEffect` (`Size`) under `Lighting` or the `Camera` apply to the whole 3D view (Roblox docs). Parented to `Workspace.CurrentCamera`, they are local to that client and do not affect other players.
- `ColorGradingEffect` exists (exposes `TonemapperPreset`); treat it as a scene grade, not a damage channel (Roblox docs, API dump October 2026).
- Post-processing does **not** affect `ScreenGui`s. A red edge vignette is usually an `ImageLabel` with a radial-gradient texture you author, stretched over the screen with `IgnoreGuiInset` on its `ScreenGui`.
- There is no built-in vignette post effect in the API (checked against the API dump, October 2026). Do not ask an AI for `VignetteEffect`; it does not exist.

## Architecture: one owner, many requests

Several systems want the screen: damage, low health, poison, a boss roar, a cutscene, the death screen. If each tweens `ColorCorrectionEffect` directly, the last tween wins and effects get stuck on. Instead, one client module owns the effect instances and composes requests every frame.

```lua
--!strict
-- ScreenFX: the only code that writes to the damage ColorCorrection, Blur and vignette.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ScreenFX = {}
ScreenFX.intensityScale = 1 -- from settings: 0 disables everything

type Pulse = { tint: Color3, strength: number, start: number, duration: number }
local pulses: {Pulse} = {}
local lowHealth = 0 -- 0..1 persistent channel

local camera = Workspace.CurrentCamera
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "ScreenFX_CC"
cc.Parent = camera
local blur = Instance.new("BlurEffect")
blur.Name = "ScreenFX_Blur"
blur.Size = 0
blur.Parent = camera

function ScreenFX.pulse(tint: Color3, strength: number, duration: number)
	table.insert(pulses, { tint = tint, strength = strength, start = os.clock(), duration = duration })
end

function ScreenFX.setLowHealth(value: number)
	lowHealth = math.clamp(value, 0, 1)
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local flash, r, g, b = 0, 0, 0, 0
	for i = #pulses, 1, -1 do
		local p = pulses[i]
		local t = (now - p.start) / p.duration
		if t >= 1 then
			table.remove(pulses, i)
		else
			local w = p.strength * (1 - t) ^ 2 -- fast attack, eased decay
			flash += w
			r += p.tint.R * w; g += p.tint.G * w; b += p.tint.B * w
		end
	end
	flash = math.min(flash, 0.6) * ScreenFX.intensityScale -- cap stacked hits
	local total = flash + lowHealth * 0.35 * ScreenFX.intensityScale
	local tint = if flash > 0 then Color3.new(r, g, b) else Color3.new(1, 0.3, 0.3)
	cc.TintColor = Color3.new(1, 1, 1):Lerp(tint, math.min(total, 1))
	cc.Saturation = -0.5 * lowHealth * ScreenFX.intensityScale
	blur.Size = 6 * lowHealth * ScreenFX.intensityScale
end)

return ScreenFX
```

Reviewed, not run. The `CurrentCamera` can be replaced (rare, but it happens on some respawn flows); re-parent on `Workspace:GetPropertyChangedSignal("CurrentCamera")` in production.

Key decisions encoded above:

- **Cap stacked flashes.** Ten pellets in one frame must not produce ten times the tint. Clamp the summed strength (0.6 above is a rule of thumb).
- **Fast attack, eased decay.** The hit is instant; the fade is 0.15 to 0.35 s (rule of thumb).
- **Persistent channel for low health.** It is a level, not a pulse, so it is a separate input driven by `Humanoid.HealthChanged` or your own health attribute.

## The four effects

| Effect | Drive from | Look | Timing (rule of thumb) |
|---|---|---|---|
| Hit flash | Server-confirmed damage event to this player | brief tint toward red or white, plus edge vignette pulse | 0.15 to 0.3 s decay |
| Directional indicator | Damage source position | arc on the screen edge pointing to the attacker | 1 to 1.5 s fade |
| Low-health vignette | Health below about 30 % | red edge, slight desaturation, slow heartbeat pulse | continuous; fades out over 1 s on heal |
| Heavy-hit blur | Big hits, stuns, explosions | `BlurEffect.Size` spike | under 0.3 s; never during aiming |

The directional indicator is the most useful and most often skipped. It needs the attacker position, which the server already knows; send it with the damage event rather than letting the client guess.

## Accessibility and comfort

- Expose a **Screen effects intensity** slider (0 to 100 %) that maps to `intensityScale`. Zero must remove tint, blur and vignette, leaving the health bar and sound as the feedback.
- Respect reduced-motion preferences for blur and any screen shake; see [[Motion Sensitivity and Camera Comfort]] for a comfort module that combines `ReducedMotionEnabled` with saved overrides.
- **Never flash** full-screen brightness changes more than about three times per second (rule of thumb drawn from common photosensitivity guidance; this is not a Roblox rule). Rapid-fire weapons must merge into one sustained tint, which the cap above does.
- Low-health vignettes darken the screen edges where phone players keep their thumbs and HUD; test that HUD buttons stay readable ([[Accessibility Contrast]]).
- Pair the red signal with a non-colour signal (pulse, heartbeat sound, icon) for colour-blind players.

## Server and client split

The server applies damage. It fires one remote to the damaged player with `amount`, `sourcePosition` and a `kind` tag; the client calls `ScreenFX.pulse`. Do not drive screen effects from local predictions of incoming hits; a predicted hit that the server rejects produces a phantom flash. Outgoing hit feedback (you hit someone) is different and can be predicted; see [[Client Hit Prediction for Melee Feedback]].

## Common mistakes

- **Several scripts tweening the same `ColorCorrectionEffect`.** Effects stick on after a death or respawn. One owner.
- **Effects parented to `Lighting` in a game that also uses lighting zones.** Zone scripts overwrite or duplicate them. Keep damage effects on the camera with unique names.
- **Uncapped stacking.** Shotguns and DoT ticks white out the screen.
- **Blur during aiming or precise platforming.** Players read it as lag.
- **No reset on death and respawn.** Clear pulses and the low-health level when the character is removed.
- **Flash with no intensity setting.** Fails accessibility review and annoys streamers.
- **Inventing APIs.** There is no `VignetteEffect`; build vignettes in UI.

## Checklist

- [ ] One client module owns every screen effect instance.
- [ ] Hits are pulses; low health is a level; both capped.
- [ ] Damage effects driven by server-confirmed events, with source position for a directional indicator.
- [ ] Intensity slider that reaches zero; reduced-motion respected.
- [ ] No full-screen flashing above about three per second.
- [ ] Reset on character removal; camera replacement handled.
- [ ] Tested on a phone at low graphics quality with the HUD visible.

## See also

- [[Atmosphere Sky Clouds and Post-Processing]]
- [[Motion Sensitivity and Camera Comfort]]
- [[Camera Shake and Camera FX]]
- [[Hit-Stop and Screen Shake Tuning by Numbers]]
- [[Game Feel and Juice]]
- [[Accessibility]]

## Connected notes

[[Gore Policy and Kid-Friendly Hit Feedback]] · [[Layering Camera Feedback on the Default Camera]] · Juice on a Budget - Mobile and Low-End · Post-Processing · HUD Design

<!-- related:start -->
## Related
[[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Stylized Lighting Recipes]] · [[Highlights and Selection Effects]] · [[Lighting Mood and Time of Day]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Combat Sound Design and Feedback]] · [[Lighting Technologies and Settings]]
<!-- related:end -->
