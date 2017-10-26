require "/lua/api/cconfig.lua"

local Terminal
local Inverted
local Modified 

local ComputerID = false

local Width, Height

local CursorX, CursorY = 1, 1
local sCursorX, sCursorY = 1, 1

local isCursorEnabled = true
local InputMode = "character"

local type, lastError = type
local function checkArg(arg, name, arg_type)
    if type(arg) ~= arg_type then
        lastError = name .. " must be a " .. arg_type .. ", got a " .. type(arg) .. " value instead"
        return true
    end
end

function init()
    cconfig.root(root)

    Width = cconfig.get("objects/terminal.cb_terminal1.width", 40)
    Height = cconfig.get("objects/terminal.cb_terminal1.height", 12)
    Colors = cconfig.get("objects/terminal.cb_terminal1.colors", {{255, 255, 255}, {0, 0, 0}})
    Terminal, Inverted, Modified = {}, {}, {}

    message.setHandler("getData", 
        function() 
            return {
                ComputerID,
                Width, Height,
                Colors
            } 
        end)

    message.setHandler("getQueue", 
        function() 
            local Queue, i = {}, 1
            for y = 1, Height do
                if Modified[y] then
                    Queue[i] = Terminal[y]
                    Queue[i+1] = Inverted[y]
                    Queue[i+2] = y; i = i + 3
                end
            end
            
            Queue[i] = CursorX
            Queue[i+1] = CursorY

            if CursorY > 0 and CursorY <= Height and CursorX > 0 and CursorX <= Width then
                Queue[i+2] = isCursorEnabled and Inverted[CursorY][CursorX] or (not Inverted[CursorY][CursorX])
                Queue[i+3] = Terminal[CursorY][CursorX]
            else
                Queue[i+2] = true
                Queue[i+3] = " "
            end

            return Queue
        end)

    for y = 1, Height do
        local yline = {}
        local yinv = {}
        for x = 1, Width do
            yline[x] = " "
            yinv[x] = false
        end
        Terminal[y] = yline
        Inverted[y] = yinv
        Modified[y] = false
    end
end

function peripheralAddress()
    storage.address = storage.address or sb.makeUuid()
    return storage.address
end

function peripheralType()
    return "terminal"
end

function peripheralMethods(NodeType)
    return {
        "setLine", "getLine", 
        "setMode", "getMode",
        "setInverted", "getInverted",
        "setCursorPosition", "getCursorPosition",
        "setCursorEnabled", "getCursorEnabled",
        "clear", "clearLine",
        "scroll", "writef",
        "getResolution",
        "process"
    }
end

-- www.termsys.demon.co.uk/vtansi.htm
--[[

    Usage:
        The terminal has an internal buffer the size
        of the screen that clears out at a pre-set interval
        (say, 1/30th of a second). The computer keeps sending
        text to fill this buffer with. If the buffer is full,
        the new text is automatically discarded. When the buffer
        is processed, it will go through the string and send
        errors back the moment they're processed, meaning ansi
        sanity won't be checked for. A message is sent back to the
        computer once the string is processed, containing any errors
        it might've had. Once an error is found, processing is
        discontinued.

    Functions:
        set(text: string)
        * Sets the contents of the terminal's buffer.

        append(text: string)
        * Appends data to the content of the buffer.

        read()
        * Returns the contents of the terminal's buffer.

        process(send: boolean)
        * Whether or not to actively process the contents
          of the terminal buffer. Useful for, say, when a
          program is constantly appending data to the buffer
          but doesn't want any of it to be drawn until it's
          done with it's processing.

          Note: The 1/30th clock is reset whenever this is
                called with a true boolean, meaning that
                it'll take 1/30th of a second before the
                contents of the buffer are shown.
--]]

function peripheralCall(Computer, NodeType, FunctionName, arg1, arg2, arg3)
    if FunctionName == "setLine" then
        if checkArg(arg1, "line", "string") then return {false, lastError} end

        if type(arg2) ~= "nil" then
            if checkArg(arg2, "x", "number") then return {false, lastError} end
        end

        if type(arg3) ~= "nil" then
            if checkArg(arg3, "y", "number") then return {false, lastError} end
        end
        
        local x = arg2 and (arg2 // 1) + 1 or CursorX
        local y = arg3 and (arg3 // 1) + 1 or CursorY

        if y < 1 or y > Height or x > Width then return 0 end

        local yline = Terminal[y]
        local yinv = Inverted[y]
        
        local set, s = 0, 1
        local sub = string.sub

        for i = x + 1, x + #arg1 + 1 do
            if i > 1 and i < Width then
                yline[i] = sub(arg1, s, s); set = set + 1
                yinv[i] = isInverted
            end
            s = s + 1
        end

        Modified[y] = true

        return set

    elseif FunctionName == "getLine" then
        if checkArg(arg1, "length", "number") then return {false, lastError} end
        
        if type(arg2) ~= "nil" then
            if checkArg(arg2, "x", "number") then return {false, lastError} end
        end

        if type(arg3) ~= "nil" then
            if checkArg(arg3, "y", "number") then return {false, lastError} end
        end
        
        local x = arg2 and (arg2 // 1) + 1 or CursorX
        local y = arg3 and (arg3 // 1) + 1 or CursorY
        
        if y < 1 or y > Height or x > Width then return 0 end
        local length = x + (arg1 // 1) - 1

        return table.concat(Terminal[y], _, x < 1 and 1 or x, length > Width and Width or length)

    elseif FunctionName == "process" then
        if checkArg(arg1, "line", "string") then return {false, lastError} end

        local cursor_x = CursorX
        local cursor_y = CursorY
        local i, length = 1, #arg1
        local line = arg1

        local ssub = string.sub
        local sfind = string.find
        local smatch = string.match

        local tonum = tonumber

        while i <= length do
            local char = ssub(line, i, i)

            -- ANSI Control Sequences.
            if char == "\27" then
                local line, col
                if ssub(line, i+1, i+1) ~= "[" then
                    return {false, "bad ansi sequence starting at " .. i}
                end
                i = i + 2

                -- Set Cursor Position.
                local line, column, found = smatch(line, "^(%d*);(%d*)([Hf])$", i)
                if found ~= "" then
                    i = i + #line + #column + 2

                    cursor_y = tonum(line) + 1 or 1
                    cursor_x = tonum(column) + 1 or 1

                    goto found_escape
                end

                -- Move Cursor Around.
                local value, mode = smatch(line, "^(%d*)[ABCD]$", i)
                if mode ~= "" then
                    i = i + #value + 1
                    value = tonum(value) or 1

                    if mode == "A" then
                        cursor_y = cursor_y + value

                    elseif mode == "B" then
                        cursor_y = cursor_y - value

                    elseif mode == "C" then
                        cursor_x = cursor_x + value

                    else
                        cursor_x = cursor_x - value

                    end

                    goto found_escape
                end

                local mode = ssub(line, i, i)
                if mode == "s" then -- Save Cursor Position.

                elseif mode == "u" then -- Restore Cursor Position.

                elseif mode == "K" then -- Erase Line.
                    -- erase starting from x to end of line

                else
                    return {false, "bad ansi sequence starting at " .. i}
                end

                ::found_escape::

            -- ASCII Control Codes.
            elseif sfind(char, "[\n\t\f\r\b\v\a]") then
                if char == "\n" then        -- Newline.
                    cursor_y = cursor_y + 1
                    cursor_x = 1

                elseif char == "\t" then    -- Horizontal Tab.
                    cursor_x = cursor_x + 3

                elseif char == "\f" then    -- Form Feed.
                    cursor_y = cursor_y + 1

                elseif char == "\r" then    -- Carriage Return.
                    cursor_x = 1

                elseif char == "\b" then    -- Backspace.
                    cursor_x = cursor_x - 1

                elseif char == "\v" then    -- Vertical Tab.
                    cursor_y = cursor_y + 3

                else                        -- Bell.
                    -- do some bell stuff
                end

                -- Scroll when done.

            -- ASCII Text.
            else

            end
        end

    elseif FunctionName == "setMode" then
        if checkArg(arg1, "mode", "string") then return {false, lastError} end
        if arg1 ~= "character" and arg1 ~= "line" and arg1 ~= "block" then
            return {false, "invalid mode"}
        end
        InputMode = arg1

    elseif FunctionName == "getMode" then
        return InputMode

    elseif FunctionName == "setInverted" then
        if checkArg(arg1, "enabled", "boolean") then return {false, lastError} end
        isInverted = arg1

    elseif FunctionName == "getInverted" then
        return isInverted

    elseif FunctionName == "setCursorPosition" then
        if type(arg1) == "number" then
            CursorX = (arg1 // 1) + 1
        end

        if type(arg2) == "number" then
            CursorY = (arg2 // 1) + 1
        end

    elseif FunctionName == "getCursorPosition" then
        return {CursorX - 1, CursorY - 1}

    elseif FunctionName == "setCursorEnabled" then
        if checkArg(arg1, "enabled", "boolean") then return {false, lastError} end
        isCursorEnabled = arg1

    elseif FunctionName == "getCursorEnabled" then
        return isCursorEnabled

    elseif FunctionName == "clear" then
        local inv = false
        if type(arg1) ~= "nil" then
            if checkArg(arg1, "inverted", "boolean") then return {false, lastError} end
            inv = arg1
        end

        local Terminal = Terminal
        local Inverted = Inverted

        for y = 1, Height do
            local yline = Terminal[y]
            local yinv = Inverted[y]

            for x = 1, Width do
                yline[x] = " "
                yinv[x] = inv
            end

            Terminal[y] = yline
            Inverted[y] = yinv
            Modified[y] = true
        end

    elseif FunctionName == "clearLine" then
        local inv = false

        if checkArg(arg1, "y", "number") then return {false, lastError} end
        if type(arg2) ~= "nil" then
            if checkArg(arg2, "inverted", "boolean") then return {false, lastError} end
            inv = arg2
        end

        local Terminal = Terminal
        local Inverted = Inverted
        local y = arg1 // 1

        if y >= 0 and y < Height then
            y = y + 1

            local yline = Terminal[y]
            local yinv = Inverted[y]

            for x = 1, Width do
                yline[x] = " "
                yinv[x] = inv
            end

            Terminal[y] = yline
            Inverted[y] = yinv
            Modified[y] = true
        end

    elseif FunctionName == "scroll" then
        if checkArg(arg1, "lines", "number") then return {false, lastError} end

        local Terminal = Terminal
        local Inverted = Inverted
        local lines = arg1 // 1

        if lines > 0 then
            for y = 1, Height do
                local tline = Terminal[y+lines]

                if tline then
                    Terminal[y] = tline
                    Inverted[y] = Inverted[y+lines]
                else
                    local tline, iline = {}, {}
                    for x = 1, Width do
                        tline[x] = " "
                        iline[x] = isInverted
                    end
                    Terminal[y] = tline
                    Inverted[y] = iline
                end

                Modified[y] = true
            end
        end

    elseif FunctionName == "writef" then
        if checkArg(arg1, "text", "string") then return {false, lastError} end

        if type(arg2) ~= "nil" then
            if checkArg(arg2, "x", "number") then return {false, lastError} end
        end

        if type(arg3) ~= "nil" then
            if checkArg(arg3, "y", "number") then return {false, lastError} end
        end

        local cursor_x = arg2 and (arg2 // 1) + 1 or CursorX
        local cursor_y = arg3 and (arg3 // 1) + 1 or CursorY

        local smatch = string.match
        local ssub = string.sub
        local mceil = math.ceil

        local Terminal = Terminal
        local Inverted = Inverted

        local i, length = 1, #arg1

        while i <= length do
            local whitespace = smatch(arg1, "^[ ]+", i)
            if whitespace then
                local wlength = #whitespace; i = i + wlength
                cursor_x = cursor_x + wlength
            end

            local escapes = smatch(arg1, "^[\n\t\f\r\b\v\a]+", i)
            if escapes then
                local elength = #escapes

                for j = 0, elength-1 do
                    local char = ssub(arg1, i+j, i+j)

                    if char == "\n" then    -- Newline
                        cursor_y = cursor_y + 1
                        cursor_x = 1

                    elseif char == "\t" then    -- Horizontal Tab
                        cursor_x = cursor_x + 3

                    elseif char == "\f" then    -- Form Feed
                        cursor_y = cursor_y + 1

                    elseif char == "\r" then    -- Carriage Return
                        cursor_x = 1

                    elseif char == "\b" then    -- Backspace
                        cursor_x = cursor_x - 1

                    elseif char == "\v" then    -- Vertical Tab
                        cursor_y = cursor_y + 3

                    else end --beep() end             -- Bell
                end

                if cursor_y > Height then
                    peripheralCall(Computer, NodeType, "scroll", cursor_y - Height)
                    cursor_y = Height
                end

                i = i + elength
            end
            
            local word = smatch(arg1, "^[^ \n\t\f\r\b\v\a]+", i)
            if word then
                local word_length = #word

                if word_length > Width then
                    if cursor_x > Width then
                        if cursor_y == Height then
                            peripheralCall(Computer, NodeType, "scroll", 1)
                        else
                            cursor_y = cursor_y + 1
                        end

                        cursor_x = cursor_x + 1
                    end

                    local offset = cursor_x - Width
                    local section = ssub(word, 1, Width - offset)
                    peripheralCall(Computer, NodeType, "setLine", section, cursor_x-1, cursor_y-1)
                    cursor_x = cursor_x + #section

                    for i = 1, (word_length // Width) - 1 do
                        if cursor_y == Height then
                            peripheralCall(Computer, NodeType, "scroll", 1)
                        else
                            cursor_y = cursor_y + 1
                        end

                        local section = ssub(word, ((i-1)*Width)+1+offset, (i*Width)+offset)
                        peripheralCall(Computer, NodeType, "setLine", section, cursor_x-1, cursor_y-1)
                        cursor_x = #section
                    end

                else
                    if cursor_x + word_length > Width then
                        if cursor_y == Height then
                            peripheralCall(Computer, NodeType, "scroll", 1)
                        else
                            cursor_y = cursor_y + 1
                        end

                        cursor_x = 1
                    end
                    peripheralCall(Computer, NodeType, "setLine", word, cursor_x-1, cursor_y-1)
                    cursor_x = cursor_x + word_length
                end

                i = i + word_length
            end
        end
        CursorX, CursorY = cursor_x, cursor_y

    elseif FunctionName == "getResolution" then
        return {Width, Height}

    else
        return {false, "invalid operation"}
    end
end

function peripheralConnect(Computer, NodeType)
    if not ComputerID then
        ComputerID = Computer.ID
    end
end

function peripheralDisconnect(Computer, NodeType)
    if ComputerID == Computer.ID then
        ComputerID = false

        for y = 1, Height do
            local yline = Terminal[y]
            local yinv = Inverted[y]

            for x = 1, Width do
                yline[x] = " "
                yinv[x] = false
            end

            Terminal[y] = yline
            Inverted[y] = yinv
            Modified[y] = true
        end
    end
end

--[[
require "/lua/api/cconfig.lua"

local Buffer, Index = {}, 0
local Size, MaxSize = 0
local LastBuffer = ""
local isModified = false

local ComputerID = false
local Width, Height

local Cursor = {0, 0, 0, 0, true}
local isProcessing = true
local isConnectionOpen = false
--local InputMode = "character"

local type = type
local tconcat = table.concat
local ssub = string.sub

function init()
    cconfig.root(root)

    Width = cconfig.get("objects/terminal.cb_terminal1.width", 40)
    Height = cconfig.get("objects/terminal.cb_terminal1.height", 12)
    MaxSize = cconfig.get("objects/terminal.cb_terminal1.buffer", 32)
    Colors = cconfig.get("objects/terminal.cb_terminal1.colors", {{255, 255, 255}, {0, 0, 0}})

    message.setHandler("openConnection", function()
        isConnectionOpen = true
    end)

    message.setHandler("closeConnection", function()
        isConnectionOpen = false
    end)

    message.setHandler("getInfo", function()
        return {
            ComputerID,
            Width, Height,
            Colors
        }
    end)

    message.setHandler("getScreen", function()
    end)

    message.setHandler("drawText", function(_, _, drawT)
    end)
end

function update()
    if isProcessing then
        if connectionOpen and isModified then
            LastBuffer = tconcat(Buffer, _, 1, Index)
        end
        Index, Size = 0, 0
        isModified = false
    end
end

function peripheralAddress()
    storage.address = storage.address or sb.makeUuid()
    return storage.address
end

function peripheralType()
    return "terminal"
end

function peripheralMethods(NodeType)
    return {
        "set", "append", "read", "flush", "process"
    }
end

function peripheralCall(Computer, NodeType, FunctionName, arg1)
    if FunctionName == "set" then
        if type(arg1) == "string" then
            local set_line = ssub(arg1, 1, MaxSize)
            Buffer[1], Index, Size = set_line, 1, #set_line
            isModified = true
            return Size
        else
            return {false, "string expected, got a " .. type(arg1) .. " value instead"}
        end

    elseif FunctionName == "append" then
        if type(arg1) == "string" then
            if Size < MaxSize then
                local append_line = ssub(arg1, 1, MaxSize - Size)
                Index, Size = Index + 1, Size + #append_line
                Buffer[Index] = append_line; isModified = true
                return Size
            end
            return {false, "terminal buffer full"}
        else
            return {false, "string expected, got a " .. type(arg1) .. " value instead"}
        end
        

    elseif FunctionName == "read" then
        return tconcat(Buffer, _, 1, Index)

    elseif FunctionName == "flush" then

    elseif FunctionName == "process" then
        if type(arg1) == "boolean" then
            isProcessing = arg1
            return true
        else
            return {false, "boolean expected, got a " .. type(arg1) .. " value instead"}
        end

    elseif FunctionName == "currentSize" then
        return Size

    elseif FunctionName == "bufferSize" then
        return MaxSize

    --elseif FunctionName == "getResolution" then

    else
        return {false, "invalid operation"}
    end
end

function peripheralConnect(Computer, NodeType)
    if not ComputerID then
        ComputerID = Computer.ID
    end
end

function peripheralDisconnect(Computer, NodeType)
    if ComputerID == Computer.ID then
        ComputerID = false
    end
end
--]]