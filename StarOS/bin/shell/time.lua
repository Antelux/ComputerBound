-- Funny how I don't use os.time() for this.
local sFlag = ...
if sFlag then
	return sFlag == "-mt" and print("The current time is " ..os.date("%H:%M.")) or printError('unknown flag: "' ..sFlag.. '"')
end
print("The current time is " ..os.date("%I:%M %p."))