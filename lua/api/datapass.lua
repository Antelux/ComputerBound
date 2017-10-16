local temp = {}

dp = {
	set = function(name, data)
		temp[name] = data
	end,

	get = function(name)
		local data = temp[name]
		temp[name] = nil; return data
	end,
}