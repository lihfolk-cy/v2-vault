--!strict
-- LihFolk Systems: Odds
-- Install: ReplicatedStorage/LihFolk/Odds (ModuleScript)
--
-- One source of truth for weighted random rolls AND their disclosure.
-- The server rolls by calling Flatten and Pick on exactly the same inputs it
-- uses to build the odds the player sees, so the display cannot drift from
-- the roll (vault: Paid Random Items and Odds Disclosure in Practice).
--
-- Model: tiers (ascending rarity) -> items within a tier.
--   luck     multiplies the weight of tiers marked lucky, then renormalises
--   minRank  hard pity: tiers below this rank get weight 0 for this roll
--   excluded once-per-player items already obtained; empty tiers drop to 0
-- Status: reviewed, not run in Studio.

export type Item = { id: string, weight: number, once: boolean? }
export type Tier = { name: string, weight: number, lucky: boolean?, items: { Item } }
export type Final = { id: string, tier: string, rank: number, p: number }
export type FlattenOptions = {
	luck: number?,
	minRank: number?,
	excluded: { [string]: boolean }?,
}
export type Shown = { id: string, tier: string, rank: number, percent: number, text: string, oneIn: string }

local Odds = {}

Odds.Disclaimer = "Odds are rounded for display and may not add up to exactly 100%."

local function isFiniteNonNegative(n: any): boolean
	return type(n) == "number" and n == n and n >= 0 and n < math.huge
end

-- Validates a tier table. Errors with a clear message; call at server startup.
function Odds.Validate(label: string, tiers: { Tier })
	assert(type(tiers) == "table" and #tiers > 0, `{label}: needs at least one tier`)
	local seen: { [string]: boolean } = {}
	local reachable = false
	for rank, tier in tiers do
		assert(type(tier.name) == "string", `{label}: tier {rank} needs a name`)
		assert(isFiniteNonNegative(tier.weight), `{label}: tier {tier.name} weight must be finite and >= 0`)
		assert(type(tier.items) == "table" and #tier.items > 0, `{label}: tier {tier.name} has no items`)
		local tierTotal = 0
		for _, item in tier.items do
			assert(type(item.id) == "string" and item.id ~= "", `{label}: item without id in {tier.name}`)
			assert(not seen[item.id], `{label}: item {item.id} appears twice (flattened odds would double count)`)
			seen[item.id] = true
			assert(isFiniteNonNegative(item.weight), `{label}: item {item.id} weight must be finite and >= 0`)
			tierTotal += item.weight
		end
		if tier.weight > 0 and tierTotal > 0 then
			reachable = true
		end
	end
	assert(reachable, `{label}: no reachable outcome`)
end

-- Flattens tiers into final-outcome probabilities (p in 0..1, summing to 1).
-- Returns the list and the total tier weight used (0 means nothing is reachable).
function Odds.Flatten(tiers: { Tier }, options: FlattenOptions?): ({ Final }, number)
	local luck = 1
	local minRank = 1
	local excluded: { [string]: boolean }? = nil
	if options then
		luck = options.luck or 1
		minRank = options.minRank or 1
		excluded = options.excluded
	end
	assert(luck == luck and luck > 0 and luck < math.huge, "Odds.Flatten: luck must be finite and > 0")

	local tierWeight = table.create(#tiers, 0)
	local itemTotal = table.create(#tiers, 0)
	local total = 0
	for rank, tier in tiers do
		local available = 0
		for _, item in tier.items do
			if not (excluded and excluded[item.id]) then
				available += item.weight
			end
		end
		itemTotal[rank] = available
		local w = 0
		if rank >= minRank and available > 0 then
			w = if tier.lucky then tier.weight * luck else tier.weight
		end
		tierWeight[rank] = w
		total += w
	end

	local finals: { Final } = {}
	for rank, tier in tiers do
		local pTier = if total > 0 then tierWeight[rank] / total else 0
		for _, item in tier.items do
			local w = if excluded and excluded[item.id] then 0 else item.weight
			local p = if itemTotal[rank] > 0 then pTier * w / itemTotal[rank] else 0
			table.insert(finals, { id = item.id, tier = tier.name, rank = rank, p = p })
		end
	end
	return finals, total
end

-- Picks one final outcome. r is a number in [0, 1) (rng:NextNumber()).
-- The tail loop returns the last REACHABLE outcome when floating point sums
-- end a hair below 1, so an impossible (p = 0) item is never handed out.
function Odds.PickWith(finals: { Final }, r: number): Final
	local acc = 0
	for _, final in finals do
		if final.p > 0 then
			acc += final.p
			if r < acc then
				return final
			end
		end
	end
	for i = #finals, 1, -1 do
		if finals[i].p > 0 then
			return finals[i]
		end
	end
	error("Odds.PickWith: no reachable outcome")
end

function Odds.Pick(finals: { Final }, rng: Random): Final
	return Odds.PickWith(finals, rng:NextNumber())
end

-- Formats a percentage (0..100). Rounds to four places below the first
-- non-zero digit (or four decimals at 1% and above), trims trailing zeros,
-- and never shows a non-zero chance as 0%.
function Odds.Format(percent: number): string
	if percent ~= percent or percent <= 0 then
		return "0%"
	end
	if percent >= 100 then
		return "100%"
	end
	local decimals = 4
	if percent < 1 then
		-- First non-zero digit sits at decimal place -floor(log10(p)).
		-- Floating error can only add a place here, never remove one.
		decimals = -math.floor(math.log10(percent)) + 4
	end
	decimals = math.clamp(decimals, 0, 30)
	local text = string.format(`%.{decimals}f`, percent)
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text .. "%"
end

local function withCommas(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local out = s
	repeat
		local replaced
		out, replaced = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
	until replaced == 0
	return out
end

-- "1 in 1,234" supplement for a probability p in (0, 1]. Percentages remain the required format.
function Odds.OneIn(p: number): string
	if p ~= p or p <= 0 then
		return "never"
	end
	local n = 1 / p
	if n < 10 then
		return string.format("1 in %.1f", n)
	end
	return `1 in {withCommas(n)}`
end

-- Builds display rows from finals (same inputs as the roll).
function Odds.Shown(finals: { Final }): { Shown }
	local rows: { Shown } = table.create(#finals)
	for _, final in finals do
		local percent = final.p * 100
		table.insert(rows, {
			id = final.id,
			tier = final.tier,
			rank = final.rank,
			percent = percent,
			text = Odds.Format(percent),
			oneIn = Odds.OneIn(final.p),
		})
	end
	return rows
end

-- Total probability of outcomes at or above a rank (e.g. "Legendary or better").
function Odds.ChanceAtOrAbove(finals: { Final }, rank: number): number
	local sum = 0
	for _, final in finals do
		if final.rank >= rank then
			sum += final.p
		end
	end
	return sum
end

-- Hard pity: base chance p per roll, guaranteed on roll K. Long-run rate per roll.
-- E = (1 - (1 - p)^K) / p rolls per hit; rate = 1 / E.
function Odds.PityEffectiveRate(p: number, K: number): number
	if p <= 0 then
		return 1 / K
	end
	if p >= 1 then
		return 1
	end
	return p / (1 - (1 - p) ^ K)
end

-- Chance of at least one hit in n independent rolls.
function Odds.AtLeastOne(p: number, n: number): number
	return 1 - (1 - p) ^ n
end

-- Chi-square goodness of fit of `counts` against finals over n rolls.
-- Outcomes expecting fewer than 5 hits are pooled. Returns (chi2, degreesOfFreedom).
function Odds.ChiSquare(finals: { Final }, counts: { [string]: number }, n: number): (number, number)
	local chi, dof = 0, -1
	local pooledExpected, pooledObserved = 0, 0
	for _, final in finals do
		local expected = final.p * n
		local observed = counts[final.id] or 0
		if expected >= 5 then
			local d = observed - expected
			chi += d * d / expected
			dof += 1
		else
			pooledExpected += expected
			pooledObserved += observed
		end
	end
	if pooledExpected >= 5 then
		local d = pooledObserved - pooledExpected
		chi += d * d / pooledExpected
		dof += 1
	end
	return chi, math.max(dof, 1)
end

return Odds
