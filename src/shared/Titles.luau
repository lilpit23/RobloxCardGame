-- Titles: names shown over a player's head, earned from collection, tower and rebirth
-- milestones. Earning one also pays aura once. Which titles a profile has earned is saved in
-- data.titles; the one being worn is data.title ("" = none).
local Cards = require(script.Parent.Cards)

local Titles = {}

Titles.List = {} -- { id, name, text, aura, rank, check = function(profile) -> boolean }
Titles.ById = {}

-- rank says how impressive a title is; "wear my best title" picks the highest rank earned.
local function add(id, name, text, aura, rank, check)
	local title = { id = id, name = name, text = text, aura = aura, rank = rank, check = check }
	table.insert(Titles.List, title)
	Titles.ById[id] = title
end

local SET_TITLES = {
	storybook = "Storyteller",
	seas = "Sea Dog",
	west = "Pilgrim",
	midnight = "Night Owl",
	olympus = "Olympian",
	knights = "Knight Errant",
	rome = "Centurion",
	america = "Trailblazer",
}

for index, setId in ipairs(Cards.SetOrder) do
	local set = Cards.Sets[setId]
	local name = SET_TITLES[setId] or set.name
	add("set_" .. setId, name, "Collect every " .. set.name .. " card", 500 * index, 10 * index, function(profile)
		local found, total = Cards.setProgress(profile.collection, setId)
		return found >= total
	end)
	add("gold_" .. setId, "Golden " .. name, "Collect every " .. set.name .. " card in Golden", 5000 * index, 100 + 10 * index, function(profile)
		for _, def in ipairs(set.cards) do
			if not profile.collection[Cards.makeKey(def.id, "gold")] then
				return false
			end
		end
		return true
	end)
end

for _, entry in ipairs({
	{ 10, "Tower Challenger" },
	{ 20, "Tower Knight" },
	{ 30, "Tower Champion" },
	{ 40, "Tower Legend" },
	{ 50, "Master of the Tower" },
}) do
	local floor = entry[1]
	add("tower_" .. floor, entry[2], "Clear floor " .. floor .. " of the Battle Tower", 30 * floor, 3 * floor, function(profile)
		return (profile.tower or 0) >= floor
	end)
end

for _, entry in ipairs({
	{ 1, "Reborn" },
	{ 3, "Thrice Reborn" },
	{ 5, "Phoenix" },
	{ 8, "Eternal" },
}) do
	local rebirths = entry[1]
	add("rebirth_" .. rebirths, entry[2], "Rebirth " .. rebirths .. (rebirths == 1 and " time" or " times"), 0, 25 * rebirths, function(profile)
		return (profile.rebirths or 0) >= rebirths
	end)
end

for _, entry in ipairs({
	{ 100, "Collector" },
	{ 400, "Curator" },
	{ 1000, "Grand Archivist" },
}) do
	local goal = entry[1]
	add("book_" .. goal, entry[2], "Discover " .. goal .. " different cards and effects", goal * 5, goal / 10, function(profile)
		local count = 0
		for _ in pairs(profile.collection) do
			count = count + 1
			if count >= goal then
				return true
			end
		end
		return false
	end)
end

-- Titles the profile qualifies for but has not been given yet. profile needs: collection,
-- tower, rebirths. owned = data.titles.
function Titles.newlyEarned(profile, owned)
	local list = {}
	for _, title in ipairs(Titles.List) do
		if not owned[title.id] and title.check(profile) then
			table.insert(list, title)
		end
	end
	return list
end

-- The highest-ranked title in owned (= data.titles), or "" if there are none.
function Titles.best(owned)
	local best = nil
	for _, title in ipairs(Titles.List) do
		if owned[title.id] and (best == nil or title.rank > best.rank) then
			best = title
		end
	end
	return best and best.id or ""
end

function Titles.name(id)
	local title = Titles.ById[id]
	return title and title.name or ""
end

return Titles
