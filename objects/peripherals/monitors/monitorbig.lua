local toHex = {}
for i = 0, 255 do
	local h = string.format("%x", i)
	toHex[i] = #h == 1 and "0"..h or h
end

local Screen, Width, Height, Scale, Size
local sub, ty = string.sub, type

local concat = table.concat
local longTable, longString
local function prepareLongTable()
	local i = 2
	for y = 0, Height - 1 < 255 and Height - 1 or 255 do
		for x = 0, Width - 1 < 255 and Width - 1 or 255 do
			longTable[i] 	 = toHex[x]..toHex[y].."ff="
			longTable[i + 2] = ";"; i = i + 3
		end
	end
end

local maxSize = 255*255
local ignore, sendMessage, entityID = true
local function generateNewLongString(Screen)
	if Screen ~= true then
		for i = 1, Size < maxSize and Size or maxSize do longTable[i * 3] = Screen[i] or "000000" end
		Screen = nil; longString = concat(longTable)
		collectgarbage(); collectgarbage(); ignore = false
	end

	return sendMessage(entityID, "getBind", ignore)
end

local drawImage, unpackStr
function init()
	local size = console.canvasSize()
	Scale = config.getParameter("scale")
	Width, Height = size[1] / Scale, size[2] / Scale
	Size = Width * Height

	entityID = console.sourceEntity()
	drawImage = console.canvasDrawImage
	sendMessage = world.sendEntityMessage

	longTable = {"/objects/peripherals/monitors/"..config.getParameter("type").."/screen.png?replace;"}
	prepareLongTable(); Screen = {}; for i = 1, Size do Screen[i] = "000000" end
	Screen.succeeded = function() return true end; Screen.result = function(self) return self end
	
	collectgarbage("stop")
end

function die()
	Screen, CompID, toHex = nil, nil, nil
	longTable, longString = nil, nil
	collectgarbage(); collectgarbage()
end

local spamKeyEvent = false
local spamKeyTimer = 0.25

local iCoords, CompID = {0, 0}
function update(dt)
	CompID = CompID or sendMessage(entityID, "getID")
	Screen = Screen:result() and generateNewLongString(Screen:result()) or Screen

	drawImage(longString, iCoords, Scale)

	if ty(CompID) == "userdata" then
		CompID = CompID:result() or CompID

	else
		local mx, my = console.canvasMousePosition()
		mx, my = (mx[1] / Scale) // 1, Height - ((mx[2] / Scale) // 1)
		if mx >= 1 and mx <= Width and my >= 1 and my <= Height then 
			sendMessage(CompID, "updateMouse", mx, my) 
		end

		if spamKeyEvent then
			spamKeyTimer = spamKeyTimer - dt
			if spamKeyTimer <= 0 then
				sendMessage(CompID, "pushEvent", "key", spamKeyEvent, true) 
			end
		end
	end
end

function canvasKeyEvent(key, isKeyDown)
	if ty(CompID) == "number" then
		sendMessage(CompID, "pushEvent", "key", key, isKeyDown)
		if isKeyDown then
			spamKeyEvent = key
			spamKeyTimer = 1
		else
			if key == spamKeyEvent then
				spamKeyEvent = false
				spamKeyTimer = 1
			end
		end
	end
end

function canvasClickEvent(position, button, isDown)
	local mx, my = (position[1] / Scale) // 1, Height - ((position[2] / Scale) // 1)
	if ty(CompID) == "number" and mx >= 1 and mx <= Width and my >= 1 and my <= Height then
		sendMessage(CompID, "pushEvent", "mouse", (position[1] / Scale) // 1, Height - (position[2] / Scale) // 1, button, isDown)
	end
end