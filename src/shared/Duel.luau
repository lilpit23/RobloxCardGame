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

-- What a card does when played. Every card has exactly one role.
Duel.Roles = {
	attack = { name = "Strike", icon = "⚔️", target = true },
	blast = { name = "Blast", icon = "💥" },
	heal = { name = "Heal", icon = "💚" },
	shield = { name = "Shield", icon = "🛡️" },
	charge = { name = "Power-up", icon = "🔥" },
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
	if role == "attack" then
		amount = power
		text = short(amount) .. " damage to one enemy"
	elseif role == "blast" then
		amount = math.max(1, math.floor(power * 0.5))
		text = short(amount) .. " damage to every enemy"
	elseif role == "heal" then
		amount = math.floor(power * 1.5)
		text = "Heal " .. short(amount) .. " health"
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
-- or traded away drop out. Returns a new array of keys.
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

function Duel.enemies(floor)
	local power = Duel.floorPower(floor)
	local boss = floor % Duel.BossEvery == 0
	local count = 3
	if floor <= 3 then
		count = 1
	elseif floor <= 9 then
		count = 2
	end
	local list = {}
	for index = 1, count do
		local def = Cards.List[(floor * 7 + index * 13) % #Cards.List + 1]
		local isBoss = boss and index == 1
		local hp = math.max(10, math.floor(power * (isBoss and 6 or 2.5)))
		list[index] = {
			name = (isBoss and "👑 " or "") .. "Shadow " .. def.name,
			glyph = def.glyph,
			type = def.type,
			boss = isBoss,
			attack = math.max(1, math.floor(power * (isBoss and 0.55 or 0.32))),
			maxHp = hp,
			hp = hp,
			weak = {}, -- fractions taken off its next attacks
			winding = false, -- a boss about to land its big hit
		}
	end
	return list
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
function Duel.new(floor, deck, rng)
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
		round = 1,
		energy = Duel.StartEnergy,
		hp = health,
		maxHp = health,
		shields = {}, -- fractions blocked from the next hits
		charges = {}, -- fractions added to the next attacks
		enemies = Duel.enemies(floor),
		deck = pile,
		hand = {},
		discard = {},
		over = false,
		win = false,
	}
	draw(state, rng)
	return state
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
			attack = enemy.attack,
			hp = enemy.hp,
			maxHp = enemy.maxHp,
			weak = #enemy.weak,
			winding = enemy.winding,
		}
	end
	return {
		floor = state.floor,
		round = state.round,
		energy = state.energy,
		hp = state.hp,
		maxHp = state.maxHp,
		shields = #state.shields,
		charges = #state.charges,
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

local function hitEnemy(state, events, card, index, damage)
	local enemy = state.enemies[index]
	local strong = Cards.typeBeats(card.type, enemy.type)
	local resisted = Cards.typeBeats(enemy.type, card.type)
	if strong then
		damage = damage * Duel.Strong
	elseif resisted then
		damage = damage * Duel.Resisted
	end
	damage = math.max(1, math.floor(damage))
	enemy.hp = math.max(0, enemy.hp - damage)
	local text = card.name .. " hits " .. enemy.name .. " for " .. short(damage)
	if strong then
		text = text .. " — type advantage!"
	elseif resisted then
		text = text .. " (resisted)"
	end
	if enemy.hp <= 0 then
		text = text .. "  KO!"
	end
	table.insert(events, { kind = "hit", text = text, enemy = index, enemyHp = enemy.hp })
end

-- The enemies' turn, then the start of the next round.
local function finishRound(state, events, rng)
	if firstAlive(state) == nil then
		state.over, state.win = true, true
		table.insert(events, { kind = "win", text = "🏆 Victory!" })
		return
	end

	for index, enemy in ipairs(state.enemies) do
		if enemy.hp > 0 and state.hp > 0 then
			if enemy.boss and not enemy.winding and state.round % 3 == 2 then
				-- bosses spend a turn winding up, so you can see the big hit coming
				enemy.winding = true
				table.insert(events, { kind = "windup", text = "⚠️ " .. enemy.name .. " is winding up a huge attack!", enemy = index })
			else
				local damage = enemy.attack * (0.85 + 0.3 * rng:NextNumber())
				if enemy.winding then
					damage = damage * 2.2
					enemy.winding = false
				end
				local weak = table.remove(enemy.weak, 1)
				if weak then
					damage = damage * (1 - weak)
				end
				local blocked = table.remove(state.shields, 1)
				if blocked then
					damage = damage * (1 - blocked)
				end
				damage = math.max(1, math.floor(damage))
				state.hp = math.max(0, state.hp - damage)
				local text = enemy.name .. " hits you for " .. short(damage)
				if blocked then
					text = text .. " (shield blocked " .. percent(blocked) .. ")"
				elseif weak then
					text = text .. " (weakened)"
				end
				table.insert(events, { kind = "hurt", text = text, enemy = index, hp = state.hp })
			end
		end
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
		table.insert(events, { kind = "heal", text = card.name .. " heals you for " .. short(healed), hp = state.hp })
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

return Duel
