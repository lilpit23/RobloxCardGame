-- Battle Training: upgrades bought with aura that only count in player duels (the tower and
-- the daily challenge are untouched). Like the staff perks, they are kept through rebirths.
-- "training" below is the saved table { [trainingId] = level }.
local Training = {}

Training.Order = { "vitality", "might", "guard", "restoration" }

-- per = what one level gives; cost(level) = aura for the next level after `level`.
Training.Defs = {
	vitality = {
		name = "Vitality",
		icon = "❤️",
		max = 5,
		per = 6,
		cost = function(level)
			return 1500 * 3 ^ level
		end,
		describe = function(level)
			return "+" .. (6 * level) .. " health in player duels  (+6 per level)"
		end,
	},
	might = {
		name = "Might",
		icon = "⚔️",
		max = 5,
		per = 0.012,
		cost = function(level)
			return 2000 * 3 ^ level
		end,
		describe = function(level)
			return "Your hits deal +" .. (1.2 * level) .. "%  (+1.2% per level)"
		end,
	},
	guard = {
		name = "Guard",
		icon = "🛡️",
		max = 5,
		per = 0.012,
		cost = function(level)
			return 2000 * 3 ^ level
		end,
		describe = function(level)
			return "Hits on you deal -" .. (1.2 * level) .. "%  (+1.2% per level)"
		end,
	},
	restoration = {
		name = "Restoration",
		icon = "💚",
		max = 5,
		per = 0.03,
		cost = function(level)
			return 1500 * 3 ^ level
		end,
		describe = function(level)
			return "Heals, Mends and Drains heal +" .. (3 * level) .. "%  (+3% per level)"
		end,
	},
}

function Training.level(training, id)
	local level = training and training[id]
	if type(level) ~= "number" then
		return 0
	end
	return math.clamp(math.floor(level), 0, Training.Defs[id].max)
end

-- The numbers a fighter gets from its training, as Duel.pvpNew takes them.
function Training.stats(training)
	local function value(id)
		return Training.level(training, id) * Training.Defs[id].per
	end
	return {
		health = value("vitality"),
		might = 1 + value("might"),
		guard = 1 - value("guard"),
		healing = 1 + value("restoration"),
	}
end

-- Total levels bought, shown to the opponent so they know what they face.
function Training.total(training)
	local total = 0
	for _, id in ipairs(Training.Order) do
		total = total + Training.level(training, id)
	end
	return total
end

function Training.maxTotal()
	local total = 0
	for _, id in ipairs(Training.Order) do
		total = total + Training.Defs[id].max
	end
	return total
end

return Training
