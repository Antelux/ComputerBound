-- This architecure implements the standard Lua 5.3 environment,
-- with some parts of the libraries needing to be in a wrapper.
-- Other parts are disabled, be it partially or altogether due
-- to the lack of specific functionality or security reasons.

--[[
    
    To do:
    
    * Finish up io.* library.
    * Finish up require()
    * Finish up loadfile()
    * Add more error/argument type checking.

--]]

require "/lua/api/cconfig.lua"

--[[
local oslocale = {collate = "C", ctype = "C", monetary = "C", numeric = "C", time = "C", all = "C"}
setlocale = function(locale, category)
    if category and type(category) ~= "string" then
        return
    end

    category = category or "all"

    if type(locale) ~= "string" then
        return oslocale[category]

    else
        if category ~= "all" then
            if oslocale[category] then
                oslocale[category] = locale
            end
        else
            oslocale.collate = locale
            oslocale.ctype = locale
            oslocale.monetary = locale
            oslocale.numeric = locale
            oslocale.time = locale
            oslocale.all = locale
        end
    end
end,
--]]

local DefaultInputFile, DefaultOutputFile
local RandomSource
local ComputerStartTime
local OS_ENV

----------------------------------------------------------------------------------------------------
-- archEnvironment is called only once upon initiation of the CPU component.
----------------------------------------------------------------------------------------------------

local type, pairs = type, pairs
local function copy(t)
    local newtable = {}
    if type(t) == "table" then
        for key, value in pairs(t) do
            newtable[key] = type(value) == "table" and copy(value) or value
        end
    end
    
    return newtable
end

function archEnvironment(ComputerAPI)

    local coroutine = coroutine
    local math = math
    local string = string
    local table = table
    local utf8 = utf8
    local io = io
    local os = os

    local copy = copy
    local type = type

    -- The function load is reimplemented as to prevent the loading of binary chunks.
    local arch_load
    if cconfig.get("architectures/Lua53.binaryChunksEnabled") then
        arch_load = load
    else
        arch_load = function(code, chunkname, mode, env)
            if type(mode) == "string" and mode:find("b") then
                error("attempt to load a binary chunk", 2)
            end
            return load(code, chunkname, mode, env)
        end
    end

    -- The getmetatable function is reimplemented to prevent messing with metatables that are
    -- global, i.e. string. While normally I wouldn't mind one doing so, it unfortunately affects
    -- all Lua instances, not just the current one. A work around can be made, but it's honestly
    -- more trouble than it's worth.
    local function arch_getmetatable(object)
        return type(object) == "table" and getmetatable(object)
    end





    -- Functions belonging to math.* --
    local function arch_math_randomseed(seed)
        RandomSource:init(type(seed) == "number" and seed or error("seed must be a number, got a " ..type(seed).. " value", 2))
    end

    local function arch_math_random(min, max)
        min = min and (type(min) == "number" and min or error("minimum value must be a number, got a " ..type(min).. " value", 2))
        max = max and (type(max) == "number" and max or error("maximum value must be a number, got a " ..type(max).. " value", 2))

        if max and min then
            return (RandomSource:randf(min, max) + 0.5) // 1
        elseif min then
            return (RandomSource:randf(1, min) + 0.5) // 1
        else 
            return RandomSource:randf() 
        end
    end





    -- Functions belonging to os.* --
    local function arch_os_remove(item)
        local drivename, path = item:match("^/(.-)(/.+)$")
        local drive = ComputerAPI.Component.wrap(drivename)

        if drive then
            local ok, err = drive.delete(path)
            if ok then
                local eventData
                repeat
                    eventData = coroutine.yield()
                until eventData and (eventData[1] == "storage_delete" and eventData[2] == drivename)

                return eventData[3]
            else
                return false, err
            end
        end
    end

    local function arch_os_rename(item1, item2)
        local drivename, path = item:match("^/(.-)(/.+)$")
        local drive = ComputerAPI.Component.wrap(drivename)

        if drive then
            local ok, err = drive.move(path)
            if ok then
                local eventData
                repeat
                    eventData = coroutine.yield()
                until eventData and (eventData[1] == "storage_move" and eventData[2] == drivename)

                return eventData[3]
            else
                return false, err
            end
        end
    end

    local function arch_os_list(folder)
        local drivename, path = folder:match("^/(.-)(/.+)$")
        local drive = ComputerAPI.Component.wrap(drivename)

        if drive then
            local ok, err = drive.list(path)
            if ok then
                local eventData
                repeat
                    eventData = coroutine.yield()
                until eventData and (eventData[1] == "storage_list" and eventData[2] == drivename)

                return eventData[3]
            else
                return false, err
            end
        end
    end

    local function arch_os_exists(item)
        local drivename, path = item:match("^/(.-)(/.+)$")
        local drive = ComputerAPI.Component.wrap(drivename)

        if drive then
            local ok, err = drive.exists(path)
            if ok then
                local eventData
                repeat
                    eventData = coroutine.yield()
                until eventData and (eventData[1] == "storage_exists" and eventData[2] == drivename)

                return eventData[3]
            else
                return false, err
            end
        end
    end

    local function arch_os_exit(code)
        error(type(code) == "number" and code or 0)
    end

    local function arch_os_size(item)
        local drivename, path = item:match("^/(.-)(/.+)$")
        local drive = ComputerAPI.Component.wrap(drivename)

        if drive then
            local ok, err = drive.size(path)
            if ok then
                local eventData
                repeat
                    eventData = coroutine.yield()
                until eventData and (eventData[1] == "storage_size" and eventData[2] == drivename)

                return eventData[3]
            else
                return false, err
            end
        end
    end

    local function arch_os_makedir(folder)
        local drivename, path = folder:match("^/(.-)(/.+)$")
        local drive = ComputerAPI.Component.wrap(drivename)

        if drive then
            local ok, err = drive.makedir(path)
            if ok then
                local eventData
                repeat
                    eventData = coroutine.yield()
                until eventData and (eventData[1] == "storage_size" and eventData[2] == drivename)

                return eventData[3]
            else
                return false, err
            end
        end
    end

    local oclock = os.clock
    local function arch_os_clock()
        return oclock() - ComputerStartTime
    end

    local function arch_os_date()

    end

    local function arch_os_getenv(varname)
        if type(varname) == "string" then
            return OS_ENV[varname]
        else
            error("varname must be a string, got a " ..type(varname).. " value", 2)
        end
    end

    local function arch_os_setenv(varname, data)
        if type(varname) == "string" then
            OS_ENV[varname] = data
        else
            error("varname must be a string, got a " ..type(varname).. " value", 2)
        end
    end





    -- Functions belonging io.* --
    local ecwrap = ComputerAPI.Component.wrap

    local function setPath(drive, drivename, path)
        local ok, err = drive.set(path)
        if ok then
            local eventData
            repeat
                eventData = coroutine.yield()
            until eventData and eventData[1] == "storage_set" and eventData[2] == drivename

            return eventData[3], eventData[4]
        else
            error("unable to set path for '" .. tostring(drivename) .. "'; " .. tostring(err))
        end
    end

    local __FileTag = function() end
    local function arch_io_type(file)
        if type(file) == "table" then
            return 
                file.__tag == __FileTag and
                (file.__isOpen and "file" or "closed file") or nil
        end
    end

    local function arch_io_open(filename, mode)
        local drivename, path = filename:match("^/(.-)(/.+)$")
        local drive = ecwrap(drivename)
        local mode = mode or "r"; path = path or "/"

        if drive then
            local Buffer, Index = {}, 0
            local BufferSize = 0
            local MaxBufferSize = 2048
            local BufferMode = "full"

            local File = {
                __isOpen = true,
                __tag = __FileTag,
            }

            local FileMetatable = {
                close = function(File)
                    if File.flush then
                        File:flush()
                    end
                    File.__isOpen = nil
                end,

                seek = function(File, whence, offset)

                end
            }

            if mode == "r" then
                function FileMetatable.lines(File)

                end

                function FileMetatable.read(File, ...)
                    local formats = {...}
                    formats[1] = formats[1] or "l"
                    setPath(drive, drivename, path)

                    for i = 1, #formats do
                        local f = formats[i]

                        if type(f) == "number" then

                        elseif f == "n" then

                        elseif f == "a" then
                            local ok, err = drive.read(-1)
                            if ok then
                                local eventData
                                repeat
                                    eventData = coroutine.yield()
                                until eventData and (eventData[1] == "storage_read" and eventData[2] == drivename)

                                return eventData[3]
                            else
                                error("unable to read; " .. tostring(err))
                            end

                        elseif f == "l" then

                        elseif f == "L" then

                        else
                            error("invalid read format '" .. tostring(f) .. "'")
                        end
                    end
                end

            elseif mode == "w" then
                function FileMetatable.write(File, ...)
                    local data = {...}
                    local tostring = tostring
                    local Buffer = Buffer

                    if BufferMode == "no" then
                        setPath(drive, drivename, path)
                        
                        for i = 1, #data do
                            local ok, err = drive.write(tostring(data[i]))
                            if ok then
                                local eventData
                                repeat
                                    eventData = coroutine.yield()
                                until eventData and (eventData[1] == "storage_write" and eventData[2] == drivename)

                                return eventData[3]
                            else
                                error("unable to write; " .. tostring(err))
                            end
                        end

                    elseif BufferMode == "full" then
                        for i = 1, #data do
                            local data_string = tostring(data[i])

                            Index = Index + 1; Buffer[Index] = data_string
                            BufferSize = BufferSize + #data_string

                            if BufferSize > MaxBufferSize then
                                File:flush()
                            end
                        end

                    else -- "line"
                        local sfind = string.find
                        for i = 1, #data do
                            local data_string = tostring(data[i])

                            Index = Index + 1; Buffer[Index] = data_string
                            BufferSize = BufferSize + #data_string

                            if (BufferSize > MaxBufferSize) or sfind(data_string, "\n") then
                                File:flush()
                            end
                        end
                    end
                end

                local AvailableModes = {no = true, full = true, line = true}
                function FileMetatable.setvbuf(File, mode, size)
                    if arch_io_type(File) == "file" then
                        if mode and not AvailableModes[mode] then error("invalid buffer mode", 2) end
                        if size and (type(size) ~= "number" or size < 0) then error("positive number expected for buffer size", 2) end

                        BufferMode = mode or BufferMode
                        MaxBufferSize = size or MaxBufferSize
                    else
                        error("file expected", 2)
                    end
                end

                function FileMetatable.flush(File)
                    setPath(drive, drivename, path)
                    local Buffer = Buffer
                    for i = 1, Index do
                        local ok, err = drive.write(Buffer[i])
                        if ok then
                            local eventData
                            repeat
                                eventData = coroutine.yield()
                            until eventData and (eventData[1] == "storage_write" and eventData[2] == drivename)

                            return eventData[3]
                        else
                            error("unable to write; " .. tostring(err))
                        end

                        Buffer[i] = nil
                    end
                    Index = 0
                    BufferSize = 0
                end
            end

            return setmetatable(File, {__index = FileMetatable})
        else
            error("invalid drive: " .. tostring(drivename))
        end
    end

    local function arch_io_close(file)
        if arch_io_type(file) == "file" then
            file:close()
        else
            local _ = DefaultOutputFile and DefaultOutputFile:close()
        end
    end

    local function arch_io_lines(filename, ...)
        if type(filename) == "string" then
            local drivename, path = filename:match("^/(.-)(/.+)$")
            local drive = ecwrap(drivename)
            
            if drive then
                return function()
                    local ok, err = setPath(drive, drivename, path)
                    if ok then
                        local ok, err = drive.read("l")
                        if ok then
                            local eventData
                            repeat
                                eventData = coroutine.yield()
                            until eventData and (eventData[1] == "storage_read" and eventData[2] == drivename)

                            return eventData[3]
                        else
                            error("unable to read; " .. tostring(err))
                        end
                    else
                        error("unable to set path; " .. tostring(err))
                    end
                end
            else
                error("invalid drive: " .. tostring(drivename))
            end
        else
            return DefaultInputFile and DefaultInputFile:lines("*l")
        end
    end

    local function arch_io_input(file)
        if type(file) == "string" then
            --DefaultInputFile = io.open(prepare(file), "r")

        elseif arch_io_type(file) == "file" then
            DefaultInputFile = file

        else
            return DefaultInputFile
        end
    end

    local function arch_io_read(...)
        if DefaultInputFile then
            return DefaultInputFile:read(...)
        end
    end

    local function arch_io_output(file)
        if type(file) == "string" then
            --DefaultOutputFile = io.open(prepare(file), "w")

        elseif arch_io_type(file) == "file" then
            DefaultOutputFile = file

        else
            return DefaultOutputFile
        end
    end

    local function arch_io_write(...)
        if DefaultOutputFile then
            return DefaultOutputFile:write(...)
        end
    end

    local function arch_io_flush()
        local _ = DefaultOutputFile and DefaultOutputFile:flush()
    end





    -- Functions relating specifically to compiling Lua --
    local function arch_loadfile(file, mode, env)
        if file then
            local code = arch_io_open(file, "r")
            if code then
                local ok, err = arch_load(code:read("a"), file, mode, env or {})
                code:close(); return ok, err
            end
            return nil, "File not found"
        else
            -- load standard input
        end
    end





    -- Visual Input/Output Functions -- 
    local tostring = tostring
    local cnof = ComputerAPI.Node.output.find
    local cnoi = ComputerAPI.Node.output.invoke
    local cyield = coroutine.yield
    local ssub = string.sub

    local function arch_print(...)
        local Terminal = cnof("terminal")

        if Terminal then
            local tostr = tostring
            local values = {...}

            for i = 1, #values do
                cnoi(Terminal, "writef", tostr(values[i]))
            end

            cnoi(Terminal, "writef", "\n")
        end
    end

    local function arch_io_stdout(value)
        local Terminal = cnof("terminal")

        if Terminal then
            cnoi(Terminal, "writef", value)
        end
    end

    local function arch_io_stdin()
        local Terminal; repeat
            Terminal = cnof("terminal")
            if not Terminal then
                cyield()
            end
        until Terminal

        local ssub = ssub
        local Keys = temp_keys

        local line, pos = "", 0
        local resolution = cnoi(Terminal, "getResolution")
        local position = cnoi(Terminal, "getCursorPosition")

        local width, height = resolution[1], resolution[2]
        local x, y = position[1], position[2]

        local function redraw()
            if y < 0 or y > height - 1 then return end

            cnoi(Terminal, "writef", line, x, y)
            cnoi(Terminal, "setCursorPosition", x + pos, y)
        end

        local isShifting
        while true do
            local int
            repeat
                int = cyield()
            until int and int[1] == "char"
            local char = int[2]

            if #char == 1 then
                line = ssub( line, 1, pos ) .. char .. ssub( line, pos + 1 )
                pos = pos + 1; redraw()

            elseif char == "\01\03" then -- Enter
                return line
                
            elseif char == "\01\90" then -- Left
                if pos > 0 then
                    pos = pos - 1
                    redraw()
                end
                
            elseif char == "\01\89" then -- Right
                if pos < #line then
                    pos = pos + 1
                    redraw()
                end

            elseif char == "\01\01" then -- Backspace
                if pos > 0 then
                    line = ssub( line, 1, pos - 1 ) .. ssub( line, pos + 1 )
                    pos = pos - 1; redraw()
                end

            elseif char == "\01\69" then -- Delete
                if pos < #line then
                    line = ssub( line, 1, pos ) .. ssub( line, pos + 2 )                
                    redraw()
                end
            end
        end
    end

    local function arch_io_stderr(err)
        local Terminal = cnof("terminal")

        if Terminal then
            cnoi(Terminal, "setInverted", true)
            cnoi(Terminal, "writef", tostring(err))
            cnoi(Terminal, "setInverted", false)
        end
    end





    -- Return the Lua 5.3 Architecture --
    return {

        -- Lua 5.3 Libraries --
        coroutine = {
            create = coroutine.create,
            isyieldable = coroutine.isyieldable,
            resume = coroutine.resume,
            running = coroutine.running,
            status = coroutine.status,
            wrap = coroutine.wrap,
            yield = coroutine.yield
        },
        debug = cconfig.get("architectures/Lua53.debugLibraryEnabled") and
        {
            --debug
            --gethook
            --getinfo
            --getlocal
            --getmetatable
            --getregistry
            --getupvalue
            --getuservalue
            --sethook
            --setlocal
            --setmetatable
            --setupvalue
            --setuservalue
            --traceback
            --upvalueid
            --upvaluejoin
        },
        io = {
            close = arch_io_close,
            flush  = arch_io_flush,
            input  = arch_io_input,
            lines = arch_io_lines,
            open = arch_io_open,
            output = arch_io_output,
            -- popen                    (not implemented)
            read  = arch_io_read,
            stderr = arch_io_stderr,
            stdin = arch_io_stdin,
            stdout = arch_io_stdout,
            -- tmpfile                  (not implemented)
            type  = arch_io_type,
            write = arch_io_write
        },
        math = {
            abs = math.abs,
            acos = math.acos,
            asin = math.asin,
            atan = math.atan,
            ceil = math.ceil,
            cos = math.cos,
            deg = math.deg,
            exp = math.exp,
            floor = math.floor,
            fmod = math.fmod,
            huge = math.huge,
            log = math.log,
            max = math.max,
            maxinteger = math.maxinteger,
            min = math.min,
            mininteger = math.mininteger,
            modf = math.modf,
            pi = math.pi,
            rad = math.rad,
            random = arch_math_random,
            randomseed = arch_math_randomseed,
            sin = math.sin,
            sqrt = math.sqrt,
            tan = math.tan,
            tointeger = math.tointeger,
            type = math.type,
            ult = math.ult
        },
        os = {
            clock = arch_os_clock,
            date = arch_os_date,
            difftime = os.difftime,
            -- execute                  (not implemented)
            exists = arch_os_exists,
            exit = arch_os_exit,
            getenv = arch_os_getenv,
            list = arch_os_list,
            makedir = arch_os_makedir,
            remove = arch_os_remove,
            rename = arch_os_rename,
            setenv = arch_os_setenv, -- (added)
            -- setlocale                (not implemented)
            size = arch_os_size,
            time = os.time
            -- tmpname                  (not implemented)
        },
        package = {
            config = "/\n;\n?\n!\n-\n",
            -- cpath                    (not implemented)
            loaded = {},
            -- loadlib                  (not implemented)
            path = ""
            -- preload                  (runtime)
            -- searchers                (not implemented)
            -- searchpath               (not implemented)
        },
        string = {
            byte = string.byte,
            char = string.char,
            dump = string.dump,
            find = string.find,
            format = string.format,
            gmatch = string.gmatch,
            gsub = string.gsub,
            len = string.len,
            lower = string.lower,
            match = string.match,
            pack = string.pack,
            packsize = string.packsize,
            rep = string.rep,
            reverse = string.reverse,
            sub = string.sub,
            unpack = string.unpack,
            upper = string.upper
        },
        table = {
            concat = table.concat,
            insert = table.insert,
            move = table.move,
            pack = table.pack,
            remove = table.remove,
            sort = table.sort,
            unpack = table.unpack
        },
        utf8 = {
            char = utf8.char,
            charpattern = utf8.charpattern,
            codepoint = utf8.codepoint,
            codes = utf8.codes,
            len = utf8.len,
            offset = utf8.offset
        },
        
        -- Standard Lua Functions --
        assert = assert,
        -- collectgarbage                   (not implemented)
        -- dofile                           (runtime)
        error = error, 
        getmetatable = arch_getmetatable,
        ipairs = ipairs,
        load = arch_load,
        loadfile = arch_loadfile,
        next = next,
        pairs = pairs,
        pcall = pcall,
        print = arch_print,
        rawequal = rawequal,
        rawget = rawget,
        rawlen = rawlen,
        rawset = rawset,
        require = arch_require,
        select = select,
        setmetatable = setmetatable, 
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        xpcall = xpcall,
        
        -- Lua 5.3 Constants --
        _VERSION = _VERSION,

        -- ComputerBound Libraries --
        system = copy(ComputerAPI.System),
        node = copy(ComputerAPI.Node),
        component = copy(ComputerAPI.Component),

        -- ComputerBound Constants --
        _CBVERSION = ComputerAPI.Version
    }
end

----------------------------------------------------------------------------------------------------
-- archRuntime is called every time the computer is turned on, meaning this is the code
-- that runs exactly before any user defined operating systems / programs.
----------------------------------------------------------------------------------------------------

function archRuntime(Environment)
    -- Initializing a couple of parameters
    RandomSource = sb.makeRandomSource(os.time() * 1000)
    DefaultInputFile, DefaultOutputFile = nil, nil
    ComputerStartTime = os.clock(); OS_ENV = {}

    -- Computers will have an internal clock for the date.
    -- To users, it will appear to increment by one every second
    -- and continue to do so even after the computer has turned off.
    -- In reality, this will be achieved:
    --      when in use: return date + (oclock() - startTime)
    --      when off: date = date + (oclock() - savedClock)
    --
    -- The date will represent the amount of time that has passed
    -- since the computer was first created.
    -- 
    -- There will be a function to set the clock manually.

    Environment.package.preload = setmetatable({}, {__newindex = function(t, k, v)
        if type(v) ~= "function" then error("loader must be a function, got a " ..type(v).. " value", 2) end; t[k] = v
    end})

    local aloadfile = Environment.loadfile
    function Environment.dofile(file, ...)
        local func, err = aloadfile(file, "t", Environment)
        if func then
            return func(...)
        else
            error(err)
        end
    end

    --
    --       REMEMBER TO IMPLEMENT THE . USAGE!!!!!!
    --
    local edofile = Environment.dofile
    local aoexists = Environment.os.exists
    local apackage = Environment.package
    function Environment.require(modname)
        if type(modname) ~= "string" then 
            error("module name must be a string, got a " ..type(modname).. " value", 2) 
        end
        
        if apackage.loaded[modname] then
            return apackage.loaded[modname]
        
        else
            if apackage.preload[modname] then
                apackage.loaded[modname] = apackage.preload[modname](modname)

            else
                local pconfig = apackage.config
                local ppath = apackage.path
                local err = "no field package.preload['" .. modname .. "']\n"

                local sgsub = string.gsub
                local sfind = string.find
                local ssub = string.sub

                if type(pconfig) ~= "string" then
                    error("package.config must be a string, got a " .. type(pconfig) .. " value", 2)
                end

                if type(ppath) ~= "string" then
                    error("package.path must be a string, got a " .. type(ppath) .. " value", 2)
                end

                local s1, e1 = sfind(pconfig, ".\n")
                if not e1 then error("package.config must define a directory seperator.", 2) end
                local s2, e2 = sfind(pconfig, ".\n", e1)
                if not e2 then error("package.config must define a template seperator.", 2) end
                local s3, e3 = sfind(pconfig, ".\n", e2)
                if not e3 then error("package.config must define a substitution pointer.", 2) end
                -- Currently, the "!" (executable's directory) and "-" (ignore marker) symbols aren't supported.

                local dir_sepr = ssub(pconfig, s1, e1 - 1)
                local template_sepr = ssub(pconfig, s2, e2 - 1)
                local sub_point = ssub(pconfig, s3, e3 - 1)
                local filename = modname .. ".lua"

                local spath, epath = sfind(ppath, "(.-);")
                
                if not spath then
                    error("module '" .. modname .. "' not found:\n" .. err .. "package.path has no valid paths to search\n")
                end

                while spath do
                    local path = ssub(ppath, spath, epath-1)
                    local filepath = sgsub(path, sub_point, filename)
                    if aoexists(filepath) == "file" then
                        local result = edofile(filepath, filepath) or true
                        apackage.loaded[modname] = result
                        return result
                    end

                    err = err .. "no file '" .. filepath .. "'\n"
                    spath, epath = sfind(ppath, "(.-);", epath + 1)
                end
                error("module '" .. modname .. "' not found:\n" .. err, 2)
            end
        end
    end
    
    -- And, of course, implement _G.
    Environment._G = Environment

    -- This is essentially the "BIOS" for this architecture.
    local _ENV = Environment
    return function()

        -- Woah, the super low level beep!
        function beep(amount, long)
            local amount = type(amount) == "number" and amount or 1

            for i = 1, amount do
                system.playTone(4000, 1, long and 0.5 or 0.1)

                local delay = long and 1 or 0.25
                local start = os.clock()
                repeat
                    coroutine.yield() 
                until os.clock() - start >= delay
            end
        end

        -- Ensure there's an actual drive to boot from.
        if not component.find("storage") then 
            beep(3); error("no drives are present to boot from!") 
        end

        -- This will search for an init.lua, first from the storage
        -- devices, then from any disks that are in the computer.
        for _, address in ipairs(component.findAll("storage")) do
            if os.exists("/" .. address .. "/init.lua") == "file" then
                local ok, err = dofile("/" .. address .. "/init.lua", address)
                if not ok then beep(2, true); error(err) end

                goto Execution_Complete
            end
        end

        beep(3, true)
        error("Unable to locate /init.lua on any connected storage medium!")

        :: Execution_Complete ::
        error("Computer has completed program execution.")
    end
end