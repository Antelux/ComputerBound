local maxInputPort = node.getInputRange()

term.setTextColor(colors.blue)
print("Input Nodes:")
for i = 0, maxInputPort do
	local sType = node.getType(i) or "No connection."
	term.setTextColor(colors.blue); term.write("Port " ..i.. ": ")
	term.setTextColor(colors.white); print(sType)
end

term.setTextColor(colors.red)
print("\nOutput Nodes:")
for i = maxInputPort + 1, node.getMaxPort() do
	local sType = node.getType(i) or "No connection."
	term.setTextColor(colors.red); term.write("Port " ..i.. ": ")
	term.setTextColor(colors.white); print(sType)
end