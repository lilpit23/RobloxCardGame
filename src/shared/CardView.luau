-- Builds the visual for a card. Used by the client UI and by the display stands in the world.
local Cards = require(script.Parent.Cards)
local Format = require(script.Parent.Format)

local CardView = {}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 140)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 110, 255)),
})

local function addLabel(parent, text, yScale, heightScale, font)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0.06, 0, yScale, 0)
	label.Size = UDim2.new(0.88, 0, heightScale, 0)
	label.Font = font or Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Parent = parent
	return label
end

local function baseFrame(color, strokeColor)
	local frame = Instance.new("Frame")
	frame.Name = "Card"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.07, 0)
	corner.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(105, 105, 120))
	gradient.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 4
	stroke.Color = strokeColor
	stroke.Parent = frame

	return frame, stroke
end

-- "DJL 007/038 ★" — set code, card number and rarity mark, like the corner of a real card.
local function numberLine(def)
	local set = Cards.Sets[def.set]
	return set.code .. " " .. def.numberText .. " " .. Cards.Rarities[def.rarity].symbol
end

-- Full card face for a card key.
function CardView.new(key)
	local def, variantId, variant = Cards.parse(key)
	if def == nil then
		return CardView.newUnknown(nil)
	end
	local rarity = Cards.Rarities[def.rarity]
	local frame, stroke = baseFrame(rarity.color, variant.color)

	if variantId == "prism" then
		local rainbow = Instance.new("UIGradient")
		rainbow.Color = RAINBOW
		rainbow.Rotation = 45
		rainbow.Parent = stroke
	end

	addLabel(frame, def.name, 0.02, 0.15)

	if def.image then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Position = UDim2.new(0.1, 0, 0.18, 0)
		image.Size = UDim2.new(0.8, 0, 0.38, 0)
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = def.image
		image.Parent = frame
	else
		addLabel(frame, def.glyph or "?", 0.18, 0.38)
	end

	local typeInfo = Cards.Types[def.type]
	local rarityLabel = addLabel(frame, typeInfo.icon .. " " .. string.upper(def.rarity), 0.57, 0.08, Enum.Font.GothamBlack)
	if def.rarity == "Secret" then
		rarityLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	end

	local income = addLabel(frame, Format.cash(Cards.getIncome(key)) .. "/s", 0.66, 0.11, Enum.Font.GothamBlack)
	income.TextColor3 = Color3.fromRGB(150, 255, 160)

	local bottom = {}
	if variantId ~= "normal" then
		table.insert(bottom, "✨ " .. string.upper(variant.name))
	end
	local aura = Cards.getAura(key)
	if aura > 0 then
		table.insert(bottom, "+" .. Format.short(aura) .. " aura/s")
	end
	if #bottom > 0 then
		local bottomLabel = addLabel(frame, table.concat(bottom, "  "), 0.78, 0.08)
		bottomLabel.TextColor3 = Color3.fromRGB(255, 190, 240)
	end

	local number = addLabel(frame, numberLine(def), 0.89, 0.07)
	number.TextColor3 = Color3.fromRGB(230, 230, 240)

	return frame
end

-- Face-down / undiscovered card (an empty binder slot). def may be nil.
function CardView.newUnknown(def)
	local frame = baseFrame(Color3.fromRGB(45, 45, 55), Color3.fromRGB(20, 20, 25))
	local question = addLabel(frame, "?", 0.18, 0.42, Enum.Font.GothamBlack)
	question.TextColor3 = Color3.fromRGB(120, 120, 135)
	if def then
		local rarity = Cards.Rarities[def.rarity]
		local label = addLabel(frame, string.upper(def.rarity), 0.66, 0.1, Enum.Font.GothamBlack)
		label.TextColor3 = rarity.color
		if def.rarity == "Secret" then
			label.TextColor3 = Color3.fromRGB(255, 80, 80)
		end
		local number = addLabel(frame, numberLine(def), 0.89, 0.07)
		number.TextColor3 = Color3.fromRGB(150, 150, 165)
	end
	return frame
end

return CardView
