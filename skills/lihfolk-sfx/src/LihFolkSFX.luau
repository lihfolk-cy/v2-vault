--!strict
--[[
	LihFolkSFX: layered, varied, pooled one-shot sound effects (client only, classic Sound API).

	- Registry of named sound definitions (`LihFolkSFX.Defs`): each name is a stack of layers
	  (transient / body / tail / sweetener), each layer a round-robin bag of takes with its own volume,
	  pitch range, delay, rolloff and bus.
	- `play(name, at?)`: random pitch and volume per layer, no take twice in a row, per-name cooldown and
	  instance cap, optional choke, and a global voice cap with priority stealing. Sound instances are
	  pooled and reused; a pooled Sound destroyed with its parent part is dropped from the pool.
	- Buses: SoundService > Master > SFX / Music / UI / Ambience (SoundGroups). `setBusVolume` takes a
	  0..1 slider value and applies a squared curve.
	- `bindToTrack` / `bindAnimator`: play names on KeyframeMarkers (the same markers LihFolkVFX reads:
	  TrailOn, Hit, DashStart, ChargeStart, Release, Impact, Deflect, Footstep).
	- `playUI(name)`: 2D (non-positional) sounds for menus.

	Every id is "rbxassetid://REPLACE_ME" until it is replaced by a real id from one of two places: a
	Roblox-licensed sound found in the Creator Store (Toolbox search or the Studio MCP asset search), or
	a sound the user uploaded from a premium library they hold a licence for. Never guess or invent an id.
	Placeholder takes are skipped with one warning per name. `search` holds the keywords to look for;
	`source` records where the takes came from and under which licence (required once ids are real).
	The newer Audio API (AudioPlayer / AudioEmitter / AudioListener / Wire) is the alternative; see SKILL.md.
]]

local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LihFolkSFX = {}

local PLACEHOLDER = "rbxassetid://REPLACE_ME"
LihFolkSFX.PLACEHOLDER = PLACEHOLDER

-------------------------------------------------------------------------------
-- Types
-------------------------------------------------------------------------------
export type Rolloff = { min: number, max: number, mode: Enum.RollOffMode? }

export type Layer = {
	ids: { string }, -- round-robin takes ("rbxassetid://<id>"); placeholders are skipped
	search: string?, -- what to look for in the Creator Store or a licensed library (documentation only)
	source: string?, -- where the takes came from + licence, e.g. "Creator Store, Roblox-licensed" or
	-- "BOOM Library <pack>, single-user EULA, uploaded by <group>, 2026-10-29"
	volume: number?, -- Sound.Volume before jitter (default 0.5)
	pitch: NumberRange?, -- random PlaybackSpeed range; NumberRange.new(1) = fixed (tonal stings)
	volumeJitter: number?, -- +- fraction (default Config.volumeJitter)
	delay: number?, -- seconds after the trigger
	peak: number?, -- seconds from file start to the transient; skipped when played on a marker (onBeat)
	rolloff: (string | Rolloff)?, -- preset name in LihFolkSFX.Rolloff or a table
	group: string?, -- bus override for this layer
}

export type SoundDef = {
	layers: { Layer },
	group: string?, -- bus: "SFX" (default), "UI", "Music", "Ambience"
	rolloff: (string | Rolloff)?, -- default for the layers
	cooldown: number?, -- minimum seconds between two plays of this name
	maxInstances: number?, -- live layer voices of this name; the oldest is cut beyond it
	choke: boolean?, -- a new play stops the previous one of this name
	priority: number?, -- 1 (far footstep) .. 5 (kill confirm, player hurt)
	caption: string?, -- sent to the caption handler; only for sounds that carry information
}

export type PlayOptions = {
	volume: number?, -- multiplier (onlookers: Config.onlookerVolume)
	pitch: number?, -- multiplier on top of the random pitch (combo climb: 1.059 ^ step)
	onBeat: boolean?, -- start each layer at its `peak` so the transient lands now (marker plays)
	priority: number?, -- overrides the def's priority
}

export type Target = BasePart | Attachment | Vector3
export type Cancel = (stopPlaying: boolean?) -> ()
export type MarkerEntry = string | (param: string) -> string?
export type MarkerMap = { [string]: MarkerEntry }
export type BindOptions = {
	volume: number?, -- multiplier for every sound of this binding
	autoUnbind: boolean?, -- disconnect when the track stops (bindAnimator sets it)
	onPlay: { [string]: string }?, -- Animation name -> sound name played when the track starts (ChargeUp)
}

-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------
LihFolkSFX.Config = {
	maxVoices = 24, -- live layer voices at once; beyond it a higher (or equal) priority steals the oldest lowest
	defaultCooldown = 0.03, -- per name: twenty hits in one frame become one, not a phasey stack
	defaultMaxInstances = 4,
	defaultPriority = 2,
	pitch = NumberRange.new(0.96, 1.04), -- +-4 %: small sounds; tonal stings use NumberRange.new(1)
	volumeJitter = 0.08, -- +-8 % (about +-0.7 dB)
	onlookerVolume = 0.7, -- other players' combat
	unloadedLength = 2, -- seconds a voice counts as busy when its asset has not loaded yet
}
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	LihFolkSFX.Config.maxVoices = 16
end

-- Rolloff presets (studs). InverseTapered fades to zero at max instead of cutting off.
LihFolkSFX.Rolloff = {
	footstep = { min = 5, max = 50 } :: Rolloff,
	melee = { min = 8, max = 100 } :: Rolloff,
	ability = { min = 12, max = 200 } :: Rolloff,
	explosion = { min = 30, max = 450 } :: Rolloff,
}

-- Bus base volumes (the authored mix level a 100 % slider gives).
LihFolkSFX.BusBase = { Master = 1, SFX = 1, Music = 0.7, UI = 0.8, Ambience = 0.8 } :: { [string]: number }
local BUS_CHILDREN = { "SFX", "Music", "UI", "Ambience" }

-------------------------------------------------------------------------------
-- Sound definitions. Layers: transient (the crack), body (weight), tail (air, space), sweetener (identity).
-- Every entry needs its source and licence noted: when you paste real ids into a layer, set its `source`
-- (Creator Store Roblox-licensed asset, or the licensed library + licence + uploader + date) and keep the
-- same line in the project's audio manifest. Layers with real ids but no `source` warn once.
-- `peak` values are starting guesses for a trimmed file (transient within ~10 ms); measure each real file
-- (seconds from file start to its loudest transient) and overwrite them.
-------------------------------------------------------------------------------
local function takes(n: number): { string }
	return table.create(n, PLACEHOLDER)
end

local FIXED = NumberRange.new(1)

LihFolkSFX.Defs = {
	-- Swing whoosh on TrailOn: starts before Hit so its swell (about 40 % of the file) is heard
	Swing = {
		priority = 2, rolloff = "melee", choke = true,
		layers = {
			{ ids = takes(3), search = "sword swing whoosh light", volume = 0.45 },
		},
	},
	SlashSweep = { -- heavy wide sweep
		priority = 3, rolloff = "melee", choke = true,
		layers = {
			{ ids = takes(3), search = "sword slash swipe metal", volume = 0.45, peak = 0.003 },
			{ ids = takes(3), search = "heavy sword swing whoosh", volume = 0.6 },
			{ ids = takes(3), search = "soft air whoosh", volume = 0.3, delay = 0.12, pitch = NumberRange.new(0.82, 0.9) },
		},
	},
	CrescentDouble = { -- two staggered crescents: two bodies 0.08 s apart
		priority = 3, rolloff = "melee",
		layers = {
			{ ids = takes(3), search = "blade slice swipe", volume = 0.4, peak = 0.003 },
			{ ids = takes(3), search = "fast sword whoosh", volume = 0.5 },
			{ ids = takes(3), search = "fast sword whoosh", volume = 0.42, delay = 0.08, pitch = NumberRange.new(1.05, 1.12) },
			{ ids = takes(1), search = "magic sparkle shimmer", volume = 0.12, delay = 0.05, pitch = NumberRange.new(1.25, 1.4) },
		},
	},
	OverheadCleave = { -- vertical crescent into a ground crack
		priority = 3, rolloff = "ability",
		layers = {
			{ ids = takes(3), search = "heavy weapon swing whoosh low", volume = 0.5, pitch = NumberRange.new(0.88, 0.95) },
			{ ids = takes(3), search = "heavy ground impact hit", volume = 0.7, delay = 0.11, peak = 0.004 },
			{ ids = takes(3), search = "rock debris crumble", volume = 0.3, delay = 0.17, pitch = NumberRange.new(0.65, 0.75) },
		},
	},
	ThrustPierce = { -- forward stab: tight air pierce, bright ring, shock thump
		priority = 3, rolloff = "melee", choke = true,
		layers = {
			{ ids = takes(3), search = "spear stab whoosh short", volume = 0.5, peak = 0.05 },
			{ ids = takes(1), search = "blade ring shing metal", volume = 0.14, pitch = NumberRange.new(1.6, 1.7) },
			{ ids = takes(3), search = "body punch impact thump", volume = 0.3, delay = 0.05, pitch = NumberRange.new(1.25, 1.35) },
		},
	},
	DashTrail = {
		priority = 2, rolloff = "melee", choke = true,
		layers = {
			{ ids = takes(3), search = "dash launch thump", volume = 0.35, peak = 0.004, pitch = NumberRange.new(0.78, 0.85) },
			{ ids = takes(3), search = "fast whoosh pass by", volume = 0.5, pitch = NumberRange.new(1.08, 1.15) },
			{ ids = takes(3), search = "wind whoosh tail", volume = 0.25, delay = 0.15 },
		},
	},
	HitSpark = { -- neutral contact: predicted on the attacker's client; outcome stings come from the server
		priority = 4, rolloff = "melee", maxInstances = 4,
		layers = {
			{ ids = takes(3), search = "sword hit impact flesh", volume = 0.6, peak = 0.004, pitch = NumberRange.new(0.95, 1.08) },
			{ ids = takes(3), search = "metal hit clang short", volume = 0.18, pitch = NumberRange.new(1.2, 1.28) },
			{ ids = takes(3), search = "impact grit debris small", volume = 0.2, pitch = NumberRange.new(0.8, 0.9) },
		},
	},
	ChargeUp = { -- riser: starts with the effect (peak 0), fixed pitch so it stays a learned cue
		priority = 3, rolloff = "ability", choke = true, caption = "Heavy attack charging",
		layers = {
			{ ids = takes(1), search = "energy charge riser power up", volume = 0.45, pitch = FIXED },
			{ ids = takes(1), search = "metal ping ting bright", volume = 0.12, delay = 0.95, pitch = NumberRange.new(2, 2) },
		},
	},
	IceExplosion = {
		priority = 4, rolloff = "explosion", caption = "Ice explosion",
		layers = {
			{ ids = takes(1), search = "ice impact hit", volume = 0.5, peak = 0.004, pitch = NumberRange.new(1.15, 1.25) },
			{ ids = takes(1), search = "ice shatter glass break", volume = 0.7 },
			{ ids = takes(1), search = "ice crackle freeze", volume = 0.35, delay = 0.15 },
			{ ids = takes(1), search = "cold wind whoosh", volume = 0.18, pitch = NumberRange.new(0.68, 0.74) },
		},
	},
	IceBallCharge = { -- ChargeStart of the IceBall cast
		priority = 3, rolloff = "ability", choke = true,
		layers = {
			{ ids = takes(1), search = "ice magic charge", volume = 0.35, pitch = NumberRange.new(1.3, 1.3) },
			{ ids = takes(1), search = "ice crackle freeze", volume = 0.2, delay = 0.2 },
		},
	},
	IceBallRelease = {
		priority = 3, rolloff = "ability",
		layers = {
			{ ids = takes(3), search = "magic projectile whoosh", volume = 0.5, pitch = NumberRange.new(1.15, 1.25) },
			{ ids = takes(1), search = "ice sparkle crackle", volume = 0.18, pitch = NumberRange.new(1.4, 1.5) },
		},
	},
	LightningBallCharge = {
		priority = 3, rolloff = "ability", choke = true,
		layers = {
			{ ids = takes(1), search = "electric charge riser", volume = 0.3, pitch = NumberRange.new(0.9, 0.9) },
			{ ids = takes(1), search = "electric buzz hum", volume = 0.3, pitch = NumberRange.new(0.65, 0.75) },
			{ ids = takes(1), search = "electric zap spark", volume = 0.22, delay = 0.35, pitch = NumberRange.new(0.75, 0.85) },
		},
	},
	LightningBallRelease = {
		priority = 3, rolloff = "ability",
		layers = {
			{ ids = takes(1), search = "electric zap spark", volume = 0.5, peak = 0.013 },
			{ ids = takes(1), search = "magic projectile whoosh", volume = 0.35, pitch = NumberRange.new(0.8, 0.9) },
		},
	},
	LightningExplosion = {
		priority = 4, rolloff = "explosion", caption = "Lightning strike",
		layers = {
			{ ids = takes(1), search = "thunder crack close lightning strike", volume = 0.75, peak = 0.003, pitch = NumberRange.new(0.92, 1.02) },
			{ ids = takes(1), search = "electric zap spark", volume = 0.4 },
			{ ids = takes(1), search = "heavy ground impact hit", volume = 0.35, peak = 0.004 },
		},
	},
	GroundImpact = { -- Impact marker without an element (GroundSlam)
		priority = 3, rolloff = "ability",
		layers = {
			{ ids = takes(3), search = "ground slam heavy impact", volume = 0.65, peak = 0.004 },
			{ ids = takes(3), search = "rock debris crumble", volume = 0.25, delay = 0.08, pitch = NumberRange.new(0.6, 0.7) },
		},
	},
	-- Outcome layers: played when the server's result arrives (never predicted)
	Blocked = { -- dry, no tail
		priority = 4, rolloff = "melee",
		layers = { { ids = takes(3), search = "sword block parry metal clash", volume = 0.45, peak = 0.003 } },
	},
	Crit = { -- tonal sting above the impact's range; 2D for the attacker
		priority = 5, group = "SFX",
		layers = { { ids = takes(1), search = "critical hit sting metal ring", volume = 0.35, pitch = NumberRange.new(1.5, 1.5) } },
	},
	Kill = { priority = 5, layers = { { ids = takes(1), search = "kill confirm sting", volume = 0.35, pitch = FIXED } } },
	Footstep = { -- one def per surface in a real game (concrete, grass, wood, metal)
		priority = 1, rolloff = "footstep", cooldown = 0.08, maxInstances = 2,
		layers = { { ids = takes(4), search = "footstep concrete shoe", volume = 0.3, peak = 0.005, pitch = NumberRange.new(0.92, 1.08) } },
	},
	-- UI (2D, UI bus): one family, quiet, consistent pitch ladder
	UIHover = { group = "UI", cooldown = 0.06, layers = { { ids = takes(1), search = "ui hover tick soft", volume = 0.15, pitch = NumberRange.new(0.98, 1.02) } } },
	UIClick = { group = "UI", cooldown = 0.04, layers = { { ids = takes(3), search = "ui button click", volume = 0.35 } } },
	UIConfirm = { group = "UI", layers = { { ids = takes(1), search = "ui confirm positive", volume = 0.35, pitch = FIXED } } },
	UIError = { group = "UI", cooldown = 0.2, layers = { { ids = takes(1), search = "ui error negative", volume = 0.3, pitch = FIXED } } },
	CoinPickup = { group = "UI", cooldown = 0.05, maxInstances = 3, layers = { { ids = takes(3), search = "coin pickup collect", volume = 0.3 } } },
} :: { [string]: SoundDef }

-- Marker maps. Hit values follow the LihFolkVFX sword clips.
local HIT_BY_PARAM: { [string]: string } = {
	["1"] = "CrescentDouble",
	["2"] = "CrescentDouble",
	["3"] = "OverheadCleave",
	heavy = "SlashSweep",
	dash = "CrescentDouble",
	thrust = "ThrustPierce",
}
local IMPACT_BY_PARAM: { [string]: string } = {
	ice = "IceExplosion",
	lightning = "LightningExplosion",
}
LihFolkSFX.Maps = {
	Default = {
		TrailOn = "Swing",
		Hit = function(param: string): string?
			return HIT_BY_PARAM[param] or "CrescentDouble"
		end,
		DashStart = "DashTrail",
		Impact = function(param: string): string?
			return IMPACT_BY_PARAM[param] or "GroundImpact"
		end,
		Deflect = "Blocked",
		Footstep = "Footstep",
	} :: MarkerMap,
	IceBallCast = { ChargeStart = "IceBallCharge", Release = "IceBallRelease", Impact = "IceExplosion" } :: MarkerMap,
	LightningBallCast = {
		ChargeStart = "LightningBallCharge",
		Release = "LightningBallRelease",
		Impact = "LightningExplosion",
	} :: MarkerMap,
}

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
type Voice = {
	sound: Sound,
	anchor: Attachment?, -- for Vector3 targets, parented to Terrain
	name: string,
	priority: number,
	startedAt: number,
	busyUntil: number,
	serial: number,
}

type Bag = { queue: { string }, last: string? }

local rng = Random.new()
local voices: { Voice } = {}
local bags: { [Layer]: Bag } = {}
local lastPlayed: { [string]: number } = {}
local warned: { [string]: boolean } = {}
local buses: { [string]: SoundGroup } = {}
local poolFolder: Folder? = nil
local captionHandler: ((text: string, position: Vector3?) -> ())? = nil

if not RunService:IsClient() then
	warn("LihFolkSFX is client-only: require it from a LocalScript (cosmetic sounds play on each client)")
end

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn("[LihFolkSFX] " .. message)
	end
end

local function isRealId(id: string): boolean
	return id ~= "" and string.find(id, "REPLACE_ME", 1, true) == nil
end

local function getPool(): Folder
	local f = poolFolder
	if f and f.Parent then
		return f
	end
	local folder = Instance.new("Folder")
	folder.Name = "LihFolkSFXPool"
	folder.Parent = SoundService
	poolFolder = folder
	return folder
end

-------------------------------------------------------------------------------
-- Buses
-------------------------------------------------------------------------------
local function findOrMakeGroup(parent: Instance, name: string): SoundGroup
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing :: SoundGroup
	end
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = LihFolkSFX.BusBase[name] or 1
	g.Parent = parent
	return g
end

--[[ Create (or adopt existing) SoundService.Master with SFX / Music / UI / Ambience nested inside. ]]
function LihFolkSFX.setupBuses(): SoundGroup
	local master = buses.Master
	if master and master.Parent then
		return master
	end
	master = findOrMakeGroup(SoundService, "Master")
	buses.Master = master
	for _, name in BUS_CHILDREN do
		buses[name] = findOrMakeGroup(master, name)
	end
	return master
end

function LihFolkSFX.getBus(name: string): SoundGroup?
	LihFolkSFX.setupBuses()
	return buses[name]
end

--[[ Player volume setting: slider 0..1 -> SoundGroup.Volume = base * slider^2 (perceptual curve). ]]
function LihFolkSFX.setBusVolume(name: string, slider: number)
	local bus = LihFolkSFX.getBus(name)
	if not bus then
		warnOnce("bus:" .. name, "unknown bus " .. name)
		return
	end
	local v = math.clamp(slider, 0, 1)
	bus.Volume = (LihFolkSFX.BusBase[name] or 1) * v * v
end

-------------------------------------------------------------------------------
-- Voices (pool + cap + stealing)
-------------------------------------------------------------------------------
local function newVoice(): Voice
	local sound = Instance.new("Sound")
	sound.Name = "LihFolkSFXVoice"
	sound.Parent = getPool()
	local voice: Voice = {
		sound = sound,
		anchor = nil,
		name = "",
		priority = 0,
		startedAt = 0,
		busyUntil = 0,
		serial = 0,
	}
	-- Back to the pool when it finishes (a re-played sound is still playing: leave it).
	sound.Ended:Connect(function()
		if not sound.IsPlaying then
			voice.busyUntil = 0
			sound.Parent = getPool()
		end
	end)
	-- Destroyed with a target part: forget it (and its anchor) so the pool never holds dead sounds.
	sound.Destroying:Connect(function()
		local i = table.find(voices, voice)
		if i then
			table.remove(voices, i)
		end
		local a = voice.anchor
		if a then
			voice.anchor = nil
			a:Destroy()
		end
	end)
	return voice
end

local function isFree(v: Voice, now: number): boolean
	return now >= v.busyUntil and not v.sound.IsPlaying
end

local function acquire(priority: number, now: number): Voice?
	for _, v in voices do
		if isFree(v, now) then
			return v
		end
	end
	if #voices < LihFolkSFX.Config.maxVoices then
		local v = newVoice()
		table.insert(voices, v)
		return v
	end
	-- Full: steal the lowest-priority voice (oldest first) that is not above the new sound.
	local victim: Voice? = nil
	for _, v in voices do
		if v.priority <= priority then
			if victim == nil or v.priority < victim.priority or (v.priority == victim.priority and v.startedAt < victim.startedAt) then
				victim = v
			end
		end
	end
	return victim
end

local function release(v: Voice)
	v.serial += 1
	v.busyUntil = 0
	v.sound:Stop()
	v.sound.Parent = getPool()
end

local function liveOf(name: string, now: number): { Voice }
	local list = {}
	for _, v in voices do
		if v.name == name and not isFree(v, now) then
			table.insert(list, v)
		end
	end
	table.sort(list, function(a: Voice, b: Voice): boolean
		return a.startedAt < b.startedAt
	end)
	return list
end

-------------------------------------------------------------------------------
-- Layers
-------------------------------------------------------------------------------
-- Round-robin bag: shuffle the takes, draw without replacement, never the same take twice in a row.
local function nextId(layer: Layer): string?
	local n = #layer.ids
	if n == 0 then
		return nil
	end
	if n == 1 then
		return layer.ids[1]
	end
	local bag = bags[layer]
	if not bag then
		bag = { queue = {}, last = nil }
		bags[layer] = bag
	end
	if #bag.queue == 0 then
		local q = table.clone(layer.ids)
		for i = #q, 2, -1 do
			local j = rng:NextInteger(1, i)
			q[i], q[j] = q[j], q[i]
		end
		if q[#q] == bag.last then
			q[1], q[#q] = q[#q], q[1]
		end
		bag.queue = q
	end
	local id = table.remove(bag.queue)
	bag.last = id
	return id
end

local function resolveRolloff(value: (string | Rolloff)?): Rolloff?
	if value == nil then
		return nil
	end
	if type(value) == "string" then
		return (LihFolkSFX.Rolloff :: { [string]: Rolloff })[value]
	end
	return value
end

local function targetPosition(at: Target): Vector3?
	if typeof(at) == "Vector3" then
		return at
	end
	local inst = at :: Instance
	if not inst:IsDescendantOf(Workspace) then
		return nil
	end
	if inst:IsA("Attachment") then
		return inst.WorldPosition
	elseif inst:IsA("BasePart") then
		return inst.Position
	end
	return nil
end

type Play = { cancelled: boolean, started: { { voice: Voice, serial: number } } }

local function startLayer(name: string, def: SoundDef, layer: Layer, at: Target?, opts: PlayOptions, token: Play)
	if token.cancelled then
		return
	end
	local id = nextId(layer)
	if id == nil or not isRealId(id) then
		warnOnce(
			"id:" .. name,
			("'%s' has placeholder ids (search: %s): paste a Roblox-licensed Creator Store id or your licensed upload"):format(
				name,
				layer.search or "?"
			)
		)
		return
	end
	if layer.source == nil then
		warnOnce("src:" .. name, ("'%s' has real ids with no `source`: note where they came from and their licence"):format(name))
	end
	local roll = resolveRolloff(layer.rolloff or def.rolloff)
	local position: Vector3? = nil
	if at ~= nil then
		position = targetPosition(at)
		if position == nil then
			return -- the part left the world (delayed layer after its owner was removed)
		end
		local camera = Workspace.CurrentCamera
		if roll and camera and (camera.CFrame.Position - position).Magnitude > roll.max then
			return -- distance gate: never start a sound nobody can hear
		end
	end

	local now = os.clock()
	local priority = opts.priority or def.priority or LihFolkSFX.Config.defaultPriority
	local voice = acquire(priority, now)
	if not voice then
		return
	end
	release(voice)
	local s = voice.sound
	local pitchRange = layer.pitch or LihFolkSFX.Config.pitch
	local jitter = layer.volumeJitter or LihFolkSFX.Config.volumeJitter
	local speed = rng:NextNumber(pitchRange.Min, pitchRange.Max) * (opts.pitch or 1)
	s.SoundId = id
	s.SoundGroup = LihFolkSFX.getBus(layer.group or def.group or "SFX")
	s.Volume = (layer.volume or 0.5) * (1 + rng:NextNumber(-jitter, jitter)) * (opts.volume or 1)
	s.PlaybackSpeed = speed
	if roll then
		s.RollOffMode = roll.mode or Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = roll.min
		s.RollOffMaxDistance = roll.max
	end
	local skip = if opts.onBeat then (layer.peak or 0) else 0
	s.TimePosition = skip

	if at == nil then
		s.Parent = getPool() -- not under a part or attachment: 2D
	elseif typeof(at) == "Vector3" then
		local anchor = voice.anchor
		if not anchor then
			local a = Instance.new("Attachment")
			a.Name = "LihFolkSFXAnchor"
			a.Parent = Workspace.Terrain
			voice.anchor = a
			anchor = a
		end
		anchor.WorldPosition = at
		s.Parent = anchor
	else
		s.Parent = at :: Instance -- follows the part or attachment
	end

	voice.name = name
	voice.priority = priority
	voice.startedAt = now
	local length = if s.TimeLength > 0 then (s.TimeLength - skip) / speed else LihFolkSFX.Config.unloadedLength
	voice.busyUntil = now + math.max(0.05, length)
	s:Play()
	table.insert(token.started, { voice = voice, serial = voice.serial })
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------
function LihFolkSFX.register(name: string, def: SoundDef)
	LihFolkSFX.Defs[name] = def
end

--[[ Who hears captions: pass a function that shows `text` (see "Captions and Audio Accessibility"). ]]
function LihFolkSFX.setCaptionHandler(handler: ((text: string, position: Vector3?) -> ())?)
	captionHandler = handler
end

--[[ Play a named sound. `at`: BasePart / Attachment (follows it) or Vector3 (fixed point); nil = 2D.
	Returns cancel(stopPlaying?): cancels delayed layers; stops started ones unless stopPlaying == false. ]]
function LihFolkSFX.play(name: string, at: Target?, options: PlayOptions?): Cancel
	local token: Play = { cancelled = false, started = {} }
	local function cancel(stopPlaying: boolean?)
		token.cancelled = true
		if stopPlaying ~= false then
			for _, entry in token.started do
				if entry.voice.serial == entry.serial then
					release(entry.voice)
				end
			end
		end
		table.clear(token.started)
	end

	local def = LihFolkSFX.Defs[name]
	if not def then
		warnOnce("def:" .. name, "no sound definition named " .. name)
		return cancel
	end
	local opts: PlayOptions = options or {}
	local now = os.clock()
	if now - (lastPlayed[name] or -math.huge) < (def.cooldown or LihFolkSFX.Config.defaultCooldown) then
		return cancel
	end
	lastPlayed[name] = now

	local live = liveOf(name, now)
	if def.choke then
		for _, v in live do
			release(v)
		end
	else
		local cap = def.maxInstances or LihFolkSFX.Config.defaultMaxInstances
		local extra = #live + #def.layers - cap
		for i = 1, math.min(extra, #live) do
			release(live[i]) -- cut the oldest copies of this name
		end
	end

	if def.caption and captionHandler then
		local pos = if at ~= nil then targetPosition(at) else nil
		task.spawn(captionHandler, def.caption, pos)
	end

	for _, layer in def.layers do
		local d = layer.delay or 0
		if d > 0 then
			task.delay(d, startLayer, name, def, layer, at, opts, token)
		else
			startLayer(name, def, layer, at, opts, token)
		end
	end
	return cancel
end

--[[ 2D sound for menus and HUD (non-positional, the def's bus; UI defs use the UI bus). ]]
function LihFolkSFX.playUI(name: string, options: PlayOptions?): Cancel
	return LihFolkSFX.play(name, nil, options)
end

--[[ Play sounds on an AnimationTrack's KeyframeMarkers. map: marker -> sound name, or a function of the
	marker's value returning a name (nil = silent). Marker plays are onBeat: transients land on the marker. ]]
function LihFolkSFX.bindToTrack(track: AnimationTrack, map: MarkerMap, at: Target?, options: BindOptions?): () -> ()
	local bind: BindOptions = options or {}
	local opts: PlayOptions = { onBeat = true, volume = bind.volume }
	local conns: { RBXScriptConnection } = {}
	local pending: { Cancel } = {}

	local function unbind()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
	end

	for marker, entry in map do
		table.insert(conns, track:GetMarkerReachedSignal(marker):Connect(function(param: string)
			local name: string? = if type(entry) == "function" then entry(param) else entry
			if name then
				table.insert(pending, LihFolkSFX.play(name, at, opts))
				if #pending > 8 then
					table.remove(pending, 1)
				end
			end
		end))
	end

	local onPlay = bind.onPlay
	local anim = track.Animation
	local startName = if onPlay and anim then onPlay[anim.Name] else nil
	local startCancel: Cancel? = nil
	if startName then
		startCancel = LihFolkSFX.play(startName, at, { volume = bind.volume })
	end

	table.insert(conns, track.Stopped:Connect(function()
		-- an interrupted move drops its scheduled layers; ringing tails finish
		for _, c in pending do
			c(false)
		end
		table.clear(pending)
		if startCancel then
			startCancel(true) -- the charge riser stops with its clip
			startCancel = nil
		end
		if bind.autoUnbind then
			unbind()
		end
	end))
	return unbind
end

--[[ Bind every track the animator plays (each binding ends when its track stops). ]]
function LihFolkSFX.bindAnimator(animator: Animator, map: MarkerMap, at: Target?, options: BindOptions?): () -> ()
	local base: BindOptions = options or {}
	local bind: BindOptions = { volume = base.volume, onPlay = base.onPlay, autoUnbind = true }
	local unbinds: { () -> () } = {}
	local conn = animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		local u = LihFolkSFX.bindToTrack(track, map, at, bind)
		table.insert(unbinds, u)
		if #unbinds > 32 then
			table.remove(unbinds, 1) -- old tracks already unbound themselves on Stopped
		end
	end)
	return function()
		conn:Disconnect()
		for _, u in unbinds do
			u()
		end
		table.clear(unbinds)
	end
end

--[[ Fetch every real id (or only those of `names`) so the first hit is not late. Call on equip/spawn. ]]
function LihFolkSFX.preload(names: { string }?)
	local list: { string } = {}
	local seen: { [string]: boolean } = {}
	local function addDef(def: SoundDef)
		for _, layer in def.layers do
			for _, id in layer.ids do
				if isRealId(id) and not seen[id] then
					seen[id] = true
					table.insert(list, id)
				end
			end
		end
	end
	if names then
		for _, n in names do
			local def = LihFolkSFX.Defs[n]
			if def then
				addDef(def)
			end
		end
	else
		for _, def in LihFolkSFX.Defs do
			addDef(def)
		end
	end
	if #list > 0 then
		task.spawn(function()
			ContentProvider:PreloadAsync(list)
		end)
	end
end

--[[ Stop every live voice (menu opened, cutscene, character reset). ]]
function LihFolkSFX.stopAll()
	for _, v in voices do
		release(v)
	end
end

return LihFolkSFX
