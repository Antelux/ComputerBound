function peripheralType(Computer, NodeType)
    return "mouse"
end

function peripheralConnect(Computer, NodeType)

end

function peripheralDisconnect(Computer, NodeType)

end

function peripheralMethods(NodeType)
    return {"getPosition", "isDown"}
end

function peripheralCall(Computer, NodeType, FunctionName, ...)
    if FunctionName == "getPosition" then
        return 1

    elseif FunctionName == "isDown" then
        return 2

    end
end