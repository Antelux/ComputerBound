-- Add a flag for showing more info when listing files, such as size, last modified date/time, #files in a folder, etc.
local sPath = ...
if sPath then
	sPath = shell.resolvePath(sPath) or printError('no such directory "'..sPath..'/"')
	if not sPath then return end
else
	sPath = shell.getWorkingDirectory()
end

local tFolders = fs.listFolders(sPath)
local tFiles = fs.listFiles(sPath)

if #tFolders ~= 0 then
	term.setTextColor(colors.green)
	print(table.concat(tFolders, "  "))
end

if #tFiles ~= 0 then
	term.setTextColor(colors.white)
	print(table.concat(tFiles, "  "))
end