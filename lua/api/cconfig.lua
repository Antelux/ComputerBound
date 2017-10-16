--[[
    
    This is a small API I've made called Centralized Configurations.
    It works similar to the standard Starbound config API, but with
    the difference that you can keep all your config files in one
    folder called "config."

    How useful is it? Well, it doesn't add any sort of performance
    benefits (in fact, since it's in Lua, it should be slower). The
    main benefit here is organization and ease of configuring the
    mod for server owners or even just single player.

    Is it worth writing an entire API for? That's what I'm going
    to find out by putting it to use. If it doesn't help out too
    much, I'll just switch to the default config API.

--]]

local loaded = {}
local configs = {}
local root

local function copyJson(path, json)
    for key, value in pairs(json) do
        if type(value) == "table" then
            copyJson(path .. "." .. key, value)
        end
        configs[path .. "." .. key] = value
    end
end

cconfig = {
    root = function(r)
        root = root or r
    end,

    get = function(parameter, default)
        if type(parameter) ~= "string" then 
            error("parameter: string expected, got a " .. type(path) .. " value instead", 2) 
        end

        local data = configs[parameter]
        if data then return data end

        local s, e = string.find(parameter, "%.")
        local path = string.sub(parameter, 1, s and s - 1 or #parameter)
        local configPath = "/config/" .. path .. ".config"

        if not loaded[configPath] then
            local ok, Json = pcall(root.assetJson, configPath)
            if ok then
                copyJson(path, Json); configs[path] = Json
                sb.logInfo("[CConfig] [Info] Loaded configuration from '" .. configPath .. "' successfully.")
            else
                sb.logInfo("[CConfig] [Warn] Unable to load configuration from '" .. configPath .. "'; " .. tostring(Json)) 
            end

            loaded[configPath] = true
        end
        
        return configs[parameter] or default
    end
}