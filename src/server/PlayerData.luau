-- Player profiles: load, autosave, release.
--  * every DataStore call is retried with backoff
--  * all reads/writes go through UpdateAsync
--  * session lock: only one server owns a profile at a time (stops item dupes)
--  * if the load fails on a live server the player is NOT given a blank profile
--    (PlayerData.load returns nil and the caller kicks them)
-- Gameplay code only touches the in-memory table from PlayerData.get.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlayerData = {}

local CURRENT_VERSION = 1
-- A lock older than this belongs to a crashed server and can be taken over.
local LOCK_STALE_SECONDS = Config.AutosaveInterval * 2 + 30
local LOCK_WAIT_ATTEMPTS = 4

-- Add a function here whenever the saved shape changes: MIGRATIONS[n] upgrades v(n) to v(n+1).
local MIGRATIONS = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)

local profiles = {} -- [player] = { data = table, canSave = boolean }

local function newData()
	return {
		version = CURRENT_VERSION,
		cash = 0,
		aura = 0,
		inventory = {}, -- [cardKey] = count (cards not on display)
		slots = {}, -- [tostring(slotIndex)] = cardKey (cards on display)
		collection = {}, -- [cardKey] = true (every card ever owned)
		upgrades = { store = 0, slots = 0, luck = 0 },
		freePacks = 1,
		packsOpened = 0,
		rebirths = 0,
		vault = {}, -- array of cardKeys that survive a rebirth
		lastSeen = 0, -- os.time() of the last save, for offline earnings
	}
end

local function migrate(data)
	if type(data.version) ~= "number" then
		data.version = 1
	end
	while data.version < CURRENT_VERSION do
		local step = MIGRATIONS[data.version]
		if step == nil then
			error("missing migration from v" .. data.version)
		end
		data = step(data)
		data.version = data.version + 1
	end
	return data
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

local function withRetry(attempts, fn)
	local delaySeconds = 1
	for attempt = 1, attempts do
		local ok, err = pcall(fn)
		if ok then
			return true
		end
		warn("[AuraPacks] DataStore attempt " .. attempt .. "/" .. attempts .. " failed: " .. tostring(err))
		if attempt < attempts then
			task.wait(delaySeconds)
			delaySeconds = math.min(delaySeconds * 2, 8)
		end
	end
	return false
end

local function lockedByOtherServer(stored, now)
	local lock = type(stored) == "table" and stored.lock or nil
	if type(lock) ~= "table" then
		return false
	end
	return lock.jobId ~= game.JobId and now - (tonumber(lock.time) or 0) < LOCK_STALE_SECONDS
end

-- Returns the profile data, or nil plus a message to show the player.
function PlayerData.load(player)
	local key = keyFor(player)
	local loaded = nil
	local callsOk = store ~= nil

	if store then
		for attempt = 1, LOCK_WAIT_ATTEMPTS do
			local claimed = nil
			callsOk = withRetry(3, function()
				store:UpdateAsync(key, function(stored)
					local now = os.time()
					if lockedByOtherServer(stored, now) then
						claimed = nil
						return nil -- leave it alone; another server still owns it
					end
					if type(stored) ~= "table" then
						stored = newData()
					end
					stored.lock = { jobId = game.JobId, time = now }
					claimed = stored
					return stored
				end)
			end)
			if not callsOk or claimed then
				loaded = claimed
				break
			end
			if attempt < LOCK_WAIT_ATTEMPTS then
				task.wait(4) -- the other server is probably finishing its last save
			end
		end
	end

	if loaded then
		local ok, result = pcall(function()
			return reconcile(migrate(loaded))
		end)
		if not ok then
			warn("[AuraPacks] Could not migrate data for " .. player.Name .. ": " .. tostring(result))
			return nil, "Your data could not be loaded. Please rejoin."
		end
		profiles[player] = { data = result, canSave = true }
		return result
	end

	if RunService:IsStudio() then
		-- Studio without API access: play with a temporary profile that is never saved.
		warn("[AuraPacks] Using a temporary, unsaved profile for " .. player.Name)
		profiles[player] = { data = newData(), canSave = false }
		return profiles[player].data
	end

	if callsOk then
		return nil, "Your data is still saving from your last server. Please rejoin in a moment."
	end
	return nil, "Your data could not be loaded. Please rejoin."
end

function PlayerData.get(player)
	local profile = profiles[player]
	if profile then
		return profile.data
	end
	return nil
end

-- release = true on the final save: clears the session lock so another server can load.
function PlayerData.save(player, release)
	local profile = profiles[player]
	if profile == nil or not profile.canSave or store == nil then
		return
	end
	local data = profile.data
	withRetry(3, function()
		store:UpdateAsync(keyFor(player), function(stored)
			local now = os.time()
			if lockedByOtherServer(stored, now) then
				return nil -- we lost ownership; never overwrite another server's data
			end
			data.lastSeen = now
			if release then
				data.lock = nil
			else
				data.lock = { jobId = game.JobId, time = now }
			end
			return data
		end)
	end)
end

function PlayerData.release(player)
	if profiles[player] then
		PlayerData.save(player, true)
		profiles[player] = nil
	end
end

return PlayerData
