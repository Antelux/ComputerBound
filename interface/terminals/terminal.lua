local type = type

local renderer
local sendMessage

local Width, Height
local Colors

local DataPromise
local QueuePromise
local Queue

local MonitorID
local ComputerID

local spamKeyEvent = false
local spamKeyTimer = 0.25

local cursorBlink = false
local cursorTimer = 0.5

function init()
	renderer = widget.bindCanvas("screen")
  	widget.focus("screen")

	MonitorID = pane.sourceEntity()
	sendMessage = world.sendEntityMessage

	DataPromise = sendMessage(MonitorID, "getData")
end

function update(dt)
	cursorTimer = cursorTimer - dt
	if cursorTimer <= 0 then
		cursorBlink = not cursorBlink
		cursorTimer = 0.5
	end

	if DataPromise and DataPromise:finished() then
		if DataPromise:succeeded() then
			local Data = DataPromise:result()
			ComputerID = Data[1]
			Width, Height = Data[2], Data[3]
			Colors = Data[4]

			QueuePromise = sendMessage(MonitorID, "getQueue")
			DataPromise = nil
		else
			sb.logInfo("Terminal GUI Error: " .. tostring(DataPromise:error()))
			DataPromise = sendMessage(MonitorID, "getData")
		end
	end

	if spamKeyEvent and ComputerID then
		spamKeyTimer = spamKeyTimer - dt
		if spamKeyTimer <= 0 then
			sendMessage(ComputerID, "interrupt", "key_sustain", spamKeyEvent, true)
			spamKeyTimer = 0.05
		end
	end

	if QueuePromise and QueuePromise:finished() then
		local Queue = QueuePromise:result()
		if Queue then
			local renderer = renderer
			local position = {0, 0}
			local rect = {0, 0, 0, 0}

			local textPositioning = {
				position = position,
				horizontalAnchor = "mid",
				verticalAnchor = "top"
			}

			renderer:clear()

			local Size = #Queue
			for i = 1, Size - 4, 3 do
				local line = Queue[i]
				local inverted = Queue[i + 1]
				local y = Height - Queue[i + 2] + 1

				position[2] = (y * 11) + 40

				for x = 1, Width do
					position[1] = (x * 6.4) + 29

					if inverted[x] then
						rect[1] = (x * 6.4) + 25.4
						rect[2] = (y * 11) + 29
						rect[3] = (x * 6.4) + 31.8
						rect[4] = (y * 11) + 40

						renderer:drawRect(rect, Colors[1])
						if line[x] ~= " " then
							renderer:drawText(line[x], textPositioning, 10, Colors[2])
						end
						
					elseif line[x] ~= " " then
						renderer:drawText(line[x], textPositioning, 10, Colors[1])
					end
				end
			end

			if cursorBlink then
				local char = Queue[Size]
				local inverted = Queue[Size - 1]
				local cury = Height - Queue[Size - 2]
				local curx = Queue[Size - 3]

				rect[1] = (curx * 6.4) + 31.8
				rect[2] = (cury * 11) + 40
				rect[3] = (curx * 6.4) + 38.2
				rect[4] = (cury * 11) + 51

				position[2] = (cury * 11) + 40
				position[1] = (curx * 6.4) + 29

				if inverted then
					renderer:drawRect(rect, Colors[1])
					renderer:drawText(char, textPositioning, 10, Colors[2])
				else
					renderer:drawRect(rect, Colors[2])
					renderer:drawText(char, textPositioning, 10, Colors[1])
				end
			end

			Queue = nil
			collectgarbage(); collectgarbage()
		end
		
		QueuePromise = sendMessage(MonitorID, "getQueue")
	end
end

function canvasKeyEvent(key, isKeyDown)
	if ComputerID then
		if isKeyDown then
			sendMessage(ComputerID, "interrupt", "key_press", key)
		else
			sendMessage(ComputerID, "interrupt", "key_release", key)
		end

		if isKeyDown then
			spamKeyEvent = key
			spamKeyTimer = 0.5
		else
			if key == spamKeyEvent then
				spamKeyEvent = false
				spamKeyTimer = 0.5
			end
		end
	end
end