local sAlias = ...
if not sAlias then
	printError("alias expected")
	return
end

shell.clearAlias(sAlias)