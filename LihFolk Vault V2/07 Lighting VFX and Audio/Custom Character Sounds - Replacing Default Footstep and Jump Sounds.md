---
tags: [audio, characters, footsteps, rbxcharactersounds, materials, animation-markers, type/guide, area/audio, level/intermediate, api/Humanoid, api/AnimationTrack, api/Sound]
---
# Custom Character Sounds - Replacing Default Footstep and Jump Sounds

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Adding sounds to the rig without disabling the default -> Replace `RbxCharacterSounds`
> - Avoid: Playing footsteps on the server -> Client-side for all characters
> - Avoid: Speed-based loop for steps -> Animation markers
> - `RbxCharacterSounds` replaced (disabled or forked, fork dated).
> - Footstep markers on every locomotion animation.
> - Surface from raycast with attribute overrides; Terrain covered.
>
> Cost: TL;DR ~140 tok · whole note ~2.6k tok. Read more: ## 1. How the default works · ## 3. A replacement footstep system · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Every Roblox character makes sounds out of the box: running, jumping, landing, falling, climbing, swimming, splash, getting up and dying. They come from a default client script, not from the character model, which is why adding sounds to your custom rig does not remove the stock ones, and why "change the footstep sound" is a script fork, not an asset swap. This note covers how the default system is structured, the three ways to replace it, and a material-aware, animation-synced footstep system that works for every character on every client without remotes.

Source labels: **Roblox docs**, **Default script behaviour** (as shipped; Roblox can change it), **Rule of thumb**, **Unverified**.

---

## 1. How the default works

- At join, the engine adds default player scripts, including a `LocalScript` named **`RbxCharacterSounds`**, into each player's `PlayerScripts` (**Default script behaviour**; see https://create.roblox.com/docs/players/characters for the default character setup).
- That script runs on **each client** and handles sounds for **every character** it sees, not just the local one. It creates `Sound` instances under each character's `HumanoidRootPart` and plays them from `Humanoid` state changes (`Running`, `Jumping`, `Freefall`, `Landed`, `Climbing`, `Swimming` and so on).
- Nothing is replicated: each client generates the sounds locally from the replicated character state. That is good for bandwidth and means your replacement must do the same.
- The running sound is a loop whose playback follows movement speed; it is not synced to feet, which is why default footsteps drift against custom walk animations.

**Unverified:** recent releases have added an option for the default character sounds to use the Audio API instead of `Sound` objects (exposed on `SoundService`). Check the SoundService reference before depending on either object type in your own code.

## 2. Three ways to replace it

| Approach | How | When |
|---|---|---|
| **Disable** | Put a `LocalScript` named `RbxCharacterSounds` (empty) in `StarterPlayer.StarterPlayerScripts`. A script with that name replaces the default | You will write a full replacement |
| **Fork** | In a Play test, copy `RbxCharacterSounds` from `Players.<you>.PlayerScripts`, stop, paste into `StarterPlayerScripts`, edit the sound ids and logic | You want the stock behaviour with your own sounds |
| **Silence specific sounds** | A client script that finds the created sounds under each root part and sets their volume to 0 | Quick prototypes only: it races the default script and breaks when its names change |

A fork is a snapshot: it stops receiving Roblox's fixes to the default script. Record the date you forked and diff it against a fresh copy occasionally ([[Version History and Backups]]).

## 3. A replacement footstep system

Design goals: footsteps land on the foot, change with surface, differ per character type, cost almost nothing for distant players, and need no server work.

### Sync to feet with animation markers
Add a `Footstep` marker on each contact frame in your walk and run animations (in the Animation Editor's event track), optionally with a parameter `L`/`R`. Then listen on every playing locomotion track:

```lua
--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

type SoundSet = { [string]: { string } } -- material name -> asset ids you uploaded
local SETS: { [string]: SoundSet } = require(script.Parent:WaitForChild("FootstepSets")) :: any

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local lastIndex: { [string]: number } = {}

local function surfaceKey(char: Model, hum: Humanoid): string
	local root = hum.RootPart
	if not root then return "Default" end
	rayParams.FilterDescendantsInstances = { char }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -(hum.HipHeight + root.Size.Y), 0), rayParams)
	if not hit then return "Default" end
	local override = hit.Instance:GetAttribute("FootstepSurface") -- e.g. "MetalGrate"
	if typeof(override) == "string" then return override end
	return hit.Material.Name -- also covers Terrain materials
end

local function pick(list: { string }, key: string): string
	local n = #list
	local i = math.random(n)
	if n > 1 and i == lastIndex[key] then i = i % n + 1 end -- no immediate repeat
	lastIndex[key] = i
	return list[i]
end

local function onFootstep(char: Model, hum: Humanoid)
	local cam = Workspace.CurrentCamera
	local root = hum.RootPart
	if not (cam and root) then return end
	local dist = (cam.CFrame.Position - root.Position).Magnitude
	if dist > 80 then return end -- distance cull before any work

	local setName = char:GetAttribute("FootstepSet")
	local set = SETS[if typeof(setName) == "string" then setName else "Human"]
	local key = surfaceKey(char, hum)
	local list = set[key] or set.Default
	if not list then return end

	local s = Instance.new("Sound")
	s.SoundId = pick(list, key)
	s.Volume = 0.35 * (0.85 + math.random() * 0.3)
	s.PlaybackSpeed = 0.92 + math.random() * 0.16
	s.RollOffMaxDistance = 60
	s.Parent = root
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
end

local function hookAnimator(char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	local animator = hum and hum:WaitForChild("Animator", 10) :: Animator?
	if not (hum and animator) then return end
	animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		track:GetMarkerReachedSignal("Footstep"):Connect(function()
			if hum.FloorMaterial ~= Enum.Material.Air then
				onFootstep(char, hum)
			end
		end)
	end)
end
```

Hook `hookAnimator` for every player's `CharacterAdded` (including existing players at start) and for NPCs you care about. In production replace the per-step `Instance.new` with a small voice pool ([[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] section 4).

Key APIs (**Roblox docs**): `AnimationTrack:GetMarkerReachedSignal` (https://create.roblox.com/docs/reference/engine/classes/AnimationTrack#GetMarkerReachedSignal), `Animator.AnimationPlayed`, `Humanoid.FloorMaterial` (https://create.roblox.com/docs/reference/engine/classes/Humanoid#FloorMaterial).

### Why a raycast and not only `FloorMaterial`
`FloorMaterial` gives the base `Enum.Material` only. Two plastic parts dressed as carpet and as metal grating report the same value, and `MaterialVariant` names are not reported. A short downward raycast lets you read an attribute override on the hit part. Use `FloorMaterial` as the cheap "am I grounded" gate.

### Per-character sets
Store `FootstepSet` as an attribute on the character model (`Human`, `Heavy`, `Robot`, `Creature`, `Barefoot`). Class systems set it when they apply a rig ([[Custom Characters and StarterCharacter]]). Heavy sets get lower pitch and a low-frequency layer; tiny characters get higher pitch and lower volume.

## 4. The other states

| State | Replacement | Notes |
|---|---|---|
| Jump | One-shot on `Humanoid.StateChanged` to `Jumping`; a cloth/effort layer plus a light foot scuff | Different set per surface is overkill; per character is enough |
| Land | One-shot on transition from `Freefall` to `Landed`, volume from vertical speed before landing | Skip below a small fall speed or every step-down thuds |
| Freefall wind | Loop that fades in after about 0.6 s of falling | Not on short hops |
| Swim / splash | Splash one-shot on entering `Swimming`; stroke markers in the swim animation | Terrain water is the usual source |
| Climb | Markers in the climb animation; surface from a forward raycast | |
| Death | Usually your own death sound on the server-decided death event, not `Died` locally | Keep it consistent with combat audio ([[Combat Sound Design and Feedback]]) |

Own character: consider playing the local player's footsteps 2D or with a closer listener, otherwise they sound distant behind a third-person camera ([[Spatial Audio and Mixing]] section 2).

## 5. Performance

- Cull by distance before raycasting. **Rule of thumb:** 60 to 100 studs for footsteps; beyond that nobody can hear them over the mix.
- Cap simultaneous footstep voices (8 to 12). Thirty players running in a hub will otherwise spawn hundreds of sounds a second.
- Animation markers for distant characters still fire if their animations play; the distance check is what keeps it cheap.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Adding sounds to the rig without disabling the default | Double footsteps | Replace `RbxCharacterSounds` |
| Playing footsteps on the server | Latency, bandwidth, doubled on owner | Client-side for all characters |
| Speed-based loop for steps | Steps drift from feet | Animation markers |
| Only `FloorMaterial` | Carpet and metal sound the same | Raycast plus attribute override |
| No repeat avoidance | Machine-gun sameness | Never repeat the last variant; pitch and volume jitter |
| No distance culling | CPU spikes in busy servers | Cull before work; voice cap |

## Checklist
- [ ] `RbxCharacterSounds` replaced (disabled or forked, fork dated).
- [ ] Footstep markers on every locomotion animation.
- [ ] Surface from raycast with attribute overrides; Terrain covered.
- [ ] Per-character sound sets via attribute.
- [ ] Jump, land, swim, climb and fall handled or deliberately silent.
- [ ] Distance cull, voice cap and repeat avoidance in place.

## See also
[[Sound Design for Games]] · [[Spatial Audio and Mixing]] · [[Markers and Events]] · [[Characters and Humanoids]] · [[Custom Characters and StarterCharacter]] · [[Procedural Gait and Footstep Planning]]

## Connected notes
<!-- auto-links:start -->
[[Sound Fundamentals]] · [[Captions and Audio Accessibility]] · The Default Animate Script · Audio Pipeline
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Impact Decals and Material-Aware Hit Sparks]] · [[Engine and Tyre Audio Driven by RPM and Slip]] · [[Music and Adaptive Audio]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[The Audio API - Players Emitters Wires and Effects]] · [[Game Feel and Juice]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]]
<!-- related:end -->
