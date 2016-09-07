local sFile = ...; sFile = sFile and (shell.resolvePath(sFile) or shell.getWorkingDirectory()..sFile)
if not sFile then return printError("path expected") end; local fileType = io.exists(sFile)
if fileType == "dir" then return printError("cannot edit a directory") end

local file = fs.open(sFile, "r")
local code, i = {""}, 0

if file then
	repeat
		local line = file:read("l"); i = i + 1
		code[i] = line and line:gsub("\t", "    ")
	until not code[i]
end

local Width, Height = term.getSize()
local hWidth, hHeight = math.floor(Width/2+0.5), math.floor(Height/2-0.5)
local xCursor, yCursor = 0, 0

local keywords = {"local", "function", "while", "repeat", "until", "do", "if", "elseif", "else", "then", "end", "for", "in", "return", "break"} 
local keywordops = {"and", "or", "not"}; local booleans = {"true", "false", "nil"}
for i = 1, #keywords do keywords[keywords[i]] = true end
for i = 1, #keywordops do keywordops[keywordops[i]] = true end
for i = 1, #booleans do booleans[booleans[i]] = true end

local sub = string.sub
local find = string.find
local Highlight
local function matchWrite(line, regex, color, func)
	local match = string.match(line, regex)
	if match then
		line = sub(line, #match + 1)
		if func then
			term.setTextColor(func(match))
		else
			term.setTextColor(color)
		end

		if Highlight then
			local s, e = find(match, Highlight)
			if s then
				term.write(sub(match, 0, s - 1))
				term.setBackColor(colors.yellow)
				term.write(sub(match, s, e))
				term.setBackColor(colors.black)
				term.write(sub(match, e + 1))
			else
				term.write(match)
			end
		else
			term.write(match)
		end

		return line
	end
end

local function drawText(sLine)
	while #sLine ~= 0 do
		-- Comments
		local match = string.match(sLine, "^%-%-")
		if match then
			term.setTextColor(colors.blue)
			term.write(sLine); break
		end

		local nLine =
			-- Whitespace
			matchWrite(sLine, "^%s+", colors.black) or

			-- Symbols
			matchWrite(sLine, "^[|&</>=~#%+%-%*%%]+", colors.iorange) or
			matchWrite(sLine, "^%.%.[%.]*", colors.iorange) or

			-- Strings
			matchWrite(sLine, "^\".-[^\\]\"", colors.green) or
			matchWrite(sLine, "^\'.-[^\\]\'", colors.green) or

			-- Numbers
			matchWrite(sLine, "^0x[%x]+", colors.red) or
			matchWrite(sLine, "^%d[%d%.]*", colors.red) or

			-- Identifers or Keys
			matchWrite(sLine, "^[%w_]+", _, function(match)
				if keywords[match] then
					return colors.azurer
				elseif keywordops[match] then
					return colors.bribbon
				elseif booleans[match] then
					return colors.worange
				else
					return colors.white
				end
			end) or

			-- Ordinary symbols
			matchWrite(sLine, "^[%.%[%]%(%){}:;,]+", colors.white)

		if nLine then sLine = nLine else
			term.setTextColor(colors.white)
			term.write(sLine); break
		end
	end
end

local displayBlinker = false
local footerMessage = "Press Cntrl+H to access help menu."
local function redraw()
	gpu.clear(0)

	local offy = yCursor < hHeight and 0 or yCursor - hHeight
	local offy = offy > #code - 1 and #code - 1 or offy
	local offx = xCursor < hWidth and 0 or xCursor - hWidth
	local spacing = #tostring(Height + offy - 1)

	for y = 1, Height - 1 do
		if code[y + offy] then
			term.setCursorPos(spacing - offx + 2, y); drawText(code[y + offy])
			term.setCursorPos(1, y); term.setTextColor(colors.cyan)
			term.write((y + offy) .. string.rep(" ", spacing - #tostring(y + offy) + 1))
		end
	end

	gpu.setColor(colors.white)
	gpu.rectangle((spacing + 1) * 6 - 3, 1, 1, Height * 10)

	if displayBlinker then
		gpu.rectangle((spacing + 1 + (xCursor < hWidth and xCursor or hWidth)) * 6 + 1, (yCursor < hHeight and yCursor or hHeight) * 10 + 1, 5, 10, colors.white)
	end

	term.setCursorPos(1, Height)
	term.setTextColor(colors.yellow)
	term.write(footerMessage)
end

local Menu = {
	"List of available shortcuts:",
	"Save",	"^S", "Run ", "^R",
	"Exit",	"^E", "Goto", "^G",
	"Find", "^F", "Help", "^H"
}

local bTimer = system.startTimer(0.5)
local isShifting = false
local isCntrling = false
local isInsing = false

redraw()
while true do
	local eType, arg1, arg2 = event.pull("key", "timer")

	if eType == "key" then
		if arg1 == keys.lShift or arg1 == keys.rShift then isShifting = arg2 and arg1 end
		if arg1 == keys.lCntrl or arg1 == keys.rCntrl then isCntrling = arg2 and arg1 end
		local key = isShifting and (arg1 ~= isShifting and arg1 + 200) or arg1
		local line = yCursor + 1

		if isCntrling then
			if arg2 then
				if key == keys.s then
					local ok, file = pcall(fs.open, sFile, "w")
					if not ok then 
						local err = file:match("%[.+%]:%d+: (.+)")
						err = err:sub(1, 1):upper()..err:sub(2)..(err:sub(#err) ~= "." and "." or "")
						footerMessage = err
					else
						for i = 1, #code do file:write(code[i]:gsub("    ", "\t").."\n") end; file:close()
						footerMessage = 'Saved to "' ..sFile.. '" ('..os.date("%H:%M %p")..")."
					end

				elseif key == keys.r then
					displayBlinker = false
					system.cancelTimer(bTimer)
					term.setCursorPos(1, 1)
					gpu.clear(0)

					local ok, err = load(table.concat(code, "\n"), sFile, "t", _G)
					if ok then ok, err = pcall(ok) end

					if not ok then
						term.setCursorPos(1, 1); gpu.clear(0)
						term.setTextColor(colors.white)
						print("An error has occured:")
						printError(err)
						print("Press any key to continue.")
						while true do
							local k, i = event.pull("key")
							if i then break end
						end
					else
						footerMessage = "File ran successfully."
					end
					bTimer = system.startTimer(0.5)


				elseif key == keys.e then
					gpu.clear(0)
					term.setCursorPos(1, 1)
					break

				elseif key == keys.g then
					displayBlinker = false
					system.cancelTimer(bTimer)
					footerMessage = "Goto: "; redraw()

					term.setTextColor(colors.white)
					local line = tonumber(term.read())

					if line then
						if code[line] then
							xCursor, yCursor = 0, line - 1
							footerMessage = "Jumped to line " ..line.. "."
						else
							footerMessage = "Line " ..line.. " is out of range."
						end
					else
						footerMessage = "Line must be a number."
					end
					bTimer = system.startTimer(0.5)

				elseif key == keys.f then
					displayBlinker = false
					system.cancelTimer(bTimer)
					footerMessage = "Find: "
					redraw(); Highlight = nil

					term.setTextColor(colors.white)
					local smatch = term.read()
					for i = yCursor + 1, #code do
						local s = string.find(code[i], smatch)
						if s then
							footerMessage = 'Arrow keys to navigate, "f" to go back.'
							xCursor, yCursor = s - 1, i - 1
							Highlight = smatch; break
						end
					end

					if Highlight then
						redraw()
						while true do
							local key, isDown = event.pull("key")
							if isDown then
								if key == keys.up then
									for i = yCursor - 1, 1, -1 do
										local s = string.find(code[i], smatch)
										if s then
											xCursor, yCursor = s - 1, i - 1
											redraw(); break
										end
									end

								elseif key == keys.down then
									for i = yCursor + 2, #code do
										local s = string.find(code[i], smatch)
										if s then
											xCursor, yCursor = s - 1, i - 1
											redraw(); break
										end
									end

								elseif key == keys.f then
									footerMessage = "Press cntrl+H to access help menu."
									break
								end
							end
						end
					else
						footerMessage = "No matches found."
					end
					system.pushEvent("key", keys.lCntrl, false)
					system.pushEvent("key", keys.rCntrl, false)
					bTimer = system.startTimer(0.5); Highlight = nil

				elseif key == keys.h then
					displayBlinker = false
					system.cancelTimer(bTimer)
					footerMessage = "Press anything to continue."
					redraw()

					local x = hWidth - (#Menu[1] / 2)
					local ey = Height*0.75//1

					gpu.rectangle((x-1)*6, 10, #Menu[1] * 6 + 2, 81, colors.white)
					gpu.rectangle((x-1)*6+1, 11, #Menu[1] * 6, 79, colors.black)

					term.setTextColor(colors.cyan)
					term.write(Menu[1], x, 2)
					for i = 2, 12, 2 do
						term.setTextColor(colors.cyan)
						term.write(Menu[i].."\t\t", hWidth - 7, ey - i // 2)
						term.setTextColor(colors.white)
						term.write(Menu[i + 1])
					end

					while true do
						local k, i = event.pull("key")
						if i then break end
					end

					footerMessage = "Press cntrl+H to access help menu."
					bTimer = system.startTimer(0.5)
				end
			end

		elseif arg2 then
			if keys[key] then
				if isInsing then
					code[line] = code[line]:sub(1, xCursor + 1) .. keys[key] .. code[line]:sub(xCursor + 3)
				else
					code[line] = code[line]:sub(1, xCursor) .. keys[key] .. code[line]:sub(xCursor + 1)
		            xCursor = xCursor + 1
		        end

			elseif key == keys.up then
				yCursor = yCursor - 1; displayBlinker = true
				if code[line - 1] and xCursor > #code[line - 1] then
					xCursor = #code[line - 1]
				end
			
			elseif key == keys.down then
				yCursor = yCursor + 1; displayBlinker = true
				if code[line + 1] and xCursor > #code[line + 1] then
					xCursor = #code[line + 1]
				end
			
			elseif key == keys.left then
				xCursor = xCursor - 1
				displayBlinker = true
				if xCursor < 0 then
					xCursor, yCursor = code[yCursor] and #code[yCursor] or 0, yCursor - 1
				end
			
			elseif key == keys.right then
				xCursor = xCursor + 1
				displayBlinker = true
				if xCursor > #code[line] then
	        		xCursor, yCursor = 0, yCursor + 1
	        	end

			elseif key == keys.enter then
				table.insert(code, line + 1, code[line]:sub(xCursor + 1))
				code[line] = code[line]:sub(1, xCursor)
				xCursor, yCursor = 0, yCursor + 1

			elseif key == keys.tab then
				code[line] = code[line]:sub(1, xCursor) .. "    " .. code[line]:sub(xCursor + 1)
	            xCursor = xCursor + 4
	                            
	        elseif key == keys.bSpace then
	        	if xCursor == 0 then
	        		if yCursor ~= 0 then
	        			xCursor = #code[yCursor]
	        			code[yCursor] = code[yCursor] .. table.remove(code, line)
	        			yCursor, line = yCursor - 1, line - 1
	        		end
	        	else
		        	code[line] = code[line]:sub(1, xCursor - 1) .. code[line]:sub(xCursor + 1)
		            xCursor = xCursor - 1
		        end

		    elseif key == keys.ins then
		    	isInsing = not isInsing

	        elseif key == keys.del then
	            code[line] = code[line]:sub(1, xCursor) .. code[line]:sub(xCursor + 2)

	        end

			yCursor = (yCursor < 0 and 0) or (yCursor > #code - 1 and #code - 1) or yCursor
		end

		redraw()

	elseif eType == "timer" and arg1 == bTimer then
		bTimer = system.startTimer(0.5)
		displayBlinker = not displayBlinker
		redraw()
	end
end