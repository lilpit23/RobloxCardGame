-- Duels: the turn-based card battles of the Battle Tower. Pure logic, no Roblox services:
-- the server owns the duel state and calls play / pass / discard; the client only draws the
-- view and the events it is sent.
--
-- How a duel goes: you bring a battle deck built from cards you own. Each round you gain one
-- energy, draw back up to a full hand, and play ONE card (or pass and save your energy).
-- Then every enemy takes its turn. Rarer cards cost more energy and hit harder.
local Cards = require(script.Parent.Cards)

local Duel = {}

Duel.DeckSize = 20 -- most cards a battle deck can hold
Duel.MaxCopies = 3 -- of the same card + effect
Duel.MaxPricey = 8 -- auto-build keeps at most this many cards costing 4+ energy
Duel.HandSize = 5
Duel.StartEnergy = 2
Duel.MaxEnergy = 7
Duel.MaxRounds = 40 -- the enemies win if the fight drags on past this
Duel.MaxStacks = 3 -- shields / power-ups waiting on one fighter
Duel.Strong = 1.3 -- damage multiplier when the card's type beats the target's
Duel.Resisted = 0.75 -- ...and when the target's type beats the card's
Duel.BossEvery = 10 -- every tenth floor is a boss

-- Every type does its own kind of damage, and a Strike or Blast leaves its mark:
--   🐾 Beast   Bleed   the target loses a share of the hit at the end of each round; it stacks
--                       and halves every round
--   🔮 Mystic  Burn    the target burns for a few rounds (a new burn replaces a weaker one)
--   ⭐ Star    Chill   enough chills freeze the target: it loses its next turn and its wind-up,
--                       but takes less damage while frozen
--   ⚙️ Tech    Shock   ignores armour, and a Strike arcs to a second enemy
--   ⚔️ Warrior Stagger a hit on an enemy winding up breaks the wind-up and lands harder
-- And a Shield that takes a wind-up hit parries it: part of what it blocked hits the attacker.
Duel.Effects = {
	beast = { name = "Bleed", icon = "🩸", text = "Strikes make the target bleed every round (stacks)" },
	mystic = { name = "Burn", icon = "♨️", text = "Strikes set the target burning for 3 rounds" },
	star = { name = "Chill", icon = "❄️", text = "3 chills freeze an enemy: it loses its turn (bosses need 5)" },
	tech = { name = "Shock", icon = "⚡", text = "Ignores armour; Strikes arc to a second enemy" },
	warrior = { name = "Stagger", icon = "🔨", text = "Breaks a wind-up and hits it +25% harder" },
}
Duel.BleedShare = 0.15 -- of the damage dealt, added to the target's bleed
Duel.BurnShare = 0.12 -- of the damage dealt, burned each round...
Duel.BurnRounds = 3 -- ...for this many rounds
Duel.ChillToFreeze = 3
Duel.BossChillToFreeze = 5
Duel.FrozenGuard = 0.3 -- a frozen enemy takes this much less damage
Duel.ShockArc = 0.3 -- share of a Tech Strike that arcs to another enemy
Duel.StaggerBonus = 1.25
Duel.Parry = 0.5 -- share of the damage a shield blocks from a wind-up hit that goes back
Duel.PoisonShare = 0.4 -- of a venomous enemy's hit, added to your poison

-- What a card does when played. Every card has exactly one role.
Duel.Roles = {
	attack = { name = "Strike", icon = "⚔️", target = true },
	blast = { name = "Blast", icon = "💥" },
	heal = { name = "Heal", icon = "💚" },
	shield = { name = "Shield", icon = "🛡️" },
	charge = { name = "Power-up", icon = "💪" },
	weaken = { name = "Weaken", icon = "🌀", target = true },
}

-- Every third card of a type has that type's signature role; the rest are Strikes.
local SIGNATURE = { warrior = "charge", beast = "blast", mystic = "heal", tech = "shield", star = "weaken" }

-- Characters whose role is picked by hand because the story calls for it.
local ROLE_OVERRIDES = {
	merlin = "charge",
	dr_watson = "heal",
	sir_galahad = "shield",
	van_helsing = "weaken",
	the_kraken = "blast",
	moby_dick = "blast",
	zeus = "blast",
	athena = "shield",
	apollo = "heal",
	medusa = "weaken",
	excalibur = "charge",
	tinker_bell = "heal",
	tin_woodman = "shield",
	hannibal = "charge",
	war_elephant = "blast",
	marcus_aurelius = "heal",
	tang_sanzang = "heal",
	sun_wukong = "attack",
	sherlock_holmes = "weaken",
	count_dracula = "attack",
	king_arthur = "attack",
	hercules = "attack",
	paul_bunyan = "blast",
	thor = "attack",
	jormungandr = "blast",
	heimdall = "shield",
	freya = "heal",
	loki = "weaken",
	odin = "charge",
	john_henry = "attack",
	lady_liberty = "shield",
	george_washington = "charge",
}
for id in pairs(ROLE_OVERRIDES) do
	assert(Cards.ById[id], "Duel role override for unknown card " .. id)
end

local function roleOf(def)
	local override = ROLE_OVERRIDES[def.id]
	if override then
		return override
	end
	if def.number % 3 == 0 then
		return SIGNATURE[def.type] or "attack"
	end
	return "attack"
end

local function percent(value)
	return math.floor(value * 100 + 0.5) .. "%"
end

local function short(value)
	if value >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e4 then
		return string.format("%.1fK", value / 1e3)
	end
	return tostring(math.floor(value))
end
Duel.short = short

-- The battle version of a card: { key, name, glyph, type, role, cost, power, amount, text }.
-- power grows with the square root of the card's income, so a Prismatic Secret is strong but
-- not a billion times stronger than a Common. amount is what the role does: damage, healing,
-- or a fraction for shields, power-ups and weakens.
local cardCache = {}
function Duel.card(key)
	local cached = cardCache[key]
	if cached then
		return cached
	end
	local def = Cards.parse(key)
	if def == nil then
		return nil
	end
	local cost = Cards.Rarities[def.rarity].order
	if cost > 1 then
		cost = cost - 1 -- Common 1, Uncommon 1, Rare 2 ... Secret 6
	end
	local power = math.max(1, math.floor(10 * math.sqrt(Cards.getIncome(key))))
	local role = roleOf(def)
	local amount, text
	local effect = Duel.Effects[def.type]
	if role == "attack" then
		amount = power
		text = short(amount) .. " damage to one enemy" .. (effect and (" · " .. effect.icon .. " " .. effect.name) or "")
	elseif role == "blast" then
		amount = math.max(1, math.floor(power * 0.5))
		text = short(amount) .. " damage to every enemy" .. (effect and (" · " .. effect.icon .. " " .. effect.name) or "")
	elseif role == "heal" then
		amount = math.floor(power * 1.5)
		text = "Heal " .. short(amount) .. " health and cure poison"
	elseif role == "shield" then
		amount = math.min(0.8, 0.3 + 0.08 * cost)
		text = "Block " .. percent(amount) .. " of the next hit on you"
	elseif role == "charge" then
		amount = 0.25 + 0.1 * cost
		text = "Your next attack deals +" .. percent(amount)
	else
		amount = math.min(0.8, 0.3 + 0.08 * cost)
		text = "One enemy's next attack deals -" .. percent(amount)
	end
	local card = {
		key = key,
		name = Cards.getDisplayName(key),
		glyph = def.glyph,
		type = def.type,
		role = role,
		cost = cost,
		power = power,
		amount = amount,
		text = text,
	}
	cardCache[key] = card
	return card
end

-- How many copies of each exact card the profile owns: inventory + deck + vault.
function Duel.ownedCounts(profile)
	local counts = {}
	for key, count in pairs(profile.inventory) do
		counts[key] = (counts[key] or 0) + count
	end
	for _, key in pairs(profile.slots) do
		counts[key] = (counts[key] or 0) + 1
	end
	for _, key in pairs(profile.vault) do
		counts[key] = (counts[key] or 0) + 1
	end
	return counts
end

-- The part of a saved battle deck the profile can still field: cards that were sold, fused
-- away drop out. Returns a new array of keys.
function Duel.usableDeck(profile, saved)
	local counts = Duel.ownedCounts(profile)
	local used = {}
	local deck = {}
	for _, key in ipairs(saved or {}) do
		if #deck >= Duel.DeckSize then
			break
		end
		local taken = used[key] or 0
		if type(key) == "string" and Duel.card(key) and taken < math.min(counts[key] or 0, Duel.MaxCopies) then
			used[key] = taken + 1
			table.insert(deck, key)
		end
	end
	return deck
end

-- A sensible deck from everything the profile owns: the strongest cards, but not so many
-- expensive ones that the early rounds have nothing to play.
function Duel.autoDeck(profile)
	local options = {}
	for key, count in pairs(Duel.ownedCounts(profile)) do
		local card = Duel.card(key)
		if card then
			for _ = 1, math.min(count, Duel.MaxCopies) do
				table.insert(options, card)
			end
		end
	end
	table.sort(options, function(a, b)
		if a.power ~= b.power then
			return a.power > b.power
		end
		return a.key < b.key
	end)
	local deck, pricey = {}, 0
	for _, card in ipairs(options) do
		if #deck >= Duel.DeckSize then
			break
		end
		if card.cost < 4 then
			table.insert(deck, card.key)
		elseif pricey < Duel.MaxPricey then
			pricey = pricey + 1
			table.insert(deck, card.key)
		end
	end
	return deck
end

-- Health a deck gives its owner: eight times its average card power.
function Duel.deckHealth(deck)
	local total, count = 0, 0
	for _, key in ipairs(deck) do
		local card = Duel.card(key)
		if card then
			total = total + card.power
			count = count + 1
		end
	end
	if count == 0 then
		return 0
	end
	return math.max(60, math.floor(8 * total / count))
end

-- The enemies on a floor. Same floor = same enemies for everyone.
function Duel.floorPower(floor)
	return 10 * 1.16 ^ (floor - 1)
end

-- The tower is themed by set: the first floors are haunted by Storybook characters, the last
-- by Romans. Returns the set id for a floor.
Duel.FloorsPerSet = 7
Duel.TowerSets = 7 -- the tower's enemies are drawn from the first seven sets
function Duel.floorSet(floor)
	return Cards.SetOrder[math.min(Duel.TowerSets, math.floor((floor - 1) / Duel.FloorsPerSet) + 1)]
end

local SET_PREFIX = {
	storybook = "Runaway",
	seas = "Cursed",
	west = "Demon",
	midnight = "Haunted",
	olympus = "Fallen",
	knights = "Rogue",
	rome = "Rebel",
	america = "Rival", -- only met in the daily challenge; the tower stops at the Rome floors
	norse = "Frostbound",
}

-- Kinds of enemy. Brutes just hit; the others have a trick, shown on the duel screen.
Duel.Kinds = {
	brute = { name = "", text = "" },
	healer = { name = "💚 Healer", text = "Heals its most hurt ally instead of attacking" },
	armored = { name = "🛡️ Armoured", text = "Takes 35% less damage" },
	berserker = { name = "😡 Berserker", text = "Hits harder every round" },
	venomous = { name = "🐍 Venomous", text = "Its hits poison you; a Heal cures it" },
	warded = { name = "🔮 Warded", text = "Shrugs off bleed, burn and chill" },
	summoner = { name = "📯 Summoner", text = "Calls a knocked-out ally back to fight (once each)" },
}
Duel.Armor = 0.35
Duel.HealShare = 0.12 -- of the healed ally's full health
Duel.BerserkGrowth = 1.12
Duel.BossRegen = 0.04 -- of the boss's full health, each round (second boss onwards)
Duel.EnrageBelow = 0.5 -- third boss onwards: below this share of health it hits harder
Duel.EnrageDamage = 1.4
Duel.SummonShare = 0.4 -- of its full health, a called-back ally returns with

local function kindFor(floor, index, isBoss)
	if isBoss or index == 1 then
		return "brute"
	end
	local roll = (floor * 5 + index * 3) % 6
	if floor >= 6 and roll == 0 then
		return "healer"
	elseif floor >= 12 and roll == 1 then
		return "armored"
	elseif floor >= 18 and roll == 2 then
		return "berserker"
	elseif floor >= 15 and roll == 3 then
		return "venomous"
	elseif floor >= 22 and roll == 4 then
		return "warded"
	elseif floor >= 30 and roll == 5 then
		return "summoner"
	end
	return "brute"
end

-- power and setId are only given by the daily challenge, which borrows a floor's line-up but
-- sets its own strength and theme.
function Duel.enemies(floor, power, setId)
	power = power or Duel.floorPower(floor)
	local boss = floor % Duel.BossEvery == 0
	local bossNumber = math.floor(floor / Duel.BossEvery)
	local count = 3
	if floor <= 3 then
		count = 1
	elseif floor <= 9 then
		count = 2
	end
	setId = setId or Duel.floorSet(floor)
	local pool = Cards.Sets[setId].cards
	local list = {}
	for index = 1, count do
		local def = pool[(floor * 7 + index * 13) % #pool + 1]
		local isBoss = boss and index == 1
		local kind = kindFor(floor, index, isBoss)
		local hp = math.max(10, math.floor(power * (isBoss and 6 or 2.5)))
		local attack = power * (isBoss and 0.55 or 0.32)
		if kind == "healer" or kind == "summoner" then
			attack = attack * 0.6
		elseif kind == "berserker" then
			attack = attack * 0.7
		elseif kind == "venomous" then
			attack = attack * 0.8
		end
		list[index] = {
			name = (isBoss and "👑 " or "") .. SET_PREFIX[setId] .. " " .. def.name,
			glyph = def.glyph,
			type = def.type,
			boss = isBoss,
			kind = kind,
			regen = isBoss and bossNumber >= 2, -- heals a little every round
			armor = (kind == "armored" or (isBoss and bossNumber >= 4)) and Duel.Armor or 0,
			enrages = isBoss and bossNumber >= 3,
			attack = math.max(1, math.floor(attack)),
			maxHp = hp,
			hp = hp,
			weak = {}, -- fractions taken off its next attacks
			winding = false, -- a boss about to land its big hit
			bleed = 0, -- damage at the end of each round, halving
			burn = 0, -- damage at the end of each round...
			burnRounds = 0, -- ...for this many more rounds
			chill = 0,
			frozen = false, -- loses its next turn
			raised = false, -- already called back once by a summoner
		}
	end
	return list
end

-- The daily challenge: everyone gets the same preset deck and the same enemies for the day,
-- so it is a test of play rather than of collection. day = Quests.today().
-- Returns { set = setId, deck = { cardKey, ... }, floor = the tower floor whose line-up you
-- face, power = how strong those enemies are }.
Duel.ChallengePower = 25 -- enemy strength for a Storybook deck; doubles with each later set
function Duel.challenge(day)
	local setIndex = day % #Cards.SetOrder + 1
	local set = Cards.Sets[Cards.SetOrder[setIndex]]
	local byRarity = {}
	for _, def in ipairs(set.cards) do
		byRarity[def.rarity] = byRarity[def.rarity] or {}
		table.insert(byRarity[def.rarity], def)
	end
	local deck = {}
	local function take(rarity, count, effect)
		local pool = byRarity[rarity] or {}
		for pick = 1, math.min(count, #pool) do
			local def = pool[(day * 3 + pick * 5) % #pool + 1]
			table.insert(deck, effect and Cards.makeKey(def.id, effect) or def.id)
		end
	end
	take("Common", 4)
	take("Uncommon", 4)
	take("Rare", 3)
	take("Epic", 2)
	take("Legendary", 1, "holo")
	return { set = set.id, deck = deck, floor = 11 + day % 8, power = Duel.ChallengePower * 2 ^ (setIndex - 1) }
end

local function shuffle(list, rng)
	for index = #list, 2, -1 do
		local other = rng:NextInteger(1, index)
		list[index], list[other] = list[other], list[index]
	end
end

local function draw(state, rng)
	while #state.hand < Duel.HandSize do
		if #state.deck == 0 then
			if #state.discard == 0 then
				return
			end
			state.deck, state.discard = state.discard, {}
			shuffle(state.deck, rng)
		end
		table.insert(state.hand, table.remove(state.deck))
	end
end

local function firstAlive(state)
	for index, enemy in ipairs(state.enemies) do
		if enemy.hp > 0 then
			return index
		end
	end
	return nil
end

-- A new duel. deck = array of card keys (already checked with usableDeck). Returns nil if
-- the deck is empty.
function Duel.new(floor, deck, rng, mode, enemies)
	local pile = {}
	for _, key in ipairs(deck) do
		if Duel.card(key) then
			table.insert(pile, key)
		end
	end
	if #pile == 0 then
		return nil
	end
	local health = Duel.deckHealth(pile)
	shuffle(pile, rng)
	local state = {
		floor = floor,
		mode = mode or "tower",
		round = 1,
		energy = Duel.StartEnergy,
		hp = health,
		maxHp = health,
		shields = {}, -- fractions blocked from the next hits
		charges = {}, -- fractions added to the next attacks
		poison = 0, -- damage you take at the end of each round, halving
		enemies = enemies or Duel.enemies(floor),
		deck = pile,
		hand = {},
		discard = {},
		over = false,
		win = false,
	}
	draw(state, rng)
	return state
end

function Duel.chillToFreeze(enemy)
	return enemy.boss and Duel.BossChillToFreeze or Duel.ChillToFreeze
end

-- What the client is allowed to see (everything except the order of the draw pile).
function Duel.view(state)
	local enemies = {}
	for index, enemy in ipairs(state.enemies) do
		enemies[index] = {
			name = enemy.name,
			glyph = enemy.glyph,
			type = enemy.type,
			boss = enemy.boss,
			kind = enemy.kind,
			regen = enemy.regen,
			armor = enemy.armor,
			enrages = enemy.enrages,
			attack = enemy.attack,
			hp = enemy.hp,
			maxHp = enemy.maxHp,
			weak = #enemy.weak,
			winding = enemy.winding,
			bleed = enemy.bleed,
			burn = enemy.burnRounds > 0 and enemy.burn or 0,
			chill = enemy.chill,
			chillMax = Duel.chillToFreeze(enemy),
			frozen = enemy.frozen,
		}
	end
	return {
		floor = state.floor,
		mode = state.mode,
		round = state.round,
		energy = state.energy,
		hp = state.hp,
		maxHp = state.maxHp,
		shields = #state.shields,
		charges = #state.charges,
		poison = state.poison,
		enemies = enemies,
		hand = table.clone(state.hand),
		deckLeft = #state.deck,
		over = state.over,
		win = state.win,
	}
end

-- Throw a card away for free; a new one is drawn at the start of the next round.
function Duel.discard(state, handIndex)
	if state.over or type(handIndex) ~= "number" or state.hand[handIndex] == nil then
		return false
	end
	table.insert(state.discard, table.remove(state.hand, handIndex))
	return true
end

-- The bleed, burn or chill a hit leaves (Duel.Effects). Returns a few words for the log.
local function markEnemy(enemy, card, damage)
	if card.type == "beast" or card.type == "mystic" or card.type == "star" then
		if enemy.kind == "warded" then
			return " (warded)"
		end
	end
	if card.type == "beast" then
		local added = math.max(1, math.floor(damage * Duel.BleedShare))
		enemy.bleed = enemy.bleed + added
		return " 🩸" .. short(enemy.bleed)
	elseif card.type == "mystic" then
		local burn = math.max(1, math.floor(damage * Duel.BurnShare))
		if burn >= enemy.burn or enemy.burnRounds <= 0 then
			enemy.burn = burn
		end
		enemy.burnRounds = Duel.BurnRounds
		return " ♨️"
	elseif card.type == "star" then
		enemy.chill = enemy.chill + 1
		if enemy.chill >= Duel.chillToFreeze(enemy) then
			enemy.chill = 0
			enemy.frozen = true
			enemy.winding = false
			return " ❄️ FROZEN!"
		end
		return " ❄️" .. enemy.chill .. "/" .. Duel.chillToFreeze(enemy)
	end
	return ""
end

-- arc: this is the second, smaller hit of a Tech Strike (it does not arc again).
local function hitEnemy(state, events, card, index, damage, arc)
	local enemy = state.enemies[index]
	local strong = Cards.typeBeats(card.type, enemy.type)
	local resisted = Cards.typeBeats(enemy.type, card.type)
	if strong then
		damage = damage * Duel.Strong
	elseif resisted then
		damage = damage * Duel.Resisted
	end
	local pierced = card.type == "tech" and enemy.armor > 0
	if enemy.armor > 0 and not pierced then
		damage = damage * (1 - enemy.armor)
	end
	local staggered = card.type == "warrior" and enemy.winding
	if staggered then
		damage = damage * Duel.StaggerBonus
		enemy.winding = false
	end
	if enemy.frozen then
		damage = damage * (1 - Duel.FrozenGuard)
	end
	damage = math.max(1, math.floor(damage))
	enemy.hp = math.max(0, enemy.hp - damage)
	local text = (arc and "⚡ The shock arcs to " or (card.name .. " hits ")) .. enemy.name .. " for " .. short(damage)
	if pierced then
		text = text .. " (through armour)"
	elseif enemy.armor > 0 then
		text = text .. " (armour)"
	end
	if strong then
		text = text .. " — type advantage!"
	elseif resisted then
		text = text .. " (resisted)"
	end
	if staggered then
		text = text .. " 🔨 Wind-up broken!"
	end
	if enemy.hp <= 0 then
		text = text .. "  KO!"
	elseif not arc then
		text = text .. markEnemy(enemy, card, damage)
	end
	table.insert(events, { kind = "hit", text = text, enemy = index, enemyHp = enemy.hp, damage = damage, strong = strong })

	if card.type == "tech" and card.role == "attack" and not arc then
		-- a Tech Strike arcs to the healthiest other enemy still standing
		local other, most = nil, 0
		for otherIndex, otherEnemy in ipairs(state.enemies) do
			if otherIndex ~= index and otherEnemy.hp > most then
				other, most = otherIndex, otherEnemy.hp
			end
		end
		if other then
			hitEnemy(state, events, card, other, card.amount * Duel.ShockArc, true)
		end
	end
end

-- The living enemy missing the biggest share of its health, or nil if nobody is hurt.
local function mostHurt(state)
	local best, worst = nil, 1
	for index, enemy in ipairs(state.enemies) do
		if enemy.hp > 0 and enemy.hp / enemy.maxHp < worst then
			best, worst = index, enemy.hp / enemy.maxHp
		end
	end
	return best
end

-- The enemies' turn, then the start of the next round.
local function finishRound(state, events, rng)
	if firstAlive(state) == nil then
		state.over, state.win = true, true
		table.insert(events, { kind = "win", text = "🏆 Victory!" })
		return
	end

	for index, enemy in ipairs(state.enemies) do
		-- bleeding and burning come first, and can finish an enemy before it acts
		if enemy.hp > 0 and (enemy.bleed > 0 or enemy.burnRounds > 0) then
			local damage, parts = 0, {}
			if enemy.bleed > 0 then
				damage = damage + enemy.bleed
				table.insert(parts, "bleeds")
				enemy.bleed = math.floor(enemy.bleed / 2)
			end
			if enemy.burnRounds > 0 then
				damage = damage + enemy.burn
				table.insert(parts, "burns")
				enemy.burnRounds = enemy.burnRounds - 1
			end
			enemy.hp = math.max(0, enemy.hp - damage)
			local text = enemy.name .. " " .. table.concat(parts, " and ") .. " for " .. short(damage)
			if enemy.hp <= 0 then
				text = text .. "  KO!"
			end
			table.insert(events, { kind = "tick", text = text, enemy = index, enemyHp = enemy.hp, damage = damage })
		end
		if enemy.hp > 0 and enemy.frozen and state.hp > 0 then
			enemy.frozen = false
			table.insert(events, { kind = "frozen", text = "❄️ " .. enemy.name .. " is frozen solid and loses its turn.", enemy = index })
		elseif enemy.hp > 0 and state.hp > 0 then
			if enemy.regen and enemy.hp < enemy.maxHp then
				enemy.hp = math.min(enemy.maxHp, enemy.hp + math.floor(enemy.maxHp * Duel.BossRegen))
				table.insert(events, { kind = "mend", text = enemy.name .. " regenerates.", enemy = index, enemyHp = enemy.hp })
			end
			local hurtAlly = enemy.kind == "healer" and mostHurt(state) or nil
			local fallen = nil
			if enemy.kind == "summoner" then
				for otherIndex, other in ipairs(state.enemies) do
					if other.hp <= 0 and not other.raised then
						fallen = otherIndex
						break
					end
				end
			end
			if fallen then
				local ally = state.enemies[fallen]
				ally.raised = true
				ally.hp = math.max(1, math.floor(ally.maxHp * Duel.SummonShare))
				ally.bleed, ally.burn, ally.burnRounds, ally.chill, ally.frozen, ally.winding = 0, 0, 0, 0, false, false
				ally.weak = {}
				table.insert(events, { kind = "summon", text = "📯 " .. enemy.name .. " calls " .. ally.name .. " back to fight!", enemy = fallen, enemyHp = ally.hp })
			elseif hurtAlly then
				local ally = state.enemies[hurtAlly]
				ally.hp = math.min(ally.maxHp, ally.hp + math.floor(ally.maxHp * Duel.HealShare))
				table.insert(events, { kind = "mend", text = enemy.name .. " heals " .. (hurtAlly == index and "itself" or ally.name) .. ".", enemy = hurtAlly, enemyHp = ally.hp })
			elseif enemy.boss and not enemy.winding and state.round % 3 == 2 then
				-- bosses spend a turn winding up, so you can see the big hit coming
				enemy.winding = true
				table.insert(events, { kind = "windup", text = "⚠️ " .. enemy.name .. " is winding up a huge attack!", enemy = index })
			else
				local damage = enemy.attack * (0.85 + 0.3 * rng:NextNumber())
				local bigHit = enemy.winding
				if bigHit then
					damage = damage * 2.2
					enemy.winding = false
				end
				local enraged = enemy.enrages and enemy.hp < enemy.maxHp * Duel.EnrageBelow
				if enraged then
					damage = damage * Duel.EnrageDamage
				end
				local weak = table.remove(enemy.weak, 1)
				if weak then
					damage = damage * (1 - weak)
				end
				local blocked = table.remove(state.shields, 1)
				local parried = 0
				if blocked then
					if bigHit then
						parried = math.floor(damage * blocked * Duel.Parry)
					end
					damage = damage * (1 - blocked)
				end
				damage = math.max(1, math.floor(damage))
				state.hp = math.max(0, state.hp - damage)
				local text = enemy.name .. (enraged and " is enraged and hits you for " or " hits you for ") .. short(damage)
				if enemy.kind == "venomous" then
					state.poison = state.poison + math.max(1, math.floor(damage * Duel.PoisonShare))
					text = text .. " 🐍"
				end
				if enemy.kind == "berserker" then
					enemy.attack = math.max(enemy.attack + 1, math.floor(enemy.attack * Duel.BerserkGrowth))
				end
				if blocked then
					text = text .. " (shield blocked " .. percent(blocked) .. ")"
				elseif weak then
					text = text .. " (weakened)"
				end
				table.insert(events, { kind = "hurt", text = text, enemy = index, hp = state.hp, damage = damage, attack = enemy.attack })
				if parried > 0 then
					enemy.hp = math.max(0, enemy.hp - parried)
					table.insert(events, { kind = "parry", text = "🛡️ Parried! " .. short(parried) .. " goes back at " .. enemy.name .. (enemy.hp <= 0 and "  KO!" or ""), enemy = index, enemyHp = enemy.hp, damage = parried })
				end
			end
		end
	end

	if state.hp > 0 and firstAlive(state) == nil then
		state.over, state.win = true, true
		table.insert(events, { kind = "win", text = "🏆 Victory!" })
		return
	end
	if state.poison > 0 and state.hp > 0 then
		state.hp = math.max(0, state.hp - state.poison)
		table.insert(events, { kind = "poison", text = "🐍 Poison hurts you for " .. short(state.poison), hp = state.hp, damage = state.poison })
		state.poison = math.floor(state.poison / 2)
	end

	if state.hp <= 0 then
		state.over, state.win = true, false
		table.insert(events, { kind = "lose", text = "💀 Defeated on round " .. state.round .. "." })
		return
	end
	if state.round >= Duel.MaxRounds then
		state.over, state.win = true, false
		table.insert(events, { kind = "lose", text = "💀 Out of time — the tower's guardians outlast you." })
		return
	end

	state.round = state.round + 1
	state.energy = math.min(Duel.MaxEnergy, state.energy + 1)
	draw(state, rng)
end

-- Save your energy this round. Returns the list of events.
function Duel.pass(state, rng)
	if state.over then
		return nil, "This battle is over."
	end
	local events = { { kind = "pass", text = "You hold your cards and gather energy." } }
	finishRound(state, events, rng)
	return events
end

-- Play the card at handIndex (at enemy targetIndex, for cards that need a target).
-- Returns events, or nil and a message for the player.
function Duel.play(state, handIndex, targetIndex, rng)
	if state.over then
		return nil, "This battle is over."
	end
	if type(handIndex) ~= "number" or state.hand[handIndex] == nil then
		return nil, "Pick a card from your hand."
	end
	local card = Duel.card(state.hand[handIndex])
	if card.cost > state.energy then
		return nil, "Not enough energy: that card costs " .. card.cost .. "."
	end
	local role = Duel.Roles[card.role]
	if role.target then
		local target = type(targetIndex) == "number" and state.enemies[targetIndex] or nil
		if target == nil or target.hp <= 0 then
			targetIndex = firstAlive(state)
		end
	end

	state.energy = state.energy - card.cost
	table.insert(state.discard, table.remove(state.hand, handIndex))
	local events = {}

	if card.role == "attack" or card.role == "blast" then
		local boost = table.remove(state.charges, 1)
		local damage = card.amount * (1 + (boost or 0))
		if boost then
			table.insert(events, { kind = "boost", text = "🔥 Power-up: +" .. percent(boost) .. " damage!" })
		end
		if card.role == "attack" then
			hitEnemy(state, events, card, targetIndex, damage)
		else
			for index, enemy in ipairs(state.enemies) do
				if enemy.hp > 0 then
					hitEnemy(state, events, card, index, damage)
				end
			end
		end
	elseif card.role == "heal" then
		local healed = math.min(card.amount, state.maxHp - state.hp)
		state.hp = state.hp + healed
		local cured = state.poison > 0
		state.poison = 0
		table.insert(events, { kind = "heal", text = card.name .. " heals you for " .. short(healed) .. (cured and " and cures the poison" or ""), hp = state.hp })
	elseif card.role == "shield" then
		if #state.shields >= Duel.MaxStacks then
			table.remove(state.shields, 1)
		end
		table.insert(state.shields, card.amount)
		table.insert(events, { kind = "shield", text = card.name .. " shields you: the next hit is cut by " .. percent(card.amount) })
	elseif card.role == "charge" then
		if #state.charges >= Duel.MaxStacks then
			table.remove(state.charges, 1)
		end
		table.insert(state.charges, card.amount)
		table.insert(events, { kind = "charge", text = card.name .. " powers you up: your next attack deals +" .. percent(card.amount) })
	else
		local enemy = state.enemies[targetIndex]
		if #enemy.weak >= Duel.MaxStacks then
			table.remove(enemy.weak, 1)
		end
		table.insert(enemy.weak, card.amount)
		table.insert(events, { kind = "weaken", text = card.name .. " weakens " .. enemy.name .. ": its next attack deals -" .. percent(card.amount), enemy = targetIndex })
	end

	finishRound(state, events, rng)
	return events
end

-- How much a hit of `damage` from `card` is worth against one enemy in a view, counting its
-- bleed / burn / chill / stagger and finishing the enemy off.
local function hitValue(card, enemy, damage)
	if Cards.typeBeats(card.type, enemy.type) then
		damage = damage * Duel.Strong
	elseif Cards.typeBeats(enemy.type, card.type) then
		damage = damage * Duel.Resisted
	end
	if card.type ~= "tech" then
		damage = damage * (1 - (enemy.armor or 0))
	end
	if enemy.frozen then
		damage = damage * (1 - Duel.FrozenGuard)
	end
	local value = 0
	if card.type == "warrior" and enemy.winding then
		damage = damage * Duel.StaggerBonus
		value = value + enemy.attack * 2 -- the big hit never lands
	end
	local hp = enemy.hp - (enemy.bleed or 0) - (enemy.burn or 0) -- what is left after this round's ticks
	value = value + math.min(damage, math.max(0, hp))
	if damage >= hp then
		return value + enemy.attack * 3 -- it stops hitting back
	end
	if enemy.kind ~= "warded" then
		if card.type == "beast" then
			value = value + damage * Duel.BleedShare * 2
		elseif card.type == "mystic" and damage * Duel.BurnShare > (enemy.burn or 0) then
			value = value + (damage * Duel.BurnShare - (enemy.burn or 0)) * Duel.BurnRounds
		elseif card.type == "star" and (enemy.chill or 0) + 1 >= (enemy.chillMax or Duel.ChillToFreeze) then
			value = value + enemy.attack * (enemy.winding and 2.2 or 1)
		end
	end
	return value
end

-- A sensible move for the given view (what Duel.view returns): the Auto battler plays these.
-- Returns an action for the server: { kind = "play", hand, target } or { kind = "pass" }.
function Duel.suggest(view)
	local bestScore, bestHand, bestTarget = 0, nil, nil
	local incoming, windingUp = 0, false
	for _, enemy in ipairs(view.enemies) do
		if enemy.hp > 0 and not enemy.frozen then
			incoming = math.max(incoming, enemy.attack * (enemy.winding and 2.2 or 1))
			windingUp = windingUp or enemy.winding
		end
	end
	for handIndex, key in ipairs(view.hand) do
		local card = Duel.card(key)
		if card and card.cost <= view.energy then
			local score, target = 0, nil
			if card.role == "attack" then
				for index, enemy in ipairs(view.enemies) do
					if enemy.hp > 0 then
						local value = hitValue(card, enemy, card.amount)
						if card.type == "tech" then
							local arc = 0
							for otherIndex, other in ipairs(view.enemies) do
								if otherIndex ~= index and other.hp > 0 then
									arc = math.max(arc, hitValue(card, other, card.amount * Duel.ShockArc))
								end
							end
							value = value + arc
						end
						if value > score then
							score, target = value, index
						end
					end
				end
			elseif card.role == "blast" then
				for _, enemy in ipairs(view.enemies) do
					if enemy.hp > 0 then
						score = score + hitValue(card, enemy, card.amount)
					end
				end
			elseif card.role == "heal" then
				score = (math.min(card.amount, view.maxHp - view.hp) + (view.poison or 0) * 2) * 1.2
			elseif card.role == "shield" then
				if view.shields == 0 then
					score = incoming * card.amount * (windingUp and 1.5 * (1 + Duel.Parry) or 1.5)
				end
			elseif card.role == "charge" then
				score = view.charges == 0 and 1 or 0
			else
				-- weaken whoever hits hardest
				local hardest = 0
				for index, enemy in ipairs(view.enemies) do
					if enemy.hp > 0 and enemy.attack > hardest then
						hardest, target = enemy.attack, index
					end
				end
				score = 0.5
			end
			if score > bestScore then
				bestScore, bestHand, bestTarget = score, handIndex, target
			end
		end
	end
	if bestHand then
		return { kind = "play", hand = bestHand, target = bestTarget }
	end
	return { kind = "pass" }
end

return Duel
