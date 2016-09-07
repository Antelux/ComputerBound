local sPath = ...
if not sPath then
	term.setTextColor(colors.white)
	return print(shell.getWorkingDirectory()) 
end

if sPath == ".." then
	local workingDirectory, t = shell.getWorkingDirectory():gsub("\\", "/"), {}
	for path in workingDirectory:gmatch("([^/]+)") do t[#t + 1] = path end; t[#t] = nil
	if #t ~= 0 then shell.setWorkingDirectory(table.concat(t, "/").."/"); t = nil end; return
end

sPath = shell.resolvePath(sPath) or printError('no such directory "'..sPath..'/"')
if sPath then shell.setWorkingDirectory(sPath) end