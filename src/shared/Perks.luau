-- Aura Shrine: permanent perks bought with aura. They are NOT reset by rebirth, which is
-- what makes spending aura before a rebirth worth it.
-- "perks" below is the saved table { [perkId] = level }.
local Format = require(script.Parent.Format)

local Perks = {}

local START_CASH = { 500, 5000, 50000, 500000, 5000000 }

Perks.Order = { "packer", "startCash", "discount", "fortune", "aura", "offline", "vault" }

local PACKER_SECONDS = { 10, 7, 5, 3, 2 } -- seconds between automatic packs, by level

Perks.Defs = {
	packer = {
		name = "Auto Packer",
		max = #PACKER_SECONDS,
		cost = function(level)
			return 1500 * 4 ^ level
		end,
		describe = function(level)
			if level < 1 then
				return "Buys and opens a pack for you every " .. PACKER_SECONDS[1] .. " seconds. Pick the pack in the Pack Shop."
			end
			return "Opens a pack every " .. PACKER_SECONDS[level] .. " seconds. Pick the pack in the Pack Shop."
		end,
	},
	startCash = {
		name = "Head Start",
		max = #START_CASH,
		cost = function(level)
			return 1000 * 4 ^ level
		end,
		describe = function(level)
			if level >= #START_CASH then
				return "Start every run with " .. Format.cash(START_CASH[level])
			end
			return "Start every run after a rebirth with " .. Format.cash(START_CASH[level + 1])
		end,
	},
	discount = {
		name = "Bulk Deal",
		max = 5,
		cost = function(level)
			return 1500 * 3 ^ level
		end,
		describe = function(level)
			return "Cash packs cost " .. (level * 5) .. "% less  (+5% per level)"
		end,
	},
	fortune = {
		name = "Fortune",
		max = 5,
		cost = function(level)
			return 4000 * 3 ^ level
		end,
		describe = function(level)
			return "+" .. level .. " luck, forever  (+1 per level)"
		end,
	},
	aura = {
		name = "Aura Magnet",
		max = 5,
		cost = function(level)
			return 3000 * 3 ^ level
		end,
		describe = function(level)
			return "Cards radiate +" .. (level * 20) .. "% aura  (+20% per level)"
		end,
	},
	offline = {
		name = "Night Shift",
		max = 3,
		cost = function(level)
			return 2000 * 3 ^ level
		end,
		describe = function(level)
			return "Offline earnings +" .. (level * 25) .. "%  (+25% per level)"
		end,
	},
	vault = {
		name = "Bigger Vault",
		max = 2,
		cost = function(level)
			return 5000 * 10 ^ level
		end,
		describe = function(level)
			return "+" .. level .. " vault slots  (+1 per level)"
		end,
	},
}

local function levelOf(perks, id)
	local level = perks and perks[id]
	if type(level) ~= "number" then
		return 0
	end
	return level
end

Perks.level = levelOf

-- Seconds between automatic packs, or nil if the Auto Packer is not owned.
function Perks.packerInterval(perks)
	return PACKER_SECONDS[levelOf(perks, "packer")]
end

function Perks.startCash(perks)
	return START_CASH[levelOf(perks, "startCash")] or 0
end

-- Price of a pack after the Bulk Deal perk (aura packs are never discounted).
function Perks.packCost(pack, perks)
	if pack.currency ~= "cash" then
		return pack.cost
	end
	return math.max(1, math.floor(pack.cost * (1 - 0.05 * levelOf(perks, "discount"))))
end

function Perks.auraMult(perks)
	return 1 + 0.2 * levelOf(perks, "aura")
end

function Perks.offlineMult(perks)
	return 1 + 0.25 * levelOf(perks, "offline")
end

function Perks.vaultBonus(perks)
	return levelOf(perks, "vault")
end

return Perks
