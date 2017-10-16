local address

-- Required: Called to get the type of component (e.g. "GPU").
function componentType()
    return "ComponentTypeHere"
end

-- Required: Called when a list of function names are needed.
function componentMethods()
    return {"Method1", "Method2", "Method3"}
end

-- Required: Called when a function from the method list is called on.
function componentCall(FunctionName, ...)
    if FunctionName == "Method1" then
        return 42

    elseif FunctionName == "Method2" then
        return {}

    elseif FunctionName == "Method3" then
        return "Hello, world!"

    end
end

-- Optional: Called when the computer is first booted up.
function componentInit(Computer, Address)
    address = Address
end

-- Optional: Called when the computer is shutting down.
function componentUninit()

end