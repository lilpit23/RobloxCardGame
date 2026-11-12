-- Booster packs. Every set has its own Booster and Elite pack, and a pack is a fixed list of
-- SLOTS: each slot is one card, rolled from that slot's rarity odds — commons in the common
-- slots, a guaranteed rare-or-better in the last slot, like a real booster pack.
local Cards = require(script.Parent.Cards)
local Perks = require(script.Parent.Perks)

local Packs = {}

-- Slot types: rarity -> relative odds.
local COMMON = { Common = 100 }
local UNCOMMON = { Uncommon = 85, Rare = 15 }
local RARE = { Rare = 80, Epic = 16, Legendary = 3.3, Mythic = 0.6, Secret = 0.1 }
local EPIC = { Epic = 75, Legendary = 20, Mythic = 4.3, Secret = 0.7 }
local CHAMPION = { Epic = 55, Legendary = 36, Mythic = 8.5, Secret = 0.5 }

local BOOSTER_SLOTS = { COMMON, COMMON, COMMON, UNCOMMON, RARE }
local ELITE_SLOTS = { UNCOMMON, UNCOMMON, RARE, RARE, EPIC }
local ELITE_PRICE = 8 -- an Elite pack costs this many times its set's Booster

-- Store tier needed to buy each set's packs. Price and colour live on the set, in Cards.
-- A pack can have image = "rbxassetid://..." cover art; upload assets/packs/<pack id>.png.
local SET_TIER = { storybook = 1, seas = 2, west = 3, midnight = 4, olympus = 5, knights = 6, rome = 7 }

Packs.List = {}

for _, setId in ipairs(Cards.SetOrder) do
	local set = Cards.Sets[setId]
	if not set.promo then
		local storeTier = SET_TIER[setId] or 1
		table.insert(Packs.List, {
			id = setId .. "_booster",
			name = set.name .. " Booster",
			currency = "cash",
			cost = set.packCost,
			storeTier = storeTier,
			sets = { setId },
			color = set.color,
			slots = BOOSTER_SLOTS,
			kind = "booster",
		})
		table.insert(Packs.List, {
			id = setId .. "_elite",
			name = set.name .. " Elite",
			currency = "cash",
			cost = set.packCost * ELITE_PRICE,
			storeTier = storeTier,
			sets = { setId },
			color = set.color:Lerp(Color3.new(0, 0, 0), 0.35),
			slots = ELITE_SLOTS,
			kind = "elite",
		})
	end
end

-- Special pack that pulls from every set (sets = nil).
table.insert(Packs.List, {
	id = "champion",
	name = "Champion Pack",
	currency = "aura", -- the one pack bought with aura; aura packs never get dearer
	cost = 500000,
	storeTier = 7,
	color = Color3.fromRGB(245, 245, 250),
	slots = { CHAMPION, CHAMPION, CHAMPION, CHAMPION, CHAMPION },
})
Packs.ById = {}
for _, pack in ipairs(Packs.List) do
	pack.size = #pack.slots
	Packs.ById[pack.id] = pack
end

-- Cash packs get a little dearer every time you open one in the same run (reset by rebirth).
-- This is the main brake on progress: early packs are cheap, the hundredth is not.
Packs.InflationPerPack = 0.018

-- Total price of the next `count` packs, given how many of this pack were already opened
-- this run. Includes the Bulk Deal perk. Aura packs never inflate.
function Packs.price(pack, opened, count, perks)
	local base = Perks.packCost(pack, perks)
	if pack.currency ~= "cash" then
		return base * count
	end
	local total = 0
	for index = 0, count - 1 do
		total = total + math.floor(base * (1 + Packs.InflationPerPack) ^ ((opened or 0) + index))
	end
	return total
end

-- The pack new players get for free.
Packs.StarterId = "storybook_booster"

-- Each luck level makes better rarities 10% more likely.
function Packs.luckMultiplier(luckLevel)
	return 1 + 0.1 * (luckLevel or 0)
end

-- Each luck level makes card effects (Shiny, Slimy, ...) 3% more likely.
function Packs.effectLuckMultiplier(luckLevel)
	return 1 + 0.03 * (luckLevel or 0)
end

-- "Storybook Friends", "High Seas" or "All sets"
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

-- Luck counts for less in later sets, so their rare cards stay hard to get however much
-- luck a player has stacked up. One entry per set, in set order; the last value repeats.
Packs.SetLuckScale = { 1, 0.8, 0.65, 0.5, 0.4, 0.3, 0.25 }

-- Every card slot of every pack keeps at least this chance of a Common, whatever the luck.
Packs.MinCommonChance = 0.01

local function luckScale(pack)
	if pack.sets == nil then
		return Packs.SetLuckScale[#Packs.SetLuckScale] -- all-set packs use the hardest scale
	end
	local scale = 1
	for position, setId in ipairs(Cards.SetOrder) do
		if table.find(pack.sets, setId) then
			scale = math.min(scale, Packs.SetLuckScale[position] or Packs.SetLuckScale[#Packs.SetLuckScale])
		end
	end
	return scale
end

-- The luck levels that actually apply to this pack (after the set's scale).
function Packs.effectiveLuck(pack, luckLevel)
	return (luckLevel or 0) * luckScale(pack)
end

-- The real odds of one slot of a pack: { [rarityName] = chance from 0 to 1 }.
-- Luck boosts every rarity above the slot's lowest one, then the Common floor is applied.
function Packs.slotOdds(pack, slot, luckLevel)
	local lowest = math.huge
	for rarityName in pairs(slot) do
		lowest = math.min(lowest, Cards.Rarities[rarityName].order)
	end
	local boost = Packs.luckMultiplier(Packs.effectiveLuck(pack, luckLevel))

	local weights, total = {}, 0
	for rarityName, weight in pairs(slot) do
		if Cards.Rarities[rarityName].order > lowest then
			weight = weight * boost
		end
		weights[rarityName] = weight
		total = total + weight
	end

	local odds = {}
	for rarityName, weight in pairs(weights) do
		odds[rarityName] = weight / total
	end

	-- Common floor: take the missing share evenly out of everything else.
	local common = odds.Common or 0
	if common < Packs.MinCommonChance then
		local shrink = (1 - Packs.MinCommonChance) / (1 - common)
		for rarityName, chance in pairs(odds) do
			odds[rarityName] = chance * shrink
		end
		odds.Common = Packs.MinCommonChance
	end
	return odds
end

local function rollSlot(pack, slot, luckLevel, rng)
	local odds = Packs.slotOdds(pack, slot, luckLevel)
	local pick = rng:NextNumber()
	local chosenRarity = nil
	for _, rarityName in ipairs(Cards.RarityOrder) do
		local chance = odds[rarityName]
		if chance and chance > 0 then
			chosenRarity = rarityName
			if pick < chance then
				break
			end
			pick = pick - chance
		end
	end

	local pool = Cards.pool(chosenRarity, pack.sets)
	local def = pool[rng:NextInteger(1, #pool)]

	-- Card effect: rarest first, the first hit is kept. Luck helps a little.
	local variantId = "normal"
	local effectLuck = Packs.effectLuckMultiplier(Packs.effectiveLuck(pack, luckLevel))
	for _, candidate in ipairs(Cards.RollOrder) do
		if rng:NextNumber() < Cards.Variants[candidate].chance * effectLuck then
			variantId = candidate
			break
		end
	end

	return Cards.makeKey(def.id, variantId)
end

-- Opens one pack: returns an array of card keys, one per slot. rng is a Random object.
function Packs.open(pack, luckLevel, rng)
	local keys = {}
	for index, slot in ipairs(pack.slots) do
		keys[index] = rollSlot(pack, slot, luckLevel, rng)
	end
	return keys
end

local function percentText(percent)
	if percent >= 99.95 then
		return "100%"
	elseif percent >= 10 then
		return string.format("%d%%", math.floor(percent + 0.5))
	end
	return string.format("%.2g%%", percent)
end

-- Human-readable odds, one line per kind of slot:
-- { "3 cards: Common 100%", "1 card: Uncommon 85% · Rare 15%", ... }
function Packs.oddsLines(pack, luckLevel)
	local lines = {}
	local index = 1
	while index <= #pack.slots do
		local slot = pack.slots[index]
		local count = 1
		while pack.slots[index + count] == slot do
			count = count + 1
		end
		local odds = Packs.slotOdds(pack, slot, luckLevel)
		local parts = {}
		for _, rarityName in ipairs(Cards.RarityOrder) do
			local chance = odds[rarityName]
			if chance and chance > 0 then
				table.insert(parts, rarityName .. " " .. percentText(chance * 100))
			end
		end
		table.insert(lines, count .. (count == 1 and " card: " or " cards: ") .. table.concat(parts, " · "))
		index = index + count
	end
	return lines
end

return Packs
