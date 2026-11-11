-- Aura Packs — main server script. All game rules live here; the client only asks.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cards = require(Shared:WaitForChild("Cards"))
local Packs = require(Shared:WaitForChild("Packs"))
local Upgrades = require(Shared:WaitForChild("Upgrades"))
local Format = require(Shared:WaitForChild("Format"))
local Rebirth = require(Shared:WaitForChild("Rebirth"))
local Quests = require(Shared:WaitForChild("Quests"))
local Perks = require(Shared:WaitForChild("Perks"))
local Combos = require(Shared:WaitForChild("Combos"))
local Luck = require(Shared:WaitForChild("Luck"))
local Deck = require(Shared:WaitForChild("Deck"))
local Season = require(Shared:WaitForChild("Season"))
local Achievements = require(Shared:WaitForChild("Achievements"))
local Battle = require(Shared:WaitForChild("Battle"))

local PlayerData = require(script:WaitForChild("PlayerData"))
local Plots = require(script:WaitForChild("Plots"))
local Monetization = require(script:WaitForChild("Monetization"))

local rng = Random.new()
local STARTER = Packs.ById[Packs.StarterId]

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local function newRemote(className, name)
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local StateRemote = newRemote("RemoteEvent", "State") -- server -> client
local NotifyRemote = newRemote("RemoteEvent", "Notify") -- server -> client
local OpenShopRemote = newRemote("RemoteEvent", "OpenShop") -- server -> client
local BuyPackRemote = newRemote("RemoteFunction", "BuyPack")
local PlaceCardRemote = newRemote("RemoteEvent", "PlaceCard")
local RemoveCardRemote = newRemote("RemoteEvent", "RemoveCard")
local SellCardRemote = newRemote("RemoteEvent", "SellCard")
local EquipBestRemote = newRemote("RemoteEvent", "EquipBest")
local BuyUpgradeRemote = newRemote("RemoteEvent", "BuyUpgrade")
local RequestStateRemote = newRemote("RemoteEvent", "RequestState")
local FuseCardRemote = newRemote("RemoteEvent", "FuseCard")
local FuseAllRemote = newRemote("RemoteEvent", "FuseAll")
local SellSparesRemote = newRemote("RemoteEvent", "SellSpares")
local AchievementClaimRemote = newRemote("RemoteEvent", "AchievementClaim")
local RebirthRemote = newRemote("RemoteEvent", "Rebirth")
local VaultStoreRemote = newRemote("RemoteEvent", "VaultStore")
local VaultTakeRemote = newRemote("RemoteEvent", "VaultTake")
local QuestClaimRemote = newRemote("RemoteEvent", "QuestClaim")
local DailyClaimRemote = newRemote("RemoteEvent", "DailyClaim")
local BuyPerkRemote = newRemote("RemoteEvent", "BuyPerk")
local BattleRemote = newRemote("RemoteFunction", "Battle")
local OpenTradeRemote = newRemote("RemoteEvent", "OpenTrade") -- server -> client
local OpenBattleRemote = newRemote("RemoteEvent", "OpenBattle") -- server -> client
local AnnounceRemote = newRemote("RemoteEvent", "Announce") -- server -> everyone
local OpenRebirthRemote = newRemote("RemoteEvent", "OpenRebirth") -- server -> client
local AutoPackSetRemote = newRemote("RemoteEvent", "AutoPackSet")
local AutoPullRemote = newRemote("RemoteEvent", "AutoPull") -- server -> client
local SetShowcaseRemote = newRemote("RemoteEvent", "SetShowcase")
local RedeemCodeRemote = newRemote("RemoteEvent", "RedeemCode")
local ResetDataRemote = newRemote("RemoteEvent", "ResetData")
local MarketStateRemote = newRemote("RemoteEvent", "MarketState") -- server -> client
local MarketListRemote = newRemote("RemoteEvent", "MarketList")
local MarketCancelRemote = newRemote("RemoteEvent", "MarketCancel")
local MarketBuyRemote = newRemote("RemoteEvent", "MarketBuy")
local TradeStateRemote = newRemote("RemoteEvent", "TradeState") -- server -> client
local TradeRequestRemote = newRemote("RemoteEvent", "TradeRequest") -- both directions
local TradeAcceptRemote = newRemote("RemoteEvent", "TradeAccept")
local TradeOfferRemote = newRemote("RemoteEvent", "TradeOffer")
local TradeConfirmRemote = newRemote("RemoteEvent", "TradeConfirm")
local TradeCancelRemote = newRemote("RemoteEvent", "TradeCancel")

remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- Session state (not saved)
---------------------------------------------------------------------
-- [player] = { plot, pending = uncollected cash at the register, rev, questRev, dirty, ... }
local sessions = {}

-- Token-bucket rate limit, per player and per remote. First line of every remote handler.
local buckets = {}

local function allow(player, key, ratePerSec, burst)
	local now = os.clock()
	local playerBuckets = buckets[player]
	if playerBuckets == nil then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[key]
	if bucket == nil then
		bucket = { tokens = burst, last = now }
		playerBuckets[key] = bucket
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.last) * ratePerSec)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens = bucket.tokens - 1
	return true
end

local function notify(player, text, kind)
	NotifyRemote:FireClient(player, text, kind or "info")
end

-- The game's creator (or anyone testing in Studio) gets a few testing tools.
local function isOwner(player)
	if RunService:IsStudio() then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

-- Game passes owned, looked up by profile: [data] = { [passKey] = true }.
local dataPasses = setmetatable({}, { __mode = "k" })

local function hasPass(data, passKey)
	local flags = dataPasses[data]
	return flags ~= nil and flags[passKey] == true
end

local function hasAutoCollect(data)
	return data.upgrades.auto >= 1 or hasPass(data, "autoCollect")
end

local function slotCount(data)
	local bonus = hasPass(data, "extraSlots") and Config.Monetization.ExtraSlots or 0
	return math.min(Config.BaseSlots + data.upgrades.slots + bonus, Config.MaxSlots)
end

local function collectionCount(data)
	local count = 0
	for _ in pairs(data.collection) do
		count = count + 1
	end
	return count
end

-- Total income multiplier: store tier x rebirth bonus x collection book bonus x deck combos
-- x completed sets.
local function storeMult(data)
	local collectionBonus = 1 + Config.CollectionBonusPerCard * collectionCount(data)
	local combos = Combos.evaluate(data.slots)
	local setBonus = 1 + Config.SetCompleteBonus * Cards.completedSets(data.collection)
	local passBonus = hasPass(data, "doubleCash") and 2 or 1
	if data.boosts.cashUntil > os.time() then
		passBonus = passBonus * 2 -- Cash Potion
	end
	local achievementBonus = Achievements.incomeMult(data.achievements)
	return Upgrades.getStoreTier(data.upgrades.store).mult * Rebirth.incomeMult(data.rebirths) * collectionBonus * combos.income * setBonus * passBonus * achievementBonus
end

-- Aura multiplier: Aura Magnet perk x deck combos.
local function auraMult(data)
	local passBonus = hasPass(data, "doubleAura") and 2 or 1
	return Perks.auraMult(data.perks) * Combos.evaluate(data.slots).aura * passBonus
end

local luckEventEndsAt = 0 -- os.time() when the current lucky event ends

-- The player's total Luck stat, from every source (see Luck.luau).
local function luckLevel(data)
	return Luck.total(data, os.time() < luckEventEndsAt, dataPasses[data])
end

local function vaultSlots(data)
	local passBonus = hasPass(data, "bigVault") and Config.Monetization.ExtraVaultSlots or 0
	return Rebirth.vaultSlots(data.rebirths) + Perks.vaultBonus(data.perks) + passBonus
end

local function totals(data)
	local income, aura = 0, 0
	for index = 1, slotCount(data) do
		local key = data.slots[tostring(index)]
		if key then
			income = income + Cards.getIncome(key)
			aura = aura + Cards.getAura(key)
		end
	end
	return income * storeMult(data), aura * auraMult(data)
end

local function pushState(player)
	local session = sessions[player]
	local data = PlayerData.get(player)
	if session == nil or data == nil then
		return
	end
	session.dirty = false
	local income, aura = totals(data)
	StateRemote:FireClient(player, {
		rev = session.rev,
		cash = data.cash,
		aura = data.aura,
		inventory = data.inventory,
		slots = data.slots,
		collection = data.collection,
		upgrades = data.upgrades,
		freePacks = data.freePacks,
		rebirths = data.rebirths,
		vault = data.vault,
		vaultSlots = vaultSlots(data),
		perks = data.perks,
		tower = data.tower,
		luckEventEndsAt = luckEventEndsAt,
		luck = luckLevel(data),
		quests = data.quests,
		questRev = session.questRev,
		daily = data.daily,
		today = Quests.today(),
		slotCount = slotCount(data),
		gifts = data.gifts,
		featuredSet = Season.featuredSet(),
		passes = dataPasses[data] or {},
		cashCap = Rebirth.cashCap(data.rebirths),
		packsOpened = data.packsOpened,
		stats = data.stats,
		achievements = data.achievements,
		packCounts = data.packCounts,
		autoPack = data.autoPack,
		autoRev = session.autoRev or 0,
		boosts = data.boosts,
		showcase = data.showcase,
		restricted = session.restricted,
		isOwner = isOwner(player),
		incomePerSec = income,
		auraPerSec = aura,
	})
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Cash.Value = math.floor(data.cash)
		stats.Aura.Value = math.floor(data.aura)
	end
end

-- structural = inventory / slots / collection / upgrades changed (client rebuilds its panels)
-- Keeps the two showcase frames at the store entrance on the deck's two best cards.
local function updateShowcase(player)
	local session = sessions[player]
	local data = PlayerData.get(player)
	if session == nil or data == nil then
		return
	end
	local keys = {}
	for index = 1, slotCount(data) do
		local key = data.slots[tostring(index)]
		if key then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		local incomeA, incomeB = Cards.getIncome(a), Cards.getIncome(b)
		if incomeA ~= incomeB then
			return incomeA > incomeB
		end
		return a < b
	end)
	-- a card the player picked wins, as long as they still own it; otherwise the top earners
	local function owns(key)
		if key == "" or Cards.parse(key) == nil then
			return false
		end
		if (data.inventory[key] or 0) > 0 or table.find(data.vault, key) then
			return true
		end
		for _, deckKey in pairs(data.slots) do
			if deckKey == key then
				return true
			end
		end
		return false
	end
	local left = owns(data.showcase.left) and data.showcase.left or keys[1]
	local right = owns(data.showcase.right) and data.showcase.right or keys[2]
	if right == nil and left ~= keys[1] then
		right = keys[1]
	end
	local signature = (left or "") .. "|" .. (right or "")
	if signature ~= session.showcase then
		session.showcase = signature
		Plots.setShowcase(session.plot, left, right)
	end
end

local function touch(player, structural)
	local session = sessions[player]
	if session == nil then
		return
	end
	if structural then
		session.rev = session.rev + 1
		updateShowcase(player)
	end
	pushState(player)
end

-- Rolls new quests when the (UTC) day changes. Returns true if they changed.
local function ensureQuests(player, data)
	local day = Quests.today()
	if data.quests.day == day and type(data.quests.list) == "table" then
		return false
	end
	local income = totals(data)
	data.quests = { day = day, list = Quests.generate(day, player.UserId, income) }
	return true
end

-- Adds progress to today's quests of one type.
local function questProgress(player, questType, amount)
	local session = sessions[player]
	local data = PlayerData.get(player)
	if session == nil or data == nil or amount <= 0 then
		return
	end
	for _, quest in ipairs(data.quests.list) do
		if quest.type == questType and quest.progress < quest.goal then
			quest.progress = math.min(quest.goal, quest.progress + amount)
			session.questRev = session.questRev + 1
			session.dirty = true
			if quest.progress >= quest.goal then
				notify(player, "🎯 Quest complete! Claim your aura in Quests.", "good")
			end
		end
	end
end

-- Set further down, once trading and the market exist: clears a player's listings and trade.
local onRebirthReset = function(_player, _data) end

local function addCard(data, key, amount)
	data.inventory[key] = (data.inventory[key] or 0) + (amount or 1)
	data.collection[key] = true
end

local function takeCard(data, key, amount)
	local owned = data.inventory[key] or 0
	if owned < amount then
		return false
	end
	if owned == amount then
		data.inventory[key] = nil
	else
		data.inventory[key] = owned - amount
	end
	return true
end

local function firstEmptySlot(data)
	for index = 1, slotCount(data) do
		if data.slots[tostring(index)] == nil then
			return index
		end
	end
	return nil
end

-- Adds cash, respecting the wallet cap (see Rebirth.cashCap). Returns what was really added.
-- bypassCap is for money a player is owed by someone else (market sales).
local function addCash(data, amount, bypassCap)
	if amount <= 0 then
		return 0
	end
	if not bypassCap then
		amount = math.min(amount, math.max(0, Rebirth.cashCap(data.rebirths) - data.cash))
	end
	data.cash = data.cash + amount
	data.stats.earned = data.stats.earned + amount -- lifetime total, for achievements
	return amount
end

local function spend(data, currency, cost)
	if currency ~= "cash" and currency ~= "aura" then
		return false
	end
	if data[currency] < cost then
		return false
	end
	data[currency] = data[currency] - cost
	return true
end

RequestStateRemote.OnServerEvent:Connect(function(player)
	if not allow(player, "RequestState", 1, 3) then
		return
	end
	pushState(player)
end)

---------------------------------------------------------------------
-- Packs
---------------------------------------------------------------------
-- Anyone can open 1 to 3 packs at once; 10 at once needs the game pass.
local function isBulkSize(data, count)
	for _, size in ipairs(Config.PackBulkSizes) do
		if count == size then
			return true
		end
	end
	return count == Config.PassBulkSize and hasPass(data, "megaOpen")
end

-- Opens `count` packs that have already been paid for: rolls the cards, adds them to the
-- profile and returns the list for the client to show.
-- autoSell (Auto Packer only): 1-3 sells spare plain cards up to that rarity (see Config).
local function openPacks(player, data, pack, count, autoSell)
	-- this week's featured set gets bonus luck
	local luck = luckLevel(data)
	if pack.sets and table.find(pack.sets, Season.featuredSet()) then
		luck = luck + Season.FeaturedLuck
	end

	local pulled = {}
	local rareCount = 0 -- Epic or better, for the quest
	for _ = 1, count do
		for _, key in ipairs(Packs.open(pack, luck, rng)) do
			local def, variantId = Cards.parse(key)
			local order = Cards.Rarities[def.rarity].order
			if order >= 4 then
				rareCount = rareCount + 1
			end
			if order >= 6 then
				-- Mythic and Secret pulls are announced to the whole server
				AnnounceRemote:FireAllClients(player.DisplayName, key)
			end
			local isNew = data.collection[key] == nil
			local auraBonus = Cards.getAura(key) * Config.AuraPullBonus
			data.aura = data.aura + auraBonus

			local spare = variantId == "normal" and (data.inventory[key] or 0) >= Config.FuseCount
			local sold = autoSell ~= nil and autoSell > 0 and order <= autoSell and spare and not isNew
			if sold then
				addCash(data, Cards.getSellValue(key))
			else
				addCard(data, key, 1)
			end
			table.insert(pulled, { key = key, isNew = isNew, auraBonus = auraBonus, sold = sold })
		end
	end

	data.packsOpened = data.packsOpened + count
	data.packCounts[pack.id] = (data.packCounts[pack.id] or 0) + count
	questProgress(player, "open_packs", count)
	questProgress(player, "pull_rare", rareCount)
	return pulled
end

BuyPackRemote.OnServerInvoke = function(player, packId, count)
	local session = sessions[player]
	local data = PlayerData.get(player)
	local pack = type(packId) == "string" and Packs.ById[packId] or nil
	if session == nil or data == nil or pack == nil then
		return { ok = false, error = "Something went wrong." }
	end

	if not allow(player, "BuyPack", 4, 6) then
		return { ok = false, error = "Slow down!" }
	end

	if data.upgrades.store + 1 < pack.storeTier then
		return { ok = false, error = "Upgrade your store to " .. Upgrades.StoreTiers[pack.storeTier].name .. " first." }
	end

	if count == nil then
		count = 1
	end
	if type(count) ~= "number" or not isBulkSize(data, count) then
		return { ok = false, error = "Something went wrong." }
	end

	if count == 1 and pack.id == STARTER.id and data.freePacks > 0 then
		data.freePacks = data.freePacks - 1
	elseif count == 1 and pack.kind == "booster" and data.gifts > 0 then
		data.gifts = data.gifts - 1 -- a free booster gift
	elseif not spend(data, pack.currency, Packs.price(pack, data.packCounts[pack.id], count, data.perks)) then
		return { ok = false, error = "Not enough " .. pack.currency .. "." }
	end

	local pulled = openPacks(player, data, pack, count, nil)
	touch(player, true)
	return { ok = true, cards = pulled }
end

-- Auto Packer settings: which pack, on/off, and how much to auto-sell.
AutoPackSetRemote.OnServerEvent:Connect(function(player, packId, on, sell)
	if not allow(player, "AutoPackSet", 4, 8) then
		return
	end
	local data = PlayerData.get(player)
	if data == nil or type(packId) ~= "string" or type(on) ~= "boolean" or type(sell) ~= "number" then
		return
	end
	if sell ~= sell or sell % 1 ~= 0 or sell < 0 or sell > Config.AutoSellMax then
		return
	end
	local pack = Packs.ById[packId]
	if packId ~= "" and (pack == nil or pack.currency ~= "cash") then
		return
	end
	if Perks.packerInterval(data.perks) == nil then
		notify(player, "Unlock the Auto Packer in Upgrades → Aura Shrine first.", "error")
		return
	end
	data.autoPack = { packId = packId, on = on and packId ~= "", sell = sell }
	touch(player, true)
end)

-- Runs once a second per player from the income loop.
local function runAutoPacker(player, session, data)
	local interval = Perks.packerInterval(data.perks)
	local settings = data.autoPack
	if interval == nil or not settings.on then
		return
	end
	session.autoTimer = (session.autoTimer or 0) + 1
	if session.autoTimer < interval then
		return
	end
	session.autoTimer = 0
	local pack = Packs.ById[settings.packId]
	if pack == nil or pack.currency ~= "cash" or data.upgrades.store + 1 < pack.storeTier then
		return
	end
	if not spend(data, "cash", Packs.price(pack, data.packCounts[pack.id], 1, data.perks)) then
		return -- cannot afford it right now; try again next time
	end
	-- the best card owned before this pack, to spot a new personal best
	local bestBefore = 0
	for key in pairs(data.inventory) do
		bestBefore = math.max(bestBefore, Cards.getIncome(key))
	end
	for _, key in pairs(data.slots) do
		bestBefore = math.max(bestBefore, Cards.getIncome(key))
	end
	for _, key in ipairs(data.vault) do
		bestBefore = math.max(bestBefore, Cards.getIncome(key))
	end

	local pulled = openPacks(player, data, pack, 1, settings.sell)

	local newBest = nil
	for _, entry in ipairs(pulled) do
		local income = Cards.getIncome(entry.key)
		if not entry.sold and income > bestBefore then
			bestBefore = income
			newBest = entry.key
		end
	end
	AutoPullRemote:FireClient(player, pulled, newBest)
	updateShowcase(player)
	session.rev = session.rev + 1
	session.autoRev = (session.autoRev or 0) + 1 -- lets the client tell this apart from a click
	session.dirty = true
end

---------------------------------------------------------------------
-- Displaying / selling cards
---------------------------------------------------------------------
local function placeCard(player, key, index)
	local session = sessions[player]
	local data = PlayerData.get(player)
	if session == nil or data == nil or Cards.parse(key) == nil then
		return
	end
	if index == nil then
		index = firstEmptySlot(data)
		if index == nil then
			notify(player, "Your deck is full. Buy more deck slots or take a card out.", "error")
			return
		end
	end
	if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > slotCount(data) then
		return
	end
	if not takeCard(data, key, 1) then
		return
	end
	local slotKey = tostring(index)
	if data.slots[slotKey] then
		addCard(data, data.slots[slotKey], 1)
	end
	data.slots[slotKey] = key
	Plots.setCard(session.plot, index, key)
	touch(player, true)
end

local function removeCard(player, index)
	local session = sessions[player]
	local data = PlayerData.get(player)
	if session == nil or data == nil or type(index) ~= "number" then
		return
	end
	local slotKey = tostring(index)
	local key = data.slots[slotKey]
	if key == nil then
		return
	end
	data.slots[slotKey] = nil
	addCard(data, key, 1)
	Plots.setCard(session.plot, index, nil)
	touch(player, true)
end

PlaceCardRemote.OnServerEvent:Connect(function(player, key, index)
	if not allow(player, "PlaceCard", 8, 16) then
		return
	end
	placeCard(player, key, index)
end)

RemoveCardRemote.OnServerEvent:Connect(function(player, index)
	if not allow(player, "RemoveCard", 8, 16) then
		return
	end
	removeCard(player, index)
end)

SellCardRemote.OnServerEvent:Connect(function(player, key, amount)
	if not allow(player, "SellCard", 8, 16) then
		return
	end
	local data = PlayerData.get(player)
	if data == nil or Cards.parse(key) == nil then
		return
	end
	if type(amount) ~= "number" or amount ~= amount or amount < 1 then
		return
	end
	amount = math.min(math.floor(amount), data.inventory[key] or 0)
	if amount < 1 then
		return
	end
	local value = Cards.getSellValue(key) * amount
	if data.cash + value > Rebirth.cashCap(data.rebirths) then
		notify(player, "Your wallet is full. Spend some cash or rebirth before selling.", "error")
		return
	end
	if not takeCard(data, key, amount) then
		return
	end
	value = addCash(data, value)
	notify(player, "Sold for " .. Format.cash(value), "cash")
	questProgress(player, "sell", amount)
	touch(player, true)
end)

-- Fuse: FuseCount copies of the same card + variant become one copy of the next variant up.
FuseCardRemote.OnServerEvent:Connect(function(player, key)
	if not allow(player, "FuseCard", 8, 16) then
		return
	end
	local data = PlayerData.get(player)
	local def, variantId = Cards.parse(key)
	if data == nil or def == nil then
		return
	end
	local nextVariant = Cards.nextVariant(variantId)
	if nextVariant == nil then
		notify(player, "Prismatic cards can't be fused any further.", "error")
		return
	end
	if not takeCard(data, key, Config.FuseCount) then
		notify(player, "You need " .. Config.FuseCount .. " copies to fuse.", "error")
		return
	end
	local newKey = Cards.makeKey(def.id, nextVariant)
	addCard(data, newKey, 1)
	notify(player, "Fused into " .. Cards.getDisplayName(newKey) .. "!", "good")
	data.stats.fused = data.stats.fused + 1
	questProgress(player, "fuse", 1)
	touch(player, true)
end)

-- Fuses every set of spare copies in the inventory (cards in the deck are left alone).
-- Runs a few passes so three new Shiny cards can go on to become a Golden one.
FuseAllRemote.OnServerEvent:Connect(function(player)
	if not allow(player, "FuseAll", 1, 2) then
		return
	end
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	local fused = 0
	for _ = 1, #Cards.FuseOrder do
		local changes = {}
		for key, count in pairs(data.inventory) do
			local def, variantId = Cards.parse(key)
			local nextVariant = def and Cards.nextVariant(variantId)
			if nextVariant and count >= Config.FuseCount then
				table.insert(changes, { key = key, times = math.floor(count / Config.FuseCount), newKey = Cards.makeKey(def.id, nextVariant) })
			end
		end
		if #changes == 0 then
			break
		end
		for _, change in ipairs(changes) do
			if takeCard(data, change.key, change.times * Config.FuseCount) then
				addCard(data, change.newKey, change.times)
				fused = fused + change.times
			end
		end
	end
	if fused == 0 then
		notify(player, "Nothing to fuse. You need " .. Config.FuseCount .. " spare copies of the same card.", "error")
		return
	end
	data.stats.fused = data.stats.fused + fused
	questProgress(player, "fuse", fused)
	notify(player, "Fused " .. fused .. " times!", "good")
	touch(player, true)
end)

-- Sells plain spare copies from the inventory, keeping enough of each card to fuse once.
SellSparesRemote.OnServerEvent:Connect(function(player)
	if not allow(player, "SellSpares", 1, 2) then
		return
	end
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	local room = Rebirth.cashCap(data.rebirths) - data.cash
	local sold, total = 0, 0
	local keys = {}
	for key in pairs(data.inventory) do
		table.insert(keys, key)
	end
	for _, key in ipairs(keys) do
		local def, variantId = Cards.parse(key)
		local spare = (data.inventory[key] or 0) - Config.FuseCount
		if def and variantId == "normal" and spare > 0 then
			local each = Cards.getSellValue(key)
			-- never sell into a full wallet
			local amount = math.min(spare, math.floor((room - total) / each))
			if amount > 0 and takeCard(data, key, amount) then
				sold = sold + amount
				total = total + each * amount
			end
		end
	end
	if sold == 0 then
		notify(player, "No spare cards to sell (or your wallet is full).", "error")
		return
	end
	total = addCash(data, total)
	questProgress(player, "sell", sold)
	notify(player, "Sold " .. sold .. " spare cards for " .. Format.cash(total), "cash")
	touch(player, true)
end)

EquipBestRemote.OnServerEvent:Connect(function(player)
	if not allow(player, "EquipBest", 1, 3) then
		return
	end
	local session = sessions[player]
	local data = PlayerData.get(player)
	if session == nil or data == nil then
		return
	end
	local count = slotCount(data)

	-- Take every card out of the deck, then rebuild it.
	for index = 1, count do
		local slotKey = tostring(index)
		if data.slots[slotKey] then
			addCard(data, data.slots[slotKey], 1)
			data.slots[slotKey] = nil
		end
	end

	-- Deck.autoFill starts from the highest earners and swaps in story combos that pay more.
	for index, key in ipairs(Deck.autoFill(data.inventory, count)) do
		if takeCard(data, key, 1) then
			data.slots[tostring(index)] = key
		end
	end

	for slot = 1, count do
		Plots.setCard(session.plot, slot, data.slots[tostring(slot)])
	end
	touch(player, true)
end)

---------------------------------------------------------------------
-- Upgrades
---------------------------------------------------------------------
BuyUpgradeRemote.OnServerEvent:Connect(function(player, upgradeId)
	if not allow(player, "BuyUpgrade", 5, 10) then
		return
	end
	local session = sessions[player]
	local data = PlayerData.get(player)
	local def = type(upgradeId) == "string" and Upgrades.Defs[upgradeId] or nil
	if session == nil or data == nil or def == nil then
		return
	end
	local level = data.upgrades[upgradeId]
	if level >= def.max then
		notify(player, def.name .. " is maxed out.", "error")
		return
	end
	if not spend(data, def.currency, def.cost(level)) then
		notify(player, "Not enough " .. def.currency .. ".", "error")
		return
	end
	data.upgrades[upgradeId] = level + 1

	if upgradeId == "slots" then
		Plots.setSlotCount(session.plot, slotCount(data))
		notify(player, "New deck slot unlocked!", "good")
	elseif upgradeId == "store" then
		Plots.setTier(session.plot, data.upgrades.store + 1)
		Plots.setOwnerSign(session.plot, player, data.upgrades.store, data.rebirths, hasPass(data, "vip"))
		notify(player, "Store upgraded to " .. Upgrades.getStoreTier(data.upgrades.store).name .. "!", "good")
	else
		notify(player, def.name .. " upgraded!", "good")
	end
	touch(player, true)
end)

---------------------------------------------------------------------
-- Aura Shrine (permanent perks)
---------------------------------------------------------------------
-- Redeem a code from Config.Codes. Each code works once per player.
RedeemCodeRemote.OnServerEvent:Connect(function(player, text)
	if not allow(player, "RedeemCode", 0.5, 3) then
		return
	end
	local data = PlayerData.get(player)
	if data == nil or type(text) ~= "string" or #text > 40 then
		return
	end
	local code = string.upper((string.gsub(text, "%s+", "")))
	local reward = Config.Codes[code]
	if reward == nil then
		notify(player, "That code isn't valid.", "error")
		return
	end
	if data.codes[code] then
		notify(player, "You've already used that code.", "error")
		return
	end
	data.codes[code] = true
	local parts = {}
	if reward.gifts then
		data.gifts = data.gifts + reward.gifts
		table.insert(parts, reward.gifts .. " free boosters")
	end
	if reward.aura then
		data.aura = data.aura + reward.aura
		table.insert(parts, "+" .. Format.short(reward.aura) .. " aura")
	end
	if reward.cash then
		table.insert(parts, Format.cash(addCash(data, reward.cash)))
	end
	notify(player, "🎉 Code redeemed: " .. table.concat(parts, ", "), "good")
	touch(player, true)
end)

-- Owner-only testing tool: wipe your own save and start again.
ResetDataRemote.OnServerEvent:Connect(function(player)
	if not allow(player, "ResetData", 0.2, 1) or not isOwner(player) then
		return
	end
	local session = sessions[player]
	if session then
		session.pending = 0
	end
	PlayerData.reset(player)
	player:Kick("Your save was reset. Rejoin to start fresh.")
end)

-- Choose a card for one of the two storefront frames. side = "left", "right", or "auto" to go
-- back to showing the deck's top earners.
SetShowcaseRemote.OnServerEvent:Connect(function(player, side, key)
	if not allow(player, "SetShowcase", 4, 8) then
		return
	end
	local data = PlayerData.get(player)
	if data == nil then
		return
	end
	if side == "auto" then
		data.showcase = { left = "", right = "" }
	elseif (side == "left" or side == "right") and Cards.parse(key) then
		data.showcase[side] = key -- ownership is checked every time the frames are drawn
	else
		return
	end
	updateShowcase(player)
	touch(player, true)
end)

BuyPerkRemote.OnServerEvent:Connect(function(player, perkId)
	if not allow(player, "BuyPerk", 5, 10) then
		return
	end
	local data = PlayerData.get(player)
	local def = type(perkId) == "string" and Perks.Defs[perkId] or nil
	if data == nil or def == nil then
		return
	end
	local level = Perks.level(data.perks, perkId)
	if level >= def.max then
		notify(player, def.name .. " is maxed out.", "error")
		return
	end
	if level >= Perks.maxLevel(perkId, data.rebirths) then
		notify(player, "Rebirth to unlock the next level of " .. def.name .. ".", "error")
		return
	end
	if not spend(data, "aura", def.cost(level)) then
		notify(player, "Not enough aura.", "error")
		return
	end
	data.perks[perkId] = level + 1
	notify(player, def.name .. " is now level " .. (level + 1) .. " — permanently!", "good")
	touch(player, true)
end)

---------------------------------------------------------------------
-- Battle tower (PvE)
---------------------------------------------------------------------
-- The server picks the player's strongest team, runs the whole fight, and returns the log
-- for the client to play back.
BattleRemote.OnServerInvoke = function(player)
	local session = sessions[player]
	local data = PlayerData.get(player)
	if session == nil or data == nil then
		return { ok = false, error = "Something went wrong." }
	end
	local now = os.clock()
	if not allow(player, "Battle", 1, 2) or now - (session.lastBattle or 0) < Config.BattleCooldown then
		return { ok = false, error = "Your team is catching its breath. Try again in a moment." }
	end
	local floor = data.tower + 1
	if floor > Battle.MaxFloor then
		return { ok = false, error = "You have cleared the whole tower!" }
	end
	local team = Battle.bestTeam(data)
	if #team == 0 then
		return { ok = false, error = "You need at least one card to battle." }
	end
	session.lastBattle = now

	local enemies = Battle.enemyTeam(floor)
	local win, log = Battle.simulate(team, enemies, rng)

	local result = { ok = true, win = win, floor = floor, team = team, enemies = enemies, log = log }
	if win then
		local aura, cash = Battle.reward(floor, Rebirth.cashCap(data.rebirths))
		data.tower = floor
		data.aura = data.aura + aura
		cash = addCash(data, cash)
		result.aura = aura
		result.cash = cash
		touch(player, false)
	end
	return result
end

---------------------------------------------------------------------
-- Quests and daily reward
---------------------------------------------------------------------
QuestClaimRemote.OnServerEvent:Connect(function(player, index)
	if not allow(player, "QuestClaim", 4, 8) then
		return
	end
	local session = sessions[player]
	local data = PlayerData.get(player)
	if session == nil or data == nil or type(index) ~= "number" or index % 1 ~= 0 then
		return
	end
	local quest = data.quests.list[index]
	if quest == nil or quest.claimed or quest.progress < quest.goal then
		return
	end
	quest.claimed = true
	local aura = Quests.reward(data.rebirths)
	data.aura = data.aura + aura
	session.questRev = session.questRev + 1
	notify(player, "Quest reward: +" .. Format.short(aura) .. " aura", "good")
	touch(player, false)
end)

DailyClaimRemote.OnServerEvent:Connect(function(player)
	if not allow(player, "DailyClaim", 1, 3) then
		return
	end
	local session = sessions[player]
	local data = PlayerData.get(player)
	if session == nil or data == nil then
		return
	end
	local day = Quests.today()
	local daily = data.daily
	if daily.lastDay >= day then
		notify(player, "You already claimed today's reward. Come back tomorrow!", "error")
		return
	end
	if daily.lastDay == day - 1 then
		daily.streak = daily.streak + 1
	else
		daily.streak = 1
	end
	daily.lastDay = day
	local aura = Quests.dailyAura(daily.streak, data.rebirths)
	local income = totals(data)
	local cash = 100 + math.floor(income * 120)
	data.aura = data.aura + aura
	cash = addCash(data, cash)
	session.questRev = session.questRev + 1
	notify(player, "Day " .. daily.streak .. " reward: +" .. Format.short(aura) .. " aura and " .. Format.cash(cash), "good")
	touch(player, false)
end)

AchievementClaimRemote.OnServerEvent:Connect(function(player, achievementId)
	if not allow(player, "AchievementClaim", 4, 8) then
		return
	end
	local session = sessions[player]
	local data = PlayerData.get(player)
	local achievement = type(achievementId) == "string" and Achievements.ById[achievementId] or nil
	if session == nil or data == nil or achievement == nil or data.achievements[achievement.id] then
		return
	end
	-- the profile plus the one value that is not saved in it
	local value
	if achievement.stat == "deck" then
		value = slotCount(data)
	else
		value = Achievements.value(data, achievement.stat)
	end
	if value < achievement.goal then
		return
	end
	data.achievements[achievement.id] = true
	local aura = Achievements.auraReward(achievement)
	data.aura = data.aura + aura
	session.questRev = session.questRev + 1
	notify(player, "🏆 " .. achievement.name .. "!  +" .. math.floor(Achievements.BonusEach * 100 + 0.5) .. "% income forever, +" .. Format.short(aura) .. " aura", "good")
	touch(player, false)
end)

---------------------------------------------------------------------
-- Vault and rebirth
---------------------------------------------------------------------
-- Vault cards earn nothing, but they are the only cards that survive a rebirth.
-- fromSlot (optional): vault the card straight out of that deck slot instead of the inventory.
VaultStoreRemote.OnServerEvent:Connect(function(player, key, fromSlot)
	if not allow(player, "VaultStore", 8, 16) then
		return
	end
	local session = sessions[player]
	local data = PlayerData.get(player)
	if session == nil or data == nil or Cards.parse(key) == nil then
		return
	end
	if #data.vault >= vaultSlots(data) then
		notify(player, "Your vault is full. Rebirth to unlock more vault slots.", "error")
		return
	end
	if fromSlot ~= nil then
		if type(fromSlot) ~= "number" or fromSlot % 1 ~= 0 or fromSlot < 1 or fromSlot > slotCount(data) then
			return
		end
		local slotKey = tostring(fromSlot)
		if data.slots[slotKey] ~= key then
			return
		end
		data.slots[slotKey] = nil
		Plots.setCard(session.plot, fromSlot, nil)
	elseif not takeCard(data, key, 1) then
		return
	end
	table.insert(data.vault, key)
	notify(player, Cards.getDisplayName(key) .. " is safe in your vault.", "good")
	touch(player, true)
end)

VaultTakeRemote.OnServerEvent:Connect(function(player, index)
	if not allow(player, "VaultTake", 8, 16) then
		return
	end
	local data = PlayerData.get(player)
	if data == nil or type(index) ~= "number" or index % 1 ~= 0 then
		return
	end
	if index < 1 or index > #data.vault then
		return
	end
	local key = table.remove(data.vault, index)
	addCard(data, key, 1)
	touch(player, true)
end)

RebirthRemote.OnServerEvent:Connect(function(player)
	if not allow(player, "Rebirth", 0.5, 2) then
		return
	end
	local session = sessions[player]
	local data = PlayerData.get(player)
	if session == nil or data == nil then
		return
	end
	local level, ready = Rebirth.check(data)
	if level == nil then
		notify(player, "You have reached the highest rebirth.", "error")
		return
	end
	if not ready then
		notify(player, "You don't meet the rebirth requirements yet.", "error")
		return
	end

	onRebirthReset(player, data)

	-- Reset the run. Kept: rebirths, vault, collection book, perks, tower, packsOpened.
	data.rebirths = data.rebirths + 1
	data.cash = Perks.startCash(data.perks)
	data.aura = 0
	data.inventory = {}
	data.slots = {}
	data.upgrades = { store = 0, slots = 0, luck = 0, auto = 0, charm = 0 }
	data.packCounts = {} -- pack prices start low again
	data.freePacks = 1
	session.pending = 0
	Plots.setPending(session.plot, 0)

	Plots.resetStands(session.plot, slotCount(data))
	Plots.setTier(session.plot, 1)
	Plots.setOwnerSign(session.plot, player, data.upgrades.store, data.rebirths, hasPass(data, "vip"))

	notify(player, "🌟 REBIRTH " .. data.rebirths .. "!  " .. Rebirth.describeBonuses(data.rebirths), "good")
	touch(player, true)
end)

---------------------------------------------------------------------
-- Marketplace: list a card for cash; other players in the server can buy it
---------------------------------------------------------------------
-- A listed card leaves the inventory and sits in data.listings (saved) until sold or cancelled.
local listingCounter = 0

local function marketSnapshot()
	local list = {}
	for seller in pairs(sessions) do
		local data = PlayerData.get(seller)
		if data then
			for _, listing in ipairs(data.listings) do
				table.insert(list, {
					id = listing.id,
					key = listing.key,
					price = listing.price,
					sellerId = seller.UserId,
					sellerName = seller.DisplayName,
				})
			end
		end
	end
	table.sort(list, function(a, b)
		if a.price ~= b.price then
			return a.price < b.price
		end
		return a.id < b.id
	end)
	return list
end

local function broadcastMarket()
	MarketStateRemote:FireAllClients(marketSnapshot())
end

MarketListRemote.OnServerEvent:Connect(function(player, key, price)
	if not allow(player, "MarketList", 2, 4) then
		return
	end
	local data = PlayerData.get(player)
	if data == nil or Cards.parse(key) == nil then
		return
	end
	if type(price) ~= "number" or price ~= price then
		return
	end
	price = math.floor(price)
	if price < 1 or price > Config.Market.MaxPrice then
		notify(player, "Enter a price between $1 and " .. Format.cash(Config.Market.MaxPrice) .. ".", "error")
		return
	end
	if #data.listings >= Config.Market.MaxListings then
		notify(player, "You can only have " .. Config.Market.MaxListings .. " cards for sale at once.", "error")
		return
	end
	if not takeCard(data, key, 1) then
		return
	end
	listingCounter = listingCounter + 1
	table.insert(data.listings, {
		id = player.UserId .. "-" .. os.time() .. "-" .. listingCounter,
		key = key,
		price = price,
	})
	notify(player, Cards.getDisplayName(key) .. " listed for " .. Format.cash(price) .. ".", "good")
	touch(player, true)
	broadcastMarket()
end)

MarketCancelRemote.OnServerEvent:Connect(function(player, listingId)
	if not allow(player, "MarketCancel", 4, 8) then
		return
	end
	local data = PlayerData.get(player)
	if data == nil or type(listingId) ~= "string" then
		return
	end
	for index, listing in ipairs(data.listings) do
		if listing.id == listingId then
			table.remove(data.listings, index)
			addCard(data, listing.key, 1)
			touch(player, true)
			broadcastMarket()
			return
		end
	end
end)

MarketBuyRemote.OnServerEvent:Connect(function(player, listingId)
	if not allow(player, "MarketBuy", 4, 8) then
		return
	end
	local data = PlayerData.get(player)
	if data == nil or type(listingId) ~= "string" then
		return
	end
	for seller in pairs(sessions) do
		local sellerData = PlayerData.get(seller)
		if sellerData and seller ~= player then
			for index, listing in ipairs(sellerData.listings) do
				if listing.id == listingId then
					if Cards.parse(listing.key) == nil then
						return
					end
					if not spend(data, "cash", listing.price) then
						notify(player, "Not enough cash.", "error")
						return
					end
					table.remove(sellerData.listings, index)
					addCard(data, listing.key, 1)
					addCash(sellerData, listing.price, true)
					local name = Cards.getDisplayName(listing.key)
					notify(player, "You bought " .. name .. " for " .. Format.cash(listing.price) .. "!", "good")
					notify(seller, player.DisplayName .. " bought your " .. name .. " for " .. Format.cash(listing.price) .. "!", "cash")
					touch(player, true)
					touch(seller, false)
					broadcastMarket()
					return
				end
			end
		end
	end
	notify(player, "That card is no longer for sale.", "error")
end)

---------------------------------------------------------------------
-- Trading: two players each offer cards, both confirm, the server swaps them
---------------------------------------------------------------------
-- Offered cards stay in each inventory until both players confirm; the swap then re-checks
-- ownership and happens in one step, so a card can never be duplicated or lost.
local trades = {} -- [player] = trade (the same table for both players)
local tradeRequests = {} -- [target] = { [from] = os.clock() }

local function sendTradeState(trade)
	for _, player in ipairs({ trade.a, trade.b }) do
		local other = player == trade.a and trade.b or trade.a
		TradeStateRemote:FireClient(player, {
			partnerName = other.DisplayName,
			mine = trade.offers[player],
			theirs = trade.offers[other],
			myConfirm = trade.confirmed[player] == true,
			theirConfirm = trade.confirmed[other] == true,
		})
	end
end

local function endTrade(trade, message, kind)
	for _, player in ipairs({ trade.a, trade.b }) do
		if trades[player] == trade then
			trades[player] = nil
			TradeStateRemote:FireClient(player, nil)
			if message then
				notify(player, message, kind or "info")
			end
		end
	end
end

-- True if the player's inventory holds every card in the offer (duplicates counted).
local function canCover(data, offer)
	local needed = {}
	for _, key in ipairs(offer) do
		needed[key] = (needed[key] or 0) + 1
	end
	for key, count in pairs(needed) do
		if (data.inventory[key] or 0) < count then
			return false
		end
	end
	return true
end

TradeRequestRemote.OnServerEvent:Connect(function(player, targetUserId)
	if not allow(player, "TradeRequest", 0.5, 3) then
		return
	end
	if type(targetUserId) ~= "number" or sessions[player] == nil then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if target == nil or target == player or sessions[target] == nil then
		return
	end
	if trades[player] or trades[target] then
		notify(player, "One of you is already in a trade.", "error")
		return
	end
	tradeRequests[target] = tradeRequests[target] or {}
	tradeRequests[target][player] = os.clock()
	TradeRequestRemote:FireClient(target, player.UserId, player.DisplayName)
	notify(player, "Trade request sent to " .. target.DisplayName .. ".", "info")
end)

TradeAcceptRemote.OnServerEvent:Connect(function(player, fromUserId)
	if not allow(player, "TradeAccept", 1, 3) then
		return
	end
	if type(fromUserId) ~= "number" or sessions[player] == nil then
		return
	end
	local from = Players:GetPlayerByUserId(fromUserId)
	local requests = tradeRequests[player]
	local sentAt = from and requests and requests[from]
	if from == nil or sessions[from] == nil or sentAt == nil or os.clock() - sentAt > Config.Trade.RequestTimeout then
		notify(player, "That trade request has expired.", "error")
		return
	end
	if trades[player] or trades[from] then
		notify(player, "One of you is already in a trade.", "error")
		return
	end
	requests[from] = nil
	local trade = { a = from, b = player, offers = { [from] = {}, [player] = {} }, confirmed = {} }
	trades[from] = trade
	trades[player] = trade
	sendTradeState(trade)
end)

TradeOfferRemote.OnServerEvent:Connect(function(player, key, add)
	if not allow(player, "TradeOffer", 8, 16) then
		return
	end
	local trade = trades[player]
	local data = PlayerData.get(player)
	if trade == nil or data == nil or Cards.parse(key) == nil then
		return
	end
	local offer = trade.offers[player]
	if add == true then
		local offered = 0
		for _, offeredKey in ipairs(offer) do
			if offeredKey == key then
				offered = offered + 1
			end
		end
		if #offer >= Config.Trade.MaxCards or offered >= (data.inventory[key] or 0) then
			return
		end
		table.insert(offer, key)
	else
		local index = table.find(offer, key)
		if index == nil then
			return
		end
		table.remove(offer, index)
	end
	trade.confirmed = {} -- any change means both players must confirm again
	sendTradeState(trade)
end)

TradeConfirmRemote.OnServerEvent:Connect(function(player)
	if not allow(player, "TradeConfirm", 2, 4) then
		return
	end
	local trade = trades[player]
	if trade == nil then
		return
	end
	trade.confirmed[player] = true
	if not (trade.confirmed[trade.a] and trade.confirmed[trade.b]) then
		sendTradeState(trade)
		return
	end

	local dataA, dataB = PlayerData.get(trade.a), PlayerData.get(trade.b)
	local offerA, offerB = trade.offers[trade.a], trade.offers[trade.b]
	if dataA == nil or dataB == nil or not canCover(dataA, offerA) or not canCover(dataB, offerB) then
		endTrade(trade, "Trade failed: a card was no longer available.", "error")
		return
	end
	for _, key in ipairs(offerA) do
		takeCard(dataA, key, 1)
	end
	for _, key in ipairs(offerB) do
		takeCard(dataB, key, 1)
	end
	for _, key in ipairs(offerA) do
		addCard(dataB, key, 1)
	end
	for _, key in ipairs(offerB) do
		addCard(dataA, key, 1)
	end
	touch(trade.a, true)
	touch(trade.b, true)
	endTrade(trade, "🤝 Trade complete!", "good")
end)

TradeCancelRemote.OnServerEvent:Connect(function(player)
	if not allow(player, "TradeCancel", 2, 4) then
		return
	end
	local trade = trades[player]
	if trade then
		endTrade(trade, "Trade cancelled.", "info")
	end
end)

onRebirthReset = function(player, data)
	local trade = trades[player]
	if trade then
		endTrade(trade, "Trade cancelled.", "info")
	end
	if #data.listings > 0 then
		data.listings = {} -- cards for sale are part of the run and are reset with it
		broadcastMarket()
	end
end

---------------------------------------------------------------------
-- Game passes and developer products
---------------------------------------------------------------------
Monetization.init({
	onPassChanged = function(player)
		local session = sessions[player]
		local data = PlayerData.get(player)
		if session == nil or data == nil then
			return
		end
		dataPasses[data] = Monetization.get(player)
		Plots.setSlotCount(session.plot, slotCount(data))
		Plots.setOwnerSign(session.plot, player, data.upgrades.store, data.rebirths, hasPass(data, "vip"))
		notify(player, "Thank you! Your game pass is now active.", "good")
		touch(player, true)
	end,

	grantProduct = function(player, data, product)
		local now = os.time()
		local message
		if product.kind == "luck" then
			-- buying again while one is running adds time
			data.boosts.luckUntil = math.max(data.boosts.luckUntil, now) + product.minutes * 60
			message = "+" .. Config.Monetization.PotionLuck .. " luck for " .. product.minutes .. " minutes"
		elseif product.kind == "cash" then
			data.boosts.cashUntil = math.max(data.boosts.cashUntil, now) + product.minutes * 60
			message = "double cash for " .. product.minutes .. " minutes"
		elseif product.kind == "warp" then
			local income = totals(data)
			local gained = addCash(data, income * product.seconds)
			message = Format.cash(gained) .. " from your deck"
		else
			data.aura = data.aura + (product.aura or 0)
			message = "+" .. Format.short(product.aura or 0) .. " aura"
		end
		notify(player, "Thank you! " .. product.name .. ": " .. message, "good")
		touch(player, true)
	end,
})

---------------------------------------------------------------------
-- Plot callbacks
---------------------------------------------------------------------
Plots.init({
	onCollect = function(plot, player)
		local session = sessions[player]
		local data = PlayerData.get(player)
		if session == nil or data == nil then
			return
		end
		local amount = session.pending
		if amount < 1 then
			return
		end
		session.pending = 0
		addCash(data, amount)
		questProgress(player, "collect", amount)
		Plots.setPending(plot, 0)
		touch(player, false)
	end,

	onCardPrompt = function(plot, index, player)
		-- only the owner can take a card off its stand
		if plot.owner == player then
			removeCard(player, index)
		end
	end,

	onShop = function(_, player)
		OpenShopRemote:FireClient(player)
	end,

	onTrade = function(_, player)
		OpenTradeRemote:FireClient(player)
	end,

	onVault = function(_, player)
		OpenRebirthRemote:FireClient(player)
	end,

	onTower = function(player)
		OpenBattleRemote:FireClient(player)
	end,
})

---------------------------------------------------------------------
-- Income loop
---------------------------------------------------------------------
local function updateLeaderboard()
	local rows = {}
	for player in pairs(sessions) do
		local data = PlayerData.get(player)
		if data then
			local income = totals(data)
			table.insert(rows, { name = player.DisplayName, income = income, rebirths = data.rebirths })
		end
	end
	table.sort(rows, function(a, b)
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.name < b.name
	end)
	local lines = {}
	for index = 1, math.min(5, #rows) do
		local row = rows[index]
		local line = index .. ". " .. row.name .. "   " .. Format.cash(row.income) .. "/s"
		if row.rebirths > 0 then
			line = line .. "   ★" .. row.rebirths
		end
		table.insert(lines, line)
	end
	Plots.setLeaderboard(lines)
end

local leaderboardTick = 0

task.spawn(function()
	while true do
		task.wait(1)
		leaderboardTick = leaderboardTick + 1
		if leaderboardTick % 5 == 0 then
			updateLeaderboard()
		end
		for player, session in pairs(sessions) do
			local data = PlayerData.get(player)
			if data then
				-- The active deck earns cash into the register and radiates aura.
				local income, auraGain = 0, 0
				local hasCards = next(data.inventory) ~= nil
				for index = 1, slotCount(data) do
					local key = data.slots[tostring(index)]
					if key then
						hasCards = true
						income = income + Cards.getIncome(key)
						auraGain = auraGain + Cards.getAura(key)
					end
				end
				if income > 0 then
					-- the register stops filling once the wallet cap is reached
					local room = math.max(0, Rebirth.cashCap(data.rebirths) - data.cash)
					session.pending = math.min(session.pending + income * storeMult(data), room)
					if not hasAutoCollect(data) then
						Plots.setPending(session.plot, session.pending)
					end
				end

				-- Auto Collector upgrade: bank everything straight away.
				if hasAutoCollect(data) and session.pending >= 1 then
					addCash(data, session.pending)
					questProgress(player, "collect", session.pending)
					session.pending = 0
					Plots.setPending(session.plot, 0)
					session.dirty = true
				end
				if auraGain > 0 then
					data.aura = data.aura + auraGain * auraMult(data)
					session.dirty = true
				end

				runAutoPacker(player, session, data)

				-- a free booster gift for every stretch of play time
				session.playSeconds = session.playSeconds + 1
				if session.playSeconds >= Config.GiftInterval then
					session.playSeconds = 0
					if data.gifts < Config.GiftMax then
						data.gifts = data.gifts + 1
						session.rev = session.rev + 1
						session.dirty = true
						notify(player, "🎁 Thanks for playing! You earned a free booster — open any unlocked Booster for free.", "good")
					end
				end

				if ensureQuests(player, data) then
					session.questRev = session.questRev + 1
					session.dirty = true
				end

				-- Never let a player get stuck with no cards and no money.
				if not hasCards and data.freePacks < 1 and data.cash + session.pending < STARTER.cost then
					data.freePacks = 1
					session.rev = session.rev + 1
					session.dirty = true
					notify(player, "You're out of cards — here's a free Starter Pack!", "good")
				end

				if session.dirty then
					pushState(player)
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- Lucky event: bonus luck for the whole server every so often
---------------------------------------------------------------------
local function markAllDirty()
	for _, session in pairs(sessions) do
		session.rev = session.rev + 1 -- pack odds changed, so open panels rebuild
		session.dirty = true
	end
end

task.spawn(function()
	local settings = Config.LuckEvent
	while true do
		task.wait(settings.Interval)
		luckEventEndsAt = os.time() + settings.Duration
		markAllDirty()
		for player in pairs(sessions) do
			notify(player, "🍀 LUCKY EVENT! Better pack odds for everyone for " .. math.floor(settings.Duration / 60) .. " minutes!", "good")
		end
		task.wait(settings.Duration)
		markAllDirty()
	end
end)

---------------------------------------------------------------------
-- Players joining / leaving
---------------------------------------------------------------------
local function onCharacterAdded(player, character)
	local session = sessions[player]
	if session == nil then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and sessions[player] == session then
		task.wait()
		character:PivotTo(Plots.getSpawnCFrame(session.plot))
	end
end

local function onPlayerAdded(player)
	local plot = Plots.assign(player)
	if plot == nil then
		player:Kick("This server is full. Please join another one!")
		return
	end

	local data, loadError = PlayerData.load(player)
	if data == nil then
		Plots.release(player)
		player:Kick(loadError or "Your data could not be loaded. Please rejoin.")
		return
	end
	-- game passes and regional purchase rules (both ask Roblox, so they can take a moment)
	dataPasses[data] = Monetization.load(player)
	local restricted = Monetization.isRestricted(player)

	if player.Parent == nil then
		-- left while their data was loading
		Plots.release(player)
		PlayerData.release(player)
		return
	end

	local session = {
		plot = plot,
		pending = 0,
		playSeconds = 0,
		restricted = restricted,
		rev = 1,
		questRev = 0,
		dirty = true,
	}
	sessions[player] = session

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cashValue = Instance.new("NumberValue")
	cashValue.Name = "Cash"
	cashValue.Parent = stats
	local auraValue = Instance.new("NumberValue")
	auraValue.Name = "Aura"
	auraValue.Parent = stats
	stats.Parent = player

	Plots.setSlotCount(plot, slotCount(data))
	Plots.setTier(plot, data.upgrades.store + 1)
	Plots.setOwnerSign(plot, player, data.upgrades.store, data.rebirths, hasPass(data, "vip"))
	for index = 1, slotCount(data) do
		Plots.setCard(plot, index, data.slots[tostring(index)])
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	-- Offline earnings: a share of what the displayed cards would have made while away.
	if data.lastSeen > 0 then
		local away = math.clamp(os.time() - data.lastSeen, 0, Config.OfflineMaxSeconds)
		local income = totals(data)
		local earned = math.floor(income * away * Config.OfflineRate * Perks.offlineMult(data.perks))
		if earned >= 1 then
			earned = addCash(data, earned)
			notify(player, "Welcome back! Your store earned " .. Format.cash(earned) .. " while you were away.", "good")
		end
	end
	data.lastSeen = os.time()
	ensureQuests(player, data)
	updateShowcase(player)
	broadcastMarket()

	pushState(player)
end

local function onPlayerRemoving(player)
	local session = sessions[player]
	local data = PlayerData.get(player)
	if session and data then
		-- bank uncollected cash so nothing is lost
		addCash(data, session.pending)
		session.pending = 0
	end
	local trade = trades[player]
	if trade then
		endTrade(trade, "The other player left, so the trade was cancelled.", "info")
	end
	tradeRequests[player] = nil
	for _, requests in pairs(tradeRequests) do
		requests[player] = nil
	end
	sessions[player] = nil
	buckets[player] = nil
	Monetization.forget(player)
	broadcastMarket()
	Plots.release(player)
	PlayerData.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Autosave: one player at a time so saves are spread out.
task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		local list = {}
		for player in pairs(sessions) do
			table.insert(list, player)
		end
		for _, player in ipairs(list) do
			if sessions[player] then
				PlayerData.save(player, false)
				task.wait(1)
			end
		end
	end
end)

-- Server shutdown: final save for everyone, in parallel, then wait for them to land.
game:BindToClose(function()
	local remaining = 0
	for _, player in ipairs(Players:GetPlayers()) do
		remaining = remaining + 1
		task.spawn(function()
			onPlayerRemoving(player)
			remaining = remaining - 1
		end)
	end
	if RunService:IsStudio() then
		return
	end
	local deadline = os.clock() + 25
	while remaining > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)
