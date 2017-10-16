-- Required: Called to get the unique ID of the peripheral.
function peripheralAddress()
    -- Alternatively, you can put the below line into the
    -- init() function of the peripheral if it has one.
    storage.address = storage.address or sb.makeUuid()
    return storage.address
end

-- Required: Called to get the type of peripheral (e.g. "Monitor").
function peripheralType()
    return "PeripheralTypeHere"
end

-- Required: Called when a list of function names are needed.
function peripheralMethods(NodeType)
    return {"Method1", "Method2", "Method3"}
end

-- Required: Called when a function from the method list is called on.
function peripheralCall(Computer, NodeType, FunctionName, ...)
    if FunctionName == "Method1" then
        return 42

    elseif FunctionName == "Method2" then
        return {}

    elseif FunctionName == "Method3" then
        return "Hello, world!"

    end
end

-- Optional: Called when the peripheral is connected to a computer.
function peripheralConnect(Computer, NodeType)

end

-- Optional: Called when the peripheral is disconnected from a computer.
function peripheralDisconnect(Computer, NodeType)

end

-- Optional: Used by some components to interact with peripherals.
function peripheralAPI(ComponentType, FunctionName, ...)
    if FunctionName == "Method1" then
        return 1

    elseif FunctionName == "Method2" then
        return 2

    elseif FunctionName == "Method3" then
        return 3

    end
end