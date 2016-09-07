print("The following drives are registered:\n")
term.setTextColor(colors.azurer)
for label, device in pairs(io.getLabels()) do
	print(label.. ":/ - " ..device)
end