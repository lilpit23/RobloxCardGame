-- The weekly FEATURED SET: one set a week whose packs get bonus luck.
local Cards = require(script.Parent.Cards)

local Season = {}

Season.FeaturedLuck = 5 -- bonus luck levels when opening the featured set's packs

-- The set whose packs are boosted this week.
function Season.featuredSet()
	local week = math.floor(os.time() / (7 * 24 * 60 * 60))
	return Cards.SetOrder[week % #Cards.SetOrder + 1]
end

-- The weekly EVENT: one bonus for everybody, changing every week.
--   cash / aura = multipliers on what the deck earns, luck = bonus luck levels on every pack,
--   tower = multiplier on aura from tower floors and the daily challenge.
Season.Events = {
	{ id = "gold", name = "💰 Gold Rush", text = "+25% cash from your deck", cash = 1.25 },
	{ id = "aura", name = "✨ Aura Bloom", text = "+50% aura from your deck", aura = 1.5 },
	{ id = "luck", name = "🍀 Lucky Week", text = "+3 luck on every pack", luck = 3 },
	{ id = "tower", name = "⚔️ Tower Week", text = "Double aura from tower floors and the daily challenge", tower = 2 },
}

function Season.event()
	local week = math.floor(os.time() / (7 * 24 * 60 * 60))
	return Season.Events[week % #Season.Events + 1]
end

return Season
