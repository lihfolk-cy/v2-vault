--!strict
--[[
	LihFolkUIComponents
	Constructor functions for every LihFolk UI component. Each returns a small
	table: the Roblox instance (`root`) plus closures to change it. Nothing here
	creates a ScreenGui or opens a window; that is LihFolkUIController's job.

	Components:
	  Text, Pill, SectionHeader, Card, Row, Grid, Pattern, Sunburst,
	  Button (3D tactile slab), StateButton (claim / claimed / locked / skip / pending),
	  CurrencyButton, CloseButton, HeaderAction, HudButton,
	  Window (themed header, close, header action, pattern, scrolling body),
	  ProgressBar (recessed track), TierCompare, RewardCard, Toggle, SettingRow, TextInput.

	Sizes are design units (see LihFolkUITheme.Size). Motion reads LihFolkUITheme.Motion
	and respects Reduced Motion.

	License: LihFolk. Free to use and modify in your games.
]]

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Theme = require(script.Parent.LihFolkUITheme)
local Icons = require(script.Parent.LihFolkUIIcons)

type RoleName = Theme.RoleName
type ThemeName = Theme.ThemeName
type TextStyleName = Theme.TextStyleName
type Swatch = Theme.Swatch

local P = Theme.Palette
local S = Theme.Size
local M = Theme.Motion
local SP = Theme.Space

local Components = {}

---------------------------------------------------------------------------
-- Primitives
---------------------------------------------------------------------------
local function px(n: number): UDim
	return UDim.new(0, n)
end

local function corner(parent: GuiObject, radius: UDim): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
	return c
end

local function outline(parent: GuiObject, thickness: number, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or P.ink
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function faceGradient(parent: GuiObject, swatch: Swatch): UIGradient
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = Theme.faceSequence(swatch)
	g.Parent = parent
	return g
end

local function pad(parent: Instance, top: number, right: number?, bottom: number?, left: number?): UIPadding
	local r = right or top
	local p = Instance.new("UIPadding")
	p.PaddingTop = px(top)
	p.PaddingRight = px(r)
	p.PaddingBottom = px(bottom or top)
	p.PaddingLeft = px(left or r)
	p.Parent = parent
	return p
end

local function list(
	parent: Instance,
	direction: Enum.FillDirection,
	gap: number,
	hAlign: Enum.HorizontalAlignment?,
	vAlign: Enum.VerticalAlignment?
): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = direction
	l.Padding = px(gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center
	l.VerticalAlignment = vAlign or Enum.VerticalAlignment.Center
	l.Parent = parent
	return l
end

local function blank(name: string, size: UDim2?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = size or UDim2.fromScale(1, 1)
	return f
end

local function tween(instance: Instance, time: number, style: Enum.EasingStyle, direction: Enum.EasingDirection, goals: { [string]: any }): Tween
	local t = TweenService:Create(instance, TweenInfo.new(time, style, direction), goals)
	t:Play()
	return t
end

-- A recessed look: ink shading at the top edge fading out by 40 percent height.
local function recess(parent: GuiObject, radius: UDim)
	local shade = blank("Recess")
	shade.BackgroundTransparency = 0
	shade.BackgroundColor3 = P.ink
	corner(shade, radius)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = shade
	shade.Parent = parent
end

-- The gamepad selection ring used by every selectable LihFolk control.
local function selectionRing(radius: UDim): Frame
	local ring = blank("SelectionRing", UDim2.new(1, 10, 1, 10))
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	corner(ring, radius)
	outline(ring, 3, P.white)
	return ring
end

Components.corner = corner
Components.outline = outline
Components.pad = pad
Components.list = list

---------------------------------------------------------------------------
-- Sound
---------------------------------------------------------------------------
local soundCache: { [string]: Sound } = {}

-- Plays a Theme.Sounds slot locally. Silent when the slot is empty.
function Components.playSound(name: string)
	local id = Theme.Sounds[name]
	if id == nil or id == "" then
		return
	end
	local sound = soundCache[name]
	if sound == nil then
		local s = Instance.new("Sound")
		s.Name = "LihFolkUI_" .. name
		s.SoundId = id
		s.Volume = 0.5
		s.Parent = SoundService
		soundCache[name] = s
		sound = s
	end
	SoundService:PlayLocalSound(sound :: Sound)
end

---------------------------------------------------------------------------
-- Window type (declared early: loop-owning components accept a window)
---------------------------------------------------------------------------
export type Window = {
	name: string,
	theme: ThemeName,
	designSize: Vector2,
	root: Frame, -- slot sized in design units; the controller fits and scales it
	panel: Frame, -- the visible panel; open/close animates its Motion UIScale
	header: Frame,
	body: GuiObject, -- put your content here (ScrollingFrame unless scroll = false)
	closeButton: Button,
	headerActionButton: Button?,
	fitScale: UIScale,
	motionScale: UIScale,
	loops: { Tween }, -- looping tweens: played on open, paused on close
	defaultSelection: GuiObject?, -- gamepad focus on open (defaults to the close button)
	requestClose: () -> (), -- replaced by the controller on register
	setTitle: (title: string) -> (),
	addLoop: (t: Tween) -> (),
	removeLoop: (t: Tween) -> (),
}

-- Registers a looping tween with a window (paused while closed), or plays it now.
local function adoptLoop(window: Window?, t: Tween)
	if window then
		window.addLoop(t)
		if window.root.Visible then
			t:Play()
		end
	else
		t:Play()
	end
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------
export type TextProps = {
	color: Color3?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	align: Enum.TextXAlignment?,
	scaled: boolean?, -- fit to box (never overflows); capped at the style size
	autoY: boolean?, -- wrap and grow vertically
	wrap: boolean?, -- wrap inside a fixed box, ellipsis on the last line
	name: string?,
	layoutOrder: number?,
	zIndex: number?,
	parent: Instance?,
}

local function makeText(style: TextStyleName, text: string, props: TextProps?): (TextLabel, UIStroke?)
	local p: TextProps = props or {}
	local spec = Theme.Text[style]
	local label = Instance.new("TextLabel")
	label.Name = p.name or "Text"
	label.BackgroundTransparency = 1
	label.FontFace = spec.font
	label.TextSize = spec.size
	label.Text = text
	label.TextColor3 = p.color or P.textHi
	label.TextXAlignment = p.align or Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Size = p.size or UDim2.new(1, 0, 0, spec.size + 10)
	label.Position = p.position or UDim2.new()
	label.AnchorPoint = p.anchor or Vector2.zero
	label.LayoutOrder = p.layoutOrder or 0
	if p.zIndex then
		label.ZIndex = p.zIndex
	end
	if p.scaled then
		label.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = spec.size
		limit.MinTextSize = math.min(spec.size, Theme.MinTextSize)
		limit.Parent = label
	elseif p.autoY then
		label.TextWrapped = true
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = p.size or UDim2.new(1, 0, 0, 0)
	else
		label.TextWrapped = p.wrap == true
		label.TextTruncate = Enum.TextTruncate.AtEnd
	end
	local stroke: UIStroke? = nil
	if spec.stroke > 0 then
		local s = Instance.new("UIStroke")
		s.Color = P.ink
		s.Thickness = spec.stroke
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = label
		stroke = s
	end
	if p.parent then
		label.Parent = p.parent
	end
	return label, stroke
end

-- A styled label. Styles: display, title, button, number, small, body, caption.
function Components.Text(style: TextStyleName, text: string, props: TextProps?): TextLabel
	local label = makeText(style, text, props)
	return label
end

---------------------------------------------------------------------------
-- Pill: small rounded tag ("BEST VALUE", "x2", "NEXT")
---------------------------------------------------------------------------
export type PillProps = {
	role: RoleName?,
	position: UDim2?,
	anchor: Vector2?,
	rotation: number?,
	layoutOrder: number?,
	zIndex: number?,
	parent: Instance?,
}

function Components.Pill(text: string, props: PillProps?): Frame
	local p: PillProps = props or {}
	local swatch = Theme.role(p.role or "premium")
	local pill = blank("Pill", UDim2.fromOffset(0, 28))
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundTransparency = 0
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Position = p.position or UDim2.new()
	pill.AnchorPoint = p.anchor or Vector2.zero
	pill.Rotation = p.rotation or 0
	pill.LayoutOrder = p.layoutOrder or 0
	pill.ZIndex = p.zIndex or 1
	corner(pill, Theme.Radius.pill)
	outline(pill, 2.5)
	faceGradient(pill, swatch)
	pad(pill, 0, 12, 0, 12)
	local label = makeText("small", text, { size = UDim2.fromScale(0, 1), color = swatch.text })
	label.AutomaticSize = Enum.AutomaticSize.X
	label.TextTruncate = Enum.TextTruncate.None
	label.Parent = pill
	if p.parent then
		pill.Parent = p.parent
	end
	return pill
end

---------------------------------------------------------------------------
-- SectionHeader: accent pill + title + faint underline
---------------------------------------------------------------------------
function Components.SectionHeader(text: string, theme: ThemeName?, layoutOrder: number?, parent: Instance?): Frame
	local swatch = Theme.menu(theme or "neutral")
	local root = blank("SectionHeader", UDim2.new(1, 0, 0, 40))
	root.LayoutOrder = layoutOrder or 0

	local accent = blank("Accent", UDim2.fromOffset(8, 26))
	accent.BackgroundTransparency = 0
	accent.BackgroundColor3 = Color3.new(1, 1, 1)
	accent.AnchorPoint = Vector2.new(0, 0.5)
	accent.Position = UDim2.new(0, 2, 0.5, -2)
	corner(accent, Theme.Radius.pill)
	outline(accent, 2)
	faceGradient(accent, swatch)
	accent.Parent = root

	makeText("title", text, {
		name = "Title",
		size = UDim2.new(1, -20, 1, -4),
		position = UDim2.fromOffset(20, 0),
		align = Enum.TextXAlignment.Left,
		parent = root,
	})

	local line = blank("Underline", UDim2.new(1, 0, 0, Theme.Stroke.divider))
	line.BackgroundTransparency = 0.35
	line.BackgroundColor3 = P.line
	line.AnchorPoint = Vector2.new(0, 1)
	line.Position = UDim2.fromScale(0, 1)
	corner(line, Theme.Radius.pill)
	line.Parent = root

	if parent then
		root.Parent = parent
	end
	return root
end

---------------------------------------------------------------------------
-- Card: raised container on the canvas
---------------------------------------------------------------------------
export type CardProps = {
	size: UDim2?,
	name: string?,
	featured: boolean?, -- gold outline for the item you want looked at first
	padding: number?,
	layout: ("list" | "none")?,
	gap: number?,
	layoutOrder: number?,
	parent: Instance?,
}

export type Card = {
	root: Frame,
	content: Frame,
	setFeatured: (featured: boolean) -> (),
}

function Components.Card(props: CardProps?): Card
	local p: CardProps = props or {}
	local root = blank(p.name or "Card", p.size or UDim2.new(1, 0, 0, 120))
	root.BackgroundTransparency = 0
	root.BackgroundColor3 = Color3.new(1, 1, 1)
	root.LayoutOrder = p.layoutOrder or 0
	corner(root, px(Theme.Radius.card))
	local stroke = outline(root, Theme.Stroke.card)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(P.duskRaisedHi, P.duskRaised)
	g.Parent = root

	local content = blank("Content")
	content.ZIndex = 2
	pad(content, p.padding or SP.md)
	if (p.layout or "list") == "list" then
		list(content, Enum.FillDirection.Vertical, p.gap or SP.sm, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	end
	content.Parent = root

	local function setFeatured(featured: boolean)
		stroke.Color = if featured then P.gold else P.ink
		stroke.Thickness = if featured then Theme.Stroke.card + 1 else Theme.Stroke.card
	end
	setFeatured(p.featured == true)

	if p.parent then
		root.Parent = p.parent
	end
	return { root = root, content = content, setFeatured = setFeatured }
end

---------------------------------------------------------------------------
-- Row and Grid helpers
---------------------------------------------------------------------------
export type RowProps = {
	height: number,
	gap: number?,
	align: Enum.HorizontalAlignment?,
	name: string?,
	layoutOrder: number?,
	parent: Instance?,
}

-- A full-width horizontal strip with a centred UIListLayout.
function Components.Row(props: RowProps): Frame
	local row = blank(props.name or "Row", UDim2.new(1, 0, 0, props.height))
	row.LayoutOrder = props.layoutOrder or 0
	list(row, Enum.FillDirection.Horizontal, props.gap or SP.md, props.align or Enum.HorizontalAlignment.Center)
	if props.parent then
		row.Parent = props.parent
	end
	return row
end

-- Adds a UIGridLayout. Pair the container with AutomaticSize = Y when it sits in a list.
function Components.Grid(parent: Instance, cell: Vector2, gap: number?): UIGridLayout
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	grid.CellPadding = UDim2.fromOffset(gap or SP.md, gap or SP.md)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = parent
	return grid
end

---------------------------------------------------------------------------
-- Pattern: soft diagonal "candy bands" tinted with the menu colour.
-- Uses the registered "pattern" tile if you added one.
---------------------------------------------------------------------------
function Components.Pattern(parent: GuiObject, color: Color3, radius: UDim?): GuiObject
	local tile = Icons.get("pattern")
	local result: GuiObject
	if tile then
		local image = Instance.new("ImageLabel")
		image.Name = "Pattern"
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = tile
		image.ImageColor3 = color
		image.ImageTransparency = 0.9
		image.ScaleType = Enum.ScaleType.Tile
		image.TileSize = UDim2.fromOffset(96, 96)
		result = image
	else
		local bands = blank("Pattern")
		bands.BackgroundTransparency = 0
		bands.BackgroundColor3 = color
		local g = Instance.new("UIGradient")
		g.Rotation = 32
		local keys: { NumberSequenceKeypoint } = {}
		local segments = 12 -- 6 soft bands
		for i = 0, segments do
			local value = if i % 2 == 0 then 1 else 0.9
			table.insert(keys, NumberSequenceKeypoint.new(i / segments, value))
		end
		g.Transparency = NumberSequence.new(keys)
		g.Parent = bands
		result = bands
	end
	corner(result, radius or px(Theme.Radius.panel))
	result.Parent = parent
	return result
end

---------------------------------------------------------------------------
-- Sunburst: rotating rays behind a featured item
---------------------------------------------------------------------------
export type SunburstProps = {
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	rays: number?, -- even number; default 16
	transparency: number?, -- brightest ray transparency; default 0.35
	spin: boolean?, -- default true (off under Reduced Motion)
	zIndex: number?,
	window: Window?, -- loop is paused while this window is closed
	parent: Instance?,
}

export type Sunburst = {
	root: Frame,
	spinner: Frame,
	loop: Tween?,
}

function Components.Sunburst(props: SunburstProps?): Sunburst
	local p: SunburstProps = props or {}
	local color = p.color or P.gold
	local root = blank("Sunburst", p.size or UDim2.fromScale(1.4, 1.4))
	root.AnchorPoint = p.anchor or Vector2.new(0.5, 0.5)
	root.Position = p.position or UDim2.fromScale(0.5, 0.5)
	root.ZIndex = p.zIndex or 1
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = root

	local spinner = blank("Spinner")
	spinner.AnchorPoint = Vector2.new(0.5, 0.5)
	spinner.Position = UDim2.fromScale(0.5, 0.5)
	spinner.Parent = root

	local art = Icons.get("sunburst")
	if art then
		local image = Instance.new("ImageLabel")
		image.Name = "Rays"
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = art
		image.ImageColor3 = color
		image.ImageTransparency = p.transparency or 0.35
		image.Parent = spinner
	else
		local t = p.transparency or 0.35
		local bars = math.max(2, math.floor((p.rays or 16) / 2))
		local fade = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.8),
			NumberSequenceKeypoint.new(0.42, t),
			NumberSequenceKeypoint.new(0.58, t),
			NumberSequenceKeypoint.new(0.85, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		})
		for i = 0, bars - 1 do
			-- Each bar is two opposite rays; Rotation turns around the bar's centre.
			local bar = blank("Ray" .. i, UDim2.fromScale(0.09, 1))
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Position = UDim2.fromScale(0.5, 0.5)
			bar.Rotation = i * 180 / bars
			bar.BackgroundTransparency = 0
			bar.BackgroundColor3 = color
			corner(bar, Theme.Radius.pill)
			local g = Instance.new("UIGradient")
			g.Rotation = 90
			g.Transparency = fade
			g.Parent = bar
			bar.Parent = spinner
		end
	end

	local loop: Tween? = nil
	if p.spin ~= false and not Theme.isReducedMotion() then
		local t = TweenService:Create(
			spinner,
			TweenInfo.new(M.sunburstPeriod, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Rotation = 360 }
		)
		adoptLoop(p.window, t)
		loop = t
	end

	if p.parent then
		root.Parent = p.parent
	end
	return { root = root, spinner = spinner, loop = loop }
end

---------------------------------------------------------------------------
-- Button: the 3D tactile slab. Face sits on a darker lip; press sinks it.
---------------------------------------------------------------------------
export type ButtonProps = {
	text: string?,
	role: RoleName?, -- default "go"
	swatch: Swatch?, -- overrides role (used by themed header and HUD buttons)
	icon: string?, -- icon registry name
	size: UDim2?, -- default 200 x 56
	position: UDim2?,
	anchor: Vector2?,
	depth: number?, -- lip height, default 6
	round: boolean?, -- pill / circle ends
	textStyle: TextStyleName?, -- default "button"
	name: string?,
	layoutOrder: number?,
	zIndex: number?,
	parent: Instance?,
	onActivated: (() -> ())?,
}

export type Button = {
	root: Frame,
	hit: TextButton, -- the input surface (also the gamepad selection target)
	face: Frame,
	label: TextLabel,
	setText: (text: string) -> (),
	setRole: (role: RoleName) -> (),
	setSwatch: (swatch: Swatch) -> (),
	setIcon: (name: string?) -> (),
	setEnabled: (enabled: boolean) -> (),
	isEnabled: () -> boolean,
	setCallback: (callback: (() -> ())?) -> (),
	destroy: () -> (),
}

local function offsetOf(value: UDim2, axis: "X" | "Y", fallback: number): number
	local udim = if axis == "X" then value.X else value.Y
	if udim.Scale == 0 and udim.Offset > 0 then
		return udim.Offset
	end
	return fallback
end

function Components.Button(props: ButtonProps): Button
	local swatch: Swatch = props.swatch or Theme.role(props.role or "go")
	local depth = props.depth or S.depth
	local radius = if props.round then Theme.Radius.pill else px(Theme.Radius.button)
	local size = props.size or UDim2.fromOffset(200, S.buttonH)
	local width = offsetOf(size, "X", 200)
	local height = offsetOf(size, "Y", S.buttonH)
	local hasText = props.text ~= nil and props.text ~= ""
	local iconPx = math.floor((height - depth) * (if hasText then 0.6 else 0.66))

	local enabled = true
	local hovering = false
	local pressed = false
	local callback = props.onActivated

	local root = blank(props.name or "Button", size)
	root.Position = props.position or UDim2.new()
	root.AnchorPoint = props.anchor or Vector2.zero
	root.LayoutOrder = props.layoutOrder or 0
	if props.zIndex then
		root.ZIndex = props.zIndex
	end

	-- Body is centre-anchored so hover and press scale around the middle.
	local body = blank("Body")
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Parent = root
	local fx = Instance.new("UIScale")
	fx.Name = "Fx"
	fx.Parent = body

	local base = blank("Base")
	base.BackgroundTransparency = 0
	base.BackgroundColor3 = swatch.shade
	corner(base, radius)
	outline(base, Theme.Stroke.button)
	base.Parent = body

	local face = blank("Face", UDim2.new(1, 0, 1, -depth))
	face.BackgroundTransparency = 0
	face.BackgroundColor3 = Color3.new(1, 1, 1) -- the gradient supplies the colour
	face.ZIndex = 2
	corner(face, radius)
	local gradient = faceGradient(face, swatch)
	face.Parent = body

	local content = blank("Content")
	local sidePad = if hasText then SP.md else 2
	pad(content, 2, sidePad, 2, sidePad)
	list(content, Enum.FillDirection.Horizontal, SP.sm)
	content.Parent = face

	local label, labelStroke = makeText(props.textStyle or "button", props.text or "", {
		name = "Label",
		scaled = true,
		size = UDim2.fromScale(1, 1),
		color = swatch.text,
		layoutOrder = 2,
	})
	label.Parent = content

	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	-- Grow the invisible tap pad so a small visual still gets a full touch target.
	hit.Size = UDim2.new(1, math.max(0, S.touchMin - width), 1, math.max(0, S.touchMin - height))
	hit.ZIndex = 10
	hit.Selectable = true
	hit.SelectionImageObject = selectionRing(radius)
	hit.Parent = root

	local iconObj: GuiObject? = nil

	local function layoutContent()
		label.Visible = label.Text ~= ""
		if iconObj and label.Visible then
			label.Size = UDim2.new(1, -(iconPx + SP.sm), 1, 0)
		else
			label.Size = UDim2.fromScale(1, 1)
		end
	end

	local function setIcon(name: string?)
		if iconObj then
			iconObj:Destroy()
			iconObj = nil
		end
		if name then
			local obj = Icons.make(name, UDim2.fromOffset(iconPx, iconPx))
			obj.LayoutOrder = 1
			obj.Parent = content
			iconObj = obj
		end
		layoutContent()
	end

	local function setSwatch(sw: Swatch)
		swatch = sw
		base.BackgroundColor3 = sw.shade
		gradient.Color = Theme.faceSequence(sw)
		label.TextColor3 = sw.text
		if labelStroke then
			labelStroke.Enabled = sw.textStroke ~= nil
			if sw.textStroke then
				labelStroke.Color = sw.textStroke
			end
		end
	end

	local function settle(kind: "press" | "release" | "hover")
		local scaleGoal = 1
		if not Theme.isReducedMotion() then
			scaleGoal = if pressed then M.pressScale elseif hovering then M.hoverScale else 1
		end
		local faceGoal = UDim2.fromOffset(0, if pressed then depth - 2 else 0)
		local time: number = M.hoverTime
		local style: Enum.EasingStyle = Enum.EasingStyle.Quad
		if kind == "press" then
			time = M.pressTime
		elseif kind == "release" then
			time = M.releaseTime
			style = Enum.EasingStyle.Back
		end
		tween(fx, time, style, Enum.EasingDirection.Out, { Scale = scaleGoal })
		tween(face, time, style, Enum.EasingDirection.Out, { Position = faceGoal })
	end

	local function isPointer(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end

	hit.MouseEnter:Connect(function()
		if enabled then
			hovering = true
			settle("hover")
			Components.playSound("hover")
		end
	end)
	hit.MouseLeave:Connect(function()
		if hovering or pressed then
			hovering = false
			pressed = false
			settle("release")
		end
	end)
	hit.SelectionGained:Connect(function()
		if enabled then
			hovering = true
			settle("hover")
		end
	end)
	hit.SelectionLost:Connect(function()
		hovering = false
		pressed = false
		settle("release")
	end)
	hit.InputBegan:Connect(function(input: InputObject)
		if enabled and isPointer(input) then
			pressed = true
			settle("press")
		end
	end)
	hit.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			hovering = false -- touch has no reliable MouseLeave; never stay "hovered"
		end
		if pressed and isPointer(input) then
			pressed = false
			settle("release")
		end
	end)
	hit.Activated:Connect(function()
		if not enabled then
			return
		end
		Components.playSound("click")
		if callback then
			callback()
		end
	end)

	local function setEnabled(value: boolean)
		enabled = value
		hit.Selectable = value
		if not value and (hovering or pressed) then
			hovering = false
			pressed = false
			settle("release")
		end
	end

	setIcon(props.icon)
	if props.parent then
		root.Parent = props.parent
	end

	return {
		root = root,
		hit = hit,
		face = face,
		label = label,
		setText = function(text: string)
			label.Text = text
			layoutContent()
		end,
		setRole = function(role: RoleName)
			setSwatch(Theme.role(role))
		end,
		setSwatch = setSwatch,
		setIcon = setIcon,
		setEnabled = setEnabled,
		isEnabled = function(): boolean
			return enabled
		end,
		setCallback = function(fn: (() -> ())?)
			callback = fn
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

---------------------------------------------------------------------------
-- StateButton: claim / claimed / locked / skip / pending
---------------------------------------------------------------------------
export type ClaimState = "claim" | "claimed" | "locked" | "skip" | "pending"

type StateSpec = { role: RoleName, text: string, icon: string?, enabled: boolean }

local STATES: { [ClaimState]: StateSpec } = {
	claim = { role = "go", text = "CLAIM", icon = nil, enabled = true },
	claimed = { role = "done", text = "CLAIMED", icon = "check", enabled = false },
	locked = { role = "locked", text = "LOCKED", icon = "lock", enabled = false },
	skip = { role = "premium", text = "SKIP", icon = "robux", enabled = true },
	pending = { role = "neutral", text = "...", icon = nil, enabled = false },
}

export type StateButtonProps = {
	state: ClaimState?,
	size: UDim2?,
	texts: { [string]: string }?, -- per-state caption overrides, e.g. { claimed = "OWNED" }
	icons: { [string]: string }?, -- per-state icon overrides
	position: UDim2?,
	anchor: Vector2?,
	name: string?,
	layoutOrder: number?,
	window: Window?, -- the claim glow loop pauses while this window is closed
	parent: Instance?,
	onActivated: ((state: ClaimState) -> ())?,
}

export type StateButton = {
	root: Frame,
	button: Button,
	setState: (state: ClaimState) -> (),
	getState: () -> ClaimState,
}

function Components.StateButton(props: StateButtonProps): StateButton
	local state: ClaimState = props.state or "claim"
	local button = Components.Button({
		text = "",
		size = props.size or UDim2.fromOffset(180, S.buttonH),
		position = props.position,
		anchor = props.anchor,
		name = props.name or "StateButton",
		layoutOrder = props.layoutOrder,
	})

	-- Breathing outline shown only while claimable (a second, non-colour cue).
	local glow = blank("Glow", UDim2.new(1, 10, 1, 10))
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.ZIndex = 0
	corner(glow, px(Theme.Radius.button + 5))
	local glowStroke = outline(glow, 4, Theme.Roles.go.top)
	glow.Visible = false
	glow.Parent = button.root
	local glowLoop: Tween? = nil

	local window = props.window
	local texts = props.texts
	local icons = props.icons
	local onActivated = props.onActivated

	local function stopGlow()
		local current = glowLoop
		if current then
			current:Cancel()
			if window then
				window.removeLoop(current)
			end
			glowLoop = nil
		end
		glow.Visible = false
	end

	local function setState(newState: ClaimState)
		state = newState
		local spec = STATES[newState]
		button.setRole(spec.role)
		local caption = (texts and texts[newState]) or spec.text
		button.setText(caption)
		local iconName = (icons and icons[newState]) or spec.icon
		button.setIcon(iconName)
		button.setEnabled(spec.enabled)
		stopGlow()
		if newState == "claim" then
			glow.Visible = true
			glowStroke.Transparency = 0.35
			if not Theme.isReducedMotion() then
				local t = TweenService:Create(
					glowStroke,
					TweenInfo.new(M.glowTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Transparency = 0.85 }
				)
				adoptLoop(window, t)
				glowLoop = t
			end
		end
	end

	button.setCallback(function()
		if onActivated then
			onActivated(state)
		end
	end)
	setState(state)

	if props.parent then
		button.root.Parent = props.parent
	end
	return {
		root = button.root,
		button = button,
		setState = setState,
		getState = function(): ClaimState
			return state
		end,
	}
end

---------------------------------------------------------------------------
-- CurrencyButton: price with a currency icon ("robux", "coin", "gem", ...)
---------------------------------------------------------------------------
export type CurrencyButtonProps = {
	price: number | string,
	currency: string?, -- icon registry name, default "robux"
	role: RoleName?, -- default "go" (a purchase is the primary action)
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	name: string?,
	layoutOrder: number?,
	parent: Instance?,
	onActivated: (() -> ())?,
}

export type CurrencyButton = {
	root: Frame,
	button: Button,
	setPrice: (price: number | string) -> (),
}

local function formatPrice(price: number | string, currency: string): string
	if type(price) == "number" then
		if currency ~= "robux" and price >= 100000 then
			return Theme.formatShort(price)
		end
		return Theme.formatComma(price)
	end
	return tostring(price)
end

function Components.CurrencyButton(props: CurrencyButtonProps): CurrencyButton
	local currency = props.currency or "robux"
	local button = Components.Button({
		text = formatPrice(props.price, currency),
		role = props.role or "go",
		icon = currency,
		textStyle = "number",
		size = props.size or UDim2.fromOffset(150, S.buttonH),
		position = props.position,
		anchor = props.anchor,
		name = props.name or "Price",
		layoutOrder = props.layoutOrder,
		parent = props.parent,
		onActivated = props.onActivated,
	})
	return {
		root = button.root,
		button = button,
		setPrice = function(price: number | string)
			button.setText(formatPrice(price, currency))
		end,
	}
end

---------------------------------------------------------------------------
-- CloseButton and HeaderAction
---------------------------------------------------------------------------
function Components.CloseButton(onActivated: (() -> ())?): Button
	return Components.Button({
		name = "Close",
		role = "danger",
		icon = "close",
		round = true,
		depth = S.depthSmall,
		size = UDim2.fromOffset(S.close, S.close),
		onActivated = onActivated,
	})
end

export type HeaderActionProps = {
	text: string?,
	icon: string?,
	role: RoleName?, -- default "info"
	width: number?,
	onActivated: () -> (),
}

function Components.HeaderAction(props: HeaderActionProps): Button
	local hasText = props.text ~= nil and props.text ~= ""
	return Components.Button({
		name = "HeaderAction",
		text = props.text,
		icon = props.icon,
		role = props.role or "info",
		round = not hasText,
		depth = S.depthSmall,
		textStyle = "small",
		size = UDim2.fromOffset(props.width or (if hasText then 132 else S.close), S.close),
		onActivated = props.onActivated,
	})
end

---------------------------------------------------------------------------
-- HudButton: menu launcher in the HUD, coloured with the menu's theme
---------------------------------------------------------------------------
export type HudButtonProps = {
	label: string,
	icon: string,
	theme: ThemeName,
	layoutOrder: number?,
	parent: Instance?,
	onActivated: (() -> ())?,
}

export type HudButton = {
	root: Frame,
	button: Button,
	setBadge: (visible: boolean) -> (),
}

function Components.HudButton(props: HudButtonProps): HudButton
	local size = S.hudButton
	local root = blank("Hud_" .. props.label, UDim2.fromOffset(size, size + 22))
	root.LayoutOrder = props.layoutOrder or 0

	local button = Components.Button({
		name = "Slab",
		icon = props.icon,
		swatch = Theme.menu(props.theme),
		depth = S.depthSmall + 1,
		size = UDim2.fromOffset(size, size),
		onActivated = props.onActivated,
		parent = root,
	})

	makeText("small", props.label, {
		name = "Caption",
		scaled = true,
		size = UDim2.new(1, 16, 0, 22),
		position = UDim2.new(0.5, 0, 1, 0),
		anchor = Vector2.new(0.5, 1),
		parent = root,
	})

	-- Notification badge: colour + "!" glyph, so it reads without colour vision.
	local badge = blank("Badge", UDim2.fromOffset(24, 24))
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = Theme.Roles.danger.bottom
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromOffset(size - 4, 4)
	badge.ZIndex = 20
	badge.Visible = false
	corner(badge, Theme.Radius.pill)
	outline(badge, 2.5)
	makeText("small", "!", { size = UDim2.fromScale(1, 1), scaled = true, parent = badge })
	badge.Parent = root

	if props.parent then
		root.Parent = props.parent
	end
	return {
		root = root,
		button = button,
		setBadge = function(visible: boolean)
			badge.Visible = visible
		end,
	}
end

---------------------------------------------------------------------------
-- Window: panel + themed header slab + close + optional header action
---------------------------------------------------------------------------
export type WindowProps = {
	name: string,
	title: string,
	theme: ThemeName?,
	icon: string?,
	size: Vector2?, -- design units, default Theme.Size.window
	headerAction: HeaderActionProps?,
	pattern: boolean?, -- default true
	scroll: boolean?, -- default true (keeps content reachable on short phones)
	bodyLayout: ("list" | "none")?, -- default "list"
	bodyGap: number?,
}

function Components.Window(props: WindowProps): Window
	local themeName: ThemeName = props.theme or "neutral"
	local swatch = Theme.menu(themeName)
	local design = props.size or S.window
	local inset = S.headerInset
	local headerH = S.headerH
	local lip = S.depth

	local root = blank(props.name, UDim2.fromOffset(design.X, design.Y))
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Visible = false
	local fitScale = Instance.new("UIScale")
	fitScale.Name = "Fit"
	fitScale.Parent = root

	local panel = blank("Panel")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundTransparency = 0
	panel.BackgroundColor3 = P.dusk
	panel.Active = true -- sinks taps so they never reach the backdrop (which closes the menu)
	corner(panel, px(Theme.Radius.panel))
	outline(panel, Theme.Stroke.panel)
	panel.Parent = root
	local motionScale = Instance.new("UIScale")
	motionScale.Name = "Motion"
	motionScale.Parent = panel

	if props.pattern ~= false then
		Components.Pattern(panel, swatch.top)
	end

	-- Header: an inset tactile slab in the menu colour.
	local header = blank("Header", UDim2.new(1, -inset * 2, 0, headerH))
	header.Position = UDim2.fromOffset(inset, inset)
	header.ZIndex = 2
	header.Parent = panel

	local headerBase = blank("Base")
	headerBase.BackgroundTransparency = 0
	headerBase.BackgroundColor3 = swatch.shade
	corner(headerBase, px(Theme.Radius.header))
	outline(headerBase, Theme.Stroke.card)
	headerBase.Parent = header

	local headerFace = blank("Face", UDim2.new(1, 0, 1, -lip))
	headerFace.BackgroundTransparency = 0
	headerFace.BackgroundColor3 = Color3.new(1, 1, 1)
	headerFace.ZIndex = 2
	corner(headerFace, px(Theme.Radius.header))
	faceGradient(headerFace, swatch)
	headerFace.Parent = header

	local faceH = headerH - lip
	local left = SP.md
	if props.icon then
		local chip = Icons.make(props.icon, UDim2.fromOffset(faceH - 18, faceH - 18))
		chip.AnchorPoint = Vector2.new(0, 0.5)
		chip.Position = UDim2.new(0, left, 0.5, 0)
		chip.Parent = headerFace
		left += faceH - 18 + SP.sm
	end

	-- Right cluster: [header action] [close]
	local cluster = blank("Actions", UDim2.fromOffset(0, S.close))
	cluster.AutomaticSize = Enum.AutomaticSize.X
	cluster.AnchorPoint = Vector2.new(1, 0.5)
	cluster.Position = UDim2.new(1, -SP.sm - 2, 0.5, 0)
	list(cluster, Enum.FillDirection.Horizontal, SP.sm, Enum.HorizontalAlignment.Right)
	cluster.Parent = headerFace

	local rightW = S.close + SP.sm + 2
	local actionButton: Button? = nil
	local actionProps = props.headerAction
	if actionProps then
		local action = Components.HeaderAction(actionProps)
		action.root.LayoutOrder = 1
		action.root.Parent = cluster
		actionButton = action
		rightW += action.root.Size.X.Offset + SP.sm
	end

	local title = makeText("display", props.title, {
		name = "Title",
		scaled = true,
		align = Enum.TextXAlignment.Left,
		size = UDim2.new(1, -(left + rightW + SP.md), 1, -14),
		position = UDim2.new(0, left, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		color = swatch.text,
	})
	title.Parent = headerFace

	-- Body
	local top = inset + headerH + SP.md
	local body: GuiObject
	if props.scroll ~= false then
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "Body"
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new()
		scroll.ScrollBarThickness = 6
		scroll.ScrollBarImageColor3 = P.textLow
		scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
		body = scroll
	else
		body = blank("Body")
	end
	body.Position = UDim2.fromOffset(SP.lg, top)
	body.Size = UDim2.new(1, -SP.lg * 2, 1, -(top + SP.lg))
	body.ZIndex = 2
	-- Padding keeps ink outlines, glows and hover growth from being clipped.
	pad(body, SP.sm)
	if (props.bodyLayout or "list") == "list" then
		list(body, Enum.FillDirection.Vertical, props.bodyGap or SP.md, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	end
	body.Parent = panel

	local loops: { Tween } = {}
	local window: Window

	local close = Components.CloseButton(function()
		window.requestClose()
	end)
	close.root.LayoutOrder = 2
	close.root.Parent = cluster

	window = {
		name = props.name,
		theme = themeName,
		designSize = design,
		root = root,
		panel = panel,
		header = header,
		body = body,
		closeButton = close,
		headerActionButton = actionButton,
		fitScale = fitScale,
		motionScale = motionScale,
		loops = loops,
		defaultSelection = nil,
		requestClose = function()
			root.Visible = false -- replaced by LihFolkUIController.register
		end,
		setTitle = function(text: string)
			title.Text = text
		end,
		addLoop = function(t: Tween)
			table.insert(loops, t)
		end,
		removeLoop = function(t: Tween)
			local index = table.find(loops, t)
			if index then
				table.remove(loops, index)
			end
		end,
	}
	return window
end

---------------------------------------------------------------------------
-- ProgressBar: recessed track, glossy fill, centred label
---------------------------------------------------------------------------
export type ProgressBarProps = {
	value: number?, -- 0..1
	role: RoleName?, -- fill colour, default "premium"
	swatch: Swatch?,
	text: string?,
	size: UDim2?, -- default full width x 30
	name: string?,
	layoutOrder: number?,
	parent: Instance?,
}

export type ProgressBar = {
	root: Frame,
	setValue: (value: number, animate: boolean?) -> (),
	getValue: () -> number,
	setText: (text: string) -> (),
}

function Components.ProgressBar(props: ProgressBarProps?): ProgressBar
	local p: ProgressBarProps = props or {}
	local swatch = p.swatch or Theme.role(p.role or "premium")
	local size = p.size or UDim2.new(1, 0, 0, S.progressH)
	local height = offsetOf(size, "Y", S.progressH)
	local value = 0

	local root = blank(p.name or "ProgressBar", size)
	root.BackgroundTransparency = 0
	root.BackgroundColor3 = P.duskSunken
	root.LayoutOrder = p.layoutOrder or 0
	corner(root, Theme.Radius.pill)
	outline(root, Theme.Stroke.card)
	recess(root, Theme.Radius.pill)

	local area = blank("FillArea", UDim2.new(1, -8, 1, -8))
	area.Position = UDim2.fromOffset(4, 4)
	area.ZIndex = 2
	area.Parent = root

	local fill = blank("Fill", UDim2.fromScale(0, 1))
	fill.BackgroundTransparency = 0
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.Visible = false
	corner(fill, Theme.Radius.pill)
	faceGradient(fill, swatch)
	local minWidth = Instance.new("UISizeConstraint")
	minWidth.MinSize = Vector2.new(height - 8, 0) -- a sliver never renders as a squashed blob
	minWidth.Parent = fill
	fill.Parent = area

	local gloss = blank("Gloss", UDim2.new(1, -10, 0.3, 0))
	gloss.Position = UDim2.new(0, 5, 0.12, 0)
	gloss.BackgroundTransparency = 0.6
	gloss.BackgroundColor3 = P.white
	corner(gloss, Theme.Radius.pill)
	gloss.Parent = fill

	local label = makeText("small", p.text or "", {
		name = "Label",
		scaled = true,
		size = UDim2.new(1, -16, 1, -6),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		zIndex = 3,
	})
	label.Parent = root

	local function setValue(v: number, animate: boolean?)
		value = math.clamp(v, 0, 1)
		local goal = UDim2.fromScale(value, 1)
		if value <= 0 then
			fill.Visible = false
			fill.Size = goal
			return
		end
		if not fill.Visible then
			fill.Size = UDim2.fromScale(0, 1)
			fill.Visible = true
		end
		if animate ~= false and not Theme.isReducedMotion() then
			tween(fill, M.fillTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Size = goal })
		else
			fill.Size = goal
		end
	end
	setValue(p.value or 0, false)

	if p.parent then
		root.Parent = p.parent
	end
	return {
		root = root,
		setValue = setValue,
		getValue = function(): number
			return value
		end,
		setText = function(text: string)
			label.Text = text
		end,
	}
end

---------------------------------------------------------------------------
-- TierCompare: [NOW card] -> [NEXT card]
---------------------------------------------------------------------------
export type Tier = {
	title: string, -- "Rebirth 3"
	value: string, -- "x2.5"
	caption: string?, -- "Cash multiplier"
}

export type TierCompareProps = {
	current: Tier,
	nextTier: Tier,
	theme: ThemeName?,
	height: number?, -- default 176
	layoutOrder: number?,
	window: Window?,
	parent: Instance?,
}

export type TierCompare = {
	root: Frame,
	setTiers: (current: Tier, nextTier: Tier) -> (),
}

function Components.TierCompare(props: TierCompareProps): TierCompare
	local swatch = Theme.menu(props.theme or "rebirth")
	local height = props.height or 176
	local root = blank("TierCompare", UDim2.new(1, 0, 0, height))
	root.LayoutOrder = props.layoutOrder or 0
	list(root, Enum.FillDirection.Horizontal, SP.md)

	local function tierCard(order: number, tag: string, featured: boolean): (TextLabel, TextLabel, TextLabel)
		local card = Components.Card({
			name = if featured then "Next" else "Current",
			size = UDim2.new(0.5, -(28 + SP.md), 1, 0),
			featured = featured,
			gap = SP.xs,
			layoutOrder = order,
			parent = root,
		})
		Components.Pill(tag, { role = if featured then "go" else "neutral", layoutOrder = 1, parent = card.content })
		local titleLabel = makeText("small", "", { name = "Title", color = P.textMid, layoutOrder = 2, parent = card.content })
		local valueLabel = makeText("number", "", {
			name = "Value",
			scaled = true,
			size = UDim2.new(1, 0, 0, 44),
			color = if featured then swatch.top else P.textHi,
			layoutOrder = 3,
			parent = card.content,
		})
		local captionLabel = makeText("caption", "", { name = "Caption", color = P.textLow, layoutOrder = 4, parent = card.content })
		return titleLabel, valueLabel, captionLabel
	end

	local nowTitle, nowValue, nowCaption = tierCard(1, "NOW", false)

	local arrowSlot = blank("Arrow", UDim2.new(0, 56, 1, 0))
	arrowSlot.LayoutOrder = 2
	arrowSlot.Parent = root
	local arrow = Icons.make("arrow_right", UDim2.fromOffset(48, 48))
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.new(0.5, -3, 0.5, 0)
	arrow.Parent = arrowSlot
	if not Theme.isReducedMotion() then
		local nudge = TweenService:Create(
			arrow,
			TweenInfo.new(M.nudgeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.new(0.5, 3, 0.5, 0) }
		)
		adoptLoop(props.window, nudge)
	end

	local nextTitle, nextValue, nextCaption = tierCard(3, "NEXT", true)

	local function setTiers(current: Tier, nextTier: Tier)
		nowTitle.Text = current.title
		nowValue.Text = current.value
		nowCaption.Text = current.caption or ""
		nextTitle.Text = nextTier.title
		nextValue.Text = nextTier.value
		nextCaption.Text = nextTier.caption or ""
	end
	setTiers(props.current, props.nextTier)

	if props.parent then
		root.Parent = props.parent
	end
	return { root = root, setTiers = setTiers }
end

---------------------------------------------------------------------------
-- RewardCard: day tag, icon, amount, state button (+ featured sunburst)
---------------------------------------------------------------------------
export type RewardCardProps = {
	title: string, -- "DAY 3"
	amount: string, -- "x500"
	icon: string,
	state: ClaimState?,
	featured: boolean?,
	tag: string?, -- pill text for featured cards, e.g. "BIG REWARD"
	size: UDim2?, -- default 156 x 196
	layoutOrder: number?,
	window: Window?,
	parent: Instance?,
	onActivated: ((state: ClaimState) -> ())?,
}

export type RewardCard = {
	root: Frame,
	card: Card,
	button: StateButton,
	setState: (state: ClaimState) -> (),
	setAmount: (amount: string) -> (),
}

function Components.RewardCard(props: RewardCardProps): RewardCard
	local featured = props.featured == true
	local card = Components.Card({
		name = "Reward_" .. props.title,
		size = props.size or UDim2.fromOffset(156, 196),
		featured = featured,
		layout = "none",
		padding = SP.sm + 2,
		layoutOrder = props.layoutOrder,
	})
	local content = card.content
	local buttonH = S.touchMin
	local amountH = 26

	makeText("small", props.title, {
		name = "Day",
		scaled = true,
		size = UDim2.new(1, 0, 0, 22),
		color = if featured then P.gold else P.textMid,
		parent = content,
	})

	local iconArea = blank("IconArea", UDim2.new(1, 0, 1, -(24 + amountH + buttonH + SP.xs * 2)))
	iconArea.Position = UDim2.fromOffset(0, 24)
	iconArea.Parent = content

	if featured then
		Components.Sunburst({
			size = UDim2.fromScale(1.5, 1.5),
			zIndex = 0,
			window = props.window,
			parent = iconArea,
		})
		Components.Pill(props.tag or "BIG REWARD", {
			role = "premium",
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, 0, 0, -2),
			rotation = 6,
			zIndex = 5,
			parent = content,
		})
	end

	local icon = Icons.make(props.icon, UDim2.fromScale(0.95, 0.95))
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.ZIndex = 2
	icon.Parent = iconArea

	local amount = makeText("number", props.amount, {
		name = "Amount",
		scaled = true,
		size = UDim2.new(1, 0, 0, amountH),
		position = UDim2.new(0, 0, 1, -(buttonH + SP.xs)),
		anchor = Vector2.new(0, 1),
		parent = content,
	})

	local stateButton = Components.StateButton({
		state = props.state or "locked",
		size = UDim2.new(1, 0, 0, buttonH),
		position = UDim2.fromScale(0, 1),
		anchor = Vector2.new(0, 1),
		window = props.window,
		onActivated = props.onActivated,
		parent = content,
	})

	-- Claimed: a veil and a check badge, so "done" reads by shape and lightness too.
	local veil = blank("Veil")
	veil.BackgroundTransparency = 0.5
	veil.BackgroundColor3 = P.ink
	veil.ZIndex = 3
	veil.Visible = false
	corner(veil, px(Theme.Radius.card))
	veil.Parent = card.root

	local check = Icons.make("check", UDim2.fromOffset(36, 36))
	check.AnchorPoint = Vector2.new(0.5, 0.5)
	check.Position = UDim2.new(1, -10, 0, 10)
	check.ZIndex = 4
	check.Visible = false
	check.Parent = card.root

	local function setState(state: ClaimState)
		stateButton.setState(state)
		local claimed = state == "claimed"
		veil.Visible = claimed
		check.Visible = claimed
	end
	setState(props.state or "locked")

	if props.parent then
		card.root.Parent = props.parent
	end
	return {
		root = card.root,
		card = card,
		button = stateButton,
		setState = setState,
		setAmount = function(text: string)
			amount.Text = text
		end,
	}
end

---------------------------------------------------------------------------
-- Toggle: pill switch with ON / OFF text (never colour alone)
---------------------------------------------------------------------------
export type ToggleProps = {
	value: boolean?,
	position: UDim2?,
	anchor: Vector2?,
	name: string?,
	layoutOrder: number?,
	parent: Instance?,
	onChanged: ((value: boolean) -> ())?,
}

export type Toggle = {
	root: Frame,
	hit: TextButton,
	set: (value: boolean, silent: boolean?) -> (),
	get: () -> boolean,
}

function Components.Toggle(props: ToggleProps?): Toggle
	local p: ToggleProps = props or {}
	local value = p.value == true
	local w, h = S.toggleW, S.toggleH
	local knob = h - 8
	local onSwatch = Theme.Roles.go
	local offSwatch = Theme.Roles.locked

	local root = blank(p.name or "Toggle", UDim2.fromOffset(w, h))
	root.BackgroundTransparency = 0
	root.BackgroundColor3 = if value then onSwatch.bottom else offSwatch.bottom
	root.Position = p.position or UDim2.new()
	root.AnchorPoint = p.anchor or Vector2.zero
	root.LayoutOrder = p.layoutOrder or 0
	corner(root, Theme.Radius.pill)
	outline(root, Theme.Stroke.card)
	recess(root, Theme.Radius.pill)

	local stateText = makeText("small", "", {
		name = "State",
		scaled = true,
		size = UDim2.new(1, -(knob + 14), 1, -10),
		anchor = Vector2.new(0, 0.5),
		zIndex = 2,
	})
	stateText.Parent = root

	local knobFrame = blank("Knob", UDim2.fromOffset(knob, knob))
	knobFrame.BackgroundTransparency = 0
	knobFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	knobFrame.AnchorPoint = Vector2.new(0, 0.5)
	knobFrame.ZIndex = 3
	corner(knobFrame, Theme.Radius.pill)
	outline(knobFrame, 2.5)
	local kg = Instance.new("UIGradient")
	kg.Rotation = 90
	kg.Color = ColorSequence.new(P.white, Color3.fromHex("#DCD6F5"))
	kg.Parent = knobFrame
	knobFrame.Parent = root

	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	hit.Size = UDim2.new(1, 20, 1, math.max(16, S.touchMin - h))
	hit.ZIndex = 10
	hit.SelectionImageObject = selectionRing(Theme.Radius.pill)
	hit.Parent = root

	local function render(animate: boolean)
		local knobGoal = if value then UDim2.new(1, -(knob + 4), 0.5, 0) else UDim2.new(0, 4, 0.5, 0)
		local colorGoal = if value then onSwatch.bottom else offSwatch.bottom
		stateText.Text = if value then "ON" else "OFF"
		stateText.Position = if value then UDim2.new(0, 8, 0.5, 0) else UDim2.new(0, knob + 6, 0.5, 0)
		if animate and not Theme.isReducedMotion() then
			tween(knobFrame, M.toggleTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Position = knobGoal })
			tween(root, M.toggleTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundColor3 = colorGoal })
		else
			knobFrame.Position = knobGoal
			root.BackgroundColor3 = colorGoal
		end
	end

	local onChanged = p.onChanged
	local function set(newValue: boolean, silent: boolean?)
		if newValue == value then
			return
		end
		value = newValue
		render(true)
		if not silent and onChanged then
			onChanged(value)
		end
	end

	hit.Activated:Connect(function()
		Components.playSound("click")
		set(not value)
	end)
	render(false)

	if p.parent then
		root.Parent = p.parent
	end
	return {
		root = root,
		hit = hit,
		set = set,
		get = function(): boolean
			return value
		end,
	}
end

---------------------------------------------------------------------------
-- SettingRow: icon + label + description + toggle; the whole row is tappable
---------------------------------------------------------------------------
export type SettingRowProps = {
	label: string,
	description: string?,
	icon: string?,
	value: boolean,
	layoutOrder: number?,
	parent: Instance?,
	onChanged: ((value: boolean) -> ())?,
}

export type SettingRow = {
	root: Frame,
	toggle: Toggle,
	hit: TextButton,
}

function Components.SettingRow(props: SettingRowProps): SettingRow
	local hasDescription = props.description ~= nil and props.description ~= ""
	local rowH = if hasDescription then 78 else 64
	local card = Components.Card({
		name = "Setting_" .. props.label,
		size = UDim2.new(1, 0, 0, rowH),
		layout = "none",
		padding = SP.md,
		layoutOrder = props.layoutOrder,
	})
	local content = card.content

	local left = 0
	if props.icon then
		local icon = Icons.make(props.icon, UDim2.fromOffset(40, 40))
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.fromScale(0, 0.5)
		icon.Parent = content
		left = 40 + SP.md
	end

	local textW = -(left + S.toggleW + SP.lg)
	makeText("small", props.label, {
		name = "Label",
		align = Enum.TextXAlignment.Left,
		size = UDim2.new(1, textW, 0, 26),
		position = UDim2.new(0, left, if hasDescription then 0 else 0.5, if hasDescription then 2 else 0),
		anchor = Vector2.new(0, if hasDescription then 0 else 0.5),
		parent = content,
	})
	if hasDescription then
		makeText("caption", props.description :: string, {
			name = "Description",
			align = Enum.TextXAlignment.Left,
			color = P.textLow,
			size = UDim2.new(1, textW, 0, 20),
			position = UDim2.new(0, left, 1, -2),
			anchor = Vector2.new(0, 1),
			parent = content,
		})
	end

	local toggle = Components.Toggle({
		value = props.value,
		anchor = Vector2.new(1, 0.5),
		position = UDim2.fromScale(1, 0.5),
		onChanged = props.onChanged,
		parent = content,
	})
	toggle.hit.Selectable = false -- the row is the single gamepad stop

	local rowHit = Instance.new("TextButton")
	rowHit.Name = "RowHit"
	rowHit.Text = ""
	rowHit.AutoButtonColor = false
	rowHit.BackgroundTransparency = 1
	rowHit.Size = UDim2.fromScale(1, 1)
	rowHit.ZIndex = 5
	rowHit.SelectionImageObject = selectionRing(px(Theme.Radius.card))
	rowHit.Parent = card.root
	rowHit.Activated:Connect(function()
		Components.playSound("click")
		toggle.set(not toggle.get())
	end)

	if props.parent then
		card.root.Parent = props.parent
	end
	return { root = card.root, toggle = toggle, hit = rowHit }
end

---------------------------------------------------------------------------
-- TextInput: recessed field + status line
---------------------------------------------------------------------------
export type InputStatus = "ok" | "error" | "info" | "none"

export type TextInputProps = {
	placeholder: string?,
	maxLength: number?,
	size: UDim2?, -- default full width x (56 + status line)
	name: string?,
	layoutOrder: number?,
	parent: Instance?,
	onSubmit: ((text: string) -> ())?,
	onChanged: ((text: string) -> ())?,
}

export type TextInput = {
	root: Frame,
	box: TextBox,
	getText: () -> string, -- trimmed
	setText: (text: string) -> (),
	clear: () -> (),
	setStatus: (kind: InputStatus, text: string?) -> (),
	shake: () -> (),
}

local function trim(text: string): string
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

function Components.TextInput(props: TextInputProps?): TextInput
	local p: TextInputProps = props or {}
	local fieldH = S.inputH
	local root = blank(p.name or "TextInput", p.size or UDim2.new(1, 0, 0, fieldH + 28))
	root.LayoutOrder = p.layoutOrder or 0

	local field = blank("Field", UDim2.new(1, 0, 0, fieldH))
	field.BackgroundTransparency = 0
	field.BackgroundColor3 = P.duskSunken
	corner(field, px(Theme.Radius.input))
	local stroke = outline(field, Theme.Stroke.input)
	recess(field, px(Theme.Radius.input))
	field.Parent = root

	local box = Instance.new("TextBox")
	box.Name = "Box"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.ZIndex = 2
	box.FontFace = Theme.Fonts.body
	box.TextSize = 22
	box.TextColor3 = P.textHi
	box.PlaceholderText = p.placeholder or ""
	box.PlaceholderColor3 = P.textLow
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClipsDescendants = true
	box.Text = ""
	box.SelectionImageObject = selectionRing(px(Theme.Radius.input))
	pad(box, 0, SP.lg, 0, SP.lg)
	box.Parent = field

	local status = makeText("caption", "", {
		name = "Status",
		align = Enum.TextXAlignment.Left,
		size = UDim2.new(1, -8, 0, 22),
		position = UDim2.fromOffset(4, fieldH + 4),
		color = P.textLow,
	})
	status.Parent = root

	local maxLength = p.maxLength
	local onChanged = p.onChanged
	local onSubmit = p.onSubmit
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local text = box.Text
		if maxLength then
			local length = utf8.len(text) or #text
			if length > maxLength then
				local cut = utf8.offset(text, maxLength + 1)
				box.Text = string.sub(text, 1, (cut or (maxLength + 1)) - 1)
				return
			end
		end
		if onChanged then
			onChanged(text)
		end
	end)

	box.Focused:Connect(function()
		stroke.Color = Theme.Roles.info.top
		stroke.Thickness = Theme.Stroke.focus
	end)
	box.FocusLost:Connect(function(enterPressed: boolean)
		stroke.Color = P.ink
		stroke.Thickness = Theme.Stroke.input
		if enterPressed and onSubmit then
			onSubmit(trim(box.Text))
		end
	end)

	local function setStatus(kind: InputStatus, text: string?)
		if kind == "none" or text == nil or text == "" then
			status.Text = ""
			return
		end
		-- Glyph prefix gives a non-colour cue for success and failure.
		local prefix = if kind == "ok" then "\u{2713} " elseif kind == "error" then "! " else ""
		status.Text = prefix .. text
		status.TextColor3 = if kind == "ok" then P.positive elseif kind == "error" then P.negative else P.textLow
	end

	local shaking = false
	local function shake()
		if shaking or Theme.isReducedMotion() then
			return
		end
		shaking = true
		task.spawn(function()
			for _, dx in { 8, -8, 5, -5, 2, 0 } do
				tween(field, M.shakeStep, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Position = UDim2.fromOffset(dx, 0) })
				task.wait(M.shakeStep)
			end
			shaking = false
		end)
	end

	if p.parent then
		root.Parent = p.parent
	end
	return {
		root = root,
		box = box,
		getText = function(): string
			return trim(box.Text)
		end,
		setText = function(text: string)
			box.Text = text
		end,
		clear = function()
			box.Text = ""
		end,
		setStatus = setStatus,
		shake = shake,
	}
end

return Components
