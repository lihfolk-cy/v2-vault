---
tags: [qol, graphics, performance, low-end, mobile, particles, shadows, vfx, settings, type/guide, area/performance, level/intermediate, api/ParticleEmitter, api/Lighting, api/UserGameSettings]
---
# Graphics and Performance Toggles for Low-End Devices

<!-- tldr:start -->
> [!tldr] TL;DR
> - Low mode still stutters in fights: Ability VFX emit fixed counts -> Route every `Emit` through the scale helper
> - Players on Low cannot dodge attacks: Telegraphs disabled with decoration -> Exempt gameplay VFX
> - "Render distance" slider does nothing: Streaming radius is place-wide -> Rename to "Hide distant decoration" or drop it
> - Auto, Low, Medium, High presets, with an Advanced fold.
> - All VFX counts pass through one density scale.
> - Decorative shadows and post effects toggleable; gameplay VFX exempt.
>
> Cost: TL;DR ~170 tok · whole note ~2.1k tok. Read more: ## 1. What scripts can and cannot do · ## 3. A client module that applies the preset · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox already gives players a graphics quality slider. Your job is not to replace it but to add the levers only your game knows about: how many particles your abilities spawn, whether your decorative lights cast shadows, whether that 400-part waterfall animates. On a low-end Android phone these game-specific costs often matter more than the engine slider. This note covers what to offer, what scripts can and cannot change, and a small client module that applies a preset. The deep performance material lives in [[Mobile and Low-End Optimization]], [[Rendering Performance]] and [[VFX Performance Budgets and Culling]].

Sources: **Roblox docs** for `UserGameSettings` (https://create.roblox.com/docs/reference/engine/classes/UserGameSettings), `ParticleEmitter` (https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter) and `Lighting` (https://create.roblox.com/docs/reference/engine/classes/Lighting). Preset contents are **Rule of thumb**.

## 1. What scripts can and cannot do

| Lever | Script control | Notes |
|---|---|---|
| Engine graphics quality | Read only | `UserSettings():GetService("UserGameSettings").SavedQualityLevel` reads the player's choice (`Automatic` or levels 1-10); you cannot set it (**Roblox docs**) |
| Global shadows | Yes, locally | A LocalScript setting `Lighting.GlobalShadows = false` only affects that client |
| Per-part shadows | Yes | `BasePart.CastShadow` on decorative parts |
| Particle density | Yes | Scale `ParticleEmitter.Rate` and the counts you pass to `Emit` |
| Post effects | Yes | Disable `BloomEffect`, `DepthOfFieldEffect`, `SunRaysEffect` locally |
| Render distance | Indirect | With streaming, `StreamingTargetRadius` is a server-wide place property, not per player; you can hide your own far-away decoration client-side |
| Frame rate cap | No | Roblox owns the frame rate cap setting |

Treat "render distance" as a hint, not a promise. With `StreamingEnabled` the engine decides what is loaded; a client option can only hide what is already there (fog, culling your own decorative folders). See [[Instance Streaming]] and [[Level of Detail and Model Streaming]].

## 2. Presets players understand

Offer four choices: **Auto** (follow the engine level), **Low**, **Medium**, **High**. Sliders for each lever overwhelm most players; put them under an "Advanced" fold.

| Lever | Low | Medium | High |
|---|---|---|---|
| VFX density | 0.35 | 0.7 | 1.0 |
| Global shadows | Off | On | On |
| Decorative shadows | Off | Off | On |
| Post effects | Off | Bloom only | All |
| Ambient animated props | Static | Near only | All |
| Other players' cosmetic trails | Off | Own and party | All |

**Auto** maps the engine level to a preset. A reasonable mapping (**Rule of thumb**): levels 1-3 Low, 4-7 Medium, 8-10 High, and `Automatic` treated as Medium because you cannot read what the engine actually picked.

## 3. A client module that applies the preset

```lua
--!strict
-- StarterPlayerScripts/GraphicsTweaks (ModuleScript)
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ClientSettings = require(script.Parent.ClientSettings)

type Preset = { vfx: number, globalShadows: boolean, decoShadows: boolean, post: boolean }
local PRESETS: { [string]: Preset } = {
	low = { vfx = 0.35, globalShadows = false, decoShadows = false, post = false },
	medium = { vfx = 0.7, globalShadows = true, decoShadows = false, post = true },
	high = { vfx = 1, globalShadows = true, decoShadows = true, post = true },
}

local M = { vfxScale = 1 }

local function engineLevel(): string
	local ugs = UserSettings():GetService("UserGameSettings")
	local level = ugs.SavedQualityLevel
	if level == Enum.SavedQualitySetting.Automatic then return "medium" end
	local n = level.Value -- 1..10 for QualityLevel1..QualityLevel10
	return if n <= 3 then "low" elseif n <= 7 then "medium" else "high"
end

local function apply()
	local choice = ClientSettings.get("graphics") :: string
	local preset = PRESETS[if choice == "auto" then engineLevel() else choice]
	M.vfxScale = preset.vfx
	Lighting.GlobalShadows = preset.globalShadows
	for _, part in CollectionService:GetTagged("DecoShadow") do
		if part:IsA("BasePart") then part.CastShadow = preset.decoShadows end
	end
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("PostEffect") and not effect:IsA("ColorCorrectionEffect") then
			effect.Enabled = preset.post
		end
	end
end

-- Every VFX spawner calls this instead of emitting a fixed count.
function M.emit(emitter: ParticleEmitter, count: number)
	local n = math.floor(count * M.vfxScale + 0.5)
	if n > 0 then emitter:Emit(n) end
end

ClientSettings.Changed:Connect(function(key) if key == "graphics" then apply() end end)
apply()
return M
```

Check that `SavedQualityLevel.Value` maps as assumed in your build before shipping (**Unverified** for exact enum values). Colour correction stays on in every preset because many games use it for readability, not decoration.

Gotchas:
- **Content streamed in later is not tagged yet.** Listen to `CollectionService:GetInstanceAddedSignal("DecoShadow")` and apply the current preset to new parts.
- **Server-spawned emitters with high `Rate`** must be scaled on each client. Spawn VFX on clients from a remote where possible ([[Particle Emitters In Depth]]).
- **Never** disable gameplay-relevant effects (telegraphs, hit indicators) in Low. Tag them `GameplayVFX` and exempt them; a player on Low must see the boss attack coming.

## 4. Help low-end phones without asking

Many phone players never open settings. Two automatic helpers (**Rule of thumb**):

1. **First-session prompt**: if `UserInputService.TouchEnabled` and the engine level is low, suggest Low with one tap. Do not force it.
2. **Frame time watchdog**: sample frame time for 30 seconds after load; if the median is far above 33 ms, show a one-time toast "Switch to Low detail for smoother play?". Do not switch silently, because players notice their game "getting uglier" and assume a bug.

```lua
--!strict
local RunService = game:GetService("RunService")

local function medianFrameTime(seconds: number): number
	local samples: { number } = {}
	local start = os.clock()
	local conn = RunService.RenderStepped:Connect(function(dt) table.insert(samples, dt) end)
	repeat task.wait(1) until os.clock() - start >= seconds
	conn:Disconnect()
	table.sort(samples)
	return samples[math.max(1, #samples // 2)] or 0
end
```

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Low mode still stutters in fights | Ability VFX emit fixed counts | Route every `Emit` through the scale helper |
| Players on Low cannot dodge attacks | Telegraphs disabled with decoration | Exempt gameplay VFX |
| "Render distance" slider does nothing | Streaming radius is place-wide | Rename to "Hide distant decoration" or drop it |
| Graphics resets to High on a phone | Saved per account | Store per device bucket |
| Settings fight the engine slider | Game tries to drive quality level | Read the engine level, add game levers only |

## Checklist

- [ ] Auto, Low, Medium, High presets, with an Advanced fold.
- [ ] All VFX counts pass through one density scale.
- [ ] Decorative shadows and post effects toggleable; gameplay VFX exempt.
- [ ] Newly streamed instances get the current preset.
- [ ] Low-end phones get a one-time suggestion, not a silent switch.
- [ ] Engine quality setting read, never overridden.

## See also

- [[Mobile and Low-End Optimization]]
- [[Juice on a Budget - Mobile and Low-End]]
- [[Light Sources and Shadows]]
- [[Settings Menu Essentials and Persistence]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[VFX Performance Budgets and Culling]] · Rendering Performance · [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]]
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Weather Performance Budgets and Quality Tiers]] · [[QoL Audit Checklist]] · [[UI Scale HUD Hide and Compact Mode]] · [[Top 25 QoL Wins by Effort]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] · [[Mobile Button Layout Editor]] · [[Audio Mixer Settings with SoundGroups]] · [[Rebinding Controls with the Input Action System]] · [[Accessibility Cross-Links for QoL Settings]]
<!-- related:end -->
