-- Game passes and developer products. Nothing is on sale until real ids are put in
-- Config.Monetization (an id of 0 means "not created yet").
--   * Passes are checked with MarketplaceService when a player joins and when a purchase
--     prompt finishes.
--   * Products are granted in ProcessReceipt; each PurchaseId is recorded in the player's
--     profile so a receipt is never granted twice.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local SETTINGS = Config.Monetization

local Monetization = {}

local owned = {} -- [player] = { [passKey] = true }

-- Asks Roblox which passes the player owns. Yields. Returns the flags table.
function Monetization.load(player)
	local flags = {}
	for key, pass in pairs(SETTINGS.Passes) do
		if pass.id > 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and has then
				flags[key] = true
			end
		end
	end
	owned[player] = flags
	return flags
end

function Monetization.get(player)
	return owned[player] or {}
end

function Monetization.forget(player)
	owned[player] = nil
end

-- True where paid random items are restricted (some countries / ages). Aura can buy random
-- packs, so aura bundles are hidden from these players. When unsure, treat as restricted.
function Monetization.isRestricted(player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if ok and type(info) == "table" then
		return info.ArePaidRandomItemsRestricted == true
	end
	return true
end

-- hooks.onPassChanged(player)              a pass was just bought
-- hooks.grantProduct(player, data, product) give the product's contents
function Monetization.init(hooks)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in pairs(SETTINGS.Passes) do
			if pass.id > 0 and pass.id == passId then
				local flags = owned[player]
				if flags == nil then
					flags = {}
					owned[player] = flags
				end
				flags[key] = true
				hooks.onPassChanged(player)
			end
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local data = player and PlayerData.get(player)
		if player == nil or data == nil then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if data.receipts[receipt.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local product = nil
		for _, candidate in pairs(SETTINGS.Products) do
			if candidate.id > 0 and candidate.id == receipt.ProductId then
				product = candidate
			end
		end
		if product == nil then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		hooks.grantProduct(player, data, product)
		data.receipts[receipt.PurchaseId] = os.time()
		-- Only tell Roblox the purchase is done once it is saved. If the save fails Roblox
		-- will call again; the receipt recorded above stops a second grant.
		if PlayerData.save(player, false) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return Monetization
