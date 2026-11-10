-- Pack definitions and the pull roll.
local Cards = require(script.Parent.Cards)

local Packs = {}

-- weights = relative odds per rarity. storeTier = store level needed to buy it.
Packs.List = {
	{
		id = "starter",
		name = "Starter Pack",
		currency = "cash",
		cost = 25,
		storeTier = 1,
		color = Color3.fromRGB(90, 160, 110),
		weights = { Common = 70, Uncommon = 25, Rare = 4.5, Epic = 0.5 },
	},
	{
		id = "dojo",
		name = "Dojo Pack",
		currency = "cash",
		cost = 500,
		storeTier = 1,
		color = Color3.fromRGB(70, 120, 220),
		weights = { Common = 40, Uncommon = 40, Rare = 17, Epic = 2.8, Legendary = 0.2 },
	},
	{
		id = "shogun",
		name = "Shogun Pack",
		currency = "cash",
		cost = 10000,
		storeTier = 2,
		color = Color3.fromRGB(150, 80, 220),
		weights = { Uncommon = 45, Rare = 40, Epic = 13, Legendary = 1.9, Mythic = 0.1 },
	},
	{
		id = "celestial",
		name = "Celestial Pack",
		currency = "cash",
		cost = 250000,
		storeTier = 3,
		color = Color3.fromRGB(240, 170, 50),
		weights = { Rare = 50, Epic = 38, Legendary = 10.5, Mythic = 1.4, Secret = 0.1 },
	},
	{
		id = "aura",
		name = "Aura Pack",
		currency = "aura",
		cost = 1500,
		storeTier = 1,
		color = Color3.fromRGB(230, 60, 110),
		weights = { Epic = 60, Legendary = 32, Mythic = 7, Secret = 1 },
	},
}

Packs.ById = {}
for _, pack in ipairs(Packs.List) do
	Packs.ById[pack.id] = pack
end

-- Each luck level makes Rare+ rarities and special variants 10% more likely.
function Packs.luckMultiplier(luckLevel)
	return 1 + 0.1 * (luckLevel or 0)
end

function Packs.adjustedWeight(pack, rarityName, luckLevel)
	local weight = pack.weights[rarityName]
	if weight == nil then
		return 0
	end
	if Cards.Rarities[rarityName].order >= 3 then
		weight = weight * Packs.luckMultiplier(luckLevel)
	end
	return weight
end

-- Returns a card key. rng is a Random object.
function Packs.roll(pack, luckLevel, rng)
	local total = 0
	for _, rarityName in ipairs(Cards.RarityOrder) do
		total = total + Packs.adjustedWeight(pack, rarityName, luckLevel)
	end

	local pick = rng:NextNumber() * total
	local chosenRarity = nil
	for _, rarityName in ipairs(Cards.RarityOrder) do
		local weight = Packs.adjustedWeight(pack, rarityName, luckLevel)
		if weight > 0 then
			chosenRarity = rarityName
			if pick < weight then
				break
			end
			pick = pick - weight
		end
	end

	local pool = Cards.ByRarity[chosenRarity]
	local def = pool[rng:NextInteger(1, #pool)]

	-- Rarest variant is checked first.
	local variantId = "normal"
	local luck = Packs.luckMultiplier(luckLevel)
	for index = #Cards.VariantOrder, 2, -1 do
		local candidate = Cards.VariantOrder[index]
		if rng:NextNumber() < Cards.Variants[candidate].chance * luck then
			variantId = candidate
			break
		end
	end

	return Cards.makeKey(def.id, variantId)
end

return Packs
