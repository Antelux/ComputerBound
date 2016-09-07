local aliases = shell.getAlias()
local list, i = {}, 1
for alias in pairs(aliases) do
	list[i] = alias; i = i + 1
end

term.setTextColor(colors.blue)
print(table.concat(list, "  "))
aliases, list = nil, nil