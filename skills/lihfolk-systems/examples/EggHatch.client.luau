--!strict
-- LihFolk Systems example: EggHatch (client)
-- Install: StarterPlayer/StarterPlayerScripts/EggHatchClient (LocalScript)
-- The client only sends intent and renders the server's answer.
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(Shared:WaitForChild("Net"))
local Feedback = require(Shared:WaitForChild("Feedback"))

-- The odds panel shows SERVER-computed odds for this player (luck, pity,
-- obtained once-items), from the same function the roll uses, and refetches
-- whenever the server says they changed. Put it behind a button labelled
-- "Odds" on every purchase surface (not a bare (i) icon).
local EGG = "Basic"

local function renderOdds()
	local result = Net.Request("Eggs.GetOdds", EGG)
	if not result.ok then
		return
	end
	local odds = result.data
	print(`[Odds] {odds.name}  luck x{odds.luck}{if odds.paidLuckActive then " (includes paid boosts)" else ""}`)
	if not odds.allowed then
		print(`[Odds] {odds.restrictedNote}`)
	end
	for _, row in odds.rows do
		print(`  {row.tier}  {row.id}  {row.text}  ({row.oneIn})`)
	end
	if odds.pity then
		print(`  {odds.pity.rule}; you are at {odds.pity.count}. Base {odds.pity.baseChance}, effective {odds.pity.effectiveChance}`)
	end
	print(`  {odds.disclaimer}`)
end

Net.On("Eggs.OddsChanged", function(eggId: string?)
	if eggId == nil or eggId == EGG then
		renderOdds()
	end
end)
renderOdds()

-- Boost preview: numeric before/after with the cap applied; disable at cap.
local preview = Net.Request("Eggs.PreviewBoost", EGG, 2)
if preview.ok then
	local p = preview.data
	print(`[Boost] x2 Luck for 15 minutes. {p.tier}: {p.before} now, {p.after} with this boost.`)
	if p.atCap then
		print("[Boost] Your luck is already at the maximum. (Button disabled)")
	end
end

local hatch = Net.Request("Eggs.Hatch", EGG, 1)
if hatch.ok then
	for _, pet in hatch.data do
		Feedback.Show("Hatched!", `{pet.item} ({pet.tier})`)
	end
else
	Feedback.Result("Eggs", hatch)
end
