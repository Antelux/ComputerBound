local tArgs = {...}
local sFile, sAlias

if #tArgs == 0 then
	printError("alias expected")
elseif #tArgs == 1 then
	sAlias = tArgs[1]
else
	sFile, sAlias = tArgs[1], tArgs[2]
end

if not (sFile or sAlias) then return end
if not sFile then
	local alias = shell.getAlias(sAlias)
	if alias then print(alias)
	else printError("no such alias") end
	return
end

if shell.getAlias(sAlias) then 
	printError('the alias "' ..sAlias.. '" already exists')
	return
end

sFile = shell.resolvePath(sFile) or printError('no such file "'..sFile..'/"')
if sFile then
	if io.exists(sFile) ~= "file" then 
		printError('file expected')
		return
	end

	shell.setAlias(sFile, sAlias)
end