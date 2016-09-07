-- Potentially add the option to search a specific folder.
local sPath = ...
if not sPath then 
	return printError("path expected") 
end

sPath = sPath:gsub("*", ".*")
local tDirs, tFiles = {}, {}
local function search(sDir)
	local files = io.list(sDir)
	for i = 1, #files do
		local file = files[i]

		if file.name:find(sPath) then
			if file.isDir then
				tDirs[#tDirs + 1] = sDir..file.name
			else
				tFiles[#tFiles + 1] = sDir..file.name
			end
		end
		if file.isDir then search(sDir..file.name.."/") end
	end
end

for label in pairs(io.getLabels()) do
	search(label.. ":/")
end

if #tDirs ~= 0 then
	term.setTextColor(colors.green)
	print(table.concat(tDirs, "  "))
end

if #tFiles ~= 0 then
	term.setTextColor(colors.white)
	print(table.concat(tFiles, "  "))
end