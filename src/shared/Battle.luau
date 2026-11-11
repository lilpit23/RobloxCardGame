-- Card battles. Pure logic: the server runs Battle.simulate and sends the log to the client,
-- which only plays it back. Built so the same simulate() can later run player vs player.
local Cards = require(script.Parent.Cards)

local Battle = {}

Battle.TeamSize = 3
Battle.MaxFloor = 50
Battle.MaxTurns = 80
Battle.TypeAdvantage = 1.3 -- damage multiplier when the attacker's type beats the target's

-- A fighting unit made from a card. Power grows with the square root of income, so a
-- Prismatic Secret is strong but not a billion times stronger than a Common.
function Battle.unitFromKey(key)
	local def = Cards.parse(key)
	if def == nil then
		return nil
	end
	local attack = math.max(1, math.floor(10 * math.sqrt(Cards.getIncome(key))))
	return {
		key = key,
		name = Cards.getDisplayName(key),
		glyph = def.glyph,
		type = def.type,
		attack = attack,
		maxHp = attack * 5,
		hp = attack * 5,
	}
end

-- Every card the profile owns, counting duplicates: inventory + display + vault.
local function ownedKeys(profile)
	local keys = {}
	for key, count in pairs(profile.inventory) do
		for _ = 1, math.min(count, Battle.TeamSize) do
			table.insert(keys, key)
		end
	end
	for _, key in pairs(profile.slots) do
		table.insert(keys, key)
	end
	for _, key in pairs(profile.vault) do
		table.insert(keys, key)
	end
	return keys
end

-- The strongest team the profile can field (array of units, may be shorter than TeamSize).
function Battle.bestTeam(profile)
	local units = {}
	for _, key in ipairs(ownedKeys(profile)) do
		local unit = Battle.unitFromKey(key)
		if unit then
			table.insert(units, unit)
		end
	end
	table.sort(units, function(a, b)
		if a.attack ~= b.attack then
			return a.attack > b.attack
		end
		return a.key < b.key
	end)
	local team = {}
	for index = 1, math.min(Battle.TeamSize, #units) do
		team[index] = units[index]
	end
	return team
end

-- The tower's enemy team for a floor. Same floor = same enemies for everyone.
function Battle.enemyTeam(floor)
	local attack = math.floor(8 * 1.25 ^ (floor - 1))
	local team = {}
	for index = 1, Battle.TeamSize do
		local def = Cards.List[(floor * 7 + index * 13) % #Cards.List + 1]
		local unitAttack = math.max(1, math.floor(attack * (0.85 + 0.15 * index)))
		team[index] = {
			name = "Shadow " .. def.name,
			glyph = def.glyph,
			type = def.type,
			attack = unitAttack,
			maxHp = unitAttack * 5,
			hp = unitAttack * 5,
		}
	end
	return team
end

-- Aura and cash for clearing a floor. The cash is limited to a share of the wallet cap so
-- the tower can never outrun the rest of the economy.
Battle.RewardCapShare = 0.05

function Battle.reward(floor, cashCap)
	local cash = math.floor(150 * 1.45 ^ floor)
	if cashCap and cashCap < math.huge then
		cash = math.min(cash, math.floor(cashCap * Battle.RewardCapShare))
	end
	return 40 * floor, cash
end

local function firstAlive(team)
	for index, unit in ipairs(team) do
		if unit.hp > 0 then
			return index
		end
	end
	return nil
end

-- Runs the fight. teamA attacks first. Units' hp fields are changed in place.
-- Returns aWins, log = { { side = "a"|"b", attacker, target, damage, hpLeft, strong }, ... }
function Battle.simulate(teamA, teamB, rng)
	local log = {}
	local order = {}
	for index = 1, math.max(#teamA, #teamB) do
		if teamA[index] then
			table.insert(order, { side = "a", index = index })
		end
		if teamB[index] then
			table.insert(order, { side = "b", index = index })
		end
	end

	local turns = 0
	while turns < Battle.MaxTurns do
		for _, turn in ipairs(order) do
			local mine = turn.side == "a" and teamA or teamB
			local theirs = turn.side == "a" and teamB or teamA
			local attacker = mine[turn.index]
			local targetIndex = firstAlive(theirs)
			if targetIndex == nil or firstAlive(mine) == nil then
				break
			end
			if attacker.hp > 0 then
				local target = theirs[targetIndex]
				local strong = Cards.typeBeats(attacker.type, target.type)
				local damage = attacker.attack * (0.85 + 0.3 * rng:NextNumber())
				if strong then
					damage = damage * Battle.TypeAdvantage
				end
				damage = math.max(1, math.floor(damage))
				target.hp = math.max(0, target.hp - damage)
				turns = turns + 1
				table.insert(log, {
					side = turn.side,
					attacker = turn.index,
					target = targetIndex,
					damage = damage,
					hpLeft = target.hp,
					strong = strong,
				})
			end
		end
		if firstAlive(teamA) == nil or firstAlive(teamB) == nil then
			break
		end
	end

	-- A draw (turn limit) counts as a loss for the attacker.
	return firstAlive(teamB) == nil and firstAlive(teamA) ~= nil, log
end

return Battle
