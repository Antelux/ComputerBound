local ty, pairs = type, pairs
local function copy(t, t2)
    if ty(t2) == "table" then
        for k, v in pairs(t2) do
            t[k] = ty(v) == "table" and copy(v) or v
        end
    end
    
    return t
end

-- Localizing because why not.
local iopen = io.open
local ipopen = io.popen
local ilines = io.lines
local itype = io.type

local oexecute = os.execute
local orename = os.rename
local oclock = os.clock
local odate = os.date
local odifftime = os.difftime
local otime = os.time

local tremove = table.remove
local tconcat = table.concat

local pcall = pcall

local OS -- (very) Basic OS detection.
if package.cpath:find(".dll") then
    OS = "Windows"
elseif package.cpath:find(".so") then
    OS = "Linux"
elseif package.cpath:find(".dylib") then
    OS = "Mac"
end

-- The BIOS implements the standard Lua environment, with some
-- parts of the libraries needing to be in a wrapper.
-- It cannot change and will be the same for all computers.
-- What can change, however, is the init.lua.
function newThread(env, RandomSource)
	-- I'll have to improve the sandboxing later.
    local _ENV = copy({
        -- Standard Lua Libraries
        math = copy(math),
        table = copy(table),
        string = copy(string),
        coroutine = copy(coroutine),

        -- Standard Lua Functions
        setmetatable = setmetatable,
        getmetatable = getmetatable,
        pairs = pairs,
        ipairs = ipairs,
        select = select,
        next = next,
        rawset = rawset,
        rawget = rawget,
        rawlen = rawlen,
        rawequal = rawequal,
        tostring = tostring,
        tonumber = tonumber,
        load = load,
        pcall = pcall,
        xpcall = xpcall,
        type = type,
        error = error,
        assert = assert,

        _VERSION = _VERSION
    }, env); _ENV._G = _ENV

    return coroutine.create(function()
        -- Woah, the super low level beep!
        function beep(amount, long)
            local amount = type(amount) == "number" and amount or 1
            system.playTone(4000, 1, long and 0.5 or 0.1)
            for i = 1, amount - 1 do
                local timer = system.startTimer(long and 1 or 0.25)
                repeat 
                    local sEvent, nTimer = coroutine.yield() 
                until sEvent == "timer" and nTimer == timer
                system.playTone(4000, 1, long and 0.5 or 0.1)
            end
        end

        -- Ensure there's an actual drive to boot from.
        if #components.storage.addresses == 0 then return beep(3) end
        local p = ipopen("cd"); local StorageDirectory = p:read(); p:close()
        StorageDirectory = StorageDirectory:match("[%w%s:\\%(%)%%]+[%W+]").."storage\\computers\\"

        local Storage = {}
        local function getStorage(sDirectory, noTable)
            if sDirectory then
                local dir = Storage
                for s in sDirectory:gmatch("([^\\]+)") do
                	if not dir[s] and noTable then return end
                    dir[s] = dir[s] or {}; dir = dir[s]
                end
                return dir
            end
        end

        -- Time to create a table containing all files and folders on the drive. Fun.
        local matchFriendly = StorageDirectory:gsub("%(", "%%("):gsub("%)", "%%)"):gsub("%-", "%%-")
        for i = 1, #components.storage.addresses do
            local Address = components.storage.addresses[i]
            local pFile = ipopen("cd " ..StorageDirectory..Address.. " & dir /s")
            
            local directory, i
            for sLine in pFile:lines() do
            	local dMatch = sLine:match(" Directory of " ..matchFriendly.. "(.+)")
            	if dMatch then directory, i = getStorage(dMatch), 1 end

                if directory then
                	local date = sLine:match("(%d%d/%d%d/%d%d%d%d)")
                	local time = sLine:match("(%d%d:%d%d [AP]M)")
                	local isDir = sLine:match("(<DIR>)")
                	local name = sLine:match("[%w.*]+$")
                    --local size = sLine:match("[%d,*]+$")

                    if time and date and name ~= "." and name ~= ".." and not isDir then
                        directory[i] = {name, date, time}; i = i + 1
                    end
                end
            end
            pFile:close()
        end

        -- And with that done, Windows users will no longer see a million command windows.
        local labels = {}
        local function isValidPath(sPath, relative)
            local sPath = ty(sPath) == "string" and sPath:gsub("/", "\\") or error("path must be a string, got a " ..ty(sPath).. " value", 2)
            local _ = sPath:find('[%*%"%<%>%|%%]') and error("path cannot have any of the following chars: *?\"<>|%%", 2)
            while sPath:sub(#sPath, #sPath) == "\\" do sPath = sPath:sub(1, #sPath - 1) end

            local nStart, nEnd = sPath:find("[%a]+:")
            if nStart == 1 then
                local label = labels[sPath:sub(1, nEnd - 1)]
                sPath = label and label..sPath:sub(nEnd + 1) or error('invalid storage label: "'..sPath:sub(1, nEnd - 1)..'"', 2)
            end

            local drive, max, i = "", #sPath, 1
            while i <= max and sPath:sub(i, i) ~= "\\" do
                drive = drive..sPath:sub(i, i); i = i + 1
                if i == max then
                    sPath = sPath.."\\"
                end
            end

            return Storage[drive] and (relative and sPath or StorageDirectory..sPath) or error('invalid storage drive: "'..drive..'"', 2)
        end

		local currentInputFile, currentOutputFile
		local gmt = getmetatable
        io = {
            -- The function io.stderr, io.stdin, io.stdout, io.popen, and io.tmpfile have not been implemented.
            -- Of course, all of these functions are possible to be implemented by any OS that runs on the computer.
            open = function(sFilename, sMode)
                local file = iopen(isValidPath(sFilename), sMode)
                if file then
	                if sMode:find("[wa%+]") then
	                	local fMetatable = gmt(file)
	                	local nativeClose = fMetatable.close
	                	local rPath = isValidPath(sFilename, true)

	                	fMetatable.close = function(self)
	                		nativeClose(self)
	                		local directory = getStorage(rPath:match("(.+)\\.+"), true)
                			local filename = rPath:match(".+\\(.+)")

                			for i = 1, #directory do
                				local file = directory[i]
                				if file[1] == filename then
                					file[2], file[3] = odate("%m/%d/%Y"), odate("%I:%M %p")
                					fMetatable.close = nativeClose; return
                				end
                			end
                			
                			directory[#directory + 1] = {filename, odate("%m/%d/%Y"), odate("%I:%M %p")}
                			fMetatable.close = nativeClose
	                	end
	                end
	                return file
	            end
            end,

            lines = function(sFilename)
                return ilines(isValidPath(sFilename))
            end,

            input = function(file)
                if ty(file) == "string" then
                    currentInputFile = iopen(isValidPath(file), "r")
                elseif itype(file) == "file" then
                    currentInputFile = file
                else
                    return currentInputFile
                end
            end,

            read = function(...)
                if currentInputFile then
                    return currentInputFile:read(...)
                end
            end,

            output = function(file)
                if ty(file) == "string" then
                    currentOutputFile = iopen(isValidPath(file), "w")
                elseif itype(file) == "file" then
                    currentOutputFile = file
                else
                    return currentOutputFile
                end
            end,

            write = function(...)
                if currentOutputFile then
                    return currentOutputFile:write(...)
                end
            end,

            flush = function()
                local _ = currentOutputFile and currentOutputFile:flush()
            end,

            type = itype,

            -- The following functions have been added to enhance this library.
            list = function(sPath)
            	local directory = getStorage(isValidPath(sPath, true), true)
            	if directory then
            		local tFiles, i = {}, 1
            		for k, v in pairs(directory) do
            			if ty(k) == "number" then
            				tFiles[i] = {name = v[1], isDir = false, time = v[3], date = v[2]} -- size = v.size}
            			else
            				tFiles[i] = {name = k, isDir = true}
            			end
            			i = i + 1
            		end
            		return tFiles
            	end
            end,

            exists = function(sPath)
                local ok, sPath = pcall(isValidPath, sPath, true)
                if not ok then return end

                local directory = getStorage(sPath, true)
                if directory then return "dir" end

                local filename = sPath:match(".+\\(.+)")
                directory = getStorage(sPath:sub(1, #sPath - #filename), true)

                if directory then
                	for i = 1, #directory do
                		if directory[i][1] == filename then
                			return "file"
                		end
                	end
                end
            end,

            makeDir = function(sPath)
            	local sPath = isValidPath(sPath, true)
                local directory = sPath:match("(.+)\\.+")
                local dirname = sPath:match(".+\\(.+)")

                local success = oexecute("cd " ..StorageDirectory..directory.. " & mkdir " ..dirname)
                return success and getStorage(sPath) and true
            end,

            setLabel = function(drive, label)
                if ty(drive) ~= "string" then error("drive must be a string, got a " ..ty(drive).. " value", 2) end
                if not Storage[drive] then error('invalid drive: "'..drive..'"', 2) end
                if ty(label) ~= "string" then error("label must be a string, got a " ..ty(label).. " value", 2) end
                if label:find("%A") then error("label can only contain chars [A-Z][a-z]", 2) end
                labels[label] = drive
            end,

            getLabels = function()
                local tLabels = {}
                for k, v in pairs(labels) do
                    tLabels[k] = v
                end
                return tLabels
            end
        }

        function loadfile(sFile, tEnv, ...)
            local tEnv = tEnv or {}
            local fFile = io.open( sFile, "r" )

            if fFile then
                local ok, err = load(fFile:read("a"), sFile, "t", tEnv)
                fFile:close(); return ok, err
            end
            return nil, "File not found"
        end

        function dofile(sFile, ...)
            local fnFile, err = loadfile( sFile, _ENV, ... )
            if err then return nil, err end
            return pcall(fnFile, ...)
        end

        package = {
            loaded = {},
            preload = setmetatable({}, {__newindex = function(t, k, v)
                if type(v) ~= "function" then error("loader must be a function, got a " ..type(v).. " value", 2) end; t[k] = v
            end})

            -- The functions package.config, package.cpath, package.path, package.searchpath,
            -- package.searchers and package.loadlib, have not been implemented.
        }

        function require(sFile)
            if ty(sFile) ~= "string" then error("filename must be a string, got a " ..ty(sFile).. " value", 2) end
            if io.exists(sFile) ~= "file" then error('no such file "' ..sFile.. '"', 2) end
            package.loaded[sFile], e = package.loaded[sFile] or ((package.preload[sFile] and (package.preload[sFile](sFile) or true)) or dofile(sFile) or true)
            if not package.loaded[sFile] and e then error(e) end; return package.loaded[sFile]
        end

        local startTime = oclock()
        local rem = table.remove
        os = {
            -- The functions os.getenv, os.setlocale, os.execute, os.exit, and os.tmpname have not been implemented.
            -- Of course, all of these functions are possible to be implemented by any OS that runs on the computer.
            date = odate, difftime = odifftime, time = otime,

            clock = function()
                return oclock() - startTime
            end,

            -- Would be great if I could use the real os.remove() instead of os.execute() to emulate it.
            remove = function(sPath)
                local sType = io.exists(sPath)
                if sType == "dir" then
                    local sPath = isValidPath(sPath, true)
                	local directory = sPath:match("(.+)\\.+")
                	local dirname = sPath:match(".+\\(.+)")

                	local success = oexecute("cd " ..StorageDirectory..directory.. " & rmdir " ..dirname.. " /s /q")
                    if success then
                    	directory = getStorage(directory)
                    	directory[dirname] = nil
                    	return true
                    end

                elseif sType == "file" then
                	local sPath = isValidPath(sPath, true)
                	local directory = sPath:match("(.+)\\.+")
                	local filename = sPath:match(".+\\(.+)")

                	local success = oexecute("cd " ..StorageDirectory..directory.. " & del " ..filename.. " /q")
                    if success then
                    	directory = getStorage(directory)
                    	for i = 1, #directory do
                    		if directory[i][1] == filename then
                    			rem(directory, i); break
                    		end
                    	end
                
                    	return true
                    end

                else
                    return true
                end
            end,

            rename = function(sPath1, sPath2)
                local sType, ok, err = io.exists(sPath1)
                if sType then
                	ok, err = orename(isValidPath(sPath1), isValidPath(sPath2))
                	if ok then
                		sPath1 = isValidPath(sPath1, true)
                		sPath2 = isValidPath(sPath2, true)

	                	local dir1 = getStorage(sPath1:match("(.+)\\.+"))
	                	local dir2 = getStorage(sPath2:match("(.+)\\.+"))
	                	local name = sPath1:match(".+\\(.+)")

	                	if sType == "dir" then
	                		dir2[sPath2:match(".+\\(.+)")] = dir1[name]; dir1[name] = nil

	                	elseif sType == "file" then
	                		for i = 1, #dir1 do
	                			if dir1[i][1] == name then
	                				local file = rem(dir1, i)
	                				file[1] = sPath2:match(".+\\(.+)")
	                				dir2[#dir2 + 1] = file; break
	                			end
	                		end
	                	end
	                end
                end
                return ok, err or (not ok and "No such file or directory" or nil)
            end
        }

        function math.randomseed(nSeed)
            RandomSource:init(ty(nSeed) == "number" and nSeed or error("seed must be a number, got a " ..ty(nSeed).. " value", 2))
        end

        function math.random(nMin, nMax)
            local min = nMin and (ty(nMin) == "number" or error("minimum value must be a number, got a " ..ty(nMin).. " value", 2))
            local max = nMax and (ty(nMax) == "number" or error("minimum value must be a number, got a " ..ty(nMax).. " value", 2))
            
            if max and min then return (nMax - nMin + 1) * RandomSource:randf() // 1 + nMin
            elseif min then return nMin * RandomSource:randf() // 1 + 1
            else return RandomSource:randf() end
        end

        -- This will search for a init.lua, first from the storage
        -- devices, then from any disks that are in the computer.
        local sBootLocation
        for i = 1, #components.storage.addresses do
            local address = components.storage.addresses[i]
            if io.exists(address.."/init.lua") == "file" then
                sBootLocation = address.."/init.lua"; break
            end
        end

        if not sBootLocation then return beep(3, true) end
        while true do coroutine.yield() end
        local ok, err = dofile(sBootLocation)
        if not ok then error(err); beep(2, true) end
    end)
end