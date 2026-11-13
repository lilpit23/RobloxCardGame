-- Staff: the people who work in your store. Each one runs one or two of the permanent aura
-- upgrades (the perks in Perks.luau), has a desk on the shop floor that gets fancier as you
-- upgrade them, and says hello when you walk up. Some only join after a few rebirths.
local Perks = require(script.Parent.Perks)

local Staff = {}

Staff.Order = { "megan", "harshdeep", "alabaster", "fimby", "darius" }

-- perks = the perk ids this person looks after. rebirths = rebirths needed before they join.
Staff.Defs = {
	megan = {
		name = "Megan",
		role = "Fortune Teller",
		desk = "Fortune Table",
		perks = { "fortune" },
		rebirths = 0,
		color = Color3.fromRGB(190, 90, 220),
		face = "😊",
		hire = "I read the cards before you open them. Hire me and your luck goes up for good!",
		lines = {
			"Hi boss! The cards say today is a lucky day.",
			"I see a Legendary in your future... probably.",
			"Hello! Shuffle the deck three times for luck. Works every time.",
			"Hi! Your aura looks great today.",
		},
	},
	harshdeep = {
		name = "Harshdeep",
		role = "Stockroom Manager",
		desk = "Stockroom Desk",
		perks = { "packer", "discount" },
		rebirths = 0,
		color = Color3.fromRGB(70, 140, 230),
		face = "😄",
		hire = "I can open packs for you all day and haggle the price down. Just say the word.",
		lines = {
			"Hey boss! Fresh boosters just came in.",
			"Hello! I got us a deal on the next crate of packs.",
			"Hi! The stockroom has never been tidier.",
			"Packs in, cards out. That's the job!",
		},
	},
	alabaster = {
		name = "Alabaster",
		role = "Accountant",
		desk = "Accounts Desk",
		perks = { "startCash", "offline" },
		rebirths = 1,
		color = Color3.fromRGB(235, 200, 90),
		face = "🧐",
		hire = "I keep money aside for your next rebirth and keep the till ringing while you are away.",
		lines = {
			"Good day. The books are balanced, as always.",
			"Hello. I have set a little aside for your next fresh start.",
			"Ah, boss. The night takings were excellent.",
			"Every coin counted. Twice.",
		},
	},
	fimby = {
		name = "Fimby",
		role = "Aura Keeper",
		desk = "Aura Altar",
		perks = { "aura" },
		rebirths = 2,
		color = Color3.fromRGB(240, 110, 200),
		face = "🤩",
		hire = "Ooh, your cards are GLOWING. Let me tune them and they will glow even more!",
		lines = {
			"Hiii! Can you feel it? The aura in here is amazing!",
			"Hello hello! I polished every card's aura this morning.",
			"Boss! That shiny one winked at me, I swear.",
			"More aura, more sparkle. That's my motto!",
		},
	},
	darius = {
		name = "Darius",
		role = "Head of Security",
		desk = "Security Desk",
		perks = { "vault" },
		rebirths = 3,
		color = Color3.fromRGB(90, 100, 120),
		face = "😎",
		hire = "Nothing gets past me. Give me the budget and I will build you a bigger vault.",
		lines = {
			"Boss. All quiet. The vault is locked tight.",
			"Evening. Nobody touches the cards on my watch.",
			"Hello. I checked the safe. Then I checked it again.",
			"Your best cards are safe with me.",
		},
	},
}

-- [perkId] = staffId
Staff.ForPerk = {}
for _, id in ipairs(Staff.Order) do
	for _, perkId in ipairs(Staff.Defs[id].perks) do
		assert(Perks.Defs[perkId], "staff " .. id .. " runs unknown perk " .. perkId)
		Staff.ForPerk[perkId] = id
	end
end
for _, perkId in ipairs(Perks.Order) do
	assert(Staff.ForPerk[perkId], "perk " .. perkId .. " has nobody running it")
end

function Staff.unlocked(id, rebirths)
	return (rebirths or 0) >= Staff.Defs[id].rebirths
end

-- How far this person has been upgraded: the levels of their perks added up.
function Staff.level(perks, id)
	local total = 0
	for _, perkId in ipairs(Staff.Defs[id].perks) do
		total = total + Perks.level(perks, perkId)
	end
	return total
end

function Staff.maxLevel(id)
	local total = 0
	for _, perkId in ipairs(Staff.Defs[id].perks) do
		total = total + Perks.Defs[perkId].max
	end
	return total
end

-- What they say when someone walks up. rng needs :NextInteger.
function Staff.greeting(id, level, unlocked, rng)
	local def = Staff.Defs[id]
	if not unlocked then
		return def.name .. " will join after " .. def.rebirths .. (def.rebirths == 1 and " rebirth." or " rebirths.")
	elseif level < 1 then
		return def.hire
	end
	return def.lines[rng:NextInteger(1, #def.lines)]
end

return Staff
