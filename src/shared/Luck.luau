-- The Luck stat. Every luck level makes better rarities 10% more likely in packs (and card
-- effects 3% more likely). Luck comes from many places; this module adds them all up so the
-- server (to roll packs) and the client (to show the breakdown) always agree.
local Cards = require(script.Parent.Cards)
local Combos = require(script.Parent.Combos)
local Config = require(script.Parent.Config)
local Perks = require(script.Parent.Perks)
local Rebirth = require(script.Parent.Rebirth)

local Luck = {}

Luck.PerCompletedSet = 2
Luck.TowerFloorsPerLevel = 10

-- profile needs: upgrades, rebirths, perks, collection, slots, tower.
-- eventActive = a server lucky event is running. passes = { [passKey] = true } game passes owned.
-- Returns the list of sources { { name, levels }, ... } (only non-zero ones) and the total.
function Luck.sources(profile, eventActive, passes)
	local list = {}
	local total = 0
	local function add(name, levels)
		if levels and levels > 0 then
			table.insert(list, { name = name, levels = levels })
			total = total + levels
		end
	end

	add("Aura Luck upgrade", profile.upgrades.luck)
	add("Lucky Charms upgrade", profile.upgrades.charm)
	add("Fortune perk", Perks.level(profile.perks, "fortune"))
	add("Rebirths", Rebirth.luckBonus(profile.rebirths))
	add("Completed sets", Luck.PerCompletedSet * Cards.completedSets(profile.collection))
	add("Battle Tower", math.floor((profile.tower or 0) / Luck.TowerFloorsPerLevel))
	add("Deck combos", Combos.evaluate(profile.slots).luck)
	if passes and passes.vip then
		add("VIP pass", Config.Monetization.VipLuck)
	end
	if eventActive then
		add("Lucky event", Config.LuckEvent.BonusLevels)
	end
	return list, total
end

function Luck.total(profile, eventActive, passes)
	local _, total = Luck.sources(profile, eventActive, passes)
	return total
end

-- 13 levels -> "+130%"
function Luck.percentText(levels)
	return "+" .. math.floor(levels * 10 + 0.5) .. "%"
end

return Luck
