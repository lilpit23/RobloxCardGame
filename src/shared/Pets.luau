-- Pets: a late-game companion system. Eggs are bought with aura and hatch one random pet;
-- equipped pets add to your cash income and your aura. Eggs open with rebirths (the first
-- after the sixth), and pets are kept through rebirths. Pets are their own creatures (no
-- set or story), can't be traded, and float beside their owner's character.
-- "owned" below is the saved table { [petId] = count }; "equipped" is an array of pet ids.
local Pets = {}

Pets.UnlockRebirths = 6 -- the first egg opens here

-- How many pets can be equipped at once.
function Pets.slots(rebirths)
	return (rebirths or 0) >= 8 and 4 or 3
end

-- bonus = what one pet of this rarity adds to cash and aura income (before the egg's scale)
Pets.Rarities = {
	Common = { order = 1, bonus = 0.05, color = Color3.fromRGB(190, 190, 190) },
	Rare = { order = 2, bonus = 0.1, color = Color3.fromRGB(80, 160, 255) },
	Epic = { order = 3, bonus = 0.18, color = Color3.fromRGB(180, 90, 255) },
	Legendary = { order = 4, bonus = 0.3, color = Color3.fromRGB(255, 190, 40) },
	Mythic = { order = 5, bonus = 0.45, color = Color3.fromRGB(255, 80, 120) },
}

-- Each egg: the rebirths it needs, its aura price, how much stronger its pets are (scale),
-- and its pets as { id, name, glyph, rarity, weight }.
Pets.Eggs = {
	{
		id = "ember",
		name = "Ember Egg",
		glyph = "🥚",
		color = Color3.fromRGB(255, 120, 60),
		rebirths = 6,
		cost = 1000000,
		scale = 1,
		pets = {
			{ "ember_pup", "Ember Pup", "🐶", "Common", 50 },
			{ "cinder_cat", "Cinder Cat", "🐱", "Rare", 30 },
			{ "blaze_fox", "Blaze Fox", "🦊", "Epic", 14 },
			{ "magma_lizard", "Magma Lizard", "🦎", "Legendary", 5 },
			{ "sunfire_bird", "Sunfire Bird", "🐦", "Mythic", 1 },
		},
	},
	{
		id = "frost",
		name = "Frost Egg",
		glyph = "🥚",
		color = Color3.fromRGB(120, 200, 255),
		rebirths = 7,
		cost = 4000000,
		scale = 1.6,
		pets = {
			{ "snow_bunny", "Snow Bunny", "🐰", "Common", 50 },
			{ "ice_penguin", "Ice Penguin", "🐧", "Rare", 30 },
			{ "glacier_bear", "Glacier Bear", "🐻", "Epic", 14 },
			{ "aurora_owl", "Aurora Owl", "🦉", "Legendary", 5 },
			{ "frost_drake", "Frost Drake", "🐉", "Mythic", 1 },
		},
	},
	{
		id = "star",
		name = "Starlight Egg",
		glyph = "🥚",
		color = Color3.fromRGB(255, 220, 120),
		rebirths = 8,
		cost = 15000000,
		scale = 2.5,
		pets = {
			{ "moon_moth", "Moon Moth", "🦋", "Common", 50 },
			{ "comet_turtle", "Comet Turtle", "🐢", "Rare", 30 },
			{ "nebula_squid", "Nebula Squid", "🦑", "Epic", 14 },
			{ "sun_lion", "Sun Lion", "🦁", "Legendary", 5 },
			{ "galaxy_whale", "Galaxy Whale", "🐋", "Mythic", 1 },
		},
	},
}

Pets.ById = {} -- [petId] = { id, name, glyph, rarity, weight, egg, bonus }
Pets.EggById = {}
Pets.Order = {} -- every pet, egg by egg
for _, egg in ipairs(Pets.Eggs) do
	Pets.EggById[egg.id] = egg
	local total = 0
	for _, row in ipairs(egg.pets) do
		total = total + row[5]
	end
	egg.totalWeight = total
	for _, row in ipairs(egg.pets) do
		local pet = {
			id = row[1],
			name = row[2],
			glyph = row[3],
			rarity = row[4],
			weight = row[5],
			chance = row[5] / total,
			egg = egg.id,
			bonus = Pets.Rarities[row[4]].bonus * egg.scale,
		}
		assert(Pets.ById[pet.id] == nil, "duplicate pet id " .. pet.id)
		Pets.ById[pet.id] = pet
		table.insert(Pets.Order, pet)
	end
end

-- Golden pets: fuse Pets.GoldenCost copies of a pet into its golden version, which gives
-- Pets.GoldenMult times the bonus. Eggs never hatch golden pets.
Pets.GoldenCost = 5
Pets.GoldenMult = 2.5
for _, pet in ipairs(table.clone(Pets.Order)) do
	local golden = {
		id = pet.id .. "_golden",
		name = "Golden " .. pet.name,
		glyph = pet.glyph,
		rarity = pet.rarity,
		weight = 0,
		chance = 0,
		egg = pet.egg,
		bonus = pet.bonus * Pets.GoldenMult,
		golden = true,
		base = pet.id,
	}
	pet.goldenId = golden.id
	Pets.ById[golden.id] = golden
	table.insert(Pets.Order, golden)
end

function Pets.eggUnlocked(egg, rebirths)
	return (rebirths or 0) >= egg.rebirths
end

-- Hatch one pet from an egg. rng is a Random object. Returns the pet id.
function Pets.roll(egg, rng)
	local pick = rng:NextNumber() * egg.totalWeight
	for _, row in ipairs(egg.pets) do
		pick = pick - row[5]
		if pick < 0 then
			return row[1]
		end
	end
	return egg.pets[#egg.pets][1]
end

-- The income multipliers the equipped pets give: { cash = 1.x, aura = 1.x }.
function Pets.bonus(equipped)
	local total = 0
	for _, petId in ipairs(equipped or {}) do
		local pet = Pets.ById[petId]
		if pet then
			total = total + pet.bonus
		end
	end
	return { cash = 1 + total, aura = 1 + total }
end

-- The strongest pets you own, up to `slots` of them (duplicates allowed if you own copies).
function Pets.best(owned, slots)
	local list = {}
	for petId, count in pairs(owned or {}) do
		local pet = Pets.ById[petId]
		if pet and type(count) == "number" then
			for _ = 1, math.min(count, slots) do
				table.insert(list, pet)
			end
		end
	end
	table.sort(list, function(a, b)
		if a.bonus ~= b.bonus then
			return a.bonus > b.bonus
		end
		return a.id < b.id
	end)
	local equipped = {}
	for index = 1, math.min(slots, #list) do
		equipped[index] = list[index].id
	end
	return equipped
end

-- Drops equipped pets the profile no longer owns (or has too few copies of) and trims to the
-- slot count. Returns a new array.
function Pets.clean(owned, equipped, slots)
	local used = {}
	local list = {}
	for _, petId in ipairs(equipped or {}) do
		if #list >= slots then
			break
		end
		local have = owned and owned[petId] or 0
		if Pets.ById[petId] and type(have) == "number" and (used[petId] or 0) < have then
			used[petId] = (used[petId] or 0) + 1
			table.insert(list, petId)
		end
	end
	return list
end

function Pets.percent(bonus)
	return "+" .. math.floor(bonus * 100 + 0.5) .. "%"
end

return Pets
