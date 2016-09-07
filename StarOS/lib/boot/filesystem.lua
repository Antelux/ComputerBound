-- This API feels so cluttered.. I should re-work it some time;
-- Clean it up and such, give it a fresh coat of paint.

local io, ty = io, type
local rem = table.remove

local protectedPaths = {}
local function isProtected(sPath, bIgnore)
	sPath = sPath:gsub("/", "\\")
	while sPath:sub(#sPath, #sPath) == "\\" do sPath = sPath:sub(1, #sPath - 1) end

	for i = 1, #protectedPaths do
		if sPath:find(protectedPaths[i]) == 1 then 
			return not bIgnore and error("the path " ..protectedPaths[i].. "\\ is protected.", 2) or true
		end
	end
	return sPath
end

local function preparePath(sPath, checkForExistence)
	local sPath = ty(sPath) == "string" and isProtected(sPath) or error("path must be a string, got a " ..ty(sPath).. " value", 2)
	if checkForExistence and io.exists(sPath) ~= nil then error('the path "' ..sPath.. '" already exists', 2) end

	local tPath = {}
	for s in sPath:gmatch("([^\\]+)") do
    	tPath[#tPath + 1] = s
    end
    if #tPath <= 2 then 
    	return sPath
    end

    local sPath = rem(tPath, 1).."\\"..rem(tPath, 1)
    local sEnd = rem(tPath, #tPath)
    for i = 1, #tPath == 0 and 1 or #tPath do
    	local sType = io.exists(sPath)
    	if sType == "file" then
    		error('the path "' ..sPath.. '" refers to a file', 2)
    	
    	elseif sType == nil then
    		io.makeDir(sPath)
    	end
    	sPath = sPath.."\\"..(rem(tPath, 1) or "")
    end
    return sPath.."\\"..sEnd
end

local function cp(sPath1, sPath2)
	local sType = io.exists(sPath1)
	if sType == "dir" then
		io.makeDir(sPath2)

		local files = io.list(sPath1)
		for i = 1, #files do
			local file = files[i]
			if file.isDir then
				cp(sPath1.."\\"..file.name, sPath2.."\\"..file.name)
			else
				local f1 = io.open(sPath1.."\\"..file.name, "r")
				local f2 = io.open(sPath2.."\\"..file.name, "w")
				f2:write(f1:read("a")):close(); f1:close()
			end
		end
	else
		local f1 = io.open(sPath1, "r")
		local f2 = io.open(sPath2, "w")
		f2:write(f1:read("a")):close(); f1:close()
	end
end

fs = {
	open = function(sFile, sMode)
		if ty(sFile) ~= "string" then error("file name must be a string, got a " ..ty(sFile).. " value", 2) end
		if ty(sMode) ~= "string" then error("file mode must be a string, got a " ..ty(sMode).. " value", 2) end
		if sMode:find("[wa%+]") then sFile = isProtected(sFile) end; return io.open(sFile, sMode)
	end,

	preparePath = function(sFile)
		preparePath(sFile)
	end,

	makeDir = function(sDir)
		io.makeDir(preparePath(sDir))
	end,

	copy = function(sPath1, sPath2)
		if not io.exists(sPath1) then error("cannot copy non-existant file or dir", 2) end
		return cp(sPath1, preparePath(sPath2, true)) or true
	end,

	move = function(sPath1, sPath2)
		os.rename(isProtected(sPath1), preparePath(sPath2, true))
	end,

	delete = function(sPath)
		os.remove(isProtected(sPath))
	end,

	listFiles = function(sPath)
		local tDirectory = io.list(sPath)
		local tFiles, i = {}, 1
		
		for j = 1, #tDirectory do
			if not tDirectory[j].isDir then
				tFiles[i] = tDirectory[j].name; i = i + 1
			end
		end
		return tFiles
	end,

	listFolders = function(sPath)
		local tDirectory = io.list(sPath)
		local tFiles, i = {}, 1

		for j = 1, #tDirectory do
			if tDirectory[j].isDir then
				tFiles[i] = tDirectory[j].name; i = i + 1
			end
		end
		return tFiles
	end,

	protect = function(sPath)
		local sPath = ty(sPath) == "string" and sPath:gsub("/", "\\") or error("path must be a string, got a " ..ty(sPath).. " value", 2)
		local sType = io.exists(sPath)

		if sType == "file" then
			error("can only protect directories", 2)
		
		elseif sType == "dir" then
			while sPath:sub(#sPath, #sPath) == "\\" do
				sPath = sPath:sub(1, #sPath - 1)
			end
			protectedPaths[#protectedPaths + 1] = sPath
		
		else
			error("cannot protect non-existant directory", 2)
		end
	end,

	isProtecting = function(sPath)
		return isProtected(ty(sPath) == "string" and sPath or error("path must be a string, got a " ..ty(sPath).. " value", 2), true)
	end,

	--getSize = function()
	--end,

	--getFreeSpace = function()
    --end,

    --getTotalSpace = function(sDrive)
    --end
}