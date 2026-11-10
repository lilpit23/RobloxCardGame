-- Card database. Add a card by adding a row to Cards.List.
-- A "card key" identifies a card + variant: "akane" (normal) or "akane:gold".
local Cards = {}

Cards.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Cards.Rarities = {
	Common = { order = 1, color = Color3.fromRGB(140, 150, 165), aura = 0 },
	Uncommon = { order = 2, color = Color3.fromRGB(70, 185, 95), aura = 0 },
	Rare = { order = 3, color = Color3.fromRGB(55, 130, 235), aura = 0 },
	Epic = { order = 4, color = Color3.fromRGB(160, 75, 230), aura = 1 },
	Legendary = { order = 5, color = Color3.fromRGB(245, 170, 40), aura = 5 },
	Mythic = { order = 6, color = Color3.fromRGB(235, 55, 95), aura = 25 },
	Secret = { order = 7, color = Color3.fromRGB(35, 35, 45), aura = 150 },
}

-- Variants multiply income and aura. "chance" is rolled per card pulled.
Cards.VariantOrder = { "normal", "holo", "gold", "prism" }

Cards.Variants = {
	normal = { name = "", mult = 1, chance = 0, color = Color3.fromRGB(25, 25, 30) },
	holo = { name = "Holo", mult = 2, chance = 0.08, color = Color3.fromRGB(120, 235, 255) },
	gold = { name = "Gold", mult = 5, chance = 0.02, color = Color3.fromRGB(255, 205, 60) },
	prism = { name = "Prismatic", mult = 20, chance = 0.003, color = Color3.fromRGB(255, 255, 255) },
}

-- income = cash per second while on a display stand.
-- image (optional) = "rbxassetid://..." card art; the glyph is used when it is missing.
Cards.List = {
	{ id = "taro", name = "Rookie Ronin Taro", rarity = "Common", income = 1, glyph = "🗡️" },
	{ id = "miko", name = "Ramen Runner Miko", rarity = "Common", income = 1, glyph = "🍜" },
	{ id = "pip", name = "Slime Tamer Pip", rarity = "Common", income = 2, glyph = "🫧" },
	{ id = "jun", name = "Dojo Sweeper Jun", rarity = "Common", income = 2, glyph = "🧹" },
	{ id = "hana", name = "Paper Fan Hana", rarity = "Common", income = 3, glyph = "🪭" },
	{ id = "nyanko", name = "Cat Courier Nyanko", rarity = "Common", income = 3, glyph = "🐱" },

	{ id = "raizo", name = "Thunder Kid Raizo", rarity = "Uncommon", income = 6, glyph = "⚡" },
	{ id = "sora", name = "Blade Apprentice Sora", rarity = "Uncommon", income = 8, glyph = "⚔️" },
	{ id = "lune", name = "Moon Archer Lune", rarity = "Uncommon", income = 10, glyph = "🏹" },
	{ id = "bolt", name = "Mecha Mechanic Bolt", rarity = "Uncommon", income = 12, glyph = "🔧" },
	{ id = "kiri", name = "Spirit Fox Kiri", rarity = "Uncommon", income = 14, glyph = "🦊" },
	{ id = "nami", name = "Tidal Monk Nami", rarity = "Uncommon", income = 16, glyph = "🌊" },

	{ id = "akane", name = "Crimson Samurai Akane", rarity = "Rare", income = 40, glyph = "👹" },
	{ id = "kage", name = "Shadow Ninja Kage", rarity = "Rare", income = 50, glyph = "🥷" },
	{ id = "hoshi", name = "Star Idol Hoshi", rarity = "Rare", income = 60, glyph = "🎤" },
	{ id = "yuki", name = "Frost Witch Yuki", rarity = "Rare", income = 75, glyph = "❄️" },
	{ id = "gantz", name = "Iron Brawler Gantz", rarity = "Rare", income = 90, glyph = "🥊" },

	{ id = "ryuma", name = "Dragon Rider Ryuma", rarity = "Epic", income = 300, glyph = "🐲" },
	{ id = "noir", name = "Phantom Thief Noir", rarity = "Epic", income = 380, glyph = "🎭" },
	{ id = "raika", name = "Storm Empress Raika", rarity = "Epic", income = 460, glyph = "🌩️" },
	{ id = "zeta", name = "Cyber Oni Zeta", rarity = "Epic", income = 550, glyph = "🤖" },
	{ id = "ren", name = "Sakura Blademaster Ren", rarity = "Epic", income = 650, glyph = "🌸" },

	{ id = "hinode", name = "Solar Emperor Hinode", rarity = "Legendary", income = 2500, glyph = "☀️" },
	{ id = "kuro", name = "Void Reaper Kuro", rarity = "Legendary", income = 3200, glyph = "💀" },
	{ id = "tenryu", name = "Celestial Dragon Tenryu", rarity = "Legendary", income = 4000, glyph = "🐉" },
	{ id = "chrona", name = "Time Sage Chrona", rarity = "Legendary", income = 5000, glyph = "⏳" },

	{ id = "zenith", name = "Aura King Zenith", rarity = "Mythic", income = 20000, glyph = "👑" },
	{ id = "eclipse", name = "Eclipse Twins Yin & Yang", rarity = "Mythic", income = 28000, glyph = "☯️" },
	{ id = "gorath", name = "World Eater Gorath", rarity = "Mythic", income = 40000, glyph = "🌋" },

	{ id = "finalboss", name = "The Final Boss", rarity = "Secret", income = 250000, glyph = "👁️" },
	{ id = "sensei", name = "Dev-sensei", rarity = "Secret", income = 400000, glyph = "💻" },
}

Cards.ById = {}
Cards.ByRarity = {}
for _, rarityName in ipairs(Cards.RarityOrder) do
	Cards.ByRarity[rarityName] = {}
end
for index, def in ipairs(Cards.List) do
	def.index = index
	Cards.ById[def.id] = def
	table.insert(Cards.ByRarity[def.rarity], def)
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

function Cards.getSellValue(key, sellMultiplier)
	return Cards.getIncome(key) * sellMultiplier
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
