-- Duels: the turn-based card battles of the Battle Tower. Pure logic, no Roblox services:
-- the server owns the duel state and calls play / pass / discard; the client only draws the
-- view and the events it is sent.
--
-- How a duel goes: you bring a battle deck built from cards you own. Each round you gain one
-- energy, draw back up to a full hand, and play ONE card (or pass and save your energy).
-- Then every enemy takes its turn. Rarer cards cost more energy and hit harder.
local Cards = require(script.Parent.Cards)
local Battle = require(script.Parent.Battle)

local Duel = {}

Duel.DeckSize = 20 -- most cards a battle deck can hold
Duel.MaxCopies = 3 -- of the same card + effect
Duel.MaxPricey = 8 -- auto-build keeps at most this many cards costing 4+ energy
Duel.MaxSupport = 8 -- ...and at most this many cards that deal no direct damage
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
	drain = { name = "Drain", icon = "🧛", target = true },
	curse = { name = "Curse", icon = "☠️", target = true },
	hex = { name = "Hex", icon = "🎯", target = true },
	stun = { name = "Stun", icon = "💫", target = true },
	mend = { name = "Mend", icon = "🌿" },
}

-- Not every card is an attack. Each type has its own mix of six roles, and a card's role is
-- picked by its number in the set, so every set has a bit of everything:
--   Warrior: fights up front and buffs     Beast: hits hard, drains, sets hexes
--   Mystic:  heals and curses              Tech:  shields, stuns and wide blasts
--   Star:    weakens, hexes and stuns
local ROLE_CYCLES = {
	warrior = { "attack", "charge", "attack", "stun", "blast", "shield" },
	beast = { "attack", "blast", "drain", "hex", "attack", "charge" },
	mystic = { "attack", "heal", "curse", "weaken", "mend", "blast" },
	tech = { "attack", "shield", "blast", "stun", "curse", "charge" },
	star = { "attack", "weaken", "hex", "attack", "drain", "stun" },
}
-- Roles that hurt an enemy straight away (the rest buff, heal, protect or set things up).
Duel.Damaging = { attack = true, blast = true, drain = true, stun = true }
Duel.CurseRounds = 3
Duel.MendRounds = 3
Duel.DrainHeal = 0.5 -- of the damage a Drain deals, healed

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

-- A card's place among the cards of its type in its set (0, 1, 2 ...), so each type's role
-- cycle runs evenly through every set.
local typePlace = {}
do
	local seen = {}
	for _, def in ipairs(Cards.List) do
		local slot = def.set .. "/" .. def.type
		typePlace[def.id] = seen[slot] or 0
		seen[slot] = (seen[slot] or 0) + 1
	end
end

local function roleOf(def)
	local override = ROLE_OVERRIDES[def.id]
	if override then
		return override
	end
	local cycle = ROLE_CYCLES[def.type]
	if cycle == nil then
		return "attack"
	end
	return cycle[(typePlace[def.id] or 0) % #cycle + 1]
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
	elseif role == "drain" then
		amount = math.max(1, math.floor(power * 0.75))
		text = short(amount) .. " damage, and heal half of it"
	elseif role == "curse" then
		amount = math.max(1, math.floor(power * 0.55))
		text = "Curse: " .. short(amount) .. " damage a round for " .. Duel.CurseRounds .. " rounds"
	elseif role == "hex" then
		amount = math.min(0.9, 0.3 + 0.1 * cost)
		text = "The next hit on one enemy deals +" .. percent(amount)
	elseif role == "stun" then
		amount = math.max(1, math.floor(power * 0.35))
		text = short(amount) .. " damage and stun: it loses its next turn"
	elseif role == "mend" then
		amount = math.max(1, math.floor(power * 0.6))
		text = "Heal " .. short(amount) .. " a round for " .. Duel.MendRounds .. " rounds"
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
	local deck, pricey, support = {}, 0, 0
	for _, card in ipairs(options) do
		if #deck >= Duel.DeckSize then
			break
		end
		local helper = not Duel.Damaging[card.role]
		if (card.cost < 4 or pricey < Duel.MaxPricey) and (not helper or support < Duel.MaxSupport) then
			if card.cost >= 4 then
				pricey = pricey + 1
			end
			if helper then
				support = support + 1
			end
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
-- Past floor 49 (the Norse floors, for players who have opened every set) it grows more
-- slowly, so the last floors are a climb for an endgame collection rather than a wall.
Duel.LateFloor = 49
Duel.LateGrowth = 1.08
function Duel.floorPower(floor)
	local early = math.min(floor, Duel.LateFloor)
	return 10 * 1.16 ^ (early - 1) * Duel.LateGrowth ^ math.max(0, floor - Duel.LateFloor)
end

-- The tower is themed by set: the first floors are haunted by Storybook characters, then
-- seven floors per set up to Rome, and the top floors (50 and up) by the Norse myths.
-- Sets of real people (Pax Americana) are never tower enemies, so they are not in this list.
Duel.FloorsPerSet = 7
Duel.TowerSets = { "storybook", "seas", "west", "midnight", "olympus", "knights", "rome", "norse" }
for _, setId in ipairs(Duel.TowerSets) do
	assert(Cards.Sets[setId], "Duel.TowerSets names unknown set " .. setId)
end
function Duel.floorSet(floor)
	return Duel.TowerSets[math.min(#Duel.TowerSets, math.floor((floor - 1) / Duel.FloorsPerSet) + 1)]
end

local SET_PREFIX = {
	storybook = "Runaway",
	seas = "Cursed",
	west = "Demon",
	midnight = "Haunted",
	olympus = "Fallen",
	knights = "Rogue",
	rome = "Rebel",
	america = "Rival", -- only met in the daily challenge; real people are never tower enemies
	norse = "Frostbound",
}

-- Real people in the tower's sets (Glory of Rome). They are cards you can collect, and a boss
-- can drop them, but they are never shown as enemies.
Duel.RealPeople = {}
for _, id in ipairs({
	"spartacus",
	"cicero",
	"virgil",
	"boudica",
	"vitruvius",
	"livia",
	"mark_antony",
	"cleopatra",
	"scipio_africanus",
	"hannibal",
	"marcus_aurelius",
	"julius_caesar",
	"augustus",
	"trajan",
	"hadrian_the_builder",
}) do
	assert(Cards.ById[id], "Duel.RealPeople names unknown card " .. id)
	Duel.RealPeople[id] = true
end

-- Every boss has a signature from its set's stories, on top of the wind-up and the tier
-- tricks (regen, enrage, armour). The top floor's boss gets Ragnarok.
Duel.BossTraits = {
	undertow = { name = "🌊 Undertow", text = "Its big hit also drains 2 of your energy" },
	cloudstep = { name = "☁️ Cloud-step", text = "The first hit on it each round deals half" },
	thunder = { name = "⚡ Thunderbolt", text = "Its big hit goes straight through shields" },
	rally = { name = "📯 Rally", text = "Calls knocked-out allies back to fight (once each)" },
	frostbite = { name = "❄️ Frostbite", text = "Its hits leave frost that hurts every round; a Heal cures it" },
	ragnarok = { name = "🔥 Ragnarok", text = "Below half health it winds up every other round" },
}
local SET_TRAIT = {
	storybook = "cloudstep",
	seas = "undertow",
	west = "cloudstep",
	midnight = "frostbite",
	olympus = "thunder",
	knights = "rally",
	rome = "rally",
	norse = "frostbite",
}
function Duel.bossTrait(floor, setId)
	if floor >= Battle.MaxFloor then
		return "ragnarok"
	end
	return SET_TRAIT[setId]
end

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
	local pool, bossPool = {}, {}
	for _, def in ipairs(Cards.Sets[setId].cards) do
		if not Duel.RealPeople[def.id] then
			table.insert(pool, def)
			-- bosses come from the set's Legendary and Mythic cards; its Secret card is saved
			-- for the top floor
			local order = Cards.Rarities[def.rarity].order
			if (floor >= Battle.MaxFloor and def.rarity == "Secret") or (floor < Battle.MaxFloor and order >= 5 and def.rarity ~= "Secret") then
				table.insert(bossPool, def)
			end
		end
	end
	if #bossPool == 0 then
		bossPool = pool
	end
	local list = {}
	for index = 1, count do
		local isBoss = boss and index == 1
		local def = isBoss and bossPool[math.floor(floor / Duel.BossEvery) % #bossPool + 1] or pool[(floor * 7 + index * 13) % #pool + 1]
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
			trait = isBoss and Duel.bossTrait(floor, setId) or nil, -- the boss's signature (Duel.BossTraits)
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
			dodged = false, -- an evasive boss already halved a hit this round
			curse = 0, -- damage at the end of each round...
			curseRounds = 0, -- ...for this many more rounds
			hex = {}, -- fractions added to the next hits on it
			stunned = false, -- loses its next turn
			stunGuard = false, -- just shook off a stun: cannot be stunned again until it acts
		}
	end
	return list
end

-- The daily challenge: everyone gets the same preset deck and the same enemies for the day,
-- so it is a test of play rather than of collection. day = Quests.today().
-- Returns { set = setId, deck = { cardKey, ... }, floor = the tower floor whose line-up you
-- face, power = how strong those enemies are }.
Duel.ChallengePower = 20 -- enemy strength for a Storybook deck; doubles with each later set
function Duel.challenge(day)
	local setIndex = day % #Cards.SetOrder + 1
	local set = Cards.Sets[Cards.SetOrder[setIndex]]
	local byRarity = {}
	for _, def in ipairs(set.cards) do
		byRarity[def.rarity] = byRarity[def.rarity] or {}
		table.insert(byRarity[def.rarity], def)
	end
	local deck = {}
	-- about two thirds of each rarity's picks hit, the rest support
	local function take(rarity, count, effect)
		local hitters, helpers = {}, {}
		for _, def in ipairs(byRarity[rarity] or {}) do
			table.insert(Duel.Damaging[Duel.card(def.id).role] and hitters or helpers, def)
		end
		local hitCount = math.max(1, math.ceil(count * 2 / 3))
		for pick = 1, count do
			local pool = (pick <= hitCount or #helpers == 0) and hitters or helpers
			if #pool == 0 then
				pool = helpers
			end
			if #pool > 0 then
				local def = pool[(day * 3 + pick * 5) % #pool + 1]
				table.insert(deck, effect and Cards.makeKey(def.id, effect) or def.id)
			end
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
		mend = 0, -- healing at the end of each round...
		mendRounds = 0, -- ...for this many more rounds
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
-- hero = whose side is shown (the state itself in a solo duel).
local function viewOf(state, hero)
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
			curse = enemy.curseRounds > 0 and enemy.curse or 0,
			hex = #enemy.hex,
			stunned = enemy.stunned,
			stunGuard = enemy.stunGuard,
			trait = enemy.trait,
			raid = enemy.raid,
		}
	end
	return {
		floor = state.floor,
		mode = state.mode,
		round = state.round,
		energy = hero.energy,
		hp = hero.hp,
		maxHp = hero.maxHp,
		shields = #hero.shields,
		charges = #hero.charges,
		poison = hero.poison,
		mend = hero.mendRounds > 0 and hero.mend or 0,
		enemies = enemies,
		hand = table.clone(hero.hand),
		deckLeft = #hero.deck,
		over = state.over,
		win = state.win,
	}
end

function Duel.view(state)
	return viewOf(state, state)
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
	local hexed = not arc and table.remove(enemy.hex, 1) or nil
	if hexed then
		damage = damage * (1 + hexed)
	end
	local dodged = enemy.trait == "cloudstep" and not enemy.dodged
	if dodged then
		enemy.dodged = true
		damage = damage * 0.5
	end
	damage = math.max(1, math.floor(damage))
	enemy.hp = math.max(0, enemy.hp - damage)
	local text = (arc and "⚡ The shock arcs to " or (card.name .. " hits ")) .. enemy.name .. " for " .. short(damage)
	if hexed then
		text = text .. " 🎯"
	end
	if dodged then
		text = text .. " (☁️ half dodged)"
	end
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
	return damage
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
local applyCard -- (state, hero, heroIndex, handIndex, targetIndex, events): defined below

-- The heroes of a duel: a solo duel is its own (only) hero; a co-op duel has state.heroes.
local function heroesOf(state)
	return state.heroes or { state }
end

local function heroStanding(state)
	for _, hero in ipairs(heroesOf(state)) do
		if hero.hp > 0 then
			return true
		end
	end
	return false
end

-- Who an enemy attacks: in a team, a random hero still standing.
local function pickHero(state, rng)
	local heroes = heroesOf(state)
	if #heroes == 1 then
		return heroes[1], 1
	end
	local standing = {}
	for index, hero in ipairs(heroes) do
		if hero.hp > 0 then
			table.insert(standing, index)
		end
	end
	local index = standing[rng:NextInteger(1, #standing)]
	return heroes[index], index
end

-- "you" in a solo duel, the hero's name in a team.
local function whoIs(hero)
	return hero.name or "you"
end

local function finishRound(state, events, rng)
	if firstAlive(state) == nil then
		state.over, state.win = true, true
		table.insert(events, { kind = "win", text = "🏆 Victory!" })
		return
	end

	for index, enemy in ipairs(state.enemies) do
		enemy.dodged = false
		-- bleeding and burning come first, and can finish an enemy before it acts
		if enemy.hp > 0 and (enemy.bleed > 0 or enemy.burnRounds > 0 or enemy.curseRounds > 0) then
			local damage, parts = 0, {}
			if enemy.curseRounds > 0 then
				damage = damage + enemy.curse
				table.insert(parts, "is cursed")
				enemy.curseRounds = enemy.curseRounds - 1
			end
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
		if enemy.hp > 0 and enemy.stunned and heroStanding(state) then
			enemy.stunned = false
			enemy.stunGuard = true
			table.insert(events, { kind = "frozen", text = "💫 " .. enemy.name .. " is stunned and loses its turn.", enemy = index })
		elseif enemy.hp > 0 and enemy.frozen and heroStanding(state) then
			enemy.frozen = false
			table.insert(events, { kind = "frozen", text = "❄️ " .. enemy.name .. " is frozen solid and loses its turn.", enemy = index })
		elseif enemy.hp > 0 and heroStanding(state) then
			enemy.stunGuard = false
			if enemy.regen and enemy.hp < enemy.maxHp then
				enemy.hp = math.min(enemy.maxHp, enemy.hp + math.floor(enemy.maxHp * Duel.BossRegen))
				table.insert(events, { kind = "mend", text = enemy.name .. " regenerates.", enemy = index, enemyHp = enemy.hp })
			end
			local hurtAlly = enemy.kind == "healer" and mostHurt(state) or nil
			local fallen = nil
			if enemy.kind == "summoner" or enemy.trait == "rally" then
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
				ally.curse, ally.curseRounds, ally.stunned, ally.stunGuard = 0, 0, false, false
				ally.weak, ally.hex = {}, {}
				table.insert(events, { kind = "summon", text = "📯 " .. enemy.name .. " calls " .. ally.name .. " back to fight!", enemy = fallen, enemyHp = ally.hp })
			elseif hurtAlly then
				local ally = state.enemies[hurtAlly]
				ally.hp = math.min(ally.maxHp, ally.hp + math.floor(ally.maxHp * Duel.HealShare))
				table.insert(events, { kind = "mend", text = enemy.name .. " heals " .. (hurtAlly == index and "itself" or ally.name) .. ".", enemy = hurtAlly, enemyHp = ally.hp })
			elseif enemy.boss and not enemy.winding and (state.round % 3 == 2 or (enemy.trait == "ragnarok" and enemy.hp < enemy.maxHp * 0.5 and state.round % 2 == 0)) then
				-- bosses spend a turn winding up, so you can see the big hit coming
				enemy.winding = true
				table.insert(events, { kind = "windup", text = "⚠️ " .. enemy.name .. " is winding up a huge attack!", enemy = index })
			else
				local hero, heroIndex = pickHero(state, rng)
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
				local thunder = bigHit and enemy.trait == "thunder" and #hero.shields > 0
				local blocked = not thunder and table.remove(hero.shields, 1) or nil
				local parried = 0
				if blocked then
					if bigHit then
						parried = math.floor(damage * blocked * Duel.Parry)
					end
					damage = damage * (1 - blocked)
				end
				damage = math.max(1, math.floor(damage))
				hero.hp = math.max(0, hero.hp - damage)
				local text = enemy.name .. (enraged and " is enraged and hits " or " hits ") .. whoIs(hero) .. " for " .. short(damage)
				if enemy.kind == "venomous" or enemy.trait == "frostbite" then
					hero.poison = hero.poison + math.max(1, math.floor(damage * Duel.PoisonShare))
					text = text .. (enemy.kind == "venomous" and " 🐍" or " ❄️ frostbite")
				end
				if thunder then
					text = text .. " ⚡ straight through the shield!"
				end
				if bigHit and enemy.trait == "undertow" then
					hero.energy = math.max(0, hero.energy - 2)
					text = text .. " 🌊 -2 energy"
				end
				if enemy.kind == "berserker" then
					enemy.attack = math.max(enemy.attack + 1, math.floor(enemy.attack * Duel.BerserkGrowth))
				end
				if blocked then
					text = text .. " (shield blocked " .. percent(blocked) .. ")"
				elseif weak then
					text = text .. " (weakened)"
				end
				if hero.hp <= 0 and state.heroes then
					text = text .. "  💀 " .. whoIs(hero) .. " is down!"
				end
				table.insert(events, { kind = "hurt", text = text, enemy = index, hp = hero.hp, hero = heroIndex, damage = damage, attack = enemy.attack })
				if parried > 0 then
					enemy.hp = math.max(0, enemy.hp - parried)
					table.insert(events, { kind = "parry", text = "🛡️ Parried! " .. short(parried) .. " goes back at " .. enemy.name .. (enemy.hp <= 0 and "  KO!" or ""), enemy = index, enemyHp = enemy.hp, damage = parried })
				end
			end
		end
	end

	if heroStanding(state) and firstAlive(state) == nil then
		state.over, state.win = true, true
		table.insert(events, { kind = "win", text = "🏆 Victory!" })
		return
	end
	for heroIndex, hero in ipairs(heroesOf(state)) do
		if hero.mendRounds > 0 and hero.hp > 0 then
			hero.mendRounds = hero.mendRounds - 1
			local healed = math.min(hero.mend, hero.maxHp - hero.hp)
			hero.hp = hero.hp + healed
			table.insert(events, { kind = "heal", text = "🌿 " .. (hero.name or "You") .. " mend" .. (hero.name and "s " or " ") .. short(healed) .. " health.", hp = hero.hp, hero = heroIndex })
		end
		if hero.poison > 0 and hero.hp > 0 then
			hero.hp = math.max(0, hero.hp - hero.poison)
			table.insert(events, { kind = "poison", text = "🐍 Poison hurts " .. whoIs(hero) .. " for " .. short(hero.poison), hp = hero.hp, hero = heroIndex, damage = hero.poison })
			hero.poison = math.floor(hero.poison / 2)
		end
	end

	if not heroStanding(state) then
		state.over, state.win = true, false
		table.insert(events, { kind = "lose", text = "💀 Defeated on round " .. state.round .. "." })
		return
	end
	if state.mode == "raid" and state.round >= Duel.RaidRounds then
		state.over, state.win = true, true
		table.insert(events, { kind = "win", text = "⏱️ Time! You held your ground against the world boss." })
		return
	end
	if state.round >= Duel.MaxRounds then
		state.over, state.win = true, false
		table.insert(events, { kind = "lose", text = "💀 Out of time — the tower's guardians outlast you." })
		return
	end

	state.round = state.round + 1
	for _, hero in ipairs(heroesOf(state)) do
		if hero.hp > 0 then
			hero.energy = math.min(Duel.MaxEnergy, hero.energy + 1)
			draw(hero, rng)
		end
	end
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

	local events = {}
	applyCard(state, state, 1, handIndex, targetIndex, events)
	finishRound(state, events, rng)
	return events
end

-- Spend the hero's energy on the card at handIndex and do what it does. Targets must already
-- be checked. The hero is the state itself in a solo duel, or one of state.heroes.
function applyCard(state, hero, heroIndex, handIndex, targetIndex, events)
	local card = Duel.card(hero.hand[handIndex])
	hero.energy = hero.energy - card.cost
	table.insert(hero.discard, table.remove(hero.hand, handIndex))

	if card.role == "attack" or card.role == "blast" or card.role == "drain" then
		local boost = table.remove(hero.charges, 1)
		local damage = card.amount * (1 + (boost or 0))
		if boost then
			table.insert(events, { kind = "boost", text = "💪 Power-up: +" .. percent(boost) .. " damage!" })
		end
		if card.role == "attack" then
			hitEnemy(state, events, card, targetIndex, damage)
		elseif card.role == "drain" then
			local dealt = hitEnemy(state, events, card, targetIndex, damage)
			local healed = math.min(math.floor(dealt * Duel.DrainHeal), hero.maxHp - hero.hp)
			hero.hp = hero.hp + healed
			table.insert(events, { kind = "heal", text = "🧛 " .. card.name .. " drains " .. short(healed) .. " health back to " .. whoIs(hero), hp = hero.hp, hero = heroIndex })
		else
			for index, enemy in ipairs(state.enemies) do
				if enemy.hp > 0 then
					hitEnemy(state, events, card, index, damage)
				end
			end
		end
	elseif card.role == "heal" then
		-- in a team, a Heal goes to whoever is most hurt (yourself included)
		local patient, patientIndex = hero, heroIndex
		if state.heroes then
			local worst = hero.hp / hero.maxHp
			for otherIndex, other in ipairs(state.heroes) do
				if other.hp > 0 and other.hp / other.maxHp < worst then
					patient, patientIndex, worst = other, otherIndex, other.hp / other.maxHp
				end
			end
		end
		local healed = math.min(card.amount, patient.maxHp - patient.hp)
		patient.hp = patient.hp + healed
		local cured = patient.poison > 0
		patient.poison = 0
		table.insert(events, { kind = "heal", text = card.name .. " heals " .. whoIs(patient) .. " for " .. short(healed) .. (cured and " and cures the poison" or ""), hp = patient.hp, hero = patientIndex })
	elseif card.role == "shield" then
		if #hero.shields >= Duel.MaxStacks then
			table.remove(hero.shields, 1)
		end
		table.insert(hero.shields, card.amount)
		table.insert(events, { kind = "shield", text = card.name .. " shields " .. whoIs(hero) .. ": the next hit is cut by " .. percent(card.amount) })
	elseif card.role == "charge" then
		if #hero.charges >= Duel.MaxStacks then
			table.remove(hero.charges, 1)
		end
		table.insert(hero.charges, card.amount)
		table.insert(events, { kind = "charge", text = card.name .. " powers up " .. whoIs(hero) .. ": the next attack deals +" .. percent(card.amount) })
	elseif card.role == "mend" then
		hero.mend = math.max(hero.mendRounds > 0 and hero.mend or 0, card.amount)
		hero.mendRounds = Duel.MendRounds
		table.insert(events, { kind = "charge", text = "🌿 " .. card.name .. ": " .. whoIs(hero) .. " will heal " .. short(hero.mend) .. " a round for " .. Duel.MendRounds .. " rounds" })
	elseif card.role == "stun" then
		local enemy = state.enemies[targetIndex]
		hitEnemy(state, events, card, targetIndex, card.amount)
		if enemy.hp > 0 then
			local text
			if enemy.boss then
				text = "💫 " .. enemy.name .. " is too mighty to stun" .. (enemy.winding and ", but its wind-up breaks!" or ".")
				enemy.winding = false
			elseif enemy.stunGuard or enemy.stunned then
				text = "💫 " .. enemy.name .. " shrugs off the stun (it was just stunned)."
			else
				enemy.stunned = true
				text = "💫 " .. enemy.name .. " is stunned: it loses its next turn!"
			end
			table.insert(events, { kind = "weaken", text = text, enemy = targetIndex, icon = "💫" })
		end
	elseif card.role == "curse" then
		local enemy = state.enemies[targetIndex]
		enemy.curse = math.max(enemy.curseRounds > 0 and enemy.curse or 0, card.amount)
		enemy.curseRounds = Duel.CurseRounds
		table.insert(events, { kind = "weaken", text = "☠️ " .. card.name .. " curses " .. enemy.name .. ": " .. short(enemy.curse) .. " damage a round for " .. Duel.CurseRounds .. " rounds", enemy = targetIndex, icon = "☠️" })
	elseif card.role == "hex" then
		local enemy = state.enemies[targetIndex]
		if #enemy.hex >= Duel.MaxStacks then
			table.remove(enemy.hex, 1)
		end
		table.insert(enemy.hex, card.amount)
		table.insert(events, { kind = "weaken", text = "🎯 " .. card.name .. " hexes " .. enemy.name .. ": the next hit on it deals +" .. percent(card.amount), enemy = targetIndex, icon = "🎯" })
	else
		local enemy = state.enemies[targetIndex]
		if #enemy.weak >= Duel.MaxStacks then
			table.remove(enemy.weak, 1)
		end
		table.insert(enemy.weak, card.amount)
		table.insert(events, { kind = "weaken", text = card.name .. " weakens " .. enemy.name .. ": its next attack deals -" .. percent(card.amount), enemy = targetIndex, icon = "🌀" })
	end
end

-- World boss -------------------------------------------------------------------------------
-- Every so often the whole server fights one giant boss. Each player's fight is a solo duel of
-- Duel.RaidRounds rounds against a copy that cannot fall; what counts is the damage dealt,
-- measured in "points" against the player's own health (one point = 2.5% of it),
-- so a new player's hits count as much as a veteran's. The server adds the points up.
Duel.RaidRounds = 10
Duel.RaidStartEnergy = 4 -- a short fight, so it starts with more energy
Duel.RaidHitShare = 0.07 -- the world boss hits for this share of your health
Duel.RaidTraits = { "undertow", "cloudstep", "thunder", "frostbite" }

-- Picks the next world boss: a Legendary or Mythic from a tower set (never a real person).
function Duel.raidPick(rng)
	local pool = {}
	for _, setId in ipairs(Duel.TowerSets) do
		for _, def in ipairs(Cards.Sets[setId].cards) do
			local order = Cards.Rarities[def.rarity].order
			if (order == 5 or order == 6) and not Duel.RealPeople[def.id] then
				table.insert(pool, def)
			end
		end
	end
	local def = pool[rng:NextInteger(1, #pool)]
	return {
		cardId = def.id,
		name = def.name,
		glyph = def.glyph,
		type = def.type,
		trait = Duel.RaidTraits[rng:NextInteger(1, #Duel.RaidTraits)],
	}
end

-- A duel against the world boss described by `boss` (from Duel.raidPick).
function Duel.raidNew(boss, deck, rng)
	local enemies = Duel.enemies(Duel.BossEvery)
	local enemy = enemies[1]
	local state = Duel.new(Duel.BossEvery, deck, rng, "raid", { enemy })
	if state == nil then
		return nil
	end
	enemy.name = "🐉 " .. boss.name
	enemy.glyph = boss.glyph
	enemy.type = boss.type
	enemy.trait = boss.trait
	enemy.raid = true
	enemy.regen, enemy.enrages, enemy.armor = false, false, 0
	enemy.maxHp = 1e12
	enemy.hp = enemy.maxHp
	enemy.attack = math.max(1, math.floor(state.maxHp * Duel.RaidHitShare))
	state.energy = Duel.RaidStartEnergy
	return state
end

-- Points a finished world-boss duel earned.
function Duel.raidPoints(state)
	local enemy = state.enemies[1]
	local dealt = enemy.maxHp - enemy.hp
	return math.floor(dealt / math.max(1, state.maxHp / 40))
end

-- Co-op duels -----------------------------------------------------------------------------
-- Up to Duel.CoopMax players fight one tower floor together. Each hero has their own deck,
-- hand, energy and health; every round all of them pick a move, the moves play out in
-- order, then each enemy attacks a random hero still standing. A Heal goes to the most hurt
-- teammate. The enemies get more health for every extra hero. The team wins when every enemy
-- is down and loses when every hero is.
Duel.CoopMax = 4
Duel.CoopEnemyHealth = 1.1 -- each extra hero adds this share of the enemies' health

function Duel.coopNew(floor, decks, names, rng, enemies)
	local heroes = {}
	for index, deck in ipairs(decks) do
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
		local hero = {
			name = names[index],
			energy = Duel.StartEnergy,
			hp = health,
			maxHp = health,
			shields = {},
			charges = {},
			poison = 0,
			mend = 0,
			mendRounds = 0,
			deck = pile,
			hand = {},
			discard = {},
			move = nil, -- { kind = "play", hand, target } or { kind = "pass" } once chosen
			left = false, -- walked out of the fight
		}
		draw(hero, rng)
		heroes[index] = hero
	end
	enemies = enemies or Duel.enemies(floor)
	local scale = 1 + Duel.CoopEnemyHealth * (#heroes - 1)
	for _, enemy in ipairs(enemies) do
		enemy.maxHp = math.floor(enemy.maxHp * scale)
		enemy.hp = enemy.maxHp
	end
	return {
		floor = floor,
		mode = "coop",
		round = 1,
		heroes = heroes,
		enemies = enemies,
		over = false,
		win = false,
	}
end

-- Lock in a hero's move. action = { kind = "play", hand, target } or { kind = "pass" }.
function Duel.coopChoose(state, heroIndex, action)
	local hero = state.heroes[heroIndex]
	if state.over or hero == nil then
		return nil, "This battle is over."
	end
	if hero.hp <= 0 then
		return nil, "You're down. Your team fights on!"
	end
	if hero.move then
		return nil, "You already picked your move. Waiting for your team."
	end
	if action.kind == "pass" then
		hero.move = { kind = "pass" }
		return true
	end
	local key = type(action.hand) == "number" and hero.hand[action.hand] or nil
	if key == nil then
		return nil, "Pick a card from your hand."
	end
	if Duel.card(key).cost > hero.energy then
		return nil, "Not enough energy: that card costs " .. Duel.card(key).cost .. "."
	end
	hero.move = { kind = "play", hand = action.hand, target = type(action.target) == "number" and action.target or nil }
	return true
end

function Duel.coopDiscard(state, heroIndex, handIndex)
	local hero = state.heroes[heroIndex]
	if state.over or hero == nil or hero.hp <= 0 or hero.move or type(handIndex) ~= "number" or hero.hand[handIndex] == nil then
		return false
	end
	table.insert(hero.discard, table.remove(hero.hand, handIndex))
	return true
end

-- True when every hero still standing has picked a move.
function Duel.coopReady(state)
	for _, hero in ipairs(state.heroes) do
		if hero.hp > 0 and hero.move == nil then
			return false
		end
	end
	return true
end

-- Play out the round (a missing move is a pass). Returns the events, which name heroes by
-- index in `hero` (see Duel.coopEventsFor).
function Duel.coopResolve(state, rng)
	local events = {}
	for heroIndex, hero in ipairs(state.heroes) do
		local move = hero.move or { kind = "pass" }
		if hero.hp > 0 and not state.over and firstAlive(state) then
			local key = move.kind == "play" and hero.hand[move.hand] or nil
			local card = key and Duel.card(key) or nil
			if card and card.cost <= hero.energy then
				local target = move.target
				if Duel.Roles[card.role].target then
					local enemy = type(target) == "number" and state.enemies[target] or nil
					if enemy == nil or enemy.hp <= 0 then
						target = firstAlive(state)
					end
				end
				applyCard(state, hero, heroIndex, move.hand, target, events)
			else
				table.insert(events, { kind = "pass", text = hero.name .. " holds and gathers energy." })
			end
		end
		hero.move = nil
	end
	finishRound(state, events, rng)
	return events
end

-- A hero walks out (fled or left the game). The team fights on without them.
function Duel.coopLeave(state, heroIndex)
	local hero = state.heroes[heroIndex]
	if hero == nil or state.over then
		return
	end
	hero.hp = 0
	hero.left = true
	hero.move = nil
	if not heroStanding(state) then
		state.over, state.win = true, false
	end
end

-- The events as one hero sees them: their own health changes keep `hp`; a teammate's become
-- "allyhurt" / "allyheal" so the screen does not mistake them for yours.
function Duel.coopEventsFor(events, heroIndex)
	local list = {}
	for index, event in ipairs(events) do
		if event.hero and event.hero ~= heroIndex then
			local copy = table.clone(event)
			copy.hp = nil
			copy.kind = (event.kind == "heal") and "allyheal" or "allyhurt"
			list[index] = copy
		else
			list[index] = event
		end
	end
	return list
end

-- One hero's view, with their teammates' health.
function Duel.coopView(state, heroIndex)
	local hero = state.heroes[heroIndex]
	local view = viewOf(state, hero)
	view.chosen = hero.move ~= nil
	view.allies = {}
	for index, other in ipairs(state.heroes) do
		if index ~= heroIndex then
			table.insert(view.allies, { name = other.name, hp = other.hp, maxHp = other.maxHp, ready = other.move ~= nil, left = other.left })
		end
	end
	return view
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
	if (enemy.hex or 0) > 0 then
		damage = damage * 1.5
	end
	local value = 0
	if card.type == "warrior" and enemy.winding then
		damage = damage * Duel.StaggerBonus
		value = value + enemy.attack * 2 -- the big hit never lands
	end
	local hp = enemy.hp - (enemy.bleed or 0) - (enemy.burn or 0) - (enemy.curse or 0) -- left after this round's ticks
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
	local cardFor = view.mode == "pvp" and Duel.pvpCard or Duel.card
	local bestScore, bestHand, bestTarget = 0, nil, nil
	local incoming, windingUp = 0, false
	for _, enemy in ipairs(view.enemies) do
		if enemy.hp > 0 and not enemy.frozen then
			incoming = math.max(incoming, enemy.attack * (enemy.winding and 2.2 or 1))
			windingUp = windingUp or enemy.winding
		end
	end
	for handIndex, key in ipairs(view.hand) do
		local card = cardFor(key)
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
			elseif card.role == "drain" then
				for index, enemy in ipairs(view.enemies) do
					if enemy.hp > 0 then
						local value = hitValue(card, enemy, card.amount)
						value = value + math.min(card.amount * Duel.DrainHeal, view.maxHp - view.hp)
						if value > score then
							score, target = value, index
						end
					end
				end
			elseif card.role == "stun" then
				for index, enemy in ipairs(view.enemies) do
					if enemy.hp > 0 then
						local value = hitValue(card, enemy, card.amount)
						if enemy.boss then
							value = value + (enemy.winding and enemy.attack * 2.2 or 0)
						elseif not enemy.stunned and not enemy.stunGuard and not enemy.frozen then
							value = value + enemy.attack * 1.3
						end
						if value > score then
							score, target = value, index
						end
					end
				end
			elseif card.role == "curse" then
				for index, enemy in ipairs(view.enemies) do
					if enemy.hp > 0 and (enemy.curse or 0) < card.amount then
						local value = math.min((card.amount - (enemy.curse or 0)) * Duel.CurseRounds, enemy.hp) * 0.8
						if value > score then
							score, target = value, index
						end
					end
				end
			elseif card.role == "hex" then
				-- worth it when a big hit is coming next round
				local best = 0
				for otherIndex, otherKey in ipairs(view.hand) do
					local other = otherIndex ~= handIndex and cardFor(otherKey) or nil
					if other and (other.role == "attack" or other.role == "drain") then
						best = math.max(best, other.amount)
					end
				end
				for index, enemy in ipairs(view.enemies) do
					if enemy.hp > 0 and (enemy.hex or 0) == 0 and enemy.hp > best then
						local value = best * card.amount * 0.6
						if value > score then
							score, target = value, index
						end
					end
				end
			elseif card.role == "mend" then
				if (view.mend or 0) < card.amount then
					score = math.min(card.amount * Duel.MendRounds, view.maxHp - view.hp) * 0.8
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

-- Player duels ----------------------------------------------------------------------------
-- Two players who both agreed to fight. Nothing is at stake: no cards or currency change
-- hands. Card strength comes from rarity alone (Duel.PvpPower), not from a card's income, so
-- a new player's deck can beat a veteran's: it is a test of deck and play.
-- Every round both players pick a move in secret (a card, or pass); then the moves resolve,
-- with the first move alternating each round. Each player has a "school": the type most of
-- their deck belongs to, which decides type advantage against them.
Duel.PvpHealth = 250
Duel.PvpPower = { 30, 64, 104, 146, 192, 240 } -- by energy cost: a little more per energy for rarer cards
Duel.PvpBlast = 1 -- a Blast hits the one opponent for this share of its power
Duel.PvpHeal = 1 -- a Heal restores this share of its power
Duel.PvpMaxRounds = 30 -- then the healthier player (by share of health) wins
Duel.PvpTurnTime = 30 -- seconds to pick a move; then you pass
Duel.PvpChillToFreeze = 5
Duel.PvpBleedShare = 0.25 -- of a Beast hit, added to the bleed (more than in the tower)
Duel.PvpThreat = 80
Duel.PvpParry = 0.3 -- of the damage a shield blocks, sent back at the attacker
Duel.PvpShockDrain = 1 -- a Tech hit takes this much energy from the opponent
Duel.PvpStagger = 1.15 -- a Warrior hit deals this much more and breaks every shield
-- How each type's mark works in a player duel (bleed and burn work as in the tower).
Duel.PvpEffects = {
	beast = "🩸 Bleed: stacks, every round",
	mystic = "♨️ Burn: 3 rounds",
	star = "❄️ Chill: 5 freeze them for a turn",
	tech = "⚡ Shock: drains 1 energy",
	warrior = "🔨 Stagger: +15%, breaks all shields",
}

local pvpCache = {}
function Duel.pvpCard(key)
	local cached = pvpCache[key]
	if cached then
		return cached
	end
	local base = Duel.card(key)
	if base == nil then
		return nil
	end
	local power = Duel.PvpPower[base.cost] or Duel.PvpPower[#Duel.PvpPower]
	local card = table.clone(base)
	card.power = power
	local effect = Duel.Effects[base.type]
	local mark = effect and (" · " .. effect.icon .. " " .. effect.name) or ""
	if base.role == "attack" then
		card.amount = power
		card.text = power .. " damage" .. mark
	elseif base.role == "blast" then
		card.amount = math.floor(power * Duel.PvpBlast)
		card.text = card.amount .. " damage" .. mark
	elseif base.role == "heal" then
		card.amount = math.floor(power * Duel.PvpHeal)
		card.text = "Heal " .. card.amount .. " health"
	elseif base.role == "drain" then
		card.amount = math.floor(power * 0.75)
		card.text = card.amount .. " damage, heal half" .. mark
	elseif base.role == "curse" then
		card.amount = math.max(1, math.floor(power * 0.45))
		card.text = "Curse: " .. card.amount .. " a round for " .. Duel.CurseRounds .. " rounds"
	elseif base.role == "stun" then
		card.amount = math.max(1, math.floor(power * 0.3))
		card.text = card.amount .. " damage and stun" .. mark
	elseif base.role == "mend" then
		card.amount = math.max(1, math.floor(power * 0.5))
		card.text = "Heal " .. card.amount .. " a round for " .. Duel.MendRounds .. " rounds"
	end
	pvpCache[key] = card
	return card
end

-- The type most of a deck belongs to (ties go to the earlier type in Cards.TypeOrder).
function Duel.school(deck)
	local counts = {}
	for _, key in ipairs(deck) do
		local card = Duel.card(key)
		if card then
			counts[card.type] = (counts[card.type] or 0) + 1
		end
	end
	local best, most = Cards.TypeOrder[1], 0
	for _, typeId in ipairs(Cards.TypeOrder) do
		if (counts[typeId] or 0) > most then
			best, most = typeId, counts[typeId]
		end
	end
	return best
end

-- trained = what the fighter's Battle Training gives (Training.stats), or nil for none.
local function newFighter(deck, name, rng, trained)
	local pile = {}
	for _, key in ipairs(deck) do
		if Duel.card(key) then
			table.insert(pile, key)
		end
	end
	shuffle(pile, rng)
	trained = trained or {}
	local health = Duel.PvpHealth + (trained.health or 0)
	local fighter = {
		name = name,
		school = Duel.school(pile),
		hp = health,
		maxHp = health,
		energy = Duel.StartEnergy + (trained.energy or 0),
		might = trained.might or 1, -- damage multiplier from training
		guard = trained.guard or 1, -- damage-taken multiplier from training
		healing = trained.healing or 1, -- healing multiplier from training
		trainedLevels = trained.levels or 0,
		shields = {},
		charges = {},
		weak = {},
		bleed = 0,
		burn = 0,
		burnRounds = 0,
		chill = 0,
		frozen = false,
		curse = 0,
		curseRounds = 0,
		hex = {},
		stunned = false,
		stunGuard = false,
		mend = 0,
		mendRounds = 0,
		deck = pile,
		hand = {},
		discard = {},
		move = nil, -- { kind = "play", hand = index } or { kind = "pass" } once chosen
	}
	draw(fighter, rng)
	return fighter
end

-- A new player duel. trainedA / trainedB = Training.stats (plus levels) or nil. Returns nil if
-- either deck is empty.
function Duel.pvpNew(deckA, nameA, deckB, nameB, rng, trainedA, trainedB)
	if #deckA == 0 or #deckB == 0 then
		return nil
	end
	return {
		mode = "pvp",
		round = 1,
		fighters = { newFighter(deckA, nameA, rng, trainedA), newFighter(deckB, nameB, rng, trainedB) },
		over = false,
		winner = nil, -- 1 or 2, or 0 for a draw
	}
end

-- Lock in a side's move for this round. action = { kind = "play", hand } or { kind = "pass" }.
-- Returns true, or nil and a message.
function Duel.pvpChoose(state, side, action)
	local me = state.fighters[side]
	if state.over or me == nil then
		return nil, "This duel is over."
	end
	if me.move then
		return nil, "You already picked your move. Waiting for your opponent."
	end
	if action.kind == "pass" then
		me.move = { kind = "pass" }
		return true
	end
	local key = type(action.hand) == "number" and me.hand[action.hand] or nil
	if key == nil then
		return nil, "Pick a card from your hand."
	end
	local card = Duel.pvpCard(key)
	if card.cost > me.energy then
		return nil, "Not enough energy: that card costs " .. card.cost .. "."
	end
	me.move = { kind = "play", hand = action.hand }
	return true
end

-- Throw a card away for free (only before you pick your move, so the hand does not shift
-- under it).
function Duel.pvpDiscard(state, side, handIndex)
	local me = state.fighters[side]
	if state.over or me == nil or me.move or type(handIndex) ~= "number" or me.hand[handIndex] == nil then
		return false
	end
	table.insert(me.discard, table.remove(me.hand, handIndex))
	return true
end

-- Resolves the round once both moves are in (a missing move counts as a pass).
-- Returns { [1] = events for side 1, [2] = events for side 2 }: each side sees the same
-- story, with "hit" for its own hits and "hurt" for the other's, and its own health in hp.
function Duel.pvpResolve(state, rng)
	local events = { {}, {} }
	local fighters = state.fighters
	-- kinds: "hit" (actor hurts the other), "tick" (actor hurts itself over time), "heal",
	-- "buff" (shield / power-up / weaken), "frozen", "pass"
	local function emit(actor, kind, text, damage)
		for viewer = 1, 2 do
			local mine = viewer == actor
			local shown = kind
			if kind == "hit" then
				shown = mine and "hit" or "hurt"
			elseif kind == "tick" then
				shown = mine and "poison" or "tick"
			elseif kind == "heal" then
				shown = mine and "heal" or "mend"
			elseif kind == "buff" then
				shown = "shield"
			end
			table.insert(events[viewer], {
				kind = shown,
				text = text,
				damage = damage,
				hp = fighters[viewer].hp,
				enemy = 1,
				enemyHp = fighters[3 - viewer].hp,
			})
		end
	end

	-- One hit from a damage card (Strike, Blast, Drain or Stun). Returns the damage dealt.
	local function strike(side, card, base, prefix)
		local me, foe = fighters[side], fighters[3 - side]
		local damage = base
		local notes = {}
		if Cards.typeBeats(card.type, foe.school) then
			damage = damage * Duel.Strong
			table.insert(notes, "type advantage!")
		elseif Cards.typeBeats(foe.school, card.type) then
			damage = damage * Duel.Resisted
			table.insert(notes, "resisted")
		end
		local weak = table.remove(me.weak, 1)
		if weak then
			damage = damage * (1 - weak)
			table.insert(notes, "weakened")
		end
		local hexed = table.remove(foe.hex, 1)
		if hexed then
			damage = damage * (1 + hexed)
			table.insert(notes, "🎯 hex +" .. percent(hexed))
		end
		if card.type == "warrior" then
			damage = damage * Duel.PvpStagger
			if #foe.shields > 0 then
				foe.shields = {}
				table.insert(notes, "🔨 shields broken")
			end
		end
		local blocked = table.remove(foe.shields, 1)
		local parried = 0
		if blocked then
			parried = math.floor(damage * blocked * Duel.PvpParry)
			damage = damage * (1 - blocked)
			table.insert(notes, "shield " .. percent(blocked))
		end
		if foe.frozen then
			damage = damage * (1 - Duel.FrozenGuard)
		end
		damage = math.max(1, math.floor(damage * (me.might or 1) * (foe.guard or 1)))
		foe.hp = math.max(0, foe.hp - damage)
		if card.type == "tech" and foe.energy > 0 then
			foe.energy = math.max(0, foe.energy - Duel.PvpShockDrain)
			table.insert(notes, "⚡ -" .. Duel.PvpShockDrain .. " energy")
		end
		if foe.hp > 0 then
			if card.type == "beast" then
				foe.bleed = foe.bleed + math.max(1, math.floor(damage * Duel.PvpBleedShare))
				table.insert(notes, "🩸")
			elseif card.type == "mystic" then
				foe.burn = math.max(foe.burnRounds > 0 and foe.burn or 0, math.max(1, math.floor(damage * Duel.BurnShare)))
				foe.burnRounds = Duel.BurnRounds
				table.insert(notes, "♨️")
			elseif card.type == "star" then
				foe.chill = foe.chill + 1
				if foe.chill >= Duel.PvpChillToFreeze then
					foe.chill = 0
					foe.frozen = true
					table.insert(notes, "❄️ FROZEN!")
				else
					table.insert(notes, "❄️" .. foe.chill .. "/" .. Duel.PvpChillToFreeze)
				end
			end
		end
		local text = prefix .. " hits " .. foe.name .. " for " .. damage
		if #notes > 0 then
			text = text .. " (" .. table.concat(notes, ", ") .. ")"
		end
		emit(side, "hit", text, damage)
		if parried > 0 and foe.hp > 0 then
			me.hp = math.max(0, me.hp - parried)
			emit(3 - side, "hit", "🛡️ " .. foe.name .. " parries " .. parried .. " back at " .. me.name, parried)
		end
		return damage
	end

	local function act(side)
		local me, foe = fighters[side], fighters[3 - side]
		local move = me.move or { kind = "pass" }
		if me.stunned then
			me.stunned = false
			me.stunGuard = true
			emit(side, "frozen", "💫 " .. me.name .. " is stunned and loses the turn.")
			return
		end
		if me.frozen then
			me.frozen = false
			emit(side, "frozen", "❄️ " .. me.name .. " is frozen solid and loses the turn.")
			return
		end
		me.stunGuard = false
		local key = move.kind == "play" and me.hand[move.hand] or nil
		local card = key and Duel.pvpCard(key) or nil
		if card == nil or card.cost > me.energy then
			emit(side, "pass", me.name .. " holds and gathers energy.")
			return
		end
		me.energy = me.energy - card.cost
		table.insert(me.discard, table.remove(me.hand, move.hand))
		local prefix = me.name .. "'s " .. card.name

		if card.role == "attack" or card.role == "blast" or card.role == "drain" then
			local base = card.amount * (1 + (table.remove(me.charges, 1) or 0))
			local dealt = strike(side, card, base, prefix)
			if card.role == "drain" and me.hp > 0 then
				local healed = math.min(math.floor(dealt * Duel.DrainHeal * (me.healing or 1)), me.maxHp - me.hp)
				me.hp = me.hp + healed
				emit(side, "heal", "🧛 " .. me.name .. " drains " .. healed .. " health")
			end
		elseif card.role == "stun" then
			strike(side, card, card.amount, prefix)
			if foe.hp > 0 then
				if foe.stunGuard or foe.stunned then
					emit(side, "buff", "💫 " .. foe.name .. " shrugs off the stun (just stunned).")
				else
					foe.stunned = true
					emit(side, "buff", "💫 " .. foe.name .. " is stunned: they lose their next move!")
				end
			end
		elseif card.role == "heal" then
			local healed = math.min(math.floor(card.amount * (me.healing or 1)), me.maxHp - me.hp)
			me.hp = me.hp + healed
			emit(side, "heal", prefix .. " heals " .. me.name .. " for " .. healed)
		elseif card.role == "mend" then
			me.mend = math.max(me.mendRounds > 0 and me.mend or 0, math.floor(card.amount * (me.healing or 1)))
			me.mendRounds = Duel.MendRounds
			emit(side, "buff", "🌿 " .. prefix .. ": " .. me.name .. " heals " .. me.mend .. " a round for " .. Duel.MendRounds .. " rounds")
		elseif card.role == "curse" then
			foe.curse = math.max(foe.curseRounds > 0 and foe.curse or 0, card.amount)
			foe.curseRounds = Duel.CurseRounds
			emit(side, "buff", "☠️ " .. prefix .. " curses " .. foe.name .. " (" .. foe.curse .. " a round)")
		elseif card.role == "hex" then
			if #foe.hex >= Duel.MaxStacks then
				table.remove(foe.hex, 1)
			end
			table.insert(foe.hex, card.amount)
			emit(side, "buff", "🎯 " .. prefix .. " hexes " .. foe.name .. " (next hit +" .. percent(card.amount) .. ")")
		elseif card.role == "shield" then
			if #me.shields >= Duel.MaxStacks then
				table.remove(me.shields, 1)
			end
			table.insert(me.shields, card.amount)
			emit(side, "buff", prefix .. " raises a 🛡️ shield (" .. percent(card.amount) .. ")")
		elseif card.role == "charge" then
			if #me.charges >= Duel.MaxStacks then
				table.remove(me.charges, 1)
			end
			table.insert(me.charges, card.amount)
			emit(side, "buff", prefix .. " powers up 💪 (+" .. percent(card.amount) .. ")")
		else
			if #foe.weak >= Duel.MaxStacks then
				table.remove(foe.weak, 1)
			end
			table.insert(foe.weak, card.amount)
			emit(side, "buff", prefix .. " weakens " .. foe.name .. " 🌀 (-" .. percent(card.amount) .. ")")
		end
	end

	local first = state.round % 2 == 1 and 1 or 2
	for _, side in ipairs({ first, 3 - first }) do
		if not state.over then
			act(side)
			if fighters[3 - side].hp <= 0 then
				state.over, state.winner = true, side
			end
		end
	end

	-- bleeding and burning at the end of the round
	if not state.over then
		for side = 1, 2 do
			local me = fighters[side]
			local damage, parts = 0, {}
			if me.bleed > 0 then
				damage = damage + me.bleed
				me.bleed = math.floor(me.bleed / 2)
				table.insert(parts, "bleeds")
			end
			if me.burnRounds > 0 then
				damage = damage + me.burn
				me.burnRounds = me.burnRounds - 1
				table.insert(parts, "burns")
			end
			if me.curseRounds > 0 then
				damage = damage + me.curse
				me.curseRounds = me.curseRounds - 1
				table.insert(parts, "is cursed")
			end
			if damage > 0 then
				me.hp = math.max(0, me.hp - damage)
				emit(side, "tick", me.name .. " " .. table.concat(parts, " and ") .. " for " .. damage, damage)
			end
			if me.mendRounds > 0 and me.hp > 0 then
				me.mendRounds = me.mendRounds - 1
				local healed = math.min(me.mend, me.maxHp - me.hp)
				me.hp = me.hp + healed
				emit(side, "heal", "🌿 " .. me.name .. " mends " .. healed)
			end
		end
		local down1, down2 = fighters[1].hp <= 0, fighters[2].hp <= 0
		if down1 or down2 then
			state.over = true
			state.winner = (down1 and down2) and 0 or (down1 and 2 or 1)
		end
	end

	if not state.over and state.round >= Duel.PvpMaxRounds then
		local share1 = fighters[1].hp / fighters[1].maxHp
		local share2 = fighters[2].hp / fighters[2].maxHp
		state.over = true
		state.winner = share1 > share2 and 1 or (share2 > share1 and 2 or 0)
		emit(1, "pass", "⏱️ Time! The healthier duellist wins.")
	end

	for _, me in ipairs(fighters) do
		me.move = nil
	end
	if not state.over then
		state.round = state.round + 1
		for _, me in ipairs(fighters) do
			me.energy = math.min(Duel.MaxEnergy, me.energy + 1)
			draw(me, rng)
		end
	end
	return events
end

-- Practice duels: a bot opponent for player-duel rules, at three levels. rarities = the
-- rarest card it may bring; training = Battle Training levels in every upgrade; health = added
-- to (or taken from) its health; sloppy = the share of rounds it plays a random card.
Duel.PracticeLevels = {
	{ name = "Apprentice", rarities = 3, training = 0, health = -100, sloppy = 0.6 },
	{ name = "Adept", rarities = 5, training = 1, health = -40, sloppy = 0.3 },
	{ name = "Master", rarities = 7, training = 4, health = 0, sloppy = 0 },
}

-- What the practice bot of a level gets, in the shape Duel.pvpNew takes.
function Duel.practiceTraining(level, Training)
	local settings = Duel.PracticeLevels[level]
	local levels = {}
	for _, id in ipairs(Training.Order) do
		levels[id] = settings.training
	end
	local stats = Training.stats(levels)
	stats.health = stats.health + settings.health
	stats.levels = Training.total(levels)
	return stats
end

-- The practice bot's deck: an auto-built deck from random cards up to the level's rarity.
function Duel.practiceDeck(level, rng)
	local settings = Duel.PracticeLevels[level]
	local pool = {}
	for _, def in ipairs(Cards.List) do
		if Cards.Rarities[def.rarity].order <= settings.rarities then
			table.insert(pool, def.id)
		end
	end
	local inventory = {}
	for _ = 1, 60 do
		local id = pool[rng:NextInteger(1, #pool)]
		inventory[id] = (inventory[id] or 0) + 1
	end
	return Duel.autoDeck({ inventory = inventory, slots = {}, vault = {} })
end

-- The bot's move for one side of a player duel.
function Duel.botMove(state, side, level, rng)
	local view = Duel.pvpView(state, side)
	local settings = Duel.PracticeLevels[level] or Duel.PracticeLevels[1]
	if rng:NextNumber() < settings.sloppy then
		local options = {}
		for index, key in ipairs(view.hand) do
			if Duel.pvpCard(key).cost <= view.energy then
				table.insert(options, index)
			end
		end
		if #options > 0 then
			return { kind = "play", hand = options[rng:NextInteger(1, #options)] }
		end
		return { kind = "pass" }
	end
	local suggestion = Duel.suggest(view)
	return { kind = suggestion.kind, hand = suggestion.hand }
end

-- One side forfeits (fled or left the game).
function Duel.pvpForfeit(state, side)
	if not state.over then
		state.over = true
		state.winner = 3 - side
	end
end

-- What one side is allowed to see. Shaped like Duel.view, with the opponent as the only
-- "enemy", so the duel screen and stage work for both kinds of fight.
function Duel.pvpView(state, side)
	local me, foe = state.fighters[side], state.fighters[3 - side]
	return {
		mode = "pvp",
		floor = 0,
		round = state.round,
		energy = me.energy,
		hp = me.hp,
		maxHp = me.maxHp,
		shields = #me.shields,
		charges = #me.charges,
		poison = 0,
		school = me.school,
		bleed = me.bleed,
		burn = me.burnRounds > 0 and me.burn or 0,
		chill = me.chill,
		frozen = me.frozen,
		curse = me.curseRounds > 0 and me.curse or 0,
		stunned = me.stunned,
		mend = me.mendRounds > 0 and me.mend or 0,
		chosen = me.move ~= nil,
		enemies = {
			{
				name = foe.name,
				glyph = Cards.Types[foe.school].icon,
				type = foe.school,
				boss = false,
				kind = "brute",
				regen = false,
				armor = 0,
				enrages = false,
				attack = Duel.PvpThreat, -- what the bot expects a hit to be; their hand is hidden
				hp = foe.hp,
				maxHp = foe.maxHp,
				weak = #foe.weak,
				winding = false,
				bleed = foe.bleed,
				burn = foe.burnRounds > 0 and foe.burn or 0,
				chill = foe.chill,
				chillMax = Duel.PvpChillToFreeze,
				frozen = foe.frozen,
				curse = foe.curseRounds > 0 and foe.curse or 0,
				hex = #foe.hex,
				stunned = foe.stunned,
				stunGuard = foe.stunGuard,
				shields = #foe.shields,
				charges = #foe.charges,
				ready = foe.move ~= nil,
				trained = foe.trainedLevels,
			},
		},
		hand = table.clone(me.hand),
		deckLeft = #me.deck,
		over = state.over,
		win = state.winner == side,
		draw = state.winner == 0,
	}
end

return Duel
