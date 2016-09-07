local uptime = os.clock()

-- I'm really liking the new // operation. =P
local nMinutes = uptime // 60
local nSeconds = uptime // 1
local nHours = uptime // 3600
local nDays = uptime // 86400
local Weeks = uptime // 604800

local Days = (uptime // 86400) - Weeks * 7
local Hours = (uptime // 3600) - nDays * 24
local Minutes = (uptime // 60) - nHours * 60
local Seconds = (uptime // 1) - nMinutes * 60

term.setTextColor(colors.white)
print("The computer has been on for "..
	(Weeks ~= 0 and math.tointeger(Weeks).." weeks, " or "")..
	(Days ~= 0 and math.tointeger(Days).." days, " or "")..
	(Hours ~= 0 and math.tointeger(Hours).." hours, " or "")..
	(Minutes ~= 0 and math.tointeger(Minutes).." minutes, and " or "")..
	(Seconds ~= 0 and math.tointeger(Seconds).." seconds." or ""))