-- Sets the label of drives in alphabetical order, starting from "C"
for i = 1, #components.storage.addresses do
    local address = components.storage.addresses[i]
    io.setLabel(address, string.char(66 + i))
end

gpu = components.gpu.drivers[1]
if not gpu then
    beep(2); error("No GPU device found.")
end

-- Connect a monitor to the GPU
local foundMonitor = false
for port, peripheral in pairs(node.list()) do
    if peripheral == "monitor" and not foundMonitor then
        gpu.bind(port); foundMonitor = true
    end

    -- Tell the peripheral to connect to us only.
    node.bind(port)
end

-- Install more of the os and io APIs.
local function randomChar()
    local t = math.random(3)
    return string.char((t == 1 and math.random(48, 57)) or -- Numbers
                       (t == 2 and math.random(65, 90)) or -- Uppercase
                       math.random(97, 122)) -- Lowercase
end

function os.tmpname()
    return osenv["%TMP%"].."/"..randomChar()..randomChar()..randomChar()..randomChar().. ".TMP"
end

local osenv = {OS = "StarOS", Version = 1.0, ComputerName = "Computer", ["%TMP%"] = "C:/tmp", ["%DATA%"] = "C:/data", ["%STARTUP%"] = "C:/startup.lua"}
function os.getenv(sVarname)
    return type(sVarname) == "string" and osenv[sVarname] or error("varname must be a string, got a " ..type(sVarname).. " value", 2)
end

function os.setenv(sVarname, data)
    if type(sVarname) ~= "string" then
        error("varname must be a string, got a " ..type(sVarname).. " value", 2)
    end
    osenv[sVarname] = data
end

function io.tmpfile()
    return io.open(os.tmpname(), "w+")
end

-- Load APIs that are needed by just about everything for the OS.
local tFiles = io.list("C:/lib/boot")
for i = 1, #tFiles do
    if not tFiles[i].isDir then
        local ok, err = dofile("C:/lib/boot/"..tFiles[i].name)
        if not ok then error(err) end
    end
end

-- Load APIs that are more for convenience.
local tFiles = io.list("C:/lib")
for i = 1, #tFiles do
    if not tFiles[i].isDir then
        local ok, err = dofile("C:/lib/"..tFiles[i].name)
        if not ok then error(err) end
    end
end

-- And here we protect the main folders.
fs.protect("C:/bin/")
fs.protect("C:/lib/")

-- Load some data.
local dataPath = os.getenv("%DATA%") or ""; fs.makeDir(dataPath)
local sType = io.exists(dataPath.. "/osenv.json")

if sType == "file" then
    local file = fs.open(dataPath.. "/osenv.json", "r")
    local ok, tJson = pcall(json.decode, file:read("a")); file:close()
    if not ok then
        beep(2); printError(dataPath.. "/osenv.json refers to an invalid JSON, recommending deletion or fixing of file.")
    
    elseif type(tJson) == "table" then
        for k, v in pairs(tJson) do
            osenv[k] = v
        end
    end

elseif sType == "dir" then
    beep(2); printError(dataPath.. "/osenv.json refers to a directory, recommending a path change.")

else
    local file = fs.open(dataPath.. "/osenv.json", "w")
    if file then
        file:write(json.encode(osenv)):close()
    end

end

-- Remove all tmp files.
local tempPath = os.getenv("%TMP%")
fs.delete(tempPath)
fs.makeDir(tempPath)

function sleep(nTime)
    if type(nTime) ~= "number" then error("time must be a number", 2) end
    if nTime <= 0 then return end

    local timer = system.startTimer(nTime)
    repeat until event.pull("timer") == timer
end

beep() -- Let us know everything is fine just before running any files.
local startup = os.getenv("%STARTUP%")
if io.exists(startup) == "file" then
    local ok, err = dofile(startup)
    if not ok then
        printError("startup error: " ..err)
    end
end

local ok, err = dofile("C:/bin/cmd.lua")
if not ok then beep(2)
    gpu.clear(0); term.setCursorPos(1, 1); term.setTextColor(0xFFFFFF)
    print('Failure running "C:/bin/cmd.lua," error:'); printError(err)
    if type(err) == "userdata" then print("A program most likely took too long to yield.") end
    print('Will attempt to run "C:/bin/lua.lua" in 5 seconds.'); sleep(5)

    local ok, err = dofile("C:/bin/lua.lua")
    if not ok then beep(2)
        gpu.clear(0); term.setCursorPos(1, 1)
        print('Failure running "C:/bin/lua.lua," error:')
        printError(err); print("Computer unable to start up.")
        while true do coroutine.yield() end
    end
end

--[[

    Final stages of To-do:
        
    * Fix up the paint program. 
        - Create a function to load .spif images and turn them into a texture for gpu use.
    
    * Fix up the adv program.
    
    * Have the FS API protect files as well so I can actually protect init.lua, otherwise it can be edited!
    
    * Add in the rest of the peripherals (modem and router gotta wait, sorry :( )

    * Finish IO compatability with other OSes.

    * Fix GPU problem with drawing textures...

    * Make soundcards.
    * Fix up soundchips.
    
    * Create buttons and stuff for computers to turn on/off.

    * Create recipes and a crafting station? =P

    * Fix boot sound.

    * Make all components have a function to get thier specs.

    * Change drives to be mounted instead of labeled.
    * Change labeling to be the actual name of the drive.

    * Stop binary files from being loaded from load() (for now.)




    





    -- Turns out I can link specific parts of the page on Github, so
    -- that means I can move System, Node, and Components into a page
    -- called "Standard Computer Environment." Be sure to provide examples
    -- for all functions use ```lua <code> ````. Will be awesome.
    --
    -- ex: https://github.com/DetectiveSmith/ComputerBound/wiki/Components#gpu-functions
    -------- Work on: -------
    * Term API
    * Soundsystem API & soundcfg prorgam.










    * Data streams can just be like files.

    local byteStream = tcp.send("Hello, world!")
    local data, i = {}, 1

    while byteStream:isDownloading() do
        data[i] = byteStream:read()
        i = data[i] and i + 1 or i
    end

    if byteStream:finished() then
        print("Packet fully received.")
    else
        print("Packet partially received.")
    end

    mac = address:sub(25, 36)

    Credit the font
]]