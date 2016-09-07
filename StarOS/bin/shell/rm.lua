local sPath = ...
if not sPath then printError("path expected") end
sPath = shell.resolvePath(sPath) or printError('no such directory "'..sPath..'/"')
if sPath then fs.delete(sPath) end