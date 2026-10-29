---
tags: [weather, lighting, atmosphere, state-machine, replication, determinism, type/guide, area/vfx, area/lighting, area/networking, level/intermediate, api/GetServerTimeNow, api/Atmosphere, api/GlobalWind]
---
# Weather System Architecture - State Machine, Transitions and Replication

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Server tweens `Lighting` -> Server writes attributes, client interpolates
> - Avoid: `math.random` per server -> Seeded walk from a fixed epoch
> - Avoid: `WeatherStart = now` -> Use the slot boundary time
> - Weather decided only on the server; clients only render.
> - Four attributes, `WeatherState` written last as the commit.
> - Alpha computed from `GetServerTimeNow()`; late joiners land mid-blend correctly.
>
> Cost: TL;DR ~150 tok · whole note ~3.6k tok. Read more: ## 4. Seeded forecasts so every server agrees · ## 5. Client renderer and transitions · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Weather on Roblox is three separate problems that most first attempts mash into one script: **deciding** what the weather is (server, authoritative, cheap), **telling** clients (a handful of attributes, not per-frame remotes), and **rendering** it (client only: Atmosphere, Clouds, particles, sound, post-processing). This note covers the decision and replication layers, a transition model that never pops, and seeded forecasts so every server in a universe shows the same storm at the same moment. Rendering recipes live in [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] and [[Snow, Sandstorm, Blizzard and Ash Recipes]]; the day clock it sits on top of is in [[Lighting Mood and Time of Day]].

Source labels: **Roblox docs** (create.roblox.com, as of October 2026), **Rule of thumb** (experience), **Unverified**. Code is strict Luau, reviewed, not run.

---

## 1. Who owns what

| Layer | Runs on | Writes | Never does |
|---|---|---|---|
| Weather director | Server | `Workspace` attributes: `WeatherState`, `WeatherFrom`, `WeatherStart`, `WeatherBlend` | Touch `Lighting`, emitters or sounds |
| Gameplay hooks | Server | Grip, sight and hearing multipliers read from the same state ([[Weather That Changes Gameplay - Grip, Visibility and Hearing]]) | Trust anything the client says about weather |
| Weather renderer | Client (one controller) | `Lighting`, `Atmosphere`, `Clouds`, `Workspace.GlobalWind`, local emitters, local sounds | Decide the weather |

Why the server must not write `Lighting` directly: every property write replicates to every client, including dozens of tween steps per transition, and a server-side tween looks steppy because clients receive snapshots, not the curve (Rule of thumb). Atmosphere and Clouds are rendered locally anyway; a client controller that interpolates locally is smoother and costs zero bandwidth after the four attribute writes.

**One renderer, one owner.** If a zone-mood script, a cutscene script and the weather script all write `Atmosphere.Density`, you get flicker. Route every look change through one client controller that composes layers (day curve, zone, weather, override) as described in [[Lighting Mood and Time of Day]] section 3.

## 2. The state machine

Model weather as a small set of named states with explicit allowed transitions, not as free-form numbers. That gives you designer-readable data, prevents "blizzard to heatwave in 2 seconds", and keeps the replicated payload to a string.

```lua
--!strict
-- ReplicatedStorage/WeatherDefs (shared by server and client)
export type WeatherDef = {
	weight: number,            -- relative chance when rolling the next state
	minDuration: number,       -- seconds
	maxDuration: number,
	blendIn: number,           -- seconds to fade in from the previous state
	next: {string},            -- allowed successors
	gameplay: { grip: number, sight: number, hearing: number },
}

local Defs: {[string]: WeatherDef} = {
	Clear = { weight = 5, minDuration = 240, maxDuration = 480, blendIn = 20,
		next = { "Overcast" }, gameplay = { grip = 1, sight = 1, hearing = 1 } },
	Overcast = { weight = 3, minDuration = 120, maxDuration = 300, blendIn = 25,
		next = { "Clear", "Rain" }, gameplay = { grip = 1, sight = 0.9, hearing = 1 } },
	Rain = { weight = 2, minDuration = 120, maxDuration = 240, blendIn = 15,
		next = { "Overcast", "Storm" }, gameplay = { grip = 0.8, sight = 0.75, hearing = 0.8 } },
	Storm = { weight = 1, minDuration = 60, maxDuration = 150, blendIn = 10,
		next = { "Rain" }, gameplay = { grip = 0.7, sight = 0.55, hearing = 0.6 } },
}

return Defs
```

Rules of thumb that keep it sane:
- Severe states are only reachable through milder ones (Clear -> Overcast -> Rain -> Storm), so the sky always telegraphs danger.
- `blendIn` is a property of the **target** state: storms arrive faster than clear skies return.
- Keep gameplay multipliers in the same table so designers tune look and effect together.

## 3. Replicating with attributes, not remotes

Attributes on `Workspace` replicate to all clients and late joiners automatically, and `GetAttributeChangedSignal` gives clients a clean trigger (Roblox docs: https://create.roblox.com/docs/studio/properties#attributes). Write four values per change:

| Attribute | Type | Meaning |
|---|---|---|
| `WeatherFrom` | string | State being faded out |
| `WeatherState` | string | Target state |
| `WeatherStart` | number | `Workspace:GetServerTimeNow()` when the blend began |
| `WeatherBlend` | number | Blend length in seconds |

The client computes `alpha = clamp((GetServerTimeNow() - WeatherStart) / WeatherBlend, 0, 1)` every frame. A player who joins mid-transition lands at the correct alpha instantly, and there is no per-frame traffic. `Workspace:GetServerTimeNow()` is synchronised across clients (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/Workspace#GetServerTimeNow).

Write order matters: set `WeatherStart` and `WeatherBlend` **before** `WeatherState`, and have the client listen only to `WeatherState`. Attribute changes from one server frame normally arrive together, but listening to a single "commit" attribute makes the ordering question irrelevant (Rule of thumb).

## 4. Seeded forecasts so every server agrees

Players notice when their friend's server has sunshine and theirs has a storm, especially if weather grants luck boosts or spawns rare items. Make weather a pure function of universe time, so every server computes the same timeline without talking to each other.

```lua
--!strict
-- ServerScriptService/WeatherDirector
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Defs = require(ReplicatedStorage:WaitForChild("WeatherDefs"))

local SLOT = 120               -- seconds per forecast slot
local EPOCH = 1_767_225_600    -- fixed universe epoch (unix seconds); never change after launch
local UNIVERSE_SALT = 7331     -- change to reshuffle the whole forecast

local function pick(rng: Random, options: {string}): string
	local total = 0
	for _, name in options do total += Defs[name].weight end
	local roll = rng:NextNumber() * total
	for _, name in options do
		roll -= Defs[name].weight
		if roll <= 0 then return name end
	end
	return options[#options]
end

-- Walk the chain from the epoch. Each slot's successor depends only on slot index and previous state.
local function stateAtSlot(slot: number): string
	local state = "Clear"
	local anchor = slot - (slot % 64) -- re-anchor every 64 slots to bound the walk
	for s = anchor, slot do
		local rng = Random.new(s * 92821 + UNIVERSE_SALT)
		if rng:NextNumber() < 0.35 then -- chance to change state this slot
			state = pick(rng, Defs[state].next)
		end
	end
	return state
end

local lastState = ""
while true do
	local now = Workspace:GetServerTimeNow()
	local slot = math.floor((now - EPOCH) / SLOT)
	local state = Workspace:GetAttribute("ForceWeather") or stateAtSlot(slot)
	if type(state) == "string" and state ~= lastState and Defs[state] then
		Workspace:SetAttribute("WeatherFrom", lastState ~= "" and lastState or state)
		Workspace:SetAttribute("WeatherStart", slot * SLOT + EPOCH)
		Workspace:SetAttribute("WeatherBlend", Defs[state].blendIn)
		Workspace:SetAttribute("WeatherState", state) -- commit attribute, written last
		lastState = state
	end
	task.wait(1)
end
```

Notes:
- `WeatherStart` uses the slot boundary, not "now", so two servers that started at different times still agree on alpha.
- The 64-slot re-anchor is a trade: the chain always restarts from Clear at the anchor, which is a visible reset every ~2 hours at `SLOT = 120`. Hide it by making the anchor state match the most common state, or use a longer anchor (Rule of thumb).
- This replaces the duration ranges in the defs with a per-slot change chance. If you need exact durations, precompute a schedule from the epoch with the same seeded walk.
- `Random.new(seed)` is deterministic for the same seed across servers (Roblox docs: https://create.roblox.com/docs/reference/engine/datatypes/Random). See [[Seeds Determinism and Reproducible Worlds]].
- For live-ops overrides (a scheduled "eclipse"), read a config value from [[Global State and Live Config]] and let it win over the seeded result; all servers pick it up within the config poll interval.

## 5. Client renderer and transitions

The renderer holds a numeric "look" per state and lerps between `WeatherFrom` and `WeatherState` by eased alpha.

```lua
--!strict
-- StarterPlayerScripts/WeatherRenderer (excerpt)
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

type Look = { density: number, haze: number, cover: number, wind: Vector3, rain: number }
local Looks: {[string]: Look} = {
	Clear    = { density = 0.30, haze = 0.5, cover = 0.45, wind = Vector3.new(4, 0, 2),  rain = 0 },
	Overcast = { density = 0.38, haze = 1.5, cover = 0.75, wind = Vector3.new(8, 0, 3),  rain = 0 },
	Rain     = { density = 0.45, haze = 2.5, cover = 0.85, wind = Vector3.new(12, 0, 4), rain = 0.6 },
	Storm    = { density = 0.55, haze = 4.0, cover = 0.95, wind = Vector3.new(22, 0, 8), rain = 1 },
}

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
local smooth = function(t: number): number return t * t * (3 - 2 * t) end

RunService.RenderStepped:Connect(function()
	local from = Looks[Workspace:GetAttribute("WeatherFrom") :: string] or Looks.Clear
	local to = Looks[Workspace:GetAttribute("WeatherState") :: string] or Looks.Clear
	local start = (Workspace:GetAttribute("WeatherStart") :: number?) or 0
	local blend = math.max((Workspace:GetAttribute("WeatherBlend") :: number?) or 1, 0.01)
	local a = smooth(math.clamp((Workspace:GetServerTimeNow() - start) / blend, 0, 1))
	if atmosphere then
		atmosphere.Density = from.density + (to.density - from.density) * a
		atmosphere.Haze = from.haze + (to.haze - from.haze) * a
	end
	if clouds then clouds.Cover = from.cover + (to.cover - from.cover) * a end
	Workspace.GlobalWind = from.wind:Lerp(to.wind, a)
	-- hand rain intensity to the precipitation module rather than touching emitters here
end)
```

Transition gotchas:
- **Lerp numbers, switch assets.** Densities, colours and wind blend cleanly. Skyboxes and emitter textures do not; cross-fade them with transparency or switch them at alpha 0.5 behind a heavy haze.
- **Ease, and order the channels.** Clouds should lead, then haze, then precipitation, then sound. Offsetting each channel's alpha (for example rain starts at alpha 0.4) sells "a storm rolling in".
- **Write only when changed** if the controller also runs while paused in menus; or throttle to every other frame. Writing identical values every frame is cheap but adds noise when debugging with property watchers (Rule of thumb).
- `GlobalWind` affects clouds, terrain grass and particles with `WindAffectsDrag` (Roblox docs: https://create.roblox.com/docs/reference/engine/classes/Workspace#GlobalWind). Changing it changes every wind-driven emitter in the place, including ones you did not intend.

## 6. Debug and QA hooks

- `ForceWeather` attribute on the server, settable only from a developer-gated command, pins the state for testing (the director above honours it).
- A client-only debug slider that overrides alpha lets artists scrub a transition without waiting 25 seconds.
- Log state changes with the slot index; when a player reports "the storm never ends", the slot tells you what every server was showing.

## Common mistakes

| Mistake | What you see | Fix |
|---|---|---|
| Server tweens `Lighting` | Steppy fades, bandwidth spikes on every change | Server writes attributes, client interpolates |
| `math.random` per server | Different weather on every server | Seeded walk from a fixed epoch |
| `WeatherStart = now` | Servers disagree on blend progress | Use the slot boundary time |
| Several scripts write `Atmosphere` | Flicker at zone edges and cutscenes | One renderer composing layers |
| Lerping skyboxes | Pop at the midpoint | Cross-fade or switch behind haze |
| Gameplay reads client weather | Exploiters remove storms and keep the boost | Gameplay hooks read server state only |
| Changing `EPOCH` after launch | Forecast jumps on every server | Treat epoch and salt as save data |

## Checklist

- [ ] Weather decided only on the server; clients only render.
- [ ] Four attributes, `WeatherState` written last as the commit.
- [ ] Alpha computed from `GetServerTimeNow()`; late joiners land mid-blend correctly.
- [ ] Forecast is a pure function of universe time and a salt.
- [ ] Severe states reachable only through milder ones.
- [ ] One client renderer owns every look property.
- [ ] Developer-gated `ForceWeather` for QA.
- [ ] Tested with two servers side by side showing the same state.

## See also

[[Lighting Mood and Time of Day]] · [[Atmosphere Sky Clouds and Post-Processing]] · [[Rain - Camera-Local Particles, Splashes and Wet Surfaces]] · [[Snow, Sandstorm, Blizzard and Ash Recipes]] · [[Lightning Strikes and Thunder - Procedural Bolts and Sound Delay]] · [[Weather That Changes Gameplay - Grip, Visibility and Hearing]] · [[Weather Performance Budgets and Quality Tiers]] · [[Seeds Determinism and Reproducible Worlds]] · [[Global State and Live Config]] · [[Instances Attributes and Tags]]

## Connected notes
<!-- auto-links:start -->
[[Zone Detection - Area Enter and Exit for Music, Lighting and Ambience]] · [[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · Behaviour Trees Utility AI and State Machines for NPCs · Replication Rules
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Stylized Lighting Recipes]] · [[Lighting Technologies and Settings]] · [[Particle Emitters In Depth]] · [[Custom Character Sounds - Replacing Default Footstep and Jump Sounds]] · [[Music and Adaptive Audio]] · [[Elemental VFX Kits - Fire, Ice, Earth, Water, Wind and Lightning]] · [[Screen Damage Effects - Hit Flash, Low-Health Vignette and Blur]] · [[Light Sources and Shadows]]
<!-- related:end -->
