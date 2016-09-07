print("CPU: " ..system.updatesPerSecond().. "UPs @ " ..system.threads().. " thread(s)")
print("Total RAM installed: " ..system.totalMemory().. "kb")
print("GPU: ")
for i = 1, #components.gpu.drivers do
	print("\t"..components.gpu.addresses[i]:sub(1, 8).. ": " ..components.gpu.drivers[i].totalChannelBits().. " bit color")
end