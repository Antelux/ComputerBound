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

local spamCharEvent = false
local spamCharTimer = 0.25

local cursorBlink = false
local cursorTimer = 0.5

function init()
	renderer = widget.bindCanvas("screen")
  	widget.focus("screen")

	MonitorID = pane.sourceEntity()
	sendMessage = world.sendEntityMessage

	DataPromise = sendMessage(MonitorID, "getData")
end

function uninit()

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

	if spamCharEvent and ComputerID then
		spamCharTimer = spamCharTimer - dt
		if spamCharTimer <= 0 then
			sendMessage(ComputerID, "interrupt", "char", spamCharEvent)
			spamCharTimer = 0.05
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

local KeyConversion = {
	-- temp keys
	[0] = "\01\01",
	[03] = "\01\03",
	[69] = "\01\69",
	[89] = "\01\89",
	[90] = "\01\90",
	


    [05] = " ",

    [11] = "'",
    [16] = ",",
    [17] = "-",
    [18] = ".",
    [19] = "/",

    [20] = "0",
    [21] = "1",
    [22] = "2",
    [23] = "3",
    [24] = "4",
    [25] = "5",
    [26] = "6",
    [27] = "7",
    [28] = "8",
    [29] = "9",

    [31] = ";",
    [33] = "=",
    [37] = "[",
    [38] = "\\",
    [39] = "]",
    [42] = "`",

    [43] = "a",
    [44] = "b",
    [45] = "c",
    [46] = "d",
    [47] = "e",
    [48] = "f",
    [49] = "g",
    [50] = "h",
    [51] = "i",
    [52] = "j",
    [53] = "k",
    [54] = "l",
    [55] = "m",
    [56] = "n",
    [57] = "o",
    [58] = "p",
    [59] = "q",
    [60] = "r",
    [61] = "s",
    [62] = "t",
    [63] = "u",
    [64] = "v",
    [65] = "w",
    [66] = "x",
    [67] = "y",
    [68] = "z",

    [70] = "0",
    [71] = "1",
    [72] = "2",
    [73] = "3",
    [74] = "4",
    [75] = "5",
    [76] = "6",
    [77] = "7",
    [78] = "8",
    [79] = "9",

    [80] = ".",
    [81] = "/",
    [82] = "*",
    [83] = "-",
    [84] = "+",

    [205] = " ",

    [211] = '"',
    [216] = "<",
    [217] = "_",
    [218] = ">",
    [219] = "?",

    [220] = ")",
    [221] = "!",
    [222] = "@",
    [223] = "#",
    [224] = "$",
    [225] = "%",
    [226] = "^",
    [227] = "&",
    [228] = "*",
    [229] = "(",

    [231] = ":",
    [233] = "+",
    [237] = "{",
    [238] = "|",
    [239] = "}",
    [242] = "~",

    [243] = "A",
    [244] = "B",
    [245] = "C",
    [246] = "D",
    [247] = "E",
    [248] = "F",
    [249] = "G",
    [250] = "H",
    [251] = "I",
    [252] = "J",
    [253] = "K",
    [254] = "L",
    [255] = "M",
    [256] = "N",
    [257] = "O",
    [258] = "P",
    [259] = "Q",
    [260] = "R",
    [261] = "S",
    [262] = "T",
    [263] = "U",
    [264] = "V",
    [265] = "W",
    [266] = "X",
    [267] = "Y",
    [268] = "Z"
}

local isShifting = false
local capsLock = false
function canvasKeyEvent(key, isKeyDown)
	if ComputerID then
		if key == 115 then isShifting = isKeyDown end
		--if key == capsLock and isKeyDown then capsLock = not capsLock end
		if isShifting or capsLock then key = key + 200 end
		local char = KeyConversion[key]

		if char then
			if isKeyDown then
				sendMessage(ComputerID, "interrupt", "char", char)
				spamCharEvent = char
				spamCharTimer = 0.5

			elseif char == spamCharEvent then
				spamCharEvent = false
				spamCharTimer = 0.5
			end
		end
	end
end