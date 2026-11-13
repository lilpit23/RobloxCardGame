-- Rebirth: once you have enough cash and aura AND own specific cards, reset your run for
-- permanent bonuses. Cards in the vault survive the reset.
-- Used by the server (to decide) and the client (to show progress).
local Cards = require(script.Parent.Cards)
local Format = require(script.Parent.Format)

local Rebirth = {}

-- Levels[n] = what it takes to go from rebirth n-1 to rebirth n.
-- cards = card ids you must own (any variant; display, inventory or vault all count).
-- Costs climb about 20x per rebirth while each rebirth unlocks a new, richer set (1 to 4).
-- After that every set is open and income only creeps up, so the costs climb about 3x.
-- Aura per second does not grow with later sets at all, so the aura asked for flattens too.
Rebirth.Levels = {
	{ cash = 300000000, aura = 500, cards = { "piglet", "winnie_the_pooh" } }, -- Storybook Friends
	{ cash = 5000000000, aura = 5000, cards = { "tigger", "mad_hatter", "jim_hawkins" } }, -- + High Seas
	{ cash = 100000000000, aura = 40000, cards = { "long_john_silver", "zhu_bajie" } }, -- + Journey to the West
	{ cash = 2000000000000, aura = 250000, cards = { "moby_dick", "nezha", "dr_watson" } }, -- + Midnight Classics
	{ cash = 20000000000000, aura = 1000000, cards = { "sun_wukong", "sherlock_holmes" } },
	{ cash = 60000000000000, aura = 3000000, cards = { "jade_emperor", "count_dracula" } },
	{ cash = 200000000000000, aura = 8000000, cards = { "hercules", "medusa" } }, -- + Olympus
	{ cash = 600000000000000, aura = 20000000, cards = { "zeus", "king_arthur", "merlin", "julius_caesar" } }, -- + Knights and Outlaws, Glory of Rome
}

Rebirth.IncomePerRebirth = 0.5 -- +50% income per rebirth
Rebirth.LuckPerRebirth = 1 -- free luck levels per rebirth (each is +10%)
Rebirth.BaseVaultSlots = 1
Rebirth.MaxVaultSlots = 5

-- The most cash a player can hold before their next rebirth: twice what that rebirth costs.
-- Hitting the cap is the signal to rebirth; every rebirth raises it. No cap after the last one.
Rebirth.CapFactor = 2

function Rebirth.cashCap(rebirths)
	local level = Rebirth.Levels[(rebirths or 0) + 1]
	if level == nil then
		return math.huge
	end
	return level.cash * Rebirth.CapFactor
end

function Rebirth.incomeMult(rebirths)
	return 1 + Rebirth.IncomePerRebirth * (rebirths or 0)
end

function Rebirth.luckBonus(rebirths)
	return Rebirth.LuckPerRebirth * (rebirths or 0)
end

function Rebirth.vaultSlots(rebirths)
	return math.min(Rebirth.BaseVaultSlots + (rebirths or 0), Rebirth.MaxVaultSlots)
end

function Rebirth.describeBonuses(rebirths)
	local slots = Rebirth.vaultSlots(rebirths)
	return "x" .. Rebirth.incomeMult(rebirths) .. " income  ·  +" .. (Rebirth.luckBonus(rebirths) * 10) .. "% luck  ·  " .. slots .. (slots == 1 and " vault slot" or " vault slots")
end

local function matches(key, id)
	local def = Cards.parse(key)
	return def ~= nil and def.id == id
end

-- profile needs: inventory, slots, vault.
function Rebirth.ownsCard(profile, id)
	for key in pairs(profile.inventory) do
		if matches(key, id) then
			return true
		end
	end
	for _, key in pairs(profile.slots) do
		if matches(key, id) then
			return true
		end
	end
	for _, key in pairs(profile.vault) do
		if matches(key, id) then
			return true
		end
	end
	return false
end

-- profile needs: rebirths, cash, aura, inventory, slots, vault.
-- Returns level (nil when maxed), ready, requirements = { { text = string, met = boolean }, ... }
function Rebirth.check(profile)
	local level = Rebirth.Levels[(profile.rebirths or 0) + 1]
	if level == nil then
		return nil, false, {}
	end
	local requirements = {
		{ text = Format.cash(level.cash) .. " cash", met = profile.cash >= level.cash },
		{ text = Format.short(level.aura) .. " aura", met = profile.aura >= level.aura },
	}
	for _, id in ipairs(level.cards) do
		local def = Cards.ById[id]
		table.insert(requirements, {
			text = "Own " .. def.name .. "  (" .. def.rarity .. " from " .. Cards.Sets[def.set].name .. " packs, any effect)",
			met = Rebirth.ownsCard(profile, id),
		})
	end
	local ready = true
	for _, requirement in ipairs(requirements) do
		if not requirement.met then
			ready = false
		end
	end
	return level, ready, requirements
end

return Rebirth
