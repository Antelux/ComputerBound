local unpack, ty = table.unpack, type
shell = {
    -- Allows for seperate shell instances.
    new = function()
        local workingDirectory = "C:/"
        local aliases = {}

        -- Load usermade aliases.
        local dataPath = os.getenv("%DATA%") or ""
        local sType = io.exists(dataPath.. "/shaliases.json")

        if sType == "file" then
            local file = fs.open(dataPath.. "/shaliases.json", "r")
            local ok, tJson = pcall(json.decode, file:read("a")); file:close()
            if not ok then
                printError(dataPath.. "/shaliases.json refers to an invalid JSON, recommending deletion or fixing of file.")
            
            elseif type(tJson) == "table" then
                for k, v in pairs(tJson) do
                    aliases[k] = v
                end
            end

        elseif sType == "dir" then
            printError(dataPath.. "/shaliases.json refers to a directory, recommending a path change.")
        end

        -- Now return the shell object.
        return {
            execute = function(line)
                local words = {}
                for s in line:gmatch("([^ ]+)") do
                    words[#words + 1] = s
                end

                local cmd = table.remove(words, 1)
                if not cmd then words = nil; return end

                if aliases[cmd] then
                    local ok, err = dofile(aliases[cmd], unpack(words))
                    if not ok then printError(err) end

                elseif io.exists(workingDirectory..cmd) == "file" then
                    local ok, err = dofile(workingDirectory..cmd, unpack(words))
                    if not ok then printError(err) end

                else
                    printError("Invalid program")
                end
                words = nil
            end,

            setWorkingDirectory = function(sPath)
                if ty(sPath) == "string" then
                    if io.exists(sPath) ~= "dir" then error("path must be a existant directory", 2) end
                    sPath:gsub("\\", "/"); while sPath:sub(#sPath, #sPath) == "/" do sPath = sPath:sub(1, #sPath - 1) end
                    workingDirectory = sPath.."/"
                else
                    error("path must be a string, got a " ..ty(sPath).. " value", 2)
                end
            end,

            getWorkingDirectory = function(sPath)
                return workingDirectory
            end,

            resolvePath = function(sPath)
                if ty(sPath) ~= "string" then error("path must be a string, got a " ..ty(sPath).. " value.", 2) end
                sPath:gsub("\\", "/"); while sPath:sub(#sPath, #sPath) == "/" do sPath = sPath:sub(1, #sPath - 1) end

                local sType = io.exists(sPath); if sType then return sPath end
                sType = io.exists(workingDirectory..sPath); if sType then return workingDirectory..sPath end
            end,

            setAlias = function(sPath, sAlias)
                local sPath = ty(sPath) == "string" and sPath or error("path must be a string, got a " ..ty(sPath).. " value", 2)
                local sType = io.exists(sPath)

                if sType == "file" then
                    local alias = ty(sAlias) == "string" and sAlias or error("alias must be a string, got a " ..ty(sAlias).. " value", 2)
                    if aliases[alias] then error("alias " ..alias.. " already exists", 2) end; aliases[alias] = sPath

                elseif sType == "dir" then
                    local files = io.list(sPath)
                    for i = 1, #files do
                        local file = files[i]
                        if not file.isDir and file.name:find("[^%.]+%.lua") then
                            aliases[file.name:match("[^%.]+")] = sPath.."/"..file.name
                        end
                    end
                else
                    error('"'..sPath..'" refers to a non-existant file or directory.', 2)
                end
            end,

            clearAlias = function(sAlias)
                local alias = ty(sAlias) == "string" and sAlias or error("alias must be a string, got a " ..ty(sAlias).. " value", 2)
                aliases[alias] = nil
            end,

            getAlias = function(sAlias)
                if ty(sAlias) == "string" then return aliases[sAlias] end
                local tAliases = {}
                for alias, path in pairs(aliases) do
                    tAliases[alias] = path
                end
                return tAliases
            end,

            saveAliases = function()
                local dataPath = os.getenv("%DATA%")
                local file = fs.open(dataPath.. "/shaliases.json", "w")
                if file then
                    file:write(json.encode(alias)):close()
                end
            end
        }
    end
}

local osShell = shell.new()
osShell.setAlias("C:/bin")
os.execute = osShell.execute

-- Todo: reimplement io.popen using osShell