-- Rebirth: once you have enough cash and aura AND own specific cards, reset your run for
-- permanent bonuses. Cards in the vault survive the reset.
-- Used by the server (to decide) and the client (to show progress).
local Cards = require(script.Parent.Cards)
local Format = require(script.Parent.Format)

local Rebirth = {}

-- Levels[n] = what it takes to go from rebirth n-1 to rebirth n.
-- cards = card ids you must own (any variant; display, inventory or vault all count).
Rebirth.Levels = {
	{ cash = 100000, aura = 500, cards = { "kage", "noir" } },
	{ cash = 2000000, aura = 5000, cards = { "yuki", "zeta", "ren" } },
	{ cash = 25000000, aura = 40000, cards = { "raika", "hinode" } },
	{ cash = 250000000, aura = 250000, cards = { "ryuma", "kuro", "tenryu" } },
	{ cash = 2500000000, aura = 1500000, cards = { "chrona", "zenith" } },
	{ cash = 25000000000, aura = 10000000, cards = { "eclipse", "gorath" } },
}

Rebirth.IncomePerRebirth = 0.5 -- +50% income per rebirth
Rebirth.LuckPerRebirth = 1 -- free luck levels per rebirth (each is +10%)
Rebirth.BaseVaultSlots = 1
Rebirth.MaxVaultSlots = 5

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
			text = "Own " .. def.name .. " (" .. def.rarity .. ", any variant)",
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
