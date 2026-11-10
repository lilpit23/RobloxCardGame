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
local Synergy = require(Shared:WaitForChild("Synergy"))
local Battle = require(Shared:WaitForChild("Battle"))

local PlayerData = require(script:WaitForChild("PlayerData"))
local Plots = require(script:WaitForChild("Plots"))

local rng = Random.new()
local STARTER = Packs.ById.starter

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
local RebirthRemote = newRemote("RemoteEvent", "Rebirth")
local VaultStoreRemote = newRemote("RemoteEvent", "VaultStore")
local VaultTakeRemote = newRemote("RemoteEvent", "VaultTake")
local QuestClaimRemote = newRemote("RemoteEvent", "QuestClaim")
local DailyClaimRemote = newRemote("RemoteEvent", "DailyClaim")
local BuyPerkRemote = newRemote("RemoteEvent", "BuyPerk")
local BattleRemote = newRemote("RemoteFunction", "Battle")
local OpenTradeRemote = newRemote("RemoteEvent", "OpenTrade") -- server -> client
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
-- [player] = { plot, pending = {[slot] = cash}, rev, questRev, dirty, ... }
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

local function slotCount(data)
	return math.min(Config.BaseSlots + data.upgrades.slots, Config.MaxSlots)
end

local function collectionCount(data)
	local count = 0
	for _ in pairs(data.collection) do
		count = count + 1
	end
	return count
end

-- Total income multiplier: store tier x rebirth bonus x collection book bonus x display synergies.
local function storeMult(data)
	local collectionBonus = 1 + Config.CollectionBonusPerCard * collectionCount(data)
	local synergy = Synergy.compute(data.slots)
	return Upgrades.getStoreTier(data.upgrades.store).mult * Rebirth.incomeMult(data.rebirths) * collectionBonus * synergy
end

local luckEventEndsAt = 0 -- os.time() when the current lucky event ends

-- Bought luck levels, plus the free ones from rebirths, plus the lucky event.
local function luckLevel(data)
	local level = data.upgrades.luck + Rebirth.luckBonus(data.rebirths)
	if os.time() < luckEventEndsAt then
		level = level + Config.LuckEvent.BonusLevels
	end
	return level
end

local function vaultSlots(data)
	return Rebirth.vaultSlots(data.rebirths) + Perks.vaultBonus(data.perks)
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
	return income * storeMult(data), aura * Perks.auraMult(data.perks)
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
local function touch(player, structural)
	local session = sessions[player]
	if session == nil then
		return
	end
	if structural then
		session.rev = session.rev + 1
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
local function isBulkSize(count)
	for _, size in ipairs(Config.PackBulkSizes) do
		if count == size then
			return true
		end
	end
	return false
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
	if type(count) ~= "number" or not isBulkSize(count) then
		return { ok = false, error = "Something went wrong." }
	end

	if count == 1 and pack.id == STARTER.id and data.freePacks > 0 then
		data.freePacks = data.freePacks - 1
	elseif not spend(data, pack.currency, Perks.packCost(pack, data.perks) * count) then
		return { ok = false, error = "Not enough " .. pack.currency .. "." }
	end

	local pulled = {}
	local rareCount = 0
	for _ = 1, Config.CardsPerPack * count do
		local key = Packs.roll(pack, luckLevel(data), rng)
		local def = Cards.parse(key)
		if def and Cards.Rarities[def.rarity].order >= 3 then
			rareCount = rareCount + 1
		end
		local isNew = data.collection[key] == nil
		addCard(data, key, 1)
		local auraBonus = Cards.getAura(key) * Config.AuraPullBonus
		data.aura = data.aura + auraBonus
		table.insert(pulled, { key = key, isNew = isNew, auraBonus = auraBonus })
	end
	data.packsOpened = data.packsOpened + count
	questProgress(player, "open_packs", count)
	questProgress(player, "pull_rare", rareCount)

	touch(player, true)
	return { ok = true, cards = pulled }
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
			notify(player, "All display stands are full. Buy more stands or remove a card.", "error")
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
	if amount < 1 or not takeCard(data, key, amount) then
		return
	end
	local value = Cards.getSellValue(key, Config.SellMultiplier) * amount
	data.cash = data.cash + value
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
	questProgress(player, "fuse", 1)
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

	-- Pull everything off the stands, then put the highest earners back.
	for index = 1, count do
		local slotKey = tostring(index)
		if data.slots[slotKey] then
			addCard(data, data.slots[slotKey], 1)
			data.slots[slotKey] = nil
		end
	end

	local keys = {}
	for key in pairs(data.inventory) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		local incomeA, incomeB = Cards.getIncome(a), Cards.getIncome(b)
		if incomeA ~= incomeB then
			return incomeA > incomeB
		end
		return a < b
	end)

	local index = 1
	for _, key in ipairs(keys) do
		while index <= count and (data.inventory[key] or 0) > 0 do
			takeCard(data, key, 1)
			data.slots[tostring(index)] = key
			index = index + 1
		end
		if index > count then
			break
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
		notify(player, "New display stand built!", "good")
	elseif upgradeId == "store" then
		Plots.setTier(session.plot, data.upgrades.store + 1)
		Plots.setOwnerSign(session.plot, player, data.upgrades.store, data.rebirths)
		notify(player, "Store upgraded to " .. Upgrades.getStoreTier(data.upgrades.store).name .. "!", "good")
	else
		notify(player, def.name .. " upgraded!", "good")
	end
	touch(player, true)
end)

---------------------------------------------------------------------
-- Aura Shrine (permanent perks)
---------------------------------------------------------------------
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
		local aura, cash = Battle.reward(floor)
		data.tower = floor
		data.aura = data.aura + aura
		data.cash = data.cash + cash
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
	data.cash = data.cash + cash
	session.questRev = session.questRev + 1
	notify(player, "Day " .. daily.streak .. " reward: +" .. Format.short(aura) .. " aura and " .. Format.cash(cash), "good")
	touch(player, false)
end)

---------------------------------------------------------------------
-- Vault and rebirth
---------------------------------------------------------------------
-- Vault cards earn nothing, but they are the only cards that survive a rebirth.
VaultStoreRemote.OnServerEvent:Connect(function(player, key)
	if not allow(player, "VaultStore", 8, 16) then
		return
	end
	local data = PlayerData.get(player)
	if data == nil or Cards.parse(key) == nil then
		return
	end
	if #data.vault >= vaultSlots(data) then
		notify(player, "Your vault is full. Rebirth to unlock more vault slots.", "error")
		return
	end
	if not takeCard(data, key, 1) then
		return
	end
	table.insert(data.vault, key)
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
	data.upgrades = { store = 0, slots = 0, luck = 0, auto = 0 }
	data.freePacks = 1
	session.pending = {}

	Plots.resetStands(session.plot, slotCount(data))
	Plots.setTier(session.plot, 1)
	Plots.setOwnerSign(session.plot, player, data.upgrades.store, data.rebirths)

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
					sellerData.cash = sellerData.cash + listing.price
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
-- Plot callbacks
---------------------------------------------------------------------
Plots.init({
	onCollect = function(plot, index, player)
		local session = sessions[player]
		local data = PlayerData.get(player)
		if session == nil or data == nil then
			return
		end
		local amount = session.pending[index] or 0
		if amount < 1 then
			return
		end
		session.pending[index] = 0
		data.cash = data.cash + amount
		questProgress(player, "collect", amount)
		Plots.setPending(plot, index, 0)
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
})

---------------------------------------------------------------------
-- Income loop
---------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		for player, session in pairs(sessions) do
			local data = PlayerData.get(player)
			if data then
				local mult = storeMult(data)
				local auraGain = 0
				local pendingTotal = 0
				local hasCards = next(data.inventory) ~= nil
				for index = 1, slotCount(data) do
					local key = data.slots[tostring(index)]
					if key then
						hasCards = true
						session.pending[index] = (session.pending[index] or 0) + Cards.getIncome(key) * mult
						auraGain = auraGain + Cards.getAura(key)
						Plots.setPending(session.plot, index, session.pending[index])
					end
					pendingTotal = pendingTotal + (session.pending[index] or 0)
				end

				-- Auto Collector upgrade: bank everything straight away.
				if data.upgrades.auto >= 1 and pendingTotal >= 1 then
					data.cash = data.cash + pendingTotal
					questProgress(player, "collect", pendingTotal)
					for index = 1, slotCount(data) do
						if (session.pending[index] or 0) > 0 then
							session.pending[index] = 0
							Plots.setPending(session.plot, index, 0)
						end
					end
					session.dirty = true
				end
				if auraGain > 0 then
					data.aura = data.aura + auraGain * Perks.auraMult(data.perks)
					session.dirty = true
				end

				if ensureQuests(player, data) then
					session.questRev = session.questRev + 1
					session.dirty = true
				end

				-- Never let a player get stuck with no cards and no money.
				if not hasCards and data.freePacks < 1 and data.cash + pendingTotal < STARTER.cost then
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
	if player.Parent == nil then
		-- left while their data was loading
		Plots.release(player)
		PlayerData.release(player)
		return
	end

	local session = {
		plot = plot,
		pending = {},
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
	Plots.setOwnerSign(plot, player, data.upgrades.store, data.rebirths)
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
			data.cash = data.cash + earned
			notify(player, "Welcome back! Your store earned " .. Format.cash(earned) .. " while you were away.", "good")
		end
	end
	data.lastSeen = os.time()
	ensureQuests(player, data)
	broadcastMarket()

	pushState(player)
end

local function onPlayerRemoving(player)
	local session = sessions[player]
	local data = PlayerData.get(player)
	if session and data then
		-- bank uncollected cash so nothing is lost
		for _, amount in pairs(session.pending) do
			data.cash = data.cash + amount
		end
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
