-- The Battle Tower: how tall it is and what clearing a floor pays. The fights themselves are
-- turn-based duels; their rules live in Duel.luau.
local Battle = {}

Battle.MaxFloor = 50

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

return Battle
