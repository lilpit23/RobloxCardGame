-- Deck building helpers. Pure logic, used by the server's "Auto-fill Deck".
local Cards = require(script.Parent.Cards)
local Combos = require(script.Parent.Combos)

local Deck = {}

-- Cash per second a deck (array of card keys) earns before store-wide multipliers:
-- the cards' own income times the deck's combo bonus.
function Deck.score(keys)
	local slots = {}
	local income = 0
	for index, key in ipairs(keys) do
		slots[tostring(index)] = key
		income = income + Cards.getIncome(key)
	end
	return income * Combos.evaluate(slots).income
end

local function byIncome(a, b)
	local incomeA, incomeB = Cards.getIncome(a), Cards.getIncome(b)
	if incomeA ~= incomeB then
		return incomeA > incomeB
	end
	return a < b
end

-- Picks the deck for `count` slots from the cards owned ({ [cardKey] = copies }).
-- Starts from the highest earners, then tries each story combo the player could complete:
-- it swaps the combo's missing cards in for the weakest cards and keeps the swap only if the
-- deck earns more. Returns an array of card keys (shorter than count if few cards are owned).
function Deck.autoFill(owned, count)
	local all = {}
	for key, copies in pairs(owned) do
		if Cards.parse(key) then
			for _ = 1, math.min(copies, count) do
				table.insert(all, key)
			end
		end
	end
	table.sort(all, byIncome)

	local deck = {}
	for index = 1, math.min(count, #all) do
		deck[index] = all[index]
	end
	if #deck < count then
		return deck -- everything owned already fits
	end

	-- The best copy owned of each card id (list is sorted, so the first seen is the best).
	local bestOwned = {}
	for _, key in ipairs(all) do
		local def = Cards.parse(key)
		if bestOwned[def.id] == nil then
			bestOwned[def.id] = key
		end
	end

	local bestScore = Deck.score(deck)
	for _, story in ipairs(Combos.Stories) do
		if #story.cards <= count then
			local inDeck = {}
			for _, key in ipairs(deck) do
				inDeck[Cards.parse(key).id] = true
			end
			local missing = {}
			local possible = true
			for _, id in ipairs(story.cards) do
				if not inDeck[id] then
					if bestOwned[id] then
						table.insert(missing, bestOwned[id])
					else
						possible = false
					end
				end
			end

			if possible and #missing > 0 then
				-- replace the weakest cards that are not part of this story
				local needed = {}
				for _, id in ipairs(story.cards) do
					needed[id] = true
				end
				local candidate = table.clone(deck)
				local swapped = 0
				for index = #candidate, 1, -1 do
					if swapped >= #missing then
						break
					end
					if not needed[Cards.parse(candidate[index]).id] then
						swapped = swapped + 1
						candidate[index] = missing[swapped]
					end
				end
				if swapped == #missing then
					local score = Deck.score(candidate)
					if score > bestScore then
						table.sort(candidate, byIncome)
						deck, bestScore = candidate, score
					end
				end
			end
		end
	end

	return deck
end

return Deck
