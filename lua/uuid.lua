-- I always wondered why OpenComputers used this system. Now I understand. =P
function newUUID()
    local uuid = {[9]="-",[14]="-",[19]="-",[24]="-"}
    for i = 1, 36 do
    	uuid[i] = uuid[i] or string.format("%x", math.random(0, 15))
    end
    return table.concat(uuid)
end