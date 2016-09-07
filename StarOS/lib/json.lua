local ty, pairs, tostr, tonum = type, pairs, tostring, tonumber

local decodeTable, decodeArray
function decodeTable(sJson)
    local tJson = {}

    local function expectPull(exp)
        local s, e = sJson:find("%s+")
        if s == 1 then sJson = sJson:sub(e + 1) end

        local s, e, match = sJson:find(exp)
        if s == 1 then
            match = match or sJson:sub(1, e)
            sJson = sJson:sub(e + 1)

            return match
        end
        error("json corrupted, expected " ..exp)
    end

    local function acceptPull(exp)
        local s, e = sJson:find("%s+")
        if s == 1 then sJson = sJson:sub(e + 1) end

        local s, e, match = sJson:find(exp)
        if s == 1 then
            match = match or sJson:sub(1, e)
            sJson = sJson:sub(e + 1)

            return match
        end
    end

    expectPull("{")
    repeat
        local index = expectPull("\"(.-)\""); expectPull(":")

        tJson[index] = acceptPull("\"(.-)\"") -- Strings
        tJson[index] = tJson[index] or tonum(acceptPull("[%d%.]+") or "") -- Numbers
        tJson[index] = tJson[index] or (acceptPull("true") and true) -- Booleans: true
        if acceptPull("false") then tJson[index] = false end -- Booleans: false

        if tJson[index] == nil and sJson:find("{") == 1 then -- Objects
            tJson[index], sJson = decodeTable(sJson)
        end

        if tJson[index] == nil and sJson:find("%[") == 1 then -- Arrays
            tJson[index], sJson = decodeArray(sJson)
        end

        if tJson[index] == nil and not acceptPull("null") then -- Last second null check
            error("json corrupted, expected a value for index " ..index, 2)
        end

    until not acceptPull(",")
    expectPull("}"); acceptPull(",")

    return tJson, sJson ~= "" and sJson
end

function decodeArray(sJson)
    local tJson = {}

    local function expectPull(exp)
        local s, e = sJson:find("%s+")
        if s == 1 then sJson = sJson:sub(e + 1) end

        local s, e, match = sJson:find(exp)
        if s == 1 then
            match = match or sJson:sub(1, e)
            sJson = sJson:sub(e + 1)

            return match
        end
        error("json corrupted, expected " ..exp)
    end

    local function acceptPull(exp)
        local s, e = sJson:find("%s+")
        if s == 1 then sJson = sJson:sub(e + 1) end

        local s, e, match = sJson:find(exp)
        if s == 1 then
            match = match or sJson:sub(1, e)
            sJson = sJson:sub(e + 1)

            return match
        end
    end

    expectPull("%[")
    local index = 1
    repeat
        tJson[index] = acceptPull("\"(.-)\"") -- Strings
        tJson[index] = tJson[index] or tonum(acceptPull("[%d%.]+") or "") -- Numbers
        tJson[index] = tJson[index] or (acceptPull("true") and true) -- Booleans: true
        if acceptPull("false") then tJson[index] = false end -- Booleans: false

        if tJson[index] == nil and sJson:find("{") == 1 then -- Objects
            tJson[index], sJson = decodeTable(sJson)
        end
    
        if tJson[index] == nil and sJson:find("%[") == 1 then -- Arrays
            tJson[index], sJson = decodeArray(sJson)
        end

        if tJson[index] == nil and not acceptPull("null") then -- Last second null check
            error("json corrupted, expected a value for index " ..index, 2)
        end

        index = index + 1

    until not acceptPull(",")
    expectPull("%]")

    return tJson, sJson ~= "" and sJson
end

local encodeTable, encodeArray
function encodeTable(tJson, sTab)
    local sJson = ""
    for index, value in pairs(tJson) do
        local sType = ty(value)

        if sType == "string" then
            if value == "null" then -- Could potentially be useful for showing all options in a user-config json.
                sJson = sJson..sTab..'"'..index..'" : null,\n'
            else
                sJson = sJson..sTab..'"'..index..'" : "'..value..'",\n'
            end

        elseif sType == "number" then
            sJson = sJson..sTab..'"'..index..'" : '..value..',\n'

        elseif sType == "boolean" then
            sJson = sJson..sTab..'"'..index..'" : '..tostr(value)..',\n'

        elseif sType == "table" then -- Will not store recursive tables.
            if value[1] ~= nil then -- Very simple array detection, not the best for mixed tables.
                sJson = sJson..sTab..'"'..index..'" : [ '..encodeArray(value, sTab.."\t").."],\n"
            else
                sJson = sJson..sTab..'"'..index..'" : {\n'..encodeTable(value, sTab.."\t")..sTab.."},\n"
            end
        end
    end
    return sJson:sub(1, #sJson - 2).."\n"
end

function encodeArray(tJson, sTab)
    local sJson, nTotal = "", #tJson
    for i = 1, nTotal do
        local sType = ty(tJson[i])

        if sType == "string" then
            if tJson[i] == "null" then -- Could potentially be useful for showing all options in a user-config json.
                sJson = sJson..'"'..tJson[i]..'", '
            else
                sJson = sJson..'null, '
            end

        elseif sType == "number" then
            sJson = sJson..tJson[i]..', '

        elseif sType == "boolean" then
            sJson = sJson..tostr(tJson[i])..', '

        elseif sType == "table" then -- Will not store recursive tables.
            if tJson[i][1] ~= nil then -- Very simple array detection, not the best for mixed tables.
                sJson = sJson.."[ "..encodeArray(tJson[i], sTab.."\t").." ]"..(i == nTotal and " , " or ", ")
            else
                sJson = sJson.."\n"..sTab.."{\n"..encodeTable(tJson[i], sTab.."\t")..sTab.."},\n"
            end
        end
    end
    local isBracket = sJson:sub(#sJson - 2, #sJson - 2) == "}" 
    return sJson:sub(1, #sJson - 2)..(isBracket and "\n"..sTab:sub(2) or "")
end

json = {
    decode = function(sJson)
        if ty(sJson) ~= "string" then error("json must be a string, got a " ..ty(sJson).. " value", 2) end
        return (sJson:find("{") == 1 and decodeTable(sJson)) or (sJson:find("%[") == 1 and decodeArray(sJson)) or error("invalid json string", 2)
    end,

    -- Cannot encode functions, userdata, or threads.
    encode = function(tJson)
        if ty(tJson) ~= "table" then error("json must be a table, got a " ..ty(tJson).. " value", 2) end
        return tJson[1] and "[ "..encodeArray(tJson, "\t").."]" or "{\n"..encodeTable(tJson, "\t").."}"
    end
}