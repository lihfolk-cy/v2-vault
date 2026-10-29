--!strict
-- LihFolk Systems: Feedback (client helper)
-- Install: ReplicatedStorage/LihFolk/Feedback (ModuleScript)
-- Turns server result codes into kind, short messages and shows them as a
-- notification. Replace Show with your own toast UI (roblox-ui-builder).
-- Status: reviewed, not run in Studio.

local StarterGui = game:GetService("StarterGui")

local Feedback = {}

Feedback.Messages = {
	Ok = "Done!",
	TooFast = "Slow down a little.",
	Busy = "Still working on your last request.",
	Invalid = "That did not work. Try again.",
	Error = "Something went wrong. Please try again.",
	NetworkError = "Connection problem. Please try again.",
	NotReady = "Your data is still loading.",
	NotEnough = "You cannot afford that yet.",
	BagFull = "Your inventory is full. Make some space first.",
	StackFull = "You cannot carry more of that.",
	LimitReached = "You already have the maximum of that.",
	Restricted = "This is not available on your account.",
	Unavailable = "This is not available right now.",
	AlreadyOwned = "You already own this.",
	AtMaxLuck = "Your luck is already at the maximum.",
	BoostLimit = "You have the most boosts running at once. Try again when one ends.",
	NotFound = "That code does not exist.",
	Expired = "That code has expired.",
	AlreadyRedeemed = "You already used that code.",
	Locked = "Too many wrong codes. Try again in a few minutes.",
	AlreadyClaimed = "Already claimed. Come back later!",
	NotComplete = "Finish the quest first.",
	NotOwned = "You do not own that.",
	NotEquippable = "That cannot be equipped.",
	EquipFull = "Unequip something first.",
	MaxReached = "You reached the maximum.",
	EggEmpty = "Nothing left to hatch in this egg.",
	NotEligible = "You cannot use that yet.",
} :: { [string]: string }

function Feedback.Text(code: string): string
	return Feedback.Messages[code] or Feedback.Messages.Error
end

function Feedback.Show(title: string, text: string)
	-- SetCore can fail before the core scripts register it; retry briefly.
	for _ = 1, 5 do
		local ok = pcall(StarterGui.SetCore, StarterGui, "SendNotification", { Title = title, Text = text, Duration = 3 })
		if ok then
			return
		end
		task.wait(0.5)
	end
end

-- Shows a Net.Result: successText on ok, the friendly message otherwise.
function Feedback.Result(title: string, result: { ok: boolean, code: string, data: any? }, successText: string?)
	if result.ok then
		Feedback.Show(title, successText or Feedback.Messages.Ok)
	else
		Feedback.Show(title, Feedback.Text(result.code))
	end
end

return Feedback
