--!strict
--[[
	LihFolkVFX: stylised slash VFX on one Heartbeat-driven timeline (client only).

	Presets (default element in brackets)
	  SlashSweep      heavy wide sweep across the front, two layered crescents (teal); no weapon Trail
	                  (SlashRing is an alias: the old 350 deg ring broke the frontal rule)
	  CrescentDouble  two staggered crescents (violet)
	  ThrustPierce    forward stab: narrow layered cone + travelling shockwave rings (ice)
	  OverheadCleave  vertical crescent that lands in a ground crack + shockwave (fire)
	  DashTrail       afterimage streak along a dash: ghosts, ribbons, speed lines (lightning)
	  HitSpark        impact burst on a target: dark impact frame, star, rings, sparks (holy)
	  ChargeUp        gathering aura before a heavy: converging motes and rings, ready glint (teal)
	  IceExplosion    radial ice burst: frost flash, frost-crack ring, erupting crystal spikes that
	                  shatter, low cold mist, glitter (ice). Radial on purpose: not a slash
	  LightningExplosion  radial branching ground bolts, 2-3 f lightning column, scorched ring + glowing
	                  cracks, sparks, lingering static, faint smoke (plasma). UNTESTED IN STUDIO
	  SpinShock       SpinAttack per-turn ground dust/shock ring + radial grit (teal). Radial: spin move. UNTESTED IN STUDIO
	  SpinFinish      SpinAttack frontal finishing crescent (teal). UNTESTED IN STUDIO
	Sequences         playIceBallCast, playLightningBallCast, playSpinAttack (whirl trails, wind swirl,
	                  tangential sparks + the two presets above; UNTESTED IN STUDIO)
	Elements          teal, violet, fire, ice, lightning, plasma, void, holy (palette per role)

	Layer recipe per crescent/ring unit (times in seconds after the Hit marker):
	  flash (0-0.07) -> sweep-in (0.11-0.13, reveal textures + yaw sweep) -> hold (0.05)
	  -> brush erosion (0.36-0.40, 5 texture swaps then fade; smoothErode cross-fades them) ;
	  dark ink mesh over the body's inner half, additive flipbook glow card, hot edge Beam riding
	  the head, sparks/glints from the head, debris flung along the swing, ground ring, short light.
	Generic layers (the other presets): bursts (Emit), rings (expanding SpecialMesh), beams
	(growing ribbons), ghosts (afterimages), all on the same one-Heartbeat clock.

	Setup: upload VFX/Textures/*.png and VFX/Meshes/*.glb, paste the ids into
	LihFolkVFX.Textures / LihFolkVFX.Meshes (empty string = layer skipped, never a guessed id).
	See SKILL.md for the full layer table and the marker binding.
]]

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LihFolkVFX = {}

-------------------------------------------------------------------------------
-- Asset config: paste "rbxassetid://<id>" after uploading. "" = not uploaded yet.
-------------------------------------------------------------------------------
LihFolkVFX.Textures = {
	-- crescent / ring strips (mesh UV: u along arc tail->head, v inner->outer)
	strip_body = "",
	strip_body_reveal_1 = "",
	strip_body_reveal_2 = "",
	strip_body_reveal_3 = "",
	strip_body_erode_1 = "",
	strip_body_erode_2 = "",
	strip_body_erode_3 = "",
	strip_body_erode_4 = "",
	strip_body_erode_5 = "",
	strip_ink = "",
	strip_ink_erode_1 = "",
	strip_ink_erode_2 = "",
	strip_ink_erode_3 = "",
	strip_ground_ring = "",
	-- wide-stroke ink (SlashSweep)
	strip_ink_wide = "",
	-- soft-edged body (SlashSweep): hold frame + 5 erosion stages for cross-fading
	strip_body_soft = "",
	strip_body_soft_reveal_1 = "",
	strip_body_soft_reveal_2 = "",
	strip_body_soft_reveal_3 = "",
	strip_body_soft_erode_1 = "",
	strip_body_soft_erode_2 = "",
	strip_body_soft_erode_3 = "",
	strip_body_soft_erode_4 = "",
	strip_body_soft_erode_5 = "",
	strip_ink_wide_erode_1 = "",
	strip_ink_wide_erode_2 = "",
	strip_ink_wide_erode_3 = "",
	-- 1024 flipbooks (4x4: frames 0-3 sweep-in, 4-5 hold, 6-15 erode)
	flip_crescent_4x4 = "",
	flip_crescent_ink_4x4 = "",
	flip_ring_4x4 = "",
	flip_ring_ink_4x4 = "",
	flip_petals_8x8 = "",
	flip_glint_4x4 = "",
	-- sprites
	flash_hot = "",
	glow_soft = "",
	glint_star4 = "",
	spark_streak = "",
	spark_square = "",
	ground_disc_faint = "",
	ground_ring_card = "",
	ground_crack = "",
	ground_frost = "",
	frost_ring = "",
	crystal_facets = "",
	shard_A = "",
	beam_edge_h = "", -- leave "" for a solid hot-edge ribbon (works without any upload)
	trail_soft = "",
	-- SpinAttack v2 (VFX/_src/build_textures_spin.py)
	rune_circle = "", -- carved sigil ring under the spin pivot (Decal on a flat part)
	smoke_puff = "", -- billowy dust puff with value variation
	god_ray = "", -- soft tapered light shaft (Beam, Stretch; SpinFinish v2.1)
}

LihFolkVFX.Meshes = {
	crescent_single_thick = "",
	crescent_single_thin = "",
	crescent_double = "",
	crescent_tilted = "",
	ring_full_dish = "",
	crescent_single_thick_hd = "", -- 72 segments: smooth outline at 8+ studs (SlashSweep)
	crystal = "", -- hexagonal ice prism, 1 x 1 stud along Y (IceExplosion spikes)
	ice_mound = "", -- low faceted icy dome, 1 stud wide (IceExplosion)
	ring_full_dish_hd = "", -- 112 segments (legacy ring; rings are not used by the frontal presets)
	ring_full_thin = "",
	ground_ring = "",
}

LihFolkVFX.Sounds = {
	-- { id = "rbxassetid://<id>", peak = seconds from sound start to its crack } ; id "" = silent
	slash = { id = "", peak = 0.08, volume = 0.6 },
	ring = { id = "", peak = 0.12, volume = 0.7 },
	thrust = { id = "", peak = 0.05, volume = 0.6 },
	cleave = { id = "", peak = 0.1, volume = 0.75 },
	dash = { id = "", peak = 0.04, volume = 0.5 },
	spark = { id = "", peak = 0.02, volume = 0.6 },
	charge = { id = "", peak = 0, volume = 0.5 }, -- a riser: starts with the effect, no skip
	ice = { id = "", peak = 0.03, volume = 0.75 },
	thunder = { id = "", peak = 0.02, volume = 0.8 }, -- LightningExplosion
}

LihFolkVFX.Config = {
	meshYawOffset = 0, -- degrees; set once if your import faces the arc the wrong way (head must end on the swing's far side)
	cardRotation = 0, -- degrees added to flat-card Rotation; tune once so the card head matches the mesh head
	maxActive = 8, -- effects alive at once (new non-important casts are dropped beyond this)
	maxLiveParticles = 900, -- PC; mobile is set below
	cullDistance = 220, -- studs from the camera: skip entirely
	lowDetailDistance = 160, -- studs: decoration layers off, counts halved
	quality = 1, -- 0..1, scale for every Emit count; set from your settings menu
}
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	LihFolkVFX.Config.quality = 0.6
	LihFolkVFX.Config.maxLiveParticles = 360
end

-------------------------------------------------------------------------------
-- Palettes (roles: main body, hot rim, dark ink, glow, spark, debris)
-------------------------------------------------------------------------------
export type Palette = {
	main: Color3,
	hot: Color3,
	dark: Color3,
	glow: Color3,
	spark: Color3,
	debris: Color3,
	debrisLight: number?, -- LightEmission for debris (0 = solid dark petals)
}

local rgb = Color3.fromRGB
LihFolkVFX.Elements = {
	teal = { main = rgb(40, 215, 195), hot = rgb(225, 255, 250), dark = rgb(5, 20, 24), glow = rgb(60, 255, 220), spark = rgb(185, 255, 240), debris = rgb(8, 12, 14) },
	violet = { main = rgb(120, 48, 255), hot = rgb(242, 234, 255), dark = rgb(40, 12, 100), glow = rgb(125, 70, 255), spark = rgb(205, 180, 255), debris = rgb(16, 6, 34) },
	fire = { main = rgb(255, 105, 25), hot = rgb(255, 242, 205), dark = rgb(38, 8, 3), glow = rgb(255, 150, 40), spark = rgb(255, 205, 110), debris = rgb(28, 9, 5) },
	ice = { main = rgb(85, 185, 255), hot = rgb(235, 250, 255), dark = rgb(8, 24, 46), glow = rgb(135, 215, 255), spark = rgb(220, 245, 255), debris = rgb(170, 220, 245), debrisLight = 0.3 },
	lightning = { main = rgb(255, 225, 55), hot = rgb(255, 255, 238), dark = rgb(28, 22, 58), glow = rgb(255, 238, 110), spark = rgb(255, 255, 200), debris = rgb(18, 16, 38) },
	-- void: inverted treatment (dark body, bright magenta rim) so it still reads in dark zones
	void = { main = rgb(60, 18, 98), hot = rgb(255, 95, 232), dark = rgb(4, 0, 10), glow = rgb(205, 60, 255), spark = rgb(255, 140, 240), debris = rgb(3, 0, 7) },
	-- plasma: lightning ball (white core, electric cyan, violet edges, dark ink); the yellow `lightning` stays for DashTrail
	plasma = { main = rgb(70, 215, 255), hot = rgb(246, 252, 255), dark = rgb(14, 8, 40), glow = rgb(150, 95, 255), spark = rgb(175, 238, 255), debris = rgb(10, 8, 26) },
	holy = { main = rgb(255, 212, 115), hot = rgb(255, 255, 240), dark = rgb(70, 48, 18), glow = rgb(255, 228, 150), spark = rgb(255, 246, 205), debris = rgb(255, 240, 205), debrisLight = 0.4 },
}

-------------------------------------------------------------------------------
-- Presets: the layer tables. Angles in degrees, sizes in studs, times in seconds.
-- Positions are { x, y, z } in a named space: "body" = the cf you pass (x right, y up, -z forward),
-- "swing" = body after flip/tilt/yaw, "ground" = flat on the floor under body (floor studs down),
-- "path" = offset from the current dash head (DashTrail).
-- Colour roles: main, hot, dark, glow, spark, debris (palette) + deep (main 50 % toward dark).
-------------------------------------------------------------------------------
export type Unit = {
	shape: string, -- "ring" | "crescent"
	mesh: string, -- key in LihFolkVFX.Meshes
	card: string, -- flipbook key for the additive glow card
	inkCard: string?, -- flipbook key for the dark card
	cardROut: number, -- outer radius of the arc inside a card cell (0..1)
	radius: number,
	span: number,
	delay: number,
	lift: number,
	tilt: number,
	yaw: number,
	sweep: number,
	hold: number,
	erode: number,
	sweepEase: number, -- exponent of the ease-out on the reveal (2 = quad out)
	drift: number, -- degrees of extra rotation through the erode
	inkLag: number, -- degrees the ink smear trails behind the body
	inkDrop: number, -- studs below the body; negative = painted over the body's inner half (reads on dark stages)
	inkScale: number, -- ink radius / body radius; ~1 so the dark smear overlaps the body's inner half (it must overlap something bright to read)
	bodyGain: number, -- VertexColor multiplier for the body
	cardBrightness: number,
	cardTransparency: number,
	edge: { width: number, band: number, life: number, brightness: number, lift: number? }, -- lift: x radius, puts the beam on the mesh's raised lip
	sparks: number,
	glints: number,
	debris: number,
	squares: number,
	debrisSize: number, -- petal size multiplier
	glintSize: number, -- studs
	body: string?, -- body erosion family for smoothErode ("strip_body" default, "strip_body_soft" = broad soft strokes)
	ink: string?, -- ink strip family ("strip_ink" default, "strip_ink_wide" = broad strokes)
	smoothErode: boolean?, -- cross-fade erosion stages with a second mesh (no stepped pops; +1 mesh per layer)
	rim: number?, -- white-hot rim along the whole arc after the sweep (strip_edge mesh layer, VertexColor gain); nil = off
	fwd: number?, -- forward bias added to head-spawned sparks/debris (keeps the mess in front)
	cards: boolean?, -- false = no flipbook glow/ink cards (their hairline erosion bands show on a full ring)
	expand: number?, -- extra scale gained through the erode (default 0.04): the shape keeps opening as it dies
}

export type Preset = {
	element: string?, -- default element
	units: { Unit }?,
	flash: { size: number, life: number, brightness: number, forward: number?, at: { number }?, space: string?, t: number? }?,
	ground: { drop: number, radius: number, life: number, transparency: number, ring: boolean?, discRole: string?, discLe: number?, discBright: number?, forward: number? }?,
	light: { brightness: number, range: number, life: number, rise: number?, at: { number }?, space: string?, t: number? },
	bursts: { any }?, -- particle bursts / single cards (see buildBurst)
	rings: { any }?, -- expanding or converging SpecialMesh rings (see buildRing)
	beams: { any }?, -- growing ribbons (see buildBeam)
	ghosts: any?, -- afterimages of opts.character (see buildGhosts)
	spikes: any?, -- crystal spikes erupting from a point, then shattering (see buildSpikes)
	bolts: { any }?, -- jagged lightning polylines (see buildBolts; LightningExplosion). UNTESTED IN STUDIO
	dash: { distance: number, duration: number, pow: number }?, -- predicted head path for "path" space
	floor: number?, -- studs from the cf down to the floor (default ground.drop or 3)
	lead: number?, -- ChargeUp: seconds from start to release (bindings retime it to the clip)
	trail: boolean?, -- false = the weapon Trail must stay off for this move (spins)
	sound: string,
	life: number, -- whole effect incl. lingering particles
}

LihFolkVFX.Presets = {
	-- Heavy wide sweep across the front (replaces the old 350 deg SlashRing: slashes stay in front).
	SlashSweep = {
		element = "teal",
		trail = false, -- a Trail across a 200 deg heavy sweep draws a solid wedge; the arc already shows the path
		units = {
			{
				shape = "crescent", mesh = "crescent_single_thick_hd", card = "flip_crescent_4x4", inkCard = "flip_crescent_ink_4x4",
				cardROut = 0.9, radius = 9, span = 200, delay = 0, lift = -0.9, tilt = 4, yaw = 0,
				sweep = 0.12, hold = 0.04, erode = 0.36, sweepEase = 2.2, drift = 10, inkLag = 18, inkDrop = -0.1,
				inkScale = 1.0, bodyGain = 1.2, cardBrightness = 1.0, cardTransparency = 0.85,
				edge = { width = 1.4, band = 90, life = 0.4, brightness = 7 },
				sparks = 16, glints = 5, debris = 22, squares = 0, debrisSize = 1.8, glintSize = 3,
				ink = "strip_ink_wide", body = "strip_body_soft", smoothErode = true, cards = false, rim = 2.2,
				expand = 0.12, fwd = 0.7,
			},
			{
				shape = "crescent", mesh = "crescent_single_thin", card = "flip_crescent_4x4",
				cardROut = 0.9, radius = 7.2, span = 160, delay = 0.04, lift = -0.4, tilt = -5, yaw = 0,
				sweep = 0.11, hold = 0.03, erode = 0.3, sweepEase = 2.2, drift = 10, inkLag = 14, inkDrop = -0.1,
				inkScale = 0.98, bodyGain = 1.0, cardBrightness = 1.0, cardTransparency = 0.85,
				edge = { width = 1.0, band = 70, life = 0.3, brightness = 5 },
				sparks = 6, glints = 0, debris = 0, squares = 0, debrisSize = 1, glintSize = 2,
				body = "strip_body_soft", smoothErode = true, cards = false, fwd = 0.7,
			},
		},
		flash = { size = 7, life = 0.07, brightness = 5, forward = 6 },
		-- dark pool under the sweep, pushed forward (not a glow plate): the teal body reads against it
		ground = { drop = 1.7, radius = 7, life = 0.55, transparency = 0.3, ring = false, discRole = "dark", discLe = 0, discBright = 1, forward = 4 },
		light = { brightness = 3, range = 16, life = 0.35, at = { 0, 0, -5 }, space = "body" },
		sound = "ring",
		life = 1.1,
	} :: Preset,
	CrescentDouble = {
		element = "violet",
		units = {
			{
				shape = "crescent", mesh = "crescent_single_thick", card = "flip_crescent_4x4", inkCard = "flip_crescent_ink_4x4",
				cardROut = 0.9, radius = 8, span = 200, delay = 0, lift = 0.6, tilt = 10, yaw = 0,
				sweep = 0.11, hold = 0.05, erode = 0.36, sweepEase = 2.2, drift = 30, inkLag = 18, inkDrop = -0.1,
				inkScale = 0.98, bodyGain = 1.0, cardBrightness = 1.2, cardTransparency = 0.45,
				edge = { width = 1.3, band = 100, life = 0.34, brightness = 5 },
				sparks = 8, glints = 3, debris = 0, squares = 13, debrisSize = 1, glintSize = 2.2,
			},
			{
				shape = "crescent", mesh = "crescent_single_thick", card = "flip_crescent_4x4", inkCard = "flip_crescent_ink_4x4",
				cardROut = 0.9, radius = 6.6, span = 200, delay = 0.06, lift = -0.7, tilt = -12, yaw = -14,
				sweep = 0.11, hold = 0.05, erode = 0.36, sweepEase = 2.2, drift = 30, inkLag = 18, inkDrop = -0.1,
				inkScale = 0.98, bodyGain = 0.9, cardBrightness = 1.0, cardTransparency = 0.5,
				edge = { width = 1.1, band = 95, life = 0.34, brightness = 4.5 },
				sparks = 8, glints = 3, debris = 0, squares = 13, debrisSize = 1, glintSize = 2.2,
			},
		},
		flash = { size = 6, life = 0.06, brightness = 5, forward = 6 },
		ground = { drop = 3, radius = 7, life = 0.45, transparency = 0.65 },
		light = { brightness = 2.5, range = 16, life = 0.3 },
		sound = "slash",
		life = 1.3,
	} :: Preset,

	-- Forward stab: three nested cones (dark ink, element body, white needle) that shoot out and
	-- then collapse from the base, two converging wind lines, shockwave rings travelling down the line.
	ThrustPierce = {
		element = "ice",
		floor = 3,
		flash = { size = 5.5, life = 0.06, brightness = 5, at = { 1.0, 0.9, -5.5 }, space = "body" },
		light = { brightness = 2.5, range = 14, life = 0.25, at = { 1.0, 0.9, -6.5 }, space = "body" },
		beams = {
			{ t = 0, life = 0.44, from = { 1.0, 0.9, -2.4 }, to = { 1.0, 0.9, -15.5 }, grow = 0.07, growPow = 2.4,
				tailDelay = 0.1, tailPow = 1.6, tailMax = 0.85, width0 = 4.2, width1 = 0.2, shrink = 0.55, shrinkPow = 1.5,
				role = { "deep", "dark" }, le = 0, bright = 1, tex = "trail_soft", transp = 0.0, fadePow = 1.8,
				tailFade = 0.2, headFade = 0.1, zoff = -1 },
			{ t = 0, life = 0.42, from = { 1.0, 0.9, -2.2 }, to = { 1.0, 0.9, -15 }, grow = 0.06, growPow = 2.4,
				tailDelay = 0.08, tailPow = 1.5, tailMax = 0.9, width0 = 3.0, width1 = 0.05, shrink = 0.7, shrinkPow = 1.4,
				role = { "main", "glow" }, le = 1, bright = 3, tex = "beam_edge_h", transp = 0.05, fadePow = 1.6,
				tailFade = 0.5, headFade = 0, zoff = 0 },
			{ t = 0, life = 0.24, from = { 1.0, 0.9, -2 }, to = { 1.0, 0.9, -17.5 }, grow = 0.05, growPow = 2.4,
				tailDelay = 0.06, tailPow = 1.4, tailMax = 0.95, width0 = 0.9, width1 = 0, shrink = 1, shrinkPow = 1.5,
				role = { "glow", "hot" }, le = 1, bright = 6, tex = "beam_edge_h", transp = 0, fadePow = 2,
				tailFade = 0.6, headFade = 0, zoff = 1 },
			{ t = 0.01, life = 0.26, from = { 2.3, 2.0, -3 }, to = { 1.0, 0.9, -13 }, grow = 0.07, growPow = 2,
				tailDelay = 0.05, tailPow = 1.3, tailMax = 1, width0 = 0.55, width1 = 0.05, shrink = 1, shrinkPow = 1.3,
				role = { "glow", "hot" }, le = 1, bright = 3, tex = "beam_edge_h", transp = 0.2, fadePow = 1.6,
				tailFade = 0.7, headFade = 0, deco = true },
			{ t = 0.01, life = 0.26, from = { -0.3, -0.3, -3 }, to = { 1.0, 0.9, -13 }, grow = 0.07, growPow = 2,
				tailDelay = 0.05, tailPow = 1.3, tailMax = 1, width0 = 0.55, width1 = 0.05, shrink = 1, shrinkPow = 1.3,
				role = { "glow", "hot" }, le = 1, bright = 3, tex = "beam_edge_h", transp = 0.2, fadePow = 1.6,
				tailFade = 0.7, headFade = 0, deco = true },
		},
		rings = {
			{ mesh = "ground_ring", tex = "strip_ground_ring", role = "dark", le = 0, t = 0.03, life = 0.38, r0 = 0.8, r1 = 3.2,
				pow = 3, transp0 = 0.12, fadePow = 1.2, at = { 1.0, 0.9, -5.4 }, space = "body", plane = "forward", spin = 0 },
			{ mesh = "ground_ring", tex = "strip_ground_ring", role = "glow", le = 1, gain = 1.2, t = 0.02, life = 0.24,
				r0 = 0.7, r1 = 3.2, pow = 3, transp0 = 0.05, fadePow = 1.3, at = { 1.0, 0.9, -6 }, space = "body", plane = "forward", spin = 40 },
			{ mesh = "ground_ring", tex = "strip_ground_ring", role = "glow", le = 1, gain = 1.1, t = 0.06, life = 0.22,
				r0 = 0.5, r1 = 2.2, pow = 3, transp0 = 0.15, fadePow = 1.3, at = { 1.0, 0.9, -10.5 }, space = "body", plane = "forward", spin = -40, deco = true },
		},
		bursts = {
			{ tex = "spark_streak", role = { "hot", "spark" }, count = 14, t = 0, over = 0.05, at = { 1.0, 0.9, -5.5 }, space = "body",
				dir = "cone", spread = 9, speed = { 70, 115 }, drag = 5, life = { 0.16, 0.28 }, size = { { 0, 0.7 }, { 1, 0 } },
				transp = { { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }, orient = "vpar", le = 1, bright = 5, zoff = 1 },
			{ tex = "flip_glint_4x4", role = "hot", count = 2, t = 0.02, at = { 1.0, 0.9, -6.5 }, space = "body", dir = "sphere",
				radius = 0.8, speed = { 0.5, 1 }, life = { 0.18, 0.24 }, size = 2.6, grid = 4, mode = "oneshot", le = 1, bright = 6,
				zoff = 2, deco = true },
			{ tex = "flip_petals_8x8", role = "debris", debris = true, count = 10, t = 0.01, over = 0.06, at = { 1.0, 0.9, -6 },
				space = "body", dir = "cone", spread = 24, speed = { 30, 55 }, drag = 3, acc = { 0, -14, 0 }, life = { 0.45, 0.75 },
				size = { { 0, 0.5 }, { 0.15, 0.9 }, { 1, 0.55 } }, transp = { { 0, 0 }, { 0.7, 0 }, { 1, 1 } }, rot = { 0, 360 },
				rotSpeed = { -420, 420 }, grid = 8, mode = "random", bright = 1 },
		},
		trail = false, -- the cone already draws the stab; a Trail drags a streak from behind the back
		sound = "thrust",
		life = 0.95,
	} :: Preset,

	-- Overhead: a vertical crescent sweeping from behind the head down into the floor ~5.5 studs ahead,
	-- landing in a glowing ground crack with a shockwave ring, shards, dust and sparks.
	OverheadCleave = {
		element = "fire",
		floor = 3,
		units = {
			{
				shape = "crescent", mesh = "crescent_single_thick", card = "flip_crescent_4x4", inkCard = "flip_crescent_ink_4x4",
				cardROut = 0.9, radius = 7, span = 160, delay = 0, lift = 1.5, tilt = 90, yaw = -20,
				sweep = 0.1, hold = 0.04, erode = 0.36, sweepEase = 2.4, drift = 12, inkLag = 16, inkDrop = -0.1,
				inkScale = 0.98, bodyGain = 1.0, cardBrightness = 1.1, cardTransparency = 0.55,
				edge = { width = 1.5, band = 95, life = 0.32, brightness = 6 },
				sparks = 8, glints = 2, debris = 0, squares = 0, debrisSize = 1, glintSize = 2.4,
				smoothErode = true,
			},
		},
		rings = {
			{ mesh = "ground_ring", tex = "strip_ground_ring", role = "dark", le = 0, t = 0.07, life = 0.6, r0 = 1.2, r1 = 6.5,
				pow = 3, transp0 = 0.25, fadePow = 1.2, at = { 0, 0.05, -5.5 }, space = "ground", plane = "flat", spin = 0, deco = true },
			{ mesh = "ground_ring", tex = "strip_ground_ring", role = "glow", le = 1, gain = 1.2, t = 0.07, life = 0.42, r0 = 1,
				r1 = 8, pow = 3, transp0 = 0.05, fadePow = 1.3, at = { 0, 0.1, -5.5 }, space = "ground", plane = "flat", spin = 30 },
		},
		bursts = {
			{ tex = "ground_crack", role = "dark", le = 0, bright = 1, count = 1, t = 0.07, at = { 0, 0.06, -5.5 }, space = "ground",
				orient = "flat", size = { { 0, 6 }, { 0.08, 11 }, { 1, 11.5 } }, transp = { { 0, 0.05 }, { 0.75, 0.1 }, { 1, 1 } },
				life = { 1.1, 1.1 }, rot = { 20, 20 } },
			{ tex = "ground_crack", role = { "hot", "main" }, le = 1, bright = 4, count = 1, t = 0.07, at = { 0, 0.12, -5.5 },
				space = "ground", orient = "flat", size = { { 0, 6 }, { 0.1, 11 }, { 1, 11.5 } },
				transp = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } }, life = { 0.9, 0.9 }, rot = { 20, 20 }, zoff = 0.5 },
			{ tex = "flash_hot", role = "hot", count = 1, t = 0.07, at = { 0, 1, -5.5 }, space = "ground",
				size = { { 0, 0 }, { 0.3, 8 }, { 1, 3 } }, transp = { { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } }, life = { 0.08, 0.08 },
				le = 1, bright = 5, rot = { 0, 90 }, zoff = 4 },
			{ tex = "shard_A", role = "debris", debris = true, count = 14, t = 0.07, over = 0.03, at = { 0, 0.3, -5.5 },
				space = "ground", dir = "disc", radius = 1.2, up = 1.3, speed = { 18, 34 }, drag = 1.2, acc = { 0, -70, 0 },
				life = { 0.5, 0.8 }, size = { { 0, 0.6 }, { 1, 0.45 } }, transp = { { 0, 0 }, { 0.8, 0 }, { 1, 1 } },
				rot = { 0, 360 }, rotSpeed = { -300, 300 }, bright = 1 },
			{ tex = "glow_soft", role = "dark", le = 0, count = 8, t = 0.08, at = { 0, 0.6, -5.5 }, space = "ground", dir = "disc",
				radius = 1.5, up = 0.35, speed = { 8, 14 }, drag = 4, life = { 0.6, 0.9 }, size = { { 0, 2 }, { 1, 5.5 } },
				transp = { { 0, 0.45 }, { 1, 1 } }, rot = { 0, 360 }, bright = 1, deco = true },
			{ tex = "spark_streak", role = { "hot", "spark" }, count = 12, t = 0.07, at = { 0, 0.3, -5.5 }, space = "ground",
				dir = "up", spread = 50, speed = { 40, 70 }, drag = 5, acc = { 0, -30, 0 }, life = { 0.2, 0.4 },
				size = { { 0, 0.7 }, { 1, 0 } }, transp = { { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }, orient = "vpar", le = 1, bright = 5 },
		},
		light = { brightness = 3.5, range = 18, life = 0.4, at = { 0, 1.5, -5.5 }, space = "ground", t = 0.06 },
		trail = true,
		sound = "cleave",
		life = 1.2,
	} :: Preset,

	-- Dash: afterimage ghosts of the character, a dark streak under an element streak and a white core
	-- along the path (tail catches up after the dash), backward speed lines, a launch ring and dust.
	DashTrail = {
		element = "lightning",
		floor = 3,
		dash = { distance = 11, duration = 0.27, pow = 2.4 }, -- SwordDashSlash: DashStart -> DashEnd, ease-out
		flash = { size = 4, life = 0.06, brightness = 4, at = { 0, 0, 0 }, space = "body" },
		light = { brightness = 2, range = 14, life = 0.35, at = { 0, 0, -5 }, space = "body" },
		ghosts = { t = 0, count = 4, interval = 0.06, life = 0.3, role = "main", oldRole = "deep", transp0 = 0.45, maxParts = 24 },
		beams = {
			{ t = 0, life = 0.55, path = true, from = { 0, -0.2, 0.6 }, to = { 0, -0.2, 0 }, tailDelay = 0.22, tailPow = 1.4,
				tailMax = 1, width0 = 0.6, width1 = 4.2, shrink = 0.5, shrinkPow = 1.5, role = { "dark", "dark" }, le = 0,
				bright = 1, tex = "trail_soft", transp = 0.25, fadePow = 2, tailFade = 0.6, headFade = 0.15, zoff = -1 },
			{ t = 0, life = 0.48, path = true, from = { 0, 0, 0.6 }, to = { 0, 0, 0 }, tailDelay = 0.2, tailPow = 1.4, tailMax = 1,
				width0 = 0.4, width1 = 3.0, shrink = 0.6, shrinkPow = 1.5, role = { "deep", "main" }, le = 1, bright = 2,
				tex = "trail_soft", transp = 0.15, fadePow = 2, tailFade = 0.5, headFade = 0.05, zoff = 0 },
			{ t = 0, life = 0.4, path = true, from = { 0, 0.1, 0.6 }, to = { 0, 0.1, 0 }, tailDelay = 0.15, tailPow = 1.4,
				tailMax = 1, width0 = 0.1, width1 = 0.9, shrink = 1, shrinkPow = 1.5, role = { "glow", "hot" }, le = 1, bright = 5,
				tex = "beam_edge_h", transp = 0, fadePow = 2, tailFade = 0.5, headFade = 0, zoff = 1 },
			{ t = 0, life = 0.5, path = true, from = { 0, -2.75, 0.6 }, to = { 0, -2.75, 0 }, tailDelay = 0.2, tailPow = 1.4,
				tailMax = 1, width0 = 0.4, width1 = 2.4, shrink = 0.5, shrinkPow = 1.5, role = { "glow", "glow" }, le = 1,
				bright = 1.2, tex = "trail_soft", transp = 0.5, fadePow = 2, tailFade = 0.5, headFade = 0.2, deco = true },
		},
		rings = {
			{ mesh = "ground_ring", tex = "strip_ground_ring", role = "glow", le = 1, gain = 1.1, t = 0, life = 0.3, r0 = 0.6,
				r1 = 4, pow = 3, transp0 = 0.2, fadePow = 1.3, at = { 0, 0.08, 0.3 }, space = "ground", plane = "flat", spin = 20 },
		},
		bursts = {
			{ tex = "spark_streak", role = { "hot", "glow" }, count = 16, t = 0, over = 0.26, at = { 0, 0.2, 0 }, space = "path",
				radius = 1.6, dir = "back", spread = 4, speed = { 25, 45 }, drag = 4, life = { 0.15, 0.3 },
				size = { { 0, 0.9 }, { 1, 0 } }, transp = { { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }, orient = "vpar", le = 1, bright = 4 },
			{ tex = "glow_soft", role = "dark", le = 0, count = 7, t = 0, at = { 0, 0.4, 0.5 }, space = "ground", dir = "back",
				spread = 55, speed = { 7, 13 }, drag = 4, life = { 0.45, 0.7 }, size = { { 0, 1.6 }, { 1, 4.2 } },
				transp = { { 0, 0.5 }, { 1, 1 } }, rot = { 0, 360 }, bright = 1, deco = true },
			{ tex = "flip_glint_4x4", role = "hot", count = 4, t = 0.02, over = 0.24, at = { 0, 0.3, 0.5 }, space = "path",
				radius = 1.6, dir = "sphere", speed = { 0.5, 1.5 }, life = { 0.16, 0.24 }, size = 2.2, grid = 4, mode = "oneshot",
				le = 1, bright = 6, zoff = 2, deco = true },
		},
		trail = true,
		sound = "dash",
		life = 0.9,
	} :: Preset,

	-- Impact on a target. cf: position = contact point, -Z = hit direction (attacker -> target).
	HitSpark = {
		element = "holy",
		flash = { size = 8, life = 0.08, brightness = 6, at = { 0, 0, 0 }, space = "body" },
		light = { brightness = 3, range = 12, life = 0.18, at = { 0, 0, 0.5 }, space = "body" },
		bursts = {
			{ tex = "glow_soft", role = "dark", le = 0, count = 1, t = 0, at = { 0, 0, 0.3 }, space = "body",
				size = { { 0, 3 }, { 0.25, 9 }, { 1, 10 } }, transp = { { 0, 0.1 }, { 0.6, 0.35 }, { 1, 1 } },
				life = { 0.14, 0.14 }, bright = 1, zoff = -2 },
			{ tex = "ground_ring_card", role = "glow", count = 1, t = 0, at = { 0, 0, 0 }, space = "body",
				size = { { 0, 1.5 }, { 0.4, 6 }, { 1, 7.5 } }, transp = { { 0, 0 }, { 0.5, 0.35 }, { 1, 1 } }, life = { 0.22, 0.22 },
				le = 1, bright = 2.5, zoff = 1 },
			{ tex = "ground_ring_card", role = "hot", count = 1, t = 0.02, at = { 0, 0, 0 }, space = "body",
				size = { { 0, 2 }, { 0.5, 8 }, { 1, 9.5 } }, transp = { { 0, 0.2 }, { 1, 1 } }, life = { 0.14, 0.14 }, le = 1, bright = 3,
				zoff = 1, deco = true },
			{ tex = "flip_crescent_4x4", role = { "hot", "main" }, count = 1, t = 0, at = { 0, 0, 0 }, space = "body", size = 5.5,
				life = { 0.26, 0.26 }, grid = 4, mode = "oneshot", rot = { -35, -35 }, le = 1, bright = 2,
				transp = { { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }, zoff = 2 },
			{ tex = "spark_streak", role = { "hot", "spark" }, count = 18, t = 0, at = { 0, 0, 0 }, space = "body", dir = "cone",
				spread = 80, speed = { 45, 85 }, drag = 7, acc = { 0, -20, 0 }, life = { 0.16, 0.32 }, size = { { 0, 0.65 }, { 1, 0 } },
				transp = { { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }, orient = "vpar", le = 1, bright = 5, zoff = 1 },
			{ tex = "shard_A", role = "debris", debris = true, count = 7, t = 0, at = { 0, 0, 0 }, space = "body", dir = "cone",
				spread = 65, speed = { 22, 38 }, drag = 2, acc = { 0, -45, 0 }, life = { 0.35, 0.6 },
				size = { { 0, 0.45 }, { 1, 0.3 } }, transp = { { 0, 0 }, { 0.8, 0 }, { 1, 1 } }, rot = { 0, 360 },
				rotSpeed = { -400, 400 }, bright = 1 },
			{ tex = "flip_glint_4x4", role = "hot", count = 3, t = 0.03, at = { 0, 0, 0 }, space = "body", dir = "sphere",
				radius = 1.6, speed = { 0.5, 1 }, life = { 0.18, 0.24 }, size = 2.2, grid = 4, mode = "oneshot", le = 1,
				bright = 6, zoff = 2, deco = true },
		},
		trail = true,
		sound = "spark",
		life = 0.75,
	} :: Preset,

	-- Anticipation before a heavy: motes and dark specks converge on a core glow, two ground rings
	-- implode, aura streaks rise around the feet, then a ready glint at release (lead).
	ChargeUp = {
		element = "teal",
		floor = 3,
		lead = 0.75,
		light = { brightness = 2.5, range = 14, life = 0.85, rise = 0.85, at = { 0.6, 0.9, -1.3 }, space = "body" },
		rings = {
			{ mesh = "ground_ring", tex = "strip_ground_ring", role = "glow", le = 1, gain = 1.1, t = 0.02, life = 0.36,
				r0 = 7, r1 = 1.2, ease = "in", pow = 2.2, transp0 = 0.15, fadeIn = 0.3, hold = 0.8, fadePow = 1.5,
				at = { 0, 0.08, 0 }, space = "ground", plane = "flat", spin = -60 },
			{ mesh = "ground_ring", tex = "strip_ground_ring", role = "glow", le = 1, gain = 1.2, t = 0.36, life = 0.32,
				r0 = 6, r1 = 1, ease = "in", pow = 2.2, transp0 = 0.05, fadeIn = 0.3, hold = 0.8, fadePow = 1.5,
				at = { 0, 0.1, 0 }, space = "ground", plane = "flat", spin = 60 },
		},
		bursts = {
			{ tex = "ground_disc_faint", role = "dark", le = 0, count = 1, t = 0, at = { 0, 0.04, 0 }, space = "ground",
				orient = "flat", size = { { 0, 6 }, { 0.3, 11 }, { 1, 12 } },
				transp = { { 0, 1 }, { 0.2, 0.3 }, { 0.8, 0.35 }, { 1, 1 } }, life = { 1.0, 1.0 }, bright = 1 },
			{ tex = "spark_streak", role = { "spark", "hot" }, count = 26, t = 0, over = 0.58, at = { 0.6, 0.9, -1.3 },
				space = "body", dir = "converge", radius = 6.5, up = 0.3, speed = { 19, 23 }, life = { 0.28, 0.32 },
				size = { { 0, 0.25 }, { 0.7, 0.6 }, { 1, 0.1 } }, transp = { { 0, 1 }, { 0.25, 0.1 }, { 0.85, 0 }, { 1, 1 } },
				orient = "vpar", le = 1, bright = 4 },
			{ tex = "flip_petals_8x8", role = "debris", debris = true, count = 12, t = 0.04, over = 0.5, at = { 0.6, 0.9, -1.3 },
				space = "body", dir = "converge", radius = 7, up = 0.2, speed = { 17, 21 }, life = { 0.34, 0.38 },
				size = { { 0, 0.25 }, { 0.5, 0.55 }, { 1, 0.15 } }, transp = { { 0, 1 }, { 0.2, 0 }, { 0.85, 0 }, { 1, 1 } },
				rot = { 0, 360 }, rotSpeed = { -300, 300 }, grid = 8, mode = "random", bright = 1, deco = true },
			{ tex = "spark_streak", role = { "main", "glow" }, count = 18, t = 0.08, over = 0.6, at = { 0, 0.2, 0 },
				space = "ground", dir = "up", radius = 2.4, spread = 8, speed = { 9, 15 }, drag = 1, acc = { 0, 4, 0 },
				life = { 0.35, 0.5 }, size = { { 0, 0.5 }, { 0.4, 1.2 }, { 1, 0 } }, transp = { { 0, 0.3 }, { 1, 1 } },
				orient = "vpar", le = 1, bright = 2.5 },
			{ tex = "glow_soft", role = "glow", count = 1, t = 0.05, at = { 0.6, 0.9, -1.3 }, space = "body",
				size = { { 0, 0.6 }, { 0.85, 3.6 }, { 1, 0.5 } }, transp = { { 0, 0.6 }, { 0.8, 0.15 }, { 1, 1 } },
				life = { 0.72, 0.72 }, le = 1, bright = 2, zoff = 1 },
			{ tex = "flash_hot", role = "hot", count = 1, t = 0.66, at = { 0.6, 0.9, -1.3 }, space = "body",
				size = { { 0, 0 }, { 0.35, 6 }, { 1, 0 } }, transp = { { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } }, life = { 0.14, 0.14 },
				le = 1, bright = 5, rot = { 0, 90 }, zoff = 4 },
			{ tex = "spark_streak", role = { "hot", "spark" }, count = 10, t = 0.66, at = { 0.6, 0.9, -1.3 }, space = "body",
				dir = "sphere", speed = { 25, 40 }, drag = 6, life = { 0.15, 0.25 }, size = { { 0, 0.5 }, { 1, 0 } },
				transp = { { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }, orient = "vpar", le = 1, bright = 5 },
		},
		trail = true,
		sound = "charge",
		life = 1.05,
	} :: Preset,

	-- Radial ice burst at a point on the floor (cf = impact point at body height; floor 3 studs down).
	-- Not a slash, so radial is fine. Timeline at 30 fps: flash 0-3 f, frost ring 0-9 f,
	-- spikes erupt 1-6 f (staggered), hold to ~16 f, shatter into shards, mist lingers to ~40 f.
	IceExplosion = {
		element = "ice",
		floor = 3,
		flash = { size = 5, life = 0.06, brightness = 4, at = { 0, 1.2, 0 }, space = "ground" }, -- small and fast: keep the caster readable
		light = { brightness = 4, range = 20, life = 0.55, at = { 0, 2, 0 }, space = "ground" },
		spikes = {
			mesh = "crystal", tex = "crystal_facets", gain = 1.35, neon = false,
			count = 6, centre = true, t = 0.03, stagger = 0.033, grow = 0.15, hold = 0.34, shatter = 0.1,
			length = { 3.4, 5.6 }, width = { 0.95, 1.45 }, radius = { 0.5, 1.4 }, lean = { 20, 48 },
			small = { count = 4, length = { 1.1, 2.0 }, width = { 0.5, 0.8 }, radius = { 1.3, 2.3 }, lean = { 40, 70 } },
			mound = { mesh = "ice_mound", width = 4.6, height = 3.2, role = "glow", fade = 0.3 },
			role = "glow", altRole = "main",
			at = { 0, 0, 0 }, space = "ground",
			shards = { tex = "shard_A", role = { "hot", "glow" }, per = 3, speed = { 14, 26 }, life = { 0.45, 0.75 },
				size = { { 0, 0.55 }, { 1, 0.3 } }, acc = { 0, -40, 0 }, drag = 1.5, le = 0.6, bright = 1.6 },
		},
		rings = {
			{ mesh = "ground_ring", tex = "strip_ground_ring", role = "dark", le = 0, t = 0.02, life = 0.45, r0 = 0.8, r1 = 7.5,
				pow = 3, transp0 = 0.55, fadePow = 1.3, at = { 0, 0.05, 0 }, space = "ground", plane = "flat", spin = 0 },
		},
		bursts = {
			-- slight blue tint flash around the white core
			{ tex = "glow_soft", role = "main", count = 1, t = 0, at = { 0, 1.4, 0 }, space = "ground",
				size = { { 0, 3 }, { 0.35, 8 }, { 1, 9 } }, transp = { { 0, 0.45 }, { 0.4, 0.7 }, { 1, 1 } },
				life = { 0.1, 0.1 }, le = 1, bright = 1.5, zoff = 3 },
			-- frosted shockwave: broken bright rim, fern frost fringe, crackled see-through inside (eases out)
			{ tex = "frost_ring", role = { "hot", "glow" }, le = 1, bright = 1.6, count = 1, t = 0, at = { 0, 0.14, 0 },
				space = "ground", orient = "flat", size = { { 0, 2 }, { 0.12, 11 }, { 0.3, 16 }, { 0.6, 18.5 }, { 1, 19.5 } },
				transp = { { 0, 0 }, { 0.45, 0.2 }, { 1, 1 } }, life = { 0.5, 0.5 }, rot = { 0, 360 }, zoff = 0.6 },
			-- frost-crack decal: dark crack + bright frost on top, spreading fast then holding
			{ tex = "ground_frost", role = "dark", le = 0, count = 1, t = 0.02, at = { 0, 0.06, 0 }, space = "ground",
				orient = "flat", size = { { 0, 3 }, { 0.2, 12 }, { 1, 13 } }, transp = { { 0, 0.1 }, { 0.75, 0.2 }, { 1, 1 } },
				life = { 1.25, 1.25 }, rot = { 15, 15 }, bright = 1 },
			{ tex = "ground_frost", role = { "hot", "glow" }, le = 1, bright = 2.2, count = 1, t = 0.02, at = { 0, 0.12, 0 },
				space = "ground", orient = "flat", size = { { 0, 3 }, { 0.25, 12 }, { 1, 13 } },
				transp = { { 0, 0 }, { 0.4, 0.25 }, { 1, 1 } }, life = { 0.85, 0.85 }, rot = { 15, 15 }, zoff = 0.5 },
			-- cold mist: pale, nearly normal blend, low and slow, lingering
			{ tex = "glow_soft", role = "spark", le = 0.15, count = 9, t = 0.1, over = 0.12, at = { 0, 1.6, 0 },
				space = "ground", dir = "disc", radius = 2.2, up = 0.04, speed = { 3, 6.5 }, drag = 1.6, acc = { 0, -0.4, 0 },
				life = { 0.9, 1.25 }, size = { { 0, 2.5 }, { 1, 6 } }, transp = { { 0, 1 }, { 0.15, 0.62 }, { 0.6, 0.72 }, { 1, 1 } },
				rot = { 0, 360 }, rotSpeed = { -20, 20 }, bright = 1, deco = true },
			-- glitter: twinkles around the spikes, square sparkles drifting down
			{ tex = "flip_glint_4x4", role = "hot", count = 8, t = 0.08, over = 0.5, at = { 0, 2.2, 0 }, space = "ground",
				dir = "sphere", radius = 4.5, speed = { 0.3, 1 }, life = { 0.2, 0.28 }, size = 2.2, grid = 4, mode = "oneshot",
				le = 1, bright = 6, zoff = 2, deco = true },
			{ tex = "spark_square", role = "spark", count = 14, t = 0.05, over = 0.1, at = { 0, 0.8, 0 }, space = "ground",
				dir = "disc", radius = 2.5, up = 1.6, speed = { 5, 11 }, drag = 2.5, acc = { 0, -3, 0 }, life = { 0.7, 1.15 },
				size = { { 0, 0 }, { 0.15, 0.32 }, { 0.35, 0.12 }, { 0.55, 0.28 }, { 1, 0 } }, rot = { 0, 45 }, le = 1, bright = 4 },
		},
		trail = true,
		sound = "ice",
		life = 1.35,
	} :: Preset,
	-- !! UNTESTED IN STUDIO !! Radial lightning burst at a point on the floor (cf = impact point at body
	-- height; floor 3 studs down). Authored against Previews/LightningBall_Cast_to_Explosion.mp4 only.
	-- Timeline at 30 fps: small flash 0-2 f, branching bolts strike outward along the ground 0-3 f and
	-- re-strike (flicker) to ~11 f, an upward column for 2-3 f, scorched ring + glowing cracks hold to
	-- ~40 f, spark burst, lingering static arcs to ~35 f, faint smoke. Palette: plasma (white core,
	-- electric cyan, violet edges, dark ink). Bolts = the `bolts` layer (see buildBolts).
	LightningExplosion = {
		element = "plasma",
		floor = 3,
		flash = { size = 3, life = 0.05, brightness = 4, at = { 0, 1.0, 0 }, space = "ground" }, -- small: keep the landing readable
		light = { brightness = 5, range = 22, life = 0.6, at = { 0, 2.5, 0 }, space = "ground" },
		bolts = {
			-- radial branching strikes along the ground (white core, cyan halo, violet edge); re-strike every ~2 f
			{ kind = "radial", t = 0, count = 9, length = { 5.5, 9.5 }, segs = 8, jitter = 0.9, branches = 2, branchLen = 0.45,
				width = 0.3, glow = 4, grow = 0.07, stagger = 0.01, hold = 0.2, fade = 0.12, flicker = 0.05,
				at = { 0, 0.15, 0 }, space = "ground", core = "hot", halo = "main", edge = "glow" },
			-- upward column, 2-3 frames
			{ kind = "column", t = 0.005, count = 3, height = 13, spread = 0.45, segs = 10, jitter = 0.55, branches = 3,
				branchLen = 0.3, width = 0.5, glow = 4, grow = 0.02, hold = 0.05, fade = 0.03, flicker = 0.034,
				at = { 0, 0, 0 }, space = "ground", core = "hot", halo = "main", edge = "glow" },
			-- lingering static: short arcs crawling over the scorch
			{ kind = "arcs", t = 0.22, count = 12, over = 0.75, radius = { 0.8, 5 }, length = { 1.2, 2.8 }, up = 1.0, segs = 5,
				jitter = 1.1, width = 0.13, glow = 4, life = 0.08, flicker = 0.034, at = { 0, 0.1, 0 }, space = "ground",
				core = "hot", halo = "main", edge = "glow", deco = true },
		},
		rings = {
			{ mesh = "ground_ring", tex = "strip_ground_ring", role = "main", le = 1, gain = 1.2, t = 0, life = 0.3, r0 = 0.8, r1 = 9,
				pow = 3, transp0 = 0.25, fadePow = 1.2, at = { 0, 0.08, 0 }, space = "ground", plane = "flat", spin = 30 },
		},
		bursts = {
			-- violet-cyan shock glow around the small white flash
			{ tex = "glow_soft", role = "glow", count = 1, t = 0, at = { 0, 1.2, 0 }, space = "ground",
				size = { { 0, 2.5 }, { 0.35, 7 }, { 1, 8 } }, transp = { { 0, 0.4 }, { 0.4, 0.65 }, { 1, 1 } },
				life = { 0.12, 0.12 }, le = 1, bright = 1.6, zoff = 3 },
			-- scorched dark disc + ring (dark ink), holding
			{ tex = "ground_disc_faint", role = "dark", le = 0, count = 1, t = 0.01, at = { 0, 0.04, 0 }, space = "ground",
				orient = "flat", size = { { 0, 4 }, { 0.12, 11 }, { 1, 12 } }, transp = { { 0, 0.05 }, { 0.8, 0.15 }, { 1, 1 } },
				life = { 1.4, 1.4 }, bright = 1 },
			{ tex = "ground_ring_card", role = "dark", le = 0, count = 1, t = 0.01, at = { 0, 0.05, 0 }, space = "ground",
				orient = "flat", size = { { 0, 3 }, { 0.1, 9.5 }, { 1, 10.5 } }, transp = { { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } },
				life = { 1.4, 1.4 }, bright = 1 },
			-- cracks: dark crack decal + glowing cyan/violet cracks on top that cool down
			{ tex = "ground_crack", role = "dark", le = 0, count = 1, t = 0.01, at = { 0, 0.07, 0 }, space = "ground",
				orient = "flat", size = { { 0, 4 }, { 0.12, 11 }, { 1, 11.5 } }, transp = { { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } },
				life = { 1.4, 1.4 }, rot = { 25, 25 }, bright = 1 },
			{ tex = "ground_crack", role = { "hot", "glow" }, le = 1, bright = 2.6, count = 1, t = 0.01, at = { 0, 0.11, 0 },
				space = "ground", orient = "flat", size = { { 0, 4 }, { 0.15, 11 }, { 1, 11.5 } },
				transp = { { 0, 0 }, { 0.35, 0.3 }, { 1, 1 } }, life = { 1.0, 1.0 }, rot = { 25, 25 }, zoff = 0.5 },
			-- crackling spark burst
			{ tex = "spark_streak", role = { "hot", "main" }, count = 28, t = 0.01, at = { 0, 0.6, 0 }, space = "ground",
				dir = "up", radius = 1.2, spread = 70, speed = { 28, 55 }, drag = 5, acc = { 0, -35, 0 }, life = { 0.2, 0.42 },
				size = { { 0, 0.7 }, { 1, 0 } }, transp = { { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }, orient = "vpar", le = 1, bright = 5 },
			{ tex = "spark_square", role = "spark", count = 18, t = 0.05, over = 0.5, at = { 0, 0.6, 0 }, space = "ground",
				dir = "disc", radius = 4, up = 1.2, speed = { 3, 8 }, drag = 2.5, acc = { 0, -4, 0 }, life = { 0.3, 0.6 },
				size = { { 0, 0 }, { 0.1, 0.3 }, { 0.3, 0.08 }, { 0.5, 0.26 }, { 0.7, 0.05 }, { 1, 0 } }, rot = { 0, 45 },
				le = 1, bright = 4, deco = true },
			{ tex = "flip_glint_4x4", role = "hot", count = 6, t = 0.03, over = 0.5, at = { 0, 1.2, 0 }, space = "ground",
				dir = "sphere", radius = 4.5, speed = { 0.3, 1 }, life = { 0.16, 0.24 }, size = 2, grid = 4, mode = "oneshot",
				le = 1, bright = 6, zoff = 2, deco = true },
			-- faint smoke rising off the scorch
			{ tex = "glow_soft", role = "dark", le = 0, count = 7, t = 0.12, over = 0.2, at = { 0, 0.8, 0 }, space = "ground",
				dir = "disc", radius = 2.5, up = 1.5, speed = { 1.5, 3.5 }, drag = 1.2, acc = { 0, 1.2, 0 }, life = { 0.9, 1.3 },
				size = { { 0, 2 }, { 1, 5.5 } }, transp = { { 0, 1 }, { 0.2, 0.72 }, { 0.6, 0.8 }, { 1, 1 } },
				rot = { 0, 360 }, rotSpeed = { -25, 25 }, bright = 1, deco = true },
		},
		trail = true,
		sound = "thunder",
		life = 1.5,
	} :: Preset,

	-- !! UNTESTED IN STUDIO !! SpinAttack v2, one per turn (Hit "spin1".."spin3"; DefaultHits scale 0.85 / 1.15 / 1.5,
	-- so the stack escalates instead of stamping the same ring 3x). Radial on purpose (spin move). cf = root part
	-- (floor 3 studs down). Budget per turn: 1 mesh ring + ~13 particles.
	SpinShock = {
		element = "teal",
		floor = 3,
		light = { brightness = 0.6, range = 12, life = 0.25, at = { 0, 7, 0 }, space = "ground" }, -- v2.1: above the head, not at shin height
		rings = {
			-- one ring that fades IN while it expands, then fades out (no stamped frame)
			{ mesh = "ground_ring", tex = "strip_ground_ring", role = "glow", le = 1, gain = 1.0, t = 0, life = 0.55, r0 = 2.0,
				r1 = 6.5, pow = 2, transp0 = 0.35, fadeIn = 0.25, fadePow = 1.2, at = { 0, 0.08, 0 }, space = "ground",
				plane = "flat", spin = 60 },
		},
		bursts = {
			-- billowy dust kicked outward along the floor (textured puff, light top / dark core, turning)
			{ tex = "smoke_puff", role = { "spark", "deep" }, le = 0, count = 7, t = 0, over = 0.06, at = { 0, 0.5, 0 },
				space = "ground", dir = "disc", radius = 1.8, up = 0.15, speed = { 9, 15 }, drag = 3, life = { 0.5, 0.85 },
				size = { { 0, 1.4 }, { 1, 3.8 } }, transp = { { 0, 1 }, { 0.12, 0.35 }, { 0.7, 0.55 }, { 1, 1 } },
				rot = { 0, 360 }, rotSpeed = { -60, 60 }, bright = 1, deco = true },
			-- radial grit / ink chips (short throw: nothing drifts off-frame)
			{ tex = "flip_petals_8x8", role = "debris", debris = true, count = 6, t = 0, over = 0.05, at = { 0, 0.4, 0 },
				space = "ground", dir = "disc", radius = 1.4, up = 0.6, speed = { 10, 16 }, drag = 2, acc = { 0, -36, 0 },
				life = { 0.35, 0.55 }, size = { { 0, 0.3 }, { 0.2, 0.55 }, { 1, 0.3 } }, rot = { 0, 360 },
				rotSpeed = { -400, 400 }, grid = 8, mode = "random", bright = 1 },
		},
		trail = false,
		sound = "ring",
		life = 0.9,
	} :: Preset,

	-- !! UNTESTED IN STUDIO !! SpinAttack v2 finisher (Hit "spinfinish"). Frontal only: huge crescent + a thinner
	-- shock crescent that travels outward, a brief pressure ring, 4 light shafts, ground cracks thrown forward,
	-- forward debris, dust blast (the vortex collapsing outward), afterglow hang, drifting embers. Glints sit on the
	-- blade-tip contact point and the crescent head, never on the body. cf = root part (floor 3 studs down).
	-- Budget: ~11 mesh parts, 8 beams (4 crescent edge + 4 god-rays), ~58 particles, 1 light.
	SpinFinish = {
		element = "teal",
		floor = 3,
		trail = false,
		units = {
			{
				shape = "crescent", mesh = "crescent_single_thick_hd", card = "flip_crescent_4x4", inkCard = "flip_crescent_ink_4x4",
				cardROut = 0.9, radius = 11.5, span = 200, delay = 0, lift = -0.6, tilt = 3, yaw = 0,
				sweep = 0.1, hold = 0.06, erode = 0.38, sweepEase = 2.4, drift = 10, inkLag = 20, inkDrop = -0.1,
				inkScale = 1.05, bodyGain = 1.35, cardBrightness = 1.0, cardTransparency = 0.85,
				edge = { width = 1.9, band = 100, life = 0.4, brightness = 9 },
				sparks = 14, glints = 0, debris = 0, squares = 0, debrisSize = 1.5, glintSize = 3,
				ink = "strip_ink_wide", body = "strip_body_soft", smoothErode = true, cards = false, rim = 3.0,
				expand = 0.12, fwd = 0.7,
			},
			{ -- shock wave: thinner, wider crescent that leaves a beat later and keeps travelling outward
				shape = "crescent", mesh = "crescent_single_thin", card = "flip_crescent_4x4",
				cardROut = 0.9, radius = 15, span = 150, delay = 0.06, lift = -1.0, tilt = -2, yaw = 0,
				sweep = 0.12, hold = 0.02, erode = 0.3, sweepEase = 2.0, drift = 6, inkLag = 14, inkDrop = -0.1,
				inkScale = 0.98, bodyGain = 0.8, cardBrightness = 1.0, cardTransparency = 0.85,
				edge = { width = 0.8, band = 60, life = 0.3, brightness = 4 },
				sparks = 0, glints = 0, debris = 0, squares = 0, debrisSize = 1, glintSize = 2,
				body = "strip_body_soft", smoothErode = true, cards = false, fwd = 0.7, expand = 0.35,
			},
		},
		-- v2.1: tiny, 1 frame late, 1-2 frames long, at the crescent head ahead of the body (never over the character)
		flash = { size = 1.8, life = 0.04, brightness = 3, at = { -4.5, -0.4, -10 }, space = "body", t = 0.033 },
		ground = { drop = 3, radius = 8, life = 0.6, transparency = 0.3, ring = false, discRole = "dark", discLe = 0, discBright = 1, forward = 5 },
		light = { brightness = 2, range = 14, life = 0.45, at = { 0, 0.5, -7 }, space = "body" }, -- v2.1: ahead of the body
		rings = {
			-- pressure wave: pale ring facing forward, fast and faint (reads as air distortion)
			{ mesh = "ring_full_thin", tex = "strip_ground_ring", role = "hot", le = 0.3, gain = 0.7, t = 0.03, life = 0.2, r0 = 1,
				r1 = 5.5, pow = 2.5, transp0 = 0.72, fadePow = 1.0, at = { 0, 0.3, -9 }, space = "body", plane = "forward", spin = 0 },
		},
		beams = {
			-- v2.1 god-rays: soft tapered shafts (god_ray texture: bright at the source, streaky, fading along the
			-- length and to both edges), additive, fanning radially out of the crescent ahead of the body
			{ from = { 0, 0.2, -8 }, to = { -9, 4, -15 }, width0 = 0.8, width1 = 4.0, tex = "god_ray", role = "glow", le = 1,
				bright = 2.6, transp = 0.05, tailFade = 0, headFade = 0, t = 0.04, life = 0.62, grow = 0.07, tailDelay = 0.4, shrink = 0.3 },
			{ from = { 0, 0.2, -8 }, to = { -3.5, 7, -17 }, width0 = 0.8, width1 = 4.4, tex = "god_ray", role = "hot", le = 1,
				bright = 2.2, transp = 0.1, tailFade = 0, headFade = 0, t = 0.05, life = 0.62, grow = 0.07, tailDelay = 0.4, shrink = 0.3 },
			{ from = { 0, 0.2, -8 }, to = { 2.5, 7.5, -17 }, width0 = 0.8, width1 = 4.4, tex = "god_ray", role = "glow", le = 1,
				bright = 2.4, transp = 0.1, tailFade = 0, headFade = 0, t = 0.06, life = 0.6, grow = 0.07, tailDelay = 0.38, shrink = 0.3 },
			{ from = { 0, 0.2, -8 }, to = { 8, 4.5, -15 }, width0 = 0.7, width1 = 3.8, tex = "god_ray", role = "glow", le = 1,
				bright = 2.2, transp = 0.15, tailFade = 0, headFade = 0, t = 0.07, life = 0.58, grow = 0.07, tailDelay = 0.36, shrink = 0.3 },
		},
		bursts = {
			-- ground cracks radiating forward (dark crack + thin glowing copy on top)
			{ tex = "ground_crack", role = "dark", le = 0, count = 1, t = 0.02, at = { 0, 0.05, -4.5 }, space = "ground",
				orient = "flat", size = { { 0, 3 }, { 0.15, 10 }, { 1, 11 } }, transp = { { 0, 0.05 }, { 0.8, 0.2 }, { 1, 1 } },
				life = { 1.3, 1.3 }, bright = 1 },
			{ tex = "ground_crack", role = { "hot", "glow" }, le = 1, bright = 1.3, count = 1, t = 0.02, at = { 0, 0.1, -4.5 },
				space = "ground", orient = "flat", size = { { 0, 3 }, { 0.15, 10 }, { 1, 11 } },
				transp = { { 0, 0 }, { 0.4, 0.3 }, { 1, 1 } }, life = { 0.7, 0.7 }, zoff = 0.5 },
			-- debris and pebbles thrown forward
			{ tex = "flip_petals_8x8", role = "debris", debris = true, count = 16, t = 0.02, over = 0.06, at = { 0, -1.5, -3 },
				space = "body", dir = "cone", spread = 35, speed = { 18, 30 }, drag = 1.5, acc = { 0, -34, 0 },
				life = { 0.5, 0.85 }, size = { { 0, 0.3 }, { 0.2, 0.6 }, { 1, 0.35 } }, rot = { 0, 360 },
				rotSpeed = { -400, 400 }, grid = 8, mode = "random", bright = 1 },
			{ tex = "spark_square", role = "debris", debris = true, count = 10, t = 0.02, over = 0.05, at = { 0, -2.2, -3 },
				space = "body", dir = "cone", spread = 30, speed = { 14, 24 }, drag = 1, acc = { 0, -40, 0 },
				life = { 0.45, 0.7 }, size = { { 0, 0.25 }, { 1, 0.2 } }, rot = { 0, 45 }, le = 0, bright = 1 },
			-- dust blast: the vortex collapses outward
			{ tex = "smoke_puff", role = { "spark", "deep" }, le = 0, count = 12, t = 0.06, over = 0.06, at = { 0, 0.8, 0 },
				space = "ground", dir = "disc", radius = 2.5, up = 0.1, speed = { 14, 22 }, drag = 2.6, life = { 0.7, 1.1 },
				size = { { 0, 2 }, { 1, 6 } }, transp = { { 0, 1 }, { 0.1, 0.3 }, { 0.7, 0.6 }, { 1, 1 } }, rot = { 0, 360 },
				rotSpeed = { -50, 50 }, bright = 1, deco = true },
			-- afterglow hang in front
			{ tex = "glow_soft", role = "glow", count = 1, t = 0.05, at = { 0, 0.5, -6 }, space = "body",
				size = { { 0, 3 }, { 0.2, 7 }, { 1, 8 } }, transp = { { 0, 0.55 }, { 0.3, 0.7 }, { 1, 1 } }, life = { 0.9, 0.9 },
				le = 1, bright = 1.1 },
			-- embers drifting up
			{ tex = "spark_square", role = { "hot", "spark" }, count = 14, t = 0.12, over = 0.6, at = { 0, 0.5, -5 }, space = "body",
				dir = "up", radius = 4, spread = 25, speed = { 1.5, 3.5 }, drag = 0.6, acc = { 0, 1.2, 0 }, life = { 1.2, 1.8 },
				size = { { 0, 0 }, { 0.15, 0.22 }, { 0.5, 0.12 }, { 0.8, 0.2 }, { 1, 0 } }, rot = { 0, 45 }, le = 1, bright = 3,
				deco = true },
			-- glint: only on the crescent head, far from the body (v2.1)
			{ tex = "flip_glint_4x4", role = "hot", count = 1, t = 0.1, at = { -10.6, -0.6, -2.5 }, space = "body", size = 3,
				life = { 0.24, 0.24 }, grid = 4, mode = "oneshot", le = 1, bright = 6, zoff = 2 },
		},
		sound = "slash",
		life = 1.9,
	} :: Preset,
}
-- old name kept so existing calls keep working (it is the frontal sweep now)
(LihFolkVFX.Presets :: any).SlashRing = LihFolkVFX.Presets.SlashSweep

-- Marker value -> what to play (values come from our clips: SwordLight1..3 "1".."3", SwordHeavy "heavy", SwordDashSlash "dash")
export type HitSpec = {
	preset: string,
	flip: boolean?,
	tilt: number?,
	yaw: number?,
	scale: number?,
	element: string?,
	offset: CFrame?,
	skipUnits: boolean?, -- play only the non-arc layers (e.g. OverheadCleave's ground crack for a slam)
	follow: boolean?, -- DashTrail: the streak head follows the root part (else the predicted path)
	byValue: { [string]: HitSpec }?, -- marker value -> a different spec (e.g. Impact "ice" -> IceExplosion)
}
LihFolkVFX.DefaultHits = {
	["1"] = { preset = "CrescentDouble", tilt = 12 },
	["2"] = { preset = "CrescentDouble", flip = true, tilt = -10 },
	["3"] = { preset = "OverheadCleave" }, -- SwordLight3 is the stepping overhead
	heavy = { preset = "SlashSweep" },
	dash = { preset = "CrescentDouble", scale = 1.3, offset = CFrame.new(0, 0, -3) },
	thrust = { preset = "ThrustPierce" }, -- for a stab clip with Hit value "thrust"
	-- SpinAttack clip (UNTESTED IN STUDIO): ground shock per turn, growing; frontal finisher.
	-- LihFolkVFX.playSpinAttack() adds the whirl trails, wind swirl and tangential sparks on top.
	spin1 = { preset = "SpinShock", scale = 0.85 },
	spin2 = { preset = "SpinShock", scale = 1.15 },
	spin3 = { preset = "SpinShock", scale = 1.5 },
	spinfinish = { preset = "SpinFinish", offset = CFrame.new(0, 0, -3) }, -- v2.1: spawned ahead of the body
} :: { [string]: HitSpec }

-- Other markers by name (the marker value, if a number, is the dash distance in studs)
LihFolkVFX.DefaultMarkers = {
	DashStart = { preset = "DashTrail", follow = true }, -- SwordDashSlash (value "11.0")
	Impact = { -- GroundSlam; marker value "ice" (or any preset name) picks another effect
		preset = "OverheadCleave", skipUnits = true, offset = CFrame.new(0, 0, 3.5),
		byValue = { ice = { preset = "IceExplosion", offset = CFrame.new(0, 0, -3) } },
	},
	Deflect = { preset = "HitSpark", offset = CFrame.new(0.5, 1, -2.5), scale = 0.7 }, -- SwordParry
} :: { [string]: HitSpec }

-- Clips that open with a charge (keyed by Animation.Name, or set the Animation attribute "VFXCharge" = preset):
-- the charge starts when the track starts and is retimed so its release lands on the Hit marker (lead, seconds).
LihFolkVFX.DefaultCharges = {
	SwordHeavy = { preset = "ChargeUp", lead = 0.767 },
} :: { [string]: { preset: string, lead: number } }

-- Clips whose weapon Trail must stay off (spins). Also any Animation with the attribute "VFXNoTrail".
LihFolkVFX.NoTrailClips = { SwordHeavy = true, SpinAttack = true } :: { [string]: boolean }

-------------------------------------------------------------------------------
-- Small helpers
-------------------------------------------------------------------------------
local warned: { [string]: boolean } = {}
local function warnOnce(key: string, msg: string)
	if not warned[key] then
		warned[key] = true
		warn("[LihFolkVFX] " .. msg)
	end
end

local function tex(key: string): string?
	local id = (LihFolkVFX.Textures :: any)[key]
	if type(id) == "string" and id ~= "" then
		return id
	end
	warnOnce("tex:" .. key, "texture '" .. key .. "' has no id yet; that layer is skipped")
	return nil
end

local function meshId(key: string): string?
	local id = (LihFolkVFX.Meshes :: any)[key]
	if type(id) == "string" and id ~= "" then
		return id
	end
	warnOnce("mesh:" .. key, "mesh '" .. key .. "' has no id yet; mesh layers using it are skipped")
	return nil
end

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function easeOut(x: number, p: number): number
	return 1 - (1 - clamp01(x)) ^ p
end

local function easeIn(x: number, p: number): number
	return clamp01(x) ^ p
end

local function ns(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(kps)
end

-- point on the arc circle in pivot space; phi in degrees, 0 = +X, 90 = forward (-Z)
local function arcPoint(phi: number, r: number, y: number): Vector3
	local a = math.rad(phi)
	return Vector3.new(math.cos(a) * r, y, -math.sin(a) * r)
end

local function arcTangent(phi: number): Vector3
	local a = math.rad(phi)
	return Vector3.new(-math.sin(a), 0, -math.cos(a))
end

local function newPart(name: string, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function newEmitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	e.LightInfluence = 0
	e.LockedToPart = false
	e.VelocityInheritance = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function meshLayer(name: string, mesh: string, texture: string, cf: CFrame, parent: Instance, neon: boolean): (Part, SpecialMesh)
	local p = newPart(name, cf, parent)
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Transparency = 1
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.FileMesh
	m.MeshId = mesh
	m.TextureId = texture
	m.Scale = Vector3.one
	m.Parent = p
	return p, m
end

local function v3(c: Color3, gain: number): Vector3
	return Vector3.new(c.R * gain, c.G * gain, c.B * gain)
end

-- palette role -> colour ("deep" = main halfway to dark, "white")
local function role(pal: Palette, name: string?): Color3
	local key = name or "main"
	local c = (pal :: any)[key]
	if typeof(c) == "Color3" then
		return c
	elseif key == "deep" then
		return pal.main:Lerp(pal.dark, 0.5)
	elseif key == "white" then
		return Color3.new(1, 1, 1)
	end
	return pal.main
end

-- role or { roleAtStart, roleAtEnd }
local function roleSeq(pal: Palette, r: any): ColorSequence
	if type(r) == "table" then
		return ColorSequence.new(role(pal, r[1]), role(pal, r[2] or r[1]))
	end
	return ColorSequence.new(role(pal, r))
end

local function vec(t: any, s: number): Vector3
	if type(t) ~= "table" then
		return Vector3.zero
	end
	return Vector3.new((t[1] or 0) * s, (t[2] or 0) * s, (t[3] or 0) * s)
end

-- number or {{t, v}, ...} -> NumberSequence, values scaled by s
local function seqOf(v: any, s: number): NumberSequence
	if type(v) == "number" then
		return NumberSequence.new(v * s)
	end
	local kps = {}
	for _, p in v do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2] * s))
	end
	return NumberSequence.new(kps)
end

local function range(v: any, default: number, s: number?): NumberRange
	local k = s or 1
	if type(v) == "table" then
		return NumberRange.new(v[1] * k, (v[2] or v[1]) * k)
	elseif type(v) == "number" then
		return NumberRange.new(v * k)
	end
	return NumberRange.new(default)
end

local function randomUnit(): Vector3
	local z = 2 * math.random() - 1
	local a = 2 * math.pi * math.random()
	local r = math.sqrt(1 - z * z)
	return Vector3.new(r * math.cos(a), z, r * math.sin(a))
end

-- random direction within `deg` of axis
local function randomCone(axis: Vector3, deg: number): Vector3
	local ref = if math.abs(axis.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local p = axis:Cross(ref).Unit
	local q = axis:Cross(p)
	local th = math.rad(deg) * math.sqrt(math.random())
	local ph = 2 * math.pi * math.random()
	return (axis * math.cos(th) + (p * math.cos(ph) + q * math.sin(ph)) * math.sin(th)).Unit
end

local function aim(pos: Vector3, dir: Vector3): CFrame
	local up = if math.abs(dir.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(pos, pos + dir, up)
end

-------------------------------------------------------------------------------
-- Timeline engine (one Heartbeat connection for every live effect)
-------------------------------------------------------------------------------
type Step = (t: number) -> ()
type Effect = {
	t0: number,
	life: number,
	steps: { Step },
	root: Instance,
	particles: number,
	stopped: boolean,
	finished: boolean,
	speed: number, -- timeline rate (ChargeUp is retimed to its clip)
}

local active: { Effect } = {}
local heartbeat: RBXScriptConnection? = nil
local liveParticles = 0
local container: Folder? = nil

local function getContainer(): Folder
	local c = container
	if c and c.Parent then
		return c
	end
	local f = Instance.new("Folder")
	f.Name = "LihFolkVFX"
	f.Parent = Workspace
	container = f
	return f
end

local function finish(e: Effect)
	-- (a stop() call only flags `stopped`; the next tick lands here and really cleans up)
	if e.finished then
		return
	end
	e.finished = true
	e.stopped = true
	liveParticles = math.max(0, liveParticles - e.particles)
	e.root:Destroy()
end

local function tick()
	local now = os.clock()
	for i = #active, 1, -1 do
		local e = active[i]
		local t = now - e.t0
		if e.stopped or t >= e.life then
			finish(e)
			table.remove(active, i)
		else
			local ok, err = pcall(function()
				local lt = t * e.speed
				for _, step in e.steps do
					step(lt)
				end
			end)
			if not ok then
				warn("[LihFolkVFX] effect step failed, cleaning up: " .. tostring(err))
				finish(e)
				table.remove(active, i)
			end
		end
	end
	if #active == 0 and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function start(e: Effect)
	table.insert(active, e)
	-- safety net: even if the loop dies, the instances go away
	Debris:AddItem(e.root, e.life + 3)
	if not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(tick)
	end
	tick()
end

-------------------------------------------------------------------------------
-- Build context
-------------------------------------------------------------------------------
type BuildCtx = {
	root: Instance,
	base: CFrame, -- swing frame (XZ plane = swing plane, -Z = forward)
	body: CFrame, -- the cf passed to play (no flip/tilt/yaw)
	ground: CFrame, -- flat on the floor under body, facing body's heading
	anchor: BasePart,
	pal: Palette,
	scale: number,
	detail: number, -- 0..1 count scale
	deco: boolean, -- decoration layers on
	steps: { Step },
	particles: number,
	pathHead: (t: number) -> Vector3, -- dash head in body space
	character: Model?,
	arcShift: number, -- degrees added to every unit's yaw (from opts.arc), then clamped to the front
}

local function frameOf(space: string?, ctx: BuildCtx): CFrame
	if space == "ground" then
		return ctx.ground
	elseif space == "swing" then
		return ctx.base
	end
	return ctx.body -- "body" and "path"
end

local function count(n: number, ctx: BuildCtx): number
	if n <= 0 then
		return 0
	end
	return math.max(1, math.floor(n * ctx.detail + 0.5))
end

-------------------------------------------------------------------------------
-- Unit builder: one crescent or ring with all its layers
-------------------------------------------------------------------------------
local BODY_REVEAL = { "strip_body_reveal_1", "strip_body_reveal_2", "strip_body_reveal_3", "strip_body" }
local BODY_ERODE = { "strip_body_erode_1", "strip_body_erode_2", "strip_body_erode_3", "strip_body_erode_4", "strip_body_erode_5" }
local function bodyStack(family: string): { string }
	local ids = { family }
	for i = 1, 5 do
		table.insert(ids, family .. "_erode_" .. i)
	end
	return ids
end

local function inkStages(family: string): { string }
	return { family, family .. "_erode_1", family .. "_erode_2", family .. "_erode_3" }
end

--[[ Cross-fade between baked erosion stages: part A shows stage floor(s) and fades out while part B
	shows the next (smaller, it is a subset) stage at full alpha, so the break-up eats in smoothly
	instead of popping. `alpha` is the layer's overall opacity. ]]
local function crossfade(a: Part, am: SpecialMesh, b: Part?, bm: SpecialMesh?, ids: { string }, s: number, alpha: number)
	local n = #ids
	local k = math.clamp(math.floor(s), 1, n)
	local f = if k >= n then 0 else s - k
	am.TextureId = ids[k]
	a.Transparency = 1 - alpha * (1 - f)
	if b and bm then
		if k < n then
			bm.TextureId = ids[k + 1]
			b.Transparency = 1 - alpha
		else
			b.Transparency = 1
		end
	end
end

-- Frontal rule: a slash arc stays in front of the character. In the unit's own plane phi 90 is forward,
-- so the arc (tail .. head) is clamped to 90 +- FRONT_LIMIT and the drift may carry the head only
-- FRONT_DRIFT degrees further. Arcs longer than 2 * FRONT_LIMIT are not allowed (no rings or spins).
local FRONT_LIMIT = 100
local FRONT_DRIFT = 10

local function frontalYaw(u: Unit, shift: number): (number, number)
	local half = math.min(u.span, 2 * FRONT_LIMIT) / 2
	local yaw = math.clamp(u.yaw + shift, half - FRONT_LIMIT, FRONT_LIMIT - half)
	local drift = math.clamp(u.drift, 0, math.max(0, FRONT_LIMIT + FRONT_DRIFT - (half + yaw)))
	return yaw, drift
end

local function buildUnit(u: Unit, ctx: BuildCtx)
	local R = u.radius * ctx.scale
	local unitYaw, driftDeg = frontalYaw(u, ctx.arcShift)
	local cf = ctx.base
		* CFrame.new(0, u.lift * ctx.scale, 0)
		* CFrame.Angles(0, 0, math.rad(u.tilt))
		* CFrame.Angles(0, math.rad(unitYaw), 0)
	local pivot = newPart("Unit", cf, ctx.root)
	local tail = 90 - u.span / 2
	local head0 = 90 + u.span / 2
	local tHold = u.sweep + u.hold
	local tEnd = tHold + u.erode
	local smooth = u.smoothErode == true

	-- shared clock of the unit: reveal r(t) and the head angle
	local function reveal(t: number): number
		return easeOut(t / u.sweep, u.sweepEase)
	end
	local function yawAt(t: number): number
		local r = reveal(t)
		local drift = driftDeg * easeOut((t - u.sweep) / (tEnd - u.sweep), 2)
		return -u.span * (1 - r) + drift
	end

	local yawOffset = LihFolkVFX.Config.meshYawOffset
	local meshKey = meshId(u.mesh)

	-- 1) dark ink smear mesh (painted over the body's inner half)
	local family = u.ink or "strip_ink"
	local inkTex = tex(family)
	if meshKey and inkTex then
		local part, mesh = meshLayer("Ink", meshKey, inkTex, cf, ctx.root, false)
		mesh.VertexColor = v3(ctx.pal.dark, 1)
		local partB: Part?, meshB: SpecialMesh? = nil, nil
		if smooth then
			local pb, mb = meshLayer("InkB", meshKey, inkTex, cf, ctx.root, false)
			mb.VertexColor = v3(ctx.pal.dark, 1)
			partB, meshB = pb, mb
		end
		local inkIds: { string } = {}
		for _, k in inkStages(family) do
			table.insert(inkIds, tex(k) or inkTex)
		end
		local lastStage = 0
		table.insert(ctx.steps, function(t: number)
			local lt = t - u.delay - 0.03
			if lt < 0 then
				part.Transparency = 1
				if partB then
					partB.Transparency = 1
				end
				return
			end
			local inT = clamp01(lt / 0.07)
			local outT = clamp01((lt - (tHold + u.erode * 0.4)) / (u.erode * 0.65))
			local alpha = 0.88 * inT - 0.88 * easeIn(outT, 1.6)
			-- erosion is front-loaded (sqrt): the break-up starts right after the hold
			local ex = clamp01((lt - tHold) / u.erode)
			if smooth then
				local s = if lt < tHold then 1 else 1 + 3 * math.sqrt(ex)
				crossfade(part, mesh, partB, meshB, inkIds, s, math.max(alpha, 0))
			else
				part.Transparency = 1 - alpha
				local stage = if lt < tHold then 1 else 1 + math.clamp(math.floor(3 * math.sqrt(ex)) + 1, 1, 3)
				if stage ~= lastStage then
					lastStage = stage
					mesh.TextureId = inkIds[stage]
				end
			end
			local s = R * u.inkScale * (0.95 + 0.07 * easeOut(lt / tEnd, 2))
			local icf = cf * CFrame.new(0, -u.inkDrop * ctx.scale, 0) * CFrame.Angles(0, math.rad(yawAt(lt) - u.inkLag + yawOffset), 0)
			mesh.Scale = Vector3.new(s, s, s)
			part.CFrame = icf
			if partB and meshB then
				meshB.Scale = mesh.Scale
				partB.CFrame = icf
			end
		end)
	end

	-- 2) body mesh: reveal swaps during the sweep, erosion swaps (or cross-fades) after the hold
	local bodyTex = tex("strip_body")
	if meshKey and bodyTex then
		local part, mesh = meshLayer("Body", meshKey, bodyTex, cf, ctx.root, true)
		part.Color = ctx.pal.main
		mesh.VertexColor = v3(ctx.pal.main, u.bodyGain)
		local partB: Part?, meshB: SpecialMesh? = nil, nil
		if smooth then
			local pb, mb = meshLayer("BodyB", meshKey, bodyTex, cf, ctx.root, true)
			pb.Color = ctx.pal.main
			mb.VertexColor = v3(ctx.pal.main, u.bodyGain)
			partB, meshB = pb, mb
		end
		local reveals: { string } = {}
		local fam = u.body or "strip_body"
		for i, k in BODY_REVEAL do
			local key = if fam == "strip_body" then k elseif i < 4 then fam .. "_reveal_" .. i else fam
			table.insert(reveals, tex(key) or bodyTex)
		end
		local erodes: { string } = {}
		for _, k in BODY_ERODE do
			table.insert(erodes, tex(k) or bodyTex)
		end
		local stack: { string } = {}
		for _, k in bodyStack(u.body or "strip_body") do
			table.insert(stack, tex(k) or bodyTex)
		end
		local current = ""
		table.insert(ctx.steps, function(t: number)
			local lt = t - u.delay
			if lt < 0 then
				part.Transparency = 1
				if partB then
					partB.Transparency = 1
				end
				return
			end
			local fade = clamp01((lt - (tHold + u.erode * 0.4)) / (u.erode * 0.6))
			local alpha = 1 - easeIn(fade, 1.8)
			if smooth and lt >= tHold then
				-- strip_body -> erode_5 as one continuous stack (front-loaded)
				crossfade(part, mesh, partB, meshB, stack, 1 + 5 * math.sqrt(clamp01((lt - tHold) / u.erode)), alpha)
				current = ""
			else
				local id: string
				if lt < u.sweep then
					local r = reveal(lt)
					id = reveals[if r < 0.42 then 1 elseif r < 0.67 then 2 elseif r < 0.9 then 3 else 4]
				elseif lt < tHold then
					id = if smooth then stack[1] else reveals[4]
				else
					local k = math.clamp(math.floor(5 * math.sqrt(clamp01((lt - tHold) / u.erode))) + 1, 1, 5)
					id = erodes[k]
				end
				if id ~= current then
					current = id
					mesh.TextureId = id
				end
				part.Transparency = 1 - alpha
				if partB then
					partB.Transparency = 1
				end
			end
			local grow = 0.86 + 0.14 * easeOut(lt / tHold, 2) + (u.expand or 0.04) * easeOut((lt - tHold) / u.erode, 2)
			local s = R * grow
			local bcf = cf * CFrame.Angles(0, math.rad(yawAt(lt) + yawOffset), 0)
			mesh.Scale = Vector3.new(s, s, s)
			part.CFrame = bcf
			if partB and meshB then
				meshB.Scale = mesh.Scale
				partB.CFrame = bcf
			end
		end)
	end

	-- 2b) white-hot rim along the whole arc once it is drawn (value ladder: white rim, element body, dark ink)
	local rimTex = if u.rim then tex("strip_edge") else nil
	if meshKey and rimTex then
		local part, mesh = meshLayer("Rim", meshKey, rimTex, cf, ctx.root, true)
		part.Color = ctx.pal.hot
		mesh.VertexColor = v3(ctx.pal.hot, u.rim or 1)
		table.insert(ctx.steps, function(t: number)
			local lt = t - u.delay
			if lt < u.sweep * 0.8 then
				part.Transparency = 1
				return
			end
			local alpha = clamp01((lt - u.sweep * 0.8) / 0.04) * (1 - easeIn((lt - tHold) / (u.erode * 0.55), 1.3))
			part.Transparency = 1 - alpha
			local s = R * (0.86 + 0.14 * easeOut(lt / tHold, 2) + (u.expand or 0.04) * easeOut((lt - tHold) / u.erode, 2))
			mesh.Scale = Vector3.new(s, s, s)
			part.CFrame = cf * CFrame.Angles(0, math.rad(yawAt(lt) + yawOffset), 0)
		end)
	end

	-- 3) additive flipbook glow card (+ dark card) lying in the swing plane
	local cardSize = 2 * R / u.cardROut
	local cardRot = tail + LihFolkVFX.Config.cardRotation
	local cardAtt = Instance.new("Attachment")
	cardAtt.Parent = pivot
	local cardsOn = u.cards ~= false
	local cardTex = if cardsOn then tex(u.card) else nil
	if cardTex then
		local e = newEmitter(cardAtt, {
			Texture = cardTex,
			Color = ColorSequence.new(ctx.pal.glow),
			LightEmission = 1,
			Brightness = u.cardBrightness,
			Size = NumberSequence.new(cardSize),
			Transparency = ns({ { 0, u.cardTransparency }, { 0.8, u.cardTransparency }, { 1, 1 } }),
			Lifetime = NumberRange.new(tEnd),
			Speed = NumberRange.new(0.001),
			SpreadAngle = Vector2.zero,
			EmissionDirection = Enum.NormalId.Top,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Rotation = NumberRange.new(cardRot),
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			ZOffset = 0.5,
		})
		local fired = false
		table.insert(ctx.steps, function(t: number)
			if not fired and t >= u.delay then
				fired = true
				e:Emit(1)
			end
		end)
		ctx.particles += 1
	end
	if cardsOn and u.inkCard and ctx.deco then
		local inkCardTex = tex(u.inkCard)
		if inkCardTex then
			local e = newEmitter(cardAtt, {
				Texture = inkCardTex,
				Color = ColorSequence.new(ctx.pal.dark),
				LightEmission = 0,
				Brightness = 1,
				Size = NumberSequence.new(cardSize * u.inkScale),
				Transparency = ns({ { 0, 0.35 }, { 0.75, 0.35 }, { 1, 1 } }),
				Lifetime = NumberRange.new(tEnd * 1.1),
				Speed = NumberRange.new(0.001),
				SpreadAngle = Vector2.zero,
				EmissionDirection = Enum.NormalId.Top,
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
				Rotation = NumberRange.new(cardRot - u.inkLag),
				FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
				FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
				ZOffset = -0.5,
			})
			local fired = false
			table.insert(ctx.steps, function(t: number)
				if not fired and t >= u.delay then
					fired = true
					e:Emit(1)
				end
			end)
			ctx.particles += 1
		end
	end

	-- 4) hot edge: a Beam band riding the head (solid ribbon if beam_edge_h is not uploaded)
	do
		local a0 = Instance.new("Attachment")
		local a1 = Instance.new("Attachment")
		a0.Parent = pivot
		a1.Parent = pivot
		local beams: { Beam } = {}
		local function makeBeam(widthMul: number, transp: number, color: ColorSequence, brightness: number)
			local b = Instance.new("Beam")
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.FaceCamera = true
			b.Segments = 24
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Brightness = brightness
			b.Color = color
			b.Texture = (LihFolkVFX.Textures :: any).beam_edge_h or ""
			b.TextureMode = Enum.TextureMode.Stretch
			b.TextureLength = 1
			b.TextureSpeed = 0
			b.Transparency = NumberSequence.new(1)
			b:SetAttribute("WidthMul", widthMul)
			b:SetAttribute("Base", transp)
			b.Parent = pivot
			table.insert(beams, b)
		end
		makeBeam(1, 0, ColorSequence.new(ctx.pal.glow, ctx.pal.hot), u.edge.brightness)
		if ctx.deco then
			makeBeam(3.2, 0.72, ColorSequence.new(ctx.pal.glow), 1.5)
		end
		local rEdge = R * 0.985
		local yEdge = (u.edge.lift or 0) * R + 0.05
		table.insert(ctx.steps, function(t: number)
			local lt = t - u.delay
			local alive = lt >= 0 and lt <= u.edge.life
			if not alive then
				for _, b in beams do
					b.Transparency = NumberSequence.new(1)
				end
				return
			end
			local head = head0 + yawAt(lt)
			local band = u.edge.band * (0.35 + 0.65 * reveal(lt))
			local phiA = head - band
			local k = 4 / 3 * math.tan(math.rad(band) / 4) * rEdge
			a0.CFrame = CFrame.fromMatrix(arcPoint(phiA, rEdge, yEdge), arcTangent(phiA), Vector3.yAxis)
			a1.CFrame = CFrame.fromMatrix(arcPoint(head, rEdge, yEdge), arcTangent(head), Vector3.yAxis)
			local life = lt / u.edge.life
			local w = u.edge.width * ctx.scale * (1 - easeIn(life, 1.5))
			local fade = easeIn(life, 2)
			for _, b in beams do
				b.CurveSize0 = k
				b.CurveSize1 = k
				local wm = b:GetAttribute("WidthMul") :: number
				local base = b:GetAttribute("Base") :: number
				b.Width0 = w * wm * 0.15
				b.Width1 = w * wm
				local o = base + (1 - base) * fade
				b.Transparency = ns({ { 0, 1 }, { 0.3, math.min(1, o + 0.35) }, { 0.8, o }, { 1, math.min(1, o + 0.1) } })
			end
		end)
	end

	-- 5) head-spawned particles: sparks, glints, debris (along the swing, not radial)
	local emitAtt = Instance.new("Attachment")
	emitAtt.Parent = pivot
	local spawners: { { e: ParticleEmitter, n: number, done: number, out: number, up: number, ramp: number } } = {}
	local function spawner(e: ParticleEmitter?, n: number, outward: number, up: number, ramp: number)
		if e and n > 0 then
			table.insert(spawners, { e = e, n = n, done = 0, out = outward, up = up, ramp = ramp })
			ctx.particles += n
		end
	end
	local sparkTex = tex("spark_streak")
	spawner(sparkTex and newEmitter(emitAtt, {
		Texture = sparkTex,
		Color = ColorSequence.new(ctx.pal.spark),
		LightEmission = 1,
		Brightness = 5,
		Size = ns({ { 0, 0.55 * ctx.scale }, { 1, 0 } }),
		Transparency = ns({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.2, 0.38),
		Speed = NumberRange.new(34, 58),
		SpreadAngle = Vector2.new(14, 14),
		EmissionDirection = Enum.NormalId.Front,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Drag = 6,
		Acceleration = Vector3.new(0, -24, 0),
		ZOffset = 1,
	}) or nil, count(u.sparks, ctx), 0.35, 0.12, 1)
	local glintTex = tex("flip_glint_4x4")
	if ctx.deco then
		spawner(glintTex and newEmitter(emitAtt, {
			Texture = glintTex,
			Color = ColorSequence.new(ctx.pal.hot),
			LightEmission = 1,
			Brightness = 6,
			Size = NumberSequence.new(u.glintSize * ctx.scale),
			Lifetime = NumberRange.new(0.18, 0.24),
			Speed = NumberRange.new(0.5, 2),
			SpreadAngle = Vector2.new(60, 60),
			EmissionDirection = Enum.NormalId.Front,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			ZOffset = 2,
		}) or nil, count(u.glints, ctx), 0.6, 0.1, 1)
	end
	local petalTex = tex("flip_petals_8x8")
	spawner(petalTex and newEmitter(emitAtt, {
		Texture = petalTex,
		Color = ColorSequence.new(ctx.pal.debris),
		LightEmission = ctx.pal.debrisLight or 0,
		Brightness = 1,
		Size = ns({ { 0, 0.35 * u.debrisSize * ctx.scale }, { 0.15, 0.7 * u.debrisSize * ctx.scale }, { 1, 0.45 * u.debrisSize * ctx.scale } }),
		Squash = ns({ { 0, 0 }, { 0.25, 0.6 }, { 0.5, -0.4 }, { 0.75, 0.5 }, { 1, 0 } }), -- fake tumble
		Transparency = ns({ { 0, 0 }, { 0.7, 0 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.55, 0.95),
		Speed = NumberRange.new(30, 62),
		SpreadAngle = Vector2.new(18, 18),
		EmissionDirection = Enum.NormalId.Front,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-420, 420),
		Drag = 3.2,
		Acceleration = Vector3.new(0, -14, 0),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NumberRange.new(0.001),
		FlipbookStartRandom = true,
		ZOffset = 0.2,
	}) or nil, count(u.debris, ctx), 0.55, 0.15, 1.15)

	if #spawners > 0 then
		table.insert(ctx.steps, function(t: number)
			local lt = t - u.delay
			if lt < 0 then
				return
			end
			for _, s in spawners do
				-- spread each burst over the sweep (+ a short tail), always from the current head
				local due = math.min(s.n, math.floor(s.n * clamp01(lt / (u.sweep * s.ramp + 0.03)) + 0.5))
				local k = due - s.done
				if k > 0 then
					local head = head0 + yawAt(lt)
					local dir = (arcTangent(head) + arcPoint(head, 1, 0) * s.out + Vector3.yAxis * s.up + Vector3.new(0, 0, -(u.fwd or 0))).Unit
					local pos = arcPoint(head, R * (0.88 + 0.1 * math.random()), 0.1)
					emitAtt.CFrame = CFrame.lookAt(pos, pos + dir)
					s.e:Emit(k)
					s.done = due
				end
			end
		end)
	end

	-- 6) floating square sparks along the whole arc at the hold (violet style)
	local squareTex = tex("spark_square")
	local nSq = if ctx.deco then count(u.squares, ctx) else 0
	if squareTex and nSq > 0 then
		local sqAtt = Instance.new("Attachment")
		sqAtt.Parent = pivot
		local e = newEmitter(sqAtt, {
			Texture = squareTex,
			Color = ColorSequence.new(ctx.pal.spark),
			LightEmission = 1,
			Brightness = 4,
			Size = ns({ { 0, 0 }, { 0.15, 0.32 * ctx.scale }, { 0.35, 0.12 * ctx.scale }, { 0.55, 0.28 * ctx.scale }, { 1, 0 } }),
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(3, 10),
			SpreadAngle = Vector2.new(40, 40),
			EmissionDirection = Enum.NormalId.Front,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Rotation = NumberRange.new(0, 45),
			Drag = 2,
			Acceleration = Vector3.new(0, 2.5, 0),
			ZOffset = 1,
		})
		local fired = false
		table.insert(ctx.steps, function(t: number)
			if not fired and t - u.delay >= u.sweep * 0.7 then
				fired = true
				for _ = 1, nSq do
					local phi = tail + u.span * (0.15 + 0.85 * math.random()) + yawAt(t - u.delay)
					local pos = arcPoint(phi, R * (0.75 + 0.3 * math.random()), (math.random() - 0.5) * 1.2)
					sqAtt.CFrame = CFrame.lookAt(pos, pos + (arcPoint(phi, 1, 0) + Vector3.yAxis * 0.4).Unit)
					e:Emit(1)
				end
			end
		end)
		ctx.particles += nSq
	end
end

-------------------------------------------------------------------------------
-- Generic layers (ThrustPierce, OverheadCleave, DashTrail, HitSpark, ChargeUp, flashes)
-------------------------------------------------------------------------------
--[[ Burst: Emit `count` particles at time t (or spread over `over` seconds).
	dir: "none" (sprite/card), "cone" (forward, spread), "back" (+Z, spread), "up" (spread),
	     "sphere" (outward from a radius), "disc" (radial in the floor plane, `up` lift),
	     "converge" (start on a sphere of `radius`, fly to `at`; speed ~ radius / life)
	orient: "camera" (default), "vpar" (streaks), "flat" (card in the space's floor plane),
	        "flatForward" (card facing forward) ]]
local function buildBurst(b: any, ctx: BuildCtx)
	if b.deco and not ctx.deco then
		return
	end
	local n = count(b.count or 1, ctx)
	local texId = tex(b.tex)
	if n <= 0 or not texId then
		return
	end
	local s = ctx.scale
	local orient = b.orient or "camera"
	local mode = b.dir or "none"
	local props: { [string]: any } = {
		Texture = texId,
		Color = roleSeq(ctx.pal, b.role),
		LightEmission = if b.debris then (ctx.pal.debrisLight or 0) else (b.le or 1),
		Brightness = b.bright or 1,
		Size = seqOf(b.size or 1, s),
		Transparency = if b.transp then seqOf(b.transp, 1) else NumberSequence.new(0),
		Lifetime = range(b.life, 0.3),
		Speed = if b.speed then range(b.speed, 0, s) else NumberRange.new(0.001),
		SpreadAngle = Vector2.zero,
		EmissionDirection = if orient == "flat" then Enum.NormalId.Top else Enum.NormalId.Front,
		Orientation = if orient == "flat" or orient == "flatForward"
			then Enum.ParticleOrientation.VelocityPerpendicular
			elseif orient == "vpar" then Enum.ParticleOrientation.VelocityParallel
			else Enum.ParticleOrientation.FacingCamera,
		Rotation = range(b.rot, 0),
		RotSpeed = range(b.rotSpeed, 0),
		Drag = b.drag or 0,
		Acceleration = vec(b.acc, s),
		ZOffset = b.zoff or 0,
	}
	if b.grid then
		props.FlipbookLayout = if b.grid == 8 then Enum.ParticleFlipbookLayout.Grid8x8 else Enum.ParticleFlipbookLayout.Grid4x4
		if b.mode == "random" then
			props.FlipbookMode = Enum.ParticleFlipbookMode.Loop
			props.FlipbookFramerate = NumberRange.new(0.001)
			props.FlipbookStartRandom = true
		else
			props.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end
	end
	local att = Instance.new("Attachment")
	att.Parent = ctx.anchor
	local e = newEmitter(att, props)
	ctx.particles += n
	local at = vec(b.at, s)
	local r = (b.radius or 0) * s
	local spread = b.spread or 0
	local function spawnCf(lt: number): CFrame
		local pos = at
		if b.space == "path" then
			pos += ctx.pathHead(lt)
		end
		if mode == "cone" then
			return aim(pos, randomCone(Vector3.new(0, 0, -1), spread))
		elseif mode == "back" then
			local j = randomUnit() * r
			return aim(pos + Vector3.new(j.X, j.Y, 0), randomCone(Vector3.new(0, 0, 1), spread))
		elseif mode == "up" then
			local a = 2 * math.pi * math.random()
			return aim(pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), randomCone(Vector3.yAxis, spread))
		elseif mode == "sphere" then
			local d = randomUnit()
			return aim(pos + d * r * math.random(), d)
		elseif mode == "disc" then
			local a = 2 * math.pi * math.random()
			local radial = Vector3.new(math.cos(a), 0, math.sin(a))
			return aim(pos + radial * r * (0.5 + 0.5 * math.random()), (radial + Vector3.yAxis * (b.up or 0)).Unit)
		elseif mode == "converge" then
			local d = (randomUnit() + Vector3.yAxis * (b.up or 0)).Unit
			return aim(pos + d * r, -d)
		end
		return CFrame.new(pos)
	end
	local t0 = b.t or 0
	local over = b.over or 0
	local done = 0
	local frame = frameOf(b.space, ctx)
	table.insert(ctx.steps, function(t: number)
		local lt = t - t0
		if lt < 0 or done >= n then
			return
		end
		local due = if over > 0 then math.min(n, math.floor(n * clamp01(lt / over)) + 1) else n
		for _ = done + 1, due do
			att.WorldCFrame = frame * spawnCf(lt)
			e:Emit(1)
		end
		done = due
	end)
end

--[[ Ring: a ground_ring-style SpecialMesh scaling from r0 to r1 (ease "out" expands, "in" implodes),
	in the space's floor plane ("flat") or facing forward ("forward"). le 0 = dark SmoothPlastic. ]]
local function buildRing(g: any, ctx: BuildCtx)
	if g.deco and not ctx.deco then
		return
	end
	local m = meshId(g.mesh or "ground_ring")
	local tx = tex(g.tex or "strip_ground_ring")
	if not (m and tx) then
		return
	end
	local s = ctx.scale
	local frame = frameOf(g.space, ctx) * CFrame.new(vec(g.at, s))
	if g.plane == "forward" then
		frame = frame * CFrame.Angles(math.rad(90), 0, 0)
	end
	local neon = (g.le or 1) > 0
	local part, mesh = meshLayer("Ring", m, tx, frame, ctx.root, neon)
	local c = role(ctx.pal, g.role)
	part.Color = c
	mesh.VertexColor = v3(c, g.gain or 1)
	local t0, life = g.t or 0, g.life
	local implode = g.ease == "in"
	local a0 = 1 - (g.transp0 or 0)
	local fadeIn, hold = g.fadeIn or 0, g.hold or 0
	table.insert(ctx.steps, function(t: number)
		local lt = t - t0
		if lt < 0 or lt > life then
			part.Transparency = 1
			return
		end
		local x = lt / life
		local k = if implode then easeIn(x, g.pow or 2) else easeOut(x, g.pow or 3)
		local rr = (g.r0 + (g.r1 - g.r0) * k) * s
		mesh.Scale = Vector3.new(rr, rr, rr)
		local alpha = a0 * (if fadeIn > 0 then clamp01(x / fadeIn) else 1)
		alpha *= 1 - easeIn((x - hold) / (1 - hold), g.fadePow or 1.4)
		part.Transparency = 1 - alpha
		part.CFrame = frame * CFrame.Angles(0, math.rad((g.spin or 0) * easeOut(x, 2)), 0)
	end)
end

--[[ Beam ribbon: head grows from `from` toward `to` (grow, ease-out), or along the dash path (path = true,
	then `to` is an offset from the dash head); after tailDelay the tail chases the head. ]]
local function buildBeam(bm: any, ctx: BuildCtx)
	if bm.deco and not ctx.deco then
		return
	end
	local s = ctx.scale
	local frame = frameOf(bm.space, ctx)
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	a0.Parent = ctx.anchor
	a1.Parent = ctx.anchor
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.FaceCamera = true
	b.Segments = bm.segments or 12
	b.LightEmission = bm.le or 1
	b.LightInfluence = 0
	b.Brightness = bm.bright or 1
	b.Color = roleSeq(ctx.pal, bm.role)
	b.Texture = (LihFolkVFX.Textures :: any)[bm.tex or ""] or ""
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.TextureSpeed = 0
	b.ZOffset = bm.zoff or 0
	b.Transparency = NumberSequence.new(1)
	b.Parent = ctx.anchor
	local from, to = vec(bm.from, s), vec(bm.to, s)
	local t0, life = bm.t or 0, bm.life
	local tailDelay = bm.tailDelay or life
	table.insert(ctx.steps, function(t: number)
		local lt = t - t0
		if lt < 0 or lt > life then
			b.Transparency = NumberSequence.new(1)
			return
		end
		local head: Vector3
		if bm.path then
			head = ctx.pathHead(lt) + to
		else
			head = from:Lerp(to, easeOut(lt / (bm.grow or 0.05), bm.growPow or 2.4))
		end
		local tk = easeIn((lt - tailDelay) / math.max(life - tailDelay, 1e-3), bm.tailPow or 1.5) * (bm.tailMax or 1)
		local tailP = from:Lerp(head, tk)
		if (head - tailP).Magnitude < 0.05 then
			head = tailP + Vector3.new(0, 0, -0.05)
		end
		a0.WorldCFrame = frame * CFrame.new(tailP)
		a1.WorldCFrame = frame * CFrame.new(head)
		local x = lt / life
		local wk = 1 - easeIn(x, bm.shrinkPow or 1.5) * (bm.shrink or 1)
		b.Width0 = bm.width0 * s * wk
		b.Width1 = bm.width1 * s * wk
		local o = (bm.transp or 0) + (1 - (bm.transp or 0)) * easeIn(x, bm.fadePow or 2)
		b.Transparency = ns({
			{ 0, math.min(1, o + (bm.tailFade or 0.5)) },
			{ 0.5, o },
			{ 1, math.min(1, o + (bm.headFade or 0)) },
		})
	end)
end

--[[ Ghosts: `count` afterimages of opts.character, one every `interval`, each a Neon copy of the
	visible BaseParts (max `maxParts`) fading over `life`. Oldest uses oldRole. Needs opts.character. ]]
local function buildGhosts(gs: any, ctx: BuildCtx)
	local character = ctx.character
	if not character or not ctx.deco then
		return
	end
	local n = count(gs.count or 4, ctx)
	local spawned = 0
	local ghosts: { { t0: number, parts: { BasePart } } } = {}
	local function snapshot(i: number, t: number)
		local model = Instance.new("Model")
		model.Name = "Ghost"
		local c = role(ctx.pal, if i == 1 then (gs.oldRole or gs.role) else gs.role)
		local parts: { BasePart } = {}
		for _, d in character:GetDescendants() do
			if #parts >= (gs.maxParts or 24) then
				break
			end
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.95 then
				local ok, copy = pcall(function()
					return d:Clone()
				end)
				if ok and copy then
					copy:ClearAllChildren()
					copy.Anchored = true
					copy.CanCollide = false
					copy.CanQuery = false
					copy.CanTouch = false
					copy.CastShadow = false
					copy.Massless = true
					copy.Material = Enum.Material.Neon
					copy.Color = c
					if copy:IsA("MeshPart") then
						copy.TextureID = ""
					end
					copy.CFrame = d.CFrame
					copy.Transparency = 1
					copy.Parent = model
					table.insert(parts, copy)
				end
			end
		end
		model.Parent = ctx.root
		table.insert(ghosts, { t0 = t, parts = parts })
	end
	table.insert(ctx.steps, function(t: number)
		local lt = t - (gs.t or 0)
		if lt < 0 then
			return
		end
		while spawned < n and lt >= spawned * gs.interval do
			spawned += 1
			snapshot(spawned, lt)
		end
		for _, g in ghosts do
			local x = clamp01((lt - g.t0) / gs.life)
			local tr = (gs.transp0 or 0.5) + (1 - (gs.transp0 or 0.5)) * easeIn(x, 1.2)
			for _, p in g.parts do
				p.Transparency = tr
			end
		end
	end)
end

--[[ Spikes: a crystal cluster erupting from `at`: a near-vertical centre spike, `count` main spikes leaning
	outward, `small.count` short ones at the base, all bedded in an icy mound; staggered eruption with a small
	overshoot, a hold, then each spike collapses and throws shard particles. Meshes are 1 stud wide and
	1 stud long along Y, centred (as Roblox imports them); the facet texture carries the value ladder
	(white facet edges, pale body, deep base), tinted by VertexColor. ]]
local function buildSpikes(sp: any, ctx: BuildCtx)
	local m = meshId(sp.mesh or "crystal")
	if not m then
		return
	end
	local s = ctx.scale
	local frame = frameOf(sp.space, ctx) * CFrame.new(vec(sp.at, s))
	local texId = if sp.tex then (tex(sp.tex) or "") else ""
	local neon = sp.neon == true
	local function rnd(r: any): number
		return r[1] + (r[2] - r[1]) * math.random()
	end
	local sh = sp.shards
	local shardEmitter: ParticleEmitter? = nil
	local shardAtt = Instance.new("Attachment")
	shardAtt.Parent = ctx.anchor

	-- the list of spikes: { len, wid, lean, radius, angle, role, t }
	local list: { { number } } = {}
	local nMain = count(sp.count or 6, ctx)
	for i = 1, nMain do
		local centre = sp.centre and i == 1
		table.insert(list, {
			rnd(sp.length) * (if centre then 1.15 else 1),
			rnd(sp.width) * (if centre then 1.15 else 1),
			if centre then 4 else rnd(sp.lean),
			if centre then 0 else rnd(sp.radius),
			(i - 1) / math.max(nMain - 1, 1) * 2 * math.pi + (math.random() - 0.5) * 0.6,
			if i % 3 == 0 then 2 else 1,
		})
	end
	local sm = sp.small
	if sm and ctx.deco then
		for i = 1, count(sm.count or 4, ctx) do
			table.insert(list, { rnd(sm.length), rnd(sm.width), rnd(sm.lean), rnd(sm.radius), math.random() * 2 * math.pi, 1 })
		end
	end
	local n = #list
	if sh then
		local shTex = tex(sh.tex or "shard_A")
		if shTex then
			shardEmitter = newEmitter(shardAtt, {
				Texture = shTex,
				Color = roleSeq(ctx.pal, sh.role),
				LightEmission = sh.le or 0.5,
				Brightness = sh.bright or 1,
				Size = seqOf(sh.size, s),
				Transparency = ns({ { 0, 0 }, { 0.75, 0.1 }, { 1, 1 } }),
				Lifetime = range(sh.life, 0.5),
				Speed = range(sh.speed, 10, s),
				SpreadAngle = Vector2.new(35, 35),
				EmissionDirection = Enum.NormalId.Front,
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-360, 360),
				Drag = sh.drag or 1,
				Acceleration = vec(sh.acc, s),
				ZOffset = 1,
			})
			ctx.particles += nMain * (sh.per or 3)
		end
	end

	-- icy mound the spikes are bedded in
	local md = sp.mound
	if md then
		local mm = meshId(md.mesh or "ice_mound")
		if mm then
			local part, mesh = meshLayer("Mound", mm, texId, frame, ctx.root, neon)
			local c = role(ctx.pal, md.role or sp.role)
			part.Color = c
			mesh.VertexColor = v3(c, sp.gain or 1)
			local t0 = sp.t or 0
			table.insert(ctx.steps, function(t: number)
				local lt = t - t0
				local x = clamp01(lt / (sp.grow * 1.2))
				local fx = clamp01((lt - sp.grow - sp.hold - sp.shatter) / (md.fade or 0.3))
				if lt < 0 or fx >= 1 then
					part.Transparency = 1
					return
				end
				local k = easeOut(x, 3)
				mesh.Scale = Vector3.new(md.width * s * k, md.height * s * k * (1 - 0.5 * fx), md.width * s * k)
				part.CFrame = frame * CFrame.new(0, md.height * 0.35 * 0.5 * s * k * (1 - 0.5 * fx), 0)
				part.Transparency = easeIn(fx, 1.2)
			end)
		end
	end

	local order: { number } = {}
	for i = 1, n do
		table.insert(order, i)
	end
	for i = n, 2, -1 do -- random eruption order (the centre spike first)
		local j = math.random(2, math.max(i, 2))
		order[i], order[j] = order[j], order[i]
	end
	for i, d in list do
		local len, wid = d[1] * s, d[2] * s
		local lean, ang = math.rad(d[3]), d[5]
		local out = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local axis = (out * math.sin(lean) + Vector3.yAxis * math.cos(lean)).Unit
		local side = axis:Cross(out).Unit
		-- sink the base a little into the mound/floor
		local basePos = out * d[4] * s - axis * (0.12 * len)
		local c = role(ctx.pal, if d[6] == 2 then (sp.altRole or sp.role) else sp.role)
		local core, coreMesh = meshLayer("Spike", m, texId, frame, ctx.root, neon)
		core.Color = c
		coreMesh.VertexColor = v3(c, sp.gain or 1)
		local t0 = (sp.t or 0) + (order[i] - 1) * (sp.stagger or 0.033)
		local isMain = i <= nMain
		local shattered = false
		table.insert(ctx.steps, function(t: number)
			local lt = t - t0
			if lt < 0 then
				core.Transparency = 1
				return
			end
			-- grow with a small overshoot (back ease), hold, then collapse while it shatters
			local x = lt / sp.grow
			local k = if x < 1 then 1 + 2.2 * (x - 1) ^ 3 + 1.2 * (x - 1) ^ 2 else 1
			local sx = clamp01((lt - sp.grow - sp.hold) / sp.shatter)
			if sx > 0 and not shattered then
				shattered = true
				if shardEmitter and isMain then
					shardAtt.WorldCFrame = frame * aim(basePos + axis * len * 0.5, (axis + out).Unit)
					shardEmitter:Emit(sh.per or 3)
				end
			end
			local L = math.max(len * k * (1 - 0.6 * sx), 0.05)
			local W = math.max(wid * (1 - sx), 0.05)
			coreMesh.Scale = Vector3.new(W, L, W)
			core.CFrame = frame * CFrame.fromMatrix(basePos + axis * (L * 0.5), side, axis)
			core.Transparency = if sx >= 1 then 1 else 0.02 + 0.98 * easeIn(sx, 1.5)
		end)
	end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Lightning bolts (LightningExplosion `bolts` layer, LightningBallCast). !! UNTESTED IN STUDIO !!
-- A bolt is a jagged polyline drawn with stretched Neon parts: white core, cyan halo, violet edge
-- (roles core / halo / edge). It re-jitters every `flicker` seconds (a re-strike) so it crackles.
-- Layer fields: kind "radial" (strikes along the ground) | "column" (upward) | "arcs" (short static),
-- count, segs, jitter, branches, branchLen, width, glow (edge width / core width), t, stagger,
-- grow (strike-out time), hold, fade, flicker, length / height / spread / radius / up / over / life.
-------------------------------------------------------------------------------
type BoltSeg = { core: Part, halo: Part, edge: Part }
type BoltLine = { segs: { BoltSeg }, pts: { Vector3 }, shown: boolean }

local function boltPoints(a: Vector3, b: Vector3, n: number, jitter: number, flat: boolean): { Vector3 }
	local d = b - a
	local len = d.Magnitude
	local dir = if len > 1e-4 then d / len else Vector3.yAxis
	local ref = if math.abs(dir.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	local s1 = dir:Cross(ref).Unit
	local s2 = dir:Cross(s1).Unit
	local pts = { a }
	for i = 1, n - 1 do
		local u = i / n
		local amp = jitter * len / n * (0.5 + 0.7 * math.sin(math.pi * u))
		local o = s1 * (math.random() * 2 - 1) * amp + s2 * (math.random() * 2 - 1) * amp * (if flat then 0.3 else 1)
		table.insert(pts, a + d * (u + (math.random() - 0.5) * 0.4 / n) + o)
	end
	table.insert(pts, b)
	return pts
end

local function boltPart(name: string, color: Color3, parent: Instance): Part
	local p = newPart(name, CFrame.identity, parent)
	p.Material = Enum.Material.Neon
	p.Color = color
	return p
end

local function newBoltLine(n: number, pal: Palette, roles: any, parent: Instance): BoltLine
	local segs: { BoltSeg } = {}
	for _ = 1, n do
		table.insert(segs, {
			core = boltPart("BoltCore", role(pal, roles.core or "hot"), parent),
			halo = boltPart("BoltHalo", role(pal, roles.halo or "main"), parent),
			edge = boltPart("BoltEdge", role(pal, roles.edge or "glow"), parent),
		})
	end
	return { segs = segs, pts = {}, shown = true }
end

local function hideBoltLine(line: BoltLine)
	if not line.shown then
		return
	end
	line.shown = false
	for _, sg in line.segs do
		sg.core.Transparency, sg.halo.Transparency, sg.edge.Transparency = 1, 1, 1
	end
end

-- draw the first `shown` (fractional) segments; the width tapers toward the far end
local function drawBoltLine(line: BoltLine, shown: number, w: number, glow: number, alpha: number)
	if alpha <= 0.01 or shown <= 0 then
		hideBoltLine(line)
		return
	end
	line.shown = true
	local pts = line.pts
	local n = #line.segs
	for i, sg in line.segs do
		local a, b = pts[i], pts[i + 1]
		local k = math.clamp(shown - (i - 1), 0, 1)
		if a and b and k > 0 then
			b = a:Lerp(b, k)
			local len = (b - a).Magnitude
			local cf = if len > 1e-3 then CFrame.lookAt((a + b) / 2, b) else CFrame.new(a)
			local ww = w * (1 - 0.55 * (i - 1) / math.max(n, 1))
			sg.core.Size = Vector3.new(ww, ww, len + ww)
			sg.core.CFrame = cf
			sg.core.Transparency = 1 - alpha
			local hw = ww * 2.2
			sg.halo.Size = Vector3.new(hw, hw, len + hw)
			sg.halo.CFrame = cf
			sg.halo.Transparency = 1 - alpha * 0.45
			local ew = ww * glow
			sg.edge.Size = Vector3.new(ew, ew, len + ew)
			sg.edge.CFrame = cf
			sg.edge.Transparency = 1 - alpha * 0.16
		else
			sg.core.Transparency, sg.halo.Transparency, sg.edge.Transparency = 1, 1, 1
		end
	end
end

local function buildBolts(bo: any, ctx: BuildCtx)
	if bo.deco and not ctx.deco then
		return
	end
	local s = ctx.scale
	local frame = frameOf(bo.space, ctx) * CFrame.new(vec(bo.at, s))
	local function rnd(r: any, d: number): number
		if type(r) ~= "table" then
			return r or d
		end
		return r[1] + (r[2] - r[1]) * math.random()
	end
	local kind = bo.kind or "radial"
	local flat = kind == "radial"
	local segsN = bo.segs or 6
	local jitter = bo.jitter or 0.8
	local nBr = if ctx.deco then (bo.branches or 0) else 0
	local brSegs = math.max(2, math.ceil(segsN / 2))
	local grow = bo.grow or 0
	local hold = bo.hold or bo.life or 0.1
	local fade = bo.fade or 0
	local flicker = bo.flicker or 0.05
	local w = (bo.width or 0.3) * s
	local glow = bo.glow or 4
	local roles = { core = bo.core, halo = bo.halo, edge = bo.edge }
	local folder = Instance.new("Folder")
	folder.Name = "Bolts"
	folder.Parent = ctx.root
	local list = {}
	local n = count(bo.count or 1, ctx)
	for i = 1, n do
		local a: Vector3, b: Vector3, t0: number
		if kind == "radial" then
			local ang = (i - 1) / n * 2 * math.pi + (math.random() - 0.5) * (2 * math.pi / n) * 0.7
			local L = rnd(bo.length, 6) * s
			a = frame.Position
			b = frame:PointToWorldSpace(Vector3.new(math.cos(ang) * L, 0, math.sin(ang) * L))
			t0 = (bo.t or 0) + (bo.stagger or 0) * (i - 1)
		elseif kind == "column" then
			local sp = (bo.spread or 0.4) * s
			local o = Vector3.new((math.random() * 2 - 1) * sp, 0, (math.random() * 2 - 1) * sp)
			a = frame:PointToWorldSpace(o)
			b = frame:PointToWorldSpace(o * 0.3 + Vector3.new(0, (bo.height or 10) * s * (0.8 + 0.2 * math.random()), 0))
			t0 = (bo.t or 0) + (bo.stagger or 0) * (i - 1)
		else
			local ang = math.random() * 2 * math.pi
			local r = rnd(bo.radius, 3) * s
			a = frame:PointToWorldSpace(Vector3.new(math.cos(ang) * r, math.random() * (bo.up or 1) * s, math.sin(ang) * r))
			b = a + randomUnit() * rnd(bo.length, 2) * s
			t0 = (bo.t or 0) + (bo.over or 0) * math.random()
		end
		local brs = {}
		for _ = 1, nBr do
			table.insert(brs, { line = newBoltLine(brSegs, ctx.pal, roles, folder), k = math.random(2, math.max(2, segsN - 2)) })
		end
		table.insert(list, { a = a, b = b, t0 = t0, main = newBoltLine(segsN, ctx.pal, roles, folder), brs = brs, nextJit = -1 })
	end
	local function rejitter(B: any)
		B.main.pts = boltPoints(B.a, B.b, segsN, jitter, flat)
		local d = B.b - B.a
		for _, br in B.brs do
			local p = B.main.pts[br.k + 1] or B.a
			local dir: Vector3
			if flat then
				local ang = math.rad((25 + 25 * math.random()) * (if math.random() < 0.5 then -1 else 1))
				dir = CFrame.Angles(0, ang, 0):VectorToWorldSpace(d.Unit)
			else
				dir = randomCone(d.Unit, 50)
			end
			br.line.pts = boltPoints(p, p + dir * d.Magnitude * (bo.branchLen or 0.4), brSegs, jitter, flat)
		end
	end
	table.insert(ctx.steps, function(t: number)
		for _, B in list do
			local lt = t - B.t0
			if lt < 0 or lt > grow + hold + fade then
				hideBoltLine(B.main)
				for _, br in B.brs do
					hideBoltLine(br.line)
				end
			else
				if lt >= B.nextJit then
					rejitter(B)
					B.nextJit = lt + flicker
				end
				local shown = if grow > 0 then segsN * clamp01(lt / grow) else segsN
				local k = if lt > grow + hold then 1 - clamp01((lt - grow - hold) / math.max(fade, 1e-3)) else 1
				local alpha = k * (0.65 + 0.35 * math.random())
				drawBoltLine(B.main, shown, w, glow, alpha)
				for _, br in B.brs do
					drawBoltLine(br.line, (shown - br.k) * 2, w * 0.6, glow, alpha * 0.85)
				end
			end
		end
	end)
end

export type PlayOptions = {
	element: string?,
	palette: Palette?,
	flip: boolean?,
	tilt: number?,
	yaw: number?,
	scale: number?,
	important: boolean?, -- own casts: ignore maxActive and keep decoration at distance
	skipUnits: boolean?, -- play only the generic layers (e.g. a slam using OverheadCleave's ground crack)
	follow: BasePart?, -- DashTrail: the streak head follows this part (else the predicted dash path)
	character: Model?, -- DashTrail: afterimages are copied from this character
	distance: number?, -- DashTrail: dash length in studs (default preset.dash.distance)
	speed: number?, -- timeline rate (1 = authored; ChargeUp bindings retime to the clip)
	arc: { number }?, -- { startDeg, endDeg } from the LookVector (+ = right / weapon side): where the slash
	--                   sits and which way it sweeps; clamped so the arc stays within +-100 deg of forward
	size: number?, -- alias of scale
}

--[[ Play a preset. `cf` is the swing frame: its position is the swing centre (e.g. the root part),
	its XZ plane is the swing plane and -Z is forward. Returns a stop function. ]]
function LihFolkVFX.play(presetName: string, cf: CFrame, options: PlayOptions?): () -> ()
	local opts: PlayOptions = options or {}
	local preset = (LihFolkVFX.Presets :: any)[presetName] :: Preset?
	if not preset then
		warnOnce("preset:" .. presetName, "unknown preset " .. presetName)
		return function() end
	end
	local cfg = LihFolkVFX.Config
	local important = opts.important == true
	if not important and #active >= cfg.maxActive then
		return function() end
	end
	local detail = cfg.quality
	local deco = detail >= 0.55
	local cam = Workspace.CurrentCamera
	if cam and not important then
		local dist = (cam.CFrame.Position - cf.Position).Magnitude
		if dist > cfg.cullDistance then
			return function() end
		elseif dist > cfg.lowDetailDistance then
			detail *= 0.5
			deco = false
		end
	end
	if liveParticles > cfg.maxLiveParticles * 0.75 then
		detail *= 0.5
		deco = false
	end
	local pal = opts.palette or (LihFolkVFX.Elements :: any)[opts.element or preset.element or "teal"] :: Palette?
	if not pal then
		pal = (LihFolkVFX.Elements :: any).teal
	end
	local base = cf
	if opts.flip then
		base = base * CFrame.Angles(0, 0, math.pi)
	end
	if opts.tilt then
		base = base * CFrame.Angles(0, 0, math.rad(opts.tilt))
	end
	if opts.yaw then
		base = base * CFrame.Angles(0, math.rad(opts.yaw), 0)
	end
	local scale = opts.scale or opts.size or 1
	-- arc range: centre and direction of the sweep (its length is the mesh's: 200 deg thick, 160 deg thin)
	local arcShift = 0
	if opts.arc and #opts.arc >= 2 then
		local a0 = math.clamp(opts.arc[1], -FRONT_LIMIT, FRONT_LIMIT)
		local a1 = math.clamp(opts.arc[2], -FRONT_LIMIT, FRONT_LIMIT)
		arcShift = -(a0 + a1) / 2
		if a1 > a0 then -- left -> right: mirror the sweep
			base = base * CFrame.Angles(0, 0, math.pi)
			arcShift = -arcShift
		end
	end
	local speed = math.max(opts.speed or 1, 0.05)

	-- floor frame: flat, below the cf, facing the caster's heading
	local g = preset.ground
	local drop = preset.floor or (g and g.drop) or 3
	local gPos = cf.Position - Vector3.new(0, drop * scale, 0)
	local flat = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local groundCf = CFrame.lookAt(gPos, gPos + flat.Unit)

	-- dash head in body space (predicted ease-out path, or the followed part)
	local dash = preset.dash
	local dashDist = (opts.distance or (dash and dash.distance) or 0) * scale
	local follow = opts.follow
	local function pathHead(t: number): Vector3
		if follow and follow.Parent then
			local p = cf:PointToObjectSpace(follow.Position)
			return Vector3.new(p.X, 0, p.Z)
		end
		if not dash then
			return Vector3.zero
		end
		return Vector3.new(0, 0, -dashDist * easeOut(t / dash.duration, dash.pow))
	end

	local root = Instance.new("Model")
	root.Name = presetName
	local anchor = newPart("Anchor", base, root)
	local ctx: BuildCtx = {
		root = root,
		base = base,
		body = cf,
		ground = groundCf,
		anchor = anchor,
		pal = pal :: Palette,
		scale = scale,
		detail = detail,
		deco = deco,
		steps = {},
		particles = 0,
		pathHead = pathHead,
		character = opts.character,
		arcShift = arcShift,
	}

	-- hot flash (at the contact point, or wherever the preset puts it)
	local f = preset.flash
	if f then
		buildBurst({
			tex = "flash_hot",
			role = "hot",
			count = 1,
			t = f.t or 0,
			at = f.at or { 0, 0, -(f.forward or 0) },
			space = if f.at then f.space else "swing",
			size = { { 0, 0 }, { 0.3, f.size }, { 1, f.size * 0.4 } },
			transp = { { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } },
			life = { f.life, f.life },
			le = 1,
			bright = f.brightness,
			rot = { 0, 90 },
			zoff = 4,
		}, ctx)
	end

	if preset.units and not opts.skipUnits then
		for _, u in preset.units do
			buildUnit(u, ctx)
		end
	end
	for _, b in preset.beams or {} do
		buildBeam(b, ctx)
	end
	for _, r in preset.rings or {} do
		buildRing(r, ctx)
	end
	for _, b in preset.bursts or {} do
		buildBurst(b, ctx)
	end
	if preset.ghosts then
		buildGhosts(preset.ghosts, ctx)
	end
	if preset.spikes then
		buildSpikes(preset.spikes, ctx)
	end
	for _, bo in preset.bolts or {} do
		buildBolts(bo, ctx)
	end

	-- ground ring + disc (world up, below the swing centre)
	if g and ctx.deco then
		local gMesh = meshId("ground_ring")
		local gTex = tex("strip_ground_ring")
		if gMesh and gTex and g.ring ~= false then
			local part, mesh = meshLayer("Ground", gMesh, gTex, groundCf * CFrame.new(0, 0, -(g.forward or 0) * scale), root, true)
			part.Color = ctx.pal.glow
			mesh.VertexColor = v3(ctx.pal.glow, 1)
			table.insert(ctx.steps, function(t: number)
				local x = clamp01(t / g.life)
				local s = g.radius * scale * (0.45 + 0.8 * easeOut(x, 3))
				mesh.Scale = Vector3.new(s, s, s)
				part.Transparency = g.transparency + (1 - g.transparency) * easeIn(x, 1.4)
			end)
		end
		buildBurst({
			tex = "ground_disc_faint",
			role = g.discRole or "glow",
			le = g.discLe or 1,
			bright = g.discBright or 0.6,
			count = 1,
			at = { 0, 0.05, -(g.forward or 0) },
			space = "ground",
			orient = "flat",
			size = { { 0, g.radius * 1.6 }, { 1, g.radius * 2.6 } },
			transp = { { 0, if g.discRole then g.transparency else 0.7 }, { 1, 1 } },
			life = { g.life * 1.2, g.life * 1.2 },
			zoff = -1,
		}, ctx)
	end

	-- short light in the glow colour (no shadows); `rise` = fraction of life spent rising (charges)
	local L = preset.light
	local lightPart = anchor
	if L.at then
		lightPart = newPart("Light", frameOf(L.space, ctx) * CFrame.new(vec(L.at, scale)), root)
	end
	local light = Instance.new("PointLight")
	light.Color = ctx.pal.glow
	light.Range = L.range * scale
	light.Shadows = false
	light.Brightness = 0
	light.Parent = lightPart
	local rise = L.rise or 0.1
	local lt0 = L.t or 0
	table.insert(ctx.steps, function(t: number)
		local x = (t - lt0) / L.life
		if x < 0 then
			light.Brightness = 0
		elseif x < rise then
			light.Brightness = L.brightness * x / rise
		else
			light.Brightness = L.brightness * math.max(0, 1 - easeOut((x - rise) / (1 - rise), 2))
		end
	end)

	-- sound with its peak on the hit
	local snd = (LihFolkVFX.Sounds :: any)[preset.sound]
	if snd and snd.id ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = snd.id
		s.Volume = snd.volume
		-- the marker IS the hit, so skip into the sound until its crack lands now
		s.TimePosition = snd.peak
		s.PlaybackSpeed = speed
		s.Parent = anchor
		s:Play()
	end

	root.Parent = getContainer()
	liveParticles += ctx.particles
	local effect: Effect = {
		t0 = os.clock(),
		life = preset.life / speed,
		steps = ctx.steps,
		root = root,
		particles = ctx.particles,
		stopped = false,
		finished = false,
		speed = speed,
	}
	start(effect)
	return function()
		effect.stopped = true
	end
end

-- Impact burst on a target: position = contact point, direction = attacker -> target.
function LihFolkVFX.hitSpark(position: Vector3, direction: Vector3, options: PlayOptions?): () -> ()
	local d = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.new(0, 0, -1)
	return LihFolkVFX.play("HitSpark", aim(position, d), options)
end

--[[ Preload every texture and mesh id a preset uses (call when the weapon is equipped, not on first swing).
	Fresh uploads can fail PreloadAsync for about a minute; that is normal. ]]
function LihFolkVFX.preload()
	local ids: { string } = {}
	for _, id in LihFolkVFX.Textures :: any do
		if type(id) == "string" and id ~= "" then
			table.insert(ids, id)
		end
	end
	for _, id in LihFolkVFX.Meshes :: any do
		if type(id) == "string" and id ~= "" then
			table.insert(ids, id)
		end
	end
	if #ids > 0 then
		task.spawn(function()
			local ok, err = pcall(function()
				ContentProvider:PreloadAsync(ids)
			end)
			if not ok then
				warn("[LihFolkVFX] preload failed: " .. tostring(err))
			end
		end)
	end
end

function LihFolkVFX.setQuality(q: number)
	LihFolkVFX.Config.quality = math.clamp(q, 0.25, 1)
end

-- Stop and remove every live effect (scene change, death, teleport).
function LihFolkVFX.clear()
	for _, e in active do
		finish(e)
	end
	table.clear(active)
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

-------------------------------------------------------------------------------
-- Weapon trail (TrailOn / TrailOff window)
-------------------------------------------------------------------------------
--[[ Creates a disabled Trail on the blade between two points (blade-local offsets).
	Use it for cuts and stabs only: across a spin (> ~120 deg) a Trail draws a solid wedge. ]]
function LihFolkVFX.attachTrail(blade: BasePart, baseOffset: Vector3, tipOffset: Vector3, element: string?): Trail
	local pal = (LihFolkVFX.Elements :: any)[element or "teal"] :: Palette
	local a0 = Instance.new("Attachment")
	a0.Name = "LihFolkTrail0"
	a0.Position = baseOffset
	a0.Parent = blade
	local a1 = Instance.new("Attachment")
	a1.Name = "LihFolkTrail1"
	a1.Position = tipOffset
	a1.Parent = blade
	local tr = Instance.new("Trail")
	tr.Name = "LihFolkTrail"
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Enabled = false
	tr.Lifetime = 0.16
	tr.MinLength = 0.05
	tr.FaceCamera = false
	tr.LightEmission = 1
	tr.LightInfluence = 0
	tr.Brightness = 3
	tr.Color = ColorSequence.new(pal.hot, pal.glow)
	tr.Transparency = ns({ { 0, 0.1 }, { 0.5, 0.5 }, { 1, 1 } })
	tr.WidthScale = ns({ { 0, 1 }, { 1, 0.15 } })
	tr.Texture = LihFolkVFX.Textures.trail_soft
	tr.TextureMode = Enum.TextureMode.Stretch
	tr.Parent = blade
	return tr
end

-------------------------------------------------------------------------------
-- Animation marker binding
--   Hit (value -> DefaultHits), DashStart / Impact / Deflect (DefaultMarkers), TrailOn / TrailOff,
--   charge on track start (DefaultCharges, retimed so its release lands on Hit)
-------------------------------------------------------------------------------
export type Binding = {
	hits: { [string]: HitSpec }?, -- marker value -> spec; defaults to LihFolkVFX.DefaultHits
	markers: { [string]: HitSpec }?, -- marker name -> spec; defaults to LihFolkVFX.DefaultMarkers
	charges: { [string]: { preset: string, lead: number } }?, -- Animation.Name -> charge; defaults to DefaultCharges
	element: string?, -- default element (else the character's "VFXElement" attribute)
	trail: Trail?, -- weapon trail toggled by TrailOn / TrailOff
	important: boolean?, -- true for the local player's own character
}

local function rootOf(character: Model): BasePart?
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return character.PrimaryPart
end

local function elementOf(spec: HitSpec, b: Binding, character: Model): string?
	local element = spec.element or b.element or character:GetAttribute("VFXElement")
	return if type(element) == "string" then element else nil
end

--[[ Listen to one AnimationTrack's markers. Returns a disconnect function. ]]
function LihFolkVFX.bindTrack(track: AnimationTrack, character: Model, binding: Binding?): () -> ()
	local b: Binding = binding or {}
	local anim = track.Animation
	-- upper-body copies carry the same markers; only the full clip fires effects
	if anim and anim:GetAttribute("KitUpper") then
		return function() end
	end
	local conns: { RBXScriptConnection } = {}
	local hits = b.hits or LihFolkVFX.DefaultHits
	local markers = b.markers or LihFolkVFX.DefaultMarkers
	local trail = b.trail
	local animName = if anim then anim.Name else ""
	local noTrail = LihFolkVFX.NoTrailClips[animName] == true or (anim ~= nil and anim:GetAttribute("VFXNoTrail") == true)

	local function fire(spec: HitSpec, param: string?)
		if param and spec.byValue and spec.byValue[param] then
			spec = spec.byValue[param]
			param = nil
		elseif param and param ~= "" and (LihFolkVFX.Presets :: any)[param] then
			spec = { preset = param, offset = spec.offset }
			param = nil
		end
		local root = rootOf(character)
		if not root then
			return
		end
		local preset = (LihFolkVFX.Presets :: any)[spec.preset] :: Preset?
		if trail and preset and preset.trail == false then
			trail.Enabled = false
			trail:Clear()
		end
		LihFolkVFX.play(spec.preset, root.CFrame * (spec.offset or CFrame.identity), {
			element = elementOf(spec, b, character),
			flip = spec.flip,
			tilt = spec.tilt,
			yaw = spec.yaw,
			scale = spec.scale,
			skipUnits = spec.skipUnits,
			important = b.important,
			follow = if spec.follow then root else nil,
			character = character,
			distance = tonumber(param or ""),
		})
	end

	-- charge: starts with the clip, retimed so its release lands on the Hit marker
	local chargeStop: (() -> ())? = nil
	local charges = b.charges or LihFolkVFX.DefaultCharges
	local charge = charges[animName]
	local attr = if anim then anim:GetAttribute("VFXCharge") else nil
	if not charge and type(attr) == "string" then
		charge = { preset = attr, lead = 0.75 }
	end
	if charge then
		local root = rootOf(character)
		local preset = (LihFolkVFX.Presets :: any)[charge.preset] :: Preset?
		if root and preset then
			local lead = math.max(charge.lead / math.max(track.Speed, 0.05), 0.1)
			chargeStop = LihFolkVFX.play(charge.preset, root.CFrame, {
				element = elementOf({ preset = charge.preset }, b, character),
				important = b.important,
				speed = (preset.lead or lead) / lead,
			})
		end
	end

	table.insert(conns, track:GetMarkerReachedSignal("Hit"):Connect(function(param: string?)
		chargeStop = nil -- the charge has released; let it finish on its own
		local spec = hits[param or ""] or hits["1"]
		if spec then
			fire(spec, nil)
		end
	end))
	for name, spec in markers do
		table.insert(conns, track:GetMarkerReachedSignal(name):Connect(function(param: string?)
			fire(spec, param)
		end))
	end
	if trail then
		table.insert(conns, track:GetMarkerReachedSignal("TrailOn"):Connect(function()
			if noTrail then
				return
			end
			trail:Clear() -- otherwise it connects from where the blade was last time
			trail.Enabled = true
		end))
		table.insert(conns, track:GetMarkerReachedSignal("TrailOff"):Connect(function()
			trail.Enabled = false
		end))
	end
	table.insert(conns, track.Stopped:Connect(function()
		if trail then
			trail.Enabled = false
		end
		if chargeStop then
			chargeStop() -- interrupted before the Hit
			chargeStop = nil
		end
	end))
	return function()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		if trail then
			trail.Enabled = false
		end
		if chargeStop then
			chargeStop()
			chargeStop = nil
		end
	end
end

--[[ Bind every track this Animator plays from now on. Returns a disconnect function. ]]
function LihFolkVFX.bindAnimator(animator: Animator, character: Model, binding: Binding?): () -> ()
	local unbinds: { [AnimationTrack]: () -> () } = {}
	local played = animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		if unbinds[track] then
			return
		end
		unbinds[track] = LihFolkVFX.bindTrack(track, character, binding)
		track.Ended:Once(function()
			local un = unbinds[track]
			if un then
				un()
				unbinds[track] = nil
			end
		end)
	end)
	local destroying = character.Destroying:Once(function()
		played:Disconnect()
		for _, un in unbinds do
			un()
		end
		table.clear(unbinds)
	end)
	return function()
		played:Disconnect()
		destroying:Disconnect()
		for _, un in unbinds do
			un()
		end
		table.clear(unbinds)
	end
end

-------------------------------------------------------------------------------
-- Sequences (multi-stage effects driven by clip markers)
-- !! UNTESTED IN STUDIO !! IceBallCast was authored against the Blender preview
-- (Previews/IceBall_Cast_to_Explosion.mp4) only. Verify welds, timings and the
-- landing raycast in Studio before shipping.
-------------------------------------------------------------------------------
export type SequenceSpec = {
	element: string,
	ballRadius: number, -- studs
	growTime: number, -- seed -> full size (s), slight overshoot
	flightTime: number, -- Release -> Impact (s)
	distance: number, -- studs ahead of the root part where the ball lands
	arcHeight: number, -- extra apex height of the flight arc (studs)
	impactPreset: string, -- played on the floor where the ball lands
}

LihFolkVFX.Sequences = {
	-- IceCastThrow clip: ChargeStart (f12) -> ball grows on RightGripAttachment; Release (f49) -> projectile;
	-- Impact (f64) -> IceExplosion where it lands. UNTESTED IN STUDIO.
	IceBallCast = {
		element = "ice",
		ballRadius = 0.72,
		growTime = 0.73,
		flightTime = 0.5,
		distance = 12,
		arcHeight = 1.3,
		impactPreset = "IceExplosion",
	} :: SequenceSpec,
} :: { [string]: SequenceSpec }

local function makeIceBall(pal: Palette, radius: number): (Part, PointLight)
	local ball = Instance.new("Part")
	ball.Name = "LihFolkIceBall"
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Glass
	ball.Color = pal.main
	ball.Transparency = 0.15
	ball.Reflectance = 0.25
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Massless = true
	ball.Size = Vector3.one * 0.05
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Material = Enum.Material.Neon
	core.Color = pal.dark:Lerp(pal.main, 0.35)
	core.CanCollide, core.CanQuery, core.CanTouch, core.CastShadow, core.Massless = false, false, false, false, true
	core.Size = Vector3.one * 0.03
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = ball, core
	core.CFrame = ball.CFrame
	w.Parent = core
	core.Parent = ball
	local light = Instance.new("PointLight")
	light.Color = pal.glow
	light.Range = 10
	light.Brightness = 0
	light.Parent = ball
	local glint = Instance.new("ParticleEmitter")
	glint.Name = "Glints"
	glint.Texture = LihFolkVFX.Textures.glint_star4 or ""
	glint.Color = ColorSequence.new(pal.hot)
	glint.LightEmission = 1
	glint.Size = ns({ { 0, 0 }, { 0.4, radius * 1.3 }, { 1, 0 } })
	glint.Lifetime = NumberRange.new(0.18, 0.28)
	glint.Rate = 10
	glint.Speed = NumberRange.new(0)
	glint.Shape = Enum.ParticleEmitterShape.Sphere
	glint.Parent = ball
	return ball, light
end

--[[ Play the IceBallCast sequence on a character whose track carries ChargeStart / Release / Impact markers.
	UNTESTED IN STUDIO. Returns a cleanup function. ]]
function LihFolkVFX.playIceBallCast(track: AnimationTrack, character: Model, spec: SequenceSpec?): () -> ()
	local s: SequenceSpec = spec or LihFolkVFX.Sequences.IceBallCast
	local pal = (LihFolkVFX.Elements :: any)[s.element] :: Palette
	local conns: { RBXScriptConnection } = {}
	local ball: Part? = nil
	local light: PointLight? = nil
	local charge: (() -> ())? = nil
	-- lihfolk-ignore: findfirstchild-chain (results are nil-checked before use)
	local hand = character:FindFirstChild("RightHand") :: BasePart?
	-- lihfolk-ignore: findfirstchild-chain (guarded by `hand and`)
	local grip = hand and hand:FindFirstChild("RightGripAttachment") :: Attachment?

	local function cleanup()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		if charge then
			charge()
			charge = nil
		end
		if ball then
			ball:Destroy()
			ball = nil
		end
	end

	table.insert(conns, track:GetMarkerReachedSignal("ChargeStart"):Connect(function()
		if not hand then
			return
		end
		local b, l = makeIceBall(pal, s.ballRadius)
		ball, light = b, l
		local up = s.ballRadius + 0.18
		b.CFrame = (if grip then grip.WorldCFrame else hand.CFrame) * CFrame.new(0, 0, 0) + Vector3.new(0, up, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Name = "HandWeld"
		weld.Part0, weld.Part1 = hand, b
		weld.Parent = b
		b.Parent = getContainer()
		-- converging frost motes + mist (ChargeUp preset recoloured ice, retimed to the grow)
		charge = LihFolkVFX.play("ChargeUp", b.CFrame, { element = s.element, speed = 1 })
		local t0 = os.clock()
		local c: RBXScriptConnection
		c = RunService.Heartbeat:Connect(function()
			if ball ~= b then
				c:Disconnect()
				return
			end
			local x = clamp01((os.clock() - t0) / s.growTime)
			local c1 = 1.70158
			local k = 1 + (c1 + 1) * (x - 1) ^ 3 + c1 * (x - 1) ^ 2 -- easeOutBack: slight overshoot
			local d = math.max(0.05, 2 * s.ballRadius * k)
			if weld.Parent then
				weld.Enabled = false
				b.Size = Vector3.one * d
				-- lihfolk-ignore: findfirstchild-chain (nil-checked on the next line)
				local core = b:FindFirstChild("Core") :: BasePart?
				if core then
					core.Size = Vector3.one * d * 0.55
					core.CFrame = b.CFrame
				end
				weld.Enabled = true
			end
			l.Brightness = 2 * x
			if x >= 1 then
				c:Disconnect()
			end
		end)
		table.insert(conns, c)
	end))

	table.insert(conns, track:GetMarkerReachedSignal("Release"):Connect(function()
		local b = ball
		local root = rootOf(character)
		if not b or not root then
			return
		end
		local weld = b:FindFirstChild("HandWeld")
		if weld then
			weld:Destroy()
		end
		b.Anchored = true
		local p0 = b.Position
		local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		local target = root.Position + (if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)) * s.distance
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { character, getContainer() }
		params.FilterType = Enum.RaycastFilterType.Exclude
		local hit = Workspace:Raycast(target + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
		local p1 = if hit then hit.Position else target - Vector3.new(0, 3, 0)
		local trail = LihFolkVFX.attachTrail(b, Vector3.new(0, -s.ballRadius * 0.8, 0), Vector3.new(0, s.ballRadius * 0.8, 0), s.element)
		trail.Enabled = true
		local t0 = os.clock()
		local c: RBXScriptConnection
		c = RunService.Heartbeat:Connect(function()
			if ball ~= b then
				c:Disconnect()
				return
			end
			local u = clamp01((os.clock() - t0) / s.flightTime)
			b.CFrame = CFrame.new(p0:Lerp(p1 + Vector3.new(0, s.ballRadius * 0.6, 0), u) + Vector3.new(0, 4 * s.arcHeight * u * (1 - u), 0))
				* CFrame.Angles(u * 9, u * 5, 0)
			if u >= 1 then
				c:Disconnect()
			end
		end)
		table.insert(conns, c)
		b:SetAttribute("LandAt", p1)
	end))

	table.insert(conns, track:GetMarkerReachedSignal("Impact"):Connect(function()
		local b = ball
		if not b then
			return
		end
		local p1 = b:GetAttribute("LandAt")
		local at = if typeof(p1) == "Vector3" then p1 else b.Position
		local root = rootOf(character)
		local look = if root then root.CFrame.LookVector * Vector3.new(1, 0, 1) else Vector3.new(0, 0, -1)
		if look.Magnitude < 1e-3 then
			look = Vector3.new(0, 0, -1)
		end
		-- IceExplosion cf = impact point at body height (its floor is 3 studs down)
		LihFolkVFX.play(s.impactPreset, CFrame.lookAt(at + Vector3.new(0, 3, 0), at + Vector3.new(0, 3, 0) + look.Unit), {
			element = s.element,
			important = true,
		})
		ball = nil
		b:Destroy()
	end))

	table.insert(conns, track.Stopped:Connect(function()
		task.delay(0.1, cleanup)
	end))
	return cleanup
end

-------------------------------------------------------------------------------
-- !! UNTESTED IN STUDIO !! LightningBallCast was authored against the Blender preview
-- (Previews/LightningBall_Cast_to_Explosion.mp4) only. Verify part counts, timings, the hand
-- midpoint tracking and the landing raycast in Studio before shipping.
-- Clip: LightningCastThrow (ChargeStart f12, Release f49, Impact f64); IceCastThrow also works
-- (same markers) but its single raised palm does not match the two-hand cup.
-------------------------------------------------------------------------------
export type LightningSequenceSpec = {
	element: string,
	ballRadius: number, -- studs
	growTime: number, -- seed -> full size (s), slight overshoot
	pullStart: number, -- s after ChargeStart: the ball leaves the cupped hands ...
	pullEnd: number, -- ... and sits in the right hand (wind-up)
	flightTime: number, -- Release -> Impact (s)
	distance: number, -- studs ahead of the root part where the ball lands
	arcHeight: number,
	impactDelay: number, -- the explosion starts this long after contact (1 frame: keep the landing readable)
	impactPreset: string,
	inArcRate: number, -- arcs per second jumping from the air / ground INTO the hands
	surfaceArcs: number, -- arcs crawling over the ball surface
}

(LihFolkVFX.Sequences :: any).LightningBallCast = {
	element = "plasma",
	ballRadius = 0.55,
	growTime = 0.73,
	pullStart = 0.933,
	pullEnd = 1.067,
	flightTime = 0.5,
	distance = 12,
	arcHeight = 1.3,
	impactDelay = 1 / 30,
	impactPreset = "LightningExplosion",
	inArcRate = 22,
	surfaceArcs = 3,
} :: LightningSequenceSpec

local function makePlasmaBall(pal: Palette, parent: Instance): (Part, Part, PointLight)
	local core = newPart("LihFolkPlasmaBall", CFrame.identity, parent)
	core.Shape = Enum.PartType.Ball
	core.Material = Enum.Material.Neon
	core.Color = pal.hot
	core.Transparency = 0
	core.Size = Vector3.one * 0.05
	local shell = newPart("Halo", CFrame.identity, core)
	shell.Shape = Enum.PartType.Ball
	shell.Material = Enum.Material.ForceField -- electric cyan film, violet tint at the rim via the palette glow
	shell.Color = pal.main
	shell.Transparency = 0
	shell.Size = Vector3.one * 0.08
	local light = Instance.new("PointLight")
	light.Color = pal.main
	light.Range = 12
	light.Brightness = 0
	light.Shadows = false
	light.Parent = core
	local sp = Instance.new("ParticleEmitter")
	sp.Name = "Sparks"
	sp.Texture = LihFolkVFX.Textures.spark_square or ""
	sp.Color = ColorSequence.new(pal.hot, pal.main)
	sp.LightEmission = 1
	sp.LightInfluence = 0
	sp.Size = ns({ { 0, 0 }, { 0.15, 0.22 }, { 0.4, 0.06 }, { 0.6, 0.18 }, { 1, 0 } })
	sp.Lifetime = NumberRange.new(0.2, 0.4)
	sp.Speed = NumberRange.new(3, 7)
	sp.Drag = 3
	sp.Rate = 30
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.Parent = core
	return core, shell, light
end

--[[ Play the LightningBallCast sequence on a character whose track carries ChargeStart / Release / Impact.
	UNTESTED IN STUDIO. Returns a cleanup function. ]]
function LihFolkVFX.playLightningBallCast(track: AnimationTrack, character: Model, spec: LightningSequenceSpec?): () -> ()
	local s: LightningSequenceSpec = spec or (LihFolkVFX.Sequences :: any).LightningBallCast
	local pal = (LihFolkVFX.Elements :: any)[s.element] :: Palette
	local conns: { RBXScriptConnection } = {}
	local folder: Folder? = nil
	local ball: Part? = nil
	local charge: (() -> ())? = nil
	local phase = "none" -- "charge" | "flight" | "done"
	-- lihfolk-ignore: findfirstchild-chain (results are nil-checked before use)
	local rh = character:FindFirstChild("RightHand") :: BasePart?
	-- lihfolk-ignore: findfirstchild-chain (results are nil-checked before use)
	local lh = character:FindFirstChild("LeftHand") :: BasePart?
	-- lihfolk-ignore: findfirstchild-chain (guarded by `rh and`)
	local grip = rh and rh:FindFirstChild("RightGripAttachment") :: Attachment?

	local function cleanup()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		if charge then
			charge()
			charge = nil
		end
		if folder then
			folder:Destroy()
			folder = nil
		end
		ball = nil
	end

	table.insert(conns, track:GetMarkerReachedSignal("ChargeStart"):Connect(function()
		if not rh then
			return
		end
		local hand: BasePart = rh
		local f = Instance.new("Folder")
		f.Name = "LihFolkLightningBall"
		f.Parent = getContainer()
		folder = f
		local b, shell, light = makePlasmaBall(pal, f)
		ball = b
		phase = "charge"
		local roles = { core = "hot", halo = "main", edge = "glow" }
		local inArcs: { BoltLine } = {}
		local inLife: { number } = {}
		for i = 1, 4 do
			inArcs[i] = newBoltLine(6, pal, roles, f)
			inLife[i] = -1
		end
		local surf: { BoltLine } = {}
		for i = 1, s.surfaceArcs do
			surf[i] = newBoltLine(3, pal, roles, f)
		end
		local trail: { BoltLine } = { newBoltLine(6, pal, roles, f), newBoltLine(4, pal, roles, f) }
		local hist: { Vector3 } = {}
		local t0 = os.clock()
		local lastJit, lastArc, lastGhost = -1, 0, 0
		local p0, p1, tRel = Vector3.zero, Vector3.zero, 0
		charge = LihFolkVFX.play("ChargeUp", b.CFrame, { element = s.element, important = true })

		local function handPos(t: number): Vector3
			local right = (if grip then grip.WorldPosition else hand.Position) + Vector3.new(0, s.ballRadius + 0.18, 0)
			if not lh then
				return right
			end
			local mid = (hand.Position + lh.Position) / 2
			local k = clamp01((t - s.pullStart) / (s.pullEnd - s.pullStart))
			k = k * k * (3 - 2 * k)
			return mid:Lerp(right, k)
		end

		local c: RBXScriptConnection
		c = RunService.Heartbeat:Connect(function()
			if ball ~= b or not b.Parent then
				c:Disconnect()
				return
			end
			local now = os.clock()
			local t = now - t0
			local x = clamp01(t / s.growTime)
			local c1 = 1.70158
			local grow = 1 + (c1 + 1) * (x - 1) ^ 3 + c1 * (x - 1) ^ 2 -- easeOutBack
			local r = math.max(0.03, s.ballRadius * grow)
			local pos: Vector3
			if phase == "charge" then
				pos = handPos(t)
			elseif phase == "flight" then
				local u = clamp01((now - tRel) / s.flightTime)
				pos = p0:Lerp(p1 + Vector3.new(0, s.ballRadius, 0), u) + Vector3.new(0, 4 * s.arcHeight * u * (1 - u), 0)
			else
				pos = b.Position
			end
			b.CFrame = CFrame.new(pos)
			-- flicker every 1-2 frames: core size, halo opacity, light
			local jit = now - lastJit >= (if math.random() < 0.5 then 1 / 30 else 1 / 15)
			if jit then
				lastJit = now
				local fl = 0.9 + 0.2 * math.random()
				b.Size = Vector3.one * 2 * r * 0.62 * fl
				shell.Size = Vector3.one * 2 * r * (1.05 + 0.1 * math.random())
				shell.Transparency = 0.15 + 0.35 * math.random()
				light.Brightness = (2 + 2 * math.random()) * x
				-- arcs crawling over the surface
				for _, ln in surf do
					local d1 = randomUnit()
					local d2 = randomCone(d1, 70)
					ln.pts = boltPoints(pos + d1 * r * 1.05, pos + d2 * r * 1.1, 3, 1.4, false)
					drawBoltLine(ln, 3, 0.06, 3, 0.9)
				end
			end
			if phase == "charge" then
				-- arcs jumping from the air / ground INTO the hands (each lives ~2 frames)
				if t - lastArc >= 1 / s.inArcRate and x < 1.4 then
					lastArc = t
					for i, ln in inArcs do
						if t - inLife[i] > 0.066 then
							local from = if math.random() < 0.3
								then Vector3.new(pos.X, pos.Y - 2.6, pos.Z) + Vector3.new(math.random() * 4 - 2, 0, math.random() * 4 - 2)
								else pos + randomUnit() * (2.4 + 2 * math.random())
							ln.pts = boltPoints(from, pos, 6, 1.0, false)
							inLife[i] = t
							break
						end
					end
				end
				for i, ln in inArcs do
					local age = t - inLife[i]
					if age >= 0 and age <= 0.066 then
						drawBoltLine(ln, 6, 0.09, 3.5, 1 - age / 0.1)
					else
						hideBoltLine(ln)
					end
				end
			else
				for _, ln in inArcs do
					hideBoltLine(ln)
				end
			end
			if phase == "flight" then
				-- forked lightning trail along the recent path + afterimages
				table.insert(hist, 1, pos)
				if #hist > 8 then
					table.remove(hist)
				end
				if jit and #hist >= 3 then
					local tail = hist[#hist]
					trail[1].pts = boltPoints(pos, tail, 6, 0.9, false)
					local mid = trail[1].pts[3]
					trail[2].pts = boltPoints(mid, mid + randomCone((tail - pos).Unit, 40) * (tail - pos).Magnitude * 0.5, 4, 1.0, false)
				end
				drawBoltLine(trail[1], 6, 0.16, 3.5, 0.9)
				drawBoltLine(trail[2], 4, 0.1, 3.5, 0.7)
				if now - lastGhost >= 1 / 30 then
					lastGhost = now
					local g = shell:Clone()
					g:ClearAllChildren()
					g.CFrame = CFrame.new(pos)
					g.Material = Enum.Material.Neon
					g.Color = pal.glow
					g.Transparency = 0.55
					g.Parent = f
					local g0 = now
					local gc: RBXScriptConnection
					gc = RunService.Heartbeat:Connect(function()
						local a = (os.clock() - g0) / 0.15
						if a >= 1 or not g.Parent then
							gc:Disconnect()
							g:Destroy()
							return
						end
						g.Transparency = 0.55 + 0.45 * a
						g.Size = shell.Size * (1 - 0.4 * a)
					end)
				end
			else
				hideBoltLine(trail[1])
				hideBoltLine(trail[2])
			end
		end)
		table.insert(conns, c)

		table.insert(conns, track:GetMarkerReachedSignal("Release"):Connect(function()
			local root = rootOf(character)
			if ball ~= b or not root then
				return
			end
			p0 = b.Position
			local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			local target = root.Position + (if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)) * s.distance
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { character, getContainer() }
			params.FilterType = Enum.RaycastFilterType.Exclude
			local hit = Workspace:Raycast(target + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
			p1 = if hit then hit.Position else target - Vector3.new(0, 3, 0)
			tRel = os.clock()
			phase = "flight"
			if charge then
				charge()
				charge = nil
			end
		end))

		table.insert(conns, track:GetMarkerReachedSignal("Impact"):Connect(function()
			if ball ~= b then
				return
			end
			phase = "done"
			local at = p1
			local root = rootOf(character)
			local look = if root then root.CFrame.LookVector * Vector3.new(1, 0, 1) else Vector3.new(0, 0, -1)
			if look.Magnitude < 1e-3 then
				look = Vector3.new(0, 0, -1)
			end
			-- ball stays visible on the contact frame; the explosion starts 1 frame later
			task.delay(s.impactDelay, function()
				LihFolkVFX.play(s.impactPreset, CFrame.lookAt(at + Vector3.new(0, 3, 0), at + Vector3.new(0, 3, 0) + look.Unit), {
					element = s.element,
					important = true,
				})
				if ball == b then
					ball = nil
				end
				if folder == f then
					f:Destroy()
					folder = nil
				end
			end)
		end))
	end))

	table.insert(conns, track.Stopped:Connect(function()
		task.delay(0.3, cleanup)
	end))
	return cleanup
end

-------------------------------------------------------------------------------
-- !! UNTESTED IN STUDIO !! SpinAttack v2 was authored against the Blender preview
-- (Previews/SpinAttack.mp4, tools/spinattack/composite.py) only. Verify blade attachment
-- offsets, Trail look at 6-8 frame turns, the vortex beams/emitters and part counts in
-- Studio (PC + phone) before shipping.
-- Clip: SpinAttack v2 (SpinStart f12, Hit "spin1" f16 / "spin2" f24 / "spin3" f30, SpinEnd f34,
-- Hit "spinfinish" f41, TrailOff f48). Turns accelerate (~8 / 7 / 6 frames). Radial layers are
-- deliberate here (spin move); the finisher stays frontal.
-- Use EITHER playSpinAttack (everything) OR bindAnimator alone (ground shocks + finisher only);
-- with both bound set spec.playHits = false so the shocks are not doubled.
--
-- BUDGET (whole move, quality 1; counts scale with Config.quality):
--   persistent: 1 pivot part + 1 rune part (Decal; no light: it tinted the shins), 7 Attachments + 5 Trails on the blade,
--               6 vortex Beams (12 Attachments), 3 vortex ParticleEmitters (LockedToPart)
--   vortex particles: dust <= 14/s, debris <= 22/s, pebbles <= 12/s -> ~35 live at the peak
--   per turn: 1 transient spark part (10/16/24 sparks) + SpinShock (1 mesh ring, ~13 particles)
--   finisher: SpinFinish (~11 mesh parts, 6 beams, ~60 particles, 1 light)
--   peak live particles ~150 (Config.maxLiveParticles PC 900 / mobile 360)
-------------------------------------------------------------------------------
export type SpinTier = {
	life: number, -- trail lifetime (s): shorter as the turns speed up, so the stack stays thin
	inner: number, -- studs along the blade (Handle +Y) where this layer starts
	outer: number, -- ... and ends (past bladeTip = wider than the blade)
	color0: string, -- palette role at the head (newest)
	color1: string, -- palette role at the tail
	brightness: number,
	transparency: number, -- at the head
}

export type SpinSequenceSpec = {
	element: string,
	ink: Color3, -- deep navy value layer (shadow smear under the bright rings)
	accent: Color3, -- violet secondary: outer rim on turn 3 + every other vortex line
	bladeBase: number,
	bladeTip: number, -- the pipeline's preview blade: 0.55 .. 3.45 along Handle +Y
	inkLife: number,
	tiers: { SpinTier }, -- one Trail per turn: 1 teal, 2 brighter/wider, 3 white-hot core
	hotLife: number,
	vortexLines: number,
	vortexRadius: { number }, -- start, end (tightens over the 3 turns)
	vortexHeight: { number }, -- start, end (grows)
	vortexSpeed: { number }, -- deg/s start, end (spins up)
	sparks: { number }, -- per turn, flung tangentially off the blade tip
	runeSize: number, -- studs
	runeTransparency: { number }, -- per turn (brightens)
	shockPreset: string,
	shockScale: { number },
	finishPreset: string,
	finishForward: number, -- studs ahead of the root: the finisher layers never cross the character
	playHits: boolean, -- false when bindAnimator already plays DefaultHits for this clip
}

(LihFolkVFX.Sequences :: any).SpinAttack = {
	element = "teal",
	ink = Color3.fromRGB(10, 16, 46),
	accent = Color3.fromRGB(150, 90, 255),
	bladeBase = 0.9,
	bladeTip = 3.4,
	inkLife = 0.24,
	tiers = {
		{ life = 0.17, inner = 2.0, outer = 3.4, color0 = "glow", color1 = "main", brightness = 2, transparency = 0.4 },
		{ life = 0.14, inner = 1.9, outer = 3.8, color0 = "hot", color1 = "glow", brightness = 3.5, transparency = 0.3 },
		{ life = 0.12, inner = 1.8, outer = 4.2, color0 = "hot", color1 = "hot", brightness = 6, transparency = 0.15 },
	},
	hotLife = 0.05,
	vortexLines = 6,
	vortexRadius = { 5.0, 3.2 },
	vortexHeight = { 3.0, 8.0 },
	vortexSpeed = { 700, 1500 },
	sparks = { 10, 16, 24 },
	runeSize = 9,
	runeTransparency = { 0.85, 0.68, 0.45 },
	shockPreset = "SpinShock",
	shockScale = { 0.85, 1.15, 1.5 },
	finishPreset = "SpinFinish",
	finishForward = 3,
	playHits = true,
} :: SpinSequenceSpec

local function spinTrail(blade: BasePart, a0: Attachment, a1: Attachment, name: string): Trail
	local tr = Instance.new("Trail")
	tr.Name = name
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Enabled = false
	tr.MinLength = 0.05
	tr.FaceCamera = false
	tr.LightInfluence = 0
	tr.TextureMode = Enum.TextureMode.Stretch
	tr.Texture = tex("trail_soft") or ""
	tr.Parent = blade
	return tr
end

--[[ Play the SpinAttack v2 sequence on a character whose track carries SpinStart / Hit "spinN" / SpinEnd /
	Hit "spinfinish" / TrailOff. The weapon is the first Tool's Handle (blade along Handle +Y).
	UNTESTED IN STUDIO. Returns a cleanup function. ]]
function LihFolkVFX.playSpinAttack(track: AnimationTrack, character: Model, spec: SpinSequenceSpec?): () -> ()
	local s: SpinSequenceSpec = spec or (LihFolkVFX.Sequences :: any).SpinAttack
	local pal = ((LihFolkVFX.Elements :: any)[s.element] or (LihFolkVFX.Elements :: any).teal) :: Palette
	local conns: { RBXScriptConnection } = {}
	local made: { Instance } = {}
	local vortex: Effect? = nil
	local tier = 0 -- 0 before SpinStart, 1..3 during the turns, 4 = collapsing (finisher)
	local collapseAt: number? = nil
	local tool = character:FindFirstChildOfClass("Tool")
	-- lihfolk-ignore: findfirstchild-chain (nil-checked below)
	local blade = if tool then tool:FindFirstChild("Handle") :: BasePart? else nil
	local tierTrails: { Trail } = {}
	local others: { Trail } = {} -- ink + accent: on for the whole spin
	local hot: Trail? = nil

	if blade then
		local function att(name: string, y: number): Attachment
			local a = Instance.new("Attachment")
			a.Name = name
			a.Position = Vector3.new(0, y, 0)
			a.Parent = blade
			table.insert(made, a)
			return a
		end
		-- deep navy ink smear: thick, pushed outward past the tip so it frames the bright layers
		local ink = spinTrail(blade, att("SpinInk0", s.bladeTip - 0.6), att("SpinInk1", s.bladeTip + 1.1), "SpinInk")
		ink.Lifetime = s.inkLife
		ink.LightEmission = 0
		ink.Brightness = 1
		ink.Color = ColorSequence.new(s.ink)
		ink.Transparency = ns({ { 0, 0.5 }, { 0.4, 0.55 }, { 1, 1 } })
		ink.WidthScale = ns({ { 0, 1 }, { 1, 0.85 } })
		table.insert(others, ink)
		table.insert(made, ink)
		for i, t in s.tiers do
			local tr = spinTrail(blade, att("SpinT" .. i .. "a", t.inner), att("SpinT" .. i .. "b", t.outer), "SpinTier" .. i)
			tr.Lifetime = t.life
			tr.LightEmission = 1
			tr.Brightness = t.brightness
			tr.Color = ColorSequence.new(role(pal, t.color0), role(pal, t.color1))
			tr.Transparency = ns({ { 0, t.transparency }, { 0.5, 0.5 + t.transparency * 0.5 }, { 1, 1 } })
			tr.WidthScale = ns({ { 0, 1 }, { 1, 0.4 } })
			table.insert(tierTrails, tr)
			table.insert(made, tr)
		end
		-- violet accent rim on the last turn (outside the white-hot core)
		local acc = spinTrail(blade, att("SpinAcc0", s.bladeTip + 0.3), att("SpinAcc1", s.bladeTip + 0.9), "SpinAccent")
		acc.Lifetime = 0.12
		acc.LightEmission = 1
		acc.Brightness = 3
		acc.Color = ColorSequence.new(s.accent)
		acc.Transparency = ns({ { 0, 0.2 }, { 1, 1 } })
		table.insert(made, acc)
		-- white-hot edge for the finisher
		local h = spinTrail(blade, att("SpinHot0", s.bladeTip - 0.9), att("SpinHot1", s.bladeTip), "SpinHot")
		h.Lifetime = s.hotLife
		h.LightEmission = 1
		h.Brightness = 6
		h.Color = ColorSequence.new(pal.hot, pal.glow)
		h.Transparency = ns({ { 0, 0 }, { 1, 1 } })
		hot = h
		table.insert(made, h)
		tierTrails[4] = acc
	else
		warnOnce("spin:noblade", "playSpinAttack: no Tool Handle on the character; whirl trails skipped")
	end

	local function setTier(n: number)
		tier = n
		for i = 1, 3 do
			local tr = tierTrails[i]
			if tr then
				if i == n then
					tr:Clear()
				end
				tr.Enabled = (i == n) -- the previous turn's layer stops emitting and fades on its own
			end
		end
		local acc = tierTrails[4]
		if acc then
			acc.Enabled = (n == 3)
		end
	end

	local function stopVortex()
		if vortex then
			vortex.stopped = true
			vortex = nil
		end
	end

	local function cleanup()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		stopVortex()
		for _, i in made do
			i:Destroy()
		end
		table.clear(made)
	end

	-- wind vortex column + rune sigil + lifted dust / debris / pebbles
	local function startVortex()
		local root = rootOf(character)
		if not root then
			return
		end
		local hum = character:FindFirstChildOfClass("Humanoid")
		local floorY = root.Position.Y - (if hum then hum.HipHeight else 2) - root.Size.Y / 2
		local base = Vector3.new(root.Position.X, floorY, root.Position.Z)
		local folder = Instance.new("Folder")
		folder.Name = "SpinVortex"
		folder.Parent = getContainer()
		local pivot = newPart("VortexPivot", CFrame.new(base), folder)
		-- rune sigil on the floor
		local rune = newPart("Rune", CFrame.new(base + Vector3.new(0, 0.03, 0)), folder)
		rune.Size = Vector3.new(s.runeSize, 0.05, s.runeSize)
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Top
		decal.Texture = tex("rune_circle") or ""
		decal.Color3 = pal.glow
		decal.Transparency = 1
		decal.Parent = rune
		-- helical vortex lines (each beam = one 140 deg rising arc, re-posed every frame)
		local lines: { { b: Beam, a0: Attachment, a1: Attachment, phi: number, y: number } } = {}
		for i = 1, s.vortexLines do
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Parent, a1.Parent = pivot, pivot
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = a0, a1
			b.Segments = 24
			b.FaceCamera = true
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Brightness = 2
			b.Color = if i % 2 == 0 then ColorSequence.new(s.accent, pal.glow) else ColorSequence.new(pal.hot, pal.glow)
			b.Transparency = NumberSequence.new(1)
			b.Texture = tex("trail_soft") or ""
			b.Parent = pivot
			table.insert(lines, { b = b, a0 = a0, a1 = a1, phi = 360 * i / s.vortexLines, y = (i - 1) / math.max(1, s.vortexLines - 1) })
		end
		-- lifted particles ride the spinning pivot (LockedToPart) -> they spiral up the column
		local function liftEmitter(props: { [string]: any }): ParticleEmitter
			local e = newEmitter(pivot, props)
			e.LockedToPart = true
			e.Shape = Enum.ParticleEmitterShape.Cylinder
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
			e.EmissionDirection = Enum.NormalId.Top
			e.Enabled = true
			return e
		end
		pivot.Size = Vector3.new(2 * s.vortexRadius[1], 0.2, 2 * s.vortexRadius[1])
		local dust = liftEmitter({
			Texture = tex("smoke_puff") or "",
			Color = ColorSequence.new(pal.spark, role(pal, "deep")),
			LightEmission = 0,
			Size = ns({ { 0, 1.2 }, { 1, 3 } }),
			Transparency = ns({ { 0, 1 }, { 0.15, 0.45 }, { 0.7, 0.6 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.6, 0.9),
			Speed = NumberRange.new(3, 6),
			Acceleration = Vector3.new(0, 4, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-60, 60),
		})
		local debris = liftEmitter({
			Texture = tex("flip_petals_8x8") or "",
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8,
			FlipbookMode = Enum.ParticleFlipbookMode.Random,
			Color = ColorSequence.new(s.ink),
			LightEmission = 0,
			Size = ns({ { 0, 0.25 }, { 0.3, 0.5 }, { 1, 0.3 } }),
			Lifetime = NumberRange.new(0.5, 0.8),
			Speed = NumberRange.new(5, 10),
			Acceleration = Vector3.new(0, 6, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-400, 400),
		})
		local pebbles = liftEmitter({
			Texture = tex("spark_square") or "",
			Color = ColorSequence.new(pal.debris),
			LightEmission = 0,
			Size = NumberSequence.new(0.18),
			Lifetime = NumberRange.new(0.35, 0.55),
			Speed = NumberRange.new(6, 11),
			Acceleration = Vector3.new(0, -20, 0),
			Rotation = NumberRange.new(0, 45),
		})
		local q = LihFolkVFX.Config.quality
		local e: Effect = { t0 = os.clock(), life = 3.0, steps = {}, root = folder, particles = 0, stopped = false,
			finished = false, speed = 1 }
		local spin = 0
		local lastT = 0
		local spinDur = 0.75 -- SpinStart -> SpinEnd at clip speed 1
		table.insert(e.steps, function(t: number)
			local u = clamp01(t / spinDur)
			local k = 0.0 -- collapse 0..1
			if collapseAt then
				k = clamp01((os.clock() - collapseAt) / 0.3)
			end
			local r = (s.vortexRadius[1] + (s.vortexRadius[2] - s.vortexRadius[1]) * u) * (1 + 1.6 * easeOut(k, 2))
			local hgt = s.vortexHeight[1] + (s.vortexHeight[2] - s.vortexHeight[1]) * u
			local w = s.vortexSpeed[1] + (s.vortexSpeed[2] - s.vortexSpeed[1]) * u
			spin += w * (t - lastT)
			lastT = t
			local rp = rootOf(character)
			local p = if rp then Vector3.new(rp.Position.X, floorY, rp.Position.Z) else base
			pivot.CFrame = CFrame.new(p) * CFrame.Angles(0, math.rad(spin), 0)
			pivot.Size = Vector3.new(2 * r * 0.8, 0.2, 2 * r * 0.8)
			local a = (0.25 + 0.1 * math.min(tier, 3)) * clamp01(t / 0.12) * (1 - k)
			for _, l in lines do
				local y0 = 0.3 + l.y * hgt * 0.75
				local y1 = y0 + hgt * 0.25
				l.a0.CFrame = CFrame.new(arcPoint(l.phi, r, y0)) * CFrame.Angles(0, math.rad(l.phi), 0)
				l.a1.CFrame = CFrame.new(arcPoint(l.phi + 140, r * 0.92, y1)) * CFrame.Angles(0, math.rad(l.phi + 140), 0)
				local kk = 4 / 3 * math.tan(math.rad(140) / 4) * r
				l.b.CurveSize0, l.b.CurveSize1 = kk, -kk
				l.b.Width0, l.b.Width1 = 0.06, 0.35 + 0.12 * math.min(tier, 3)
				l.b.Transparency = ns({ { 0, 1 }, { 0.3, 1 - a }, { 0.8, 1 - a * 0.6 }, { 1, 1 } })
			end
			local tt = math.min(tier, 3)
			dust.Rate = (if k > 0 then 0 else 6 + 4 * tt) * q
			debris.Rate = (if k > 0 then 0 else 10 + 4 * tt) * q
			pebbles.Rate = (if k > 0 then 0 else 4 + 3 * tt) * q
			-- rune: brightens per turn, flares on the finisher, then fades
			local rt = s.runeTransparency[math.max(1, tt)]
			if tier == 0 then
				rt = 1
			end
			if k > 0 then
				rt = 0.05 + 0.95 * easeIn(k, 1.5)
			end
			decal.Transparency = rt
			rune.CFrame = CFrame.new(p + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, math.rad(-spin * 0.08), 0)
			if k >= 1 then
				e.stopped = true
			end
		end)
		start(e)
		vortex = e
	end

	local function tipSparks(n: number)
		if not blade then
			return
		end
		local root = rootOf(character)
		local tip = blade.CFrame * Vector3.new(0, s.bladeTip, 0)
		local centre = if root then root.Position else blade.Position
		local radial = (tip - centre) * Vector3.new(1, 0, 1)
		if radial.Magnitude < 1e-3 then
			return
		end
		local tangent = Vector3.yAxis:Cross(radial.Unit) -- counter-clockwise from above
		local p = newPart("SpinSparks", CFrame.lookAt(tip, tip + (tangent + radial.Unit * 0.25).Unit), getContainer())
		local em = newEmitter(p, {
			Texture = tex("spark_streak") or "",
			Color = ColorSequence.new(pal.hot, pal.spark),
			LightEmission = 1,
			Brightness = 5,
			Size = ns({ { 0, 0.5 }, { 1, 0 } }),
			Transparency = ns({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.15, 0.28),
			Speed = NumberRange.new(18, 32),
			SpreadAngle = Vector2.new(14, 10),
			Drag = 6,
			Acceleration = Vector3.new(0, -24, 0),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			EmissionDirection = Enum.NormalId.Front,
		})
		em:Emit(math.max(1, math.floor(n * LihFolkVFX.Config.quality + 0.5)))
		Debris:AddItem(p, 0.5)
	end

	table.insert(conns, track:GetMarkerReachedSignal("SpinStart"):Connect(function()
		for _, t in others do
			t:Clear()
			t.Enabled = true
		end
		if hot then
			hot:Clear()
			hot.Enabled = true
		end
		setTier(1)
		startVortex()
	end))

	table.insert(conns, track:GetMarkerReachedSignal("Hit"):Connect(function(param: string?)
		local v = param or ""
		local i = tonumber(string.match(v, "^spin(%d)$") or "")
		local root = rootOf(character)
		if i then
			tipSparks(s.sparks[i] or 12)
			if i < 3 then
				task.delay(0.033, function()
					if tier == i then
						setTier(i + 1)
					end
				end)
			end
			if s.playHits and root then
				LihFolkVFX.play(s.shockPreset, root.CFrame, { element = s.element, scale = s.shockScale[i] or 1, important = true })
			end
		elseif v == "spinfinish" then
			collapseAt = os.clock() -- the vortex blows outward into the finisher's dust blast
			tier = 4
			if s.playHits and root then
				LihFolkVFX.play(s.finishPreset, root.CFrame * CFrame.new(0, 0, -s.finishForward), { element = s.element, important = true })
			end
		end
	end))

	table.insert(conns, track:GetMarkerReachedSignal("SpinEnd"):Connect(function()
		-- the turn layers stop emitting and fade; the hot edge stays on for the finishing slash
		for i = 1, 4 do
			local tr = tierTrails[i]
			if tr then
				tr.Enabled = false
			end
		end
		for _, t in others do
			t.Enabled = false
		end
	end))

	table.insert(conns, track:GetMarkerReachedSignal("TrailOff"):Connect(function()
		if hot then
			hot.Enabled = false
		end
	end))

	table.insert(conns, track.Stopped:Connect(function()
		for _, t in made do
			if t:IsA("Trail") then
				t.Enabled = false
			end
		end
		if not collapseAt then
			stopVortex()
		end
		task.delay(0.6, cleanup)
	end))
	return cleanup
end


return LihFolkVFX
