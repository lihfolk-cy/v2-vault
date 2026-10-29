---
tags: [qol, audio, soundgroup, volume, mixer, music, ducking, sidechain, settings, type/guide, area/audio, level/intermediate, api/SoundGroup, api/CompressorSoundEffect, api/SoundService]
---
# Audio Mixer Settings with SoundGroups

<!-- tldr:start -->
> [!tldr] TL;DR
> - Music slider leaves some music audible: Track has no `SoundGroup` -> Assign groups at creation; audit script
> - Slider "does nothing" below half: Linear mapping -> Squared curve
> - Dialogue lost under music: No ducking -> Sidechain compressor or scripted duck
> - Master, Music, SFX, UI (and Voice) SoundGroups, nested under Master.
> - Every sound, including runtime ones, has a `SoundGroup`.
> - Sliders use a perceptual curve; mute-music toggle exists.
>
> Cost: TL;DR ~150 tok · whole note ~1.9k tok. Read more: ## 2. Map sliders to volume with a curve · ## 3. Ducking · ## Common mistakes · ## Checklist
<!-- tldr:end -->

"Turn the music off" is the most common settings request on any Roblox game, and many still cannot do it without muting the whole client. A proper mixer needs four sliders (Master, Music, SFX, UI), a quick mute-music toggle, and the discipline to put every sound in a group. This note shows the group layout, the client code that maps settings to volumes, and simple ducking so dialogue or a boss sting is audible over the soundtrack. Sound basics and mixing theory are in [[Sound Fundamentals]], [[Spatial Audio and Mixing]] and [[Music and Adaptive Audio]]; the newer wire-based API is in [[The Audio API - Players Emitters Wires and Effects]].

Sources: **Roblox docs** for `SoundGroup` (https://create.roblox.com/docs/reference/engine/classes/SoundGroup), `Sound.SoundGroup` (https://create.roblox.com/docs/reference/engine/classes/Sound) and `CompressorSoundEffect` (https://create.roblox.com/docs/reference/engine/classes/CompressorSoundEffect). Curve choices are **Rule of thumb**.

## 1. Group layout

```
SoundService
  Master (SoundGroup)
    Music (SoundGroup)
    SFX (SoundGroup)
      Combat (SoundGroup)
      Ambient (SoundGroup)
    UI (SoundGroup)
    Voice (SoundGroup)    -- dialogue, announcer
```

A `SoundGroup` parented to another `SoundGroup` nests: the effective volume is the product down the chain (**Roblox docs**). Each `Sound` joins a group through its `SoundGroup` property, not by being parented inside it, so 3D sounds can stay on their parts.

Gotcha: a sound with `SoundGroup = nil` ignores your mixer completely. Audit with a quick Studio command:

```lua
--!strict
-- Command bar: list sounds that bypass the mixer.
for _, s in game:GetDescendants() do
	if s:IsA("Sound") and s.SoundGroup == nil then
		print(s:GetFullName())
	end
end
```

Run it in Play mode too; sounds created at runtime (tools, character sounds, VFX) are the usual leaks. Assign a group in the factory function that creates them.

## 2. Map sliders to volume with a curve

Human loudness perception is roughly logarithmic, so a linear slider feels like "nothing happens until 30%, then it's loud". A squared curve is a cheap fix (**Rule of thumb**). `SoundGroup.Volume` accepts 0 to 10 (**Roblox docs**); keep your mapped maximum at the authored level (usually 1) so 100% means "as mixed".

```lua
--!strict
-- StarterPlayerScripts/AudioMixer (ModuleScript)
local SoundService = game:GetService("SoundService")
local ClientSettings = require(script.Parent.ClientSettings)

local master = SoundService:WaitForChild("Master") :: SoundGroup
local groups: { [string]: SoundGroup } = {
	masterVolume = master,
	musicVolume = master:WaitForChild("Music") :: SoundGroup,
	sfxVolume = master:WaitForChild("SFX") :: SoundGroup,
	uiVolume = master:WaitForChild("UI") :: SoundGroup,
}
local BASE: { [string]: number } = { masterVolume = 1, musicVolume = 0.7, sfxVolume = 1, uiVolume = 0.8 }

local function curve(x: number): number
	return x * x
end

local function apply(key: string)
	local group = groups[key]
	if group == nil then return end
	local v = ClientSettings.get(key) :: number
	if key == "musicVolume" and ClientSettings.get("muteMusic") == true then v = 0 end
	group.Volume = BASE[key] * curve(v)
end

for key in groups do apply(key) end
ClientSettings.Changed:Connect(function(key)
	if key == "muteMusic" then apply("musicVolume") else apply(key) end
end)

return {}
```

Add `muteMusic` (bool, default false) to the schema in [[Settings Menu Essentials and Persistence]]. A separate toggle matters because players often want music off but SFX on, and they want to flip it back without remembering the slider position.

The whole mixer runs on the client. Volumes are personal; nothing here needs the server except persistence.

## 3. Ducking

Ducking lowers music while something important plays. Two ways:

**Sidechain compressor (engine-driven).** Put a `CompressorSoundEffect` inside the Music group and set its `SideChain` to the Voice group. When voice plays, the compressor reduces music (**Roblox docs** describe `SideChain` as the sound or group that drives compression). Tune `Threshold`, `Ratio`, `Attack` and `Release` by ear; a slow release (about half a second) avoids pumping.

**Scripted duck (explicit).** Easier to reason about and to tie to game events:

```lua
--!strict
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local music = SoundService.Master.Music :: SoundGroup

local holders = 0
local duckGroup = Instance.new("SoundGroup")
duckGroup.Name = "MusicDuck"
duckGroup.Volume = 1
duckGroup.Parent = music

local function setDuck(target: number)
	TweenService:Create(duckGroup, TweenInfo.new(0.25), { Volume = target }):Play()
end

local Ducker = {}
function Ducker.hold(): () -> ()
	holders += 1
	setDuck(0.35)
	local released = false
	return function()
		if released then return end
		released = true
		holders -= 1
		if holders == 0 then setDuck(1) end
	end
end
return Ducker
```

Route music tracks into `MusicDuck` (a child of Music), so the player's slider and the duck multiply instead of fighting. The reference-counted `hold` prevents two overlapping voice lines from un-ducking early. Usage: `local release = Ducker.hold()` when a voice line starts, `release()` in its `Ended` handler and in any cancel path.

## 4. Extra QoL

- **Preview on change**: play a short UI click or SFX sample when the slider is released, so players hear the level.
- **Separate Voice slider** if your game has narration; captions belong in [[Captions and Audio Accessibility]].
- **Remember the music track position** when unmuting, rather than restarting the intro every time.
- **Don't fight Roblox's master volume.** `UserGameSettings.MasterVolume` is Roblox's; your Master slider is in-game only.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| Music slider leaves some music audible | Track has no `SoundGroup` | Assign groups at creation; audit script |
| Slider "does nothing" below half | Linear mapping | Squared curve |
| Dialogue lost under music | No ducking | Sidechain compressor or scripted duck |
| Music un-ducks mid-line | Boolean duck flag | Reference-counted holds |
| Player slider resets on duck | Duck writes the Music group volume | Separate duck group under Music |

## Checklist

- [ ] Master, Music, SFX, UI (and Voice) SoundGroups, nested under Master.
- [ ] Every sound, including runtime ones, has a `SoundGroup`.
- [ ] Sliders use a perceptual curve; mute-music toggle exists.
- [ ] Ducking on a separate group with reference counting.
- [ ] Settings persist via the shared settings service.

## See also

- [[Sound Fundamentals]]
- [[Spatial Audio and Mixing]]
- [[Sound Design Pitfalls - Reused Ids Onsets and Layered Loops]]
- [[Settings Menu Essentials and Persistence]]

## Connected notes
<!-- auto-links:start -->
[[Player QoL Start Here]] · [[Music and Adaptive Audio]] · Captions and Audio Accessibility · Combat Sound Design and Feedback
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Combat Sound Design and Feedback]] · [[QoL Audit Checklist]] · [[Accessibility Cross-Links for QoL Settings]] · [[Top 25 QoL Wins by Effort]] · [[Camera Settings - FOV Shake Sensitivity and Shift-Lock]] · [[Graphics and Performance Toggles for Low-End Devices]] · [[UI Scale HUD Hide and Compact Mode]] · [[Mobile Button Layout Editor]] · [[Block and Mute Respecting Platform Rules]]
<!-- related:end -->
