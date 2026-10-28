--!strict
--[[
	LihFolkUITheme
	Design tokens for LihFolk UI: palette, button roles, per-menu header themes,
	type scale, spacing, radii, strokes, sizes, motion and sound slots.

	Look: "Ink and Candy". Deep dusk-violet canvas, thick ink outlines, candy-coloured
	tactile slabs, soft diagonal candy bands, Fredoka One display type with ink strokes.

	Every other LihFolk UI module reads from here. Change a value here, never inline.
	All sizes are DESIGN UNITS: pixels at a UIScale of 1. The controller scales them.

	License: LihFolk. Free to use and modify in your games. Docs are CC BY 4.0.
]]

local GuiService = game:GetService("GuiService")

local Theme = {}

export type RoleName = "go" | "neutral" | "premium" | "danger" | "info" | "done" | "locked"
export type ThemeName = "shop" | "codes" | "rebirth" | "settings" | "daily" | "neutral"
export type TextStyleName = "display" | "title" | "button" | "number" | "small" | "body" | "caption"

-- A tactile surface: gradient face (top -> bottom), the darker "lip" under it,
-- and the text colour / outline that reads on it.
export type Swatch = {
	top: Color3,
	bottom: Color3,
	shade: Color3,
	text: Color3,
	textStroke: Color3?, -- nil = no outline on this surface
}

export type TextStyle = {
	font: Font,
	size: number,
	stroke: number, -- outline thickness in design px, 0 = none
}

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

---------------------------------------------------------------------------
-- Palette (raw colours). Names describe the colour, not the use.
---------------------------------------------------------------------------
Theme.Palette = {
	ink = hex("#160F2B"), -- outlines, text strokes, the darkest value in the kit
	dusk = hex("#2D2852"), -- panel canvas
	duskRaised = hex("#3B3566"), -- cards on the canvas
	duskRaisedHi = hex("#4A437A"), -- top of a card's gradient
	duskSunken = hex("#1F1B3D"), -- recessed tracks and text fields
	line = hex("#57508F"), -- dividers on the canvas
	textHi = hex("#FFFFFF"), -- titles and primary text (13.7:1 on dusk, 11.1:1 on cards)
	textMid = hex("#D6D0F5"), -- body text (9.2:1 on dusk, 7.5:1 on cards)
	textLow = hex("#B0A9DD"), -- captions, placeholders (6.2:1 on dusk, 5.1:1 on cards)
	positive = hex("#7BF5A6"), -- success messages on dark surfaces (10.1:1 on dusk)
	negative = hex("#FF8FA8"), -- error messages on dark surfaces (6.3:1 on dusk)
	backdrop = hex("#0B0718"), -- modal dimmer
	white = hex("#FFFFFF"),
	gold = hex("#FFD24A"), -- featured outlines, sunburst
}

---------------------------------------------------------------------------
-- Button roles. Every interactive slab uses exactly one role.
-- Roles differ in LIGHTNESS and carry a glyph or word, never colour alone.
---------------------------------------------------------------------------
local ROLES: { [RoleName]: Swatch } = {
	go = { -- claim, buy, confirm, the one primary action on a screen
		top = hex("#7BF5A6"),
		bottom = hex("#25C773"),
		shade = hex("#12804A"),
		text = hex("#FFFFFF"),
		textStroke = hex("#160F2B"),
	},
	neutral = { -- secondary actions, tabs, back
		top = hex("#9C94DB"),
		bottom = hex("#6E66B3"),
		shade = hex("#40397A"),
		text = hex("#FFFFFF"),
		textStroke = hex("#160F2B"),
	},
	premium = { -- Robux, skip, paid boosts
		top = hex("#FFE27A"),
		bottom = hex("#FFB224"),
		shade = hex("#B06B00"),
		text = hex("#FFFFFF"),
		textStroke = hex("#160F2B"),
	},
	danger = { -- close, destructive, reset
		top = hex("#FF7A98"),
		bottom = hex("#EE3D66"),
		shade = hex("#9A1838"),
		text = hex("#FFFFFF"),
		textStroke = hex("#160F2B"),
	},
	info = { -- help, header actions, links
		top = hex("#7CC8FF"),
		bottom = hex("#3D93F0"),
		shade = hex("#1D58A8"),
		text = hex("#FFFFFF"),
		textStroke = hex("#160F2B"),
	},
	done = { -- claimed, owned, equipped: pale, quiet, not interactive
		top = hex("#ECE9FA"),
		bottom = hex("#C4BEE0"),
		shade = hex("#827BA8"),
		text = hex("#2D2852"),
		textStroke = nil,
	},
	locked = { -- not yet available: darkest slab in the kit
		top = hex("#4F4980"),
		bottom = hex("#3A3466"),
		shade = hex("#221D42"),
		text = hex("#B3ACDB"),
		textStroke = nil,
	},
}
Theme.Roles = ROLES

---------------------------------------------------------------------------
-- Menu header themes. Each menu owns one colour identity; the body stays dusk
-- so every menu still reads as the same family.
---------------------------------------------------------------------------
local MENUS: { [ThemeName]: Swatch } = {
	shop = { top = hex("#FFB54D"), bottom = hex("#FF7B22"), shade = hex("#B9480A"), text = hex("#FFFFFF"), textStroke = hex("#160F2B") }, -- Tangerine
	codes = { top = hex("#5DEBDB"), bottom = hex("#18B5C6"), shade = hex("#0C6F80"), text = hex("#FFFFFF"), textStroke = hex("#160F2B") }, -- Lagoon
	rebirth = { top = hex("#CF9BFF"), bottom = hex("#9257F2"), shade = hex("#5A2AAE"), text = hex("#FFFFFF"), textStroke = hex("#160F2B") }, -- Orchid
	settings = { top = hex("#86AEFF"), bottom = hex("#4F7BEA"), shade = hex("#2B4CA3"), text = hex("#FFFFFF"), textStroke = hex("#160F2B") }, -- Denim
	daily = { top = hex("#FF9ACD"), bottom = hex("#F25AA2"), shade = hex("#A82568"), text = hex("#FFFFFF"), textStroke = hex("#160F2B") }, -- Bubblegum
	neutral = { top = hex("#9C94DB"), bottom = hex("#6E66B3"), shade = hex("#40397A"), text = hex("#FFFFFF"), textStroke = hex("#160F2B") }, -- Lilac
}
Theme.Menus = MENUS

---------------------------------------------------------------------------
-- Typography. Two families only.
--   Display: Fredoka One (rounded, heavy, friendly; built in, so no download).
--   Body:    Builder Sans (Roblox's own UI face; wide language coverage).
-- Outline ratio: about 9 to 10 percent of the text size, round joins.
---------------------------------------------------------------------------
Theme.Fonts = {
	display = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
	body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
	bodySemi = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
}

local TEXT: { [TextStyleName]: TextStyle } = {
	display = { font = Theme.Fonts.display, size = 36, stroke = 3.5 }, -- window titles
	title = { font = Theme.Fonts.display, size = 26, stroke = 2.5 }, -- section headers, card titles
	button = { font = Theme.Fonts.display, size = 24, stroke = 2.5 }, -- button captions
	number = { font = Theme.Fonts.display, size = 30, stroke = 3 }, -- amounts, prices, multipliers
	small = { font = Theme.Fonts.display, size = 18, stroke = 2 }, -- pills, bar labels, day tags
	body = { font = Theme.Fonts.body, size = 18, stroke = 0 }, -- descriptions
	caption = { font = Theme.Fonts.bodySemi, size = 15, stroke = 0 }, -- hints, timers (never under 12 px drawn)
}
Theme.Text = TEXT

Theme.MinDrawnText = 12 -- hard floor in real pixels after scaling
Theme.MinTextSize = 15 -- design units; 15 x the 0.85 touch scale floor still draws about 12.7 px

---------------------------------------------------------------------------
-- Spacing (4-point steps), radii, stroke widths, component sizes
---------------------------------------------------------------------------
Theme.Space = { xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32 }

-- Nested radius rule: inner radius = outer radius - gap between them.
Theme.Radius = {
	panel = 22,
	header = 14, -- panel 22 minus the 8 px header inset
	card = 14,
	button = 12,
	input = 10,
	pill = UDim.new(0.5, 0), -- fully round ends
}

Theme.Stroke = {
	panel = 4,
	card = 3,
	button = 3,
	input = 2.5,
	focus = 3,
	divider = 2,
}

Theme.Size = {
	touchMin = 52, -- smallest tappable box in design units; drawn >= 44 px on phones
	touchDrawnMin = 44, -- real pixels; the controller never scales touch UI below this
	buttonH = 56,
	depth = 6, -- tactile lip under a slab
	depthSmall = 4,
	headerH = 72, -- header slab including its lip
	headerInset = 8,
	close = 52,
	iconSm = 28,
	iconMd = 48,
	iconLg = 72,
	toggleW = 84,
	toggleH = 40,
	progressH = 30,
	inputH = 56,
	window = Vector2.new(760, 520), -- default window, design units
	screenMargin = 16, -- gap kept between a window and the safe-area edge
	hudButton = 64,
}

---------------------------------------------------------------------------
-- Motion. All UI tweens take their numbers from here.
---------------------------------------------------------------------------
Theme.Motion = {
	openTime = 0.22,
	openFrom = 0.86, -- window scale when it starts to open
	openStyle = Enum.EasingStyle.Back,
	openDirection = Enum.EasingDirection.Out,
	closeTime = 0.12,
	closeTo = 0.9,
	closeStyle = Enum.EasingStyle.Quad,
	closeDirection = Enum.EasingDirection.In,
	dimTime = 0.18,
	dimTransparency = 0.45, -- backdrop at rest when a menu is open
	hoverScale = 1.04,
	hoverTime = 0.1,
	pressScale = 0.96,
	pressTime = 0.05,
	releaseTime = 0.16,
	fillTime = 0.35, -- progress bars
	toggleTime = 0.16,
	glowTime = 0.8, -- claimable glow breathing half-period
	nudgeTime = 0.6, -- tier arrow nudge half-period
	sunburstPeriod = 16, -- seconds per full turn
	staggerStep = 0.04,
	shakeStep = 0.04,
}

-- Optional sound slots. Empty = silent. Fill with YOUR uploaded audio ids,
-- as "rbxassetid://<your id>". Never ship ids you have not checked.
local SOUNDS: { [string]: string } = {
	click = "", -- PLACEHOLDER
	hover = "", -- PLACEHOLDER (keep very quiet, or leave empty)
	open = "", -- PLACEHOLDER
	close = "", -- PLACEHOLDER
	success = "", -- PLACEHOLDER
	error = "", -- PLACEHOLDER
}
Theme.Sounds = SOUNDS

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local reducedMotionOverride: boolean? = nil

-- Player setting wins; otherwise follow the platform's Reduced Motion setting.
function Theme.isReducedMotion(): boolean
	if reducedMotionOverride ~= nil then
		return reducedMotionOverride
	end
	local ok, value = pcall(function(): any
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

-- nil = follow the platform setting again.
function Theme.setReducedMotion(value: boolean?)
	reducedMotionOverride = value
end

function Theme.role(name: RoleName): Swatch
	return Theme.Roles[name] or Theme.Roles.neutral
end

function Theme.menu(name: ThemeName): Swatch
	return Theme.Menus[name] or Theme.Menus.neutral
end

-- Vertical face gradient (UIGradient.Rotation = 90 runs top to bottom).
function Theme.faceSequence(swatch: Swatch): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, swatch.top),
		ColorSequenceKeypoint.new(0.45, swatch.top:Lerp(swatch.bottom, 0.55)),
		ColorSequenceKeypoint.new(1, swatch.bottom),
	})
end

-- 1234567 -> "1,234,567"
function Theme.formatComma(n: number): string
	local negative = n < 0
	local digits = tostring(math.floor(math.abs(n)))
	local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return if negative then "-" .. out else out
end

-- 1234567 -> "1.2M". Keeps trailing zeros of the integer part intact ("160M", not "16M").
local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }
function Theme.formatShort(n: number): string
	local value = math.abs(n)
	if value < 1000 then
		return tostring(math.floor(n))
	end
	local index = 0
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text: string
	if value >= 100 then
		text = string.format("%d", math.floor(value))
	else
		text = string.format("%.1f", math.floor(value * 10) / 10)
		if text:sub(-2) == ".0" then
			text = text:sub(1, -3)
		end
	end
	return (if n < 0 then "-" else "") .. text .. SUFFIXES[index]
end

return Theme
