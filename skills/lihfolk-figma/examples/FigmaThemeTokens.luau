--!strict
--[[
	FigmaThemeTokens (example ModuleScript)

	The shape that Figma variables map into. Fill it from the Figma MCP tool `get_variable_defs`
	(or from the variables panel by hand): every Figma variable becomes one entry here, keyed by
	the variable's path with "/" turned into the table nesting ("color/surface/raised" ->
	Color.surface.raised is flattened to Color.surfaceRaised below to keep lookups short).

	Rules (see skills/lihfolk-figma/SKILL.md):
	- Generated builders and hand-written components read tokens; they never hard-code values.
	- Numbers are DESIGN UNITS at the reference resolution (1920 x 1080). The Fit UIScale scales them.
	- Colour variables with modes (light / dark, or a per-menu accent) become one table per mode.
	- A Figma variable that has no Roblox meaning (prototype booleans, string copy) stays in Figma.

	The values below are the LihFolk "Ink and Candy" tokens, used here as a worked example.
]]

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Tokens = {}

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

-- color/* -> Color (Figma COLOR variables; alpha goes to a separate transparency token)
Tokens.Color = {
	ink = hex("#160F2B"),
	surface = hex("#2D2852"),
	surfaceRaised = hex("#3B3566"),
	surfaceRaisedHi = hex("#4A437A"),
	surfaceSunken = hex("#1F1B3D"),
	textHi = hex("#FFFFFF"),
	textMid = hex("#D6D0F5"),
	textLow = hex("#B0A9DD"),
	accent = hex("#FFD24A"),
	focusRing = hex("#FFFFFF"),
}

-- Button roles: one Figma component set "Button" with a Role variant; each role is a swatch.
export type Swatch = { top: Color3, bottom: Color3, lip: Color3, text: Color3 }
Tokens.Role = {
	go = { top = hex("#7BF5A6"), bottom = hex("#25C773"), lip = hex("#12804A"), text = hex("#FFFFFF") },
	neutral = { top = hex("#9C94DB"), bottom = hex("#6E66B3"), lip = hex("#40397A"), text = hex("#FFFFFF") },
	danger = { top = hex("#FF7A98"), bottom = hex("#EE3D66"), lip = hex("#9A1838"), text = hex("#FFFFFF") },
	disabled = { top = hex("#4F4980"), bottom = hex("#3A3466"), lip = hex("#221D42"), text = hex("#B0A9DD") },
} :: { [string]: Swatch }

-- radius/* (FLOAT variables, px). "pill" uses Scale 0.5 so it stays round at any size.
Tokens.Radius = { panel = 22, header = 14, card = 14, button = 12, input = 10 }
-- space/* (FLOAT variables): the auto layout gaps and paddings in Figma use only these steps
Tokens.Space = { xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32 }
-- stroke/* (FLOAT variables)
Tokens.Stroke = { panel = 4, card = 3, button = 3, input = 2.5 }

-- Text styles (Figma text styles or typography variables): family file, weight, size, outline.
export type TextStyle = { font: Font, size: number, stroke: number }
local function face(stem: string, weight: Enum.FontWeight): Font
	return Font.new("rbxasset://fonts/families/" .. stem .. ".json", weight, Enum.FontStyle.Normal)
end
Tokens.Type = {
	title = { font = face("FredokaOne", Enum.FontWeight.Regular), size = 26, stroke = 2.5 },
	button = { font = face("FredokaOne", Enum.FontWeight.Regular), size = 24, stroke = 2.5 },
	body = { font = face("BuilderSans", Enum.FontWeight.Bold), size = 18, stroke = 0 },
	caption = { font = face("BuilderSans", Enum.FontWeight.SemiBold), size = 15, stroke = 0 },
} :: { [string]: TextStyle }

-- Motion tokens: Figma has no tween data, so these come from the vault's motion notes.
Tokens.Motion = {
	hover = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	press = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	release = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	hoverScale = 1.04,
	pressScale = 0.96,
}

---------------------------------------------------------------------------
-- Readers
---------------------------------------------------------------------------

function Tokens.corner(parent: GuiObject, radius: number | "pill")
	local c = Instance.new("UICorner")
	c.CornerRadius = if radius == "pill" then UDim.new(0.5, 0) else UDim.new(0, radius)
	c.Parent = parent
end

function Tokens.text(label: TextLabel | TextButton, style: string, color: Color3?)
	local s = Tokens.Type[style] or Tokens.Type.body
	label.FontFace = s.font
	label.TextSize = s.size
	label.TextColor3 = color or Tokens.Color.textHi
	if s.stroke > 0 then
		local existing = label:FindFirstChild("TextStroke")
		local stroke = if existing and existing:IsA("UIStroke") then existing else Instance.new("UIStroke")
		stroke.Name = "TextStroke"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Thickness = s.stroke
		stroke.Color = Tokens.Color.ink
		stroke.Parent = label
	end
end

---------------------------------------------------------------------------
-- A component function: the Figma "Button" component set as Luau.
-- Variants Default / Hover / Pressed / Disabled / Selected map to one state machine.
-- Gamepad selection gets its own ring (SelectionImageObject), never the Hover look alone.
---------------------------------------------------------------------------

export type ButtonState = "Default" | "Hover" | "Pressed" | "Disabled"
export type Button = {
	instance: TextButton,
	setEnabled: (enabled: boolean) -> (),
	setSelected: (selected: boolean) -> (),
	destroy: () -> (),
}

function Tokens.button(text: string, role: string, size: Vector2, onActivated: () -> ()): Button
	local swatch = Tokens.Role[role] or Tokens.Role.neutral
	local lipHeight = 6

	-- the root is the lip (darker); the face sits on top and sinks when pressed
	local root = Instance.new("TextButton")
	root.Name = text .. "Button"
	root.Text = ""
	root.AutoButtonColor = false
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Size = UDim2.fromOffset(size.X, size.Y)
	root.BackgroundColor3 = swatch.lip
	Tokens.corner(root, Tokens.Radius.button)
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	outline.Thickness = Tokens.Stroke.button
	outline.Color = Tokens.Color.ink
	outline.Parent = root

	local motion = Instance.new("UIScale") -- hover and press live here, never on the Fit scale
	motion.Name = "Motion"
	motion.Parent = root

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -lipHeight)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.Parent = root
	Tokens.corner(face, Tokens.Radius.button)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(swatch.top, swatch.bottom)
	gradient.Parent = face

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.BackgroundTransparency = 1
	caption.Size = UDim2.fromScale(1, 1)
	caption.Text = text
	caption.TextTruncate = Enum.TextTruncate.AtEnd
	caption.Parent = face
	Tokens.text(caption, "button", swatch.text)

	local ring = Instance.new("Frame") -- gamepad focus ring
	ring.Name = "SelectionRing"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.new(1, 8, 1, 8)
	ring.Position = UDim2.fromOffset(-4, -4)
	Tokens.corner(ring, Tokens.Radius.button + 4)
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Thickness = 3
	ringStroke.Color = Tokens.Color.focusRing
	ringStroke.Parent = ring
	root.SelectionImageObject = ring

	local enabled = true
	local hovered = false
	local pressed = false
	local connections: { RBXScriptConnection } = {}

	local function current(): ButtonState
		if not enabled then
			return "Disabled"
		elseif pressed then
			return "Pressed"
		elseif hovered then
			return "Hover"
		end
		return "Default"
	end

	local function apply()
		local state = current()
		root:SetAttribute("State", state)
		local s = if state == "Disabled" then Tokens.Role.disabled else swatch
		gradient.Color = ColorSequence.new(s.top, s.bottom)
		root.BackgroundColor3 = s.lip
		caption.TextColor3 = s.text
		local scale = if state == "Hover" then Tokens.Motion.hoverScale
			elseif state == "Pressed" then Tokens.Motion.pressScale
			else 1
		local sink = if state == "Pressed" then lipHeight - 2 else 0
		if GuiService.ReducedMotionEnabled then
			motion.Scale = 1 -- colour still changes; movement does not
			face.Position = UDim2.fromOffset(0, sink)
			return
		end
		local info = if state == "Pressed" then Tokens.Motion.press
			elseif state == "Default" then Tokens.Motion.release
			else Tokens.Motion.hover
		TweenService:Create(motion, info, { Scale = scale }):Play()
		TweenService:Create(face, info, { Position = UDim2.fromOffset(0, sink) }):Play()
	end

	table.insert(connections, root.MouseEnter:Connect(function()
		hovered = true
		apply()
	end))
	table.insert(connections, root.MouseLeave:Connect(function()
		hovered = false
		pressed = false
		apply()
	end))
	table.insert(connections, root.SelectionGained:Connect(function()
		hovered = true
		apply()
	end))
	table.insert(connections, root.SelectionLost:Connect(function()
		hovered = false
		apply()
	end))
	table.insert(connections, root.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA then
			pressed = true
			apply()
		end
	end))
	table.insert(connections, root.InputEnded:Connect(function()
		pressed = false
		apply()
	end))
	table.insert(connections, root.Activated:Connect(function()
		if enabled then
			onActivated()
		end
	end))
	apply()

	return {
		instance = root,
		setEnabled = function(value: boolean)
			enabled = value
			root.Active = value
			apply()
		end,
		setSelected = function(selected: boolean)
			if selected then
				GuiService.SelectedObject = root
			elseif GuiService.SelectedObject == root then
				GuiService.SelectedObject = nil
			end
		end,
		destroy = function()
			for _, c in connections do
				c:Disconnect()
			end
			root:Destroy()
		end,
	}
end

return Tokens
