-- Card database, organised like a trading card game: expansion SETS of numbered cards.
-- Add a card by adding a row to its set below; add a set by adding a block to SETS.
-- A "card key" identifies a card + variant: "piglet" (normal) or "piglet:gold".
local Cards = {}

Cards.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

-- income = base cash per second for the first card of that rarity in set 1.
-- symbol = the rarity mark printed on the card.
-- sell = sell price as a share of the card's set Booster price. Keep these low: the cards in
-- an average pack must sell for well under the pack's price, or packs become free money.
Cards.Rarities = {
	Common = { order = 1, color = Color3.fromRGB(140, 150, 165), aura = 0, income = 1, symbol = "●", sell = 0.015 },
	Uncommon = { order = 2, color = Color3.fromRGB(70, 185, 95), aura = 0, income = 3, symbol = "◆", sell = 0.04 },
	Rare = { order = 3, color = Color3.fromRGB(55, 130, 235), aura = 0, income = 8, symbol = "★", sell = 0.08 },
	Epic = { order = 4, color = Color3.fromRGB(160, 75, 230), aura = 1, income = 25, symbol = "★★", sell = 0.2 },
	Legendary = { order = 5, color = Color3.fromRGB(245, 170, 40), aura = 5, income = 80, symbol = "★★★", sell = 0.7 },
	Mythic = { order = 6, color = Color3.fromRGB(235, 55, 95), aura = 25, income = 300, symbol = "✦", sell = 2.5 },
	Secret = { order = 7, color = Color3.fromRGB(35, 35, 45), aura = 150, income = 1500, symbol = "✪", sell = 10 },
}

-- Card EFFECTS (called "variants" in code). A pulled card can come with one effect.
--   mult       = cash multiplier for that card
--   chance     = base chance per card pulled (luck raises it)
--   deckIncome = while in the deck, adds this much cash bonus to the WHOLE deck
--   deckLuck   = while in the deck, adds this many luck levels
--   auraFlat   = extra aura per second, even on cards that normally give none
--   auraMult   = aura multiplier (defaults to mult)
--   tint       = colour wash over the card face
--   shine      = a diagonal foil streak across the card
Cards.VariantOrder = { "normal", "holo", "slimy", "lucky", "shadow", "gold", "fullart", "prism" }

Cards.Variants = {
	normal = { name = "", mult = 1, chance = 0, color = Color3.fromRGB(25, 25, 30) },
	holo = { name = "Shiny", mult = 1.5, chance = 0.07, shine = true, color = Color3.fromRGB(120, 235, 255) },
	slimy = {
		name = "Slimy",
		mult = 1.25,
		chance = 0.04,
		deckIncome = 0.02,
		color = Color3.fromRGB(110, 230, 90),
		tint = Color3.fromRGB(90, 220, 70),
	},
	lucky = {
		name = "Lucky",
		mult = 1.25,
		chance = 0.03,
		deckLuck = 0.5,
		color = Color3.fromRGB(60, 200, 120),
		tint = Color3.fromRGB(40, 180, 110),
	},
	shadow = {
		name = "Shadow",
		mult = 2,
		chance = 0.02,
		auraFlat = 1,
		color = Color3.fromRGB(120, 60, 200),
		tint = Color3.fromRGB(20, 0, 45),
	},
	gold = {
		name = "Golden",
		mult = 3,
		chance = 0.015,
		shine = true,
		color = Color3.fromRGB(255, 205, 60),
		tint = Color3.fromRGB(255, 200, 40),
	},
	fullart = {
		name = "Full Art",
		mult = 4,
		chance = 0.006,
		fullArt = true, -- the picture fills the whole card
		shine = true,
		color = Color3.fromRGB(255, 170, 220),
	},
	prism = {
		name = "Prismatic",
		mult = 8,
		chance = 0.003,
		deckIncome = 0.05,
		deckLuck = 1,
		shine = true,
		color = Color3.fromRGB(255, 255, 255),
	},
}

-- Effects are rolled rarest first; the first one that hits is kept.
Cards.RollOrder = { "prism", "fullart", "gold", "shadow", "lucky", "slimy", "holo" }

-- Fusing 3 copies moves a card one step along this chain. Other effects are pull-only.
Cards.FuseOrder = { "normal", "holo", "gold", "prism" }

-- "x3 cash, +2 aura/s" — what an effect does, for the effects guide.
function Cards.effectText(variantId)
	local variant = Cards.Variants[variantId]
	local parts = { "x" .. variant.mult .. " cash" }
	if variant.auraFlat then
		table.insert(parts, "+" .. variant.auraFlat .. " aura/s")
	end
	if variant.deckIncome then
		table.insert(parts, "+" .. math.floor(variant.deckIncome * 100 + 0.5) .. "% deck cash")
	end
	if variant.deckLuck then
		table.insert(parts, "+" .. variant.deckLuck .. " luck")
	end
	return table.concat(parts, ", ")
end

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

-- Every set is built from PUBLIC-DOMAIN stories, so real character names can be used.
-- Base cards on the original books ("sources"), not on later films or shows: details those
-- adaptations added (a costume, a song, a redesign) can still be protected.
-- Each card row is { name, glyph, type letter } (w/b/m/t/s). A card's id is its name in
-- lower case with underscores ("Winnie-the-Pooh" -> "winnie_the_pooh"); ids are what gets
-- saved, so renaming a card orphans the copies players already own.
-- Cards are numbered in the order written, Common first. Secret cards are numbered past the
-- set size (e.g. 037/036), like secret rares. "mult" scales every card's income, so later
-- sets are worth more. "packCost" is the price of the set's Booster pack. "icon" and "color"
-- give the set its own look on cards and packs.
-- To give a card real art, add a fourth entry: "rbxassetid://<image id>".
local SETS = {
	{
		id = "storybook",
		code = "SBF",
		name = "Storybook Friends",
		icon = "📖",
		color = Color3.fromRGB(235, 170, 60),
		sources = "Winnie-the-Pooh, Alice in Wonderland, The Wonderful Wizard of Oz, Peter Pan",
		mult = 1,
		packCost = 100,
		cards = {
			Common = {
				{ "Honey Bee", "🐝", "b" },
				{ "Honey Pot", "🍯", "s" },
				{ "Rabbit's Friends and Relations", "🐇", "b" },
				{ "Playing Card Gardener", "🃏", "s" },
				{ "Talking Flower", "🌷", "m" },
				{ "Munchkin", "🧢", "s" },
				{ "Winged Monkey", "🐒", "b" },
				{ "Lost Boy", "🧒", "w" },
				{ "Dormouse", "🐭", "b" },
				{ "Field Mouse", "🐁", "b" },
				{ "Kalidah", "🐯", "b" },
				{ "Pirate Deckhand", "🏴‍☠️", "w" },
			},
			Uncommon = {
				{ "Roo", "🦘", "b" },
				{ "Kanga", "👜", "b" },
				{ "Owl", "🦉", "m" },
				{ "Rabbit", "🥕", "b" },
				{ "March Hare", "☕", "s" },
				{ "Dodo", "🦤", "b" },
				{ "Toto", "🐕", "b" },
				{ "Smee", "🧔", "w" },
			},
			Rare = {
				{ "Piglet", "🐷", "b" },
				{ "Eeyore", "🫏", "b" },
				{ "White Rabbit", "⏱️", "s" },
				{ "Scarecrow", "🌾", "m" },
				{ "Tin Woodman", "🪓", "t" },
				{ "Cowardly Lion", "🦁", "b" },
			},
			Epic = {
				{ "Winnie-the-Pooh", "🧸", "b" },
				{ "Tigger", "🐅", "b" },
				{ "Mad Hatter", "🎩", "s" },
				{ "Cheshire Cat", "😸", "m" },
				{ "Tinker Bell", "🧚", "m" },
			},
			Legendary = {
				{ "Alice", "👧", "s" },
				{ "Dorothy", "🌪️", "s" },
				{ "Peter Pan", "🍃", "w" },
			},
			Mythic = {
				{ "Queen of Hearts", "♥️", "m" },
				{ "Captain Hook", "🪝", "w" },
			},
			Secret = {
				{ "The Wizard of Oz", "💚", "m" },
			},
		},
	},
	{
		id = "seas",
		code = "HSE",
		name = "High Seas",
		icon = "🏴‍☠️",
		color = Color3.fromRGB(60, 130, 215),
		sources = "Treasure Island, Moby-Dick, Twenty Thousand Leagues Under the Seas, Robinson Crusoe, Sinbad, sea folklore",
		mult = 4,
		packCost = 5000,
		cards = {
			Common = {
				{ "Cabin Boy", "🧒", "w" },
				{ "Deck Swabber", "🧹", "w" },
				{ "Ship's Cook", "🍲", "s" },
				{ "Lookout", "🔭", "w" },
				{ "Powder Monkey", "💣", "t" },
				{ "Ship's Cat", "🐈", "b" },
				{ "Parrot", "🦜", "b" },
				{ "Mutineer", "🗡️", "w" },
				{ "Island Goat", "🐐", "b" },
				{ "Rum Barrel", "🛢️", "s" },
				{ "Treasure Map", "🗺️", "s" },
				{ "Harpooner", "🔱", "w" },
			},
			Uncommon = {
				{ "Blind Pew", "🕶️", "m" },
				{ "Black Dog", "🐕‍🦺", "w" },
				{ "Israel Hands", "✋", "w" },
				{ "Ben Gunn", "🧀", "s" },
				{ "Squire Trelawney", "🎩", "s" },
				{ "Dr. Livesey", "⚕️", "m" },
				{ "Friday", "👣", "w" },
				{ "Queequeg", "🪶", "w" },
			},
			Rare = {
				{ "Jim Hawkins", "🧭", "w" },
				{ "Billy Bones", "🦴", "w" },
				{ "Captain Smollett", "⚓", "w" },
				{ "Robinson Crusoe", "🏝️", "w" },
				{ "Ishmael", "📜", "s" },
				{ "Sinbad the Sailor", "⛵", "s" },
			},
			Epic = {
				{ "Long John Silver", "🦿", "w" },
				{ "Captain Flint", "💀", "w" },
				{ "Captain Ahab", "⚡", "w" },
				{ "Captain Nemo", "🤿", "t" },
				{ "The Roc", "🦅", "b" },
			},
			Legendary = {
				{ "Moby Dick", "🐋", "b" },
				{ "The Nautilus", "🚢", "t" },
				{ "The Kraken", "🐙", "b" },
			},
			Mythic = {
				{ "Davy Jones", "⚰️", "m" },
				{ "The Flying Dutchman", "👻", "m" },
			},
			Secret = {
				{ "Flint's Treasure", "💎", "s" },
			},
		},
	},
	{
		id = "west",
		code = "JTW",
		name = "Journey to the West",
		icon = "🐒",
		color = Color3.fromRGB(225, 75, 65),
		sources = "Journey to the West (16th-century Chinese novel)",
		mult = 16,
		packCost = 250000,
		cards = {
			Common = {
				{ "Mountain Monkey", "🐵", "b" },
				{ "Peach of Immortality", "🍑", "m" },
				{ "Cloud Spirit", "☁️", "m" },
				{ "Little Demon Scout", "👿", "b" },
				{ "Heavenly Horse", "🐎", "b" },
				{ "Temple Novice", "🧹", "s" },
				{ "River Fish Demon", "🐟", "b" },
				{ "Village Elder", "👴", "s" },
				{ "Shrimp Soldier", "🦐", "b" },
				{ "Crab General", "🦀", "b" },
				{ "Earth Spirit", "🌱", "m" },
				{ "Lantern Bearer", "🏮", "s" },
			},
			Uncommon = {
				{ "White Dragon Horse", "🐴", "b" },
				{ "Gold Horned King", "🥇", "m" },
				{ "Silver Horned King", "🥈", "m" },
				{ "Spider Demon", "🕷️", "b" },
				{ "Yellow Wind Demon", "🌪️", "m" },
				{ "Black Bear Spirit", "🐻", "b" },
				{ "Scorpion Demon", "🦂", "b" },
				{ "Jade Rabbit", "🐇", "b" },
			},
			Rare = {
				{ "Sha Wujing", "🏜️", "w" },
				{ "Zhu Bajie", "🐷", "w" },
				{ "Tang Sanzang", "📿", "m" },
				{ "Red Boy", "🔥", "m" },
				{ "Princess Iron Fan", "🪭", "m" },
				{ "White Bone Demon", "🦴", "m" },
			},
			Epic = {
				{ "Nezha", "🛞", "w" },
				{ "Erlang Shen", "👁️", "w" },
				{ "Bull Demon King", "🐂", "b" },
				{ "Dragon King of the East Sea", "🐉", "b" },
				{ "Six-Eared Macaque", "🙉", "b" },
			},
			Legendary = {
				{ "Sun Wukong", "🐒", "w" },
				{ "Great Sage Equal to Heaven", "🌩️", "w" },
				{ "Jade Emperor", "🏯", "m" },
			},
			Mythic = {
				{ "Wukong of 72 Transformations", "🌀", "m" },
				{ "Golden-Winged Great Peng", "🦅", "b" },
			},
			Secret = {
				{ "The Stone Egg", "🥚", "m" },
			},
		},
	},
	{
		id = "midnight",
		code = "MNC",
		name = "Midnight Classics",
		icon = "🦇",
		color = Color3.fromRGB(130, 80, 200),
		sources = "Dracula, Frankenstein, Sherlock Holmes, Jekyll and Hyde, The Invisible Man, Carmilla, The Phantom of the Opera, Sleepy Hollow, Poe",
		mult = 64,
		packCost = 5000000,
		cards = {
			Common = {
				{ "Village Bat", "🦇", "b" },
				{ "Graveyard Raven", "🐦‍⬛", "b" },
				{ "Lamplighter", "🏮", "s" },
				{ "Fog Bank", "🌫️", "m" },
				{ "Castle Rat", "🐀", "b" },
				{ "Gravedigger", "⚰️", "w" },
				{ "Baker Street Urchin", "🧒", "s" },
				{ "Coachman", "🐎", "w" },
				{ "Laboratory Assistant", "🧪", "t" },
				{ "Black Cat", "🐈‍⬛", "b" },
				{ "Tell-Tale Heart", "🫀", "m" },
				{ "Jack-o'-Lantern", "🎃", "m" },
			},
			Uncommon = {
				{ "Renfield", "🪰", "m" },
				{ "Mina Harker", "✒️", "s" },
				{ "Jonathan Harker", "📓", "w" },
				{ "Inspector Lestrade", "🚨", "w" },
				{ "Mrs. Hudson", "🫖", "s" },
				{ "Ichabod Crane", "📚", "s" },
				{ "Dr. Jekyll", "⚗️", "t" },
				{ "The Raven", "🪶", "m" },
			},
			Rare = {
				{ "Dr. Watson", "🩺", "w" },
				{ "Van Helsing", "🧄", "w" },
				{ "Mr. Hyde", "👹", "b" },
				{ "The Invisible Man", "🕶️", "t" },
				{ "Carmilla", "🌹", "m" },
				{ "Irene Adler", "🎭", "s" },
			},
			Epic = {
				{ "Sherlock Holmes", "🔎", "s" },
				{ "Professor Moriarty", "🕸️", "m" },
				{ "The Headless Horseman", "🏇", "w" },
				{ "The Phantom of the Opera", "🎹", "s" },
				{ "The Hound of the Baskervilles", "🐕", "b" },
			},
			Legendary = {
				{ "Count Dracula", "🧛", "m" },
				{ "Frankenstein's Creature", "⚡", "t" },
				{ "Victor Frankenstein", "🔬", "t" },
			},
			Mythic = {
				{ "The Grim Reaper", "💀", "m" },
				{ "The Red Death", "🩸", "m" },
			},
			Secret = {
				{ "Nevermore", "🌑", "m" },
			},
		},
	},
	{
		id = "olympus",
		code = "OLY",
		name = "Olympus",
		icon = "⚡",
		color = Color3.fromRGB(60, 190, 170),
		sources = "Greek mythology (Homer, Hesiod, Ovid)",
		mult = 256,
		packCost = 60000000,
		cards = {
			Common = {
				{ "Olive Farmer", "🫒", "s" },
				{ "Temple Dove", "🕊️", "b" },
				{ "Satyr Piper", "🎶", "s" },
				{ "Wood Nymph", "🌳", "m" },
				{ "Hoplite Recruit", "🛡️", "w" },
				{ "Shepherd Boy", "🐑", "s" },
				{ "Oracle's Attendant", "🏺", "m" },
				{ "River Naiad", "💧", "m" },
				{ "Chariot Racer", "🏇", "w" },
				{ "Lyre Student", "🎼", "s" },
				{ "Harpy", "🪶", "b" },
				{ "Bronze Automaton", "⚙️", "t" },
			},
			Uncommon = {
				{ "Pegasus", "🐎", "b" },
				{ "Centaur Archer", "🏹", "w" },
				{ "Cyclops Smith", "👁️", "t" },
				{ "Siren", "🧜", "s" },
				{ "Pandora", "📦", "m" },
				{ "Icarus", "🪽", "t" },
				{ "Daedalus", "📐", "t" },
				{ "King Midas", "👑", "s" },
			},
			Rare = {
				{ "Medusa", "🐍", "m" },
				{ "Minotaur", "🐂", "b" },
				{ "Perseus", "🗡️", "w" },
				{ "Atalanta", "🍎", "w" },
				{ "Orpheus", "🎻", "s" },
				{ "Cerberus", "🐕", "b" },
			},
			Epic = {
				{ "Hercules", "💪", "w" },
				{ "Achilles", "🦶", "w" },
				{ "Odysseus", "⛵", "w" },
				{ "Athena", "🦉", "m" },
				{ "Hermes", "👟", "s" },
			},
			Legendary = {
				{ "Poseidon", "🔱", "m" },
				{ "Hades", "💀", "m" },
				{ "Apollo", "☀️", "s" },
			},
			Mythic = {
				{ "Zeus", "⚡", "m" },
				{ "Typhon", "🌪️", "b" },
			},
			Secret = {
				{ "Primordial Chaos", "🌌", "m" },
			},
		},
	},
	{
		id = "knights",
		code = "KNO",
		name = "Knights and Outlaws",
		icon = "🏰",
		color = Color3.fromRGB(50, 150, 90),
		sources = "Arthurian legend (Le Morte d'Arthur) and the Robin Hood ballads",
		mult = 1024,
		packCost = 750000000,
		cards = {
			Common = {
				{ "Stable Boy", "🐴", "w" },
				{ "Castle Cook", "🍖", "s" },
				{ "Squire", "🛡️", "w" },
				{ "Court Jester", "🃏", "s" },
				{ "Village Blacksmith", "🔨", "t" },
				{ "Forest Deer", "🦌", "b" },
				{ "Herald", "📯", "s" },
				{ "Castle Guard", "💂", "w" },
				{ "Falconer's Hawk", "🦅", "b" },
				{ "Minstrel", "🪕", "s" },
				{ "Sherwood Archer", "🏹", "w" },
				{ "Tax Collector", "💰", "t" },
			},
			Uncommon = {
				{ "Friar Tuck", "🍺", "s" },
				{ "Little John", "🪵", "w" },
				{ "Will Scarlet", "🧣", "w" },
				{ "Maid Marian", "🌼", "s" },
				{ "Sir Kay", "🍽️", "w" },
				{ "Sir Bedivere", "🤝", "w" },
				{ "Much the Miller's Son", "🌾", "s" },
				{ "Alan-a-Dale", "🎵", "s" },
			},
			Rare = {
				{ "Robin Hood", "🎯", "w" },
				{ "Sir Gawain", "🌿", "w" },
				{ "Sir Percival", "🏆", "w" },
				{ "Sheriff of Nottingham", "⚖️", "t" },
				{ "The Green Knight", "🪓", "m" },
				{ "Sir Tristan", "💔", "s" },
			},
			Epic = {
				{ "Sir Lancelot", "⚔️", "w" },
				{ "Sir Galahad", "🕊️", "w" },
				{ "Queen Guinevere", "👸", "s" },
				{ "Morgan le Fay", "🔮", "m" },
				{ "Mordred", "🗡️", "w" },
			},
			Legendary = {
				{ "King Arthur", "👑", "w" },
				{ "Merlin", "🧙", "m" },
				{ "Lady of the Lake", "🌊", "m" },
			},
			Mythic = {
				{ "Excalibur", "✨", "t" },
				{ "The Questing Beast", "🐉", "b" },
			},
			Secret = {
				{ "The Grail", "🍷", "m" },
			},
		},
	},
	{
		id = "rome",
		code = "ROM",
		name = "Glory of Rome",
		icon = "🏛️",
		color = Color3.fromRGB(170, 35, 45),
		sources = "Ancient Roman history and legend (Livy, Plutarch, Suetonius)",
		mult = 4096,
		packCost = 10000000000,
		cards = {
			Common = {
				{ "Legionary Recruit", "🛡️", "w" },
				{ "Aqueduct Builder", "🧱", "t" },
				{ "Forum Merchant", "🏺", "s" },
				{ "Chariot Horse", "🐎", "b" },
				{ "Olive Seller", "🫒", "s" },
				{ "Bathhouse Keeper", "🛁", "s" },
				{ "Road Surveyor", "📏", "t" },
				{ "Capitoline Goose", "🪿", "b" },
				{ "Scroll Scribe", "📜", "m" },
				{ "Colosseum Fan", "🎟️", "s" },
				{ "Vineyard Farmer", "🍇", "s" },
				{ "Standard Bearer", "🚩", "w" },
			},
			Uncommon = {
				{ "Centurion", "⚔️", "w" },
				{ "Gladiator", "🗡️", "w" },
				{ "Charioteer", "🏇", "w" },
				{ "Vestal Flame Keeper", "🔥", "m" },
				{ "Senator", "🏛️", "s" },
				{ "War Elephant", "🐘", "b" },
				{ "Roman Engineer", "⚙️", "t" },
				{ "Praetorian Guard", "💂", "w" },
			},
			Rare = {
				{ "Spartacus", "⛓️", "w" },
				{ "Cicero", "🗣️", "s" },
				{ "Virgil", "✒️", "m" },
				{ "Boudica", "🐴", "w" },
				{ "Vitruvius", "📐", "t" },
				{ "Livia", "👑", "s" },
			},
			Epic = {
				{ "Mark Antony", "🍷", "w" },
				{ "Cleopatra", "🐍", "m" },
				{ "Scipio Africanus", "🏹", "w" },
				{ "Hannibal", "🏔️", "w" },
				{ "Marcus Aurelius", "📖", "m" },
			},
			Legendary = {
				{ "Julius Caesar", "🌿", "w" },
				{ "Augustus", "🦅", "s" },
				{ "Trajan", "🗿", "w" },
			},
			Mythic = {
				{ "Romulus and Remus", "🐺", "b" },
				{ "Hadrian the Builder", "🏰", "t" },
			},
			Secret = {
				{ "The Eternal City", "🌇", "m" },
			},
		},
	},
	{
		-- American folklore first: tall tales, legends and fearsome critters, all from stories
		-- told or printed before 1929. The few real people all died about a century ago or
		-- more (the latest is Annie Oakley, 1926): nobody living, recent, or in office in
		-- living memory.
		id = "america",
		code = "PAX",
		name = "Pax Americana",
		icon = "🦅",
		color = Color3.fromRGB(45, 80, 165),
		sources = "American folklore and early history: the Paul Bunyan and Pecos Bill tall tales, the ballads of John Henry and Casey Jones, Washington Irving's Rip Van Winkle, frontier legends and fearsome critters",
		mult = 16384,
		packCost = 125000000000,
		cards = {
			Common = {
				{ "Minuteman", "🎖️", "w" },
				{ "Frontier Trapper", "🦫", "b" },
				{ "Prairie Bison", "🦬", "b" },
				{ "Bald Eagle", "🦅", "b" },
				{ "Wild Mustang", "🐎", "b" },
				{ "Covered Wagon", "🛞", "t" },
				{ "Railroad Worker", "🛤️", "t" },
				{ "Gold Prospector", "⛏️", "s" },
				{ "Riverboat Pilot", "🚢", "t" },
				{ "Liberty Bell", "🔔", "m" },
				{ "Jackalope", "🐇", "b" },
				{ "Yankee Doodle", "🪶", "s" },
			},
			Uncommon = {
				{ "Paul Revere", "🏇", "w" },
				{ "Betsy Ross", "🧵", "s" },
				{ "Johnny Appleseed", "🍏", "s" },
				{ "Davy Crockett", "🦝", "w" },
				{ "Daniel Boone", "🌲", "w" },
				{ "Rip Van Winkle", "💤", "m" },
				{ "Casey Jones", "🚂", "t" },
				{ "Molly Pitcher", "🪣", "w" },
			},
			Rare = {
				{ "Annie Oakley", "🎯", "w" },
				{ "Pecos Bill", "🌪️", "w" },
				{ "Mike Fink", "🛶", "w" },
				{ "Old Stormalong", "⚓", "t" },
				{ "Jersey Devil", "🦇", "b" },
				{ "Sasquatch", "👣", "b" },
			},
			Epic = {
				{ "John Henry", "🔨", "w" },
				{ "Babe the Blue Ox", "🐂", "b" },
				{ "Benjamin Franklin", "🪁", "t" },
				{ "Sitting Bull", "🌄", "w" },
				{ "Harriet Tubman", "🌟", "s" },
			},
			Legendary = {
				{ "George Washington", "🚣", "w" },
				{ "Abraham Lincoln", "🎩", "s" },
				{ "Geronimo", "⛰️", "w" },
			},
			Mythic = {
				{ "Paul Bunyan", "🪓", "w" },
				{ "Lady Liberty", "🗽", "m" },
			},
			Secret = {
				{ "Uncle Sam", "🎆", "s" },
			},
		},
	},
	{
		-- The endgame set: it unlocks with the last rebirth. Based on the medieval Eddas and
		-- sagas, not on any modern comic, film or game version of these gods.
		id = "norse",
		code = "NRS",
		name = "Norse Sagas",
		icon = "🪓",
		color = Color3.fromRGB(70, 130, 150),
		sources = "The Poetic Edda and Snorri Sturluson's Prose Edda (13th century), and the Icelandic sagas",
		mult = 65536,
		packCost = 1500000000000,
		cards = {
			Common = {
				{ "Viking Raider", "🪓", "w" },
				{ "Shield Maiden", "🛡️", "w" },
				{ "Longship", "⛵", "t" },
				{ "Rune Carver", "🪨", "m" },
				{ "Skald", "🎵", "s" },
				{ "Mead Brewer", "🍯", "s" },
				{ "Fjord Fisher", "🎣", "s" },
				{ "Reindeer", "🦌", "b" },
				{ "Northern Wolf", "🐺", "b" },
				{ "Sword Forger", "⚒️", "t" },
				{ "Frost Sprite", "❄️", "m" },
				{ "Jarl's Hound", "🐕", "b" },
			},
			Uncommon = {
				{ "Valkyrie", "🪽", "w" },
				{ "Berserker", "🐻", "w" },
				{ "Dwarf Smith", "💍", "t" },
				{ "Light Elf", "✨", "m" },
				{ "Frost Giant", "🧊", "w" },
				{ "Fire Giant", "🔥", "w" },
				{ "The Norns", "🕸️", "m" },
				{ "Huginn and Muninn", "🐦", "b" },
			},
			Rare = {
				{ "Heimdall", "📯", "w" },
				{ "Tyr", "✋", "w" },
				{ "Baldur", "☀️", "s" },
				{ "Sif", "🌾", "s" },
				{ "Sleipnir", "🐴", "b" },
				{ "Ratatoskr", "🐿️", "b" },
			},
			Epic = {
				{ "Freya", "🐈", "m" },
				{ "Loki", "🦊", "s" },
				{ "Fenrir", "🌕", "b" },
				{ "Jormungandr", "🐍", "b" },
				{ "Hel", "💀", "m" },
			},
			Legendary = {
				{ "Thor", "⚡", "w" },
				{ "Odin", "🧙", "m" },
				{ "Surtr", "🌋", "w" },
			},
			Mythic = {
				{ "Yggdrasil", "🌳", "m" },
				{ "Bifrost", "🌈", "t" },
			},
			Secret = {
				{ "Ragnarok", "🌑", "s" },
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
		promo = setData.promo == true,
		icon = setData.icon,
		color = setData.color,
		sources = setData.sources,
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
			if not set.promo then
				table.insert(Cards.ByRarity[rarityName], def) -- the pool packs pull from
			end
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

-- The next step when fusing (normal -> Shiny -> Golden -> Prismatic), or nil if the effect
-- cannot be fused further.
function Cards.nextVariant(variantId)
	for index, id in ipairs(Cards.FuseOrder) do
		if id == variantId then
			return Cards.FuseOrder[index + 1]
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
	return Cards.Rarities[def.rarity].aura * (variant.auraMult or variant.mult) + (variant.auraFlat or 0)
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
