-- Deck combos. The cards in your active deck earn cash on their own, and the right mix of
-- cards adds bonuses on top:
--   * Type combos   — several cards of one type (Warrior, Beast, ...)
--   * Set combos    — several cards from one set
--   * Effect combos — several cards with the same effect (Slimy, Shadow, ...)
--   * Story combos  — specific characters together (Pooh + Piglet + Eeyore + Tigger)
--   * Per-card effect bonuses (every Slimy card: +2% deck cash, every Lucky card: +0.5 luck)
-- Bonuses are income (cash), aura, or luck levels. All income bonuses add together.
local Cards = require(script.Parent.Cards)

local Combos = {}

-- { cards needed, income bonus }. The highest tier reached applies, per type / per set.
Combos.TypeTiers = { { 3, 0.1 }, { 6, 0.25 }, { 10, 0.45 }, { 16, 0.7 }, { 24, 1 } }
Combos.SetTiers = { { 4, 0.1 }, { 8, 0.25 }, { 16, 0.5 }, { 32, 1 } }

-- Having `count` cards with the same effect in the deck.
Combos.EffectCombos = {
	holo = { name = "Shiny Showcase", count = 5, income = 0.15 },
	slimy = { name = "Slime Pile", count = 3, income = 0.1 },
	lucky = { name = "Four-Leaf Clover", count = 3, luck = 2 },
	shadow = { name = "Shadow Court", count = 3, aura = 0.25 },
	gold = { name = "Gold Rush", count = 3, income = 0.25 },
	fullart = { name = "Art Gallery", count = 2, aura = 0.5 },
	prism = { name = "Double Rainbow", count = 2, income = 0.5 },
}

-- Specific cards together (any effect counts). cards = card ids.
Combos.Stories = {
	{ name = "Hundred Acre Friends", cards = { "winnie_the_pooh", "piglet", "eeyore", "tigger" }, income = 0.4 },
	{ name = "Mad Tea Party", cards = { "mad_hatter", "march_hare", "dormouse" }, luck = 2 },
	{ name = "Yellow Brick Road", cards = { "dorothy", "scarecrow", "tin_woodman", "cowardly_lion", "toto" }, income = 0.5 },
	{ name = "Neverland", cards = { "peter_pan", "tinker_bell", "captain_hook", "smee", "lost_boy" }, aura = 0.5 },
	{ name = "Hispaniola Crew", cards = { "jim_hawkins", "long_john_silver", "captain_smollett", "dr_livesey", "squire_trelawney" }, income = 0.5 },
	{ name = "The White Whale", cards = { "captain_ahab", "ishmael", "queequeg", "moby_dick" }, aura = 0.5 },
	{ name = "Twenty Thousand Leagues", cards = { "captain_nemo", "the_nautilus", "the_kraken" }, income = 0.4 },
	{ name = "The Pilgrims", cards = { "sun_wukong", "zhu_bajie", "sha_wujing", "tang_sanzang", "white_dragon_horse" }, income = 0.75 },
	{ name = "Flaming Mountain", cards = { "bull_demon_king", "princess_iron_fan", "red_boy" }, luck = 3 },
	{ name = "Havoc in Heaven", cards = { "great_sage_equal_to_heaven", "nezha", "erlang_shen", "jade_emperor" }, aura = 0.75 },
	{ name = "221B Baker Street", cards = { "sherlock_holmes", "dr_watson", "mrs_hudson", "inspector_lestrade" }, luck = 3 },
	{ name = "Vampire Hunters", cards = { "van_helsing", "mina_harker", "jonathan_harker", "count_dracula" }, income = 0.75 },
	{ name = "It's Alive!", cards = { "victor_frankenstein", "frankenstein_s_creature", "laboratory_assistant" }, aura = 0.75 },
	{ name = "Two Faces", cards = { "dr_jekyll", "mr_hyde" }, income = 0.3 },
	{ name = "The Labyrinth", cards = { "minotaur", "daedalus", "icarus" }, luck = 3 },
	{ name = "Heroes of Legend", cards = { "hercules", "achilles", "odysseus", "perseus" }, aura = 1 },
	{ name = "The Olympians", cards = { "zeus", "poseidon", "hades", "athena", "apollo", "hermes" }, income = 1 },
	{ name = "Merry Men", cards = { "robin_hood", "little_john", "friar_tuck", "will_scarlet", "maid_marian" }, income = 0.75 },
	{ name = "The Round Table", cards = { "king_arthur", "sir_lancelot", "sir_galahad", "sir_gawain", "sir_percival" }, aura = 1 },
	{ name = "Sword in the Stone", cards = { "king_arthur", "merlin", "excalibur" }, luck = 4 },
	{ name = "Bread and Circuses", cards = { "gladiator", "charioteer", "colosseum_fan" }, luck = 3 },
	{ name = "Antony and Cleopatra", cards = { "mark_antony", "cleopatra" }, income = 0.5 },
	{ name = "The Punic Wars", cards = { "scipio_africanus", "hannibal", "war_elephant" }, aura = 1 },
	{ name = "The Emperors", cards = { "augustus", "trajan", "hadrian_the_builder", "marcus_aurelius" }, income = 1 },
	{ name = "Founding of Rome", cards = { "romulus_and_remus", "capitoline_goose", "the_eternal_city" }, luck = 5 },
}

for _, story in ipairs(Combos.Stories) do
	for _, id in ipairs(story.cards) do
		assert(Cards.ById[id], "story combo " .. story.name .. " uses unknown card " .. id)
	end
end

local function tierBonus(tiers, count)
	local bonus, reached = 0, 0
	for _, tier in ipairs(tiers) do
		if count >= tier[1] then
			bonus, reached = tier[2], tier[1]
		end
	end
	return bonus, reached
end

local function percent(value)
	return math.floor(value * 100 + 0.5) .. "%"
end

-- "+40% cash", "+50% aura", "+2 luck"
local function bonusText(bonus)
	if bonus.income then
		return "+" .. percent(bonus.income) .. " cash"
	elseif bonus.aura then
		return "+" .. percent(bonus.aura) .. " aura"
	end
	return "+" .. bonus.luck .. " luck"
end
Combos.bonusText = bonusText

-- slots = { [tostring(slotIndex)] = cardKey } (the active deck).
-- Returns {
--   income = cash multiplier, aura = aura multiplier, luck = bonus luck levels,
--   active = { { name, text }, ... },                 combos currently switched on
--   progress = { { name, have, need, text }, ... },   story combos partly collected
-- }
function Combos.evaluate(slots)
	local typeCounts, setCounts, effectCounts, present = {}, {}, {}, {}
	local income, aura, luck = 0, 0, 0
	local active = {}

	local function apply(name, bonus)
		income = income + (bonus.income or 0)
		aura = aura + (bonus.aura or 0)
		luck = luck + (bonus.luck or 0)
		table.insert(active, { name = name, text = bonusText(bonus) })
	end

	local effectIncome, effectLuck = 0, 0
	for _, key in pairs(slots) do
		local def, variantId, variant = Cards.parse(key)
		if def then
			typeCounts[def.type] = (typeCounts[def.type] or 0) + 1
			setCounts[def.set] = (setCounts[def.set] or 0) + 1
			effectCounts[variantId] = (effectCounts[variantId] or 0) + 1
			present[def.id] = true
			effectIncome = effectIncome + (variant.deckIncome or 0)
			effectLuck = effectLuck + (variant.deckLuck or 0)
		end
	end

	for _, typeId in ipairs(Cards.TypeOrder) do
		local bonus, reached = tierBonus(Combos.TypeTiers, typeCounts[typeId] or 0)
		if bonus > 0 then
			local info = Cards.Types[typeId]
			apply(info.icon .. " " .. reached .. " " .. info.name .. " cards", { income = bonus })
		end
	end

	for _, setId in ipairs(Cards.SetOrder) do
		local bonus, reached = tierBonus(Combos.SetTiers, setCounts[setId] or 0)
		if bonus > 0 then
			local set = Cards.Sets[setId]
			apply(set.icon .. " " .. reached .. " " .. set.name .. " cards", { income = bonus })
		end
	end

	for _, variantId in ipairs(Cards.VariantOrder) do
		local combo = Combos.EffectCombos[variantId]
		if combo and (effectCounts[variantId] or 0) >= combo.count then
			apply(combo.name .. " (" .. combo.count .. " " .. Cards.Variants[variantId].name .. ")", combo)
		end
	end

	local progress = {}
	for _, story in ipairs(Combos.Stories) do
		local have = 0
		for _, id in ipairs(story.cards) do
			if present[id] then
				have = have + 1
			end
		end
		if have >= #story.cards then
			apply("📖 " .. story.name, story)
		elseif have > 0 then
			table.insert(progress, { name = story.name, have = have, need = #story.cards, text = bonusText(story) })
		end
	end
	table.sort(progress, function(a, b)
		local leftA, leftB = a.need - a.have, b.need - b.have
		if leftA ~= leftB then
			return leftA < leftB
		end
		return a.name < b.name
	end)

	if effectIncome > 0 then
		income = income + effectIncome
		table.insert(active, { name = "Card effects in deck", text = "+" .. percent(effectIncome) .. " cash" })
	end
	if effectLuck > 0 then
		luck = luck + effectLuck
		table.insert(active, { name = "Card effects in deck", text = "+" .. effectLuck .. " luck" })
	end

	return { income = 1 + income, aura = 1 + aura, luck = luck, active = active, progress = progress }
end

return Combos
