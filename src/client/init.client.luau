-- Aura Packs — client UI. Everything is built from code, so there is nothing to set up in Studio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cards = require(Shared:WaitForChild("Cards"))
local Packs = require(Shared:WaitForChild("Packs"))
local Upgrades = require(Shared:WaitForChild("Upgrades"))
local Format = require(Shared:WaitForChild("Format"))
local CardView = require(Shared:WaitForChild("CardView"))
local Rebirth = require(Shared:WaitForChild("Rebirth"))
local Quests = require(Shared:WaitForChild("Quests"))
local Perks = require(Shared:WaitForChild("Perks"))
local Combos = require(Shared:WaitForChild("Combos"))
local Luck = require(Shared:WaitForChild("Luck"))
local Season = require(Shared:WaitForChild("Season"))
local Achievements = require(Shared:WaitForChild("Achievements"))
local Battle = require(Shared:WaitForChild("Battle"))

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
	upgrades = { store = 0, slots = 0, luck = 0, auto = 0, charm = 0 },
	freePacks = 0,
	rebirths = 0,
	vault = {},
	vaultSlots = 1,
	luck = 0,
	quests = { day = 0, list = {} },
	questRev = 0,
	daily = { lastDay = 0, streak = 0 },
	today = 0,
	gifts = 0,
	featuredSet = "",
	passes = {},
	restricted = true,
	isOwner = false,
	perks = {},
	tower = 0,
	luckEventEndsAt = 0,
	slotCount = Config.BaseSlots,
	incomePerSec = 0,
	cashCap = math.huge,
	boosts = { luckUntil = 0, cashUntil = 0 },
	showcase = { left = "", right = "" },
	packsOpened = 0,
	stats = { fused = 0, earned = 0 },
	achievements = {},
	packCounts = {},
	autoPack = { packId = "", on = false, sell = 0 },
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
	Size = UDim2.new(0, 210, 0, 440),
}, screen)
addScale(hud)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, hud)

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
local autoLabel = newLabel(hud, "", UDim2.new(), UDim2.new(1, 0, 0, 16), {
	LayoutOrder = 4,
	TextSize = 12,
	TextStrokeTransparency = 0.3,
	TextWrapped = false,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Visible = false,
})
local controlsLabel = newLabel(hud, "", UDim2.new(), UDim2.new(1, 0, 0, 28), {
	LayoutOrder = 30,
	TextSize = 11,
	TextColor3 = COLORS.text,
	TextStrokeTransparency = 0.3,
	TextYAlignment = Enum.TextYAlignment.Top,
})
local rateLabel = newLabel(hud, "", UDim2.new(), UDim2.new(1, 0, 0, 68), {
	TextYAlignment = Enum.TextYAlignment.Top,
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
-- Hint banner at the top of the screen: big white text on a dark box with a yellow border
local hintLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.new(0, 680, 0, 54),
	BackgroundColor3 = Color3.fromRGB(16, 16, 24),
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 21,
	TextWrapped = true,
	Visible = false,
}, screen)
round(hintLabel, 12)
make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, hintLabel)
-- the stroke must be on the border: left on its default it outlines every letter instead
make("UIStroke", {
	Color = Color3.fromRGB(255, 215, 90),
	Thickness = 3,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, hintLabel)
addScale(hintLabel)

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
	SortOrder = Enum.SortOrder.LayoutOrder,
}, toastHolder)

local TOAST_COLORS = {
	info = COLORS.button,
	good = COLORS.good,
	error = COLORS.bad,
	cash = COLORS.good,
	announce = Color3.fromRGB(215, 150, 30),
}

local MAX_TOASTS = 5
local toasts = {} -- oldest first
local toastOrder = 0

local function toast(text, kind)
	-- never more than MAX_TOASTS on screen: the oldest makes room
	while #toasts >= MAX_TOASTS do
		local oldest = table.remove(toasts, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	toastOrder = toastOrder + 1
	local label = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = TOAST_COLORS[kind] or COLORS.button,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextColor3 = COLORS.text,
		TextSize = 16,
		TextWrapped = true,
		LayoutOrder = toastOrder,
	}, toastHolder)
	round(label, 10)
	table.insert(toasts, label)
	task.delay(3.5, function()
		if label.Parent == nil then
			return -- already pushed out by newer messages
		end
		local tween = TweenService:Create(label, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		local index = table.find(toasts, label)
		if index then
			table.remove(toasts, index)
		end
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

-- Sounds come from Config.Sounds; a missing or empty id just plays nothing.
local sounds = {}
local function playSound(name)
	local id = Config.Sounds[name]
	if id == nil or id == "" then
		return
	end
	local sound = sounds[name]
	if sound == nil then
		sound = make("Sound", { SoundId = id, Volume = 0.6 }, SoundService)
		sounds[name] = sound
	end
	SoundService:PlayLocalSound(sound)
end

-- Full-screen colour flash for big pulls.
local function flashScreen(color)
	local flash = make("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, overlay)
	local tween = TweenService:Create(flash, TweenInfo.new(0.7), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		flash:Destroy()
	end)
end

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

-- Covers a frame with the pack's cover art when the pack has an image id.
local function addPackImage(parent, pack)
	if pack.image then
		make("ImageLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Image = pack.image,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 2,
		}, parent)
	end
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
	addPackImage(back, pack)
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

		if rarity.order >= 5 then
			playSound("bigPull")
			flashScreen(rarity.color)
		else
			playSound("flip")
		end
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

	revealTitle.Text = pack.name .. " x" .. math.floor(#pulled / pack.size)
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

-- Wobbles a GUI object left and right.
local function shakeRotation(object, degrees, times, stepTime)
	for index = 1, times do
		object.Rotation = index % 2 == 0 and degrees or -degrees
		task.wait(stepTime)
	end
	object.Rotation = 0
end

-- Rattles the whole reveal stage (big pulls only).
local function shakeScreen(intensity)
	local home = revealStage.Position
	for _ = 1, 8 do
		revealStage.Position = home + UDim2.new(0, math.random(-intensity, intensity), 0, math.random(-intensity, intensity))
		task.wait(0.03)
	end
	revealStage.Position = home
end

-- The pack wobbles (harder the better its best card is), then bursts open.
local function playPackOpening(pack, pulled)
	revealing = true
	revealGui.Enabled = true
	cardHolder.Visible = true
	cardHolder:ClearAllChildren()
	cardHolder.Size = UDim2.new(0, CARD_W, 0, CARD_H)
	newPackBack(pack).Parent = cardHolder
	revealTitle.Text = pack.name
	revealTitle.TextColor3 = COLORS.text
	revealSub.Text = ""
	revealHint.Text = "Opening…"

	local best, bestColor = 1, COLORS.text
	for _, entry in ipairs(pulled) do
		local def = Cards.parse(entry.key)
		if def then
			local rarity = Cards.Rarities[def.rarity]
			if rarity.order > best then
				best = rarity.order
				bestColor = def.rarity == "Secret" and Color3.fromRGB(255, 80, 80) or rarity.color
			end
		end
	end

	playSound("click")
	shakeRotation(cardHolder, 3, 6, 0.06)
	if best >= 4 then
		shakeRotation(cardHolder, 6, 8, 0.045)
	end
	if best >= 5 then
		shakeRotation(cardHolder, 10, 10, 0.035)
	end

	if best >= 3 then
		flashScreen(bestColor)
	end
	playSound(best >= 5 and "bigPull" or "flip")
	local burst = TweenService:Create(cardHolder, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, CARD_W * 1.4, 0, 0),
	})
	burst:Play()
	burst.Completed:Wait()
	cardHolder:ClearAllChildren()
	cardHolder.Size = UDim2.new(0, CARD_W, 0, CARD_H)
	if best >= 5 then
		shakeScreen(best >= 6 and 14 or 8)
	end
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
		playPackOpening(pack, result.cards)
		if #result.cards > pack.size then
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
local renderPanel -- defined below; panels call it to refresh themselves
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
panels.Packs = function()
	titleLabel.Text = "🎴 Pack Shop"
	useList()
	local tier = state.upgrades.store + 1

	-- Auto Packer: opens the chosen pack on a timer (an Aura Shrine perk)
	local packerInterval = Perks.packerInterval(state.perks)
	local autoRow = newRow(0, 60)
	autoRow.BackgroundColor3 = Color3.fromRGB(38, 58, 82)
	if packerInterval == nil then
		newLabel(autoRow, "🤖 Auto Packer — opens packs for you while you play. Unlock it in Upgrades → Aura Shrine.", UDim2.new(0, 14, 0, 0), UDim2.new(1, -28, 1, 0), { TextSize = 14 })
	else
		local autoPack = Packs.ById[state.autoPack.packId]
		local chosen = autoPack and autoPack.name or "tap 🤖 on a pack below to choose"
		newLabel(autoRow, "🤖 Auto Packer:  " .. chosen .. "\nOne pack every " .. packerInterval .. " seconds. Prices still rise with every pack.", UDim2.new(0, 14, 0, 0), UDim2.new(1, -190, 1, 0), { TextSize = 13 })
		local isOn = state.autoPack.on
		newButton(autoRow, isOn and "ON" or "OFF", UDim2.new(1, -164, 0, 10), UDim2.new(0, 66, 0, 40), isOn and COLORS.good or COLORS.locked, function()
			Remotes.AutoPackSet:FireServer(state.autoPack.packId, not isOn, state.autoPack.sell)
		end)
		local SELL_LABELS = { "Keep all", "Sell spare C", "Sell spare C+U", "Sell spare ≤R" }
		newButton(autoRow, SELL_LABELS[state.autoPack.sell + 1] or "Keep all", UDim2.new(1, -92, 0, 10), UDim2.new(0, 84, 0, 40), COLORS.row, function()
			Remotes.AutoPackSet:FireServer(state.autoPack.packId, isOn, (state.autoPack.sell + 1) % (Config.AutoSellMax + 1))
		end).TextSize = 11
	end
	for order, pack in ipairs(Packs.List) do
		local row = newRow(order, 100)
		local swatch = make("Frame", {
			Position = UDim2.new(0, 10, 0, 12),
			Size = UDim2.new(0, 54, 0, 76),
			BackgroundColor3 = pack.color,
			BorderSizePixel = 0,
		}, row)
		round(swatch, 6)
		newLabel(swatch, "🎴", UDim2.new(), UDim2.new(1, 0, 1, 0), { TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center })
		addPackImage(swatch, pack)

		local featured = pack.sets ~= nil and table.find(pack.sets, state.featuredSet) ~= nil
		local packLuck = state.luck + (featured and Season.FeaturedLuck or 0)
		local title = pack.name .. "  ·  " .. pack.size .. " cards"
		if featured then
			title = "⭐ " .. title .. "  ·  FEATURED +" .. (Season.FeaturedLuck * 10) .. "% luck"
		end
		if pack.sets == nil then
			title = title .. "  ·  all sets"
		end
		newLabel(row, title, UDim2.new(0, 76, 0, 6), UDim2.new(1, -292, 0, 24), {
			Font = Enum.Font.FredokaOne,
			TextSize = 19,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		newLabel(row, table.concat(Packs.oddsLines(pack, packLuck), "\n"), UDim2.new(0, 76, 0, 32), UDim2.new(1, -292, 0, 64), {
			TextSize = 12,
			TextColor3 = COLORS.dim,
			TextYAlignment = Enum.TextYAlignment.Top,
		})

		local buttonPosition = UDim2.new(1, -160, 0, 14)
		local buttonSize = UDim2.new(0, 148, 0, 40)
		if tier >= pack.storeTier then
			-- choose this pack for the Auto Packer
			if packerInterval and pack.currency == "cash" then
				local selected = state.autoPack.packId == pack.id
				newButton(row, "🤖", UDim2.new(1, -204, 0, 14), UDim2.new(0, 38, 0, 40), selected and COLORS.good or COLORS.locked, function()
					Remotes.AutoPackSet:FireServer(selected and "" or pack.id, not selected, state.autoPack.sell)
				end)
			end
			-- bulk buttons under the main one
			local bulkColor = pack.currency == "aura" and Color3.fromRGB(150, 55, 135) or Color3.fromRGB(60, 105, 195)
			local x = -160
			for _, size in ipairs(Config.PackBulkSizes) do
				if size > 1 then
					newButton(row, "x" .. size, UDim2.new(1, x, 0, 60), UDim2.new(0, 46, 0, 26), bulkColor, function()
						buyPack(pack, size)
					end).TextSize = 14
					x = x + 50
				end
			end
			-- x10 is a game pass perk; without the pass the button leads to the Store
			if state.passes["megaOpen"] then
				newButton(row, "x" .. Config.PassBulkSize, UDim2.new(1, x, 0, 60), UDim2.new(0, 48, 0, 26), Color3.fromRGB(120, 80, 200), function()
					buyPack(pack, Config.PassBulkSize)
				end).TextSize = 14
			else
				newButton(row, "x" .. Config.PassBulkSize .. " 💎", UDim2.new(1, x, 0, 60), UDim2.new(0, 48, 0, 26), COLORS.locked, function()
					currentPanel = "Store"
					body.CanvasPosition = Vector2.new(0, 0)
					renderPanel()
				end).TextSize = 11
			end
		end
		if tier < pack.storeTier then
			local locked = newButton(row, "🔒 " .. Upgrades.StoreTiers[pack.storeTier].name, buttonPosition, buttonSize, COLORS.locked, nil)
			locked.TextSize = 13
			locked.AutoButtonColor = false
		elseif (pack.id == Packs.StarterId and state.freePacks > 0) or (pack.kind == "booster" and state.gifts > 0) then
			newButton(row, "FREE 🎁", buttonPosition, buttonSize, COLORS.good, function()
				buyPack(pack)
			end)
		else
			local color = pack.currency == "aura" and Color3.fromRGB(200, 70, 180) or COLORS.button
			newButton(row, currencyText(pack.currency, Packs.price(pack, state.packCounts[pack.id], 1, state.perks)), buttonPosition, buttonSize, color, function()
				buyPack(pack)
			end)
		end
	end
end

-- Deck + cards ----------------------------------------------------------
local function newCardCell(parent, key, order)
	local cell = make("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	local holder = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 4, 0, 4),
		Size = UDim2.new(1, -8, 0, 157),
	}, cell)
	CardView.new(key).Parent = holder
	return cell
end

-- "Shiny: x2 cash   ·   Slimy: x1.5 cash, +2% deck cash   ·   ..."
local function effectsGuide()
	local parts = {}
	for _, variantId in ipairs(Cards.VariantOrder) do
		if variantId ~= "normal" then
			table.insert(parts, Cards.Variants[variantId].name .. ": " .. Cards.effectText(variantId))
		end
	end
	return table.concat(parts, "   ·   ")
end

-- What the collection book is showing (declared here because the Deck screen can jump to it).
local bookSet = Cards.SetOrder[1] -- a set id, or "combos" for the combo book
local bookCard = nil -- card id being looked at in detail, or nil for the binder page

-- How the Deck screen is sorted and filtered.
local deckSort = "income"
local deckSetFilter = "all" -- a set id, or "all"

local SORTS = {
	{ "income", "💰 Income" },
	{ "rarity", "⭐ Rarity" },
	{ "set", "📚 Set" },
	{ "name", "🔤 Name" },
	{ "effect", "✨ Effect" },
	{ "copies", "🔢 Copies" },
}

-- A number to sort a card by for the chosen sort (bigger first), with name as a tie-break.
local function sortValue(key)
	local def, variantId = Cards.parse(key)
	if deckSort == "rarity" then
		return Cards.Rarities[def.rarity].order * 1e9 + Cards.getIncome(key)
	elseif deckSort == "set" then
		return -(table.find(Cards.SetOrder, def.set) * 1000 + def.number)
	elseif deckSort == "effect" then
		return table.find(Cards.VariantOrder, variantId) * 1e12 + Cards.getIncome(key)
	elseif deckSort == "copies" then
		return state.inventory[key] or 0
	end
	return Cards.getIncome(key)
end

local function sortKeys(a, b)
	if deckSort == "name" then
		local nameA, nameB = Cards.getDisplayName(a), Cards.getDisplayName(b)
		if nameA ~= nameB then
			return nameA < nameB
		end
		return a < b
	end
	local valueA, valueB = sortValue(a), sortValue(b)
	if valueA ~= valueB then
		return valueA > valueB
	end
	return a < b
end

local function passesFilter(key)
	local def = Cards.parse(key)
	return def ~= nil and (deckSetFilter == "all" or def.set == deckSetFilter)
end

panels.Cards = function()
	local used = 0
	for index = 1, state.slotCount do
		if state.slots[tostring(index)] then
			used = used + 1
		end
	end
	titleLabel.Text = "🃏 Active Deck  (" .. used .. "/" .. state.slotCount .. " slots)"
	actionButton.Text = "Auto-fill Deck"
	actionButton.Visible = true
	useList()

	-- Combos: what the current deck switches on, and story combos that are close
	local combos = Combos.evaluate(state.slots)
	local lines = {}
	for _, combo in ipairs(combos.active) do
		table.insert(lines, "✅ " .. combo.name .. "   " .. combo.text)
	end
	if #lines == 0 then
		table.insert(lines, "No combos yet. Put 3 cards of one type, 4 from one set, or a story group in your deck.")
	end
	for index = 1, math.min(3, #combos.progress) do
		local entry = combos.progress[index]
		table.insert(lines, "▫️ " .. entry.name .. "  " .. entry.have .. "/" .. entry.need .. "   (" .. entry.text .. ")")
	end
	local comboRow = newRow(1, 40 + #lines * 18)
	local summary = "Combos:  x" .. string.format("%.2f", combos.income) .. " cash"
	if combos.aura > 1 then
		summary = summary .. "  ·  x" .. string.format("%.2f", combos.aura) .. " aura"
	end
	if combos.luck > 0 then
		summary = summary .. "  ·  +" .. combos.luck .. " luck"
	end
	newLabel(comboRow, summary, UDim2.new(0, 14, 0, 6), UDim2.new(1, -28, 0, 22), {
		Font = Enum.Font.FredokaOne,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 215, 90),
	})
	newLabel(comboRow, table.concat(lines, "\n"), UDim2.new(0, 14, 0, 32), UDim2.new(1, -28, 0, #lines * 18), {
		TextSize = 13,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local toolsRow = newRow(3, 44)
	toolsRow.BackgroundTransparency = 1
	newButton(toolsRow, "⚗️ Fuse all spares", UDim2.new(0, 0, 0, 2), UDim2.new(1 / 3, -4, 0, 38), Color3.fromRGB(200, 70, 180), function()
		Remotes.FuseAll:FireServer()
	end).TextSize = 14
	newButton(toolsRow, "💰 Sell spares (keep 3)", UDim2.new(1 / 3, 2, 0, 2), UDim2.new(1 / 3, -4, 0, 38), COLORS.bad, function()
		Remotes.SellSpares:FireServer()
	end).TextSize = 14
	newButton(toolsRow, "📜 Pick a combo", UDim2.new(2 / 3, 4, 0, 2), UDim2.new(1 / 3, -4, 0, 38), Color3.fromRGB(150, 95, 230), function()
		-- the combo book lists every combo with an "Add to deck" button
		bookSet = "combos"
		bookCard = nil
		currentPanel = "Book"
		body.CanvasPosition = Vector2.new(0, 0)
		renderPanel()
	end).TextSize = 14

	-- sort and filter
	local sortRow = newRow(4, 40)
	sortRow.BackgroundTransparency = 1
	for index, sort in ipairs(SORTS) do
		newButton(sortRow, sort[2], UDim2.new(0, (index - 1) * 80, 0, 2), UDim2.new(0, 76, 0, 34), deckSort == sort[1] and COLORS.button or COLORS.row, function()
			deckSort = sort[1]
			renderPanel()
		end).TextSize = 12
	end
	local filterSet = Cards.Sets[deckSetFilter]
	newButton(sortRow, filterSet and (filterSet.icon .. " " .. filterSet.code .. " only") or "All sets", UDim2.new(0, #SORTS * 80 + 6, 0, 2), UDim2.new(1, -(#SORTS * 80 + 6), 0, 34), filterSet and COLORS.good or COLORS.row, function()
		-- step through: all sets, then each set in turn
		local position = table.find(Cards.SetOrder, deckSetFilter) or 0
		deckSetFilter = Cards.SetOrder[position + 1] or "all"
		renderPanel()
	end).TextSize = 12

	local guideRow = newRow(2, 58)
	newLabel(guideRow, "Card effects  —  " .. effectsGuide(), UDim2.new(0, 14, 0, 4), UDim2.new(1, -28, 1, -8), {
		TextSize = 12,
		TextColor3 = COLORS.dim,
	})

	-- the deck first, then the rest of the collection
	local page = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
	}, body)
	make("UIGridLayout", {
		CellSize = UDim2.new(0, 120, 0, 241),
		CellPadding = UDim2.new(0, 6, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, page)

	-- copies of each card sitting in the deck (they count toward fusing)
	local deckCopies = {}
	local deckCards = {}
	for index = 1, state.slotCount do
		local key = state.slots[tostring(index)]
		if key and Cards.parse(key) then
			deckCopies[key] = (deckCopies[key] or 0) + 1
			if passesFilter(key) then
				table.insert(deckCards, { key = key, index = index })
			end
		end
	end
	table.sort(deckCards, function(a, b)
		if a.key ~= b.key then
			return sortKeys(a.key, b.key)
		end
		return a.index < b.index
	end)

	local order = 0
	for _, entry in ipairs(deckCards) do
		local key, index = entry.key, entry.index
		do
			order = order + 1
			local cell = newCardCell(page, key, order)
			newLabel(cell, "IN DECK", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 16), {
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundTransparency = 0,
				BackgroundColor3 = COLORS.good,
				ZIndex = 3,
			})
			newButton(cell, "Take out", UDim2.new(0, 4, 0, 167), UDim2.new(1, -8, 0, 32), COLORS.locked, function()
				Remotes.RemoveCard:FireServer(index)
			end).TextSize = 14
			-- fuse and vault straight from the deck; copies in the deck and inventory both count
			local _, deckVariant = Cards.parse(key)
			local deckNext = Cards.nextVariant(deckVariant)
			local deckCanFuse = deckNext ~= nil and (state.inventory[key] or 0) + deckCopies[key] >= Config.FuseCount
			local deckCanVault = #state.vault < state.vaultSlots
			local leftPosition, leftSize = UDim2.new(0, 4, 0, 203), UDim2.new(1, -8, 0, 32)
			local rightPosition, rightSize = leftPosition, leftSize
			if deckCanFuse and deckCanVault then
				leftSize = UDim2.new(0.5, -6, 0, 32)
				rightPosition, rightSize = UDim2.new(0.5, 2, 0, 203), UDim2.new(0.5, -6, 0, 32)
			end
			if deckCanFuse then
				newButton(cell, "Fuse → " .. Cards.Variants[deckNext].name, leftPosition, leftSize, Color3.fromRGB(200, 70, 180), function()
					Remotes.FuseCard:FireServer(key, index)
				end).TextSize = 11
			end
			if deckCanVault then
				newButton(cell, "🔐 Vault", rightPosition, rightSize, Color3.fromRGB(215, 160, 50), function()
					Remotes.VaultStore:FireServer(key, index)
				end).TextSize = 12
			end
		end
	end

	local keys = {}
	for key in pairs(state.inventory) do
		if passesFilter(key) then
			table.insert(keys, key)
		end
	end
	table.sort(keys, sortKeys)

	for _, key in ipairs(keys) do
		order = order + 1
		local cell = newCardCell(page, key, order)
		newLabel(cell, "x" .. state.inventory[key], UDim2.new(1, -44, 0, 0), UDim2.new(0, 44, 0, 18), {
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(20, 20, 28),
			ZIndex = 3,
		})
		newButton(cell, "To deck", UDim2.new(0, 4, 0, 167), UDim2.new(0.5, -6, 0, 32), COLORS.button, function()
			Remotes.PlaceCard:FireServer(key)
		end).TextSize = 13
		newButton(cell, "Sell " .. Format.cash(Cards.getSellValue(key)), UDim2.new(0.5, 2, 0, 167), UDim2.new(0.5, -6, 0, 32), COLORS.bad, function()
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
		page:Destroy()
		newLabel(newRow(5, 60), deckSetFilter == "all" and "No cards yet — open a pack from the Pack Shop!" or "No cards from that set. Tap the set button to change the filter.", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), {
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = COLORS.dim,
		})
	end
end

-- Collection book: one binder page per set ---------------------------------

-- How many copies of an exact card + effect the player has, and where.
local function countCopies(key)
	local inDeck, inVault = 0, 0
	for _, deckKey in pairs(state.slots) do
		if deckKey == key then
			inDeck = inDeck + 1
		end
	end
	for _, vaultKey in ipairs(state.vault) do
		if vaultKey == key then
			inVault = inVault + 1
		end
	end
	return (state.inventory[key] or 0) + inDeck + inVault, inDeck, inVault
end

-- One card, every effect version of it: which you have found, how many you own, and
-- buttons to put one on your storefront.
local function renderCardDetail(def)
	local set = Cards.Sets[def.set]
	titleLabel.Text = "📖 " .. def.name

	local top = newRow(1, 48)
	top.BackgroundTransparency = 1
	newButton(top, "← Back to " .. set.name, UDim2.new(0, 0, 0, 4), UDim2.new(0, 250, 0, 38), COLORS.button, function()
		bookCard = nil
		renderPanel()
	end).TextSize = 15
	newLabel(top, set.code .. " " .. def.numberText .. "  ·  " .. def.rarity .. "  ·  " .. Cards.Types[def.type].name, UDim2.new(0, 262, 0, 4), UDim2.new(1, -262, 0, 38), {
		TextSize = 15,
		TextColor3 = COLORS.dim,
	})

	local page = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	}, body)
	make("UIGridLayout", {
		CellSize = UDim2.new(0, 150, 0, 300),
		CellPadding = UDim2.new(0, 8, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, page)

	for order, variantId in ipairs(Cards.VariantOrder) do
		local key = Cards.makeKey(def.id, variantId)
		local variant = Cards.Variants[variantId]
		local total, inDeck, inVault = countCopies(key)
		local cell = make("Frame", { BackgroundTransparency = 1, LayoutOrder = order }, page)
		local holder = make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 4, 0, 4),
			Size = UDim2.new(1, -8, 0, 199),
		}, cell)
		if state.collection[key] then
			CardView.new(key).Parent = holder
		else
			CardView.newUnknown(def).Parent = holder
		end

		local effectName = variantId == "normal" and "Normal" or variant.name
		newLabel(cell, effectName, UDim2.new(0, 0, 0, 206), UDim2.new(1, 0, 0, 18), {
			Font = Enum.Font.FredokaOne,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local owned
		if total > 0 then
			owned = "Own " .. total
			if inDeck > 0 then
				owned = owned .. "  ·  " .. inDeck .. " in deck"
			end
			if inVault > 0 then
				owned = owned .. "  ·  " .. inVault .. " in vault"
			end
		elseif state.collection[key] then
			owned = "Found before, none owned now"
		else
			owned = "Not found yet"
		end
		newLabel(cell, owned, UDim2.new(0, 0, 0, 226), UDim2.new(1, 0, 0, 30), {
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = total > 0 and COLORS.cash or COLORS.dim,
		})
		if total > 0 then
			-- put this card in one of the two frames at the front of the store
			local onLeft, onRight = state.showcase.left == key, state.showcase.right == key
			newButton(cell, onLeft and "◀ Shown" or "◀ Show", UDim2.new(0, 4, 0, 262), UDim2.new(0.5, -6, 0, 30), onLeft and COLORS.good or COLORS.row, function()
				Remotes.SetShowcase:FireServer("left", key)
			end).TextSize = 12
			newButton(cell, onRight and "Shown ▶" or "Show ▶", UDim2.new(0.5, 2, 0, 262), UDim2.new(0.5, -6, 0, 30), onRight and COLORS.good or COLORS.row, function()
				Remotes.SetShowcase:FireServer("right", key)
			end).TextSize = 12
		end
	end

	local footer = newRow(3, 50)
	newLabel(footer, "\"Show\" puts a card in the left or right frame at the front of your store. Automatic shows your deck's two top earners.", UDim2.new(0, 14, 0, 0), UDim2.new(1, -190, 1, 0), {
		TextSize = 12,
		TextColor3 = COLORS.dim,
	})
	local auto = state.showcase.left == "" and state.showcase.right == ""
	newButton(footer, auto and "Automatic ✓" or "Use automatic", UDim2.new(1, -164, 0, 8), UDim2.new(0, 156, 0, 34), auto and COLORS.locked or COLORS.button, function()
		Remotes.SetShowcase:FireServer("auto", "")
	end).TextSize = 14
end

panels.Book = function()
	useList()

	local detail = bookCard and Cards.ById[bookCard]
	if detail then
		renderCardDetail(detail)
		return
	end

	-- overall progress (every card and variant counts toward the income bonus)
	local discovered = 0
	for _ in pairs(state.collection) do
		discovered = discovered + 1
	end
	local bonus = math.floor(discovered * Config.CollectionBonusPerCard * 100 + 0.5)
	titleLabel.Text = "📖 Collection  ·  +" .. bonus .. "% income"

	-- set tabs
	local tabs = newRow(1, 40)
	tabs.BackgroundTransparency = 1
	local tabCount = #Cards.SetOrder + 1 -- one per set, plus the combo book
	local tabWidth = math.floor(640 / tabCount) - 6
	for index, setId in ipairs(Cards.SetOrder) do
		local tabSet = Cards.Sets[setId]
		local tabFound, tabTotal = Cards.setProgress(state.collection, setId)
		local label = tabSet.icon .. " " .. tabSet.code .. (tabFound >= tabTotal and " ✓" or "")
		newButton(tabs, label, UDim2.new(0, (index - 1) * (tabWidth + 6), 0, 2), UDim2.new(0, tabWidth, 0, 36), bookSet == setId and COLORS.button or COLORS.row, function()
			bookSet = setId
			renderPanel()
		end).TextSize = 13
	end
	newButton(tabs, "📜 Combos", UDim2.new(0, (tabCount - 1) * (tabWidth + 6), 0, 2), UDim2.new(0, tabWidth, 0, 36), bookSet == "combos" and COLORS.button or COLORS.row, function()
		bookSet = "combos"
		renderPanel()
	end).TextSize = 13

	if bookSet == "combos" then
		-- Combo book: every story combo, what it needs, and what you have
		local inDeck = {}
		for _, key in pairs(state.slots) do
			local def = Cards.parse(key)
			if def then
				inDeck[def.id] = true
			end
		end
		local note = newRow(2, 34)
		note.BackgroundTransparency = 1
		newLabel(note, "✅ in your deck    🟡 owned, not in deck    ❌ not owned yet.  \"Add to deck\" puts the whole combo in for you.", UDim2.new(0, 4, 0, 0), UDim2.new(1, -8, 1, 0), {
			TextSize = 12,
			TextColor3 = COLORS.dim,
		})
		for index, story in ipairs(Combos.Stories) do
			local parts = {}
			local have = 0
			local missing = 0
			for _, id in ipairs(story.cards) do
				local mark = "❌"
				if inDeck[id] then
					mark = "✅"
					have = have + 1
				elseif Rebirth.ownsCard(state, id) then
					mark = "🟡"
				else
					missing = missing + 1
				end
				table.insert(parts, mark .. " " .. Cards.ById[id].name)
			end
			local done = have >= #story.cards
			local row = newRow(2 + index, 64)
			newLabel(row, story.name .. "   " .. Combos.bonusText(story) .. (done and "   ACTIVE" or ""), UDim2.new(0, 14, 0, 6), UDim2.new(1, -180, 0, 22), {
				Font = Enum.Font.FredokaOne,
				TextSize = 17,
				TextColor3 = done and Color3.fromRGB(255, 215, 90) or COLORS.text,
			})
			newLabel(row, table.concat(parts, "    "), UDim2.new(0, 14, 0, 30), UDim2.new(1, -180, 0, 30), {
				TextSize = 12,
				TextColor3 = COLORS.dim,
				TextYAlignment = Enum.TextYAlignment.Top,
			})
			-- one tap puts the whole combo in the deck
			local comboPosition, comboSize = UDim2.new(1, -156, 0, 12), UDim2.new(0, 148, 0, 40)
			if done then
				newButton(row, "In deck ✓", comboPosition, comboSize, COLORS.locked, nil).AutoButtonColor = false
			elseif missing > 0 then
				local need = newButton(row, "Missing " .. missing .. (missing == 1 and " card" or " cards"), comboPosition, comboSize, COLORS.locked, nil)
				need.TextSize = 14
				need.AutoButtonColor = false
			else
				newButton(row, "Add to deck", comboPosition, comboSize, COLORS.good, function()
					Remotes.ComboFill:FireServer(index)
				end)
			end
		end
		return
	end

	local set = Cards.Sets[bookSet]
	local found, total = Cards.setProgress(state.collection, bookSet)
	local info = newRow(2, 38)
	local complete = found >= total
	local bonusPercent = math.floor(Config.SetCompleteBonus * 100 + 0.5)
	local progress = "Tap a card for its effects.  " .. set.icon .. " " .. set.name .. "  ·  " .. found .. "/" .. total .. "  ·  "
	if complete then
		progress = progress .. "SET COMPLETE: +" .. bonusPercent .. "% income!"
	else
		progress = progress .. "complete the set for +" .. bonusPercent .. "% income"
	end
	newLabel(info, progress, UDim2.new(0, 14, 0, 0), UDim2.new(1, -28, 1, 0), {
		TextSize = 14,
		TextColor3 = complete and Color3.fromRGB(255, 215, 90) or COLORS.text,
	})

	-- the binder page: every card of the set in number order
	local page = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
	}, body)
	make("UIGridLayout", {
		CellSize = UDim2.new(0, 116, 0, 184),
		CellPadding = UDim2.new(0, 8, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, page)
	for order, def in ipairs(set.cards) do
		local best = nil
		local variantsFound = 0
		for _, variantId in ipairs(Cards.VariantOrder) do
			local key = Cards.makeKey(def.id, variantId)
			if state.collection[key] then
				variantsFound = variantsFound + 1
				best = key
			end
		end

		local cell = make("Frame", { BackgroundTransparency = 1, LayoutOrder = order }, page)
		local holder = make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 4, 0, 4),
			Size = UDim2.new(1, -8, 0, 151),
		}, cell)
		if best then
			CardView.new(best).Parent = holder
		else
			CardView.newUnknown(def).Parent = holder
		end
		-- tap a card to see every effect version of it
		local open = make("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 5,
		}, cell)
		open.Activated:Connect(function()
			bookCard = def.id
			body.CanvasPosition = Vector2.new(0, 0)
			renderPanel()
		end)
		-- one mark per effect found
		local dots = string.rep("◆", variantsFound) .. string.rep("◇", #Cards.VariantOrder - variantsFound)
		newLabel(cell, dots, UDim2.new(0, 0, 0, 160), UDim2.new(1, 0, 0, 18), {
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = variantsFound == #Cards.VariantOrder and Color3.fromRGB(255, 215, 90) or COLORS.dim,
		})
	end
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

	local vaultLines = math.ceil(state.vaultSlots / 5)
	local vaultRow = newRow(0, 40 + vaultLines * 222) -- first thing on the screen
	newLabel(vaultRow, "🔐 Vault  (" .. #state.vault .. "/" .. state.vaultSlots .. ") — cards in here survive a rebirth. Use the 🔐 Vault button under any card on the Deck screen, in your deck or not.", UDim2.new(0, 14, 0, 6), UDim2.new(1, -28, 0, 22), {
		TextSize = 14,
	})
	local strip = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 34),
		Size = UDim2.new(1, -20, 0, vaultLines * 222),
	}, vaultRow)
	make("UIGridLayout", {
		CellSize = UDim2.new(0, 118, 0, 216),
		CellPadding = UDim2.new(0, 6, 0, 6),
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
	if Achievements.anyClaimable(state, state.achievements) then
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

	-- Achievements: permanent goals. Shows what can be claimed and the next goal of each kind.
	local rows, claimedCount = Achievements.display(state, state.achievements)
	local bonus = math.floor(Achievements.BonusEach * claimedCount * 100 + 0.5)
	local header = newRow(20, 44)
	header.BackgroundColor3 = Color3.fromRGB(60, 45, 80)
	newLabel(header, "🏆 Achievements  ·  " .. claimedCount .. "/" .. #Achievements.List .. "  ·  +" .. bonus .. "% income forever", UDim2.new(0, 14, 0, 0), UDim2.new(1, -28, 1, 0), {
		Font = Enum.Font.FredokaOne,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(255, 215, 90),
	})
	for index, entry in ipairs(rows) do
		local achievement = entry.achievement
		local row = newRow(20 + index, 60)
		newLabel(row, achievement.name, UDim2.new(0, 14, 0, 6), UDim2.new(1, -190, 0, 22), { Font = Enum.Font.FredokaOne, TextSize = 17 })
		local progress
		if achievement.cash then
			progress = Format.cash(math.min(entry.value, achievement.goal)) .. " / " .. Format.cash(achievement.goal)
		else
			progress = Format.short(math.min(entry.value, achievement.goal)) .. " / " .. Format.short(achievement.goal)
		end
		newLabel(row, achievement.text .. "   ·   " .. progress, UDim2.new(0, 14, 0, 30), UDim2.new(1, -190, 0, 24), {
			TextSize = 13,
			TextColor3 = COLORS.dim,
		})
		if entry.done then
			newButton(row, "Claim", UDim2.new(1, -160, 0, 8), buttonSize, COLORS.good, function()
				Remotes.AchievementClaim:FireServer(achievement.id)
			end)
		else
			newButton(row, "+" .. math.floor(Achievements.BonusEach * 100 + 0.5) .. "% income", UDim2.new(1, -160, 0, 8), buttonSize, COLORS.locked, nil).AutoButtonColor = false
		end
	end
end

-- Aura Shrine: permanent perks, shown under the store upgrades ---------------------
local renderStoreUpgrades = panels.Upgrades
panels.Upgrades = function()
	renderStoreUpgrades()

	-- Luck stat and where it comes from
	local sources = Luck.sources(state, state.luckEventEndsAt > os.time(), state.passes)
	local parts = {}
	for _, source in ipairs(sources) do
		table.insert(parts, source.name .. " +" .. source.levels)
	end
	local luckRow = newRow(0, 88)
	luckRow.BackgroundColor3 = Color3.fromRGB(30, 70, 50)
	newLabel(luckRow, "🍀 Luck " .. Luck.percentText(state.luck) .. "   (" .. state.luck .. " levels)", UDim2.new(0, 14, 0, 6), UDim2.new(1, -28, 0, 24), {
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(150, 255, 170),
	})
	local breakdown = #parts > 0 and table.concat(parts, "   ·   ") or "No luck yet. Buy Lucky Charms, finish sets, climb the tower or build luck combos."
	newLabel(luckRow, "Each level makes better rarities 10% more likely. Later sets use less of your luck (the Pack Shop shows the real odds).  " .. breakdown, UDim2.new(0, 14, 0, 32), UDim2.new(1, -28, 0, 52), {
		TextSize = 12,
		TextColor3 = COLORS.dim,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local header = newRow(20, 44)
	header.BackgroundColor3 = Color3.fromRGB(70, 35, 80)
	newLabel(header, "✨ Aura Shrine — permanent perks. Each rebirth unlocks one more level.", UDim2.new(0, 14, 0, 0), UDim2.new(1, -28, 1, 0), {
		Font = Enum.Font.FredokaOne,
		TextSize = 17,
		TextColor3 = COLORS.aura,
	})
	for order, perkId in ipairs(Perks.Order) do
		local def = Perks.Defs[perkId]
		local level = Perks.level(state.perks, perkId)
		local row = newRow(20 + order, 72)
		newLabel(row, def.name .. "   Lv " .. level .. "/" .. def.max, UDim2.new(0, 14, 0, 8), UDim2.new(1, -190, 0, 24), {
			Font = Enum.Font.FredokaOne,
			TextSize = 19,
		})
		newLabel(row, def.describe(level), UDim2.new(0, 14, 0, 36), UDim2.new(1, -190, 0, 30), {
			TextSize = 13,
			TextColor3 = COLORS.dim,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		local buttonPosition = UDim2.new(1, -160, 0, 14)
		local buttonSize = UDim2.new(0, 148, 0, 44)
		if level >= def.max then
			newButton(row, "MAX", buttonPosition, buttonSize, COLORS.locked, nil).AutoButtonColor = false
		elseif level >= Perks.maxLevel(perkId, state.rebirths) then
			-- each rebirth opens one more level of every perk
			local locked = newButton(row, "🔒 Needs " .. level .. (level == 1 and " rebirth" or " rebirths"), buttonPosition, buttonSize, COLORS.locked, nil)
			locked.TextSize = 13
			locked.AutoButtonColor = false
		else
			newButton(row, currencyText("aura", def.cost(level)), buttonPosition, buttonSize, Color3.fromRGB(200, 70, 180), function()
				Remotes.BuyPerk:FireServer(perkId)
			end)
		end
	end
end

-- Trade + marketplace ---------------------------------------------------------------
local market = {} -- every card for sale in this server: { id, key, price, sellerId, sellerName }
local activeTrade = nil -- { partnerName, mine, theirs, myConfirm, theirConfirm } while trading
local tradeRequestsIn = {} -- { { userId, name }, ... }
local tradeView = "market" -- "market" | "sell" | "players"
local sellKey = nil
local sellPriceText = ""

-- "Crimson Samurai Akane  ·  $40/s", coloured by rarity.
local function newCardLine(parent, key, position, size)
	local def = Cards.parse(key)
	local label = newLabel(parent, Cards.getDisplayName(key) .. "  ·  " .. Format.cash(Cards.getIncome(key)) .. "/s", position, size, {
		TextSize = 14,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	if def and def.rarity ~= "Secret" then
		label.TextColor3 = Cards.Rarities[def.rarity].color:Lerp(Color3.new(1, 1, 1), 0.35)
	elseif def then
		label.TextColor3 = Color3.fromRGB(255, 90, 90)
	end
	return label
end

local function sortedInventoryKeys()
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
	return keys
end

local function newNote(order, text)
	local row = newRow(order, 34)
	row.BackgroundTransparency = 1
	newLabel(row, text, UDim2.new(0, 4, 0, 0), UDim2.new(1, -8, 1, 0), { TextSize = 14, TextColor3 = COLORS.dim })
	return row
end

local function renderActiveTrade()
	local trade = activeTrade
	titleLabel.Text = "🤝 Trading with " .. trade.partnerName
	local header = newRow(1, 76)
	local status = "Add cards, then both press Confirm."
	if trade.myConfirm and not trade.theirConfirm then
		status = "You confirmed. Waiting for " .. trade.partnerName .. "…"
	elseif trade.theirConfirm and not trade.myConfirm then
		status = trade.partnerName .. " confirmed. Check the offer, then confirm."
	end
	newLabel(header, status, UDim2.new(0, 14, 0, 6), UDim2.new(1, -28, 0, 22), { TextSize = 14 })
	newButton(header, trade.myConfirm and "Confirmed ✓" or "Confirm", UDim2.new(0, 14, 0, 34), UDim2.new(0, 160, 0, 34), trade.myConfirm and COLORS.locked or COLORS.good, function()
		if not trade.myConfirm then
			Remotes.TradeConfirm:FireServer()
		end
	end)
	newButton(header, "Cancel trade", UDim2.new(0, 184, 0, 34), UDim2.new(0, 140, 0, 34), COLORS.bad, function()
		Remotes.TradeCancel:FireServer()
	end)

	local order = 1
	local function section(title, keys, removable)
		order = order + 1
		newNote(order, title)
		if #keys == 0 then
			order = order + 1
			newNote(order, "    (nothing yet)")
		end
		for _, key in ipairs(keys) do
			order = order + 1
			local row = newRow(order, 36)
			newCardLine(row, key, UDim2.new(0, 12, 0, 0), UDim2.new(1, -120, 1, 0))
			if removable then
				newButton(row, "Remove", UDim2.new(1, -98, 0, 4), UDim2.new(0, 90, 0, 28), COLORS.locked, function()
					Remotes.TradeOffer:FireServer(key, false)
				end).TextSize = 13
			end
		end
	end
	section("You give (" .. #trade.mine .. "/" .. Config.Trade.MaxCards .. "):", trade.mine, true)
	section(trade.partnerName .. " gives:", trade.theirs, false)

	order = order + 1
	newNote(order, "Your cards — tap Add to offer one:")
	for _, key in ipairs(sortedInventoryKeys()) do
		order = order + 1
		local row = newRow(order, 36)
		newCardLine(row, key, UDim2.new(0, 12, 0, 0), UDim2.new(1, -170, 1, 0))
		newLabel(row, "x" .. state.inventory[key], UDim2.new(1, -150, 0, 0), UDim2.new(0, 44, 1, 0), { TextSize = 13, TextColor3 = COLORS.dim })
		newButton(row, "Add", UDim2.new(1, -98, 0, 4), UDim2.new(0, 90, 0, 28), COLORS.button, function()
			Remotes.TradeOffer:FireServer(key, true)
		end).TextSize = 13
	end
end

panels.Trade = function()
	useList()
	if activeTrade then
		renderActiveTrade()
		return
	end
	titleLabel.Text = "🤝 Trade & Market"

	-- tabs
	local tabs = newRow(1, 40)
	tabs.BackgroundTransparency = 1
	local TABS = { { "market", "🛒 Market" }, { "sell", "💰 Sell a card" }, { "players", "🤝 Trade" } }
	for index, tab in ipairs(TABS) do
		local label = tab[2]
		if tab[1] == "players" and #tradeRequestsIn > 0 then
			label = label .. "  ❗"
		end
		newButton(tabs, label, UDim2.new(0, (index - 1) * 206, 0, 2), UDim2.new(0, 200, 0, 36), tradeView == tab[1] and COLORS.button or COLORS.row, function()
			tradeView = tab[1]
			renderPanel()
		end).TextSize = 15
	end

	if tradeView == "market" then
		if #market == 0 then
			newNote(2, "Nothing is for sale right now. List one of your cards in \"Sell a card\".")
		end
		for index, listing in ipairs(market) do
			local row = newRow(1 + index, 48)
			newCardLine(row, listing.key, UDim2.new(0, 12, 0, 4), UDim2.new(1, -190, 0, 22))
			local mine = listing.sellerId == player.UserId
			newLabel(row, mine and "Your listing" or ("Seller: " .. tostring(listing.sellerName)), UDim2.new(0, 12, 0, 26), UDim2.new(1, -190, 0, 18), {
				TextSize = 12,
				TextColor3 = COLORS.dim,
			})
			if mine then
				newButton(row, "Cancel  (" .. Format.cash(listing.price) .. ")", UDim2.new(1, -168, 0, 7), UDim2.new(0, 160, 0, 34), COLORS.locked, function()
					Remotes.MarketCancel:FireServer(listing.id)
				end).TextSize = 13
			else
				newButton(row, "Buy  " .. Format.cash(listing.price), UDim2.new(1, -168, 0, 7), UDim2.new(0, 160, 0, 34), COLORS.good, function()
					Remotes.MarketBuy:FireServer(listing.id)
				end).TextSize = 15
			end
		end
	elseif tradeView == "sell" then
		if sellKey and (state.inventory[sellKey] or 0) < 1 then
			sellKey = nil
		end
		local form = newRow(2, 84)
		if sellKey then
			newCardLine(form, sellKey, UDim2.new(0, 14, 0, 8), UDim2.new(1, -28, 0, 22))
		else
			newLabel(form, "Pick a card below, set a price, then list it.", UDim2.new(0, 14, 0, 8), UDim2.new(1, -28, 0, 22), { TextSize = 14 })
		end
		local priceBox = make("TextBox", {
			Position = UDim2.new(0, 14, 0, 40),
			Size = UDim2.new(0, 220, 0, 34),
			BackgroundColor3 = Color3.fromRGB(20, 20, 30),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			PlaceholderText = "Price in cash, e.g. 5000",
			Text = sellPriceText,
			TextColor3 = COLORS.text,
			TextSize = 15,
			ClearTextOnFocus = false,
		}, form)
		round(priceBox, 8)
		priceBox:GetPropertyChangedSignal("Text"):Connect(function()
			sellPriceText = priceBox.Text
		end)
		newButton(form, "List for sale", UDim2.new(0, 244, 0, 40), UDim2.new(0, 160, 0, 34), COLORS.good, function()
			local price = tonumber((string.gsub(sellPriceText, "[,%$%s]", "")))
			if sellKey == nil then
				toast("Pick a card to sell first.", "error")
			elseif price == nil or price < 1 then
				toast("Type a price first.", "error")
			else
				Remotes.MarketList:FireServer(sellKey, math.floor(price))
				sellKey = nil
				sellPriceText = ""
			end
		end)
		for index, key in ipairs(sortedInventoryKeys()) do
			local row = newRow(2 + index, 36)
			newCardLine(row, key, UDim2.new(0, 12, 0, 0), UDim2.new(1, -170, 1, 0))
			newLabel(row, "x" .. state.inventory[key], UDim2.new(1, -150, 0, 0), UDim2.new(0, 44, 1, 0), { TextSize = 13, TextColor3 = COLORS.dim })
			newButton(row, sellKey == key and "Selected" or "Select", UDim2.new(1, -98, 0, 4), UDim2.new(0, 90, 0, 28), sellKey == key and COLORS.good or COLORS.button, function()
				sellKey = key
				renderPanel()
			end).TextSize = 13
		end
	else
		local order = 1
		for _, request in ipairs(tradeRequestsIn) do
			order = order + 1
			local row = newRow(order, 44)
			newLabel(row, request.name .. " wants to trade with you", UDim2.new(0, 14, 0, 0), UDim2.new(1, -180, 1, 0), { TextSize = 15 })
			newButton(row, "Accept", UDim2.new(1, -158, 0, 6), UDim2.new(0, 150, 0, 32), COLORS.good, function()
				Remotes.TradeAccept:FireServer(request.userId)
			end)
		end
		local others = 0
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				others = others + 1
				order = order + 1
				local row = newRow(order, 44)
				newLabel(row, other.DisplayName, UDim2.new(0, 14, 0, 0), UDim2.new(1, -180, 1, 0), { TextSize = 15 })
				newButton(row, "Ask to trade", UDim2.new(1, -158, 0, 6), UDim2.new(0, 150, 0, 32), COLORS.button, function()
					Remotes.TradeRequest:FireServer(other.UserId)
				end).TextSize = 15
			end
		end
		if others == 0 then
			newNote(order + 1, "Nobody else is in this server right now.")
		end
	end
end

-- Store: game passes and aura bundles ------------------------------------------------
local codeText = ""
local resetConfirmUntil = 0

panels.Store = function()
	titleLabel.Text = "💎 Store"
	useList()
	local settings = Config.Monetization
	local buttonPosition = UDim2.new(1, -160, 0, 14)
	local buttonSize = UDim2.new(0, 148, 0, 44)

	-- redeem a code
	local codeRow = newRow(0, 60)
	codeRow.BackgroundColor3 = Color3.fromRGB(38, 58, 82)
	newLabel(codeRow, "🎟️ Got a code?", UDim2.new(0, 14, 0, 0), UDim2.new(0, 150, 1, 0), { Font = Enum.Font.FredokaOne, TextSize = 18 })
	local codeBox = make("TextBox", {
		Position = UDim2.new(0, 170, 0, 12),
		Size = UDim2.new(1, -340, 0, 36),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		PlaceholderText = "Type it here",
		Text = codeText,
		TextColor3 = COLORS.text,
		TextSize = 16,
		ClearTextOnFocus = false,
	}, codeRow)
	round(codeBox, 8)
	codeBox:GetPropertyChangedSignal("Text"):Connect(function()
		codeText = codeBox.Text
	end)
	newButton(codeRow, "Redeem", UDim2.new(1, -160, 0, 8), buttonSize, COLORS.good, function()
		if codeText ~= "" then
			Remotes.RedeemCode:FireServer(codeText)
			codeText = ""
			codeBox.Text = ""
		end
	end)

	local order = 0
	for _, passKey in ipairs(settings.PassOrder) do
		local pass = settings.Passes[passKey]
		order = order + 1
		local row = newRow(order, 72)
		newLabel(row, pass.name, UDim2.new(0, 14, 0, 8), UDim2.new(1, -190, 0, 24), { Font = Enum.Font.FredokaOne, TextSize = 19 })
		newLabel(row, pass.text, UDim2.new(0, 14, 0, 36), UDim2.new(1, -190, 0, 30), {
			TextSize = 13,
			TextColor3 = COLORS.dim,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		if state.passes[passKey] then
			newButton(row, "Owned ✓", buttonPosition, buttonSize, COLORS.good, nil).AutoButtonColor = false
		elseif pass.id <= 0 then
			newButton(row, "Coming soon", buttonPosition, buttonSize, COLORS.locked, nil).AutoButtonColor = false
		else
			newButton(row, "Buy", buttonPosition, buttonSize, Color3.fromRGB(150, 95, 230), function()
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end)
		end
	end

	-- Boosts and bundles. Products that hand out cash (which buys random packs) are hidden
	-- where paid random items are restricted.
	for _, productKey in ipairs(settings.ProductOrder) do
		local product = settings.Products[productKey]
		if not (product.random and state.restricted) then
			order = order + 1
			local row = newRow(order, 72)
			newLabel(row, product.name, UDim2.new(0, 14, 0, 8), UDim2.new(1, -190, 0, 24), {
				Font = Enum.Font.FredokaOne,
				TextSize = 19,
				TextColor3 = product.kind == "aura" and COLORS.aura or COLORS.text,
			})
			newLabel(row, product.text, UDim2.new(0, 14, 0, 36), UDim2.new(1, -190, 0, 30), {
				TextSize = 13,
				TextColor3 = COLORS.dim,
				TextYAlignment = Enum.TextYAlignment.Top,
			})
			if product.id <= 0 then
				newButton(row, "Coming soon", buttonPosition, buttonSize, COLORS.locked, nil).AutoButtonColor = false
			else
				newButton(row, "Buy", buttonPosition, buttonSize, Color3.fromRGB(200, 70, 180), function()
					MarketplaceService:PromptProductPurchase(player, product.id)
				end)
			end
		end
	end

	-- testing tool, only shown to the game's creator (and in Studio)
	if state.isOwner then
		local resetRow = newRow(order + 2, 60)
		resetRow.BackgroundColor3 = Color3.fromRGB(70, 30, 30)
		newLabel(resetRow, "🧪 Owner tool: wipe your own save to test the game from the start. Only you can see this.", UDim2.new(0, 14, 0, 0), UDim2.new(1, -190, 1, 0), { TextSize = 13 })
		local resetButton
		resetButton = newButton(resetRow, "Reset my save", UDim2.new(1, -160, 0, 8), buttonSize, COLORS.bad, function()
			if os.clock() < resetConfirmUntil then
				Remotes.ResetData:FireServer()
			else
				resetConfirmUntil = os.clock() + 4
				resetButton.Text = "Tap again to wipe"
				resetButton.TextSize = 14
			end
		end)
	end

	local note = newRow(order + 1, 34)
	note.BackgroundTransparency = 1
	newLabel(note, "Purchases are optional. Everything in the game can be earned by playing.", UDim2.new(0, 4, 0, 0), UDim2.new(1, -8, 1, 0), {
		TextSize = 13,
		TextColor3 = COLORS.dim,
	})
end

-- Battle tower -----------------------------------------------------------------------
local battling = false
local renderedTower = -1

local function newUnitBox(parent, unit, column, index)
	local box = make("Frame", {
		Position = UDim2.new(column * 0.5, column == 0 and 10 or 5, 0, 8 + (index - 1) * 78),
		Size = UDim2.new(0.5, -15, 0, 70),
		BackgroundColor3 = Color3.fromRGB(30, 30, 44),
		BorderSizePixel = 0,
	}, parent)
	round(box, 8)
	newLabel(box, unit.glyph or "?", UDim2.new(0, 6, 0, 10), UDim2.new(0, 44, 0, 44), {
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	newLabel(box, unit.name, UDim2.new(0, 58, 0, 4), UDim2.new(1, -64, 0, 18), {
		TextSize = 12,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local typeInfo = Cards.Types[unit.type]
	newLabel(box, (typeInfo and (typeInfo.icon .. " " .. typeInfo.name) or "") .. "   ATK " .. Format.short(unit.attack), UDim2.new(0, 58, 0, 22), UDim2.new(1, -64, 0, 16), {
		TextSize = 11,
		TextColor3 = COLORS.dim,
	})
	local bar = make("Frame", {
		Position = UDim2.new(0, 58, 0, 44),
		Size = UDim2.new(1, -68, 0, 16),
		BackgroundColor3 = Color3.fromRGB(15, 15, 22),
		BorderSizePixel = 0,
	}, box)
	round(bar, 5)
	local fill = make("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = column == 0 and COLORS.good or COLORS.bad,
		BorderSizePixel = 0,
	}, bar)
	round(fill, 5)
	local hpLabel = newLabel(bar, Format.short(unit.maxHp) .. " HP", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), {
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
	})
	return { unit = unit, box = box, fill = fill, hpLabel = hpLabel }
end

panels.Battle = function()
	titleLabel.Text = "⚔️ Battle Tower  (" .. state.tower .. "/" .. Battle.MaxFloor .. " floors cleared)"
	renderedTower = state.tower
	useList()

	local floor = state.tower + 1
	local cleared = floor > Battle.MaxFloor
	local infoRow = newRow(1, 84)
	local arena = newRow(2, 8 + Battle.TeamSize * 78)
	local logRow = newRow(3, 40)
	local logLabel = newLabel(logRow, "", UDim2.new(0, 14, 0, 0), UDim2.new(1, -28, 1, 0), { TextSize = 14 })

	local viewsA, viewsB = {}, {}
	local function drawArena(team, enemies)
		arena:ClearAllChildren()
		round(arena, 10)
		viewsA, viewsB = {}, {}
		for index, unit in ipairs(team) do
			viewsA[index] = newUnitBox(arena, unit, 0, index)
		end
		for index, unit in ipairs(enemies) do
			viewsB[index] = newUnitBox(arena, unit, 1, index)
		end
	end
	drawArena(Battle.bestTeam(state), cleared and {} or Battle.enemyTeam(floor))

	if cleared then
		newLabel(infoRow, "You cleared the whole tower. More floors are coming!", UDim2.new(0, 14, 0, 0), UDim2.new(1, -28, 1, 0), {
			Font = Enum.Font.FredokaOne,
			TextSize = 18,
		})
		return
	end

	local aura, cash = Battle.reward(floor, state.cashCap)
	newLabel(infoRow, "Floor " .. floor .. "   ·   win: +" .. Format.short(aura) .. " aura, " .. Format.cash(cash), UDim2.new(0, 14, 0, 8), UDim2.new(1, -190, 0, 24), {
		Font = Enum.Font.FredokaOne,
		TextSize = 19,
	})
	newLabel(infoRow, "Your 3 strongest cards fight for you. Type advantage deals +30% damage:\n⚔️ beats 🐾 beats 🔮 beats ⚙️ beats ⭐ beats ⚔️", UDim2.new(0, 14, 0, 36), UDim2.new(1, -190, 0, 44), {
		TextSize = 12,
		TextColor3 = COLORS.dim,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	newButton(infoRow, "FIGHT", UDim2.new(1, -160, 0, 20), UDim2.new(0, 148, 0, 44), COLORS.bad, function()
		if battling then
			return
		end
		battling = true
		local ok, result = pcall(function()
			return Remotes.Battle:InvokeServer()
		end)
		if not ok or type(result) ~= "table" or not result.ok then
			battling = false
			toast(ok and type(result) == "table" and result.error or "Could not start the battle.", "error")
			return
		end

		-- Play back the fight the server already decided.
		for _, unit in ipairs(result.team) do
			unit.hp = unit.maxHp
		end
		for _, unit in ipairs(result.enemies) do
			unit.hp = unit.maxHp
		end
		drawArena(result.team, result.enemies)
		for _, entry in ipairs(result.log) do
			if currentPanel ~= "Battle" then
				break
			end
			local attackers = entry.side == "a" and viewsA or viewsB
			local targets = entry.side == "a" and viewsB or viewsA
			local attacker, target = attackers[entry.attacker], targets[entry.target]
			if attacker and target then
				target.fill.Size = UDim2.new(math.clamp(entry.hpLeft / target.unit.maxHp, 0, 1), 0, 1, 0)
				target.hpLabel.Text = entry.hpLeft > 0 and (Format.short(entry.hpLeft) .. " HP") or "KO"
				if entry.hpLeft <= 0 then
					target.box.BackgroundTransparency = 0.6
				end
				logLabel.Text = attacker.unit.name .. " hits " .. target.unit.name .. " for " .. Format.short(entry.damage) .. (entry.strong and "  — type advantage!" or "")
				playSound("hit")
			end
			task.wait(0.3)
		end

		if result.win then
			logLabel.Text = "🏆 VICTORY!  +" .. Format.short(result.aura) .. " aura, " .. Format.cash(result.cash)
			logLabel.TextColor3 = COLORS.cash
			playSound("bigPull")
		else
			logLabel.Text = "💀 Defeat. Pull stronger cards (or better types) and try again."
			logLabel.TextColor3 = COLORS.bad
		end
		task.wait(1.6)
		battling = false
		if currentPanel == "Battle" then
			renderPanel()
		end
	end)
end

local lastRenderAt = 0
local renderQueued = false -- a rebuild is waiting for the throttle below

function renderPanel()
	if currentPanel == nil then
		return
	end
	lastRenderAt = os.clock()
	renderQueued = false
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

-- HUD menu buttons: two columns so the menu stays short on phones
local packsButton = nil
local questsButton = nil
local MENU = {
	{ "Packs", "🎴 Packs", Color3.fromRGB(225, 80, 120), "P" },
	{ "Cards", "🃏 Deck", COLORS.button, "C" },
	{ "Book", "📖 Book", Color3.fromRGB(150, 95, 230), "B" },
	{ "Upgrades", "🏪 Upgrade", COLORS.good, "U" },
	{ "Trade", "🤝 Trade", Color3.fromRGB(40, 170, 160), "T" },
	{ "Battle", "⚔️ Battle", Color3.fromRGB(200, 60, 60), "G" },
	{ "Quests", "🎯 Quests", Color3.fromRGB(230, 120, 50), "Q" },
	{ "Rebirth", "🌟 Rebirth", Color3.fromRGB(215, 160, 50), "R" },
	{ "Store", "💎 Store", Color3.fromRGB(120, 80, 200), "M" },
}
local keyBadges = {} -- the little key letters on the buttons (keyboard players only)
local menuGrid = make("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, math.ceil(#MENU / 2) * 40),
	LayoutOrder = 10,
}, hud)
make("UIGridLayout", {
	CellSize = UDim2.new(0.5, -3, 0, 34),
	CellPadding = UDim2.new(0, 6, 0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, menuGrid)
for index, entry in ipairs(MENU) do
	local button = newButton(menuGrid, entry[2], UDim2.new(), UDim2.new(1, 0, 1, 0), entry[3], function()
		openPanel(entry[1])
	end)
	button.LayoutOrder = index
	button.TextSize = 15
	table.insert(keyBadges, newLabel(button, entry[4], UDim2.new(1, -15, 0, 1), UDim2.new(0, 13, 0, 12), {
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0.35,
		BackgroundColor3 = Color3.new(0, 0, 0),
	}))
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
	if state.cashCap < math.huge and state.cash >= state.cashCap * 0.999 then
		return "💰 Wallet full! Rebirth (🌟) to raise your money cap — vault your best cards first."
	end
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
		return "🎁 Open your free pack — tap the 🎁 FREE! button"
	end
	if owned and not displayed then
		return "🃏 Open Deck and tap Auto-fill Deck to start earning"
	end
	if displayed and discovered < 8 and state.upgrades.auto < 1 and state.cash < 100 then
		return "💵 Walk over the green cash register in your store to collect"
	end
	return ""
end

local function refreshHud()
	local hint = tutorialHint()
	hintLabel.Text = hint
	hintLabel.Visible = hint ~= ""
	if state.cashCap < math.huge then
		-- wallet cap: shown as "have / cap", red when full
		cashLabel.Text = "💵 " .. Format.cash(state.cash) .. " / " .. Format.cash(state.cashCap)
		cashLabel.TextSize = 17
		cashLabel.TextColor3 = state.cash >= state.cashCap * 0.999 and COLORS.bad or COLORS.cash
	else
		cashLabel.Text = "💵 " .. Format.cash(state.cash)
		cashLabel.TextSize = 22
		cashLabel.TextColor3 = COLORS.cash
	end
	auraLabel.Text = "✨ " .. Format.short(state.aura) .. " Aura"
	local rate = "+" .. Format.cash(state.incomePerSec) .. "/s"
	if state.auraPerSec > 0 then
		rate = rate .. "   +" .. Format.short(state.auraPerSec) .. " aura/s"
	end
	local combos = Combos.evaluate(state.slots)
	rate = rate .. "\n🍀 Luck " .. Luck.percentText(state.luck)
	if #combos.active > 0 then
		rate = rate .. "   ·   " .. #combos.active .. " combos"
	end
	-- bought potions that are still running
	local cashLeft = state.boosts.cashUntil - os.time()
	if cashLeft > 0 then
		rate = rate .. string.format("\n⚡ 2x cash  %d:%02d", math.floor(cashLeft / 60), cashLeft % 60)
	end
	local luckLeft = state.boosts.luckUntil - os.time()
	if luckLeft > 0 then
		rate = rate .. string.format("\n🧪 Luck potion  %d:%02d", math.floor(luckLeft / 60), luckLeft % 60)
	end
	local eventLeft = state.luckEventEndsAt - os.time()
	if eventLeft > 0 then
		rate = rate .. string.format("\n🍀 Lucky event  %d:%02d", math.floor(eventLeft / 60), eventLeft % 60)
	end
	rateLabel.Text = rate
	packsButton.Text = (state.freePacks > 0 or state.gifts > 0) and "🎁 FREE!" or "🎴 Packs"
	questsButton.Text = hasClaimable() and "🎯 Quests❗" or "🎯 Quests"
end

local seenAutoRev = 0

Remotes.State.OnClientEvent:Connect(function(newState)
	for key, value in pairs(newState) do
		state[key] = value
	end
	-- did this update come from the Auto Packer (rather than something the player did)?
	local fromAutoPacker = (state.autoRev or 0) ~= seenAutoRev
	seenAutoRev = state.autoRev or 0
	refreshHud()
	-- The rebirth checklist also refreshes when cash / aura crosses a requirement.
	local rebirthChanged = currentPanel == "Rebirth" and rebirthSignature() ~= renderedRebirthSignature
	local questsChanged = currentPanel == "Quests" and state.questRev ~= renderedQuestRev
	local battleChanged = currentPanel == "Battle" and state.tower ~= renderedTower
	local busy = currentPanel == "Battle" and battling -- don't rebuild the arena mid-fight
	if currentPanel and not busy and (state.rev ~= renderedRev or rebirthChanged or questsChanged or battleChanged) then
		-- The Auto Packer adds cards every few seconds; rebuilding a big screen that often
		-- makes buttons hard to press, so its updates are spaced out. Anything the player did
		-- themselves (an upgrade, a purchase) always shows straight away.
		if fromAutoPacker and os.clock() - lastRenderAt < 4 then
			renderQueued = true
		else
			renderPanel()
		end
	end
end)

Remotes.Notify.OnClientEvent:Connect(function(text, kind)
	toast(tostring(text), kind)
end)

-- Someone in the server pulled a Mythic or Secret card.
Remotes.Announce.OnClientEvent:Connect(function(playerName, key)
	if Cards.parse(key) then
		toast("🌟 " .. tostring(playerName) .. " pulled " .. Cards.getDisplayName(key) .. "!", "announce")
	end
end)

-- The vault safe in the store opens the Rebirth screen, which starts with the vault.
Remotes.OpenRebirth.OnClientEvent:Connect(function()
	if currentPanel ~= "Rebirth" or not window.Visible then
		openPanel("Rebirth")
	end
end)

-- The Auto Packer just opened a pack: show the best card on the HUD ticker.
Remotes.AutoPull.OnClientEvent:Connect(function(pulled, newBest)
	if type(pulled) ~= "table" then
		return
	end
	-- a new personal best gets a sound and a banner
	if Cards.parse(newBest) then
		playSound("bigPull")
		toast("🤖 New best card: " .. Cards.getDisplayName(newBest) .. "!", "announce")
	end
	local bestKey, bestIncome, sold = nil, -1, 0
	for _, entry in ipairs(pulled) do
		if entry.sold then
			sold = sold + 1
		end
		local income = Cards.getIncome(entry.key)
		if Cards.parse(entry.key) and income > bestIncome then
			bestKey, bestIncome = entry.key, income
		end
	end
	if bestKey then
		local def = Cards.parse(bestKey)
		local text = "🤖 " .. Cards.getDisplayName(bestKey)
		if sold > 0 then
			text = text .. "  (sold " .. sold .. ")"
		end
		autoLabel.Text = text
		autoLabel.TextColor3 = def.rarity == "Secret" and Color3.fromRGB(255, 90, 90) or Cards.Rarities[def.rarity].color:Lerp(Color3.new(1, 1, 1), 0.4)
		autoLabel.Visible = true
	end
end)

Remotes.OpenBattle.OnClientEvent:Connect(function()
	if currentPanel ~= "Battle" or not window.Visible then
		openPanel("Battle")
	end
end)

Remotes.OpenTrade.OnClientEvent:Connect(function()
	if currentPanel ~= "Trade" or not window.Visible then
		openPanel("Trade")
	end
end)

Remotes.MarketState.OnClientEvent:Connect(function(listings)
	market = type(listings) == "table" and listings or {}
	if currentPanel == "Trade" then
		renderPanel()
	end
end)

Remotes.TradeState.OnClientEvent:Connect(function(newTrade)
	local started = activeTrade == nil and newTrade ~= nil
	activeTrade = newTrade
	if started then
		-- a trade just began: bring the trade window up
		tradeRequestsIn = {}
		if currentPanel ~= "Trade" or not window.Visible then
			openPanel("Trade")
			return
		end
	end
	if currentPanel == "Trade" then
		renderPanel()
	end
end)

Remotes.TradeRequest.OnClientEvent:Connect(function(fromUserId, fromName)
	for _, request in ipairs(tradeRequestsIn) do
		if request.userId == fromUserId then
			return
		end
	end
	table.insert(tradeRequestsIn, { userId = fromUserId, name = tostring(fromName) })
	toast("🤝 " .. tostring(fromName) .. " wants to trade! Open Trade to accept.", "info")
	if currentPanel == "Trade" then
		renderPanel()
	end
end)

Remotes.OpenShop.OnClientEvent:Connect(function()
	if currentPanel ~= "Packs" or not window.Visible then
		openPanel("Packs")
	end
end)

---------------------------------------------------------------------
-- Hotkeys: keyboard letters on PC, buttons on a gamepad / console
---------------------------------------------------------------------
local keyToPanel = {}
for _, entry in ipairs(MENU) do
	keyToPanel[Enum.KeyCode[entry[4]]] = entry[1]
end

local function usingGamepad()
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil
end

local function closeWindow()
	window.Visible = false
	currentPanel = nil
	GuiService.SelectedObject = nil
end

-- Opens the panel `step` places along the menu from the current one (gamepad bumpers).
local function cyclePanel(step)
	local index = 0
	for position, entry in ipairs(MENU) do
		if entry[1] == currentPanel then
			index = position
		end
	end
	if index == 0 then
		index = 1
	else
		index = (index - 1 + step) % #MENU + 1
	end
	if MENU[index][1] ~= currentPanel or not window.Visible then
		openPanel(MENU[index][1])
	end
	task.defer(function()
		if window.Visible then
			GuiService:Select(window)
		end
	end)
end

local function refreshControls()
	local inputType = UserInputService:GetLastInputType()
	local keyboard = inputType == Enum.UserInputType.Keyboard or string.find(inputType.Name, "Mouse") ~= nil
	for _, badge in ipairs(keyBadges) do
		badge.Visible = keyboard
	end
	if usingGamepad() then
		controlsLabel.Text = "🎮 Y: menu   LB / RB: switch screen\nA: select   B: close"
	elseif keyboard then
		controlsLabel.Text = "Press the letter on a button to open it,\nand again to close. Space: next card."
	else
		controlsLabel.Text = ""
	end
end

UserInputService.LastInputTypeChanged:Connect(refreshControls)
refreshControls()

UserInputService.InputBegan:Connect(function(input, processed)
	if UserInputService:GetFocusedTextBox() then
		return -- typing a price
	end
	local key = input.KeyCode

	-- during a pack reveal: Space / Enter / A moves on to the next card
	if revealGui.Enabled then
		if key == Enum.KeyCode.Space or key == Enum.KeyCode.Return or key == Enum.KeyCode.ButtonA then
			clickSignal:Fire()
		end
		return
	end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		if processed then
			return
		end
		local panel = keyToPanel[key]
		if panel then
			openPanel(panel)
		end
	elseif key == Enum.KeyCode.ButtonY then
		-- Y: jump to the menu, or close whatever is open
		if window.Visible then
			closeWindow()
		elseif GuiService.SelectedObject then
			GuiService.SelectedObject = nil
		else
			GuiService.SelectedObject = packsButton
		end
	elseif key == Enum.KeyCode.ButtonB then
		if window.Visible then
			closeWindow()
		end
	elseif key == Enum.KeyCode.ButtonR1 then
		cyclePanel(1)
	elseif key == Enum.KeyCode.ButtonL1 then
		cyclePanel(-1)
	end
end)

refreshHud()
Remotes:WaitForChild("RequestState"):FireServer()

-- Keeps the lucky-event countdown ticking.
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()
		if state.luckEventEndsAt - now > -2 or state.boosts.cashUntil - now > -2 or state.boosts.luckUntil - now > -2 then
			refreshHud() -- keep the countdowns ticking
		end
		if renderQueued and currentPanel and os.clock() - lastRenderAt >= 4 and not (currentPanel == "Battle" and battling) then
			renderPanel()
		end
	end
end)
