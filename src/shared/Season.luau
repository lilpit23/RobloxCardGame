-- Things that change with the calendar:
--   * the SEASON PASS — a free reward track that resets every month; you earn season XP by
--     opening packs, clearing tower floors and finishing quests
--   * the weekly FEATURED SET — its packs get bonus luck for the week
local Cards = require(script.Parent.Cards)
local Format = require(script.Parent.Format)

local Season = {}

Season.XpPerLevel = 10
Season.MaxLevel = 30
Season.Xp = { pack = 1, floor = 5, quest = 10 }
Season.FeaturedLuck = 5 -- bonus luck levels when opening the featured set's packs

local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }

-- A number that changes once a month (UTC).
function Season.currentId()
	local now = os.date("!*t")
	return now.year * 12 + (now.month - 1)
end

function Season.name(seasonId)
	return MONTHS[seasonId % 12 + 1] .. " Season"
end

function Season.levelFor(xp)
	return math.min(Season.MaxLevel, math.floor((xp or 0) / Season.XpPerLevel))
end

-- The set whose packs are boosted this week. Promo sets are never featured.
function Season.featuredSet()
	local candidates = {}
	for _, setId in ipairs(Cards.SetOrder) do
		if not Cards.Sets[setId].promo then
			table.insert(candidates, setId)
		end
	end
	local week = math.floor(os.time() / (7 * 24 * 60 * 60))
	return candidates[week % #candidates + 1]
end

-- The reward for a season level:
--   every 10th level: a promo card that cannot be pulled from packs
--   every 5th level:  two free booster gifts
--   even levels:      aura
--   odd levels:       cash (two minutes of the player's income, at least $500)
-- Returns { kind = "promo"|"gift"|"aura"|"cash", amount = number, card = cardKey? }
function Season.reward(level, seasonId, incomePerSec)
	if level % 10 == 0 then
		local promo = Cards.Sets.promo.cards
		local def = promo[(seasonId + level / 10) % #promo + 1]
		return { kind = "promo", amount = 1, card = def.id }
	elseif level % 5 == 0 then
		return { kind = "gift", amount = 2 }
	elseif level % 2 == 0 then
		return { kind = "aura", amount = 100 * level }
	end
	return { kind = "cash", amount = math.max(500, math.floor((incomePerSec or 0) * 120)) }
end

function Season.rewardText(reward)
	if reward.kind == "promo" then
		return "Promo card: " .. Cards.getDisplayName(reward.card)
	elseif reward.kind == "gift" then
		return reward.amount .. " free boosters"
	elseif reward.kind == "aura" then
		return "+" .. Format.short(reward.amount) .. " aura"
	end
	return Format.cash(reward.amount)
end

return Season
