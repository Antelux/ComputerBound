local cconfig 

cstorage = {
	setConfig = function(c)
		if not cconfig then
			cconfig = c.components.storage
		end
	end,

	new = function(item_name)
		if cconfig[item_name] then

		else
			return "no such storage device named '" .. tostring(item_name) .. "'"
		end
	end
}