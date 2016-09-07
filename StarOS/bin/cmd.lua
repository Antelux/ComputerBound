term.setTextColor(colors.cyan)
print(os.getenv("OS").." v"..os.getenv("Version"))

shell = shell.new()
shell.setAlias("C:/bin")
shell.setAlias("C:/bin/shell")

local commandHistory = {}
while true do
	gpu.setColor(0, 0, 0); term.setBackColor(0, 0, 0)
    term.setTextColor(colors.magenta)
    term.write("% " ..shell.getWorkingDirectory().. " ")
    term.setTextColor(colors.white)

    local sLine = term.read( nil, commandHistory )
    table.insert( commandHistory, sLine )
    print(); shell.execute( sLine )
end