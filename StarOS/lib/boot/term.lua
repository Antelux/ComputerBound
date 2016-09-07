local ty = type
local ins = table.insert
local rem = table.remove

local Width, Height = gpu.getSize()
Width, Height = Width // 6, Height // 10

local OriginX, OriginY = 1, 1
local CursorX, CursorY = 1, 1

local TextColor = 0xFFFFFF
local BackColor = 0x000000

local TermStates = {}

term = {
    setCursorPos = function(x, y)
        CursorX = ty(x) == "number" and OriginX + x - 1 or CursorX
        CursorY = ty(y) == "number" and OriginX + y - 1 or CursorY
    end,

    getCursorPos = function()
        return CursorX, CursorY
    end,

    offsetCursorPos = function(ox, oy)
        CursorX = CursorX + (ty(ox) == "number" and ox or 0)
        CursorY = CursorY + (ty(oy) == "number" and oy or 0)
    end,

    setOrigin = function(bx, by)
        OriginX = ty(x) == "number" and x or OriginX
        OriginY = ty(y) == "number" and y or OriginY
    end,

    getOrigin = function()
        return OriginX, OriginY
    end,

    setSize = function(nw, nh)
        Width = ty(nw) == "number" and nw or Width
        Height = ty(nh) == "number" and nh or Height
    end,

    getSize = function()
        return Width - OriginX + 1, Height - OriginY + 1
    end,

    setTextColor = function(color)
        TextColor = ty(color) == "number" and color or TextColor
    end,

    setBackColor = function(color)
        BackColor = ty(color) == "number" and color or BackColor
    end,

    push = function(...)
        if ... then
            local args = {...}
            for i = 1, #args do args[args[i]] = true end

            ins(TermStates, 1, {
                args.origin and OriginX, args.origin and OriginY, 
                args.cursor and CursorX, args.cursor and CursorY, 
                args.size and Width, args.size and Height,
                args.color and TextColor, args.color and BackColor
            }); args = nil

        else
            ins(TermStates, 1, {
                OriginX, OriginY, 
                CursorX, CursorY, 
                Width, Height,
                TextColor, BackColor
            })
        end
    end,

    pop = function()
        local state = rem(TermStates, 1)
        if state then
            OriginX, OriginY = state[1] or OriginX, state[2] or OriginY
            CursorX, CursorY = state[3] or CursorX, state[4] or CursorY
            Width, Height = state[5] or Width, state[6] or Height
            TextColor, BackColor = state[7] or TextColor, state[8] or BackColor
        end
    end,

    scroll = function(amount)
        local Color = gpu.getColor()
        gpu.setColor(BackColor)
        gpu.offset(_, amount * 10)
        gpu.setColor(Color)
    end,

    write = function(sText, nx, ny)
        if CursorY < OriginX or CursorY > Height or CursorX > Width then return end
        if ty(sText) ~= "string" then return end; term.setCursorPos(nx, ny)
        local Color = gpu.getColor(); gpu.setColor(TextColor)

        for i = 1, #sText do
            if CursorX > Width then return gpu.setColor(Color) end

            local sChar = sText:sub(i, i)
            if sChar == "\t" then
                gpu.rectangle((CursorX - 1) * 6 + 1, (CursorY - 1) * 10 + 1, 24, 10, BackColor)
                CursorX = CursorX + 4

            elseif sChar == "\n" then
                CursorY = CursorY + 1
                if CursorY > Height then
                    CursorX = OriginX; CursorY = Height
                    gpu.setColor(Color); gpu.offset(_, 10)
                    gpu.setColor(TextColor)
                end

            else
                local fChar = font[sChar] or font["?"]
                local cx, cy = (CursorX - 1) * 6 + 1, (CursorY - 1) * 10 + 1
                gpu.rectangle(cx, cy, 6, 10, BackColor)
                gpu.drawTexture(fChar, cx, cy + (fChar.offset or 0), 5, 7) --font.width, font.height)
                CursorX = CursorX + 1
            end
        end
        gpu.setColor(Color)
    end,

    -- Totally didn't steal the read() function from ComputerCraft.
    read = function( _sReplaceChar, _tHistory )
        local sLine, nPos, nHistoryPos = "", 0
        _sReplaceChar = type(_sReplaceChar) == "string" and _sReplaceChar:sub(1, 1)
        
        local x, y = CursorX, CursorY
        local isBlinking = false

        local function redraw( _sCustomReplaceChar )
            local nScroll = 0
            if x + nPos >= Width then
                nScroll = (x + nPos) - Width
            end

            CursorX, CursorY = x, y
            local sReplace = _sCustomReplaceChar or _sReplaceChar
            if sReplace then
                term.write( string.rep( sReplace, math.max( string.len(sLine) - nScroll, 0 ) ) )
            else
                term.write( string.sub( sLine, nScroll + 1 ) )
            end

            CursorX, CursorY = x + nPos < Width - 1 and x + nPos or Width - 1, y
            if isBlinking then
                gpu.rectangle((CursorX - 1) * 6 + 1, (CursorY - 1) * 10 + 1, 5, 10, TextColor)

            elseif nPos == #sLine or CursorX == Width - 1 then
                gpu.rectangle((CursorX - 1) * 6 + 1, (CursorY - 1) * 10 + 1, 5, 10, BackColor)
            end
        end
        
        local isShifting = false
        local bTimer = system.startTimer(0.5)
        while true do
            local event, key, isDown = event.pull()

            if event == "key" then
                if key == keys.lShift or key == keys.rShift then isShifting = isDown and key end
                if isDown then
                    key = isShifting and (key ~= isShifting and key + 200) or key
                    if keys[key] then
                        sLine = string.sub( sLine, 1, nPos ) .. keys[key] .. string.sub( sLine, nPos + 1 )
                        nPos = nPos + 1
                        redraw()

                    elseif key == keys.enter then
                        break
                        
                    elseif key == keys.left then
                        if nPos > 0 then
                            gpu.rectangle(((x + nPos < Width - 1 and x + nPos or Width - 1) - 1) * 6 + 1, (y - 1) * 10 + 1, 6, 10, BackColor)
                            nPos = nPos - 1; redraw(); isBlinking = true
                        end
                        
                    elseif key == keys.right then
                        if nPos < string.len(sLine) then
                            redraw(" "); nPos = nPos + 1
                            redraw(); isBlinking = true
                        end
                    
                    elseif key == keys.up or key == keys.down then
                        if _tHistory then
                            redraw(" ")
                            if key == keys.up then
                                if nHistoryPos == nil then
                                    if #_tHistory > 0 then
                                        nHistoryPos = #_tHistory
                                    end
                                elseif nHistoryPos > 1 then
                                    nHistoryPos = nHistoryPos - 1
                                end
                            else
                                if nHistoryPos == #_tHistory then
                                    nHistoryPos = nil
                                elseif nHistoryPos ~= nil then
                                    nHistoryPos = nHistoryPos + 1
                                end                        
                            end
                            if nHistoryPos then
                                sLine = _tHistory[nHistoryPos]
                                nPos = string.len( sLine ) 
                            else
                                sLine = ""
                                nPos = 0
                            end
                            redraw()
                        end

                    elseif key == keys.bSpace then
                        if nPos > 0 then
                            redraw(" ")
                            gpu.rectangle(((x + nPos < Width - 1 and x + nPos or Width - 1) - 1) * 6 + 1, (y - 1) * 10 + 1, 6, 10, BackColor)
                            sLine = string.sub( sLine, 1, nPos - 1 ) .. string.sub( sLine, nPos + 1 )
                            nPos = nPos - 1; redraw(); if isBlinking then term.write(" ") end
                        end

                    elseif key == keys.del then
                        if nPos < string.len(sLine) then
                            redraw(" ")
                            sLine = string.sub( sLine, 1, nPos ) .. string.sub( sLine, nPos + 2 )                
                            redraw()
                        end

                    elseif key == keys["end"] then
                        redraw(" ")
                        nPos = string.len(sLine)
                        redraw()
                    end
                end

            elseif event == "timer" and key == bTimer then
                bTimer = system.startTimer(0.5)
                isBlinking = not isBlinking

                redraw()
            end
        end

        isBlinking = false
        system.cancelTimer(bTimer)
        redraw()

        return sLine
    end
}

-- Totally didn't rip functions from the CC Bios.
function write( sText, nX, nY )
    local nLinesPrinted = 0
    local function newLine()
        if CursorY < Height then
            CursorX, CursorY = OriginX, CursorY + 1
        else
            CursorX, CursorY = OriginX, Height
            term.scroll(1)
        end
        nLinesPrinted = nLinesPrinted + 1
    end
    
    -- Print the line with proper word wrapping
    while string.len(sText) > 0 do
        local whitespace = string.match( sText, "^[ \t]+" )
        if whitespace then
            -- Print whitespace
            term.write( whitespace )
            sText = string.sub( sText, string.len(whitespace) + 1 )
        end
        
        local newline = string.match( sText, "^\n" )
        if newline then
            -- Print newlines
            newLine()
            sText = string.sub( sText, 2 )
        end
        
        local text = string.match( sText, "^[^ \t\n]+" )
        if text then
            sText = string.sub( sText, string.len(text) + 1 )
            if string.len(text) > Width then
                -- Print a multiline word                
                while string.len( text ) > 0 do
                    if CursorX > Width then
                        newLine()
                    end
                    term.write( text )
                    text = string.sub( text, (Width-CursorX) + 2 )
                end
            else
                -- Print a word normally
                if CursorX + string.len(text) - 1 > Width then
                    newLine()
                end
                term.write( text )
            end
        end
    end
    
    return nLinesPrinted
end

-- Combine the above and below functions into print()
function print( ... )
    local nLinesPrinted = 0
    for n,v in ipairs( { ... } ) do
        nLinesPrinted = nLinesPrinted + write( tostring( v ) )
    end
    nLinesPrinted = nLinesPrinted + write( "\n" )
    return nLinesPrinted
end

function printError(sText)
    term.push("color")
    term.setTextColor(0xFF0000)
    print(sText)
    term.pop()
end

-- Add in some io functions.
io.stdin = term.read
io.stdout = term.write
io.stderr = printError