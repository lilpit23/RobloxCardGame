-- Builds the map and every player's store plot out of parts, so no Studio building is needed.
-- Plot local space: the street is toward -Z, the back of the store is +Z, floor top is Y = 1.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cards = require(Shared:WaitForChild("Cards"))
local CardView = require(Shared:WaitForChild("CardView"))
local Format = require(Shared:WaitForChild("Format"))
local Upgrades = require(Shared:WaitForChild("Upgrades"))

local Plots = {}

local SIZE = Config.PlotSize
local HALF = SIZE / 2
local COLUMNS = { -21, -7, 7, 21 }
local ROWS = { -12, 0, 12, 24 }

local TIER_STYLE = {
	{ floor = Color3.fromRGB(150, 110, 75), material = Enum.Material.WoodPlanks, accent = Color3.fromRGB(230, 200, 150) },
	{ floor = Color3.fromRGB(200, 205, 215), material = Enum.Material.Concrete, accent = Color3.fromRGB(80, 170, 255) },
	{ floor = Color3.fromRGB(235, 235, 240), material = Enum.Material.Marble, accent = Color3.fromRGB(170, 90, 240) },
	{ floor = Color3.fromRGB(45, 45, 60), material = Enum.Material.SmoothPlastic, accent = Color3.fromRGB(255, 80, 170) },
	{ floor = Color3.fromRGB(240, 195, 80), material = Enum.Material.Foil, accent = Color3.fromRGB(255, 240, 150) },
}

local plots = {}
local callbacks = {}

local function newPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function newBillboard(parent, text, offsetY, width, height)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(width or 6, 0, height or 1.5, 0)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 90
	gui.AlwaysOnTop = false
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = gui
	return label
end

local function newSurfaceLabel(part, face, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = gui
	return label
end

local function playerFromHit(hit)
	local character = hit.Parent
	if character == nil then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function slotPosition(index)
	local row = math.floor((index - 1) / 4) + 1
	local column = (index - 1) % 4 + 1
	return COLUMNS[column], ROWS[row]
end

local function buildStand(plot, index)
	local x, z = slotPosition(index)
	local folder = Instance.new("Folder")
	folder.Name = "Stand" .. index
	folder.Parent = plot.standsFolder

	newPart(folder, "Pedestal", Vector3.new(5, 1, 2), plot.cframe * CFrame.new(x, 1.5, z), Color3.fromRGB(60, 60, 70))

	local card = newPart(folder, "Card", Vector3.new(4, 5.6, 0.3), plot.cframe * CFrame.new(x, 4.8, z), Color3.fromRGB(20, 20, 25))
	card.Transparency = 0.8

	local guis = {}
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = card
		table.insert(guis, gui)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.ObjectText = "Card"
	prompt.HoldDuration = Config.Stealing.HoldTime
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = card
	prompt.Triggered:Connect(function(player)
		if callbacks.onCardPrompt then
			callbacks.onCardPrompt(plot, index, player)
		end
	end)

	local pad = newPart(folder, "CollectPad", Vector3.new(5, 0.2, 3), plot.cframe * CFrame.new(x, 1.1, z - 3.5), Color3.fromRGB(70, 220, 110), Enum.Material.Neon)
	local pendingLabel = newBillboard(pad, "", 1.2, 5, 1.2)
	pendingLabel.TextColor3 = Color3.fromRGB(150, 255, 160)
	pad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player and player == plot.owner and callbacks.onCollect then
			callbacks.onCollect(plot, index, player)
		end
	end)

	plot.stands[index] = { folder = folder, card = card, guis = guis, prompt = prompt, pendingLabel = pendingLabel }
end

local function buildDecor(plot)
	plot.decor:ClearAllChildren()
	local style = TIER_STYLE[plot.tier]
	plot.floor.Color = style.floor
	plot.floor.Material = style.material

	local wallColor = Color3.fromRGB(235, 230, 220)
	if plot.tier >= 2 then
		newPart(plot.decor, "BackWall", Vector3.new(SIZE, 14, 1), plot.cframe * CFrame.new(0, 8, HALF - 0.5), wallColor)
	end
	if plot.tier >= 3 then
		newPart(plot.decor, "LeftWall", Vector3.new(1, 14, SIZE - 1), plot.cframe * CFrame.new(-HALF + 0.5, 8, -0.5), wallColor)
		newPart(plot.decor, "RightWall", Vector3.new(1, 14, SIZE - 1), plot.cframe * CFrame.new(HALF - 0.5, 8, -0.5), wallColor)
	end
	if plot.tier >= 4 then
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local pillar = newPart(plot.decor, "Pillar", Vector3.new(2, 24, 2), plot.cframe * CFrame.new(sx * (HALF - 1), 13, sz * (HALF - 1)), style.accent, Enum.Material.Neon)
				local light = Instance.new("PointLight")
				light.Color = style.accent
				light.Range = 20
				light.Parent = pillar
			end
		end
	end
	if plot.tier >= 5 then
		local beam = newPart(plot.decor, "AuraBeam", Vector3.new(4, 120, 4), plot.cframe * CFrame.new(0, 61, HALF - 4), style.accent, Enum.Material.Neon)
		beam.Transparency = 0.5
		beam.CanCollide = false
		beam.Shape = Enum.PartType.Block
	end
end

local function buildPlot(index, cframe, parent)
	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. index
	folder.Parent = parent

	local plot = {
		index = index,
		cframe = cframe,
		folder = folder,
		owner = nil,
		tier = 1,
		stands = {},
	}

	plot.floor = newPart(folder, "Floor", Vector3.new(SIZE, 1, SIZE), cframe * CFrame.new(0, 0.5, 0), TIER_STYLE[1].floor, TIER_STYLE[1].material)

	plot.standsFolder = Instance.new("Folder")
	plot.standsFolder.Name = "Stands"
	plot.standsFolder.Parent = folder

	plot.decor = Instance.new("Folder")
	plot.decor.Name = "Decor"
	plot.decor.Parent = folder

	-- Sign over the entrance
	for _, sx in ipairs({ -1, 1 }) do
		newPart(folder, "SignPost", Vector3.new(1, 13, 1), cframe * CFrame.new(sx * 11, 7.5, -HALF + 1), Color3.fromRGB(50, 50, 60))
	end
	local sign = newPart(folder, "Sign", Vector3.new(24, 5, 1), cframe * CFrame.new(0, 14, -HALF + 1), Color3.fromRGB(30, 30, 40))
	plot.signLabels = {
		newSurfaceLabel(sign, Enum.NormalId.Front, "Unclaimed"),
		newSurfaceLabel(sign, Enum.NormalId.Back, "Unclaimed"),
	}

	-- Pack shop counter
	local counter = newPart(folder, "PackCounter", Vector3.new(10, 3, 3), cframe * CFrame.new(-19, 2.5, -26), Color3.fromRGB(200, 70, 110))
	newBillboard(counter, "🎴 PACK SHOP", 3.2, 9, 1.6)
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.ActionText = "Open"
	shopPrompt.ObjectText = "Pack Shop"
	shopPrompt.MaxActivationDistance = 10
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = counter
	shopPrompt.Triggered:Connect(function(player)
		if callbacks.onShop then
			callbacks.onShop(plot, player)
		end
	end)

	-- Lock pad + shield
	local lockPad = newPart(folder, "LockPad", Vector3.new(5, 0.2, 5), cframe * CFrame.new(19, 1.1, -26), Color3.fromRGB(235, 70, 70), Enum.Material.Neon)
	plot.lockLabel = newBillboard(lockPad, "", 2.5, 9, 1.4)
	lockPad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player and player == plot.owner and callbacks.onLock then
			callbacks.onLock(plot, player)
		end
	end)
	if not Config.Stealing.Enabled then
		lockPad.Transparency = 1
		lockPad.CanCollide = false
		lockPad.CanTouch = false
	end

	local shield = newPart(folder, "Shield", Vector3.new(SIZE, 30, SIZE), cframe * CFrame.new(0, 16, 0), Color3.fromRGB(90, 190, 255), Enum.Material.ForceField)
	shield.Transparency = 1
	shield.CanCollide = false
	shield.CanTouch = false
	shield.CanQuery = false
	shield.CastShadow = false
	plot.shield = shield

	return plot
end

function Plots.init(handlers)
	callbacks = handlers

	if workspace:FindFirstChild("Baseplate") == nil then
		newPart(workspace, "Baseplate", Vector3.new(420, 4, 300), CFrame.new(0, -2, 0), Color3.fromRGB(95, 170, 105), Enum.Material.Grass)
	end
	if workspace:FindFirstChildWhichIsA("SpawnLocation", true) == nil then
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.CFrame = CFrame.new(0, 0.5, 0)
		spawn.Neutral = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Parent = workspace
	end

	local root = Instance.new("Folder")
	root.Name = "Plots"
	root.Parent = workspace

	local perRow = math.ceil(Config.PlotCount / 2)
	local spacing = SIZE + 8
	for index = 1, Config.PlotCount do
		local row = (index - 1) % 2
		local column = math.floor((index - 1) / 2)
		local x = (column - (perRow - 1) / 2) * spacing
		local cframe
		if row == 0 then
			-- north side of the street, entrance faces +Z
			cframe = CFrame.new(x, 0, -(HALF + 16)) * CFrame.Angles(0, math.pi, 0)
		else
			-- south side of the street, entrance faces -Z
			cframe = CFrame.new(x, 0, HALF + 16)
		end
		plots[index] = buildPlot(index, cframe, root)
	end
end

function Plots.assign(player)
	for _, plot in ipairs(plots) do
		if plot.owner == nil then
			plot.owner = player
			return plot
		end
	end
	return nil
end

function Plots.release(player)
	for _, plot in ipairs(plots) do
		if plot.owner == player then
			plot.owner = nil
			plot.standsFolder:ClearAllChildren()
			plot.stands = {}
			Plots.setTier(plot, 1)
			Plots.setSign(plot, "Unclaimed")
			Plots.setShield(plot, false)
			Plots.setLockText(plot, "")
		end
	end
end

function Plots.setSlotCount(plot, count)
	for index = 1, count do
		if plot.stands[index] == nil then
			buildStand(plot, index)
		end
	end
end

-- key = nil clears the stand.
function Plots.setCard(plot, index, key)
	local stand = plot.stands[index]
	if stand == nil then
		return
	end
	for _, gui in ipairs(stand.guis) do
		gui:ClearAllChildren()
		if key then
			CardView.new(key).Parent = gui
		end
	end
	if key then
		stand.card.Transparency = 0
		stand.prompt.ObjectText = Cards.getDisplayName(key)
		stand.prompt.Enabled = true
	else
		stand.card.Transparency = 0.8
		stand.prompt.Enabled = false
	end
end

function Plots.setPending(plot, index, amount)
	local stand = plot.stands[index]
	if stand == nil then
		return
	end
	if amount >= 1 then
		stand.pendingLabel.Text = Format.cash(amount)
	else
		stand.pendingLabel.Text = ""
	end
end

function Plots.setTier(plot, tier)
	plot.tier = math.clamp(tier, 1, #TIER_STYLE)
	buildDecor(plot)
end

function Plots.setSign(plot, text)
	for _, label in ipairs(plot.signLabels) do
		label.Text = text
	end
end

function Plots.setOwnerSign(plot, player, storeLevel)
	Plots.setSign(plot, player.DisplayName .. "'s " .. Upgrades.getStoreTier(storeLevel).name)
end

function Plots.setShield(plot, enabled)
	if enabled then
		plot.shield.Transparency = 0.4
	else
		plot.shield.Transparency = 1
	end
end

function Plots.setLockText(plot, text)
	plot.lockLabel.Text = text
end

function Plots.contains(plot, position)
	local localPosition = plot.cframe:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= HALF and math.abs(localPosition.Z) <= HALF
end

function Plots.getSpawnCFrame(plot)
	return plot.cframe * CFrame.new(0, 5, -22) * CFrame.Angles(0, math.pi, 0)
end

return Plots
