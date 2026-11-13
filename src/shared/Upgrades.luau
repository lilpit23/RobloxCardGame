-- Store upgrades. "level" is how many times an upgrade has been bought (starts at 0).
local Config = require(script.Parent.Config)

local Upgrades = {}

-- Store tier = store upgrade level + 1. cost is the price to reach that tier.
Upgrades.StoreTiers = {
	{ name = "Card Stall", cost = 0, mult = 1 },
	{ name = "Card Shop", cost = 10000, mult = 1.5 },
	{ name = "Card Emporium", cost = 750000, mult = 2.5 },
	{ name = "Mega Card Store", cost = 15000000, mult = 4 },
	{ name = "Aura Tower", cost = 500000000, mult = 7 },
	{ name = "Card Palace", cost = 15000000000, mult = 12 },
	{ name = "Hall of Legends", cost = 500000000000, mult = 20 },
	{ name = "Grand Capitol", cost = 10000000000000, mult = 32 },
}

Upgrades.Order = { "store", "charm", "luck", "auto" }

-- Deck slots are the shelves of the store, so they come with the building: every store tier
-- adds shelves (the ground floor holds 16, each storey above it 8 more).
Upgrades.TierSlots = { 4, 16, 24, 32, 40, 48, 56, 64 }
-- ...but a store can only stock so many shelves until its owner has rebirthed enough:
-- index = rebirths + 1, and from the fifth rebirth every shelf is open.
Upgrades.RebirthSlots = { 16, 24, 32, 40, 52, 64 }

function Upgrades.rebirthSlotCap(rebirths)
	return Upgrades.RebirthSlots[math.min((rebirths or 0) + 1, #Upgrades.RebirthSlots)]
end

-- Deck slots for a store level (0 = Card Stall) and rebirth count. bonus = extra slots from
-- the game pass, which are not held back by the rebirth cap.
function Upgrades.slotCount(storeLevel, rebirths, bonus)
	local tier = math.min((storeLevel or 0) + 1, #Upgrades.TierSlots)
	local slots = math.min(Upgrades.TierSlots[tier], Upgrades.rebirthSlotCap(rebirths))
	return math.min(slots + (bonus or 0), Config.MaxSlots)
end

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
			return current.name .. " (x" .. current.mult .. ") → " .. nextTier.name .. " (x" .. nextTier.mult .. " income, a new floor of shelves, new packs)"
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
