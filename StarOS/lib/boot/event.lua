local TimerFunctions, smt, clock = {}, setmetatable, os.clock; TimerFunctions.__index = TimerFunctions

-- Maybe add Timer.start() and Timer.stop() ?
TimerFunctions.elapsedTime = function(self) return clock() - self[1] end
TimerFunctions.wentOff = function(self) return self[2] <= clock() - self[1] end
TimerFunctions.restart = function(self) self[1] = clock() end

local unpack = table.unpack
local yield = coroutine.yield
event = {
    pull = function(...)
    	local filters = {...}
    	local amount = #filters

    	if amount >= 1 then
	        local events
	        
	        while true do
	            events = {yield()}; local sEvent = events[1]
	            if sEvent == "terminate" then error("terminated") end

	            for i = 1, amount do
	            	if sEvent == filters[i] then
	            		filters = nil
	            		return unpack(events, amount == 1 and 2 or 1)
	            	end
	            end
	        end	    
	    else
			return yield()
		end
    end,

    push = system.pushEvent,

    timer = function(nTime)
    	return smt({clock(), nTime}, TimerFunctions)
    end,
    
    -- safe sleep
    sleep = function(nTime)
	    if type(nTime) ~= "number" then error("time must be a number", 2) end
	    if nTime <= 0 then return end

	    local timer, events = system.startTimer(nTime)
	    while true do
	    	events = {yield()}
	    	if events[1] == "timer" and events[2] == timer then break end
	    	system.pushEvent(unpack(events))
	    end
	    events = nil
	end,

    -- Should be used by background processes and alike.
    listen = function(...)
    	local filters = {...}; local amount = #filters
    	if amount == 0 then error("must supply string event names to listen for", 2) end
        local events = {yield()}; local sEvent = events[1]

        for i = 1, amount do
        	if sEvent == filters[i] then
        		filters = nil
        		return unpack(events, amount == 1 and 2 or 1)
        	end
        end

        system.pushEvent(events)
    end
}