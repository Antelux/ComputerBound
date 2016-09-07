-- Load the speaker configuration.
local SpeakerConfig = {}
local dataPath = os.getenv("%DATA%") or ""
local sType = io.exists(dataPath.. "/sdcfg.json")

if sType == "file" then
    local file = fs.open(dataPath.. "/sdcfg.json", "r")
    local ok, tJson = pcall(json.decode, file:read("a")); file:close()
    if not ok then
         printError(dataPath.. "/sdcfg.json refers to an invalid JSON, recommending deletion or fixing of file.")
    
    elseif type(tJson) == "table" then
        for k, v in pairs(tJson) do
            SpeakerConfig[k] = v
        end
    end

elseif sType == "dir" then
    printError(dataPath.. "/sdcfg.json refers to a directory, recommending a path change.")

end

ss = {
	play = function(speaker, ...)

	end,

	setSpeakers = function(config)
		if type(config) == "table" then
			SpeakerConfig = config

			local file = fs.open(dataPath.. "/sdcfg.json", "w")
		    if file then
		        file:write(json.encode(osenv)):close()
		    end
		else
			error("config must be a table, got a " ..type(config).. " value", 2)
		end
	end,

	getSpeakers = function()
		local speakers = {}
		for k, v in pairs(SpeakerConfig) do
			speakers[k] = v
		end
		return speakers
	end
}