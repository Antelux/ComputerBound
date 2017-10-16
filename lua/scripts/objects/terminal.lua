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
    Colors = cconfig.get("objects/terminal.cb_terminal1.colors", {{255, 255, 255}, {0, 0, 0}})

    MaxSize = Width * Height

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

    message.setHandler("getBuffer", function()
        return {
            LastBuffer, Cursor
        }
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
        "set", "append", "read", "process"
    }
end

function peripheralCall(Computer, NodeType, FunctionName, arg1)
    if FunctionName == "set" then
        if type(arg1) ~= "string" then
            return {false, "string expected, got a " .. type(arg1) .. " value instead"}
        end

        local set_line = ssub(arg1, 1, MaxSize)
        Buffer[1], Index, Size = set_line, 1, #set_line
        isModified = true

    elseif FunctionName == "append" then
        if type(arg1) ~= "string" then
            return {false, "string expected, got a " .. type(arg1) .. " value instead"}
        end

        if Size < MaxSize then
            local append_line = ssub(arg1, 1, MaxSize - Size)
            Index, Size = Index + 1, Size + #append_line
            Buffer[Index] = append_line; isModified = true
        end

    elseif FunctionName == "read" then
        return tconcat(Buffer, _, 1, Index)

    elseif FunctionName == "process" then
        if type(arg1) ~= "boolean" then
            return {false, "boolean expected, got a " .. type(arg1) .. " value instead"}
        end

        isProcessing = arg1

    elseif FunctionName == "size" then
        return Size

    elseif FunctionName == "capacity" then
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