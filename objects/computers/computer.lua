----------------------------------------------------------------------------------------------------
-- Here we load a few necessary APIs, as well as establish a few functions.
----------------------------------------------------------------------------------------------------

require "/items/components/gpu/gpu.lua"
require "/items/components/soundchips/soundchip.lua"
require "/lua/bios.lua"; require "/lua/uuid.lua"

local ty, pairs = type, pairs
local function list(t, ind)
	local ind = ind or ""
	for k, v in pairs(t) do
		local t = (ty(v) ~= "table" and ty(v) ~= "thread" and ty(v) ~= "userdata" and ty(v) ~= "function") and " ("..ty(v)..")" or ""
		sb.logInfo(ind.."["..k.."]: " ..tostring(v).. t)
		if k ~= "_ENV" and k ~= "utf8" and k ~= "package" and k ~= "_G" and k ~= "storage"and k ~= "loaded" and ty(v) == "table" then 
			list(v, ind.."    ")
		end
	end
end

local function unload(t)
	if ty(t) ~= "table" then return nil end
	for k, v in pairs(t) do
		t[k] = ty(v) == "table" and (k ~= "_G" and unload(v)) or nil
	end
	return nil
end

local function copy(t)
	local newt = {}
	for k, v in pairs(t) do
		newt[k] = ty(v) == "table" and copy(v) or v
	end
	return newt
end

local computerIsOn = true
local computerReboot = false
local errorOccured = false
local isRunning = false

local Threads = {}
local totalMemory = 0

local MaxInputNodes 
local MaxOutputNodes
local MaxPort

local currentSound
local waitTime = 1
local entityID

----------------------------------------------------------------------------------------------------
-- EventQueue is pretty self explanitory; You can push events on to the queue, which are
-- later pulled to resume the current thread(s) at hand, making the thread(s) event-based.
----------------------------------------------------------------------------------------------------

local rem, unp = table.remove, table.unpack
local empty = {}

local EventQueue = {
	Push = function(self, t)
		local n = #self
		if n < 256 then
			self[n + 1] = t
			return true
		else
			return false
		end
	end,

	Pull = function(self)
		return unp(rem(self, 1) or empty)
	end
}

function pushEvent(sEvent, ...)
	if ty(sEvent) == "string" then
		EventQueue:Push({sEvent, ...})
	end
end

----------------------------------------------------------------------------------------------------
--	checkComponents() is used to see what's currrently inside the computer case.
--	Using it tells the computer what specs and APIs it will have and use.
----------------------------------------------------------------------------------------------------

local components
local function checkComponents()
	local Components = world.containerItems(entityID)
	local hasCPU, hasRAM; totalMemory = 0

	components = {list = {}}
	local function addComponent(c, a, f)
		components[c] = components[c] or {addresses = {}, drivers = {}}

		components[c][a] = f; components.list[a] = c
		components[c].addresses[#components[c].addresses + 1] = a
		components[c].drivers[#components[c].drivers + 1] = f
	end

	for i = 0, 8 do
		local component = Components[i + 1]
		if component then
			local isCPU = component.name:find("cpu"); hasCPU = hasCPU or isCPU
			local isGPU = component.name:find("gpu")
			local isRAM = component.name:find("ram"); hasRAM = hasRAM or isRAM
			local isSHD = component.name:find("harddrive")
			--soundchip = newSoundchipDriver(MaxInputNodes, MaxOutputNodes, animator),

			if isCPU then
				script.setUpdateDelta(root.assetJson("/items/components/cpu/"..component.name..".item").deltaTime or 3)
			elseif isRAM then
				totalMemory = totalMemory + root.assetJson("/items/components/ram/"..component.name..".item").memory * 1000
			end

			if isGPU or isSHD then
				local address = component.parameters.address
				if not address then
					address = newUUID()
					component.parameters.address = address
					world.containerTakeAt(entityID, i)
					world.containerPutItemsAt(entityID, component, i)
				end

				if isGPU then
					local bits = root.assetJson("/items/components/gpu/"..component.name..".item").bits
					addComponent("gpu", address, newGPU(MaxInputNodes, MaxOutputNodes, bits))
				
				elseif isSHD then
					if not component.parameters.description then
						component.parameters.description = address
						world.containerTakeAt(entityID, i)
						world.containerPutItemsAt(entityID, component, i)
					end
					--os.execute("mkdir Computer\\Storage\\" ..address)

					addComponent("storage", address, {
						getTotalSize = function()
							-- Return kb
						end
					})
				end
			end
		end
	end
	Components = nil

	return hasCPU and hasRAM
end

----------------------------------------------------------------------------------------------------
--	checkNodes() is used to see what objects and peripherals are currently connected to
--	the computer. It's used for the node API, the lowest level API there is for interacting
--	with objects and peripherals outside the computer. It is also called by the three functions
--	following checkNodes(), which themselves are called when there are changes made to the wiring.
----------------------------------------------------------------------------------------------------

local Nodes = {}
local function checkNodes()
	for i = 0, MaxInputNodes - 1 do
		if object.isInputNodeConnected(i) then
			local cNodes = object.getInputNodeIds(i)
			local cAmount, cEntity = 0

			for entity in pairs(cNodes) do
				cAmount = cAmount + 1
				cEntity = cEntity or entity
			end

			cNodes = unload(cNodes)
			Nodes[i] = cAmount == 1 and {world.callScriptedEntity(cEntity, "peripheralType", entityID) or "primitive", cEntity, i}
		else
			Nodes[i] = nil
		end
	end

	for i = 0, MaxOutputNodes - 1 do
		if object.isOutputNodeConnected(i) then
			local cNodes = object.getOutputNodeIds(i)
			local cAmount, cEntity = 0

			for entity in pairs(cNodes) do
				cAmount = cAmount + 1
				cEntity = cEntity or entity
			end

			cNodes = unload(cNodes)
			Nodes[i + MaxInputNodes] = cAmount == 1 and {world.callScriptedEntity(cEntity, "peripheralType", entityID) or "primitive", cEntity, i}
		else
			Nodes[i + MaxInputNodes] = nil
		end
	end
end

function onNodeConnectionChange() checkNodes() end
function onInputNodeChange() checkNodes(); EventQueue:Push({"node_input_change"}) end
function onOutputNodeChange() checkNodes(); EventQueue:Push({"node_output_change"}) end

----------------------------------------------------------------------------------------------------
-- createEnvironment() is used to create what's essentially the _G. table for the programs which
-- will run on the computer. Here is where hardware APIs, such as gpu and storage, as well as low
-- level APIs are implemented. This table is created once upon the computer starting up, and is
-- shared across all of it's threads/cores. It is completely unloaded once the computer shuts down.
----------------------------------------------------------------------------------------------------

local function verifyPort(nPort)
	if ty(nPort) ~= "number" then return end --error("port must be a number", 2) end
	if nPort < 0 or nPort > MaxPort then return end --error("port is out of range", 2) end
	return Nodes[nPort] and Nodes[nPort][1]
end

local Timers, t, m = {}, 0, math.maxinteger
local mouseX, mouseY = 0, 0; local Env

local function createEnvironment()
	--[[
		cpu = {
			getMaxThreads = function()

			end,

			getCurrentThread = function()
				-- Returns what thread is currently being executed.
			end,

			sendToThread = function(nThread, sEvent, ...)
				-- Sends an event to a specific thread.
			end,

			setThreadCode = function(nThread, sfCode)
				-- Sets the code for a specific thread,
				-- where code can be a string or function.
				--
				-- Doesn't work on the first thread.
			end,
		}
	--]]
	Env = { -- This will be responsible for adding in APIs that need access to internals or externals.
		components = copy(components),
		mouse = {
			getPosition = function()
				return mouseX, mouseY
			end
		},

		system = {
			restart = function()
				computerIsOn = false
				computerReboot = true
            end,

			shutdown = function()
				computerIsOn = false
            end,

            pushEvent = function(sEvent, ...)
            	if ty(sEvent) == "string" then
            		return EventQueue:Push({sEvent, ...})
            	end
            end,

            startTimer = function(nTime)
            	t = t + 1; t = t <= m and t or 1
            	Timers[t] = nTime; return t
            end,

            cancelTimer = function(nID)
            	Timers[ty(nID) == "number" and nID or -1] = nil
            end,

            playTone = function(nFrequency, nAmplitude, nDuration)
				local frequency = ty(nFrequency) == "number" and nFrequency
				local amplitude = ty(nAmplitude) == "number" and nAmplitude or 1
				local duration = ty(nDuration) == "number" and nDuration or 1
				
				frequency = frequency >= 20 and frequency <= 20000 and frequency / 100
				amplitude = amplitude >= -1 and amplitude <= 1 and amplitude * 0.5
				duration = duration > 0 and duration <= 5 and duration

				if not (frequency and amplitude and duration) then return end
				if currentSound then animator.stopAllSounds("100hz") end

				animator.setSoundPitch("100hz", frequency, 0)
				animator.setSoundVolume("100hz", amplitude, 0)
				animator.playSound("100hz", 0); currentSound = duration
				return true
			end,

			address = function()
				return storage.address
			end,

			-- CPU related
			updatesPerSecond = function()
				return 1//script.updateDt()
			end,

			threads = function()
				return #Threads
			end,

			--sendToThread()
			--setThreadCode()

			-- RAM related
			memoryUsage = function()
				return collectgarbage("count") - 18000
			end,

			freeMemory = function()
				return totalMemory - (collectgarbage("count") - 18000)
			end,

			totalMemory = function()
				return totalMemory
			end,

			-- Super secret function
            localTime = world.timeOfDay
		},

        node = {
        	list = function()
        		local nodeConnections = {}
        		for i = 0, MaxPort do
					nodeConnections[i] = Nodes[i] and Nodes[i][1]
				end
				return nodeConnections
        	end,

			getPort = function(sType)
				if ty(sType) ~= "string" then error("type must be a string", 2) end
				for i = 0, MaxPort do
					if Nodes[i] and Nodes[i][1] == sType then
						-- This can be improved by returning a table of all ports of sType.
						return i
					end
				end
			end,

			getType = function(nPort)
				return verifyPort(nPort)
			end,

			getInputRange = function()
				return MaxInputNodes - 1
			end,

			getMaxPort = function()
				return MaxPort
			end,

			setOutput = function(nPort, bActivated)
				if ty(bActivated) ~= "boolean" then error("activated must be a boolean", 2) end
				return verifyPort(nPort) == "primitive" and object.setOutputNodeLevel(Nodes[nPort][3], bActivated) and true
			end,

			getInput = function(nPort)
				return verifyPort(nPort) == "primitive" and object.getInputNodeLevel(Nodes[nPort][3])
			end,

			invoke = function(nPort, sFunction, ...)
				if ty(sFunction) ~= "string" then error("function name must be a string", 2) end
				if verifyPort(nPort) ~= "primitive" and Nodes[nPort] then
					local driver = world.callScriptedEntity(Nodes[nPort][2], "peripheralDriver", nPort)
					return sFunction == "getDriver" and driver or (driver[sFunction] and driver[sFunction](...))
				end
			end,

			bind = function(nPort)
				if verifyPort(nPort) ~= "primitive" and Nodes[nPort] then
					world.callScriptedEntity(Nodes[nPort][2], "peripheralBind", entityID)
				end
			end,

			address = function(nPort)
				if verifyPort(nPort) ~= "primitive" and Nodes[nPort] then
					return world.callScriptedEntity(Nodes[nPort][2], "peripheralAddress", entityID)
				end
			end
		}
	}
end

----------------------------------------------------------------------------------------------------
-- Create the peripheral for the computer.
----------------------------------------------------------------------------------------------------

function peripheralType()
	return "computer"
end

function peripheralAddress()
	return storage.address
end

function peripheralDriver()
	return {
		isRunning = function()
			return computerIsOn and isRunning
		end
	}
end

----------------------------------------------------------------------------------------------------
-- The init() function, when called on, assigns several values that are neccessary for the
-- computer to work correctly. It also sets the "queueEvent" message which, when called, will
-- put into queue any arguments it's given. It requires that the first argument be a string.
----------------------------------------------------------------------------------------------------

function init()
	--script.setUpdateDelta(1/60)
	entityID = entity.id()
	MaxInputNodes = object.inputNodeCount()
	MaxOutputNodes = object.outputNodeCount()
	MaxPort = MaxInputNodes + MaxOutputNodes - 1

	-- Make sure there are random values on each run.
	math.randomseed(os.time()); for i = 1, 10 do math.random() end
	storage.address = storage.address or newUUID()

	message.setHandler("pushEvent", function(_, _, sEvent, ...)
		if ty(sEvent) == "string" then
			EventQueue:Push({sEvent, ...})
		end
	end)

	message.setHandler("updateMouse", function(_, _, mx, my)
		mouseX, mouseY = ty(mx) == "number" and mx, ty(my) == "number" and my
	end)

	collectgarbage("stop")
end

----------------------------------------------------------------------------------------------------
-- The uninit() function simply clears some tables from memory.
----------------------------------------------------------------------------------------------------

function uninit()
	unload(Env); unload(EventQueue)
	unload(Timers); unload(Threads)
	collectgarbage(); collectgarbage()
end

----------------------------------------------------------------------------------------------------
-- resumeThreads() is self explanitory; it will only resume the threads if an event can be pulled
-- from the event queue. update() is also self explanitory; it updates the current state of the
-- computer, checking if everything is still connected, unloading parts of memory if need be, etc.
----------------------------------------------------------------------------------------------------

local function resumeThreads(ignoreQueue)
	if #EventQueue > 0 or ignoreQueue then -- Can potentially remove this.
		local ok, err = coroutine.resume(Threads[1], EventQueue:Pull())
		if not ok then 
			computerIsOn, errorOccured = false, err
			repeat local e = EventQueue:Pull() until not e
		end
		collectgarbage(); collectgarbage()
	end

	--if totalMemory - (collectgarbage("count") - 18000) <= 0 then
	--	computerIsOn, errorOccured = false, "out of memory"
	--	repeat local e = EventQueue:Pull() until not e
	--end
end

function update(dt)
	if waitTime then
		waitTime = waitTime - dt
		if waitTime <= 0 then waitTime = false end

	else
		if computerIsOn then
			if isRunning then
				currentSound = currentSound and currentSound - dt
				if currentSound and currentSound <= 0 then
					animator.stopAllSounds("100hz")
					currentSound = nil
				end

				for k, v in pairs(Timers) do
					if v then 
						Timers[k] = v - dt
						if Timers[k] <= 0 then
							EventQueue:Push({"timer", k})
							Timers[k] = nil
						end
					end
				end

				resumeThreads()
				if errorOccured then
					computerIsOn = false
				end

			elseif checkComponents() then
				checkNodes(); createEnvironment(); isRunning = true
				Threads[1] = newThread(Env, sb.makeRandomSource(42))
				currentSound = nil; resumeThreads(true)

			else
				computerIsOn = false

			end

		else
			if isRunning then
				unload(Env); unload(Timers); isRunning = false
				unload(Threads); collectgarbage(); collectgarbage()
				animator.stopAllSounds("100hz")

				if computerReboot then
					computerIsOn = true
					computerReboot = false
				end
			end

			if errorOccured then
				error(errorOccured)
				--object.say(errMessage)
			end
		end
	end
end