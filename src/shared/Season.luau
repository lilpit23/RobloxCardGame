-- The weekly FEATURED SET: one set a week whose packs get bonus luck.
local Cards = require(script.Parent.Cards)

local Season = {}

Season.FeaturedLuck = 5 -- bonus luck levels when opening the featured set's packs

-- The set whose packs are boosted this week.
function Season.featuredSet()
	local week = math.floor(os.time() / (7 * 24 * 60 * 60))
	return Cards.SetOrder[week % #Cards.SetOrder + 1]
end

return Season
