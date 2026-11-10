-- Aura Packs — client UI. Everything is built from code, so there is nothing to set up in Studio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cards = require(Shared:WaitForChild("Cards"))
local Packs = require(Shared:WaitForChild("Packs"))
local Upgrades = require(Shared:WaitForChild("Upgrades"))
local Format = require(Shared:WaitForChild("Format"))
local CardView = require(Shared:WaitForChild("CardView"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local state = {
	rev = 0,
	cash = 0,
	aura = 0,
	inventory = {},
	slots = {},
	collection = {},
	upgrades = { store = 0, slots = 0, luck = 0 },
	freePacks = 0,
	slotCount = Config.BaseSlots,
	incomePerSec = 0,
	auraPerSec = 0,
}

local COLORS = {
	panel = Color3.fromRGB(28, 28, 40),
	row = Color3.fromRGB(44, 44, 62),
	text = Color3.fromRGB(255, 255, 255),
	dim = Color3.fromRGB(175, 175, 195),
	cash = Color3.fromRGB(90, 220, 120),
	aura = Color3.fromRGB(240, 110, 220),
	button = Color3.fromRGB(80, 140, 255),
	good = Color3.fromRGB(70, 190, 100),
	bad = Color3.fromRGB(220, 75, 75),
	locked = Color3.fromRGB(95, 95, 110),
}

---------------------------------------------------------------------
-- Small UI helpers
---------------------------------------------------------------------
local function make(className, props, parent)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function round(instance, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, instance)
end

local function newLabel(parent, text, position, size, props)
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextColor3 = COLORS.text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, parent)
	if props then
		for key, value in pairs(props) do
			label[key] = value
		end
	end
	return label
end

local function newButton(parent, text, position, size, color, onClick)
	local button = make("TextButton", {
		Position = position,
		Size = size,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Font = Enum.Font.FredokaOne,
		Text = text,
		TextColor3 = COLORS.text,
		TextSize = 18,
		AutoButtonColor = true,
	}, parent)
	round(button, 8)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

local function addScale(instance)
	local scale = make("UIScale", {}, instance)
	local camera = workspace.CurrentCamera
	local function update()
		scale.Scale = math.clamp(camera.ViewportSize.Y / 720, 0.5, 1.25)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
	return scale
end

---------------------------------------------------------------------
-- Screen layout
---------------------------------------------------------------------
local screen = make("ScreenGui", {
	Name = "AuraPacksUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
}, playerGui)

-- HUD (left side)
local hud = make("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.new(0, 210, 0, 330),
}, screen)
addScale(hud)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, hud)

local function newPill(order, color)
	local pill = make("Frame", {
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = order,
	}, hud)
	round(pill, 12)
	make("UIStroke", { Color = color, Thickness = 2 }, pill)
	return newLabel(pill, "", UDim2.new(0, 12, 0, 0), UDim2.new(1, -24, 1, 0), {
		Font = Enum.Font.FredokaOne,
		TextSize = 22,
		TextColor3 = color,
	})
end

local cashLabel = newPill(1, COLORS.cash)
local auraLabel = newPill(2, COLORS.aura)
local rateLabel = newLabel(hud, "", UDim2.new(), UDim2.new(1, 0, 0, 18), {
	LayoutOrder = 3,
	TextSize = 13,
	TextColor3 = COLORS.text,
	TextStrokeTransparency = 0.3,
})

-- Window
local window = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 680, 0, 470),
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
	Visible = false,
}, screen)
round(window, 16)
make("UIStroke", { Color = Color3.fromRGB(90, 90, 120), Thickness = 2 }, window)
addScale(window)

local titleLabel = newLabel(window, "", UDim2.new(0, 18, 0, 8), UDim2.new(1, -260, 0, 40), {
	Font = Enum.Font.FredokaOne,
	TextSize = 26,
})
local actionButton = newButton(window, "", UDim2.new(1, -236, 0, 10), UDim2.new(0, 170, 0, 36), COLORS.good, nil)
actionButton.Visible = false
local closeButton = newButton(window, "X", UDim2.new(1, -54, 0, 10), UDim2.new(0, 40, 0, 36), COLORS.bad, nil)

local body = make("ScrollingFrame", {
	Position = UDim2.new(0, 14, 0, 58),
	Size = UDim2.new(1, -28, 1, -72),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 8,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, window)

-- Toast notifications
local toastHolder = make("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -90),
	Size = UDim2.new(0, 520, 0, 200),
}, screen)
make("UIListLayout", {
	Padding = UDim.new(0, 6),
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, toastHolder)

local TOAST_COLORS = { info = COLORS.button, good = COLORS.good, error = COLORS.bad, cash = COLORS.good }

local function toast(text, kind)
	local label = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = TOAST_COLORS[kind] or COLORS.button,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextColor3 = COLORS.text,
		TextSize = 16,
		TextWrapped = true,
	}, toastHolder)
	round(label, 10)
	task.delay(3.5, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
end

---------------------------------------------------------------------
-- Pack opening reveal
---------------------------------------------------------------------
local revealGui = make("ScreenGui", {
	Name = "AuraPacksReveal",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 20,
	Enabled = false,
}, playerGui)

local overlay = make("TextButton", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
}, revealGui)

local revealStage = make("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 600, 0, 560),
}, overlay)
addScale(revealStage)

local revealTitle = newLabel(revealStage, "", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 50), {
	Font = Enum.Font.FredokaOne,
	TextSize = 40,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 0,
})
local revealSub = newLabel(revealStage, "", UDim2.new(0, 0, 0, 52), UDim2.new(1, 0, 0, 28), {
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Color3.fromRGB(255, 230, 120),
})
local revealHint = newLabel(revealStage, "", UDim2.new(0, 0, 1, -60), UDim2.new(1, 0, 0, 24), {
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = COLORS.dim,
})

local CARD_W, CARD_H = 280, 392
local cardHolder = make("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 10),
	Size = UDim2.new(0, CARD_W, 0, CARD_H),
}, revealStage)

local clickSignal = Instance.new("BindableEvent")
local skipRequested = false
local revealing = false

overlay.Activated:Connect(function()
	clickSignal:Fire()
end)
local skipButton = newButton(revealStage, "Skip", UDim2.new(1, -110, 1, -32), UDim2.new(0, 100, 0, 32), COLORS.locked, function()
	skipRequested = true
	clickSignal:Fire()
end)
skipButton.ZIndex = 5

local function flipTo(build)
	local shrink = TweenService:Create(cardHolder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, CARD_H),
	})
	shrink:Play()
	shrink.Completed:Wait()
	cardHolder:ClearAllChildren()
	build().Parent = cardHolder
	local grow = TweenService:Create(cardHolder, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, CARD_W, 0, CARD_H),
	})
	grow:Play()
	grow.Completed:Wait()
end

local function newPackBack(pack)
	local back = make("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = pack.color,
		BorderSizePixel = 0,
	}, nil)
	round(back, 18)
	make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 4 }, back)
	newLabel(back, "🎴", UDim2.new(0, 0, 0.2, 0), UDim2.new(1, 0, 0.35, 0), {
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	newLabel(back, pack.name, UDim2.new(0.05, 0, 0.62, 0), UDim2.new(0.9, 0, 0.14, 0), {
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	return back
end

local function revealCards(pulled, pack)
	revealing = true
	skipRequested = false
	revealGui.Enabled = true

	for index, entry in ipairs(pulled) do
		if skipRequested then
			break
		end
		local def, variantId, variant = Cards.parse(entry.key)
		local rarity = Cards.Rarities[def.rarity]

		revealTitle.Text = pack.name
		revealTitle.TextColor3 = COLORS.text
		revealSub.Text = "Card " .. index .. " of " .. #pulled
		revealHint.Text = "Tap to flip"
		cardHolder:ClearAllChildren()
		cardHolder.Size = UDim2.new(0, CARD_W, 0, CARD_H)
		newPackBack(pack).Parent = cardHolder
		clickSignal.Event:Wait()
		if skipRequested then
			break
		end

		flipTo(function()
			return CardView.new(entry.key)
		end)

		local title = string.upper(def.rarity) .. "!"
		if variantId ~= "normal" then
			title = string.upper(variant.name) .. " " .. title
		end
		revealTitle.Text = title
		revealTitle.TextColor3 = def.rarity == "Secret" and Color3.fromRGB(255, 80, 80) or rarity.color
		local notes = {}
		if entry.isNew then
			table.insert(notes, "★ NEW CARD")
		end
		if entry.auraBonus and entry.auraBonus > 0 then
			table.insert(notes, "+" .. Format.short(entry.auraBonus) .. " aura")
		end
		revealSub.Text = table.concat(notes, "   ")
		revealHint.Text = "Tap to continue"

		if rarity.order >= 4 then
			-- big pull: punch the card
			cardHolder.Size = UDim2.new(0, CARD_W * 1.25, 0, CARD_H * 1.25)
			TweenService:Create(cardHolder, TweenInfo.new(0.35, Enum.EasingStyle.Bounce), {
				Size = UDim2.new(0, CARD_W, 0, CARD_H),
			}):Play()
		end
		clickSignal.Event:Wait()
	end

	cardHolder:ClearAllChildren()
	revealGui.Enabled = false
	revealing = false
end

local buying = false
local function buyPack(pack)
	if buying or revealing then
		return
	end
	buying = true
	local ok, result = pcall(function()
		return Remotes.BuyPack:InvokeServer(pack.id)
	end)
	buying = false
	if ok and type(result) == "table" and result.ok then
		revealCards(result.cards, pack)
	elseif ok and type(result) == "table" and result.error then
		toast(result.error, "error")
	else
		toast("Could not open the pack. Try again.", "error")
	end
end

---------------------------------------------------------------------
-- Panels
---------------------------------------------------------------------
local currentPanel = nil
local renderedRev = -1
local panels = {}

local function clearBody()
	for _, child in ipairs(body:GetChildren()) do
		child:Destroy()
	end
	actionButton.Visible = false
end

local function useList()
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)
end

local function useGrid(cellWidth, cellHeight)
	make("UIGridLayout", {
		CellSize = UDim2.new(0, cellWidth, 0, cellHeight),
		CellPadding = UDim2.new(0, 10, 0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, body)
end

local function newRow(order, height)
	local row = make("Frame", {
		Size = UDim2.new(1, -12, 0, height),
		BackgroundColor3 = COLORS.row,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, body)
	round(row, 10)
	return row
end

local function currencyText(currency, amount)
	if currency == "aura" then
		return Format.short(amount) .. " aura"
	end
	return Format.cash(amount)
end

-- Packs ---------------------------------------------------------------
local function oddsText(pack)
	local total = 0
	for _, rarityName in ipairs(Cards.RarityOrder) do
		total = total + Packs.adjustedWeight(pack, rarityName, state.upgrades.luck)
	end
	local parts = {}
	for _, rarityName in ipairs(Cards.RarityOrder) do
		local weight = Packs.adjustedWeight(pack, rarityName, state.upgrades.luck)
		if weight > 0 then
			local percent = weight / total * 100
			local text = percent >= 10 and string.format("%d%%", math.floor(percent + 0.5)) or string.format("%.2g%%", percent)
			table.insert(parts, rarityName .. " " .. text)
		end
	end
	return table.concat(parts, "  ·  ")
end

panels.Packs = function()
	titleLabel.Text = "🎴 Pack Shop"
	useList()
	local tier = state.upgrades.store + 1
	for order, pack in ipairs(Packs.List) do
		local row = newRow(order, 84)
		local swatch = make("Frame", {
			Position = UDim2.new(0, 10, 0, 10),
			Size = UDim2.new(0, 46, 0, 64),
			BackgroundColor3 = pack.color,
			BorderSizePixel = 0,
		}, row)
		round(swatch, 6)
		newLabel(swatch, "🎴", UDim2.new(), UDim2.new(1, 0, 1, 0), { TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center })

		newLabel(row, pack.name .. "  (" .. Config.CardsPerPack .. " cards)", UDim2.new(0, 68, 0, 8), UDim2.new(1, -240, 0, 24), {
			Font = Enum.Font.FredokaOne,
			TextSize = 20,
		})
		newLabel(row, oddsText(pack), UDim2.new(0, 68, 0, 34), UDim2.new(1, -240, 0, 42), {
			TextSize = 12,
			TextColor3 = COLORS.dim,
			TextYAlignment = Enum.TextYAlignment.Top,
		})

		local buttonPosition = UDim2.new(1, -160, 0, 20)
		local buttonSize = UDim2.new(0, 148, 0, 44)
		if tier < pack.storeTier then
			local locked = newButton(row, "🔒 " .. Upgrades.StoreTiers[pack.storeTier].name, buttonPosition, buttonSize, COLORS.locked, nil)
			locked.TextSize = 13
			locked.AutoButtonColor = false
		elseif pack.id == "starter" and state.freePacks > 0 then
			newButton(row, "FREE!", buttonPosition, buttonSize, COLORS.good, function()
				buyPack(pack)
			end)
		else
			local color = pack.currency == "aura" and Color3.fromRGB(200, 70, 180) or COLORS.button
			newButton(row, currencyText(pack.currency, pack.cost), buttonPosition, buttonSize, color, function()
				buyPack(pack)
			end)
		end
	end
end

-- Cards (inventory) ----------------------------------------------------
local function newCardCell(key, order)
	local cell = make("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, body)
	local holder = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 4, 0, 4),
		Size = UDim2.new(1, -8, 0, 157),
	}, cell)
	CardView.new(key).Parent = holder
	return cell
end

panels.Cards = function()
	local used = 0
	for index = 1, state.slotCount do
		if state.slots[tostring(index)] then
			used = used + 1
		end
	end
	titleLabel.Text = "🃏 My Cards  (" .. used .. "/" .. state.slotCount .. " on display)"
	actionButton.Text = "Display Best"
	actionButton.Visible = true
	useGrid(120, 241)

	local order = 0
	for index = 1, state.slotCount do
		local key = state.slots[tostring(index)]
		if key then
			order = order + 1
			local cell = newCardCell(key, order)
			newLabel(cell, "ON DISPLAY", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 16), {
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundTransparency = 0,
				BackgroundColor3 = COLORS.good,
				ZIndex = 3,
			})
			newButton(cell, "Remove", UDim2.new(0, 4, 0, 167), UDim2.new(1, -8, 0, 32), COLORS.locked, function()
				Remotes.RemoveCard:FireServer(index)
			end).TextSize = 14
		end
	end

	local keys = {}
	for key in pairs(state.inventory) do
		if Cards.parse(key) then
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

	for _, key in ipairs(keys) do
		order = order + 1
		local cell = newCardCell(key, order)
		newLabel(cell, "x" .. state.inventory[key], UDim2.new(1, -44, 0, 0), UDim2.new(0, 44, 0, 18), {
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(20, 20, 28),
			ZIndex = 3,
		})
		newButton(cell, "Display", UDim2.new(0, 4, 0, 167), UDim2.new(0.5, -6, 0, 32), COLORS.button, function()
			Remotes.PlaceCard:FireServer(key)
		end).TextSize = 13
		newButton(cell, "Sell " .. Format.cash(Cards.getSellValue(key, Config.SellMultiplier)), UDim2.new(0.5, 2, 0, 167), UDim2.new(0.5, -6, 0, 32), COLORS.bad, function()
			Remotes.SellCard:FireServer(key, 1)
		end).TextSize = 11

		local _, variantId = Cards.parse(key)
		local nextVariant = Cards.nextVariant(variantId)
		if nextVariant and state.inventory[key] >= Config.FuseCount then
			local fuseText = "Fuse " .. Config.FuseCount .. " → " .. Cards.Variants[nextVariant].name
			newButton(cell, fuseText, UDim2.new(0, 4, 0, 203), UDim2.new(1, -8, 0, 32), Color3.fromRGB(200, 70, 180), function()
				Remotes.FuseCard:FireServer(key)
			end).TextSize = 12
		end
	end

	if order == 0 then
		body:ClearAllChildren()
		newLabel(body, "No cards yet — open a pack from the Pack Shop!", UDim2.new(0, 0, 0, 20), UDim2.new(1, 0, 0, 40), {
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = COLORS.dim,
		})
	end
end

-- Collection book --------------------------------------------------------
panels.Book = function()
	useGrid(120, 190)
	local found, total = 0, 0
	for order, def in ipairs(Cards.List) do
		local best = nil
		local variantsFound = 0
		for _, variantId in ipairs(Cards.VariantOrder) do
			total = total + 1
			local key = Cards.makeKey(def.id, variantId)
			if state.collection[key] then
				found = found + 1
				variantsFound = variantsFound + 1
				best = key
			end
		end

		local cell = make("Frame", { BackgroundTransparency = 1, LayoutOrder = order }, body)
		local holder = make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 4, 0, 4),
			Size = UDim2.new(1, -8, 0, 157),
		}, cell)
		if best then
			CardView.new(best).Parent = holder
		else
			CardView.newUnknown(def).Parent = holder
		end
		newLabel(cell, "Variants " .. variantsFound .. "/" .. #Cards.VariantOrder, UDim2.new(0, 0, 0, 166), UDim2.new(1, 0, 0, 18), {
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = variantsFound == #Cards.VariantOrder and Color3.fromRGB(255, 215, 90) or COLORS.dim,
		})
	end
	titleLabel.Text = "📖 Collection Book  (" .. found .. "/" .. total .. ")"
end

-- Upgrades -----------------------------------------------------------------
panels.Upgrades = function()
	titleLabel.Text = "🏪 Store Upgrades"
	useList()
	for order, upgradeId in ipairs(Upgrades.Order) do
		local def = Upgrades.Defs[upgradeId]
		local level = state.upgrades[upgradeId] or 0
		local row = newRow(order, 84)
		newLabel(row, def.name .. "   Lv " .. level .. "/" .. def.max, UDim2.new(0, 14, 0, 8), UDim2.new(1, -190, 0, 24), {
			Font = Enum.Font.FredokaOne,
			TextSize = 20,
		})
		newLabel(row, def.describe(level), UDim2.new(0, 14, 0, 34), UDim2.new(1, -190, 0, 42), {
			TextSize = 13,
			TextColor3 = COLORS.dim,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		local buttonPosition = UDim2.new(1, -160, 0, 20)
		local buttonSize = UDim2.new(0, 148, 0, 44)
		if level >= def.max then
			newButton(row, "MAX", buttonPosition, buttonSize, COLORS.locked, nil).AutoButtonColor = false
		else
			local color = def.currency == "aura" and Color3.fromRGB(200, 70, 180) or COLORS.good
			newButton(row, currencyText(def.currency, def.cost(level)), buttonPosition, buttonSize, color, function()
				Remotes.BuyUpgrade:FireServer(upgradeId)
			end)
		end
	end
end

local function renderPanel()
	if currentPanel == nil then
		return
	end
	local scroll = body.CanvasPosition
	clearBody()
	panels[currentPanel]()
	renderedRev = state.rev
	body.CanvasPosition = scroll
end

local function openPanel(name)
	if currentPanel == name and window.Visible then
		window.Visible = false
		currentPanel = nil
		return
	end
	currentPanel = name
	body.CanvasPosition = Vector2.new(0, 0)
	window.Visible = true
	renderPanel()
end

closeButton.Activated:Connect(function()
	window.Visible = false
	currentPanel = nil
end)

actionButton.Activated:Connect(function()
	if currentPanel == "Cards" then
		Remotes.EquipBest:FireServer()
	end
end)

-- HUD menu buttons
local packsButton = nil
local MENU = {
	{ "Packs", "🎴 Packs", Color3.fromRGB(225, 80, 120) },
	{ "Cards", "🃏 My Cards", COLORS.button },
	{ "Book", "📖 Collection", Color3.fromRGB(150, 95, 230) },
	{ "Upgrades", "🏪 Upgrades", COLORS.good },
}
for index, entry in ipairs(MENU) do
	local button = newButton(hud, entry[2], UDim2.new(), UDim2.new(1, 0, 0, 42), entry[3], function()
		openPanel(entry[1])
	end)
	button.LayoutOrder = 10 + index
	if entry[1] == "Packs" then
		packsButton = button
	end
end

---------------------------------------------------------------------
-- State updates from the server
---------------------------------------------------------------------
local function refreshHud()
	cashLabel.Text = "💵 " .. Format.cash(state.cash)
	auraLabel.Text = "✨ " .. Format.short(state.aura) .. " Aura"
	local rate = "+" .. Format.cash(state.incomePerSec) .. "/s"
	if state.auraPerSec > 0 then
		rate = rate .. "   +" .. Format.short(state.auraPerSec) .. " aura/s"
	end
	rateLabel.Text = rate
	packsButton.Text = state.freePacks > 0 and "🎁 FREE PACK!" or "🎴 Packs"
end

Remotes.State.OnClientEvent:Connect(function(newState)
	for key, value in pairs(newState) do
		state[key] = value
	end
	refreshHud()
	if currentPanel and state.rev ~= renderedRev then
		renderPanel()
	end
end)

Remotes.Notify.OnClientEvent:Connect(function(text, kind)
	toast(tostring(text), kind)
end)

Remotes.OpenShop.OnClientEvent:Connect(function()
	if currentPanel ~= "Packs" or not window.Visible then
		openPanel("Packs")
	end
end)

refreshHud()
Remotes:WaitForChild("RequestState"):FireServer()
