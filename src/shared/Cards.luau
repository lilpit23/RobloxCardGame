-- Card database, organised like a trading card game: expansion SETS of numbered cards.
-- Add a card by adding a row to its set below; add a set by adding a block to SETS.
-- A "card key" identifies a card + variant: "stretch_pirate" (normal) or "stretch_pirate:gold".
local Cards = {}

Cards.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

-- income = base cash per second for the first card of that rarity in set 1.
-- symbol = the rarity mark printed on the card.
-- sell = sell price as a share of the card's set Booster price. Keep these low: the cards in
-- an average pack must sell for well under the pack's price, or packs become free money.
Cards.Rarities = {
	Common = { order = 1, color = Color3.fromRGB(140, 150, 165), aura = 0, income = 1, symbol = "●", sell = 0.015 },
	Uncommon = { order = 2, color = Color3.fromRGB(70, 185, 95), aura = 0, income = 5, symbol = "◆", sell = 0.04 },
	Rare = { order = 3, color = Color3.fromRGB(55, 130, 235), aura = 0, income = 15, symbol = "★", sell = 0.08 },
	Epic = { order = 4, color = Color3.fromRGB(160, 75, 230), aura = 1, income = 120, symbol = "★★", sell = 0.25 },
	Legendary = { order = 5, color = Color3.fromRGB(245, 170, 40), aura = 5, income = 900, symbol = "★★★", sell = 0.9 },
	Mythic = { order = 6, color = Color3.fromRGB(235, 55, 95), aura = 25, income = 8000, symbol = "✦", sell = 3.5 },
	Secret = { order = 7, color = Color3.fromRGB(35, 35, 45), aura = 150, income = 80000, symbol = "✪", sell = 15 },
}

-- Variants multiply income and aura. "chance" is rolled per card pulled.
Cards.VariantOrder = { "normal", "holo", "gold", "prism" }

Cards.Variants = {
	normal = { name = "", mult = 1, chance = 0, color = Color3.fromRGB(25, 25, 30) },
	holo = { name = "Holo", mult = 2, chance = 0.08, color = Color3.fromRGB(120, 235, 255) },
	gold = { name = "Gold", mult = 5, chance = 0.02, color = Color3.fromRGB(255, 205, 60) },
	prism = { name = "Prismatic", mult = 20, chance = 0.003, color = Color3.fromRGB(255, 255, 255) },
}

-- Card types. Used for display synergies and battles: each type beats the next one in
-- TypeOrder (and the last beats the first).
Cards.TypeOrder = { "warrior", "beast", "mystic", "tech", "star" }
Cards.Types = {
	warrior = { name = "Warrior", icon = "⚔️" },
	beast = { name = "Beast", icon = "🐾" },
	mystic = { name = "Mystic", icon = "🔮" },
	tech = { name = "Tech", icon = "⚙️" },
	star = { name = "Star", icon = "⭐" },
}
local TYPE_BY_LETTER = { w = "warrior", b = "beast", m = "mystic", t = "tech", s = "star" }

-- The sets are parodies of anime genres. Cards use plain descriptive nicknames ("Stretch
-- Pirate"), never a real character's name, official title, catchphrase or likeness.
-- Each card row is { name, glyph, type letter } (w/b/m/t/s). A card's id is its name in
-- lower case with underscores ("Stretch Pirate" -> "stretch_pirate"); ids are what gets
-- saved, so renaming a card orphans the copies players already own.
-- Cards are numbered in the order written, Common first. Secret cards are numbered past the
-- set size (e.g. 037/036), like secret rares. "mult" scales every card's income, so later
-- sets are worth more. "packCost" is the price of the set's Booster pack.
-- To give a card real art, add a fourth entry: "rbxassetid://<image id>".
local SETS = {
	{
		id = "pirate",
		code = "UNP",
		name = "Uno Price",
		blurb = "Pirates chasing the greatest treasure on the seas.",
		mult = 1,
		packCost = 100,
		cards = {
			Common = {
				{ "Cabin Boy", "🧒", "w" },
				{ "Deck Swabber", "🧹", "w" },
				{ "Barrel Pirate", "🛢️", "s" },
				{ "Seagull Lookout", "🐦", "b" },
				{ "Rookie Marine", "⚓", "w" },
				{ "Fishman Grunt", "🐟", "b" },
				{ "Clown Crew Pirate", "🤡", "s" },
				{ "Island Villager", "🏝️", "s" },
				{ "Treasure Map Kid", "🗺️", "s" },
				{ "Snail Phone Operator", "🐌", "t" },
				{ "Dock Bartender", "🍺", "s" },
				{ "Cannon Loader", "💣", "t" },
			},
			Uncommon = {
				{ "Sniper Storyteller", "🎯", "t" },
				{ "Navigator Thief", "🍊", "m" },
				{ "Reindeer Doctor", "🦌", "b" },
				{ "Axe-Hand Captain", "🪓", "w" },
				{ "Clown Captain", "🎪", "s" },
				{ "Smoke Marine", "💨", "m" },
				{ "Desert Princess", "👸", "s" },
				{ "Sea Train Engineer", "🚂", "t" },
			},
			Rare = {
				{ "Green Swordsman", "🗡️", "w" },
				{ "Kicking Cook", "🍳", "w" },
				{ "Cyborg Shipwright", "🔩", "t" },
				{ "Skeleton Musician", "🎻", "s" },
				{ "Many-Hands Scholar", "🌸", "m" },
				{ "Fishman Karate Master", "🌊", "b" },
			},
			Epic = {
				{ "Stretch Pirate", "🏴‍☠️", "w" },
				{ "Flame Brother", "🔥", "m" },
				{ "Sharp-Eyed Swordmaster", "🦅", "w" },
				{ "Snake Empress", "🐍", "b" },
				{ "Room Surgeon", "⚕️", "m" },
			},
			Legendary = {
				{ "Scarred Red Captain", "🍷", "w" },
				{ "Earthquake Old Captain", "🌋", "m" },
				{ "Dragon Beast Emperor", "🐉", "b" },
			},
			Mythic = {
				{ "Darkness Emperor", "🌑", "m" },
				{ "Laughing Sun Warrior", "☀️", "s" },
			},
			Secret = {
				{ "The Greatest Treasure", "💎", "s" },
			},
		},
	},
	{
		id = "ninja",
		code = "NDN",
		name = "Noodle Ninja",
		blurb = "A hidden village of ninja, rivals and ramen.",
		mult = 4,
		packCost = 5000,
		cards = {
			Common = {
				{ "Academy Student", "📚", "w" },
				{ "Ramen Shop Owner", "🍜", "s" },
				{ "Ninja Hound", "🐕", "b" },
				{ "Scroll Courier", "📜", "s" },
				{ "Training Log", "🪵", "t" },
				{ "Kunai Rookie", "🔪", "w" },
				{ "Village Gate Guard", "🚪", "w" },
				{ "Messenger Toad", "🐸", "b" },
				{ "Smoke Bomb Kid", "💨", "t" },
				{ "Sandal Maker", "🩴", "s" },
				{ "Squirrel Scout", "🐿️", "b" },
				{ "Paper Bomb Crafter", "🧨", "t" },
			},
			Uncommon = {
				{ "Lazy Shadow Genius", "☁️", "m" },
				{ "Snack-Loving Brawler", "🍖", "w" },
				{ "Bug Whisperer", "🐛", "b" },
				{ "Mind-Swap Florist", "💐", "m" },
				{ "Hard-Working Kicker", "🥋", "w" },
				{ "Weapon Mistress", "⚔️", "t" },
				{ "Puppet Master", "🎎", "t" },
				{ "Wind Fan Kunoichi", "🪭", "m" },
			},
			Rare = {
				{ "Pink Medic Ninja", "🌸", "m" },
				{ "Gentle Palm Prodigy", "👁️", "w" },
				{ "Masked Teacher", "😷", "w" },
				{ "Sand Guardian", "🏜️", "m" },
				{ "Dog Rider", "🐺", "b" },
				{ "Green Beast Mentor", "🐢", "w" },
			},
			Epic = {
				{ "Orange Prankster Ninja", "🍥", "w" },
				{ "Lone Avenger", "⚡", "m" },
				{ "Toad Hermit", "📖", "b" },
				{ "Slug Princess Healer", "🩹", "m" },
				{ "Snake Scientist", "🐍", "b" },
			},
			Legendary = {
				{ "Yellow Flash Leader", "💛", "w" },
				{ "Crow Illusionist", "🐦‍⬛", "m" },
				{ "Forest Founder", "🌳", "m" },
			},
			Mythic = {
				{ "Masked Moon Schemer", "🌕", "m" },
				{ "Nine-Tailed Fox Spirit", "🦊", "b" },
			},
			Secret = {
				{ "The First Sage", "☯️", "m" },
			},
		},
	},
	{
		id = "dragon",
		code = "DGB",
		name = "Dragon Bowl",
		blurb = "Martial artists powering up to protect the world.",
		mult = 16,
		packCost = 250000,
		cards = {
			Common = {
				{ "Turtle School Student", "🐢", "w" },
				{ "Flying Cloud", "☁️", "m" },
				{ "Capsule Engineer", "💊", "t" },
				{ "Desert Bandit", "🏜️", "w" },
				{ "Shape-Shift Piglet", "🐷", "b" },
				{ "Tournament Announcer", "🎙️", "s" },
				{ "Bean Farmer", "🫘", "s" },
				{ "Scouter Soldier", "🔍", "t" },
				{ "Little Green Minion", "🌱", "b" },
				{ "Dinosaur Hatchling", "🦖", "b" },
				{ "Radar Inventor", "📡", "t" },
				{ "Weighted Shell Trainee", "🏋️", "w" },
			},
			Uncommon = {
				{ "Bald Monk Fighter", "🧘", "w" },
				{ "Three-Eyed Fighter", "🔺", "w" },
				{ "Old Turtle Hermit", "🏖️", "m" },
				{ "Wolf Fang Bandit", "🐺", "b" },
				{ "Scholar Half-Warrior", "📘", "w" },
				{ "Android Twin", "🤖", "t" },
				{ "Pink Blob Trickster", "🍬", "m" },
				{ "Champion Showman", "🏆", "s" },
			},
			Rare = {
				{ "Green Mentor Warrior", "💚", "w" },
				{ "Time-Travel Swordsman", "⏰", "w" },
				{ "Proud Warrior Prince", "👑", "w" },
				{ "Purple Captain Poser", "🕺", "s" },
				{ "Insect Bio-Android", "🪲", "b" },
				{ "Fusion Dancers", "🤝", "s" },
			},
			Epic = {
				{ "Monkey-Tailed Hero", "🐒", "w" },
				{ "Golden Hair Form", "🌟", "s" },
				{ "Galactic Tyrant", "👽", "m" },
				{ "Cat God of Destruction", "🐱", "b" },
				{ "Angel Attendant", "😇", "m" },
			},
			Legendary = {
				{ "Blue Hair Form", "💙", "s" },
				{ "Legendary Berserker", "💪", "w" },
				{ "Fused Warrior", "✨", "w" },
			},
			Mythic = {
				{ "Silver Instinct Form", "🤍", "s" },
				{ "Wish Dragon", "🐉", "b" },
			},
			Secret = {
				{ "The Tiny King of All", "🔘", "m" },
			},
		},
	},
	{
		id = "demon",
		code = "DMS",
		name = "Demon Sweeper",
		blurb = "Sword masters hunting demons through the night.",
		mult = 64,
		packCost = 12000000,
		cards = {
			Common = {
				{ "Charcoal Seller", "🪨", "s" },
				{ "Messenger Crow", "🐦‍⬛", "b" },
				{ "Sword Trainee", "🗡️", "w" },
				{ "Wisteria Gardener", "🌿", "m" },
				{ "Butterfly Nurse", "🦋", "m" },
				{ "Mountain Sparrow", "🐤", "b" },
				{ "Hand Demon", "✋", "b" },
				{ "Swamp Demon", "🫧", "b" },
				{ "Mask Carver", "🎭", "s" },
				{ "Swordsmith Apprentice", "⚒️", "t" },
				{ "Rice Ball Girl", "🍙", "s" },
				{ "Night Train Conductor", "🚂", "t" },
			},
			Uncommon = {
				{ "Boar-Headed Brawler", "🐗", "b" },
				{ "Sleepy Thunder Boy", "⚡", "w" },
				{ "Bamboo Sister", "🎋", "b" },
				{ "Drum Demon", "🥁", "s" },
				{ "Spider Mother", "🕷️", "b" },
				{ "Masked Swordsmith", "🔨", "t" },
				{ "Butterfly Apprentice", "🪻", "m" },
				{ "Rifle Brother", "🎯", "t" },
			},
			Rare = {
				{ "Checkered Sun Swordsman", "🎴", "w" },
				{ "Water Blade Master", "💧", "w" },
				{ "Insect Blade Master", "🐝", "m" },
				{ "Sound Blade Master", "🎵", "s" },
				{ "Love Blade Master", "💗", "s" },
				{ "Spider Thread Boy", "🕸️", "b" },
			},
			Epic = {
				{ "Flame Blade Master", "🔥", "w" },
				{ "Mist Blade Prodigy", "🌫️", "w" },
				{ "Serpent Blade Master", "🐍", "w" },
				{ "Ice Fan Demon", "❄️", "m" },
				{ "Tattooed Fist Demon", "👊", "b" },
			},
			Legendary = {
				{ "Stone Giant Monk", "📿", "w" },
				{ "Six-Eyed Moon Swordsman", "🌙", "w" },
				{ "First Sun Dancer", "☀️", "w" },
			},
			Mythic = {
				{ "Demon King in White", "🩸", "m" },
				{ "Sunlit Sister", "🌅", "b" },
			},
			Secret = {
				{ "The Blue Spider Lily", "🌺", "m" },
			},
		},
	},
}

---------------------------------------------------------------------
-- Build the lookup tables from SETS
---------------------------------------------------------------------
Cards.List = {} -- every card, in set then number order
Cards.ById = {}
Cards.ByRarity = {}
Cards.SetOrder = {}
Cards.Sets = {} -- [setId] = { id, code, name, mult, size, cards = { def, ... } }

for _, rarityName in ipairs(Cards.RarityOrder) do
	Cards.ByRarity[rarityName] = {}
end

for _, setData in ipairs(SETS) do
	local set = {
		blurb = setData.blurb,
		id = setData.id,
		code = setData.code,
		name = setData.name,
		mult = setData.mult,
		packCost = setData.packCost,
		size = 0,
		cards = {},
	}
	Cards.Sets[set.id] = set
	table.insert(Cards.SetOrder, set.id)

	for _, rarityName in ipairs(Cards.RarityOrder) do
		local rarity = Cards.Rarities[rarityName]
		for position, row in ipairs(setData.cards[rarityName] or {}) do
			-- each card of a rarity is worth 10% more than the one before it
			local income = math.max(1, math.floor(rarity.income * (1 + 0.1 * (position - 1)) * set.mult + 0.5))
			local def = {
				id = string.gsub(string.gsub(string.lower(row[1]), "[^%w]+", "_"), "^_*(.-)_*$", "%1"),
				name = row[1],
				glyph = row[2],
				type = TYPE_BY_LETTER[row[3]] or "warrior",
				image = row[4],
				rarity = rarityName,
				income = income,
				set = set.id,
				number = #set.cards + 1,
			}
			assert(Cards.ById[def.id] == nil, "duplicate card id " .. def.id)
			table.insert(set.cards, def)
			table.insert(Cards.List, def)
			table.insert(Cards.ByRarity[rarityName], def)
			Cards.ById[def.id] = def
			def.index = #Cards.List
			if rarityName ~= "Secret" then
				set.size = set.size + 1
			end
		end
	end
	for _, def in ipairs(set.cards) do
		def.numberText = string.format("%03d/%03d", def.number, set.size)
	end
end

function Cards.typeBeats(attackerType, targetType)
	for index, typeId in ipairs(Cards.TypeOrder) do
		if typeId == attackerType then
			return Cards.TypeOrder[index % #Cards.TypeOrder + 1] == targetType
		end
	end
	return false
end

-- Cards of one rarity, optionally limited to a list of set ids (nil = every set).
local poolCache = {}
function Cards.pool(rarityName, sets)
	if sets == nil then
		return Cards.ByRarity[rarityName]
	end
	local cacheKey = rarityName .. "|" .. table.concat(sets, ",")
	local pool = poolCache[cacheKey]
	if pool == nil then
		pool = {}
		for _, def in ipairs(Cards.ByRarity[rarityName]) do
			if table.find(sets, def.set) then
				table.insert(pool, def)
			end
		end
		poolCache[cacheKey] = pool
	end
	return pool
end

function Cards.makeKey(id, variantId)
	if variantId == nil or variantId == "normal" then
		return id
	end
	return id .. ":" .. variantId
end

-- Returns def, variantId, variantDef — or nil if the key is not a real card.
function Cards.parse(key)
	if type(key) ~= "string" then
		return nil
	end
	local id, variantId = string.match(key, "^([^:]+):?(.*)$")
	if variantId == nil or variantId == "" then
		variantId = "normal"
	end
	local def = Cards.ById[id]
	local variant = Cards.Variants[variantId]
	if def == nil or variant == nil then
		return nil
	end
	if Cards.makeKey(id, variantId) ~= key then
		return nil
	end
	return def, variantId, variant
end

-- True if any variant of the card has ever been owned.
function Cards.discovered(collection, def)
	for _, variantId in ipairs(Cards.VariantOrder) do
		if collection[Cards.makeKey(def.id, variantId)] then
			return true
		end
	end
	return false
end

-- How much of a set's card list has been collected (any variant counts).
-- Returns found, total (total includes secret cards).
function Cards.setProgress(collection, setId)
	local set = Cards.Sets[setId]
	local found = 0
	for _, def in ipairs(set.cards) do
		if Cards.discovered(collection, def) then
			found = found + 1
		end
	end
	return found, #set.cards
end

-- Number of sets with every card collected.
function Cards.completedSets(collection)
	local completed = 0
	for _, setId in ipairs(Cards.SetOrder) do
		local found, total = Cards.setProgress(collection, setId)
		if found >= total then
			completed = completed + 1
		end
	end
	return completed
end

-- The variant one step up (normal -> holo -> gold -> prism), or nil at the top.
function Cards.nextVariant(variantId)
	for index, id in ipairs(Cards.VariantOrder) do
		if id == variantId then
			return Cards.VariantOrder[index + 1]
		end
	end
	return nil
end

function Cards.getIncome(key)
	local def, _, variant = Cards.parse(key)
	if def == nil then
		return 0
	end
	return def.income * variant.mult
end

function Cards.getAura(key)
	local def, _, variant = Cards.parse(key)
	if def == nil then
		return 0
	end
	return Cards.Rarities[def.rarity].aura * variant.mult
end

-- Cash for selling a card: a share of its set's Booster price, by rarity and variant.
function Cards.getSellValue(key)
	local def, _, variant = Cards.parse(key)
	if def == nil then
		return 0
	end
	local set = Cards.Sets[def.set]
	return math.max(1, math.floor(set.packCost * Cards.Rarities[def.rarity].sell * variant.mult))
end

function Cards.getDisplayName(key)
	local def, variantId, variant = Cards.parse(key)
	if def == nil then
		return "?"
	end
	if variantId == "normal" then
		return def.name
	end
	return variant.name .. " " .. def.name
end

return Cards
