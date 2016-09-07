local sFile = ...
if not sFile then 
	printError("file name expected") 
	return
end

sFile = shell.resolvePath(sFile) or printError('no such file "'..sFile..'/"')
if sFile then
	if io.exists(sFile) ~= "file" then 
		printError('file expected')
		return
	end

	term.setTextColor(colors.white)
	for line in io.lines(sFile) do
		print(line)
	end
end