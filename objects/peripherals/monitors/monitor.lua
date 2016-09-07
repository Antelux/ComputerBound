--[[
	A little fun fact for why this function is here:

	Originally, there was a bug that made the screen "ghost", and I kinda liked it,
	so I decided it was gonna graduate from bug to feature. But then, I accidentally
	fixed it, not realizing how I caused it in the first place. So, I was kinda sad,
	and wrote up a quick and dirty function to emulate some "ghosting." For now, there's
	a small chance that a monitor will ghost upon use. Perhaps I'll remove the feature
	once the mod is out of the alpha phase.
--]]

--[[
math.randomseed(os.time() * 100000000)
local isGhosting = math.random(1000); isGhosting = isGhosting <= 2 and isGhosting or false
local floor, sqrt = math.floor, math.sqrt
local function ghost(s1, s2, p)
	local c1, c2 = bytes[sub(s1, p, p)], bytes[sub(s2, p, p)]
	return isGhosting == 1 and ((c1+c2) * 0.5) or sqrt(c1 ^ 2 + c2 ^ 2)
end
--]]

local Screen, Width, Height, Scale, Size

local ty = type
local concat = table.concat
local longTable, longString
local function prepareLongTable()
	local i = 2
	for y = 0, Height - 1 do
		for x = 0, Width - 1 do
			longTable[i] 	 = string.format("%02x", x)..string.format("%02x", y).."ff="
			longTable[i + 2] = ";"; i = i + 3
		end
	end
end

local ignore, sendMessage, entityID = true
local function generateNewLongString(Screen)
	if Screen ~= true then
		for i = 1, 240*135 do longTable[i * 3] = Screen[i] or "000000" end
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

function uninit()
	Screen, CompID = nil, nil
	longTable, longString = nil, nil
	collectgarbage(); collectgarbage()
end

-- Temp until proper mouse/keyboard peripherals are made.
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
		mx, my = mx[1] // Scale, Height - (mx[2] // Scale)
		if mx >= 1 and mx <= Width and my >= 1 and my <= Height then 
			sendMessage(CompID, "updateMouse", mx, my) 
		end

		if spamKeyEvent then
			spamKeyTimer = spamKeyTimer - dt
			if spamKeyTimer <= 0 then
				sendMessage(CompID, "pushEvent", "key", spamKeyEvent, true)
				spamKeyTimer = 0.05
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
	local mx, my = position[1] // Scale, Height - (position[2] // Scale)
	if ty(CompID) == "number" and mx >= 1 and mx <= Width and my >= 1 and my <= Height then
		sendMessage(CompID, "pushEvent", "mouse", mx, my, button, isDown)
	end
end