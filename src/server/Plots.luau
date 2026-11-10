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
-- The active deck is shown as rows of cards: 8 across, up to 8 rows (64 slots).
local STAND_COLUMNS = 8
local STAND_SPACING_X = 7
local STAND_FIRST_Z = -14
local STAND_SPACING_Z = 6

local TIER_STYLE = {
	{ floor = Color3.fromRGB(150, 110, 75), material = Enum.Material.WoodPlanks, accent = Color3.fromRGB(230, 200, 150) },
	{ floor = Color3.fromRGB(200, 205, 215), material = Enum.Material.Concrete, accent = Color3.fromRGB(80, 170, 255) },
	{ floor = Color3.fromRGB(235, 235, 240), material = Enum.Material.Marble, accent = Color3.fromRGB(170, 90, 240) },
	{ floor = Color3.fromRGB(45, 45, 60), material = Enum.Material.SmoothPlastic, accent = Color3.fromRGB(255, 80, 170) },
	{ floor = Color3.fromRGB(240, 195, 80), material = Enum.Material.Foil, accent = Color3.fromRGB(255, 240, 150) },
	{ floor = Color3.fromRGB(120, 210, 230), material = Enum.Material.Glass, accent = Color3.fromRGB(120, 255, 255) },
	{ floor = Color3.fromRGB(25, 20, 45), material = Enum.Material.Neon, accent = Color3.fromRGB(255, 120, 255) },
}

local plots = {}
local leaderboardLabels = {}
local callbacks: { [string]: (...any) -> ...any } = {}

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
	local row = math.floor((index - 1) / STAND_COLUMNS)
	local column = (index - 1) % STAND_COLUMNS
	local x = (column - (STAND_COLUMNS - 1) / 2) * STAND_SPACING_X
	return x, STAND_FIRST_Z + row * STAND_SPACING_Z
end

local function buildStand(plot, index)
	local x, z = slotPosition(index)
	local folder = Instance.new("Folder")
	folder.Name = "Stand" .. index
	folder.Parent = plot.standsFolder

	newPart(folder, "Pedestal", Vector3.new(4.4, 0.6, 1.2), plot.cframe * CFrame.new(x, 1.3, z), Color3.fromRGB(60, 60, 70))

	local card = newPart(folder, "Card", Vector3.new(4, 5.6, 0.3), plot.cframe * CFrame.new(x, 4.4, z), Color3.fromRGB(20, 20, 25))
	card.Transparency = 0.8

	-- one face only (toward the street): 64 slots per store adds up
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = card

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take out of deck"
	prompt.ObjectText = "Card"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = card
	prompt.Triggered:Connect(function(player)
		if callbacks.onCardPrompt then
			callbacks.onCardPrompt(plot, index, player)
		end
	end)

	plot.stands[index] = { folder = folder, card = card, guis = { gui }, prompt = prompt }
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

	-- Cash register: everything the deck earns piles up here; walk over it to collect
	local register = newPart(folder, "CashRegister", Vector3.new(9, 0.2, 4), cframe * CFrame.new(0, 1.1, -28), Color3.fromRGB(70, 220, 110), Enum.Material.Neon)
	plot.registerLabel = newBillboard(register, "💵 Cash register", 2.4, 10, 1.5)
	plot.registerLabel.TextColor3 = Color3.fromRGB(150, 255, 160)
	register.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player and player == plot.owner and callbacks.onCollect then
			callbacks.onCollect(plot, player)
		end
	end)

	-- Trade & market board
	local board = newPart(folder, "TradeBoard", Vector3.new(10, 3, 3), cframe * CFrame.new(19, 2.5, -26), Color3.fromRGB(40, 170, 160))
	newBillboard(board, "🤝 TRADE & MARKET", 3.2, 10, 1.6)
	local tradePrompt = Instance.new("ProximityPrompt")
	tradePrompt.ActionText = "Open"
	tradePrompt.ObjectText = "Trade & Market"
	tradePrompt.MaxActivationDistance = 10
	tradePrompt.RequiresLineOfSight = false
	tradePrompt.Parent = board
	tradePrompt.Triggered:Connect(function(player)
		if callbacks.onTrade then
			callbacks.onTrade(plot, player)
		end
	end)

	return plot
end

---------------------------------------------------------------------
-- The map: a cul-de-sac of stores, one road out, a tunnel through the ridge, and the PvE
-- tower arena beyond it. Everything is laid out along +X from the plaza at the origin:
--
--   [ plaza + ring of plots ] ==== road ==== [ tunnel ] ==== [ arena + tower ]
---------------------------------------------------------------------
local ROAD_WIDTH = 24
local ROAD_LENGTH = 150 -- plaza edge to tunnel mouth
local TUNNEL_LENGTH = 70
local TUNNEL_WIDTH = 32
local TUNNEL_HEIGHT = 18
local RIDGE_HEIGHT = 44
local ARENA_RADIUS = 85

local ASPHALT = Color3.fromRGB(52, 54, 60)
local PAVEMENT = Color3.fromRGB(190, 190, 195)
local ROCK = Color3.fromRGB(105, 98, 92)
local DARK_STONE = Color3.fromRGB(60, 58, 70)

-- A flat disc lying on the ground.
local function newDisc(parent, name, radius, height, position, color, material)
	local disc = newPart(parent, name, Vector3.new(height, radius * 2, radius * 2), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	disc.Shape = Enum.PartType.Cylinder
	return disc
end

local function newLamp(parent, x, z)
	newPart(parent, "LampPost", Vector3.new(0.7, 13, 0.7), CFrame.new(x, 6.5, z), Color3.fromRGB(40, 40, 48), Enum.Material.Metal)
	local lamp = newPart(parent, "Lamp", Vector3.new(2.4, 0.8, 2.4), CFrame.new(x, 13.4, z), Color3.fromRGB(255, 230, 170), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 225, 170)
	light.Range = 28
	light.Brightness = 1.2
	light.Parent = lamp
end

local function newTree(parent, x, z)
	newPart(parent, "Trunk", Vector3.new(2, 9, 2), CFrame.new(x, 4.5, z), Color3.fromRGB(105, 75, 50), Enum.Material.Wood)
	local leaves = newPart(parent, "Leaves", Vector3.new(11, 11, 11), CFrame.new(x, 12.5, z), Color3.fromRGB(70, 150, 80), Enum.Material.Grass)
	leaves.Shape = Enum.PartType.Ball
end

-- Where everything goes, worked out from the number of plots.
-- Plots sit on a ring facing the plaza; one position on the ring (toward +X) is left open
-- for the road.
local function mapLayout()
	local step = 2 * math.pi / (Config.PlotCount + 1)
	-- far enough out that neighbouring plots' front corners do not overlap
	local plazaRadius = math.ceil(HALF / math.tan(step / 2)) + 6
	local tunnelStart = plazaRadius + ROAD_LENGTH
	local tunnelEnd = tunnelStart + TUNNEL_LENGTH
	return {
		step = step,
		plazaRadius = plazaRadius,
		plotDistance = plazaRadius + HALF,
		tunnelStart = tunnelStart,
		tunnelEnd = tunnelEnd,
		arenaX = tunnelEnd + ARENA_RADIUS + 10,
	}
end

-- The cul-de-sac plaza: round road, a green island with the spawn, banner and leaderboard.
local function buildPlaza(map, layout)
	local radius = layout.plazaRadius
	newDisc(map, "PlazaPavement", radius + 5, 0.2, Vector3.new(0, 0.1, 0), PAVEMENT, Enum.Material.Concrete)
	newDisc(map, "PlazaRoad", radius, 0.3, Vector3.new(0, 0.15, 0), ASPHALT, Enum.Material.Asphalt)
	newDisc(map, "IslandKerb", 24, 0.5, Vector3.new(0, 0.25, 0), PAVEMENT, Enum.Material.Concrete)
	newDisc(map, "Island", 22, 0.6, Vector3.new(0, 0.3, 0), Color3.fromRGB(95, 170, 105), Enum.Material.Grass)

	-- lamps between the plots and on both sides of the road mouth
	for index = 0, Config.PlotCount do
		local angle = (index + 0.5) * layout.step
		newLamp(map, math.cos(angle) * (radius + 2), math.sin(angle) * (radius + 2))
	end

	-- banner and leaderboard on the island, facing down the road
	for _, side in ipairs({ -1, 1 }) do
		newPart(map, "SignPillar", Vector3.new(1.5, 22, 1.5), CFrame.new(0, 11, side * 15), Color3.fromRGB(40, 40, 48), Enum.Material.Metal)
	end
	local facing = CFrame.Angles(0, math.pi / 2, 0)
	local banner = newPart(map, "Banner", Vector3.new(32, 7, 1), CFrame.new(0, 20, 0) * facing, Color3.fromRGB(230, 60, 110), Enum.Material.Neon)
	local board = newPart(map, "Leaderboard", Vector3.new(30, 9, 0.6), CFrame.new(0, 11.5, 0) * facing, Color3.fromRGB(25, 25, 38))
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		newSurfaceLabel(banner, face, "🎴 " .. string.upper(Config.GameName) .. " 🎴")
		local label = newSurfaceLabel(board, face, "🏆 TOP STORES")
		label.TextScaled = false
		label.TextSize = 34
		label.TextYAlignment = Enum.TextYAlignment.Top
		table.insert(leaderboardLabels, label)
	end
end

-- The road from the plaza to the arena, with lamps, trees and a signpost.
local function buildRoad(map, layout)
	local startX = layout.plazaRadius - 2
	local endX = layout.arenaX - ARENA_RADIUS + 4
	local length = endX - startX
	local midX = (startX + endX) / 2
	newPart(map, "Road", Vector3.new(length, 0.3, ROAD_WIDTH), CFrame.new(midX, 0.15, 0), ASPHALT, Enum.Material.Asphalt)
	for _, side in ipairs({ -1, 1 }) do
		local pavementLength = layout.tunnelStart - (layout.plazaRadius + 5)
		newPart(map, "Pavement", Vector3.new(pavementLength, 0.2, 5), CFrame.new(layout.plazaRadius + 5 + pavementLength / 2, 0.1, side * (ROAD_WIDTH / 2 + 2.5)), PAVEMENT, Enum.Material.Concrete)
	end
	for x = layout.plazaRadius + 10, layout.tunnelStart - 6, 16 do
		newPart(map, "Line", Vector3.new(6, 0.05, 0.6), CFrame.new(x, 0.33, 0), Color3.fromRGB(245, 215, 90), Enum.Material.SmoothPlastic)
	end
	for x = layout.plazaRadius + 30, layout.tunnelStart - 20, 40 do
		for _, side in ipairs({ -1, 1 }) do
			newLamp(map, x, side * (ROAD_WIDTH / 2 + 3))
			newTree(map, x + 20, side * (ROAD_WIDTH / 2 + 16))
		end
	end

	-- signpost where the road leaves the plaza
	local post = newPart(map, "Signpost", Vector3.new(0.8, 9, 0.8), CFrame.new(layout.plazaRadius + 12, 4.5, ROAD_WIDTH / 2 + 3), Color3.fromRGB(105, 75, 50), Enum.Material.Wood)
	newBillboard(post, "⚔️ Tower Defense →", 6, 12, 1.6)
end

-- A rocky ridge across the map with the tunnel through it.
local function buildTunnel(map, layout)
	local midX = (layout.tunnelStart + layout.tunnelEnd) / 2
	local sideDepth = 150
	for _, side in ipairs({ -1, 1 }) do
		local z = side * (TUNNEL_WIDTH / 2 + sideDepth / 2)
		newPart(map, "Ridge", Vector3.new(TUNNEL_LENGTH, RIDGE_HEIGHT, sideDepth), CFrame.new(midX, RIDGE_HEIGHT / 2, z), ROCK, Enum.Material.Slate)
		-- lower shoulders so the ridge does not end in a cliff
		newPart(map, "RidgeShoulder", Vector3.new(TUNNEL_LENGTH - 20, RIDGE_HEIGHT / 2, 40), CFrame.new(midX, RIDGE_HEIGHT / 4, side * (TUNNEL_WIDTH / 2 + sideDepth + 20)), ROCK, Enum.Material.Slate)
	end
	local roofHeight = RIDGE_HEIGHT - TUNNEL_HEIGHT
	newPart(map, "TunnelRoof", Vector3.new(TUNNEL_LENGTH, roofHeight, TUNNEL_WIDTH), CFrame.new(midX, TUNNEL_HEIGHT + roofHeight / 2, 0), ROCK, Enum.Material.Slate)
	newPart(map, "RidgeTop", Vector3.new(TUNNEL_LENGTH - 14, 8, TUNNEL_WIDTH + 90), CFrame.new(midX, RIDGE_HEIGHT + 4, 0), Color3.fromRGB(88, 82, 78), Enum.Material.Slate)

	-- lights along the tunnel ceiling
	for x = layout.tunnelStart + 10, layout.tunnelEnd - 10, 16 do
		local strip = newPart(map, "TunnelLight", Vector3.new(4, 0.4, TUNNEL_WIDTH - 12), CFrame.new(x, TUNNEL_HEIGHT - 0.3, 0), Color3.fromRGB(190, 120, 255), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(190, 120, 255)
		light.Range = 24
		light.Parent = strip
	end

	-- signs over both mouths
	local facing = CFrame.Angles(0, math.pi / 2, 0)
	local entrance = newPart(map, "TunnelSign", Vector3.new(30, 5, 1), CFrame.new(layout.tunnelStart - 0.6, TUNNEL_HEIGHT + 4, 0) * facing, Color3.fromRGB(150, 60, 220), Enum.Material.Neon)
	newSurfaceLabel(entrance, Enum.NormalId.Front, "⚔️ TOWER DEFENSE ⚔️")
	newSurfaceLabel(entrance, Enum.NormalId.Back, "⚔️ TOWER DEFENSE ⚔️")
	local exit = newPart(map, "TunnelSign", Vector3.new(30, 5, 1), CFrame.new(layout.tunnelEnd + 0.6, TUNNEL_HEIGHT + 4, 0) * facing, Color3.fromRGB(230, 60, 110), Enum.Material.Neon)
	newSurfaceLabel(exit, Enum.NormalId.Front, "🎴 BACK TO THE STORES 🎴")
	newSurfaceLabel(exit, Enum.NormalId.Back, "🎴 BACK TO THE STORES 🎴")
end

-- The PvE arena: a stone circle, the tower with its gate, a lane, braziers and monster gates.
local function buildArena(map, layout)
	local centerX = layout.arenaX
	newDisc(map, "ArenaRim", ARENA_RADIUS + 4, 0.2, Vector3.new(centerX, 0.1, 0), ROCK, Enum.Material.Slate)
	newDisc(map, "ArenaFloor", ARENA_RADIUS, 0.3, Vector3.new(centerX, 0.15, 0), DARK_STONE, Enum.Material.Cobblestone)

	-- the tower, at the far side of the arena
	local towerX = centerX + 38
	local accent = Color3.fromRGB(170, 90, 240)
	newPart(map, "TowerBase", Vector3.new(36, 24, 36), CFrame.new(towerX, 12, 0), DARK_STONE, Enum.Material.Brick)
	newPart(map, "TowerMiddle", Vector3.new(28, 22, 28), CFrame.new(towerX, 35, 0), Color3.fromRGB(72, 68, 86), Enum.Material.Brick)
	newPart(map, "TowerTop", Vector3.new(20, 20, 20), CFrame.new(towerX, 56, 0), DARK_STONE, Enum.Material.Brick)
	local crown = newPart(map, "TowerCrown", Vector3.new(8, 16, 8), CFrame.new(towerX, 74, 0), accent, Enum.Material.Neon)
	local crownLight = Instance.new("PointLight")
	crownLight.Color = accent
	crownLight.Range = 60
	crownLight.Brightness = 2
	crownLight.Parent = crown
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			newPart(map, "TowerBattlement", Vector3.new(5, 5, 5), CFrame.new(towerX + sx * 15.5, 26.5, sz * 15.5), DARK_STONE, Enum.Material.Brick)
		end
	end

	-- the gate: walk up and use it to fight the next floor
	local gate = newPart(map, "TowerGate", Vector3.new(1, 15, 12), CFrame.new(towerX - 18.4, 7.5, 0), accent, Enum.Material.Neon)
	newBillboard(gate, "⚔️ BATTLE TOWER", 10, 14, 2)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter"
	prompt.ObjectText = "Battle Tower"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = gate
	prompt.Triggered:Connect(function(player)
		if callbacks.onTower then
			callbacks.onTower(player)
		end
	end)

	-- the lane from the tunnel to the gate
	local laneStart = layout.tunnelEnd
	local laneEnd = towerX - 19
	newPart(map, "Lane", Vector3.new(laneEnd - laneStart, 0.2, 12), CFrame.new((laneStart + laneEnd) / 2, 0.4, 0), Color3.fromRGB(150, 140, 125), Enum.Material.Cobblestone)

	-- braziers along the lane
	for x = centerX - 60, centerX, 30 do
		for _, side in ipairs({ -1, 1 }) do
			newPart(map, "Brazier", Vector3.new(2, 5, 2), CFrame.new(x, 2.5, side * 10), Color3.fromRGB(40, 40, 48), Enum.Material.Metal)
			local fire = newPart(map, "BrazierFire", Vector3.new(2.6, 1.6, 2.6), CFrame.new(x, 5.8, side * 10), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 150, 60)
			light.Range = 22
			light.Parent = fire
		end
	end

	-- monster gates at the sides of the arena (where waves will come from)
	for _, side in ipairs({ -1, 1 }) do
		local z = side * (ARENA_RADIUS - 8)
		local x = centerX - 10
		for _, offset in ipairs({ -7, 7 }) do
			newPart(map, "MonsterGatePillar", Vector3.new(3, 16, 3), CFrame.new(x + offset, 8, z), Color3.fromRGB(35, 30, 40), Enum.Material.Slate)
		end
		newPart(map, "MonsterGateLintel", Vector3.new(20, 3, 3), CFrame.new(x, 17.5, z), Color3.fromRGB(35, 30, 40), Enum.Material.Slate)
		local portal = newPart(map, "MonsterGatePortal", Vector3.new(11, 15, 0.6), CFrame.new(x, 7.5, z), Color3.fromRGB(220, 50, 70), Enum.Material.Neon)
		portal.Transparency = 0.35
		portal.CanCollide = false
	end
end

function Plots.init(handlers)
	callbacks = handlers
	local layout = mapLayout()

	if workspace:FindFirstChild("Baseplate") == nil then
		-- big enough for the cul-de-sac, the road, the ridge and the arena
		local minX = -(layout.plotDistance + HALF + 40)
		local maxX = layout.arenaX + ARENA_RADIUS + 60
		local depth = math.max(layout.plotDistance + HALF + 40, 240) * 2
		newPart(workspace, "Baseplate", Vector3.new(maxX - minX, 4, depth), CFrame.new((minX + maxX) / 2, -2, 0), Color3.fromRGB(95, 170, 105), Enum.Material.Grass)
	end
	if workspace:FindFirstChildWhichIsA("SpawnLocation", true) == nil then
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.CFrame = CFrame.new(8, 1, 0)
		spawn.Neutral = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Parent = workspace
	end

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	buildPlaza(map, layout)
	buildRoad(map, layout)
	buildTunnel(map, layout)
	buildArena(map, layout)

	local root = Instance.new("Folder")
	root.Name = "Plots"
	root.Parent = workspace

	-- Plots around the plaza, each facing its centre. Ring position 0 (toward +X) is the road.
	for index = 1, Config.PlotCount do
		local angle = index * layout.step
		local position = Vector3.new(math.cos(angle) * layout.plotDistance, 0, math.sin(angle) * layout.plotDistance)
		plots[index] = buildPlot(index, CFrame.lookAt(position, Vector3.new(0, 0, 0)), root)
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
			Plots.setPending(plot, 0)
		end
	end
end

-- lines = array of strings, best store first.
function Plots.setLeaderboard(lines)
	local text = "🏆 TOP STORES\n" .. table.concat(lines, "\n")
	for _, label in ipairs(leaderboardLabels) do
		label.Text = text
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

-- Uncollected cash waiting at the cash register.
function Plots.setPending(plot, amount)
	if amount >= 1 then
		plot.registerLabel.Text = "💵 Collect " .. Format.cash(amount)
	else
		plot.registerLabel.Text = "💵 Cash register"
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

function Plots.setOwnerSign(plot, player, storeLevel, rebirths)
	local text = player.DisplayName .. "'s " .. Upgrades.getStoreTier(storeLevel).name
	if rebirths and rebirths > 0 then
		text = "★" .. rebirths .. "  " .. text
	end
	Plots.setSign(plot, text)
end

-- Tears down every stand and rebuilds `count` empty ones (used by rebirth).
function Plots.resetStands(plot, count)
	plot.standsFolder:ClearAllChildren()
	plot.stands = {}
	Plots.setSlotCount(plot, count)
end

function Plots.contains(plot, position)
	local localPosition = plot.cframe:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= HALF and math.abs(localPosition.Z) <= HALF
end

function Plots.getSpawnCFrame(plot)
	return plot.cframe * CFrame.new(0, 5, -21) * CFrame.Angles(0, math.pi, 0)
end

return Plots
