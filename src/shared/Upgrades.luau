-- Store upgrades. "level" is how many times an upgrade has been bought (starts at 0).
local Config = require(script.Parent.Config)

local Upgrades = {}

-- Store tier = store upgrade level + 1. cost is the price to reach that tier.
Upgrades.StoreTiers = {
	{ name = "Card Stall", cost = 0, mult = 1 },
	{ name = "Card Shop", cost = 2500, mult = 1.5 },
	{ name = "Card Emporium", cost = 50000, mult = 2.5 },
	{ name = "Mega Card Store", cost = 1000000, mult = 4 },
	{ name = "Aura Tower", cost = 25000000, mult = 7 },
}

Upgrades.Order = { "store", "slots", "luck" }

Upgrades.Defs = {
	store = {
		name = "Upgrade Store",
		currency = "cash",
		max = #Upgrades.StoreTiers - 1,
		cost = function(level)
			return Upgrades.StoreTiers[level + 2].cost
		end,
		describe = function(level)
			local current = Upgrades.StoreTiers[level + 1]
			local nextTier = Upgrades.StoreTiers[level + 2]
			if nextTier == nil then
				return current.name .. " — x" .. current.mult .. " income (MAX)"
			end
			return current.name .. " (x" .. current.mult .. ") → " .. nextTier.name .. " (x" .. nextTier.mult .. " income, new packs)"
		end,
	},
	slots = {
		name = "Display Stand",
		currency = "cash",
		max = Config.MaxSlots - Config.BaseSlots,
		cost = function(level)
			return math.floor(150 * 2.4 ^ level)
		end,
		describe = function(level)
			return (Config.BaseSlots + level) .. " / " .. Config.MaxSlots .. " stands — each stand shows one card that earns cash"
		end,
	},
	luck = {
		name = "Aura Luck",
		currency = "aura",
		max = 10,
		cost = function(level)
			return math.floor(250 * 2 ^ level)
		end,
		describe = function(level)
			return "+" .. (level * 10) .. "% chance for Rare+ cards and Holo / Gold / Prismatic variants"
		end,
	},
}

function Upgrades.getStoreTier(storeLevel)
	return Upgrades.StoreTiers[(storeLevel or 0) + 1]
end

return Upgrades
