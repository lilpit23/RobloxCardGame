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
local Rebirth = require(Shared:WaitForChild("Rebirth"))
local Quests = require(Shared:WaitForChild("Quests"))

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
	upgrades = { store = 0, slots = 0, luck = 0, auto = 0 },
	freePacks = 0,
	rebirths = 0,
	vault = {},
	vaultSlots = 1,
	luck = 0,
	quests = { day = 0, list = {} },
	questRev = 0,
	daily = { lastDay = 0, streak = 0 },
	today = 0,
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
	Size = UDim2.new(0, 210, 0, 480),
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
-- First-minute hint at the top of the screen
local hintLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(0, 470, 0, 38),
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = "",
	TextColor3 = Color3.fromRGB(255, 225, 120),
	TextSize = 16,
	TextWrapped = true,
	Visible = false,
}, screen)
round(hintLabel, 10)
make("UIStroke", { Color = Color3.fromRGB(255, 225, 120), Thickness = 2 }, hintLabel)

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

-- Several packs at once: show everything in one grid, best cards first.
local function revealGrid(pulled, pack)
	revealing = true
	revealGui.Enabled = true
	cardHolder.Visible = false
	skipButton.Text = "Continue"

	local newCount, auraTotal = 0, 0
	local sorted = {}
	for _, entry in ipairs(pulled) do
		table.insert(sorted, entry)
		if entry.isNew then
			newCount = newCount + 1
		end
		auraTotal = auraTotal + (entry.auraBonus or 0)
	end
	table.sort(sorted, function(a, b)
		local incomeA, incomeB = Cards.getIncome(a.key), Cards.getIncome(b.key)
		if incomeA ~= incomeB then
			return incomeA > incomeB
		end
		return a.key < b.key
	end)

	revealTitle.Text = pack.name .. " x" .. math.floor(#pulled / Config.CardsPerPack)
	revealTitle.TextColor3 = COLORS.text
	local summary = newCount .. " new"
	if auraTotal > 0 then
		summary = summary .. "   +" .. Format.short(auraTotal) .. " aura"
	end
	revealSub.Text = summary
	revealHint.Text = ""

	local grid = make("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 88),
		Size = UDim2.new(1, 0, 1, -140),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, revealStage)
	make("UIGridLayout", {
		CellSize = UDim2.new(0, 88, 0, 123),
		CellPadding = UDim2.new(0, 9, 0, 9),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for order, entry in ipairs(sorted) do
		local cell = make("Frame", { BackgroundTransparency = 1, LayoutOrder = order }, grid)
		local holder = make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 3, 0, 3),
			Size = UDim2.new(1, -6, 1, -6),
		}, cell)
		CardView.new(entry.key).Parent = holder
		if entry.isNew then
			newLabel(cell, "NEW", UDim2.new(0, 0, 0, 0), UDim2.new(0, 36, 0, 15), {
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundTransparency = 0,
				BackgroundColor3 = COLORS.bad,
				ZIndex = 3,
			})
		end
	end

	clickSignal.Event:Wait()

	grid:Destroy()
	skipButton.Text = "Skip"
	cardHolder.Visible = true
	revealGui.Enabled = false
	revealing = false
end

local buying = false
local function buyPack(pack, count)
	if buying or revealing then
		return
	end
	buying = true
	local ok, result = pcall(function()
		return Remotes.BuyPack:InvokeServer(pack.id, count or 1)
	end)
	buying = false
	if ok and type(result) == "table" and result.ok then
		if #result.cards > Config.CardsPerPack then
			revealGrid(result.cards, pack)
		else
			revealCards(result.cards, pack)
		end
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
		total = total + Packs.adjustedWeight(pack, rarityName, state.luck)
	end
	local parts = {}
	for _, rarityName in ipairs(Cards.RarityOrder) do
		local weight = Packs.adjustedWeight(pack, rarityName, state.luck)
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

		newLabel(row, pack.name .. "  ·  " .. Packs.setsText(pack), UDim2.new(0, 68, 0, 8), UDim2.new(1, -240, 0, 24), {
			Font = Enum.Font.FredokaOne,
			TextSize = 20,
		})
		newLabel(row, oddsText(pack), UDim2.new(0, 68, 0, 34), UDim2.new(1, -240, 0, 42), {
			TextSize = 12,
			TextColor3 = COLORS.dim,
			TextYAlignment = Enum.TextYAlignment.Top,
		})

		local buttonPosition = UDim2.new(1, -160, 0, 8)
		local buttonSize = UDim2.new(0, 148, 0, 40)
		if tier >= pack.storeTier then
			-- bulk buttons under the main one
			local bulkColor = pack.currency == "aura" and Color3.fromRGB(150, 55, 135) or Color3.fromRGB(60, 105, 195)
			local x = -160
			for _, size in ipairs(Config.PackBulkSizes) do
				if size > 1 then
					newButton(row, "x" .. size, UDim2.new(1, x, 0, 52), UDim2.new(0, 72, 0, 26), bulkColor, function()
						buyPack(pack, size)
					end).TextSize = 14
					x = x + 76
				end
			end
		end
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
		local canFuse = nextVariant ~= nil and state.inventory[key] >= Config.FuseCount
		local canVault = #state.vault < state.vaultSlots
		-- third button row: Fuse and/or Vault share the width
		local fusePosition, fuseSize = UDim2.new(0, 4, 0, 203), UDim2.new(1, -8, 0, 32)
		local vaultPosition, vaultSize = fusePosition, fuseSize
		if canFuse and canVault then
			fuseSize = UDim2.new(0.5, -6, 0, 32)
			vaultPosition, vaultSize = UDim2.new(0.5, 2, 0, 203), UDim2.new(0.5, -6, 0, 32)
		end
		if canFuse then
			local fuseText = "Fuse → " .. Cards.Variants[nextVariant].name
			newButton(cell, fuseText, fusePosition, fuseSize, Color3.fromRGB(200, 70, 180), function()
				Remotes.FuseCard:FireServer(key)
			end).TextSize = 11
		end
		if canVault then
			newButton(cell, "🔐 Vault", vaultPosition, vaultSize, Color3.fromRGB(215, 160, 50), function()
				Remotes.VaultStore:FireServer(key)
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
	local bonus = math.floor(found * Config.CollectionBonusPerCard * 100 + 0.5)
	titleLabel.Text = "📖 Collection  (" .. found .. "/" .. total .. ")  +" .. bonus .. "% income"
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

-- Rebirth + vault -------------------------------------------------------------
local rebirthConfirmUntil = 0
local renderedRebirthSignature = ""

-- Which requirements are currently met, as a string like "1101".
local function rebirthSignature()
	local _, _, requirements = Rebirth.check(state)
	local parts = {}
	for _, requirement in ipairs(requirements) do
		table.insert(parts, requirement.met and "1" or "0")
	end
	return table.concat(parts)
end

panels.Rebirth = function()
	titleLabel.Text = "🌟 Rebirth  (" .. state.rebirths .. " so far)"
	useList()
	local level, ready, requirements = Rebirth.check(state)
	renderedRebirthSignature = rebirthSignature()

	local bonusRow = newRow(1, level and 64 or 40)
	newLabel(bonusRow, "Now:   " .. Rebirth.describeBonuses(state.rebirths), UDim2.new(0, 14, 0, 8), UDim2.new(1, -28, 0, 22), {
		TextSize = 15,
	})
	if level then
		newLabel(bonusRow, "Next:  " .. Rebirth.describeBonuses(state.rebirths + 1), UDim2.new(0, 14, 0, 34), UDim2.new(1, -28, 0, 22), {
			TextSize = 15,
			TextColor3 = Color3.fromRGB(255, 215, 90),
		})
	end

	if level then
		local lineHeight = 22
		local row = newRow(2, 44 + #requirements * lineHeight + 64)
		newLabel(row, "To rebirth you need:", UDim2.new(0, 14, 0, 8), UDim2.new(1, -28, 0, 24), {
			Font = Enum.Font.FredokaOne,
			TextSize = 19,
		})
		for index, requirement in ipairs(requirements) do
			newLabel(row, (requirement.met and "✅  " or "❌  ") .. requirement.text, UDim2.new(0, 18, 0, 36 + (index - 1) * lineHeight), UDim2.new(1, -36, 0, lineHeight), {
				TextSize = 14,
				TextColor3 = requirement.met and COLORS.cash or COLORS.dim,
			})
		end
		local bottom = 44 + #requirements * lineHeight
		newLabel(row, "Resets cash, aura, cards and every upgrade. Keeps your vault and collection book.", UDim2.new(0, 14, 0, bottom), UDim2.new(1, -200, 0, 52), {
			TextSize = 12,
			TextColor3 = COLORS.dim,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		local button
		button = newButton(row, ready and "REBIRTH" or "Not ready", UDim2.new(1, -170, 0, bottom), UDim2.new(0, 156, 0, 46), ready and Color3.fromRGB(215, 160, 50) or COLORS.locked, function()
			if not ready then
				return
			end
			if os.clock() < rebirthConfirmUntil then
				rebirthConfirmUntil = 0
				Remotes.Rebirth:FireServer()
			else
				rebirthConfirmUntil = os.clock() + 4
				button.Text = "Tap again to confirm"
				button.TextSize = 13
			end
		end)
	end

	local vaultRow = newRow(3, 262)
	newLabel(vaultRow, "🔐 Vault  (" .. #state.vault .. "/" .. state.vaultSlots .. ") — cards in here survive a rebirth. Add cards from My Cards.", UDim2.new(0, 14, 0, 6), UDim2.new(1, -28, 0, 22), {
		TextSize = 14,
	})
	local strip = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 34),
		Size = UDim2.new(1, -20, 0, 220),
	}, vaultRow)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, strip)
	for index = 1, state.vaultSlots do
		local key = state.vault[index]
		local cell = make("Frame", {
			BackgroundColor3 = Color3.fromRGB(30, 30, 44),
			BorderSizePixel = 0,
			Size = UDim2.new(0, 118, 0, 216),
			LayoutOrder = index,
		}, strip)
		round(cell, 8)
		if key then
			local holder = make("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 5, 0, 5),
				Size = UDim2.new(1, -10, 0, 151),
			}, cell)
			CardView.new(key).Parent = holder
			newButton(cell, "Take out", UDim2.new(0, 5, 0, 176), UDim2.new(1, -10, 0, 32), COLORS.locked, function()
				Remotes.VaultTake:FireServer(index)
			end).TextSize = 13
		else
			newLabel(cell, "Empty\nslot", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), {
				TextSize = 15,
				TextColor3 = COLORS.dim,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		end
	end
end

-- Quests + daily reward ----------------------------------------------------------
local renderedQuestRev = -1

-- True when there is something to claim (used for the "!" on the menu button).
local function hasClaimable()
	if state.today > 0 and state.daily.lastDay < state.today then
		return true
	end
	for _, quest in ipairs(state.quests.list) do
		if not quest.claimed and quest.progress >= quest.goal then
			return true
		end
	end
	return false
end

panels.Quests = function()
	titleLabel.Text = "🎯 Daily Quests"
	renderedQuestRev = state.questRev
	useList()
	local buttonPosition = UDim2.new(1, -160, 0, 14)
	local buttonSize = UDim2.new(0, 148, 0, 44)

	-- Daily login reward
	local dailyRow = newRow(1, 72)
	local claimedToday = state.daily.lastDay >= state.today
	local streak = state.daily.streak
	if not claimedToday and state.daily.lastDay ~= state.today - 1 then
		streak = 0 -- streak was broken
	end
	local nextStreak = claimedToday and streak or streak + 1
	newLabel(dailyRow, "📅 Daily Reward  ·  day " .. math.max(nextStreak, 1) .. " streak", UDim2.new(0, 14, 0, 8), UDim2.new(1, -190, 0, 24), {
		Font = Enum.Font.FredokaOne,
		TextSize = 19,
	})
	newLabel(dailyRow, "+" .. Format.short(Quests.dailyAura(math.max(nextStreak, 1), state.rebirths)) .. " aura and some cash. Grows every day up to day 7.", UDim2.new(0, 14, 0, 36), UDim2.new(1, -190, 0, 30), {
		TextSize = 13,
		TextColor3 = COLORS.dim,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	if claimedToday then
		newButton(dailyRow, "Tomorrow", buttonPosition, buttonSize, COLORS.locked, nil).AutoButtonColor = false
	else
		newButton(dailyRow, "Claim", buttonPosition, buttonSize, COLORS.good, function()
			Remotes.DailyClaim:FireServer()
		end)
	end

	for index, quest in ipairs(state.quests.list) do
		local row = newRow(1 + index, 72)
		local done = quest.progress >= quest.goal
		newLabel(row, Quests.describe(quest), UDim2.new(0, 14, 0, 8), UDim2.new(1, -190, 0, 24), {
			Font = Enum.Font.FredokaOne,
			TextSize = 18,
		})
		local bar = make("Frame", {
			Position = UDim2.new(0, 14, 0, 40),
			Size = UDim2.new(1, -190, 0, 18),
			BackgroundColor3 = Color3.fromRGB(25, 25, 35),
			BorderSizePixel = 0,
		}, row)
		round(bar, 6)
		local fill = make("Frame", {
			Size = UDim2.new(math.clamp(quest.progress / math.max(quest.goal, 1), 0, 1), 0, 1, 0),
			BackgroundColor3 = done and COLORS.good or COLORS.button,
			BorderSizePixel = 0,
		}, bar)
		round(fill, 6)
		newLabel(bar, Quests.progressText(quest) .. "   ·   +" .. Format.short(Quests.reward(state.rebirths)) .. " aura", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), {
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 2,
		})
		if quest.claimed then
			newButton(row, "Claimed ✓", buttonPosition, buttonSize, COLORS.locked, nil).AutoButtonColor = false
		elseif done then
			newButton(row, "Claim", buttonPosition, buttonSize, COLORS.good, function()
				Remotes.QuestClaim:FireServer(index)
			end)
		else
			newButton(row, "In progress", buttonPosition, buttonSize, COLORS.locked, nil).AutoButtonColor = false
		end
	end

	local footer = newRow(10, 30)
	footer.BackgroundTransparency = 1
	newLabel(footer, "New quests every day.", UDim2.new(0, 4, 0, 0), UDim2.new(1, -8, 1, 0), {
		TextSize = 13,
		TextColor3 = COLORS.dim,
	})
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
local questsButton = nil
local MENU = {
	{ "Packs", "🎴 Packs", Color3.fromRGB(225, 80, 120) },
	{ "Cards", "🃏 My Cards", COLORS.button },
	{ "Book", "📖 Collection", Color3.fromRGB(150, 95, 230) },
	{ "Upgrades", "🏪 Upgrades", COLORS.good },
	{ "Quests", "🎯 Quests", Color3.fromRGB(230, 120, 50) },
	{ "Rebirth", "🌟 Rebirth", Color3.fromRGB(215, 160, 50) },
}
for index, entry in ipairs(MENU) do
	local button = newButton(hud, entry[2], UDim2.new(), UDim2.new(1, 0, 0, 42), entry[3], function()
		openPanel(entry[1])
	end)
	button.LayoutOrder = 10 + index
	if entry[1] == "Packs" then
		packsButton = button
	elseif entry[1] == "Quests" then
		questsButton = button
	end
end

---------------------------------------------------------------------
-- State updates from the server
---------------------------------------------------------------------
-- What a brand-new player should do next, or "" once they have the hang of it.
local function tutorialHint()
	if state.rebirths > 0 then
		return ""
	end
	local owned = next(state.inventory) ~= nil
	local displayed = next(state.slots) ~= nil
	local discovered = 0
	for _ in pairs(state.collection) do
		discovered = discovered + 1
	end
	if state.freePacks > 0 and not owned and not displayed then
		return "🎁 Open your free pack — tap the FREE PACK button!"
	end
	if owned and not displayed then
		return "🃏 Open My Cards and tap Display Best to start earning"
	end
	if displayed and discovered < 8 and state.upgrades.auto < 1 and state.cash < 25 then
		return "💵 Walk over the green pads in your store to collect cash"
	end
	return ""
end

local function refreshHud()
	local hint = tutorialHint()
	hintLabel.Text = hint
	hintLabel.Visible = hint ~= ""
	cashLabel.Text = "💵 " .. Format.cash(state.cash)
	auraLabel.Text = "✨ " .. Format.short(state.aura) .. " Aura"
	local rate = "+" .. Format.cash(state.incomePerSec) .. "/s"
	if state.auraPerSec > 0 then
		rate = rate .. "   +" .. Format.short(state.auraPerSec) .. " aura/s"
	end
	rateLabel.Text = rate
	packsButton.Text = state.freePacks > 0 and "🎁 FREE PACK!" or "🎴 Packs"
	questsButton.Text = hasClaimable() and "🎯 Quests  ❗" or "🎯 Quests"
end

Remotes.State.OnClientEvent:Connect(function(newState)
	for key, value in pairs(newState) do
		state[key] = value
	end
	refreshHud()
	-- The rebirth checklist also refreshes when cash / aura crosses a requirement.
	local rebirthChanged = currentPanel == "Rebirth" and rebirthSignature() ~= renderedRebirthSignature
	local questsChanged = currentPanel == "Quests" and state.questRev ~= renderedQuestRev
	if currentPanel and (state.rev ~= renderedRev or rebirthChanged or questsChanged) then
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
