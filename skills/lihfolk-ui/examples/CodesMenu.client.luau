--!strict
--[[
	LihFolk UI example: CODES (input + redeem)
	LocalScript in StarterPlayer > StarterPlayerScripts.

	Server contract (you write it; see the roblox-secure-remotes skill):
	  ReplicatedStorage > Remotes > RedeemCode (RemoteFunction)
	  InvokeServer(code: string) -> { ok: boolean, message: string }
	The server owns the code list, expiry, one-use-per-player and rate limiting.
	The client never contains valid codes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("LihFolkUI")
local Theme = require(UI:WaitForChild("LihFolkUITheme"))
local C = require(UI:WaitForChild("LihFolkUIComponents"))
local Controller = require(UI:WaitForChild("LihFolkUIController"))

local CLIENT_COOLDOWN = 2 -- seconds; a courtesy only, the server must rate-limit too

Controller.start()

local window = C.Window({
	name = "Codes",
	title = "Codes",
	theme = "codes",
	icon = "codes",
	size = Vector2.new(600, 400),
})

C.Text("body", "Follow the group and check the game page for new codes.", {
	color = Theme.Palette.textMid,
	wrap = true,
	size = UDim2.new(1, 0, 0, 48),
	layoutOrder = 1,
	parent = window.body,
})

local busy = false
local redeemButton: any

local input = C.TextInput({
	placeholder = "Enter code",
	maxLength = 24,
	layoutOrder = 2,
	parent = window.body,
	-- Enter-to-submit is wired below with FocusLost, once submit() exists.
})

local function findRemote(): RemoteFunction?
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild("RedeemCode")
	if remote and remote:IsA("RemoteFunction") then
		return remote
	end
	return nil
end

local function setBusy(value: boolean)
	busy = value
	redeemButton.setEnabled(not value)
	redeemButton.setRole(if value then "neutral" else "go")
	redeemButton.setText(if value then "CHECKING..." else "REDEEM")
end

local function submit()
	if busy then
		return
	end
	local code = input.getText()
	if code == "" then
		input.setStatus("error", "Type a code first")
		input.shake()
		return
	end
	local remote = findRemote()
	if not remote then
		input.setStatus("info", "Codes are not set up on the server yet")
		warn("[Codes] Add ReplicatedStorage.Remotes.RedeemCode (RemoteFunction)")
		return
	end

	setBusy(true)
	input.setStatus("none")
	local ok, reply = pcall(remote.InvokeServer, remote, code)
	if ok and type(reply) == "table" and reply.ok == true then
		input.setStatus("ok", tostring(reply.message or "Code redeemed!"))
		input.clear()
		C.playSound("success")
	else
		local message = if ok and type(reply) == "table" and reply.message then tostring(reply.message) else "Try again in a moment"
		input.setStatus("error", message)
		input.shake()
		C.playSound("error")
	end
	task.delay(CLIENT_COOLDOWN, function()
		setBusy(false)
	end)
end

redeemButton = C.Button({
	text = "REDEEM",
	role = "go",
	icon = "check",
	size = UDim2.fromOffset(260, Theme.Size.buttonH),
	layoutOrder = 3,
	parent = window.body,
	onActivated = submit,
})

-- Enter in the box submits too.
input.box.FocusLost:Connect(function(enterPressed: boolean)
	if enterPressed then
		submit()
	end
end)

window.defaultSelection = input.box
Controller.register(window)
Controller.addHudButton({ window = "Codes", label = "Codes", icon = "codes", theme = "codes", layoutOrder = 4 })
