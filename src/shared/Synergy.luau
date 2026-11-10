-- Synergy: displaying several cards of the same type boosts the whole store's income.
local Cards = require(script.Parent.Cards)

local Synergy = {}

-- Reaching a count gives that bonus (highest reached tier applies, per type).
Synergy.Tiers = {
	{ count = 3, bonus = 0.15 },
	{ count = 5, bonus = 0.35 },
	{ count = 8, bonus = 0.6 },
}

local function bonusFor(count)
	local bonus = 0
	for _, tier in ipairs(Synergy.Tiers) do
		if count >= tier.count then
			bonus = tier.bonus
		end
	end
	return bonus
end

-- slots = { [tostring(slotIndex)] = cardKey }.
-- Returns the income multiplier and the active synergies { { type, count, bonus }, ... }.
function Synergy.compute(slots)
	local counts = {}
	for _, key in pairs(slots) do
		local def = Cards.parse(key)
		if def then
			counts[def.type] = (counts[def.type] or 0) + 1
		end
	end
	local total = 0
	local active = {}
	for _, typeId in ipairs(Cards.TypeOrder) do
		local count = counts[typeId] or 0
		local bonus = bonusFor(count)
		if bonus > 0 then
			total = total + bonus
			table.insert(active, { type = typeId, count = count, bonus = bonus })
		end
	end
	return 1 + total, active
end

-- "⚔️ x3 +15%   🐾 x5 +35%" or "" when nothing is active.
function Synergy.describe(slots)
	local _, active = Synergy.compute(slots)
	local parts = {}
	for _, entry in ipairs(active) do
		local info = Cards.Types[entry.type]
		table.insert(parts, info.icon .. " x" .. entry.count .. " +" .. math.floor(entry.bonus * 100 + 0.5) .. "%")
	end
	return table.concat(parts, "   ")
end

return Synergy
