local nWidth, nHeight = 100, 100 --gpu.getSize()
local rBits = gpu.getChannelBits("r")
local gBits = gpu.getChannelBits("g")
local bBits = gpu.getChannelBits("b")

local tArgs = {...}

local sFile = tArgs[1] and (shell.resolvePath(tArgs[1]) or shell.getWorkingDirectory()..tArgs[1])
if not sFile then return printError("path expected") end; local fileType = io.exists(sFile)
if fileType == "dir" then return printError("cannot paint a directory") end

nWidth, nHeight = tonumber(tArgs[2]) or nWidth, tonumber(tArgs[3]) or nHeight
if nWidth and nWidth < 1 then return printError("width must be greater than 0") end
if nHeight and nHeight < 1 then return printError("height must be greater than 0") end

-- Had to borrow this from the GPU code
local binToHex = {{},{},{},{},{},{},{},{}}
for b = 1, 8 do
	local max = 2^b-1
	for i = 0, max do
		binToHex[b][i] = math.ceil((i/max)*255)
	end
end

local byte, char = string.byte, string.char
local tonum = tonumber
local file = fs.open(sFile, "rb")
local image = {}

local function assert(condition, err)
	if not condition then
		file:close()
		error("file is corrupted: " ..err, 2)
	end
end

local function readByte() 
	local byte = file:read(1)
	return assert(byte, "incorrect length") or byte:byte()
end

local bitString = ""
local function readBits(nBits)
	if nBits > #bitString then
		for i = 1, math.ceil(nBits / 8) do
			local byte, bits = readByte(), ""
			for i = 1, 8 do
				local obyte = byte; byte = byte >> 1
				bits = (byte == obyte * 0.5 and 0 or 1)..bits
			end
			bitString = bitString..bits
		end
	end
	local bits = bitString:sub(1, nBits)
	bitString = bitString:sub(nBits + 1)
	return tonum(bits, 2)
end

if file then
	-- SPIF = StarOS Paint Image File Format
	local Header = readBits(32); assert(Header == 0x53504946, "invalid header")
	rBits = readBits(3); assert(rBits <= 8, "invalid rBits")
	gBits = readBits(3); assert(gBits <= 8, "invalid gBits")
	bBits = readBits(3); assert(bBits <= 8, "invalid bBits")
	nWidth = readBits(16); nHeight = readBits(16)

	for i = 1, nWidth * nHeight do
		image[i] = (binToHex[rBits][readBits(rBits)]<<16) + (binToHex[gBits][readBits(gBits)]<<8) + binToHex[bBits][readBits(bBits)]
	end
	file:close()
else
	for i = 1, nWidth * nHeight do
		image[i] = 0
	end
end

local byteString = ""
local function writeBits(n, bits)
	local bstr = ""
	for i = 1, bits do
		local on = n; n = n >> 1
		bstr = (n == on * 0.5 and 0 or 1)..bstr
	end

	byteString = byteString..bstr
	for i = 1, #byteString // 8 do
		file:write(char(tonum(byteString:sub(1, 8), 2)))
		byteString = byteString:sub(9)
	end
end

-- H: 0-359, S: 0-1, V:0-1
local abs = math.abs
local function HSVtoRGB(h, s, v)
	local C = v*s
	local X = C * (1 - abs((h / 60) % 2 - 1))
	local m = v - C
	local i = h // 60
	local R, G, B

	if i == 0 then -- 0-60
		R, G, B = C, X, 0
	elseif i == 1 then -- 60-159
		R, G, B = X, C, 0
	elseif i == 2 then -- 120--179
		R, G, B = 0, C, X
	elseif i == 3 then -- 180-239
		R, G, B = 0, X, C
	elseif i == 4 then -- 240-299
		R, G, B = X, 0, C
	else -- 300-359
		R, G, B = C, 0, X
	end
	return ((((R+m)*255 + 0.5) // 1) << 16) + ((((G+m)*255 + 0.5) // 1) << 8) + (((B+m)*255 + 0.5) // 1)
end

local rWidth, rHeight = gpu.getSize()
local tWidth, tHeight = term.getSize()
local showColorSelector = true
local currentHue = 180
local currentSat = 50
local currentVal = 50

local squareStartX = (rWidth//2) - 50
local squareStartY = (rHeight//2) - 50
local function redraw()
	gpu.clear(0)--; gpu.drawTexture(image, 1, 1, nWidth, nHeight)
	--gpu.setColor(colors.white)
	--gpu.rectangle(5, 5, 102, 1)
	--gpu.rectangle(5, 106, 103, 1)

	if not showColorSelector then return end
	-- Draw the hue selectors.
	local y = -1
	for i = 0, 179, 1.8 do
		gpu.setColor(HSVtoRGB(i, 1, 1)); y = y + 1
		gpu.rectangle(squareStartX - 19, squareStartY + y, 10, 1)
	end

	local y = -1
	for i = 180, 359, 1.8 do
		gpu.setColor(HSVtoRGB(i, 1, 1)); y = y + 1
		gpu.rectangle(squareStartX + 110, squareStartY + y, 10, 1)
	end


	gpu.setColor(colors.white) -- Draw the border around the color square.
	gpu.rectangle(squareStartX - 1, squareStartY - 1, 103, 1)
	gpu.rectangle(squareStartX - 1, squareStartY + 101, 103, 1)
	gpu.rectangle(squareStartX - 1, squareStartY, 1, 101)
	gpu.rectangle(squareStartX + 101, squareStartY, 1, 101)

	-- Draw the actual color sqaure.
	for s = 0, 100 do
		for v = 0, 100 do
			gpu.setColor(HSVtoRGB(currentHue, 1-s/100, v/100))
			gpu.point(v + squareStartX, s + squareStartY)
		end
	end

	-- Points to the currently selected color.
	gpu.rectangle(currentVal + squareStartX, squareStartY, 1, 101)
	gpu.rectangle(squareStartX, squareStartY + currentSat, 101, 1)

	-- Points to the currently selected hue.
	gpu.setColor(colors.white); local left = currentHue < 180
	gpu.rectangle(squareStartX + (left and -21 or 108), squareStartY + (currentHue/1.8) - (left and 0 or 100), 14, 1)

	-- Write text centered on screen.
	local channelStr = "Channels: " ..gpu.getChannelBits("r").. ", " ..gpu.getChannelBits("g").. ", " ..gpu.getChannelBits("b")
	term.setCursorPos((tWidth/2) - (#channelStr/2), 1); term.write(channelStr)
	local selectionStr = "HSV: " ..currentHue.. ", " ..currentSat.. ", " ..currentVal
	term.setCursorPos((tWidth/2) - (#selectionStr/2), tHeight); term.write(selectionStr)
end

redraw()

local drawTimer = system.startTimer(0.05)
local color1, color2 = colors.white, colors.black
local mouseDown -- 0 = l, 1 = m, 2 = r

while true do
	local eventType, mx, my, button, isDown = event.pull("mouse", "key", "timer")

	if eventType == "mouse" then
		mouseDown = isDown and button
		if isDown then
			if showColorSelector then
				-- Color sqare
				if mx >= squareStartX and mx <= squareStartX + 100 and my >= squareStartY and my <= squareStartY + 100 then
					currentVal = mx - squareStartX
					currentSat = math.tointeger(my - squareStartY)

				-- Hue Sliders
				elseif my >= squareStartY and my <= squareStartY + 99 then
					if mx >= squareStartX - 19 and mx <= squareStartX - 10 then -- Left slider
						currentHue = math.tointeger(((my - squareStartY) * 1.8 + 0.5) // 1)
					elseif mx >= squareStartX + 110 and mx <= squareStartX + 120 then -- Left slider
						currentHue = 180 + math.tointeger(((my - squareStartY) * 1.8 + 0.5) // 1)
					end
				end

			elseif mx <= nWidth and my <= nHeight then
				image[(my-1)*nHeight+mx] = mouseDown == 0 and color1 or color2
			end

			 -- TEMP
			--[[
			file = fs.open(sFile, "wb")
			if file then
				file:write("SPIF")
				writeBits(rBits, 3); writeBits(gBits, 3); writeBits(bBits, 3)
				writeBits(nWidth, 16); writeBits(nHeight, 16)
				for i = 1, nWidth*nHeight do
					local c = image[i]
					writeBits((c >> 16) >> (8 - rBits), rBits)
					writeBits((c >> 8 & 0xFF) >> (8 - gBits), gBits)
					writeBits((c & 0xFF) >> (8 - bBits), bBits)
				end
				if #byteString ~= 0 then
					file:write(char(tonum(byteString:sub(1, #byteString), 2)))
					byteString = ""
				end
			end
			--]]
			redraw()
		end

	elseif eventType == "key" then
		local key, isDown = mx, my
		if isDown then
			if key == keys.e then 
				break
			end

			if showColorSelector then
				-- Hue fine tuning
				if key == keys.kp7 then
					currentHue = currentHue + 1
					if currentHue == 360 then currentHue = 0 end

				elseif key == keys.kp9 then
					currentHue = currentHue - 1
					if currentHue == -1 then currentHue = 359 end

				-- Saturation fine tuning
				elseif key == keys.kp4 then
					currentSat = currentSat - 1
					if currentSat == -1 then currentSat = 100 end

				elseif key == keys.kp6 then
					currentSat = currentSat + 1
					if currentSat == 101 then currentSat = 0 end

				-- Value fine tuning
				elseif key == keys.kp1 then
					currentVal = currentVal - 1
					if currentVal == -1 then currentVal = 100 end

				elseif key == keys.kp3 then
					currentVal = currentVal + 1
					if currentVal == 101 then currentVal = 0 end
				end
			end
		end

	elseif eventType == "timer" and mx == drawTimer then
		drawTimer = system.startTimer(0.05)

		if mouseDown then
			local mx, my = mouse.getPosition()
			--if mx <= nWidth and my <= nHeight then
			--	image[(my-1)*nHeight+mx] = mouseDown == 0 and color1 or color2
			--end

			if showColorSelector then
				-- Color square
				if mx >= squareStartX and mx <= squareStartX + 100 and my >= squareStartY and my <= squareStartY + 100 then
					currentVal = mx - squareStartX
					currentSat = math.tointeger(my - squareStartY)
				
				-- Hue Sliders
				elseif my >= squareStartY and my <= squareStartY + 99 then
					if mx >= squareStartX - 19 and mx <= squareStartX - 10 then -- Left slider
						currentHue = math.tointeger(((my - squareStartY) * 1.8 + 0.5) // 1)
					elseif mx >= squareStartX + 110 and mx <= squareStartX + 120 then -- Left slider
						currentHue = 180 + math.tointeger(((my - squareStartY) * 1.8 + 0.5) // 1)
					end
				end
			end
		end

		redraw()
	end
end

gpu.clear(0)
term.setCursorPos(1,1)