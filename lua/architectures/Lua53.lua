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

----------------------------------------------------------------------------------------------------
-- This is very much temporary
----------------------------------------------------------------------------------------------------

local temp_keys = {
    [05] = " ",

    [11] = "'",
    [16] = ",",
    [17] = "-",
    [18] = ".",
    [19] = "/",

    [20] = "0",
    [21] = "1",
    [22] = "2",
    [23] = "3",
    [24] = "4",
    [25] = "5",
    [26] = "6",
    [27] = "7",
    [28] = "8",
    [29] = "9",

    [31] = ";",
    [33] = "=",
    [37] = "[",
    [38] = "\\",
    [39] = "]",
    [42] = "`",

    [43] = "a",
    [44] = "b",
    [45] = "c",
    [46] = "d",
    [47] = "e",
    [48] = "f",
    [49] = "g",
    [50] = "h",
    [51] = "i",
    [52] = "j",
    [53] = "k",
    [54] = "l",
    [55] = "m",
    [56] = "n",
    [57] = "o",
    [58] = "p",
    [59] = "q",
    [60] = "r",
    [61] = "s",
    [62] = "t",
    [63] = "u",
    [64] = "v",
    [65] = "w",
    [66] = "x",
    [67] = "y",
    [68] = "z",

    [70] = "0",
    [71] = "1",
    [72] = "2",
    [73] = "3",
    [74] = "4",
    [75] = "5",
    [76] = "6",
    [77] = "7",
    [78] = "8",
    [79] = "9",

    [80] = ".",
    [81] = "/",
    [82] = "*",
    [83] = "-",
    [84] = "+",

    [205] = " ",

    [211] = '"',
    [216] = "<",
    [217] = "_",
    [218] = ">",
    [219] = "?",

    [220] = ")",
    [221] = "!",
    [222] = "@",
    [223] = "#",
    [224] = "$",
    [225] = "%",
    [226] = "^",
    [227] = "&",
    [228] = "*",
    [229] = "(",

    [231] = ":",
    [233] = "+",
    [237] = "{",
    [238] = "|",
    [239] = "}",
    [242] = "~",

    [243] = "A",
    [244] = "B",
    [245] = "C",
    [246] = "D",
    [247] = "E",
    [248] = "F",
    [249] = "G",
    [250] = "H",
    [251] = "I",
    [252] = "J",
    [253] = "K",
    [254] = "L",
    [255] = "M",
    [256] = "N",
    [257] = "O",
    [258] = "P",
    [259] = "Q",
    [260] = "R",
    [261] = "S",
    [262] = "T",
    [263] = "U",
    [264] = "V",
    [265] = "W",
    [266] = "X",
    [267] = "Y",
    [268] = "Z"
}

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
            return load(code, chunkname, mode, env or Architecture)
        end
    end

    -- The getmetatable function is reimplemented to prevent messing with metatables that are
    -- global, i.e. string. While normally I wouldn't mind one doing so, it unfortunately affects
    -- all Lua instances, not just the current one. A work around can be made, but it's honestly
    -- more trouble than it's worth.
    local function arch_getmetatable(object)
        return type(object) == "table" and getmetatable(object)
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
            until int and int[1]:find("key_")

            local event = int[1]
            local key = int[2]
            local isDown = int[3]

            if key == 115 then
                isShifting = event ~= "key_release"
            end

            local k = not isShifting and key or key + 200

            if event == "key_press" then
                if Keys[k] then
                    line = ssub( line, 1, pos ) .. Keys[k] .. ssub( line, pos + 1 )
                    pos = pos + 1; redraw()

                elseif key == 3 then -- Enter
                    return line
                    
                elseif key == 90 then -- Left
                    if pos > 0 then
                        pos = pos - 1
                        redraw()
                    end
                    
                elseif key == 89 then -- Right
                    if pos < #line then
                        pos = pos + 1
                        redraw()
                    end

                elseif key == 0 then -- Backspace
                    if pos > 0 then
                        line = ssub( line, 1, pos - 1 ) .. ssub( line, pos + 1 )
                        pos = pos - 1; redraw()
                    end

                elseif key == 69 then -- Delete
                    if pos < #line then
                        line = ssub( line, 1, pos ) .. ssub( line, pos + 2 )                
                        redraw()
                    end
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
            -- close                    (runtime)
            -- flush                    (runtime)
            -- input                    (runtime)
            -- lines                    (runtime)
            -- open                     (runtime)
            -- output                   (runtime)
            -- popen                    (not implemented)
            -- read                     (runtime)
            stderr = arch_io_stderr,
            stdin = arch_io_stdin,
            stdout = arch_io_stdout
            -- tmpfile                  (not implemented)
            -- type                     (runtime)
            -- write                    (runtime)
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
            sin = math.sin,
            sqrt = math.sqrt,
            tan = math.tan,
            tointeger = math.tointeger,
            type = math.type,
            ult = math.ult
        },
        os = {
            -- clock                    (runtime)
            -- date                     (runtime)
            difftime = os.difftime,
            -- execute                  (not implemented)
            exists = arch_os_exists,
            exit = arch_os_exit,
            -- getenv                   (runtime)
            list = arch_os_list,
            makedir = arch_os_makedir,
            remove = arch_os_remove,
            rename = arch_os_rename,
            -- setenv                   (runtime - added)
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
        -- loadfile                         (runtime)
        next = next,
        pairs = pairs,
        pcall = pcall,
        print = arch_print,
        rawequal = rawequal,
        rawget = rawget,
        rawlen = rawlen,
        rawset = rawset,
        -- require                          (runtime)
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
    -- The following math functions are reimplemented so they're not shared across all computers.
    local RandomSource = sb.makeRandomSource(os.time() * 1000)

    function Environment.math.randomseed(seed)
        RandomSource:init(type(seed) == "number" and seed or error("seed must be a number, got a " ..type(seed).. " value", 2))
    end

    function Environment.math.random(min, max)
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

    Environment.package.preload = setmetatable({}, {__newindex = function(t, k, v)
        if type(v) ~= "function" then error("loader must be a function, got a " ..type(v).. " value", 2) end; t[k] = v
    end})

    -- os.clock is reimplemented to use the time relative to when the thread was created.
    local oclock = os.clock
    local startTime = oclock()

    local osenv = {}

    function Environment.os.clock()
        return oclock() - startTime
    end

    function Environment.os.date()

    end

    function Environment.os.getenv(varname)
        if type(varname) == "string" then
            return osenv[varname]
        else
            error("varname must be a string, got a " ..type(varname).. " value", 2)
        end
    end

    function Environment.os.setenv(varname, data)
        if type(varname) == "string" then
            osenv[varname] = data
        else
            error("varname must be a string, got a " ..type(varname).. " value", 2)
        end
    end

    -- Functions belonging io.* --
    local DefaultInputFile, DefaultOutputFile
    local ecwrap = Environment.component.wrap

    local function setPath(drive, drivename, path)
        local ok, err = drive.set(path)
        if ok then
            local eventData
            repeat
                eventData = coroutine.yield()
            until eventData and eventData[1] == "storage_set" and eventData[2] == drivename

            return eventData[3], eventData[4]
        else
            return false, err
        end
    end

    local function arch_io_type(file)

    end

    function Environment.io.open(filename, mode)
        local drivename, path = filename:match("^/(.-)(/.+)$")
        local drive = ecwrap(drivename)
        local mode = mode or "r"; path = path or "/"

        if drive then
            local File = {}
            local FileMetatable = {
                close = function(File)

                end,

                flush = function(File)

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
                    local ok, err = setPath(drive, drivename, path)

                    if ok then
                        for i = 1, #formats do
                            local f = formats[i]
                            local f_type = type(f)

                            if f_type == "string" then
                                if f == "n" then

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
                                    error("unknown format '" .. f .. "'", 2)
                                end

                            elseif f_type == "number" then

                            else
                                error("format must be a string or number, got a " .. f_type .. " value instead", 2)
                            end
                        end
                    else
                        error("unable to set path; " .. tostring(err))
                    end
                end

            elseif mode == "w" then
                function FileMetatable.write(File, ...)

                end

                function FileMetatable.setvbuf(File, mode, size)

                end
            end

            return setmetatable(File, {__index = FileMetatable})
        end
    end

    function Environment.io.close(file)
        if arch_io_type(file) == "file" then
            file:close()
        else
            local _ = DefaultOutputFile and DefaultOutputFile:close()
        end
    end

    function Environment.io.lines(filename, ...)
        if type(file) == "string" then
            --return io.lines(prepare(filename), ...)
        else
            return DefaultInputFile and DefaultInputFile:lines("*l")
        end
    end

    function Environment.io.input(file)
        if type(file) == "string" then
            --DefaultInputFile = io.open(prepare(file), "r")

        elseif arch_io_type(file) == "file" then
            DefaultInputFile = file

        else
            return DefaultInputFile
        end
    end

    function Environment.io.read(...)
        if DefaultInputFile then
            return DefaultInputFile:read(...)
        end
    end

    function Environment.io.output(file)
        if type(file) == "string" then
            --DefaultOutputFile = io.open(prepare(file), "w")

        elseif arch_io_type(file) == "file" then
            DefaultOutputFile = file

        else
            return DefaultOutputFile
        end
    end

    function Environment.io.write(...)
        if DefaultOutputFile then
            return DefaultOutputFile:write(...)
        end
    end

    function Environment.io.flush()
        local _ = DefaultOutputFile and DefaultOutputFile:flush()
    end

    Environment.io.type = arch_io_type

    -- Functions relating specifically to compiling Lua --
    local eload = Environment.load
    local eiopen = Environment.io.open
    
    function Environment.loadfile(file, mode, env)
        if file then
            local code = eiopen(file, "r")
            if code then
                local ok, err = eload(code:read("a"), file, mode, env or {})
                code:close(); return ok, err
            end
            return nil, "File not found"
        else
            -- load standard input
        end
    end
    
    local eloadfile = Environment.loadfile
    function Environment.dofile(file, ...)
        local func, err = eloadfile(file, "t", Environment)
        if func then
            return func(...)
        else
            error(err)
        end
    end

    --
    --       REMEMBER TO IMPLEMENT THE . USAGE!!!!!!
    --
    local adofile = Environment.dofile
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
                        local result = adofile(filepath, filepath) or true
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