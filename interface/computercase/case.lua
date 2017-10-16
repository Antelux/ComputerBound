----------------------------------------------------------------------------------------------------
-- Initialize local variables.
----------------------------------------------------------------------------------------------------

local ComputerID
local canBoot = false
local lastErr

local pairs = pairs
local remove = table.remove

local storage = {}
local promises = {}

local function getErrorMessage()
	local errorMessage = ""

	if not storage["cpuSlot1"] then
		errorMessage = errorMessage .. "Missing CPU Component!\n"
	end

	if not storage["ramSlot1"] then
		errorMessage = errorMessage .. "Missing RAM Component!\n"
	end

	if not storage["storageSlot1"] and not storage["diskSlot1"] then
		errorMessage = errorMessage .. "Missing storage medium to boot from!\n"
	end

	if errorMessage == "" then
		widget.setText("scrollArea.text", "Press the power or restart button to turn on your computer!")
		canBoot = true
	else
		widget.setText("scrollArea.text", "Error(s):\n" .. errorMessage)
		canBoot = false
	end
end

local function newPromise(onCompletion, request, ...)
	promises[#promises + 1] = {world.sendEntityMessage(ComputerID, request, ...), onCompletion}
end

----------------------------------------------------------------------------------------------------
-- Set up the tool tips, aka the description that's shown when the mouse hovers over a widget.
----------------------------------------------------------------------------------------------------

local ToolTipLayout = {
	background = {
      type = "background",
      fileHeader = "",
      fileBody = "/interface/computercase/tooltip.png",
      fileFooter = ""
    },

    title = {
      type = "label",
      position = {2, 10},
      hAnchor = "left",
      vAnchor = "top",
      wrapWidth = 100,
      fontSize = 8
    }
}

local ToolTips = {
	cpuSlot1 = "CPU Slot",

	gpuSlot1 = "GPU Slot",

	ramSlot1 = "RAM Slot",
	ramSlot2 = "RAM Slot",
	ramSlot3 = "RAM Slot",
	ramSlot4 = "RAM Slot",

	storageSlot1 = "Storage Slot",
	storageSlot2 = "Storage Slot",
	storageSlot3 = "Storage Slot",
	storageSlot4 = "Storage Slot",

	diskSlot1 = "Disk Slot",
	diskSlot2 = "Disk Slot",
	diskSlot3 = "Disk Slot",
	diskSlot4 = "Disk Slot",

	expansionSlot1 = "Expansion Slot",
	expansionSlot2 = "Expansion Slot",
	expansionSlot3 = "Expansion Slot",
	expansionSlot4 = "Expansion Slot",

	["buttons.0"] = "Power Button",
	["buttons.1"] = "Reset Button"
}

----------------------------------------------------------------------------------------------------
-- 
----------------------------------------------------------------------------------------------------

function createTooltip(screenPosition)
	for widgetName, description in pairs(ToolTips) do
	    if widget.inMember(widgetName, screenPosition) then
	    	ToolTipLayout.title.position[1] = 35 - (#description*4)/2
	    	ToolTipLayout.title.value = description

	    	return ToolTipLayout
	    end
	end
end

----------------------------------------------------------------------------------------------------
-- 
----------------------------------------------------------------------------------------------------

local function putInItemSlot(widgetName, item)
	-- Give the component an address if it doesn't have one.
	if not item.parameters.address then
		local address = sb.makeUuid()
		item.parameters.address = string.sub(address, 1, 8) .. "-" .. string.sub(address, 9, 12) .. "-" .. string.sub(address, 13, 16) .. "-" .. string.sub(address, 17, 20) .. "-" .. string.sub(address, 21)
	end
	item.count = 1 -- Amount of the component we want to remove from the player's inventory.

	player.consumeItem(item) -- Take the item away from the player.
	newPromise(function()
		storage[widgetName] = item -- Store the item in memory.
		widget.setItemSlotItem(widgetName, item) -- Set the item slot to have said item.
		getErrorMessage() -- Tell the user what components are still needed.
	end, "storageSet", widgetName, item)
end

local function takeFromItemSlot(widgetName)
	local Item = storage[widgetName]
	
	if Item then
		newPromise(function()
			player.giveItem(Item) -- Give the item back to the player.
			storage[widgetName] = nil -- Remove the item from memory.
			widget.setItemSlotItem(widgetName, nil) -- Remove the item visually.
			getErrorMessage() -- Tell the user what components are still needed.
		end, "storageSet", widgetName, nil)
	end

	getErrorMessage()
end

-- These functions are probably a bit inefficient but it'll do for now.
function cpuSlotModifier(widgetName)
	if not widget.getChecked("buttons.0") then -- Only continue if the computer is off.
		local Item = player.primaryHandItem()

		if Item then
			if Item.name:find("cb_cpu") then
				putInItemSlot(widgetName, Item)
			end
		else
			takeFromItemSlot(widgetName)
		end
	end
end

function gpuSlotModifier(widgetName)
	if not widget.getChecked("buttons.0") then
		local Item = player.primaryHandItem()

		if Item then
			if Item.name:find("cb_gpu") then
				putInItemSlot(widgetName, Item)
			end
		else
			takeFromItemSlot(widgetName)
		end
	end
end

function ramSlotModifier(widgetName)
	if not widget.getChecked("buttons.0") then
		local Item = player.primaryHandItem()

		if Item then
			if Item.name:find("cb_ram") then
				putInItemSlot(widgetName, Item)
			end
		else
			takeFromItemSlot(widgetName)
		end
	end
end

function storageSlotModifier(widgetName)
	if not widget.getChecked("buttons.0") then
		local Item = player.primaryHandItem()

		if Item then
			if Item.name:find("cb_harddrive") then
				putInItemSlot(widgetName, Item)
			end
		else
			takeFromItemSlot(widgetName)
		end
	end
end

function diskSlotModifier(widgetName)
	if not widget.getChecked("buttons.0") then
		local Item = player.primaryHandItem()

		if Item then
			if Item.name:find("cb_disk") or Item.name:find("cb_floppy") then
				putInItemSlot(widgetName, Item)
			end
		else
			takeFromItemSlot(widgetName)
		end
	end
end

function expansionSlotModifier(widgetName)
	if not widget.getChecked("buttons.0") then
		local Item = player.primaryHandItem()

		if Item then
			if Item.name:find("expansioncard") then
				putInItemSlot(widgetName, Item)
			end
		else
			takeFromItemSlot(widgetName)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- 
----------------------------------------------------------------------------------------------------

function onButtonToggle(index)
	-- Ensure all the necessary components are in the computer.
	if storage["cpuSlot1"] and storage["ramSlot1"] and (storage["storageSlot1"] or storage["diskSlot1"]) then
		-- Check if the restart button is on.
		if widget.getChecked("buttons.1") then
			widget.setChecked("buttons.1", false) -- If so, switch it off.
			widget.setChecked("buttons.0", true)  -- Then turn the power button on.
			world.sendEntityMessage(ComputerID, "preformRestart") -- And then restart the computer.
		else
			world.sendEntityMessage(ComputerID, "setPowerState", widget.getChecked("buttons.0"))
		end

	else -- Otherwise, prevent the computer from booting.
		widget.setChecked("buttons.1", false)
		widget.setChecked("buttons.0", false)
	end
end

----------------------------------------------------------------------------------------------------
-- 
----------------------------------------------------------------------------------------------------

function init()
	ComputerID = pane.sourceEntity()
	onButtonToggle()

	newPromise(function(data)
		if type(data) == "table" then
			storage = data[1]; getErrorMessage()

			for widgetName, item in pairs(data[1]) do
				widget.setItemSlotItem(widgetName, item)
			end

			if data[2] then
				widget.setChecked("buttons.0", true)
				widget.setText("scrollArea.text", "Computer is currently running.")
			end
		end
	end, "getComputerData")
end

----------------------------------------------------------------------------------------------------
-- 
----------------------------------------------------------------------------------------------------

-- Note to self: Make this better.
function update(dt)
	for i = 1, #promises do
		if promises[i] then
			local promise = promises[i][1]
			if promise:finished() then
				promises[i][2](promise:result())
				promises[i][1] = nil
				promises[i][2] = nil
				remove(promises, i)
			end
		end
	end

	newPromise(function(data)
		if data ~= "nil" then
			widget.setText("scrollArea.text", tostring(data))
		else
			getErrorMessage()
		end
	end, "getLastError")
end