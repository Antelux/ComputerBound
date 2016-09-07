require "/lua/uuid.lua"

local bindedComputer
function init()
	storage.address = storage.address or newUUID()
	message.setHandler("getID", function() return bindedComputer end)
	message.setHandler("getBind", function() return true end)
end

function bind(f)
	message.setHandler("getBind", f)
end

function getSize()
	return {config.getParameter("width"), config.getParameter("height")}
end

-------------------------------------------------------------------------------

function peripheralType()
	return "monitor"
end

function peripheralBind(computerID)
	bindedComputer = computerID
end

function peripheralAddress()
	return storage.address
end

function peripheralDriver()
	return {
		getResolution = function()
			return config.getParameter("width"), config.getParameter("height")
		end,

		setResolutionScale = function(scale)
			-- For now, the value can only be 1 or 2.
			-- Once done, the GPU must be binded again to the monitor.
		end,

		getResolutionScale = function(scale)

		end,
	}
end