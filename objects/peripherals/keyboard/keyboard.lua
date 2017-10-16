function peripheralType(Computer, NodeType)
    return "keyboard"
end

function peripheralConnect(Computer, NodeType)

end

function peripheralDisconnect(Computer, NodeType)

end

function peripheralMethods(NodeType)
    return {"isDown"}
end

function peripheralCall(Computer, NodeType, FunctionName, ...)
    -- Returns true until the key is no longer pressed
    if FunctionName == "isDown" then
        return 2

    end
end