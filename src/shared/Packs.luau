-- Pack definitions and the pull roll.
local Cards = require(script.Parent.Cards)

local Packs = {}

-- weights = relative odds per rarity. storeTier = store level needed to buy it.
-- sets = card sets the pack pulls from (nil = every set).
Packs.List = {
	{
		id = "starter",
		name = "Starter Pack",
		currency = "cash",
		cost = 25,
		storeTier = 1,
		sets = { "dojo" },
		color = Color3.fromRGB(90, 160, 110),
		weights = { Common = 70, Uncommon = 25, Rare = 4.5, Epic = 0.5 },
	},
	{
		id = "dojo",
		name = "Dojo Pack",
		currency = "cash",
		cost = 500,
		storeTier = 1,
		sets = { "dojo" },
		color = Color3.fromRGB(70, 120, 220),
		weights = { Common = 40, Uncommon = 40, Rare = 17, Epic = 2.8, Legendary = 0.2 },
	},
	{
		id = "neon",
		name = "Neon Pack",
		currency = "cash",
		cost = 3000,
		storeTier = 2,
		sets = { "neon" },
		color = Color3.fromRGB(40, 200, 210),
		weights = { Common = 45, Uncommon = 38, Rare = 14.5, Epic = 2.4, Legendary = 0.1 },
	},
	{
		id = "shogun",
		name = "Shogun Pack",
		currency = "cash",
		cost = 10000,
		storeTier = 2,
		sets = { "dojo" },
		color = Color3.fromRGB(150, 80, 220),
		weights = { Uncommon = 45, Rare = 40, Epic = 13, Legendary = 1.9, Mythic = 0.1 },
	},
	{
		id = "arcade",
		name = "Arcade Pack",
		currency = "cash",
		cost = 75000,
		storeTier = 3,
		sets = { "neon" },
		color = Color3.fromRGB(240, 90, 200),
		weights = { Uncommon = 40, Rare = 42, Epic = 15.5, Legendary = 2.4, Mythic = 0.1 },
	},
	{
		id = "celestial",
		name = "Celestial Pack",
		currency = "cash",
		cost = 250000,
		storeTier = 3,
		sets = { "dojo" },
		color = Color3.fromRGB(240, 170, 50),
		weights = { Rare = 50, Epic = 38, Legendary = 10.5, Mythic = 1.4, Secret = 0.1 },
	},
	{
		id = "glitch",
		name = "Glitch Pack",
		currency = "cash",
		cost = 5000000,
		storeTier = 4,
		sets = { "neon" },
		color = Color3.fromRGB(110, 230, 90),
		weights = { Rare = 45, Epic = 40, Legendary = 13, Mythic = 1.85, Secret = 0.15 },
	},
	{
		id = "omega",
		name = "Omega Pack",
		currency = "cash",
		cost = 150000000,
		storeTier = 5,
		color = Color3.fromRGB(245, 245, 250),
		weights = { Epic = 55, Legendary = 36, Mythic = 8.5, Secret = 0.5 },
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

-- "Dojo Legends", "Neon Arcade" or "All sets"
function Packs.setsText(pack)
	if pack.sets == nil then
		return "All sets"
	end
	local names = {}
	for _, setId in ipairs(pack.sets) do
		table.insert(names, Cards.Sets[setId].name)
	end
	return table.concat(names, " + ")
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

	local pool = Cards.pool(chosenRarity, pack.sets)
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
