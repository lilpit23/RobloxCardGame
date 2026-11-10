-- Loads and saves player profiles with DataStoreService.
-- If loading fails (for example Studio without API access) the player gets a
-- temporary profile that is never saved, so real data is never overwritten.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlayerData = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)

local profiles = {} -- [player] = { data = table, canSave = boolean }

local function newData()
	return {
		cash = 0,
		aura = 0,
		inventory = {}, -- [cardKey] = count (cards not on display)
		slots = {}, -- [tostring(slotIndex)] = cardKey (cards on display)
		collection = {}, -- [cardKey] = true (every card ever owned)
		upgrades = { store = 0, slots = 0, luck = 0 },
		freePacks = 1,
		packsOpened = 0,
	}
end

local function reconcile(data)
	local defaults = newData()
	for key, value in pairs(defaults) do
		if data[key] == nil or type(data[key]) ~= type(value) then
			data[key] = value
		end
	end
	for key, value in pairs(defaults.upgrades) do
		if type(data.upgrades[key]) ~= "number" then
			data.upgrades[key] = value
		end
	end
	return data
end

local function keyFor(player)
	return "u_" .. player.UserId
end

function PlayerData.load(player)
	local data = nil
	local loaded = false
	if store then
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			loaded = true
			if type(result) == "table" then
				data = result
			end
		else
			warn("[AuraPacks] Could not load data for " .. player.Name .. ": " .. tostring(result))
		end
	end
	local profile = { data = reconcile(data or newData()), canSave = loaded }
	profiles[player] = profile
	return profile.data
end

function PlayerData.get(player)
	local profile = profiles[player]
	if profile then
		return profile.data
	end
	return nil
end

function PlayerData.save(player)
	local profile = profiles[player]
	if profile == nil or not profile.canSave or store == nil then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), profile.data)
	end)
	if not ok then
		warn("[AuraPacks] Could not save data for " .. player.Name .. ": " .. tostring(err))
	end
end

function PlayerData.release(player)
	if profiles[player] then
		PlayerData.save(player)
		profiles[player] = nil
	end
end

return PlayerData
