local tFiles = {...}
if not tFiles[1] then return printError("source path expected") end
if not tFiles[2] then return printError("destination path expected") end
tFiles[1] = shell.resolvePath(tFiles[1]) or printError('no such path "'..tFiles[1]..'/"')
tFiles[2] = shell.resolvePath(tFiles[2]) or shell.getWorkingDirectory()..tFiles[2]
if not (tFiles[1] and tFiles[2]) then return end; fs.copy(tFiles[1], tFiles[2])