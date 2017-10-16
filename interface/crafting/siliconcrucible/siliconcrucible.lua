local promises = {}
local crucibleID

local storage
local cconfig

local remove = table.remove
local isDownloading = true


local function newPromise(onCompletion, request, ...)
    promises[#promises + 1] = {world.sendEntityMessage(crucibleID, request, ...), onCompletion}
end

local function updateSlots()
    local silicon = storage.silicon
    local boules = storage.boules

    widget.setItemSlotItem("input", silicon > 0 and {name = "cb_silicon", count = silicon} or nil)
    widget.setItemSlotItem("output", boules > 0 and {name = "cb_siliconboule", count = boules} or nil)

    local hasEnoughSilicon = silicon >= 10
    widget.setButtonEnabled("toggleCrafting", hasEnoughSilicon and boules < cconfig.siliconBouleCapacity)

    if not hasEnoughSilicon and storage.start then
        newPromise(function() end, "storageSet", "start", false)
        storage.start = false; widget.setProgress("progressBar", 0)
    end
end

function onCraftingToggle()
    if storage.start then
        newPromise(function() end, "storageSet", "start", false)
        storage.start = false; widget.setProgress("progressBar", 0)
        widget.setText("toggleCrafting", "Grow")

    elseif storage.silicon >= 10 then
        local c = os.clock()
        newPromise(function() end, "storageSet", "start", c)
        storage.start = c
        widget.setText("toggleCrafting", "Stop")
    end
end

function inputModifier()
    local item = player.primaryHandItem()
    if item then
        if item.name == "cb_silicon" then
            local count = math.min(item.count or 1, cconfig.siliconCapacity - storage.silicon)
            if count > 0 then
                item.count = count; player.consumeItem(item)
                storage.silicon = storage.silicon + count
                newPromise(function() end, "storageSet", "silicon", storage.silicon)

                updateSlots()
            end
        end
    else

        player.giveItem({name = "cb_silicon", count = storage.silicon}); storage.silicon = 0
        newPromise(function() end, "storageSet", "silicon", storage.silicon); updateSlots()
    end
end

function outputModifier()
    if not player.primaryHandItem() and storage.boules > 0 then
        player.giveItem({name = "cb_siliconboule", count = storage.boules}); storage.boules = 0
        newPromise(function() end, "storageSet", "boules", storage.boules); updateSlots()
    end
end

function init()
    crucibleID = pane.sourceEntity()

    newPromise(function(data)
        if type(data) == "table" then
            storage = data
            if storage.start then
                widget.setText("toggleCrafting", "Stop")
            end
        end
    end, "storageGet")

    newPromise(function(data)
        if type(data) == "table" then
            cconfig = data

            cconfig.siliconCapacity = cconfig.siliconCapacity or 100
            cconfig.siliconBouleCapacity = cconfig.siliconBouleCapacity or 10
            cconfig.bouleGrowTime = cconfig.bouleGrowTime or 600
        end
    end, "configGet")
end

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

    if isDownloading then
        if storage and cconfig then
            widget.setVisible("input", true)
            widget.setVisible("output", true)

            updateSlots(); isDownloading = false
            script.setUpdateDelta(30)
        end

    else
        local start = storage.start
        if start then
            local diff = os.clock() - start

            if diff >= cconfig.bouleGrowTime then
                local passes = diff // cconfig.bouleGrowTime

                for i = 1, passes do
                    if storage.silicon >= 10 then
                        storage.silicon = storage.silicon - 10
                        storage.boules = storage.boules + 1
                    end
                end

                if storage.silicon >= 10 then
                    storage.start = os.clock() - math.max(diff - (passes * cconfig.bouleGrowTime), 0)
                else
                    storage.start = false
                end

                newPromise(function() end, "storageSet", "start", storage.start)
                newPromise(function() end, "storageSet", "silicon", storage.silicon)
                newPromise(function() end, "storageSet", "boules", storage.boules)

                updateSlots()
            else
                widget.setProgress("progressBar", diff / cconfig.bouleGrowTime)
            end
        end
    end
end