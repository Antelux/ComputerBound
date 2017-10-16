----------------------------------------------------------------------------------------------------
-- Localization of some commonly used functions / variables.
----------------------------------------------------------------------------------------------------

require "/lua/api/cconfig.lua"

local ComponentAPI = {}

local debug = debug
local sbapi
local type = type

local unpack = table.unpack
local remove = table.remove

local pairs = pairs
local ipairs = ipairs

local function copy(t)
    local newtable = {}
    if type(t) == "table" then
        for key, value in pairs(t) do
            newtable[key] = type(value) == "table" and copy(value) or value
        end
    end
    
    return newtable
end

local function unload(t)
    for key, value in pairs(t) do
        t[key] = type(value) == "table" and (value ~= debug and value ~= sbapi) and (key ~= "_G" and unload(value)) or nil
    end
end

local ty, pairs = type, pairs
local function list(t, ind)
    local ind = ind or ""
    for k, v in pairs(t) do
        local t = (ty(v) ~= "table" and ty(v) ~= "thread" and ty(v) ~= "userdata" and ty(v) ~= "function") and " ("..ty(v)..")" or ""
        sb.logInfo(ind.."["..k.."]: " ..tostring(v).. t)
        if ty(v) == "table" then 
            list(v, ind.."    ")
        end
    end
end

--player.isAdmin()

----------------------------------------------------------------------------------------------------
-- The base object for the computer and all it's fields.
----------------------------------------------------------------------------------------------------

local StaticEnvironment
local Computer = {
    ID              = -1,    -- Entity ID of the computer.

    InputNodes      = {},    -- The current input node connections of the computer.
    OutputNodes     = {},    -- The current output node connections of the computer.
    InputNodeIDs    = {},    -- The entity IDs of the peripherals connected to the output nodes.
    OutputNodeIDs   = {},    -- The entity IDs of the peripherals connected to the input nodes.
    MaxInputNode    = 0,     -- Number of input nodes it has.
    MaxOutputNode   = 0,     -- Number of output nodes it has.

    isRunning       = false, -- Whether or not the computer is on.
    isRebooting     = false, -- Whether or not the computer is restarting.

    lastError       = nil,   -- The last error that caused the entire computer to crash.

    API             = {      -- Table that holds all native computer APIs.
        Version = "1.17"     -- ComputerBound Version.
    },

    Thread          = nil,   -- The "CPU" of the computer.
    Environment     = {},    -- The global memory space of the computer.
    Components      = {},    -- All internal connected components to the computer.

    TotalMemory     = 0,     -- The total amount of RAM installed in the system, in bytes.
    --AvailableMemory = 0,     -- The amount of free RAM, in bytes.
    UsedMemory      = 0,     -- The amount of used RAM, in bytes.

    Interrupt = {            -- Holds data pertaining to triggered events.
        Push = function(self, t)
            local n = self.Size
            if n <= 512 then
                n = n + 1
                self[n] = t
                self.Size = n
                return true
            end
        end,

        Pull = function(self)
            local t = self[1]
            if t then
                local n = self.Size
                for i = 1, n do
                    self[i] = self[i + 1]
                end
                self.Size = n - 1
            end
            return t
        end,

        Clear = function(self)
            for i = 1, self.Size do
                self[i] = nil
            end
            self.Size = 0
        end,

        Size = 0
    }
}

----------------------------------------------------------------------------------------------------
-- The following functions handle all I/O done via nodes (the in-game wiring system).
-- onNodeConnectionChange() is called whenever something is connected/disconnected from the computer.
-- onInputNodeChange() is called whenever a connected peripheral changes it's output.
----------------------------------------------------------------------------------------------------

function onNodeConnectionChange(ignoreChanges)
    for i = 0, Computer.MaxInputNode do
        local nodes = object.getInputNodeIds(i)
        local amount, peripheralID = 0

        for entity in pairs(nodes) do
            peripheralID = entity
            amount = amount + 1
        end

        local newPeripheral =
           (amount > 1 and "undefined") or
           (amount == 1 and (
                world.callScriptedEntity(peripheralID, "peripheralType", Computer.ID)
                or "primitive"
                )
            ) or nil

        if ignoreChanges then
            if peripheralID then
                world.callScriptedEntity(peripheralID, "peripheralConnect", Computer, "input")
            end

        else
            local currentPeripheral = Computer.InputNodes[i]
            local currentID = Computer.InputNodeIDs[i]

            if currentPeripheral ~= newPeripheral then
                if not currentPeripheral then
                    if peripheralID then
                        -- Add support for a peripheral_connect / peripheral_disconnect, name, port event
                        pcall(world.callScriptedEntity, peripheralID, "peripheralConnect", Computer, "input")
                        Computer.Interrupt:Push({"node_input_connected", newPeripheral, i})
                    end

                else
                    if currentID then
                        pcall(world.callScriptedEntity, currentID, "peripheralDisconnect", Computer, "input")
                        Computer.Interrupt:Push({"node_input_disconnected", currentPeripheral, i})
                    end
                end
            end
        end

        Computer.InputNodes[i] = newPeripheral
        Computer.InputNodeIDs[i] = peripheralID
    end

    for i = 0, Computer.MaxOutputNode do
        local nodes = object.getOutputNodeIds(i)
        local amount, peripheralID = 0

        for entity in pairs(nodes) do
            peripheralID = entity
            amount = amount + 1
        end

        local newPeripheral =
           (amount > 1 and "undefined") or
           (amount == 1 and (
                world.callScriptedEntity(peripheralID, "peripheralType", Computer.ID)
                or "primitive"
                )
            ) or nil

        if ignoreChanges then
            if peripheralID then
                world.callScriptedEntity(peripheralID, "peripheralConnect", Computer, "input")
            end

        else
            local currentPeripheral = Computer.OutputNodes[i]
            local currentID = Computer.OutputNodeIDs[i]

            if currentPeripheral ~= newPeripheral then
                if not currentPeripheral then
                    if peripheralID then
                        pcall(world.callScriptedEntity, peripheralID, "peripheralConnect", Computer, "output")
                        Computer.Interrupt:Push({"node_output_connected", newPeripheral, i})
                    end

                else
                    if currentID then
                        pcall(world.callScriptedEntity, currentID, "peripheralDisconnect", Computer, "output")
                        Computer.Interrupt:Push({"node_output_disconnected", currentPeripheral, i})
                    end
                end
            end
        end

        Computer.OutputNodes[i] = newPeripheral
        Computer.OutputNodeIDs[i] = peripheralID
    end
end

----------------------------------------------------------------------------------------------------
-- 
----------------------------------------------------------------------------------------------------

function initComponents()
    local hasCPU, hasRAM
    Computer.TotalMemory = 0

    local comp = 1
    local multipliers = {
        b = 1,
        kb = 1000,
        mb = 1000000
    }

    for _, component in pairs(storage.inventory) do
        local name = component.name
        local address = component.parameters.address
        local ctype = name:match("%((%a+)%)")

        if not address then
            return false, "Bad Component '" .. name .. "'; missing address"
        end

        if name:find("cb_cpu_") then
            local architecture = name:match("^cb_cpu_(%w+)")
            if architecture then
                local ok, err = pcall(require, "/lua/architectures/" .. architecture .. ".lua")
                if ok then
                    if type(archEnvironment) ~= "function" then
                        return false, "Missing Arch Env."
                    end

                    if type(archRuntime) ~= "function" then
                        return false, "Missing Arch Runtime."
                    end                    

                    local ok, senv = pcall(archEnvironment, Computer.API)
                    if ok then
                        StaticEnvironment, hasCPU = senv, true
                    else
                        return false, "Bad Arch Env: " .. tostring(senv)
                    end
                else
                    return false, "Bad Arch: " .. tostring(err)
                end
            end
        
        -- Be sure to implement allowing only the same kind of ram once one is found.
        elseif name:find("cb_ram_") then
            local amount, mult = name:match("^cb_ram_(%d+)(%a+)")
            mult = multipliers[mult:lower()]

            if amount and mult then
                Computer.TotalMemory = Computer.TotalMemory + (amount * mult); hasRAM = true
            else
                return false, "Bad RAM: " .. tostring(name) 
            end

        elseif ctype then
            if not ComponentAPI[ctype] then
                local ok, err = pcall(require, "/lua/components/" .. ctype .. ".lua")
                if ok then
                    ComponentAPI[ctype] = newComponent; newComponent = nil
                else
                    return false, "Bad Component '" .. name .. "'; " .. tostring(err)
                end
            end

            local ok, api = pcall(ComponentAPI[ctype], Computer, name, address)
            if ok then
                api.address = address
                Computer.Components[address] = api
                Computer.Components[comp] = api
                comp = comp + 1
            else
                return false, "Bad Component Spawn '" .. name .. "'; " .. tostring(api)
            end
        end
    end
    Computer.Components[0] = comp - 1

    return hasCPU and hasRAM, (not hasCPU and "missing CPU; " or "") .. (not hasRAM and "missing RAM" or "")
end

----------------------------------------------------------------------------------------------------
-- The following functions are computer-specific APIs that give users access to different aspects
-- of the computer that would normally be hidden otherwise.
----------------------------------------------------------------------------------------------------

local function checkInput(port)
    if type(port) ~= "number" then return end
    if port < 0 or port > Computer.MaxInputNode then return end
    return Computer.InputNodes[port]
end

local function checkOutput(port)
    if type(port) ~= "number" then return end
    if port < 0 or port > Computer.MaxOutputNode then return end
    return Computer.OutputNodes[port]
end

Computer.API.System = {  
    -- Restarts the computer
    restart = function()
        Computer.isRunning = false
        Computer.isRebooting = true
    end,

    -- Turns the computer off
    shutdown = function()
        Computer.isRunning = false
    end,

    pushEvent = function(event, p1, p2, p3, p4, p5)
        if type(event) == "string" then
            Computer.Interrupt:Push({event, p1, p2, p3, p4, p5})
        end
    end,

    -- Not sure about this.
    --pullEvent = function()
    --    return unpack(Computer.Interrupt:Pull())
    --end,

    playTone = function(frequency, amplitude, duration)
        frequency = type(frequency) == "number" and frequency
        amplitude = type(amplitude) == "number" and amplitude or 1
        duration = type(duration) == "number" and duration or 1
        
        frequency = frequency >= 20 and frequency <= 20000 and frequency / 100
        amplitude = amplitude >= 0 and amplitude <= 1 and amplitude * 0.20
        duration = duration > 0 and duration <= 5 and duration

        if not (frequency and amplitude and duration) then return end
        if currentSound then animator.stopAllSounds("100hz") end

        animator.setSoundPitch("100hz", frequency, 0)
        animator.setSoundVolume("100hz", amplitude, 0)
        animator.playSound("100hz", 0); currentSound = duration

        return true
    end,

    address = function()
        return storage.address
    end,

    --time = function()
    --    local t = world.timeOfDay() * 24 + 6
    --    return t >= 24 and t - 6 or t
    --end
}

Computer.API.Node = {
    input = {
        find = function(peripheralType)
            if type(peripheralType) == "string" then
                local Nodes, j = Computer.InputNodes, 1
                for i = 0, Computer.MaxInputNode do
                    if Nodes[i] == peripheralType then
                        return i
                    end
                end
            end
        end,

        findAll = function(peripheralType)
            local nodeConnections = {}

            if type(peripheralType) then
                local Nodes, j = Computer.InputNodes, 1
                for i = 0, Computer.MaxInputNode do
                    if Nodes[i] == peripheralType then
                        nodeConnections[j] = i; j = j + 1
                    end
                end
            end

            return nodeConnections
        end,

        type = function(port)
            return checkInput(port)
        end,

        list = function()
            local nodeConnections = {}
            local Nodes = Computer.InputNodes

            for i = 0, Computer.MaxInputNode do
                nodeConnections[i] = Nodes[i]
            end

            return nodeConnections
        end,

        maxPort = function()
            return Computer.MaxInputNode
        end,

        getLevel = function(port)
            return type(port) == "number" and object.getInputNodeLevel(port)
        end,

        invoke = function(port, functionName, ...)
            if type(port) == "number" and type(functionName) == "string" then
                return world.callScriptedEntity(Computer.InputNodeIDs[port], "peripheralCall", Computer, "input", functionName, ...)
            end
        end,

        wrap = function(node)
            local node_type = type(node)
            local Nodes = Computer.InputNodes
            local MethodNames, EntityID, port

            if node_type == "number" and Nodes[node] then
                EntityID = Computer.InputNodeIDs[node]; port = node
                MethodNames = world.callScriptedEntity(EntityID, "peripheralMethods", "input")

            elseif node_type == "string" then
                for i = 0, Computer.MaxInputNode do
                    if Nodes[i] == node then
                        EntityID = Computer.InputNodeIDs[i]; port = i
                        MethodNames = world.callScriptedEntity(EntityID, "peripheralMethods", "input")
                        break
                    end
                end

            end

            if MethodNames then
                local Peripheral = {}

                for i = 1, #MethodNames do
                    local Method = MethodNames[i]
                    local Connected = true
                    
                    Peripheral[Method] = function(...)
                        if Nodes[port] and Connected then
                            local value = world.callScriptedEntity(EntityID, "peripheralCall", Computer, "input", Method, ...)
                            if type(value) == "table" then
                                return unpack(value)
                            else
                                return value
                            end
                        else
                            Connected = false
                            error("connection to peripheral severed", 2)
                        end
                    end
                end

                return Peripheral
            end
        end,

        address = function(port)
            if type(port) == "number" then
                return world.callScriptedEntity(Computer.InputNodeIDs[port], "peripheralAddress")
            end
        end
    },

    output = {
        find = function(peripheralType)
            if type(peripheralType) == "string" then
                local Nodes, j = Computer.OutputNodes, 1
                for i = 0, Computer.MaxOutputNode do
                    if Nodes[i] == peripheralType then
                        return i
                    end
                end
            end
        end,

        findAll = function(peripheralType)
            local nodeConnections = {}

            if type(peripheralType) == "string" then
                local Nodes, j = Computer.OutputNodes, 1
                for i = 0, Computer.MaxOutputNode do
                    if Nodes[i] == peripheralType then
                        nodeConnections[j] = i; j = j + 1
                    end
                end
            end

            return nodeConnections
        end,

        type = function(port)
            return checkOutput(port)
        end,
        
        list = function()
            local nodeConnections = {}
            local Nodes = Computer.OutputNodes

            for i = 0, Computer.MaxOutputNode do
                nodeConnections[i] = Nodes[i]
            end

            return nodeConnections
        end,

        maxPort = function()
            return Computer.MaxOutputNode
        end,

        setLevel = function(port, activated)
            if type(port) == "number" and type(activated) == "boolean" then
                object.setOutputNodeLevel(port, activated)
                return true
            end
        end,

        --[[
        setAllLevels = function(activated)
            if type(activated) == "boolean" then
                object.setAllOutputNodes(activated)
                return true
            end
        end,
        --]]

        getLevel = function(port)
            if type(port) == "number" then
                return object.getOutputNodeLevel(port)
            else
                return false, "port must be a number, got a " .. type(port) .. " value instead"
            end
        end,

        invoke = function(port, functionName, ...)
            if type(port) == "number" and type(functionName) == "string" then
                return world.callScriptedEntity(Computer.OutputNodeIDs[port], "peripheralCall", Computer, "output", functionName, ...)
            end
        end,

        wrap = function(node)
            local node_type = type(node)
            local Nodes = Computer.OutputNodes
            local MethodNames, EntityID, port

            if node_type == "number" and Nodes[node] then
                EntityID = Computer.OutputNodeIDs[node]; port = node
                MethodNames = world.callScriptedEntity(EntityID, "peripheralMethods", "output")

            elseif node_type == "string" then
                for i = 0, Computer.MaxOutputNode do
                    if Nodes[i] == node then
                        EntityID = Computer.OutputNodeIDs[i]; port = i
                        MethodNames = world.callScriptedEntity(EntityID, "peripheralMethods", "output")
                        break
                    end
                end
            end

            if not EntityID then return false, "unable to find peripheral" end
            if not MethodNames then return false, "peripheral lacks callable methods" end

            local Peripheral = {}
            for i = 1, #MethodNames do
                local Method = MethodNames[i]
                local Connected = true

                Peripheral[Method] = function(...)
                    if Nodes[port] and Connected then
                        local value = world.callScriptedEntity(EntityID, "peripheralCall", Computer, "output", Method, ...)
                        if type(value) == "table" then
                            return unpack(value)
                        else
                            return value
                        end
                    else
                        Connected = false
                        return false, "connection to peripheral severed"
                    end
                end
            end

            return Peripheral
        end,

        address = function(port)
            if type(port) == "number" then
                return world.callScriptedEntity(Computer.OutputNodeIDs[port], "peripheralAddress")
            else
                return false, "port must be a number, got a " .. type(port) .. " value instead"
            end
        end
    }
}

Computer.API.Component = {
    find = function(componentType)
        if type(componentType) ~= "string" then
            return false, "type must be a string"
        end

        local Components = Computer.Components
        for i = 1, Components[0] or 0 do
            local Component = Components[i]
            if Component.type == componentType then
                return Component.address
            end
        end
    end,

    findAll = function(componentType)
        if type(componentType) ~= "string" then
            return false, "type must be a string"
        end

        local List, j = {}, 1
        local Components = Computer.Components

        for i = 1, Components[0] or 0 do
            local Component = Components[i]
            if Component.type == componentType then
                List[j] = Component.address; j = j + 1
            end
        end

        return List
    end,

    type = function(componentAddress)
        if type(componentAddress) ~= "string" then
            return false, "address must be a string"
        end

        local Component = Computer.Components[componentAddress]
        if Component then
            return Component.type
        else
            return false, "no such component with address '" .. componentAddress .. "'"
        end
    end,

    list = function()
        local Components = Computer.Components
        local List = {}

        for i = 1, Components[0] or 0 do
            List[i] = Components[i].address
        end

        return List
    end,

    invoke = function(componentAddress, functionName, ...)
        if type(componentAddress) ~= "string" then
            return false, "address must be a string"
        elseif type(functionName) ~= "string" then
            return false, "function must be a string"
        end

        local Component = Computer.Components[componentAddress]
        if Component then
            return Component.call(functionName, ...)
        else
            return false, "no such component with address '" .. componentAddress .. "'"
        end
    end,

    wrap = function(componentAddress)
        if type(componentAddress) ~= "string" then
            return false, "address must be a string"
        end

        local Component = Computer.Components[componentAddress]
        if Component then
            local Methods = Component.methods()
            if Methods then
                local Wrapper = {}
                local Call = Component.call

                for i = 1, #Methods do
                    local Method_Name = Methods[i]

                    Wrapper[Method_Name] = function(...)
                        return Call(Method_Name, ...)
                    end
                end

                return Wrapper
            else
                return false, "component lacks callable methods"
            end
        else
            return false, "no such component with address '" .. componentAddress .. "'"
        end
    end
}

----------------------------------------------------------------------------------------------------
--
----------------------------------------------------------------------------------------------------

local function initComputer()
    Computer.Environment = copy(StaticEnvironment)
    local ok, func = pcall(archRuntime, Computer.Environment)

    if ok then
        Computer.Thread = coroutine.create(func)

        -- Initialize internal components.
        local Components = Computer.Components
        for i = 1, Components[0] or 0 do
            Components[i].init()
        end
    else
        Computer.isRunning = false
        Computer.lastError = "Unable to create thread: " .. tostring(func)
    end
end

----------------------------------------------------------------------------------------------------
-- Initialize a few variables and set up message handlers.
----------------------------------------------------------------------------------------------------

function init()
    cconfig.root(root)
    --local sc_config = cconfig.get("objects/siliconcrucible", {})

    Computer.ID = entity.id()
    Computer.MaxInputNode = object.inputNodeCount() - 1
    Computer.MaxOutputNode = object.outputNodeCount() - 1

    sbapi = sb

    storage.address = storage.address or sb.makeUuid()
    storage.inventory = storage.inventory or {}
    
    local Computer = Computer

    --  Make all the below stuff more secure!!
    message.setHandler("interrupt", function(_, _, event, p1, p2, p3, p4, p5)
        if type(event) == "string" then
            Computer.Interrupt:Push({event, p1, p2, p3, p4, p5})
        end
    end)

    message.setHandler("preformRestart", function()
        Computer.isRunning = false
        Computer.isRebooting = true
        script.setUpdateDelta(1)

        collectgarbage("stop")
        collectgarbage(); collectgarbage()
    end)

    message.setHandler("setPowerState", function(_, _, power)
        if not Computer.isRebooting then
            if Computer.isRunning then
                Computer.isRunning = false
                
            else
                Computer.isRebooting = true
                script.setUpdateDelta(1)

                collectgarbage("stop")
                collectgarbage(); collectgarbage()
            end
        end
    end)

    message.setHandler("getLastError", function()
        return tostring(Computer.lastError)
    end)

    message.setHandler("storageSet", function(_, _, index, value)
        storage.inventory[index] = value
    end)

    message.setHandler("getComputerData", function(_, _, index)
        return {storage.inventory, Computer.isRunning or Computer.isRebooting}
    end)

    collectgarbage("stop")
    collectgarbage(); collectgarbage()
end

function uninit()
    -- Uninitialize internal components.
    local Components = Computer.Components
    for i = 1, Components[0] or 0 do
        Components[i].uninit()
    end

    -- Delete everything from memory.
    unload(Computer.Environment)
    unload(Computer.Components)
    Computer.Interrupt:Clear()

    -- If the computer is rebooting, reinitialize everything.
    if Computer.isRebooting then
        local ok, err = initComponents()
        if ok then
            Computer.isRunning = true
            initComputer()
        end

        Computer.isRebooting = false
        Computer.lastError = err

    else
        -- Stop updating the computer script and wait until the computer reboots.
        collectgarbage(); collectgarbage()
        collectgarbage("restart"); script.setUpdateDelta(0)
    end
end

function die()
    local InputNodeIDs = Computer.InputNodeIDs
    for i = 0, Computer.MaxInputNode do
        local EntityID = InputNodeIDs[i]
        if EntityID then
            pcall(world.callScriptedEntity, EntityID, "peripheralDisconnect", Computer, "input")
        end
    end

    local OutputNodeIDs = Computer.OutputNodeIDs
    for i = 0, Computer.MaxOutputNode do
        local EntityID = OutputNodeIDs[i]
        if EntityID then
            pcall(world.callScriptedEntity, EntityID, "peripheralDisconnect", Computer, "output")
        end
    end

    unload(StaticEnvironment or {})
    unload(Computer)

    local inventory = storage.inventory
    for name, item in pairs(inventory) do
        world.spawnItem(item, entity.position(), 1)
        inventory[name] = nil
    end
    storage.inventory = nil

    collectgarbage(); collectgarbage()
end

----------------------------------------------------------------------------------------------------
-- Main update loop.
----------------------------------------------------------------------------------------------------

local realInit = true
function update(dt)
    if realInit then
        onNodeConnectionChange(true)
        realInit = false
    end

    local Computer = Computer
    if Computer.isRunning then
        -- Update internal components.
        local Components = Computer.Components
        for i = 1, Components[0] or 0 do
            Components[i].update()
        end

        -- Update the current sound playing.
        if currentSound then
            currentSound = currentSound - dt
            if currentSound <= 0 then
                animator.stopAllSounds("100hz")
            end
        end

        -- Now update the thread.
        local memoryUsage = collectgarbage("count")
        local ok, err = coroutine.resume(Computer.Thread, Computer.Interrupt:Pull())
        collectgarbage(); collectgarbage()
        local memoryUsage = collectgarbage("count") - memoryUsage

        Computer.UsedMemory = memoryUsage

        if not ok then
            Computer.isRunning = false
            Computer.isRebooting = false
            Computer.lastError = err

            uninit()
        end
    else
        uninit()
    end
end