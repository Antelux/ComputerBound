for component, addresses in pairs(components) do
	local addresses = addresses.addresses
	
	if addresses then
		term.setTextColor(colors.white)
		print(component.. ":")
		term.setTextColor(colors.azurer)
		for i = 1, #addresses do
			print("\t"..addresses[i])
		end
	end
end