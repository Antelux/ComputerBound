local ty, tonum, tostr = type, tonumber, tostring
local function printValue(t, ind)
    if ty(t) ~= "table" then
        return print(tostr(t))
    end

    local ind, i = ind or "\t", 1
    print(ind:sub(3).."{")
    for k, v in pairs(t) do
        local vType = ty(v)
        local k = ind..(ty(tonum(k)) == "number" and "["..k.."]" or k)

        if vType == "table" then
            if v == t then
                print(k.." = self,")
            else
                print(k.." = {"); printValue(v, ind.."\t"); print(ind.."},")
            end
        elseif vType == "function" then
            print(k.." = function()")
        elseif vType == "string" then
            print(k..' = "' ..tostr(v)..'",')
        else
            print(k.." = " ..tostr(v)..",")
        end
        i = i + 1; if i == 50 then break end
    end
    print(ind:sub(2).."}")
end

term.setTextColor(0xFFFF00)
print(_VERSION.. " Console")
term.setTextColor(0xFFFFFF)

local isRunning, commandHistory = true, {}
local tEnv = setmetatable({
    exit = function() isRunning = false end,
    _echo = function(...) return ... end
}, {__index = _ENV})

while isRunning do
    write("lua> ")
    local s = term.read( nil, commandHistory )
    table.insert( commandHistory, s )
    print()
    
    local func, e = load(s, "lua", "t", tEnv)
    local func2, e2 = load("return _echo("..s..")", "lua", "t", tEnv)
    local func0, e0 = func2 or func, func and e or e2
    
    if func0 then
        local tResults = {pcall(func0)}
        if tResults[1] then
            for i = 2, #tResults do
                printValue(tResults[i])
            end
        else
            printError(tResults[2])
        end
    else
        printError(e0)
    end
    
end