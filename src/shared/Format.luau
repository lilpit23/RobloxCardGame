-- Number formatting: 1234567 -> "1.23M"
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc" }

function Format.short(value)
	value = math.floor(value or 0)
	if value < 1000 then
		return tostring(value)
	end
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value = value / 1000
		index = index + 1
	end
	local text
	if value >= 100 then
		text = string.format("%d", math.floor(value))
	elseif value >= 10 then
		text = string.format("%.1f", math.floor(value * 10) / 10)
	else
		text = string.format("%.2f", math.floor(value * 100) / 100)
	end
	return text .. SUFFIXES[index]
end

function Format.cash(value)
	return "$" .. Format.short(value)
end

return Format
