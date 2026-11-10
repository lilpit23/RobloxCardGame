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

remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- Session state (not saved)
---------------------------------------------------------------------
-- [player] = { plot, pending = {[slot] = cash}, rev, dirty, carrying, shieldOn, shieldUntil, cooldownUntil, ... }
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

local function storeMult(data)
	return Upgrades.getStoreTier(data.upgrades.store).mult
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
	return income * storeMult(data), aura
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
BuyPackRemote.OnServerInvoke = function(player, packId)
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

	if pack.id == STARTER.id and data.freePacks > 0 then
		data.freePacks = data.freePacks - 1
	elseif not spend(data, pack.currency, pack.cost) then
		return { ok = false, error = "Not enough " .. pack.currency .. "." }
	end

	local pulled = {}
	for _ = 1, Config.CardsPerPack do
		local key = Packs.roll(pack, data.upgrades.luck, rng)
		local isNew = data.collection[key] == nil
		addCard(data, key, 1)
		local auraBonus = Cards.getAura(key) * Config.AuraPullBonus
		data.aura = data.aura + auraBonus
		table.insert(pulled, { key = key, isNew = isNew, auraBonus = auraBonus })
	end
	data.packsOpened = data.packsOpened + 1

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
		Plots.setOwnerSign(session.plot, player, data.upgrades.store)
		notify(player, "Store upgraded to " .. Upgrades.getStoreTier(data.upgrades.store).name .. "!", "good")
	else
		notify(player, def.name .. " upgraded!", "good")
	end
	touch(player, true)
end)

---------------------------------------------------------------------
-- Stealing
---------------------------------------------------------------------
local function setCarryVisual(player, key)
	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head")
	local old = head and head:FindFirstChild("CarryTag")
	if old then
		old:Destroy()
	end
	if key == nil then
		if humanoid then
			humanoid.WalkSpeed = 16
		end
		return
	end
	if humanoid then
		humanoid.WalkSpeed = Config.Stealing.CarrySpeed
	end
	if head then
		local gui = Instance.new("BillboardGui")
		gui.Name = "CarryTag"
		gui.Size = UDim2.new(8, 0, 1.2, 0)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.AlwaysOnTop = true
		gui.Parent = head
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 90, 90)
		label.TextStrokeTransparency = 0
		label.Text = "🚨 STOLE " .. Cards.getDisplayName(key)
		label.Parent = gui
	end
end

-- Ends a steal. success = the thief keeps the card.
local function finishSteal(thief, success)
	local session = sessions[thief]
	if session == nil or session.carrying == nil then
		return
	end
	local carrying = session.carrying
	session.carrying = nil
	setCarryVisual(thief, nil)

	local victim = carrying.victim
	local victimData = PlayerData.get(victim)
	local name = Cards.getDisplayName(carrying.key)

	-- If the victim already left, the thief keeps the card either way.
	if success or victimData == nil then
		local data = PlayerData.get(thief)
		if data then
			addCard(data, carrying.key, 1)
			notify(thief, "You stole " .. name .. "! It's in your cards.", "good")
			touch(thief, true)
		end
		if victimData then
			notify(victim, thief.DisplayName .. " got away with your " .. name .. "!", "error")
		end
	else
		addCard(victimData, carrying.key, 1)
		notify(victim, "You got " .. name .. " back! Put it on display again.", "good")
		notify(thief, "You lost the " .. name .. "!", "error")
		touch(victim, true)
	end
end

local function trySteal(thief, plot, index)
	local settings = Config.Stealing
	local owner = plot.owner
	local thiefSession = sessions[thief]
	local ownerSession = owner and sessions[owner]
	local ownerData = owner and PlayerData.get(owner)
	if not settings.Enabled or thiefSession == nil or ownerSession == nil or ownerData == nil then
		return
	end
	if thiefSession.carrying then
		notify(thief, "You are already carrying a card. Get it back to your store!", "error")
		return
	end
	if ownerSession.shieldOn then
		notify(thief, "This store is locked.", "error")
		return
	end
	local slotKey = tostring(index)
	local key = ownerData.slots[slotKey]
	if key == nil then
		return
	end
	ownerData.slots[slotKey] = nil
	Plots.setCard(plot, index, nil)
	thiefSession.carrying = { key = key, victim = owner }
	setCarryVisual(thief, key)
	notify(thief, "Run back to your store! The owner can catch you.", "info")
	notify(owner, "🚨 " .. thief.DisplayName .. " is stealing your " .. Cards.getDisplayName(key) .. "! Catch them!", "error")
	touch(owner, true)
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function setShield(player, enabled)
	local session = sessions[player]
	if session == nil then
		return
	end
	session.shieldOn = enabled
	Plots.setShield(session.plot, enabled)
end

task.spawn(function()
	while true do
		task.wait(0.25)
		local now = os.clock()
		for player, session in pairs(sessions) do
			if session.shieldOn and now >= session.shieldUntil then
				setShield(player, false)
				session.cooldownUntil = now + Config.Stealing.ShieldCooldown
			end
			if session.carrying then
				local root = rootOf(player)
				if root == nil then
					finishSteal(player, false)
				elseif Plots.contains(session.plot, root.Position) then
					finishSteal(player, true)
				else
					local victim = session.carrying.victim
					local victimRoot = sessions[victim] and rootOf(victim)
					if victimRoot and (victimRoot.Position - root.Position).Magnitude <= Config.Stealing.CatchDistance then
						finishSteal(player, false)
					end
				end
			end
		end
	end
end)

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
		Plots.setPending(plot, index, 0)
		touch(player, false)
	end,

	onCardPrompt = function(plot, index, player)
		if plot.owner == player then
			removeCard(player, index)
		else
			trySteal(player, plot, index)
		end
	end,

	onShop = function(_, player)
		OpenShopRemote:FireClient(player)
	end,

	onLock = function(_, player)
		local session = sessions[player]
		if session == nil or session.shieldOn or not Config.Stealing.Enabled then
			return
		end
		local now = os.clock()
		if now < session.cooldownUntil then
			return
		end
		session.shieldUntil = now + Config.Stealing.ShieldTime
		setShield(player, true)
		notify(player, "Store locked for " .. Config.Stealing.ShieldTime .. " seconds.", "good")
	end,
})

---------------------------------------------------------------------
-- Income loop
---------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
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
				if auraGain > 0 then
					data.aura = data.aura + auraGain
					session.dirty = true
				end

				-- Never let a player get stuck with no cards and no money.
				if not hasCards and session.carrying == nil and data.freePacks < 1 and data.cash + pendingTotal < STARTER.cost then
					data.freePacks = 1
					session.rev = session.rev + 1
					session.dirty = true
					notify(player, "You're out of cards — here's a free Starter Pack!", "good")
				end

				if Config.Stealing.Enabled then
					if session.shieldOn then
						Plots.setLockText(session.plot, "🔒 LOCKED " .. math.ceil(session.shieldUntil - now) .. "s")
					elseif now < session.cooldownUntil then
						Plots.setLockText(session.plot, "Recharging " .. math.ceil(session.cooldownUntil - now) .. "s")
					else
						Plots.setLockText(session.plot, "Step here to lock store")
					end
				end

				if session.dirty then
					pushState(player)
				end
			end
		end
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

	local now = os.clock()
	local session = {
		plot = plot,
		pending = {},
		rev = 1,
		dirty = true,
		carrying = nil,
		shieldOn = false,
		shieldUntil = 0,
		cooldownUntil = 0,
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
	Plots.setOwnerSign(plot, player, data.upgrades.store)
	for index = 1, slotCount(data) do
		Plots.setCard(plot, index, data.slots[tostring(index)])
	end

	if Config.Stealing.Enabled and Config.Stealing.JoinShield > 0 then
		session.shieldUntil = now + Config.Stealing.JoinShield
		setShield(player, true)
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
		local earned = math.floor(income * away * Config.OfflineRate)
		if earned >= 1 then
			data.cash = data.cash + earned
			notify(player, "Welcome back! Your store earned " .. Format.cash(earned) .. " while you were away.", "good")
		end
	end
	data.lastSeen = os.time()

	pushState(player)
end

local function onPlayerRemoving(player)
	local session = sessions[player]
	local data = PlayerData.get(player)
	if session and data then
		if session.carrying then
			finishSteal(player, false)
		end
		-- bank uncollected cash so nothing is lost
		for _, amount in pairs(session.pending) do
			data.cash = data.cash + amount
		end
	end
	sessions[player] = nil
	buckets[player] = nil
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
