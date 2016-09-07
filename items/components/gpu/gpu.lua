local binToHex = {[0]={[0]="00"},{},{},{},{},{},{},{},{}}
for b = 1, 8 do
	local max = 2^b-1
	for i = 0, max do
		binToHex[b][i] = string.format("%02x", math.ceil((i/max)*255))
	end
end

local ty, format, tonum = type, string.format, tonumber
function newGPU(MaxInputNodes, MaxOutputNodes, TotalBits)
	local changeOccured, reset = false, false
	local Screen, Width, Height, Size = {}
	local lBits, rBits, gBits, bBits = 0
	local Color = "000000"

	rBits, gBits, bBits = TotalBits // 3, TotalBits // 3, TotalBits // 3
	local leftOver = TotalBits - (rBits * 3)

	if leftOver == 1 then
		gBits = gBits + 1
	else
		rBits, gBits = rBits + 1, gBits + 1
	end

	local function init()
		if reset then
			--for i = 1, Width * Height * 3 do
			--	Screen[i] = nil
			--end
			reset = false
		end

		for i = 1, Size do
			Screen[i] = Color
		end
	end

	local function checkColor(c)
		if ty(c) == "number" and (c >= 0x0 and c <= 0xFFFFFF) then
			return binToHex[rBits][(c >> 16) >> (8 - rBits)]..binToHex[gBits][(c >> 8 & 0xFF) >> (8 - gBits)]..binToHex[bBits][(c & 0xFF) >> (8 - bBits)]
		else
			return Color
		end
	end

	local function clear(color)
		local Color = checkColor(color)
		for i = 1, Size do
			Screen[i] = Color
		end
		changeOccured = true
	end
	
	return {
		bind = function(port)
			if ty(port) ~= "number" then return end; port = port - MaxInputNodes
			if port < 0 or port > MaxOutputNodes then return end; local c, en = 0

			for e in pairs(object.getOutputNodeIds(port)) do c, en = c + 1, e end
			if c ~= 1 or not en then return end

			local mData = world.callScriptedEntity(en, "getSize")
			Width, Height = mData[1], mData[2]
			Size = Width * Height; init()

			world.callScriptedEntity(en, "bind", function(_, _, ignore)
				local oChangeOccured = changeOccured; changeOccured = false
				return (oChangeOccured or ignore) and Screen or true
			end)
		end,

		getSize = function()
			return Width, Height
		end,

		setColor = function(color)
			Color = checkColor(color)
		end,

		getColor = function()
			return tonum(Color, 16)
		end,

		clear = clear,

		offset = function(ox, oy, color)
			local ox = ty(ox) == "number" and ox // 1
			local oy = ty(oy) == "number" and oy // 1

			if ox or oy then
				local Color = checkColor(color)
				local off = (oy or 0) * Width + (ox or 0)

				for i = 1, Width * Height do
					Screen[i] = Screen[i+off] or Color
				end
				changeOccured = true 
			end
		end,

		point = function(x, y)
			local x = ty(x) == "number" and x >= 1 and x <= Width and x // 1
			local y = ty(y) == "number" and y >= 1 and y <= Height and y // 1

			if x and y then 
				Screen[(y - 1) * Width + x] = Color
				changeOccured = true 
			end
		end,

		line = function(x1, y1, x2, y2, color)
			-- Based on code from https://www.cs.helsinki.fi/group/goa/mallinnus/lines/bresenh.html
			local x1 = ty(x1) == "number" and ((x1 < 1 and 1) or (x1 > Width and Width) or x1) // 1
			local y1 = ty(y1) == "number" and ((y1 < 1 and 1) or (y1 > Height and Height) or y1) // 1
			local x2 = ty(x2) == "number" and ((x2 < 1 and 1) or (x2 > Width and Width) or x2) // 1
			local y2 = ty(y2) == "number" and ((y2 < 1 and 1) or (y2 > Height and Height) or y2) // 1
			
			if x1 and y1 and x2 and y2 then
				local Color = checkColor(color)
				local dx = x2 - x1
				local dy = y2 - y1
				local eps = 0

				local line = (y1 - 1) * Width
				for x = x1, x2 do
					Screen[line + x] = Color
					eps = eps + dy

					if eps << 1 >= dx then
						line = line + Width
						eps = eps - dx
					end
				end
				changeOccured = true
			end
		end,

		rectangle = function(x, y, w, h, color)
			local x = ty(x) == "number" and ((x < 1 and 1) or (x > Width and Width) or x) // 1
			local y = ty(y) == "number" and ((y < 1 and 1) or (y > Height and Height) or y) // 1
			local w, h = ty(w) == "number" and w // 1, ty(h) == "number" and h // 1

			if x and y and w and h then
				local Color = checkColor(color)

				w = x + w; w = w <= Width and w or Width - w
				h = y + h; h = h <= Height and h or Height - h

				for py = y - 1, h - 2 do
					local ay = py * Width
					for px = ay + x, ay + w - 1 do
						Screen[px] = Color
					end
				end
				changeOccured = true
			end
		end,

		drawTexture = function(texture, x, y, w, h, color)
			local texture = ty(texture) == "table" and #texture > 0 and texture
			local x = ty(x) == "number" and ((x < 1 and 1) or (x > Width and Width) or x) // 1
			local y = ty(y) == "number" and ((y < 1 and 1) or (y > Height and Height) or y) // 1
			local w, h = ty(w) == "number" and w // 1, ty(h) == "number" and h // 1

			if texture and x and y and w and h then
				w = (x + w) < Width and w or Width - x
				h = (y + h) < Height and h or Height - y
				local bColor = color and checkColor(color)
				local ex, i = x + w - 1, 1

				for py = y - 1, y + h - 2 do
					local ay = py * Width
					for px = x, ex do
						local color = texture[i] and (checkColor(texture[i]) or bColor)
						if color then Screen[ay + px] = color end; i = i + 1
					end
				end
				changeOccured = true
			end
		end,

		--[[
		drawScreen = function(screen)
			local screen = ty(screen) == "table" and #screen == Size and screen
			if screen then
				for i = 1, Size do
					Screen[i] = screen[i] and checkColor(screen[i]) or "000000"
				end
			end
		end,

		shader = function(fShader)
			
		end,
		--]]

		totalChannelBits = function()
			return rBits + gBits + bBits
		end,

		setChannelBits = function(channel, bits)
			if ty(channel) == "string" then
				if channel == "r" then
					if bits < rBits then
						lBits = lBits + (rBits - bits)
						rBits = bits
					elseif bits > rBits and bits - rBits <= lBits then
						lBits = lBits - (bits - rBits)
						rBits = bits
					end

				elseif channel == "g" then
					if bits < gBits then
						lBits = lBits + (gBits - bits)
						gBits = bits
					elseif bits > gBits and bits - gBits <= lBits then
						lBits = lBits - (bits - gBits)
						gBits = bits
					end

				elseif channel == "b" then
					if bits < bBits then
						lBits = lBits + (bBits - bits)
						bBits = bits
					elseif bits > bBits and bits - bBits <= lBits then
						lBits = lBits - (bits - bBits)
						bBits = bits
					end
				end
			end
		end,

		getChannelBits = function(channel)
			if ty(channel) == "string" then
				return (channel == "r" and rBits) or (channel == "g" and gBits) or (channel == "b" and bBits)
			end
		end
	}
end