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
local Players = game:GetService("Players")

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
		upgrades = { store = 0, slots = 0, luck = 0, auto = 0, charm = 0 },
		freePacks = 1,
		packsOpened = 0,
		rebirths = 0,
		vault = {}, -- array of cardKeys that survive a rebirth
		listings = {}, -- left over from the removed market; emptied back into the inventory on join
		perks = {}, -- Aura Shrine levels, kept through rebirths: [perkId] = level
		tower = 0, -- highest battle tower floor cleared
		battleDeck = {}, -- array of cardKeys to bring to tower duels (empty = pick automatically)
		challengeDay = 0, -- Quests.today() of the last daily challenge won
		titles = {}, -- [titleId] = true for titles earned (see Titles.luau)
		title = "", -- the title being worn, "" for none
		loadouts = {}, -- saved decks: [tostring(1..Config.Loadouts)] = array of cardKeys
		quests = { day = 0, list = {} }, -- today's quests, see Quests.luau
		daily = { lastDay = 0, streak = 0 }, -- daily login reward
		packCounts = {}, -- packs opened this run, per pack id (drives pack price; reset by rebirth)
		autoPack = { packId = "", on = false, sell = 0 }, -- Auto Packer settings
		achievements = {}, -- [achievementId] = true once claimed (permanent income bonus)
		stats = { fused = 0, earned = 0, duels = 0 }, -- lifetime counters (achievements, Auto battler unlock)
		gifts = 0, -- free boosters waiting to be opened (playtime and season rewards)
		codes = {}, -- [CODE] = true for codes already redeemed
		showcase = { left = "", right = "" }, -- cards chosen for the storefront frames ("" = automatic)
		boosts = { luckUntil = 0, cashUntil = 0 }, -- os.time() when bought potions run out
		receipts = {}, -- developer product PurchaseIds already granted
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
-- Returns true if the data is safely stored (or there is nothing to store).
function PlayerData.save(player, release)
	local profile = profiles[player]
	if profile == nil then
		return false
	end
	if not profile.canSave or store == nil then
		return true -- temporary Studio profile: nothing to save
	end
	local data = profile.data
	return withRetry(3, function()
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

-- Admins -------------------------------------------------------------------------------
-- One shared record, { [tostring(userId)] = name }, read by every server. Without a
-- DataStore (Studio with API access off) the list only lives in memory.
local ADMINS_KEY = "admins"
local memoryAdmins = {}

-- Returns the admin table, or nil if it could not be read.
function PlayerData.loadAdmins()
	if store == nil then
		return memoryAdmins
	end
	local result = nil
	local ok = withRetry(2, function()
		result = store:GetAsync(ADMINS_KEY)
	end)
	if not ok then
		return nil
	end
	return type(result) == "table" and result or {}
end

-- name = a string to make that user an admin, nil to remove them.
-- Returns the new admin table, or nil if it could not be saved.
function PlayerData.setAdmin(userId, name)
	local id = tostring(userId)
	if store == nil then
		memoryAdmins[id] = name
		return memoryAdmins
	end
	local result = nil
	local ok = withRetry(3, function()
		result = store:UpdateAsync(ADMINS_KEY, function(stored)
			local list = type(stored) == "table" and stored or {}
			list[id] = name
			return list
		end)
	end)
	if not ok or type(result) ~= "table" then
		return nil
	end
	return result
end

-- Global leaderboards --------------------------------------------------------------------
-- One OrderedDataStore per board, keyed by user id. Both calls are safe to fail: boards just
-- keep their old contents (Studio without API access has no stores at all).
local scoreStores: { [string]: any } = {}
local nameCache: { [number]: string } = {}
local sentScores = {} -- [player] = { [boardId] = last score written }

local function scoreStore(boardId)
	if scoreStores[boardId] == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(Config.DataStoreName .. "_Top_" .. boardId)
		end)
		scoreStores[boardId] = ok and result or false
	end
	return scoreStores[boardId] or nil
end

-- scores = { [boardId] = whole number }. Zero scores are not written.
function PlayerData.submitScores(player, scores)
	local profile = profiles[player]
	if profile == nil or not profile.canSave then
		return
	end
	nameCache[player.UserId] = player.DisplayName
	local sent = sentScores[player] or {}
	sentScores[player] = sent
	for boardId, score in pairs(scores) do
		score = math.floor(score)
		local boardStore = scoreStore(boardId)
		if boardStore and score > 0 and sent[boardId] ~= score then
			local ok = pcall(function()
				boardStore:SetAsync(tostring(player.UserId), score)
			end)
			if ok then
				sent[boardId] = score
			end
		end
	end
end

-- Returns { { name, score }, ... }, best first. Empty when the store cannot be read.
function PlayerData.topScores(boardId, count)
	local rows = {}
	local boardStore = scoreStore(boardId)
	if boardStore == nil then
		return rows
	end
	local ok, page = pcall(function()
		return boardStore:GetSortedAsync(false, count):GetCurrentPage()
	end)
	if not ok or type(page) ~= "table" then
		return rows
	end
	for _, entry in ipairs(page) do
		local userId = tonumber(entry.key)
		local name = userId and nameCache[userId]
		if userId and name == nil then
			local found, result = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			name = found and result or "Player"
			nameCache[userId] = name
		end
		table.insert(rows, { name = name or "Player", score = entry.value })
	end
	return rows
end

-- Wipes the player's progress back to a brand-new profile (keeps the session lock, so the
-- wiped profile is what gets saved when they leave).
function PlayerData.reset(player)
	local profile = profiles[player]
	if profile then
		local lock = profile.data.lock
		profile.data = newData()
		profile.data.lock = lock
	end
end

function PlayerData.release(player)
	if profiles[player] then
		PlayerData.save(player, true)
		profiles[player] = nil
		sentScores[player] = nil
	end
end

return PlayerData
