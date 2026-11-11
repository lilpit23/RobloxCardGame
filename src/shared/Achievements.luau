-- Achievements: long-term goals. Each one claimed gives a small PERMANENT income bonus and
-- some aura, and they are never reset by rebirth.
local Cards = require(script.Parent.Cards)
local Format = require(script.Parent.Format)

local Achievements = {}

Achievements.BonusEach = 0.03 -- +3% income per achievement claimed
Achievements.AuraEach = 200 -- aura for claiming one, times its tier (1, 2, 3, ...)

-- Each track is one statistic with rising goals. text uses %s for the goal; "one" is the
-- wording when the goal is 1.
local TRACKS = {
	{ stat = "packs", name = "Pack Ripper", text = "Open %s packs", goals = { 10, 100, 500, 2500, 10000, 50000 } },
	{ stat = "cards", name = "Collector", text = "Discover %s different cards (effects count)", goals = { 10, 50, 150, 400, 800, 1400 } },
	{ stat = "sets", name = "Set Master", text = "Complete %s sets", one = "Complete a set", goals = { 1, 2, 4, 6 } },
	{ stat = "rebirths", name = "Reborn", text = "Rebirth %s times", one = "Rebirth once", goals = { 1, 2, 4, 6, 8 } },
	{ stat = "tower", name = "Tower Climber", text = "Clear %s Battle Tower floors", goals = { 5, 15, 30, 50 } },
	{ stat = "fused", name = "Fusion Chef", text = "Fuse cards %s times", goals = { 5, 50, 250, 1000 } },
	{ stat = "earned", name = "Tycoon", text = "Earn %s in total", goals = { 1e6, 1e9, 1e12, 1e15, 1e18 }, cash = true },
	{ stat = "deck", name = "Full House", text = "Own %s deck slots", goals = { 8, 16, 32, 64 } },
}

Achievements.List = {}
Achievements.ById = {}
for _, track in ipairs(TRACKS) do
	for tier, goal in ipairs(track.goals) do
		local goalText = track.cash and Format.cash(goal) or Format.short(goal)
		local achievement = {
			id = track.stat .. "_" .. tier,
			stat = track.stat,
			tier = tier,
			goal = goal,
			name = track.name .. " " .. string.rep("★", tier),
			text = goal == 1 and track.one or string.format(track.text, goalText),
			cash = track.cash == true,
		}
		table.insert(Achievements.List, achievement)
		Achievements.ById[achievement.id] = achievement
	end
end

-- profile needs: packsOpened, collection, rebirths, tower, stats, slotCount (deck slots owned).
function Achievements.value(profile, stat)
	if stat == "packs" then
		return profile.packsOpened or 0
	elseif stat == "cards" then
		local count = 0
		for _ in pairs(profile.collection) do
			count = count + 1
		end
		return count
	elseif stat == "sets" then
		return Cards.completedSets(profile.collection)
	elseif stat == "rebirths" then
		return profile.rebirths or 0
	elseif stat == "tower" then
		return profile.tower or 0
	elseif stat == "deck" then
		return profile.slotCount or 0
	end
	local stats = profile.stats
	return stats and stats[stat] or 0
end

-- True if any achievement is finished but not yet claimed.
function Achievements.anyClaimable(profile, claimed)
	local cache = {}
	for _, achievement in ipairs(Achievements.List) do
		if not claimed[achievement.id] then
			local value = cache[achievement.stat]
			if value == nil then
				value = Achievements.value(profile, achievement.stat)
				cache[achievement.stat] = value
			end
			if value >= achievement.goal then
				return true
			end
		end
	end
	return false
end

-- What to show: for each track, every finished-but-unclaimed tier plus the next unfinished
-- one. Returns { { achievement, value, done }, ... } and how many are claimed in total.
function Achievements.display(profile, claimed)
	local rows = {}
	local claimedCount = 0
	local shownNext = {}
	for _, achievement in ipairs(Achievements.List) do
		if claimed[achievement.id] then
			claimedCount = claimedCount + 1
		else
			local value = Achievements.value(profile, achievement.stat)
			local done = value >= achievement.goal
			if done or not shownNext[achievement.stat] then
				table.insert(rows, { achievement = achievement, value = value, done = done })
				if not done then
					shownNext[achievement.stat] = true
				end
			end
		end
	end
	return rows, claimedCount
end

function Achievements.incomeMult(claimed)
	local count = 0
	for _ in pairs(claimed or {}) do
		count = count + 1
	end
	return 1 + Achievements.BonusEach * count
end

function Achievements.auraReward(achievement)
	return Achievements.AuraEach * achievement.tier
end

return Achievements
