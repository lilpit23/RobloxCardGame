-- Daily quests and the daily login reward. Three quests per player per day (UTC), paid in aura.
local Format = require(script.Parent.Format)

local Quests = {}

Quests.PerDay = 3

-- goals = possible targets, one is picked at random. cash = target scales with the player's income.
Quests.Types = {
	open_packs = { text = "Open %s packs", goals = { 5, 10, 20 } },
	pull_rare = { text = "Pull %s Epic or better cards", goals = { 1, 2, 4 } },
	sell = { text = "Sell %s cards", goals = { 5, 10, 20 } },
	fuse = { text = "Fuse cards %s times", goals = { 1, 2, 3 } },
	collect = { text = "Earn %s from your display stands", cash = true },
}

Quests.Order = { "open_packs", "pull_rare", "sell", "fuse", "collect" }

function Quests.today()
	return math.floor(os.time() / 86400)
end

-- Same player + same day always gives the same quest types.
function Quests.generate(day, userId, incomePerSec)
	local rng = Random.new(day * 1000 + userId % 1000)
	local pool = {}
	for _, questType in ipairs(Quests.Order) do
		table.insert(pool, questType)
	end
	local list = {}
	for _ = 1, math.min(Quests.PerDay, #pool) do
		local questType = table.remove(pool, rng:NextInteger(1, #pool))
		local def = Quests.Types[questType]
		local goal
		if def.cash then
			goal = math.max(250, math.floor(incomePerSec * 240)) -- about four minutes of income
		else
			goal = def.goals[rng:NextInteger(1, #def.goals)]
		end
		table.insert(list, { type = questType, goal = goal, progress = 0, claimed = false })
	end
	return list
end

function Quests.describe(quest)
	local def = Quests.Types[quest.type]
	if def == nil then
		return "?"
	end
	if def.cash then
		return string.format(def.text, Format.cash(quest.goal))
	end
	return string.format(def.text, tostring(quest.goal))
end

function Quests.progressText(quest)
	local def = Quests.Types[quest.type]
	if def and def.cash then
		return Format.cash(quest.progress) .. " / " .. Format.cash(quest.goal)
	end
	return math.floor(quest.progress) .. " / " .. quest.goal
end

-- Aura for finishing one quest.
function Quests.reward(rebirths)
	return 150 * (1 + (rebirths or 0))
end

-- Aura for the daily login reward; grows with the streak up to day 7.
function Quests.dailyAura(streak, rebirths)
	return 100 * math.clamp(streak, 1, 7) * (1 + (rebirths or 0))
end

return Quests
