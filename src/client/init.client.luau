-- Aura Packs — client UI. Everything is built from code, so there is nothing to set up in Studio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

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
local Duel = require(Shared:WaitForChild("Duel"))
local Titles = require(Shared:WaitForChild("Titles"))
local Staff = require(Shared:WaitForChild("Staff"))

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
	battleDeck = {},
	challengeDay = 0,
	titles = {},
	title = "",
	loadouts = {},
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
	isAdmin = false,
	admins = {},
	autoUpgrade = false,
	perks = {},
	tower = 0,
	luckEventEndsAt = 0,
	slotCount = Config.BaseSlots,
	incomePerSec = 0,
	cashCap = math.huge,
	boosts = { luckUntil = 0, cashUntil = 0 },
	showcase = { left = "", right = "" },
	packsOpened = 0,
	stats = { fused = 0, earned = 0, duels = 0 },
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

-- Like addScale, but shrinks to fit a narrow screen as well as a short one: the instance is
-- drawn as if the screen were at least `width` x `height`.
local function addFitScale(instance, width, height)
	local scale = make("UIScale", {}, instance)
	local camera = workspace.CurrentCamera
	local function update()
		local size = camera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / width, size.Y / height), 0.45, 1.25)
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
local eventLabel = newLabel(hud, "", UDim2.new(), UDim2.new(1, 0, 0, 16), {
	LayoutOrder = 3,
	TextSize = 12,
	TextColor3 = Color3.fromRGB(255, 215, 90),
	TextStrokeTransparency = 0.3,
	TextWrapped = false,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
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
-- Sounds are always played on this client only (PlayLocalSound), never for other players.
local windowFocused = true
UserInputService.WindowFocused:Connect(function()
	windowFocused = true
end)
UserInputService.WindowFocusReleased:Connect(function()
	windowFocused = false
end)
local function playSound(name)
	local id = Config.Sounds[name]
	if id == nil or id == "" then
		return
	end
	if not windowFocused then
		return -- no noise from a window you are not looking at
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
local openPanel -- defined below
local renderDuelHud, duelAct -- the duel screen, defined with the Battle panel
local renderedRev = -1
local panels = {}

-- Long lists (the deck screen, the battle deck editor) can hold thousands of cards. Building a
-- card's picture and buttons is the slow part, so those screens only lay out empty boxes and
-- the loop below fills in the ones on screen (plus a little either side) as you scroll, and
-- empties them again once they are far away.
local lazyFrames = {} -- { frame, build = function(frame), built, keep = { [child] = true } }
local lazyPending = false -- something still needs building (or the layout isn't ready yet)
local lazyCanvasY, lazyWindowY = -1, -1
local LAZY_BUILDS_PER_FRAME = 16

local function fillLazily(frame, build)
	local keep = {}
	for _, child in ipairs(frame:GetChildren()) do
		keep[child] = true
	end
	table.insert(lazyFrames, { frame = frame, build = build, built = false, keep = keep })
	lazyPending = true
end

local function clearBody()
	table.clear(lazyFrames)
	for _, child in ipairs(body:GetChildren()) do
		child:Destroy()
	end
	actionButton.Visible = false
end

RunService.RenderStepped:Connect(function()
	if #lazyFrames == 0 or not window.Visible then
		return
	end
	local canvasY, windowY = body.CanvasPosition.Y, body.AbsoluteWindowSize.Y
	if not lazyPending and canvasY == lazyCanvasY and windowY == lazyWindowY then
		return -- nothing moved since the last look
	end
	lazyCanvasY, lazyWindowY = canvasY, windowY
	local top = body.AbsolutePosition.Y
	local margin = windowY * 0.75
	local budget = LAZY_BUILDS_PER_FRAME
	local pending = false
	for _, entry in ipairs(lazyFrames) do
		local height = entry.frame.AbsoluteSize.Y
		if height <= 0 then
			pending = true -- not laid out yet; look again next frame
		else
			local y = entry.frame.AbsolutePosition.Y - top
			if y + height > -margin and y < windowY + margin then
				if not entry.built then
					if budget > 0 then
						budget = budget - 1
						entry.built = true
						entry.build(entry.frame)
					else
						pending = true
					end
				end
			elseif entry.built and (y + height < -windowY * 3 or y > windowY * 4) then
				entry.built = false
				for _, child in ipairs(entry.frame:GetChildren()) do
					if not entry.keep[child] then
						child:Destroy()
					end
				end
			end
		end
	end
	lazyPending = pending
end)

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

	-- Auto Packer: opens the chosen pack on a timer (one of Harshdeep's upgrades)
	local packerInterval = Perks.packerInterval(state.perks)
	local autoRow = newRow(0, 60)
	autoRow.BackgroundColor3 = Color3.fromRGB(38, 58, 82)
	if packerInterval == nil then
		newLabel(autoRow, "🤖 Auto Packer — opens packs for you while you play. Hire Harshdeep in Upgrades → Staff to unlock it.", UDim2.new(0, 14, 0, 0), UDim2.new(1, -28, 1, 0), { TextSize = 14 })
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
		local unlocked = Packs.unlocked(pack, state.rebirths)
		if unlocked then
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
		if not unlocked then
			local locked = newButton(row, "🔒 " .. Packs.unlockText(pack), buttonPosition, buttonSize, COLORS.locked, nil)
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
-- An empty box in a card grid. The card face is drawn, and `addControls(cell)` run, only
-- when the box scrolls into view.
local function newCardCell(parent, key, order, addControls)
	local cell = make("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	fillLazily(cell, function()
		local holder = make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 4, 0, 4),
			Size = UDim2.new(1, -8, 0, 157),
		}, cell)
		CardView.new(key).Parent = holder
		addControls(cell)
	end)
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
		return -((table.find(Cards.SetOrder, def.set) or 0) * 1000 + def.number)
	elseif deckSort == "effect" then
		return (table.find(Cards.VariantOrder, variantId) or 0) * 1e12 + Cards.getIncome(key)
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

	-- saved decks: one tap to remember the deck, one to swap back to it
	local savedRow = newRow(4, 40)
	savedRow.BackgroundTransparency = 1
	newLabel(savedRow, "Saved decks:", UDim2.new(0, 4, 0, 0), UDim2.new(0, 96, 1, 0), { TextSize = 13, TextColor3 = COLORS.dim })
	for number = 1, Config.Loadouts do
		local saved = state.loadouts[tostring(number)]
		local size = type(saved) == "table" and #saved or 0
		local x = 100 + (number - 1) * 176
		newButton(savedRow, size > 0 and ("Load " .. number .. " (" .. size .. ")") or ("Deck " .. number .. " empty"), UDim2.new(0, x, 0, 3), UDim2.new(0, 108, 0, 34), size > 0 and COLORS.button or COLORS.locked, function()
			Remotes.Loadout:FireServer("load", number)
		end).TextSize = 12
		newButton(savedRow, "Save", UDim2.new(0, x + 112, 0, 3), UDim2.new(0, 54, 0, 34), COLORS.good, function()
			Remotes.Loadout:FireServer("save", number)
		end).TextSize = 12
	end

	-- sort and filter
	local sortRow = newRow(5, 40)
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
		LayoutOrder = 6,
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
		order = order + 1
		newCardCell(page, key, order, function(cell)
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
		end)
	end

	local keys = {}
	for key in pairs(state.inventory) do
		if passesFilter(key) then
			table.insert(keys, key)
		end
	end
	table.sort(keys, sortKeys)

	local vaultHasRoom = #state.vault < state.vaultSlots
	for _, key in ipairs(keys) do
		order = order + 1
		local copies = state.inventory[key]
		newCardCell(page, key, order, function(cell)
			newLabel(cell, "x" .. copies, UDim2.new(1, -44, 0, 0), UDim2.new(0, 44, 0, 18), {
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
			local canFuse = nextVariant ~= nil and copies >= Config.FuseCount
			local canVault = vaultHasRoom
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
		end)
	end

	if order == 0 then
		page:Destroy()
		newLabel(newRow(6, 60), deckSetFilter == "all" and "No cards yet — open a pack from the Pack Shop!" or "No cards from that set. Tap the set button to change the filter.", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), {
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

local resetConfirmUntil = 0 -- the Full reset button must be tapped twice within a few seconds

panels.Rebirth = function()
	titleLabel.Text = "🌟 Rebirth  (" .. state.rebirths .. " so far)"
	useList()
	local level, ready, requirements = Rebirth.check(state)
	renderedRebirthSignature = rebirthSignature()

	local bonusRow = newRow(1, level and 104 or 40)
	newLabel(bonusRow, "Now:   " .. Rebirth.describeBonuses(state.rebirths), UDim2.new(0, 14, 0, 8), UDim2.new(1, -28, 0, 22), {
		TextSize = 15,
	})
	if level then
		newLabel(bonusRow, "Next:  " .. Rebirth.describeBonuses(state.rebirths + 1), UDim2.new(0, 14, 0, 34), UDim2.new(1, -28, 0, 22), {
			TextSize = 15,
			TextColor3 = Color3.fromRGB(255, 215, 90),
		})
		-- what the next rebirth opens up: a new set, more shelves, maybe a new employee
		local nextRebirths = state.rebirths + 1
		local unlocks = {}
		for _, pack in ipairs(Packs.List) do
			if pack.kind == "booster" and pack.rebirths == nextRebirths then
				table.insert(unlocks, "🎴 " .. Packs.setsText(pack) .. " packs")
			end
		end
		local shelvesNow, shelvesNext = Upgrades.rebirthSlotCap(state.rebirths), Upgrades.rebirthSlotCap(nextRebirths)
		if shelvesNext > shelvesNow then
			table.insert(unlocks, "🗄️ up to " .. shelvesNext .. " deck slots (now " .. shelvesNow .. ")")
		end
		for _, staffId in ipairs(Staff.Order) do
			if Staff.Defs[staffId].rebirths == nextRebirths then
				table.insert(unlocks, "🧑‍💼 " .. Staff.Defs[staffId].name .. " joins your staff")
			end
		end
		newLabel(bonusRow, "Unlocks:  " .. (#unlocks > 0 and table.concat(unlocks, "   ·   ") or "one more level of every staff upgrade"), UDim2.new(0, 14, 0, 60), UDim2.new(1, -28, 0, 38), {
			TextSize = 13,
			TextColor3 = Color3.fromRGB(150, 255, 170),
			TextYAlignment = Enum.TextYAlignment.Top,
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

	-- full reset: small, red and at the very bottom so nobody hits it by accident
	local wipeRow = newRow(900, 34)
	wipeRow.BackgroundTransparency = 1
	newLabel(wipeRow, "Start over completely? Wipes everything, rebirths and collection included.", UDim2.new(0, 4, 0, 0), UDim2.new(1, -150, 1, 0), {
		TextSize = 11,
		TextColor3 = COLORS.dim,
	})
	local wipeButton
	wipeButton = newButton(wipeRow, "Full reset", UDim2.new(1, -140, 0, 5), UDim2.new(0, 128, 0, 24), COLORS.bad, function()
		if os.clock() < resetConfirmUntil then
			resetConfirmUntil = 0
			Remotes.ResetData:FireServer()
		else
			resetConfirmUntil = os.clock() + 4
			wipeButton.Text = "Tap again to wipe"
		end
	end)
	wipeButton.TextSize = 12
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

	-- this week's event
	local weekly = Season.event()
	local eventRow = newRow(0, 40)
	eventRow.BackgroundColor3 = Color3.fromRGB(60, 45, 80)
	newButton(eventRow, "Claim all", UDim2.new(1, -160, 0, 4), UDim2.new(0, 148, 0, 32), COLORS.good, function()
		Remotes.ClaimAll:FireServer()
	end).TextSize = 15
	newLabel(eventRow, "🎉 This week:  " .. weekly.name .. "  —  " .. weekly.text, UDim2.new(0, 14, 0, 0), UDim2.new(1, -180, 1, 0), {
		Font = Enum.Font.FredokaOne,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 215, 90),
	})

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

	-- Titles: shown over your head. Earned ones first.
	local earnedCount = 0
	for _, title in ipairs(Titles.List) do
		if state.titles[title.id] then
			earnedCount = earnedCount + 1
		end
	end
	local titleHeader = newRow(200, 44)
	titleHeader.BackgroundColor3 = Color3.fromRGB(60, 45, 80)
	newLabel(titleHeader, "🎖️ Titles  ·  " .. earnedCount .. "/" .. #Titles.List .. "  ·  worn over your head", UDim2.new(0, 14, 0, 0), UDim2.new(1, -180, 1, 0), {
		Font = Enum.Font.FredokaOne,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(255, 215, 90),
	})
	if state.title ~= "" then
		newButton(titleHeader, "Take off", UDim2.new(1, -160, 0, 6), UDim2.new(0, 148, 0, 32), COLORS.locked, function()
			Remotes.SetTitle:FireServer("")
		end).TextSize = 14
	end
	for index, title in ipairs(Titles.List) do
		local earned = state.titles[title.id] == true
		local row = newRow((earned and 200 or 300) + index, 48)
		newLabel(row, title.name, UDim2.new(0, 14, 0, 4), UDim2.new(1, -190, 0, 20), {
			Font = Enum.Font.FredokaOne,
			TextSize = 16,
			TextColor3 = earned and COLORS.text or COLORS.dim,
		})
		newLabel(row, title.text .. (title.aura > 0 and ("   ·   +" .. Format.short(title.aura) .. " aura") or ""), UDim2.new(0, 14, 0, 25), UDim2.new(1, -190, 0, 18), {
			TextSize = 12,
			TextColor3 = COLORS.dim,
		})
		if not earned then
			newButton(row, "Locked", UDim2.new(1, -160, 0, 8), UDim2.new(0, 148, 0, 32), COLORS.locked, nil).AutoButtonColor = false
		elseif state.title == title.id then
			newButton(row, "Wearing", UDim2.new(1, -160, 0, 8), UDim2.new(0, 148, 0, 32), COLORS.good, nil).AutoButtonColor = false
		else
			newButton(row, "Wear", UDim2.new(1, -160, 0, 8), UDim2.new(0, 148, 0, 32), COLORS.button, function()
				Remotes.SetTitle:FireServer(title.id)
			end)
		end
	end
end

-- Staff: permanent aura upgrades, shown under the store upgrades ---------------------
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
	newLabel(header, "🧑‍💼 Staff — permanent upgrades, paid in aura. Each rebirth unlocks one more level.", UDim2.new(0, 14, 0, 0), UDim2.new(1, -28, 1, 0), {
		Font = Enum.Font.FredokaOne,
		TextSize = 16,
		TextColor3 = COLORS.aura,
	})
	for staffIndex, staffId in ipairs(Staff.Order) do
		local staff = Staff.Defs[staffId]
		local base = 20 + staffIndex * 10
		local unlocked = Staff.unlocked(staffId, state.rebirths)
		local staffLevel = Staff.level(state.perks, staffId)
		local staffRow = newRow(base, 52)
		staffRow.BackgroundColor3 = staff.color:Lerp(COLORS.panel, 0.65)
		newLabel(staffRow, staff.face .. " " .. staff.name .. "  ·  " .. staff.role, UDim2.new(0, 14, 0, 4), UDim2.new(1, -28, 0, 22), {
			Font = Enum.Font.FredokaOne,
			TextSize = 18,
		})
		local status
		if not unlocked then
			status = "🔒 Joins your store after " .. staff.rebirths .. (staff.rebirths == 1 and " rebirth." or " rebirths.")
		elseif staffLevel < 1 then
			status = "For hire: \"" .. staff.hire .. "\""
		else
			status = "Level " .. staffLevel .. "/" .. Staff.maxLevel(staffId) .. "  ·  the " .. staff.desk .. " at the back of your store gets grander as you upgrade."
		end
		newLabel(staffRow, status, UDim2.new(0, 14, 0, 27), UDim2.new(1, -28, 0, 20), {
			TextSize = 12,
			TextColor3 = COLORS.dim,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		if unlocked then
			for perkIndex, perkId in ipairs(staff.perks) do
				local def = Perks.Defs[perkId]
				local level = Perks.level(state.perks, perkId)
				local row = newRow(base + perkIndex, 72)
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
					-- each rebirth opens one more level of every upgrade
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
	end
end

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

-- Store: game passes and aura bundles ------------------------------------------------
local codeText = ""

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

	local note = newRow(order + 1, 34)
	note.BackgroundTransparency = 1
	newLabel(note, "Purchases are optional. Everything in the game can be earned by playing.", UDim2.new(0, 4, 0, 0), UDim2.new(1, -8, 1, 0), {
		TextSize = 13,
		TextColor3 = COLORS.dim,
	})
end

-- Battle tower: turn-based duels ------------------------------------------------------
-- A duel is played on the player's duel pad in the arena: the enemies are giant shadow cards
-- (built here, on this client only), the camera pulls in behind the player, and the hand sits
-- along the bottom of the screen. The server decides everything; this only shows it.
local battling = false -- a duel is in progress
local renderedTower = -1
local duel = nil -- what the server last told us about the duel in progress
local duelTarget = 1 -- which enemy the next card is aimed at
local duelLog = {} -- the last few things that happened
local duelBusy = false -- waiting for the server, or playing back a round
local duelEnding = nil -- the result line, once the duel is over
local deckEditing = false
local stage = nil -- the 3D scene: { folder, spot, figures = { { part, home, gui, ... } } }
local duelAuto = false -- the Auto battler is playing for you
local autoToken = 0 -- changes whenever a duel ends, so a queued "next floor" can tell it is stale
local startDuel -- defined below
local battleHelp = false -- the "How battles work" box in the lobby is open

-- New duellists get a coach: a line of advice each round and a glow on a good move.
local function learningDuels()
	return state.stats == nil or (state.stats.duels or 0) < 3
end

-- What the coach says right now, given the move it would make.
local function coachText(suggestion)
	if duel.round == 1 and #duelLog == 0 then
		return "👋 These are your cards. Each one costs the ⚡ shown on it, and you have ⚡" .. duel.energy .. ". Tap Play on the glowing card."
	end
	if suggestion.kind == "pass" then
		return "Your cards cost more ⚡ than you have. Tap ⏭ Pass: you gain +1 ⚡ every round, so the big cards come later."
	end
	local card = Duel.card(duel.hand[suggestion.hand])
	local alive, winding = 0, false
	for _, enemy in ipairs(duel.enemies) do
		if enemy.hp > 0 then
			alive = alive + 1
			winding = winding or enemy.winding
		end
	end
	if card.role == "heal" then
		return "💚 You are hurt. A Heal card restores your health instead of attacking: the glowing one is a good play now."
	elseif card.role == "shield" then
		return winding and "⚠️ The boss is winding up a huge hit. Play the glowing 🛡️ Shield now to block most of it!" or "🛡️ A Shield cuts the next hit on you. Play it before the enemies strike."
	elseif card.role == "charge" then
		return "🔥 A Power-up makes your NEXT attack much stronger. Play it now, then attack next round."
	elseif card.role == "weaken" then
		return "🌀 Weaken makes one enemy's next attack much smaller. Use it on whoever hits hardest."
	elseif card.role == "blast" then
		return "💥 A Blast hits every enemy at once: best when several are still standing."
	end
	local target = suggestion.target and duel.enemies[suggestion.target]
	if alive > 1 and target and suggestion.target ~= duelTarget then
		return "🎯 Tap an enemy to aim at it (yellow outline). Try " .. target.name .. ": knocking one out means fewer hits on you."
	elseif target and Cards.typeBeats(card.type, target.type) then
		return "✨ \"Strong!\" means your card's type beats the enemy's: +30% damage. Check the type icons before you attack."
	end
	return "After your move the enemies hit back. Then you gain +1 ⚡ and draw back up to " .. Duel.HandSize .. " cards. ✖ throws away a card you don't want."
end

-- The Auto battler unlocks once you have finished one battle yourself.
local function autoUnlocked()
	return state.tower >= 1 or (state.stats ~= nil and (state.stats.duels or 0) >= 1)
end

local function typeText(typeId)
	local info = Cards.Types[typeId]
	return info and (info.icon .. " " .. info.name) or ""
end

-- "⚡2  ⚔️ Strike"
local function roleLine(card)
	local role = Duel.Roles[card.role]
	return "⚡" .. card.cost .. "  " .. role.icon .. " " .. role.name
end

local function newBar(parent, position, size, color, fraction, text)
	local bar = make("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(15, 15, 22),
		BorderSizePixel = 0,
	}, parent)
	round(bar, 5)
	local fill = make("Frame", {
		Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, bar)
	round(fill, 5)
	local label = newLabel(bar, text, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), {
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
	})
	return fill, label
end

local function newNoteRow(order, text)
	local row = newRow(order, 44)
	row.BackgroundTransparency = 1
	newLabel(row, text, UDim2.new(0, 4, 0, 0), UDim2.new(1, -8, 1, 0), { TextSize = 12, TextColor3 = COLORS.dim })
end

-- The duel's own screen furniture: a log at the top, your hand along the bottom.
local duelGui = make("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 1, 0),
	Visible = false,
}, screen)
local duelTop = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 56),
	Size = UDim2.new(0, 560, 0, 104),
	BackgroundColor3 = Color3.fromRGB(18, 18, 28),
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
}, duelGui)
round(duelTop, 12)
addFitScale(duelTop, 600, 620)
local duelTitle = newLabel(duelTop, "", UDim2.new(0, 14, 0, 4), UDim2.new(1, -150, 0, 24), {
	Font = Enum.Font.FredokaOne,
	TextSize = 18,
	TextColor3 = Color3.fromRGB(255, 215, 90),
})
local duelLogLabel = newLabel(duelTop, "", UDim2.new(0, 14, 0, 28), UDim2.new(1, -28, 1, -34), {
	TextSize = 13,
	TextYAlignment = Enum.TextYAlignment.Bottom,
	TextWrapped = false,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
local autoButton = newButton(duelTop, "", UDim2.new(1, -128, 0, 5), UDim2.new(0, 120, 0, 24), COLORS.locked, nil)
autoButton.TextSize = 12
local duelBottom = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.new(0, 640, 0, 272),
	BackgroundTransparency = 1,
}, duelGui)
addFitScale(duelBottom, 660, 560)
local duelControls = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) }, duelBottom)

local TYPE_GLOW = {
	warrior = Color3.fromRGB(235, 80, 70),
	beast = Color3.fromRGB(90, 200, 100),
	mystic = Color3.fromRGB(170, 90, 240),
	tech = Color3.fromRGB(80, 170, 255),
	star = Color3.fromRGB(255, 205, 70),
}
local TARGET_GLOW = Color3.fromRGB(255, 240, 120)

local function clearStage()
	if stage then
		stage.folder:Destroy()
		for _, figure in ipairs(stage.figures) do
			figure.gui:Destroy()
		end
		stage = nil
	end
end

-- Builds the enemies as giant cards standing at the far end of the duel pad.
local function buildStage(spot, view)
	clearStage()
	local folder = Instance.new("Folder")
	folder.Name = "DuelStage"
	folder.Parent = workspace
	local figures = {}
	local count = #view.enemies
	for index, enemy in ipairs(view.enemies) do
		local size = enemy.boss and Vector3.new(7, 10, 0.5) or Vector3.new(4.6, 6.6, 0.4)
		local home = spot * CFrame.new((index - (count + 1) / 2) * 7.5, size.Y / 2 - 0.2, -13) * CFrame.Angles(0, math.pi, 0)
		local part = Instance.new("Part")
		part.Name = "Enemy" .. index
		part.Anchored = true
		part.CanCollide = false
		part.Size = size
		part.CFrame = home
		part.Color = Color3.fromRGB(34, 26, 48)
		part.Material = Enum.Material.SmoothPlastic
		part.Parent = folder

		local glow = Instance.new("Highlight")
		glow.FillTransparency = 1
		glow.OutlineColor = TYPE_GLOW[enemy.type] or Color3.new(1, 1, 1)
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = part

		local face = Instance.new("SurfaceGui")
		face.Face = Enum.NormalId.Front
		face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		face.PixelsPerStud = 30
		face.Parent = part
		newLabel(face, enemy.glyph or "?", UDim2.new(0.1, 0, 0.2, 0), UDim2.new(0.8, 0, 0.5, 0), {
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		newLabel(face, typeText(enemy.type), UDim2.new(0.05, 0, 0.76, 0), UDim2.new(0.9, 0, 0.14, 0), {
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = TYPE_GLOW[enemy.type] or COLORS.text,
		})

		-- name, health and status float above the card; tapping it aims at this enemy
		local gui = Instance.new("BillboardGui")
		gui.Name = "DuelEnemy" .. index
		gui.Adornee = part
		gui.Size = UDim2.new(0, 190, 0, 70)
		gui.StudsOffset = Vector3.new(0, size.Y / 2 + 2.4, 0)
		gui.AlwaysOnTop = true
		gui.Active = true
		gui.ResetOnSpawn = false
		gui.Parent = playerGui
		local button = make("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(18, 18, 28),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
		}, gui)
		round(button, 8)
		local stroke = make("UIStroke", { Color = TARGET_GLOW, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Enabled = false }, button)
		newLabel(button, enemy.name, UDim2.new(0, 6, 0, 2), UDim2.new(1, -12, 0, 18), {
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local fill, hpLabel = newBar(button, UDim2.new(0, 8, 0, 22), UDim2.new(1, -16, 0, 16), COLORS.bad, 1, "")
		local marks = newLabel(button, "", UDim2.new(0, 6, 0, 40), UDim2.new(1, -12, 0, 28), {
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Color3.fromRGB(255, 190, 120),
		})
		figures[index] = { part = part, home = home, gui = gui, glow = glow, stroke = stroke, fill = fill, hpLabel = hpLabel, marks = marks, down = false }
		button.Activated:Connect(function()
			if duel and duel.enemies[index] and duel.enemies[index].hp > 0 and not duelBusy then
				duelTarget = index
				renderDuelHud()
			end
		end)
	end
	stage = { folder = folder, spot = spot, figures = figures }
end

-- Camera: behind and above the player, looking at the enemies.
local function aimCamera(spot)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local goal = CFrame.lookAt((spot * CFrame.new(9, 10, 13)).Position, (spot * CFrame.new(0, 3.5, -9)).Position)
	TweenService:Create(camera, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal }):Play()
end

local function releaseCamera()
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

-- A number that floats up from a point in the world and fades.
local function floatText(position, text, color)
	if stage == nil then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = stage.folder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 150, 0, 40)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = newLabel(gui, text, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), {
		Font = Enum.Font.FredokaOne,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = color,
		TextStrokeTransparency = 0,
	})
	TweenService:Create(gui, TweenInfo.new(0.9), { StudsOffset = Vector3.new(0, 5, 0) }):Play()
	local fade = TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 })
	fade:Play()
	fade.Completed:Connect(function()
		anchor:Destroy()
	end)
end

-- Your card's attack: a glowing ball flies from you to the enemy, which flinches.
local function strikeEffect(figure, text, strong)
	if stage == nil then
		return
	end
	local from = (stage.spot * CFrame.new(0, 3, -1.5)).Position
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.Material = Enum.Material.Neon
	ball.Color = strong and TARGET_GLOW or Color3.fromRGB(150, 220, 255)
	ball.Size = Vector3.new(1.6, 1.6, 1.6)
	ball.Position = from
	ball.Parent = stage.folder
	local fly = TweenService:Create(ball, TweenInfo.new(0.18, Enum.EasingStyle.Linear), { Position = figure.home.Position })
	fly:Play()
	fly.Completed:Wait()
	ball:Destroy()
	if stage == nil then
		return
	end
	floatText(figure.home.Position + Vector3.new(0, 2, 0), text, strong and TARGET_GLOW or Color3.new(1, 1, 1))
	figure.part.Color = Color3.new(1, 1, 1)
	local flinch = TweenService:Create(figure.part, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { CFrame = figure.home * CFrame.new(0, 0, 1.2) })
	flinch:Play()
	TweenService:Create(figure.part, TweenInfo.new(0.3), { Color = Color3.fromRGB(34, 26, 48) }):Play()
end

-- An enemy's attack: it lunges at you and the screen flashes.
local function lungeEffect(figure, text)
	if stage == nil then
		return
	end
	local lunge = TweenService:Create(figure.part, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, true), { CFrame = figure.home * CFrame.new(0, 0, -6) })
	lunge:Play()
	task.wait(0.14)
	flashScreen(Color3.fromRGB(200, 40, 40))
	if stage then
		floatText((stage.spot * CFrame.new(0, 5, 0)).Position, text, Color3.fromRGB(255, 110, 110))
	end
end

local function leaveDuel()
	autoToken = autoToken + 1
	duel = nil
	duelEnding = nil
	duelLog = {}
	duelBusy = false
	battling = false
	duelGui.Visible = false
	hud.Visible = true
	clearStage()
	releaseCamera()
end

-- One move by the Auto battler. After a tower win it waits out the cooldown and starts the
-- next floor by itself; a defeat switches it off.
local function autoStep()
	if not duelAuto or duel == nil or duelBusy then
		return
	end
	if duelEnding then
		if duel.win and duel.mode == "tower" and duel.floor < Battle.MaxFloor then
			local token = autoToken
			task.delay(Config.BattleCooldown + 0.5, function()
				if duelAuto and token == autoToken and duel and duelEnding then
					leaveDuel()
					startDuel("tower")
				end
			end)
		else
			duelAuto = false
			renderDuelHud()
		end
		return
	end
	duelAct(Duel.suggest(duel))
end

autoButton.Activated:Connect(function()
	if duel == nil or not autoUnlocked() then
		return
	end
	duelAuto = not duelAuto
	renderDuelHud()
	if duelAuto then
		task.defer(autoStep)
	end
end)

function renderDuelHud()
	if duel == nil then
		return
	end
	autoButton.Visible = autoUnlocked()
	autoButton.Text = duelAuto and "🤖 Auto: ON" or "🤖 Auto: OFF"
	autoButton.BackgroundColor3 = duelAuto and COLORS.good or COLORS.locked
	local daily = duel.mode == "daily"
	duelTitle.Text = (daily and "📅 Daily challenge" or ("⚔️ Floor " .. duel.floor)) .. "  ·  Round " .. duel.round
	duelLogLabel.Text = #duelLog > 0 and table.concat(duelLog, "\n") or "Tap an enemy to aim, then play a card. Rarer cards cost more ⚡ — Pass to save up."

	-- the figures in the arena
	if stage then
		for index, figure in ipairs(stage.figures) do
			local enemy = duel.enemies[index]
			if enemy then
				local alive = enemy.hp > 0
				figure.fill.Size = UDim2.new(math.clamp(enemy.hp / enemy.maxHp, 0, 1), 0, 1, 0)
				figure.hpLabel.Text = alive and (Duel.short(enemy.hp) .. " / " .. Duel.short(enemy.maxHp)) or "KO"
				local marks = {}
				local kind = Duel.Kinds[enemy.kind]
				if kind and kind.name ~= "" then
					table.insert(marks, kind.name)
				end
				if enemy.boss and enemy.armor > 0 then
					table.insert(marks, "🛡️ Armoured")
				end
				if enemy.regen then
					table.insert(marks, "♻️ Regenerates")
				end
				if enemy.winding then
					table.insert(marks, "⚠️ BIG HIT NEXT")
				end
				if enemy.weak > 0 then
					table.insert(marks, "🌀 x" .. enemy.weak)
				end
				table.insert(marks, "hits for " .. Duel.short(enemy.attack))
				figure.marks.Text = alive and table.concat(marks, "  ·  ") or ""
				figure.stroke.Enabled = alive and index == duelTarget
				figure.glow.OutlineColor = (alive and index == duelTarget) and TARGET_GLOW or (TYPE_GLOW[enemy.type] or Color3.new(1, 1, 1))
				if not alive and not figure.down then
					figure.down = true
					TweenService:Create(figure.part, TweenInfo.new(0.5), {
						CFrame = figure.home * CFrame.new(0, -figure.part.Size.Y / 2 + 0.3, 2) * CFrame.Angles(math.rad(-85), 0, 0),
						Transparency = 0.6,
					}):Play()
				end
			end
		end
	end

	-- you and your hand
	for _, child in ipairs(duelControls:GetChildren()) do
		child:Destroy()
	end
	local status = make("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Color3.fromRGB(18, 18, 28),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, duelControls)
	round(status, 10)
	newBar(status, UDim2.new(0, 8, 0, 6), UDim2.new(0, 236, 0, 18), COLORS.good, duel.hp / duel.maxHp, "You: " .. Duel.short(duel.hp) .. " / " .. Duel.short(duel.maxHp))
	local extras = "🂠 " .. duel.deckLeft
	if duel.shields > 0 then
		extras = extras .. "   🛡️ x" .. duel.shields
	end
	if duel.charges > 0 then
		extras = extras .. "   🔥 x" .. duel.charges
	end
	newLabel(status, extras, UDim2.new(0, 10, 0, 26), UDim2.new(0, 236, 0, 16), { TextSize = 12, TextColor3 = COLORS.dim })
	newLabel(status, "⚡ " .. duel.energy .. " / " .. Duel.MaxEnergy, UDim2.new(0, 254, 0, 0), UDim2.new(0, 100, 1, 0), {
		Font = Enum.Font.FredokaOne,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(255, 215, 90),
	})

	if duelEnding then
		newButton(status, "Continue", UDim2.new(1, -168, 0, 5), UDim2.new(0, 160, 0, 36), COLORS.good, function()
			duelAuto = false
			leaveDuel()
			openPanel("Battle")
		end)
		local box = make("Frame", {
			Position = UDim2.new(0, 0, 0, 54),
			Size = UDim2.new(1, 0, 0, 90),
			BackgroundColor3 = Color3.fromRGB(18, 18, 28),
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
		}, duelControls)
		round(box, 12)
		newLabel(box, duelEnding, UDim2.new(0, 16, 0, 0), UDim2.new(1, -32, 1, 0), {
			Font = Enum.Font.FredokaOne,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = duel.win and COLORS.cash or COLORS.bad,
		})
		return
	end

	newButton(status, "🎯 Aim", UDim2.new(0, 360, 0, 5), UDim2.new(0, 82, 0, 36), Color3.fromRGB(150, 95, 230), function()
		if duelBusy then
			return
		end
		-- step to the next enemy still standing
		for step = 1, #duel.enemies do
			local index = (duelTarget + step - 1) % #duel.enemies + 1
			if duel.enemies[index].hp > 0 then
				duelTarget = index
				break
			end
		end
		renderDuelHud()
	end).TextSize = 14
	local passButton = newButton(status, "⏭ Pass", UDim2.new(0, 448, 0, 5), UDim2.new(0, 90, 0, 36), COLORS.button, function()
		duelAct({ kind = "pass" })
	end)
	passButton.TextSize = 14
	newButton(status, "Flee", UDim2.new(0, 544, 0, 5), UDim2.new(0, 88, 0, 36), COLORS.locked, function()
		duelAuto = false
		duelAct({ kind = "flee" })
	end).TextSize = 14

	-- the coach, for a player's first few duels
	local suggestion = nil
	if learningDuels() and not duelAuto and not duelBusy then
		suggestion = Duel.suggest(duel)
		local coach = make("TextLabel", {
			Position = UDim2.new(0, 0, 0, -50),
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Color3.fromRGB(18, 18, 28),
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Text = coachText(suggestion),
			TextColor3 = Color3.fromRGB(255, 235, 150),
			TextSize = 14,
			TextWrapped = true,
		}, duelControls)
		round(coach, 10)
		make("UIStroke", { Color = Color3.fromRGB(255, 215, 90), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, coach)
		make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, coach)
		if suggestion.kind == "pass" then
			make("UIStroke", { Color = Color3.fromRGB(255, 225, 90), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, passButton)
		end
	end

	local aim = duel.enemies[duelTarget]
	local handCount = #duel.hand
	for index, key in ipairs(duel.hand) do
		local card = Duel.card(key)
		if card then
			local cell = make("Frame", {
				Position = UDim2.new(0.5, (index - (handCount + 1) / 2) * 128 - 62, 0, 52),
				Size = UDim2.new(0, 124, 0, 220),
				BackgroundColor3 = Color3.fromRGB(18, 18, 28),
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
			}, duelControls)
			round(cell, 10)
			if suggestion and suggestion.kind == "play" and suggestion.hand == index then
				make("UIStroke", { Color = Color3.fromRGB(255, 225, 90), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, cell)
			end
			local holder = make("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 14, 0, 6),
				Size = UDim2.new(0, 96, 0, 126),
			}, cell)
			CardView.new(key).Parent = holder
			local affordable = card.cost <= duel.energy
			newLabel(cell, roleLine(card), UDim2.new(0, 2, 0, 134), UDim2.new(1, -4, 0, 15), {
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = affordable and Color3.fromRGB(255, 215, 90) or COLORS.dim,
				TextWrapped = false,
			})
			local text = card.text
			if aim and card.role == "attack" then
				if Cards.typeBeats(card.type, aim.type) then
					text = text .. " (strong!)"
				elseif Cards.typeBeats(aim.type, card.type) then
					text = text .. " (resisted)"
				end
			end
			newLabel(cell, text, UDim2.new(0, 4, 0, 150), UDim2.new(1, -8, 0, 34), {
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = COLORS.dim,
			})
			newButton(cell, affordable and ("Play  [" .. index .. "]") or ("Need ⚡" .. card.cost), UDim2.new(0, 4, 0, 186), UDim2.new(1, -42, 0, 30), affordable and COLORS.good or COLORS.locked, function()
				if not affordable then
					toast("Not enough energy yet. Play a cheaper card, or Pass to save up.", "error")
					return
				end
				duelAct({ kind = "play", hand = index, target = duelTarget })
			end).TextSize = 13
			newButton(cell, "✖", UDim2.new(1, -36, 0, 186), UDim2.new(0, 32, 0, 30), COLORS.bad, function()
				duelAct({ kind = "discard", hand = index })
			end).TextSize = 13
		end
	end
end

-- Send one move to the server, then play back what happened step by step.
function duelAct(action)
	if duel == nil or duelBusy or duelEnding then
		return
	end
	duelBusy = true
	local ok, result = pcall(function()
		return Remotes.DuelAct:InvokeServer(action)
	end)
	if not ok or type(result) ~= "table" or not result.ok then
		duelBusy = false
		toast(ok and type(result) == "table" and result.error or "Could not reach the server. Try again.", "error")
		if ok and type(result) == "table" and result.ended then
			leaveDuel()
		end
		return
	end
	local final = result.view
	if final.fled then
		leaveDuel()
		openPanel("Battle")
		return
	end

	-- show the new hand and energy straight away, but let the health bars catch up one
	-- event at a time
	local finalHp, finalOver = final.hp, final.over
	final.hp = duel.hp
	final.over = false
	for index, enemy in ipairs(final.enemies) do
		enemy.finalHp = enemy.hp
		enemy.hp = duel.enemies[index] and duel.enemies[index].hp or enemy.hp
	end
	duel = final
	for _, event in ipairs(result.events) do
		if duel == nil then
			return -- the player left mid-playback
		end
		table.insert(duelLog, event.text)
		while #duelLog > 3 do
			table.remove(duelLog, 1)
		end
		local figure = stage and event.enemy and stage.figures[event.enemy] or nil
		if event.kind == "hit" then
			playSound("hit")
			if figure then
				strikeEffect(figure, "-" .. Duel.short(event.damage or 0), event.strong)
			end
		elseif event.kind == "hurt" then
			playSound("hit")
			if figure then
				lungeEffect(figure, "-" .. Duel.short(event.damage or 0))
			end
		elseif event.kind == "mend" then
			if figure then
				floatText(figure.home.Position + Vector3.new(0, 2, 0), "+", Color3.fromRGB(120, 255, 150))
			end
		elseif event.kind == "heal" then
			playSound("flip")
			flashScreen(Color3.fromRGB(60, 200, 110))
		elseif event.kind == "shield" or event.kind == "charge" or event.kind == "weaken" then
			playSound("flip")
		end
		if duel == nil then
			return
		end
		if event.enemy and event.enemyHp and duel.enemies[event.enemy] then
			duel.enemies[event.enemy].hp = event.enemyHp
		end
		if event.attack and event.enemy and duel.enemies[event.enemy] then
			duel.enemies[event.enemy].attack = event.attack
		end
		if event.hp then
			duel.hp = event.hp
		end
		renderDuelHud()
		task.wait(duelAuto and 0.2 or 0.45)
	end
	if duel == nil then
		return
	end
	duel.hp = finalHp
	duel.over = finalOver
	for _, enemy in ipairs(duel.enemies) do
		enemy.hp = enemy.finalHp
	end
	local target = duel.enemies[duelTarget]
	if target == nil or target.hp <= 0 then
		for index, enemy in ipairs(duel.enemies) do
			if enemy.hp > 0 then
				duelTarget = index
				break
			end
		end
	end
	if duel.over then
		if duel.win and duel.mode == "daily" then
			if result.aura then
				duelEnding = "🏆 Challenge complete!  +" .. Format.short(result.aura) .. " aura" .. (result.gift and " and a free booster 🎁" or "")
			else
				duelEnding = "🏆 Challenge complete!  (today's reward is already yours)"
			end
			playSound("bigPull")
		elseif duel.win then
			duelEnding = "🏆 VICTORY!  +" .. Format.short(result.aura or 0) .. " aura, " .. Format.cash(result.cash or 0)
			if result.drop then
				duelEnding = duelEnding .. "\n👑 Boss drop: " .. Cards.getDisplayName(result.drop) .. "!"
			end
			playSound("bigPull")
		else
			duelEnding = "💀 Defeat. Tune your battle deck, or pull stronger cards, and try again."
		end
	end
	duelBusy = false
	renderDuelHud()
	task.defer(autoStep)
end

function startDuel(mode)
	if battling then
		return
	end
	battling = true
	local ok, result = pcall(function()
		return Remotes.DuelStart:InvokeServer(mode)
	end)
	if not ok or type(result) ~= "table" or not result.ok then
		battling = false
		toast(ok and type(result) == "table" and result.error or "Could not start the battle.", "error")
		if duelAuto then
			-- the Auto battler could not start the next floor: stop and show the lobby
			duelAuto = false
			openPanel("Battle")
		end
		return
	end
	duel = result.view
	duelTarget = 1
	duelLog = {}
	duelEnding = nil
	duelBusy = false
	deckEditing = false
	window.Visible = false
	currentPanel = nil
	hud.Visible = false
	duelGui.Visible = true
	buildStage(result.spot, duel)
	aimCamera(result.spot)
	renderDuelHud()
	task.defer(autoStep)
end

panels.Battle = function()
	renderedTower = state.tower
	titleLabel.Text = "⚔️ Battle Tower  (" .. state.tower .. "/" .. Battle.MaxFloor .. " floors cleared)"
	useList()
	if duel then
		local row = newRow(1, 64)
		newLabel(row, "A duel is waiting for you in the arena.", UDim2.new(0, 14, 0, 0), UDim2.new(1, -180, 1, 0), {
			Font = Enum.Font.FredokaOne,
			TextSize = 18,
		})
		newButton(row, "Back to it", UDim2.new(1, -160, 0, 10), UDim2.new(0, 148, 0, 44), COLORS.good, function()
			window.Visible = false
			currentPanel = nil
		end)
		return
	end

	local floor = state.tower + 1
	local cleared = floor > Battle.MaxFloor
	local infoRow = newRow(1, 92)
	if cleared then
		newLabel(infoRow, "You cleared the whole tower. More floors are coming!", UDim2.new(0, 14, 0, 0), UDim2.new(1, -28, 1, 0), {
			Font = Enum.Font.FredokaOne,
			TextSize = 18,
		})
	else
		local aura, cash = Battle.reward(floor, state.cashCap)
		aura = aura * (Season.event().tower or 1)
		local boss = floor % Duel.BossEvery == 0
		newLabel(infoRow, (boss and "👑 BOSS  ·  " or "") .. "Floor " .. floor .. "   ·   win: +" .. Format.short(aura) .. " aura, " .. Format.cash(cash) .. (boss and ", a Legendary card" or ""), UDim2.new(0, 14, 0, 6), UDim2.new(1, -190, 0, 24), {
			Font = Enum.Font.FredokaOne,
			TextSize = 17,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local names = {}
		for _, enemy in ipairs(Duel.enemies(floor)) do
			local kind = Duel.Kinds[enemy.kind]
			table.insert(names, enemy.name .. " (" .. typeText(enemy.type) .. (kind.name ~= "" and (", " .. kind.name) or "") .. ", " .. Duel.short(enemy.maxHp) .. " HP)")
		end
		newLabel(infoRow, "Enemies: " .. table.concat(names, ",  "), UDim2.new(0, 14, 0, 32), UDim2.new(1, -190, 0, 54), {
			TextSize = 12,
			TextColor3 = COLORS.dim,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		newButton(infoRow, "FIGHT", UDim2.new(1, -160, 0, 8), UDim2.new(0, 148, 0, 42), COLORS.bad, function()
			duelAuto = false
			startDuel("tower")
		end)
		if autoUnlocked() then
			newButton(infoRow, "🤖 Auto climb", UDim2.new(1, -160, 0, 54), UDim2.new(0, 148, 0, 30), Color3.fromRGB(150, 95, 230), function()
				duelAuto = true
				startDuel("tower")
			end).TextSize = 13
		else
			local lockedAuto = newButton(infoRow, "🤖 Auto: finish 1 battle", UDim2.new(1, -160, 0, 54), UDim2.new(0, 148, 0, 30), COLORS.locked, nil)
			lockedAuto.TextSize = 11
			lockedAuto.AutoButtonColor = false
		end
	end

	-- daily challenge: a preset deck, the same for everyone
	local challenge = Duel.challenge(state.today)
	local won = state.challengeDay == state.today
	local dailyRow = newRow(2, 64)
	dailyRow.BackgroundColor3 = Color3.fromRGB(60, 45, 80)
	local challengeSet = Cards.Sets[challenge.set]
	newLabel(dailyRow, "📅 Daily challenge  ·  " .. challengeSet.icon .. " " .. challengeSet.name, UDim2.new(0, 14, 0, 6), UDim2.new(1, -190, 0, 22), {
		Font = Enum.Font.FredokaOne,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(255, 215, 90),
	})
	local dailyText = won and "✅ Won today. Come back tomorrow for a new one (you can replay for fun)."
		or ("Win with a preset " .. #challenge.deck .. "-card deck: +" .. Format.short(Quests.reward(state.rebirths) * Config.ChallengeAuraQuests * (Season.event().tower or 1)) .. " aura and a free booster.")
	newLabel(dailyRow, dailyText, UDim2.new(0, 14, 0, 30), UDim2.new(1, -190, 0, 30), {
		TextSize = 12,
		TextColor3 = COLORS.dim,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	newButton(dailyRow, won and "Replay" or "PLAY", UDim2.new(1, -160, 0, 10), UDim2.new(0, 148, 0, 44), won and COLORS.locked or Color3.fromRGB(215, 160, 50), function()
		duelAuto = false
		startDuel("daily")
	end)

	-- how battles work: open for anyone who has never fought, a tap away for everyone else
	local showHelp = battleHelp or (state.stats ~= nil and (state.stats.duels or 0) == 0)
	local helpRow = newRow(3, showHelp and 318 or 40)
	helpRow.BackgroundTransparency = showHelp and 0 or 1
	newButton(helpRow, showHelp and "❓ How battles work  ▲" or "❓ How battles work  ▼", UDim2.new(0, 0, 0, 3), UDim2.new(0, 220, 0, 34), Color3.fromRGB(150, 95, 230), function()
		battleHelp = not showHelp
		renderPanel()
	end).TextSize = 14
	if showHelp then
		newLabel(helpRow, table.concat({
			"1.  You bring a battle deck of up to " .. Duel.DeckSize .. " cards you own. Battling never uses them up.",
			"2.  Each round you gain 1 ⚡ energy and hold " .. Duel.HandSize .. " cards. Play ONE card, or Pass to save your ⚡.",
			"3.  A card costs the ⚡ shown on it: Commons cost 1, Secrets cost 6 and hit far harder.",
			"4.  Then every enemy attacks you. First side to run out of health loses.",
			"",
			"⚔️ Strike: damage to one enemy          💥 Blast: damage to every enemy",
			"💚 Heal: restores your health               🛡️ Shield: blocks most of the next hit on you",
			"🔥 Power-up: your next attack is stronger   🌀 Weaken: an enemy's next attack is smaller",
			"",
			"Types:  ⚔️ beats 🐾 beats 🔮 beats ⚙️ beats ⭐ beats ⚔️.  Beating a type deals +30%, the reverse −25%.",
			"Bosses (every 10th floor) warn you one round before a huge hit: shield up or finish them.",
			"✖ throws a card away for free. Your first battles come with a coach that points out a good move.",
		}, "\n"), UDim2.new(0, 14, 0, 42), UDim2.new(1, -28, 1, -48), {
			TextSize = 13,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	end

	-- the battle deck
	local saved = Duel.usableDeck(state, state.battleDeck)
	local automatic = #saved == 0
	local deck = automatic and Duel.autoDeck(state) or saved
	local deckRow = newRow(4, 46)
	newLabel(deckRow, "Battle deck: " .. #deck .. "/" .. Duel.DeckSize .. (automatic and " (automatic)" or "") .. "   ·   " .. Duel.short(Duel.deckHealth(deck)) .. " health", UDim2.new(0, 14, 0, 0), UDim2.new(1, -300, 1, 0), {
		Font = Enum.Font.FredokaOne,
		TextSize = 15,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	newButton(deckRow, "Auto-build", UDim2.new(1, -284, 0, 6), UDim2.new(0, 96, 0, 34), COLORS.button, function()
		Remotes.BattleDeck:FireServer("auto")
	end).TextSize = 13
	newButton(deckRow, deckEditing and "Done" or "Edit deck", UDim2.new(1, -184, 0, 6), UDim2.new(0, 96, 0, 34), deckEditing and COLORS.good or Color3.fromRGB(150, 95, 230), function()
		deckEditing = not deckEditing
		renderPanel()
	end).TextSize = 13
	newButton(deckRow, "Clear", UDim2.new(1, -84, 0, 6), UDim2.new(0, 76, 0, 34), COLORS.locked, function()
		Remotes.BattleDeck:FireServer("clear")
	end).TextSize = 13

	if deckEditing then
		-- every card you own, strongest first, with + and - buttons
		local inDeck = {}
		for _, key in ipairs(saved) do
			inDeck[key] = (inDeck[key] or 0) + 1
		end
		local owned = Duel.ownedCounts(state)
		local options = {}
		for key in pairs(owned) do
			local card = Duel.card(key)
			if card then
				table.insert(options, card)
			end
		end
		table.sort(options, function(a, b)
			local deckA, deckB = inDeck[a.key] and 1 or 0, inDeck[b.key] and 1 or 0
			if deckA ~= deckB then
				return deckA > deckB
			elseif a.power ~= b.power then
				return a.power > b.power
			end
			return a.key < b.key
		end)
		if automatic then
			newNoteRow(5, "Your deck is empty, so your strongest cards are picked for you. Add a card to start your own deck.")
		end
		for index, card in ipairs(options) do
			local have = inDeck[card.key] or 0
			local most = math.min(owned[card.key], Duel.MaxCopies)
			fillLazily(newRow(5 + index, 40), function(row)
				newCardLine(row, card.key, UDim2.new(0, 12, 0, 2), UDim2.new(1, -190, 0, 18))
				newLabel(row, roleLine(card) .. "  ·  " .. card.text, UDim2.new(0, 12, 0, 20), UDim2.new(1, -190, 0, 16), {
					TextSize = 11,
					TextColor3 = COLORS.dim,
					TextWrapped = false,
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
				newLabel(row, have .. "/" .. most, UDim2.new(1, -172, 0, 0), UDim2.new(0, 40, 1, 0), {
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = have > 0 and COLORS.cash or COLORS.dim,
				})
				newButton(row, "−", UDim2.new(1, -126, 0, 5), UDim2.new(0, 56, 0, 30), have > 0 and COLORS.bad or COLORS.locked, function()
					Remotes.BattleDeck:FireServer("remove", card.key)
				end)
				newButton(row, "+", UDim2.new(1, -64, 0, 5), UDim2.new(0, 56, 0, 30), have < most and COLORS.good or COLORS.locked, function()
					Remotes.BattleDeck:FireServer("add", card.key)
				end)
			end)
		end
		return
	end

	if #deck == 0 then
		newNoteRow(5, "You have no cards yet — open a pack first.")
		return
	end
	local grid = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
	}, body)
	make("UIGridLayout", {
		CellSize = UDim2.new(0, 120, 0, 222),
		CellPadding = UDim2.new(0, 6, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for index, key in ipairs(deck) do
		local card = Duel.card(key)
		newCardCell(grid, key, index, function(cell)
			newLabel(cell, roleLine(card), UDim2.new(0, 4, 0, 163), UDim2.new(1, -8, 0, 16), {
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = Color3.fromRGB(255, 215, 90),
				TextWrapped = false,
			})
			newLabel(cell, card.text, UDim2.new(0, 4, 0, 180), UDim2.new(1, -8, 0, 40), {
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = COLORS.dim,
			})
		end)
	end
end

-- Admin tab: only for the owner and the players the owner made admins ---------------------
panels.Admin = function()
	titleLabel.Text = "🛠️ Admin"
	useList()
	if not state.isAdmin then
		newLabel(newRow(1, 60), "This tab is only for admins.", UDim2.new(0, 14, 0, 0), UDim2.new(1, -28, 1, 0), { TextSize = 16 })
		return
	end

	local intro = newRow(1, 40)
	intro.BackgroundTransparency = 1
	newLabel(intro, "Testing tools. They only change your own save, and other players cannot see this tab.", UDim2.new(0, 4, 0, 0), UDim2.new(1, -8, 1, 0), {
		TextSize = 13,
		TextColor3 = COLORS.dim,
	})

	local toolRow = newRow(2, 46)
	for index, tool in ipairs({
		{ "cash", "Fill wallet" },
		{ "aura", "+1M aura" },
		{ "cards", "+30 cards" },
		{ "rebirth", "Rebirth ready" },
		{ "tower", "+4 floors" },
	}) do
		newButton(toolRow, "🧪 " .. tool[2], UDim2.new((index - 1) / 5, 4, 0, 6), UDim2.new(1 / 5, -8, 0, 34), COLORS.button, function()
			Remotes.OwnerTool:FireServer(tool[1])
		end).TextSize = 12
	end

	local autoRow = newRow(3, 60)
	newLabel(autoRow, "Auto upgrader", UDim2.new(0, 14, 0, 6), UDim2.new(1, -190, 0, 22), { Font = Enum.Font.FredokaOne, TextSize = 17 })
	newLabel(autoRow, "Buys store and luck upgrades for you the moment you can afford them.", UDim2.new(0, 14, 0, 30), UDim2.new(1, -190, 0, 24), {
		TextSize = 12,
		TextColor3 = COLORS.dim,
	})
	newButton(autoRow, state.autoUpgrade and "ON" or "OFF", UDim2.new(1, -160, 0, 8), UDim2.new(0, 148, 0, 44), state.autoUpgrade and COLORS.good or COLORS.locked, function()
		Remotes.OwnerTool:FireServer("autoUpgrade")
	end)

	if not state.isOwner then
		return
	end

	-- the owner chooses who else is an admin
	local header = newRow(10, 44)
	header.BackgroundColor3 = Color3.fromRGB(60, 45, 80)
	newLabel(header, "👑 Admins  ·  only you can change this list", UDim2.new(0, 14, 0, 0), UDim2.new(1, -28, 1, 0), {
		Font = Enum.Font.FredokaOne,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(255, 215, 90),
	})
	local order = 10
	local listed = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			order = order + 1
			local id = tostring(other.UserId)
			listed[id] = true
			local isListed = state.admins[id] ~= nil
			local row = newRow(order, 44)
			newLabel(row, other.DisplayName .. "  (@" .. other.Name .. ")" .. (isListed and "   ·   admin" or ""), UDim2.new(0, 14, 0, 0), UDim2.new(1, -190, 1, 0), {
				TextSize = 15,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			newButton(row, isListed and "Remove admin" or "Make admin", UDim2.new(1, -160, 0, 6), UDim2.new(0, 148, 0, 32), isListed and COLORS.bad or COLORS.good, function()
				Remotes.AdminSet:FireServer(other.UserId, not isListed)
			end).TextSize = 14
		end
	end
	-- admins who are not in this server right now
	for id, name in pairs(state.admins) do
		local userId = tonumber(id)
		if not listed[id] and userId then
			order = order + 1
			local row = newRow(order, 44)
			newLabel(row, tostring(name) .. "   ·   admin (not in this server)", UDim2.new(0, 14, 0, 0), UDim2.new(1, -190, 1, 0), {
				TextSize = 15,
				TextColor3 = COLORS.dim,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			newButton(row, "Remove admin", UDim2.new(1, -160, 0, 6), UDim2.new(0, 148, 0, 32), COLORS.bad, function()
				Remotes.AdminSet:FireServer(userId, false)
			end).TextSize = 14
		end
	end
	if order == 10 then
		local empty = newRow(11, 40)
		empty.BackgroundTransparency = 1
		newLabel(empty, "Nobody else is here. A player has to be in your server for you to make them an admin.", UDim2.new(0, 4, 0, 0), UDim2.new(1, -8, 1, 0), {
			TextSize = 13,
			TextColor3 = COLORS.dim,
		})
	end
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

function openPanel(name)
	if name == "Admin" and not state.isAdmin then
		return -- the tab does not exist for ordinary players
	end
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
	{ "Battle", "⚔️ Battle", Color3.fromRGB(200, 60, 60), "G" },
	{ "Quests", "🎯 Quests", Color3.fromRGB(230, 120, 50), "Q" },
	{ "Rebirth", "🌟 Rebirth", Color3.fromRGB(215, 160, 50), "R" },
	{ "Store", "💎 Store", Color3.fromRGB(120, 80, 200), "M" },
	{ "Admin", "🛠️ Admin", Color3.fromRGB(170, 50, 50), "K" }, -- hidden unless you are an admin
}
local keyBadges = {} -- the little key letters on the buttons (keyboard players only)
local menuButtons = {} -- [panel name] = its menu button
local menuGlows = {} -- [panel name] = the yellow outline the tutorial puts on a button
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
	menuButtons[entry[1]] = button
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
-- Returns the hint text and, when it points at a menu button, that button's panel name.
local function tutorialHint()
	if duel then
		return "", nil -- the duel has its own instructions
	end
	if state.cashCap < math.huge and state.cash >= state.cashCap * 0.999 then
		return "💰 Wallet full! Rebirth (🌟) to raise your money cap — vault your best cards first.", nil
	end
	if state.rebirths > 0 then
		return "", nil
	end
	local owned = next(state.inventory) ~= nil
	local displayed = next(state.slots) ~= nil
	local discovered = 0
	for _ in pairs(state.collection) do
		discovered = discovered + 1
	end
	if state.freePacks > 0 and not owned and not displayed then
		return "🎁 Open your free pack — tap the 🎁 FREE! button", "Packs"
	end
	if owned and not displayed then
		return "🃏 Open Deck and tap Auto-fill Deck to start earning", "Cards"
	end
	if displayed and discovered < 8 and state.upgrades.auto < 1 and state.cash < 100 then
		return "💵 Walk over the green cash register in your store to collect", nil
	end
	if displayed and state.packsOpened < 3 and state.cash >= 150 then
		return "🎴 Buy another Booster in Packs — more cards means more cash", "Packs"
	end
	if displayed and state.upgrades.store == 0 and state.cash >= Upgrades.StoreTiers[2].cost then
		return "🏪 Upgrade your store: a real shop with 16 shelves instead of 4", "Upgrades"
	end
	if state.tower == 0 and discovered >= 6 and state.packsOpened >= 3 then
		return "⚔️ Try the Battle Tower — open Battle and press FIGHT", "Battle"
	end
	return "", nil
end

local function refreshHud()
	local hint, hintPanel = tutorialHint()
	hintLabel.Text = hint
	hintLabel.Visible = hint ~= ""
	-- the menu button the hint is about gets a yellow outline
	for name, button in pairs(menuButtons) do
		local glow = menuGlows[name]
		if name == hintPanel and glow == nil then
			glow = make("UIStroke", { Color = Color3.fromRGB(255, 225, 90), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
			menuGlows[name] = glow
		end
		if glow then
			glow.Enabled = name == hintPanel
		end
	end
	local weekly = Season.event()
	eventLabel.Text = "🎉 " .. weekly.name .. ": " .. weekly.text
	local adminButton = menuButtons["Admin"]
	if adminButton then
		adminButton.Visible = state.isAdmin
	end
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

-- You said hi to one of your employees: show what they said and open the staff list.
Remotes.OpenStaff.OnClientEvent:Connect(function(staffId, line)
	local staff = Staff.Defs[staffId]
	if staff then
		toast(staff.face .. " " .. staff.name .. ": " .. tostring(line), "info")
	end
	if currentPanel ~= "Upgrades" or not window.Visible then
		openPanel("Upgrades")
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
keyToPanel[Enum.KeyCode.V] = "Rebirth" -- V for vault: the vault is at the top of that screen

local DUEL_HAND_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
}

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
		if MENU[index][1] == "Admin" and not state.isAdmin then
			index = (index - 1 + step) % #MENU + 1
		end
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

	-- during a duel (with no menu open): 1-5 play a card, Tab aims, Space passes;
	-- on a gamepad RB aims and X passes
	if duelGui.Visible and not window.Visible then
		local handIndex = DUEL_HAND_KEYS[key]
		if handIndex and not processed then
			local card = duel and duel.hand[handIndex] and Duel.card(duel.hand[handIndex])
			if card and card.cost <= duel.energy then
				duelAct({ kind = "play", hand = handIndex, target = duelTarget })
			elseif card then
				toast("Not enough energy yet. Play a cheaper card, or Pass to save up.", "error")
			end
			return
		elseif (key == Enum.KeyCode.Tab or key == Enum.KeyCode.ButtonR1) and duel and not duelBusy and not duelEnding then
			for step = 1, #duel.enemies do
				local index = (duelTarget + step - 1) % #duel.enemies + 1
				if duel.enemies[index].hp > 0 then
					duelTarget = index
					break
				end
			end
			renderDuelHud()
			return
		elseif (key == Enum.KeyCode.Space and not processed) or key == Enum.KeyCode.ButtonX then
			duelAct({ kind = "pass" })
			return
		end
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
