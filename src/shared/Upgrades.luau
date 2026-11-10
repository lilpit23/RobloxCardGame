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
	{ name = "Card Palace", cost = 5000000000, mult = 12 },
	{ name = "Hall of Legends", cost = 250000000000, mult = 20 },
}

Upgrades.Order = { "store", "slots", "charm", "luck", "auto" }

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
		name = "Deck Slot",
		currency = "cash",
		max = Config.MaxSlots - Config.BaseSlots,
		cost = function(level)
			return math.floor(150 * 1.35 ^ level)
		end,
		describe = function(level)
			return (Config.BaseSlots + level) .. " / " .. Config.MaxSlots .. " deck slots — each slot holds one active card that earns cash"
		end,
	},
	charm = {
		name = "Lucky Charms",
		currency = "cash",
		max = 10,
		cost = function(level)
			return math.floor(2500 * 4 ^ level)
		end,
		describe = function(level)
			return "+" .. level .. " luck  (each luck level: +10% better pulls)"
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
			return "+" .. level .. " luck  (each luck level: +10% better pulls)"
		end,
	},
	auto = {
		name = "Auto Collector",
		currency = "aura",
		max = 1,
		cost = function()
			return 2000
		end,
		describe = function(level)
			if level >= 1 then
				return "Cash from every stand goes straight to your balance"
			end
			return "Collects the cash from every stand for you — no more walking over pads"
		end,
	},
}

function Upgrades.getStoreTier(storeLevel)
	return Upgrades.StoreTiers[(storeLevel or 0) + 1]
end

return Upgrades
